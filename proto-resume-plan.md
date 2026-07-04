# Plan — make `/saki-builder:proto` resumable after a hard stop

**Status:** Approved (user: "yes add that") · **Risk:** MED (new logic in one skill file, prose/instructions only) · **Confidence:** 95%

## Problem
A hard-stopped proto run restarts from zero even though most expensive phases already
persist durable artifacts to `tasks/proto-<slug>/` and the project tree. Root cause: no
resume-detection step reads those artifacts back on re-entry.

## Insight (from reading SKILL.md end-to-end)
The Coverage Gate (lines 1083–1095) already diffs `screen-manifest.md` vs captured PNGs —
that same artifact-presence diff is the checkpoint mechanism a resume needs. Reuse it; do
not invent a separate progress file (artifacts are the source of truth → can't drift; matches
the "verify code state, not a status flag" pattern).

## Change (one file: config/skills/proto/SKILL.md)
1. **Insert `## Step 0.5 — Resume detection`** between Step 0 and GATE 1. Contents:
   - Runs after the PRD path/slug is resolved, before GATE 1 re-writes the manifest.
   - `--restart` forces a clean run; `--figma-only` skips it.
   - Scope guard: a `PARTIAL (--slice=N)` manifest resumes only a matching-scope invocation.
   - Checkpoint ledger (in order), each DONE only when artifact present AND its gate re-verifies:
     1 GATE1=`screen-manifest.md` · 2 Step2.4=`reuse-map.md` · 3 Step2.6=`design-system-updates.md`
     + listed component files + `tsc` · 4 Step5=`proto-preview/*` + 5d provenance/typecheck +
     5c bypass present · 5 Step6a=`proto-capture.mjs`+`hotspots.json`+page PNGs (Coverage-diff;
     re-run capture to fill gaps) · 6 Step6b=`preview.html` · 7 Step8=`proto-<slug>-notes.md` ·
     8 Step8.5=PRD `<!-- prd-locked -->` marker.
   - In-context phases (2.5/3/4) never block resume — their output lives in the artifacts.
   - **Approval is proven only by the lock marker** — an unlocked PRD resumes at Step 7
     (re-present), never auto-lock a run whose approval can't be seen.
   - Partial-write safety: a failing re-verify gate ⇒ checkpoint NOT DONE ⇒ re-enter that phase.
   - Announce one line, then auto-resume (inherits proto's auto-proceed ethos).
2. **Input section:** add `[--restart]` to usage + one sentence.
3. **Rules:** one bullet — "Resumable: a hard stop resumes at the next incomplete phase (Step 0.5)."
4. **Anti-patterns:** one row — restarting from zero when a partial gallery exists.

## Success criteria
- [auto] `grep -c 'Step 0.5 — Resume detection' SKILL.md` == 1
- [auto] `grep -c '\-\-restart' SKILL.md` >= 2 (Input + Step 0.5)
- [auto] the checkpoint ledger table lists all 8 phases with a re-verify column
- [manual] section reads in the skill's voice; approval-via-lock and scope-match guards present
- [auto] no other Step numbers renumbered (Step 0.5 is additive, not a shift)

## Non-goals
- No change to the capture script, Coverage Gate logic, or lock mechanism.
- No separate progress/state file — artifact presence is the checkpoint.
