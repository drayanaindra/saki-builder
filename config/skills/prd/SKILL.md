---
name: prd
description: Generate Product Requirements Document from feature intent/description
type: generate
project_types: [web-app, api, library, cli, tui]
trigger: "create PRD, generate requirements, write specification"
inputs:
  - name: feature
    description: Feature description or intent to be built
    required: true
  - name: audience
    description: Target user/audience for this feature
    required: false
    default: "end users"
  - name: research
    description: Pass --research to enable Tier-2 external grounding (deep-research + MCP) in Step 0.7. Off by default; Tier-1 local grounding always runs.
    required: false
    default: "false"
---

## Context

You are acting as a product analyst for project {{project_name}} ({{project_type}}). Stack: {{stack}}.

The PRD bridges the human's intent to the build pipeline (`/saki-builder:rplan` → `/saki-builder:approved` → `/saki-builder:qa`).

**Philosophy:** The human sets the expectation. You apply the discipline. The deliverable must be
readable without you.

This means:
- All methodology (Klement JTBD, Ulwick outcomes, INVEST checks, Quality Gate scoring) runs
  **internally** — never surfaced to the human.
- What the human sees and approves is **5 plain-English points only**.
- The saved file contains the full technical structure for downstream skill consumption.

---

## Step 0 — Scope check (the only human-facing question)

If ANY of these is ambiguous or missing from `{{input.feature}}`, ask before proceeding.
Accept 1–2 word answers. Skip entirely if all four are already inferable:

```
Quick scope check:
Who?      [which user/role]
When?     [what triggers this]
Output?   [one concrete example of what they see or get]
Boundary? [what's explicitly out of scope]
```

If user says "you decide" → make reasonable defaults, state them clearly, continue.

---

## Step 0b — Premise check (INTERNAL — do not show to human)

In scratch (not the file), verify:

1. **The one thing that, if false, makes this not worth building** — tag it
   `assumed | observed | validated`. If `assumed`, name the cheapest validation.
2. **Three concrete reasons this fails** — rebut or concede each.
3. **Verdict** — proceed / recut / stop.

If two failure reasons stand unrebutted, STOP. Tell the human in plain English:
*"Before we write a spec, we need to answer [X] first. I'd recommend a quick discovery spike."*

---

## Step 0.7 — Evidence grounding (INTERNAL — do not show to human)

### Tier 0 — Persona check (always run)

Check `.claude/personas/*.md`. If it exists, read the relevant persona(s) and use them to
inform: acceptance criteria tone, which error states to cover, what non-goals to call out.

### Tier 1 — Local grounding (always run)

Grep/read the codebase to verify every technical claim before writing anything:
- Code confirms it → tag `observed`, note `path:line` internally
- Code contradicts it → fix the claim
- Not found in code → tag `assumed`

### Tier 2 — External grounding (only if `--research` passed)

Ground the load-bearing assumption and baseline metrics via `/deep-research` or `WebSearch`.
Tag `validated`, cite the URL internally. Skip entirely if `--research` not set.

---

## Steps 1–5 — Internal PRD construction (INTERNAL — do not show to human)

Run these silently. The output feeds both the saved file (Step 7) and the 5-point human view
(Step 8).

### 1. Job to be Done (Klement format)

Write exactly one primary: `When [situation], I want to [motivation], so I can [outcome].`
Two primary jobs = two PRDs. Related jobs: 0–3 max. Tag each slice to one job.

### 2. Outcomes (Ulwick format)

1 primary + 2–3 secondary + 1 counter-metric.
Emit §5 as a table with an explicit **Basis** column — without a column for it the basis tag
gets dropped at write time (the exact leak `/saki-builder:prd-review` hard-fails on):

`| # | Outcome (Minimize/Maximize [metric] when [context]) | Target | Basis | Method | JTBD |`

