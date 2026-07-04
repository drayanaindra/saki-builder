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
s['model'] = 'opus'  # alias — resolves to the best available Opus; never goes stale
p.write_text(json.dumps(s, indent=2))
print('Model set to opus (alias -> latest Opus)')
"
```

Then confirm with: `Model: OPUS | Status: Planning`

> This pins the model to Opus for planning and does **not** auto-restore afterward — `/saki-builder:approved` switches to Sonnet for implementation. Use the `opus` alias (not a pinned `claude-opus-4-x`) so it stays current across releases instead of silently downgrading.

---

## Step 0.5: Scope Clarification (Prompt Expander)

Before researching, check if the user's prompt has clear scope. If ANY of these are ambiguous or missing, ask:

```
Before we start, quick scope check:

Who?      [who uses this feature — which user roles?]
When?     [what triggers it — when/how does it start?]
Output?   [one concrete example of expected behavior]
Boundary? [what to skip / not include in this scope]
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

Create an execution plan following the template at `${CLAUDE_PLUGIN_ROOT}/config/skills/rplan/template.md` (the sibling `template.md` in this skill's directory — glob for it if the variable isn't expanded).

## Process

### 1. Research Phase (read-only — NEVER skip)

- **Ingest the source PRD slice FIRST (if this task came from `/saki-builder:prd`):** locate the originating `tasks/prd-*.md` and the slice this plan implements, and carry it forward — do NOT re-derive:
  - the slice's **acceptance criteria** → seed the plan's Success Criteria
  - the slice's **`Assumes:`** line (if present) → seed the plan's implementation steps + **Migration Checklist** (the hidden work — migration/backfill/index/flag/permission/rollback — `/saki-builder:prd-review` surfaced and `/saki-builder:prd` stated; do NOT re-derive it)
  - the source PRD's **§16 Technical Contract (thin)** (if present) → seed the plan's **Plan Wiring** + schema/endpoint design as the *shape to HARDEN* into full columns, request/response structs, and migration files. Do NOT re-derive the shape — deepen it: a §16 row tagged `NEW` is a create-target, a `REUSE` row (`path:line`) is an existing anchor to verify with grep/read. §16 is thin by design (entities/endpoint-purposes/one arch decision); the depth is yours to add here.
  - the **§5 outcome IDs** it serves → keep each Success Criterion's `→ 5.x` link
  - the **outcome-tied kill criterion** (§6) and the **feature appetite band** (§6/header — `small|medium|large`) → into the plan header (Step 2 / template). The band is the *feature-wide* recut ceiling; derive THIS plan's own appetite (`~N agent tasks`) from the slice's size (its acceptance-criteria count — ≤5 ≈ one agent iteration per INVEST), not from the band directly.
  - any `⚠ DISCOVERY-RISK` banner → record as a plan-level UNKNOWN with a resolution strategy
  - **Lock check:** if the source PRD carries no `<!-- prd-locked: … -->` marker, note it in the plan header
    as `Source PRD: NOT LOCKED — requirements may still change`. Inside `/saki-builder:build` this never happens
    (build's Gate 1.5 hard-blocks an unlocked PRD *before* rplan runs); a **standalone** `/saki-builder:rplan`
    stays lenient — plan against it, but flag that the freeze (`/saki-builder:proto`'s lock) hasn't run yet.
  If there is no source PRD (standalone `/saki-builder:rplan`), note "no source PRD" and continue.
- **Persona check:** after PRD ingestion, check if `.claude/personas/*.md` exists. If it does,
  read the relevant persona(s) and carry forward into the plan:
  - §3 Pain Points & §5 UI/UX Constraints → inform which error/empty states to cover in Step 2.5
  - §6 "Must Never Experience" → add as explicit guardrail criteria in Success Criteria
  - §4 Mental Model → inform copy tone in Step 2.5 Gherkin `Then` lines (UI text should match persona vocabulary)
  Cite the persona when it drives a plan decision: `→ persona/buyer.md §5`.
  If no persona file exists, continue without one — this is a check, not a blocker.
- Read ALL files related to the task: models, schemas, services, routes, frontend pages, migrations
- Identify existing patterns, dependencies, constraints
- For each user role affected (customer, admin, merchant, warehouse staff), trace the full path:
  - What UI they see
  - What API they call
  - What service logic runs
  - What DB state changes
- Document findings in `[task]-context.md` in project root

**Spike Protocol (XP):** If during research you encounter an unknown that cannot be resolved by reading code (e.g., third-party API behavior, performance characteristics, library compatibility), run a timeboxed spike:
1. Spawn a subagent with a 15-minute timebox question. For genuinely **external** unknowns (third-party API/library behavior, current pricing/limits, ecosystem facts), the spike may use `WebSearch` / `/deep-research` / a connected MCP server — not only code reading.
2. Spike output must include: question answered, approach tried, key findings, recommendation, remaining unknowns
3. Spike results feed into the plan as resolved unknowns (with evidence, not assumptions) — **cite the source** (`path:line`, URL, or MCP query), consistent with §4a's evidence rule
4. If spike fails to resolve → mark as UNKNOWN in plan with resolution strategy

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
- **Appetite & Kill-if (inherited via Step 1)** — `Appetite: ~N agent tasks` (derived from this slice's criteria count; must sit within the PRD's feature appetite band from §6/header); `Kill-if: [§5 metric] crosses [threshold]`. If the plan's step count exceeds the appetite, flag a recut **before** presenting.

### 2.5. User Flow Spec (user-facing tasks only)

**Skip** if the task is backend-only (no UI change, no endpoint a user/role directly hits through the app). Otherwise, write `[task]-flow.md` alongside the plan.

Purpose: behavior checkpoint the user reads before approval to verify the plan will behave as expected. Also consumable by `/saki-builder:qa` to lift Playwright scenarios.

Format: **Gherkin**, one `Feature:` block per role (Customer / Admin / Kasir / Warehouse / etc. — only roles that touch this feature). Do not merge roles.

Required scenarios per role:
- **Happy path** — exactly one, mandatory
- **Validation error** — one distinct UX case
- **Permission denied** — if multiple roles exist
- **Network / server error** — one case covering the common toast/retry UX
- **Stale data** — ONLY if two roles or two sessions can mutate the same row (orders, stock, table status, bill, reservations). Skip for single-owner resources.

Skip unhappy paths that would produce duplicate UX (e.g. two 4xx paths showing the same toast).

Template per role:

```gherkin
Feature: [Role] — [capability]

  Background:
    Given [role] is authenticated
    And [preconditions: data, state, feature flag]

  Scenario: [role] successfully [action]   # HAPPY PATH
    Given [starting state]
    When [role] does [action] on [page route, e.g. /pos/kasir]
    Then [observable UI response: exact text / URL / testid]
    And [DB side effect, e.g. "stock for SKU X decreases by exactly 2"]
    And [UI feedback: toast / redirect / state]

  Scenario: Validation error — [specific invalid input]
    When [role] submits [invalid data]
    Then UI shows inline validation "[exact message]" on [field testid]
    And no DB write occurs

  Scenario: Permission denied
    When [role without permission] attempts [action]
    Then system returns 403
    And UI shows "[exact message]" / redirects to [route]

  Scenario: Network error
    When backend returns 500 / times out
    Then UI shows [toast text or retry affordance]
    And local form state is preserved

  Scenario: Stale data — [other actor changed state]   # conditional
    Given [resource] was modified by [other role] after [role] loaded the page
    When [role] submits [action]
    Then system detects conflict and shows [resolution UI]
```

**Rules:**
- Every `Then` must be observable (UI text, URL, toast, disabled state, testid, DB row) — no "system handles it correctly"
- Reference exact routes and `data-testid` hooks where known
- If the flow touches money, stock, or tenant data, add an explicit invariant `And` line
- Cross-reference from `[task]-plan.md` via the `Behavior Spec:` header line
- **If a persona was loaded in Step 1:** `Then` UI copy must use the persona's vocabulary (§4 Mental Model), not technical jargon. Error messages must address the persona's top pain points (§3). Scenarios must include any state listed in §6 "Must Never Experience" as a distinct unhappy-path scenario.

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
- [ ] `[task]-flow.md` exists with Gherkin scenarios per user-facing role (or task is backend-only and this is explicitly noted in the plan header)

**Plan Wiring**

- [ ] Each major flow has a written call chain: `ComponentX → apiService.methodY → POST /v1/endpoint → service.function → Model.field`
- [ ] No step that says "update frontend" without naming the exact file and function
- [ ] No step that says "add API endpoint" without naming the method, path, and schema

### 4. Confidence Scoring (Ledger-Based)

**Score = 100 − sum of Confidence Ledger entries.**

A plan without a Confidence Ledger is **unscored** — treat as <70% and return to research. The bare percentage in the plan header is meaningless without the ledger that justifies it.

#### 4a. Reference verification (run before scoring)

Walk every step in the Steps table. Classify each file/function reference:

- **Anchor** — code that must exist NOW (caller, parent file, model being modified, route file the new endpoint lives in). Verify with grep/read. If grep fails → ledger entry required.
- **Target** — code to be created by this plan. Must have all three:
  1. A real **anchor parent path** (the file it lives in, or sits next to)
  2. A **creating step number**
  3. A unique identifier (function, struct, file name)
  Targets missing any of the three → ledger entry required.

You may not score until every reference in every step has been classified and verified.

#### 4b. Standard deduction table

| Issue | Base Δ |
|-------|--------|
| Anchor reference does not grep | -5 |
| Target reference missing anchor parent or creating step | -3 |
| Vague step ("update X" without file+function) | -5 |
| Implementation Checklist `[ ]` unchecked | -3 |
| Step missing Test column entry | -2 |
| Step Committable=No without grouping note | -3 |
| Unresolved UNKNOWN — MED | -5 |
| Unresolved UNKNOWN — HIGH | -8 |
| Missing user role coverage | -3 |
| `Concrete Example Output` empty/placeholder | BLOCK (score = 0) |

#### 4c. Risk multiplier

Apply to every deduction based on the **step the deduction belongs to**:

- LOW-risk step: ×1
- MED-risk step: ×1.5 (round up)
- HIGH-risk step: ×2

A `-3 checklist unchecked` issue tied to a HIGH-risk step is `-6` in the ledger.
A deduction not tied to any step (e.g., missing role) uses ×1.

#### 4d. Action thresholds

| Score                | Action                                           |
| -------------------- | ------------------------------------------------ |
| >= 96%               | Present plan, wait for approval                  |
| 90–95%               | Resolve ledger items, re-score                   |
| 70–89%               | More research needed — do NOT present yet        |
| < 70%                | Stop, write context file, ask user for direction |
| Unscored (no ledger) | Treat as <70% — return to research               |

**Max unresolved unknowns before presenting:** 2.

> Threshold rationale (vs `/saki-builder:prd`): `/saki-builder:rplan` presents at **≥96%** while `/saki-builder:prd` presents at **≥90%** — by design. A plan is one step from code and has a larger blast radius (a wrong file or migration ships a bug), so its bar sits higher than a product spec's.

#### 4e. Honesty rules

- Every ledger entry MUST cite evidence (`path:line`, grep result, or step number). An uncited deduction is invalid — the ledger as a whole is invalid until every entry is cited.
- A score of 100 is allowed but requires the ledger to state explicitly: *"All anchors verified, all targets have anchor parents and creating steps, all checklist items satisfied, no unknowns above LOW."*
- Before marking any checklist item `[x]`, ask: can I cite the plan line that satisfies it? If not, leave it `[ ]` and take the deduction.
- The 96% threshold is for **honest** scores. Lowering deductions to clear the bar is the failure mode this gate exists to prevent.

### 5. Pre-Present Quality Gate

Before showing the plan to the user, answer all of these:

1. Can a developer implement Step N without asking any clarifying question? (Yes for every step)
2. Are all user roles represented in the User Role Coverage matrix?
3. Is every migration change explicitly listed with the `migrate` command?
4. Is every call chain wired end-to-end in the Plan Wiring section?
5. Are success criteria testable without ambiguity?
6. Is the `Concrete Example Output` section filled with a real, specific example (not placeholder, not a restatement of the problem)?
7. Is the Confidence Ledger present, and does every entry cite evidence (`path:line`, grep result, or step number)?

If any answer is "No" → fix the plan before presenting.
If #6 is "No" → STOP. Do not present. Return to user and ask for the example, or recommend `/saki-builder:shaping-requirements`. Do not invent the example.
If #7 is "No" → the score is unsubstantiated. Build the ledger before presenting; do not round up to clear the gate.

### 6. Self-Review (built-in domain checks)

**Run BEFORE presenting the plan. This replaces /saki-builder:rplan-review for LOW/MED risk plans.**

Walk through the plan and check each item below. For each violation found, fix it in the plan immediately — do not just flag it.

#### 6a. Deterministic Checklist (always run)

| #   | Check               | What to look for                                                                            |
| --- | ------------------- | ------------------------------------------------------------------------------------------- |
| 1   | Vague steps         | Any step saying "update", "add", "modify" without exact file path + function name → rewrite |
| 2   | Missing file paths  | Any reference to a file without full path from project root → add path                      |
| 3   | Schema completeness | Any API endpoint without request/response struct named → add it                             |
| 4   | Auth guards         | Any endpoint missing permission/middleware specification → add it                           |
| 5   | Error paths         | Any service function without error cases listed → add 404/403/422                           |
| 6   | Empty states        | Any new UI page without empty state behavior → add it                                       |
| 7   | Wiring gaps         | Any flow that stops at "API endpoint" without tracing to service + DB → complete the chain  |
| 8   | YAGNI violations    | For each new function/struct/file: (Q1) Is it in the current plan step? (Q2) Will code break without it now? (Q3) Same effort to add later? (Q4) Deferring creates breaking change? → If Q1=No or (Q2=No and Q4=No) → CUT IT. Common violations: premature interfaces with one impl, unused config options, pagination before data exists, factory patterns for single-use |
| 9   | Missing TDD spec    | Any step with business logic that has no Test column entry → add test function name. Steps must specify: test name, what it asserts, TDD mode (Test-First / Test-Along / Test-After) |
| 10  | Uncommittable steps | Any step marked Committable=No without naming which step completes it → fix. Adjacent uncommittable steps must be grouped as atomic commit |
| 11  | Missing concrete example | The plan's `Concrete Example Output` section is empty, contains placeholder text ("TBD", "to be defined", "see ticket", "as discussed", "kamu yang tentukan", "n/a"), or only restates the problem statement → BLOCK. Stop self-review, return to user with: *"This plan needs a concrete example of the expected output before I can continue. Either paste an example, or run `/saki-builder:shaping-requirements` to define the problem shape first."* Do NOT attempt to fabricate the example yourself. |

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

#### 6d. Acceptance Criteria Hardening

**Run after 6a–6c. Rewrites criteria in-place so `/saki-builder:qa` can run them as-is.**

Read the Success Criteria section. For each criterion, it PASSES hardening only if it has ALL THREE:
1. **Actor + Action** — who does what (`User calls POST /v1/endpoint`, `User clicks Submit button`)
2. **Test command** — exact command to verify (`curl -X POST ...`, `go test -run TestFoo`, Playwright step)
3. **Expected outcome** — exact result (`HTTP 201`, `{"status":"ok"}`, `"Success" toast visible`)

**Classify each:**
- `✅ HARDENED` — has all three, ready for `/saki-builder:qa`
- `🔧 REWRITE` — missing test command or expected outcome
- `🔲 MANUAL` — requires browser interaction, needs Playwright scenario or explicit manual steps

**For every `🔧 REWRITE`** — rewrite it in the plan file using the wiring:
```
Given [precondition]
When [actor] [action] ([test command])
Then [expected outcome] ([verification method])
```

**For every `🔲 MANUAL`** — add numbered browser steps AND a Playwright stub:
```
Manual: 1. Navigate to [url] 2. Click [element] 3. Verify [outcome]
Playwright: test('[name]', async ({ page }) => { ... })
```

Edit the plan file. All criteria must be `✅ HARDENED` or `🔲 MANUAL` before continuing.

Print:
```
6d Criteria Hardening: total [N] | already hardened [N] | rewritten [N] | manual [N]
```

#### 6e. Update Ledger After Self-Review

Update the Confidence Ledger to reflect what was fixed: remove resolved entries, add new entries for any gaps surfaced during review (including any criterion that could not be hardened). Recompute the score from the updated ledger. Do NOT delete entries you cannot cite as resolved — leave them and take the deduction.

### 7. Output with Next Action Recommendation

- Write full plan to `[task]-plan.md` in project root
- Present plan summary in chat with:
  - Confidence score
  - Risk level
  - Self-review results (what was caught and fixed)
  - **Next action recommendation** (see below)

#### Next Action Decision Tree

Step 6 already performed self-review and (for HIGH risk) the combined-reviewer spot-check. `/saki-builder:rplan-review` is for HIGH-risk plans that benefit from parallel domain experts — it does NOT re-do Step 6's work. For LOW/MED, do not recommend `/saki-builder:rplan-review`; the gaps it would find are already covered by Step 6.

```
If confidence >= 96% AND risk is LOW/MED:
  → "Plan ready. /saki-builder:approved to start implementation."

If confidence >= 96% AND risk is HIGH:
  → "Plan ready (HIGH risk). Recommend /saki-builder:rplan-review for parallel domain expert review, or /saki-builder:approved if Step 6 spot-check is sufficient."

If confidence 90-95%:
  → "Confidence at [X]%. Gaps: [list cited ledger entries]. Fix the cited gaps and re-run /saki-builder:rplan — do NOT round up, do NOT escalate to /saki-builder:rplan-review to mask the gaps."

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
> /saki-builder:approved    — start implementation
> /saki-builder:rplan-review — expert validation (recommended for HIGH risk)
> [specific questions if confidence < 90%]
```

---

## Anti-patterns (reject on sight)

| Anti-pattern | Looks like | Fix |
|--------------|-----------|-----|
| Re-derived criteria | Success Criteria written fresh, ignoring the source PRD slice | Seed from `tasks/prd-*.md` (Step 1 ingestion) |
| Vague step | "update the service to handle X" | Name the file + function + the exact change |
| Phantom anchor | a step references a function/file that doesn't `grep` | Verify; if absent it's a target needing a creating step (§4a) |
| Orphan criterion | a Success Criterion with no `→ 5.x` link and no guardrail | Link the PRD outcome or name the guardrail, else cut it |
| Ledger inflation | 97% with one tiny deduction on a 9-step HIGH-risk plan | Re-walk §4a, classify every reference, cite every deduction |
| Stale model pin | leaving `claude-opus-4-x` hardcoded in Step 0 | Use the `opus` alias |

## Rules

- NEVER skip research phase
- NEVER skip Step 0.5 scope check (but DO skip asking if scope is already clear)
- NEVER skip Step 2.5 for user-facing tasks — the flow doc is the behavior checkpoint
- NEVER skip Step 6 self-review
- NEVER present a plan with > 2 unknowns
- NEVER proceed to implementation without explicit approval
- NEVER write "update X" in a step — always name the exact file, function, and change
- NEVER omit a user role that interacts with the feature
- NEVER omit a migration step if schema changes
- NEVER fabricate the `Concrete Example Output` — if the user did not provide one and it cannot be quoted directly from their prompt, STOP and ask. This is the single most important guard against shipping the wrong thing.
- NEVER present a score without a Confidence Ledger. The number is meaningless without cited deductions; a bare percentage is unscored (treat as <70%).
- NEVER mark a checklist item `[x]` unless you can cite the plan line that satisfies it. Unverified checks are the primary failure mode of the old gate.
- If confidence < 96% after self-review, fix gaps — do NOT lower the bar, do NOT prune ledger entries you cannot cite as resolved
