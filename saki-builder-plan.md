# EXECUTION PLAN: Convert claude-config → `saki-builder` team plugin + marketplace

**Date:** 2026-07-02
**Confidence:** 92%
**Risk Score:** MED (large restructure; fully reversible — git-tracked config, no prod/DB/auth)
**Unknown Count:** 1 / 2 max
**Behavior Spec:** N/A (developer-tooling; no app UI — verification is command-invocation + hook-fire, captured in Success Criteria)
**Source PRD:** N/A (standalone `/rplan`)
**Appetite:** LARGE — intentionally recut into 5 independently-shippable phases (0→4). Each phase verifies before the next.
**Kill-if:** Phase 0 spike shows the plugin model can't deliver namespaced skills + always-on global rules together → fall back to "personal-skills-install script" distribution (documented in Branch Points).

## Problem Statement

When my personal `claude-config` (52 skills, 25 agents, 11 hooks, a global execution protocol, and a learning loop) is valuable to my team, I want to repackage it as a Claude Code **plugin + marketplace** named **`saki-builder`** — so teammates install it with `/plugin marketplace add` + `/plugin install` (no clone/symlink), everyone shares the identical vetted toolkit, the learning loop splits into a PR-reviewed **team baseline** + a private **personal overlay**, and it **complements ed-harness** (which owns team coordination) rather than overlapping it — while my own editable repo keeps working.

---

## Concrete Example Output

**Today (owner-only, clone + symlink):**
```
$ git clone <repo> && ./install.sh            # symlinks ~/.claude/{skills,agents,hooks}
> /rplan add batch tracking                    # bare invocation, owner's machine only
```

**After (any teammate, zero clone):**
```
> /plugin marketplace add https://gitlab.solveeducation.org/solveed/saki-builder.git
> /plugin install saki-builder@saki-builder
> /saki-builder:rplan add batch tracking       # namespaced, works on every teammate's machine
```
— and on session start, the teammate's context already carries the always-on core rules
(Execution Protocol, Confidence Gate ≥90%, Risk Tiers, Response Header, Next-Actions block)
injected by a SessionStart hook, WITHOUT any teammate editing a CLAUDE.md.

**Learning loop, after:**
```
memory/patterns.md              (in plugin, read-only) → TEAM BASELINE, changed only via MR review
~/.claude/memory/patterns-personal.md (each teammate's machine) → PRIVATE overlay, never pushed
```
`/saki-builder:reflect` writes durable cross-person lessons to the team baseline (as an MR);
personal/experimental notes go to the private overlay. No two teammates ever conflict on one line.

**Owner, after:** installs saki-builder from a LOCAL-path marketplace pointing at the live repo
(`/plugin marketplace add /Users/indrayana/claude-config`), so edits flow on `/plugin marketplace update`
+ reload — same namespaced experience as the team, from an editable checkout. Legacy `install.sh` kept as deprecated fallback.

---

## Steps

Phases are ordered; each is a committable, verifiable slice. Steps within a phase are the atomic units.

