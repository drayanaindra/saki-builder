# EXECUTION PLAN: Autonomous /prd-review (option 3 — one shared loop)

**Date:** 2026-07-05
**Blocking items:** 0 (see Evidence Ledger)
**Risk Score:** MED
**Unknown Count:** 1 / 2 max
**Behavior Spec:** N/A (tooling/skill-config — no app UI; behavior captured in Success Criteria)
**Source PRD:** N/A (standalone — config/tooling change to the saki-builder plugin)
**Appetite:** ~7 agent tasks (5 edits + 1 new hook + 1 test) — within band; no recut
**Kill-if:** N/A (no product metric — this is dev tooling)

## Problem Statement

When I have a PRD I want driven to green, I want `/prd-review` to loop autonomously (review → apply the prescribed fixes → re-review) instead of doing one pass and stopping, so I can reach a shippable PRD hands-off without going through `/pickup` (which requires a roadmap epic). `/pickup` should reuse this one loop, not keep its own copy.

---

## Concrete Example Output

**Autonomous (default) — `/saki-builder:prd-review tasks/prd-instant-payout.md`:**

```
--- PRD LOADED ---  (round 1)
PHASE 1 PASSED …
--- REVIEW COMPLETE ---  Verdict: REVISE · Readiness: NOT READY — R3 fixable (missing concurrent-debit criterion, §8 Slice 3)
AUTONOMOUS: applying 2 prescribed fixes to tasks/prd-instant-payout.md (round 1 → 2)…

--- REVIEW COMPLETE ---  (round 2)  Verdict: SHIP · Readiness: READY · Failure-surface 3/3
PRD_REVIEW_GREEN: instant-payout — SHIP · READY · 2 rounds · 2 blockers fixed
✅ PRD green: tasks/prd-instant-payout.md   (review record: tasks/prd-instant-payout-review.md)
```

State file `tasks/.prd-review-instant-payout-state.json` ends at `"phase":"green"`; the Stop hook allows the stop. A non-convergent PRD instead ends `"phase":"blocked"` and prints `PRD_REVIEW_BLOCKED: <slug> — <reason>`.

**Escape hatch — `/saki-builder:prd-review tasks/prd-x.md --review-only`:** exactly today's behavior — one pass, prints the synthesis + `--- REVIEW COMPLETE ---`, writes NO state file, never edits the PRD, stops.

---

