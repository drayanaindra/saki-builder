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

8. **Initialize memory**:
   - Create .claude/memory/lessons-learned.md (empty template)

9. **Verify**:
   - Run a test hook to confirm it works
   - Show summary of what was created

## Tech Stack Detection

| File | Stack | Type Checker | Test Runner | Linter |
|------|-------|-------------|-------------|--------|
| pyproject.toml | Python | mypy | pytest | ruff |
| package.json | Node/TS | tsc --noEmit | vitest/jest | eslint |
| go.mod | Go | go vet | go test | golangci-lint |
| Cargo.toml | Rust | cargo check | cargo test | clippy |
