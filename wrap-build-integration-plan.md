# Plan — Integrate `/wrap` into `/build` with auto-heal

**Goal:** `/build` converges to a clean `main` at the end by calling `/wrap` in a new
autonomous **`--heal`** mode, where each Definition-of-Done gate failure is auto-fixed and
re-run (instead of `/wrap`'s default fail-stop), under a 3-strike honesty backstop.

**Decisions (user, 2026-07-06):**
- Scope = **full converge to main** (DoD-heal → commit → push → remove worktree → switch to main).
- Implement now.

## Core clash being resolved
- `/wrap` = fail-stop (any DoD gate fails → stop + print fix command).
- `/build` = TRUST MODE (auto-resolve, loop until green, 3-strike backstop).
- Naively appending `/wrap` would break `/build`'s "run to completion" contract. Fix: a `--heal`
  mode on `/wrap` that routes each DoD failure to the shallowest healing skill (mirrors build step 5.5).

## Auto-heal routing (DoD gate → shallowest fix)
| Gate | Route |
|---|---|
| 1a Build | `/approved` (TDD red) |
| 1b Tests | trace to slice → `/approved` |
| 1c Coverage <floor | `/qa` on files wrap listed below floor |
| 1d-i Deps CVE | bump/replace in place; Sonar dep-risk gate is backstop |
| 1e Migration unpaired | write `.down.sql` via `/approved` |
| 1f SonarQube FAILED | `sonar-list-issues` → `sonar-fix-issue` → re-analyze |
| 1d-ii Secret in diff | placeholder → scrub to env; **real secret → hard-stop (human only)** |

3-strike backstop: same gate fails same way ~3× → `BLOCKED: DoD/<gate>` → no converge, no fake-green.

## Edits
1. **`config/skills/wrap/SKILL.md`**
   - Intro: add a "Two modes" line.
   - New `## Autonomous heal mode (--heal)` section (routing table + 3-strike backstop) before Phase 1.
   - Phase 1 heading line: under `--heal`, route+re-run instead of stop (real secret always stops).
   - Safe-stops: note DoD rows become heal-routes under `--heal` (except secret).
   - Rules: one bullet.
2. **`config/skills/build/SKILL.md`**
   - Intro chain + Completion-signal bullet: add the converge step.
   - New `## FINAL GATE 2: Converge to clean (/saki-builder:wrap --heal)` after the e2e gate.
   - Completion Output: add `Converge:` line; next-action → open PR from pushed branch, on clean main.
   - Rules: one bullet.

## Activation caveat
Editing these files does NOT live-update `/saki-builder:*` — the plugin loads a version-pinned
snapshot. A plugin release + reinstall is required for the change to take effect.

## Verification
- Re-read both edited sections for internal consistency (no contradiction between Safe-stops and heal mode).
- Confirm `PRD_BUILD_COMPLETE` now gated behind FINAL GATE 2 in build.
