---
name: pickup
description: Pull a PRD-track roadmap item (Epic E<n> or Feature F<n>) into active development — the disciplined entry point for feature work. `/pickup <id>` reads the item from tasks/roadmap.md, seeds /saki-builder:prd from it (PRD stamped Epic: <id>), then loops /saki-builder:prd ↔ /saki-builder:prd-review until the PRD is green (Verdict SHIP AND Readiness READY) and STOPS — ready for /saki-builder:proto. Flips the item Planned→In-progress; escapes to Blocked if the review can't reach a shippable PRD. Running /saki-builder:proto <id> afterwards designs the UI/UX and LOCKS the PRD (freezes requirements — the gate before build); there is no separate approve step. Plan-track items (Improvement/Bug) don't come here — they go to /saki-builder:rplan. Usage — /saki-builder:pickup <E<n>|F<n>>.
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
  → loop /saki-builder:prd-review until SHIP · READY   (≤3 rounds; escape to Blocked if it can't)
  → STOP — PRD green & ready. Run /saki-builder:proto E3 (it designs the UI/UX and LOCKS the PRD).
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
exists (the `<slug>` is recorded in the item's `Child PRD:` link, or in the state file). Branch on `phase`:

| `phase` on entry | Action |
|------------------|--------|
| (no state file) | Fresh start → Phase 1. |
| `prd` | Re-run Phase 1 from the point the PRD was incomplete (the PRD file may be partial). |
| `review` | Resume Phase 2 — re-invoke autonomous `/saki-builder:prd-review` (it owns the loop-to-green) and read its terminal sentinel. |
| `proto-ready` | Already green. Re-print the ready handoff (Phase 3); do nothing else. |
| `blocked` | Re-print the BLOCKED report; a human decides. Do not silently retry. |

**Best-effort + safe:** a missing/partial state file degrades to a normal fresh run — never hard-fail on it.
Always write the state file before ending a turn so resume lands on the right phase.

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
  "review": { "rounds": 0, "verdict": "", "readiness": "", "phase1": "", "blockers_fixed": 0 }
}
```

`phase` is the cursor the Stop gate keys off:
- `prd` / `review` → front-half work in progress → the Stop gate **keeps you running**.
- `proto-ready` → PRD is green (`SHIP · READY`), waiting for the human to run `/saki-builder:proto` → the Stop
  gate **releases** (the human's turn). This is the terminal success state for `/saki-builder:pickup`.
- `blocked` → a hard stop you reported → the Stop gate **releases**.

---

## Phase 1 — `/saki-builder:prd`  (seeded by the epic)

1. Init the state file (`phase:"prd"`, stamp `started_at`, `epic`, `slug`, `title`, `prd`).
2. **Flip the epic `Planned → In-progress`** in `tasks/roadmap.md` (update its `**Status:**` and `**Updated:**`).
3. Invoke the `prd` skill, passing the **epic seed** as the feature intent — compose a rich intent string
   from the epic so `/saki-builder:prd`'s Step 0/0.5/1 consume it autonomously (no human gate here — the shape
   phase takes its autonomous fallback under `/saki-builder:pickup`):
   - epic **Goal** → the problem / desired outcome
   - epic **Target user & Job** → the JTBD (§3)
   - epic **User flow** → the recommended solution shape
   - epic **Success signal** → an outcome/metric seed (§5) and appetite hint
4. When `/saki-builder:prd` finishes it saves `tasks/prd-<slug>.md`. **Confirm the header carries `Item: <id>`**
   (pass the item id so `/saki-builder:prd` stamps it; if it wrote `—`, edit the header to `**Item:** <id>`).
5. Record `**Child PRD:** prd-<slug>.md` under the `### <id>` block in `tasks/roadmap.md`.
6. Set `phase:"review"`, `prd_written:true`.

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
- **`PRD_REVIEW_BLOCKED`** → record the reason, set `phase:"blocked"`, **flip the epic `In-progress →
  Blocked`** in `tasks/roadmap.md`, emit `PICKUP_BLOCKED: <slug> — <reason>` on its own line, and end. Do
  NOT loop forever, do NOT fabricate grounding — `prd-review` already exhausted the fixable paths.

Key design note (option 3 — one shared loop): the loop-to-green lives in `/saki-builder:prd-review`'s
autonomous mode; `/saki-builder:pickup` **reuses** it and keeps no copy. The fix→re-review loop, the 3-round
cap, and the non-convergence / DISCOVERY-FIRST / structural-`NOT READY` escapes all run **inside**
`prd-review`. `/saki-builder:pickup` only invokes it (without `--review-only`) and does the epic-specific
terminal handling (proto-ready handoff, or flip the epic to Blocked). No nesting — the loop runs in exactly
one place, so there is no double-loop when `/saki-builder:pickup` runs.

---

## Phase 3 — Ready for proto (terminal success — NO lock flag written here)

The PRD is green. `/saki-builder:pickup` stops here. It writes **no** lock flag — running `/saki-builder:proto E<n>`
designs the UI/UX and **locks** the PRD (`Status: Locked` + `<!-- prd-locked -->`, freezing requirements), the
single human gate before build. The epic stays `In-progress`.

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
- **The gate is structural.** No epic id → no run. There is no cold-intent feature path — that is the whole
  point of the disciplined workflow.
- **One human gate, at proto.** `/saki-builder:pickup` never advances into proto; running `/saki-builder:proto E<n>`
  designs the UI/UX and **locks** the PRD (the freeze before build). Never auto-run `/saki-builder:proto` from here.
- **Never fabricate grounding, never infinite-loop.** The only stops are: green (`proto-ready`), or a review
  that can't reach green (`DISCOVERY-FIRST`, an unbuilt dep / unaccepted bet, or non-convergence → `blocked`).
- **Single source of truth for behaviour.** Invoke `prd` / `prd-review`; do not re-implement them. The epic
  is the source of intent; the PRD is the source of scope. The **loop-to-green lives in `prd-review`'s
  autonomous mode** — `/saki-builder:pickup` reuses it (invoke without `--review-only`), never a second copy.
- **Always persist state before ending a turn** so any resume (a context clear, or the Stop gate re-driving
  you) lands on the right phase.
- **Status honesty.** Flip the epic `In-progress` on start and `Blocked` on escape; `/saki-builder:build` owns
  the `Shipped` flip. Never mark an epic `Shipped` from here.
