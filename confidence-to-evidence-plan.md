# EXECUTION PLAN: Migrate confidence-% gate → evidence-based (Blocking Set) gate

**Date:** 2026-07-05
**Risk Score:** MED (cross-cutting prompt/doc refactor of governance files; no DB/auth/delete/push)
**Blocking items:** 0 (must be 0 to present — see Readiness Ledger below)
**Unknown Count:** 0 / 2 max
**Behavior Spec:** N/A (governance-doc change, no runtime UI)
**Source PRD:** N/A (standalone)
**Appetite:** ~1 coordinated multi-file edit pass (concept-def → reference → template → producer → reviewer → consumers)

> This plan dogfoods the target model: it is gated on an empty **Blocking Set**, not a confidence %.

## Problem Statement

When a plan/PRD reaches its readiness gate, I want the gate to be a **boolean over cited evidence** ("is the Blocking Set empty?") instead of a **threshold over a self-assigned percentage** ("is the score ≥ 96%?"), so a single load-bearing gap can't hide behind a high number, the arithmetic can't be gamed, and momentum reads as a blocker-count trajectory (5→2→0).

---

## Concrete Example Output

**Before (rplan/SKILL.md §4d — today):**
```
| Score  | Action                          |
| >= 96% | Present plan, wait for approval |
| 90–95% | Resolve ledger items, re-score  |
| 70–89% | More research needed            |
```
A 9-step HIGH-risk plan with one unverified migration anchor (−8) scores **92%** → reads "almost ready."

**After (this change):**
```
Readiness = Blocking Set is EMPTY.
  • Blocking Set non-empty → resolve each cited item, re-check. Do NOT present.
  • An item that can't be reduced to a binary yes/no + citation → it's Advisory, not Blocking.
  • No Evidence Ledger → return to research.
```
The same plan: `Blocking Set: [1] §7 migration anchor OrderService.split_batch does not grep` → **NOT READY**, one named item to fix. No number to round up.

**Ledger shape after (template.md):**
```
## Evidence Ledger

### Blocking (must be empty to present — each row binary + cited)
| # | Step | Blocking predicate (unresolved) | Evidence |
|---|------|--------------------------------|----------|
| B1 | 7 | Anchor `OrderService.split_batch` does not grep | `grep -r split_batch backend/app/services` → no match |

### Advisory (visible, never gates)
| Step | Note | Evidence |
|------|------|----------|
| 3 | Mobile/responsive not noted (LOW, cosmetic) | Impl Checklist § Frontend |

Blocking: 1 → NOT READY.   (empty Blocking table + "all anchors verified" attestation row = READY)
```

---

## Current State (research findings — cited)

**The gate is already ~70% evidence-based; the % is vestigial scar tissue.**

- `rplan` already requires a **Confidence Ledger** where every deduction cites `path:line`/grep/step (`rplan/SKILL.md:221-285`, `template.md:167-186`). The evidence discipline exists; only the *scalar wrapper* is the problem.
- `prd-review` already emits a **signal, not a score** — `SHIP/REVISE/DISCOVERY-FIRST` + BLOCK/HIGH severities + a 5-item Readiness DoR + failure-surface coverage (`prd-review/SKILL.md:18,323,441,447`). It explicitly overrides the number: *"A BLOCK from any judge = not ready, regardless of the self-gate score"* (`:441`).
- `prd` runs a **hidden** internal `Score = 100 − Σ, gate ≥ 90` it deliberately never shows the human (`prd/SKILL.md:322,323,358,535`), and already carries a **structural floor: BLOCK regardless of score** listing which deductions are actually fatal (`:360-366`). The Blocking-Set already exists there under another name.
- The "regardless of score" veto and the **five** anti-gaming warnings (`rplan/SKILL.md:285,301,424,454,471`) are the tell: the system keeps patching around the scalar. This change removes what those patches compensate for.

**Scope-bounding facts (what makes this safe):**
- **No shell hook parses a confidence number.** `build-completion-gate.sh` / `pickup-completion-gate.sh` use a *progress* `score` (done-slices / phase-ordinal) for the circuit-breaker — unrelated (`build-completion-gate.sh:90,167`; `pickup-completion-gate.sh:65,141`). Nothing to change there.
- The only consumer of the confidence number is the **LLM reading it** (`build/SKILL.md:28,304,308`) — a prompt edit, not a parser change.
- The gate rule is injected every session from **`instructions/core.md`** via `inject-core.js:35` — must change in lockstep with `config/CLAUDE.md`.

---

## Steps

