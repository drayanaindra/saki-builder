# claude-config

A structured Claude Code configuration with skills, execution protocols, and centralized learning sync.

**Fork this repo, customize it, and install it on any machine in one command.**

## What's Inside

```
config/                  # Shared config (safe for all users)
├── CLAUDE.md            # Global instructions & execution protocol
├── settings.json        # Global hooks (notifications, context restore)
├── docs/
│   ├── execution-protocol.md   # RESEARCH > PLAN > EXECUTE > VERIFY workflow
│   └── plan-template.md        # Structured plan format with confidence scoring
├── skills/
│   ├── engineer.md, architect.md, product.md, ...  (17 role skills)
│   ├── plan/SKILL.md    # /plan command — structured planning
│   ├── retro/SKILL.md   # /retro command — session retrospective
│   ├── reflect/SKILL.md # /reflect command — cross-project pattern promotion
│   └── init-env/SKILL.md# /init-env command — scaffold new project
└── hooks/               # (add your shared hooks here)

memory/                  # Learning data — updated by /reflect, synced via git
├── patterns.md          # Confirmed cross-project patterns
├── rag-research.md      # RAG best practices
└── agent-architecture-research.md

personal/                # Your personal stuff — gitignored, not shared
└── README.md            # Instructions for personal customizations (RTK, etc.)
```

## Getting Started

### 1. Fork this repo

Click **Fork** on GitHub/GitLab. This gives you your own copy to customize.

### 2. Install on any machine

```bash
curl -fsSL https://raw.githubusercontent.com/drayanaindra/claude-config/main/get.sh | \
  REPO_URL=git@github.com:drayanaindra/claude-config.git bash
```

Or clone manually:
```bash
git clone git@github.com:drayanaindra/claude-config.git ~/claude-config
chmod +x ~/claude-config/*.sh && ~/claude-config/install.sh
```

This creates symlinks from `~/.claude/` into `~/claude-config/`. Your existing
`~/.claude/` files are backed up automatically before being replaced.

After install, restart Claude Code:
```bash
claude
```

### 3. Customize

Edit any file in `config/` — changes take effect immediately (symlinked).

For personal tools (RTK, personal hooks, etc.): see `personal/README.md`.

## Keep Learnings in Sync

After running `/reflect` in Claude Code (weekly recommended):

```bash
cd ~/claude-config && ./sync.sh   # commits memory/ changes and pushes
```

On other machines, pull the latest learnings:
```bash
cd ~/claude-config && git pull
```

Since `~/.claude/memory/` is a symlink to `~/claude-config/memory/`, the pull
immediately makes new patterns available to Claude Code.

## Workflow

| Tool | What it does |
|------|-------------|
| `/plan` | Create structured execution plan with confidence scoring |
| `/retro` | Session retrospective — captures corrections, discoveries, patterns |
| `/reflect` | Promotes confirmed patterns to `memory/patterns.md` (run weekly) |
| `/init-env` | Scaffold `.claude/` config for a new project |
| `/sync` | Commit and push `memory/` changes to remote (run after `/reflect`) |

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

## Uninstall

```bash
cd ~/claude-config && ./uninstall.sh  # removes symlinks, restores from backup
```

## Notes

- `settings.local.json` in `~/.claude/` is always gitignored — never commit secrets or personal permissions there
- Project-level `.claude/` (agents, project hooks) stays per-project, not here
- Conversation logs, telemetry, debug transcripts are ephemeral — not synced (~1+ GB)
- `personal/` is gitignored — safe to put personal tools there without polluting the shared repo
