---
name: rupdate
description: Pull latest skills, patterns, and config from the remote claude-config repo. Run when you want to sync updates from another machine or after the repo owner pushes new skills.
---

# Update Claude Config from Remote

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
- After `/sync` runs on another machine and you want the latest on this one
- First thing in a new session on a machine that hasn't pulled recently

## Related

- `/sync` — push your learnings to remote (opposite direction)
- After pulling, restart Claude Code to pick up skill changes
