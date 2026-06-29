---
name: prd-review
description: Adversarial PRD review — deterministic structural scan, then a parallel judge panel (product, metrics, slicing, evidence) that cites every finding and refuses to validate facts it cannot ground. Hard-gates acceptance criteria to be executable (Given/When/Then + `[auto]`/`[manual]` tag) and invariants to test their failure path, then emits a manual-test checklist so bugs/missing-tasks are caught before manual testing, not discovered during it. Run after /prd, before handing slices to /rplan. Emits a coarse verdict signal, not a precise score.
---

# PRD Review — Structural Scan + Adversarial Judge Panel

You are the review coordinator. Your job: stress-test a PRD produced by `/prd` *before* its slices go to `/rplan`, using an independent judge panel. This complements `/prd`'s in-skill self-gate — a model that scores its own PRD is biased toward it; this skill is the fresh-context second opinion.

There are 4 phases. Phase 1 is a hard gate — failure stops the review and sends the author back to `/prd`.

## Honest-judge contract (read before running — these limits are designed in, not apologized for)

An LLM judge has known failure modes. This skill is built to contain them, not to pretend they're absent:

- **It cannot verify external facts.** Market sizes, user percentages, benchmarks — the panel must NOT validate or refute these (doing so from model memory IS hallucination). It lists them as `UNVERIFIABLE` for a human or a grounded `/prd --research` pass.
- **It leans lenient on fluent prose.** Counteracted by **default-to-REJECT** framing and severity discipline.
- **It is non-deterministic.** The same PRD reviewed twice can differ. The output is therefore a **signal** (`SHIP / REVISE / DISCOVERY-FIRST`), not a precise number to treat as ground truth.
- **Uncited critique is discarded.** Every finding must quote the section it attacks, so you can verify it and the judge can't invent problems to look thorough.

A human makes the call. This skill informs that call; it does not replace it.

---

## Step 0: Load the PRD

Take the target from ARGUMENTS (a `tasks/prd-*.md` path). If none given, find the most recent `tasks/prd-*.md`. Read it fully.

Print:
```
--- PRD LOADED ---
File: [filename]
Self-gate score (from /prd): [X]/100  |  (none — PRD predates the Quality Gate)
DISCOVERY-RISK banner: present / absent
```

If the file has no `/prd` Quality-Gate score line, note it — the PRD may predate the upgraded skill, and the structural scan below matters more.

---

## Phase 1: Structural Completeness Scan

**Pass/fail only. Deterministic. No judgment, no probing — this is the hallucination-free layer.**

A section is PRESENT only if it has real content — not a heading, not "N/A", not a template placeholder.

| # | Required (per `/prd`) | Present & valid? | Notes |
|---|----------------------|------------------|-------|
| 1 | Step-0 premise evidence — load-bearing assumption stated + tagged | | |
| 2 | TL;DR ≤3 sentences; problem names a **measurable harm** | | |
| 3 | Evidence table — each claim tagged; floor met (≥1 `validated` OR a named spike) | | |
| 4 | Primary JTBD in **Klement** form (`When… I want… so I can…`), exactly one | | |
| 5 | §5 outcomes — each has target + **basis tag** + measurement + JTBD link | | |
| 6 | ≥1 **counter-metric** naming the metric/failure-mode it guards | | |
| 7 | **Appetite + outcome-tied Kill Criteria** | | |
| 8 | Vertical slices — **≤7**, each `Serves JTBD` + `Serves outcome` | | |
| 9 | Acceptance criteria — **≤5/slice**; each links an outcome OR names a guardrail; each is **observable** (Given/When/Then + a checkable signal) and tagged **`[auto]`** (curl/test/file/grep) or **`[manual]`** (human/browser) | | |
| 10 | **≥2 Non-Goals**; Rabbit Holes & Open Questions present | | |
| 11 | **Business Rules** (when domain logic present) — each rule falsifiable; each `🔒` invariant tested by a §9 criterion that exercises its **failure path** (over-limit / empty / concurrent / unauthorized), not only the happy path | | |

**Hard-fail rules (any one → Phase 1 FAILED):**
- Primary JTBD in persona form ("As a [role], I want…") → FAIL
- A `validated`/`observed` claim with no cited source → FAIL (fabricated evidence)
- An §5 outcome with a target but no basis tag → FAIL
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

These are /prd's job to fix, not a judgment call:
  ❌ [item]: [specific gap, with the section]

Action: fix in /prd → re-run /prd-review.
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
1. Targets with **fabricated precision** — a number with no `baseline`/`benchmark` basis.
2. A **Goodhart counter-metric** — one that doesn't name the specific metric + failure mode it guards.
3. Metrics that are **not instrumentable** with what exists or is in scope.
4. Any `observed`/`validated` tag with no cited source.
5. §5 outcomes with **no linking acceptance criterion** anywhere in the slices.

