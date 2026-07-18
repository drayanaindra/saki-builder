# saki-builder

A Claude Code **plugin** — a shared, personal-scale toolkit of planning/build/review skills, domain
agents, safety hooks, an always-on execution protocol, and a split learning loop. Everyone installs
the same vetted tools and works solo with them.

**Install (no clone):**
```
> /plugin marketplace add https://gitlab.com/drayanaindra/saki-builder.git
> /plugin install saki-builder@saketek
```
Then start a new session. Teammate guide: **[docs/HOW-TO.md](docs/HOW-TO.md)**. Every command is
namespaced `/saki-builder:<name>` (e.g. `/saki-builder:rplan`). Update with `/saki-builder:update`.

> **The three names** (all currently distinct): the git **repo** is `saki-builder` (dir `claude-config`
> on disk), the **marketplace** is `saketek`, and the **plugin** is `saki-builder` — hence the install
> slug `saki-builder@saketek` (`<plugin>@<marketplace>`) and the `/saki-builder:` command namespace.
>
> The legacy clone + `./install.sh` symlink flow below still works (owner/dev), but the plugin is the
> primary path.

## What's Inside

```
config/                  # Shared config (safe for all users)
├── CLAUDE.md            # Global instructions & execution protocol
├── settings.json        # Global hooks (notifications, context restore)
├── docs/
│   ├── execution-protocol-detail.md # Full RESEARCH > PLAN > EXECUTE > VERIFY reference (on-demand, not auto-loaded)
│   ├── ddd-patterns.md         # Domain-Driven Design code patterns
│   └── modular-architecture.md # Growth-driven architecture ladder (flat → modular → DDD → microservices)
├── skills/
│   ├── roadmap/         # /roadmap      — view/init the work-item portfolio (tasks/roadmap.md); the disciplined entry point
│   ├── add/             # /add          — universal intake: categorize (Epic·Feature·Improvement·Bug), flag Type+Track, route to a PRD or a plan
│   ├── pickup/          # /pickup       — start a PRD-track item (E<n>/F<n>): seed /prd, loop /prd ↔ /prd-review to green (ready for /proto)
│   ├── prd/             # /prd          — generate a PRD from a feature intent (premise + quality + grounding + business-rule gates)
│   ├── prd-review/      # /prd-review   — adversarial PRD review: parallel judge panel (product, metrics, slicing, evidence), every finding cited
│   ├── proto/           # /proto        — faithful throwaway UI preview of a PRD's slices (real design system, Playwright screenshots) before /build
│   ├── rplan/           # /rplan        — structured planning (confidence + completeness)
│   ├── rplan-review/    # /rplan-review — 4-phase review: structural + criteria hardening + parallel experts + readiness
│   ├── build/           # /build        — autonomously execute a finished PRD slice-by-slice (rplan→[review]→approved→qa→reviewer, +e2e); gates open-questions + 🔒 invariants
│   ├── approved/        # /approved     — approve plan, switch to Sonnet
│   ├── qa/              # /qa           — run acceptance criteria from plan, report pass/fail per criterion
│   ├── prompt/          # /prompt       — expand one-line idea into structured 6-section prompt
│   ├── reviewer/        # /reviewer     — fresh-context code review from git diff
│   ├── review/          # /review       — alternative review skill
│   ├── retro/           # /retro        — session retrospective
│   ├── reflect/         # /reflect      — promote patterns to memory/patterns.md
│   ├── sync/            # /sync         — commit & push memory/ to remote
│   ├── rupdate/         # /rupdate      — pull latest skills and patterns from remote
│   ├── init-env/        # /init-env     — scaffold new project config + skill overrides
│   └── [role skills]    # 20 role personas (see Roles section below)
├── hooks/
│   ├── dangerous-command-guard.sh  # Block destructive commands (rm -rf, DROP, force push)
│   └── rtk-rewrite.sh             # RTK token-optimizer hook
└── ...

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
curl -fsSL https://gitlab.com/drayanaindra/saki-builder/-/raw/main/get.sh | \
  REPO_URL=git@gitlab.com:drayanaindra/saki-builder.git bash
```

Or clone manually:

