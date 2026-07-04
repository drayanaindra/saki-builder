# Changelog — saki-builder

All notable changes to the saki-builder plugin. Versions track `.claude-plugin/plugin.json`.

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
