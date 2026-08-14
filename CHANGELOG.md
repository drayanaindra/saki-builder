# Changelog — saki-builder

All notable changes to the saki-builder plugin. Versions track `.claude-plugin/plugin.json`.

## 0.29.0 — 2026-08-15

**Graphify gains a post-build canonicalize/dedup pass, the pipeline stops downgrading models at
`/approved`, `build-opencode.sh` can mirror a repo's own config, and the repo registers itself as the
OpenCode plugin it ships.** All four land in the plugin snapshot at this bump.

### `/graphify` canonicalize/dedup pass (`config/skills/graphify/`)

`canonicalize_graph.py` is a post-build pass that normalizes a freshly built knowledge graph:
`normalize_id` (mirrors the `graphifyy ids.py` recipe), merges duplicate-label nodes to a
deterministic sorted-id winner (`canonical_id`/`merged_from`), rewires links + hyperedge nodes to the
winners, and accumulates `(src, tgt, relation)` edge weights keeping the strongest-confidence
provenance. Review-fix pass addresses three MED findings: no input mutation, no hyperedge dup-ids,
no empty-key collisions. `build_remap`/`rewire_links` are extracted (function ≤ 40 LOC), and the
empty-canonical-key fallback + unicode normalize_id are covered. Line coverage 87% ≥ 80%;
`test/test_canonicalize_graph.py` gates RED→GREEN. Wired into the SKILL.md pipeline with an honesty
note; `graphify-out/` + Python test/cov artifacts are gitignored.

### Model policy: most capable model everywhere (`config/skills/*`, `config/agents/*`)

The pipeline used to pin Opus for `/prd` + `/rplan` then downgrade to Sonnet at `/approved` for
implementation — backwards, since implementation is where correctness is decided. Every stage now
stays on the most capable model available. The `opus` alias (never a pinned `claude-opus-4-x`) is set
in Step 0; the python snippet degrades to an opencode `/models` hint when settings.json is absent.
Agent frontmatter `model:` pins are dropped so agents inherit the session model; the response header
is `Model: [MOST CAPABLE]`; default model in `config/settings.json` is `opus`.

### `build-opencode.sh --project <repo>` (mirror a repo's OWN config)

The global pass covered `~/.claude` only, so a repo's own CLAUDE.md / `.claude/agents/` /
`.claude/skills/` were invisible to opencode — silently downgrading any skill that prefers a project
override (e.g. `/reviewer` falls back to a generic checklist without `.claude/agents/reviewer.md`).
`--project` writes `<repo>/AGENTS.md` (CLAUDE.md with @imports inlined), `<repo>/.opencode/agent/`,
`<repo>/.opencode/command/`. Output paths probed against opencode 1.18.16, not assumed.

### The repo registers itself as an OpenCode plugin (`opencode/opencode.json`)

The `plugin` array is added so opencode loads the published `@saketek/saki-builder`; package.json
declares it as the dependency opencode resolves the plugin from (and fixes the description mojibake →
literal arrow), and package-lock is refreshed to the new version.

## 0.28.1 — 2026-08-11

Patch re-release of 0.28.0. No package content changed since the last publish (the only commit
after the tag touched the local `opencode/opencode.json` dev config, which is not shipped); this
version exists to re-publish the current `main` state to npm as `latest`.

## 0.28.0 — 2026-08-09

**The OpenCode plugin did not load, and its safety gates blocked nothing. Both are fixed, and
`/init-env` now scaffolds for OpenCode as well as Claude Code.** Anyone on 0.27.0 with the OpenCode
plugin installed should treat this as the release that makes it real: until now it registered
nothing at all.

### The plugin was inert (`opencode/plugins/plugin.ts`)

OpenCode 1.18.x does not look for a specific export name — it calls **every** export of a plugin
module as a plugin factory. A single non-callable export makes registration throw, and OpenCode
skips the entire module silently. `export const id = "saki-builder"` was exactly that, so the plugin
never loaded: no safety gates, no run visibility. It looked correct in review and matched the
`PluginModule` type, whose optional `id` belongs to the in-progress V2 system rather than the V1
loader we run on. (0.27.0's notes below claimed a `{ id, server }` default export was the working
shape. It was not — that is the bug.)

Probed against 1.18.15 on both load paths (a file in `~/.config/opencode/plugins/` and an npm
package registered via `plugin: [...]`):

| module shape | result |
|---|---|
| `export default fn` | loads |
| `export const server = fn` | loads |
| `export default fn` + `export const other = fn` | **both** load — registered twice |
| `export default fn` + `export const id = "x"` | **nothing loads** |
| `export default fn` + `export const n = 42` | **nothing loads** |

`plugin.ts` now exports only the factory, and forwards the real `PluginInput` to `SafetyHooks`
instead of `{}` — which had been discarding `worktree`/`directory` (run-state written relative to
`process.cwd()` rather than the worktree) and `client` (the bounded `session.idle` re-prompt could
never fire).

### The safety gates blocked nothing (`opencode/plugins/safety-hooks.ts`)

`tool.execute.before` wrapped its whole body in `try { … } catch { /* fail-open */ }`. Every guard
signals a block by **throwing**, so the catch swallowed the blocks themselves. Probed directly
against the shipped code: `rm -rf /`, `git push --force origin main`, a JWT in argv and an `sk-` key
in argv were all **allowed**, and the pre-push sonar + coverage gates were bypassed the same way.

The catch existed for a real reason — an OpenCode Event schema change was crashing runs — but it was
scoped to the whole handler instead of the one thing that can throw accidentally. It is now narrowed
to the input read: the command is parsed inside the `try`, every check runs outside it. Malformed
input still fails open; a deliberate deny propagates.

Both defects shipped in the same commit that broke `npm run smoke` into a parse error — and the
smoke test is what asserts those blocks. **A guard that is never observed blocking is
indistinguishable from no guard.** The tests now observe it: `test/test-safety-hooks.mts` watches
each guard actually block (and each allow case not fire), and the smoke test asserts every export of
`plugin.ts` is callable before anything else. Both fail against the pre-fix code.

### `/init-env` scaffolds for OpenCode (`config/skills/init-env/SKILL.md`)

`/init-env` produced a Claude-Code-only environment. Under OpenCode every load-bearing artifact was
ignored or silently degraded: OpenCode reads `CLAUDE.md` as a compat fallback but **never expands
`@import`**, so the execution protocol, ddd-patterns, modular-architecture and the project
`patterns.md` all vanished, while `.claude/settings.json` hooks, `.claude/agents/` and
`.claude/skills/` were ignored outright. The scaffold looked successful and loaded nothing.

One source, runtime engine detection — no forked OpenCode copy of the skill:

- **Step 0** detects the host (`OPENCODE` / `CLAUDECODE`, both positive signals — `OPENCODE` first
  because OpenCode launched from a Claude Code shell inherits `CLAUDECODE`) and resolves
  `SAKI_DOCS` + `SAKI_HOOKS` across the plugin, OpenCode and `~/.claude` installs.
- An **engine→artifact map** drives Steps 1–14 so the two cannot drift: `AGENTS.md` vs `CLAUDE.md`,
  `opencode.json` `instructions[]` vs `@import`, `.opencode/plugin/` vs `settings.json` hooks,
  `.opencode/agent/` (`mode: subagent`, no CSV `tools:`) vs `.claude/agents/`.
- `ENGINE=both` keeps the rules body in `AGENTS.md` exactly once, with `CLAUDE.md` as a thin
  `@import` wrapper.
- **OpenCode resolves project scope from the git root**: in a non-git directory `.opencode/` and
  `opencode.json` are ignored entirely, so that is now a blocking pre-check.

`config/docs/templates/opencode-quality-hooks.ts` is the `settings.json`-hooks analogue
(`tool.execute.after` = typecheck, `tool.execute.before` = commit gate, `throw` to block). It is a
real file inside the `tsconfig` include, so it cannot rot out of compiling, and its blocking throw
sits outside the fail-open catch by design.

Verified against the installed OpenCode 1.18.15: agents, skills, commands and plugins are discovered
from `.opencode/` (singular and plural both work), `instructions[]` resolves absolute and relative
paths and tolerates missing globs, and a scaffolded project registers `planner`/`reviewer`/`qa`.
`test/test-init-env-engines.sh` gates all of it and fails against the old Claude-only skill.

### OpenCode npm plugin packaging

**saki-builder is installable in OpenCode like a plugin, not just via the repo-clone bridge.**
The repo root is the npm package `@saketek/saki-builder` (zero runtime dependencies): the OpenCode
server entry `opencode/plugins/plugin.ts` wiring the existing `safety-hooks.ts` + `saki-state.ts`, a
bundle builder (`bin/build-npm-bundle.sh` → `dist/opencode-bundle/` reusing
`build-opencode.sh --from-plugin` + `namespace-refs.js --reverse`), an idempotent installer
(`bin/saki-install.mjs`, backup-before-overwrite, repoints AGENTS.md `config/docs/` refs to the
package), a smoke test (`npm run smoke`), and `docs/OPENCODE-INSTALL.md`.

Install: `opencode plugin @saketek/saki-builder --global` + `npx @saketek/saki-builder install`.
Publishing to npm is a human-gated step.

