---
name: epic
description: Add an epic to the product roadmap (tasks/roadmap.md) — the disciplined unit of product work. An epic states WHAT outcome you want and HOW the user flow looks; it maps 1:1 to a PRD (≤7 slices). Interactive add walks Goal → Target user & Job → User flow → Success signal, assigns the next E<n>, and appends it as Planned. `--list` shows every epic + status. Then start it with /saki-builder:pickup E<n>. Usage — /saki-builder:epic  |  /saki-builder:epic --list.
---

# Add an Epic

An **epic** is the unit of disciplined product work: **1 epic = 1 PRD = ≤7 vertical slices**. It captures
just enough to start — the OUTCOME you want and the happy-path user flow — and lives on the roadmap
(`tasks/roadmap.md`) so every feature traces to a stated goal. If shaping later reveals it needs >7 slices,
that's the signal to **split it into two epics**.

This skill only **adds** an epic (status `Planned`). Viewing the portfolio is `/saki-builder:roadmap`; starting
an epic (writing its PRD) is `/saki-builder:pickup E<n>`.

---

## Usage

- `/saki-builder:epic` — interactive add. Walk the 4 prompts, then append the epic to the roadmap.
- `/saki-builder:epic --list` — print `E<n> · title · Status` for every epic (a thin alias of `/saki-builder:roadmap`).

---

## Step 0 — Ensure the roadmap exists

Read `tasks/roadmap.md`. If missing, scaffold it first using the **Roadmap file template** from
`/saki-builder:roadmap` (`mkdir -p tasks`, write the template, ask once for the product name — default to the
repo/directory name). Then continue.

## Step 1 — Assign the next `E<n>`

Scan the file for existing `### E<n> · ` headers, take `max(n)` (0 if none), assign `E<max+1>`. Numbers are
**sequential and never reused** — a shipped/blocked/deleted epic's number is not recycled.

## Step 2 — Walk the 4 prompts (the epic shape)

Ask these one at a time (accept terse answers; the human may answer all at once). Keep it lean — this is the
shape-first front end, not a PRD.

1. **Title** — a short noun phrase (e.g. "Instant seller payout").
2. **Goal — what outcome do you want?** Push for the OUTCOME, not the solution. If they describe a mechanism
   ("add a withdraw button"), ask "…so that *what* changes for the user?" and capture that.
3. **Target user & Job (JTBD)** — who is this for, and what job are they hiring it to do? Shape into
   `As a <user>, when <situation>, I want <motivation> so I can <outcome>.`
4. **User flow (happy path)** — the main path, as arrow-separated steps
   (`buyer pays → webhook clears → seller sees "Payout available" → …`).
5. **Success signal** — one measurable signal that tells you it worked (`"paid too slow" churn ↓ 22% → <8%`).
   If they can't name one, record `TBD — define before /saki-builder:pickup` (a soft nudge, not a blocker).

If the user says "you decide" for any field, propose a reasonable default from the title + context and state
it explicitly so they can correct.

## Step 3 — Append the epic block

Append **exactly** the **Epic block template** from `/saki-builder:roadmap` to the `## Epics` section, filled in:

```markdown
### E<n> · <title>
**Status:** Planned · **Owner:** <@name | unassigned> · **Updated:** <today YYYY-MM-DD>
**Goal:** <goal>
**Target user & Job (JTBD):** As a <user>, when <situation>, I want <motivation> so I can <outcome>.
**User flow:** <step → step → step>
**Success signal:** <signal | TBD — define before /saki-builder:pickup>
**Child PRD:** —
```

Get today's date with `date +%F` (Bash). Bump the roadmap's top-level `**Updated:**` line to today too.

## Step 4 — Confirm

Print:

```
Added E<n> · <title>  (Planned)

Goal: <goal>
Next: /saki-builder:pickup E<n>   — writes the PRD and reviews it to green (ready for /saki-builder:proto)
```

---

## `--list` mode

Read `tasks/roadmap.md`, print each epic as `E<n> · <title> · <Status>` (grouped by status, same as
`/saki-builder:roadmap`). If the roadmap is missing → `No roadmap yet — run /saki-builder:epic to create your first epic.`

---

## Rules

- One epic = one PRD = ≤7 slices. If the goal is clearly several independent outcomes, suggest splitting into
  multiple epics rather than one oversized one.
- Keep it lean — 4 prompts, no PRD-depth questions here (that's `/saki-builder:pickup` → `/saki-builder:prd`).
- Strategy artifact only: never add scheduling/assignee-as-schedule/velocity fields to the epic block.
- Never renumber existing epics; only ever append with the next `E<n>`.
- Never set any status other than `Planned` — the workflow verbs own every later transition.
