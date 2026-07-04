---
name: pickup
description: Pull a roadmap epic into active development — the disciplined entry point for feature work. `/pickup E<n>` reads the epic from tasks/roadmap.md, seeds /saketek:prd from it (PRD stamped Epic: E<n>), then loops /saketek:prd ↔ /saketek:prd-review until the PRD is green (Verdict SHIP AND Readiness READY) and STOPS — ready for /saketek:proto. Flips the epic Planned→In-progress; escapes to Blocked if the review can't reach a shippable PRD. Running /saketek:proto E<n> afterwards designs the UI/UX and LOCKS the PRD (freezes requirements — the gate before build); there is no separate approve step. Usage — /saketek:pickup E<n>.
---

# Pick up an epic → write & review its PRD to green (ready for proto)

`/saketek:pickup E<n>` is the **only** way to start feature work — the structural gate of the disciplined
workflow. It requires an epic that already exists on `tasks/roadmap.md`; there is no cold-intent path. It
runs the **front half** of the product flow: seed `/saketek:prd` from the epic, then loop
`/saketek:prd-review` until the PRD is **green** (`Verdict SHIP` AND `Readiness READY`), and stop there —
"ready to proto". You do **not** re-implement `/saketek:prd` or `/saketek:prd-review`; you **invoke** them
(Skill tool) and drive the loop.

```
/saketek:pickup E3
  → resolve E3 from tasks/roadmap.md   (flip Planned → In-progress)
  → /saketek:prd   (seeded by the epic; PRD stamped `Epic: E3`)
  → loop /saketek:prd-review until SHIP · READY   (≤3 rounds; escape to Blocked if it can't)
  → STOP — PRD green & ready. Run /saketek:proto E3 (it designs the UI/UX and LOCKS the PRD).
```

The single human gate is at proto — **running `/saketek:proto E<n>` designs the UI/UX and locks the PRD**
(the explicit freeze before build); `/saketek:pickup` writes no lock flag and never advances into proto itself.

---

## Usage

- `/saketek:pickup E<n>` — start (or resume) epic `E<n>`. Filler words are fine (`/saketek:pickup start E3`).
- No epic id → **structural gate**: print
  `no epic id — add one first with /saketek:epic, then /saketek:pickup E<n>` and stop. Never invent a feature.

---

## GATE 0 — Resume check (deterministic)