### Phase 0 — Spike + scaffold + drift guard (LOW risk, non-destructive; resolves the one unknown)

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 0.1 | **SPIKE (timeboxed):** build a 2-skill throwaway test plugin (`skill-a` references `/skill-b` bare) under `scratch/saki-spike/`, `/plugin marketplace add` it locally, install, and observe whether the bare `/skill-b` ref inside `skill-a` resolves to `/saki-spike:skill-b`. Record verdict → resolves Unknown #1. | `scratch/saki-spike/.claude-plugin/plugin.json`, `scratch/saki-spike/skills/skill-a/SKILL.md`, `scratch/saki-spike/skills/skill-b/SKILL.md` | MED | manual: install + invoke `/saki-spike:skill-a`, confirm it can reach skill-b | Yes (delete scratch after) |
| 0.2 | Create plugin manifest: `name: "saki-builder"`, `version: "0.1.0"`, `mcpServers` → empty pointer (mirror ed-harness) | `.claude-plugin/plugin.json` | LOW | `node -e "JSON.parse(require('fs').readFileSync('.claude-plugin/plugin.json'))"` | Yes |
| 0.3 | Create marketplace manifest: marketplace `name: "saki-builder"`, one plugin entry `source: "./"`, `defaultEnabled: true` | `.claude-plugin/marketplace.json` | LOW | JSON parse | Yes |
| 0.4 | Write the **config validator** (zero-dep Node, mirrors ed-harness `test/validate.js`): parse all `plugin.json`/`marketplace.json`/`hooks.json`; every `skills/*/SKILL.md` + `agents/*.md` has valid frontmatter; every `/saki-builder:<name>` reference resolves to a real skill/command/agent; version sync (`plugin.json` ↔ `CHANGELOG.md`); the rename/prefix invariant (no stray `claude-config`) | `test/validate.js`, `package.json` (add `"test": "node test/validate.js"`) | LOW | `node test/validate.js` exits 0 | Yes |
| 0.5 | Wire the drift guard: pre-push hook runs the validator | `.githooks/pre-push`, README note to run `git config core.hooksPath .githooks` | LOW | `bash .githooks/pre-push` on a dirty ref | Yes |

**Phase 0 gate:** validator green + spike verdict recorded in this plan's Unknowns section. Then choose Phase-2 ref strategy (namespace-all vs keep-bare).

