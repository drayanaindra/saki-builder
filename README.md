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
│   ├── rplan/           # /rplan        — structured planning (confidence + completeness)
│   ├── rplan-review/    # /rplan-review — 4-phase review: structural + criteria hardening + parallel experts + readiness
│   ├── rplan-trust/     # /rplan-trust  — fully autonomous plan→review→implement
│   ├── approved/        # /approved     — approve plan, switch to Sonnet
│   ├── qa/              # /qa           — run acceptance criteria from plan, report pass/fail per criterion
│   ├── retro/           # /retro        — session retrospective
│   ├── reflect/         # /reflect      — promote patterns to memory/patterns.md
│   ├── sync/            # /sync         — commit & push memory/ to remote
│   ├── init-env/        # /init-env     — scaffold new project config + skill overrides
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

Click **Fork** on GitLab. This gives you your own copy to customize.

### 2. Install on any machine

```bash
curl -fsSL https://gitlab.com/drayanaindra/claude-config/-/raw/main/get.sh | \
  REPO_URL=git@gitlab.com:drayanaindra/claude-config.git bash
```

Or clone manually:
```bash
git clone git@gitlab.com:drayanaindra/claude-config.git ~/claude-config
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
| `/rplan-review` | 4-phase review: (1) structural completeness scan, (1.5) acceptance criteria hardening, (2) parallel domain expert agents, (3) synthesis + confidence scoring, (4) per-step readiness check. |
| `/rplan-trust` | Fully autonomous pipeline: plan → review → implement → QA. No user confirmation for CLI commands. |
| `/approved` | Approve the active plan and switch model to Sonnet for implementation. |
| `/qa` | Run each acceptance criterion from the plan as an actual test. Reports pass/fail per criterion. Never ends with "set up X". |
| `/retro` | Session retrospective — captures corrections, discoveries, patterns. |
| `/reflect` | Promotes confirmed patterns to `memory/patterns.md` (run weekly). |
| `/sync` | Commit and push `memory/` changes to remote (run after `/reflect`). |
| `/rupdate` | Pull latest skills and patterns from remote (run on other machines after `/sync`). |
| `/init-env` | Scaffold `.claude/` config for a new project including project-specific skill overrides. |

### Standard session flow

```
/rplan          → write plan (rough acceptance criteria OK)
/rplan-review   → Phase 1.5 hardens criteria into curl/test commands
                  → parallel domain experts review
/approved       → implement
/qa             → run each criterion, report pass/fail, update plan checkboxes
/retro          → capture learnings
/sync           → push patterns to remote
```

## Plan Quality Gates (4-gate system)

Every plan must pass all 4 gates before confidence can reach 96%:

| Gate | What it checks |
|------|---------------|
| **Confidence score** | ≥96%, weighted by risk (HIGH steps 2×, MED 1.5×). Deductions for unchecked checklist items. |
| **User Role Coverage** | Every affected role listed with full call chain + auth guard. |
| **Plan Wiring** | Each major flow written end-to-end: `Component → api.ts fn → HTTP METHOD /path → service.fn() → Model.field` |
| **Migration Checklist** | Every schema change has named migration file + explicit command. |

`/rplan-review` enforces these as structural blockers — missing sections stop the review entirely.

## `/rplan-review` Phases

| Phase | Name | What happens |
|-------|------|-------------|
| 1 | Structural scan | Pass/fail check for all 7 required sections. Hard gate — missing section stops review. |
| 1.5 | Acceptance criteria hardening | Every vague criterion is rewritten in-place: Given/When/Then + exact test command + expected outcome. Plan file is edited before experts run. |
| 2 | Parallel domain expert review | Specialized agents (Backend, Frontend, DB/Security, Product) run in parallel. Each agent has domain-specific blockers. Results collected and merged. |
| 3 | Synthesis | All expert findings deduplicated, confidence recalculated, blockers vs warnings classified. |
| 4 | Readiness check | Every implementation step verified: can a developer execute it without asking any questions? |

## `/qa` — Criteria-Driven Testing

`/qa` reads the plan's Success Criteria and runs each one — not generic tool commands.

**Criterion types and how they're tested:**

| Type | Signal | Test method |
|------|--------|-------------|
| `API` | Mentions endpoint, HTTP, status code | `curl -s -o /dev/null -w "%{http_code}"` |
| `GO_TEST` | Mentions Go function, service, repo | `go test ./internal/[pkg]/... -run [Name] -v` |
| `FILE` | Mentions file existence, migration | `ls -la [path]` |
| `DB` | Mentions table, column, row | `psql $DATABASE_URL -c "[query]"` |
| `BUILD` | Always run | `go build ./...`, `tsc --noEmit` |
| `UI` | Mentions page, button, browser | Playwright (if configured) or MANUAL with browser steps |

**Result states — no criterion is ever silently omitted:**
- `✅ PASS` — actual matches expected
- `❌ FAIL` — actual differs from expected (shows exact error)
- `🔲 MANUAL` — UI interaction required, browser steps listed
- `⚠️ BLOCKED` — dependency missing (server down), exact unblock instruction given
- `⚠️ NO_EXPECTED_OUTCOME` — ran successfully but plan had no expected outcome to compare

After running, `/qa` updates plan checkboxes: `[ ]` → `[x]` for PASS, `[!]` for FAIL.

## Project-Specific Skill Overrides

Skills follow a two-level override pattern:

```
~/.claude/skills/<name>/SKILL.md     ← global (language-agnostic, this repo)
    ↓ overridden by
.claude/skills/<name>/SKILL.md       ← project-specific (scaffolded by /init-env)
```

The global `/rplan-review` uses generic domain experts (Backend, Frontend, DB/Security, Product).
A project override replaces these with stack-specific agents — e.g., for a Go + Next.js + PostgreSQL project:

- **Go Engineer** — enforces `ctx context.Context`, RLS tenant guard, `pgx.Tx` atomicity
- **Next.js Engineer** — enforces App Router patterns, type coverage, auth guards
- **PostgreSQL/Security** — enforces `.down.sql` pairing, RLS policies, migration safety
- **Product** — enforces locale, currency format, user role coverage

Run `/init-env "your stack description"` in a new project to scaffold the override automatically.

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

17 specialized role personas available as skill files (loaded as instructions, not slash commands):

| Role | Use when |
|------|---------|
| `product.md` | Scoping features, defining user stories |
| `architect.md` | System design, API contracts, data models |
| `engineer.md` | Implementation, bug fixes |
| `reviewer.md` | Code review after implementation |
| `qa.md` | Manual QA thinking, test case design (not the same as `/qa` command) |
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

> Note: `qa.md` is a role persona for thinking about testing. `/qa` (in `skills/qa/`) is the executable slash command that actually runs tests against the plan's acceptance criteria.

## Uninstall

```bash
cd ~/claude-config && ./uninstall.sh  # removes symlinks, restores from backup
```

## Notes

- `settings.local.json` in `~/.claude/` is always gitignored — never commit secrets or personal permissions there
- Project-level `.claude/` (agents, project hooks, skill overrides) stays per-project, not here
- Conversation logs, telemetry, debug transcripts are ephemeral — not synced (~1+ GB)
- `personal/` is gitignored — safe to put personal tools there without polluting the shared repo
