# Global Development Environment

## Execution Protocol (BLOCKING)

For non-trivial tasks: use `/rplan` before implementing. The skill handles research → plan → readiness gate.
Trivial (typo, 1-line fix) → execute directly.
Full reference (phases, examples, decision matrix): `~/.claude/docs/execution-protocol-detail.md` — load on demand only.

**Core rules:**

1. NEVER implement without a structured plan first (unless trivial or user says "skip workflow")
2. State Model/Task/Role/Status at response start for non-trivial responses (planning, implementing, multi-step). Skip for trivial replies and acknowledgments.
3. NEVER assume — read code, verify, test assumptions
4. NEVER include subagent findings in a plan without verifying key claims (especially bug reports) by reading the actual code — subagents misread patterns and flag correct APIs as bugs
5. Write plans to files (`tasks/[task]-plan.md`), NOT chat — they survive context clearing
6. NEVER rebuild what already exists or is owned — before designing, verify against canonical source (git/board/STATUS/existing code), not summaries. Owned by someone → advisory, not rebuild

## Response Header

Format: `Model: [OPUS/SONNET/HAIKU] | Task: [...] | Role: [...] | Status: [Reading/Planning/Implementing/Testing/Complete]`.

Required for: non-trivial responses (planning, implementing, multi-step work, role/status transitions).
Skip for: trivial replies, acknowledgments ("ok", "got it"), short clarifying questions, single-line status updates.

## Readiness Gate

Do NOT execute until: the **Blocking Evidence Set is empty** (every blocking item resolved, each with a citation), Unknowns ≤ 3, human approves. A blocking item is a binary, cited predicate — an unverified anchor, an open MED/HIGH unknown, an uncovered failure path on a state-changing step. There is no percentage to clear: the gate is "no blocking item stands," and momentum reads as the blocking-item count falling to 0.

## Risk Tiers

| LOW (auto)       | MED (plan gate)      | HIGH (human gate always)         |
| ---------------- | -------------------- | -------------------------------- |
| Read, lint, test | New file, API change | DB migration, auth, delete, push |

## Pre-merge Gate (BLOCKING)

Before `git push` to main, two PreToolUse:Bash hooks must both pass:

**1. SonarQube quality gate must be PASSED** — `sonar-gate.sh`. If blocked:

1. `/sonarqube:sonar-quality-gate` — see which conditions are failing
2. `/sonarqube:sonar-list-issues` — see blocking issues
3. Fix, re-run analysis, verify gate is PASSED, then push

**2. Test coverage must be > 80%** — `coverage-gate.sh` (strict: exactly 80.0% blocks).
Reads the last coverage report an earlier test run / `/qa` produced (Jest/Vitest
`coverage-summary.json`, Cobertura `coverage.xml`, `lcov.info`, or Go `coverage.out`)
and blocks the push unless total coverage is strictly above the floor. Threshold is
`COVERAGE_MIN` (default 80). No report found → warns and allows (set `COVERAGE_STRICT=1`
to require one). If blocked: `/qa` to add tests and re-check the floor, then push.

To bypass either (intentional, documented reason only): run `git push` manually outside Claude Code.

## Clean Code Standards (write-time, SonarQube)

Write code that passes the gate the first time — don't write then fix. The gate grades your **diff**
(Clean as You Code), so apply this to every line you touch. Top gate-blockers, always-on:

- **Reliability**: null-check before deref (`if x is not None:`, not `if x:`); always close resources (`with`/`defer`/try-with-resources); check error returns; cover every switch/enum case.
- **Security**: no hardcoded secrets; parameterize SQL/shell (no string-concat injection); validate external input at the boundary; strong crypto only (no MD5/SHA-1/DES/ECB).
- **Maintainability**: cognitive complexity ≤ 15, function ≤ 40 LOC, params ≤ 7; DRY (extract at 3rd repeat, < 3% duplication); guard clauses over deep nesting; named constants over magic numbers; no dead/commented-out code; never swallow exceptions; new-code coverage ≥ 80%, **non-negotiable** (SonarQube gate) — `/qa` enforces the same ≥ 80% floor locally before push (`COVERAGE_MIN`, clamped — no lowering, no spike bypass), so coverage clears *before* the gate.

Full reference (per-quality rule list + workflow): the `/clean-code` skill (`~/.claude/skills/clean-code/SKILL.md`). `/build` auto-loads it during implementation; invoke it manually before any non-trivial code change.

## Secrets (BLOCKING)

NEVER route secrets/credentials (JWTs, API keys, tokens, passwords) through the chat — not even while debugging. When a step needs a token: read responses via the browser Network tab, run an in-page Console snippet that uses the token in place, or act server-side. Paste only non-secret outputs (response bodies, numeric ids/claims). If a secrets-detection hook blocks a paste, that's correct — don't disable it; use one of the local paths instead.

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
> /wrap (if the task touched git — converge to clean before moving on)
> /retro (if session was substantial)
```

Be specific ("run `pytest tests/test_users.py`" not "test it"). Show next uncompleted plan step if working from a plan. Include `/retro` after 5+ tasks or 30+ min. Suggest `/wrap` whenever the task reached a done state with git work outstanding (MR green / merged, commits unpushed, or a worktree still open) — it commits WIP, lands+pushes each worktree branch, removes the worktree, and returns to a clean `main`, so no work is left behind.

## Learning Loop

- `/retro` before ending long sessions
- `/reflect` weekly
- Cross-project patterns: `~/.claude/memory/patterns.md` (generic + stack-portable) — **auto-loaded** via the `@import` at the end of this file, so `/prd`, `/rplan`, `/build` and every main-thread skill recall promoted patterns with no per-skill read. (Written by `/reflect`; raw session notes live in the per-project `lessons-learned.md` inbox, which is NOT loaded.)
- Topic-specific patterns: `~/.claude/memory/patterns-<topic>.md` (e.g. `patterns-ios.md`). **Not auto-loaded** — to activate per-project, create `<project>/.claude/CLAUDE.md` with `@~/.claude/memory/patterns-<topic>.md`. Same for project-local `.claude/memory/patterns.md`: import it via the project CLAUDE.md (scaffolded by `/init-env`).

## XP Practices

Embedded in `/rplan`, `/approved`, `/qa` workflows. Full reference: `~/.claude/docs/xp-principles.md` (TDD cycle + modes, YAGNI, small releases, pair programming pushback, refactoring triggers, sustainable pace, language-specific notes).

## Context Hygiene

- `/clear` between unrelated tasks
- Delegate exploration to subagents; write findings to files, not chat
- After 2 failed corrections → `/clear` and restart with better prompt
- Session sweet spot: 60–90 min focused, then `/clear`
- Plan files survive context clearing — they are your "memory"

## Learned Patterns (auto-loaded)

Promoted cross-project patterns are imported below so they are always in context for the
planning/build pipeline. `/reflect` maintains this file; keep niche stack-specific patterns in
`patterns-<topic>.md` (NOT imported here) to keep always-on context lean.

@~/.claude/memory/patterns.md
