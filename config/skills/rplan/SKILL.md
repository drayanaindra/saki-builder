---
name: rplan
description: Create structured execution plan with confidence scoring and risk assessment. Use for any non-trivial task before implementation.
---

# Structured Planning

## Step 0: Switch model to Opus

Run this bash command first before doing anything else:

```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude' / 'settings.json'
s = json.loads(p.read_text())
s['model'] = 'claude-opus-4-6'
p.write_text(json.dumps(s, indent=2))
print('Model set to claude-opus-4-6')
"
```

Then confirm with: `Model: OPUS | Status: Planning`

---

Create an execution plan following the template at ~/.claude/docs/plan-template.md.

## Process

### 1. Research Phase (read-only — NEVER skip)

- Read ALL files related to the task: models, schemas, services, routes, frontend pages, migrations
- Identify existing patterns, dependencies, constraints
- For each user role affected (customer, admin, merchant, warehouse staff), trace the full path:
  - What UI they see
  - What API they call
  - What service logic runs
  - What DB state changes
- Document findings in `[task]-context.md` in project root

### 2. Plan Construction

Fill in the plan template with:
- **Concrete steps** — each step names exact file paths and function names, not vague descriptions
- **Risk score per step** (LOW/MED/HIGH)
- **Assumptions** — explicit, testable
- **Branch points** — pre-declared divergence points
- **No-gos** — explicit boundaries
- **Testable success criteria**
- **User Role Coverage matrix** — who can do what after this change
- **Plan Wiring section** — full call chain from UI → API → Service → DB for each role
- **Migration Checklist** — every schema change listed with its migration file

### 3. Implementation Completeness Checklist

Before scoring confidence, verify EVERY item below. A single `[ ]` (unchecked) item blocks the plan.

**User Coverage**
- [ ] Every user role that touches this feature is listed (customer / admin / merchant / warehouse)
- [ ] Each role has full path traced: UI → endpoint → service → DB
- [ ] Permission/auth check present for each role
- [ ] Edge cases per role documented (e.g., unauthenticated, wrong role, empty state)

**Database & Migrations**
- [ ] Every model field change has a corresponding migration step in the plan
- [ ] Migration file name and `alembic revision` command written out explicitly
- [ ] `alembic upgrade head` step listed in success criteria
- [ ] No breaking schema changes without a rollback strategy

**API Layer**
- [ ] Request schema (Pydantic) named and located
- [ ] Response schema named and located
- [ ] HTTP method, path, and router file written out
- [ ] Dependency injections listed (`CurrentUser`, `CurrentAdmin`, `DB`)

**Service / Business Logic**
- [ ] Every service function modified or created is named with its file path
- [ ] Side effects listed (email, webhook, background task, cache invalidation)
- [ ] Error cases handled (404, 422, 403, 500 paths documented)

**Frontend**
- [ ] Every page/component that changes is named with file path
- [ ] API service call written out (function name in `api.ts` or service file)
- [ ] Loading, error, and empty states handled
- [ ] Mobile/responsive behavior noted if UI changes

**Plan Wiring**
- [ ] Each major flow has a written call chain: `ComponentX → apiService.methodY → POST /v1/endpoint → service.function → Model.field`
- [ ] No step that says "update frontend" without naming the exact file and function
- [ ] No step that says "add API endpoint" without naming the method, path, and schema

### 4. Confidence Scoring

```
Base score = (steps_with_zero_unknowns / total_steps) × 100
Weighted: HIGH-risk steps count 2×, MED-risk steps count 1.5×

Deductions (applied after base score):
  -3 per unchecked item in Implementation Completeness Checklist
  -5 per unresolved UNKNOWN rated MED or HIGH
  -2 per missing user role coverage
```

| Score | Action |
|-------|--------|
| >= 96% | Present plan, wait for approval |
| 90–95% | Resolve remaining checklist gaps, re-score |
| 70–89% | More research needed — do NOT present yet |
| < 70%  | Stop, write context file, ask user for direction |

**Max unknowns before presenting:** 2 (down from 3)

### 5. Pre-Present Quality Gate

Before showing the plan to the user, answer all of these:

1. Can a developer implement Step N without asking any clarifying question? (Yes for every step)
2. Are all user roles represented in the User Role Coverage matrix?
3. Is every migration change explicitly listed with the `alembic` command?
4. Is every call chain wired end-to-end in the Plan Wiring section?
5. Are success criteria testable without ambiguity?

If any answer is "No" → fix the plan before presenting.

### 6. Output

- Write full plan to `[task]-plan.md` in project root
- Present plan summary in chat with:
  - Confidence score
  - Checklist pass/fail summary
  - Any remaining unknowns
- Wait for human annotation and explicit approval

---

## Rules

- NEVER skip research phase
- NEVER present a plan with > 2 unknowns
- NEVER proceed to implementation without explicit approval
- NEVER write "update X" in a step — always name the exact file, function, and change
- NEVER omit a user role that interacts with the feature
- NEVER omit a migration step if schema changes
- If confidence < 96% after checklist, fix gaps — do NOT lower the bar
