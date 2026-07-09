# EXECUTION PLAN: I1 · Auto-instrument PRD §5 success metrics through the pipeline

**Date:** 2026-07-09
**Blocking items:** 0 (see Evidence Ledger)
**Risk Score:** LOW  (markdown prompt-file edits only — no app code, no migration, reversible)
**Unknown Count:** 0 / 2 max
**Behavior Spec:** N/A — no app UI; the "actors" are the saki-builder skills themselves
**Source PRD:** N/A (Plan-track Improvement I1 — `tasks/roadmap.md`)
**Appetite:** ~7 edit tasks (one per pipeline seam + a validation step) — recut if it exceeds this
**Kill-if:** N/A (process improvement — no live metric to breach)

## Problem Statement

When a PRD reaches build, its §5 success metrics are **declared** (Outcome + Method) but never
**instrumented** — no downstream skill turns an event-based `Method` into an actual event-emit at a
wiring point, so at ship time the events §5 targets (and §6 Kill Criteria) depend on don't exist. I want
the pipeline to thread the instrumentation obligation through its existing seams — `/prd` names the
event, `/rplan` ingests it as a build step + criterion, `/qa` + `/reviewer` verify it fires — so metrics
declared instrumentable are actually instrumented.

---

## Concrete Example Output

PRD §5 row today:

```
| 1 | Maximize checkout completion when a cart exists | 40%→60% | baseline (analytics.csv) | count checkout_completed events | J1 |
```

**Today:** "count `checkout_completed` events" is accepted by `/prd`, then nothing in
`rplan → approved → build → qa → reviewer` ever emits or checks `checkout_completed`. Ship happens; the
event does not exist; outcome 5.1 is unmeasurable.

**After I1 — the same row flows through the seams:**

1. `/prd` §5 requires the event-class Method to name its event + trigger:
   `event: emit checkout_completed when checkout succeeds`.
2. `/rplan` Step-1 ingestion adds, automatically:
   - a **Steps** row — `Emit checkout_completed in CheckoutService.complete()` (Test-Along), and
   - a **Success Criterion** — `event checkout_completed fires exactly once on a successful checkout (→ 5.1)`.
3. `/approved` builds that step under TDD (asserts the emitter is called).
4. `/qa` classifies the criterion `EVENT`: greps the emit call at the wiring point **and** asserts the
   checkout flow-test triggers it once (not on the validation/error path, not twice on retry).
5. `/reviewer` checklist flags it if the event is declared-but-never-fired, fired on an error path, or double-emitted.

Net: the metric that was "instrumentable in theory" is emitted and verified in code.

---

