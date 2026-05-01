---
name: rplan-review
description: Adversarial plan review — structural completeness scan, then parallel domain expert agents, then synthesis. Blocks on missing sections. Run after /rplan before /approved.
---

# Plan Review — Structural Scan + Parallel Expert Review

You are the review coordinator. Your job: verify the plan is complete and safe to implement, using domain expert agents in parallel.

There are 4 phases. Phase 1 is a hard gate — failure stops the review entirely.

---

## Step 0: Load the active plan

Find the most recent `*-plan.md` in the project root. Read it fully.

Print:
```
--- PLAN LOADED ---
File: [filename]
Initial confidence: [X]%
```

---

## Phase 1: Structural Completeness Scan

**Pass/fail only. Not probing.**

For each required section, mark ✅ PRESENT or ❌ MISSING.
A section is PRESENT only if it has real content — not headings, not "N/A", not template placeholders.

| # | Required Section | Present? | Notes |
|---|-----------------|----------|-------|
| 1 | Steps table (exact file paths + function names in every row) | | |
| 2 | User Role Coverage matrix (all affected roles listed) | | |
| 3 | Plan Wiring (end-to-end call chain per major flow) | | |
| 4 | Migration Checklist (N/A only if zero schema changes) | | |
| 5 | Implementation Completeness Checklist (all items `[x]`) | | |
| 6 | Branch Points (or explicit "none") | | |
| 7 | Success Criteria (testable, not vague) | | |

**Scan rules:**
- Steps row saying "update frontend" or "add endpoint" without exact file+function = MISSING
- Role Coverage with only one role when feature affects multiple = INCOMPLETE
- Plan Wiring with "Component → API" but no service name and no DB model = INCOMPLETE
- Checklist with any `[ ]` = INCOMPLETE

**If ALL ✅:**
```
PHASE 1 PASSED — proceeding to Phase 2
```

**If ANY ❌:**
```
PHASE 1 FAILED — STRUCTURAL BLOCKERS FOUND

The plan author must rewrite the plan. These gaps cannot be resolved by answering questions.

Missing/incomplete:
  ❌ [section]: [specific gap]

Action: Fill missing sections → re-run /rplan-review

REVIEW STOPPED.
```

Do NOT proceed to Phase 2 if Phase 1 failed.

---

## Phase 1.5: Verify Criteria Hardening (no rewriting)

**`/rplan` Step 6d performs criteria hardening. This phase only verifies it was done.**

Read the Success Criteria section. For each criterion, check it has ALL THREE:
1. **Actor + Action** — who does what
2. **Test command** — exact command to verify
3. **Expected outcome** — exact result

**If every criterion has all three (or is explicitly `🔲 MANUAL` with numbered steps + Playwright stub):**
```
PHASE 1.5 PASSED — criteria already hardened by /rplan 6d
```

**If any criterion is missing fields:**
```
PHASE 1.5 FAILED — criteria not hardened

The plan must run /rplan Step 6d hardening before review.
Unhardened: [list of criterion IDs and what's missing]

Action: Re-run /rplan to harden criteria → re-run /rplan-review
REVIEW STOPPED.
```

Do NOT rewrite criteria here. That is `/rplan`'s job; rewriting in two places drifts.

---

## Phase 2: Parallel Domain Expert Review

**Run only if Phase 1 passed.**

Detect which domains are touched by the plan, then launch the relevant expert agents in parallel using the Agent tool.

### Domain detection rules

| Domain | Launch if... |
|--------|-------------|
| Backend | any `*.go`, `*.py`, `*.ts` service/API file in steps |
| Frontend | any frontend component, page, or UI file in steps |
| UI/UX | any new page, new component, new user flow, or design system change in steps |
| Database/Security | any migration, schema, auth, or permission change in steps |
| Product | always (role coverage and acceptance criteria always apply) |

### Expert agent prompts

Launch each applicable agent with this prompt pattern. Pass the full plan text in the prompt.

**Backend Expert Agent:**
```
You are a senior backend engineer doing adversarial plan review.

Review the following plan and identify:
1. Missing error handling paths (404, 403, 422, 500)
2. API contract issues (request/response schema mismatches)
3. Service layer violations (business logic in wrong layer)
4. Missing context propagation or dependency injection
5. Race conditions or atomicity issues
6. Any step that says "add endpoint" without naming HTTP method, path, and handler file

Plan:
[paste full plan text]

Output format:
BACKEND REVIEW
Blockers: (list — each one prevents safe implementation)
Warnings: (list — non-blocking but should be addressed)
(Phase 3 will translate blockers/warnings into Confidence Ledger entries — do NOT propose a numeric adjustment.)
```

**Frontend Expert Agent:**
```
You are a senior frontend engineer doing adversarial plan review.

Review the following plan and identify:
1. Missing loading, error, and empty states for every new UI flow
2. API call wiring gaps (is the correct endpoint called? correct method?)
3. Auth state not checked before rendering protected content
4. Missing TypeScript type definitions for new data shapes
5. Component responsibilities that are too broad (god components)
6. Any step that says "update UI" without naming the exact file and component

Plan:
[paste full plan text]

Output format:
FRONTEND REVIEW
Blockers: (list)
Warnings: (list)
Confidence adjustment: [+N% or -N% per issue]
```

**Database/Security Expert Agent:**
```
You are a senior database and security engineer doing adversarial plan review.

Review the following plan and identify:
1. Migration missing a corresponding down/rollback file
2. Destructive schema changes without backup or migration strategy
3. Missing auth/permission check before sensitive operations
4. Data isolation gaps (multi-tenant: could one tenant access another's data?)
5. SQL injection or unsafe query construction risks
6. Missing transaction boundaries for atomic operations

Plan:
[paste full plan text]

Output format:
DB/SECURITY REVIEW
Blockers: (list)
Warnings: (list)
Confidence adjustment: [+N% or -N% per issue]
```

