# Global Development Environment

## Execution Protocol (BLOCKING)

For non-trivial tasks: use `/rplan` before implementing. The skill handles research → plan → confidence gate.
Trivial (typo, 1-line fix) → execute directly.
Full reference (phases, examples, decision matrix): `~/.claude/docs/execution-protocol-detail.md` — load on demand only.

**Core rules:**

1. NEVER implement without a structured plan first (unless trivial or user says "skip workflow")
2. ALWAYS state Model/Task/Role/Status at response start
3. NEVER assume — read code, verify, test assumptions
4. NEVER include subagent findings in a plan without verifying key claims (especially bug reports) by reading the actual code — subagents misread patterns and flag correct APIs as bugs
5. Write plans to files (`[task]-plan.md`), NOT chat — they survive context clearing

## Response Header (required)

```
Model: [OPUS/SONNET/HAIKU]
Task: [What I'm doing]
Role: [Role name]
Status: [Reading/Planning/Implementing/Testing/Complete]
```

Compact for trivial tasks: `Role: Engineer | Task: Fix null check | Status: Complete`

## Confidence Gate

Do NOT execute until: Confidence ≥ 90%, Unknowns ≤ 3, human approves.

## Risk Tiers

| LOW (auto)       | MED (plan gate)      | HIGH (human gate always)         |
| ---------------- | -------------------- | -------------------------------- |
| Read, lint, test | New file, API change | DB migration, auth, delete, push |

## Branch Points

On unexpected state mid-execution: state situation + options (A/B/C) + recommendation. Default to safest option if no response.

## Next Actions (BLOCKING — after EVERY completed task)

End with:

```
--- DONE ---
Completed: [1-line summary]

Next actions:
> [most logical next step]
> [alternative]
> /retro (if session was substantial)
```

Rules: be specific ("run `pytest tests/test_users.py`" not "test it"); show the next uncompleted plan step if working from a plan; include `/retro` after 5+ tasks or 30+ min.

## Learning Loop

- `/retro` before ending long sessions
- `/reflect` weekly
- Cross-project patterns: `~/.claude/memory/patterns.md`

## Role Skills

Defined in `~/.claude/skills/`. Key roles: Product, Architect, Engineer, Reviewer, QA, DevOps, Security.

## Python Async Rules

- Use `except BaseException` (not `except Exception`) in startup/lifespan/reconnect-loop safety nets. `CancelledError` is `BaseException` in Python 3.8+ and silently escapes `except Exception`, crashing async servers (FastAPI, uvicorn, etc.) at startup.

## XP Core Principles (Extreme Programming)

These practices are embedded into the workflow skills (/rplan, /approved, /qa). Follow them during all implementation work.

**TDD (Test-Driven Development) — enforced by /approved:**
- Default cycle: RED (write failing test) → GREEN (minimum code to pass) → REFACTOR (clean up)
- Never skip the RED step — a test that never failed proves nothing
- Tests come from the plan's specification (success criteria), not from the implementation
- TDD modes by complexity:
  - Business logic → Test-First (write test from spec, then implement)
  - Infrastructure/CRUD → Test-Along (interleave test and code)
  - Trivial (config, rename) → Test-After (run existing suite)
  - Critical (auth, payment, multi-tenant) → Human-Test-First (human writes test, AI implements)

**YAGNI (You Ain't Gonna Need It) — enforced by /rplan self-review:**
- For each new function/struct/file, ask: "Can I delete this and still ship the current step?" If yes → cut it
- Common violations to catch: premature abstraction, unused config options, pagination before data exists, factory patterns for single-use
- When uncertain: DEFER. Adding later costs the same unless it creates a breaking change

**Small Releases — enforced by /approved:**
- Each plan step must produce a committable, working state
- Commit after each step's GREEN phase (tests pass)
- If a step cannot be committed independently, the plan needs restructuring
- Exception: migration + code that requires it = one atomic commit

**Pair Programming Protocol:**
- PUSH BACK when: implementation violates YAGNI, no tests for changed code, change is HIGH risk, simpler approach exists
- JUST IMPLEMENT when: human made deliberate decision with stated reasoning — repeated pushback on decided matters is friction

**Continuous Refactoring — metrics-triggered, not arbitrary:**
- After each GREEN, check: Go file > 300 LOC, function > 40 LOC, TSX > 500 LOC, duplication 3+ times, cyclomatic complexity > 10
- If any threshold exceeded → refactor before committing
- Never refactor untested code — write characterization tests first

**Sustainable Pace:**
- Context window = cognitive energy. `/clear` between unrelated tasks
- Session sweet spot: 60–90 minutes focused, then break or `/clear`
- After 2 failed attempts at same problem → `/clear` and reframe
- Plan files survive context clearing — they are your "memory"

## Context Hygiene

- `/clear` between unrelated tasks
- Delegate exploration to subagents
- Write findings to files, not chat
- After 2 failed corrections → `/clear` and restart with better prompt
