---
name: pickup
description: Pull a PRD-track roadmap item (Epic E<n> or Feature F<n>) into active development — the disciplined entry point for feature work. `/pickup <id>` reads the item from tasks/roadmap.md, seeds /saki-builder:prd from it (PRD stamped Epic: <id>), then loops /saki-builder:prd ↔ /saki-builder:prd-review until the PRD is green (Verdict SHIP AND Readiness READY) and STOPS — ready for /saki-builder:proto. Flips the item Planned→In-progress. If review dead-ends on a **scope** blocker (non-convergence / over-appetite), acts as a Senior PM — recuts the initiative into an MVP + trigger-gated follow-on phases, registers each on the roadmap via /saki-builder:add, and drives the MVP PRD to green (follow-on phases stay Planned for a later pickup); escapes to Blocked only when the review can't reach a shippable PRD for a non-scope reason (discovery/premise). Running /saki-builder:proto <id> afterwards designs the UI/UX and LOCKS the PRD (freezes requirements — the gate before build); there is no separate approve step. Plan-track items (Improvement/Bug) don't come here — they go to /saki-builder:rplan. Usage — /saki-builder:pickup <E<n>|F<n>>.
---

# Pick up a PRD-track item → write & review its PRD to green (ready for proto)

`/saki-builder:pickup <id>` is the **only** way to start PRD-track work — the structural gate of the
disciplined workflow. It requires a **PRD-track item** (Epic `E<n>` or Feature `F<n>`) that already exists
on `tasks/roadmap.md`; there is no cold-intent path. Epics and Features are handled **identically** here —
"the item" below means either. (Plan-track items — Improvement `I<n>`, Bug `B<n>` — never come here; run
`/saki-builder:rplan` on them instead.) It runs the **front half** of the product flow: seed
`/saki-builder:prd` from the item, then loop
`/saki-builder:prd-review` until the PRD is **green** (`Verdict SHIP` AND `Readiness READY`), and stop there —
"ready to proto". You do **not** re-implement `/saki-builder:prd` or `/saki-builder:prd-review`; you **invoke** them
(Skill tool) and drive the loop.

```
/saki-builder:pickup E3
  → resolve E3 from tasks/roadmap.md   (flip Planned → In-progress)
  → /saki-builder:prd   (seeded by the item; PRD stamped `Item: E3`)
  → loop /saki-builder:prd-review until SHIP · READY   (≤3 rounds)
       ↳ scope blocker (non-convergence / over-appetite) → Phase 2b: Senior-PM recut
         → split into MVP + trigger-gated phases → /saki-builder:add each → drive the MVP to green
       ↳ non-scope blocker (discovery / unproven premise) → escape to Blocked
  → STOP — MVP PRD green & ready. Run /saki-builder:proto E3 (it designs the UI/UX and LOCKS the PRD).
```

The single human gate is at proto — **running `/saki-builder:proto E<n>` designs the UI/UX and locks the PRD**
(the explicit freeze before build); `/saki-builder:pickup` writes no lock flag and never advances into proto itself.

---

## Usage

- `/saki-builder:pickup <id>` — start (or resume) a PRD-track item `E<n>` / `F<n>`. Filler words are fine (`/saki-builder:pickup start E3`).
- No item id → **structural gate**: print
  `no item id — add one first with /saki-builder:add, then /saki-builder:pickup <E<n>|F<n>>` and stop. Never invent a feature.
- A Plan-track id (`I<n>` / `B<n>`) → **wrong track**: print
  `<id> is a Plan-track item (Improvement/Bug) — run /saki-builder:rplan, not /saki-builder:pickup` and stop.

---

## GATE 0 — Resume check (deterministic)

