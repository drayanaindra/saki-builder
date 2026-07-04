---
name: roadmap
description: View or initialise the product roadmap — the single team-shareable portfolio artifact (tasks/roadmap.md) that lists every epic, its goal, user flow, and status. The roadmap is the disciplined entry point of the workflow: every feature must trace to an epic here before /pickup can start it. `/roadmap` prints the portfolio; `/roadmap init` scaffolds the file. Add epics with /saki-builder:epic. Usage — /saki-builder:roadmap [init].
---

# Product Roadmap — the portfolio artifact

`tasks/roadmap.md` is the **single source of what the product is building and in what order**. It is a
**product-strategy artifact** (what / why / order / status) — NOT a coordination tool. It deliberately
carries **no** sprint numbers, assignees-as-schedule, velocity, or due dates (team *coordination* is
out of scope). A solo builder writes just Goal + User flow and ignores the header fields; a team fills
Owner/Status/Updated and reviews the same file.

The roadmap is the **disciplined entry point**: `/saki-builder:pickup E<n>` will only start a feature that
already exists here as an epic. There is no cold-intent path.

---

## Usage

- `/saki-builder:roadmap` — print the portfolio: every epic with its `E<n> · title · Status`, grouped by status.
- `/saki-builder:roadmap init` — scaffold `tasks/roadmap.md` if it does not exist (no-op with a notice if it does).

Add or manage epics with **`/saki-builder:epic`** (this skill never adds epics — it only views/scaffolds).

---

## Behaviour

### `/saki-builder:roadmap` (view)

1. Read `tasks/roadmap.md`. If it is missing → print:
   `No roadmap yet. Run /saki-builder:roadmap init to scaffold it, then /saki-builder:epic to add your first epic.`
   and stop.
2. Parse every `### E<n> · <title>` block and its `**Status:**` field.
3. Print a compact portfolio grouped by status (Planned · In-progress · Shipped · Blocked). If there are
   zero epics → `Roadmap is empty — add one with /saki-builder:epic.`

```
ROADMAP — <product name>   (updated <YYYY-MM-DD>)

In-progress
  E3 · Instant seller payout        → Child PRD: prd-instant-seller-payout.md
Planned
  E4 · Bulk CSV import
Shipped
  E1 · Passwordless login
  E2 · Order status timeline
Blocked
  (none)

5 epics · 1 in-progress · 1 planned · 2 shipped · 0 blocked
Next: /saki-builder:pickup E4   (start the next planned epic)
```

### `/saki-builder:roadmap init` (scaffold)

If `tasks/roadmap.md` already exists → print `Roadmap already exists at tasks/roadmap.md` and stop (never
overwrite). Otherwise `mkdir -p tasks` and write the **Roadmap file template** below, asking once for the
product name (default: the repo/directory name if the human doesn't answer).

---

## Roadmap file template (canonical — reused by /saki-builder:epic and /saki-builder:pickup)

```markdown
# Roadmap: <product name>

**Updated:** <YYYY-MM-DD>

> The portfolio of epics for this product. Each epic = one PRD = ≤7 vertical slices. Add epics with
> /saki-builder:epic. Start one with /saki-builder:pickup E<n> (writes the PRD), then /saki-builder:proto E<n>, then
> /saki-builder:build E<n>. Status flows: Planned → In-progress → Shipped (Blocked if pickup can't reach a
> shippable PRD). Strategy artifact only — no sprints, assignees-as-schedule, or due dates.

## Epics

<!-- epics appended below by /saki-builder:epic, newest-numbered last -->
```

## Epic block template (canonical — /saki-builder:epic appends exactly this shape)

```markdown
### E<n> · <title>
**Status:** Planned · **Owner:** <@name | unassigned> · **Updated:** <YYYY-MM-DD>
**Goal:** <the OUTCOME we want, not the solution — one or two sentences>
**Target user & Job (JTBD):** As a <user>, when <situation>, I want <motivation> so I can <outcome>.
**User flow:** <happy-path steps, arrow-separated: step → step → step>
**Success signal:** <one measurable signal that tells us it worked>
**Child PRD:** —
```

**Status vocabulary (the lifecycle — enforced by the workflow verbs):**

| Status | Set by | Meaning |
|--------|--------|---------|
| `Planned` | `/saki-builder:epic` | on the roadmap, not started |
| `In-progress` | `/saki-builder:pickup E<n>` (on start) | PRD being written / reviewed / proto / build |
| `Shipped` | `/saki-builder:build E<n>` (on `PRD_BUILD_COMPLETE`) | built, QA-green, reviewed |
| `Blocked` | `/saki-builder:pickup E<n>` (on escape) | review can't reach a shippable PRD (discovery / unbuilt dep) |

**`E<n>` numbering:** sequential, never reused. `/saki-builder:epic` scans existing `### E<n>` headers and assigns
`max(n)+1`. A shipped or blocked epic keeps its number forever (a deleted epic's number is not recycled).

---

## Rules

- Never add or edit an epic's *content* here — that is `/saki-builder:epic`'s job (add) and the workflow verbs'
  job (status flips). This skill only **views** and **scaffolds**.
- Never overwrite an existing `tasks/roadmap.md` on `init`.
- Keep the artifact a strategy document: if asked to add scheduling/assignment/velocity fields, decline —
  the roadmap answers *what/why/order*, not *who/when* (coordination is out of scope).
