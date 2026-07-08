---
name: add
description: Add a work item to the product roadmap and route it. `/add` categorizes the item into Epic · Feature · Improvement · Bug (auto-proposed, or forced with --epic/--feature/--improvement/--bug), stamps its Type + Track flags, assigns the next id (E/F/I/B<n>), and appends it to tasks/roadmap.md. PRD-track (Epic, Feature) → next is /saki-builder:pickup <id> (writes & reviews the PRD). Plan-track (Improvement, Bug) → skip the PRD, next is /saki-builder:rplan. `--list` shows the portfolio. Usage — /saki-builder:add "<intent>" [--<type>]  |  /saki-builder:add --list.
---

# Add a work item — the universal intake

`/saki-builder:add` is the **one front door** for any new piece of work. It **categorizes** the item,
**flags** it with a Type + Track, records it on the roadmap (`tasks/roadmap.md`), and **routes** it to
the right next command — a PRD, or straight to a plan. It replaces the old epic-only `/epic`.

Like the roadmap it writes to, `/saki-builder:add` only **records + points**. It never drives
`/saki-builder:prd` or `/saki-builder:rplan` — those are the next step, run by the human.

---

## The model — two tracks, four types

| Type | Id | When | **Track** | Next after `/add` |
|------|----|------|-----------|-------------------|
| **Epic** | `E<n>` | large outcome, multiple journeys/surfaces, would span >~7 slices / multiple PRDs | **PRD** | `/saki-builder:pickup E<n>` → prd → proto → build |
| **Feature** | `F<n>` | one new user-facing capability / journey, ≤ a few slices | **PRD** | `/saki-builder:pickup F<n>` → prd → proto → build |
| **Improvement** | `I<n>` | enhancement to existing behavior — single surface, no new journey | **Plan** | `/saki-builder:rplan` → approved → qa |
| **Bug** | `B<n>` | defect / regression in existing behavior | **Plan** | `/saki-builder:rplan` (or fix directly if trivial) → qa |

**The routing rule** (why a Track): *a new user journey / UI that must be designed and approved ⇒
**PRD**-track — proto is its lock gate. A change or fix to existing behavior ⇒ **Plan**-track — skip the
PRD and proto.* Size is only the epic↔feature and improvement↔bug refiner, not the track decider.

**"Flag" — two ways:** every item carries stamped `**Type:**` + `**Track:**` fields on the roadmap; and
the caller can force the categorization with a CLI flag (`--epic` / `--feature` / `--improvement` /
`--bug`), overriding the auto-proposal.

---

## Usage

- `/saki-builder:add "<intent>"` — auto-categorize (propose Type + Track), **confirm**, then record + route.
- `/saki-builder:add --<type> "<intent>"` — force the type (`--epic|--feature|--improvement|--bug`); skip
  the propose step, still confirm the shape.
- `/saki-builder:add --list` — print the portfolio grouped by Status with Type shown inline (thin alias of
  `/saki-builder:roadmap`).

---

## Step 0 — Ensure the roadmap exists

Read `tasks/roadmap.md`. If missing, scaffold it via `/saki-builder:roadmap init` (`mkdir -p tasks`, write
the template, ask once for the product name — default the repo/directory name). Then continue.

## Step 1 — Categorize (propose Type + Track, confirm)

If a `--<type>` flag was given, use it. Otherwise **propose** a Type from the intent, using these signals,
and state the one-line reason so the human can correct:

- **Bug** — a defect in existing behavior: "broken", "500", "wrong result", "regression", repro-shaped. → **Plan**
- **Improvement** — enhancing something that already works: "faster", "polish", "add X to existing Y",
  one surface, no new journey. → **Plan**
- **Feature** — one new user-facing capability with a coherent journey, buildable in ≤ a few slices. → **PRD**
- **Epic** — a large outcome spanning multiple journeys/surfaces; would need >~7 slices or several PRDs. → **PRD**

Print `Proposed: <Type> · Track: <PRD|Plan> — <one-line reason>. Confirm? (or --<type> to change)` and
accept the human's correction. The Track follows the Type from the table (never chosen separately).

## Step 2 — Assign the next id (per-prefix counter)

Scan `tasks/roadmap.md` for existing `### <prefix><n> · ` headers **of the chosen prefix** (`E`/`F`/`I`/`B`),
take `max(n)` (0 if none), assign `<prefix><max+1>`. Counters are **per-prefix, sequential, never reused** —
a shipped/deleted item's number is not recycled, and existing `E<n>` roadmaps stay valid unchanged.

## Step 3 — Walk the shape prompts (by Track)

Accept terse answers; the human may answer all at once. Keep it lean — this is intake, not a PRD/plan.