## Steps

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 1 | Add **Step 0 arg-parse**: parse `--review-only` from ARGUMENTS; state that autonomous is the default mode. Update the frontmatter `description` + the top invariant note (§8 + Rules) so "never edits the PRD" scopes to the **review core / `--review-only`**, not autonomous mode. | `config/skills/prd-review/SKILL.md` (Step 0 @ `:45-66`; frontmatter `:3`; invariant `:8`, Rules `:427-463`) | LOW | manual read | Yes |
| 2 | Add **Phase 5 — Autonomous loop (default)** after Phase 4 (`:400-423`). Wraps the review core (Phases 1–4): init state file → each round run core inline → read verdict/readiness from the `--- REVIEW COMPLETE ---` block (`:403`) with `<!-- review-verdict -->` (`:337`) fallback → branch (green / fixable / blocked). Fix list + 3-round cap + BLOCKED escape lifted from `pickup/SKILL.md:135-149`. Emit `PRD_REVIEW_GREEN` / `PRD_REVIEW_BLOCKED` sentinels. `--review-only` skips Phase 5. | `config/skills/prd-review/SKILL.md` | MED | Success Criteria SC1–SC4 (manual dry-run) | Yes (with 1,3) |
| 3 | Add the **state-file spec** subsection to prd-review: `tasks/.prd-review-<slug>-state.json` schema + phase semantics (`reviewing`→active, `green`/`blocked`→terminal) + "write after every transition". Mirror `pickup/SKILL.md:68-93`. | `config/skills/prd-review/SKILL.md` | LOW | — | Yes (with 1,2) |
| 4 | **Create** `prd-review-completion-gate.sh` — Stop hook mirroring `pickup-completion-gate.sh`. `ACTIVE=("reviewing",)`; release on `green`/`blocked`/unknown/empty. Glob `tasks/.prd-review-*-state.json`. Progress score `ordinal(reviewing=1)+review.rounds`. Env `PRD_REVIEW_GATE_ACTIVE_MINUTES`(45)/`PRD_REVIEW_GATE_MAX_BLOCKS`(5)/`PRD_REVIEW_GATE_DISABLE`. Session-owned, fail-open, SubagentStop-safe, stale-window. Continue-reason text: "continue the autonomous review loop — apply the prescribed fixes and re-review until SHIP·READY or blocked". | `config/hooks/prd-review-completion-gate.sh` (NEW) | MED | Step 5 | Yes (with 5,6) |
| 5 | **Create** `test-prd-review-completion-gate.sh` mirroring `test-pickup-completion-gate.sh` (99 lines): `reviewing`→block; `green`/`blocked`/unknown/empty→allow; no-file/garbage→allow; subagent→allow; session ownership (A owns, B allowed, A blocked); progress breaker (`MAX_BLOCKS=1`); stale→allow. Run: `bash config/hooks/test-prd-review-completion-gate.sh`. | `config/hooks/test-prd-review-completion-gate.sh` (NEW) | LOW | self (the test) | Yes (with 4) |
| 6 | **Register** the new hook in the `Stop` array — add a third `{type:"command", command:"…/prd-review-completion-gate.sh", timeout:15}` entry after `pickup-completion-gate.sh`, in **BOTH** registration surfaces: `config/settings.json` (config owner's global, `~/.claude` symlink) **and** `config/hooks/hooks.json` (the plugin's own manifest for plugin users, via `${CLAUDE_PLUGIN_ROOT}`) — mirroring how pickup/build gates appear in both. — adjusted in impl: hooks.json was missed in the original plan (only settings.json was cited); found via plugin.json's `"hooks": "./config/hooks/hooks.json"` ref. | `config/settings.json:143-147`, `config/hooks/hooks.json:44-59` | MED | `python3 -c "import json;json.load(open('config/settings.json'));json.load(open('config/hooks/hooks.json'))"` | Yes (with 4) |
| 7 | **Rewrite `/pickup` Phase 2** to delegate: invoke `prd-review` (default autonomous) on the PRD; on `green` → set pickup `phase:"proto-ready"` + `PICKUP_READY`; on `blocked` → flip epic `In-progress→Blocked` + `PICKUP_BLOCKED`. Remove the hand-rolled fix-loop; keep pickup's state file + the "Key design note" reworded to "the loop lives in `/prd-review`; pickup reuses it". Keep the 3-round cap wording referenced (now enforced inside prd-review). | `config/skills/pickup/SKILL.md:114-155` (+ note `:153`, Rules `:191`) | MED | Success Criteria SC5 (manual dry-run) | Yes |
| 8 | **Rollout:** bump `.claude-plugin/plugin.json` `0.7.0`→`0.8.0`; add `CHANGELOG.md` `## 0.8.0` entry; commit `release(saki-builder): v0.8.0 — autonomous /prd-review loop-to-green`; publish + reinstall/update the plugin so `/saki-builder:prd-review`+`pickup` pick up the snapshot. (Hooks + settings are live via symlink already.) | `.claude-plugin/plugin.json:4`, `CHANGELOG.md:5` | LOW | `/saki-builder:prd-review --review-only` post-reinstall smoke | No → gated on 1–7 |

> Each Action names the exact file + section/line + the function/phase changed. No vague steps.

---

## Invocation-Context Coverage  (adapts "User Role Coverage" — this is tooling, not app roles)

| Context | Can Do (after change) | Guard / Behavior | Entry Point |
|---------|-----------------------|------------------|-------------|
| Human, standalone | `/prd-review <prd>` → autonomous loop to green/blocked; writes `.prd-review-<slug>-state.json`; kept alive by the new gate | 3-round cap + BLOCKED escape (no infinite loop); edits the PRD | `/saki-builder:prd-review` |
| Human, review-only | `/prd-review <prd> --review-only` → single pass, no edits, no state file | invariant preserved (never edits PRD) | `--review-only` flag |
| `/pickup` orchestrator | Phase 2 invokes autonomous `/prd-review` once; branches on terminal state | no nesting — loop lives only in prd-review; pickup gate covers `prd` phase, prd-review gate covers `reviewing` | `/saki-builder:pickup E<n>` |
| Stop hook (`prd-review-completion-gate.sh`) | blocks stop while `phase==reviewing`; releases on green/blocked/unknown; breaker caps no-progress blocks | session-owned, fail-open, subagent-safe, stale-window | global `Stop` hook |

---

## Control-Flow Wiring  (adapts "Plan Wiring")

