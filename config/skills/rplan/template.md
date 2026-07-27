# Plan Template

Use this format for all non-trivial execution plans.

---

```markdown
# EXECUTION PLAN: [task name]

**Date:** YYYY-MM-DD
**Blocking items:** [N] (must be 0 to present — see Evidence Ledger)
**Risk Score:** LOW / MED / HIGH
**Unknown Count:** [N] / 2 max
**Behavior Spec:** `tasks/[task]-flow.md` (user-facing) | N/A (backend-only)
**Source PRD:** `tasks/prd-[feature].md` § slice N | N/A (standalone)
**Prior slices:** `tasks/<prd-slug>-slice1-plan.md`, … (slices 1..N-1 read — their shipped shape wins over the PRD) | N/A — slice 1 / standalone
**Appetite:** ~[N] agent tasks (from PRD slice) — recut if step count exceeds this
**Kill-if:** [§5 metric] crosses [threshold] (from PRD slice) | N/A

## Problem Statement

When [situation], I want to [action], so I can [outcome].

---

## Concrete Example Output

A real, specific example of what "done" looks like — not a description.
Required before this plan can be presented — a Blocking item until filled.

**Format depends on work type:**
- Feature/Enhancement → user-visible behavior: input → output (paste a JSON response, screenshot caption, or exact UI text)
- Bug fix → reproduction steps + the exact wrong output today + the exact right output after fix
- Debugging → the failing case to investigate + the signal that proves the hypothesis is right or wrong

**Rejected values:** "TBD", "to be defined", "see ticket", "as discussed", anything vague.
If you cannot fill this in, run `/saki-builder:shaping-requirements` first — the problem isn't ready to plan.

```
[paste concrete example here]
```

---

## Steps

| # | Action | Files (exact paths) | Risk | Test | Committable? |
|---|--------|---------------------|------|------|-------------|
| 1 | | | LOW/MED/HIGH | [test name or "existing suite"] | Yes/No (if No, which step completes it?) |
| 2 | | | | | |

> Rule: Each "Action" cell must name the exact function/method being added or changed.
> No vague steps like "update frontend" or "add endpoint".
> **XP Rule:** Every step with business logic MUST have a Test field naming the test function to write FIRST (Red→Green→Refactor).
> **XP Rule:** Every step must be Committable=Yes, or state which subsequent step makes it committable (group as atomic commit).

---

## User Role Coverage

List every user role that interacts with this feature.

| Role | Can Do | Cannot Do | Auth Guard | UI Entry Point |
|------|--------|-----------|------------|----------------|
| Customer | | | | |
| Admin | | | | |
| Merchant | | | | (if applicable) |
| Warehouse | | | | (if applicable) |

---

## Plan Wiring

Full call chain for each major flow. Format:
`[Page/Component] → [api.ts function] → [HTTP METHOD /v1/path] → [service.function()] → [Model.field]`

### Flow 1: [name, e.g. "Customer places order"]
```
[ComponentName] (frontend/src/...)
  → apiService.methodName() (frontend/src/services/api.ts:line)
  → POST /v1/endpoint
  → router function (backend/app/api/v1/file.py:line)
  → service.function(db, user, payload) (backend/app/services/file.py:line)
  → Model.field → table_name
