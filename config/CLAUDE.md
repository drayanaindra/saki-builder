# Global Development Environment

## Execution Protocol (BLOCKING)

For non-trivial tasks: use `/rplan` before implementing. The skill handles research → plan → confidence gate.
Trivial (typo, 1-line fix) → execute directly.
Full reference (phases, examples, decision matrix): `~/.claude/docs/execution-protocol-detail.md` — load on demand only.

**Core rules:**

1. NEVER implement without a structured plan first (unless trivial or user says "skip workflow")
2. State Model/Task/Role/Status at response start for non-trivial responses (planning, implementing, multi-step). Skip for trivial replies and acknowledgments.
3. NEVER assume — read code, verify, test assumptions
4. NEVER include subagent findings in a plan without verifying key claims (especially bug reports) by reading the actual code — subagents misread patterns and flag correct APIs as bugs
5. Write plans to files (`[task]-plan.md`), NOT chat — they survive context clearing

## Response Header

Format: `Model: [OPUS/SONNET/HAIKU] | Task: [...] | Role: [...] | Status: [Reading/Planning/Implementing/Testing/Complete]`.

Required for: non-trivial responses (planning, implementing, multi-step work, role/status transitions).
Skip for: trivial replies, acknowledgments ("ok", "got it"), short clarifying questions, single-line status updates.

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

Be specific ("run `pytest tests/test_users.py`" not "test it"). Show next uncompleted plan step if working from a plan. Include `/retro` after 5+ tasks or 30+ min.

## Learning Loop

- `/retro` before ending long sessions
- `/reflect` weekly
- Cross-project patterns: `~/.claude/memory/patterns.md`

## XP Practices

Embedded in `/rplan`, `/approved`, `/qa` workflows. Full reference: `~/.claude/docs/xp-principles.md` (TDD cycle + modes, YAGNI, small releases, pair programming pushback, refactoring triggers, sustainable pace, language-specific notes).

## Context Hygiene

- `/clear` between unrelated tasks
- Delegate exploration to subagents; write findings to files, not chat
- After 2 failed corrections → `/clear` and restart with better prompt
- Session sweet spot: 60–90 min focused, then `/clear`
- Plan files survive context clearing — they are your "memory"
