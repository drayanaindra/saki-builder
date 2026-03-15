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
│   └── plan-template.md        # Plan template with 4-gate review sections
├── skills/
│   ├── rplan/           # /rplan      — structured planning (confidence + completeness)
│   ├── rplan-review/    # /rplan-review — 3-phase structural + adversarial review
│   ├── rplan-trust/     # /rplan-trust  — fully autonomous plan→review→implement
│   ├── approved/        # /approved   — approve plan, switch to Sonnet
│   ├── retro/           # /retro      — session retrospective
│   ├── reflect/         # /reflect    — promote patterns to memory/patterns.md
│   ├── sync/            # /sync       — commit & push memory/ to remote
│   ├── init-env/        # /init-env   — scaffold new project config
│   └── [17 role skills] # engineer, architect, product, qa, devops, security, ...
└── hooks/               # Shared hooks

memory/                  # Learning data — updated by /reflect, synced via git
├── patterns.md          # Confirmed cross-project patterns (promoted by /reflect)
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

| Command | What it does |
|---------|-------------|
| `/rplan` | Create structured execution plan. Confidence must reach ≥96% with all 4 gates passing before presenting. |
| `/rplan-review` | 3-phase review: (1) structural completeness scan, (2) adversarial confidence probing, (3) per-step implementation readiness check. |
| `/rplan-trust` | Fully autonomous pipeline: plan → structural scan → probing → implement → QA. No user confirmation for CLI commands. |
| `/approved` | Approve the active plan and switch model to Sonnet for implementation. |
| `/retro` | Session retrospective — captures corrections, discoveries, patterns. |
| `/reflect` | Promotes confirmed patterns to `memory/patterns.md` (run weekly). |
| `/sync` | Commit and push `memory/` changes to remote (run after `/reflect`). |
| `/init-env` | Scaffold `.claude/` config for a new project. |

## Plan Quality Gates (4-gate system)

Every plan must pass all 4 gates before confidence can reach 96%:

| Gate | What it checks |
|------|---------------|
| **Confidence score** | ≥96%, weighted by risk (HIGH steps 2×, MED 1.5×). Deductions for unchecked checklist items. |
| **User Role Coverage** | Every affected role (customer/admin/merchant/warehouse) listed with full call chain + auth guard. |
| **Plan Wiring** | Each major flow written end-to-end: `Component → api.ts fn → HTTP METHOD /path → service.fn() → Model.field` |
| **Migration Checklist** | Every schema change has named migration file + explicit `alembic` command. |

`/rplan-review` enforces these as structural blockers — missing sections stop the review entirely, they cannot be "answered away" with verbal confirmation.

## Execution Protocol

Every non-trivial task follows:

```
RESEARCH → PLAN → ANNOTATE → EXECUTE → VERIFY → LEARN
```

Full protocol: `config/docs/execution-protocol.md`

Key rules:
- Never implement without a plan for 2+ file changes
- Confidence ≥ 96% with all 4 gates passing before executing
- Max 2 unknowns before presenting a plan
- `/retro` after long sessions, `/reflect` weekly
- HIGH risk (DB, auth, delete, push) always requires human gate

## Roles

17 specialized roles available via skill files:

| Role | Use when |
|------|---------|
| `product.md` | Scoping features, defining user stories |
| `architect.md` | System design, API contracts, data models |
| `engineer.md` | Implementation, bug fixes |
| `reviewer.md` | Code review after implementation |
| `qa.md` | Test automation, acceptance criteria |
| `devops.md` | CI/CD, infrastructure, deployment |
| `security-expert.md` | Security review, hardening |
| `pentester.md` | Attack simulation, vulnerability testing |
| `nlp-engineer.md` | Prompt engineering, AI agent behavior |
| `ai-architect.md` | AI/ML system design |
| `mobile-engineer.md` | iOS/Android, React Native |
| `design.md` | UI/UX, design systems |
| `go-engineer.md` | Go-specific patterns |
| `ddd-engineer.md` | Domain-driven design |
| `service-designer.md` | Customer journey, conversation design |
| `gpu-engineer.md` | Metal, CUDA, compute shaders |
| `image-processing-engineer.md` | CIFilter pipelines, LUTs, color science |

## Uninstall

```bash
cd ~/claude-config && ./uninstall.sh  # removes symlinks, restores from backup
```

## Notes

- `settings.local.json` in `~/.claude/` is always gitignored — never commit secrets or personal permissions there
- Project-level `.claude/` (agents, project hooks) stays per-project, not here
- Conversation logs, telemetry, debug transcripts are ephemeral — not synced (~1+ GB)
- `personal/` is gitignored — safe to put personal tools there without polluting the shared repo
