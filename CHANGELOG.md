# Changelog — saki-builder

All notable changes to the saki-builder plugin. Versions track `.claude-plugin/plugin.json`.

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
