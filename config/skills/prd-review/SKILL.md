---
name: prd-review
description: Adversarial PRD review — deterministic structural scan, then a parallel judge panel (product, metrics, implementation-reality, evidence) that cites every finding and refuses to validate facts it cannot ground. Leads on implementation reality: surfaces the failure/edge paths and hidden build work (migration, flag, permission, rollback) each slice hides, prescribing the criteria to catch them. Hard-gates acceptance criteria to be executable (Given/When/Then + `[auto]`/`[manual]` tag) and gates the verdict on failure-surface completeness, then emits an implementation-reality checklist as the headline so bugs/missing-tasks are caught before manual testing, not during it. Run after /saki-builder:prd, before handing slices to /saki-builder:rplan. Emits a coarse verdict signal, not a precise score.
---

# PRD Review — Structural Scan + Adversarial Judge Panel

You are the review coordinator. Your job: stress-test a PRD produced by `/saki-builder:prd` *before* its slices go to `/saki-builder:rplan`, using an independent judge panel. This complements `/saki-builder:prd`'s in-skill self-gate — a model that scores its own PRD is biased toward it; this skill is the fresh-context second opinion.

**Lead lens — implementation reality.** The highest-priority job is to make VISIBLE what building this actually entails: the failure/edge paths the happy-path criteria hide, and the implementation work a slice silently assumes (migration, backfill, feature flag, new permission, index, rollback). **Judge 3 owns this and leads synthesis** — its prescribed criteria + surfaced hidden work are the headline output, and the verdict gates on failure-surface completeness, not just premise soundness. The other judges (premise, metrics, evidence) still run — a well-tested bad idea is still a bad idea — they just don't lead. Priority order for the whole review: **① surface implementation reality → ② keep every finding grounded → ③ prescribe, don't lecture.**

There are 4 phases. Phase 1 is a hard gate — failure stops the review and sends the author back to `/saki-builder:prd`.

## Honest-judge contract (the four limits this skill is built to contain)

- **No external-fact validation.** Market sizes, user %, benchmarks — the panel neither confirms nor refutes them (that would be hallucination); it routes them to `UNVERIFIABLE` for a human or `/saki-builder:prd --research`.
- **Default to REJECT.** Fluent, well-formatted prose is not evidence of quality — lean skeptical.
- **Signal, not score.** The judge is non-deterministic — output is `SHIP / REVISE / DISCOVERY-FIRST`, one sample, not a number to treat as ground truth.
- **Uncited critique is discarded.** Every finding quotes the section it attacks — *including prescriptions*, which must anchor to the slice/rule they extend, so the judge can't invent a checklist to look thorough.

A human makes the call. This skill informs it; it does not replace it.

---

## Step 0: Load the PRD

Take the target from ARGUMENTS (a `tasks/prd-*.md` path). If none given, find the most recent `tasks/prd-*.md`. Read it fully.

Print:
```
--- PRD LOADED ---
File: [filename]
Self-gate score (from /saki-builder:prd): [X]/100  |  (none — PRD predates the Quality Gate)
DISCOVERY-RISK banner: present / absent
```

If the file has no `/saki-builder:prd` Quality-Gate score line, note it — the PRD may predate the upgraded skill, and the structural scan below matters more.

---

## Phase 1: Structural Completeness Scan

**Pass/fail only. Deterministic. No judgment, no probing — this is the hallucination-free layer.**

A section is PRESENT only if it has real content — not a heading, not "N/A", not a template placeholder.