```

### Flow 2: [name]
```
...
```

---

## Compatibility & Consumers

Every EXISTING surface this plan changes or removes. Additive-only work → write `None — additive only`.
(The Role Coverage matrix above asks *who uses this*; this one asks *what depends on this*.)

| Changed surface (exact) | Kind | Consumers found (`grep`) | Verdict | Mitigation / step |
|---|---|---|---|---|
| [`ExampleService.method()` — replace this row] | signature | 3 (`[path:line]`, `[path:line]`, `[path:line]`) | updated in step N | step N |
| [`GET /v1/example` `status` field — replace this row] | API response | 1 (`[path:line]`) | breaks — keep old field one release | step N (expand-contract) |
| [`EXAMPLE_ENV_KEY` — replace this row] | config key | none found (grep: `grep -rn EXAMPLE_ENV_KEY .`) | none found | — |

Verdicts: `unaffected` (say which part it doesn't touch) · `updated in step N` (N must be a real step) ·
`breaks — <mitigation>` (name the shim / dual-read window / versioned field / deploy-order constraint) ·
`none found (grep: <command>)` (genuinely zero consumers — a **complete** verdict; cite the grep).
A §16 `CHANGE` row from the source PRD is always an entry here — carry its `↳ Breaks:` note in.

**Forward compatibility:** additive-only? / versioned? / tolerant-reader? / deploy-order constraint?

---

## Migration Checklist

List every DB schema change and its migration.

| Change | Table | Column/Index | Migration File | alembic Command |
|--------|-------|--------------|----------------|-----------------|
| Add field X | table_name | column_name (type) | `migrations/versions/xxxx_desc.py` | `alembic revision --autogenerate -m "desc"` |

- [ ] `alembic upgrade head` listed in success criteria
- [ ] No destructive column drops without backup step
- [ ] Rollback: `alembic downgrade -1` is safe (verified)
- [ ] Every rename / drop / new-NOT-NULL / live-table index is planned as its multi-step **expand-contract**
      sequence (add → backfill → dual-read → cutover → drop), not a single ALTER — the running app must
      work against BOTH the old and the new schema. See `safe-migrations` (loaded in rplan Step 1).

---

## Branch Points (pre-declared)

Three states — decide / pause / block (see CLAUDE.md § Branch Points). Reversible forks are decided, not presented:

- Step N: If [condition] → auto-handle with [approach] (reversible — record `AUTO-RESOLVED: <question> → <decision> — <why>`)
- Step M: If [condition] → PAUSE with ONE specific question (irreversible/HIGH-tier or intent-shaped — wait for human)
- Step P: If [condition] would cross a No-Go or `🔒 INVARIANT` → BLOCKED (never auto-resolve past a guardrail)

---

## Unknowns (must be <= 2)

1. [LOW/MED/HIGH] [description] → resolution: [strategy]
2. ...

---

## No-Gos

- Will NOT [explicit boundary]
- Will NOT [explicit boundary]

---

## Implementation Completeness Checklist

Any unchecked item on a state-changing step is a **Blocking** item; unchecked cosmetic items on LOW steps are Advisory. All Blocking items must be resolved before presenting.

**User Coverage**
- [ ] Every role that touches this feature is in the Role Coverage matrix
- [ ] Each role has full call chain in Plan Wiring
- [ ] Permission/auth check listed for each role
- [ ] Edge cases per role documented

**Database & Migrations**
- [ ] Every model field change has a migration row in Migration Checklist
- [ ] `alembic upgrade head` in success criteria
- [ ] No breaking change without rollback strategy

**API Layer**
- [ ] Request schema (Pydantic) named and file path given
- [ ] Response schema named and file path given
- [ ] HTTP method, path, router file written out
- [ ] Dependencies listed (`CurrentUser`, `CurrentAdmin`, `DB`)

**Service / Business Logic**
- [ ] Every service function modified/created named with file path
- [ ] Side effects listed (email, webhook, background task, cache)
- [ ] Error paths documented (404, 403, 422, 500)

**Frontend**
- [ ] Every page/component that changes named with file path
- [ ] API service call written out (function name + file)
- [ ] Loading, error, empty states handled
- [ ] Mobile/responsive noted if UI changes

**Compatibility & Consumers**
- [ ] Compatibility & Consumers filled — every changed/removed existing surface has enumerated consumers + a verdict, every `breaks` verdict has a mitigation step, forward-compat answered — **OR** the section reads `None — additive only`
- [ ] Prior slices 1..N-1 read (slice plans only) — or `N/A — slice 1 / standalone`

**Plan Wiring**
- [ ] Every major flow has end-to-end call chain written out
- [ ] No step uses vague verbs without exact file+function
- [ ] No "update frontend" without naming file and function

---

## Evidence Ledger

Readiness is a boolean: the plan is presentable when the **Blocking** table is empty. A plan without an
Evidence Ledger is **unscored** — return to research. There is no percentage; the Blocking count is the signal.

### Blocking (must be empty to present — each row a binary, cited predicate)

| # | Step | Blocking predicate (unresolved) | Evidence |
|---|------|---------------------------------|----------|
| B1 | 7 | Anchor `OrderService.split_batch` does not grep | `grep -r split_batch backend/app/services` → no match |
| B2 | 9 | Migration file `xxxx_add_batch_id.py` named but has no creating step | no creating step in plan |

### Advisory (visible, never gates)

| Step | Note | Evidence |
|------|------|----------|
| 3 | Mobile/responsive not noted (LOW, cosmetic) | this plan, Implementation Checklist § Frontend |

**Rules:**
- Every Blocking row MUST cite evidence (`path:line`, grep result, or step number). An uncited row is invalid — resolve it or move it to Advisory.
- **Blocking vs Advisory is decided by the step's risk, not by a weight:** an unresolved gap on a HIGH-risk or state-changing step is Blocking; the same gap on a LOW cosmetic step is Advisory. If you can't reduce an item to a binary yes/no + citation, it's Advisory.
- `Step` column: write `—` for ledger-wide items (missing role, vague global criteria).
- A ready plan shows an **empty Blocking table** plus one attestation row in Advisory: `| — | All anchors verified, all targets have creating steps, no unchecked items on state-changing steps, no unknowns above LOW | self-audit |`.
- Replace the example rows above with your own. Empty or missing ledger → return to research.

**Blocking: [N] → READY when 0.**

---

## Success Criteria

- [ ] [testable outcome — include exact command or behavior to verify]
- [ ] [testable outcome]
- [ ] `alembic upgrade head` runs without error (if migrations exist)
- [ ] All user roles can perform their expected actions (manual test checklist)

---

## Annotation Space

> Human: add notes, corrections, constraints here.
> Claude will revise plan and re-check the Blocking Set before proceeding.

---
Status: [ ] Draft  [ ] Annotated  [ ] Approved  [ ] In Progress  [ ] Complete
Readiness Gate: [ ] Evidence Ledger present and every blocking item cited  [ ] Blocking Set empty  [ ] Unknowns <= 2
```