**UI/UX Expert Agent:**
```
You are a senior UI/UX designer doing adversarial plan review.

Review the following plan and identify:
1. Visual design gaps — missing spacing, typography, color, or layout decisions for new UI
2. User flow friction — steps where the user must guess, wait without feedback, or can get confused
3. Design system violations — components or patterns inconsistent with the existing design system
4. Accessibility gaps — missing ARIA roles, keyboard navigation, focus management, color contrast
5. Mobile/responsive gaps — new UI described without specifying mobile behavior
6. Interaction design gaps — missing hover, active, disabled, or transition states for interactive elements
7. Any step that says "add UI" without specifying visual behavior or referencing design system components

Plan:
[paste full plan text]

Output format:
UI/UX REVIEW
Blockers: (list — each one creates a broken or inaccessible user experience)
Warnings: (list — non-blocking but degrades UX quality)
(Phase 3 will translate blockers/warnings into Confidence Ledger entries — do NOT propose a numeric adjustment.)
```

**Product Expert Agent:**
```
You are a senior product manager doing adversarial plan review.

Review the following plan and identify:
1. User roles that interact with this feature but are missing from the Role Coverage matrix
2. Acceptance criteria that are vague or untestable ("works correctly" is not testable)
3. Flows where the user can get stuck (no error message, no empty state, no fallback)
4. Edge cases not covered: what happens if the user is unauthenticated? unauthorized? has no data?
5. UI copy that is inconsistent with the product's tone or language

Plan:
[paste full plan text]

Output format:
PRODUCT REVIEW
Blockers: (list)
Warnings: (list)
Confidence adjustment: [+N% or -N% per issue]
```

### Collect all results

Wait for all agents to return. Print each review result in full.

---

## Phase 3: Synthesis

Merge all expert findings:

1. **Deduplicate** — same issue flagged by multiple experts counts once
2. **Classify** — Blocker (must fix before /approved) vs Warning (should fix, not blocking)
3. **Extend the Confidence Ledger — do NOT overwrite the score with a formula.**

   For each blocker, append a new ledger entry to the plan file using the existing format from `/rplan` Step 4:
   - Cite evidence (`path:line`, the expert that found it, the step number it ties to)
   - Use the standard deduction from `/rplan` Step 4b (closest match, e.g. missing auth → "missing user role coverage" -3, vague step -5)
   - Apply the risk multiplier of the step the issue ties to (×1, ×1.5, ×2 per Step 4c)

   For each warning, append a ledger entry with `-1` (uncited warnings invalid), or skip if non-actionable.

   **Recompute the score** = `100 − sum(ledger)`. The score lives entirely in the ledger; ad-hoc per-expert `+/-N%` adjustments are NOT applied separately.

   If the plan has no ledger (i.e. it was scored without one), state: "PHASE 3 ABORTED — plan has no Confidence Ledger. Re-run /rplan to score with ledger first."

Print synthesis:

```
--- SYNTHESIS ---

Domains reviewed: [Backend / Frontend / DB+Security / Product]

Blockers (must fix before /approved):
  ❌ [B1] [domain]: [description]
  ❌ [B2] [domain]: [description]

Warnings (non-blocking):
  ⚠️ [W1] [domain]: [description]

Confidence: [initial]% → [final]%
```

**If blockers exist:**
```
PHASE 3 FAILED — blockers found
Fix all ❌ blockers in the plan file, then re-run /rplan-review.
```

**If no blockers, confidence > 96%:**
```
PHASE 3 PASSED — no blockers, confidence [X]% > 96%
Proceeding to Phase 4.
```

**If no blockers but confidence ≤ 96%:**
```
PHASE 3 PARTIAL — no blockers but confidence [X]% ≤ 96%
Resolve warnings or add more detail to reach 96%.
Re-run /rplan-review after updating the plan.
```

---

## Phase 4: Implementation Readiness Check

**Run only if Phase 3 passed.**

Walk every step in the plan:

| Step # | Implementable without questions? | All file paths named? | All functions named? | Pass? |
|--------|----------------------------------|-----------------------|----------------------|-------|
| 1 | | | | |
| 2 | | | | |

If any step fails: note what's missing. Do NOT approve.

If all steps pass:
```
PHASE 4 PASSED — implementation ready
```

---

## Final Verdict

```
--- REVIEW COMPLETE ---

Phase 1 (Structural):   PASSED / FAILED
Phase 2 (Expert review): PASSED / FAILED
Phase 3 (Synthesis):    PASSED / FAILED / PARTIAL
Phase 4 (Readiness):    PASSED / FAILED

Confidence: [start]% → [final]%
Blockers found: [N]
Warnings found: [N]

Verdict:
  ✅ APPROVED FOR IMPLEMENTATION
     All phases passed. Confidence [X]% > 96%.
     Next: /approved

  OR

  ❌ NOT READY
     [Phase N] failed:
     - [blocker 1]
     - [blocker 2]
     Next: Fix blockers → re-run /rplan-review
```

---

## Rules

- NEVER skip Phase 1. A structural gap is never a probe question.
- Launch expert agents in parallel — never sequentially.
- Only launch agents for domains that are actually touched by the plan.
- A blocker from any agent = plan is NOT ready, regardless of confidence score.
- "I'll handle it during implementation" = BLOCKER.
- Annotate the plan file with all resolved findings under "Annotation Space".

---

## Project Override

This is the **general version**. For project-specific domain experts (language, framework, design system), create:
```
.claude/skills/rplan-review/SKILL.md
```
That file overrides this one and should contain agents tuned to the project's stack and conventions.
Run `/init-env` to scaffold the project-specific override automatically.
