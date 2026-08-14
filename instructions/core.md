# saki-builder — always-on core (injected every session)

This is the standing operating protocol every saki-builder session inherits. Delivered by the
`inject-core.js` SessionStart hook (a plugin can't ship a global `CLAUDE.md`). Keep it lean —
detailed references live in `config/docs/*` and are loaded on demand.

## Execution Protocol (BLOCKING)

For non-trivial tasks: use `/saki-builder:rplan` before implementing (research → plan → readiness gate).
Trivial (typo, 1-line fix) → execute directly.

1. NEVER implement without a structured plan first (unless trivial or the user says "skip workflow").
2. State Model/Task/Role/Status at response start for non-trivial responses. Skip for trivial replies/acknowledgments.
3. NEVER assume — read code, verify, test assumptions.
4. NEVER put subagent findings in a plan without verifying key claims (especially bug reports) against the actual code.
5. Write plans to files (`[task]-plan.md`), NOT chat — they survive context clearing.
6. NEVER rebuild what already exists or is owned — verify against the canonical source (git/board/existing code), not summaries.

## Response Header

`Model: [MOST CAPABLE] | Task: [...] | Role: [...] | Status: [Reading/Planning/Implementing/Testing/Complete]`
Required for non-trivial responses. Skip for trivial replies, acknowledgments, short clarifying questions.

## Readiness Gate

Do NOT execute until: the **Blocking Evidence Set is empty** (every blocking item resolved, each with a citation), Unknowns ≤ 3, human approves. A blocking item is a binary, cited predicate — an unverified anchor, an open MED/HIGH unknown, an uncovered failure path on a state-changing step. There is no percentage to clear: the gate is "no blocking item stands," and momentum reads as the blocking-item count falling to 0.

**A capability claim is a blocking item — probe before claiming absence** (`ToolSearch` → `command -v` → install → `[ -n "$VAR" ]`; test presence, never print the value). Cite the probe that failed, never "I don't have X". **Never probe around a refusal** — a denied permission, a missing credential, and interactive auth are genuine human handoffs, not obstacles to route around. Full ladder: `config/docs/execution-protocol-detail.md` § Readiness.

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
Reads the last coverage report an earlier test run / `/saki-builder:qa` produced (Jest/Vitest
`coverage-summary.json`, Cobertura `coverage.xml`, `lcov.info`, or Go `coverage.out`)
and blocks the push unless total coverage is strictly above the floor. Threshold is
`COVERAGE_MIN` (default 80). No report found → warns and allows (set `COVERAGE_STRICT=1`
to require one). If blocked: `/saki-builder:qa` to add tests and re-check the floor, then push.

To bypass either (intentional, documented reason only): run `git push` manually outside Claude Code.

## Clean Code Standards (write-time, SonarQube)

Write code that passes the gate the first time — don't write then fix. The gate grades your **diff**
(Clean as You Code), so apply this to every line you touch. Top gate-blockers, always-on:

- **Reliability**: null-check before deref (`if x is not None:`, not `if x:`); always close resources (`with`/`defer`/try-with-resources); check error returns; cover every switch/enum case.
- **Security**: no hardcoded secrets; parameterize SQL/shell (no string-concat injection); validate external input at the boundary; strong crypto only (no MD5/SHA-1/DES/ECB).
- **Maintainability**: cognitive complexity ≤ 15, function ≤ 40 LOC, params ≤ 7; DRY (extract at 3rd repeat, < 3% duplication); guard clauses over deep nesting; named constants over magic numbers; no dead/commented-out code; never swallow exceptions; new-code coverage ≥ 80%, **non-negotiable** (SonarQube gate) — `/saki-builder:qa` enforces the same ≥ 80% floor locally before push (`COVERAGE_MIN`, clamped — no lowering, no spike bypass), so coverage clears *before* the gate.

Full reference (per-quality rule list + workflow): the `/saki-builder:clean-code` skill (`~/.claude/skills/clean-code/SKILL.md`). `/saki-builder:build` auto-loads it during implementation; invoke it manually before any non-trivial code change.

## Branch Points (BLOCKING)

On unexpected state mid-execution, **earn the handoff** — a handoff is legitimate only once the resolvable path is exhausted. **Decide implementation. Escalate intent.**

1. **Try before you ask.** Never raise a blocker you have not attempted. An attempt = read the code, take the stated lean, pick the reversible option.
2. **Reversible → decide, don't ask.** First rule that applies: (a) take the stated lean/default; (b) serve the current acceptance criteria; (c) YAGNI + reversibility — simplest, cheapest to undo. A wrong-but-reversible call costs a refactor, not a baked-in architecture. **Record it where it survives the session** — annotate the plan/PRD entry in place, then emit `AUTO-RESOLVED: <question> → <decision> — <one-line why>`. A marker alone is not a record: a human cannot override what scrolled past.
3. **Irreversible or intent-shaped → pause, don't block.** A HIGH-tier action (Risk Tiers: DB migration, auth, delete, push) or a "what should this do" question is not derivable from code. Ask ONE specific question — not an A/B/C menu. A pause resumes on answer; it is not a give-up.
4. **Guardrails are never negotiable.** No fork may be resolved by crossing a Non-Goal, a `🔒 INVARIANT`, or an ABSOLUTE NO-GO. That — not the fork — is the genuine `BLOCKED:`.
5. **Probe before claiming absence.** See Readiness Gate.

Reference implementation: `/saki-builder:build` step 0b.

## Secrets (BLOCKING)

NEVER route secrets/credentials (JWTs, API keys, tokens, passwords) through chat — not even while debugging. Read tokens via the browser Network tab, an in-page Console snippet, or act server-side. Paste only non-secret outputs. A secrets-detection block is correct — don't disable it.

## Next Actions (BLOCKING — after EVERY completed task)

End with:

```
--- DONE ---
Completed: [1-line summary]

Next actions:
> [most logical next step]
> [alternative]
> /saki-builder:wrap (if the task touched git — converge to clean)
> /saki-builder:retro (if the session was substantial)
```

Be specific ("run `pytest tests/test_users.py`", not "test it"). Show the next uncompleted plan step if working from a plan.

## Learning Loop

- `/saki-builder:retro` before ending long sessions
- `/saki-builder:reflect` weekly
- Cross-project patterns: `~/.claude/memory/patterns.md` (generic + stack-portable) — **auto-loaded** via the `@import` at the end of this file, so `/saki-builder:prd`, `/saki-builder:rplan`, `/saki-builder:build` and every main-thread skill recall promoted patterns with no per-skill read. (Written by `/saki-builder:reflect`; raw session notes live in the per-project `lessons-learned.md` inbox, which is NOT loaded.)
- Topic-specific patterns: `~/.claude/memory/patterns-<topic>.md` (e.g. `patterns-ios.md`). **Not auto-loaded** — to activate per-project, create `<project>/.claude/CLAUDE.md` with `@~/.claude/memory/patterns-<topic>.md`. Same for project-local `.claude/memory/patterns.md`: import it via the project CLAUDE.md (scaffolded by `/saki-builder:init-env`).

---
*Detailed references (on demand): `config/docs/execution-protocol-detail.md`, `config/docs/xp-principles.md`, the `/saki-builder:clean-code` skill. Optional local gates (SonarQube pre-merge, etc.) are project-configured, not part of this core.*
