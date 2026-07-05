# Changelog — saki-builder

All notable changes to the saki-builder plugin. Versions track `.claude-plugin/plugin.json`.

## 0.8.0 — 2026-07-05

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
