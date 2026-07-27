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
  - name: evidence
    description: Optional demand signal to ground the problem — a file path or pasted analytics / support-ticket / sales-quote / usage data. Feeds §2 as observed/validated in Step 0.7 Tier 1.5.
    required: false
  - name: owner
    description: Optional owner for the shareable header (e.g. @name). Defaults to unassigned. Team-facing only — a solo builder can ignore it.
    required: false
  - name: appetite
    description: Optional appetite override (e.g. "small", "medium", "large", or "~3 days"). If set, Step 0.5 uses it instead of asking.
    required: false
---

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

Then confirm with: `Model: OPUS | Status: Reading`

> This pins the model to Opus for PRD authoring and does **not** auto-restore afterward — `/saki-builder:rplan` keeps it on Opus for planning, and `/saki-builder:approved` switches to Sonnet for implementation. Use the `opus` alias (not a pinned `claude-opus-4-x`) so it stays current across releases instead of silently downgrading.

---

## Context

You are acting as a product analyst for project {{project_name}} ({{project_type}}). Stack: {{stack}}.

The PRD bridges the human's intent to the build pipeline (`/saki-builder:rplan` → `/saki-builder:approved` → `/saki-builder:qa`).

**Philosophy:** The human sets the expectation. You apply the discipline. The deliverable must be
readable without you.

This means:
- **Shape before you formalize.** Step 0.5 runs a lean divergent pass *with* the human (problem →
  appetite → 2–3 options → decision) so the PRD formalizes a *chosen* shape, not the first idea.
  This is the only extra human touch — it replaces guesswork, it doesn't add ceremony.
- All methodology (Klement JTBD, Ulwick outcomes, INVEST checks, Quality Gate scoring) runs
  **internally** — never surfaced to the human.
- What the human sees and approves is **plain-English points only** (5 core + appetite + any bet risk).
- The saved file contains the full technical structure for downstream skill consumption, plus a
  **team-shareable header + Decision Log** — so the same PRD works for a solo builder (ignore the
  header) and a team that reviews and evolves it. Team *coordination* stays out of scope; this is a
  team-grade *artifact*, not a team workflow.

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

## Step 0.5 — Shape (human-facing, lean — divergent before you formalize)

Run this *before* the internal construction. It borrows the methodology of `shaping-requirements`
(Shape-Up pitch) and `brainstorm-feature-options` (2–3 approaches → decision), compressed into one
present-then-pick pass. Goal: agree on **how much this is worth** and **which shape** we build —
not a design. Keep it short; accept 1–2 word answers.

**(a) Problem** — restate the user struggle in one line (JTBD-lite), confirming Who/When from Step 0.
Do not propose a solution yet.

**(b) Appetite** — set the time-box *with the human*. This is Shape Up's load-bearing lever (fixed
time, variable scope) and it is what `/saki-builder:prd-review` and `/saki-builder:rplan` inherit downstream —
so it is never optional. Offer:

```
How much is this worth?
  small   — hours       (1–2 slices)
  medium  — a few days  (3–4 slices)
  large   — ~a week+    (5–7 slices; >7 = split into multiple epics, each its own PRD)
```

If `{{input.appetite}}` is set, use it and skip the ask. Appetite **caps slice count** — carry it
into §6 and the header, and enforce it at the gate.

**(c) Options** — propose **2–3 solution shapes** in plain English with trade-offs. Lead with your
recommendation and one line of reasoning. Rough concepts (moving parts), not high-fidelity design.
Apply YAGNI — cut anything the appetite can't afford.

**(d) Decision** — the human picks a shape (or "you decide" → take your recommendation and state
it). Record the **chosen shape + one-line why-not for each alternative** — this becomes the §7
Decision Log and the human-view "why this approach" line. A decision with no recorded alternatives
is not a decision.

**(e) Rabbit holes & no-gos** — name 1–2 places this could sink time, and 1–2 things explicitly out
of bounds. Seed §12 (rabbit holes) and §11 (non-goals).

**Autonomous fallback (`/saki-builder:pickup` / `--yes` / "you decide"):** do not stall for input. Auto-select
the recommended shape, derive appetite from the intent's scope (small/medium/large), state the defaults
in one line, and continue. When invoked by `/saki-builder:pickup <id>` (E<n>/F<n>), the **item seed** grounds
this: the item's Goal → problem (a), its Success signal → appetite hint, its User flow → the recommended shape. This
preserves the workflow's single human gate at proto — running `/saki-builder:proto` designs the UI and **locks**
the PRD — so the shape phase adds **no** new gate.

---

## Step 0b — Premise check (INTERNAL — do not show to human)

In scratch (not the file), verify:

1. **The one thing that, if false, makes this not worth building** — tag it
   `assumed | observed | validated`.
2. **Three concrete reasons this fails** — rebut or concede each.
3. **Verdict** — proceed / recut / stop.

