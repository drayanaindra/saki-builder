---
name: update
description: Update the installed saki-builder plugin to the latest marketplace version. Reports installed vs latest and the exact /plugin upgrade commands. Pull-based — a newer version doesn't reach you until you pull it.
---

# /saketek:update — update the plugin to the latest version

Updating is **pull-based**: a newer version in the marketplace doesn't reach your install until you
pull it. Claude Code keeps the plugin in a **managed cache** it updates via the `/plugin` manager —
so this reports where you stand and gives you the exact commands. A SessionStart hook
(`check-plugin-update.js`) also nudges you when you're behind; this is the on-demand version.

> **Don't assume a git checkout.** The install is usually a managed cache (no `.git`,
> multiple versions side by side). `git` won't work there — that's normal. The supported update is
> `/plugin marketplace update` + `/plugin update` + a session reload.

## Steps

1. **Read the installed version.** `ROOT="${CLAUDE_PLUGIN_ROOT}"`. If `${ROOT}/.claude-plugin/plugin.json`
   is missing, you can't determine the install — say so and give the `/plugin` path (step 3). Else read its `version`.

2. **Detect install type quietly.** `git -C "$ROOT" rev-parse --is-inside-work-tree 2>/dev/null`:
   - **Not a git checkout** (the normal managed-cache case) → skip git, go to step 3.
   - **A git checkout** (owner dev) → `git -C "$ROOT" fetch --quiet origin` then compare
     `git -C "$ROOT" show origin/HEAD:.claude-plugin/plugin.json | grep version`; if behind,
     `git -C "$ROOT" merge --ff-only origin/HEAD`, then the reload note.

3. **Update via the `/plugin` manager** (the supported path for the managed cache):
   ```
   /plugin marketplace update saki-builder
   /plugin update saketek@saki-builder
   ```
   It's a no-op if already current, so it's safe to run regardless. Best-effort latest check: if
   `GITLAB_TOKEN` is set, run `node "${ROOT}/config/hooks/check-plugin-update.js"` to confirm
   behind/current; otherwise say you couldn't confirm the remote latest — **never claim "up to date"
   you couldn't verify.**
   - **⚠ Reload to take effect.** Commands load at session start, so after `/plugin update` start a new session.

## Guardrails

- Don't leak a `fatal: not a git repository` — a non-git install is the normal case, not an error.
- Never claim "up to date" you couldn't verify (no git fetch + no `GITLAB_TOKEN` → say "couldn't confirm").
- Use the marketplace/plugin names `saki-builder` / `saketek@saki-builder`.

> The legacy `/saketek:rupdate` pulls a symlink-install repo (owner-only). For the plugin, this is the path.
