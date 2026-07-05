# Context — /build proto-fidelity gate (inverse of proto 5d)

## Task
Add a gate to `config/skills/build/SKILL.md` that verifies a shipped user-facing slice actually
**imported/promoted proto's real components** (per `tasks/proto-<slug>-notes.md`) instead of
re-inventing UI from scratch. The inverse of proto's Step 5d provenance check. Skill-prose edit.

## Why (the seam this closes)
- The paired proto fix (branch `proto-grounding-gate`) stops **proto** from reinventing existing
  components. But `/build` consumes the proto handoff **softly**: `config/skills/build/SKILL.md:145`
  is titled *"Optional: reuse a proto preview if one exists"* and says *"promote … instead of
  re-picking from scratch"* — no verification. So build can still silently re-pick UI and drift from
  the approved look, even when proto was faithful. Nothing greps the shipped slice.
- Symmetry: proto's 5d greps the *preview harness* to prove it imported the real components; this
  greps the *shipped slice* to prove the same. Same mechanism, opposite side of the handoff.

## Build skill structure (verified)
Per-Slice Loop (`## The Per-Slice Loop` @245): step 0 open-question gate @250 · 1 `/rplan` @295 ·
2 `/rplan-review` @303 · 3 `/approved` implement @312 · 4 `/qa` @320 · 5 `/reviewer` @328 ·
5.5 security audit @333 · 6 mark done @386. The `5.5` sub-step sets the precedent for a gated,
conditional loop step. Proto reuse is described @145 (before GATE 1.5), soft/optional.

## Exact anchors in config/skills/build/SKILL.md
| Line | Anchor | Role |
|------|--------|------|
| 145–153 | `### Optional: reuse a /saki-builder:proto preview if one exists` | reword: reuse is MANDATORY-when-notes-exist + verified by new step 3.5 (Step 2 of plan) |
| 312–318 | `### 3. /saki-builder:approved — implement` (ends `…between slices.)`) | new **step 3.5** inserted immediately after (Step 1) |
| 320 | `### 4. /saki-builder:qa …` | insertion boundary — step 3.5 goes before it |
| 333 | `### 5.5. Security audit` | precedent for a gated conditional loop step; also its §2 security-reshape path already re-proto's + updates notes → the gate's "legitimate deviation" case |
| 390 | `**Loop until issue-free:** a slice is "done" only when …` | append step-3.5 clause for slices with a proto handoff (Step 3) |
| 452–468 | `## Rules` | add one bullet (Step 4); insert after the `Never fake green` bullet @463–464 |

## Design decisions
- **Placement:** new **step 3.5 "Proto-fidelity gate"** between implement (3) and qa (4) — catches
  re-invention earliest, before functional QA. Mirrors the existing `5.5` gated-substep pattern.
- **Gated:** runs ONLY when `tasks/proto-<slug>-notes.md` exists AND the slice is user-facing;
  else skip + log one line (`PROTO-FIDELITY: slice N — skipped (no proto notes | backend slice)`).
- **Mechanism:** inverse-5d grep — for each real component the notes name for this slice's screen(s),
  confirm the slice's REAL implementation imports it by its recorded path (mirrors 5d's
  `grep -Rl "<recorded-import-path>"`; where the notes give only a name, resolve the design-system path).
- **Severity:** blocking-but-recoverable — same bar as a `/reviewer` correctness block: fix in place
  (import/promote the named component), re-run the gate; NOT an unrecoverable abort. Consistent with
  how qa/reviewer/security findings loop in this skill (never aborts the whole build on a fixable gap).
- **Legitimate deviation (not a block):** the step-5.5 security reshape already re-proto's + updates
  the notes (@363–370), so an intentional look change keeps the notes current and the grep matches.
  Notes are the source of truth; a deviation that did NOT update the notes is drift → reconcile.

## Out of scope (follow-up, NOT this plan)
- **Visual screenshot-diff** of the built slice against proto's approved `*-page-*.png` — a stronger,
  heavier check (needs the built route running + capture). The inverse of 5d is *import-provenance*,
  not visual; the visual regression is a separate slice.
- The proto skill (already done, branch `proto-grounding-gate`). Project files.

## No source PRD (standalone /rplan). No UI/DB/API/roles → template's full-stack + Step 2.5 flow doc
are N/A by construction (skill-prose edit). Verification = grep + dry-read of the edited skill.