### Phase 1 — Thin vertical slice: prove the plugin end-to-end (MED risk)

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 1.1 | Restructure to root-level plugin dirs (ed-harness convention): `git mv config/skills skills`, `git mv config/agents agents`, `git mv config/hooks hooks`, `git mv config/docs docs` | repo root | MED | `ls skills agents hooks docs` | Yes (atomic with 1.2) |
| 1.2 | Update `install.sh` symlink sources (`config/skills`→`skills`, etc.) so the LEGACY owner path still works | `install.sh` | MED | `./install.sh` on a scratch `HOME`, verify symlinks resolve | Yes |
| 1.3 | Extract the always-on global rules from `config/CLAUDE.md` into a MINIMAL core (~40 lines: rules 1–6, Response Header, Confidence Gate, Risk Tiers, Next-Actions, Secrets). Keep detail (clean-code, xp, execution-protocol-detail) as on-demand `docs/` | `instructions/core.md` | LOW | read-back | Yes |
| 1.4 | Write SessionStart hook that emits `{"additionalContext": <instructions/core.md + optional ~/.claude/memory/patterns-personal.md if present>}` — this is how the plugin delivers always-on global rules (verified: plugins can't ship a CLAUDE.md) | `hooks/inject-core.js` | MED | run node hook, assert JSON has `additionalContext` containing "Execution Protocol" | Yes |
| 1.5 | Create `hooks/hooks.json` registering `inject-core.js` on SessionStart using `${CLAUDE_PLUGIN_ROOT}` | `hooks/hooks.json` | LOW | JSON parse + validator | Yes |
| 1.6 | Migrate 5 core skills as the proof set, applying the Phase-0 ref decision: `rplan`, `approved`, `qa`, `reviewer`, `wrap`. Fix their internal `~/.claude/...` path refs → relative/`${CLAUDE_PLUGIN_ROOT}` (rplan `template.md`, qa `playwright-patterns.md`) | `skills/{rplan,approved,qa,reviewer,wrap}/SKILL.md` | MED | validator + manual invoke `/saki-builder:rplan` | Yes |
| 1.7 | Owner installs from LOCAL-path marketplace and verifies the loop | (no file) `/plugin marketplace add /Users/indrayana/claude-config` → `/plugin install saki-builder@saki-builder` | MED | `/saki-builder:rplan` runs; new session shows core rules present | Yes |

**Phase 1 gate:** a fresh session with the plugin installed can run `/saki-builder:rplan`, the core rules are in context, and `node test/validate.js` is green.

### Phase 2 — Full component migration (MED risk, mechanical)

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 2.1 | Migrate remaining 47 skills into `skills/` (already moved by 1.1; this step is the ref + path fixes) | `skills/*/SKILL.md` | MED | validator | Yes |
| 2.2 | Apply Phase-0 ref decision across ALL skills/agents: if spike says bare doesn't resolve → run the namespacing script (ed-harness pattern) rewriting bare `/rplan`→`/saki-builder:rplan` for the ~380 internal refs; else leave bare + add validator note | `skills/*/SKILL.md`, `agents/*.md` (script: `bin/namespace-refs.js`) | MED | validator's reference-resolution check passes | Yes |
| 2.3 | Fix internal `~/.claude/...` refs in skill bodies (reflect 7, init-env 6, qa 3, reviewer 2, rplan 1) to plugin-portable form | `skills/{reflect,init-env,qa,reviewer,rplan}/SKILL.md` | MED | grep shows 0 `~/.claude/skills\|docs` in skill bodies | Yes |
| 2.4 | Triage & port hooks. **Shareable → `hooks/hooks.json`:** `dangerous-command-guard`, `build-completion-gate`, `pipeline-completion-gate`, `format-staged`, `repo-context`. **Personal/env-specific → `templates/personal-hooks/` + docs (NOT auto-registered):** `rtk-rewrite` (RTK), `sonar-gate`+`sonar-gate-init`+`sonar-secrets/` (SonarQube+`~/.sonar` creds), macOS `osascript` notification | `hooks/hooks.json`, `templates/personal-hooks/`, `docs/hooks-personal.md` | MED | validator + each shared hook fires without env deps | Yes |
| 2.5 | Convert `config/settings.json` → `templates/settings.recommended.json` (permissions/model/env can't ship in a plugin — verified). Document the merge in onboarding | `templates/settings.recommended.json`, `docs/HOW-TO.md` | LOW | JSON parse | Yes |
| 2.6 | Update `plugin.json` version → `0.2.0`; add `CHANGELOG.md` entry | `.claude-plugin/plugin.json`, `CHANGELOG.md` | LOW | validator version-sync | Yes |

**Phase 2 gate:** all 52 skills + 25 agents resolve under validator; shared hooks fire clean; no `claude-config` / stray-path leakage.

### Phase 3 — Learnings split: team baseline + personal overlay (MED risk)

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 3.1 | Keep `memory/patterns*.md` in the plugin as the **read-only TEAM BASELINE** | `memory/patterns.md`, `memory/patterns-*.md` | LOW | present | Yes |
| 3.2 | Define the **personal overlay** contract: `~/.claude/memory/patterns-personal.md` (per machine, gitignored, never in plugin). `inject-core.js` (1.4) already appends it if present | `docs/learning-loop.md`, `.gitignore` (confirm overlay path ignored) | LOW | overlay file read by hook when present, skipped when absent | Yes |
| 3.3 | Rewire `/saki-builder:reflect`: durable cross-person lessons → team baseline **as an MR** (not a direct push); personal/experimental → the private overlay. Replace the "everyone pushes `memory/`" model | `skills/reflect/SKILL.md` | MED | reflect writes to correct target per lesson class | Yes |
| 3.4 | Rewire `/saki-builder:sync`: stop pushing `memory/` for everyone; sync only owns team-baseline changes via MR; personal overlay never synced | `skills/sync/SKILL.md`, `sync.sh` | MED | sync no longer stages `~/.claude/memory/patterns-personal.md` | Yes |

**Phase 3 gate:** a teammate's personal notes stay local; a promoted team lesson lands via reviewable MR; no shared-line conflicts.

### Phase 4 — Distribution polish + publish (MED risk)

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 4.1 | Add `/saki-builder:update` command (mirror ed-harness `commands/update.md`): report installed vs latest, give exact `/plugin` update commands, session-reload note | `commands/update.md` | LOW | `/saki-builder:update --check` | Yes |
| 4.2 | Add SessionStart `check-plugin-update.js` (mirror ed-harness): fail-open nudge when behind (GitLab raw plugin.json API) | `hooks/check-plugin-update.js`, `hooks/hooks.json` | LOW | run with stubbed API | Yes |
| 4.3 | Rename `claude-config` → `saki-builder` across the 47 doc/script refs; portabilize `/Users/indrayana` machine paths in templates | `README.md`, `install.sh`, `get.sh`, `sync.sh`, `build-opencode.sh`, `skills/{reviewer,init-env,qa,rupdate,reflect,sync}/SKILL.md` | MED | `grep -riE 'claude[- ]config'` → 0 (excluding archived plan-history) | Yes |
| 4.4 | Write teammate onboarding (`docs/HOW-TO.md`): install, namespaced commands, settings merge, personal overlay, personal-hooks opt-in | `docs/HOW-TO.md` | LOW | read-through | Yes |
| 4.5 | Push marketplace to GitLab (`solveed/saki-builder`); add to `extraKnownMarketplaces`; a teammate does a clean install to verify | GitLab remote + a teammate machine | MED | teammate `/plugin install` + `/saki-builder:rplan` works | Yes |

---

## User Role Coverage

| Role | Can Do | Cannot Do | "Auth Guard" (gate) | Entry Point |
|------|--------|-----------|---------------------|-------------|
| **Owner (you)** | develop in the repo; install via local-path marketplace; publish new versions; approve team-baseline MRs | — | pre-push validator; MR review on `memory/patterns*.md` | live git checkout + `/plugin marketplace add <local path>` |
| **Teammate** | install/update via git-URL marketplace; use all `/saki-builder:*` commands; keep a private overlay; propose team-baseline lessons via MR | edit shipped plugin files locally (managed cache is read-only); push to `memory/` directly | plugin is read-only cache; team-baseline changes require MR | `/plugin marketplace add <gitlab-url>` + `/plugin install` |
| **Contributor** | open MRs to add/change skills/agents/hooks | merge without validator green | `.gitlab-ci.yml validate-config` job + pre-push hook | fork/branch + MR |

---

## Component Migration Map (this task's "wiring" — replaces API/DB/Frontend sections)

**REVISED post-spike (2026-07-02): `plugin.json` path-override keys let the plugin load from the EXISTING `config/` layout — NO restructure, owner symlinks + `install.sh` untouched.** Proven: a skill under `config/skills/` loaded as `/spike2:nested-skill` via `"skills": ["./config/skills"]`.
```
config/skills/*/SKILL.md   → STAYS PUT; plugin.json "skills":["./config/skills"]  (invoked /saki-builder:<name>)
config/agents/*.md         → STAYS PUT; plugin.json "agents":["./config/agents"]  (verify in Phase 1; personal/project agents override same-named plugin agents)
config/hooks/*.sh (shared) → registered via config/hooks/hooks.json + plugin.json "hooks" (Phase 2.4; ${CLAUDE_PLUGIN_ROOT}, MERGE with user hooks)
config/hooks/*.sh (personal)→ templates/personal-hooks/ + docs  (opt-in; NOT auto-registered)
config/CLAUDE.md (core)    → instructions/core.md      (delivered by SessionStart config/hooks/inject-core.js → additionalContext)
config/CLAUDE.md (detail)  → config/docs/*.md          (on-demand, referenced by skills; stays put)
config/settings.json       → templates/settings.recommended.json  (plugin can't ship permissions/env/model — merge documented)
memory/patterns*.md        → memory/patterns*.md        (TEAM BASELINE, read-only in plugin)
(new)                      → ~/.claude/memory/patterns-personal.md  (PERSONAL overlay, per machine, gitignored)
(new)                      → .claude-plugin/{plugin.json,marketplace.json}, test/validate.js, .githooks/pre-push
```
— adjusted in impl: path-override spike removed the need to move dirs; Phase 1.1/1.2 (git mv + install.sh symlink rewrite) are now NO-OPs, replaced by plugin.json path keys.

**Verified plugin facts driving this map** (empirical, from ed-harness + docs):
- Plugin skills/commands are **namespaced** `/<plugin>:<name>` (ed-harness: 700+ `/ed-harness:*` internal refs).
- A plugin **cannot** ship an always-on `CLAUDE.md` (ed-harness `init.md:16`); SessionStart `additionalContext` is the delivery path.
- Plugin `hooks/hooks.json` **merges** with user hooks; `${CLAUDE_PLUGIN_ROOT}` resolves to the install dir.
- Plugin `settings.json` supports only `agent`/`subagentStatusLine` — **not** permissions/env/model.
- Personal/project `.claude/agents/` **override** same-named plugin agents (docs migration guide).
- Install target is a **read-only managed cache** (no `.git`); update = `/plugin marketplace update` + `/plugin update` + reload.

---

## Branch Points (pre-declared)

- **Step 0.1 (spike result) — RESOLVED → "don't resolve" branch taken:** spike proved invocation is namespaced (`/saki-spike:skill-a`), so run `bin/namespace-refs.js` (Step 2.2) to rewrite the ~380 refs to `/saki-builder:*`; the legacy symlink path loses bare cross-ref resolution (deprecated; plugin is primary).
- **Kill fallback:** If Phase 0 proves the plugin model can't deliver namespaced skills + always-on rules acceptably (e.g. `additionalContext` token cost is prohibitive) → PAUSE and switch distribution to a **personal-skills install script** (a `get.sh` that writes into each teammate's `~/.claude/skills` — bare invocation, no namespacing) and drop the marketplace path. Report to user before proceeding.
- **Step 1.1 (restructure):** work on branch `feat/saki-builder-plugin`; do NOT touch `main` symlink workflow until Phase 4. If `./install.sh` breaks on the scratch HOME test → fix before merging 1.1/1.2.
- **Step 4.5 (publish):** PAUSE for human — creating/pushing the GitLab `saki-builder` marketplace repo is owner-only.

---

## Unknowns (must be <= 2)

1. ~~**[MED] Within-plugin bare-reference resolution.**~~ **RESOLVED (Phase-0 spike, 2026-07-02).** Built a throwaway 2-skill plugin, loaded it with `claude --plugin-dir`, and enumerated its commands: they appear **namespaced by `plugin.json` name** — `/saki-spike:skill-a`, `/saki-spike:skill-b`. Bare invocation is not the plugin model. **Verdict → namespace-all:** all ~380 internal cross-refs get rewritten to `/saki-builder:<name>` (Step 2.2 script required); the owner's legacy symlink path (bare) is therefore deprecated in favor of the local-marketplace install (already the plan's owner path). Validator enforces the prefix invariant.

