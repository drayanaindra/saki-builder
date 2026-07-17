# Execution Protocol

## Overview

Every non-trivial task follows: **RESEARCH > PLAN > ANNOTATE > EXECUTE > VERIFY > LEARN**

Trivial tasks (typo fix, single-line change) can skip to EXECUTE with inline confirmation.

---

## Phase 1: RESEARCH (read-only)

- Use planner subagent or plan mode
- Read all relevant files before proposing changes
- Write findings to `tasks/[task]-context.md` (NOT in chat)
- Output: context file with file paths, current behavior, relevant patterns

## Phase 2: PLAN (structured)

- Use plan template at `~/.claude/skills/rplan/template.md`
- Build the Blocking Evidence Set, count unknowns, declare branch points
- Write to `tasks/[task]-plan.md`
- Output: plan file ready for human annotation

### Readiness (Blocking Evidence Set)

The gate is a boolean over cited evidence, not a threshold over a score.

```
Readiness = the Blocking Evidence Set is EMPTY.
```

A **blocking item** is a binary, cited predicate that must be resolved before the plan is presentable:
an anchor reference that does not grep, a target with no creating step, an open MED/HIGH unknown, an
uncovered failure path on a state-changing step, an unchecked completeness item on a state-changing step,
a missing Concrete Example, or **an uncited capability claim** (see below). Everything else (cosmetic gaps
on LOW steps, polish) is **Advisory** — visible, never gating. Momentum reads as the blocking-item count
falling (5 → 2 → 0), not as a rising %.

**Probe before claiming absence.** "I don't have tool X" is a blocking item like any other and needs a
citation — an unprobed capability claim is uncited, and therefore invalid. Run the ladder, cheapest first:

| # | Probe | Command |
| - | ----- | ------- |
| 1 | Tool deferred, not absent — most `mcp__*` tools load on demand | `ToolSearch` |
| 2 | CLI on PATH — the terminal covers most of what a missing MCP would | `command -v gh` |
| 3 | Installable — a missing binary is a LOW-tier action, not a blocker | `brew install …` / `npx …` |
| 4 | Env present — test presence, **never print the value** (Secrets rule) | `[ -n "$VAR" ] && echo set` |

Only a probe-negative earns `BLOCKED:`, and it must name the probe that failed:

```
BLOCKED: N8N_API_KEY unset ([ -n "$N8N_API_KEY" ] → empty)
```

not "I don't have n8n access".

| State                                            | Action                                                     |
| ------------------------------------------------ | ---------------------------------------------------------- |
| Blocking Set empty                               | Present plan, proceed after approval                       |
| Blocking Set non-empty                           | Resolve each cited blocking item, re-check — do NOT present |
| Item not reducible to a binary yes/no + citation | It is Advisory, not Blocking                               |
| No Evidence Ledger                               | Unscored — return to research                              |

### Unknown Threshold

- Max 3 unknowns before plan can be presented
- Each unknown must have a resolution strategy
- LOW unknowns can be auto-resolved by reading files
- MED/HIGH unknowns require human input

## Phase 3: ANNOTATE (human loop)

- Human adds corrections, context, constraints to plan file
- Claude revises plan and re-checks the Blocking Evidence Set
- Repeat 1-6 cycles until the Blocking Set is empty AND unknowns <= 3
- Gate: DO NOT proceed to execute without explicit approval

## Phase 4: EXECUTE (autonomous within guardrails)

- Implement from approved plan
- Mark completed steps in plan file
- Pause at pre-declared branch points
- Hooks enforce quality (typecheck, lint) automatically

### Branch Points

When hitting unexpected state mid-execution, **earn the handoff** — a handoff is legitimate only once the
resolvable path is exhausted. **Decide implementation. Escalate intent.** Three states, not two — the old
A/B/C menu existed because there was no state between "decide" and "quit":

| State | When | Form |
| ----- | ---- | ---- |
| **Decide** | Reversible, implementation-shaped. The fork is derivable from code, criteria, or a stated lean. | Resolve, record, keep going |
| **Pause** | Irreversible (HIGH tier) or intent-shaped. Not derivable from any file. | ONE specific question; resumes on answer |
| **Block** | Only way forward crosses a guardrail (Non-Goal / `🔒 INVARIANT` / ABSOLUTE NO-GO). | `BLOCKED: <reason>` |

**Decide** — resolve with the first rule that applies, then record it:

1. Take the stated lean/default (plan, PRD, spec recommendation).
2. Else serve the current acceptance criteria.
3. Else YAGNI + reversibility — simplest, cheapest to undo. A wrong-but-reversible call costs a refactor,
   not a baked-in architecture.

```
AUTO-RESOLVED: <question> → <decision> — <one-line why>
```

**Pause** — never an A/B/C menu. State the situation, ask the one question that unblocks, and stop:

```
BRANCH POINT - Step [N] of [M]

Situation: [what happened that wasn't in the plan]
Tried:     [what you attempted before asking — required; an unattempted blocker is not earned]
Question:  [the ONE thing only a human can answer]
```

A pause is not a give-up: no `BLOCKED:`, no abandonment — work resumes the moment the human answers.
`/build` automates this via its `NEEDS_DECISION:` sentinel (see `/build` step 0a); an attended session
just asks in chat.