```bash
git clone git@gitlab.com:drayanaindra/saki-builder.git ~/claude-config
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

| Command         | What it does                                                                                                                                                                                                    |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/roadmap`      | View (or `init`) the product roadmap — `tasks/roadmap.md`, the single team-shareable portfolio of work items (epics · features · improvements · bugs) + status. The disciplined entry point: every piece of work traces to an item here. |
| `/add`          | **The universal intake.** Categorizes an incoming item into **Epic · Feature · Improvement · Bug** (auto-proposed, or forced with `--epic`/`--feature`/`--improvement`/`--bug`), stamps a **Type + Track** flag, assigns a per-type id (`E`/`F`/`I`/`B<n>`), records it on the roadmap, and **routes** it. Routing rule: a new user journey/UI ⇒ **PRD-track** (→ `/pickup`); a change/fix to existing behavior ⇒ **Plan-track** (→ `/rplan` step-by-step, or `/build I<n>`/`B<n>` for the whole chain autonomously — skipping PRD + proto either way). Records + points only. `--list` shows the portfolio. Replaces the old `/epic`. |
| `/pickup`       | **Start a PRD-track item.** `/pickup E<n>` (or `F<n>`) reads the item, seeds `/prd`, and loops `/prd` ↔ `/prd-review` to green (`SHIP · READY`), then stops — ready for `/proto`. Flips the item `In-progress`; escapes to `Blocked` if the review can't reach a shippable PRD. PRD-track only — an `I<n>`/`B<n>` id is redirected to `/rplan`. |
| `/prd`          | Generate a Product Requirements Document (Job Story, outcomes, vertical slices, acceptance criteria, business rules & invariants, non-goals) from a feature intent. Gates on substance — premise, quality score, evidence grounding. Saved to `tasks/prd-<feature>.md`. Usually invoked by `/pickup`, not directly. |
| `/prd-review`   | Adversarial, fresh-context PRD review: a deterministic structural scan, then a parallel judge panel (product, metrics, slicing, evidence) that cites every finding. Run after `/prd`, before `/build`. |
| `/proto`        | Render a faithful, **throwaway** UI preview of the PRD's user-facing slices using the project's real design-system components + tokens, screenshotting every state via Playwright — so you see the end-user surface **before** `/build` writes code. Sits between `/prd` and `/build`. |
| `/build`        | **Autonomously execute a finished PRD _or_ a plan-track item.** Two modes, picked from the argument. **PRD mode** — `/build E<n>` / `F<n>` / `<prd-file.md>` reads the PRD's vertical slices and runs `/rplan` → (`/rplan-review` if needed) → `/approved` → `/qa` → `/reviewer` on each, looping until every slice is green and reviewed; hard-stops on an unresolved `before slice N` open question; enforces the PRD's `🔒 INVARIANT`s. **PLAN mode** — `/build I<n>` / `B<n>` / `<plan-file>` runs that same chain **once** over one Improvement/Bug (no PRD-lock, no slices, no proto; UI handled inline). Both always run the e2e suite and converge to clean (`/wrap --heal`) before declaring done. No confirmation prompts. |
| `/rplan`        | Create structured execution plan. Confidence must reach >=96% with all 4 gates passing before presenting.                                                                                                       |
| `/rplan-review` | 4-phase review: (1) structural completeness scan, (1.5) acceptance criteria hardening, (2) parallel domain expert agents, (3) synthesis + confidence scoring, (4) per-step readiness check.                     |
| `/approved`     | Approve the active plan and switch model to Sonnet for implementation.                                                                                                                                          |
| `/qa`           | Run each acceptance criterion from the plan as an actual test. Reports pass/fail per criterion. Uses `@playwright/mcp` for UI criteria when available; falls back to auto-generated Playwright specs otherwise. |
| `/prompt`       | Expand a one-line idea into a structured 6-section prompt (Role, Task, Context, Reasoning, Stop, Output).                                                                                                       |
| `/reviewer`     | Fresh-context code review — reads git diff, uses project-specific checklist if available, reports issues with severity. Run before committing.                                                                  |
| `/retro`        | Session retrospective — captures corrections, discoveries, patterns.                                                                                                                                            |
| `/reflect`      | Promotes confirmed patterns to `memory/patterns.md` (run weekly).                                                                                                                                               |
| `/sync`         | Commit and push `memory/` changes to remote (run after `/reflect`).                                                                                                                                             |
| `/rupdate`      | Pull latest skills and patterns from remote (run on other machines after `/sync`).                                                                                                                              |
| `/init-env`     | Scaffold `.claude/` config for a new project including project-specific skill overrides.                                                                                                                        |

