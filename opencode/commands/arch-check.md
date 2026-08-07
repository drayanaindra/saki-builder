---
description: "Read-only per-module architecture-tier detector. Measures the MECHANICAL transition triggers from modular-architecture.md against the repo and reports, per module, which fired — recommending a clean-arch (Stage 3) upgrade ONLY for modules that cross thresholds. Judgment-only triggers (business rules, aggregate boundaries) surfaced as candidates. Detect + recommend only — never rewrites code or runs a migration. Usage — /arch-check [repo-root]."
---

# arch-check — per-module architecture-tier detector

`/arch-check` answers one question, per module, from evidence:
**"Which architecture-ladder transition triggers have actually fired — and does any specific module
warrant a clean-architecture (Stage 3) upgrade?"**

The architecture ladder and its transition triggers live in
`${CLAUDE_PLUGIN_ROOT}/config/docs/modular-architecture.md` (§Transition Triggers). That doc is the
**single source of truth** for the thresholds; this skill only *measures the repo against it* and reports.

**It is detect + recommend ONLY.** It never edits, moves, or refactors code, and never runs a migration.
Acting on a recommendation is a separate, human-gated step (`/rplan` a per-module refactor).

---

## The one rule that must not be broken

Stage 3 (clean architecture) is a **per-MODULE** upgrade, not a whole-app flip. The doc is explicit:
*"Stage 2 triggers fire for a SPECIFIC module (not all at once)… Only upgrade modules that genuinely need
it — most stay at Stage 2."* So the report recommends clean-arch for **individual crossing modules**, never
for the whole codebase.

---

## Step 1 — Locate the triggers (source of truth)

Read `${CLAUDE_PLUGIN_ROOT}/config/docs/modular-architecture.md` §Transition Triggers. Confirm the
thresholds the detector uses match the doc (they are mirrored as named constants in `detect.sh`):

- **Stage 1→2** (app-level): model count >15 · component count >20 · any backend `.py` >300 · any frontend `.tsx` >500.
- **Stage 2→3** (per-module): module `service.*` >500 lines · module imports ≥5 sibling modules.

If the doc's thresholds ever change, they win — update `detect.sh`'s constants to match, don't fork them here.

## Step 2 — Measure (run the emitter)

Run the read-only detector against the target repo (default: current dir):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/config/skills/arch-check/detect.sh [repo-root]
```

It prints a `Detected layout:` line, one `MODULE <name> service_loc=… sibling_imports=… stage3_fired=…`
line per module (Stage 2 layouts), and an `APP …` line with the Stage 1→2 metrics (flat layouts).

## Step 2.5 — Graphify Enrichment (if graph exists — additive)

Read the knowledge graph report before and after running `detect.sh`. This step never blocks —
if the graph is absent, proceed to Step 3.

```bash
cat graphify-out/GRAPH_REPORT.md 2>/dev/null || echo "No graph — run /graphify . to build one."
```

Then query for module-specific structural data:
```bash
graphify query "which modules are most interconnected?"
graphify path "ModuleA" "ModuleB"   # for any two modules where coupling is suspected
graphify explain "GodNodeName"           # for any god node in the report — prints its Degree
```

**How to use the graph output in the arch-check report:**

- **God node inside a `stage3_fired=yes` module** → **HARD UPGRADE signal** — it's structurally
  load-bearing AND already oversized. Add to the FIRED section: "Graph: god node `X`
  (Degree: Y edges) lives in this module — high-connectivity + size trigger = upgrade urgency elevated."
- **God node in a Stage 2 module (no fired trigger)** → CANDIDATE: "This module owns graph hub
  `X` (Degree: Y edges) — coupling risk if the module grows further."
- **Two detect.sh modules in the same community cluster** → hidden coupling CANDIDATE: "Modules
  A and B cluster together in the graph — consider whether they should be one module or need an
  explicit boundary."
- **Surprising connections** → surface as CANDIDATE triggers: cross-module edges the static import
  heuristic can miss, each with its plain-English _why_ from the report.

## Step 3 — Classify each trigger: FIRED vs CANDIDATE

Split every trigger into two honest buckets — **never present a judgment trigger as if it were measured**:

- **FIRED** — a *mechanical* trigger the detector measured and that crossed its threshold
  (`stage3_fired=yes`, or `stage2_fired=yes`). These are evidence.
- **CANDIDATE** — a *judgment or external* trigger the detector CANNOT measure. Surface each as a question
  for the human, never as a fired result:
  - business-rule count (>10 non-validation rules in the module)
  - domain complexity / aggregate boundaries needed (e.g. Order → OrderItems → Payment)
  - dev count >3 · dedicated team ownership · merge-conflict frequency

Also honour honest `n/a`: when `detect.sh` reports `n/a` for a metric (a stack whose files don't match the
doc's Python/React shapes), report it as *not measurable for this stack* — **never** as a passing "clear".

## Step 4 — Recommend (per crossing module only)

For each module with at least one FIRED trigger, recommend a clean-arch (Stage 3) upgrade of **that module
only**, and point at the doc's Strangler-Fig migration recipe. Modules with no FIRED trigger stay at Stage 2
(note any CANDIDATE worth a human look). Close with the detect-only footer and the hand-off.

---

## Report Format

```
ARCH-CHECK — <repo>   (<date>)

Detected layout: <from detect.sh>
Modules: <n> (<names>)

Per-module — Stage 2 → 3 (clean-arch) triggers:

  <module>   ⚠ FIRED (<n> measured)
    • service.* <loc> lines            (> 500)        [measured]
    • imports <n> sibling modules      (≥ 5, approx)  [measured]
    • business rules / aggregate boundaries           [candidate — confirm]
    ⇒ RECOMMEND clean-arch (Stage 3) upgrade of `<module>` ONLY

  <module>   — no measured trigger
    • <candidate, if any>                              [candidate — confirm]

App-level — Stage 1 → 2 triggers: <fired list | N/A (already Stage 2)>

NOT auto-measured (judgment/external — confirm manually):
  business-rule count · aggregate boundaries · dev count > 3 · team ownership · merge-conflict frequency

Recommendation: <upgrade `<module>` per-module via the Strangler-Fig recipe | all modules stay Stage 2>.

Detect-only — no code changed. To act: /rplan a per-module refactor of `<module>`.
```

---

## Rules

- **Detect + recommend only.** NEVER edit, move, or refactor code; NEVER run a migration. The skill's
  output is a report, not a change.
- **Per-module, never whole-app.** Recommend Stage 3 for individual crossing modules only.
- **Measured vs judgment stays separated.** A CANDIDATE trigger is a question for the human, never a
  fired verdict. Do not fabricate a business-rule count or an aggregate-boundary call.
- **The doc is the source of truth.** Thresholds come from `modular-architecture.md`; `detect.sh` mirrors
  them as constants. If they drift, reconcile `detect.sh` to the doc — never keep a second set here.
- **Honest n/a.** A metric the detector can't measure for this stack is reported as not-measurable, not as
  a clear pass.
- **Cross-module import count is approximate** (a language heuristic) — label it `approx`; when it is the
  only signal, treat the recommendation as soft and lean on the `service.*` LOC trigger.