**Never probe around a refusal.** A denied permission, a missing credential, and interactive auth are
genuine human handoffs — re-routing a denied tool call through Bash is circumvention, not resolution.

Reference implementation: `/build` step 0b.

### Risk Tiers

| Risk | Examples                                                | Behavior           |
| ---- | ------------------------------------------------------- | ------------------ |
| LOW  | Read file, run lint, run test, edit known file          | Auto-approve       |
| MED  | New file, API change, multi-file edit                   | Plan gate required |
| HIGH | DB migration, auth/security change, delete, push, CI/CD | Human gate ALWAYS  |

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

| Command     | Purpose                                     | When to Use                                                                                                                               |
| ----------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `/rplan`    | Structured planning with an evidence-based readiness gate | Before any non-trivial task (2+ files, new feature, API change, architecture decision)                                       |
| `/retro`    | Session retrospective, capture learnings    | End of substantial sessions. Auto-reminded by Stop hook. Run when: corrections happened, non-obvious discovery, or session > 30min coding |
| `/reflect`  | Cross-project pattern promotion             | Weekly (Friday), or when lessons-learned.md has 5+ unreviewed entries                                                                     |
| `/init-env` | Scaffold environment for new project        | First time in a project with no `.claude/agents/` or `.claude/settings.json`                                                              |

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
|   |-- Plan (Blocking Set, unknowns, branch points)
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

| Situation                                            | Command               | Skip?                                           |
| ---------------------------------------------------- | --------------------- | ----------------------------------------------- |
| Multi-file feature                                   | `/rplan`              | Never skip                                      |
| Single typo/color fix                                | none                  | Always skip                                     |
| Add model field (model + migration + API + frontend) | `/rplan`              | No — 4 files                                    |
| Question about code                                  | none                  | No implementation                               |
| Refactor cross-cutting concern                       | `/rplan`              | Never skip                                      |
| Session had corrections                              | `/retro`              | Never skip — corrections = high-value learnings |
| Quick 5-min Q&A session                              | skip `/retro`         | No implementation happened                      |
| Any HIGH risk (DB, auth, delete, push)               | `/rplan` + human gate | Never skip                                      |

## XP Session Lifecycle

XP practices are embedded into the workflow skills. This section describes how they flow through a session.

### XP-Enhanced Session Flow

```
START SESSION
|
+-- Trivial task ---------- Just do it. No /rplan, no TDD needed.
|   (typo, 1-line fix)
|
+-- Non-trivial task ------ /rplan (XP-enhanced)
|   |
|   |-- Research (read-only, spike subagents for unknowns)
|   |-- Plan (each step: Test field, Committable flag, YAGNI check)
|   |-- Annotate (human reviews, 1-6 cycles)
|   |-- /approved (XP implementation mode):
|   |   |
|   |   FOR EACH STEP:
|   |   |-- SPEC   → Read step + determine TDD mode
|   |   |-- RED    → Write failing test (Test-First only)
|   |   |-- GREEN  → Minimum code to pass (YAGNI enforced)
|   |   |-- REFACTOR → Metrics-triggered cleanup
|   |   |-- COMMIT → Run full suite + commit step
|   |   +-- NEXT
|   |
|   |-- /qa (acceptance criteria verification — mandatory)
|   |-- /reviewer (fresh-context code review)
|   +-- Verify (human final review)
|
+-- End of session -------- /retro (captures XP metrics: tests first, YAGNI catches, refactors)
|
+-- Weekly ---------------- /reflect
```

### TDD Mode Decision Matrix

| Step touches... | TDD Mode | Who writes test? |
|----------------|----------|-----------------|
| Domain rules, calculations, business logic | Test-First | AI from spec (human reviews) |
| CRUD, handlers, wiring, infrastructure | Test-Along | AI interleaves test + code |
| Config, migration, rename, trivial | Test-After | Run existing suite |
| Auth, payment, multi-tenant security | Human-Test-First | Human writes/approves test |

### YAGNI Decision Framework

Ask these in order for every new function/struct/file:
1. Is this in the current plan step? No → CUT
2. Will code break without it right now? No → CUT
3. Same effort to add later vs now? Yes → DEFER
4. Will deferring create a breaking change? Yes → KEEP

### Pair Programming Protocol

| Situation | AI behavior |
|-----------|------------|
| Implementation violates YAGNI | Push back: "This adds X which isn't in the plan step" |
| No tests for changed code | Push back: "This needs a test before implementation" |
| HIGH risk tier change | Push back: "This is HIGH risk — let's review" |
| Simpler approach exists | Suggest alternative before implementing |
| Human made deliberate decision | Just implement — repeated pushback = friction |

### Refactoring Triggers (metrics-based, not arbitrary)

| Metric | Threshold | Action |
|--------|-----------|--------|
| Go file LOC | > 300 | Split into focused files |
| Go function LOC | > 40 | Extract helper functions |
| TSX file LOC | > 500 | Split component |
| Duplication | 3+ same pattern | Extract shared helper |
| Cyclomatic complexity | > 10 | Simplify conditionals |

Rule: Never refactor untested code. Write characterization tests first.

### Sustainable Pace

- Context window = cognitive energy
- Session sweet spot: 60-90 minutes focused, then `/clear` or break
- After 2 failed attempts at same problem → `/clear` and reframe
- Plan files survive context clearing — they are your "memory" between clears

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
