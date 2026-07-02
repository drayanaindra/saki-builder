# Changelog — saki-builder

All notable changes to the saki-builder plugin. Versions track `.claude-plugin/plugin.json`.

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
