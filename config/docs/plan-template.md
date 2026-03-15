# Plan Template

Use this format for all non-trivial execution plans.

---

```markdown
# EXECUTION PLAN: [task name]

**Date:** YYYY-MM-DD
**Confidence:** [X]%
**Risk Score:** LOW / MED / HIGH
**Unknown Count:** [N] / 2 max

## Problem Statement

When [situation], I want to [action], so I can [outcome].

---

## Steps

| # | Action | Files (exact paths) | Risk | Assumption |
|---|--------|---------------------|------|------------|
| 1 | | | LOW/MED/HIGH | |
| 2 | | | | |

> Rule: Each "Action" cell must name the exact function/method being added or changed.
> No vague steps like "update frontend" or "add endpoint".

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
Confidence Gate: [ ] All checklist items checked  [ ] Confidence >= 96%  [ ] Unknowns <= 2
```