Order = concept-def → reference doc → artifact template → producer → reviewer → consumers (minimizes drift; each layer's source of truth lands before its dependents).

| # | Action | Files (exact paths) | Risk | Committable? |
|---|--------|---------------------|------|-------------|
| 1 | Rename `## Confidence Gate` → `## Readiness Gate`; replace "Confidence ≥ 90%" with "Blocking Evidence Set empty (every blocking item resolved + cited)". Edit **both copies in lockstep**. | `instructions/core.md`, `config/CLAUDE.md` | MED | Yes |
| 2 | Replace `### Confidence Scoring` formula + threshold table (≥90/70-89/<70) with the Blocking-Set definition + readiness actions; update Phase-2/3 "confidence score" mentions to "blocking set". | `config/docs/execution-protocol-detail.md` (§Confidence Scoring ~25-36, Phase 3 ~49, refs ~120) | LOW | Yes |
| 3 | Header `Confidence: [X]%` → `Blocking items: [N] (0 to present)`; rename `## Confidence Ledger` → `## Evidence Ledger` with **Blocking** + **Advisory** tables (drop `Score = 100 − sum` line + Δ-weight columns, keep mandatory Evidence column); reword "reach 96% confidence" gates in Concrete-Example + Impl-Checklist + footer Gate to "presentable / Blocking empty". | `config/skills/rplan/template.md` | LOW | Yes |
| 4 | Rewrite §4 (`Score = 100 − sum` → `Readiness = Blocking Set empty`); §4b deduction table → **Blocking-predicate classification** table (binary Blocking vs Advisory); §4c risk-multiplier → **Blocking-vs-Advisory classifier** (gap on HIGH/state-changing step = Blocking; same gap on LOW cosmetic = Advisory); §4d thresholds → readiness actions; §4e honesty rules reworded (drop "don't lower deductions" → "don't demote a Blocking item without resolving it"); §6e "recompute score" → "update the two lists"; §7 decision tree → Blocking-set-based; `name:` description + `:278` rationale note reworded. | `config/skills/rplan/SKILL.md` | MED | Yes (atomic w/ step 3) |
| 5 | Phase 3 synthesis: "Extend the Confidence Ledger … Recompute score = 100 − sum" → "Append blockers to the Blocking Set; verdict = Blocking Set empty" (promote existing `:441,445-447` "regardless of score" veto to the primary rule); verdict gates `:371-382` → Blocking-set-based; `name:` description reworded. | `config/skills/rplan-review/SKILL.md` | MED | Yes (atomic w/ step 4) |
| 6 | Replace hidden `Score = 100 − Σ, ≥90` gate with "Blocking set empty to present" using the existing BLOCK-tier + structural-floor items (`:327-366`) as the Blocking set and the `−N` items as Advisory; `prd-quality: N/100` marker → `prd-blocking: 0` (or version stamp); update `:535` anti-pattern. Keep "never show internal ledger to human" spirit. | `config/skills/prd/SKILL.md` | MED | Yes |
| 7 | Reconcile the version-pin reads (`:53,66`) to the new `prd-blocking` marker; reword "regardless of the self-gate score" (`:441`) since there's no score. (Already signal-based — light touch, no redesign.) | `config/skills/prd-review/SKILL.md` | LOW | Yes (atomic w/ step 6) |
| 8 | `build`: `:28` "clears the confidence bar" / `:304` "read … confidence score" / `:308` "confidence is below its 96% bar" → "the plan's Blocking Set is non-empty" / "read the plan's Blocking Set yourself". `approved`: rename "Confidence Ledger" → "Evidence Ledger / Blocking Set" (`:30,41,84,172`) — logic already per-entry, keep it. | `config/skills/build/SKILL.md`, `config/skills/approved/SKILL.md` | LOW | Yes |
| 9 | (Advisory-priority) Reword persona escalation heuristic "confidence drops below 90% mid-implementation" → "a blocking unknown surfaces mid-implementation". | `config/agents/product-engineer.md:142` | LOW | Yes |

> Each "Action" names the exact file + section/line. Steps 3+4, 4+5, 6+7 are grouped as atomic commits (template↔producer, producer↔reviewer, prd↔prd-review must land together to avoid a half-migrated gate).

---

## User Role Coverage

N/A — governance-doc / prompt change. No user-facing roles, endpoints, or auth surfaces. (Template section deliberately marked N/A per its backend-only allowance.)

## Plan Wiring

N/A — no runtime call chain. The "wiring" is the **concept-dependency order** captured in the Steps table (concept-def → reference → template → producer → reviewer → consumers).

## Migration Checklist

N/A — no DB schema change. (The only "migration" is the doc concept swap, tracked by the Steps table + the verification greps.)

---

## Branch Points (pre-declared)

- **Step 6:** if collapsing prd's `−N` items into Blocking/Advisory turns out to change prd↔prd-review lockstep semantics (the `:366` "keep in lockstep" clause) → PAUSE, surface the two options (promote all structural-floor items to Blocking vs keep prd's finer BLOCK list), recommend "promote structural-floor items only", wait.
- **Step 9:** persona heuristic reword is Advisory — if it reads as changing the agent's escalation contract, drop it (leave as-is) rather than expand scope.