*(Resolved-by-decision, not carried as unknowns: plugin dir layout — decided to use root-level `skills/agents/hooks` per ed-harness convention rather than depend on undocumented path-override keys; global-instruction delivery — decided on SessionStart `additionalContext` from a minimal `instructions/core.md`; global-rule token cost — decided to inject a ~40-line core, keep detail on-demand.)*

---

## No-Gos

- Will NOT add team-coordination features (ownership locks, shared tracker sync, intake, claim-gate) — those are ed-harness's; saki-builder stays a personal-scale shared toolkit (locked decision #2).
- Will NOT break the owner's working setup on `main` mid-migration — all work on a branch; `install.sh` kept functional through Phase 3, deprecated (not deleted) in Phase 4.
- Will NOT ship personal/env-specific hooks (RTK, SonarQube, macOS notification) as auto-registered plugin hooks — they go to `templates/personal-hooks/` as opt-in.
- Will NOT push each teammate's learnings to a shared file — personal overlay is local-only (locked decision #3).
- Will NOT overwrite any teammate's existing `~/.claude/CLAUDE.md` or `settings.json` — global rules arrive via the SessionStart hook, settings via a documented merge.
- Will NOT rename the repo directory `/Users/indrayana/claude-config` on disk in this plan (out of scope; the *plugin/marketplace* is named `saki-builder`; dir rename is a separate optional step).