**Judge 3 — Slicing & Feasibility.** Find:
1. Slices failing INVEST — especially **horizontal-as-vertical** ("build the API layer" is not a slice).
2. **Forward-dependency violations** (slice N needs N+1) or orphan slices serving no JTBD.
3. Is Slice 1 a **vertical walking skeleton**, or plumbing that ships no user-visible value?
4. Appetite vs slice count mismatch (a "1 afternoon" appetite with 7 fat slices).
5. Acceptance criteria that are **not observable** ("works correctly" is not testable).
6. Business rules (§10) that are vague/unfalsifiable, or a `🔒` invariant with no criterion testing it.
7. **Missing failure/edge criteria — the post-manual-test bug source.** For each slice, name the failure paths the happy-path ACs leave untested (over-limit, empty, concurrent, unauthorized, network-fail) and **write the criterion that would catch them** (Given/When/Then + signal). Do NOT just flag — *prescribe* the criterion, tagged `[auto]`/`[manual]`. These prescribed criteria are exactly the "new tasks / bugs" that otherwise surface only when a human tests by hand.

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
3. **Classify** — BLOCK (fix before `/rplan`) / HIGH / MED / LOW.
4. **Collect unverifiable claims** from all judges into one list — these are NOT defects, they are grounding TODOs (run `/prd --research` or validate manually).
5. **Assemble the manual-test checklist.** Collect every `[manual]`-tagged acceptance criterion (across all slices) PLUS every failure/edge criterion Judge 3 prescribed, into one ordered checklist. This is the script a human runs by hand — it **pre-scopes** manual testing so bugs/missing-tasks are caught against a list, not *discovered* mid-test. The `[auto]` criteria are not listed here — `/qa` runs those.
6. **Emit a verdict signal — NOT a precise score** (the judge is non-deterministic; a decimal would be false precision):

   | Signal | Condition |
   |--------|-----------|
   | `DISCOVERY-FIRST` | premise laundered, OR evidence floor failed, OR the load-bearing assumption is unvalidated with no spike |
   | `REVISE` | any BLOCK or HIGH finding stands |
   | `SHIP` | no BLOCK/HIGH; only MED/LOW polish remains |

Write the full findings to `tasks/prd-[feature]-review.md`. Then print:

```
--- PRD REVIEW SYNTHESIS ---
Verdict: DISCOVERY-FIRST | REVISE | SHIP   (a signal, not ground truth — one non-deterministic sample)

Uncited findings discarded: [N]
BLOCK:  ❌ [§section] [judge]: [issue] → [fix]
HIGH:   ⚠ [§section] [judge]: [issue] → [fix]
MED/LOW: [count, listed in the review file]

Unverifiable claims (grounding TODO, NOT defects):
  • [§section] "[claim]" — ground via /prd --research or data

Manual-test checklist (run these by hand — pre-scoped so nothing is discovered mid-test):
  ☐ [slice] Given … When … Then … — expected signal: […]   [manual]
  (full list + the [auto] criteria for /qa are written to the review file)

Honest caveats: external facts were NOT validated; this is one sample of a non-deterministic
judge; a human decides.
```

---

## Phase 4: Recommendation

```
--- REVIEW COMPLETE ---
Phase 1 (Structural): PASSED / FAILED
Verdict:              DISCOVERY-FIRST / REVISE / SHIP

Next:
  SHIP            → proceed: hand slice 1 to /rplan
  REVISE          → fix BLOCK/HIGH in /prd, re-run /prd-review
  DISCOVERY-FIRST → the premise/evidence is too thin for a spec.
                    Run /shaping-requirements or ground the load-bearing claim, then /prd again.
```

---

## Rules

- NEVER skip Phase 1. A missing section is a structural fail, never a judgment call.
- Launch the four judges in parallel — never sequentially.
- A BLOCK from any judge = the PRD is not ready, regardless of the `/prd` self-gate score.
- NEVER let a judge validate an external fact. Unverifiable ≠ false; it means "ground it before trusting it."
- Discard uncited findings — they are unverifiable by definition.
- The verdict is a signal for a human, not an approval stamp. Do not phrase it as ground truth.
- "I'll validate that claim myself" from a judge = a rules violation; route it to Unverifiable claims.
- An acceptance criterion is NOT done at PRD time unless it is **observable** and tagged `[auto]`/`[manual]` — Phase 1 fails otherwise. Post-manual-test "new tasks/bugs" almost always trace to this gate being skipped; do not wave it through.
- Judge 3 must **prescribe** missing failure/edge criteria, never merely flag their absence — a flag forces the author to re-derive the fix and re-review (the back-and-forth this gate exists to remove).

---

## Project Override

This is the **general version**. For project-specific judges (a domain metric model, a house JTBD style), create:
```
.claude/skills/prd-review/SKILL.md
```
That file overrides this one. Run `/init-env` to scaffold a project-specific override.
