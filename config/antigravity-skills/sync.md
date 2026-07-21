---
name: sync
description: Sync Claude learning data to git repo. Run after /reflect to push updated patterns.md to remote.
---

# Sync Claude Learnings

Commit and push updated `memory/` data to the remote repo.

## Process

Run this command:
```bash
cd ~/claude-config && ./sync.sh
```

Report the output to the user — either "No changes to sync" or the commit + push result.

## When to use

- After `/reflect` updates `memory/patterns.md`
- After a `/retro` with learnings worth sharing
- Before switching to another machine

## Other machines

After syncing, other machines get updates with:
```bash
cd ~/claude-config && git pull
```
