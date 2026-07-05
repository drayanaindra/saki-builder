# Context — proto grounding-gate enforcement

## Task
Add enforcement teeth to `config/skills/proto/SKILL.md` so a run cannot skip the reuse-first
grounding (Step 2.4 Reuse Map + GATE 1 Screen Manifest). Two changes; no code, no tests — a
skill-prose edit whose verification is internal consistency + a dry-read of gate order.

## Verified failure (do not re-derive)
- Real run: pipeline-studio `tasks/proto-builder-workflow-studio/` — gallery shipped with **no
  `reuse-map.md` and no `screen-manifest.md`** (confirmed by directory listing).
- Consequence: proto re-created components that already exist (`LoginScreen`, `SaasBar`,
  `PipelineGraph`, `StreamPanel` in `apps/web/src/components/`) and invented a "Builder Workflow
  Studio" brand (the roadmap title) instead of the real implemented brand "Saki Studio".
- Root cause: Step 2.4 + Step 5d are labelled BLOCKING **in prose** but nothing mechanically stops
  a FRESH run when their artifacts were never written. The 5d provenance grep iterates Reuse-Map
  rows — with **no** reuse-map.md it has zero rows → **passes vacuously** (the silent hole).
- Only the Step 0.5 **resume** path checks these files exist; a fresh run has no equivalent gate.

## Exact anchors in config/skills/proto/SKILL.md (verified via grep)
| Line | Section | Role in this edit |
|------|---------|-------------------|
| 91  | `## Step 0.5 — Resume detection` | resume ledger already lists GATE 1 (manifest) + 2.4 (reuse-map) as checkpoints 1–2 — the fresh-run gate must be **consistent** with it, not contradict it |
| 140 | `## GATE 1 — Load the PRD` | writes `screen-manifest.md` (BLOCKING artifact) |
| 259 | `## Step 2.4 — Existing-implementation inventory` | writes `reuse-map.md`; **Point 1 name-drift** appended at end of this section |
| 313 | `## Step 2.5` | end boundary for the Step 2.4 insertion |
| 499 | `## Step 5 — Render …` | **Point 2 grounding gate** inserted as the FIRST block here (fail before any harness authoring, still pre-capture) |
| 521 | `### 5a.` | end boundary for the Step 5 top insertion |
| 590 | `### 5d. Mount, mark, serve` | existing provenance grep — the vacuous-pass site; reference the new gate here (no second gate) |
| 676 | `### 6a. Capture` | capture start — the gate must precede this |
| 1121 | `## Coverage Gate` | already checks manifest vs captures; must NOT duplicate the new existence check → reference, don't re-gate |
| 1262 | `## Anti-patterns` | add ONE row |
| 1316 | `## Rules` | add ONE bullet |

## Placement decision
- **Point 2 gate → top of Step 5 (line 499)**, before sub-step 5a. Rationale: Step 5's whole
  premise (compose real components per the Reuse Map) is impossible without reuse-map.md; failing
  here stops before expensive harness authoring + render + capture, and is still "pre-capture."
  Step 5d's provenance and the Coverage Gate then *reference* this gate rather than re-checking
  (no double gate — satisfies the "no contradictory/double gate" constraint).
- **Point 1 name-drift → end of Step 2.4 (before line 313)**, scoped to NEW-only screens (no
  EXISTING/PRIMITIVE match). Reused screens carry the real brand via verbatim import, so the check
  is explicitly noted as redundant there.

## Out of scope (follow-up, not this plan)
- `/build` reuse-provenance gate (inverse of 5d) → `config/skills/build/SKILL.md`.
- Project-level `roadmap.test.ts` assertion → lives in pipeline-studio, not the skill.

## No source PRD (standalone /rplan) — no lock check applies. No UI/DB/API/roles → template's
full-stack + flow-doc (Step 2.5) sections are N/A by construction; noted in the plan header.
