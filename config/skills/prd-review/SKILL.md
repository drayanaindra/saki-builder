---
name: prd-review
description: Adversarial PRD review — deterministic structural scan, then a parallel judge panel (product, evidence & metrics, implementation-reality) PLUS a driver→navigator pair-review pass (high-risk PRDs only) that hunts the implementation + scope blind spots the panel misses. Every reviewing voice is bound to be concise + faithful — one line per finding, every claim cites the text it rests on, no fabrication. Leads on implementation reality: surfaces the failure/edge paths and hidden build work (migration, flag, permission, rollback) each slice hides, prescribing the criteria to catch them. Hard-gates acceptance criteria to be executable (Given/When/Then + `[auto]`/`[manual]` tag). Emits an implementation-reality checklist as the headline, a READINESS (Definition-of-Ready) gate for buildability-now, and a technical-surface gaps list (undefined load-bearing DB · API · architecture · UI/UX surfaces) — surfacing gaps and handing off, never designing. Writes a team-shareable, trackable review record (PRD-version pinned · finding IDs + disposition · re-review reconcile). Run after /saketek:prd, before handing slices to /saketek:rplan. Emits a coarse verdict signal, not a precise score.
---

# PRD Review — Structural Scan + Adversarial Judge Panel + Pair-Review Blind-Spot Pass

You are the review coordinator. Your job: stress-test a PRD produced by `/saketek:prd` *before* its slices go to `/saketek:rplan`, using an independent judge panel and a paired blind-spot pass. This complements `/saketek:prd`'s in-skill self-gate — a model that scores its own PRD is biased toward it; this skill is the fresh-context second opinion.

**Lead lens — implementation reality.** The highest-priority job is to make VISIBLE what building this actually entails: the failure/edge paths the happy-path criteria hide, and the implementation work a slice silently assumes (migration, backfill, feature flag, new permission, index, rollback). **Judge 3 owns this and leads synthesis** — its prescribed criteria + surfaced hidden work are the headline output, and the verdict gates on failure-surface completeness, not just premise soundness. The other judges (premise, metrics, evidence) still run — a well-tested bad idea is still a bad idea — they just don't lead. Priority order for the whole review: **① surface implementation reality → ② keep every finding grounded → ③ prescribe, don't lecture.**

The review runs: **Phase 1** (structural hard gate) → **Phase 2** (parallel judge panel) → **Phase 2.5** (driver→navigator pair-review blind-spot pass) → **Phase 3** (synthesis: `R#` findings ledger + implementation-reality checklist + **Readiness / Definition-of-Ready** + **technical-surface & contract map** + verdict) → **Phase 4** (recommendation). Phase 1 is a hard gate — failure stops the review and sends the author back to `/saketek:prd`.

## Honest-judge contract (the four limits this skill is built to contain)

- **No external-fact validation.** Market sizes, user %, benchmarks — the panel neither confirms nor refutes them (that would be hallucination); it routes them to `UNVERIFIABLE` for a human or `/saketek:prd --research`.
- **Default to REJECT.** Fluent, well-formatted prose is not evidence of quality — lean skeptical.
- **Signal, not score.** The judge is non-deterministic — output is `SHIP / REVISE / DISCOVERY-FIRST`, one sample, not a number to treat as ground truth.
- **Uncited critique is discarded.** Every finding quotes the section it attacks — *including prescriptions*, which must anchor to the slice/rule they extend, so the judge can't invent a checklist to look thorough.

A human makes the call. This skill informs it; it does not replace it.

## Concise & Faithful — ALWAYS, every phase, every voice (governing principle)

This binds **every reviewing voice at every phase** — each panel judge, both pair agents, AND *your own*
coordinator output (the Phase-1 notes, the synthesis, every printed block, and the saved review file).
It is not a per-agent clause; it is a skill-wide invariant. When any instruction below conflicts with it,
this wins.

- **Concise (always).** One line per finding. No preamble, no PRD restatement, no praise, no hedging.
  A clean section = say `CLEAN` and stop. Your synthesis and the review file obey the same rule —
  findings, not essays. Tables and terse bullets over paragraphs.