### Standard session flow

```
/rplan          -> write plan (rough acceptance criteria OK)
/rplan-review   -> Phase 1.5 hardens criteria into curl/test commands
                   -> parallel domain experts review
/approved       -> implement
/qa             -> run each criterion, report pass/fail, update plan checkboxes
/retro          -> capture learnings
/reflect        -> promote patterns (weekly)
/sync           -> push patterns to remote
```

> The `/rplan → /rplan-review → /approved → /qa → /reviewer → /wrap` middle of this chain is exactly what
> `/build I<n>`/`B<n>` runs autonomously for a roadmap-anchored Improvement/Bug — reach for `/build <id>`
> when you want to walk away, and the step-by-step commands when you want a gate at each boundary.

### Roadmap-anchored stepwise flow — `/add` routes to one of two tracks

Every piece of work enters through **`/add`**, which categorizes it and stamps a **Track**. The Track
decides the path — a new user journey/UI to design gets the full PRD assembly line; a change or fix to
existing behavior skips the PRD + proto and goes straight to planning:

| Type | Id | Track | Path after `/add` |
| ------------- | ------ | ---------- | ------------------------------------------------------------------- |
| **Epic**        | `E<n>` | **PRD**  | `/pickup E<n>` → `/prd` (loop `/prd-review` to green) → `/proto` → `/build` |
| **Feature**     | `F<n>` | **PRD**  | `/pickup F<n>` → `/prd` (loop `/prd-review` to green) → `/proto` → `/build` |
| **Improvement** | `I<n>` | **Plan** | `/rplan` → `/approved` → `/qa`  · **or** `/build I<n>` (whole chain, autonomous) |
| **Bug**         | `B<n>` | **Plan** | `/rplan` (or fix directly if trivial) → `/qa`  · **or** `/build B<n>` (autonomous) |

**PRD-track** (Epic / Feature) — the disciplined assembly line, each command boundary a review gate:

```
/roadmap init        -> scaffold tasks/roadmap.md (the portfolio)              (once per project)
/add "<intent>"      -> categorize -> Epic/Feature (Track: PRD), assign E<n>/F<n>            [Planned]
/pickup E<n>         -> seed /prd, loop /prd ↔ /prd-review to green (SHIP·READY), stop      [In-progress]
                        -> writes tasks/prd-<slug>.md (Item: E<n>), records Child PRD on the roadmap
/proto E<n>          -> throwaway UI preview (real design system + Playwright shots)
                        -> running /proto IS your approval of the PRD (no separate step)
/build E<n>          -> autonomously execute every slice (see below)                          [Shipped]
```

**Plan-track** (Improvement / Bug) — no PRD, no proto; `/add` composes the intent and points at `/rplan` (step-by-step) or `/build <id>` (autonomous):

```
/add "<intent>"      -> categorize -> Improvement/Bug (Track: Plan), assign I<n>/B<n>        [Planned]
/rplan               -> structured plan (seeded from the item) -> /approved -> /qa
   — OR, one command, walk away —
/build I<n>          -> PLAN mode: /rplan (if no plan) -> /rplan-review? -> /approved -> /qa
                        -> /reviewer (+ design-system reuse check) -> security? -> /wrap --heal   [Shipped]
```

`/build I<n>` / `/build B<n>` (or `/build <plan-file>`) is the Plan-track analogue of `/build E<n>`: it runs
the same `/rplan → … → /wrap` chain you'd otherwise run by hand, once over the single item — no PRD-lock
gate, no slices, no proto. UI changes are handled inline (design-system reuse check always; a quick
screenshot glance when >1 screen or a new visible state is touched).

**The gate is structural.** All work enters through `/add` — there is no cold-intent path. On the
PRD-track, `/pickup` requires an `E<n>`/`F<n>` id, loops the PRD to green autonomously, and escapes to
`Blocked` (never fabricates grounding, never loops forever) if the review can't reach a shippable spec.
The single human gate is at proto: **running `/proto E<n>` is the approval**.

> **`/epic` is removed** (clean rename → `/add`); **`/pipeline` is retired** in favour of this stepwise
> flow. Recover the old autonomous pipeline via `git show <old-sha>:config/skills/pipeline/SKILL.md`.

### Autonomous execution (`/build`) — PRD slices or a single plan-track item

