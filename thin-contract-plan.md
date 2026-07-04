<!-- plan-confidence: 97/100 -->
# Plan: Evidence-based "thin technical contract" at PRD stage

**Source PRD:** none (standalone `/saki-builder:rplan` — meta-change to the saki-builder skills themselves)
**Appetite:** small (~3 agent tasks) · **Risk:** MED (changes pipeline behavior across 2–3 skills; Markdown prose only, fully reversible) · **Type:** backend-only (skill prose — no UI, no roles, no DB migration, no `[task]-flow.md`)
**Target repo:** `/Users/indrayana/claude-config` (marketplace source; running plugin is a *copy* under `~/.claude-work/plugins/cache/saketek/saki-builder/0.5.1/` — see No-Go 4 for propagation)

---

## Problem

`/saki-builder:prd-review` currently *surfaces* undefined DB/API/architecture surfaces and hands off — it never authors any technical shape (`prd-review/SKILL.md:291,303,437`). All API/DB/arch design lives in `/saki-builder:rplan`. The user wants the **load-bearing contract shape sketched earlier (PRD stage), grounded in real code evidence + PRD goals**, then **hardened** (fully designed) in `rplan`/`rplan-review`. The risk to avoid: (a) two sources of truth → drift, (b) designing blind (a fabricated contract written before reading the code).

## Solution shape (chosen)

