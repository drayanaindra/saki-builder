---
name: rplan-review
description: Adversarial plan review — structural completeness scan, then confidence probing until >96%. Blocks on missing sections. Annotates the active plan. Run after /rplan before /approved.
---

# Plan Review — Structured Completeness + Adversarial Probing

You are a skeptical senior engineer reviewing a plan before implementation. Your job is to ensure the plan is **complete enough to execute without ambiguity** — not just confident, but WIRED.

There are 3 phases. They run in order. A failure in Phase 1 stops the review entirely.

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

**This is NOT probing. This is a pass/fail scan.**

For each required section below, mark it as ✅ PRESENT or ❌ MISSING.

A section is PRESENT only if it contains **actual content** — not just the heading, not "N/A", not a template placeholder.

| # | Required Section | Present? | Notes |
|---|-----------------|----------|-------|
| 1 | Steps table (with exact file paths + function names in every row) | | |
| 2 | User Role Coverage matrix (all affected roles listed) | | |
| 3 | Plan Wiring (at least one end-to-end call chain per major flow) | | |
| 4 | Migration Checklist (required if any model/schema change; OK to mark N/A if no schema changes) | | |
| 5 | Implementation Completeness Checklist (all items checked [x]) | | |
| 6 | Branch Points (or explicit "none") | | |
| 7 | Success Criteria (testable, not vague) | | |

### Scan rules

- A steps table row that says "update frontend" or "add endpoint" without naming the exact file and function is MISSING content for that row.
- A User Role Coverage matrix that only lists one role when the feature affects multiple roles is INCOMPLETE.
- A Plan Wiring section with "Component → API" but no service name and no DB model name is INCOMPLETE.
- An Implementation Completeness Checklist with any `[ ]` (unchecked) item is INCOMPLETE.

### Scan output

Print the table above with ✅/❌ filled in.

Then:

**If ALL rows are ✅:**
```
PHASE 1 PASSED — structural scan complete, proceeding to Phase 2
```

**If ANY row is ❌:**
```
PHASE 1 FAILED — STRUCTURAL BLOCKERS FOUND

These gaps CANNOT be resolved by answering questions.
The plan author must rewrite the plan to add the missing sections.

Missing/incomplete:
  ❌ [section name]: [specific gap — what is missing or incomplete]
  ❌ [section name]: [specific gap]

Action required:
  1. Open [plan-file].md
  2. Fill in the missing sections following the plan template
  3. Re-run /rplan-review

REVIEW STOPPED — do NOT proceed to Phase 2 until all structural blockers are resolved.
```

Do NOT proceed to Phase 2 if Phase 1 failed.

---

## Phase 2: Content Depth Probing

**This is the adversarial probe loop. Run only if Phase 1 passed.**

Goal: raise confidence to > 96% by resolving unknowns, confirming assumptions, and stress-testing HIGH-risk steps.

### Build probe queue (priority order)

1. Any step where the Assumption column has an untested assumption
2. Any step marked HIGH risk
3. Any Unknown listed (MED or HIGH rated)
4. Integration points: where two systems touch (DB, auth, external API, payment)
5. Steps touching prod data, auth, or shared state
6. Any step where confidence score seems inflated ("LOW" risk but touches external state)
7. Migration steps: is `alembic upgrade head` reversible without data loss?

### Probe loop

**Keep probing until confidence > 96%.** No fixed round count.

For each probe, pick the **most dangerous unresolved item** and ask ONE sharp question.

```
--- REVIEW PROBE [N] ---
Current confidence: [X]%
Target: >96%
Gap type: ASSUMPTION / UNKNOWN / HIGH-RISK-STEP / INTEGRATION-POINT

Probing: [specific item from plan]

Question: [one sharp question — not a list — that reveals whether this will actually work]
```

### After each answer

**If satisfactory:**
- Write the answer as an annotation in the plan file under "Annotation Space"
- Recalculate confidence:
  - Confirmed HIGH assumption → +5–8%
  - Confirmed MED assumption → +2–4%
  - Resolved HIGH unknown → +5–10%
  - Resolved MED unknown → +3–5%
- Print: `Confidence: [old]% → [new]%`
- If confidence > 96% AND no remaining HIGH-risk unprobed items: proceed to Phase 3
- Otherwise: pick next item from queue

**If answer reveals a gap or "I don't know":**
```
PHASE 2 BLOCKER FOUND
Issue: [description]
Probe: [what was asked]
Answer: [what the user said]
Impact: plan cannot proceed — this step will fail or produce ambiguous behavior
Resolution: [what must be verified or decided before continuing]

REVIEW PAUSED — resolve this blocker then re-run /rplan-review
```

---

## Phase 3: Implementation Readiness Check

**Run only after confidence > 96% with no Phase 2 blockers.**

Go through each step in the plan and answer these questions:

| Step # | Can a developer implement this without asking any questions? | Every file path named? | Every function named? | Pass? |
|--------|-------------------------------------------------------------|----------------------|----------------------|-------|
| 1 | | | | |
| 2 | | | | |

If any step fails: add a note to the plan's Annotation Space specifying what's missing. **Do NOT approve** until all steps pass.

If all steps pass:
```
PHASE 3 PASSED — implementation readiness confirmed
```

---

## Step N: Final Verdict

```
--- REVIEW COMPLETE ---

Phase 1 (Structural scan): PASSED / FAILED
Phase 2 (Content probing): PASSED / FAILED / BLOCKED
Phase 3 (Readiness check): PASSED / FAILED

Probes run: [N]
Confidence: [start]% → [final]%
Blockers found: [N]

Verdict:
  ✅ APPROVED FOR IMPLEMENTATION
     All 3 phases passed. Confidence [X]% > 96%. No blockers.
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

- NEVER skip Phase 1. NEVER treat a structural gap as a probe question.
- A missing section = STOP. The plan author must rewrite, not answer verbally.
- Ask ONE question per probe — sharp and specific, not a list.
- Annotate the plan file with every resolved answer — the record must be permanent.
- Do NOT recommend /approved unless all 3 phases pass AND confidence > 96%.
- If a step says "LOW risk" but touches external state (DB, auth, API, payment), probe it.
- "I'll handle it during implementation" is NOT a satisfactory probe answer — it's a BLOCKER.