### Flow 1: Standalone autonomous review
```
/saki-builder:prd-review tasks/prd-<slug>.md
  → prd-review SKILL Step 0: mode=autonomous (no --review-only)
  → Phase 5 loop: init tasks/.prd-review-<slug>-state.json {phase:"reviewing"}
      round r: run review core (Phase 1 structural → Phase 2 fresh judges → 2.5 → 3 synthesis → 4)
               read Verdict/Readiness from `--- REVIEW COMPLETE ---`
        green    → state{phase:"green"}  → print PRD_REVIEW_GREEN → stop
        fixable  → edit tasks/prd-<slug>.md (apply prescribed fixes) → rounds++ → re-loop (cap 3)
        blocked  → state{phase:"blocked"} → print PRD_REVIEW_BLOCKED → stop
  → prd-review-completion-gate.sh (Stop): phase=="reviewing" ? block+continue : allow
```

### Flow 2: /pickup reuses the loop
```
/saki-builder:pickup E3
  → Phase 1: /prd (author from epic)   [pickup state phase:"prd"  — pickup gate keeps alive]
  → Phase 2: invoke autonomous /prd-review tasks/prd-<slug>.md   [pickup state phase:"review"]
        (prd-review runs Flow 1; prd-review gate keeps ITS loop alive)
        prd-review terminal green   → pickup: state phase:"proto-ready" + PICKUP_READY  [pickup gate releases]
        prd-review terminal blocked → pickup: flip epic In-progress→Blocked + PICKUP_BLOCKED
```

---

## Migration Checklist

N/A — no database. This is skill-prose + a bash hook + a settings.json entry. (No schema, no `alembic`.)

---

## Branch Points (pre-declared)

- Step 7: If rewriting pickup Phase 2 reveals pickup relies on a prd-review behavior that only exists inside its old loop (e.g. reads `review.blockers_fixed` from its own state) → keep pickup writing its own `review` counters from the prd-review terminal result; do not couple to the prd-review state file. (auto-handle)
- Step 4: If the progress-score design can't distinguish "genuinely looping" from "wedged" for prd-review (only one active phase, unlike pickup's two) → score on `review.rounds` alone (rounds increment each real pass) so the breaker still fires on a stuck loop. (auto-handle)
- Step 8: If the plugin release/publish mechanism is unclear → PAUSE and confirm the release command with the human before publishing (do not guess a publish step). Hooks/settings are already live, so autonomous works in THIS repo's sessions regardless; only the packaged `/saki-builder:*` commands wait on the release.

---

## Unknowns (must be <= 2)

1. **[LOW] Exact plugin publish/reinstall command** (marketplace pulls from the git url with `autoUpdate`). Resolution: follow the existing release convention — commit `release(saki-builder): vX.Y.Z — …` (git log `c4b71e9`) + push; if a manual reinstall step is needed, confirm with the human at Step 8 (Branch Point). Non-blocking: the hook+settings changes are live via symlink, so autonomous mode is exercisable in this repo's sessions before the packaged release lands.

---

## No-Gos

- Will NOT add an `--autonomous` flag (autonomous is the default — pinned decision).
- Will NOT let the autonomous loop run unbounded — 3-round cap + BLOCKED escape + the gate's progress breaker are all mandatory.
- Will NOT change the review CORE logic (Phases 1–4) or the judge prompts — Phase 5 is a pure wrapper; judges stay fresh subagents.
- Will NOT generalize/rename `pickup-completion-gate.sh` — a dedicated gate mirrors the build/pickup precedent.
- Will NOT fabricate grounding or auto-run `/proto` from any of these paths.
- Will NOT have the autonomous loop edit the PRD in `--review-only` mode (invariant preserved there).

---

## Implementation Completeness Checklist

**Invocation-Context Coverage** (adapted)
- [x] Every invocation context listed (standalone, review-only, pickup, Stop hook) — Coverage matrix
- [x] Each context's control-flow traced end-to-end — Wiring Flows 1–2
- [x] Guard listed per context (3-round cap / invariant / no-nesting / fail-open)
- [x] Edge cases documented (non-convergence→blocked, unknown phase→allow, subagent→no-op, stale→allow)

**Database & Migrations**
- [x] N/A — no schema change (stated in Migration Checklist)

**API / Contract Layer** (adapted: skill invocation contracts + hook I/O)
- [x] New skill arg `--review-only` named + parsed (Step 1)
- [x] State-file schema named + located `tasks/.prd-review-<slug>-state.json` (Step 3)
- [x] Hook stdin/stdout contract: reads session JSON, prints `{"decision":"block","reason":…}` or nothing (Step 4)
- [x] Stop-hook registration path + timeout given (Step 6)