## Steps

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 1 | In §5 spec, classify each `Method` as `query` (existing data — no emit) · `event` (needs a NEW emit) · `external` (outside our code); require an `event`-class Method to read `emit <event_name> when <trigger>`. Extend the §5 Outcomes prose block (the `| # | Outcome | Target | Basis | Method | JTBD |` spec at L214 and the Basis/Method notes L215–224). Add one write-time deduction row: `§5 event-class Method names no event → −3`. | `config/skills/prd/SKILL.md` (§5 block ~L214–224; deduction table L342) | LOW | `node test/validate.js` green + `grep -n "emit <event_name> when" config/skills/prd/SKILL.md` | Yes |
| 2 | Tighten the §5 review: (a) item 5 (L125) — an `event`-class Method with no named event is a finding; (b) at the "not instrumentable" / "no linking acceptance criterion" checks (L206–207) — the linking acceptance criterion for an `event`-class outcome MUST assert the event fires, not merely restate the outcome. | `config/skills/prd-review/SKILL.md` (L125, L206–207) | LOW | `node test/validate.js` green + `grep -n "event-class" config/skills/prd-review/SKILL.md` | Yes |
| 3 | **(load-bearing)** Add a Step-1 ingestion bullet after the §5-outcome-IDs bullet (L71): ingest each `event`-class §5 `Method` as BOTH (a) a **Steps** row `Emit <event_name> at <wiring point>` wired into **Plan Wiring**, and (b) a **Success Criterion** `event <name> fires when <trigger> (→ 5.x)`. Note reuse-first: emit at the wiring point already in the chain; if the event already exists (grep), assert-only, no new emit. | `config/skills/rplan/SKILL.md` (insert after L71) | LOW | `node test/validate.js` green + `grep -n "event.*class.*Method\|Emit <event_name>" config/skills/rplan/SKILL.md` | Yes |
| 4 | Add an `EVENT` row to the criterion-type table (after L202) — Signal: "criterion names an emitted event / analytics call / instrumentation point"; How to test: `grep` the emit call at the wiring point AND assert a flow/unit test triggers it (spy the emitter / assert the sink received it). Add a matching derivation row (after L240): (1) event fires exactly once — no double-emit on retry; (2) event NOT fired on the validation/error path; (3) payload carries the required fields. | `config/skills/qa/SKILL.md` (classification table L195–202; derivation table L235–240) | LOW | `node test/validate.js` green + `grep -n "\`EVENT\`" config/skills/qa/SKILL.md` | Yes |
| 5 | Add an instrumentation line to the Standard Review Checklist **Correctness** block (L176–179): "Every §5 event-based metric names an event actually emitted at its wiring point — declared-but-never-fired, fired-on-error-path, or double-emitted is a finding." | `config/skills/reviewer/SKILL.md` (Correctness block ~L176) | LOW | `node test/validate.js` green + `grep -n "event actually emitted" config/skills/reviewer/SKILL.md` | Yes |
| 6 | In the TDD-mode guidance, classify an instrumentation/emit step as **Test-Along** (write the emit + a test asserting the emitter is called, interleaved) so it isn't skipped as trivial. One line at the Test-Along row (L80) or the mode-breakdown hints (L38–39). | `config/skills/approved/SKILL.md` (L38–39 / L80) | LOW | `node test/validate.js` green + `grep -n "instrumentation\|emit step" config/skills/approved/SKILL.md` | Yes |
| 7 | Validation sweep: run `node test/validate.js` (frontmatter + `/saki-builder:*` refs intact); confirm `/prd` §1–§16 contract NOT renumbered (`grep -c '^## [0-9]' config/skills/prd/SKILL.md` unchanged vs HEAD); confirm the emit→ingest→verify chain is consistent across the 5 edited skills (the event vocabulary — "event-class Method", "emit \<event\>", "event \<name\> fires" — matches at each seam). | `test/validate.js` (run only) + all edited files (grep) | LOW | `node test/validate.js` exits 0; grep chain-consistency | Yes (final) |

> Every step is a self-contained prompt-file edit, independently committable. Steps 1→3 form the
> declare→ingest spine; if only a subset lands, the chain degrades gracefully (an un-ingested event is
> just an un-built one, same as today — no regression).

---

## Skill Wiring  (replaces app-code "Plan Wiring" — the contract this plan threads)

The instrumentation obligation is a value passed skill-to-skill. Full chain for an `event`-class metric:

```
/prd §5        emits →  Method = "event: emit <name> when <trigger>"     (Step 1)
  → /prd-review verifies the event is named + its criterion asserts it fires   (Step 2)
  → /rplan Step-1 ingests → Steps row "Emit <name> at <wiring point>"
                          + Success Criterion "event <name> fires when <trigger> (→ 5.x)"  (Step 3)
  → /approved builds the emit step under TDD (Test-Along: assert emitter called)  (Step 6)
  → /qa classifies criterion EVENT → greps emit + asserts flow-test fires it once  (Step 4)
  → /reviewer checklist: declared-but-never-fired / error-path / double-emit = finding  (Step 5)
```

`query`-class and `external`-class Methods carry no obligation (data already persisted / outside our
code) — they pass through every seam untouched. Only `event`-class produces a build step + criterion.

---

## Migration Checklist

N/A — no DB schema change. This edits skill prompt markdown only.

---

## User Role Coverage

N/A (no app roles). The "actors" are the pipeline skills; each is covered by exactly one step:
`/prd` (S1) · `/prd-review` (S2) · `/rplan` (S3) · `/qa` (S4) · `/reviewer` (S5) · `/approved` (S6),
with S7 verifying the cross-skill contract.

---

## Branch Points (pre-declared)

- Step 1: If the §5 Method column already carries any event/classification convention I missed → STOP,
  extend the existing convention instead of adding a parallel one (reuse-first). *Checked in research:
  none exists — grep for `emit`/`instrument`/`event` in `prd/SKILL.md` returns only prose, no §5 convention.*
- Step 3: If ingesting the Method as a step would collide with the existing `Assumes:`-line ingestion
  (L69) → fold the event-emit into the same "hidden build work" bullet family rather than a new mechanism.

