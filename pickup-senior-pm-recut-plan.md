# Plan — `/pickup` gains a Senior-PM scope-recut path

**Status:** Implemented + dry-run-hardened (Option A) · **Risk:** MED (core workflow skill) · **Date:** 2026-07-08

## Dry-run (trace simulation — plugin not released, can't invoke live)
- **Negative case (real fixture E1 · self-service-order-cancellation, verdict DISCOVERY-FIRST):** new branch
  routes DISCOVERY-FIRST → plain blocked, identical to today. Guard holds — no recut past an unproven premise. ✅
- **Positive case (constructed E3 · seller-analytics, non-convergence):** happy path holds (Step 5 reduces to
  "register phases → internally /pickup the MVP"), but the trace surfaced **3 must-fix holes**, now fixed:
  1. Step 1 didn't ask senior-pm for a full 5-field shape → Step 3 `/add` had no JTBD/flow inputs → broke
     autonomy. **Fixed:** Step 1 now requires a complete PRD-track shape per phase.
  2. Stop-gate circuit breaker scores `phase-ordinal + review.rounds`; recut runs at flat `phase:review`, so a
     multi-turn recut could trip `no_progress>5` and release the run mid-recut. **Fixed:** bump `review.rounds`
     on every Phase-2b state write; carry it forward (don't reset) on re-point.
  3. "Recut once" had no detection → a child MVP that non-converges would recut recursively. **Fixed:**
     once-guard = `recut` block present AND `slug == recut.active` → plain-blocked, never re-enter Phase 2b.
- Polish also applied: sequential `/add` (id-counter race), resume row resolves `recut.active` from roadmap,
  parent `Child PRD:` marked superseded by `Phase chain:`.

## Goal
When `/pickup`'s PRD review dead-ends on a **scope** blocker, stop dying. Instead act as a
Senior PM: recut the initiative into an MVP + trigger-gated follow-on phases, register each
phase on the roadmap via `/add`, and continue driving to green. Faithful to the existing
architecture (reuse `senior-pm`, `/add`, `/prd`, `/prd-review`; no new hook).

## What exists (verified, reuse-first)
- `/pickup` (`config/skills/pickup/SKILL.md`) — Phase 1 `/prd` → Phase 2 `/prd-review` (autonomous
  loop-to-green) → Phase 3 proto-ready. On block: flips item `Blocked`, emits `PICKUP_BLOCKED`, stops.
- `/prd-review` owns the loop-to-green (its Phase 5). Terminal blocked sentinel:
  `PRD_REVIEW_BLOCKED: <slug> — <DISCOVERY-FIRST | readiness: blocker | non-convergence>: <reason>`.
- `senior-pm` agent (`config/agents/senior-pm.md`) — opus, "sequence ruthlessly; cut/defer/kill";
  produces phased PRDs + trigger-gated deferrals. **Exact tool for the recut.**
- `/add` (`config/skills/add/SKILL.md`) — `--feature` forces type (skips propose); Step 3 accepts
  "answer all at once / you decide → default" ⇒ can run non-interactively from a rich intent, like
  `/prd` already does under `/pickup`.
- Stop hook `pickup-completion-gate.sh` — keeps alive while `phase ∈ {prd, review}`; **releases on any
  other/unknown phase** (incl. a new `recut` value). ⇒ **do the recut while `phase` stays `review`/`prd`
  — introduce NO new phase value, so the hook needs zero change.** Circuit breaker gives up after 5
  no-progress stops; recut's score must keep moving (re-seeding MVP `/prd`→`review` does this).
- No existing recut/phasing mechanism — the "recut" mentions in `/prd-review` & `/prd` are only the
  convergence-signal note. This is net-new. (Aligns with promoted patterns: "Recut > fix-then-fix when
  blockers accumulate"; "Phase-gate triggers tied to objective signals"; "Senior-PM peer review when
  scope fights appetite".)

## Trigger predicate (which blocker → recut)
Branch on the `PRD_REVIEW_BLOCKED` reason:
| reason | scope? | action |
|---|---|---|
| `non-convergence` (blocker volume not falling / 3-round cap) | **YES** — over-appetite | → **recut** |
| `readiness: blocker` | maybe | senior-pm **classifies**: decomposable scope/sequencing → recut; bet/discovery → plain blocked |
| `DISCOVERY-FIRST` (premise/evidence too thin) | **NO** | plain blocked (today). **Never recut** — you can't phase past not knowing if the premise holds |

## Recut sub-flow (new Phase 2b in `/pickup`, entered from a scope block)
1. **Spawn `senior-pm`** with: item seed, the non-converged `tasks/prd-<slug>.md`, the review ledger
   `tasks/prd-<slug>-review.md`. Ask for an **MVP phasing decision**:
   - **Phase 1 = MVP**: thinnest vertical delivering the primary §3 job + primary §5 outcome, within
     the PRD's §6 appetite, a walking skeleton.
   - **Phase 2…N**: deferred scope — each names the §8 slices / §5 outcomes it carries (cited), an
     **objective trigger** (prod-signal/query, per the pattern), and why deferred.
   - Cut rationale + which review blockers each phase clears. **Constraint: every phase's scope must
     trace to real PRD slices/outcomes — no invented scope.**
2. **Verify** (global rule 4 — never trust subagent output unread): each phase's cited slices exist in
   the PRD; MVP is genuinely walking-skeleton + within appetite; deferred triggers are objective. If it
   invented scope or MVP still over-appetite → re-prompt once; else fall back to plain blocked.
3. **Register each phase** via `/add --feature "<rich intent>"` (non-interactive: intent pre-fills all
   5 PRD-track shape fields → `/add` autonomous fallback). Titles: `<parent> · Phase k (MVP|trigger): <t>`.
   Capture assigned ids (F<n>…).
4. **Record the chain** under the parent block: `**Phase chain:** F7 (MVP) → F8 [trigger: …] → F9 [trigger: …]`.
   Parent status: keep `In-progress`, annotate `Recut into phase chain (MVP F7)`. (No `Recut` status
   exists; don't invent one. Flag as a possible small later roadmap enhancement.)
5. **Continue on the MVP** — set active item = MVP child, re-enter Phase 1 (`/prd` seeded by MVP item) →
   Phase 2 (`/prd-review` to green). MVP is appetite-sized ⇒ converges. Stop at `proto-ready` for the MVP.
   Deferred phases stay `Planned` + trigger-documented for a later `/pickup F8`.

## Guards
- **Recut at most once per pickup** — a child MVP that still won't converge is a genuine `blocked`
  (human decides). Prevents infinite decomposition.
- Never recut on `DISCOVERY-FIRST`.
- Verify senior-pm phasing against the PRD before acting (no fabricated phases).
- Keep `phase ∈ {prd, review}` throughout recut ⇒ Stop hook untouched; ensure the state score keeps rising.

## State file additions (`tasks/.pickup-<slug>-state.json`)
Add optional `recut` block: `{ "parent":"F3", "phases":["F7","F8","F9"], "active":"F7", "pm_rounds":1 }`.
`phase` stays `review`→`prd`→`review` (never `recut`). New terminal note when MVP greens:
`PICKUP_RECUT: F3 → F7(MVP)+F8+F9` then the normal `PICKUP_READY: <mvp-slug> …`.

## Files to edit
- `config/skills/pickup/SKILL.md` — add the trigger predicate to Phase 2's blocked handling + the new
  Phase 2b recut sub-flow + state-schema note + rules. (primary)
- `config/skills/add/SKILL.md` — one line noting orchestrator callers may pass a full shape for a
  non-interactive add (optional, faithfulness).
- Update `/pickup` front-matter description to mention the recut path.
- **Release:** bump saki-builder version + push (plugin loads a version-pinned snapshot; editing config
  does NOT live-update `/saki-builder:pickup` until release). No hook change ⇒ no dual-hook edit.

## OPEN DECISION (blocks build) — how far does "run sequentially until scope complete" go?
- **A (recommended):** recut → register all phases → drive **only the MVP** to green, stop at proto
  (the single human gate). Phases 2…N Planned + trigger-gated for later `/pickup`. Faithful to the
  proto gate + trigger-deferral pattern; ships the smallest increment first.
- **B:** recut → register all → **sequentially drive every phase's PRD to green** in one run (still
  stops before proto). Matches the literal wording but writes speculative PRDs for deferred phases.
- **C (rejected):** auto-run proto+build per phase — crosses the single human proto gate; redefines
  `/pickup`'s boundary. That's a `/build`-chaining change, not this.
