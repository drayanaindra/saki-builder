# Plan — proto grounding-gate enforcement

**Status:** Implemented (all 5 edits applied to config/skills/proto/SKILL.md; 7/7 success criteria verified)
**Source PRD:** none (standalone `/rplan`) — no lock check applies
**Behavior Spec:** N/A — this edits a *skill's prose*, not a user-facing app surface (no UI/DB/API/role).
Template's full-stack sections (migrations, API layer, Role matrix) and Step 2.5 flow doc are N/A by construction.
**Risk:** MED — changes the behavior of a load-bearing pipeline skill; blast radius LOW (prose; worst case an over-strict gate hard-stops a run with a clear, revertible message).
**Appetite:** ~2 core edit tasks (+3 trivial). Well within a small edit; recut not in question.
**Kill-if:** the new gate would fire on a *legitimately complete* run (false positive) — if a dry-read shows any correct run tripping it, redesign the condition before shipping.

---

## Problem (one line)
Step 2.4 (Reuse Map) + Step 5d (provenance) are prose-BLOCKING but a fresh run with **no
`reuse-map.md` / `screen-manifest.md`** renders anyway and the 5d grep passes **vacuously** (zero rows),
so proto reinvents existing components and invents brands. Add a mechanical pre-render gate + a
net-new name-drift check.

## Concrete Example Output (what changes, concretely)

**Before (the real pipeline-studio run):** no `reuse-map.md` written → Step 5 renders bespoke
`SignIn`/`SaasBar`/`BuildView` → 5d provenance has no rows to check → passes → gallery ships with
"Builder Workflow Studio" ⚡ brand and an approximated build view. No stop, no warning.

**After — Point 2 (grounding gate at top of Step 5):**
```
HARD STOP — GROUNDING MISSING
Step 5 cannot render: tasks/proto-<slug>/reuse-map.md is absent (or empty).
The Reuse Map (Step 2.4) + Screen Manifest (GATE 1) are the reuse-first contract every render
composes against. Without them, proto reinvents existing components (the exact drift this gate
prevents). Write both (re-run Step 2.4 / GATE 1), then resume at Step 5.
Missing: reuse-map.md.   Present: screen-manifest.md (12 rows).
```

**After — Point 1 (name-drift, net-new screen only):** for a genuinely-new screen that shows the
product name, proto resolves the brand from the real shell and, on mismatch, emits (instead of
typing the spec title):
```
NAME DRIFT — new screen "Sign in": spec/roadmap name "Builder Workflow Studio" ≠ the brand the
implemented UI renders ("Saki Studio", apps/web/src/components/TopBar.tsx). Reconcile before render:
use the implemented brand, or confirm this is an intentional rebrand (then it is a real-code change,
not a proto tweak). Not auto-choosing.
```

---

## Steps