On every invocation, parse the item id (`E<n>` / `F<n>`), then read `tasks/.pickup-<slug>-state.json` if it
exists (the `<slug>` is recorded in the item's `Child PRD:` link, or in the state file). **The state file is
named by the PARENT slug for the whole run — including through a recut — and is never renamed**, so this
lookup always resolves. Resolve resume by **explicit precedence** (evaluate top-down; `recut.stage` is the
single cursor — a run with **no `recut` block is NEVER treated as a recut**):

| Precedence | Condition | Action |
|------------|-----------|--------|
| 1 | top-level `phase` ∈ {`proto-ready`, `blocked`} | Terminal — re-print the ready handoff (Phase 3) or the BLOCKED report; do nothing else. |
| 2 | a `recut` block with `recut.stage` == `phasing` | A recut was entered but no phase registered yet — re-run **Phase 2b Steps 1–2** (senior-pm phasing + verify). Idempotent (no roadmap writes yet). |
| 3 | a `recut` block with `recut.stage` == `registering` | The `/add` loop was interrupted mid-registration — **continue Phase 2b Step 3**, using `recut.phases[]` (and the roadmap) to skip already-registered phases (dedup). Never restart the loop. |
| 4 | a `recut` block with `recut.stage` == `driving` | The MVP is being driven. **Resume the CHILD from the PERSISTED state seed** — `state.slug` / `prd` / `title` already point at the MVP; drive its Phase 1/2 at the recorded top-level `phase`. **Do NOT re-resolve the invoked parent id via GATE 1, do NOT re-init `state.slug`.** The once-guard holds: `state["slug"]` == `recut.active_slug` → never recut again. |
| 5 | **no `recut` block**, `phase` == `prd` | Normal run — re-run Phase 1 from where the PRD was incomplete (re-resolving the invoked id is correct — it IS the run). |
| 6 | **no `recut` block**, `phase` == `review` | Normal run — resume Phase 2 (re-invoke autonomous `/saki-builder:prd-review`, read its terminal sentinel). |
| 7 | (no state file) | Fresh start → Phase 1. |
| — | anything else (unknown/empty top-level `phase` with a state file, or a `recut` block with an absent/unknown `stage`) | **Fall through to the best-effort catch-all below** — treat as a normal fresh run; never hard-fail. |

**Best-effort + safe:** a missing/partial/unrecognized state file degrades to a normal fresh run — never
hard-fail on it. Always write the state file before ending a turn so resume lands on the right phase.

---

## GATE 0.5 — Greenfield guard (no product foundations yet → genesis first)

`/saki-builder:pickup` seeds `/saki-builder:prd`, which assumes a **stack, design system, and schema that
already exist** (prd grounds §16 against real code; proto's GATE 2 hard-STOPs without a design system). On a
brand-new repo none of that exists, so picking up here would seed a **stack-less PRD**. Detect that first
with **`test` builtins** — not `ls`/`find` output — so the check is both glob-safe (no `*.md` glob that
aborts under zsh `nomatch`) AND robust to RTK rewriting `ls`/`find` output into a summary (which would make
an empty repo read as non-empty):

```bash
if [ ! -e foundations.md ] && [ ! -e package.json ] && [ ! -e go.mod ] \
   && [ ! -e pyproject.toml ] && [ ! -e Cargo.toml ] \
   && [ ! -d src ] && [ ! -d app ] && [ ! -d components ]; then
  echo GREENFIELD_NO_FOUNDATIONS      # no foundations marker, no stack, no code
else
  echo FOUNDATIONS_PRESENT
fi
```

- **`GREENFIELD_NO_FOUNDATIONS`** → the product has **no foundations yet** → STOP:
  `This repo has no product foundations yet — /saki-builder:pickup would seed a PRD assuming a stack, design system, and schema that don't exist. Run /saki-builder:genesis "<product idea>" first (it sets the MVP goal + foundations and seeds the roadmap), then /saki-builder:pickup E1.`
  Do not proceed into a stack-less PRD.
- **`FOUNDATIONS_PRESENT`** (a `foundations.md`, stack, or code exists) → foundations are in place (genesis
  ran, or this is an existing product that predates genesis) → proceed to GATE 1 normally.

---

## GATE 1 — Resolve the item (hard stop if missing / wrong track)

Read `tasks/roadmap.md`. Find the `### <id> · <title>` block (`<id>` = `E<n>` or `F<n>`). If absent → print
`<id> not found on the roadmap. /saki-builder:roadmap to see items, /saki-builder:add to add one.` and stop.

Check the block's `**Track:**` (or infer from the prefix). If it is **Plan** (Improvement/Bug) → print
`<id> is a Plan-track item — run /saki-builder:rplan, not /saki-builder:pickup` and stop. Only PRD-track
items proceed.

Extract the item's fields: **title, Goal, Target user & Job (JTBD), User flow, Success signal**. These
become the **item seed** handed to `/saki-builder:prd`.

Derive `<slug>` the way `/saki-builder:prd` does: `slugify(title)`. (Single-source the slug in `/saki-builder:prd`'s
`{{input.feature | slugify}}` — `/saki-builder:pickup` passes the title as the feature, so the PRD lands at
`tasks/prd-<slug>.md` and the slug always matches.)

---

## State + status file (single source of truth)

Maintain `tasks/.pickup-<slug>-state.json`. **Update it after every phase transition** — this is what the
`pickup-completion-gate.sh` Stop hook reads to keep the loop alive across turns. Get timestamps with
`date +%s`. Schema:

```json
{
  "epic": "E3",
  "slug": "instant-seller-payout",
  "title": "Instant seller payout",
  "prd": "tasks/prd-instant-seller-payout.md",
  "session": "<session_id if known, else omit>",
  "phase": "prd|review|proto-ready|blocked",
  "started_at": 1730000000,
  "prd_written": false,
  "review": { "rounds": 0, "verdict": "", "readiness": "", "phase1": "", "blockers_fixed": 0 },
  "recut": {
    "parent": "E3",
    "stage": "phasing|registering|driving",
    "phases": [ {"id":"F7","slug":"<child-slug>","role":"mvp"}, {"id":"F8","slug":"<child-slug>","role":"deferred"} ],
    "active": "F7", "active_slug": "<mvp-slug>",
    "registered": 3, "pm_rounds": 0
  }
}
```

`phase` (top-level) is the cursor the Stop gate keys off:
- `prd` / `review` → front-half work in progress → the Stop gate **keeps you running**.
- `proto-ready` → PRD is green (`SHIP · READY`), waiting for the human to run `/saki-builder:proto` → the Stop
  gate **releases** (the human's turn). This is the terminal success state for `/saki-builder:pickup`.
- `blocked` → a hard stop you reported → the Stop gate **releases**.

`recut` is **optional** and present only after a Phase-2b scope recut. **Its presence ⇔ "this run is a
recut"; its absence ⇔ never a recut** (the guard that stops a normal `/pickup` being read as a recut).
There is **no** `phase:"recut"` value — a recut runs *while top-level `phase` stays `review` → `prd` →
`review`* (so the Stop gate keeps the run alive with no hook change); **`recut.stage` is the single resume
cursor** (`phasing` → `registering` → `driving`), a sub-field the Stop gate never gates block/release on.
The gate DOES fold `recut.stage` + capped `len(recut.phases[])` into its progress score so the multi-turn
recut can't starve it. `recut.phases[]` records each registered phase as `{id, slug, role}` (the MVP is
pinned by `role:"mvp"`, never id-order); `active`/`active_slug` name the MVP being driven; `registered` is
the confirmed count. After the re-point (stage→`driving`) the state file's `slug` / `prd` / `title` point at
the **MVP child** (the run continues on it), but **the FILE keeps the parent's name and is NEVER renamed** —
fresh MVP budget comes from deleting the `.gate.json` sidecar in place (Phase 2b Step 5), so GATE 0's
lookup-by-parent-id always resolves.

---

## Phase 1 — `/saki-builder:prd`  (seeded by the item)

1. Init the state file (`phase:"prd"`, stamp `started_at`, `epic`, `slug`, `title`, `prd`). **On a RESUME
   (the state file already exists with a `slug`), PRESERVE the existing `slug` / `prd` / `title` — stamp them
   only on a FRESH start.** (A `driving`-stage recut resume re-enters here on the MVP child; re-stamping would
   overwrite `state.slug` with the parent slug and break the once-guard — see GATE 0 precedence 4.)
2. **Flip the item `Planned → In-progress`** in `tasks/roadmap.md` (update its `**Status:**` and `**Updated:**`).
3. Invoke the `prd` skill. **Pass the item _title_ verbatim as the `feature` input** — nothing else folded
   in. `feature` is the filename driver (`/saki-builder:prd` saves `tasks/prd-<slugify(feature)>.md`), so the
   bare title is what makes the PRD land at exactly `tasks/prd-<slug>.md` and match the `**Child PRD:**` link
   you record in step 5 (see the slug note above). Supply the rest of the **item seed** as
   `/saki-builder:prd`'s grounding context — **NOT concatenated into `feature`** — so its Step 0/0.5/1 consume
   it autonomously (no human gate here; the shape phase takes its autonomous fallback under
   `/saki-builder:pickup`). The seed grounds the shape:
   - item **Goal** → the problem / desired outcome
   - item **Target user & Job** → the JTBD (§3) (also the `audience`)
   - item **User flow** → the recommended solution shape
   - item **Success signal** → an outcome/metric seed (§5) and appetite hint
4. When `/saki-builder:prd` finishes it saves `tasks/prd-<slug>.md`. **Confirm the header carries `Item: <id>`**
   (pass the item id so `/saki-builder:prd` stamps it; if it wrote `—`, edit the header to `**Item:** <id>`).
5. Record `**Child PRD:** prd-<slug>.md` under the `### <id>` block in `tasks/roadmap.md`.
6. Set `phase:"review"`, `prd_written:true`. Advance the **PRD doc header** `**Status:** Draft → In Review`
   — the autonomous review is starting, and `/saki-builder:prd`'s manual `Draft → In Review` bump doesn't
   fire under `/saki-builder:pickup`, so set it here (otherwise the doc reads a stale `Draft` right up to the
   proto lock). `/saki-builder:proto` later overwrites it to `Locked`.

---

## Phase 2 — `/saki-builder:prd-review`  (delegate the loop-to-green)

Set `phase:"review"`. Invoke the `prd-review` skill on the PRD **WITHOUT `--review-only`** — its default
**autonomous** mode drives the loop-to-green itself (review → apply the prescribed fixes to the PRD →
re-review, with a hard 3-round cap + a BLOCKED escape). You no longer hand-roll that loop; `prd-review`
**owns** it now, and `/saki-builder:pickup` **reuses** it (one loop, one place — never a second copy here).

Read `prd-review`'s **terminal** result — one of the sentinels it prints on its own line:

```
PRD_REVIEW_GREEN:   <slug> — SHIP · READY · R rounds · B blockers fixed
PRD_REVIEW_BLOCKED: <slug> — <DISCOVERY-FIRST | readiness: blocker | non-convergence>: <reason>
```

The `prd-review` state file `tasks/.prd-review-<slug>-state.json` (`phase: green | blocked`) is the robust
fallback. **Green = `Verdict SHIP` AND `Readiness READY`** — both axes; a `SHIP · NOT READY` PRD is not
buildable-now and `prd-review` returns `blocked` on that structural readiness gap, not green.

- **`PRD_REVIEW_GREEN`** → record `review.verdict:"SHIP"`, `review.readiness:"READY"`, copy `rounds` /
  `blockers_fixed` from the sentinel (or the prd-review state file), set `phase:"proto-ready"`, and go to
  **Phase 3**.
- **`PRD_REVIEW_BLOCKED`** → **branch on the reason** (the sentinel's `<DISCOVERY-FIRST | readiness:
  blocker | non-convergence>` tag):
  - **`non-convergence`** (blocker volume didn't fall across rounds, or the 3-round cap hit still-not-green)
    → a **scope** blocker → go to **Phase 2b (Senior-PM recut)**. Do NOT flip to Blocked yet. **Once-guard:**
    if the state file already carries a `recut` block whose `active` == the current `slug` (you are *already*
    driving a recut child), do NOT re-enter Phase 2b — a child never recuts; fall through to plain-blocked.
  - **`readiness: blocker`** → ambiguous → **Phase 2b Step 0** classifies it (decomposable scope → recut;
    bet/discovery → fall through to the plain-blocked path below).
  - **`DISCOVERY-FIRST`**, or a bet/discovery readiness blocker → **plain blocked** (today's behaviour):
    record the reason, set `phase:"blocked"`, **flip the item `In-progress → Blocked`** in
    `tasks/roadmap.md`, emit `PICKUP_BLOCKED: <slug> — <reason>` on its own line, and end. Do NOT loop
    forever, do NOT fabricate grounding, **never recut past an unproven premise** — `prd-review` already
    exhausted the fixable paths.

Key design note (option 3 — one shared loop): the loop-to-green lives in `/saki-builder:prd-review`'s
autonomous mode; `/saki-builder:pickup` **reuses** it and keeps no copy. The fix→re-review loop, the 3-round
cap, and the non-convergence / DISCOVERY-FIRST / structural-`NOT READY` escapes all run **inside**
`prd-review`. `/saki-builder:pickup` only invokes it (without `--review-only`) and does the item-specific
terminal handling: proto-ready handoff, a **Phase-2b Senior-PM recut** on a scope blocker, or flip the item
to Blocked on a non-scope blocker. No nesting — the loop runs in exactly one place, so there is no
double-loop when `/saki-builder:pickup` runs.

---

## Phase 2b — Scope recut (Senior PM)  (only on a SCOPE blocker; runs while `phase` stays `review`/`prd`)

Entered from Phase 2 when the review dead-ends because the initiative is **too big for its appetite**
(a scope problem), not because its premise is unproven. Acting as a Senior PM, you recut it into an MVP
plus trigger-gated follow-on phases, register each on the roadmap, and drive **only the MVP** to green.

**Recut at most once per pickup run — detected via the state file (the once-guard).** If the current run is
already a recut child (`recut.stage == "driving"` AND the loaded `state["slug"]` == `recut.active_slug`), a
scope blocker does **not** re-enter this phase — route it to the plain-blocked path in Phase 2 (flip the
child Blocked, emit `PICKUP_BLOCKED`). A child MVP that still won't converge is a genuine `blocked` (a human
decides). This bounds decomposition — no recursive recut, no infinite decomposition. **Compare the LOADED
`state["slug"]`, never an id-derived slug** (on a resume the id-derived slug is the parent's, which would
make the guard miss and re-recut).

**Do NOT introduce a `phase:"recut"` value** — the Stop gate (`pickup-completion-gate.sh`) keeps a run
alive only while top-level `phase ∈ {prd, review}` and releases on any unknown phase. The whole recut runs
while `phase` stays `review` → (Step 5) `prd`; `recut.stage` is a sub-field the gate never gates on.

**The circuit breaker is fed DETERMINISTICALLY by the gate** — it folds `recut.stage` (ordinal) + capped
`len(recut.phases[])` into its progress score, so each stage transition (`phasing`→`registering`→`driving`)
and each `/add` (which appends to `recut.phases[]`) raises the score and keeps the multi-turn recut alive
with no manual counter. You do **not** hand-bump `review.rounds` here anymore. Just write the correct
`recut.stage` + append to `recut.phases[]` at each transition (Steps 1/3/5).

### Step 0 — Confirm it is a scope blocker (classify `readiness: blocker`)
- `non-convergence` → scope blocker → proceed.
- `readiness: blocker` → pass the blocker to the senior-pm (Step 1) and ask it to classify **first**: a
  **decomposable scope/sequencing** blocker (an in-initiative dependency that can be sequenced as its own
  earlier phase, or a slice that can be deferred) → proceed with the recut; a **bet/discovery** blocker
  (unaccepted bet, unresolved DISCOVERY-RISK) → **abort the recut**, return to the plain-blocked path in
  Phase 2 (record the reason, flip the item Blocked, emit `PICKUP_BLOCKED`).
- `DISCOVERY-FIRST` never reaches here.

### Step 1 — Ask the Senior PM to phase it
**First write `recut = {parent:<id>, stage:"phasing", phases:[], registered:0}` to the state file** (this
marks the run as a recut so GATE 0 resumes it correctly, and starts crediting the gate). Then spawn the
`senior-pm` agent (Agent tool) with: the **item seed**, the non-converged PRD (`tasks/prd-<slug>.md`), and
the **review ledger** (`tasks/prd-<slug>-review.md`). Ask for its **`MVP-Phasing Decision`** artifact
(`config/agents/senior-pm.md`), and **embed the exact output template verbatim in the spawn prompt**
(belt-and-suspenders, so autonomy holds even if the agent file drifts) — instruct it to **decide, not ask**,
and to return the shape **inline**. The decision is an **MVP phasing**:
- **Phase 1 — MVP:** the thinnest vertical slice that delivers the PRD's **primary §3 job + primary §5
  outcome**, sized **within the PRD's §6 appetite**, and a **walking skeleton** (ships user-visible value,
  not plumbing).
- **Phases 2…N — deferred:** each names the **§8 slices / §5 outcomes it carries** (cited from the PRD),
  an **objective trigger** — a production signal or query that fires when the deferred scope is actually
  needed (e.g. "ships when the first dup-row is logged" / "when cohort resubmit-rate <50%"), never a
  calendar date — and one line on why it's deferred.
- **A complete PRD-track shape per phase** (MVP and each deferred) — **title · Goal (outcome) · Target
  user & Job (JTBD) · User flow · Success signal** — because this is exactly the intake `/saki-builder:add`
  consumes in Step 3. For a deferred phase the **Success signal encodes its objective trigger**. Without a
  full shape per phase, Step 3 would have to invent the missing fields or `/add` would prompt — breaking
  autonomy. (The MVP's JTBD is the parent's primary job; a deferred phase's is the narrower sub-job it serves.)
- The **cut rationale** + which review blockers each phase clears.
- **Hard constraint (grounding):** every phase's scope must trace to **slices/outcomes already in the
  PRD**. The senior-pm may re-sequence and defer; it may **not invent new scope**.

### Step 2 — Verify the phasing (never trust a subagent unread — global rule 4)
Read the senior-pm output against the actual PRD:
- each phase's cited slices/outcomes **exist** in `tasks/prd-<slug>.md`;
- the MVP is genuinely a **walking skeleton within appetite** (not the full build re-labelled);
- each deferred phase carries an **objective trigger**.
If it invented scope, or the MVP still exceeds appetite → **re-prompt the senior-pm once, CORRECTIVELY** —
re-invoke it with the exact 5-field-per-phase template AND the **specific verification defect inline** (e.g.
"Phase 2 cites §8.4 which is not in the PRD" / "the MVP still carries 6 slices, over the §6 appetite of 3"),
not a bare "try again" (bump `recut.pm_rounds`). If it still fails → abandon the recut, fall through to the
plain-blocked path (record the reason).

### Step 3 — Register each phase via `/saki-builder:add`
**Set `recut.stage = "registering"`** before the first `/add` (marks the loop for GATE 0 resume + credits the
gate). Register the phases **one `/add` per turn, never in parallel** (a MUST, not prose) — each
`/saki-builder:add` scans `tasks/roadmap.md` for the next free `F<n>`, so a parallel batch would collide on
the id counter; **read back the assigned `F<n>` before the next**. **Cap the fan-out at ≤ 5 phases** (a
runaway/injected phasing can't spam the roadmap). Invoke the `add` skill as
`/saki-builder:add --feature --autonomous "<rich intent>"` — the **`--autonomous` flag** is the deterministic
no-prompt path (`config/skills/add/SKILL.md`). **Idempotent (dedup):** before each `/add`, skip a phase
already recorded in `recut.phases[]` OR already present on the roadmap; append each registered phase to
`recut.phases[]` as `{id, slug, role}` (`role:"mvp"` for the MVP, `role:"deferred"` otherwise) and bump
`recut.registered`. Compose the intent from the phase's **full five-field shape** (Step 1) — title · Goal ·
Target user & Job · User flow · Success signal; prefix each title `<parent-id> · Phase k (<MVP | trigger: …>):
<title>`; for a deferred phase carry its trigger in the Goal / Success-signal.

### Step 4 — Record the phase chain
Under the **parent** `### <id>` block in `tasks/roadmap.md`, add
`**Phase chain:** F7 (MVP) → F8 [trigger: …] → F9 [trigger: …]` **and** a machine-readable
`**Superseded by:** F7, F8, F9` line (the phase-chain ids). Keep the parent **`In-progress`** and
annotate it `Recut into phase chain — MVP <mvp-id> active` (there is no `Recut` status; do not invent
one). The deferred children stay `Planned`. The parent's `Child PRD:` (the non-converged PRD) is now
**superseded by the `Phase chain:`** — leave that PRD as a historical artifact; each child gets its own
fresh PRD when picked up. Do not re-point or delete it. The parent is **not stranded**: when the last
phase-chain child ships, `/saki-builder:build` flips the parent to `Shipped` (see build's Completion
Output); the roadmap view renders it `recut → superseded` until then.

### Step 5 — Re-point to the MVP, delete the sidecar for a fresh budget (the rest stay Planned)
Re-point the run to the **MVP child**: set `recut.stage = "driving"`, `recut.active = <mvp F-id>`,
`recut.active_slug = <mvp-slug>`; update the state's `slug` / `prd` / `title` FIELDS to the MVP child; set
`phase:"prd"`. **Do NOT rename the state file — it keeps the parent's name so GATE 0's lookup-by-parent-id
always resolves.** Instead, **give the MVP sub-run a fresh breaker budget by deleting the sidecar in place:**
`rm -f tasks/.pickup-<parent-slug>-state.json.gate.json` (idempotent — a missing sidecar is fine). Then
**re-enter Phase 1** (`/saki-builder:prd` seeded by the MVP item) → Phase 2 (`/saki-builder:prd-review` to
green). (The MVP's own review rounds live in its own `tasks/.prd-review-<mvp-slug>-state.json`, which the
gate now folds via `delegated_rounds` since `state.slug` = mvp-slug.) Because the MVP is appetite-sized it
converges; stop at `proto-ready` **for the MVP** as normal (Phase 3).
The deferred phases stay `Planned` with their triggers — a later `/saki-builder:pickup F8` picks up phase 2
when its trigger fires. `/pickup` does **not** drive them here.

Before the MVP's Phase-3 `PICKUP_READY`, emit on its own line:
```
PICKUP_RECUT: <parent-id> → <mvp-id>(MVP) + <deferred ids> · phases registered · driving MVP to green
```

---

## Phase 3 — Ready for proto (terminal success — NO lock flag written here)

The PRD is green. `/saki-builder:pickup` stops here. It writes **no** lock flag — running `/saki-builder:proto E<n>`
designs the UI/UX and **locks** the PRD (`Status: Locked` + `<!-- prd-locked -->`, freezing requirements), the
single human gate before build. The item stays `In-progress`.

Ensure `phase:"proto-ready"` and the state file is written, then print:

```
PICKUP_READY: <slug> — review SHIP · READY · R rounds · B blockers fixed

✅ PRD green & ready for proto: tasks/prd-<slug>.md   (Item: <id>)
   Review record: tasks/prd-<slug>-review.md
   Run /saki-builder:proto <id> when ready — it designs the UI/UX and LOCKS the PRD (freezes requirements).
   (then /saki-builder:build <id> to ship it — build refuses an unlocked PRD)
```

`PICKUP_READY` (own line) is the terminal success sentinel. The `pickup-completion-gate.sh` Stop hook
ALLOWS the stop at `phase:"proto-ready"` — ending the turn here is correct and expected.

---

## Survival & rules

- **Run the loop to green.** The front half is kept alive by `pickup-completion-gate.sh` (it blocks an early
  stop while `phase` ∈ {prd, review}). It releases the moment `phase` becomes `proto-ready` or `blocked`.
- **The gate is structural.** No item id → no run. There is no cold-intent feature path — that is the whole
  point of the disciplined workflow.
- **One human gate, at proto.** `/saki-builder:pickup` never advances into proto; running `/saki-builder:proto E<n>`
  designs the UI/UX and **locks** the PRD (the freeze before build). Never auto-run `/saki-builder:proto` from here.
- **Never fabricate grounding, never infinite-loop.** The stops are: green (`proto-ready`), a **scope**
  block (`non-convergence`, or a decomposable `readiness` blocker) → **Phase 2b recut** (then the MVP
  loops to green), or a non-scope block (`DISCOVERY-FIRST` / unaccepted bet / unresolved DISCOVERY-RISK)
  → `blocked`.
- **Recut only on a scope blocker, and only once.** A scope block routes to Phase 2b (Senior-PM recut);
  `DISCOVERY-FIRST` and bet/discovery readiness blockers **never** recut — you cannot phase past an
  unproven premise. Recut at most once per run — a child MVP that still won't converge is a genuine
  `blocked`.
- **The recut re-sequences, never invents.** Verify every phase's scope traces to real PRD slices/outcomes
  before acting (global rule 4); deferred phases carry **objective triggers** (a prod signal/query, not a
  date); register them via `/saki-builder:add --feature` (non-interactive, full shape) and drive **only the
  MVP** to green — follow-on phases stay `Planned` for a later `/saki-builder:pickup`.
- **Single source of truth for behaviour.** Invoke `prd` / `prd-review`; do not re-implement them. The item
  is the source of intent; the PRD is the source of scope. The **loop-to-green lives in `prd-review`'s
  autonomous mode** — `/saki-builder:pickup` reuses it (invoke without `--review-only`), never a second copy.
- **Always persist state before ending a turn** so any resume (a context clear, or the Stop gate re-driving
  you) lands on the right phase.
- **Status honesty.** Flip the item `In-progress` on start and `Blocked` on escape; `/saki-builder:build` owns
  the `Shipped` flip. Never mark an item `Shipped` from here.
