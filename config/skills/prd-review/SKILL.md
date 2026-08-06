---
name: prd-review
description: Adversarial PRD review — deterministic structural scan, then a parallel judge panel (product, evidence & metrics, implementation-reality) PLUS a driver→navigator pair-review pass (high-risk PRDs only) that hunts the implementation + scope blind spots the panel misses. Every reviewing voice is bound to be concise + faithful — one line per finding, every claim cites the text it rests on, no fabrication. Leads on implementation reality: surfaces the failure/edge paths and hidden build work (migration, flag, permission, rollback) each slice hides, prescribing the criteria to catch them. Hard-gates acceptance criteria to be executable (Given/When/Then + `[auto]`/`[manual]` tag). Emits an implementation-reality checklist as the headline, a READINESS (Definition-of-Ready) gate for buildability-now, and a technical-contract check — verifying the PRD's §16 thin contract (present · cited · compat-declared · slice-coherent · still shape not full design) then flagging the residual undefined DB · API · architecture · UI/UX surfaces — verifying and handing off, never designing. Writes a team-shareable, trackable review record (PRD-version pinned · finding IDs + disposition · re-review reconcile). Run after /saki-builder:prd, before handing slices to /saki-builder:rplan. Emits a coarse verdict signal, not a precise score. Autonomous by default — loops (review → apply the prescribed fixes to the PRD → re-review) until SHIP·READY or blocked; pass `--review-only` for a single non-editing pass (today's behavior).
---

# PRD Review — Structural Scan + Adversarial Judge Panel + Pair-Review Blind-Spot Pass

You are the review coordinator. Your job: stress-test a PRD produced by `/saki-builder:prd` *before* its slices go to `/saki-builder:rplan`, using an independent judge panel and a paired blind-spot pass. This complements `/saki-builder:prd`'s in-skill self-gate — a model that scores its own PRD is biased toward it; this skill is the fresh-context second opinion.

**Lead lens — implementation reality.** The highest-priority job is to make VISIBLE what building this actually entails: the failure/edge paths the happy-path criteria hide, and the implementation work a slice silently assumes (migration, backfill, feature flag, new permission, index, rollback). **Judge 3 owns this and leads synthesis** — its prescribed criteria + surfaced hidden work are the headline output, and the verdict gates on failure-surface completeness, not just premise soundness. The other judges (premise, metrics, evidence) still run — a well-tested bad idea is still a bad idea — they just don't lead. Priority order for the whole review: **① surface implementation reality → ② keep every finding grounded → ③ prescribe, don't lecture.**

The review runs: **Phase 1** (structural hard gate) → **Phase 2** (parallel judge panel) → **Phase 2.5** (driver→navigator pair-review blind-spot pass) → **Phase 3** (synthesis: `R#` findings ledger + implementation-reality checklist + **Readiness / Definition-of-Ready** + **technical-surface & contract map** + verdict) → **Phase 4** (recommendation). Phase 1 is a hard gate — failure stops the review and sends the author back to `/saki-builder:prd`.

## Honest-judge contract (the four limits this skill is built to contain)

- **No external-fact validation.** Market sizes, user %, benchmarks — the panel neither confirms nor refutes them (that would be hallucination); it routes them to `UNVERIFIABLE` for a human or `/saki-builder:prd --research`.
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

## Modes — autonomous (default) vs `--review-only`

`/saki-builder:prd-review` runs **autonomous** unless `--review-only` is passed.

- **Autonomous (default).** After a review pass, if the PRD is not green (`Verdict SHIP` AND `Readiness
  READY`), **apply the review's own prescribed fixes to the PRD and re-review**, looping until green or a
  hard stop — see **Phase 5**. This is the loop-to-green that `/saki-builder:pickup` also drives; it lives
  here now, and `/saki-builder:pickup` reuses it (it does not keep its own copy).
- **`--review-only`.** Run **one** pass (Step 0 → Phase 4) and stop. Never edit the PRD, never write a state
  file. This is the classic single-pass reviewer — use it for a one-shot second opinion, or when another
  orchestrator owns the loop.