---

## Unknowns (≤ 2)

_None above LOW._ All references classified and verified against the files during research (citations in Current State). The one external fact — plugin snapshot vs source — is resolved (see Rollout).

---

## No-Gos

- Will **NOT** touch the **80% test-coverage gate** (`coverage-gate.sh`, `qa/SKILL.md`, `clean-code`) — different gate, different concept.
- Will **NOT** touch **RICE confidence** (`product.md`), **statistical confidence intervals** (`data-analyst.md`), or **pattern-confidence HIGH/MED/LOW** (`reflect`/`retro` memory metadata) — "confidence" there is unrelated to the readiness gate.
- Will **NOT** touch the completion-gate hooks' **progress `score`** (circuit-breaker, unrelated).
- Will **NOT** invent new gate predicates — reuse the ledger/BLOCK-tier items already defined; only reclassify them as Blocking vs Advisory.
- Will **NOT** push, tag a release, or reinstall the plugin as part of this plan (surfaced as a separate rollout step for your call).

---

## Rollout / Verification (evidence-based — dogfooded)

**Blocking predicates (all must resolve before "done"):**
1. `grep -rnE "Confidence ≥|confidence.{0,6}9[06]%|Score = 100 − (sum|Σ)" config/ instructions/ | grep -v plan-history` → **0 gate-usages** remain (allowed matches: none in the changed set).
2. Each changed file has **no dangling "the score" / "re-score" / "% bar"** reference: `grep -rniE "re-score|the score|% bar|confidence bar" config/skills/{rplan,rplan-review,prd,prd-review,build,approved} instructions config/CLAUDE.md config/docs/execution-protocol-detail.md` → every hit is intentional or 0.
3. `instructions/core.md` and `config/CLAUDE.md` "Readiness Gate" sections are **byte-identical in intent** (lockstep) — diff the two sections.

**Advisory (non-gating follow-ups):**
- Note in `CHANGELOG.md` on release.
- **Plugin rollout (per `project_saki_symlink_shadows_plugin`):** `config/CLAUDE.md`, `instructions/core.md`, and `execution-protocol-detail.md` are **live immediately** for the main thread (global `@import` + SessionStart inject). The `config/skills/*` edits change the **source** but `/saki-builder:*` runs a **version-pinned plugin snapshot** — they won't take effect in the plugin until a **release + reinstall**. This plan edits the source of truth; the reinstall is a separate, explicit step you trigger.

---

## Success Criteria

- [ ] Verification greps #1–#3 above pass (0 residual gate-usages; no dangling score refs; core.md↔CLAUDE.md lockstep).
- [ ] `rplan/template.md` has an **Evidence Ledger** with Blocking + Advisory tables and no `Score = 100 − sum` line.
- [ ] `rplan/SKILL.md` §4 gates on "Blocking Set empty", not a threshold; the five anti-gaming warnings that only existed to protect the scalar are removed or reduced to the one that still applies ("don't demote a Blocking item without resolving it").
- [ ] `build/SKILL.md` reads the plan's Blocking Set, not a "96% bar".
- [ ] `prd/SKILL.md` internal gate is Blocking-set-based; `prd-review` reads the reconciled marker. `prd`↔`prd-review` still in lockstep.
- [ ] Every "confidence"/percentage left in the repo is a No-Go concept (coverage 80%, RICE, stats CI, pattern H/M/L) — verified by reading each residual grep hit.

---

## Readiness Ledger (this plan's own gate — dogfooded)

### Blocking (must be empty to present)
| # | Step | Blocking predicate (unresolved) | Evidence |
|---|------|--------------------------------|----------|
| — | — | _none_ | all files read + classified during research; no unverified anchor, no open unknown |

### Advisory (non-gating)
| Step | Note | Evidence |
|------|------|----------|
| 6 | prd Blocking/Advisory split may need the Step-6 branch-point call | `prd/SKILL.md:360-366` structural-floor clause |
| 9 | persona reword is optional polish | `product-engineer.md:142` |

**Blocking: 0 → READY to present.** (Attestation: every file reference in the Steps table was read and cited during research; no anchor unverified; no unknown above LOW; no migration/role/wiring surface applies.)

---

## Annotation Space

> Human: add corrections/constraints here. I'll revise + re-check the Blocking Set before proceeding.

---
Status: [x] Draft  [ ] Approved  [ ] In Progress  [ ] Complete
Readiness Gate: [x] Evidence Ledger present, every blocking item cited  [x] Blocking Set empty  [x] Unknowns ≤ 2
