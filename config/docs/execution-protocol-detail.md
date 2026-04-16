# Execution Protocol

## Overview

Every non-trivial task follows: **RESEARCH > PLAN > ANNOTATE > EXECUTE > VERIFY > LEARN**

Trivial tasks (typo fix, single-line change) can skip to EXECUTE with inline confirmation.

---

## Phase 1: RESEARCH (read-only)

- Use planner subagent or plan mode
- Read all relevant files before proposing changes
- Write findings to `[task]-context.md` in project root (NOT in chat)
- Output: context file with file paths, current behavior, relevant patterns

## Phase 2: PLAN (structured)

- Use plan template (@~/.claude/docs/plan-template.md)
- Score confidence, count unknowns, declare branch points
- Write to `[task]-plan.md` in project root
- Output: plan file ready for human annotation

### Confidence Scoring

```
Score = (steps_with_no_unknowns / total_steps) * 100
Weighted: HIGH-risk steps count 2x, MED-risk steps count 1.5x
```

| Score | Action |
|-------|--------|
| >= 90% | Present plan, proceed after approval |
| 70-89% | Resolve unknowns first, then re-score |
| < 70% | More research needed, do NOT present plan yet |

### Unknown Threshold

- Max 3 unknowns before plan can be presented
- Each unknown must have a resolution strategy
- LOW unknowns can be auto-resolved by reading files
- MED/HIGH unknowns require human input

## Phase 3: ANNOTATE (human loop)

- Human adds corrections, context, constraints to plan file
- Claude revises plan and re-scores confidence
- Repeat 1-6 cycles until confidence >= 90% AND unknowns <= 3
- Gate: DO NOT proceed to execute without explicit approval

## Phase 4: EXECUTE (autonomous within guardrails)

- Implement from approved plan
- Mark completed steps in plan file
- Pause at pre-declared branch points
- Hooks enforce quality (typecheck, lint) automatically

### Branch Points

When hitting unexpected state mid-execution:

```
BRANCH POINT - Step [N] of [M]

Situation: [what happened that wasn't in the plan]
Options:
  A. [safest option] (recommended)
  B. [alternative]
  C. Pause - you decide

Default if no response: Option A
```

### Risk Tiers

| Risk | Examples | Behavior |
|------|----------|----------|
| LOW | Read file, run lint, run test, edit known file | Auto-approve |
| MED | New file, API change, multi-file edit | Plan gate required |
| HIGH | DB migration, auth/security change, delete, push, CI/CD | Human gate ALWAYS |

## Phase 5: VERIFY (deterministic + human)

- Run tests (hook-enforced before commit)
- Type check (hook-enforced after edit)
- Use reviewer subagent in fresh context for non-trivial changes
- Human final review before merge/push

## Phase 6: LEARN (session end)

- Run `/retro` before ending long sessions
- Captures: corrections made, assumptions that were wrong, patterns that worked
- Writes to project memory (`lessons-learned.md`)
- Periodically run `/reflect` to promote confirmed patterns to global config

---

## Command Reference

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/rplan` | Structured planning with confidence scoring | Before any non-trivial task (2+ files, new feature, API change, architecture decision) |
| `/retro` | Session retrospective, capture learnings | End of substantial sessions. Auto-reminded by Stop hook. Run when: corrections happened, non-obvious discovery, or session > 30min coding |
| `/reflect` | Cross-project pattern promotion | Weekly (Friday), or when lessons-learned.md has 5+ unreviewed entries |
| `/init-env` | Scaffold environment for new project | First time in a project with no `.claude/agents/` or `.claude/settings.json` |

## Session Flow

```
START SESSION
|
+-- New project? ---------- /init-env "project description"
|
+-- Trivial task ---------- Just do it. No /plan needed.
|   (typo, 1-line fix)
|
+-- Non-trivial task ------ /plan
|   |-- Research (read-only, planner subagent)
|   |-- Plan (confidence score, unknowns, branch points)
|   |-- Annotate (human reviews, 1-6 cycles)
|   |-- Execute (autonomous within hooks)
|   |-- Branch point? ----- Pause, present options, wait
|   +-- Verify (tests, reviewer subagent, human review)
|
+-- End of session -------- /retro (Stop hook reminds you)
|
+-- Weekly ---------------- /reflect
```

## Decision Matrix

| Situation | Command | Skip? |
|-----------|---------|-------|
| Multi-file feature | `/rplan` | Never skip |
| Single typo/color fix | none | Always skip |
| Add model field (model + migration + API + frontend) | `/rplan` | No — 4 files |
| Question about code | none | No implementation |
| Refactor cross-cutting concern | `/rplan` | Never skip |
| Session had corrections | `/retro` | Never skip — corrections = high-value learnings |
| Quick 5-min Q&A session | skip `/retro` | No implementation happened |
| Any HIGH risk (DB, auth, delete, push) | `/rplan` + human gate | Never skip |

## Quick Rules

- 2+ files touched = `/rplan`
- Any HIGH risk = `/rplan` + human gate ALWAYS
- Got corrected = `/retro` before ending
- New project = `/init-env` once
- Weekly = `/reflect` once

---

## Next Action Prompt (BLOCKING — must show after every completed task)

After finishing ANY task (trivial or complex), ALWAYS end with a "Next Actions" block:

```
--- DONE ---
Completed: [1-line summary of what was done]

Next actions:
> [most logical next step based on what just happened]
> [alternative if user wants to shift focus]
> /retro (if session was substantial)
```

### Rules for Next Actions

1. ALWAYS suggest the most logical continuation — don't make user think about what's next
2. Be specific: "Run `npm test` to verify" not "test it"
3. If task was part of a plan, show the next uncompleted step from the plan
4. If task revealed a new issue, suggest addressing it
5. If nothing obvious follows, suggest: verify/test, commit, or start next task
6. If session has been long (5+ tasks or 30+ min), include `/retro` as an option

### Examples

After a bug fix:
```
--- DONE ---
Completed: Fixed null check in api/users.py:45

Next actions:
> Run `cd backend && poetry run pytest tests/test_users.py -v` to verify
> Commit this fix
```

After implementing a plan step:
```
--- DONE ---
Completed: Step 3/5 — Added migration for user groups table

Next actions:
> Step 4/5 — Update API endpoints to use new groups model
> Review migration with `alembic history` before proceeding
```

After a research/discussion session:
```
--- DONE ---
Completed: Researched auth architecture options

Next actions:
> /plan to create structured implementation plan
> Write findings to docs/auth-research.md for team review
```

After final task in a session:
```
--- DONE ---
Completed: All 5 plan steps implemented and tested

Next actions:
> Use reviewer subagent for fresh-context code review
> Commit and create PR
> /retro to capture session learnings
```