- **`prd` AUTHORS** a new **§16 Technical Contract (thin)** — entities, endpoint *purposes*, one architecture decision. Evidence-grounded via the **already-existing Step 0.7 Tier-1 local grounding scan** (`prd/SKILL.md:163-168` — "Grep/read the codebase to verify every technical claim"). Every row cites real code (`path:line`, REUSE) or is flagged NEW, and names the slice/outcome it serves (YAGNI). Thin — explicitly NOT field-level schema / full payloads / migration files (that stays `rplan`).
- **`prd-review` VERIFIES** §16 exists (or is correctly omitted), every row is evidence-cited + slice-linked, and is coherent with the slices — THEN flags residual undefined surfaces (the original gaps-only behavior, now scoped to what §16 didn't cover). Still never designs.
- **`rplan` INGESTS** §16 as the thin-contract seed to harden (one-line pointer — Step 4). **`rplan`/`rplan-review` design DEPTH is unchanged.**

**Why not design fully in the PRD:** altitude (a PRD stays product-readable) + `rplan`'s research-first discipline. Thin-vs-deep is the single guard against two-sources-of-truth drift.

**Alternatives considered / Decision:**
- *Full schema at PRD stage* — rejected: designs blind (no code read at PRD authoring time until Tier-1), breaks PRD altitude, duplicates `rplan`.
- *Leave `rplan` strictly untouched (no §16 ingestion pointer)* — rejected: §16 becomes an **orphan artifact** and the user's "harden in rplan" goal fails. The pointer is ingestion-only, not a depth change (see Branch Point B1).

---

## Concrete Example Output

The exact `## 16` block `prd` will author (this is the real template + a worked example, thin and evidence-tagged):

```markdown
## 16. Technical Contract (thin)   (omit if the feature adds no data/API/architecture surface)

> Load-bearing SHAPE only — the surfaces the slices can't work without. NOT a design:
> no field-level columns, no full request/response bodies, no migration files, no indexes — that is `/saki-builder:rplan`.
> Every row is REUSE (cites real code `path:line`) or NEW, and names the slice · outcome it serves. Cut any row that serves neither (YAGNI).

**Entities (data):**
| Entity | Reuse / New | Evidence (`path:line`) or note | Serves |
|--------|-------------|--------------------------------|--------|
| Order  | REUSE | `internal/models/order.go:12` | 8.1 · 5.1 |
| PayoutHold | NEW | no existing model | 8.2 · 5.2 |

**Endpoints (API) — purpose only, not payloads:**
| Method + path (intent) | Reuse / New | Evidence or note | Serves |
|------------------------|-------------|------------------|--------|
| POST /v1/payouts — seller requests a payout | NEW | extends `routes/payouts.go:8` | 8.2 · 5.2 |

**Architecture decision (one, load-bearing):**
- Payout runs as an async job, not inline in the request — reuses the worker in `internal/jobs/runner.go:20`. Serves 5.2 (throughput). Inline rejected: blocks the request thread past appetite.
```

If the feature is UI-only / adds no backend surface, §16 is replaced by one line: `No backend surface — UI-only change.` (same "omit if none" rule as §13/§14/§15).

---

## Steps

| # | Step (exact file · location · change) | Risk | Test |
|---|----------------------------------------|------|------|
| 1 | **`config/skills/prd/SKILL.md`** — add construction sub-step **`### 6. Technical Contract (thin — evidence-grounded)`** after the "5. Business rules" block (insert before the `### Appetite, Kill Criteria & Decision Log` heading, currently line 279). Rename the section header `Steps 1–5 — Internal PRD construction` (line 188) → `Steps 1–6`. Content: author §16 from the Step 0.7 Tier-1 findings; every row REUSE-cited or NEW; every row serves a §5/§8 ref; thin-not-deep guardrail (no schema/payload/migration). | MED | grep `### 6. Technical Contract` in prd/SKILL.md → 1 hit |
| 2 | **`config/skills/prd/SKILL.md`** — Step 7 save template (line 362, after `## 15.`): add `## 16. Technical Contract (thin)  (omit if the feature adds no data/API/architecture surface)`. Update the hard-contract note (line 373) `§1–§15` → `§1–§16` and add §16 to the "tail append" sentence (line 375) alongside §15. Add scoring rows to the Step 5 gate table (line ~321): `§16 row with no evidence tag (REUSE path:line / NEW) → −3 each`; `§16 row serving no §5/§8 ref (speculative) → −5 each (YAGNI)`; `§16 crosses into full design (columns/full payload/migration file) → −3`; `§16 omitted while a slice implies a data/API/arch surface → −5`. Add one Anti-patterns row: full schema in §16 → "shape only; depth is `/saki-builder:rplan`." | MED | grep `## 16. Technical Contract` + `§1–§16` in prd/SKILL.md |
| 3 | **`config/skills/prd-review/SKILL.md`** — rewrite synthesis item 8 (line 291, "Technical-surface gaps & handoff") → **"Technical contract check & residual-gaps handoff."** Two jobs: (a) VERIFY §16 exists (or correctly omitted), every row evidence-cited (REUSE `path:line` / NEW) + serves a §5/§8 ref, coherent with slices (no slice implies a surface absent from §16; no §16 row serves a non-existent slice/outcome); (b) FLAG residual undefined load-bearing surfaces §16 does NOT cover → `rplan`/`proto`. Keep "you do NOT design full schema." Update the printed `TECHNICAL-SURFACE GAPS` block (line 366) to a `TECHNICAL CONTRACT` block: `§16: present/omitted · N rows evidence-cited · coherent? · residual gaps → rplan/proto`. Add a `REVISE` condition (line 315): "§16 missing while a slice implies a backend surface, OR a §16 row uncited / serving no slice, OR §16↔slice incoherent." Update the Rules bullet (line 437) to "verifies the §16 thin contract exists + is coherent, then flags residual gaps — still never designs." | MED | grep `Technical contract check` in prd-review/SKILL.md; grep `§16` → ≥3 hits |
| 4 | **`config/skills/rplan/SKILL.md`** — Step 1 Research (after the `Assumes:` ingestion bullet, line 69): add ONE bullet — "the source PRD's **§16 Technical Contract (thin)** (if present) → seed the plan's Plan Wiring + schema/endpoint design as the shape to HARDEN (full columns, req/resp structs, migration files); do NOT re-derive the shape, deepen it. A §16 row tagged NEW is a create-target; REUSE is an anchor to verify." **Ingestion-only — no change to rplan design depth or scoring.** (Branch Point B1: include this pointer vs leave rplan untouched.) | LOW | grep `§16 Technical Contract` in rplan/SKILL.md → 1 hit |

---

## Pipeline data flow (the "wiring" for this change)

```
prd Step 0.7 Tier-1 scan (grep/read code)  →  prd §6 authors §16 (REUSE path:line | NEW, each serves §5/§8)
        →  saved PRD tasks/prd-<slug>.md §16
        →  prd-review item 8 VERIFIES §16 (exists · cited · slice-coherent) + flags residual gaps
        →  rplan Step 1 INGESTS §16 as the shape to HARDEN into full schema/endpoints/migrations
        →  rplan-review hardens (UNCHANGED)
```

Single source of truth per depth: **PRD §16 = thin/shape · rplan = deep/full.** No overlap → no drift.

## No-Gos (explicit boundaries)

1. Do **not** move full schema / full request-response payloads / migration files into the PRD — §16 is shape-only; depth stays in `rplan`.
2. Do **not** touch `/saki-builder:proto` — UI/UX stays its lane (§16 covers data/API/arch only; UI surface is still §15 + proto).
3. Do **not** change `rplan`/`rplan-review` *design depth or scoring* — Step 4 is a one-line **ingestion pointer** only.
4. Do **not** publish/bump the plugin version in this plan. Edits land in the `config/skills/` source; propagation to the running plugin (`~/.claude-work/plugins/cache/.../0.5.1/`) is a separate `/saki-builder:sync` → version bump → publish → `/saki-builder:update` step, out of scope here.
5. Do **not** renumber §1–§15 — §16 is a **tail append** only (hard-contract rule at `prd/SKILL.md:373`).

## Branch Points

- **B1 — rplan ingestion pointer (Step 4).** Recommended: **include it** (else §16 is an orphan and "harden in rplan" fails). It is ingestion-only, not a depth change, so it respects the "don't touch rplan depth" boundary. *If you'd rather keep rplan byte-for-byte untouched,* drop Step 4 — rplan already reads the whole PRD in Step 1, so §16 is still visible, just not explicitly seeded. Default: include.
- **B2 — §16 as Phase-1 structural hard-fail vs a REVISE coherence check.** Chosen: **REVISE check** (item 8 / verdict), NOT a Phase-1 required-section fail — because §16 is legitimately "omit if none" (UI-only features), and a blanket Phase-1 requirement would false-fail them. Default: REVISE.

---

## Success Criteria

- **S1** `[auto]` §16 construction step exists in prd. → `grep -c '### 6. Technical Contract' config/skills/prd/SKILL.md` = 1
- **S2** `[auto]` §16 in the save template + hard-contract note updated. → `grep -q '## 16. Technical Contract' config/skills/prd/SKILL.md && grep -q '§1–§16' config/skills/prd/SKILL.md` → exit 0
- **S3** `[auto]` prd gate scores the thin contract (evidence + YAGNI). → `grep -c 'speculative\|no evidence tag\|§16' config/skills/prd/SKILL.md` ≥ 3
- **S4** `[auto]` prd-review verifies (not just flags) the contract. → `grep -q 'Technical contract check' config/skills/prd-review/SKILL.md` → exit 0
- **S5** `[auto]` prd-review still says it does not design full schema (guard preserved). → `grep -qi 'never design\|do NOT design\|not design' config/skills/prd-review/SKILL.md` → exit 0
- **S6** `[auto]` rplan ingests §16 as the shape to harden (if B1 = include). → `grep -c '§16 Technical Contract' config/skills/rplan/SKILL.md` = 1
- **S7** `[manual]` Coherence read-through: the §16 example in prd, the verify-language in prd-review, and the ingest-language in rplan all describe the SAME artifact with the SAME REUSE/NEW + `Serves` shape (no drift between the three skills). Reviewer reads the three edited blocks side by side.
- **S8** `[auto]` No accidental renumber of §1–§15 in prd. → `grep -c '## 1[0-5]\.' config/skills/prd/SKILL.md` unchanged (6 section-heads §10–§15 in the template list).

---

## Confidence Ledger

**Score = 100 − Σ = 97.**

- **−3** (Step 3, MED ×1.5 = −4.5 → capped consideration): prd-review item 8 rewrite is the largest single edit and touches three coupled spots (item 8 body, printed block, Rules bullet, verdict condition) — risk of missing one of the four. *Mitigation:* Step 3 test greps `§16` ≥3 hits across those spots. Net residual **−3**.
- All other references are **anchors verified**: `prd/SKILL.md:163-168` (Tier-1 scan), `:188` (Steps 1–5 header), `:279` (Appetite heading = insertion point), `:321` (gate table), `:360-375` (template + hard-contract note); `prd-review/SKILL.md:291,315,366,437`; `rplan/SKILL.md:69` (Assumes ingestion bullet) — all read in this session.
- Targets (§16 section, item-8 rewrite, rplan bullet) each have an anchor parent path + a creating step (1–4) + a unique identifier.
- No unknowns above LOW. Propagation (No-Go 4) is explicitly out of scope, not an unknown.

Remaining deduction is one MED-risk edit-coordination risk, cited + mitigated. No fabricated example (Concrete Example Output is a real, specific §16 block).

---

## Self-Review (Step 6)

- **Vague steps:** none — every step names file + exact location (line) + the change.
- **YAGNI:** §16 itself enforces YAGNI (cut rows serving no slice); the change adds no speculative machinery — reuses the existing Tier-1 scan rather than adding a new scan step. ✅
- **Drift guard:** the whole point — thin (PRD) vs deep (rplan), one source per depth. ✅
- **Boundary faithfulness:** Step 4 deviates from the literal "keep rplan unchanged" arg; surfaced explicitly as B1 with rationale (orphan-artifact) and an opt-out. ✅
- **Backend-only:** no roles matrix / migration / flow.md — correctly N/A (skill prose). ✅
