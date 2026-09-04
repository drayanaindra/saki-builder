---
name: sync
description: Sync saki-builder TEAM-BASELINE changes (memory/patterns + skills/hooks) to the repo via a review MR. Your personal overlay is never synced. Run after /saki-builder:reflect promotes something to the team baseline.
---

# Sync saki-builder team baseline

Commit and share changes to the **team baseline** — the shared, curated layer everyone reads:
`memory/patterns*.md`, `config/skills/`, `skill://saki-builder-runtime/hooks/`, `instructions/core.md`.

**Never synced:** your personal overlay `~/.omp/agent/memory/patterns-personal.md` lives on your
machine, not in the repo — nothing to sync, and it can never conflict with a teammate.

## Process (you must have the saki-builder repo checked out)

Team-baseline changes go through **review**, not a direct push to `main`:

```bash
cd <saki-builder-repo>
git checkout -b learnings/$(date +%Y%m%d)-<short-topic>   # a branch, not main
git add memory/ config/ instructions/            # explicit paths — never git add -A in a shared repo
git commit -m "learnings: <one-line what you promoted>"
git push -u origin HEAD
```

Then open an MR/PR for the branch. That review is the governance gate that keeps the shared
baseline curated (the split's whole point — one reviewer's noise doesn't land unreviewed).

> The legacy `./sync.sh` helper (owner-only, single-machine) still exists but pushes directly —
> use the branch + MR flow above on a team.

## When to use

- After `/saki-builder:reflect` promotes a pattern to the **team baseline** (not for personal-overlay writes)
- After editing a shipped skill/hook/`instructions/core.md` that everyone should get
- Before publishing a new plugin version (bump `.claude-plugin/plugin.json` + `CHANGELOG.md` first; the validator + pre-push hook gate the push)

## Getting others' updates

Teammates pull team-baseline updates by updating the plugin, not by cloning:

```
/plugin marketplace update saketek && /plugin update saki-builder@saketek
```

(Then start a new session so the updated skills load. The owner working from a checkout uses `git pull`.)