**Basis** is required on every row — one of `baseline N→M` (a measured starting point),
`benchmark` (an external/comparable reference), or `aspirational` (no baseline yet — an honest
target, not a measured one). A numeric target with an empty/absent Basis is fabricated precision.
Counter-metric must name the specific failure mode it guards (e.g. "guards 5.1: faster onboarding
gamed by skipping verification → locked-out users").

### 3. Slices (INVEST)

Number them. Each slice must pass all five:
1. Single user-visible capability
2. ≤2 modules
3. Test-first feasible (a failing test can be written before implementation)
4. Forward dependency only (Slice N depends on 1..N-1, never N+1)
5. Fits ~30 min agent iteration (≤5 acceptance criteria)

Cap: ≤7 slices (>7 = epic, split into multiple PRDs). Slice 1 = vertical walking skeleton.

### 4. Acceptance criteria per slice

Each criterion must have: actor + action + expected outcome.
Each must link a §5 outcome (`→ 5.x`) OR name a guardrail from this menu:
`security | validation | error-path | accessibility | performance | privacy | observability | cost | i18n`
Cap ≤5 criteria per slice.

### 5. Business rules

Numbered, falsifiable statements ("A withdrawal is rejected if amount > balance").
Tag money/stock/tenant rules `🔒 INVARIANT`. Link each rule to ≥1 acceptance criterion.

---

## Step 6 — Quality gate (INTERNAL — enforced, not shown)

Score = 100 − Σ deductions. Fix in-place until score ≥ 90 before presenting.
**Never show the score number or deduction table to the human.**

| Issue | Δ |
|-------|---|
| Premise check (Step 0b) not run / load-bearing assumption not stated | BLOCK |
| Primary JTBD in persona form ("As a…") | BLOCK |
| Evidence 100% `assumed` with no named validation spike | −10 |
| `observed`/`validated` claim with no cited source | −5 each |
| Tier-1 local grounding skipped | −5 |
| §5 outcome with target but no basis tag | −3 each |
| §5 measurement method not instrumentable and not an Open Question | −3 each |
| Counter-metric names no metric/failure-mode it guards | −5 |
| Kill criteria missing or not outcome-tied | −8 |
| Orphan slice (serves no JTBD) | −5 each |
| §5 outcome with no slice criterion linking to it | −5 each |
| Acceptance criterion with no outcome link and no guardrail | −3 each |
| Slice fails any INVEST check | −5 each |
| >7 slices, not split | −8 |
| Feature has domain logic but §10 is empty or false "none beyond CRUD" | −8 |
| `🔒 INVARIANT` not tested by any acceptance criterion | −5 each |
| Non-Goals < 2 | −5 |

If score < 90 → fix the cited gaps and re-score. Do NOT present below 90.

---

## Step 7 — Save the full PRD (for downstream skill consumption)

Save to `tasks/prd-{{input.feature | slugify}}.md` with ALL sections in this exact order
so `/saki-builder:rplan`, `/saki-builder:proto`, and `/saki-builder:qa` can parse them:

```
<!-- prd-quality: [score]/100 -->
<!-- slices: [N] -->

# PRD: [Feature name]

## 1. TL;DR
## 2. Problem & Evidence
## 3. Primary Job to be Done
## 4. Related Jobs
## 5. Desired Outcomes / Success Metrics   (cols: # | Outcome | Target | Basis | Method | JTBD)
## 6. Appetite & Kill Criteria
## 7. Solution Shape
## 8. Vertical Slices
## 9. Acceptance Criteria per Slice
## 10. Business Rules & Invariants
## 11. Non-Goals
## 12. Rabbit Holes & Open Questions
## 13. Technical Constraints  (omit if none)
## 14. Dependencies           (omit if none)
```

Include a `⚠ DISCOVERY-RISK` banner below the machine-readable header if the evidence table
is 100% `assumed` — this is a signal for `/saki-builder:rplan` to surface it as a plan-level UNKNOWN.

---

## Step 8 — Present to the human (5 points only)

Show ONLY this. Plain English. No methodology, no scores, no tags, no section numbers.

```markdown
# [Feature name]

## What I understood you want
[1–3 sentences. What the user experiences. What's saved or remembered. What's out of scope.
Written as if explaining to a teammate, not a product analyst.]

## Screens
[Numbered list of user-visible pages or views this feature adds or changes.
One line each. No jargon. Omit this section entirely if the feature has no UI —
replace with a one-liner: "No user-visible screens — this is a backend change."]

## How we'll know it's done
[Checklist. Each item is a plain-English observable outcome — what the user sees or does.
No HTTP status codes, no tech terms like "localStorage" or "JWT".
A non-technical person should be able to tick these off by using the app.]

## What we're NOT building
[✗-prefixed list. The things most likely to be assumed in scope but aren't.
Minimum 2 items.]

## When we stop
[One sentence. The user-observable signal that means this isn't working and we should stop
before finishing. Not a technical metric — something the human can see.]
```

Then ask: *"Does this match what you had in mind — or should we adjust before building?"*

---

## Step 9 — After human approval

Suggest next steps in plain English:

- If the feature has a UI: *"Run `/saki-builder:proto tasks/prd-[slug].md` to see what it'll look like
  before we write any real code."*
- Always: *"Run `/saki-builder:rplan tasks/prd-[slug].md --slice=1` to plan the first piece."*

Do NOT produce file-level tasks in the PRD — that is `/saki-builder:rplan`'s job.

---

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Showing quality gate score to human | Enforce it internally — never display it |
| Showing Klement / Ulwick / INVEST labels to human | Internal discipline only |
| Acceptance criteria written as HTTP calls in Step 8 | Write what the user observes, not how code works |
| "Screens" that are backend-only | Only list what a user actually sees |
| "When we stop" referencing a metric the human can't observe | Use user-observable behavior |
| Hollow 5-point output (vague criteria, empty screens) | Quality gate still enforces substance — hollow output fails it |
| Skipping Step 0b because the feature sounds obvious | Obvious features fail the premise check most often |

## Script

```bash
#!/bin/bash
mkdir -p tasks
```
