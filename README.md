# claude-config

Personal Claude Code configuration — installable, with centralized learning data.

## What's Inside

```
config/                  # Static config (install once)
├── CLAUDE.md            # Global instructions & execution protocol
├── RTK.md               # RTK token-optimizer config
├── settings.json        # Global hooks (RTK rewrite, notifications)
├── docs/
│   ├── execution-protocol.md   # RESEARCH > PLAN > EXECUTE > VERIFY workflow
│   └── plan-template.md        # Structured plan format with confidence scoring
├── skills/
│   ├── engineer.md, architect.md, product.md, ...  (17 role skills)
│   ├── plan/SKILL.md    # /plan command — structured planning
│   ├── retro/SKILL.md   # /retro command — session retrospective
│   ├── reflect/SKILL.md # /reflect command — cross-project pattern promotion
│   └── init-env/SKILL.md# /init-env command — scaffold new project
└── hooks/
    └── rtk-rewrite.sh   # PreToolUse hook for RTK token savings

memory/                  # Dynamic learning data (updated by /reflect)
├── patterns.md          # Confirmed cross-project patterns (auto-updated)
├── rag-research.md      # RAG best practices research
└── agent-architecture-research.md
```

## Install on a New Machine

```bash
curl -fsSL https://gitlab.com/drayanaindra/claude-config/-/raw/main/get.sh | bash
```

That's it. The script will:
1. Clone this repo to `~/claude-config/`
2. Back up any existing `~/.claude/` files
3. Symlink `~/.claude/` dirs into the repo
4. Print next steps

After install, restart Claude Code:
```bash
claude
```

> **Manual install** (if you prefer):
> ```bash
> git clone git@gitlab.com:drayanaindra/claude-config.git ~/claude-config
> chmod +x ~/claude-config/*.sh && ~/claude-config/install.sh
> ```

## Keep Learnings in Sync

After running `/reflect` in Claude Code (weekly recommended):

```bash
cd ~/claude-config
./sync.sh       # commits memory/ changes and pushes
```

On other machines, get the latest learnings:
```bash
cd ~/claude-config
git pull
```

Since `~/.claude/memory/` is a symlink to `~/claude-config/memory/`, the pull
immediately makes new patterns available to Claude Code.

## Uninstall

```bash
cd ~/claude-config
./uninstall.sh  # removes symlinks, restores from backup if available
```

## Workflow

| Tool | What it does |
|------|-------------|
| `/plan` | Create structured execution plan with confidence scoring |
| `/retro` | Session retrospective — captures corrections, discoveries, patterns |
| `/reflect` | Promotes confirmed patterns to `memory/patterns.md` (run weekly) |
| `/init-env` | Scaffold `.claude/` config for a new project |

## Execution Protocol

Every non-trivial task follows:

```
RESEARCH → PLAN → ANNOTATE → EXECUTE → VERIFY → LEARN
```

Full protocol: `config/docs/execution-protocol.md`

Key rules:
- Never implement without a plan for 2+ file changes
- Confidence ≥ 90% before executing
- `/retro` after long sessions, `/reflect` weekly
- HIGH risk (DB, auth, delete, push) always requires human gate

## Notes

- `settings.local.json` is gitignored — never commit secrets or personal permissions
- Project-level `.claude/` (agents, project hooks) stays per-project, not here
- Conversation logs, telemetry, debug transcripts are ephemeral — not synced (~1.8 GB)
