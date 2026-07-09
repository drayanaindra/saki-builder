# Dry-Run E2E Audit — saki-builder workflow chains

**Date:** 2026-07-09 · **Mode:** trace/audit (no real build) · **Auditor:** Claude (Opus)

**Method.** Read all 14 skill files in the two entry chains in full (5 parallel readers), extracted each
skill's I/O contract (consumes → produces → gates → next-hop) with line citations, then **verified every
load-bearing seam claim against the actual file text** before recording it. No product was built.

**Scope.**
- **Chain A — Greenfield:** `/genesis` → `/pickup E1` → `/prd` ↔ `/prd-review` → `/proto` → `/build`
- **Chain B — Existing project:** `/add` → (PRD-track) `/pickup` → `/prd` ↔ `/prd-review` → `/proto` → `/build`;
  (Plan-track) `/add` → `/rplan` → `/approved` → `/qa`

> **RESOLUTION (2026-07-09).** All **HIGH + MED** findings below are **fixed** in the skill files:
> **G-1, G-2, G-3** (`genesis`, `roadmap`), **P-1** (`pickup`), **PT-1** (`rplan` + `qa`),
> **B-2** (`build`, `approved`, `qa`, `rplan`), **B-4**/**B-5** (`build`). **B-1** (manifest path) is also
> closed by consolidating **all** workflow artifacts (plans + `-context.md`/`-flow.md`) under `tasks/`
> (they were in the project root) — this also fixed a latent `proto`↔`rplan` flow-file mismatch (`proto`
> already read `tasks/*-flow.md` while `rplan` wrote to root). The 5 LOW findings (**B-3, P-2, P-3, P-4,
> B-6**) are now **also fixed**: B-3 `approved` Blocking-Set gate; P-2 `prd` id-form alignment; P-3 `pickup`
> advances the PRD doc Status `Draft → In Review`; P-4 `pickup` `Superseded by:` marker + `build` parent-close
> when the last phase-chain child ships + roadmap render; B-6 `rplan-review` made `user-invocable: true`
> (matching the README/description/`rplan` references). **All 14 findings resolved.**
> `node test/validate.js` passes. See the per-finding **Fix** blocks for what changed.

**Verdict.** The **spine holds** — the two seams most likely to silently break a chain are actually sound:
the **PRD lock** (proto writes `<!-- prd-locked: … -->`, build greps exactly that) and the **plan-file
handoff inside `/build`** for a *single* slice (rplan/approved/qa/rplan-review all agree on `*-plan.md` in
project root). The breaks are concentrated in three places: **greenfield scaffold readiness (Chain A crux),
multi-slice plan selection (Chain B build), and the plan-track item lifecycle (Chain B plan-track).**

---

## Verdict at a glance

| ID | Sev | Hop | One-line |
|----|-----|-----|----------|
| **G-1** | 🔴 HIGH | genesis → proto | `GENESIS_READY` claims "GATE 2 now PASSES (real design system exists)" but Slice 1 only *prints* the scaffold checklist; if the human skips it, `/proto` hard-STOPs "NO DESIGN SYSTEM FOUND" |
| **B-2** | 🔴 HIGH | build: rplan→approved→qa | Every slice writes `*-plan.md` to project root; all readers pick "most recent" by mtime with no slice pinning → in a multi-slice build a later `/qa`/`/approved` can bind to the wrong slice's plan |
| **G-2** | 🟠 MED | genesis → pickup | Genesis hardcodes `E1` in the sentinel + handoff, but captures an id that may be `F1` → printed next-steps name a non-existent item |
| **G-3** | 🟠 MED | genesis (autonomy) | Genesis calls `/add` + `/roadmap init` in an "autonomous" phase but passes no `--type` flag → both sub-skills prompt interactively, stalling the run |
| **P-1** | 🟠 MED | pickup → prd → proto/build | PRD filename = `slugify(input.feature)`; pickup contradicts itself on whether it passes the bare **title** or a **rich intent string** → wrong slug breaks the `Child PRD:` link → proto/build id-resolution STOPs |
| **PT-1** | 🟠 MED | add → rplan (plan-track) | `/rplan` takes no id, never reads the roadmap → the I/B item's intent isn't carried in (user restates), and **no skill ever flips an I/B item past `Planned`** |
| **B-4** | 🟠 MED | build: approved→reviewer/security | If a slice ends uncommitted, `git diff BASE..HEAD` is empty → reviewer + security audit "review nothing" and can report clean → false green |
| **B-5** | 🟠 MED | build → Shipped | e2e-absent only *warns* (`⚠ NO E2E SUITE`), doesn't stop → `Status: Shipped` gets written with zero end-to-end coverage; the Shipped flip is prose-ordered, not a machine gate |
| **P-4** | 🟢 LOW | pickup recut | After a scope recut, the parent `E<n>` is stranded at `In-progress` forever (build ships the `F<n>` child; nothing flips the parent to a terminal state) |
| **B-1** | 🟢 LOW | build resume | State-manifest example records the plan at `tasks/…-slice1-plan.md` but rplan writes to project **root** → resume artifact-check fails → harmless redo |
| **B-3** | 🟢 LOW | rplan → approved (standalone) | `/approved` never re-checks the Blocking Set; only `/build` enforces it → a human can approve a non-empty-Blocking plan |
| **P-2** | 🟢 LOW | pickup/prd next-hop | pickup points at `proto E3` (id), prd points at `proto tasks/prd-…md` (path) — inconsistent guidance (both forms actually work, so no break) |
| **P-3** | 🟢 LOW | pickup → proto | PRD *document* Status can exit pickup still `Draft` (autonomous path has no human approve step); cosmetic — gates key off the lock marker, not doc Status |
| **B-6** | 🟢 LOW | rplan next-hop | `/rplan` recommends the human run `/rplan-review`, but it's `user-invocable: false` → can't be invoked as a slash command |

---

## Chain A — Greenfield (from scratch)

`/genesis "<idea>"` → `/pickup E1` → `/prd` ↔ `/prd-review` → `/proto E1` → `/build E1`

| Hop | Contract | Status |
|-----|----------|--------|
| **genesis → roadmap seed** | genesis runs `/roadmap init` then `/add` to register the MVP as `Planned`, captures id (`E1`/`F1`) | ⚠ **G-2, G-3** |
| **genesis → pickup** | prints `pickup E1` and sentinel `GENESIS_READY … (E1 = MVP)` | ⚠ **G-2** (hardcoded E1) |
| **genesis → proto (the load-bearing seam)** | genesis exists to make proto GATE 2 pass by producing a real design system | ⚠ **G-1** (Slice 1 only *prints* the scaffold; doesn't run it) |
| **pickup → prd → prd-review → green** | pickup seeds `/prd`, delegates the loop to `/prd-review` (owns the 3-round cap + escapes), waits on `PRD_REVIEW_GREEN` | ✅ holds (green signal + BLOCKED reason tags line up exactly) — ⚠ shared **P-1** |
| **proto → build** | proto writes the `<!-- prd-locked: … -->` marker; build greps it | ✅ **holds** (verified — proto:1440 / build:167 match) |
| **build → Shipped** | build executes slices, flips `E1` → `Shipped` | ⚠ **B-2, B-4, B-5** (shared with Chain B) |

**Greenfield crux (G-1).** genesis's own handoff block is internally contradictory: step 1 says *"Run the G4
scaffold checklist above (if not done)"* (`genesis:258` — concedes it may not have run) while step 3 asserts
*"proto E1 — GATE 2 now PASSES (real design system exists)"* (`genesis:260`). proto GATE 2 detects a design
system by grepping for real `components.json` / `components/ui/*` + token files (`proto:295–313`) — **not**
`design.md`. So on a Slice-1 genesis run where the human hasn't executed the printed checklist, only
`design.md` + `foundations.md` exist, and `/proto E1` hard-STOPs "NO DESIGN SYSTEM FOUND" (`proto:320–331`)
— the exact stop genesis exists to prevent. Confirmed independently by the genesis and proto readers.

---

## Chain B — Existing project

### PRD-track: `/add` → `/pickup` → `/prd` ↔ `/prd-review` → `/proto` → `/build`

| Hop | Contract | Status |
|-----|----------|--------|
| **add → roadmap** | `/add` categorizes, assigns `E/F<n>`, writes item `Planned`, leaves `Child PRD: —` | ✅ holds |
| **add → pickup** | prints `Next: /pickup <id>` | ✅ holds |
| **pickup → prd** | flips item `Planned→In-progress`, seeds `/prd`, writes `Child PRD: prd-<slug>.md` back to roadmap | ⚠ **P-1** (slug fragility) |
| **prd ↔ prd-review** | pickup delegates loop; green = `Verdict SHIP AND Readiness READY`; `PRD_REVIEW_GREEN` sentinel | ✅ **holds** (signal + reason tags match exactly) |
| **pickup → proto** | `phase:"proto-ready"`, human runs `/proto <id>` (the single approval gate) | ✅ holds — ⚠ **P-2/P-3** cosmetic |
| **proto → build** | proto resolves id via roadmap `Child PRD:` link → `tasks/prd-<slug>.md`; writes lock marker | ✅ **holds** (proto:48 / build:99 identical resolution) |
| **build (internals)** | per slice: `rplan → [rplan-review] → approved → qa → reviewer → [security]` | ⚠ **B-2, B-4, B-5** |
| **build → Shipped** | flips `<id>` → `Shipped` | ⚠ **B-5** (not bound to e2e) |

### Plan-track: `/add` → `/rplan` → `/approved` → `/qa`

| Hop | Contract | Status |
|-----|----------|--------|
| **add → rplan** | `/add` writes I/B item `Planned`, prints `Next: /rplan` | ⚠ **PT-1** (no seed; item intent not carried into rplan) |
| **rplan → approved** | rplan writes `[task]-plan.md` (root), emits "Blocking Set empty" | ✅ file handoff holds — ⚠ **B-3** (approved doesn't re-check Blocking) |
| **approved → qa** | shared plan file, `[task]-flow.md`, checkbox writes | ✅ holds (single-plan case) |
| **item lifecycle** | — | ⚠ **PT-1** (nothing flips I/B past `Planned` — no Shipped owner for plan-track) |

---

## Findings (detail + fix)

### 🔴 G-1 — Genesis asserts a proto precondition Slice 1 doesn't deliver
- **Evidence:** `genesis:258` ("Run the G4 scaffold checklist above (if not done)") vs `genesis:260`
  ("proto E1 — GATE 2 now PASSES (real design system exists)"); `genesis:41–42` (G4 is a *printed* checklist,
  auto-scaffold deferred to Slice 2); proto GATE 2 detection `proto:295–313`, STOP `proto:320–331`.
- **Impact:** the terminal sentinel `GENESIS_READY … roadmap seeded` prints regardless of whether the
  irreversible scaffold ran, so the human is told the chain is ready when `/proto` will stop.
- **Fix (messaging, cheap):** make step 3's line conditional — if the scaffold hasn't run, print
  `proto E1 — run the G4 checklist FIRST or GATE 2 will stop`. Better: gate the `GENESIS_READY` sentinel on a
  probe for real `components/ui/*` + token files (the same grep proto uses), and emit a distinct
  `GENESIS_SCAFFOLD_PENDING` state otherwise. (Root fix is Slice 2's auto-scaffold.)

### 🔴 B-2 — Multi-slice plan selection is mtime-based with no slice pinning
- **Evidence:** rplan writes `[task]-plan.md` in **project root** (`rplan:411`); `/qa` selects via
  `ls -t $(pwd)/*-plan.md | head -1` (`qa:16`); `/approved` + `/rplan-review` both read "most recent
  `*-plan.md` in project root"; `/approved` edits the plan in place on drift (`approved:99`).
- **Impact:** in a multi-slice `/build`, every slice drops a `*-plan.md` into the same root dir. A later
  in-place edit (or checkbox write) re-touches an earlier slice's plan, making it "most recent" — so a
  subsequent `/qa` or `/approved` can bind to the **wrong slice's plan**. Silent; produces green QA against
  the wrong criteria.
- **Fix:** pin the plan file per slice. `/build` should pass the exact plan path to `/approved` + `/qa`
  (they currently self-glob), or namespace by slug/slice (`prd-<slug>-slice<N>-plan.md`) and have the readers
  select by the active slug, not by mtime.

### 🟠 G-2 — Hardcoded `E1` vs captured `E1`/`F1`
- **Evidence:** `genesis:246` captures the id as "`E1`/`F1`" (because `/add` auto-categorizes Epic vs
  Feature); `genesis:255` + `genesis:259–261` hardcode `E1` in the sentinel and every handoff line.
- **Impact:** if `/add` categorizes the MVP as a **Feature**, the real id is `F1` and the printed
  `pickup E1 / proto E1 / build E1` name a non-existent item.
- **Fix (couples with G-3):** substitute the captured id into the handoff, **or** force `--epic` on the
  `/add` call so the MVP is always `E1` (also fixes G-3's prompt).

### 🟠 G-3 — Autonomous phase depends on sub-skills that prompt
- **Evidence:** `genesis:244–246` composes a rich intent "so `/add` takes its autonomous fallback (no
  prompts)" — but `/add`'s no-prompt fallback requires a `--<type>` flag with a complete shape
  (`add:81–83`); without it, `/add` Step 1 proposes a type and prints "Confirm?" (`add:68`). Separately
  `genesis:243` runs `/roadmap init`, which "asks once for the product name" (`roadmap:68`).
- **Impact:** two interactive prompts inside a phase genesis treats as autonomous → the run stalls waiting
  for input it never told the human to expect.
- **Fix:** pass `--epic` (or `--feature`) explicitly to `/add`, and pass the product name non-interactively
  to `/roadmap init` (or have genesis write the roadmap seed directly).

### 🟠 P-1 — PRD filename slug is single-sourced in theory, contradicted in practice
- **Evidence:** `/prd` saves `tasks/prd-{{input.feature | slugify}}.md` (`prd:394`). pickup asserts
  "passes the title as the feature, so … the slug always matches" (`pickup:102–104`) but two lines later says
  "compose a **rich intent string** from the item … passed as the feature intent" (`pickup:148–150`). pickup
  then records `Child PRD: prd-<slug>.md` using `slugify(title)` (`pickup:155–157`).
- **Impact:** if the rich intent string (not the bare title) is what reaches `input.feature`, the file lands
  at `prd-<rich-intent-slug>.md` while the roadmap link points at `prd-<title-slug>.md`. proto/build resolve
  the id **only** via that roadmap link with no filesystem fallback (`proto:48–50`), so a mismatch →
  `<id> has no PRD yet` STOP even though a PRD exists on disk.
- **Fix:** make pickup pass the bare **title** as `input.feature` and route Goal/JTBD/flow through the other
  `/prd` params (`audience`, `evidence`, …); state this unambiguously and delete the "rich intent string as
  feature" phrasing.

### 🟠 PT-1 — Plan-track item has no seed and no lifecycle
- **Evidence:** `/add` for I/B is "record + point only … does not run `/rplan`" (`add:168`), prints
  `Next: /rplan` (`add:141`). `/rplan` takes no id argument and never reads `tasks/roadmap.md` (no such read
  in the file); its only structured seed path is PRD-slice ingestion, explicitly N/A for standalone
  (`rplan:79`). No plan-track skill writes roadmap status.
- **Impact:** (1) the item's recorded Goal/Repro isn't carried into `/rplan` — the user must restate it;
  (2) I/B items are stuck at `Planned` permanently — `/build` (the only `Shipped` writer) is PRD-track only.
- **Fix:** let `/rplan` accept an optional `I<n>/B<n>` id, read the item block as its seed, flip it
  `Planned→In-progress`, and give the plan-track a `Shipped` writer (e.g. `/qa` green on a plan-track item, or
  `/wrap`, flips it).

### 🟠 B-4 — Empty committed diff → reviewer/security review nothing
- **Evidence:** `/reviewer` and build's security step review `git diff BASE..HEAD` (committed only,
  `reviewer:12–22`); build allows `commitPolicy:"none"` (`build:72`); `/approved` commits only when
  `Committable=Yes` (`approved:106`).
- **Impact:** a slice that ends with uncommitted work has `HEAD==BASE`, empty diff → both gates pass on an
  empty review → false green.
- **Fix:** in build's step 5/5.5, assert the diff is non-empty (or that a commit happened) before trusting an
  APPROVE / security-clean verdict; treat an empty diff on a code-bearing slice as a gate failure.

### 🟠 B-5 — Shipped flip isn't bound to e2e
- **Evidence:** e2e-absent path prints `⚠ NO E2E SUITE FOUND` and does **not** hard-stop (`build:444–445`);
  the `Status: Shipped` write lives in the Completion Output section guarded only by prose ordering
  (`build:478–488`).
- **Impact:** a PRD with only slice-level `/qa` passing (no end-to-end coverage) still flows to Completion
  Output and is marked `Shipped`.
- **Fix:** bind the Shipped write to the `PRD_BUILD_COMPLETE` sentinel / `wrap --heal` success, and make
  "no e2e suite on a multi-slice PRD" a blocking condition (or an explicit, logged waiver).

### 🟢 LOW (doc-drift / cosmetic)
- **P-4** — recut strands the parent `E<n>` at `In-progress`; nothing flips it to terminal (`pickup:281–282,
  350–351`). Give the recut a parent-terminal state (or a "superseded" annotation the roadmap view renders).
- **B-1** — build state-manifest example path `tasks/…-slice1-plan.md` (`build:64`) ≠ rplan's actual root
  write (`rplan:411`); resume artifact-check fails → harmless redo (build degrades gracefully, `build:74–76`).
  Fix the example path (or move rplan's writes to `tasks/` — but that then breaks approved/qa globbing, so
  fix the example).
- **B-3** — `/approved` presumes human approval and only *warns* on a missing Evidence Ledger
  (`approved:42–45`); it never re-checks the Blocking Set. Only `/build` enforces "Blocking Set empty"
  (`build:28`). Add a Blocking-empty check to `/approved` for the standalone plan-track path.
- **P-2** — pickup's next-hop uses the item id (`proto E3`, `pickup:26`); prd uses the file path
  (`proto tasks/prd-…md`, `prd:542`). Both proto and build accept both forms, so no break — align the guidance.
- **P-3** — the PRD *document* Status can still read `Draft` at proto handoff (autonomous pickup has no human
  approve step; `/prd` advances `Draft→In Review` only after human approval, `prd:539`). Cosmetic — gates key
  off the lock marker. Have proto's lock step normalize the doc Status too.
- **B-6** — `/rplan` recommends the human run `/rplan-review` (`rplan:427,446`), which is
  `user-invocable: false` (`rplan-review:4`). Reword to "spawned automatically by `/build`" or drop the
  human-facing recommendation.
- **Lock anchoring** — build greps `^<!-- prd-locked:` at column 0; if any PRD template ever indents the top
  comment block, the lock is missed. Keep the marker unindented (currently it is).

---

## What holds (verified-solid seams)

- **PRD lock (proto → build/rplan).** proto Step 8.5 writes `<!-- prd-locked: … -->` on its own line
  (`proto:1440`) **and** `Status: Locked`; build greps exactly `^<!-- prd-locked:` (`build:167`); rplan
  checks the same marker (`rplan:75`). The "running /proto is the approval" mechanism is a concrete,
  durable file marker — not ambiguous. PARTIAL (`--slice=N`) runs correctly refuse to lock (`proto:1436`).
- **id → PRD-file resolution (proto & build identical).** Both resolve `E<n>/F<n>` via roadmap
  `### <id>` → `Child PRD:` link → `tasks/prd-<slug>.md`, with identical STOP text when the link is `—`
  (`proto:48–50` ≡ `build:99–101`).
- **PRD-review green signal (prd-review → pickup).** `PRD_REVIEW_GREEN` = `SHIP · READY`; pickup waits on
  exactly that, and the three BLOCKED reason tags (`DISCOVERY-FIRST | readiness: blocker | non-convergence`)
  map 1:1 to pickup's branches. prd-review owns the loop; pickup reuses it with no double-nesting.
- **Single-slice plan handoff (rplan → rplan-review → approved → qa).** All four agree on `*-plan.md` in
  project root, plus derived companions `${PLAN%-plan.md}-flow.md`. The break is only the *multi-slice*
  selection ambiguity (B-2), not the file contract itself.
- **Readiness token (rplan → build).** rplan emits "Blocking Set empty"; build auto-approves exactly that
  signal (`build:28`). (The gap is only that *standalone* `/approved` doesn't also check it — B-3.)

---

## Recommended fix order (roadmap-ready)

1. **G-1** (greenfield crux) — make `GENESIS_READY` honest about scaffold state. *Improvement.*
2. **B-2** (multi-slice plan binding) — pin the plan path per slice in `/build`. *Bug.*
3. **G-2 + G-3** (one fix) — genesis passes `--epic` to `/add` + product name to `/roadmap init`. *Bug.*
4. **P-1** — pickup passes bare title as `input.feature`; delete the "rich intent as feature" phrasing. *Bug.*
5. **PT-1** — `/rplan` accepts an `I/B` id as seed + a plan-track `Shipped` writer. *Improvement.*
6. **B-4 / B-5** — bind reviewer/security to a non-empty diff and Shipped to e2e/`PRD_BUILD_COMPLETE`. *Improvement.*
7. LOW items — batch as a doc-drift cleanup pass.
