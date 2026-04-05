# Global Development Environment

## Execution Protocol (BLOCKING)

Follow @~/.claude/docs/execution-protocol.md for ALL non-trivial tasks.

@~/.claude/docs/playwright-qa-patterns.md

1. NEVER implement without presenting a structured plan first
2. ALWAYS state Model/Task/Role/Status at response start
3. NEVER assume - read code, verify, test assumptions
4. NEVER include subagent findings in a plan without verifying key claims (especially bug reports) by reading the actual code — subagents misread patterns and flag correct APIs as bugs
4. Write plans to files (plan.md), NOT chat — they survive context clearing

**Plan format:** @~/.claude/docs/plan-template.md

**Skip planning ONLY when:** User says "skip workflow" or task is trivial (typo, single-line).

## Response Header (required)

```
Model: [OPUS/SONNET/HAIKU]
Task: [What I'm doing]
Role: [Role name]
Status: [Reading/Planning/Implementing/Testing/Complete]
```

Compact for trivial tasks: `Role: Engineer | Task: Fix null check | Status: Complete`

## Confidence Gate

Present plan with confidence score. Do NOT execute until:
- Confidence >= 90%
- Unknowns <= 3
- Human approves

## Risk Tiers

| LOW (auto) | MED (plan gate) | HIGH (human gate always) |
|------------|-----------------|--------------------------|
| Read, lint, test | New file, API change | DB migration, auth, delete, push |

## Branch Points

When unexpected state during execution:
- State the situation, options (A/B/C), recommendation
- Default to safest option if no response

## Learning Loop

- Run `/retro` before ending long sessions
- Run `/reflect` weekly to promote patterns globally
- Check ~/.claude/memory/patterns.md for cross-project learnings

## Role Skills

Roles defined in ~/.claude/skills/. Activate by switching role context.
Key roles: Product, Architect, Engineer, Reviewer, QA, DevOps, Security.

## Next Actions (BLOCKING — after EVERY completed task)

ALWAYS end with a "Next Actions" block after completing any task:
```
--- DONE ---
Completed: [1-line summary]

Next actions:
> [most logical next step]
> [alternative]
> /retro (if session was substantial)
```
- If working from a plan, show next uncompleted step
- If task revealed a new issue, suggest addressing it
- Be specific: "Run `pytest tests/test_users.py`" not "test it"
- After 5+ tasks or 30+ min, always include `/retro`

## Python Async Rules

- **Always use `except BaseException` in startup/lifespan safety nets**, never `except Exception`. `CancelledError` is `BaseException` in Python 3.8+ and silently escapes `except Exception`, crashing async servers (FastAPI, uvicorn, etc.) at startup. Applies to: lifespan handlers, reconnect loops, background task wrappers.

## Context Hygiene

- /clear between unrelated tasks
- Delegate exploration to subagents
- Write findings to files, not chat
- After 2 failed corrections -> /clear and restart with better prompt