**Service / Logic**
- [x] Every changed section named with file path (Steps 1–3 prd-review; Step 7 pickup)
- [x] Side effects listed (writes state file; edits the PRD file in autonomous mode; flips epic status in pickup)
- [x] Failure paths documented (Phase 1 FAIL / REVISE / NOT READY-fixable → fix; DISCOVERY-FIRST / structural-NOT-READY / non-convergence → blocked; gate fail-open on missing/garbage/no-python3)

**Frontend**
- [x] N/A — no UI

**Plan Wiring**
- [x] Both flows have end-to-end chains (Wiring)
- [x] No vague verbs — every step names file + section/line + phase/function
- [x] No "update skill" without naming the section/lines

---

## Evidence Ledger

### Blocking (must be empty to present)

| # | Step | Blocking predicate (unresolved) | Evidence |
|---|------|---------------------------------|----------|
| — | — | *(none)* | — |

### Advisory (visible, never gates)

| Step | Note | Evidence |
|------|------|----------|
| 8 | Exact plugin publish command unconfirmed (LOW) — Branch Point pauses before guessing | Unknown #1; `git log c4b71e9` shows the release-commit convention |
| 7 | pickup's `review.blockers_fixed` counter now sourced from prd-review's terminal result, not its own loop | Branch Point (Step 7); `pickup/SKILL.md:84` |
| — | All anchors verified (prd-review `:45,:403,:337,:8`; pickup `:114-155,:68-93`; settings `:135-149`; plugin.json `:4`), all targets (2 new hook files) have creating steps (4,5) + anchor parent `config/hooks/`, no unchecked items on state-changing steps, no unknowns above LOW | self-audit |

**Blocking: 0 → READY.**

---

## Success Criteria

- [ ] **SC1** — `/saki-builder:prd-review <green-prd> ` (autonomous) writes `tasks/.prd-review-<slug>-state.json` with `"phase":"green"` and prints `PRD_REVIEW_GREEN` on a PRD that's already SHIP·READY (one pass, zero edits). Verify: file check + grep the sentinel.
- [ ] **SC2** — On a fixable-REVISE PRD, autonomous mode edits the PRD, bumps `review.rounds`, re-reviews, and reaches `"phase":"green"` within ≤3 rounds. Verify: diff shows the prescribed fix applied; state file `review.rounds` ≥ 1.
- [ ] **SC3** — On a DISCOVERY-FIRST / structural-NOT-READY PRD, autonomous mode stops at `"phase":"blocked"` + prints `PRD_REVIEW_BLOCKED` (no infinite loop). Verify: grep sentinel; state phase.
- [ ] **SC4** — `--review-only` runs one pass, writes NO `.prd-review-*` state file, does NOT modify the PRD. Verify: `git diff --stat` on the PRD is empty; no state file created.
- [ ] **SC5** — `/saki-builder:pickup E<n>` reaches `proto-ready` via the delegated loop (no double-loop); on non-convergence flips the epic to `Blocked`. Verify: pickup state phase; epic status in `tasks/roadmap.md`.
- [x] **SC6** — `bash config/hooks/test-prd-review-completion-gate.sh` exits 0 (**PASS=13 FAIL=0**), covering: reviewing→block, green/blocked/unknown/empty→allow, no-file/garbage→allow, subagent→allow, ownership, breaker, stale.
- [x] **SC7** — JSON valid for `config/settings.json` + `config/hooks/hooks.json` + `.claude-plugin/plugin.json`; **both** Stop arrays list 3 gates including `prd-review-completion-gate.sh`.
- [x] **SC8** — `bash config/hooks/test-pickup-completion-gate.sh` still exits 0 (**PASS=14 FAIL=0**, no regression).

**SC1–SC5 are deferred to post-reinstall manual QA** (the behavioral loop on a real PRD). They CANNOT be exercised via `/saki-builder:prd-review` until the plugin is reinstalled at v0.8.0 — the command runs the version-pinned 0.7.0 snapshot until then.

---

## Annotation Space

> Human: add notes, corrections, constraints here.

---
Status: [x] Draft  [ ] Annotated  [x] Approved  [x] In Progress  [ ] Complete (code done; SC1–SC5 behavioral QA deferred to plugin reinstall at v0.8.0)
Readiness Gate: [x] Evidence Ledger present and every blocking item cited  [x] Blocking Set empty  [x] Unknowns <= 2