- **Faithful (always).** Every claim — findings, blind spots, prescriptions, readiness blockers, the
  technical-surface map, AND your own synthesis — quotes the exact text it rests on (an `R#`, a `§`
  section, a slice). Speculation with no anchor ("might have edge cases", "could be slow") is
  **discarded, not raised**. External facts are never validated (route to Unverifiable). You never
  fabricate — no invented schema, endpoint, architecture, UI, metric, or requirement the PRD didn't
  state. Ungrounded ⇒ not stated.

This makes explicit and universal (it does not replace) the Honest-judge contract's
cite-everything / discard-uncited / no-external-validation / default-reject rules.

---

## Step 0: Load the PRD

Take the target from ARGUMENTS (a `tasks/prd-*.md` path). If none given, find the most recent `tasks/prd-*.md`. Read it fully.

Also parse from ARGUMENTS:
- **`--reviewer @name`** — who is running this review (team-facing metadata). Default `unassigned`.
  Do NOT auto-fill it from the PRD's `Owner` — best-practice review keeps reviewer ≠ author.

Capture the **PRD version pin** from the PRD's own header — the `<!-- prd-quality: N/100 -->` score and the
`Updated: YYYY-MM-DD` field. This pins exactly which version you reviewed, so a later review against an
evolved PRD is visibly newer.

Print:
```
--- PRD LOADED ---
File: [filename]
Reviewer: [@name | unassigned]
PRD version: quality [X]/100 · Updated [YYYY-MM-DD]   |  (none — PRD predates the Quality Gate)
DISCOVERY-RISK banner: present / absent
```

If the file has no `/saketek:prd` Quality-Gate score line, note it — the PRD may predate the upgraded skill, and the structural scan below matters more.

---

## Step 0.5: Re-review reconcile (only if a prior review file exists)

Look for `tasks/prd-<slug>-review.md` (same slug as the PRD). **If none exists → this is Round 1; skip
this step.** If one exists, read it first and set up carry-forward *before* running the phases:

1. Extract the prior findings — their **IDs (`R#`)**, severities, and **Disposition** values — and the
   prior PRD version pin.
2. Note whether the PRD changed since (compare the pinned `Updated`/quality to the current header).
3. Set **`Round: k+1`**. You will REUSE prior `R#` for issues that recur, never renumber a retired one.

After Phases 1–3 produce the current findings, reconcile (this happens in Phase 3 synthesis):
- a prior finding **no longer present** in the PRD → `Disposition: Fixed (auto, round k)`.
- a prior finding still present with `Won't-fix` / `Deferred` → **carry the disposition forward**; do NOT
  re-raise it as a new finding.
- a prior finding still present + `Open` → keep the **same `R#`**.
- a genuinely new issue → next free `R#` (continue numbering; never reuse an ID).

This makes the loop measurable: print `Round k: C carried · F fixed · N new` in synthesis — the
convergence signal the pipeline uses to decide recut-vs-loop.

---

## Phase 1: Structural Completeness Scan

**Pass/fail only. Deterministic. No judgment, no probing — this is the hallucination-free layer.**

A section is PRESENT only if it has real content — not a heading, not "N/A", not a template placeholder.