---

## Implementation Completeness Checklist

**Role Coverage**
- [x] Every role that touches this (Owner / Teammate / Contributor) is in the Role Coverage matrix
- [x] Each role has its gate + entry point named
- [x] Read-only-cache + MR-gate constraints documented per role
- [x] Edge cases: owner local-marketplace, teammate clean install, contributor MR

**Database & Migrations**
- [x] N/A — no database. (This is config packaging; the "migration" is a file-layout restructure, captured in the Component Migration Map + Phase 1.1.)

**API Layer**
- [x] N/A — no HTTP API. Verified-fact table replaces schema wiring.

**Service / Business Logic**
- [x] Every new script named with path (`test/validate.js`, `hooks/inject-core.js`, `bin/namespace-refs.js`, `hooks/check-plugin-update.js`)
- [x] Side effects listed (SessionStart context injection; pre-push validation; MR on team baseline)
- [x] Failure paths: hooks fail-open (never block a session); validator exits non-zero to block push

**Frontend**
- [x] N/A — no UI. Verification is command-invocation + hook-fire (Success Criteria).

**Wiring**
- [x] Every migration mapping written out (Component Migration Map)
- [x] No vague verbs — each step names the exact file + action
- [x] Every verified plugin fact cited to source (ed-harness path or docs)