**PRD mode** — `/build E<n>` / `/build F<n>` (or `/build prd-<feature>.md`) hands the whole PRD to an autonomous loop — walk away:

```
/build E3
  -> resolves E3 (or F<n>) -> its Child PRD -> reads the vertical slices (PRD order = execution order) + invariants
  -> for EACH slice, autonomously:
       open-question gate (hard-stop if a `before slice N` decision is unresolved)
       -> /rplan -> (/rplan-review if needed) -> /approved -> /qa -> /reviewer
     looping until the slice is green and review is clean
  -> runs the e2e suite before declaring the goal done
  -> flips the item to Shipped on the roadmap
```

`/build` asks nothing — its only hard stops are a missing PRD, an **unresolved `before slice N`
open question** (it refuses to guess a load-bearing architectural decision), an absolute DB no-go, or a
slice that genuinely can't be made green (reported honestly, never faked). It enforces the PRD's
business-rule `🔒 INVARIANT`s — verified in `/qa` and blocking in `/reviewer`.

**For bulletproof cross-turn autonomy, launch under `/goal`:**

```
/goal /build E3 — done when every slice passes /qa and /reviewer and the e2e suite is green
```

Plain `/build E3` also self-iterates (completion signal + progress scratchpad + loop guard), but the
`/goal` wrapper is what guarantees it never stops early.

**PLAN mode — `/build I<n>` / `/build B<n>` / `/build <plan-file>`:** the same executor runs a plan-track
item (Improvement/Bug) as **one unit**, not a slice list:

```
/build B7
  -> resolves B7 -> its plan (or runs /rplan to create one) -> The Single-Plan Loop, once:
       /rplan (if no plan) -> (/rplan-review if needed) -> /approved -> /qa
       -> /reviewer (+ design-system reuse check; a hand-rolled primitive is a blocking finding)
       -> security audit (only if a security surface) -> loop until green + clean
  -> UI: reuse-check always; a screenshot glance when >1 screen or a new visible state is touched
  -> e2e -> /wrap --heal -> flips the item to Shipped, prints PLAN_BUILD_COMPLETE
```