| # | File · anchor | Change | Risk | Test (dry-read / grep on edited file) | Committable |
|---|---------------|--------|------|----------------------------------------|-------------|
| 1 | `config/skills/proto/SKILL.md` — top of **Step 5** (after the `## Step 5 —` heading @499, before its intro para and `### 5a.` @521) | Insert a bolded **`Grounding gate (BLOCKING — Reuse Map + Screen Manifest must exist before any render)`** block: on a non-`--restart`, non-`--figma-only`, non-`no-UI` run, assert `tasks/proto-<slug>/reuse-map.md` AND `tasks/proto-<slug>/screen-manifest.md` exist and are **non-empty** (`[ -s file ]`); on failure emit the Concrete-Example HARD STOP and stop (return to Step 2.4 / GATE 1). Explicitly state it complements — does not duplicate — Step 0.5 (resume), 5d (provenance), and the Coverage Gate. | MED | grep `Grounding gate` @ Step 5 returns 1; block names both `reuse-map.md` + `screen-manifest.md` + `-s`; dry-read: gate sits before `### 5a.` and before `### 6a.` capture | Yes |
| 2 | `config/skills/proto/SKILL.md` — end of **Step 2.4** (after the Reuse-Map explanation, before `## Step 2.5` @313) | Append **Name-drift check (net-new screens only)**: for a screen with NO EXISTING/PRIMITIVE Reuse-Map row that renders the product/brand name, resolve the brand string from the real shell/design system (grep the real shell for the rendered brand literal), and if the PRD/roadmap product name differs, FLAG for reconciliation (per GATE 1's two-way rule) rather than typing the spec title. State it is **redundant for reused screens** (verbatim import already carries the real brand) and is a flag, not an auto-choice. | LOW | grep `Name-drift` @ Step 2.4 returns 1; text contains "net-new"/"new screen" scoping + "redundant" note + "reconcile" (not auto-pick) | Yes |
| 3 | `config/skills/proto/SKILL.md` — **Anti-patterns** table @1262 | Add ONE row: *Rendering/capturing with no `reuse-map.md`/`screen-manifest.md` written (5d passes vacuously)* → *Grounding gate (Step 5) hard-stops before any render; the Reuse Map is the contract 5d checks against.* | LOW | grep new row present; references both files + Step 5 | Yes (group w/ 1,2) |
| 4 | `config/skills/proto/SKILL.md` — **Rules** section @1316 | Add ONE bullet under the reuse rule: the reuse-first grounding is **mechanically gated** — a run with no Reuse Map / Manifest HARD-STOPS at Step 5, never renders; prose-BLOCKING alone is insufficient (it failed once). | LOW | grep bullet present; names Step 5 gate + both artifacts | Yes (group w/ 1,2) |
| 5 | `config/skills/proto/SKILL.md` — **5d** @590 + **Coverage Gate** @1121 | One-line reference each: 5d notes the Reuse Map is guaranteed present by the Step 5 grounding gate (so a vacuous pass is impossible); Coverage Gate notes manifest existence is already assured by the same gate. **No new check added** in either — reference only (prevents double gate). | LOW | dry-read: neither location adds a second existence assertion; both cite the Step 5 gate by name | Yes (group w/ 1,2) |

Steps 1–2 are the substance; 3–5 are the consistency wiring, committed together as one atomic change.

**Implementation edit order (method — removes anchor drift):** apply edits **bottom-up** —
1316 (Rules) → 1262 (Anti-patterns) → 590 (5d ref) → 499 (Step 5 gate) → 259 (Step 2.4) — so each
insertion never invalidates a later, lower-line anchor. Re-grep an anchor if a prior edit changed
line counts above it.

## No-Gos
- Do NOT add a second existence check in 5d or the Coverage Gate (double gate) — reference only.
- Do NOT make the name-drift check fire on reused screens, or auto-pick a brand — it flags only.
- Do NOT touch `config/skills/build/SKILL.md` or any pipeline-studio file (out of scope).
- Do NOT weaken/reword existing gates (GATE 1, 2, 2.4, 5d, Coverage, Step 0.5) beyond the two 1-line references in Step 5.
- Do NOT make the gate fire on `--restart`, `--figma-only`, or the no-UI PRD branch (they legitimately lack these artifacts at that point).

## Success Criteria (hardened — all `[auto]` via grep/dry-read on the edited file)

1. **Grounding gate exists & is placed correctly** — `Given` the edit is applied, `When`
   `grep -n "Grounding gate" config/skills/proto/SKILL.md`, `Then` exactly 1 hit whose line number is
   > 499 (Step 5) and < 674 (Step 6). `[auto]`
2. **Gate names both artifacts + non-empty test** — `grep -A20 "Grounding gate" …` contains
   `reuse-map.md`, `screen-manifest.md`, and a non-empty test (`-s`). `[auto]`
3. **Escape hatches honored** — the gate block text names `--restart`, `--figma-only`, and the no-UI
   branch as skip conditions (`grep` finds all three within the block). `[auto]`
4. **Name-drift check exists, net-new-scoped, flag-only** — `grep -n "Name-drift"` returns 1 hit
   within Step 2.4 (line 259–313); its block contains a net-new scoping word ("new screen"/"net-new"),
   "redundant" (reused note), and "reconcile" (not an auto-pick). `[auto]`
5. **Anti-pattern row + Rules bullet added** — one new row after line 1262 and one new bullet after
   line 1316, each naming the Step 5 gate + both artifacts. `[auto]`
6. **No double gate** — dry-read of 5d (590) and Coverage Gate (1121): neither adds a NEW existence
   assertion; each contains a one-line *reference* to the Step 5 gate. `[manual dry-read]`
7. **No false positive** — dry-read trace of a correct full run (GATE 1 writes manifest → Step 2.4
   writes reuse-map → Step 5): the gate passes. And a `--restart` / `--figma-only` / no-UI run: the
   gate is skipped. `[manual dry-read]`

## Confidence Ledger
Reference verification (§4a): every anchor is a section heading verified by grep (line numbers in the
Steps table match the `grep -nE` output in the context file). All "targets" are new prose blocks with a
named anchor section + a creating step # + a unique identifier ("Grounding gate", "Name-drift check").
All applicable Implementation-Checklist items satisfied; the full-stack items (migration/API/role/flow-doc)
are genuinely N/A for a skill-prose edit (stated in header), not skipped.

| Entry | Δ | Cite |
|-------|---|------|
| Prose-consistency correctness (no double gate, gate reads cleanly, escape hatches complete) is verified by **dry-read judgement** (criteria 6–7 `MANUAL`), not a machine check — a genuine LOW residual: on apply I may need a minor wording tweak in the 5d/Coverage reference lines | −3 ×1 = −3 | criteria 6, 7 |

Edit-ordering risk (anchor drift) is **resolved** by the bottom-up edit-order method above — not a
standing deduction. By the §4b standard table there are no anchor/target/vague/checklist deductions.

**Score = 100 − 3 = 97%.**

One cited residual, LOW-impact, about verification *method* on a reversible prose edit — not correctness.
No unknowns above LOW.

---

## Recommendation
97% · MED risk · LOW blast radius. The single −3 is the inherent "prose consistency is verified by
dry-read, not a machine" residual (criteria 6–7), which is the correct verification for a skill-prose
change; the edit-ordering risk is resolved by the bottom-up method. Clears the ≥96% present bar honestly.
Ready for `/saki-builder:approved`.
