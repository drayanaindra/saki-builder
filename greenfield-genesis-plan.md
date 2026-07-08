# Greenfield Genesis — plan to improve the saki-builder workflow for from-scratch projects

**Status:** Draft (plan only — not implemented) · **Owner:** unassigned · **Updated:** 2026-07-08
**Model:** OPUS · **Risk:** MED–HIGH (new core skill + edits to `prd`/`proto` gates — human gate required)

---

## 1. The problem (evidence-cited)

The saki-builder workflow is a **feature factory**: it turns "add feature X to an *existing* product"
into shipped code, brilliantly. Its load-bearing gates **assume the product's foundations already
exist**, so it has no path for starting a product **from scratch** (the user's reported problem):

| Assumed precondition | Where it's baked in |
|---|---|
| A chosen **stack** | `prd/SKILL.md:53` Context = `Stack: {{stack}}`; `scaffold-webapp/SKILL.md:23` `using {{stack}}` |
| **Existing code** to ground against | `prd/SKILL.md:164–169` Tier-1 = "grep the codebase to verify every technical claim"; `prd/SKILL.md:288–296` §16 = REUSE (cite `path:line`) vs NEW |
| A real **design system + app shell** | `proto/SKILL.md:291–328` GATE 2 **hard-STOPs** "NO DESIGN SYSTEM FOUND — a faithful preview is impossible" when none is detected; `proto/SKILL.md:332+` Step 2.4 reuse-map greps `src/features/**` for existing implementations |
| An **architecture + DB schema** to harden | `rplan` ingests §16 shape and hardens it against real code |
| The product already **exists** (you add *items* to it) | `pickup/SKILL.md:8–16` requires an item on the roadmap and seeds `/prd`; "there is no cold-intent path" |

On an empty repo every one of these fails: `/proto` STOPs at GATE 2, `/prd` grounds against nothing
(everything is un-anchored `NEW`), and no step ever **decides** stack, design system, architecture, or
schema. `proto` GATE 2's own escape hatch (`proto/SKILL.md:322`) says *"scaffold shadcn+Tailwind per
design.md, then re-run"* — but nothing produces `design.md`. The precondition has no producer.

`scaffold-*` and `init-env` do **not** fill this: `scaffold-webapp` adds a page to an existing app
(`SKILL.md:26` "Read existing pages to understand patterns"); `init-env` scaffolds the *Claude dev
env* and in headless mode **deliberately skips** the design engine (`init-env/SKILL.md:44–47`) and
never scaffolds a design system / architecture / schema.

## 2. What the user asked for (the missing sequence)

1. Start from the **MVP goal** (product-level).
2. **Design with mock data → "how the end looks"** — set the expectation up front.
3. Set **detailed requirements**: what to build, which **stack**, **design system**, **architecture**, **DB schema**.
4. **Research how to build the MVP**.

## 3. Design principle — prepend a Phase 0, converge onto the existing rails (do NOT fork)

The fix is **not** a parallel greenfield workflow. It is a **Phase 0 "genesis"** that *manufactures the
exact preconditions the existing loop already requires*, then hands off to it unchanged:

```
[EMPTY REPO]
   │
   ▼  NEW: /genesis   (Phase 0 — runs once, at product birth)
   │   G0 MVP goal → G1 research → G2 vision mock → G3 foundations spec → G4 scaffold → G5 seed roadmap
   │   (produces: chosen stack · real design system + app shell · initial schema · design.md · tasks/roadmap.md seeded)
   ▼
[FOUNDATIONS EXIST]  ← this is precisely the precondition /pickup, /prd, /proto already assume
   │
   ▼  EXISTING loop, untouched, now at full fidelity
   /pickup E1 → /prd (grounds §16 on the scaffold) → /proto (GATE 2 PASSES) → /build
```

This is faithful to rule 6 (never rebuild what exists) and the reuse-first pattern: the feature loop is
**reused verbatim**; genesis only produces its inputs. It mirrors how `/pickup` and `/build` already
*orchestrate* existing skills rather than re-implement them.

### Resolves the chicken-and-egg (vision needs a design system; the design system is being decided)

Split "vision design" into two fidelity tiers so the vision can come *first* and *drive* the foundation:

- **G2 vision mock = low-fidelity, system-LESS** (a looks-like directional mock, `frontend-design`
  guidance, mock data). This is `proto`'s existing option (b) "directional mock" **promoted from
  fallback to a first-class genesis artifact**. It sets the expectation AND informs which components /
  tokens / stack the foundation needs.
- **Full-fidelity design-with-mock-data stays where it already works** — `/proto`, *after* G4 scaffolds
  the real design system, so GATE 2 passes and the preview is faithful. No duplication of proto.

## 4. The new skill — `/genesis` (working name; see Open Questions)

Orchestrator skill, `config/skills/genesis/SKILL.md`, state-file + resume like `pickup`/`proto`.
Autonomous-by-default with **one human gate at G3→G4** (approve foundations before scaffolding — a
HIGH-risk, hard-to-reverse step). Phases:

| Phase | Produces | Reuses |
|---|---|---|
| **G0 — MVP goal** | product-level walking-skeleton framing: the one end-to-end thing the MVP lets a user do · who (JTBD-lite) · one success signal | `prd` Step 0/0.5 shaping, applied to the whole product |
| **G1 — "How to build this MVP" research (bounded)** | reference stacks/conventions for this product type · thinnest viable architecture · what a comparable MVP includes vs defers | `/deep-research` or `WebSearch`; **time-boxed** to avoid rabbit-hole |
| **G2 — Vision mock (low-fi, system-less)** | 3–5 key end-state screens w/ honest mock data = "how the end looks"; explicitly throwaway; drives G3 | `frontend-design` skill; proto's directional-mock technique |
| **G3 — Foundations spec** ⟵ **human gate** | `foundations.md` + seed `design.md`: **stack · design-system approach · architecture (one load-bearing decision) · initial schema (entities+relations, shape altitude)** — each a cited decision + rejected alternative. **Stack = house default for frontend+DB (Next.js + Tailwind + shadcn/ui + Postgres), auto-applied; backend is ARCHITECTURE-GATED** — from G1, a separate service is warranted → prompt Go / Rust / Python; full-stack Next.js covers it → `none`, defer the language to a trigger-gated roadmap item (never bolt on a service the MVP doesn't need). | prd §7 Decision-Log discipline; `docs/modular-architecture.md`, `docs/ddd-patterns.md` |
| **G4 — Scaffold foundations for real** | repo skeleton for the stack · real design system (tokens + primitive set + **app shell**) · initial schema/migration — enough that proto GATE 2 passes & prd can ground §16; writes the `design.md` GATE 2 references | `/init-env` (dev env) + `scaffold-*`; **genuinely-new step:** bootstrap design-system + app shell + schema |
| **G5 — Seed roadmap + hand off** | `tasks/roadmap.md` seeded: MVP → first epic/feature(s); follow-on scope **trigger-gated**; STOP with `/pickup E1` handoff | `/roadmap init`, `/add`; pickup's senior-PM recut/trigger-gate philosophy |

## 5. Downstream touch-ups (so the loop tolerates greenfield gracefully)

Small, surgical edits — NOT rewrites — so a genesis'd project flows cleanly:

1. **`/prd` greenfield mode** — when a `foundations.md` marker exists (or the repo has no code), Tier-1
   grounding reads the **foundations spec + scaffold** instead of grepping a nonexistent codebase; §16
   rows cite the scaffolded entities/endpoints (now REUSE, not blind NEW). *(`prd/SKILL.md:156–186, 279–309`)*
2. **`/proto` GATE 2** — recognize a freshly-scaffolded design system as "Found" so the honesty gate
   passes on a genesis'd greenfield project; make option (a)'s "per `design.md`" real (genesis writes it). *(`proto/SKILL.md:291–328`)*
3. **Intake routing** — `/roadmap`, `/add`, `/pickup` gain a "no project yet?" signal: running them on an
   empty repo prints `→ run /genesis first (no product foundations yet)` instead of seeding a stack-less
   PRD. *(`pickup/SKILL.md` GATE 1; `roadmap`, `add`)*

## 6. Reuse map (rule 6 — what's genuinely NEW vs reused)

- **NEW:** the `/genesis` orchestrator skill + its state/resume; the G4 "bootstrap design-system + app
  shell + initial schema" step (nothing does this today); the G2 vision-mock-as-genesis-artifact framing.
- **REUSED verbatim:** the whole `/pickup → /prd → /proto → /build` loop; `frontend-design`,
  `deep-research`, `init-env`, `roadmap`, `add`, `scaffold-*`, `senior-pm` recut/trigger-gate pattern.
- **LIGHT EDITS only:** the 3 touch-ups in §5.

## 7. Delivery — thin slice first, then converge (my own appetite/thin-slice patterns)

- **Slice 1 (MVP of genesis):** `/genesis` G0→G3 + write `foundations.md`/`design.md` + G5 seed roadmap —
  **stop before auto-scaffolding**; G4 is a printed, human-run checklist. Proves the *sequencing* and the
  handoff with the least irreversible action. Plus touch-up §5.3 (intake routing) so empty-repo users are
  pointed at `/genesis`.
- **Slice 2:** automate G4 scaffold (stack + design system + app shell + schema) per detected stack; add
  touch-ups §5.1–§5.2 so `/prd`/`/proto` consume the scaffold.
- **Slice 3:** resume/state hardening, `--restart`, figma-engine interplay, follow-on trigger-gating polish.

## 8. Decisions (LOCKED 2026-07-08)

1. **Entry point = standalone `/genesis`** — orchestrates + reuses the existing loop, mirroring `/pickup`/`/build`.
2. **G4 in Slice 1 = printed checklist** (human runs it); auto-scaffold lands in Slice 2 — G4 is the irreversible step.
3. **House-default stack, architecture-gated backend** — frontend + DB are auto-applied defaults: **Next.js + Tailwind + shadcn/ui + Postgres** (matches proto GATE 2's shadcn/Tailwind escape hatch, so `/proto` recognizes the scaffold). The **backend is architecture-gated**: from G1, a separate service is warranted → prompt **Go / Rust / Python**; full-stack Next.js covers it → **`none`**, and defer the language to a **trigger-gated roadmap item** (chosen when the first async job / non-web client appears). Never bolt a service onto an MVP that doesn't need one. G1/the vision may override the frontend/DB defaults per project. *(Refined 2026-07-08 from the dry-run — the original "always ask Go/Rust/Python" forced a separate service onto full-stack MVPs.)*

## 9. Verification (how we'll know it works)

End-to-end on a genuinely empty repo: `/genesis "<one-line product idea>"` → foundations approved →
(Slice 2) scaffold created → `/pickup E1` runs with a real stack → `/proto` GATE 2 **passes** (no
"NO DESIGN SYSTEM FOUND") → `/build` ships slice 1. The pass signal is proto rendering a faithful
preview on a repo that was empty 20 minutes earlier.