| # | Required (per `/saki-builder:prd`) | Present & valid? | Notes |
|---|----------------------|------------------|-------|
| 1 | Step-0 premise evidence — load-bearing assumption stated + tagged | | |
| 2 | TL;DR ≤3 sentences; problem names a **measurable harm** | | |
| 3 | Evidence table — each claim tagged; floor met (≥1 `validated` OR a named spike) | | |
| 4 | Primary JTBD in **Klement** form (`When… I want… so I can…`), exactly one | | |
| 5 | §5 outcomes — each has target + **basis tag** (`baseline`/`benchmark`/`aspirational`) + measurement + JTBD link | | |
| 6 | ≥1 **counter-metric** naming the metric/failure-mode it guards | | |
| 7 | **Appetite + outcome-tied Kill Criteria** | | |
| 8 | Vertical slices — **≤7**, each `Serves JTBD` + `Serves outcome` | | |
| 9 | Acceptance criteria — **≤5/slice**; each links an outcome OR names a guardrail; each is **observable** (Given/When/Then + a checkable signal) and tagged **`[auto]`** (curl/test/file/grep) or **`[manual]`** (human/browser) | | |
| 10 | **≥2 Non-Goals**; Rabbit Holes & Open Questions present | | |
| 11 | **Business Rules** (when domain logic present) — each rule falsifiable; each `🔒` invariant tested by a §9 criterion that exercises its **failure path** (over-limit / empty / concurrent / unauthorized / … — see Judge 3's canonical menu), not only the happy path | | |

**Hard-fail rules (any one → Phase 1 FAILED):**
- Primary JTBD in persona form ("As a [role], I want…") → FAIL
- A `validated`/`observed` claim with no cited source → FAIL (fabricated evidence)
- An §5 outcome with a numeric target but no **basis tag** — one of `baseline`/`benchmark`/`aspirational` → FAIL (fabricated precision). `aspirational` IS a valid basis (an honest not-yet-measured target passes); a bare number with no basis does not. Fix in /saki-builder:prd: add the Basis column value.
- Any slice that traces to no JTBD (orphan) → FAIL
- Kill criteria absent or only effort-scoped (not tied to a §5 metric) → FAIL
- A `🔒 INVARIANT` (money/stock/tenant) with no acceptance criterion testing it → FAIL
- An acceptance criterion that is **not observable** (no checkable signal — e.g. "works correctly", "is intuitive") OR lacks an `[auto]`/`[manual]` tag → FAIL (this is what detonates in manual test)
- A `🔒 INVARIANT` whose only criterion tests the **happy path** (no failure/edge criterion) → FAIL

**If ALL ✅:**
```
PHASE 1 PASSED — proceeding to the judge panel
```

**If ANY ❌:**
```
PHASE 1 FAILED — STRUCTURAL BLOCKERS

These are /saki-builder:prd's job to fix, not a judgment call:
  ❌ [item]: [specific gap, with the section]

Action: fix in /saki-builder:prd → re-run /saki-builder:prd-review.
REVIEW STOPPED.
```

Do NOT run the panel if Phase 1 failed — judging a structurally broken PRD wastes tokens.

---

## Phase 2: Adversarial Judge Panel (parallel)

**Run only if Phase 1 passed.** Launch all four judges in parallel with the Agent tool, each in fresh context. Pass the full PRD text in every prompt.

Each judge shares this **contract** (prepend to every prompt):

```
You are reviewing a PRD you did NOT write. Be adversarial: your job is to find why this
fails, not to praise it. Rules you MUST follow:
- DEFAULT TO REJECT when uncertain. Fluent, well-formatted prose is not evidence of quality.
- CITE EVERY FINDING: quote the section heading + the exact text you object to. A finding
  with no citation will be DISCARDED in synthesis — do not pad with vague concerns.
- DO NOT VALIDATE EXTERNAL FACTS. You cannot verify market sizes, user %, benchmarks, or
  competitor claims. Do NOT assert they are true or false — that is hallucination. List them
  under "Unverifiable claims" for a human to ground.
- If a section is genuinely clean, say CLEAN. Do not invent problems to seem thorough.
- Severity: BLOCK (ship-stopper) / HIGH / MED / LOW.

Output:
[LENS] JUDGMENT
Verdict: REJECT | ACCEPT-WITH-FIXES | CLEAN
Findings:
  - [SEV] §<section> "<quoted text>" — <the problem> — <the fix>
Unverifiable claims (facts asserted but not checkable from the document):
  - §<section> "<quoted claim>" — needs grounding (web/data)
```

**Judge 1 — Premise & Product.** Find:
1. Is the Primary JTBD the *real* job, or a feature description wearing a job costume? Quote it.
2. Is the Step-0 load-bearing assumption genuinely validated, or *laundered* — asserted then dressed as fact?
3. Are the Non-Goals real boundaries, or filler that doesn't constrain scope?
4. Does the problem statement name a measurable harm, or just an absent feature?
5. The strongest reason this product/feature should NOT be built — state it even if the PRD rebuts it.

**Judge 2 — Metrics & Outcomes.** Find:
1. Targets with **fabricated precision** — a number with no `baseline`/`benchmark`/`aspirational` basis (an `aspirational`-tagged target is honest, not fabricated — do not flag it).
2. A **Goodhart counter-metric** — one that doesn't name the specific metric + failure mode it guards.
3. Metrics that are **not instrumentable** with what exists or is in scope.
4. Any `observed`/`validated` tag with no cited source.
5. §5 outcomes with **no linking acceptance criterion** anywhere in the slices.

**Judge 3 — Slicing & Implementation-Reality (the lead lens).** Find, in priority order:
1. **Missing failure/edge criteria — the post-manual-test bug source.** For each state-changing or `🔒` slice, name the failure paths the happy-path ACs leave untested and **prescribe the criterion that would catch each** (Given/When/Then + signal, tagged `[auto]`/`[manual]`). Draw from this canonical, **non-exhaustive** menu, applying an item *only where the slice's stated behavior implies that path* — prescribing a path the slice can't reach (e.g. `network-fail` for a slice that makes no network call) violates the grounding rule:
   over-limit · empty/zero · concurrent/double-submit · unauthorized/wrong-tenant · network-fail/timeout · partial-failure/rollback · idempotency-on-retry · pagination/large-N · error-state UI.
   **Anchor every prescription** to the slice + the exact behavior that implies it ("§8 Slice 3 debits balance → concurrent-debit criterion"). Prescribe, never merely flag — a flag forces the author to re-derive the fix and re-review. These prescribed criteria are exactly the "new tasks / bugs" that otherwise surface only when a human tests by hand.
2. **Hidden implementation work a slice ASSUMES but never states.** For each slice, name the build work its stated behavior silently requires but the PRD omits: migration/backfill of existing rows, a feature flag, a new permission/role, an index the metric query needs, seed data, a rollback path. Anchor each to the slice text that implies it. This is the mid-build discovery this review exists to prevent — surface it now, not in the build.
3. Slices failing INVEST — especially **horizontal-as-vertical** ("build the API layer" is not a slice).
4. **Forward-dependency violations** (slice N needs N+1) or orphan slices serving no JTBD.
5. Is Slice 1 a **vertical walking skeleton**, or plumbing that ships no user-visible value?
6. Appetite vs slice count mismatch (a "1 afternoon" appetite with 7 fat slices).
7. Acceptance criteria that are **not observable** ("works correctly" is not testable).
8. Business rules (§10) that are vague/unfalsifiable, or a `🔒` invariant with no criterion testing it.

**Judge 4 — Evidence & Grounding (the honesty lens).** Find:
1. Walk EVERY factual claim in §2 and §5. For each, decide: **self-supporting from the document, or reliant on outside truth?**
2. List every outside-truth claim under "Unverifiable claims." **Do not judge whether it's true** — only whether the PRD can stand on it without grounding.
3. Is the **evidence floor** met (≥1 `validated` or a named spike), or is the table effectively all-`assumed` behind a `validated` label?
4. Does the PRD honestly carry a `DISCOVERY-RISK` banner where its evidence is thin, or does it overclaim confidence?

Wait for all four. Print each judgment in full.

---

## Phase 3: Synthesis

1. **Discard uncited findings.** A finding that doesn't quote a section is dropped — state how many were dropped.
2. **Deduplicate** — the same issue from two judges counts once (keep the higher severity).
3. **Classify** — BLOCK (fix before `/saki-builder:rplan`) / HIGH / MED / LOW.
4. **Collect unverifiable claims** from all judges into one list — these are NOT defects, they are grounding TODOs (run `/saki-builder:prd --research` or validate manually).
5. **Assemble the implementation-reality checklist — the headline output.** Two sections, in this order:
   - **Newly-surfaced (this review's payload):** every failure/edge criterion Judge 3 prescribed + every hidden-work item, each anchored to its slice. These are the "new tasks / bugs" caught *before* manual test instead of during it.
   - **Pre-existing `[manual]` ACs:** the `[manual]`-tagged criteria already in the PRD, collected as the human's hand-run script.
   `[auto]` criteria are not listed — `/saki-builder:qa` runs those. This checklist **leads** the printed synthesis; the verdict and finding lists follow it.
6. **Emit a verdict signal — NOT a precise score** (the judge is non-deterministic; a decimal would be false precision):

   | Signal | Condition |
   |--------|-----------|
   | `DISCOVERY-FIRST` | premise laundered, OR evidence floor failed, OR the load-bearing assumption is unvalidated with no spike |
   | `REVISE` | any BLOCK or HIGH finding stands, **OR any state-changing/`🔒` slice is missing a prescribed failure criterion or has unaddressed hidden work** — regardless of that finding's severity |
   | `SHIP` | no BLOCK/HIGH; **every state-changing/`🔒` slice's failure surface is covered**; only MED/LOW polish remains |

   Print a **coverage line**: `Failure-surface: N/M state-changing slices fully covered · K hidden-work items surfaced.` A gap here holds the verdict at `REVISE` even when the premise is clean — implementation reality, not prose quality, decides ship.

Write the full findings to `tasks/prd-[feature]-review.md`. Then print:

```
--- PRD REVIEW SYNTHESIS ---
Verdict: DISCOVERY-FIRST | REVISE | SHIP   (a signal — one non-deterministic sample, not ground truth)
Failure-surface: [N]/[M] state-changing slices fully covered · [K] hidden-work items surfaced

IMPLEMENTATION-REALITY CHECKLIST (the headline — caught before manual test, not during):
  Newly surfaced this review:
    ☐ [slice] Given … When … Then … — expected signal: […]   [auto|manual]   (prescribed: <failure path>)
    ☐ [slice] hidden work: <migration | flag | permission | index | rollback> — <why the slice needs it>
  Pre-existing [manual] ACs (hand-run script):
    ☐ [slice] Given … When … Then … — expected signal: […]   [manual]
  (full list + the [auto] criteria for /saki-builder:qa are written to the review file)

Uncited findings discarded: [N]
BLOCK:  ❌ [§section] [judge]: [issue] → [fix]
HIGH:   ⚠ [§section] [judge]: [issue] → [fix]
MED/LOW: [count, listed in the review file]

Unverifiable claims (grounding TODO, NOT defects):
  • [§section] "[claim]" — ground via /saki-builder:prd --research or data

Caveat: external facts were NOT validated; one non-deterministic sample; a human decides.
```

---

## Phase 4: Recommendation

```
--- REVIEW COMPLETE ---
Phase 1 (Structural): PASSED / FAILED
Verdict:              DISCOVERY-FIRST / REVISE / SHIP

Next:
  SHIP            → proceed: hand slice 1 to /saki-builder:rplan
  REVISE          → fix BLOCK/HIGH in /saki-builder:prd, re-run /saki-builder:prd-review
  DISCOVERY-FIRST → the premise/evidence is too thin for a spec.
                    Run /saki-builder:shaping-requirements or ground the load-bearing claim, then /saki-builder:prd again.
```

---

## Rules

Priority order: **① surface implementation reality → ② keep every finding grounded → ③ prescribe, don't lecture.** When they conflict, that order wins.

- NEVER skip Phase 1. A missing section is a structural fail, never a judgment call.
- Launch the four judges in parallel — never sequentially. **Judge 3 leads synthesis and the verdict.**
- A BLOCK from any judge = the PRD is not ready, regardless of the `/saki-builder:prd` self-gate score.
- **Judge 3 must PRESCRIBE** missing failure/edge criteria and name hidden work — never merely flag absence (a flag forces the author to re-derive the fix and re-review). Every prescription anchors to the slice + the behavior that implies it; a path the slice can't reach must NOT be prescribed (that's inventing work — a grounding violation).
- **Failure-surface completeness gates the verdict.** A state-changing/`🔒` slice with an uncovered failure path or unaddressed hidden work holds at `REVISE` even when the premise is clean.
- An acceptance criterion is NOT done at PRD time unless it is **observable** and tagged `[auto]`/`[manual]` — Phase 1 fails otherwise; post-manual-test "new tasks/bugs" almost always trace to this gate being skipped.
- The grounding rules — no external-fact validation, discard uncited, signal-not-score — live in the Honest-judge contract. A judge that says "I'll validate that claim myself" is violating them: route the claim to Unverifiable claims.

---

## Project Override

This is the **general version**. For project-specific judges (a domain metric model, a house JTBD style), create:
```
.claude/skills/prd-review/SKILL.md
```
That file overrides this one. Run `/saki-builder:init-env` to scaffold a project-specific override.
