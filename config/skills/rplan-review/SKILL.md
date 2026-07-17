---
name: rplan-review
description: Adversarial plan review — structural completeness scan, then parallel domain expert agents, then synthesis. Leads on implementation reality (each step's failure paths + the build work it implies but omits), grounds every finding to a cited step and verifies blockers against the code before they count, and requires experts to prescribe the exact plan edit. Gates on failure-surface completeness. Blocks on missing sections. Run after /saki-builder:rplan before /saki-builder:approved.
user-invocable: true
---

# Plan Review — Structural Scan + Parallel Expert Review

You are the review coordinator. Your job: verify the plan is complete and safe to implement, using domain expert agents in parallel.

**Priority order for the whole review: ① surface implementation reality → ② keep every finding grounded → ③ prescribe, don't lecture.** ① The lead question every expert answers first is *what fails or is silently assumed when this step runs* — the failure/edge paths the happy path hides, and the build work a step implies but the Steps table omits (backfill, index, authz middleware, rollback, feature flag). ② Every finding cites the exact step/section it attacks; uncited findings are discarded and every blocker is verified against the actual code before it enters the ledger (subagents misread patterns and flag correct APIs as bugs). ③ A finding must prescribe the exact plan edit that fixes it (step + file + function/criterion), never merely flag.

There are 4 phases. Phase 1 is a hard gate — failure stops the review entirely.

---

## Step 0: Load the active plan

**If the caller (e.g. `/saki-builder:build`) passed a specific plan-file path, use that exact file** — it pins the review to the intended slice, not whichever `*-plan.md` is newest (a multi-slice build keeps several plans in `tasks/`; mtime-based "newest-wins" selection would otherwise bind the review to the wrong slice's plan). Otherwise find the most recent `*-plan.md` in `tasks/` (workflow artifacts live under `tasks/`, not the project root). Read it fully.

Also read the Phase 1 attempt counter — `<!-- rplan-review-phase1-attempts: K -->` anywhere in the plan
file (absent → `K=0`). It bounds the Phase 1 self-route loop below and must be read here, before any
routing decision, so the bound survives a compaction or a fresh invocation.

Print:
```
--- PLAN LOADED ---
File: [filename]
Initial blocking count: [N]
Phase 1 attempts so far: [K]/3
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
**Then clear the attempt counter** — delete the `<!-- rplan-review-phase1-attempts: K -->` line from the
plan file (or set it to `0`) — so a later re-review of this plan starts fresh. This is the ONLY place the
counter is cleared; it must happen here, on the path that actually runs. A counter that only ever
increments would make the next legitimate review start at a stale `K` and emit a false `BLOCKED`.

**If ANY ❌ — route, don't terminate.** The gate is right; the *addressee* depends on who called you.
A structural gap is `/saki-builder:rplan`'s to fix (never fix it here — see the Phase 1.5 rule below:
rewriting in two places drifts). But "the plan author must rewrite" is a human-shaped instruction, and
inside `/saki-builder:build` the plan author IS the agent — so hand back to `/saki-builder:rplan` and
re-review rather than stopping the chain.

**Loop guard — 3 strikes, counted durably. Apply this BEFORE routing.** The counter must survive
compaction and re-invocation, so it lives in the plan file, not in your head:

```
<!-- rplan-review-phase1-attempts: K -->
```

Step 0 already read it (absent → `K=0`). **Now increment it and write it back to the plan file — do this
before you route, not after.** Then check the bound: **if K reaches 3, do NOT route.** Stop instead —
regardless of whether the gaps are the same ones. A rotating gap set (fix A → B appears → fix B → C
appears) is still a loop, and it is the exact case a "same failure ~3 times" predicate never catches:

```
BLOCKED: rplan-review — Phase 1 structural gaps survived 3 rounds: [cited gaps, all rounds]
```

Return control to the caller. Never loop silently past 3.

**If K < 3 AND a caller passed a plan-file path (Step 0) — self-route:**
```
PHASE 1 FAILED — STRUCTURAL BLOCKERS FOUND (attempt [K]/3)

Missing/incomplete:
  ❌ [section]: [specific gap]

Routing back to /saki-builder:rplan with the cited gaps → will re-review.
```
Re-run `/saki-builder:rplan` on the same plan file, passing every cited gap, then re-run Phase 1.

**Exception — the one gap that must NOT be self-routed.** If the gap is **intent-shaped** (not derivable
from any file), pause instead: a missing/placeholder `Concrete Example Output` is the canonical case —
`config/skills/rplan/SKILL.md:350` already blocks on it and must keep blocking. Never fabricate it, never
route it back to `/saki-builder:rplan` expecting the agent to invent it. Ask the user for the example.

**If NO caller passed a path (human-invoked review) — stop and report:**
```
PHASE 1 FAILED — STRUCTURAL BLOCKERS FOUND

The plan author must rewrite the plan. These gaps cannot be resolved by answering questions.

Missing/incomplete:
  ❌ [section]: [specific gap]

Action: Fill missing sections → re-run /saki-builder:rplan-review

REVIEW STOPPED.
```

Do NOT proceed to Phase 2 if Phase 1 failed.

---

## Phase 1.5: Verify Criteria Hardening (no rewriting)

**`/saki-builder:rplan` Step 6d performs criteria hardening. This phase only verifies it was done.**

Read the Success Criteria section. For each criterion, check it has ALL THREE:
1. **Actor + Action** — who does what
2. **Test command** — exact command to verify
3. **Expected outcome** — exact result

**If every criterion has all three (or is explicitly `🔲 MANUAL` with numbered steps + Playwright stub):**
```
PHASE 1.5 PASSED — criteria already hardened by /saki-builder:rplan 6d
```

**If any criterion is missing fields:**
```
PHASE 1.5 FAILED — criteria not hardened

The plan must run /saki-builder:rplan Step 6d hardening before review.
Unhardened: [list of criterion IDs and what's missing]

Action: Re-run /saki-builder:rplan to harden criteria → re-run /saki-builder:rplan-review
REVIEW STOPPED.
```

Do NOT rewrite criteria here. That is `/saki-builder:rplan`'s job; rewriting in two places drifts.

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
| Database | any migration, schema, data-model, or index change in steps |
| Security | any auth, permission, input-validation, secret/token, PII, or external-input handling in steps |
| Architecture | a new module/service/boundary, a cross-module or cross-service change, a new external integration/dependency, or any step touching ≥3 modules |
| QA | always (every plan has acceptance criteria + a test strategy to verify) |
| Product | always (role coverage and acceptance criteria always apply) |

### Expert agent prompts

Launch each applicable agent with this prompt pattern. Pass the full plan text in the prompt.

**Shared contract — prepend this to EVERY expert prompt below:**
```
Priority order: ① implementation reality first · ② grounded · ③ prescribe.
- LEAD with implementation reality: before your domain checks, for each step you own name (a) the failure/edge paths the happy path leaves untested, and (b) the build work the step IMPLIES but the Steps table OMITS — backfill, index, authz middleware, rollback, feature flag.
- CITE EVERY FINDING: quote the exact step # / section + the text you object to. Uncited findings are DISCARDED in synthesis — do not pad with vague concerns.
- PRESCRIBE, don't flag: each blocker names the exact plan edit that fixes it (the step to add/change: file + function/criterion). A description with no prescribed edit is a half-finding.
- DEFAULT TO BLOCKER for a state-changing or 🔒 step whose failure path is untested — do not soften it to a warning.
- Do NOT propose a numeric confidence adjustment — Phase 3 owns the ledger (each finding becomes a Blocking or Advisory row).
```

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
(Phase 3 will translate blockers/warnings into Blocking/Advisory ledger rows — do NOT propose a numeric adjustment.)
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
(cite the step # you object to + prescribe the fixing edit; Phase 3 owns the ledger — do NOT propose a numeric adjustment)
```

**Database Expert Agent:**
```
You are a senior database engineer doing adversarial plan review.

Review the following plan and identify:
1. Migration missing a corresponding down/rollback file, or an irreversible migration with no backup step
2. Destructive schema change (column drop/rename, type narrowing) without a safe migration strategy
3. Missing or wrong index for a query the plan's metric or hot path depends on
4. Data-model errors: wrong cardinality, a missing FK/UNIQUE/CHECK constraint, nullable that should not be
5. Missing transaction boundary for a multi-row / multi-table atomic operation
6. Model→migration drift: a field/model change with no matching migration step
7. Any step that changes schema without naming the migration file + the exact up/down command

Plan:
[paste full plan text]

Output format:
DATABASE REVIEW
Blockers: (list)
Warnings: (list)
(cite the step # you object to + prescribe the fixing edit; Phase 3 owns the ledger — do NOT propose a numeric adjustment)
```

**Security Expert Agent:**
```
You are a senior application security engineer doing adversarial plan review.

Review the following plan and identify:
1. Missing authn/authz check before a sensitive read or write (does every endpoint name its guard?)
2. Broken object-level authorization / IDOR — can a user act on another user's or another tenant's row?
3. Unvalidated external input at the boundary — injection (SQL/shell/template), XSS, SSRF, path traversal
4. Secrets/tokens in code, logs, or responses; weak crypto (MD5/SHA-1/DES/ECB); tokens with no expiry/rotation
5. Sensitive-data exposure — PII/financial data logged, returned in an over-broad response, or stored unencrypted
6. Missing rate-limit / abuse guard on an expensive or auth-adjacent action; enumeration or timing leaks
7. Any step handling auth, permissions, or external input without stating the check that protects it

Plan:
[paste full plan text]

Output format:
SECURITY REVIEW
Blockers: (list — each one is an exploitable gap)
Warnings: (list)
(cite the step # you object to + prescribe the fixing edit; Phase 3 owns the ledger — do NOT propose a numeric adjustment)
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
(Phase 3 will translate blockers/warnings into Blocking/Advisory ledger rows — do NOT propose a numeric adjustment.)
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
(cite the step # you object to + prescribe the fixing edit; Phase 3 owns the ledger — do NOT propose a numeric adjustment)
```

**Architecture Expert Agent:**
```
You are a senior software architect doing adversarial plan review.

Review the following plan and identify:
1. Wrong layer / boundary — business logic in a handler, a service reaching across a boundary it shouldn't, UI calling the DB directly
2. A new module/service/integration introduced without a stated contract (interface, API shape, ownership)
3. Coupling problems — a circular dependency, a dependency pointing the wrong way, a shared mutable surface two features race on
4. A missing seam for a stated variation point (a hardcoded choice the plan says will vary) OR a premature abstraction with one implementation (YAGNI)
5. Scalability/consistency risk in the design — an N+1 pattern, a sync call that should be async (or vice-versa), an unbounded fan-out, eventual-consistency assumed but not handled
6. Cross-cutting concerns unplaced — where do logging, error propagation, transactions, idempotency, and config live for the new code?
7. Any step that adds a component without saying how it wires into the existing architecture (who calls it, what it depends on)

Plan:
[paste full plan text]

Output format:
ARCHITECTURE REVIEW
Blockers: (list — each one is a structural flaw that's expensive to reverse post-build)
Warnings: (list)
(cite the step # you object to + prescribe the fixing edit; Phase 3 owns the ledger — do NOT propose a numeric adjustment)
```

**QA Expert Agent:**
```
You are a senior QA engineer doing adversarial plan review.

Review the following plan and identify:
1. Acceptance criteria with no corresponding test named in the Steps table (what actually verifies this?)
2. Missing test LEVEL — logic with no unit test, a cross-layer flow with no integration test, a user journey with no e2e
3. Untested failure/edge paths — for each state-changing step, the negative cases the happy-path test skips (over-limit, empty, concurrent, unauthorized, retry/idempotency)
4. Test-data / fixture gaps — a criterion that needs seed data, a specific account state, or a mocked external the plan never provides
5. Regression risk — an existing behavior this change can break, with no test pinning it
6. Non-deterministic / flaky-test risk — reliance on timing, ordering, network, or the real clock without control
7. Any acceptance criterion not written as an executable check (exact command / observable signal) — it can't be QA'd as-is
8. Coverage floor — any new-code step whose named tests would not reach the **NON-NEGOTIABLE ≥ 80%** coverage floor (untested branches, error paths, or whole functions with no test). Below 80% is a **BLOCKER**, never a warning — prescribe the exact missing tests.

Plan:
[paste full plan text]

Output format:
QA REVIEW
Blockers: (list — each one leaves a behavior unverifiable or a failure path untested)
Warnings: (list)
(cite the step # you object to + prescribe the fixing edit; Phase 3 owns the ledger — do NOT propose a numeric adjustment)
```

### Collect all results

Wait for all agents to return. Print each review result in full.

---

## Phase 3: Synthesis

Merge all expert findings:

1. **Discard uncited findings.** A blocker or warning that doesn't quote a step # / section is dropped — state how many were discarded. (Experts pad to look thorough; an uncited finding is unverifiable by definition.)
2. **Verify every BLOCKER against the actual code/plan line before it enters the ledger.** Subagents misread patterns and flag correct APIs as bugs (CLAUDE.md core rule #4). Read the cited `path:line` yourself; a blocker that doesn't survive verification is downgraded or dropped, with a one-line note. **Best-effort when the repo isn't on disk:** if the plan's checkout isn't available, mark such blockers `PLAUSIBLE (unverified — repo absent)` rather than confirming or dropping them.
3. **Deduplicate** — same issue flagged by multiple experts counts once
4. **Classify** — Blocker (must fix before /saki-builder:approved) vs Warning (should fix, not blocking). A state-changing or 🔒 step whose failure path is untested, or that omits implied build work (backfill/index/authz/rollback), is a **Blocker**, never a warning.
5. **Extend the Evidence Ledger — add verified blockers to the Blocking table.**

   For each verified blocker, append a new **Blocking** row to the plan file using the format from `/saki-builder:rplan` Step 4:
   - Cite evidence (`path:line`, the expert that found it, the step number it ties to)
   - Classify Blocking vs Advisory by the step's risk (§4b/§4c) — a state-changing/🔒 step's untested failure path or omitted implied work is **Blocking**
   - A verified blocker on a state-changing step is always Blocking, never Advisory

   For each warning, append an **Advisory** row (cited), or skip if non-actionable.

   **The verdict is the Blocking table being empty** — there is no score to recompute. Each finding is a Blocking or Advisory row; there are no per-expert `+/-N%` adjustments.

   If the plan has no Evidence Ledger, state: "PHASE 3 ABORTED — plan has no Evidence Ledger. Re-run /saki-builder:rplan to build the ledger first."

Print synthesis:

```
--- SYNTHESIS ---

Domains reviewed: [Backend / Frontend / UI/UX / Database / Security / Architecture / QA / Product]  (only those the plan touched)
Uncited findings discarded: [N]  ·  Blockers verified against code: [N kept / N dropped]
Failure-surface: [N]/[M] state-changing steps with failure path covered · [K] implied-work gaps found

Blockers (must fix before /saki-builder:approved — each cites a step # and prescribes the fix):
  ❌ [B1] [domain] §step: [description] → FIX: [exact plan edit: step + file + function/criterion]
  ❌ [B2] [domain] §step: [description] → FIX: [...]

Warnings (non-blocking):
  ⚠️ [W1] [domain] §step: [description] → FIX: [...]

Blocking: [initial N] → [final N]
```

**If the Blocking Set is non-empty:**
```
PHASE 3 FAILED — Blocking Set non-empty
Fix all ❌ blocking items in the plan file, then re-run /saki-builder:rplan-review.
```

**If the Blocking Set is empty:**
```
PHASE 3 PASSED — Blocking Set empty (Advisory items do not hold the gate)
Proceeding to Phase 4.
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
Phase 3 (Synthesis):    PASSED / FAILED
Phase 4 (Readiness):    PASSED / FAILED

Blocking: [start N] → [final N]
Blocking items found: [N]
Advisory items found: [N]

Verdict:
  ✅ APPROVED FOR IMPLEMENTATION
     All phases passed. Blocking Set empty.
     Next: /saki-builder:approved

  OR

  ❌ NOT READY
     [Phase N] failed:
     - [blocking item 1]
     - [blocking item 2]
     Next: Fix blocking items → re-run /saki-builder:rplan-review
```

---

## Stamp the resume manifest (best-effort)

If a manual-chain manifest exists for this plan (`tasks/.<slug>-state.json`, `<slug>` = plan filename minus
`-plan.md`), stamp this review's outcome so the chain can resume after a context clear: `rplan-review=done`
on **APPROVED**, `rplan-review=not-ready` otherwise. Run the **Stamp** snippet from
`${CLAUDE_PLUGIN_ROOT}/config/docs/manual-chain-resume.md` (`PLAN_FILE` = the reviewed plan). Skip silently
if the file is absent or on any error — it never changes the verdict.

---

## Rules

Priority order: **① surface implementation reality → ② keep every finding grounded → ③ prescribe, don't lecture.** When they conflict, that order wins.

- NEVER skip Phase 1. A structural gap is never a probe question.
- Launch expert agents in parallel — never sequentially. Every expert LEADS with implementation reality (failure paths + implied build work) before its domain checks.
- Only launch agents for domains that are actually touched by the plan.
- Discard uncited findings, and VERIFY every blocker against the cited code/plan line before it enters the ledger — subagents flag correct APIs as bugs; an unverified CRITICAL is not a blocker yet.
- Every blocker must PRESCRIBE the exact plan edit that fixes it (step + file + function/criterion) — a bare description is a half-finding.
- A state-changing/🔒 step with an untested failure path or omitted implied work (backfill/index/authz/rollback) is a Blocking item, not an Advisory — it holds the gate on its own.
- A blocker from any agent = plan is NOT ready — the Blocking Set is non-empty until it is resolved.
- "I'll handle it during implementation" = BLOCKER.
- Annotate the plan file with all resolved findings under "Annotation Space".

---

## Project Override

This is the **general version**. For project-specific domain experts (language, framework, design system), create:
```
.claude/skills/rplan-review/SKILL.md
```
That file overrides this one and should contain agents tuned to the project's stack and conventions.
Run `/saki-builder:init-env` to scaffold the project-specific override automatically.