| # | Required (per `/saketek:prd`) | Present & valid? | Notes |
|---|----------------------|------------------|-------|
| 1 | **§2 states the load-bearing assumption + tag** — an explicit `**Load-bearing assumption:** <X> — assumed/observed/validated` line in §2 (the premise from `/saketek:prd` Step 0b, in the file). A bet also carries it in the DISCOVERY-RISK banner; a grounded PRD still states it in §2 | | |
| 2 | TL;DR ≤3 sentences; problem names a **measurable harm** | | |
| 3 | Evidence table — each claim tagged; floor met (≥1 `validated` OR a named spike) | | |
| 4 | Primary JTBD in **Klement** form (`When… I want… so I can…`), exactly one | | |
| 5 | §5 outcomes — each primary/secondary has target + **basis tag** (`baseline`/`benchmark`/`aspirational`) + measurement + a **JTBD link** (a `Jn` in §3/§4); the **counter-metric** row instead names the metric(s) it guards (`guards 5.x`, not a `Jn`) | | |
| 6 | ≥1 **counter-metric** naming the metric/failure-mode it guards | | |
| 7 | **Appetite** (§6, band + span) **+ outcome-tied Kill Criteria**; **§7 Solution Shape** names the chosen shape + a **Decision Log** (alternatives considered w/ why-not) OR states there was one obvious shape | | |
| 8 | Vertical slices — **≤7**, each `Serves: J<n> · 5.<x>` where `Jn` resolves to a job defined in §3/§4 and `5.x` to an outcome in §5 (a `Jn`/`5.x` with no matching definition = dangling). Resolution is **bidirectional** — a §4 related job referenced by no slice **and** no §5 outcome is an **orphan job** (a Judge-1 scope finding, *not* a Phase-1 hard-fail — see the hard-fail carve-out) | | |
| 9 | Acceptance criteria — **≤5/slice**; each links an outcome OR names a guardrail; each is **observable** (Given/When/Then + a checkable signal) and tagged **`[auto]`** (curl/test/file/grep) or **`[manual]`** (human/browser) | | |
| 10 | **≥2 Non-Goals**; Rabbit Holes & Open Questions present | | |
| 11 | **Business Rules** (when domain logic present) — each rule falsifiable; each `🔒` invariant tested by a §9 criterion that exercises its **failure path** (over-limit / empty / concurrent / unauthorized / … — see Judge 3's canonical menu), not only the happy path | | |

**Hard-fail rules (any one → Phase 1 FAILED):**
- Primary JTBD in persona form ("As a [role], I want…") → FAIL
- A `validated`/`observed` claim with no cited source → FAIL (fabricated evidence)
- An §5 outcome with a numeric target but no **basis tag** — one of `baseline`/`benchmark`/`aspirational` → FAIL (fabricated precision). `aspirational` IS a valid basis (an honest not-yet-measured target passes); a bare number with no basis does not. Fix in /saketek:prd: add the Basis column value.
- Any slice or §5 outcome whose `Jn` reference resolves to no job defined in §3/§4 (orphan / dangling JTBD) → FAIL (the counter-metric's `guards 5.x` is not a `Jn` and is exempt). The **reverse direction is NOT a hard-fail**: a §4 related job that no slice/outcome references (an *orphan job*) is scope theater, not a broken reference — route it to Judge 1 as a scope finding, do not fail Phase 1 on it
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

These are /saketek:prd's job to fix, not a judgment call:
  ❌ [item]: [specific gap, with the section]

Action: fix in /saketek:prd → re-run /saketek:prd-review.
REVIEW STOPPED.
```

Do NOT run the panel if Phase 1 failed — judging a structurally broken PRD wastes tokens.

---

## Phase 2: Adversarial Judge Panel (parallel)

**Run only if Phase 1 passed.** Launch all three judges in parallel with the Agent tool, each in fresh context. Pass the full PRD text in every prompt.

Each judge shares this **contract** (prepend to every prompt):

```
You are reviewing a PRD you did NOT write. Be adversarial: your job is to find why this
fails, not to praise it. Rules you MUST follow:
- BE CONCISE: one line per finding. No preamble, no PRD restatement, no praise, no hedging.
  This is a rule, not a style note — verbose output is a defect.
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
6. **Orphan job** — a §4 related job that no §5 outcome **and** no slice serves. This is a dead JTBD / scope theater (the structural mirror of a dangling ref, caught here rather than in Phase 1). Flag it: cut the job, or name the outcome/slice that should serve it.

**Judge 2 — Evidence, Metrics & Grounding (the honesty lens).** Find:
1. Walk EVERY factual claim in §2 and §5: is it **self-supporting from the document, or reliant on outside truth?** List every outside-truth claim under "Unverifiable claims" — do NOT judge whether it's true, only whether the PRD can stand on it without grounding.
2. Any `observed`/`validated` tag with **no cited source** (fabricated evidence).
3. Is the **evidence floor** met (≥1 `validated` or a named spike), or is the table effectively all-`assumed` behind a `validated` label? Does the PRD honestly carry a `DISCOVERY-RISK` banner where its evidence is thin, or overclaim confidence?
4. Targets with **fabricated precision** — a number with no `baseline`/`benchmark`/`aspirational` basis (an `aspirational`-tagged target is honest, not fabricated — do not flag it), including a **circular `baseline N→M`** whose starting number N cites no source (it restates the target instead of grounding it).
5. A **Goodhart counter-metric** — one that doesn't name the specific metric + failure mode it guards.
6. Metrics that are **not instrumentable** with what exists or is in scope.
7. §5 outcomes with **no linking acceptance criterion** anywhere in the slices.

**Judge 3 — Slicing & Implementation-Reality (the lead lens).** Find, in priority order:
1. **Missing failure/edge criteria — the post-manual-test bug source.** For each state-changing or `🔒` slice, name the failure paths the happy-path ACs leave untested and **prescribe the criterion that would catch each** (Given/When/Then + signal, tagged `[auto]`/`[manual]`). Draw from this canonical, **non-exhaustive** menu, applying an item *only where the slice's stated behavior implies that path* — prescribing a path the slice can't reach (e.g. `network-fail` for a slice that makes no network call) violates the grounding rule:
   over-limit · empty/zero · concurrent/double-submit · unauthorized/wrong-tenant · network-fail/timeout · partial-failure/rollback · idempotency-on-retry · pagination/large-N · error-state UI.
   **Anchor every prescription** to the slice + the exact behavior that implies it ("§8 Slice 3 debits balance → concurrent-debit criterion"). Prescribe, never merely flag — a flag forces the author to re-derive the fix and re-review. These prescribed criteria are exactly the "new tasks / bugs" that otherwise surface only when a human tests by hand.
2. **Hidden implementation work a slice ASSUMES but never states.** For each slice, name the build work its stated behavior silently requires but the PRD omits: migration/backfill of existing rows, a feature flag, a new permission/role, an index the metric query needs, seed data, a rollback path. Anchor each to the slice text that implies it. This is the mid-build discovery this review exists to prevent — surface it now, not in the build. **Prescribe the fix as an `Assumes:` line on that slice** (`Assumes: <the hidden work>` — `/saketek:prd` Step 3) — or, when the work is a load-bearing capability in its own right, prescribe **promoting it to its own slice**. It counts as *addressed* only when the slice carries that `Assumes:` line (or the dedicated slice); an unstated assumption is not addressed. This is the wire that makes the finding reach `/saketek:rplan` — `/saketek:pickup` bakes the `Assumes:` line into the PRD on REVISE, and rplan ingests it from the PRD (the review file itself is not read downstream).
3. Slices failing INVEST — especially **horizontal-as-vertical** ("build the API layer" is not a slice).
4. **Forward-dependency violations** (slice N needs N+1) or orphan slices serving no JTBD.
5. Is Slice 1 a **vertical walking skeleton**, or plumbing that ships no user-visible value?
6. Appetite vs slice count mismatch (a "1 afternoon" appetite with 7 fat slices).
7. Acceptance criteria that are **not observable** ("works correctly" is not testable).
8. Business rules (§10) that are vague/unfalsifiable, or a `🔒` invariant with no criterion testing it.

Wait for all three. Print each judgment in full.

---

## Phase 2.5: Pair Review — blind-spot pass (driver → navigator)

**Run only if Phase 1 passed AND the PRD is high-risk, after the panel.** High-risk = the PRD carries any
`🔒 INVARIANT` (money/stock/tenant — §10/§11) **OR** more than 4 vertical slices (§8) — the surface where a
missed implementation/scope blind spot is expensive enough to justify two more (sequential) agents. On a
**low-risk PRD** (no `🔒`, ≤4 slices), **skip this phase** and print
`Pair review: skipped (low-risk PRD — no 🔒 invariant, ≤4 slices)`; Judge 3 already leads implementation
coverage, so the pair adds little there. When it runs, this is the review analog of pair programming: one
agent drafts, the other reviews/prunes/augments. Its ONE job is to catch the **implementation** and
**scope** blind spots the panel *missed* — not to re-review what the panel already found. Both agents
are bound by the **Concise & Faithful** principle (one line per finding; every item quotes the slice/
section it rests on; ungrounded speculation is discarded, not raised; a path a slice cannot reach must
NOT be prescribed — the same grounding guard Judge 3 uses).

Pass the full PRD **and the panel's findings** to both. Run them as two fresh-context Agent subagents,
**driver first, then navigator** (the navigator must see the driver's draft).

**Driver.** Prompt: *"You are the driver in a pair review. The panel already found the attached
findings — do NOT repeat them. Draft the blind spots the panel MISSED, on two axes only:*
- ***Implementation:** build-time detonations the panel didn't name — an uncovered edge/failure path, or
  hidden work a slice assumes (migration · backfill · feature flag · new permission/role · an index the
  metric query needs · seed data · rollback), or an integration / slice-sequencing trap.*
- ***Scope:** silent scope creep, a slice that is secretly two capabilities, a 'non-goal' that is
  actually load-bearing, a dependency that widens scope, an appetite/slice mismatch the panel waved
  through, or dead/orphan scope.*
*One terse line per candidate, each quoting the exact slice/section it rests on. If an axis is genuinely
clean, say CLEAN for it. Do not design solutions — name the miss + (for implementation) prescribe the
one criterion or work-item that closes it, anchored to the slice."*

**Navigator.** Prompt: *"You are the navigator. Review the driver's list against the PRD and the panel
findings. (1) PRUNE any item that is ungrounded (no quotable anchor) or already covered by the panel —
faithfulness + concision. (2) CONFIRM each survivor with its citation. (3) ADD any implementation/scope
blind spot the driver missed, same two axes, same grounding rule. Output only the tight, verified,
net-new blind-spot list — one line each, each with its `§`/slice anchor and (implementation) its
prescribed criterion/work-item. If nothing survives, say NONE."*

The navigator's output is the pair's result. Each survivor becomes a finding in synthesis with source
`Pair`; it feeds the implementation-reality checklist, the failure-surface coverage line, and (for an
undefined load-bearing contract) the readiness + technical-surface roll-ups. **Judge 3 still leads
synthesis** — the pair augments implementation + scope coverage; it does not replace the panel.

---

## Phase 3: Synthesis

Assemble findings from the panel AND the pair (Phase 2.5, if it ran — skipped on low-risk PRDs yields no
pair findings). Bound by **Concise & Faithful** — this is a ledger, not an essay.

1. **Discard uncited findings.** A finding that doesn't quote a section is dropped — state how many.
2. **Deduplicate** — the same issue from two judges counts once (keep the higher severity). Pair findings
   are already net-new vs the panel; dedupe only within the union.
3. **Assign IDs + Disposition (the trackable ledger).** Give every surviving finding a stable ID
   `R1, R2, …` with `severity · source [panel:<lens> | Pair] · <§/slice anchor>`. Default
   **`Disposition: Open`**. **Apply the Step-0.5 reconcile** if a prior review existed: reuse the prior
   `R#` for a recurring issue, carry a `Won't-fix`/`Deferred` disposition forward (don't re-raise),
   mark a vanished issue `Fixed (auto, round k)`, and give a genuinely new issue the next free ID.
   Solo builders ignore Disposition (fix + re-run); teams edit it to track closure.
4. **Classify** — BLOCK (fix before `/saketek:rplan`) / HIGH / MED / LOW.
5. **Collect unverifiable claims** from all judges into one list — NOT defects, grounding TODOs
   (run `/saketek:prd --research` or validate manually).
6. **Assemble the implementation-reality checklist — the headline output.** Two sections, in this order,
   each line citing its `R#`:
   - **Newly-surfaced (this review's payload):** every failure/edge criterion Judge 3 **and the pair**
     prescribed + every hidden-work item, each anchored to its slice. The "new tasks / bugs" caught
     *before* manual test.
   - **Pre-existing `[manual]` ACs:** the `[manual]`-tagged criteria already in the PRD, as the human's
     hand-run script.
   `[auto]` criteria are not listed — `/saketek:qa` runs those. This checklist **leads** the printed
   synthesis.
7. **Readiness — Definition of Ready (buildability NOW, distinct from the verdict).** Roll up from the
   findings + a direct read of §12/§14. Each ❌ names the blocker + its `R#`/section — no free-floating
   readiness claims.

   | # | Definition of Ready | READY when |
   |---|---------------------|------------|
   | 1 | Slice 1 startable now | walking skeleton · forward-deps only · its inputs exist |
   | 2 | No build-blocking Open Question | every §12 Q is resolved, non-blocking (doesn't gate slice 1), or a named spike |
   | 3 | Dependencies (§14) available | each is real + accessible/owned — not "TBD", not an unbuilt service with no plan |
   | 4 | Bet accepted or validated | no unresolved DISCOVERY-RISK — load-bearing assumption validated OR the bet explicitly accepted; AND no `assumed` row that **gates a committed §5 metric** (an adoption/willingness claim the primary/secondary outcome rests on) is left un-accepted, even if the whole table isn't 100% `assumed` |
   | 5 | No open BLOCK/HIGH | every ship-stopper is resolved or dispositioned (`Won't-fix`/`Deferred`) |

   Emit `Readiness: READY | NOT READY — <blockers>`. DoR #3 flags the PRD-level gap only — it cites the
   §14 line, it does NOT probe the filesystem/network (that is `/saketek:rplan`'s job). An **omitted
   §14** (`/saketek:prd` drops it when there are no dependencies) reads as `none` → DoR #3 READY, not
   a gap; likewise an omitted §13 or §15 (a no-UI PRD has no screens section). Absent-because-none ≠ missing
   — do not raise a false NOT-READY on it. **Readiness never requires the lock:** `/saketek:prd-review` runs
   *before* the `/saketek:proto` lock (it is how the PRD reaches green), so an unlocked PRD is expected, never a gap.
8. **Technical-surface gaps & handoff (visibility, not design).** A **gaps-only** list: emit a row **only**
   for a layer with an *undefined load-bearing* surface — one the slices/rules imply but the PRD never
   specifies. A fully-specified or absent layer is omitted (or `none`); this is not a full inventory.
   **Derived faithfully from the PRD — every entry cited, nothing invented**:

   | Layer | Undefined load-bearing surface (cited) | Handoff |
   |-------|----------------------------------------|---------|
   | DB / data | tables/fields/migrations/indexes the slices+rules imply but leave unspecified | → `/saketek:rplan` (DB) |
   | API / integration | endpoints / payloads / error contracts implied but unspecified | → `/saketek:rplan` (API) |
   | Architecture | components · data flow · external deps (§13/§14) · slice sequencing left open | → `/saketek:rplan` |
   | UI / UX | screens/states the PRD names (§15 inventory / §8 / §9) but leaves **undesigned** | → `/saketek:proto` (designs + locks) |

   **You surface + flag + hand off; you do NOT design.** No fabricated schema/endpoint/architecture/UI —
   detailed DB/API/arch is `/saketek:rplan`'s lane, UI is `/saketek:proto`'s. An undefined
   load-bearing contract that blocks slice 1 is ALSO a Readiness gap (step 7 #2/#3). One line per gap; a
   layer with no undefined surface is simply omitted. An **omitted §13/§14/§15** (no constraints / no deps /
   no UI) is not a gap. The "contract stated?" column is dropped by design — nothing downstream reads it; only
   the *gap* (undefined load-bearing surface) carries handoff value.
9. **Emit the verdict signal — NOT a precise score** (the judge is non-deterministic; a decimal would be
   false precision):

   | Signal | Condition |
   |--------|-----------|
   | `DISCOVERY-FIRST` | premise laundered, OR evidence floor failed, OR the load-bearing assumption is unvalidated with no spike (Readiness #4 unmet) |
   | `REVISE` | any BLOCK or HIGH stands, **OR any state-changing/`🔒` slice is missing a prescribed failure criterion or has hidden work not yet stated as an `Assumes:` line / dedicated slice, OR Readiness is NOT READY on a fixable blocker** — regardless of that finding's severity |
   | `SHIP` | no BLOCK/HIGH; **every state-changing/`🔒` slice's failure surface is covered**; only MED/LOW polish remains |

   Print a **coverage line**: `Failure-surface: N/M state-changing slices fully covered · K hidden-work items surfaced.` A gap here holds `REVISE` even when the premise is clean. **Readiness is a distinct axis:** a `SHIP`-quality PRD that is not startable prints `SHIP · NOT READY` and Phase 4 points at the blocker, not `/saketek:rplan`.

**Write the full review to `tasks/prd-[slug]-review.md`** with the team-shareable header + ledger:

```
<!-- review-verdict: SHIP|REVISE|DISCOVERY-FIRST -->
<!-- failure-surface: N/M -->

# PRD Review — [feature]

**Reviewer:** [@name | unassigned] · **Date:** [YYYY-MM-DD] · **Status:** Open | Addressed
**PRD reviewed:** `tasks/prd-[slug].md` — quality [N]/100 · Updated [YYYY-MM-DD]
**Verdict:** [signal] · **Readiness:** READY | NOT READY · **Failure-surface:** [N]/[M] · **Round:** [k]

## Findings (ledger)
### R1 · BLOCK · panel:impl · §8 Slice 1
Finding: <issue> — "<quoted text>"
Fix:     <prescribed fix>
Disposition: Open        (Open | Fixed | Won't-fix: <reason> | Deferred: <trigger>)
### R2 · MED · Pair · §8 Slice 3
...

## Implementation-reality checklist   (newly-surfaced R#s + pre-existing [manual] ACs + the [auto] list for /saketek:qa)
## Readiness (Definition of Ready)    (the 5-item table + Readiness verdict)
## Technical-surface gaps & handoff   (undefined load-bearing surfaces only → /saketek:rplan · /saketek:proto)
## Unverifiable claims                (grounding TODOs, not defects)
```

The `Status:` header is `Open` until every BLOCK/HIGH is `Fixed`/`Won't-fix`/`Deferred`, then `Addressed`.
Solo builders leave `Reviewer: unassigned` and ignore the header; teams own, date, and track closure with it.

Then print:

```
--- PRD REVIEW SYNTHESIS ---
Verdict: DISCOVERY-FIRST | REVISE | SHIP   (a signal — one non-deterministic sample, not ground truth)
Readiness: READY | NOT READY — [blocker + R#/§, if NOT READY]
Failure-surface: [N]/[M] state-changing slices fully covered · [K] hidden-work items surfaced
Round [k]: [C] carried · [F] fixed · [N] new   (omit on Round 1)

IMPLEMENTATION-REALITY CHECKLIST (the headline — caught before manual test, not during):
  Newly surfaced this review:
    ☐ R# [slice] Given … When … Then … — expected signal: […]   [auto|manual]   (prescribed: <failure path> · panel:impl|Pair)
    ☐ R# [slice] hidden work: <migration | flag | permission | index | rollback> — <why the slice needs it>
  Pre-existing [manual] ACs (hand-run script):
    ☐ [slice] Given … When … Then … — expected signal: […]   [manual]
  (full ledger + the [auto] criteria for /saketek:qa are in the review file)

TECHNICAL-SURFACE GAPS (undefined load-bearing surfaces — flagged, not designed; omit a layer with none):
  DB:    <undefined surface, cited> → /saketek:rplan
  API:   <…> → /saketek:rplan
  Arch:  <…> → /saketek:rplan
  UI/UX: <…> → /saketek:proto

Uncited findings discarded: [N]
BLOCK:  R# ❌ [§section] [source]: [issue] → [fix]
HIGH:   R# ⚠ [§section] [source]: [issue] → [fix]
MED/LOW: [count, in the review file ledger]

Unverifiable claims (grounding TODO, NOT defects):
  • [§section] "[claim]" — ground via /saketek:prd --research or data

Caveat: external facts were NOT validated; one non-deterministic sample; a human decides.
```

---

## Phase 4: Recommendation

```
--- REVIEW COMPLETE ---
Phase 1 (Structural): PASSED / FAILED
Verdict:              DISCOVERY-FIRST / REVISE / SHIP
Readiness:            READY / NOT READY [— blocker + R#/§]

Next:
  SHIP · READY      → proceed to /saketek:proto (designs the UI/UX and **locks** the PRD), then /saketek:build.
                      PRD Status: advances to Approved on human sign-off; the /saketek:proto lock sets it Locked.
                      (/saketek:build won't start until the PRD is Locked — the freeze before /saketek:rplan.)
  SHIP · NOT READY  → sound, but not startable — clear the readiness blocker first
                      (resolve the open Q / state the dep plan / define the load-bearing contract),
                      THEN /saketek:rplan.  PRD Status: stays In Review.
  REVISE            → fix BLOCK/HIGH (+ any readiness blocker) in /saketek:prd, re-run /saketek:prd-review.
                      PRD Status: stays In Review.
  DISCOVERY-FIRST   → the premise/evidence is too thin for a spec.
                      Run /saketek:shaping-requirements or ground the load-bearing claim, then /saketek:prd again.
                      PRD Status: back to Draft.
```

The PRD `Status:` transitions are **advisory** — recommend them; a human edits the PRD header. This skill
never auto-edits the PRD.

---

## Rules

**Concise & Faithful is the overriding, always-on principle** (stated near the top) — it binds every
judge, both pair agents, and your own coordinator output at every phase; when anything below conflicts
with it, it wins. Within that, priority order: **① surface implementation reality → ② keep every finding
grounded → ③ prescribe, don't lecture.**

- NEVER skip Phase 1. A missing section is a structural fail, never a judgment call.
- Launch the three judges in parallel — never sequentially. **Judge 3 leads synthesis and the verdict.**
- **Run Phase 2.5 Pair Review only on a high-risk PRD (any `🔒` invariant OR >4 slices), after the panel:
  driver first, then navigator** (the navigator must see the driver's draft). On a low-risk PRD, skip it and
  print the skip note — Judge 3 already leads implementation coverage. It reports only the implementation +
  scope blind spots the panel MISSED — never re-lists panel findings. Same grounding guard as Judge 3:
  prescribe only paths a slice can reach.
- A BLOCK from any judge = the PRD is not ready, regardless of the `/saketek:prd` self-gate score.
- **Judge 3 and the pair must PRESCRIBE** missing failure/edge criteria and name hidden work as an
  `Assumes:` line (or a dedicated slice) — never merely flag absence. Every prescription anchors to the
  slice + the behavior that implies it; a path the slice can't reach must NOT be prescribed (that's
  inventing work — a grounding violation). Hidden work counts as *addressed* only once it is stated as an
  `Assumes:` line or promoted to its own slice — that is what carries it into the PRD and on to `/saketek:rplan`.
- **Failure-surface completeness gates the verdict.** A state-changing/`🔒` slice with an uncovered
  failure path or unaddressed hidden work holds at `REVISE` even when the premise is clean.
- **Readiness is a DISTINCT axis from the verdict** — the verdict judges soundness, readiness judges
  buildability-now. A `SHIP`-quality PRD can be `NOT READY` (unbuilt dep, slice-1-blocking open Q,
  unaccepted bet). Each readiness blocker cites an `R#`/section; it never re-derives quality.
- **The technical-surface gaps list surfaces + flags + hands off — it NEVER designs.** It is gaps-only
  (undefined load-bearing surfaces), not a full inventory; no fabricated schema/endpoint/architecture/UI;
  every entry cites PRD text. Detailed DB/API/arch is `/saketek:rplan`'s lane, UI is
  `/saketek:proto`'s. Overstepping is both a faithfulness and a scope violation.
- **The review file is a trackable record:** every finding gets a stable `R#` + `Disposition`; a re-run
  reconciles against the prior file (Step 0.5) and never renumbers a retired ID. The `Reviewer`/`Status`
  header is team metadata — advisory, ignorable by a solo builder.
- An acceptance criterion is NOT done at PRD time unless it is **observable** and tagged `[auto]`/`[manual]` — Phase 1 fails otherwise; post-manual-test "new tasks/bugs" almost always trace to this gate being skipped.
- The grounding rules — no external-fact validation, discard uncited, signal-not-score — live in the Honest-judge contract. A judge that says "I'll validate that claim myself" is violating them: route the claim to Unverifiable claims.

---

## Project Override

This is the **general version**. For project-specific judges (a domain metric model, a house JTBD style), create:
```
.claude/skills/prd-review/SKILL.md
```
That file overrides this one. Run `/saketek:init-env` to scaffold a project-specific override.
