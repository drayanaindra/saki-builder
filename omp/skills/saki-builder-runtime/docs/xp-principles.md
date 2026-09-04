# XP Core Principles (Extreme Programming)

These practices are embedded into the workflow skills (`/saki-builder:rplan`, `/saki-builder:approved`, `/saki-builder:qa`). Follow them during all implementation work.

## TDD (Test-Driven Development) — enforced by /saki-builder:approved

- Default cycle: RED (write failing test) → GREEN (minimum code to pass) → REFACTOR (clean up)
- Never skip the RED step — a test that never failed proves nothing
- Tests come from the plan's specification (success criteria), not from the implementation
- TDD modes by complexity:
  - Business logic → Test-First (write test from spec, then implement)
  - Infrastructure/CRUD → Test-Along (interleave test and code)
  - Trivial (config, rename) → Test-After (run existing suite)
  - Critical (auth, payment, multi-tenant) → Human-Test-First (human writes test, AI implements)

## YAGNI (You Ain't Gonna Need It) — enforced by /saki-builder:rplan self-review

- For each new function/struct/file, ask: "Can I delete this and still ship the current step?" If yes → cut it
- Common violations to catch: premature abstraction, unused config options, pagination before data exists, factory patterns for single-use
- When uncertain: DEFER. Adding later costs the same unless it creates a breaking change

## Small Releases — enforced by /saki-builder:approved

- Each plan step must produce a committable, working state
- Commit after each step's GREEN phase (tests pass)
- If a step cannot be committed independently, the plan needs restructuring
- Exception: migration + code that requires it = one atomic commit

## Pair Programming Protocol

- PUSH BACK when: implementation violates YAGNI, no tests for changed code, change is HIGH risk, simpler approach exists
- JUST IMPLEMENT when: human made deliberate decision with stated reasoning — repeated pushback on decided matters is friction

## Continuous Refactoring — metrics-triggered, not arbitrary

- After each GREEN, check: Go file > 300 LOC, function > 40 LOC, TSX > 500 LOC, duplication 3+ times, cyclomatic complexity > 10
- If any threshold exceeded → refactor before committing
- Never refactor untested code — write characterization tests first

## Sustainable Pace

- Context window = cognitive energy. `/clear` between unrelated tasks
- Session sweet spot: 60–90 minutes focused, then break or `/clear`
- After 2 failed attempts at same problem → `/clear` and reframe
- Plan files survive context clearing — they are your "memory"

## Language-Specific Notes

**Python async:** Use `except BaseException` (not `except Exception`) in startup/lifespan/reconnect-loop safety nets. `CancelledError` is `BaseException` in Python 3.8+ and silently escapes `except Exception`, crashing async servers (FastAPI, uvicorn, etc.) at startup.
