# personal/

This directory is for **your own customizations** — things that shouldn't be in the shared repo (personal tools, credentials, machine-specific hooks).

This directory is gitignored by default. Add your own files here freely.

## What to put here

| File | Purpose |
|------|---------|
| `RTK.md` | RTK token-optimizer config (if you use RTK) |
| `hooks/rtk-rewrite.sh` | RTK PreToolUse hook |
| `settings-personal.json` | Extra hooks/settings merged into your local ~/.claude/settings.json |
| `patterns-personal.md` | Patterns too project-specific to share globally |

## How to load personal config

Add to your `~/.claude/CLAUDE.md` after install:
```
@~/claude-config/personal/RTK.md
```

Or for personal hooks, add them to `~/.claude/settings.local.json` (already gitignored).

## RTK setup example

If you use RTK (Rust Token Killer):

1. Copy `RTK.md` to this directory
2. Add `@~/claude-config/personal/RTK.md` to your `~/.claude/CLAUDE.md`
3. Add `rtk-rewrite.sh` hook to `~/.claude/settings.local.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [{
         "matcher": "Bash",
         "hooks": [{"type": "command", "command": "/Users/YOU/.claude/hooks/rtk-rewrite.sh"}]
       }]
     }
   }
   ```
