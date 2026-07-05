# Plan — /build proto-fidelity gate (inverse of proto 5d)

**Status:** Implemented (4 edits applied to config/skills/build/SKILL.md; 7/7 success criteria verified)
**Source PRD:** none (standalone `/rplan`) — no lock check applies
**Behavior Spec:** N/A — edits a *skill's prose*, not a user-facing app surface (no UI/DB/API/role).
Template's full-stack sections + Step 2.5 flow doc are N/A by construction.
**Risk:** MED — changes the per-slice loop of the autonomous build skill; blast radius LOW-MED (prose;
worst case a false-positive **blocks a build slice** — mitigated by tight skip conditions + blocking-but-
recoverable severity, never an unrecoverable abort).
**Appetite:** ~2 core edit tasks (+2 trivial). Small edit; recut not in question.
**Kill-if:** the gate false-positives on a legitimate slice (backend, no-proto, or an intentional
notes-updated deviation) — if a dry-read shows any correct slice tripping it, tighten the skip/deviation
conditions before shipping.
**Pairs with:** `proto-grounding-gate-plan.md` (already implemented, branch `proto-grounding-gate`) —
that gates the proto *side*; this gates the build *side* of the same handoff.

## Problem (one line)
`/build` consumes the proto handoff **softly** (SKILL.md:145 "Optional… promote instead of re-picking
from scratch" — unverified), so a shipped slice can silently re-invent UI and drift from the approved
look even when proto was faithful. Add the inverse of proto's 5d provenance grep.

## Concrete Example Output (what changes, concretely)

**Before:** build implements slice 1 (sign-in). The notes say promote `components/LoginScreen`. Build
hand-rolls a bespoke sign-in form instead. Nothing greps the shipped code → drift ships silently
(the pipeline-studio failure, now on the build side).

**After — step 3.5 runs (user-facing slice + proto notes present):**
```
PROTO-FIDELITY: slice 1 — re-invented LoginScreen (bespoke markup; components/LoginScreen not imported
in the shipped slice) → blocking. Import the promoted component per
tasks/proto-builder-workflow-studio-notes.md, then re-run step 3.5.
```
On a clean slice: `PROTO-FIDELITY: slice 1 — 3 promoted components verified (LoginScreen, SaasBar, tokens)`.
On a backend slice: `PROTO-FIDELITY: slice 3 — skipped (backend slice, no user-facing surface)`.

---

## Steps

| # | File · anchor | Change | Risk | Test (grep / dry-read on edited file) | Committable |
|---|---------------|--------|------|----------------------------------------|-------------|
| 1 | `config/skills/build/SKILL.md` — new **step 3.5**, inserted after step 3 (`…between slices.)` @318) and before `### 4. /saki-builder:qa` @320 | Add **`### 3.5. Proto-fidelity gate — promote the real components, don't re-invent (user-facing slice + proto handoff only)`**: (a) gate — run only when `tasks/proto-<prd-slug>-notes.md` exists AND the slice is user-facing, else skip + log `PROTO-FIDELITY: slice N — skipped (…)`; (b) inverse-5d grep — for each real component the notes name for this slice's screen(s), confirm the slice's real implementation imports it by its recorded path (`grep -Rl "<recorded-import-path>" <slice's real route/component dir>`; empty ⇒ re-invented); (c) severity — blocking-but-recoverable (same bar as a `/reviewer` correctness block): fix in place, re-run the gate, do NOT advance to step 4 while a promoted component was re-invented; (d) legitimate-deviation note — the step-5.5 security reshape already re-proto's + updates notes, so an intentional change keeps the grep matching; a deviation that didn't update the notes is drift → reconcile. State it is the **inverse of proto's 5d**. | MED | grep `Proto-fidelity gate` = 1, between line 312 and the `### 4.` anchor; block contains `proto-<prd-slug>-notes.md`, `grep -Rl`, "inverse", "skip", "blocking" | Yes |
| 2 | `config/skills/build/SKILL.md` — the `### Optional: reuse a /saki-builder:proto preview if one exists` section @145–153 | Reword so promotion is **not discretionary when notes exist**: retitle to `### Reuse the /saki-builder:proto preview when one exists (verified at step 3.5)`; body keeps "if no proto notes exist, build normally" but states that **when notes exist, promoting the named components is required and verified by step 3.5** — not left to model discretion. | LOW | grep new title present; body references "step 3.5" and keeps the "no proto notes → build normally" branch | Yes |
| 3 | `config/skills/build/SKILL.md` — `**Loop until issue-free:**` done-definition @390 | Append a clause: a slice **with a proto handoff** is "done" only when **step 3.5 (Proto-fidelity) also passes** (alongside qa green + reviewer clean + security audit clean). | LOW | grep the done-definition line now contains "3.5" / "Proto-fidelity" | Yes (group w/ 1) |
| 4 | `config/skills/build/SKILL.md` — **Rules** @452, after the `Never fake green` bullet @463–464 | Add ONE bullet: *Promote, don't re-invent* — when a proto handoff exists, the shipped user-facing slice MUST import proto's named components; step 3.5 verifies it (inverse of proto 5d); re-invention is a blocking finding, not a silent choice. | LOW | grep new bullet present; names step 3.5 + "inverse" + proto notes | Yes (group w/ 1) |

Step 1 is the substance; 2–4 are wiring/consistency, committed with it as one atomic change. Apply
**bottom-up** (452 → 390 → 145 → 312) so earlier inserts don't shift later anchors.

## No-Gos
- Do NOT add the **visual screenshot-diff** here (heavier; explicit follow-up) — this gate is
  import-provenance only, the true inverse of 5d.
- Do NOT make the gate fire on a **backend / no-user-facing** slice or a **no-proto-notes** run — skip + log.
- Do NOT make it an unrecoverable abort — blocking-but-recoverable (fix + re-run), like qa/reviewer.
- Do NOT touch `config/skills/proto/SKILL.md` (done) or any project file.
- Do NOT re-elicit or duplicate the step-5.5 security-reshape re-proto path — reference it as the
  legitimate-deviation case; don't re-implement it.

## Success Criteria (hardened — `[auto]` grep unless noted)

1. **Step 3.5 exists, placed correctly** — `grep -n "Proto-fidelity gate" config/skills/build/SKILL.md`
   → the step-header hit sits between line 312 (`### 3.`) and the `### 4. /saki-builder:qa` line. `[auto]`
2. **Gate is conditional + skips cleanly** — its block contains `proto-<prd-slug>-notes.md`, a
   user-facing condition, and a `skipped (` log token. `[auto]`
3. **Inverse-5d grep + blocking severity** — block contains `grep -Rl`, the word `inverse`, and
   `blocking` (recoverable, "re-run"/"fix in place"), and does NOT contain an "abort"/"HARD STOP whole
   build" instruction. `[auto]`
4. **Reuse section reworded** — the `@145` section title no longer starts with "Optional:"; body
   references `step 3.5` AND retains a "no proto notes → build normally" branch. `[auto]`
5. **Done-definition updated** — the `Loop until issue-free` line now names step 3.5 / Proto-fidelity. `[auto]`
6. **Rules bullet added** — one new bullet naming step 3.5 + "inverse" of proto 5d. `[auto]`
7. **No false positive** — dry-read: a backend slice, a no-proto-notes run, and an intentional
   notes-updated deviation all pass/skip the gate; only a genuine re-invention (named component absent
   from the shipped slice) blocks. `[manual dry-read]`

## Confidence Ledger
Reference verification (§4a): every anchor is a heading/line verified by grep (line numbers match the
context file's `grep -nE`). Targets are new prose blocks with a named anchor section + creating step # +
unique identifier ("Proto-fidelity gate"). Applicable checklist items satisfied; full-stack items
(migration/API/role/flow-doc) genuinely N/A for a skill-prose edit (header), not skipped.

| Entry | Δ | Cite |
|-------|---|------|
| Prose-consistency correctness (gate severity is recoverable-not-abort; skip conditions complete; reuse-section reword doesn't contradict step 3.5) is verified by **dry-read judgement** (criterion 7 `MANUAL`), not a machine check — genuine LOW residual: a minor wording tweak may surface on apply | −3 ×1 = −3 | criterion 7 |

Edit-ordering (anchor drift) resolved by the bottom-up method above — not a standing deduction. By the
§4b standard table there are no anchor/target/vague/checklist deductions.

**Score = 100 − 3 = 97%.**

One cited residual, LOW-impact, verification-*method* on a reversible prose edit — not correctness. No
unknowns above LOW.

---

## Recommendation
97% · MED risk · LOW-MED blast radius. The single −3 is the inherent "prose consistency is verified by
dry-read" residual; the false-positive risk (which is the real hazard, since this gate blocks a build
slice) is contained by tight skip conditions + blocking-but-recoverable severity + the notes-are-source-
of-truth deviation rule, and checked by criterion 7. Clears the ≥96% bar honestly. Ready for
`/saki-builder:approved`.