An **orchestrator caller** (e.g. `/saki-builder:pickup`'s Phase-2b recut) may pass a **complete shape**
(all fields) inside a `--<type>` intent — treat that as "answered all at once" and record without
prompting (the autonomous fallback, same convention `/saki-builder:prd` uses under `/saki-builder:pickup`).

**PRD-track (Epic / Feature)** — the outcome-first shape (same as the old epic):
1. **Title** — a short noun phrase.
2. **Goal — what outcome?** Push for the OUTCOME, not the mechanism (if they say "add a button", ask
   "…so that *what* changes for the user?").
3. **Target user & Job (JTBD)** — `As a <user>, when <situation>, I want <motivation> so I can <outcome>.`
4. **User flow (happy path)** — arrow-separated main-path steps.
5. **Success signal** — one measurable signal (or `TBD — define before /saki-builder:pickup`).

**Plan-track (Improvement / Bug)** — the lean shape (no JTBD / user flow / proto):
1. **Title** — a short noun phrase.
2. **What** — the fix or enhancement in one or two sentences.
3. **Repro / Context** — Bug: steps → expected vs actual. Improvement: what's suboptimal today + why it matters.

If the human says "you decide" for any field, propose a default from the title + context and state it
explicitly so they can correct.

## Step 4 — Append the item block

Append **exactly** the matching **item block template** from `/saki-builder:roadmap` to the `## Items`
section, filled in (older roadmaps use `## Epics` — append under whichever heading exists). Both
templates prepend a `**Type:** … · **Track:** …` pair to the metadata line.

**PRD-track block:**
```markdown
### E<n> · <title>
**Type:** <Epic|Feature> · **Track:** PRD · **Status:** Planned · **Owner:** <@name | unassigned> · **Updated:** <YYYY-MM-DD>
**Goal:** <the OUTCOME we want, not the solution>
**Target user & Job (JTBD):** As a <user>, when <situation>, I want <motivation> so I can <outcome>.
**User flow:** <step → step → step>
**Success signal:** <one measurable signal | TBD — define before /saki-builder:pickup>
**Child PRD:** —
```

**Plan-track block (lean):**
```markdown
### B<n> · <title>
**Type:** <Improvement|Bug> · **Track:** Plan · **Status:** Planned · **Owner:** <@name | unassigned> · **Updated:** <YYYY-MM-DD>
**What:** <the fix/enhancement in one or two sentences>
**Repro / Context:** <Bug: steps → expected vs actual · Improvement: what's suboptimal today>
**Child plan:** —
```

Get today's date with `date +%F`. Bump the roadmap's top-level `**Updated:**` line to today too.

## Step 5 — Confirm + route

Print, choosing the Next line by Track:

```
Added <id> · <title>   (<Type> · Track: <PRD|Plan> · Planned)

<Goal | What>: <text>
Next: <route>
```

- **PRD-track** → `Next: /saki-builder:pickup <id>   — writes the PRD and reviews it to green (then /saki-builder:proto)`
- **Plan-track** → `Next: /saki-builder:rplan   — plan this directly (no PRD/proto). Trivial one-liner? Just fix it.`

---

## `--list` mode

Read `tasks/roadmap.md`, print each item as `<id> · <title> · <Type> · <Status>` grouped by Status
(same as `/saki-builder:roadmap`). If the roadmap is missing →
`No roadmap yet — run /saki-builder:add to create your first item.`

---

## Rules

- **Categorize before recording.** Every item gets a Type + Track; the Track (PRD vs Plan) is derived
  from the Type, never chosen independently.
- **PRD-track = new journey/UI to design.** **Plan-track = change/fix to existing behavior.** When in
  doubt between a big Feature and a small Epic, prefer Feature and split later; between Improvement and
  Bug, "is it broken?" → Bug, "is it fine but could be better?" → Improvement.
- **Keep it lean.** PRD-track walks 5 shape prompts, Plan-track walks 3. No PRD/plan-depth questions here
  — that's `/saki-builder:prd` (PRD-track) or `/saki-builder:rplan` (Plan-track).
- **Strategy + backlog, not coordination.** Never add scheduling / assignee-as-schedule / velocity / due
  dates to an item block (that stays out of the roadmap's scope).
- **Numbering is per-prefix and append-only.** Never renumber or recycle; only ever append with the next
  `<prefix><n>`.
- **Never set any status other than `Planned`** — the workflow verbs own every later transition
  (`/saki-builder:pickup`, `/saki-builder:rplan`, `/saki-builder:build`).
- **Record + point only.** `/saki-builder:add` does not run `/saki-builder:prd` or `/saki-builder:rplan`; it
  hands off to them.
