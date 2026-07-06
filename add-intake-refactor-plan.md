# Plan — `/epic` → `/add`: a categorizing intake router

**Status:** Complete (all 9 files done · verification green) · **Owner:** drayanaindra · **Updated:** 2026-07-06
**Risk:** MED (skill-content edits across 9 workflow files; no code execution; reversible)
**Appetite:** small — one focused session

---

## Goal

Replace the epic-only `/saki-builder:epic` with a universal intake `/saki-builder:add` that
**categorizes** an incoming item into one of four types, **flags** it (Type + Track), and **routes**
it to the correct downstream path — a PRD or a plan — then align the rest of the workflow so the two
tracks are coherent.

## The model — two tracks, four types

| Type | When | Track | Path after `/add` |
|------|------|-------|-------------------|
| **Epic** `E<n>` | large outcome, multiple journeys, would span >~7 slices / multiple PRDs | **PRD** | `/pickup E<n>` → prd → prd-review → proto → build |
| **Feature** `F<n>` | one new user-facing capability / journey, ≤ a few slices | **PRD** | `/pickup F<n>` → prd → prd-review → proto → build |
| **Improvement** `I<n>` | enhancement to existing behavior, single surface, no new journey | **Plan** | `/rplan` (seeded from the item) → approved → qa |
| **Bug** `B<n>` | defect / regression in existing behavior | **Plan** | `/rplan` (or fix directly if trivial) → qa |

**Routing rule the skill applies:** *new user journey / UI to design + approve ⇒ PRD-track (proto is
its lock gate). Change or fix to existing behavior ⇒ Plan-track (skip PRD + proto).* Size is only the
epic↔feature and improvement↔bug refiner.

**"Flag" is satisfied two ways:** (1) each item carries stamped `**Type:**` + `**Track:**` fields;
(2) the caller can force the call with a CLI flag — `/add --epic|--feature|--improvement|--bug "…"` —
overriding the auto-categorization.

## `/add` behaviour (the new skill — intake + router only, never an executor)

- `/add "<intent>"` — auto-categorize (propose Type + Track), **confirm with the human**, assign the
  next id for that prefix, append the item to `tasks/roadmap.md`, print the next command.
- `/add --<type> "<intent>"` — force the type; skip the propose step.
- `/add --list` — print the portfolio (thin alias of `/roadmap`), grouped by Status, Type shown inline.
- Terminal output points to the next verb by Track:
  - PRD-track → `Next: /saki-builder:pickup <id>`
  - Plan-track → `Next: /saki-builder:rplan` (or "fix directly — trivial") — no PRD, no proto.
- Like today's `/epic`, `/add` only records + points; it does **not** drive `/prd` or `/rplan`.

## Roadmap block shapes (in `tasks/roadmap.md`)

Shared metadata line gains `**Type:**` + `**Track:**` (prepended to the existing Status/Owner/Updated
line — keeps the `### <id> · <title>` and `**Status:**` parse anchors intact for pickup/build).

**PRD-track (Epic / Feature)** — full block, unchanged fields:
```
### E3 · Instant seller payout
**Type:** Epic · **Track:** PRD · **Status:** Planned · **Owner:** — · **Updated:** 2026-07-06
**Goal:** …   **Target user & Job (JTBD):** …   **User flow:** …   **Success signal:** …
**Child PRD:** —
```

**Plan-track (Improvement / Bug)** — lean block (no JTBD / user flow / proto):
```
### B7 · Payout webhook returns 500
**Type:** Bug · **Track:** Plan · **Status:** Planned · **Owner:** — · **Updated:** 2026-07-06
**What:** <the fix/enhancement in one or two sentences>
**Repro / Context:** <Bug: steps → expected vs actual · Improvement: what's suboptimal today>
**Child plan:** —
```

**IDs:** per-type prefix, each its own sequential counter, never reused. `/add` scans `### <prefix><n>`
headers for the chosen prefix and assigns `max+1`. Existing `E<n>` roadmaps stay valid unchanged.

## Files to change (9)

1. **`config/skills/add/SKILL.md`** — NEW. The intake+router above (categorization heuristics, the two
   block templates by reference to `/roadmap`, CLI flags, `--list`, per-prefix numbering, terminal routing).
2. **`config/skills/epic/`** — DELETE entirely (`git rm -r`). Clean rename; no tombstone (per decision).
3. **`config/skills/roadmap/SKILL.md`** — add `**Type:**`/`**Track:**` to both block templates; add the
   lean Plan-track template; `/epic`→`/add` throughout; view shows Type inline + notes the two tracks;
   broaden "portfolio of epics" → "portfolio of work items (epics · features · improvements · bugs)";
   status table gains Plan-track rows. Keep the no-scheduling/no-velocity rule.
4. **`config/skills/pickup/SKILL.md`** — accept **E<n> and F<n>** (PRD-track); if given an I/B id →
   stop with "that's a Plan-track item — run `/saki-builder:rplan`, not `/pickup`"; `/epic`→`/add` in the
   "add one first" / not-found messages; one note that pickup treats Epic and Feature identically.
5. **`config/skills/prd/SKILL.md`** — `pickup E<n>` → `E<n>/F<n>`; `**Epic:**` header field holds the
   PRD-track item id (E<n> or F<n>) — keep the field name, update its comment. Terminology only.
6. **`config/skills/proto/SKILL.md`** — id resolution accepts **E<n> or F<n>** (same roadmap→Child PRD
   lookup); wording `epic id` → `item id (E<n>/F<n>)`.
7. **`config/skills/build/SKILL.md`** — id launch + Shipped-flip accept **E<n> or F<n>** (prefix-agnostic
   Child-PRD reverse-map already works); wording pass.
8. **`config/skills/pipeline/SKILL.md`** — update the tombstone redirect chain to
   `/roadmap → /add → /pickup <id> → /proto → /build`, with the Plan-track note (`/add → /rplan`).
9. **`config/skills/init-env/SKILL.md`** — Step 11b: `/epic`→`/add`, "add the first items with `/add`".

Frontmatter `description:` updated for `add`, `roadmap`, `pickup` (they show in the skill list).

## Explicitly OUT of scope (YAGNI — keep it concise & faithful)

- **No rewiring of `/rplan`** to manage roadmap status. Plan-track items are seeded by pointing the
  human at `/rplan`; `/add` composes the intent. `/rplan` stays a general skill. (Plan-track status
  flips beyond `Planned` are left lightweight/manual for v1 — noted, not built.)
- **No new `backlog.md`** — all items live on the roadmap (per decision).
- **No change to the proto lock gate** — Features use proto like Epics (proto = PRD approval/lock).
- No changes to `design.md` / `product.md` (their "epic" is agile-story hierarchy, unrelated).

## Verification (automatable)

- `grep -rn '/saki-builder:epic' config/skills/` → only the `epic/` tombstone + historical mentions;
  no live workflow skill still routes to `/epic`.
- `grep -rln 'F<n>\|Track:\|/saki-builder:add' config/skills/{add,roadmap,pickup,proto,build}` → present.
- `ls config/skills/add/SKILL.md` exists; `epic/SKILL.md` is a tombstone.
- Frontmatter `name:` in `add/SKILL.md` is `add`; descriptions updated.
- Manual read-through: walk one Epic and one Bug through the routing prose end-to-end for coherence.

## Post-implementation note (not part of this edit)

Per repo mechanics, the installed `/saki-builder:*` plugin loads a **version-pinned snapshot** — these
source edits do **not** live-update the running commands until a plugin release (version bump in
`.claude-plugin/plugin.json` + reinstall). Flag in Next Actions; do not release unless asked.