### Tests

`npm test` now runs `test/test-safety-hooks.mts` alongside `validate.js`, so the safety guards are
checked by default rather than only in a smoke script nobody notices is broken. New:
`test/test-init-env-engines.sh`, `test/test-safety-hooks.mts`. `npm run typecheck` and
`npm run smoke` are green again (both had been failing since 0.27.0's packaging work).

## 0.27.0 — 2026-08-07

**Four items and one measurement, all of which 0.26.0 shipped without.** The plugin loads a
version-pinned snapshot, so everything below was on `main` but unreachable by any installed user
until this bump.

**The runtime instructions now name commands that exist** (items I9, I10). 0.26.0 shipped with 187
bare internal references — `/rplan`, `/wrap`, `/build` — spread across skills, the completion-gate
hooks, and the on-demand docs. Under the `saki-builder` namespace none of those resolve, so every one
of them told the model to run something unavailable. The 18 worst sat inside strings the Stop gates
**inject straight into the model's context**: a build pushed back to work was instructed to take the
next slice "through rplan -> approved -> qa -> reviewer", naming four commands that do not exist.

Two classes were deliberately left bare, and the distinction is the interesting part.
`config/antigravity-skills/` (71 refs) installs into a **Gemini/Antigravity** runtime where the
`saki-builder:` namespace has never existed — rewriting those would point them at a command that
engine cannot resolve. Same for the five `/graphify` references that denote the **separate global
skill** at `~/.claude/skills/graphify`, where a rewrite would invert "invoke the global skill" into
"invoke yourself". `bin/namespace-refs.js` gained `--exclude` to make that boundary explicit and
repeatable rather than something a future contributor has to remember — and it **fails loud** when an
exclude matches nothing, because a guard that silently protects nothing is worse than no guard.

**The approval proof no longer lives only inside the PRD** (item I6). `/saki-builder:proto` wrote the
freeze marker into the PRD file, which assumes the PRD already exists when proto runs. It now writes
`tasks/proto-<slug>/.prd-locked` **always** — the gallery is proto's own output, so it exists in both
pipeline orders — and the PRD marker when the file is there; `/saki-builder:build` GATE 1.5 accepts
either. This widens *where* approval can be proven, never *whether* it must be: a run with neither
marker still hard-stops, and a `--slice` PARTIAL run still writes neither. The marker names the PRD it
froze so one gallery's approval cannot be inherited by another file deriving the same slug, and
`/saki-builder:prd` now **voids** it when it rewrites an existing PRD's scope — which is what keeps
"absence = not-yet-frozen" true now that the proof can outlive the file.

**The scope recut fires on the scope signal** (item I7). `/saki-builder:pickup` entered its Senior-PM
recut only when `/saki-builder:prd-review` returned `non-convergence` — binding a *scope* gate to a
*review* stage. New Phase 1.5 compares the §8 slice count against the §6 appetite band the moment the
PRD is written, reading the machine-readable `<!-- slices: N -->` / `<!-- appetite: X -->` markers the
PRD template already emits. Fail-open is load-bearing and tested: an unreadable band falls through to
the sentinel rather than recutting on a guess.

**The revision-pass baseline is now measurable.** `/saki-builder:prd-review` stamps a durable
`<!-- revision-passes: N -->` counter into the PRD header on every round it applies fixes — the state
file it already kept lives under gitignored `tasks/` and rotates per run, so it could never be read
back. `bin/revision-baseline.js` aggregates across runs and **refuses to emit a number** from
non-converged runs rather than a flattering one; that refusal is the load-bearing rule and it is
pinned by a test.

Every one of the four items was reviewed in a fresh context and every review returned REQUEST CHANGES
before it passed — including a regression this release introduced and caught (namespacing
`config/CLAUDE.md` leaked 15 unresolvable refs into opencode's generated `AGENTS.md`), an appetite
gate that was simultaneously **inert on all four real PRDs and false-positive-prone on three
constructible inputs**, and a lock marker that outlived the PRD it certified.

Tests: 14 suites green (was 11). New: `test-lock-resolution.sh` (8), `test-appetite-gate.sh` (14),
`test-revision-baseline.sh` (11); `test-namespace-refs.sh` grew 17 → 28.

## 0.26.0 — 2026-08-06

**A supervising agent can now see a saki-builder run while it is still running** (item I8).

Hermes Agent and OpenClaw both drive coding sessions the same way: spawn `claude -p` (or
`opencode run`) as a background subprocess and read what comes back. Running both headless under
Hermes, the operator hit the wall that shape has — *"the agent can't [be] aware when process running
in background."* Everything saki-builder emitted was **terminal**: an `--- DONE ---` block in prose,
written once, at the end. `git grep -- "--- DONE ---" --include=*.sh --include=*.js` returned zero
code hits at 0.25.1 — nothing parsed it, because it was never meant to be parsed. So a supervisor
polling for progress saw exactly one thing — nothing — whether the run was working, hung, crashed,
or had never started at all. Four states, one observation, no way to tell them apart.

A terminal signal cannot fix that no matter how well-formed it is. It answers *what happened*; the
question is *is it still alive*. The fix is a state file that exists for the **whole lifetime** of
the run, published by hooks rather than by the model:

| Event | Writes | Why it matters |
|---|---|---|
| `SessionStart` | `RUNNING`, `pid`, `started_at` | makes **absence** meaningful — no file now means "never started" |
| `PostToolBatch` | `heartbeat_ts`, `turns++`, `last_tool` | makes **liveness** observable while the run is in flight |
| `Stop` | terminal status from the model's `SAKI-RESULT:` line | the outcome |
| `SessionEnd` | closes a still-`RUNNING` state via `exit_reason` | a killed run can never leave a stale `RUNNING` |

All four verified to fire in headless `claude -p` before any of this was designed (`SessionStart` ×1,
`PostToolUse` ×2, `PostToolBatch` ×1, `Stop` ×1, `SessionEnd` ×1). `Notification` is registered too
but fired **zero** times in a clean run, so nothing depends on it.

The supervisor polls one path — `tasks/.saki/latest.json` — and reads four states off it: absent =
never started · `RUNNING` with `heartbeat_ts` advancing = alive · `RUNNING` with `heartbeat_ts` stale
= hung · terminal = done. `status` is one of `RUNNING · DONE · BLOCKED · NEEDS_INPUT · UNKNOWN`.
Concurrent runs each get `tasks/.saki/<session_id>.json`; `latest.json` is the last writer.

**A terminal status is provisional until `final`.** The three completion gates run *before* the state
hook in the `Stop` array and can block the stop to push the model back to work — and the hook cannot
see their verdict. So a tool batch arriving after a terminal write resurrects the run to `RUNNING`
(`resumed_after_stop` increments); only `SessionEnd` sets `"final": true`. A supervisor should wait for
`final`, or for a terminal status to hold across two polls, before tearing down. Caught in review: the
first cut froze the heartbeat permanently on exactly the `/build` runs the gates exist for.

**Staleness is the supervisor's judgement, and that is not a shortcut.** No hook survives `kill -9`.
A SIGKILLed session leaves `RUNNING` on disk forever and nothing in-process can change that, so
`docs/AGENT-RUNNERS.md` hands the timeout to the caller (`SAKI_STALE_SECONDS`, ~300s) instead of
pretending the run can report its own death.

**Agent mode** (`SAKI_AGENT_MODE=1`) layers `instructions/agent-mode.md` over the always-on core:
the Readiness Gate's "human approves" clause is void, Branch Points §2 (the AUTO-RESOLVED ladder)
becomes the default for every reversible fork, and the interactive Next Actions block is replaced by
the result contract. Two things still stop a run rather than hang it — a HIGH-tier irreversible
action and a genuine intent question — both emitting `NEEDS_INPUT` with one specific question.
Guardrails are untouched: a Non-Goal or `🔒 INVARIANT` is still a real `BLOCKED`.

Opt-in is by env var **only**. Sniffing was rejected on evidence, not taste: Claude Code runs command
hooks without a controlling terminal in ordinary interactive sessions, so TTY detection would have
flipped *every* session into agent mode. `instructions/core.md` is unchanged — it is injected into
every session and stays lean; the overlay is a separate file read only when the flag is set.

**opencode gets the identical schema**, so one supervisor loop serves both engines:
`session.created` → `RUNNING`, `tool.execute.after` → heartbeat, `session.error` → `BLOCKED`,
`session.idle` → terminal. One difference is stated rather than smoothed over: opencode has **no
Stop-gate equivalent**. `session.idle` is an event, not a gate, so it cannot force a run to
completion the way Claude's `Stop` hook can. The plugin logs `SAKI-INCOMPLETE: <n> slices remaining`
and attempts a bounded re-prompt (`SAKI_OC_MAX_CONTINUE`, default 5); if that is not reachable, the
run ends with an accurate INCOMPLETE record. Work that must be *forced* to completion belongs on
headless Claude, and the docs say so.

`bin/opencode-bridge.sh` installs from the **installed plugin root**, so using saki-builder under
opencode no longer requires cloning this repo. `build-opencode.sh --from-plugin` generates
`AGENTS.md` from `instructions/core.md` instead of the owner's personal `~/.claude/CLAUDE.md` —
verified to leak zero `/Users/` paths — and falls back to the plugin's own permission posture rather
than an empty block that would make opencode prompt for everything. `namespace-refs.js --reverse`
strips the `/saki-builder:` prefix from bridged skills, since opencode registers them bare.

Two findings from live payloads, recorded because both contradict the published docs:
`stopped_by` is documented for `Stop` but is **absent** from the actual payload, so a turn-limit stop
honestly reports `UNKNOWN` rather than being mislabelled; `stop_hook_active` **is** present and is
now published, telling a supervisor that one of our own completion gates held the stop open.

Nothing here can gate a run. `PostToolBatch` and `Stop` both support `decision:"block"` and the state
hook never emits it — a liveness probe that can halt the run it measures is a new failure mode, not a
feature. Every registration short-circuits in the shell before node starts, so an interactive session
pays ~7ms per tool batch instead of a ~40ms process spawn, and every error path exits 0.

New: `config/hooks/agent-session.js`, `instructions/agent-mode.md`, `bin/agent-setup.sh`,
`bin/opencode-bridge.sh`, `opencode/plugins/saki-state.ts`, `docs/AGENT-RUNNERS.md`.
Tests: 48 new assertions across three suites, including the two traps — a mid-sentence `BLOCKED:`
must not classify (line-anchored matching), and `SessionEnd` must never overwrite a terminal status.

## 0.25.0 — 2026-07-29

**`docs/project-context.md` gets a scope, a reader, and a writer** (item I5).

The file was written once by `/saki-builder:init-env` as three open-ended bullets — "business context
expanded · architecture overview · key decisions and constraints" — and then **read by nobody and
updated by nobody**: at 0.24.0 `git grep -c project-context -- config/` returned four hits — three in
`config/skills/init-env/SKILL.md` referring to itself, one in `config/antigravity-skills/init-env.md`.
No reader, no updater. It rotted from the first commit. Meanwhile the *derivable* half of "what is this
system" was already covered and auto-refreshed — `graphify-out/GRAPH_REPORT.md` (god nodes, communities,
surprising edges; rebuilt by post-commit and post-checkout hooks) is read by seven skills, and
`/saki-builder:arch-check` measures per-module tier on demand. So a free-prose revival would have been a
second source of truth with no tiebreak, the exact failure `arch-check` forbids.

The genuine gap is narrower. Graphify's extraction is AST/import-based and same-language, so it *cannot
see* a network call, an HTTP route dispatch, or a queue publish/subscribe — it reports **no path**
between two services that are genuinely coupled at runtime. And no graph carries intent: why a boundary
exists, which invariants hold, what is deliberately absent. That gap, and only that gap, is what the
revived file holds.

- **The contract** — new `config/docs/project-context-contract.md`. One rule: *derivable ⇒ banned*, with
  a table naming the owner of every banned category (god nodes, communities, per-file descriptions,
  module LOC, architecture tier, business narrative). Three allowed sections — **Topology** (deployables
  + the cross-boundary edges between them, cited `path:line`), **Invariants**, **Deliberate non-goals**.
  Plus a skeleton, a cite-or-drop rule, and a **100-line ceiling** as the anti-rot guard.
- **A reader** — `/saki-builder:rplan` §1 and `/saki-builder:prd` §0.7 Tier 1 now `cat
  docs/project-context.md` alongside the existing graph-first read. Purely additive: no existing line
  changed, and an absent file skips silently, so an un-upgraded project behaves exactly as before. The
  `prd` copy also says what to do with it — a cross-boundary edge is a §16 surface the graph cannot
  show; an invariant is a constraint a slice must not break.
- **A writer** — `/saki-builder:wrap` gains Phase-2 sub-step **2a**, running after staging on the paths
  actually staged. **Check 1** matches *filenames only*, against the **infrastructure** that accompanies
  a new service (Dockerfile, compose, Procfile, Terraform, chart, k8s manifest, `cmd/*/main.go`,
  migration files). It deliberately does **not** match language entrypoints — `index.ts`, `app.ts`,
  `main.py`, `server.js` are barrel files and modules far more often than deployables — and it is
  narrow, not exhaustive: a zero is not proof, which is why Check 2 exists.
  **Check 2 is a judgment call, deliberately not a content grep**: the agent has just read the diff to
  write the commit message, so it answers one question — did this add a deployable, a cross-process edge,
  or a system-wide invariant? — with the rule *if you cannot point at a specific added line, the answer is
  no*. Two adversarial review rounds established why: any regex broad enough to catch a route registration
  also fires on `req.Header.Get(`, `buffer.get(`, `container.get(`, `eventBus.emit(`, `npm publish` and the
  word "Subscribe" in prose. An always-on trigger rewrites the file on every commit — exactly the rot the
  contract exists to prevent — so one honest question beats a pattern that cries wolf. **No signal → no
  write** and a `Topology: ⏭` line. A signal **opens an inspection, not a rewrite**: if the file already
  covers it, 2a prints `✓ already current` and changes nothing. Every outcome carries a token (`⏭ ✓ ✎ + ⇄
  ⚠`) so no branch is silent, and the 100-line ceiling is measured (`wc -l`) after any write. 2a is
  deliberately *not* a DoD gate — it sits in Phase 2, and `Order is law` (DoD → commit → push → remove
  worktrees → switch to main) is unchanged.
- **Scaffold on contract** — `/saki-builder:init-env` Step 3 emits the three sections and the
  `Last verified:` stamp, and names the banned categories, instead of the old free-prose brief. The
  file's path is unchanged.

**Known gap, stated not hidden.** `config/antigravity-skills/init-env.md` still carries the old
free-prose brief, and it is **live** — `setup-antigravity.sh:78` symlinks it into the Antigravity
workflow paths. So that engine still scaffolds off-contract files, which 2a's grandfathering then has to
restructure. Excluded from this change by a documented No-Go (it is a separate hand-maintained port for
a different engine); it needs its own item, and the exclusion is **not** because the port is unused.

**Not retroactive.** A `docs/project-context.md` that **predates 0.25.0** was written to the old brief and
is **off-contract, not an error**: readers consume it as-is and never validate its shape, nothing warns or
blocks, and there is no migration to run. The first 2a trigger restructures it into the three sections —
keeping every topology, invariant and non-goal claim it already makes and dropping the rest (business
narrative, architecture overview, per-file notes). That is the one case where 2a edits outside the three
sections, because the sections do not exist yet.

## 0.24.0 — 2026-07-27

**Backward/forward compatibility + existing-capability chaining in the planning pipeline** (item I4).

Compatibility coverage was **DB-schema-only** (`rplan` §3 "no breaking schema changes without a rollback
strategy", plus the template's migration boxes). Neither `/saki-builder:prd`'s 32-row gate nor
`/saki-builder:rplan`'s §4b had a single predicate about a breaking change outside migrations — an API
field removal, a status-code change, a tightened validation, an auth-scope narrowing, a config/env rename,
a flag-default flip, an event-payload reshape, or a removed exported symbol all passed silently. The two
lenses that *do* ask about regression live in `/saki-builder:rplan-review`, which runs its expert panel on
HIGH-risk plans only — and `rplan` explicitly tells LOW/MED plans not to invoke it. Dependency tracing was
forward-only: Plan Wiring maps the *new* call chain, and §4a proves an anchor *exists* but never enumerates
that anchor's existing callers.

- **`/saki-builder:prd` — §16 `CHANGE` tag.** A third row tag beside `REUSE`/`NEW` for an existing surface
  the feature *modifies*. Cited on the REUSE bar (a real `path:line`) **plus** a `↳ Breaks:` sub-line naming
  what depends on the present shape. Applied to all three emit parts (the architecture-decision line hid
  load-bearing modifications), with the `omit-if-none` hole closed — "adds no surface" let a
  pure-modification feature skip §16 entirely. New `BLOCK` on a `Breaks:`-less CHANGE row; new deduction on
  a REUSE row whose slice text says change/extend/rename.
- **`/saki-builder:prd-review` — verifies it.** CHANGE accepted as cited; a new **Compat-declared** check
  wired into *all three* closed REVISE enumerations — the step-8 finding list, the verdict table, and the
  printed synthesis block (a finding with no verdict path is inert, and one that never prints is invisible);
  Judge 3 now surfaces the compatibility shim / dual-read window as hidden build work.
- **`/saki-builder:rplan` — consumer inventory + gate.** A Step-1 reverse-dependency pass (grep every caller
  of each changed/removed surface, verdict each: `unaffected` / `updated in step N` / `breaks — <mitigation>`,
  then answer forward-compat: additive / versioned / tolerant-reader / deploy-order); a
  `## Compatibility & Consumers` plan-template section; two checklist boxes; and **three §4b Blocking
  predicates** that §4c may not demote — a breaking change on a step scored LOW is a mis-scored step.
  The §16 ingestion rule now knows the CHANGE tag (it was a closed two-tag vocabulary).
- **Expand-contract doctrine un-orphaned.** `config/skills/database/safe-migrations/SKILL.md` (Backward
  Compatible First, rename-via-copy, `CREATE INDEX CONCURRENTLY`, multi-step drop) already existed and was
  reachable only from `gateway-database`. `rplan` Step 1 now loads it on any schema change.
- **Cross-slice chaining.** `rplan` reads sibling `tasks/<prd-slug>-slice*-plan.md` for slices 1..N-1 and
  plans against the **shipped** shape when it disagrees with the PRD. INVEST rule 4
  (forward-dependency-only) was declared in the PRD and verified nowhere. `approved`'s drift-check now
  reconciles the compat table too, so slice N never reads a stale one.
- **`/saki-builder:rplan-review`** gained the matching Phase-1 required-section row (its structural scan
  runs on every reviewed plan, unlike the HIGH-risk expert panel).

**Additive — nothing existing is invalidated.** `REUSE`/`NEW`-only §16s remain valid; the new §4b
predicates gate plan *construction* and **do not retroactively block plans written before 0.24.0**;
additive-only work clears the whole pass by writing `None — additive only`. A plan with **no**
`## Compatibility & Consumers` heading at all predates the section, so `rplan-review`'s Phase-1 scan
marks it ✅ with a `predates 0.24.0` note rather than routing it back — absence is grandfathered, an
empty section is not.

## 0.23.2 — 2026-07-24

- **Graphify: fixed a fictional `betweenness` field + doc/schema drift.** Verified against a real
  build that `graph.json` has no `betweenness`/centrality field at all — "god nodes" are ranked by
  raw edge count (`Degree` in `graphify explain` output), and edges live under `links[]`, not the
  documented `edges[]`. Corrected `graphify-usage.md`'s schema section and every skill that cited
  the fictional `betweenness > 0.05` threshold (`graphify`, `arch-check`, `prd`, `prd-review`,
  `rplan-review`), and replaced a stale `graph.json`-parsing Python snippet in `graphify/SKILL.md`
  with the CLI — the exact anti-pattern 0.23.1 was supposed to have removed everywhere.
- **`rplan-review`: cross-service coupling caveat.** `graphify path` finding no path is not proof
  of no coupling when the two nodes cross a language/process/service boundary (e.g. a TS
  frontend/server node calling a Go HTTP handler) — AST extraction can't see network calls, so a
  "no path" there is silence, not evidence. The graph-confirm/downgrade logic now verifies the
  call site directly before downgrading a blocker on graph silence alone.
- **`/saki-builder:prd`: automatic Discovery Spike.** Step 0b now runs a timeboxed spike itself
  (reusing `/saki-builder:rplan`'s Spike Protocol) when the load-bearing assumption is `assumed`
  and two failure reasons stand unrebutted, instead of only recommending one to the human. A
  grounded finding retags the assumption `observed`/`validated`; an inconclusive one is recorded as
  a `**Spike:**` line in §2 — which `/saki-builder:prd-review`'s evidence-floor and readiness
  checks now recognize as the concrete artifact a "named spike" means, rather than accepting the
  bare word in prose.

## 0.23.1 — 2026-07-21

- **Graphify: correct integration pattern across all skills** — all graphify blocks rewritten to
  use the official pattern from graphify.net docs: `cat GRAPH_REPORT.md` first (71.5× cheaper
  than raw files), then `graphify query/path/explain` CLI for targeted traversal. Removed
  incorrect Python API calls (`graph.json` parsing via subprocess) from all 5 skills — these
  reinvented what the CLI already does.
- **`graphify claude install`** added to `/saki-builder:graphify` Step 1.5 — wires the `CLAUDE.md`
  directive and `PreToolUse` hook (fires before every Glob/Grep; message: "Read GRAPH_REPORT.md
  first"). Now runs automatically after every graph build.
- **`config/docs/graphify-usage.md`** — new canonical reference doc with full CLI command table,
  graph schema, edge provenance rules, and per-question usage guide. All skills reference it.
- **`/saki-builder:reviewing-architecture`** — added graph-first reading step (god nodes, community
  boundary validation, surprising connections) before feature file reads.
- **Coverage**: graph-first pattern now in all 6 code-reading skills: `prd`, `prd-review`, `rplan`,
  `rplan-review`, `arch-check`, `reviewing-architecture`.

## 0.23.0 — 2026-07-21

- **Graphify integration** — `/saki-builder:graphify` (new skill) wraps the Graphify-Labs knowledge graph
  library with auto-install (uv/pip), saki-builder workflow context, and three modes: standalone build,
  research query (called by `/rplan`), and architecture enrichment (called by `/arch-check`).
- **`/rplan` research phase** now queries an existing `graphify-out/graph.json` automatically when one
  exists — surfaces blast radius, highest-betweenness god node, and community boundary crossings as a
  **Graphify Findings** section in the context doc. Offers (once, non-blocking) to build the graph for
  repos with ≥20 files that have no graph yet.
- **`/arch-check` Step 2.5** — new graphify enrichment block that, when a graph is present, extracts god
  nodes (top betweenness centrality), community clusters (bounded context candidates), and surprising
  connections from `GRAPH_REPORT.md`. God nodes in `stage3_fired=yes` modules become HARD UPGRADE signals;
  god nodes in Stage 2 modules surface as coupling-risk CANDIDATES.
- **`/prd` Tier 1** — graphify pre-fetch before codebase reads: god nodes pre-populate §16 REUSE rows;
  cross-community traversal identifies the single architecture decision; god-node touches flagged early
  as centrality risk rather than discovered at rplan time.
- **`/prd-review` before Judge 3** — coordinator fetches community clusters and god nodes before
  dispatching the lead judge; threads graph context into Judge 3's prompt so cross-boundary slice
  coupling and omitted §16 god-node REUSE rows are citable findings, not inferences.
- **`/rplan-review` Phase 3 step 2** — graphify structurally confirms or refutes architecture blockers:
  confirms coupling when graph shows an edge (cite betweenness), downgrades when no path exists,
  elevates warnings when a "low-risk" component is a top-6 god node.

## 0.22.0 — 2026-07-20

- **`/saki-builder:proto` now runs the project itself instead of dying when no dev server is up.** Its
  entire previous treatment of a stopped project was the phrase *"Otherwise start it"* — no command
  derivation, port choice, readiness wait, failure triage, pid record, or teardown. Since the capture
  hard-gates every frame on a live-DOM `__PROTO__` sentinel, nothing serving meant every frame failed and
  the Coverage Gate hard-stopped, with no recovery branch anywhere in the skill. New **Step 5.5 (Bring the
  app up)** owns the whole server lifecycle: **reuse-first** (a server you started is detected by cwd, marked
  `owner: human`, and **never killed**), boot-command derivation from the framework + lockfile, a **detached
  spawn into its own process group**, a readiness wait, and a **loopback-bind verification** — the preview
  route runs with auth bypassed, so a `0.0.0.0` bind would expose an unauthenticated route. A four-rung
  **triage ladder** handles the common boot failures (missing `node_modules` → frozen install · missing env →
  non-resolvable placeholders, never a real `.env` · busy port · harness compile error), with a 3-strike
  guard and an actionable stop message. Teardown runs at Step 8 — after Step 7.5 has had its chance to
  re-verify — guarded by a cwd identity check and a self-kill guard, killing the **process group** so the
  real server isn't orphaned behind its `npm` wrapper.
- **`/saki-builder:proto` stopped stating its rules three times.** The skill carried its gates in the Steps,
  again in an 18-bullet Rules section, and again in a 57-row anti-pattern table — 69 of those 75 items were
  pure restatement, so every gate change had to be made in three places or drift. It already had: one Step
  wrote a bare `javascript_tool` while the table two sections below warned against exactly that. The Steps
  are now the single normative home, with **18 one-line Invariants** each naming its owning Step, and the
  incident rationale moved to `config/docs/proto-incidents.md`, loaded on demand. The six items that were
  *not* duplicates were relocated into their Steps first, verified before any deletion.
- **`index.md` — the artifact `/proto` shows you for approval — finally has a producer spec.** It had 15
  references across the skill and no template, because it is *accumulated*, not written once. It now has a
  fixed shape (header · Journey overview · **§Fidelity reductions** · Decision log), every "note it in
  `index.md`" site appends to that one section, and the resume ledger verifies the section exists — a
  resumed run must say reductions are unrecoverable rather than silently write an empty list.
- **Shareable headers + a tidier run directory.** `index.md`, `screen-manifest.md` and `reuse-map.md` each
  carry `Owner · Status · Updated · PRD @ <sha>`, and the `/build` handoff notes moved from
  `tasks/proto-<slug>-notes.md` into `tasks/proto-<slug>/notes.md` (settling a `<prd-slug>`/`<slug>` naming
  drift), with all five `/saki-builder:build` consumers updated in lockstep.
- **The two largest code blocks left the spec.** The headless capture script and the gallery markup now live
  in `config/docs/templates/`, each behind a transcribe contract (read → fill `SCREENS` from this run's real
  journey → write → run) rather than a bare description. `proto/SKILL.md` went **1917 → 1710 lines (−11%)**
  without weakening a gate.
- **Fixed:** the SonarQube pre-merge gate reconnects to the local server (`sonar-gate.sh`,
  `sonar-gate-init.sh`).

## 0.21.0 — 2026-07-18

- **`/saki-builder:build` gains a PLAN mode — plan-track items (Improvement `I<n>` / Bug `B<n>`) now run
  autonomously, the same as PRD-track.** Previously only Epic/Feature PRDs had a one-command executor; an
  Improvement or Bug meant running `/saki-builder:rplan → rplan-review → approved → qa → reviewer → wrap`
  by hand. `/saki-builder:build I<n>` · `B<n>` · `<plan-file>` now runs that whole chain **once** over a
  single plan-track item. The same skill picks its mode from the argument (id prefix + roadmap `**Track:**`,
  or file shape): **PRD mode is unchanged**; **PLAN mode** drops the PRD-only gates (no lock check, no slice
  iteration, no proto-fidelity gate) and runs a single-plan loop that reuses the same underlying skills —
  no behavior re-implemented. A missing plan is **created** (PLAN mode runs `/saki-builder:rplan` itself),
  not a stop, since the roadmap item is the pre-existing scope unit and plan-track has no human lock gate.
  Completion prints `PLAN_BUILD_COMPLETE` and flips the item `Shipped`.
- **UI changes in a plan-track item are handled inline, auto-picked.** The `/saki-builder:reviewer` step
  always runs a **design-system reuse check** (a component that hand-rolls raw markup in place of an existing
  primitive is a blocking finding; composition and genuinely-new primitives are exempt). When a plan touches
  more than one screen or introduces a new visible state, a **screenshot glance** of those screens is
  captured after `/saki-builder:approved` and surfaced in the completion output. `/saki-builder:proto` is
  PRD-bound (it can't consume a plan), so PLAN mode never calls it — the reuse check plus the glance cover it.
- **Cross-skill wiring for the new mode.** `/saki-builder:qa` skips its own `Shipped` flip when driven by
  `/saki-builder:build` (keyed off a concrete `BUILD-DRIVEN` token in the invocation) so build owns the
  terminal flip after reviewer + wrap converge — no premature `Shipped` at qa-pass. `/saki-builder:rplan`
  Step 0.6 now records `**Child plan:**` back to the roadmap (the primary item→plan link; the `**Item:**`
  header stamp remains the fallback), and its Step 7 manual-chain seed is skipped for any build-driven run
  (PRD slice or PLAN item). `/saki-builder:add` and the README surface `/saki-builder:build <id>` as the
  autonomous Plan-track option.

## 0.20.0 — 2026-07-18

- **"Earn the handoff" replaces the A/B/C option menu at every branch point.** When an agent hit an
  unexpected state mid-workflow it used to present a human an option menu and stall — the option menu
  existed because there was no state between "decide" and "quit". The Branch Points rule is now a
  three-state model — **decide / pause / block** — ported from the proven `/saki-builder:build` step 0b:
  reversible, implementation-shaped forks are decided and recorded (`AUTO-RESOLVED:`, annotated in the
  plan so it survives the session); irreversible (Risk-Tiers HIGH: migration, auth, delete, push) or
  intent-shaped forks pause with ONE specific question (resumes on answer, never a give-up); a fork whose
  only resolution crosses a Non-Goal / `🔒 INVARIANT` / ABSOLUTE NO-GO is the genuine `BLOCKED:`. The
  autonomy license ships with its limit in the same rule body, so it can't invert the "NEVER assume" core
  rule. Applied across `config/CLAUDE.md`, `instructions/core.md`, `config/docs/execution-protocol-detail.md`,
  the `/saki-builder:rplan` · `rplan-review` · `approved` skills, the plan template, and the
  `product-engineer` agent (rule body kept byte-identical across copies).
- **Probe before claiming a capability is absent.** A capability claim ("I don't have tool X") is now a
  blocking item like any other and needs a citation: probe the ladder — deferred tool (`ToolSearch`) →
  CLI on PATH (`command -v`) → installable (`brew`/`npx`) → env present (`[ -n "$VAR" ]`, tested for
  presence, never printed) — and cite the probe that failed before emitting `BLOCKED:`. Never probe
  around a refusal: a denied permission, a missing credential, and interactive auth are genuine human
  handoffs, not obstacles to route around.
- **`/saki-builder:rplan-review` Phase 1 self-routes instead of terminating**, bounded by a durable
  routing budget. When a caller (e.g. `/saki-builder:build`) passes a plan path, a structural-gap failure
  routes back to `/saki-builder:rplan` and re-reviews rather than dead-ending at a human ("REVIEW STOPPED"
  is preserved only for human-invoked reviews). The 3-strike bound is a `<!-- rplan-review-phase1-attempts -->`
  counter in the plan file (survives compaction/re-invocation), scoped to the routing path, cleared on a
  Phase 1 pass, with a named manual escape — so it can't fabricate a false "survived 3 rounds" block on a
  later legitimate review.
- **`/saki-builder:reflect` enforces an auto-load budget with evict-to-make-room.** An admission filter
  promotes only env/tool/skill facts, preferences/policies/decisions, or corrections to recurring failures
  — rejecting generic best-practice the model already applies and duplicates of existing CLAUDE.md / core
  rules. The always-on patterns files are held under a context ceiling (40k hard / 37k soft cap, measured
  in Unicode), evicting the lowest-value entries to admit higher-value ones.

## 0.19.0 — 2026-07-16

- **`/saki-builder:pickup`'s Phase-2b scope recut now actually auto-resolves** — previously the run
  starved and stopped mid-recut, needing a manual re-invocation. Root cause: the `pickup-completion-gate.sh`
  Stop hook was false-wedged while `/pickup` delegated to `/saki-builder:prd-review` (it burned its
  no-progress budget on stops that were really the delegated loop's progress), so by the time the run reached
  the recut the gate was exhausted and released it. Fixed by folding the FRESH (mtime-windowed) delegated
  `review.rounds` **and** a capped recut-progress signal into the gate's score, so pickup is credited for
  delegating and for each `/add` during the recut. Slug is whitelisted + realpath-confined before the
  sibling-file read (no path traversal); every new path is fully fail-open.
- **The 3-round review cap is now harness-enforced, not prose.** `prd-review-completion-gate.sh` clamps its
  score at a hard cap (`PRD_REVIEW_GATE_HARD_CAP`, default 4) so a loop that runs past the cap plateaus and
  the circuit-breaker deterministically releases with a terminal "round cap → emit non-convergence"
  instruction — instead of the score rising every stop and wedging the loop forever.
- **Redesigned recut state-machine (single source of truth).** One parent-named `tasks/.pickup-<slug>-state.json`
  for the whole recut (never renamed, so GATE 0 resume-by-item-id always resolves); a `recut.stage`
  cursor (`phasing → registering → driving`); fresh MVP breaker budget via deleting the gate sidecar in place
  (not renaming the file); the once-guard compares the loaded `state.slug` to `recut.active_slug` so a child
  MVP never recuts again; a run with no `recut` block is never treated as a recut.
- **New `senior-pm` `MVP-Phasing Decision` artifact** (5-field-per-phase shape returned inline, objective
  triggers, decide-not-ask) that `/pickup` embeds verbatim in its Phase-2b spawn, plus a deterministic
  `/saki-builder:add --autonomous` no-prompt path with strict shape-field sanitization (a model-generated
  phase field can't forge a roadmap block or override the always-`Planned` status).
- 80 discriminating regression tests across the two gates (verified to fail against the un-fixed gate) +
  a markdown-contract test locking the skill/agent behaviors.

## 0.18.0 — 2026-07-15

- **New skill `/saki-builder:resume` + a `state.json`-style resume manifest for the manual chain — so a
  hand-run `/rplan → /rplan-review → /approved → /qa → /reviewer → /wrap` survives a context clear the way
  `/saki-builder:build` already does.** Each chain skill stamps its step into `tasks/.<slug>-state.json`
  (best-effort — a missing/unreadable manifest changes nothing, it is never a new gate, and it never clobbers
  `/saki-builder:build`'s `.build-*` manifest). The schema, init/stamp/reader snippets, `/wrap` glob
  resolution, and the orientation protocol live in one place: `config/docs/manual-chain-resume.md`.
  `/saki-builder:resume [<slug>|<plan-path>]` is a **read-only** reader that reports each step's status and the
  exact next command to run — re-entering a `red`/`not-ready`/`changes-requested` step, and treating an absent
  optional `rplan-review`/`security` step as satisfied. Auto-discovered via the `config/skills/` glob — no
  `plugin.json` skills-array change.
- **Closed the last mtime-dependent seam in the plan handoff.** `/saki-builder:rplan-review` now pins to a
  caller-passed plan file exactly like `/saki-builder:qa` and `/saki-builder:approved` already do, and
  `/saki-builder:build` passes each slice's plan into the review step — so a multi-slice build can no longer
  bind the review to the wrong slice's `*-plan.md`.

## 0.17.1 — 2026-07-15

- **`/saki-builder:n8n` Phase-1 now elicits `Bindings` + all `Branches` — so a requirement can reach the
  SAME result as a reference workflow, not just a similar shape.** Reversing a real 26-node workflow into a
  spec and rebuilding showed a plain requirement is lossy: it captures behavior but drops (a) the **bindings**
  — the exact data sources (sheet + tab ids), target ids (channel/list/label ids), and AI **model + guardrail**
  the result depends on — and (b) the **non-happy branches** (spam / unrelated / escalate / forward / skip),
  so a rebuild reads different data and silently omits paths → a different result. Phase 1's elicitation and
  the spec template now require both; the template notes a spec must carry Bindings + all Branches to
  reproduce an existing workflow's result. Behavior is portable; bindings pin the result.

## 0.17.0 — 2026-07-14

- **New skill `/saki-builder:n8n` — autonomous n8n automation builder.** Understands the expectation
  (a one-line goal → elicits gaps → writes `tasks/n8n-<slug>-spec.md`, OR an existing spec/PRD file →
  builds directly), authors the workflow JSON, deploys it against a **live** n8n instance via the REST
  API, triggers a real execution through the workflow's production webhook, reads the execution result,
  and self-corrects ("auto resolve") until a real run passes the spec's acceptance criteria — then stops
  with `N8N_AUTOMATION_COMPLETE`. **Safety is built in from the first run** (per the retry-engine
  discipline): exponential backoff, a circuit-breaker gated on a progress signal, a hard attempt budget
  (`N8N_MAX_ATTEMPTS`, default 8), and search-by-name idempotency so retries/feedback re-runs update the
  **same** workflow instead of duplicating it. Reuses `iterating-to-completion` (completion promise +
  scratchpad + loop detection) and the `/prd`·`/proto` elicitation tone rather than re-implementing them.
  Grounded on the verified n8n public API (no ad-hoc execute endpoint → trigger via production webhook;
  create body is `{name,nodes,connections,settings}` only; execution errors read from
  `data.resultData` with a version-drift fallback). Requires `N8N_BASE_URL` + `N8N_API_KEY` in env; the
  key is a secret and is never routed through chat. Faithful (builds exactly the spec) and concise.
  Auto-discovered via the `config/skills/` glob — no `plugin.json` skills-array change.

## 0.16.0 — 2026-07-14

- **Design anti-slop: `/genesis` now *elicits* a real design direction instead of accepting adjectives.**
  The Design System Contract's **Part 0 Step 1** gains a 6-step elicitation method so a non-designer is
  guided to a concrete DIRECTIONAL REFERENCE from the product's own world (materials, vernacular, artifacts)
  rather than a blank prompt that yields "modern/clean" slop: ask about the *world*, not the look; a **second
  gear** ("what does it replace + the moment of use") for abstract products with no physical world
  (analytics, infra, B2B); a physical-object metaphor prompt; reject both adjectives **and** named AI-default
  *tells* via an inline Part F checklist; a new `config/docs/design-reference-menu.md` used only as a
  last-resort axis-calibrator + springboard (never a destination — a raw archetype pick reproduces a tell);
  and a restate step with a **competitor-test** that forces the differentiating *quality* over a repeating
  anchor family.
- **Rendered-output enforcement — tells are caught on the composed screen, not just the tokens.** Part F
  gains a **"Composition tells"** anti-pattern (gradient hero · emoji-as-icons · equal-weight grid / no
  hierarchy · everything-centered · generic copy) — slop that survives clean tokens because it lives in the
  layout. `/proto` gains **Step 6.5**, a BLOCKING rendered-output tell-check between screenshot capture and
  human review that grades each screen against the Part F tell-list **and** the pinned DIRECTIONAL REFERENCE
  (a reference-judge — a fixed checklist alone passes tasteful "costume" slop), keeping Part F's legitimacy
  escape. The same enforcement is applied *proportionately* to the other design-producing skills: `/genesis`
  G2 checklist-checks the vision mock (no reference exists yet), and `/component` gains a Part F tell /
  reference-drift box in its Part C self-check. Together the pipeline is elicitation → token critique →
  vision/component/screen enforcement: guided toward good own-world design, blocking any surface that drifts
  onto a tell.

## 0.15.0 — 2026-07-10

- **`/scaffold-library` is now polyglot (Go · Python · Rust · Node · TypeScript · Ruby).** Previously the
  skill assumed Node/TypeScript — in a Go, Rust, Python, or Ruby project it produced a wrong (npm) scaffold.
  It now detects the language from the manifest (`go.mod` / `Cargo.toml` / `pyproject.toml` / `package.json`
  → Node vs TypeScript via `tsconfig.json` / `*.gemspec`|`Gemfile`), mirroring the detection-branch pattern
  already used by `/scaffold-cli` and `/scaffold-tui`, and scaffolds each language's manifest, build tool,
  source layout, public-API surface, tests, linter, and CI. Ruby is net-new (canonical Bundler skeleton:
  `lib/<name>.rb` + `version.rb` + `<name>.gemspec` + RSpec). A `language` input (default `auto`) drives the
  greenfield case; the existing `runtime`/`format` inputs are preserved and scoped to Node/TypeScript.
  Single entry point unchanged.

## 0.14.0 — 2026-07-09

- **`/genesis` — a greenfield entry point that starts a product FROM SCRATCH.** The normal
  roadmap→pickup→prd→proto→build loop can't start on an empty repo (`/proto` hard-STOPs with no design
  system; `/prd` has no stack to ground against). `/genesis "<idea>"` manufactures those preconditions in
  the order a product is born: G0 MVP goal → G1 bounded research → G2 a throwaway vision mock → G3 the
  foundations spec (stack · design system · architecture · schema) behind **one** human approval gate →
  G4 scaffold → G5 seed `tasks/roadmap.md` with the MVP epic and stop. It produces the loop's inputs, then
  converges onto the existing loop unchanged. Frontend/backend are always separate top-level folders and
  the backend language is always prompted; the **Design System Contract** is wired in so the scaffold
  matches `/proto`'s GATE 2. (Slice 1: G4 is a printed checklist the human runs; auto-scaffold is Slice 2.)
- **§5 success metrics are now instrumented end-to-end, not just declared (I1).** `/prd` classifies each
  §5 `Method` as `query` / `event` / `external` and requires an event-class Method to name the event it
  emits; `/prd-review` flags an unnamed one; `/rplan` ingests each event-class Method as a build step +
  firing criterion; `/qa` gains an `EVENT` criterion type (asserts the emit fires on the trigger, not on
  the error path); `/reviewer` flags a declared-but-never-fired metric; `/approved` treats an emit step as
  Test-Along. A metric the PRD declares now ships as built, verified instrumentation.
- **Built products default to GA4 analytics** so they are measurable at release without extra setup.
- **Workflow seam audit — all 14 findings fixed** (trace in `dryrun-e2e-audit.md`). A dry-run of both entry
  chains (greenfield + existing project) surfaced 14 handoff gaps between skills; all are resolved:
  `/genesis` probes the real scaffold state and reports `GENESIS_READY` honestly (no false "GATE 2 passes"),
  forces `--epic` for a deterministic `E1`, and runs its sub-skills non-interactively; `/pickup` pins the
  PRD filename/slug and advances the PRD doc Status; the plan-track (`/rplan` → `/qa`) now seeds from and
  closes out its roadmap `I/B` item (`Planned → In-progress → Shipped`); `/build` pins each slice's plan,
  guards against empty-diff false-greens, binds the `Shipped` flip to `PRD_BUILD_COMPLETE`, blocks e2e-absent
  on a multi-slice PRD, and closes a recut parent when its last phase ships; `/approved` enforces the
  Blocking-Set readiness gate; `/rplan-review` is now `user-invocable`.
- **All workflow artifacts now live under `tasks/`** (plans, `-context.md`, `-flow.md`) instead of the
  project root — one folder alongside the PRDs, roadmap, and state files. Also fixes a latent mismatch where
  `/proto` already read `tasks/*-flow.md` while `/rplan` wrote flow files to root. *Behavior change:* a fresh
  `/rplan` writes `tasks/<task>-plan.md`; the readers (`/approved`, `/qa`, `/rplan-review`) look there.

## 0.13.0 — 2026-07-08

- **`/pickup` now acts as a Senior PM when a PRD review dead-ends on scope — it recuts the initiative
  into an MVP instead of just stopping.** Before, a review that couldn't reach green left the item
  `Blocked` for a human. Now, when the block is a *scope* signal (`non-convergence` — blockers not
  falling across rounds, or the 3-round cap hit still-not-green), `/pickup` spawns the `senior-pm` agent
  to split the over-appetite initiative into a thin **MVP** plus trigger-gated follow-on phases,
  registers each as a roadmap Feature via `/add`, records a `Phase chain:` on the parent, and drives
  **only the MVP** to green — the follow-on phases stay `Planned` with objective triggers for a later
  `/pickup`. The reasoning: when blockers accumulate faster than they clear, the load-bearing problem is
  scope, not implementation gaps — the fix is to recut, not to keep revising.
- **The recut fires only on a scope blocker, never on a discovery one.** A `DISCOVERY-FIRST` block (the
  premise/evidence is too thin) or an unaccepted bet still stops for a human — you can't phase your way
  past not knowing whether the premise holds. An ambiguous `readiness` blocker is classified by the
  senior-pm first (decomposable scope → recut; bet/discovery → blocked).
- **Guardrails.** The senior-pm's phasing is verified against the actual PRD before acting (no invented
  scope); the recut runs **at most once** per pickup (a child MVP that still won't converge is a genuine
  block — no recursive decomposition); and it runs entirely inside the existing front-half loop, so the
  Stop-gate needs no change.

## 0.12.0 — 2026-07-07

- **`/proto` now self-converges on PRD gaps instead of stopping to ask you.** When the preview surfaces
  something the journey needs but the PRD doesn't cover — a dead-end nav item, a missing step or
  outcome screen, a change that grows scope — `/proto` no longer pauses mid-run. It hands the fix to
  `/prd` / `/prd-review`, re-derives the screen list, and loops (up to 3 passes) until coverage closes.
  The reasoning: you can't judge scope in the abstract — without a rendered screen, "is this in scope?"
  is unanswerable. So the **human gate is the finished visual** at approval time, shown with a "PRD
  adjusted this run" changelog of everything the loop changed. If it can't converge in 3 passes, it
  surfaces the genuine product question instead of drifting. `/proto` never edits scope itself — it
  delegates to `/prd`, which owns it.
- **Big design decisions now auto-resolve with senior-designer rigor**, instead of pausing for sign-off.
  A large design-only change the existing design can't cleanly host (nav restructure, a page's layout
  paradigm, a net-new pattern, a cross-screen ripple) is decided in-run — weighing 2–3 options against
  faithfulness to the shipped app, cost, accessibility, and responsive behavior, and recording the
  rationale for you to review at approval. Only a change that alters real **scope** still routes through
  the convergence loop to `/prd`.
- **`/proto` hunts for missing screens with critical thinking + curiosity.** Before freezing its screen
  list, GATE 1 now interrogates the PRD — every acceptance criterion, business rule, branch, error path,
  role, entry/exit, and shell affordance — asking "what screen does this imply that I haven't listed?".
  This closes the hole where the coverage gate (which only checks that *listed* screens were captured)
  was blind to a screen that was never listed — so a thin list passed while the gallery was missing a
  screen.

## 0.11.0 — 2026-07-06

- **`/build` now finishes the job — it converges to a clean `main` on its own.** After every slice is
  green and the e2e suite passes, `/build` runs a new final gate that hands off to `/wrap` in an
  autonomous heal mode: it runs the full Definition-of-Done gate (build, tests, coverage ≥80%,
  dependency CVEs, secrets, migration pairing, SonarQube) and, on any failure, **auto-fixes and
  re-checks instead of stopping** — routing each failing gate to the shallowest skill (`/approved`,
  `/qa`, `sonar-fix-issue`, a dependency bump), the same way it already routes security findings. Once
  green, it commits, pushes your feature branch, removes any worktree, and leaves you on a clean `main`
  with nothing outstanding. You no longer hand-run `/wrap` after a build.
- **New `/wrap --heal` mode.** `/wrap` still fail-stops by default (reports the exact fix and stops).
  Passing `--heal` makes it autonomous: a failing gate is healed and the full gate re-run under a
  3-strike honesty backstop — if the same gate fails the same way ~3 times it stops with
  `BLOCKED: DoD/<gate>` rather than fake-greening. A real secret in the diff always stops for a human
  (an agent can't rotate a leaked credential).
- **Fix: `/wrap` now pushes a feature branch created in place**, not only branches living in a
  worktree — so the common `/build` flow (a `feature/<x>` branch in the primary checkout) is pushed
  before `/wrap` switches you to `main`, instead of being stranded locally.

## 0.10.0 — 2026-07-06

- **New `/git` — a plain-English git front door, so you never need to know git.** Describe what you
  want in normal words ("set up a new repo", "start a feature", "save my work", "I broke my branch",
  "fix this conflict", "undo that", "open a PR") and saki runs the **safe** git operation for you: it
  snapshots state first, picks the safe variant of every command (stash over discard,
  `--force-with-lease` over `--force`, `-d` over `-D`), confirms only genuinely destructive actions,
  then reports back in plain language — no command to type, no conflict marker to hand-edit.
- **Covers the whole lifecycle.** Bootstrap a repo from nothing (`git init` → `.gitignore` → first
  commit; remote + provider login hand off to `/init-env`), plus branch, commit, sync, publish/PR,
  undo, recover (via `reflog`), stash, and inspect. Landing (Definition-of-Done gate → commit → push
  → clean up) still belongs to `/wrap`, which `/git` hands off to rather than duplicating.
- **Conflicts: the mechanical cases auto-resolve; real content clashes are analyzed, proposed, and
  confirmed with one tap** — saki never blind-picks a side (that silently loses work) and you never
  hand-edit a `<<<<<<<` marker.

## 0.9.0 — 2026-07-06

- **`/epic` is replaced by `/add` — a categorizing intake that routes to a PRD *or* a plan.** The old
  `/epic` only ever added epics; `/add` categorizes each incoming item as **Epic · Feature · Improvement ·
  Bug** (auto-proposed, or forced with `--epic`/`--feature`/`--improvement`/`--bug`), stamps a **Type +
  Track** flag, assigns a per-type id (`E`/`F`/`I`/`B<n>`), and records it on the roadmap. The routing rule:
  a new user journey/UI ⇒ **PRD-track** (Epic/Feature → `/pickup` → prd → proto → build); a change/fix to
  existing behavior ⇒ **Plan-track** (Improvement/Bug → straight to `/rplan`, skipping the PRD and proto).
- **BREAKING: `/saki-builder:epic` is removed** (clean rename, no tombstone). Use `/saki-builder:add`.
- **The roadmap now holds typed work items, not just epics.** Both block templates carry `**Type:**` +
  `**Track:**`; Plan-track items get a lean block (`What` / `Repro / Context` / `Child plan`). Legacy
  `## Epics` / `E<n>`-only roadmaps stay valid — they read as `Type: Epic · Track: PRD`.
- **`/pickup` is PRD-track only** — it accepts `E<n>` and `F<n>`, and redirects an `I<n>`/`B<n>` id to
  `/rplan`. The PRD header field `**Epic:**` is generalized to `**Item:**` (holds `E<n>` or `F<n>`).
- **`/prd`, `/proto`, `/build` resolve `E<n>|F<n>`** and use item-neutral wording; `/build` flips the built
  item to `Shipped`. `/pipeline` (tombstone) and `/init-env` point at `/add`.



- **`/prd-review` is autonomous by default — it loops to green instead of a single pass.** A bare
  `/prd-review <prd>` now runs the review core (Step 0 → Phase 4, which still never edits the PRD) inside a
  new **Phase 5** loop: on anything short of green (`Verdict SHIP` AND `Readiness READY`) it applies the
  review's own prescribed fixes to the PRD and re-reviews, until green or a hard blocker
  (`DISCOVERY-FIRST` / structural `NOT READY` / non-convergence), with a hard **3-round cap**. The three
  judges still run as fresh subagents each round, so relocating the fix-apply step here doesn't compromise
  the review's independence. Pass **`--review-only`** for the classic single, non-editing pass.
- **`/pickup` reuses that one loop (option 3) — it no longer keeps its own copy.** Phase 2 now invokes
  autonomous `/prd-review` (without `--review-only`) and branches on its terminal sentinel
  (`PRD_REVIEW_GREEN` → proto-ready; `PRD_REVIEW_BLOCKED` → flip the epic to Blocked). No nesting, no
  double-loop — the loop-to-green runs in exactly one place.
- **New Stop hook `prd-review-completion-gate.sh` keeps the autonomous loop alive across turns**, mirroring
  the hardened `pickup-completion-gate.sh` (phase-driven: block while `reviewing`, release on `green` /
  `blocked` / unknown; progress-aware circuit breaker; session-owned; fail-open; SubagentStop-safe). Keyed
  on `tasks/.prd-review-<slug>-state.json`. Locked by `test-prd-review-completion-gate.sh` (13/13).
- **Why:** the loop-to-green was a `/pickup`-only capability, so a PRD not tied to a roadmap epic couldn't be
  driven to green hands-off. Moving the loop into `/prd-review` and having `/pickup` reuse it gives both
  entry points one implementation — the de-duplicating direction, not a second copy.

## 0.7.0 — 2026-07-05

- **The readiness gate is now evidence-based, not a confidence percentage.** Across the whole pipeline
  (`/rplan`, `/rplan-review`, `/prd`, `/prd-review`, `/build`, `/approved`, `/persona`, plus the injected
  core protocol) the old `Confidence ≥ 90/96%` threshold is replaced by a boolean: **a plan or PRD is
  presentable only when its Blocking Set is empty.** The ledger stays — every blocking item still cites
  `path:line` / grep / step number — but the scalar, the hand-tuned deduction weights, and the threshold
  cliff are gone. A single load-bearing gap (an unverified anchor, a migration named with no creating step)
  can no longer hide behind a high number, and there is no sum to round up. Momentum reads as the blocking
  count falling (5 → 2 → 0). Risk now decides an item's **class** (Blocking vs Advisory), not a multiplier:
  a gap on a HIGH-risk / state-changing step blocks; the same gap on a LOW cosmetic step is Advisory.
- **`/prd`'s self-gate is strict.** Every real defect in the PRD predicate table is Blocking — no tolerance
  sum — keeping `/prd` and `/prd-review` in lockstep on what Phase 1 rejects. The internal `prd-quality: N/100`
  marker becomes `prd-blocking: N`.
- **Why:** a percentage answers *"how complete does this feel?"*; a gate must answer *"is anything
  load-bearing still open?"* The two only agree when nothing critical is broken — exactly the case where the
  old gate could show a green 92% over a fatal gap. The change also removes the five anti-gaming warnings the
  old scalar needed, because a boolean over cited evidence has no dial to turn. Verified with a 7-agent dry
  test: the new gate blocks unverified anchors and strict-PRD defects, passes genuinely-clean artifacts, and
  catches the demote-a-blocker-to-Advisory move the percentage invited.

## 0.6.2 — 2026-07-05

- **`/proto` no longer reinvents components that already exist.** Reuse-first grounding is now mechanically
  enforced: proto can't render until the Reuse Map + Screen Manifest exist **and are correct** — a `NEW`
  classification must be *proven absent* with a grep of the real app (never assumed because a harness didn't
  import it), and no screen may stub an EXISTING component. On resume, the map is re-derived from the real
  app, **never reconstructed from a stale harness** (which silently laundered prior errors forward). This
  closes the drift where the preview showed hand-rolled look-alikes of shipped components under an invented
  brand instead of the real ones.
- **`/build` must promote proto's components, not silently re-pick them.** New **Proto-fidelity gate**
  (per-slice step 3.5 — the inverse of proto's provenance check): a shipped user-facing slice that has a
  proto handoff must import the components proto approved; re-inventing one is a blocking finding, not a
  quiet choice. Gated to user-facing slices with a proto handoff; backend/no-proto slices skip cleanly.

## 0.6.1 — 2026-07-05

- **License: MIT** — added a `LICENSE` file and set `plugin.json` `license` to `MIT` (was `UNLICENSED`,
  which contradicted the open marketplace the plugin already publishes to). saki-builder is now
  permissively open — use, fork, and adapt it, keeping the copyright notice.

## 0.6.0 — 2026-07-05

- **Thin technical contract at PRD stage (`§16`)** — `/prd` now authors a lightweight **Technical Contract
  (§16)**: the load-bearing DB/API/architecture *shape* the slices imply (entities · endpoint purposes ·
  one architecture decision), grounded in the existing Step 0.7 Tier-1 code scan — each row is REUSE
  (cites real code `path:line`) or NEW, and must serve an `8.x · 5.x` slice/outcome (YAGNI). It is *shape,
  not design* — no column names, payloads, or migration files (that stays `/rplan`). Omit-if-none for
  UI-only features. Gate-scored (evidence · YAGNI · altitude).
- **`/prd-review` verifies the contract, no longer just flags gaps** — its technical-surface step now
  VERIFIES §16 (present · cited · slice-coherent · still shape) and raises `REVISE` on a miss, THEN flags
  the residual undefined surfaces it doesn't cover. Still never designs.
- **`/rplan` ingests §16 as the shape to harden** — Step 1 seeds Plan Wiring + schema/endpoint design from
  §16 (a `NEW` row is a create-target, a `REUSE` row an anchor to verify), deepening the shape into full
  columns/structs/migrations rather than re-deriving it. Thin-at-PRD / deep-at-rplan keeps one source of
  truth per depth (no drift).

## 0.5.1 — 2026-07-04

- **`/prd` now pins Opus** — added a Step 0 model switch mirroring `/rplan`, so PRD authoring runs on
  the `opus` alias (no auto-restore; `/rplan` keeps Opus, `/approved` switches to Sonnet). Closes the
  gap where `/prd` inherited whatever session model was active. `/prd-review` and `/rplan-review` stay
  model-agnostic by design (fresh-context second opinion; their work runs in subagents).

## 0.5.0 — 2026-07-04

Epic-anchored workflow, stronger gates, and first marketplace publish.

- **Epic-anchored stepwise workflow** — `/roadmap` → `/epic` → `/pickup E<n>` → `/proto E<n>` →
  `/build E<n>` replaces the retired autonomous `/pipeline`; every feature traces to a roadmap epic.
- **`/rplan-review`** — 8 parallel domain experts + a non-negotiable ≥80% coverage floor.
- **`/prd` + `/prd-review`** — shape-first PRD, strengthened adversarial review, explicit PRD lock at proto.
- **`/wrap`** — now a full Definition-of-Done gate (build · tests · coverage ≥80% · security · migrations ·
  SonarQube) *before* commit/push, then converge-to-clean.
- **Pre-push coverage gate** — `coverage-gate.sh` blocks pushes to the protected branch below 80%.
- **`/reviewer`** — blocking secret-scan gate (Step 1.5) runs before the LLM review.
- **`/proto`** — auto-proceeds at Step 2.5 (no pause; auto-codifies missing tokens/components into the
  real design system at Step 2.6, review backstop at Step 7b); capture hard-gates crashed renders +
  distinctness gate.
- **Published the marketplace to GitLab** — `.claude-plugin/marketplace.json` now lands on `main`, so
  `/plugin marketplace add https://gitlab.com/drayanaindra/saki-builder.git` resolves.

## 0.4.1 — 2026-07-02

Fix — gateway routing tables.

- The `gateway-*` skills routed to `skills/library/…` (wrong base) and to many skills that were
  never built. `bin/fix-gateways.js` rewrote every route for an EXISTING skill to
  `${CLAUDE_PLUGIN_ROOT}/config/skills/<cat>/<skill>/SKILL.md` and dropped 28 dead rows.
- Added 6 existing-but-unrouted library skills (backend health/resilience, security audit, 3 frontend)
  so no real library skill is unreachable. All 27 routes now resolve.
- Validator now guards gateway routes — a route to a missing skill fails the build.

## 0.4.0 — 2026-07-02

Phase 4 — distribution + rebrand.

- **`/saki-builder:update`** skill + **`config/hooks/check-plugin-update.js`** SessionStart nudge
  (pull-based; fail-open; `SAKI_UPDATE_CHECK_DISABLE=1` to silence).
- **`docs/HOW-TO.md`** — teammate onboarding (install, commands, settings merge, learning loop, hooks).
- Rebranded `claude-config` → `saki-builder` across README + skill/hook brand mentions. `rupdate`
  marked legacy (owner symlink-pull); plugin users use `/saki-builder:update`. Remaining
  `claude-config` strings are functional dir paths (the on-disk dir is intentionally not renamed).
- **Not done here (owner-only):** publishing the marketplace to GitLab. Deferred: `gateway-*` library path tables.

## 0.3.0 — 2026-07-02

Phase 3 — split learning loop.

- **Team baseline** (`memory/patterns*.md`, shipped read-only) vs **personal overlay**
  (`~/.claude/memory/patterns-personal.md`, per-machine, injected by `inject-core.js`, never pushed).
- Rewired `/saki-builder:reflect` — routes by audience: personal overlay (instant) vs team baseline (via MR).
- Rewired `/saki-builder:sync` — team-baseline edits share via a branch + MR, never a direct push to `main`;
  personal overlay is never synced.
- `/saki-builder:reviewer` now reads both layers.
- `config/docs/learning-loop.md` documents the model; `.gitignore` guards stray `patterns-personal.md`.
- Fixed 4 namespacing false-positives (`./sync.sh`, `**/prd.md`, `./auth.service`) + hardened the
  `bin/namespace-refs.js` guard against `./ ~/ **/` path contexts.

## 0.2.0 — 2026-07-02

Phase 2 — full migration to the plugin model.

- **Namespaced 319 internal skill references** to `/saki-builder:*` (across 23 skill/agent files)
  via `bin/namespace-refs.js`. External commands (`/code-review`, `/simplify`, `/verify`, `/init`)
  are left bare by design.
- **Shared hooks ported** into `config/hooks/hooks.json` (auto-registered, merge with user hooks):
  `inject-core.js`, `repo-context.sh`, `dangerous-command-guard.sh`, `format-staged.sh`,
  `build-completion-gate.sh`, `pipeline-completion-gate.sh`.
- **Personal hooks documented** as opt-in (not auto-registered): `rtk-rewrite.sh`, `sonar-gate*.sh`,
  `sonar-secrets/`, the macOS notification — see `config/docs/hooks-personal.md`.
- **`templates/settings.recommended.json`** — permissions/model/effort to merge into your own
  settings (a plugin can't ship these).
- Portabilized agent doc-refs to `${CLAUDE_PLUGIN_ROOT}/config/docs/...`.
- Validator: reference-resolution now active (every `/saki-builder:*` must resolve).

## 0.1.0 — 2026-07-02

Phases 0–1 — plugin scaffold, drift guard, global-rules delivery.

- `.claude-plugin/{plugin.json,marketplace.json,saki.mcp.json}` — the plugin points at the existing
  `config/` dirs via `plugin.json` path-override keys (no restructure).
- `test/validate.js` + `.githooks/pre-push` — zero-dependency drift guard.
- `instructions/core.md` + `config/hooks/inject-core.js` — always-on execution protocol delivered by
  a SessionStart hook (a plugin cannot ship a global CLAUDE.md), plus the private patterns overlay.
- Verified via a real `claude plugin install`: 46 skills, 3 agents, SessionStart hook, ~2,277 always-on tokens.
