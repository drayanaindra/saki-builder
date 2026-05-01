# Skill Description Audit — Plan

**Scope:** 40 `SKILL.md` files in `config/skills/*/SKILL.md`. Audit and rewrite the `description:` frontmatter field where it fails to give the Claude Code harness an unambiguous trigger signal.

**Out of scope:** Loose `.md` files at `config/skills/` root (those are agent definitions, separate concern). The `trigger`, `inputs`, `type` fields. Skill bodies. Renames or removals.

## Why this is the lever

The harness routes invocations on the `description` field. Bad descriptions cause two failure modes:
- **False negative** — skill doesn't fire when it should (description too vague: "Use for any non-trivial task")
- **False positive** — wrong skill fires (sibling skills with overlapping trigger zones, e.g. `rplan` vs `rplan-trust` vs `orchestrating-feature`)

Both are description-quality problems. Tags, status fields, and metadata don't fix them.

## Quality bar (rubric)

A description passes if it answers all four:

1. **WHAT** — one-sentence action verb (`Generate X`, `Run Y against Z`, `Launch Q after R`)
2. **WHEN** — concrete trigger condition (`after implementing`, `before committing`, `when user says "..."`). NOT "for non-trivial tasks."
3. **WHEN NOT** — for skills with siblings, exclude the sibling's territory explicitly. Example: `rplan` should say "for planning before approval — not for execution; see /approved for that."
4. **EXAMPLES** — 1–3 concrete trigger phrases for skills whose invocation is user-driven (workflow skills especially)

Skills already meeting the bar: leave untouched. Don't rewrite for style.

## Methodology

### Step 1 — Extract & score (single pass, ~30 min)
Read frontmatter from all 40 SKILL.md files. For each, score 0–4 against the rubric. Output a single audit table to `skill-audit-table.md` with: skill name, current description (truncated), score, failure modes (e.g. "WHEN missing", "collides with rplan-trust").

### Step 2 — Group by collision zone
Bucket skills where sibling overlap is the root issue. Known zones:
- **Planning/orchestration:** `rplan`, `rplan-review`, `rplan-trust`, `approved`, `orchestrating-feature`, `iterating-to-completion`
- **Gateways:** `gateway-api`, `gateway-backend`, `gateway-database`, `gateway-deploy`, `gateway-frontend`, `gateway-testing`
- **Scaffolds:** `scaffold-api`, `scaffold-cli`, `scaffold-deploy`, `scaffold-library`, `scaffold-tui`, `scaffold-webapp`, `migration`, `auth`, `component`, `testing`
- **Review/QA:** `reviewer`, `qa`, `reviewing-architecture`, `reviewing-product-strategy`, `rplan-review`
- **Meta/infra:** `reflect`, `retro`, `sync`, `rupdate`, `init-env`, `prompt`, `prd`, `dispatching-parallel-agents`, `persisting-progress-across-sessions`, `persisting-agent-outputs`, `documenting-release`, `brainstorm-feature-options`, `breadboarding-workflow`, `shaping-requirements`

Within each zone, the rewritten descriptions must collectively partition the trigger space — no two should fire on the same prompt.

### Step 3 — Draft rewrites (batched per zone)
One zone at a time. For each skill needing a rewrite, produce the new `description:` line. Output appended to `skill-audit-table.md` as a "Proposed" column.

### Step 4 — Human review gate (BLOCKING)
Present the proposed-rewrites table. User approves or annotates. No edits to SKILL.md files until this gate clears.

### Step 5 — Apply
Per-file `Edit` of the `description:` line only. No body changes, no other frontmatter changes. One commit per zone for clean revert if a zone goes wrong.

### Step 6 — Verify
After each zone's commit, sanity-check by re-listing skills as the harness would see them (description excerpts) and confirming sibling differentiation reads correctly to a cold reader.

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| Rewrites change skill-invocation behavior in unexpected ways | Per-zone commits — bisect-friendly |
| Over-editing: rewriting descriptions that already work | Rubric scoring gate — score ≥3/4 means leave it |
| Sibling-zone partition is wrong | User approval gate before any file edit |
| Loose `.md` agent files at root get touched | Scope explicitly excludes them; only edit `*/SKILL.md` |

## Success criteria

- [ ] Every SKILL.md description scores ≥3/4 against the rubric
- [ ] Within each collision zone, descriptions are mutually exclusive on trigger conditions
- [ ] No skill body or non-`description` frontmatter modified
- [ ] One commit per zone, each with a clear message
- [ ] Audit table preserved at `skill-audit-table.md` (becomes the artifact for future audits)

## Confidence

**85%.** Open unknowns:
1. Does the harness read the `trigger:` field on rich-frontmatter skills (gateways, scaffolds), or only `description`? If `trigger:` is also consumed, this audit is incomplete.
2. Is there telemetry showing which skills currently fire incorrectly? Would let me prioritize zones by real failure rate instead of guessing.
3. The `gateway-*` skills all have near-identical descriptions ("Route X tasks to the right library skill"). Are they meant to be invoked by the user, or as internal routers called by other skills? That changes the rubric for them.

Will resolve unknowns 1 and 3 before Step 3 (drafting). Unknown 2 is nice-to-have, not blocking.

## Estimated effort

- Step 1 (extract & score): 30 min
- Step 2 (group): 10 min
- Step 3 (draft, all zones): 90 min
- Step 4 (review gate): user time
- Step 5 (apply): 30 min
- Step 6 (verify): 20 min

**Total active work:** ~3 hours, gated on user review between Step 3 and Step 5.