**If (1) is `assumed` AND two failure reasons stand unrebutted — auto-spike before stopping.** Do not
go straight to the human with a suggestion; run the spike yourself, reusing `/saki-builder:rplan`'s
Spike Protocol (same contract, applied to the one load-bearing assumption instead of a code unknown):

1. Spawn a subagent, 15-minute timebox, question = the load-bearing assumption. Route by the unknown's
   kind: **external** (market demand, competitor behavior, pricing, willingness-to-pay) → `WebSearch` /
   `/deep-research`; **internal** (existing usage pattern, current behavior) → grep / `graphify query` /
   the `{{input.evidence}}` file if one was given.
2. Required output: question, approach tried, finding, recommendation, source (`path:line`, URL, or query).
3. **Spike grounds it** → retag `observed`/`validated`, cite the source in §2, and continue — do NOT stop.
4. **Spike can't ground it** (no reachable data, or it's a judgment call no search resolves) → keep
   `assumed`, but record what was tried. A spike that ran and came back inconclusive is what
   `/saki-builder:prd-review` counts as a **named spike**; an `assumed` tag with no attempt does not count.

Only if the spike itself cannot even be attempted (no viable route to check it at all) skip straight to:
STOP, tell the human in plain English: *"Before we write a spec, we need to answer [X] first — I tried a
discovery spike ([approach]) and it didn't resolve. Cheapest next step: [a founder call / a paid data
source / a small pilot / asking N real users]."*

**Carry it to the file (not just scratch).** The load-bearing assumption from (1) MUST appear in the
saved **§2** as a stated + tagged line (Step 7): `**Load-bearing assumption:** <X> — \`assumed|observed|validated\``.
**If a spike ran, add the line directly beneath it:**
`**Spike:** <question> → <finding, or "inconclusive — <why>"> (source: <cite, or "none found">)`.
This holds in BOTH cases — a bet (`assumed`, also carried in the DISCOVERY-RISK banner) and a grounded
PRD (`observed`/`validated` with its citation). It is what `/saki-builder:prd-review` Phase-1 items 1
and 3 (evidence floor) read; leaving it scratch-only breaks both consumers.

---

## Step 0.7 — Evidence grounding (INTERNAL — do not show to human)

### Tier 0 — Persona check (always run)

Check `.claude/personas/*.md`. If it exists, read the relevant persona(s) and use them to
inform: acceptance criteria tone, which error states to cover, what non-goals to call out.

### Tier 1 — Local grounding (always run)

**Graph-first reading (additive — run BEFORE any Grep/Glob/file read):**

```bash
cat graphify-out/GRAPH_REPORT.md 2>/dev/null || true
```

If the report exists, read it fully before opening any file. Use it to:
- **§16 Technical Contract REUSE rows** — god nodes the feature touches are load-bearing anchors;
  mark them `REUSE (path:line)` from the start, not discovered at rplan time.
- **Single architecture decision row** — if the feature's scope crosses >1 community cluster, it
  spans module boundaries; that is the architecture decision to name in §16.
- **Scope honesty** — if a god node (top of the report's God Nodes list — highest edge count,
  `Degree:` in `graphify explain`) sits in the blast radius, flag it as `assumed` with a
  centrality-risk note. Touching a god node is never a simple change.
- **Surprising connections** — any listed edge connecting the feature area to another module is a
  hidden dependency; surface as `assumed` unless code confirms it.

Then query for the feature's specific scope:
```bash
graphify query "<feature name and what it does>"
graphify path "ProposedModule" "ExistingModule"   # confirm coupling the PRD assumes
```

If absent: skip. ≥20 files → note once: *"Consider `/saki-builder:graphify .` for richer §16."*

Grep/read the codebase to verify every technical claim before writing anything:
- Code confirms it → tag `observed`, note `path:line` internally
- Code contradicts it → fix the claim
- Not found in code → tag `assumed`

### Tier 1.5 — Demand evidence (run if `{{input.evidence}}` provided, else prompt once)