**The review CORE (Step 0 → Phase 4) NEVER edits the PRD, in either mode.** Only the **Phase 5** autonomous
wrapper edits the PRD (it applies the prescribed fixes between passes). The judges (Phase 2) are always fresh
Agent subagents each round, so relocating the fix-apply step here does not compromise the review's
fresh-context independence.

---

## Step 0: Load the PRD

Take the target from ARGUMENTS (a `tasks/prd-*.md` path). If none given, find the most recent `tasks/prd-*.md`. Read it fully.

Also parse from ARGUMENTS:
- **`--review-only`** — run a single non-editing pass (Step 0 → Phase 4) and stop; skip **Phase 5**. Absent ⇒
  **autonomous** (loop-to-green) is the default. See **Modes** above.
- **`--reviewer @name`** — who is running this review (team-facing metadata). Default `unassigned`.
  Do NOT auto-fill it from the PRD's `Owner` — best-practice review keeps reviewer ≠ author.

Capture the **PRD version pin** from the PRD's own header — the `<!-- prd-blocking: N -->` marker and the
`Updated: YYYY-MM-DD` field. This pins exactly which version you reviewed, so a later review against an
evolved PRD is visibly newer.

Print:
```
--- PRD LOADED ---
File: [filename]
Reviewer: [@name | unassigned]
PRD version: blocking [N] · Updated [YYYY-MM-DD]   |  (none — PRD predates the readiness gate)
DISCOVERY-RISK banner: present / absent
```

If the file has no `<!-- prd-blocking: N -->` line, note it — the PRD may predate the upgraded skill, and the structural scan below matters more.

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

