---
name: init-env
description: Scaffold the Claude Code development environment for a new project. Creates CLAUDE.md, hooks, agents, and project structure.
disable-model-invocation: true
---

# Initialize Project Environment

Set up the Claude Code production development environment for this project: $ARGUMENTS

## Invocation modes

Detect the mode from `$ARGUMENTS` and the repo, then follow the matching rule for Step 1:

- **Interactive (default)** — a human ran `/saki-builder:init-env`. Ask for project name, business context, key
  constraints as normal.
- **Non-interactive / PRD-driven** — `$ARGUMENTS` contains a path to a PRD (e.g.
  `tasks/prd-*.md` / `docs/prd/**/prd.md`), OR no `$ARGUMENTS` were given but a `tasks/prd-*.md`
  exists in the repo. This happens when a tool (e.g. pipeline-studio) runs `/saki-builder:init-env` headless in a
  SINGLE turn before a build. In this mode you have **no human to ask** and **one turn to finish** —
  so do NOT run the full 14-step Process below. Instead run this **LEAN, BOUNDED scaffold** and
  complete ALL of it before stopping:

  > **Headless scaffold — do every item, in order, then STOP. You are NOT done until
  > `.claude/.env-init.json` exists AND you have committed.** Do not pause, do not ask, do not
  > narrate alternatives — just create the files.
  >
  > 0. Read the PRD; DERIVE project name, business context, constraints, and **tech stack** from it
  >    (TL;DR / problem / JTBD / any stack notes). For an empty repo with no stack files, infer the
  >    stack from the PRD ("a Next.js app" → Node/TS). Default anything unstated; never prompt.
  >    If an existing `.claude/` is FOREIGN, back it up first (see Step 1 backup rule).
  > 1. `CLAUDE.md` (lean, <100 lines) — Step 2 below, but skip the interactive "ask user" parts.
  > 2. `.claude/agents/reviewer.md` and `.claude/agents/qa.md` — Steps 6–7 below (these are what
  >    `/saki-builder:build` invokes). Also `.claude/agents/planner.md` (Step 5).
  > 3. `.claude/memory/patterns.md` and `.claude/memory/lessons-learned.md` — Step 11 below (the
  >    `@import` target + raw inbox).
  > 4. The marker `.claude/.env-init.json` — Step 12 below (config MUST be `$HOME`).
  > 5. Self-commit — Step 14 below (`git add` only the created paths + `commit --no-verify`).
  >
  > **Deliberately SKIP in headless mode** (heavier / better done interactively later; and the hooks
  > would interfere with the autonomous build that runs right after): `.claude/settings.json` hooks
  > (Step 4), `docs/project-context.md` (Step 3), `.claude/hooks/` scripts (Step 8), skill overrides
  > (Step 9), Playwright infra (Step 10), the product roadmap (Step 11b). The operator can run
  > `/saki-builder:init-env` interactively later to add these.

## Process