---

## Unknowns (must be ≤ 2)

*(none — all anchors verified against the files; no external dependency)*

---

## No-Gos

- Will NOT ship an analytics backend, event bus, or metrics dashboard — this is a §6 owner-pin vs
  dashboard decision per PRD, out of scope. I1 only makes the pipeline *emit + verify* the named event.
- Will NOT define new metrics or change what §5 measures — only how an already-declared event-based
  Method becomes build work.
- Will NOT renumber PRD §1–§16 (hard contract — `/proto` & `/prd-review` reference sections by number).
- Will NOT instrument `query`-class or `external`-class Methods (no emit needed / outside our code).
- Will NOT touch the plugin cache copy (`~/.claude/plugins/cache/...`) — edit repo `config/skills/`
  only; users pull via `/saki-builder:update`.

---

## Implementation Completeness Checklist

**User Coverage** — N/A (no app roles); each pipeline skill mapped to its step above.

**Database & Migrations** — N/A (no schema change).

**API Layer** — N/A (no endpoint).

**Service / Business Logic (here: skill-prompt logic)**
- [x] Every skill file edited is named with its exact path + anchor line (Steps 1–6)
- [x] Side effects: the ingestion in Step 3 adds a Steps row + a Success Criterion (documented in Skill Wiring)
- [x] Degradation path documented (partial landing = no regression — Steps note)

**Frontend** — N/A (no UI).

**Plan Wiring (Skill Wiring)**
- [x] The emit→ingest→verify chain is written end-to-end across all 5 skills
- [x] No step uses a vague verb without the exact file + anchor line + inserted text
- [x] Reuse-first + classification (`query`/`event`/`external`) prevents over-instrumentation

---

## Evidence Ledger

### Blocking (must be empty to present)

*(empty)*

### Advisory (visible, never gates)

| Step | Note | Evidence |
|------|------|----------|
| — | All anchors verified, all targets have creating steps, no unchecked items on state-changing steps, no unknowns above LOW | self-audit |
| 7 | No automated test asserts *prompt semantics* (only structural `validate.js`) — cross-skill consistency is verified by grep, not a runtime test (inherent to prose config) | `test/validate.js` checks frontmatter + refs only |
| 3 | The value of the ingestion is only observable end-to-end on the next real PRD→build run — track first use | design note |

**Blocking: 0 → READY.**

---

## Success Criteria

- [ ] `/prd` §5 spec requires an `event`-class Method to name its event + trigger — `grep -n "emit <event_name> when" config/skills/prd/SKILL.md` returns the inserted line → 
- [ ] `/prd` write-time deduction table includes the event-not-named penalty — `grep -n "event-class Method names no event" config/skills/prd/SKILL.md` returns a match →
- [ ] `/prd-review` flags an unnamed event-class Method and requires its criterion to assert firing — `grep -n "event-class" config/skills/prd-review/SKILL.md` returns matches at the §5 checks →
- [ ] `/rplan` Step-1 ingestion emits BOTH a Steps row and a Success Criterion per event-class Method — `grep -n "Emit <event_name>\|event <name> fires" config/skills/rplan/SKILL.md` returns the inserted bullet →
- [ ] `/qa` classification table has an `EVENT` row + a derivation row — `grep -n "\`EVENT\`" config/skills/qa/SKILL.md` returns ≥2 matches (table + derivation) →
- [ ] `/reviewer` Correctness checklist has the instrumentation line — `grep -n "event actually emitted" config/skills/reviewer/SKILL.md` returns a match →
- [ ] `/approved` marks an emit/instrumentation step as Test-Along — `grep -n "instrumentation\|emit step" config/skills/approved/SKILL.md` returns a match →
- [ ] `node test/validate.js` exits 0 (frontmatter + `/saki-builder:*` references intact after all edits) →
- [ ] PRD §1–§16 contract not renumbered — `grep -c '^## [0-9]' config/skills/prd/SKILL.md` equals the pre-edit count →

---

## Annotation Space

> Human: add notes, corrections, constraints here.

---
Status: [x] Draft  [ ] Annotated  [ ] Approved  [ ] In Progress  [ ] Complete
Readiness Gate: [x] Evidence Ledger present and every blocking item cited  [x] Blocking Set empty  [x] Unknowns ≤ 2