| # | Required (per `/saki-builder:prd`) | Present & valid? | Notes |
|---|----------------------|------------------|-------|
| 1 | **§2 states the load-bearing assumption + tag** — an explicit `**Load-bearing assumption:** <X> — assumed/observed/validated` line in §2 (the premise from `/saki-builder:prd` Step 0b, in the file). A bet also carries it in the DISCOVERY-RISK banner; a grounded PRD still states it in §2 | | |
| 2 | TL;DR ≤3 sentences; problem names a **measurable harm** | | |
| 3 | Evidence table — each claim tagged; floor met (≥1 `validated` OR a named spike — the §2 `**Spike:**` line `/saki-builder:prd` Step 0b writes when the load-bearing assumption is `assumed`; a bare `assumed` tag with no `**Spike:**` line does not count) | | |
| 4 | Primary JTBD in **Klement** form (`When… I want… so I can…`), exactly one | | |
| 5 | §5 outcomes — each primary/secondary has target + **basis tag** (`baseline`/`benchmark`/`aspirational`) + measurement + a **JTBD link** (a `Jn` in §3/§4); the **counter-metric** row instead names the metric(s) it guards (`guards 5.x`, not a `Jn`) | | |
| 5b | §5 Method is classified `query`/`event`/`external`, and every **`event`-class** row names its event (`event: emit <name> when <trigger>`) — an event-class Method with no named event is undefined instrumentation work | | |
| 6 | ≥1 **counter-metric** naming the metric/failure-mode it guards | | |
| 7 | **Appetite** (§6, band + span) **+ outcome-tied Kill Criteria**; **§7 Solution Shape** names the chosen shape + a **Decision Log** (alternatives considered w/ why-not) OR states there was one obvious shape | | |
| 8 | Vertical slices — **≤7**, each `Serves: J<n> · 5.<x>` where `Jn` resolves to a job defined in §3/§4 and `5.x` to an outcome in §5 (a `Jn`/`5.x` with no matching definition = dangling). Resolution is **bidirectional** — a §4 related job referenced by no slice **and** no §5 outcome is an **orphan job** (a Judge-1 scope finding, *not* a Phase-1 hard-fail — see the hard-fail carve-out) | | |
| 9 | Acceptance criteria — **≤5/slice**; each links an outcome OR names a guardrail; each is **observable** (Given/When/Then + a checkable signal) and tagged **`[auto]`** (curl/test/file/grep) or **`[manual]`** (human/browser) | | |
| 10 | **≥2 Non-Goals**; Rabbit Holes & Open Questions present | | |
| 11 | **Business Rules** (when domain logic present) — each rule falsifiable; each `🔒` invariant tested by a §9 criterion that exercises its **failure path** (over-limit / empty / concurrent / unauthorized / … — see Judge 3's canonical menu), not only the happy path | | |

**Hard-fail rules (any one → Phase 1 FAILED):**
- Primary JTBD in persona form ("As a [role], I want…") → FAIL
- A `validated`/`observed` claim with no cited source → FAIL (fabricated evidence)
- An §5 outcome with a numeric target but no **basis tag** — one of `baseline`/`benchmark`/`aspirational` → FAIL (fabricated precision). `aspirational` IS a valid basis (an honest not-yet-measured target passes); a bare number with no basis does not. Fix in /saki-builder:prd: add the Basis column value.
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

These are /saki-builder:prd's job to fix, not a judgment call:
  ❌ [item]: [specific gap, with the section]

Action: fix in /saki-builder:prd → re-run /saki-builder:prd-review.
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
3. Is the **evidence floor** met (≥1 `validated` or a named spike — the §2 `**Spike:**` line, present even when its finding is "inconclusive"), or is the table effectively all-`assumed` behind a `validated` label — including an `assumed` row with no `**Spike:**` line at all (the auto-spike never ran)? Does the PRD honestly carry a `DISCOVERY-RISK` banner where its evidence is thin, or overclaim confidence?
4. Targets with **fabricated precision** — a number with no `baseline`/`benchmark`/`aspirational` basis (an `aspirational`-tagged target is honest, not fabricated — do not flag it), including a **circular `baseline N→M`** whose starting number N cites no source (it restates the target instead of grounding it).
5. A **Goodhart counter-metric** — one that doesn't name the specific metric + failure mode it guards.
6. Metrics that are **not instrumentable** with what exists or is in scope — including an **`event`-class Method with no named event** (`event: emit <name> when <trigger>` missing): it declares a metric nothing will record.
7. §5 outcomes with **no linking acceptance criterion** anywhere in the slices — and, for an **`event`-class** outcome, a linking criterion that only restates the outcome instead of **asserting the event fires** (the criterion must verify emission, e.g. "event `<name>` fires when `<trigger>`").

**Graph-first context for Judge 3 (coordinator reads before dispatching, additive):**

```bash
cat graphify-out/GRAPH_REPORT.md 2>/dev/null || true
```

Read the full report before constructing Judge 3's prompt. Thread the graph summary as **Graph
Context** in Judge 3's input. Judge 3 uses it to:
- **Cross-boundary slice coupling** — if a slice's stated scope touches nodes in >1 community,
  prescribe an `Assumes:` line or a dedicated slice for the cross-boundary work.
- **Omitted god-node rows** — a slice depending on a god node (top of the report's God Nodes
  list — highest edge count) that §16 omits is a blocking §16 gap; prescribe adding
  `REUSE (path:line)` if the slice only consumes it, or `CHANGE (path:line)` + a `↳ Breaks:` note
  if the slice modifies it (a modified god node is the highest-blast-radius compat surface there is).
- **"Simple change" claims** — a change touching a god node is never simple; cite the node's edge
  count (`graphify explain` → `Degree: N`) as evidence for the finding.

Then query for slice-specific coupling:
```bash
graphify query "<slice description>"                   # what does this slice actually touch?
graphify path "SliceModule" "UnexpectedDependency"     # confirm hidden coupling
```

If absent: Judge 3 runs without graph context (unchanged behavior).

**Judge 3 — Slicing & Implementation-Reality (the lead lens).** Find, in priority order:
1. **Missing failure/edge criteria — the post-manual-test bug source.** For each state-changing or `🔒` slice, name the failure paths the happy-path ACs leave untested and **prescribe the criterion that would catch each** (Given/When/Then + signal, tagged `[auto]`/`[manual]`). Draw from this canonical, **non-exhaustive** menu, applying an item *only where the slice's stated behavior implies that path* — prescribing a path the slice can't reach (e.g. `network-fail` for a slice that makes no network call) violates the grounding rule:
   over-limit · empty/zero · concurrent/double-submit · unauthorized/wrong-tenant · network-fail/timeout · partial-failure/rollback · idempotency-on-retry · pagination/large-N · error-state UI.
   **Anchor every prescription** to the slice + the exact behavior that implies it ("§8 Slice 3 debits balance → concurrent-debit criterion"). Prescribe, never merely flag — a flag forces the author to re-derive the fix and re-review. These prescribed criteria are exactly the "new tasks / bugs" that otherwise surface only when a human tests by hand.
2. **Hidden implementation work a slice ASSUMES but never states.** For each slice, name the build work its stated behavior silently requires but the PRD omits: migration/backfill of existing rows, a feature flag, a new permission/role, an index the metric query needs, seed data, a rollback path, **a compatibility shim / dual-read window** (whenever the slice touches a §16 `CHANGE` row — an existing consumer must keep working across the change, which is real build work the criteria never state). Anchor each to the slice text that implies it. This is the mid-build discovery this review exists to prevent — surface it now, not in the build. **Prescribe the fix as an `Assumes:` line on that slice** (`Assumes: <the hidden work>` — `/saki-builder:prd` Step 3) — or, when the work is a load-bearing capability in its own right, prescribe **promoting it to its own slice**. It counts as *addressed* only when the slice carries that `Assumes:` line (or the dedicated slice); an unstated assumption is not addressed. This is the wire that makes the finding reach `/saki-builder:rplan` — `/saki-builder:pickup` bakes the `Assumes:` line into the PRD on REVISE, and rplan ingests it from the PRD (the review file itself is not read downstream).
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
4. **Classify** — BLOCK (fix before `/saki-builder:rplan`) / HIGH / MED / LOW.
5. **Collect unverifiable claims** from all judges into one list — NOT defects, grounding TODOs
   (run `/saki-builder:prd --research` or validate manually).
6. **Assemble the implementation-reality checklist — the headline output.** Two sections, in this order,
   each line citing its `R#`:
   - **Newly-surfaced (this review's payload):** every failure/edge criterion Judge 3 **and the pair**
     prescribed + every hidden-work item, each anchored to its slice. The "new tasks / bugs" caught
     *before* manual test.
   - **Pre-existing `[manual]` ACs:** the `[manual]`-tagged criteria already in the PRD, as the human's
     hand-run script.
   `[auto]` criteria are not listed — `/saki-builder:qa` runs those. This checklist **leads** the printed
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
   §14 line, it does NOT probe the filesystem/network (that is `/saki-builder:rplan`'s job). An **omitted
   §14** (`/saki-builder:prd` drops it when there are no dependencies) reads as `none` → DoR #3 READY, not
   a gap; likewise an omitted §13 or §15 (a no-UI PRD has no screens section). Absent-because-none ≠ missing
   — do not raise a false NOT-READY on it. **Readiness never requires the lock:** `/saki-builder:prd-review` runs
   *before* the `/saki-builder:proto` lock (it is how the PRD reaches green), so an unlocked PRD is expected, never a gap.
8. **Technical contract check & residual-gaps handoff (verify what's stated, flag what's missing — never design).**
   The PRD now carries a **§16 Technical Contract (thin)** — the DB/API/architecture *shape* `/saki-builder:prd`
   authored (entities · endpoint purposes · one architecture decision), each row REUSE (`path:line`), CHANGE
   (`path:line` + a `↳ Breaks:` sub-line), or NEW, and serving an `8.x · 5.x`. Two jobs:

   **(a) VERIFY §16** (when the feature has a backend surface — a UI-only PRD correctly omits it):
   - **Present** — §16 exists, OR is a correct `No backend surface — UI-only change.` omission.
   - **Cited** — every row is REUSE with a real `path:line` OR tagged `NEW`; no fabricated/uncited row.
     A **CHANGE** row is cited on the same bar as REUSE — a real `path:line` — since it names an existing
     surface. (REUSE/NEW-only §16s stay valid; CHANGE is an additional tag, not a replacement.)
   - **Compat-declared** — every **CHANGE** row carries a `↳ Breaks:` sub-line naming what depends on the
     present shape (or `none (additive)`). A CHANGE row without one declares a compatibility surface and
     then hides its blast radius — it is a `REVISE` finding, because `/saki-builder:rplan` ingests exactly
     that note as its Compatibility & Consumers entry. **Also flag the inverse mis-tag:** a row tagged
     `REUSE` whose serving §8 slice text says change / extend / rename / replace / add-field is a
     modification wearing a reuse tag — prescribe re-tagging it `CHANGE` + `↳ Breaks:`.
   - **Traceable** — every row serves a real §8 slice / §5 outcome (no speculative surface — YAGNI).
   - **Coherent** — no slice/rule implies a load-bearing surface that §16 omits; no §16 row references a
     non-existent slice/outcome. §16 must stay *shape* — a row carrying column/field names, a full request/
     response payload, or a migration file has overstepped into `/saki-builder:rplan`'s lane (flag it, don't
     bless it).
   A failure of (a) — §16 missing on a backend feature · an uncited row · an untraceable row · §16↔slice
   incoherence · a row that overstepped into full design · **a CHANGE row with no Breaks: note (or a REUSE
   row for a surface the slice modifies)** — is a `REVISE` finding (see step 9). You check the
   contract's **existence, grounding, and coherence** — you do NOT author or complete it.

   **(b) FLAG residual gaps** §16 does NOT cover — a **gaps-only** list, one row per *undefined load-bearing*
   surface the slices/rules imply but §16 (and the PRD) leaves open. Hand off; do not design. Every entry cited:

   | Layer | Undefined load-bearing surface §16 leaves open (cited) | Handoff |
   |-------|--------------------------------------------------------|---------|
   | DB / data | tables/fields/migrations/indexes implied but absent from §16 | → `/saki-builder:rplan` (DB) |
   | API / integration | endpoints / payloads / error contracts implied but absent from §16 | → `/saki-builder:rplan` (API) |
   | Architecture | components · data flow · external deps (§13/§14) · sequencing §16 leaves open | → `/saki-builder:rplan` |
   | UI / UX | screens/states the PRD names (§15 inventory / §8 / §9) but leaves **undesigned** | → `/saki-builder:proto` (designs + locks) |

   **You verify + flag + hand off; you do NOT design.** No fabricated schema/endpoint/architecture/UI —
   detailed DB/API/arch is `/saki-builder:rplan`'s lane (it *hardens* §16 into full design), UI is
   `/saki-builder:proto`'s. An undefined load-bearing contract that blocks slice 1 is ALSO a Readiness gap
   (step 7 #2/#3). One line per gap; a layer with no undefined surface is simply omitted. An **omitted
   §13/§14/§15/§16** (no constraints / no deps / no UI / no backend surface) is not a gap.
9. **Emit the verdict signal — NOT a precise score** (the judge is non-deterministic; a decimal would be
   false precision):

   | Signal | Condition |
   |--------|-----------|
   | `DISCOVERY-FIRST` | premise laundered, OR evidence floor failed, OR the load-bearing assumption is unvalidated with no §2 `**Spike:**` line recorded (Readiness #4 unmet) |
   | `REVISE` | any BLOCK or HIGH stands, **OR any state-changing/`🔒` slice is missing a prescribed failure criterion or has hidden work not yet stated as an `Assumes:` line / dedicated slice, OR §16 fails the contract check (missing on a backend feature · an uncited/untraceable row · §16↔slice incoherence · a row overstepped into full design · **a CHANGE row with no Breaks: note**), OR Readiness is NOT READY on a fixable blocker** — regardless of that finding's severity |
   | `SHIP` | no BLOCK/HIGH; **every state-changing/`🔒` slice's failure surface is covered**; only MED/LOW polish remains |

   Print a **coverage line**: `Failure-surface: N/M state-changing slices fully covered · K hidden-work items surfaced.` A gap here holds `REVISE` even when the premise is clean. **Readiness is a distinct axis:** a `SHIP`-quality PRD that is not startable prints `SHIP · NOT READY` and Phase 4 points at the blocker, not `/saki-builder:rplan`.

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

## Implementation-reality checklist   (newly-surfaced R#s + pre-existing [manual] ACs + the [auto] list for /saki-builder:qa)
## Readiness (Definition of Ready)    (the 5-item table + Readiness verdict)
## Technical contract (§16) check & residual gaps   (verify stated · flag residual → /saki-builder:rplan · /saki-builder:proto)
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
  (full ledger + the [auto] criteria for /saki-builder:qa are in the review file)

TECHNICAL CONTRACT (§16 verify) + RESIDUAL GAPS (flagged, not designed; omit a layer with none):
  §16:   present | omitted(UI-only) · rows cited? · compat-declared? · slice-coherent?   [REVISE if missing on a backend feature · uncited/untraceable row · CHANGE row with no Breaks: note · incoherent · overstepped into full design]
  DB:    <residual surface §16 leaves open, cited> → /saki-builder:rplan
  API:   <…> → /saki-builder:rplan
  Arch:  <…> → /saki-builder:rplan
  UI/UX: <…> → /saki-builder:proto

Uncited findings discarded: [N]
BLOCK:  R# ❌ [§section] [source]: [issue] → [fix]
HIGH:   R# ⚠ [§section] [source]: [issue] → [fix]
MED/LOW: [count, in the review file ledger]

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
Readiness:            READY / NOT READY [— blocker + R#/§]

Next:
  SHIP · READY      → proceed to /saki-builder:proto (designs the UI/UX and **locks** the PRD), then /saki-builder:build.
                      PRD Status: advances to Approved on human sign-off; the /saki-builder:proto lock sets it Locked.
                      (/saki-builder:build won't start until the PRD is Locked — the freeze before /saki-builder:rplan.)
  SHIP · NOT READY  → sound, but not startable — clear the readiness blocker first
                      (resolve the open Q / state the dep plan / define the load-bearing contract),
                      THEN /saki-builder:rplan.  PRD Status: stays In Review.
  REVISE            → fix BLOCK/HIGH (+ any readiness blocker) in /saki-builder:prd, re-run /saki-builder:prd-review.
                      PRD Status: stays In Review.
  DISCOVERY-FIRST   → the premise/evidence is too thin for a spec.
                      Run /saki-builder:shaping-requirements or ground the load-bearing claim, then /saki-builder:prd again.
                      PRD Status: back to Draft.
```

The PRD `Status:` transitions are **advisory** — recommend them; a human edits the PRD header. The **review
core (Step 0 → Phase 4) never auto-edits the PRD.** Under `--review-only` this recommendation is guidance for
a human. **In autonomous mode, Phase 5 acts on it for you** — applying the prescribed fixes on
`REVISE` / fixable-`NOT READY` and re-reviewing, or stopping on `SHIP · READY` (green) / a hard blocker.

---

## Phase 5: Autonomous loop-to-green  (default mode — skipped under `--review-only`)

**Run only when NOT `--review-only`.** Phases 0–4 are the single-pass **review core** and never touch the
PRD. Phase 5 wraps that core in the loop-to-green: run the core, read its verdict, and on anything short of
green **apply the review's own prescribed fixes to the PRD** and run the core again — until the PRD is green
or a hard stop is reached. You are the PRD author here (the same role `/saki-builder:pickup` played when it
owned this loop). The three judges still run as fresh Agent subagents each round.

### State file (single source of truth for the loop + the Stop hook)

Maintain `tasks/.prd-review-<slug>-state.json` (the `<slug>` is the PRD's, from `tasks/prd-<slug>.md`).
**Write it after every phase transition** — the `prd-review-completion-gate.sh` Stop hook reads it to keep
the loop alive across turns. Get timestamps with `date +%s`. Schema:

```json
{
  "slug": "instant-seller-payout",
  "prd": "tasks/prd-instant-seller-payout.md",
  "session": "<session_id if known, else omit>",
  "phase": "reviewing|green|blocked",
  "started_at": 1730000000,
  "review": { "rounds": 0, "verdict": "", "readiness": "", "blockers_fixed": 0 }
}
```

`phase` is the cursor the Stop gate keys off:
- `reviewing` → the loop is still working → the Stop gate **keeps you running**.
- `green` → the PRD reached `SHIP · READY` → terminal success → the Stop gate **releases**.
- `blocked` → a hard stop you reported → the Stop gate **releases**.

### The loop

1. Init the state file (`phase:"reviewing"`, stamp `started_at`, `slug`, `prd`). Run the review **core**
   (Step 0 → Phase 4) once. Read the result from the canonical **`--- REVIEW COMPLETE ---`** block (its
   line-start `Verdict:` / `Readiness:` labels); the `<!-- review-verdict: … -->` synthesis comment is the
   robust fallback. Record `verdict` + `readiness` and bump nothing on the first pass.

2. **Green — `Verdict SHIP` AND `Readiness READY`** → set `phase:"green"`, record `review.verdict:"SHIP"` /
   `review.readiness:"READY"`, print the terminal block below, and stop. (Both axes required — a
   `SHIP · NOT READY` PRD is **not** green.)

3. **Fixable — Phase 1 FAILED, or `Verdict REVISE`, or `Readiness NOT READY` on a FIXABLE blocker** → apply
   the review's prescribed fixes **to the PRD** (rewrite vague criteria, add the prescribed failure/edge
   criteria, add a slice's `Assumes:` line for prescribed hidden work — or promote load-bearing hidden work
   to its own slice, fix orphan slices, add kill criteria, resolve a §12 open Q, close a fixable readiness
   blocker), bump `review.rounds`, add to `review.blockers_fixed`, and re-run the core from step 1. **Cap at
   3 rounds.**

   **Also stamp the pass into the PRD header** — this is the durable counter, and the state file is not:
   `tasks/` is gitignored and a state file is deleted/rotated per run, so a count that lives only there
   cannot be read back later. Add or increment, in the PRD's top comment block, on its own line:

   ```
   <!-- revision-passes: N -->
   ```

   `N` = the number of rounds in which this skill **applied fixes to the PRD**. Increment it here, in the
   same step that applies them — never on a round that only re-read and found nothing to change, and never
   on the `blocked` escape (step 4), which applies no fixes. A PRD that reached green on the first review
   with no fixes therefore carries no marker at all, which reads as 0.

   This is the counter `/saki-builder:build`'s E1 metric 5.1 names ("stamp a **Revision passes:** counter
   into the PRD header, incremented by /saki-builder:prd-review each time it applies fixes"). It is what
   makes a revision-pass baseline measurable across runs; `bin/revision-baseline.js` aggregates it.

4. **Blocked — escape to the human, do NOT loop forever, do NOT fabricate grounding** — when the review
   can't be authored to green:
   - **`Verdict DISCOVERY-FIRST`** (a load-bearing unknown needs discovery), OR
   - **`Readiness NOT READY` on a STRUCTURAL blocker** you can't author away — an unbuilt / `TBD`
     dependency, or an unaccepted bet / unresolved DISCOVERY-RISK, OR
   - **Non-convergence** — round-2 carries the same blocker volume/level as round-1, or the 3-round cap is
     hit still not green (see `patterns.md` — score-trajectory convergence signal; recut, don't loop again).

   Set `phase:"blocked"`, print the terminal block, and stop.

### Terminal output

On green:
```
PRD_REVIEW_GREEN: <slug> — SHIP · READY · R rounds · B blockers fixed

✅ PRD green: tasks/prd-<slug>.md   (review record: tasks/prd-<slug>-review.md)
```
On blocked:
```
PRD_REVIEW_BLOCKED: <slug> — <DISCOVERY-FIRST | readiness: blocker | non-convergence>: <reason>
```
`PRD_REVIEW_GREEN` / `PRD_REVIEW_BLOCKED` (each on its own line) are the terminal sentinels; the Stop hook
releases once `phase` is `green` or `blocked`. **Always persist the state file before ending a turn** so any
resume (a context clear, or the Stop gate re-driving you) lands on the right phase.

---

## Rules

**Concise & Faithful is the overriding, always-on principle** (stated near the top) — it binds every
judge, both pair agents, and your own coordinator output at every phase; when anything below conflicts
with it, it wins. Within that, priority order: **① surface implementation reality → ② keep every finding
grounded → ③ prescribe, don't lecture.**

- **Autonomous is the default; `--review-only` is the single-pass escape hatch.** The review CORE
  (Step 0 → Phase 4) never edits the PRD in either mode — only the **Phase 5** wrapper does, and only in
  autonomous mode. Autonomous loops fix→re-review to green with a hard **3-round cap** + a BLOCKED escape
  (`DISCOVERY-FIRST` / structural `NOT READY` / non-convergence) — never an infinite loop, never fabricated
  grounding. `/saki-builder:pickup` reuses this loop; it must invoke `/saki-builder:prd-review` **without**
  `--review-only` and never keep its own copy.
- NEVER skip Phase 1. A missing section is a structural fail, never a judgment call.
- Launch the three judges in parallel — never sequentially. **Judge 3 leads synthesis and the verdict.**
- **Run Phase 2.5 Pair Review only on a high-risk PRD (any `🔒` invariant OR >4 slices), after the panel:
  driver first, then navigator** (the navigator must see the driver's draft). On a low-risk PRD, skip it and
  print the skip note — Judge 3 already leads implementation coverage. It reports only the implementation +
  scope blind spots the panel MISSED — never re-lists panel findings. Same grounding guard as Judge 3:
  prescribe only paths a slice can reach.
- A BLOCK from any judge = the PRD is not ready, regardless of the `/saki-builder:prd` self-gate result.
- **Judge 3 and the pair must PRESCRIBE** missing failure/edge criteria and name hidden work as an
  `Assumes:` line (or a dedicated slice) — never merely flag absence. Every prescription anchors to the
  slice + the behavior that implies it; a path the slice can't reach must NOT be prescribed (that's
  inventing work — a grounding violation). Hidden work counts as *addressed* only once it is stated as an
  `Assumes:` line or promoted to its own slice — that is what carries it into the PRD and on to `/saki-builder:rplan`.
- **Failure-surface completeness gates the verdict.** A state-changing/`🔒` slice with an uncovered
  failure path or unaddressed hidden work holds at `REVISE` even when the premise is clean.
- **Readiness is a DISTINCT axis from the verdict** — the verdict judges soundness, readiness judges
  buildability-now. A `SHIP`-quality PRD can be `NOT READY` (unbuilt dep, slice-1-blocking open Q,
  unaccepted bet). Each readiness blocker cites an `R#`/section; it never re-derives quality.
- **The technical-contract check verifies the §16 thin contract, then flags residual gaps — it NEVER designs.**
  Job (a) checks §16 exists · is cited (REUSE / CHANGE `path:line` / NEW) · is **compat-declared** (every
  CHANGE row has a `↳ Breaks:` note) · is slice-coherent · stayed *shape* (a row
  with column names / full payloads / a migration file overstepped — flag it, don't complete it). Job (b) is
  gaps-only (undefined load-bearing surfaces §16 leaves open), not a full inventory; no fabricated
  schema/endpoint/architecture/UI; every entry cites PRD text. Detailed DB/API/arch is `/saki-builder:rplan`'s
  lane (it hardens §16), UI is `/saki-builder:proto`'s. Authoring or completing the contract — not just
  flagging its gaps — is both a faithfulness and a scope violation.
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
That file overrides this one. Run `/saki-builder:init-env` to scaffold a project-specific override.