1. **Detect project context**:
   - Read package.json, pyproject.toml, go.mod, Cargo.toml to detect tech stack
   - Check for existing CLAUDE.md, .claude/ directory
   - Identify test framework, linter, type checker
   - **Interactive mode:** ask user for project name, business context, key constraints.
     **Non-interactive / PRD-driven mode:** derive all of these from the PRD (see "Invocation modes") — do NOT ask.
   - **If an existing `.claude/` is FOREIGN** (present but `.claude/.env-init.json` is missing or its
     `config` ≠ this machine's `$HOME` — i.e. it came from another saki-builder install, so its `@import`
     paths / hook scripts / agents won't resolve here): back it up FIRST —
     `ts=$(date +%Y%m%d-%H%M%S); mv .claude ".claude.bak-$ts"; [ -f CLAUDE.md ] && mv CLAUDE.md "CLAUDE.md.bak-$ts"` —
     then scaffold fresh below. Never overwrite a foreign `.claude/` in place.

2. **Create project CLAUDE.md** (lean, <100 lines):
   - Project identity and business context
   - Tech stack and key commands Claude can't guess
   - @import global execution protocol
   - @import DDD patterns: `@~/.claude/docs/ddd-patterns.md`
   - @import modular architecture: `@~/.claude/docs/modular-architecture.md`
   - @import project-local learned patterns: `@.claude/memory/patterns.md` — the promoted store for THIS repo (created in Step 11). Auto-loads project-specific patterns so `/saki-builder:prd`/`/saki-builder:rplan`/`/saki-builder:build` recall them. Do NOT import `lessons-learned.md` (raw inbox — keeps context lean).
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
   - This agent is invoked by Claude programmatically (not by user via /saki-builder:qa)
   - Usage by orchestrator Claude: `Agent(subagent_type="qa", prompt="Verify criteria for: [task]. Plan: [path]")`

8. **Create .claude/hooks/ scripts** (if needed):
   - protect-files.sh (block edits to .env, lock files — project-specific patterns)
   - pre-commit-check.sh (run tests before commit)
   - NOTE: `dangerous-command-guard.sh` is already active globally via the saki-builder plugin.
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

   Optionally create `.claude/skills/prd-review/SKILL.md` as a project override when the repo
   has domain-specific judges or a house style. Use the global as the base structure and:
   - Replace the four judge prompts with project-specific lenses (domain metric model, house JTBD style)
   - Keep Phase 1's executable-criteria gate (`[auto]`/`[manual]` tag, invariant failure-path) and
     the Phase 3 manual-test checklist unchanged — both are project-agnostic and load-bearing
   - Document the project's `[auto]` verification commands (curl base URL, test runner) so the
     manual-test checklist cleanly separates from what `/saki-builder:qa` will automate

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
   - Create `.claude/memory/lessons-learned.md` (empty template) — the **raw inbox**. `/saki-builder:retro`
     appends session learnings here. **NOT** imported into CLAUDE.md (unpromoted/noisy — keeping it
     out keeps always-on context lean).
   - Create `.claude/memory/patterns.md` (empty template) — the **promoted store**. `/saki-builder:reflect` writes
     confirmed project-specific patterns here. This is the file the project CLAUDE.md `@import`s
     (Step 2), so promoted patterns auto-load into `/saki-builder:prd` / `/saki-builder:rplan` / `/saki-builder:build`. Seed it with a
     header comment: `# Project Learned Patterns` + `> Promoted by /saki-builder:reflect from lessons-learned.md.
     Auto-loaded via CLAUDE.md. Raw notes live in lessons-learned.md.`

11b. **Offer the product roadmap** (INTERACTIVE mode only — SKIP in headless/PRD-driven mode):
    disciplined product work starts from a roadmap of epics. Ask once:
    `Set up a product roadmap now? It's how features get started — /saki-builder:pickup only works on an
    epic that's on the roadmap. (y/n)`
    - **y** → scaffold `tasks/roadmap.md` via `/saki-builder:roadmap init` (ask for the product name, default
      the repo name), then offer to add the first 1–3 epics with `/saki-builder:epic`. Don't force it — one
      epic is enough to demonstrate the flow; the rest can be added later.
    - **n** → skip; note the operator can run `/saki-builder:roadmap init` + `/saki-builder:epic` anytime. Do not
      block init on this.

12. **Write the init marker** `.claude/.env-init.json` — the durable "this repo's Claude env was
    initialized by THIS config" stamp that tools use to detect env state. Write exactly:
    ```bash
    cat > .claude/.env-init.json <<EOF
    {
      "tool": "pipeline-studio-init-env",
      "config": "$HOME",
      "version": 1,
      "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
    EOF
    ```
    `config` MUST be the literal value of `$HOME` so a repo carrying a marker from another machine/config
    reads as FOREIGN (its `config` won't match this `$HOME`).

13. **Verify**:
    - Run a test hook to confirm it works
    - Show summary of what was created

14. **Non-interactive / PRD-driven mode only — self-commit the env** so the repo is clean before any
    downstream build branches:
    - Stage ONLY the paths this skill ACTUALLY created (never `git add -A` — don't sweep unrelated/
      concurrent edits; and never name a path you didn't create — `git add` of a missing pathspec
      exits non-zero and stages nothing, breaking the commit). For the LEAN headless scaffold that is
      exactly: `git add CLAUDE.md .claude`. (Only add `docs/project-context.md` / `e2e` / `.env.test`
      etc. if a fuller scaffold actually created them — they are SKIPPED in lean headless mode.)
    - Commit with the hook bypass so the just-installed pre-commit test hook can't block a project
      that has no tests yet: `git -c commit.gpgsign=false commit --no-verify -m "chore(claude-env): initialize Claude environment"`.
    - (Interactive mode: leave the changes unstaged for the human to review/commit — do NOT self-commit.)

## Tech Stack Detection

| File | Stack | Type Checker | Test Runner | Linter |
|------|-------|-------------|-------------|--------|
| pyproject.toml | Python | mypy | pytest | ruff |
| package.json | Node/TS | tsc --noEmit | vitest/jest | eslint |
| go.mod | Go | go vet | go test | golangci-lint |
| Cargo.toml | Rust | cargo check | cargo test | clippy |