---

## Confidence Ledger

| Δ | Step | Reason | Evidence |
|---|------|--------|----------|
| ~~-5~~ 0 | 2.2 | ~~Unknown #1 unresolved~~ **RESOLVED** via Phase-0 spike: namespacing confirmed, namespace-all strategy locked | spike: `claude --plugin-dir scratch/saki-spike -p` → enumerated `/saki-spike:skill-a`, `/saki-spike:skill-b` |
| -3 | 0.4 | Validator's exact invariant set for `saki-builder` is designed but not yet proven against the real tree (ed-harness has one; ours is new) | `test/validate.js` does not exist yet (target, Step 0.4) |

**Rules applied:** Unknown #1 resolved (spike) → −5 removed; validator-newness is LOW (×1) −3, tied to 0.4 (clears when the validator runs green in Step 0.4).

**Score: 100 − 3 = 97%** *(updated post-spike)*

---

## Success Criteria

- [ ] **Scaffold parses:** `node -e "['plugin','marketplace'].forEach(f=>JSON.parse(require('fs').readFileSync('.claude-plugin/'+f+'.json')))"` exits 0 → `[auto]`
- [ ] **Validator green:** `node test/validate.js` exits 0 with all skills/agents/refs resolving → `[auto]`
- [ ] **Spike verdict recorded:** Unknown #1 resolved in this file with the empirical result → `[manual]`
- [ ] **Namespaced invocation works:** in a fresh session with the plugin installed, `/saki-builder:rplan` launches the rplan skill → `[manual]` (Playwright can't test the Claude REPL; verify by invocation)
- [ ] **Global rules load:** a new session's context contains "Execution Protocol" / "Confidence Gate" text injected by `hooks/inject-core.js` → `[manual]`: start session, confirm the header/rules are honored
- [ ] **Shared hooks fire clean with no env deps:** `dangerous-command-guard`, `build-completion-gate`, `pipeline-completion-gate`, `format-staged`, `repo-context` run without SonarQube/RTK present → `[auto]`: invoke each hook script directly, assert exit 0
- [ ] **Personal overlay is private + optional:** with `~/.claude/memory/patterns-personal.md` present it's injected; absent, the hook still succeeds → `[auto]`: run `inject-core.js` both ways
- [ ] **No leakage:** `grep -riE 'claude[- ]config' README.md install.sh skills/ agents/` (excluding `docs/plan-history/archive`) returns 0 → `[auto]`
- [ ] **Legacy owner path still works through Phase 3:** `./install.sh` on a scratch `HOME` produces resolvable symlinks → `[auto]`
- [ ] **Teammate clean install (Phase 4):** on a second machine, `/plugin marketplace add <gitlab-url>` + `/plugin install saki-builder@saki-builder` + `/saki-builder:rplan` succeeds → `[manual]`
- [ ] **Owner-baseline MR gate:** a change to `memory/patterns.md` is blocked from direct push and requires an MR → `[manual]`

---

## Annotation Space

> Human: add notes, corrections, constraints here.
> Open questions for you: (a) OK to run the Phase-0 spike now (non-destructive, deleted after)? (b) Confirm plugin+marketplace name `saki-builder` (marketplace slug + plugin id identical, like ed-harness)? (c) Rename the on-disk repo dir too, or keep `claude-config/` and only brand the plugin `saki-builder`?

---
Status: [x] Draft  [ ] Annotated  [x] Approved  [x] In Progress  [ ] Complete
Confidence Gate: [x] Confidence Ledger present and every entry cited  [x] All checklist items checked (N/A justified)  [x] Confidence >= 96% (97% post-spike)  [x] Unknowns <= 2 (0 remaining)

## Progress log
- **2026-07-02 — Phase 0 COMPLETE** (commit `c7e3e87`, branch `feat/saki-builder-plugin`). Spikes resolved all mechanics unknowns; scaffold + validator (73 skills / 3 agents green) + pre-push guard landed. Phase 1.1/1.2 (restructure) downgraded to NO-OP by the path-override finding.
- **2026-07-02 — Phase 1 COMPLETE.** Verified end-to-end via a real `claude plugin install` from the local marketplace:
  - **Skills (46)** load namespaced `/saki-builder:*` (inventory-confirmed). The 27 nested library skills correctly do NOT register as slash commands (they're `user-invocable:false` gateway docs — Phase 2 path-fix).
  - **Agents (3)** load at runtime as `saki-builder:{product-engineer,qa,senior-pm}`. **Finding:** the manifest `agents` key needs explicit **file paths** (`["./config/agents/x.md", …]`), not a dir — a dir path fails schema validation (`agents: Invalid input`). `claude plugin details` cosmetically miscounts path-override agents as 0, but they load (runtime-verified).
  - **Hook (1)** `inject-core.js` fires on SessionStart, injecting `instructions/core.md` + personal overlay — **always-on cost ~2,277 tok** (confirmed `CONF=90%` reaches the model). Team-baseline patterns deliberately deferred to Phase 3 (don't broadcast raw personal patterns).
  - Restructure (1.1/1.2) confirmed unnecessary (path-override). Core-skill sibling refs (rplan `template.md`, qa `playwright-patterns.md`) portabilized to `${CLAUDE_PLUGIN_ROOT}/…`.
  - Validator hardened to handle agents-as-file-paths + hooks.json; green at 73 skills / 3 agents.
- **2026-07-02 — Phase 2 COMPLETE** (v0.2.0). Verified via real install: 46 skills, 3 hook events, ~2,422 always-on tok.
  - **319 internal refs namespaced** → `/saki-builder:*` (`bin/namespace-refs.js`, guarded regex; externals left bare). Validator now resolves every ref.
  - **6 shared hooks** registered in `config/hooks/hooks.json` (inject-core, repo-context, dangerous-command-guard, format-staged, build/pipeline-completion-gate). Personal hooks (rtk, sonar*, macOS notify) documented opt-in in `config/docs/hooks-personal.md` (shipped-but-unregistered; not moved, to keep the owner's symlinked settings working).
  - `templates/settings.recommended.json` (permissions/model/effort — plugin can't ship these). Agent doc-refs → `${CLAUDE_PLUGIN_ROOT}/...`. `CHANGELOG.md` added.
  - **⚠ Entanglement noted:** the Phase-2 commit also bundles pre-existing owner WIP in 4 skill files (`prd`, `prd-review`, `proto`, `rplan-review` — a "Basis column" content edit) because the namespacing sweep touched the same files; can be split out later.
  - **⏭ Deferred:** learnings-related `~/.claude/memory/patterns` refs (reflect, reviewer) → Phase 3. `gateway-*` path table refs (`skills/library/...` — pre-existing wrong paths, need investigation) → Phase 3/follow-up.
- **Next: Phase 3** — learnings split (team baseline `memory/` read-only + `~/.claude/memory/patterns-personal.md` overlay); rewire `/saki-builder:reflect` + `/saki-builder:sync`; fix the deferred memory refs.