The strongest product evidence is **demand signal**, not code. If `{{input.evidence}}` is set (a
path or pasted analytics / support-ticket / sales-quote / usage data), read it and let it ground
§2 Problem & Evidence — tag the sourced claims `observed`/`validated` and cite the signal
internally. If no evidence input was given, ask **once**, plainly: *"Any real signal this is wanted
— usage numbers, tickets, a user quote? (or 'none — it's a bet')"*. If the answer is "none/a bet",
do not fabricate demand: leave §2's problem claim `assumed` and let it flow to the premise check
(Step 0b) and the surfaced-bet line (Step 8). A PRD grounded only in code and web research, with no
demand signal, is a bet — say so, don't launder it.

### Tier 2 — External grounding (only if `--research` passed)

Ground the load-bearing assumption and baseline metrics via `/deep-research` or `WebSearch`.
Tag `validated`, cite the URL internally. Skip entirely if `--research` not set.

---

## Steps 1–6 — Internal PRD construction (INTERNAL — do not show to human)

Run these silently. The output feeds both the saved file (Step 7) and the 5-point human view
(Step 8).

### 1. Job to be Done (Klement format)

Write exactly one primary: `When [situation], I want to [motivation], so I can [outcome].`
Two primary jobs = two PRDs. Related jobs: 0–3 max.
**Number the jobs so `Serves`/`JTBD` refs resolve:** the **primary job is `J1`** (§3); related jobs
are `J2`, `J3`, … in §4 order. Every slice's `Serves: J<n>` tag (Step 3) and every §5 `JTBD` value
(Step 2) MUST name one of these IDs — **except the counter-metric row, whose `JTBD` cell names the
metric(s) it guards (`guards 5.x`), not a job**. A `Jn` with no matching job in §3/§4 is a dangling
reference (the gate and `/saki-builder:prd-review` both fail it).
**Resolution is bidirectional.** The mirror also holds: every related job in §4 MUST itself be served
by ≥1 §5 outcome or §8 slice. A `J2`/`J3`… that nothing references is an **orphan job** — cut it (it
isn't really part of what you're building) or add the outcome/slice that serves it. A dangling
*reference* is a correctness break (a slice claims a job that doesn't exist); an orphan *job* is
scope theater (a job you listed but aren't building) — lower severity, deducted not blocked.

### 2. Outcomes (Ulwick format)

1 primary + 2–3 secondary + 1 counter-metric.
Emit §5 as a table with an explicit **Basis** column — without a column for it the basis tag
gets dropped at write time (the exact leak `/saki-builder:prd-review` hard-fails on):

`| # | Outcome (Minimize/Maximize [metric] when [context]) | Target | Basis | Method | JTBD |`

**Basis** is required on every row — one of `baseline N→M` (a measured starting point, N — **cite its
source**, don't merely restate the target), `benchmark` (an external/comparable reference), or
`aspirational` (no baseline yet — an honest target, not a measured one). A numeric target with an
empty/absent Basis is fabricated precision; a `baseline N→M` whose starting number N has no cited
source is a **circular basis** (it restates the target instead of grounding it) — cite N's source or
tag the row `aspirational`.

**Method** is *how the number gets read* — and it decides whether the metric needs instrumentation.
Classify every row's Method as exactly one of:
- `query` — the data already persists (a table/column an existing write leaves behind). Method reads
  `query: <what to count>` (e.g. `query: orders WHERE status='paid'`). **No new emit** — the row is
  measurable with what ships anyway. Use a DB/`query` Method only for server-side state GA4 can't see.
- `event` — the metric counts a user/system **action that nothing currently records**. Method MUST name
  the event and its trigger: `event: emit <event_name> when <trigger>` (e.g.
  `event: emit checkout_completed when checkout succeeds`). This is the **instrumentation target**
  `/saki-builder:rplan` ingests into a build step + a firing criterion — an `event` Method with no named
  event is undefined build work (`/saki-builder:prd-review` flags it). **Default the emit to a GA4 event**
  for product-usage metrics (GA4 is the house analytics default, wired by `/saki-builder:genesis`
  foundations) and back it with a §9 `observability` acceptance criterion asserting the event fires —
  that is how the default GA4 instrumentation actually reaches the build.
- `external` — read outside our code (payment dashboard, survey, third-party analytics). Method reads
  `external: <source>`. No emit — but say where the number comes from so it isn't mistaken for `query`.


Counter-metric must name the specific failure mode it guards (e.g. "guards 5.1: faster onboarding
gamed by skipping verification → locked-out users"); in the §5 table its `JTBD` cell reads
`guards 5.x` (the metric(s) it protects), not a `Jn`.

### 3. Slices (INVEST)

Number them. Each slice must pass all five:
1. Single user-visible capability
2. ≤2 modules
3. Test-first feasible (a failing test can be written before implementation)
4. Forward dependency only (Slice N depends on 1..N-1, never N+1)
5. Fits ~30 min agent iteration (≤5 acceptance criteria)

Each slice states **`Serves: J<n> · 5.<x>`** — the JTBD and the primary outcome it advances (this
is what `/saki-builder:prd-review` item 8 checks; a slice with no `Serves` line reads as an orphan).

A slice **MAY** carry an optional **`Assumes:`** line naming the hidden build work its behavior silently
requires but the acceptance criteria don't state — migration/backfill of existing rows · a feature flag ·
a new permission/role · an index the metric query needs · seed data · a rollback path. Keep it
**category-level and one line** (`Assumes: a backfill of existing orders; a pending-payout index`) — NOT
file-level task breakdown (which migration file / which column is `/saki-builder:rplan`'s job). If the
hidden work is a load-bearing capability in its own right (its own testable behavior), **promote it to its
own slice** instead of an `Assumes:` line. This is the line `/saki-builder:rplan` Step 1 ingests so the work
reaches the plan instead of being rediscovered mid-build; `/saki-builder:prd-review` Judge 3 prescribes it
when a state-changing slice omits it.

Cap: ≤7 slices (>7 = split into multiple epics, each its own PRD). Slice 1 = vertical walking skeleton.

### 4. Acceptance criteria per slice

Each criterion must be **observable and executable** — this is the `/saki-builder:prd-review` item 9
contract (and what `/saki-builder:qa` runs). Write each as **Given / When / Then** with a **checkable
signal**, and tag it **`[auto]`** or **`[manual]`**:

```
- N.M [auto] Given <precondition>, when <actor does X>, then <observable result + checkable signal>. → 5.x
```

- **`[auto]`** — verifiable by curl / a test / a file check / grep (HTTP status, JSON shape, row
  count, file exists, exit code). **`[manual]`** — needs a human or browser (visual rendering, auth
  flow, feel). Every criterion gets exactly one tag; a criterion with no tag is not done.
- The **signal must be checkable** — "downloads a file with the same row count as the table", not
  "works correctly" / "is intuitive" (those hard-fail review).
- Each criterion links a §5 outcome (`→ 5.x`) OR names a guardrail from this menu:
  `security | validation | error-path | accessibility | performance | privacy | observability | cost | i18n`
- Cap ≤5 criteria per slice. Prefer `[auto]` where the outcome is machine-checkable; reserve
  `[manual]` for genuinely human-judged behavior.

### 5. Business rules

Numbered, falsifiable statements ("A withdrawal is rejected if amount > balance").
Tag money/stock/tenant rules `🔒 INVARIANT`. Link each rule to ≥1 acceptance criterion — and a
`🔒 INVARIANT` MUST be tested by a criterion that exercises its **failure/edge path**, not only the
happy path (over-limit · empty/zero · concurrent/double-submit · unauthorized/wrong-tenant ·
duplicate/idempotency-on-retry · … — apply the paths the rule's stated behavior implies). A
happy-path-only test of an invariant is exactly what `/saki-builder:prd-review` Phase 1 hard-fails.

### 6. Technical Contract (thin — evidence-grounded)

Author the **§16 Technical Contract** (saved in Step 7) — the load-bearing DB/API/architecture **shape**
the slices can't work without, and nothing more. This is the surface `/saki-builder:prd-review` verifies
and `/saki-builder:rplan` hardens into full design. It is **shape, not design**.

**Omit-if-none:** if the feature adds **or changes** no data/API/architecture surface (pure UI/copy change), skip §16 —
a feature that only *modifies* existing surfaces adds none, but it is exactly the compat case §16 exists to
surface — it does NOT qualify for the omission —
in the saved file write the one-liner `No backend surface — UI-only change.` (same rule as §13/§14/§15).

**Evidence rule (do NOT design blind).** Build §16 *from the Step 0.7 Tier-1 local-grounding scan* — do not
re-scan and do not invent. Every row is one of:
- **REUSE** — the entity/endpoint/component already exists **and this feature does not modify it**; cite it
  `path:line` (the Tier-1 `observed` note).
- **CHANGE** — it already exists **and this feature modifies it** (a field's meaning or shape, a response,
  a signature, a status, a config key, an event payload). Cite it `path:line` like a REUSE row, **and add a
  `↳ Breaks:` sub-line naming what currently depends on the present shape** — or `↳ Breaks: none (additive)`
  when the change only adds. A CHANGE row is by definition a **compatibility surface**: it is what
  `/saki-builder:rplan` turns into a Compatibility & Consumers entry, so an unstated blast radius here is
  a breakage discovered mid-build. Prefer CHANGE over REUSE whenever in doubt — a modification tagged
  REUSE is the exact failure this tag exists to catch.
- **NEW** — it does not exist yet; tag `NEW` (no citation, but it must serve a slice).

A row that cites nothing and isn't tagged `NEW` is fabricated — cut it or ground it. A `CHANGE` row with no
`↳ Breaks:` sub-line is incomplete — it names a compat surface and then hides its blast radius.

**YAGNI rule.** Every row MUST name the slice · outcome it serves (`8.x · 5.x`). A surface that serves no
§8 slice / §5 outcome is speculative — cut it. The contract carries only what the slices imply.

**Thin rule (altitude — this is `/saki-builder:rplan`'s boundary).** Entities name the *thing*, not its
columns. Endpoints name *method + path + purpose*, not request/response field lists. The architecture line
is *one* load-bearing decision, not a component diagram. No migration files, no indexes, no schemas — those
are `/saki-builder:rplan`. If you're writing field names, you've crossed the line. **A `CHANGE` row keeps the
same altitude:** name *what kind* of change (a field's meaning, a response shape, a signature, a status set)
and, in `↳ Breaks:`, *who depends on the present shape* — never the new column type or the new payload. A
field name appearing inside a `↳ Breaks:` note is compat evidence, not design, and does not cross the line.

Emit three parts (any part with no rows is omitted):

```
**Entities (data):**       | Entity | Reuse / Change / New | Evidence (`path:line`) or note | Serves |
**Endpoints (API):**       | Method + path — purpose | Reuse / Change / New | Evidence or note | Serves |   (purpose only, not payloads)
**Architecture decision (one, load-bearing):**  - <decision> — <reused component `path:line` · CHANGED component `path:line` + ↳ Breaks: · or NEW>. Serves 5.x. <alternative rejected + why>.

  (a CHANGE row's `↳ Breaks:` sub-line sits directly beneath it, e.g.
   `| SellerPayout | CHANGE | backend/models/payout.py:14 | 8.2 · 5.1 |`
   `|   ↳ Breaks: the payout-status webhook consumers read the old two-state field |`)
```

### Appetite, Kill Criteria & Decision Log (from Step 0.5 — feeds §6 + §7)

- **Appetite (§6)** — the time-box from Step 0.5(b), stated as `small|medium|large` + a concrete
  span (e.g. "medium — a few days"). The slice count (§8) **must fit** the appetite band above
  (small ≤2, medium ≤4, large ≤7). If it doesn't, cut scope or split the PRD — do not inflate the
  appetite to fit the slices.
- **Kill Criteria (§6)** — an outcome-tied stop signal: the §5 metric + threshold at which we stop
  even if unfinished (not an effort budget). Name the specific failure it catches.
- **Decision Log (§7)** — from Step 0.5(c/d): the chosen shape + each alternative with a one-line
  why-not. This is what stops a team re-litigating the approach later.

**Gate = the Blocking Set is empty.** Every row in the table below is a **Blocking predicate** — under the
strict model, resolve ALL of them before presenting: a cited real defect blocks, and there is no tolerance
sum to hide behind. The Severity column is a fix-order hint (fix `BLOCK` / larger `−N` first), **not a
summand** — a `−3` no more "buys slack" than a `BLOCK`; both must be clear. Genuine cosmetic polish that is
not in this table stays Advisory and never gates.
**Keep this internal — never show the Blocking list or the table to the human.**

| Blocking predicate (resolve before presenting) | Severity (fix-order hint — NOT summed) |
|------------------------------------------------|----------------------------------------|
| Premise check (Step 0b) not run, OR load-bearing assumption not stated + tagged in §2 of the saved file | BLOCK |
| Primary JTBD in persona form ("As a…") | BLOCK |
| Appetite (§6) missing or not set in Step 0.5 | BLOCK |
| Slice count exceeds the appetite band (small ≤2 / medium ≤4 / large ≤7) | −5 |
| Decision Log (§7) absent — no alternatives recorded for the chosen shape | −3 |
| Demand evidence provided (`{{input.evidence}}`) but not reflected in §2 | −3 |
| Evidence 100% `assumed` with no named validation spike (no §2 `**Spike:**` line from Step 0b's auto-spike) | −10 |
| `observed`/`validated` claim with no cited source | −5 each |
| Tier-1 local grounding skipped | −5 |
| §5 outcome with target but no basis tag | −3 each |
| §5 `baseline` basis with no cited source for its starting number (circular — restates the target) | −3 each |
| §5 measurement method not instrumentable and not an Open Question | −3 each |
| §5 Method unclassified (no `query`/`event`/`external` prefix) | −3 each |
| §5 `event`-class Method names no event (`emit <name> when <trigger>` missing) | −3 each |
| Counter-metric names no metric/failure-mode it guards | −5 |
| Kill criteria missing or not outcome-tied | −8 |
| Orphan slice (serves no JTBD), or a `Serves`/`JTBD` `Jn` not defined in §3/§4 (dangling ref) | −5 each |
| Orphan related job (a §4 `Jn` defined but referenced by no §5 outcome and no §8 slice) | −5 each |
| §5 outcome with no slice criterion linking to it | −5 each |
| Acceptance criterion with no outcome link and no guardrail | −3 each |
| Acceptance criterion not observable (no Given/When/Then + checkable signal) OR missing `[auto]`/`[manual]` tag | BLOCK |
| Slice missing its `Serves: J<n> · 5.<x>` tag | −3 each |
| Slice fails any INVEST check | −5 each |
| >7 slices, not split | −8 |
| Feature has domain logic but §10 is empty or false "none beyond CRUD" | −8 |
| `🔒 INVARIANT` not tested by any acceptance criterion | BLOCK |
| `🔒 INVARIANT` tested only by a happy-path criterion (no failure/edge criterion) | BLOCK |
| Non-Goals < 2 | −5 |
| §16 omitted while a slice implies **or modifies** a data/API/architecture surface (not marked UI-only) | −5 |
| §16 row with no evidence tag (none of a REUSE `path:line`, a CHANGE `path:line`, or `NEW`) | −3 each |
| §16 `CHANGE` row with no `↳ Breaks:` note (what depends on the current shape) | BLOCK |
| §16 row tagged REUSE while its serving slice text says change/extend/rename/replace (a modification hiding as reuse) | −5 each |
| §16 row serving no §8 slice / §5 outcome (speculative surface — YAGNI) | −5 each |
| §16 crosses into full design (column/field names, full req/resp payload, migration file, index) — **a field name inside a `↳ Breaks:` note is compat evidence, not design, and is exempt** | −3 |

If any Blocking predicate is unresolved → fix the cited gaps and re-check. Do NOT present with a non-empty Blocking Set.

**Phase-1 structural blockers (always Blocking, listed for lockstep).** A PRD with ANY of the following
fails `/saki-builder:prd-review` Phase 1 and must be fixed before presenting: a `🔒 INVARIANT` with no
failure/edge criterion; a §5 target with no basis tag; a dangling `Jn` (a `Serves`/`JTBD` ref resolving
to no §3/§4 job); missing or effort-only Kill Criteria; <2 Non-Goals; an absent Decision Log (§7); or a
slice with no `Serves` tag. Under the strict gate these are Blocking like every other row — called out
here so `/saki-builder:prd` and `/saki-builder:prd-review` stay in lockstep on what Phase 1 rejects.

---

## Step 7 — Save the full PRD (for downstream skill consumption)

Save to `tasks/prd-{{input.feature | slugify}}.md` with ALL sections in this exact order
so `/saki-builder:rplan`, `/saki-builder:proto`, and `/saki-builder:qa` can parse them:

```
<!-- prd-blocking: 0 -->
<!-- slices: [N] -->
<!-- appetite: [small|medium|large] -->

# PRD: [Feature name]

**Owner:** [@name | unassigned] · **Status:** Draft · **Updated:** [YYYY-MM-DD] · **Appetite:** [small — hours | medium — a few days | large — ~a week+] · **Item:** [E<n> | F<n> | —]

## 1. TL;DR
## 2. Problem & Evidence   (ends with **Load-bearing assumption:** <X> — `assumed|observed|validated`, plus a **Spike:** line beneath it if Step 0b ran one — the premise from Step 0b, in the file, not just scratch)
## 3. Primary Job to be Done   (label this job `J1` — Klement form)
## 4. Related Jobs             (label `J2`, `J3`, … in order — referenced by slices/outcomes as `Jn`)
## 5. Desired Outcomes / Success Metrics   (cols: # | Outcome | Target | Basis | Method | JTBD)
## 6. Appetite & Kill Criteria      (Appetite band + span from Step 0.5(b); outcome-tied Kill Criteria)
## 7. Solution Shape                (the chosen shape + an **Alternatives considered / Decision** subsection = the Decision Log)
## 8. Vertical Slices              (each slice carries a `Serves: J<n> · 5.<x>` tag)
## 9. Acceptance Criteria per Slice   (each: Given/When/Then + checkable signal + `[auto]`/`[manual]`; ≤5/slice)
## 10. Business Rules & Invariants
## 11. Non-Goals
## 12. Rabbit Holes & Open Questions
## 13. Technical Constraints  (omit if none)
## 14. Dependencies           (omit if none)
## 15. Screens & UI Reference  (omit if the feature has no user-visible UI)
## 16. Technical Contract (thin)  (omit if the feature adds no data/API/architecture surface)
```

**§15 Screens & UI Reference** is the PRD's UI/UX footprint in the *saved artifact*. Populate it from the
**same screen list you present in Step 8** (the plain-English "Screens") — persist it here so the PRD names
its user-visible screens (one line each), instead of the list being computed for the human view and thrown
away. This is the product-level screen inventory, NOT a design (the visual design is `/saki-builder:proto`'s job).
When the feature has no user-visible screens, **omit §15 entirely** (a backend PRD has no UI footprint — the
same "omit if none" rule as §13/§14). `/saki-builder:proto` writes the **approved-design reference** into §15 at lock
time (`UI approved: tasks/proto-<slug>/ · <date>`), so the locked artifact points at its design.

**§16 Technical Contract (thin)** is the PRD's **DB/API/architecture shape** in the saved artifact — the
load-bearing surfaces the slices imply, authored in Step 6 from the Step 0.7 Tier-1 scan. Each row is REUSE
(cites real code `path:line`), **CHANGE** (cites real code `path:line` **plus** a `↳ Breaks:` sub-line — an
existing surface this feature *modifies*, i.e. a compatibility surface), or NEW, and names the `8.x · 5.x`
slice/outcome it serves. It is **shape, not
design** — entities not columns, endpoint purposes not payloads, one architecture decision not a diagram; the
full schema/req-resp/migrations are `/saki-builder:rplan`'s job. `/saki-builder:prd-review` **verifies** §16
(present · cited · slice-coherent) then flags any residual gap; `/saki-builder:rplan` **ingests** §16 as the
shape to harden. When the feature adds no backend surface, **omit §16** (write `No backend surface — UI-only
change.`) — same "omit if none" rule as §13/§14/§15.

**Section numbers §1–§16 are a hard contract** — `/saki-builder:proto` and `/saki-builder:prd-review` reference
§5/§8/§9/§10/§11/§16 **by number**. Never renumber; add new content as subsections (the Decision Log lives *inside*
§7) or in the header, never by inserting a numbered section mid-document. **§15 and §16 are tail appends** (after
§14) — they shift no existing number, so they are contract-safe; keep new sections at the tail, never inserted
between existing ones.

The **shareable header** (Owner/Status/Updated/Appetite/Item) is team-facing metadata — a solo builder can
leave `Owner: unassigned` and ignore it; a team uses it to own, review, and date the PRD. `Status`
advances **Draft → In Review → Approved → Locked** as the PRD moves through `/saki-builder:prd-review`, human
sign-off, and the `/saki-builder:proto` lock (below).
**Item:** carries the PRD-track item id (`E<n>` or `F<n>`) this PRD serves when it was started by
`/saki-builder:pickup <id>` — the traceability link back to `tasks/roadmap.md`; a standalone PRD leaves it `—`.

### The lock — the explicit freeze before build (`Status: Locked`)

The PRD phase (`/saki-builder:prd` → `/saki-builder:prd-review` → `/saki-builder:proto`) ends with an **explicit lock**:
the requirements are frozen before any slice reaches `/saki-builder:rplan`. The lock is a header machine-marker:

`<!-- prd-locked: <@approver> · <YYYY-MM-DD> · ui:tasks/proto-<slug>/ | none -->`  +  header `Status: Locked`

- **Written by `/saki-builder:proto`, not `/saki-builder:prd`.** The lock is the terminal act of the last pre-build
  layer: `/saki-builder:proto` designs the UI/UX, gets it approved, then freezes the spec by writing the marker.
  `/saki-builder:prd` **never** writes it — the *absence* of the marker is the correct default (not-yet-frozen). For a
  no-UI PRD, `/saki-builder:proto` is still the explicit freeze step (it renders nothing and writes `ui:none`).
- **Approved vs Locked.** *Approved* = sound + review-green + human sign-off (soundness). *Locked* = Approved
  AND its UI/UX designed/approved AND requirements frozen (build-ready). A Locked PRD is by definition Approved;
  `prd-locked` is the single flag `/saki-builder:build` reads — it **hard-refuses to start until the lock is present**
  (a GATE before `/saki-builder:rplan`). This is the "lock Product Requirement before hand off to rplan" gate.
- `ui:` points at the approved proto gallery (`tasks/proto-<slug>/`), so the locked artifact references its
  design; §15 carries the same reference in prose. On a no-UI PRD the value is `none`.

Include a `⚠ DISCOVERY-RISK` banner below the machine-readable header if the evidence table
is 100% `assumed`, OR the **§2 load-bearing assumption is `assumed`**, OR **any assumption that gates a
committed §5 metric is `assumed`** (e.g. an adoption/willingness claim the primary or secondary outcome
depends on) — a single un-grounded load-bearing/gating row is a bet even when the rest of the table is
grounded. This is a signal for `/saki-builder:rplan` to surface it as a plan-level UNKNOWN, and it MUST
also be surfaced to the human in Step 8 (the bet line), not left file-only. It is also what
`/saki-builder:prd-review` Readiness DoR #4 keys off — leaving it unset lets a bet pass as READY.

---

## Step 8 — Present to the human (plain English only)

Show ONLY this. Plain English. No methodology, no scores, no tags, no section numbers.

```markdown
# [Feature name]

## What I understood you want
[1–3 sentences. What the user experiences. What's saved or remembered. What's out of scope.
Written as if explaining to a teammate, not a product analyst.]

## Why this approach
[One line, from the Step 0.5 decision: the shape we chose vs the main alternative and why.
E.g. "Inline edit rather than a separate settings page — fewer clicks, fits the appetite."
Omit only if there was genuinely one obvious shape.]

## How much this is worth
[The appetite in plain English: "About a few days of work" (medium). This is the budget —
if it grows past this, we cut scope, not stretch the time.]

## Screens
[Numbered list of user-visible pages or views this feature adds or changes.
One line each. No jargon. Omit this section entirely if the feature has no UI —
replace with a one-liner: "No user-visible screens — this is a backend change."
Persist this same list to the saved PRD's §15 (Step 7) so the artifact names its UI — do not compute
it only for this view and throw it away.]

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

**If the PRD carries a `⚠ DISCOVERY-RISK` banner (load-bearing assumption still `assumed`, no
demand signal), you MUST add a bet callout above the closing question — never let the human approve
a bet without seeing it's a bet:**

```markdown
## ⚠ Worth checking first
This rests on one unproven assumption: [X, in plain English].
[If Step 0b's auto-spike ran and came back inconclusive: "I tried checking this — [one line: what the
spike attempted] — and it didn't resolve. Cheapest next step: [a founder call / a paid data source / a
small pilot / asking N real users]."
If the spike never ran (stopped before reaching it): "Cheapest way to check before we build: [Y — a
quick spike, a look at real usage, asking N users]."]
```

Then ask: *"Does this match what you had in mind — or should we adjust before building?"*

---

## Step 9 — After human approval

Advance the saved header `Status: Draft → In Review`, then suggest next steps in plain English:

- Recommended: *"Run `/saki-builder:prd-review tasks/prd-[slug].md` to pressure-test the spec before we build."*
- Then: *"Run `/saki-builder:proto tasks/prd-[slug].md` to see what it'll look like — and, on your approval,
  that **locks** the requirements (freezes the spec) for build."* (A no-UI PRD still runs `/saki-builder:proto`
  as the explicit freeze step.)
- Then (only once **Locked**): *"Run `/saki-builder:build tasks/prd-[slug].md` — it plans each slice with
  `/saki-builder:rplan` and ships it. `/saki-builder:build` won't start until the PRD is Locked."*

> When this PRD is on the roadmap (`Item:` set), `/saki-builder:proto` and `/saki-builder:build` also accept
> the **item id** — `proto E3` and `proto tasks/prd-[slug].md` are equivalent (the id resolves via the
> roadmap `Child PRD:` link). Prefer the id form to match `/saki-builder:pickup`'s handoff; the path form is
> the standalone (no-item) fallback.

Do NOT produce file-level tasks in the PRD — that is `/saki-builder:rplan`'s job. The disciplined path is
`/saki-builder:pickup <id>` → `/saki-builder:proto <id>` (locks) → `/saki-builder:build <id>` (`<id>` = E<n>/F<n>).

---

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Showing the internal Blocking list or predicate table to the human | Enforce it internally — never display it |
| Showing Klement / Ulwick / INVEST labels to human | Internal discipline only |
| Acceptance criteria written as HTTP calls in Step 8 | Write what the user observes, not how code works |
| "Screens" that are backend-only | Only list what a user actually sees |
| "When we stop" referencing a metric the human can't observe | Use user-observable behavior |
| Hollow output (vague criteria, empty screens) | Quality gate still enforces substance — hollow output fails it |
| Skipping Step 0b because the feature sounds obvious | Obvious features fail the premise check most often |
| Recommending a spike to the human instead of running one | Step 0b's auto-spike is mandatory once the assumption is `assumed` and two reasons stand unrebutted — spawn the subagent yourself; only escalate to the human if the spike itself can't be attempted |
| Skipping Step 0.5 — formalizing the first idea without shaping | Run the shape pass; the PRD formalizes a *chosen* shape, not a guess |
| Inflating appetite to fit the slices | Appetite is fixed; cut scope or split the PRD — never stretch the budget |
| A "decision" with no alternatives recorded | Not a decision — log the chosen shape + a why-not for each option (§7) |
| A related job (§4) that no §5 outcome or §8 slice serves | Orphan job — cut it (YAGNI) or add the outcome/slice that serves it; resolution is bidirectional, not just ref→job |
| Inserting a new numbered section (renumbering §5/§8/§9/§10/§11) | Hard contract — add subsections (Decision Log lives in §7) or use the header |
| A `🔒 INVARIANT` tested only on the happy path | Add a failure/edge criterion (over-limit · concurrent · duplicate/idempotency · unauthorized) — review Phase 1 hard-fails a happy-path-only invariant |
| A slice that silently assumes hidden build work (migration/index/flag/backfill) | State it in the slice's `Assumes:` line (or promote it to its own slice) — else `/saki-builder:rplan` rediscovers it mid-build; review Judge 3 prescribes it |
| A `baseline N→M` basis that just restates the target | Cite the source of the starting number N, or tag the row `aspirational` — a basis must ground, not echo |
| Approving a bet without flagging it | If DISCOVERY-RISK, the Step 8 "⚠ Worth checking first" callout is mandatory |
| Handing a PRD to `/saki-builder:build` (or `/saki-builder:rplan`) that isn't **Locked** | Requirements aren't frozen — `/saki-builder:proto`'s approval writes `Status: Locked` + `<!-- prd-locked -->`; build hard-refuses until it's present. `/saki-builder:prd` never writes the lock (absence = not-yet-frozen) |
| A UI feature whose screens live only in the Step 8 human view | Persist them to §15 of the saved PRD — the artifact must name its UI, not compute-and-discard it |
| §16 Technical Contract written with column/field names or full request/response payloads | Shape only — entity/endpoint-purpose/one-arch-decision; the schema depth is `/saki-builder:rplan`'s lane |
| A §16 row that cites no code and isn't tagged `NEW`, or serves no §8/§5 ref | Ground it from the Tier-1 scan (REUSE / CHANGE `path:line` / NEW) and name its slice·outcome, or cut it (YAGNI) |
| A §16 row tagged `REUSE` for a surface the feature actually **modifies** | Tag it `CHANGE` + add `↳ Breaks:` — a modification wearing a reuse tag is an invisible compat surface, the exact break this tag exists to catch |
| A `CHANGE` row with no `↳ Breaks:` note | Name what depends on the present shape (or `none (additive)`) — a compat surface with an unstated blast radius is rediscovered mid-build |

## Script

```bash
#!/bin/bash
mkdir -p tasks
```
