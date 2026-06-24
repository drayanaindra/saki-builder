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
   - @import project-local learned patterns: `@.claude/memory/patterns.md` — the promoted store for THIS repo (created in Step 11). Auto-loads project-specific patterns so `/prd`/`/rplan`/`/build` recall them. Do NOT import `lessons-learned.md` (raw inbox — keeps context lean).
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

7. **Create .claude/agents/qa.md**:
   - Copy from global template: `~/.claude/agents/qa.md`
   - The global template auto-detects the stack at runtime (Python/Go/TS/Rust)
   - No customization needed — it reads `pyproject.toml`, `package.json`, etc. to pick the right commands
   - This agent is invoked by Claude programmatically (not by user via /qa)
   - Usage by orchestrator Claude: `Agent(subagent_type="qa", prompt="Verify criteria for: [task]. Plan: [path]")`

8. **Create .claude/hooks/ scripts** (if needed):
   - protect-files.sh (block edits to .env, lock files — project-specific patterns)
   - pre-commit-check.sh (run tests before commit)
   - NOTE: `dangerous-command-guard.sh` is already active globally via `~/.claude/hooks/` (from claude-config).
     It blocks DROP DB/TABLE, destructive rm, git push --force main, migrate down/force/drop, curl|sh, etc.
     Do NOT recreate it per-project — it applies automatically to all projects.

9. **Scaffold project-specific skill overrides** in `.claude/skills/`:

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

   Also create `.claude/skills/qa/SKILL.md` as a project override that extends the global
   qa skill's Playwright logic. The override should:
   - Document the project's API base URL and dev server start command
   - Note any project-specific auth strategy (JWT keys, cookie name, OAuth vs token)
   - Leave Playwright generation logic (Step 1.5 template) unchanged — it is project-agnostic

10. **Scaffold Playwright test infrastructure** (if frontend detected):

   a. Install dotenv if not present: `npm install dotenv --save-dev`
   
   b. Create `e2e/fixtures/auth.ts` using the `base.extend<>` fixture pattern:
   ```typescript
   // Fill in the auth strategy for this project (replace the comment below)
   import { test as base } from '@playwright/test';
   type AuthFixtures = { loginWithToken: (token: string) => Promise<void> };
   export const test = base.extend<AuthFixtures>({
     loginWithToken: async ({ page }, use) => {
       await use(async (token: string) => {
         test.skip(!process.env.TEST_JWT, 'TEST_JWT not set');
         // TODO: replace with this project's auth strategy
         // e.g. localStorage keys, cookie name, session storage key
         await page.addInitScript(
           ({ accessToken, refreshToken }: { accessToken: string; refreshToken: string }) => {
             localStorage.setItem('access_token', accessToken);
             localStorage.setItem('refresh_token', refreshToken);
           },
           { accessToken: token, refreshToken: 'placeholder-refresh' },
         );
       });
       await page.evaluate(() => localStorage.clear());
     },
   });
   export { expect } from '@playwright/test';
   ```
   
   c. Add `dotenv.config({ path: '.env.test' })` to top of `playwright.config.ts`
      (Playwright does NOT auto-load `.env.test` — Next.js does, Playwright doesn't)
   
   d. Create `e2e/qa-generated/.gitkeep`
   
   e. Add to `.gitignore`:
   ```
   .env.test
   e2e/qa-generated/*.spec.ts
   ```
   
   f. Create `.env.test` with placeholder:
   ```
   TEST_JWT=
   ```
   Note to user: "Fill in TEST_JWT with a long-lived (≥24h) dev token for Playwright auth tests"

11. **Initialize memory** (two files, two roles — mirror the global `~/.claude/memory/` split):
   - Create `.claude/memory/lessons-learned.md` (empty template) — the **raw inbox**. `/retro`
     appends session learnings here. **NOT** imported into CLAUDE.md (unpromoted/noisy — keeping it
     out keeps always-on context lean).
   - Create `.claude/memory/patterns.md` (empty template) — the **promoted store**. `/reflect` writes
     confirmed project-specific patterns here. This is the file the project CLAUDE.md `@import`s
     (Step 2), so promoted patterns auto-load into `/prd` / `/rplan` / `/build`. Seed it with a
     header comment: `# Project Learned Patterns` + `> Promoted by /reflect from lessons-learned.md.
     Auto-loaded via CLAUDE.md. Raw notes live in lessons-learned.md.`

12. **Verify**:
    - Run a test hook to confirm it works
    - Show summary of what was created

## Tech Stack Detection

| File | Stack | Type Checker | Test Runner | Linter |
|------|-------|-------------|-------------|--------|
| pyproject.toml | Python | mypy | pytest | ruff |
| package.json | Node/TS | tsc --noEmit | vitest/jest | eslint |
| go.mod | Go | go vet | go test | golangci-lint |
| Cargo.toml | Rust | cargo check | cargo test | clippy |
