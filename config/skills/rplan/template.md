# Plan Template

Use this format for all non-trivial execution plans.

---

```markdown
# EXECUTION PLAN: [task name]

**Date:** YYYY-MM-DD
**Confidence:** [X]%
**Risk Score:** LOW / MED / HIGH
**Unknown Count:** [N] / 2 max
**Behavior Spec:** `[task]-flow.md` (user-facing) | N/A (backend-only)
**Source PRD:** `tasks/prd-[feature].md` § slice N | N/A (standalone)
**Appetite:** ~[N] agent tasks (from PRD slice) — recut if step count exceeds this
**Kill-if:** [§5 metric] crosses [threshold] (from PRD slice) | N/A

## Problem Statement

When [situation], I want to [action], so I can [outcome].

---

## Concrete Example Output

A real, specific example of what "done" looks like — not a description.
Required before this plan can reach 96% confidence.

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

## Migration Checklist

List every DB schema change and its migration.

| Change | Table | Column/Index | Migration File | alembic Command |
|--------|-------|--------------|----------------|-----------------|
| Add field X | table_name | column_name (type) | `migrations/versions/xxxx_desc.py` | `alembic revision --autogenerate -m "desc"` |

- [ ] `alembic upgrade head` listed in success criteria
- [ ] No destructive column drops without backup step
- [ ] Rollback: `alembic downgrade -1` is safe (verified)

---

## Branch Points (pre-declared)

- Step N: If [condition] → PAUSE (reason, wait for human)
- Step M: If [condition] → auto-handle with [approach]

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

All items must be checked before confidence can reach 96%.

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

**Plan Wiring**
- [ ] Every major flow has end-to-end call chain written out
- [ ] No step uses vague verbs without exact file+function
- [ ] No "update frontend" without naming file and function

---

## Confidence Ledger

The score in the header is `100 − sum(Δ)` from the rows below. A plan without a ledger is **unscored** (treated as <70%).

**Format:**

| Δ | Step | Reason | Evidence |
|---|------|--------|----------|
| -5 | 7 | Anchor `OrderService.split_batch` does not grep (HIGH-risk, ×2 of -2.5 base) | `grep -r split_batch backend/app/services` → no match |
| -3 | — | Checklist item "Mobile/responsive noted" unchecked | this plan, Implementation Checklist § Frontend |
| -8 | 9 | Migration file `xxxx_add_batch_id.py` named but not created (HIGH-risk, ×2 of -4 base) | no creating step in plan |

**Rules:**
- Every entry MUST cite evidence (`path:line`, grep result, or step number). Uncited deductions are invalid.
- `Step` column: write `—` for ledger-wide issues (missing role, vague global criteria).
- Apply the risk multiplier in your head; the `Δ` column is the final value subtracted (LOW=×1, MED=×1.5, HIGH=×2).
- Score of 100 requires a single explicit row: `| 0 | — | All anchors verified, all targets have parents and creating steps, no unchecked items, no unknowns above LOW | self-audit |`.
- Replace the example rows above with your own. Empty or missing ledger → return to research.

**Score: 100 − [sum of Δ] = [X]%** *(matches the header)*

---

## Success Criteria

- [ ] [testable outcome — include exact command or behavior to verify]
- [ ] [testable outcome]
- [ ] `alembic upgrade head` runs without error (if migrations exist)
- [ ] All user roles can perform their expected actions (manual test checklist)

---

## Annotation Space

> Human: add notes, corrections, constraints here.
> Claude will revise plan and re-score before proceeding.

---
Status: [ ] Draft  [ ] Annotated  [ ] Approved  [ ] In Progress  [ ] Complete
Confidence Gate: [ ] Confidence Ledger present and every entry cited  [ ] All checklist items checked  [ ] Confidence >= 96%  [ ] Unknowns <= 2
```