PLAN mode drops the PRD-only gates (no lock check, no slice iteration, no proto-fidelity gate); everything
else — TRUST MODE, resume, e2e, converge-to-clean — is identical. It never calls `/proto` (that's PRD-bound);
the reuse check + glance cover UI instead.

## Plan Quality Gates (4-gate system)

Every plan must pass all 4 gates before confidence can reach 96%:

| Gate                    | What it checks                                                                                                   |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Confidence score**    | >=96%, weighted by risk (HIGH steps 2x, MED 1.5x). Deductions for unchecked checklist items.                     |
| **User Role Coverage**  | Every affected role listed with full call chain + auth guard.                                                    |
| **Plan Wiring**         | Each major flow written end-to-end: `Component -> api.ts fn -> HTTP METHOD /path -> service.fn() -> Model.field` |
| **Migration Checklist** | Every schema change has named migration file + explicit command.                                                 |

`/rplan-review` enforces these as structural blockers — missing sections stop the review entirely.

## `/rplan-review` Phases

| Phase | Name                          | What happens                                                                                                                                         |
| ----- | ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | Structural scan               | Pass/fail check for all 7 required sections. Hard gate — missing section stops review.                                                               |
| 1.5   | Acceptance criteria hardening | Every vague criterion is rewritten in-place: Given/When/Then + exact test command + expected outcome. Plan file is edited before experts run.        |
| 2     | Parallel domain expert review | Specialized agents (Backend, Frontend, UI/UX, Database, Security, Architecture, QA, Product) run in parallel — only those the plan touches. Each agent has domain-specific blockers. Results collected and merged. |
| 3     | Synthesis                     | All expert findings deduplicated, confidence recalculated, blockers vs warnings classified.                                                          |
| 4     | Readiness check               | Every implementation step verified: can a developer execute it without asking any questions?                                                         |

## `/qa` — Criteria-Driven Testing

`/qa` reads the plan's Success Criteria and runs each one — not generic tool commands.

**Criterion types and how they're tested:**

| Type      | Signal                               | Test method                                                    |
| --------- | ------------------------------------ | -------------------------------------------------------------- |
| `API`     | Mentions endpoint, HTTP, status code | `curl -s -o /dev/null -w "%{http_code}"`                       |
| `GO_TEST` | Mentions Go function, service, repo  | `go test ./internal/[pkg]/... -run [Name] -v`                  |
| `FILE`    | Mentions file existence, migration   | `ls -la [path]`                                                |
| `DB`      | Mentions table, column, row          | `psql $DATABASE_URL -c "[query]"`                              |
| `BUILD`   | Always run                           | `go build ./...`, `tsc --noEmit`                               |
| `UI`      | Mentions page, button, browser       | Playwright (auto-generated specs) or MANUAL with browser steps |

**Result states — no criterion is ever silently omitted:**

- `PASS` — actual matches expected
- `FAIL` — actual differs from expected (shows exact error)
- `MANUAL` — UI interaction required, browser steps listed
- `BLOCKED` — dependency missing (server down), exact unblock instruction given
- `NO_EXPECTED_OUTCOME` — ran successfully but plan had no expected outcome to compare

After running, `/qa` updates plan checkboxes: `[ ]` -> `[x]` for PASS, `[!]` for FAIL.

## Docs

Reference documents. These are **not** auto-loaded — skills pull them in when needed (lazy-loaded to keep the base prompt small).

| Doc                                 | Purpose                                                                              | Loaded by                      |
| ----------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------ |
| `docs/execution-protocol-detail.md` | Full RESEARCH > PLAN > ANNOTATE > EXECUTE > VERIFY > LEARN protocol (phases, matrix) | `/rplan`, `/retro`, `/reflect` |
| `docs/ddd-patterns.md`              | Domain-Driven Design layer rules, directory structure, cross-context communication   | `/init-env` when stack matches |
| `docs/modular-architecture.md`      | 4-stage architecture ladder with transition triggers and migration recipes           | `/init-env` when stack matches |
| `skills/rplan/template.md`          | Plan template with 4-gate review sections, wiring, migration checklist               | `/rplan`                       |
| `skills/qa/playwright-patterns.md`  | Auth fixture, addInitScript safety, teardown patterns for /qa Playwright specs       | `/qa`                          |

## Hooks

| Hook                         | Purpose                                                                                                                                                                                                                                                                                 |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dangerous-command-guard.sh` | Blocks destructive commands (`rm -rf`, `DROP TABLE`, `git push --force`, `git checkout .`) before execution. Regex-based pattern matching on `CLAUDE_TOOL_INPUT_COMMAND`.                                                                                                               |
| `rtk-rewrite.sh`             | Rewrites CLI commands through RTK (Rust Token Killer) for 60-90% token savings on dev operations.                                                                                                                                                                                       |
| `repo-context.sh`            | SessionStart hook (matchers `startup\|resume\|clear`) — emits a tight `<repo-context>` block with top-level tree, branch ahead/behind, stash count, and active `*-plan.md` files. Deduplicated against the harness env-block (no cwd/branch/status/commits repeat). ~50 tokens, <100ms. |

## MCP Servers

| Server            | Scope | Purpose                                                                                                                                           |
| ----------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@playwright/mcp` | User  | Browser automation for `/qa` UI criteria and ad-hoc debug sessions. Installed by `install.sh` via `claude mcp add --scope user`. See `/qa` skill. |

`install.sh` registers MCP servers at user scope via `claude mcp add`. The config lives in `~/.claude.json` (machine-local, not in this repo — it holds OAuth state and other Claude-managed data). On a new machine, `./install.sh` re-registers anything missing. To remove: `claude mcp remove playwright`.

Usage policy:

- `/qa` skill auto-detects `mcp__playwright__*` tools and uses them for UI criteria.
- Outside `/qa` or explicit debug requests, Claude should not invoke `mcp__playwright__*` tools (per skill rule).
- If the MCP server is unavailable on a given machine, `/qa` falls back to its existing Playwright-spec generation path under `e2e/qa-generated/`.

## Project-Specific Skill Overrides

Skills follow a two-level override pattern:

```
~/.claude/skills/<name>/SKILL.md     <- global (language-agnostic, this repo)
    overridden by
.claude/skills/<name>/SKILL.md       <- project-specific (scaffolded by /init-env)
```

The global `/rplan-review` uses generic domain experts (Backend, Frontend, UI/UX, Database, Security, Architecture, QA, Product).
A project override replaces these with stack-specific agents — e.g., for a Go + Next.js + PostgreSQL project:

- **Go Engineer** — enforces `ctx context.Context`, RLS tenant guard, `pgx.Tx` atomicity
- **Next.js Engineer** — enforces App Router patterns, type coverage, auth guards
- **PostgreSQL/Security** — enforces `.down.sql` pairing, RLS policies, migration safety
- **Product** — enforces locale, currency format, user role coverage

Run `/init-env "your stack description"` in a new project to scaffold the override automatically.

## Execution Protocol

Every non-trivial task follows:

```
RESEARCH -> PLAN -> ANNOTATE -> EXECUTE -> VERIFY -> LEARN
```

Full protocol: `config/docs/execution-protocol-detail.md` (loaded on demand by the relevant skill)

Key rules:

- Never implement without a plan for 2+ file changes
- Confidence >= 96% with all 4 gates passing before executing
- Max 2 unknowns before presenting a plan
- `/retro` after long sessions, `/reflect` weekly
- HIGH risk (DB, auth, delete, push) always requires human gate

## Roles

20 specialized role personas available as skill files (loaded as instructions, not slash commands):

| Role                           | Use when                                                             |
| ------------------------------ | -------------------------------------------------------------------- |
| `product.md`                   | Scoping features, defining user stories                              |
| `architect.md`                 | System design, API contracts, data models                            |
| `engineer.md`                  | Implementation, bug fixes                                            |
| `reviewer.md`                  | Code review after implementation                                     |
| `qa.md`                        | Manual QA thinking, test case design (not the same as `/qa` command) |
| `devops.md`                    | CI/CD, infrastructure, deployment                                    |
| `security-expert.md`           | Security review, hardening                                           |
| `pentester.md`                 | Attack simulation, vulnerability testing                             |
| `nlp-engineer.md`              | Prompt engineering, AI agent behavior                                |
| `ai-architect.md`              | AI/ML system design                                                  |
| `mobile-engineer.md`           | iOS/Android, React Native                                            |
| `design.md`                    | UI/UX, design systems                                                |
| `go-engineer.md`               | Go-specific patterns                                                 |
| `ddd-engineer.md`              | Domain-driven design                                                 |
| `service-designer.md`          | Customer journey, conversation design                                |
| `gpu-engineer.md`              | Metal, CUDA, compute shaders                                         |
| `image-processing-engineer.md` | CIFilter pipelines, LUTs, color science                              |
| `color-scientist.md`           | Color theory, color spaces, calibration                              |
| `seo-expert.md`                | SEO optimization, structured data, indexing                          |
| `vibe-code.md`                 | Rapid prototyping, creative coding                                   |

> Note: `qa.md` is a role persona for thinking about testing. `/qa` (in `skills/qa/`) is the executable slash command that actually runs tests against the plan's acceptance criteria.

## Memory System

`memory/patterns.md` contains confirmed cross-project patterns organized by category:

- **Workflow** — planning, review, research patterns
- **Code Quality** — Tailwind, CSS anti-patterns
- **Tools & Commands** — CLI, env, git patterns
- **Debugging** — diagnostic patterns, common traps
- **React Patterns** — hooks, closures, null safety
- **Next.js App Router** — routing, remounting, Suspense
- **Go** — interfaces, pgx, JSON tags, routing
- **Architecture** — constraints, undo/redo, multi-layer enforcement
- **iOS / SwiftUI** — gestures, ViewBuilder, Metal views
- **iOS / Core Image** — CIFilter, tone mapping, color science
- **AI / LLM Integration** — prompt calibration, structured output
- **Audio / Voice / AI** — Whisper anti-hallucination
- **Python / API** — Pydantic, Alembic, SQLAlchemy
- **Python Async** — asyncio, CancelledError, anyio
- **MCP Servers** — transport, startup, tool schemas
- **Claude Code Skills** — skill architecture, QA design

Patterns are promoted by `/reflect` when confirmed across 3+ sessions or 2+ projects.

## Uninstall

```bash
cd ~/claude-config && ./uninstall.sh  # removes symlinks, restores from backup
```

## Notes

- `settings.local.json` in `~/.claude/` is always gitignored — never commit secrets or personal permissions there
- Project-level `.claude/` (agents, project hooks, skill overrides) stays per-project, not here
- Conversation logs, telemetry, debug transcripts are ephemeral — not synced (~1+ GB)
- `personal/` is gitignored — safe to put personal tools there without polluting the shared repo
