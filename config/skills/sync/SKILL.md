---
name: sync
description: Sync Claude learning data to git repo. Run after /saki-builder:reflect to push updated patterns.md to remote.
---

# Sync Claude Learnings

Commit and push updated `memory/` data to the remote repo.

## Process

Run this command:
```bash
cd ~/claude-config && ./saki-builder:sync.sh
```

Report the output to the user — either "No changes to sync" or the commit + push result.

## When to use

- After `/saki-builder:reflect` updates `memory/patterns.md`
- After a `/saki-builder:retro` with learnings worth sharing
- Before switching to another machine

## Other machines

After syncing, other machines get updates with:
```bash
cd ~/claude-config && git pull
```