On every invocation, parse the `E<n>` id, then read `tasks/.pickup-<slug>-state.json` if it exists (the
`<slug>` is recorded in the epic's `Child PRD:` link, or in the state file). Branch on `phase`:

| `phase` on entry | Action |
|------------------|--------|
| (no state file) | Fresh start → Phase 1. |
| `prd` | Re-run Phase 1 from the point the PRD was incomplete (the PRD file may be partial). |
| `review` | Resume Phase 2 — re-run `/saketek:prd-review` and continue the loop. |
| `proto-ready` | Already green. Re-print the ready handoff (Phase 3); do nothing else. |
| `blocked` | Re-print the BLOCKED report; a human decides. Do not silently retry. |

**Best-effort + safe:** a missing/partial state file degrades to a normal fresh run — never hard-fail on it.
Always write the state file before ending a turn so resume lands on the right phase.

---

## GATE 1 — Resolve the epic (hard stop if missing)

Read `tasks/roadmap.md`. Find the `### E<n> · <title>` block. If absent → print
`E<n> not found on the roadmap. /saketek:roadmap to see epics, /saketek:epic to add one.` and stop.

Extract the epic's fields: **title, Goal, Target user & Job (JTBD), User flow, Success signal**. These
become the **epic seed** handed to `/saketek:prd`.

Derive `<slug>` the way `/saketek:prd` does: `slugify(title)`. (Single-source the slug in `/saketek:prd`'s
`{{input.feature | slugify}}` — `/saketek:pickup` passes the title as the feature, so the PRD lands at
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
- `proto-ready` → PRD is green (`SHIP · READY`), waiting for the human to run `/saketek:proto` → the Stop
  gate **releases** (the human's turn). This is the terminal success state for `/saketek:pickup`.
- `blocked` → a hard stop you reported → the Stop gate **releases**.

---

## Phase 1 — `/saketek:prd`  (seeded by the epic)

1. Init the state file (`phase:"prd"`, stamp `started_at`, `epic`, `slug`, `title`, `prd`).
2. **Flip the epic `Planned → In-progress`** in `tasks/roadmap.md` (update its `**Status:**` and `**Updated:**`).
3. Invoke the `prd` skill, passing the **epic seed** as the feature intent — compose a rich intent string
   from the epic so `/saketek:prd`'s Step 0/0.5/1 consume it autonomously (no human gate here — the shape
   phase takes its autonomous fallback under `/saketek:pickup`):
   - epic **Goal** → the problem / desired outcome
   - epic **Target user & Job** → the JTBD (§3)
   - epic **User flow** → the recommended solution shape
   - epic **Success signal** → an outcome/metric seed (§5) and appetite hint
4. When `/saketek:prd` finishes it saves `tasks/prd-<slug>.md`. **Confirm the header carries `Epic: E<n>`**
   (pass the epic id so `/saketek:prd` stamps it; if it wrote `—`, edit the header to `**Epic:** E<n>`).
5. Record `**Child PRD:** prd-<slug>.md` under the `### E<n>` block in `tasks/roadmap.md`.
6. Set `phase:"review"`, `prd_written:true`.

---

## Phase 2 — `/saketek:prd-review`  (loop until green = SHIP · READY)

Set `phase:"review"`. Invoke the `prd-review` skill on the PRD. Read its result from the canonical
**`--- REVIEW COMPLETE ---`** summary block it prints at the end (the same tokens `/pipeline` consumed) —
its three lines are:

```
Phase 1 (Structural): PASSED / FAILED
Verdict:              DISCOVERY-FIRST / REVISE / SHIP
Readiness:            READY / NOT READY [— blocker + R#/§]
```

The machine-readable `<!-- review-verdict: SHIP|REVISE|DISCOVERY-FIRST -->` comment (in the synthesis
header) is the robust fallback if the block is reworded. (Anchor on the line-start `Verdict:` /
`Readiness:` labels in that block — don't match the words mid-prose elsewhere in the review.)

**Green = `Verdict: SHIP` AND `Readiness: READY`** — both axes. A `SHIP · NOT READY` PRD is sound but not
buildable-now (unbuilt dep, slice-1-blocking open Q, unaccepted bet); it is NOT green and does NOT advance.

Loop (autonomous — you are the PRD author here). Record `verdict` + `readiness` + `phase1` each round:

- **Phase 1 FAILED, or Verdict REVISE, or Readiness NOT READY on a FIXABLE blocker** → apply the review's
  prescribed fixes to the PRD (rewrite vague criteria, add the prescribed failure/edge criteria, add the
  slice's `Assumes:` line for prescribed hidden work — or promote load-bearing hidden work to its own
  slice, fix orphan slices, add kill criteria, resolve a §12 open Q, close a fixable readiness blocker), bump
  `review.rounds`, add to `review.blockers_fixed`, and re-run `prd-review`. **Cap at 3 rounds.**
- **Escape to the human as BLOCKED** — do NOT loop forever, do NOT fabricate grounding — when the review
  can't be authored to green:
  - **Verdict DISCOVERY-FIRST** (a load-bearing unknown needs discovery), OR
  - **Readiness NOT READY on a STRUCTURAL blocker** you can't author away — an unbuilt / `TBD` dependency,
    or an unaccepted bet / unresolved DISCOVERY-RISK, OR
  - **Non-convergence** — round-2 carries the same blocker volume/level as round-1, or the 3-round cap is
    hit still not green (see `patterns.md` — score-trajectory convergence signal; recut, don't loop again).

  Record it, set `phase:"blocked"`, **flip the epic `In-progress → Blocked`** in `tasks/roadmap.md`, emit
  `PICKUP_BLOCKED: <slug> — <DISCOVERY-FIRST | readiness: blocker>: <reason>` on its own line, and end.
- **Green — Verdict SHIP AND Readiness READY** → record `review.verdict:"SHIP"`, `review.readiness:"READY"`,
  set `phase:"proto-ready"`, and go to **Phase 3**.

Key design note: the review loop lives HERE in the orchestrator (`/saketek:pickup` is author + driver).
`/saketek:prd-review` stays single-pass and independent — it never edits the PRD. The loop-to-green is a
`/saketek:pickup` capability, not a reviewer capability.

---

## Phase 3 — Ready for proto (terminal success — NO lock flag written here)

The PRD is green. `/saketek:pickup` stops here. It writes **no** lock flag — running `/saketek:proto E<n>`
designs the UI/UX and **locks** the PRD (`Status: Locked` + `<!-- prd-locked -->`, freezing requirements), the
single human gate before build. The epic stays `In-progress`.

Ensure `phase:"proto-ready"` and the state file is written, then print:

```
PICKUP_READY: <slug> — review SHIP · READY · R rounds · B blockers fixed

✅ PRD green & ready for proto: tasks/prd-<slug>.md   (Epic: E<n>)
   Review record: tasks/prd-<slug>-review.md
   Run /saketek:proto E<n> when ready — it designs the UI/UX and LOCKS the PRD (freezes requirements).
   (then /saketek:build E<n> to ship it — build refuses an unlocked PRD)
```

`PICKUP_READY` (own line) is the terminal success sentinel. The `pickup-completion-gate.sh` Stop hook
ALLOWS the stop at `phase:"proto-ready"` — ending the turn here is correct and expected.

---

## Survival & rules

- **Run the loop to green.** The front half is kept alive by `pickup-completion-gate.sh` (it blocks an early
  stop while `phase` ∈ {prd, review}). It releases the moment `phase` becomes `proto-ready` or `blocked`.
- **The gate is structural.** No epic id → no run. There is no cold-intent feature path — that is the whole
  point of the disciplined workflow.
- **One human gate, at proto.** `/saketek:pickup` never advances into proto; running `/saketek:proto E<n>`
  designs the UI/UX and **locks** the PRD (the freeze before build). Never auto-run `/saketek:proto` from here.
- **Never fabricate grounding, never infinite-loop.** The only stops are: green (`proto-ready`), or a review
  that can't reach green (`DISCOVERY-FIRST`, an unbuilt dep / unaccepted bet, or non-convergence → `blocked`).
- **Single source of truth for behaviour.** Invoke `prd` / `prd-review`; do not re-implement them. The epic
  is the source of intent; the PRD is the source of scope.
- **Always persist state before ending a turn** so any resume (a context clear, or the Stop gate re-driving
  you) lands on the right phase.
- **Status honesty.** Flip the epic `In-progress` on start and `Blocked` on escape; `/saketek:build` owns
  the `Shipped` flip. Never mark an epic `Shipped` from here.
