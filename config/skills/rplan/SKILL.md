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

## Step 0.5: Scope Clarification (Prompt Expander)

Before researching, check if the user's prompt has clear scope. If ANY of these are ambiguous or missing, ask:

```
Sebelum mulai, quick scope check:

Siapa?    [who uses this feature — which user roles?]
Kapan?    [what triggers it — when/how does it start?]
Hasilnya? [one concrete example of expected behavior]
Batasnya? [what to skip / not include in this scope]
```

**Rules:**
- If the user already provided enough context (all 4 are inferable), skip — do NOT ask
- Accept terse answers (1-2 words per question is fine)
- If user says "kamu yang tentukan" or similar, make reasonable defaults and state them explicitly so user can correct
- Once answered, summarize scope in one sentence before proceeding to research

**Examples of when to skip:**
- User: "add batch tracking to inventory. warehouse staff only, saat terima barang, FEFO otomatis, skip manufacturing" — all 4 answered, proceed
- User: "fix the login bug on /masuk page" — trivial/bug fix, no scope questions needed

**Examples of when to ask:**
- User: "add reporting feature" — who sees it? what data? which reports?
- User: "add payment integration" — which roles? which payment provider? what flows?

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
- [ ] Migration file name and `migrate` command written out explicitly
- [ ] `migrate up` step listed in success criteria
- [ ] No breaking schema changes without a rollback strategy

**API Layer**
- [ ] Request/response structs named and located (Go structs or TS types)
- [ ] HTTP method, path, and router file written out
- [ ] Middleware/auth dependencies listed

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
3. Is every migration change explicitly listed with the `migrate` command?
4. Is every call chain wired end-to-end in the Plan Wiring section?
5. Are success criteria testable without ambiguity?

If any answer is "No" → fix the plan before presenting.

### 6. Self-Review (built-in domain checks)

**Run BEFORE presenting the plan. This replaces /rplan-review for LOW/MED risk plans.**

Walk through the plan and check each item below. For each violation found, fix it in the plan immediately — do not just flag it.

#### 6a. Deterministic Checklist (always run)

| # | Check | What to look for |
|---|-------|-----------------|
| 1 | Vague steps | Any step saying "update", "add", "modify" without exact file path + function name → rewrite |
| 2 | Missing file paths | Any reference to a file without full path from project root → add path |
| 3 | Schema completeness | Any API endpoint without request/response struct named → add it |
| 4 | Auth guards | Any endpoint missing permission/middleware specification → add it |
| 5 | Error paths | Any service function without error cases listed → add 404/403/422 |
| 6 | Empty states | Any new UI page without empty state behavior → add it |
| 7 | Wiring gaps | Any flow that stops at "API endpoint" without tracing to service + DB → complete the chain |

#### 6b. Project-Aware Checks (detect from project context)

If the project uses multi-tenancy (RLS, tenant isolation):
- Every DB-touching step must mention tenant context/guard

If the project has atomic operations (POS, checkout, payment):
- Every multi-table write must mention transaction boundary

If the project has a design system:
- Every new UI component must reference design tokens/system

If the project has localization:
- Every UI copy must be in the correct language

#### 6c. Lightweight Domain Spot-Check (HIGH-risk plans only)

**Only run this sub-step if the plan's overall Risk Score is HIGH** (contains DB migration, auth change, payment logic, or multi-tenant security change).

Spawn a single combined reviewer agent with this prompt:

```
You are reviewing a plan for [project name]. Check for:
1. [Backend language] patterns: missing error handling, wrong function signatures, missing context propagation
2. Security: missing auth checks, data isolation gaps, SQL injection risks
3. Frontend: missing states (loading/error/empty), type safety gaps
4. Product: missing user roles, untestable criteria, missing edge cases

Report ONLY blockers (things that would cause bugs or security issues).
Keep it under 200 words. No warnings, no style nits.

Plan:
[paste full plan text]
```

If the spot-check finds blockers, fix them in the plan before presenting.

#### 6d. Re-score After Self-Review

Recalculate confidence after all fixes. The self-review should have resolved most checklist gaps.

### 7. Output with Next Action Recommendation

- Write full plan to `[task]-plan.md` in project root
- Present plan summary in chat with:
  - Confidence score
  - Risk level
  - Self-review results (what was caught and fixed)
  - **Next action recommendation** (see below)

#### Next Action Decision Tree

```
If confidence >= 96% AND risk is LOW/MED AND self-review found 0 blockers:
  → "Plan ready. /approved to start implementation."

If confidence >= 96% AND risk is HIGH:
  → "Plan ready but HIGH risk. Recommend /rplan-review for expert validation, or /approved if you're confident."

If confidence 90-95%:
  → "Confidence at [X]%. Gaps: [list]. Recommend /rplan-review to identify remaining issues."

If confidence < 90%:
  → "Confidence too low ([X]%). Need your input on: [specific questions]"
```

**Print the recommendation clearly:**

```
--- PLAN COMPLETE ---
Confidence: [X]%
Risk: LOW / MED / HIGH
Self-review: [N] issues found and fixed, [N] blockers remaining

Recommendation: [one of the above]
> /approved    — start implementation
> /rplan-review — expert validation (recommended for HIGH risk)
> [specific questions if confidence < 90%]
```

---

## Rules

- NEVER skip research phase
- NEVER skip Step 0.5 scope check (but DO skip asking if scope is already clear)
- NEVER skip Step 6 self-review
- NEVER present a plan with > 2 unknowns
- NEVER proceed to implementation without explicit approval
- NEVER write "update X" in a step — always name the exact file, function, and change
- NEVER omit a user role that interacts with the feature
- NEVER omit a migration step if schema changes
- If confidence < 96% after self-review, fix gaps — do NOT lower the bar
