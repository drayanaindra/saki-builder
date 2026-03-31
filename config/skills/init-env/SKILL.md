---
name: init-env
description: Scaffold the Claude Code development environment for a new project. Creates CLAUDE.md, hooks, agents, and project structure.
disable-model-invocation: true
---

# Initialize Project Environment

Set up the Claude Code production development environment for this project: $ARGUMENTS

## Process

1. **Detect project context**:
   - Read package.json, pyproject.toml, go.mod, Cargo.toml to detect tech stack
   - Check for existing CLAUDE.md, .claude/ directory
   - Identify test framework, linter, type checker
   - Ask user for: project name, business context, key constraints

2. **Create project CLAUDE.md** (lean, <100 lines):
   - Project identity and business context
   - Tech stack and key commands Claude can't guess
   - @import global execution protocol
   - @import DDD patterns: `@~/.claude/docs/ddd-patterns.md`
   - @import modular architecture: `@~/.claude/docs/modular-architecture.md`
   - Detect project stage (Stage 1-4) based on model count, file sizes, team size
   - Add a "Bounded Contexts" table (ask user or infer from project structure)
   - Add "Architecture Stage" section noting current stage and transition triggers
   - Project-specific rules only (don't duplicate global)
   - Essential checklists

3. **Create docs/project-context.md**:
   - Business context expanded
   - Architecture overview
   - Key decisions and constraints

4. **Create .claude/settings.json** with hooks:

   For Python projects:
   - PostToolUse:Edit|Write -> run type checker (mypy/pyright)
   - PreToolUse (git commit hook script) -> run tests (pytest)

   For TypeScript/JavaScript projects:
   - PostToolUse:Edit|Write -> run type checker (tsc --noEmit)
   - PreToolUse (git commit hook script) -> run tests (jest/vitest)

   For Go projects:
   - PostToolUse:Edit|Write -> run vet (go vet)
   - PreToolUse (git commit hook script) -> run tests (go test)

5. **Create .claude/agents/planner.md**:
   - Read-only planning subagent
   - Tools: Read, Grep, Glob, WebFetch, WebSearch
   - Model: sonnet (fast, good enough for exploration)

6. **Create .claude/agents/reviewer.md**:
   - Fresh-context code reviewer
   - Tools: Read, Grep, Glob, Bash
   - Model: opus (thorough review needs best model)

7. **Create .claude/hooks/ scripts** (if needed):
   - protect-files.sh (block edits to .env, lock files)
   - pre-commit-check.sh (run tests before commit)

8. **Scaffold project-specific skill overrides** in `.claude/skills/`:

   Create `.claude/skills/rplan-review/SKILL.md` tailored to the detected stack.
   Use the global `~/.claude/skills/rplan-review/SKILL.md` as the base structure, but replace
   the generic expert agent prompts with project-specific ones:

   | Stack detected | Expert agents to generate |
   |----------------|--------------------------|
   | Go | Go Engineer (ctx, error handling, service layer patterns) |
   | Python/FastAPI | Python Engineer (Pydantic, async, dependency injection) |
   | Rust | Rust Engineer (ownership, error types, async runtime) |
   | Next.js/React | Frontend Engineer (App Router or Pages Router, state, auth) |
   | Vue/Nuxt | Frontend Engineer (Composition API, Pinia, SSR) |
   | PostgreSQL | DB/Security (migrations, RLS if multi-tenant, SQL safety) |
   | MySQL/SQLite | DB/Security (migrations, query safety) |
   | Multi-tenant | add RLS/tenant isolation checks to DB agent |

   Each agent prompt must include:
   - The project's specific conventions (from CLAUDE.md)
   - File path patterns specific to this project
   - Domain-specific blockers (e.g., missing tenant guard for multi-tenant apps)
   - Output format: `[DOMAIN] REVIEW / Blockers / Warnings / Confidence adjustment`

   Also create `.claude/skills/qa/SKILL.md` with the correct test commands for this project
   (replacing the global version's hardcoded paths with this project's actual paths and commands).

9. **Initialize memory**:
   - Create .claude/memory/lessons-learned.md (empty template)

10. **Verify**:
    - Run a test hook to confirm it works
    - Show summary of what was created

## Tech Stack Detection

| File | Stack | Type Checker | Test Runner | Linter |
|------|-------|-------------|-------------|--------|
| pyproject.toml | Python | mypy | pytest | ruff |
| package.json | Node/TS | tsc --noEmit | vitest/jest | eslint |
| go.mod | Go | go vet | go test | golangci-lint |
| Cargo.toml | Rust | cargo check | cargo test | clippy |
