---
name: roadmap
description: View or initialise the product roadmap — the single team-shareable portfolio artifact (tasks/roadmap.md) that lists every work item (epics · features · improvements · bugs), its goal, and status. The roadmap is the disciplined entry point of the workflow: every piece of work traces to an item here. `/roadmap` prints the portfolio; `/roadmap init` scaffolds the file. Add items with /saki-builder:add. Usage — /saki-builder:roadmap [init].
---

# Product Roadmap — the portfolio artifact

`tasks/roadmap.md` is the **single source of what the product is building and fixing, and in what
order**. It holds every **work item** — the disciplined units of work. Each item carries a **Type**
(Epic · Feature · Improvement · Bug) and a **Track** that follows from it:

- **PRD-track** (Epic `E<n>`, Feature `F<n>`) — a new user journey/UI → `/saki-builder:pickup <id>` writes
  and reviews a PRD, then `/saki-builder:proto` designs + locks it, then `/saki-builder:build`.
- **Plan-track** (Improvement `I<n>`, Bug `B<n>`) — a change/fix to existing behavior → skip the PRD and
  go straight to `/saki-builder:rplan`.

It is a **portfolio artifact** (what / why / order / status) — NOT a coordination tool. It deliberately
carries **no** sprint numbers, assignees-as-schedule, velocity, or due dates. A solo builder writes just
the Goal/What and ignores the header fields; a team fills Owner/Status/Updated and reviews the same file.

The roadmap is the **disciplined entry point**: work starts by adding an item here with
`/saki-builder:add` (which categorizes it and points at the right next command). There is no cold-intent path.

---

## Usage

- `/saki-builder:roadmap` — print the portfolio: every item with its `<id> · title · Type · Status`, grouped by status.
- `/saki-builder:roadmap init` — scaffold `tasks/roadmap.md` if it does not exist (no-op with a notice if it does).

Add or manage items with **`/saki-builder:add`** (this skill never adds items — it only views/scaffolds).

---

## Behaviour

### `/saki-builder:roadmap` (view)

1. Read `tasks/roadmap.md`. If it is missing → print:
   `No roadmap yet. Run /saki-builder:roadmap init to scaffold it, then /saki-builder:add to add your first item. (Brand-new product from scratch? /saki-builder:genesis sets up foundations and seeds the roadmap for you.)`
   and stop.
2. Parse every `### <id> · <title>` block and its `**Type:**` / `**Status:**` fields.
3. Print a compact portfolio grouped by status (Planned · In-progress · Shipped · Blocked). Show each
   item's Type inline. If there are zero items → `Roadmap is empty — add one with /saki-builder:add.`

```
ROADMAP — <product name>   (updated <YYYY-MM-DD>)

In-progress
  E3 · Instant seller payout   (Epic)      → Child PRD: prd-instant-seller-payout.md
Planned
  F4 · Bulk CSV import         (Feature)
  B7 · Payout webhook 500      (Bug)       → Child plan: —
Shipped
  E1 · Passwordless login      (Epic)
  I2 · Faster search index     (Improvement)
Blocked
  (none)

6 items · 1 in-progress · 2 planned · 2 shipped · 0 blocked
Next: /saki-builder:pickup F4  (PRD-track)  ·  /saki-builder:rplan for B7 (Plan-track)
```

### `/saki-builder:roadmap init` (scaffold)

If `tasks/roadmap.md` already exists → print `Roadmap already exists at tasks/roadmap.md` and stop (never
overwrite). Otherwise `mkdir -p tasks` and write the **Roadmap file template** below. **Product name:** use
the name passed in the invocation (`/saki-builder:roadmap init "<product name>"`, or a name a caller such as
`/saki-builder:genesis` supplies) — **only ask when none was provided** (default: the repo/directory name if
the human doesn't answer). A caller that already knows the name never triggers a prompt.

---

## Roadmap file template (canonical — reused by /saki-builder:add and /saki-builder:pickup)

```markdown
# Roadmap: <product name>

**Updated:** <YYYY-MM-DD>

> The portfolio of work items for this product. Add items with /saki-builder:add — it categorizes each
> as Epic · Feature · Improvement · Bug and routes it. PRD-track (Epic/Feature): /saki-builder:pickup <id>
> → /saki-builder:proto <id> → /saki-builder:build <id>. Plan-track (Improvement/Bug): /saki-builder:rplan.
> Status flows: Planned → In-progress → Shipped (Blocked if a PRD-track item can't reach a shippable PRD).
> Portfolio artifact only — no sprints, assignees-as-schedule, or due dates.

## Items
```

## Item block templates (canonical — /saki-builder:add appends exactly one of these)

**PRD-track (Epic / Feature):**
```markdown
### E<n> · <title>
**Type:** <Epic|Feature> · **Track:** PRD · **Status:** Planned · **Owner:** <@name | unassigned> · **Updated:** <YYYY-MM-DD>
**Goal:** <the OUTCOME we want, not the solution — one or two sentences>
**Target user & Job (JTBD):** As a <user>, when <situation>, I want <motivation> so I can <outcome>.
**User flow:** <happy-path steps, arrow-separated: step → step → step>
**Success signal:** <one measurable signal that tells us it worked>
**Child PRD:** —
```

**Plan-track (Improvement / Bug) — lean:**
```markdown
### B<n> · <title>
**Type:** <Improvement|Bug> · **Track:** Plan · **Status:** Planned · **Owner:** <@name | unassigned> · **Updated:** <YYYY-MM-DD>
**What:** <the fix/enhancement in one or two sentences>
**Repro / Context:** <Bug: steps → expected vs actual · Improvement: what's suboptimal today>
**Child plan:** —
```

**Status vocabulary (the lifecycle — enforced by the workflow verbs):**

| Status | Set by | Meaning |
|--------|--------|---------|
| `Planned` | `/saki-builder:add` | on the roadmap, not started |
| `In-progress` | `/saki-builder:pickup <id>` (PRD-track) · `/saki-builder:rplan`→`/saki-builder:approved` (Plan-track) | being written/reviewed/built |
| `Shipped` | `/saki-builder:build <id>` (PRD-track) · the fix landing QA-green (Plan-track) | built, QA-green, reviewed |
| `Blocked` | `/saki-builder:pickup <id>` (on escape) | PRD-track review can't reach a shippable PRD (discovery / unbuilt dep) |

**Id numbering:** per-type prefix (`E`/`F`/`I`/`B`), each its own sequential counter, never reused.
`/saki-builder:add` scans existing `### <prefix><n>` headers and assigns `max(n)+1` for that prefix. A
shipped or deleted item keeps its number forever (numbers are not recycled).

---

## Rules

- Never add or edit an item's *content* here — that is `/saki-builder:add`'s job (add) and the workflow
  verbs' job (status flips). This skill only **views** and **scaffolds**.
- Never overwrite an existing `tasks/roadmap.md` on `init`.
- Keep the artifact a portfolio document: if asked to add scheduling/assignment/velocity fields, decline —
  the roadmap answers *what/why/order*, not *who/when* (coordination is out of scope).
- Back-compat: an older roadmap may use a `## Epics` heading and `E<n>`-only items with no `**Type:**`
  field — read those as `Type: Epic · Track: PRD`. New scaffolds use `## Items`.
