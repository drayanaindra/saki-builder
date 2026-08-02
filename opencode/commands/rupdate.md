---
description: "(Legacy, owner symlink-install only) Pull latest skills/patterns/config from the remote saki-builder repo checkout. For the plugin, use /saki-builder:update instead."
---

# Update saki-builder from Remote (legacy symlink pull — plugin users: /saki-builder:update)

Pull the latest skills, patterns, and config from the remote repo.

## Process

Run:
```bash
cd ~/claude-config && git pull
```

Report the output:
- If already up to date: "Already up to date — no changes."
- If changes pulled: list which files changed (skills, memory, config)
- If conflict: report the conflict and stop — do NOT auto-resolve

## When to use

- After the repo owner pushes new or updated skills
- After `/saki-builder:sync` runs on another machine and you want the latest on this one
- First thing in a new session on a machine that hasn't pulled recently

## Related

- `/saki-builder:sync` — push your learnings to remote (opposite direction)
- After pulling, restart Claude Code to pick up skill changes
