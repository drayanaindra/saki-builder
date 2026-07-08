---
name: genesis
description: Start a product FROM SCRATCH — the greenfield entry point that runs BEFORE the roadmap/pickup/prd/proto/build loop can work. On an empty repo the normal loop can't start (/proto hard-STOPs "NO DESIGN SYSTEM FOUND"; /prd has no stack or code to ground against; /pickup needs a product that already exists). `/genesis "<product idea>"` fills that gap by manufacturing the preconditions the loop assumes, in the order a real product is born: G0 MVP goal (the one end-to-end thing the product must let a user do) → G1 bounded "how to build this MVP" research → G2 a low-fidelity vision mock with mock data (how the end looks, BEFORE a design system exists) → G3 the foundations spec (stack · design system · architecture · initial schema) behind ONE human approval gate → G4 scaffold the foundations → G5 seed tasks/roadmap.md with the MVP epic and STOP. Then the existing loop runs at full fidelity: /pickup E1 → /prd → /proto (GATE 2 now PASSES) → /build. Does NOT fork or replace the loop — it only produces its inputs, then converges onto it. Slice 1: G4 is a printed checklist the human runs (auto-scaffold is Slice 2). Usage — /saki-builder:genesis "<one-line product idea>" [--restart].
---

# Genesis — from an empty repo to a product the disciplined loop can build

`/saki-builder:genesis` is the **Phase 0** of the workflow: the from-scratch entry point that runs
**once, at product birth**. Everything downstream (`/saki-builder:pickup` → `/saki-builder:prd` →
`/saki-builder:proto` → `/saki-builder:build`) assumes a product that **already exists** — a chosen
stack, real code to ground against, and a real design system + app shell. On a brand-new repo none of
that exists, so the loop cannot start:

- `/saki-builder:proto` **hard-STOPs** at GATE 2 — *"NO DESIGN SYSTEM FOUND — a faithful preview is impossible."*
- `/saki-builder:prd` grounds §16 by grepping the codebase and its context is `Stack: {{stack}}` — both empty.
- `/saki-builder:pickup` requires a roadmap item and seeds a **stack-less** PRD; there is no cold-intent path.

Genesis **manufactures those preconditions** and then hands off. It does **not** re-implement or fork
the loop — it produces the loop's inputs and converges onto it, exactly as `/saki-builder:pickup` and
`/saki-builder:build` *orchestrate* existing skills rather than duplicate them.

```
[EMPTY REPO]
   │
   ▼  /saki-builder:genesis "<product idea>"
   G0 MVP goal → G1 research → G2 vision mock → G3 foundations (⟵ human gate) → G4 scaffold → G5 seed roadmap
   │   produces: chosen stack · real design system + app shell · initial schema · design.md · foundations.md · seeded tasks/roadmap.md
   ▼
[FOUNDATIONS EXIST]  ← the precise precondition /pickup, /prd, /proto already assume
   │
   ▼  the EXISTING loop, untouched, now at full fidelity
   /saki-builder:pickup E1 → /saki-builder:prd → /saki-builder:proto (GATE 2 PASSES) → /saki-builder:build
```

**One human gate — at G3 (foundations approval).** Choosing the stack (incl. the backend language),
architecture, and schema is the load-bearing, hard-to-reverse decision; the human approves it before
anything is written to the repo as foundations. G0 has a lean present-and-confirm; every other phase is
autonomous. This mirrors the workflow's single-gate discipline (`/saki-builder:pickup`'s single gate at
proto, `/saki-builder:build`'s no-prompt autonomy).

**Slice 1 scope (this file).** G0–G3 run fully; G4 is a **printed checklist the human runs** (not
auto-scaffold — G4 is the irreversible file-creation step, automated in Slice 2); G5 seeds the roadmap
and hands off. See "Roadmap for this skill" at the end.

---

## Usage

- `/saki-builder:genesis "<one-line product idea>"` — start (or resume) genesis for a from-scratch product. Filler words are fine.
- `/saki-builder:genesis` with no idea and an empty repo → ask once, plainly: *"One line: what is the product, and who is it for?"* Never invent a product.
- `--restart` — force a clean run from G0, ignoring any resume state.

---

## GATE 0 — Resume check (deterministic)

Read `tasks/.genesis-state.json` if it exists. Branch on `phase`:

| `phase` on entry | Action |
|------------------|--------|
| (no state file) | Fresh start → GATE 1. |
| `goal` / `research` / `vision` / `foundations` | Resume at that phase (re-present G0/G3 for confirmation if their approval wasn't durably recorded). |
| `scaffold-ready` | Foundations approved & written; re-print the G4 checklist (Phase G4). |
| `handed-off` | Roadmap seeded; re-print the G5 handoff (Phase G5). Do nothing else. |

**Best-effort + safe:** a missing/partial state file degrades to a fresh run — never hard-fail on it.
Always write the state file before ending a turn. `--restart` ignores this gate.

## GATE 1 — Reuse-first / not-already-a-product (hard stop if a product already exists)

Genesis is **only** for a repo with no product foundations yet. Before running, verify the repo is
genuinely greenfield — do NOT re-genesis an existing product (rule 6: never rebuild what exists):

```bash
# `test` builtins — glob-safe (no `*.md` glob that aborts under zsh `nomatch`) AND robust to RTK
# rewriting `ls`/`find` output into a summary (which would make an empty repo read as non-empty).
# Any condition TRUE ⇒ a product already exists ⇒ do NOT genesis.
if [ -e package.json ] || [ -e go.mod ] || [ -e pyproject.toml ] || [ -e Cargo.toml ] \
   || [ -e foundations.md ] || [ -e tasks/roadmap.md ] \
   || [ -d src ] || [ -d app ] || [ -d components ]; then
  echo PRODUCT_EXISTS      # a stack, code, or product artifact is present
else
  echo GREENFIELD
fi
```

- **`GREENFIELD`** (no stack, no roadmap, no code, no `foundations.md`) → proceed to G0.
- **`PRODUCT_EXISTS` via a stack or code** (`package.json`/`go.mod`/…/`src`/`app`/`components`) → STOP:
  `This repo already has a product. Genesis is for from-scratch products only. To add to an existing product: /saki-builder:add "<intent>" → /saki-builder:pickup, or /saki-builder:init-env if the Claude env isn't set up.`
- **`PRODUCT_EXISTS` via `foundations.md`** → a prior genesis ran → resume via GATE 0 (don't restart);
  `PRODUCT_EXISTS` via only `tasks/roadmap.md` (roadmap seeded, no scaffold yet) → resume at G4/G5 via GATE 0.

---

## Phase G0 — MVP goal (human-facing, lean — the product's walking skeleton)

Frame the **whole product's** thinnest end-to-end value — not a feature. Borrow `/saki-builder:prd`
Step 0/0.5 shaping, applied at product scale. Keep it short; accept 1–2 word answers. Establish:

- **The one thing** the MVP must let a user do, end-to-end (the *walking skeleton* — ships user-visible
  value start-to-finish, not plumbing). One sentence.
- **Who** it's for + the job (JTBD-lite): `When [situation], I want to [motivation], so I can [outcome].`
- **The one success signal** — the single observable that says the MVP works.
- **Explicitly NOT in the MVP** — 1–2 things a reader would assume are in scope but aren't.

Present these 4 lines and confirm in one pass (*"Is this the MVP — or adjust?"*). On "you decide",
take reasonable defaults, state them, continue. Init the state file (`phase:"goal"`). Record the
confirmed framing to scratch — it seeds G1/G2/G3.

## Phase G1 — "How to build this MVP" research (bounded — autonomous)

Set `phase:"research"`. A **time-boxed** grounding pass so the foundation choices aren't invented blind.
Reuse `/deep-research` (preferred) or `WebSearch`. Answer only:

1. **Reference stack & conventions** for this product *type* (what comparable MVPs are built with).
2. **The thinnest viable architecture** — the one load-bearing decision this product forces (e.g.
   server-rendered vs SPA, sync vs job-queue, single service vs split).
3. **Include vs defer** — what a comparable MVP ships in v1 vs pushes to later.

**Bound it** — a few targeted queries, not an open-ended survey (avoid the rabbit-hole; the point is to
*ground* G3, not to write a report). Summarize findings to scratch as inputs to G3. If offline / research
unavailable, note it and proceed on the house defaults + the vision.

## Phase G2 — Vision mock (low-fidelity, system-LESS — "how the end looks")

Set `phase:"vision"`. Produce a **directional looks-like mock** of the MVP end-state — the **3–5 key
screens** with honest **mock data** — so the human sees *how the end looks* **before** a design system
exists. This is deliberately low-fidelity and **throwaway**; its job is to set the expectation AND to
**drive the G3 design-system + stack choice** (what components / tokens / layout the vision implies).

- Use the **`frontend-design`** skill for aesthetic direction (typography, hierarchy, intentional
  choices — not templated defaults).
- Render as a **single self-contained HTML file** (inline CSS, mock data) to `tasks/genesis/vision.html`
  — no framework, no design system, no backend. Honest mock density (long strings, many rows, an empty
  state) so it doesn't lie about layout.
- This is the genesis analogue of `/saki-builder:proto`'s directional-mock option, **promoted to a
  first-class artifact**. Full-fidelity design-with-mock-data stays in `/saki-builder:proto` *after* G4
  scaffolds the real system — genesis does not duplicate it.

State plainly: *"This is a throwaway vision of the end-state to align on look + inform the foundations —
the real design system gets scaffolded next."*

## Phase G3 — Foundations spec  ⟵ **THE human gate** (approve before anything is written)

Set `phase:"foundations"`. Decide the **detailed requirements of what to build**. Each decision is
recorded with a **cited rationale + the rejected alternative** (`/saki-builder:prd` §7 Decision-Log
discipline). Ground every choice in G1 research + the G2 vision + the MVP goal.

**Stack — house defaults auto-applied; backend is ARCHITECTURE-GATED (ask only when a separate service is warranted):**

| Layer | Default (auto-applied) | How chosen |
|-------|------------------------|-----------|
| **Frontend** | **Next.js + Tailwind + shadcn/ui** | House default — matches `/saki-builder:proto` GATE 2's shadcn/Tailwind path, so proto recognizes the scaffold. Override only if G1/the vision clearly points elsewhere. |
| **Database** | **Postgres** | House default. Override only with a clear reason from G1. |
| **Backend** | **architecture-gated** | From **G1's architecture**, decide first: does the MVP need a **separate backend service**? **YES** → prompt the human *"Backend language — **Go, Rust, or Python**?"*, record the pick + one-line why (never silently default the language). **NO** — full-stack Next.js (route handlers / server actions) covers it → **`none`**, and defer the language to a **trigger-gated roadmap item** (G5) that fires when the first async job / non-web client appears (the language is chosen *then*). Never bolt a separate service onto an MVP that doesn't need one. |

**Also decide (each: decision · why · rejected alternative):**
- **Design-system approach** — shadcn/ui primitives + Tailwind tokens is the default; note any bespoke
  component families the vision (G2) implies (fed to G4 as the primitive set + app-shell spec).
- **Architecture** — the ONE load-bearing decision from G1 (not a component diagram). Cite `docs/modular-architecture.md`.
- **Initial DB schema** — entities + relations at **shape altitude** (the nouns and how they relate),
  NOT full DDL. Full migrations are `/saki-builder:rplan`'s job later. Cite `docs/ddd-patterns.md`.

**Write two artifacts** (only after the human approves — see the gate):
- `foundations.md` (repo root) — the foundations spec + Decision Log. This is also the **greenfield-mode
  marker** the loop's touch-ups key off (`/saki-builder:prd` reads it instead of grepping empty code).
- `design.md` (repo root) — seed the design system doc `/saki-builder:proto` GATE 2 option (a) references
  (tokens + the primitive/app-shell set the vision implies).

**THE GATE (BLOCKING — HIGH risk, hard to reverse).** Present the foundations to the human in plain
English — stack (incl. the backend pick), the architecture decision, the schema shape, the design-system
approach — and ask: *"Approve these foundations to scaffold, or adjust?"* Do **NOT** write `foundations.md`
/ `design.md` or advance to G4 until the human approves. On approval, write both artifacts, set
`phase:"scaffold-ready"`, and record the approval in the state file (the durable proof — Step G4 trusts it).

## Phase G4 — Scaffold the foundations  (Slice 1 = a printed checklist the human runs)

Set `phase:"scaffold-ready"`. The scaffold produces the real preconditions the loop needs: a stack
skeleton, a **real design system (tokens + primitives + app shell)**, and the **initial schema/migration**
— enough that `/saki-builder:proto` GATE 2 passes and `/saki-builder:prd` can ground §16 against real code.

**Slice 1 does NOT auto-run the scaffold** (it is the irreversible file-creation step — automated in
Slice 2). Instead, print a concrete, copy-pasteable checklist derived from the approved `foundations.md`,
e.g. (for the default frontend + the chosen backend):

```
G4 — Scaffold checklist (run these, then continue with /saki-builder:init-env):
  Frontend + design system:
    [ ] npx create-next-app@latest . --ts --tailwind --app --eslint
    [ ] npx shadcn@latest init            # tokens + primitives (matches proto GATE 2)
    [ ] add the app shell (nav/header/sidebar) + the vision's implied primitives from design.md
  Backend (<Go|Rust|Python>):
    [ ] scaffold the service skeleton for <language> (one load-bearing arch decision from foundations.md)
  Database (Postgres):
    [ ] create the initial schema/migration for the entities in foundations.md (shape only)
  Claude dev env:
    [ ] /saki-builder:init-env         # CLAUDE.md, hooks, agents, memory (Claude env — not the product)
    [ ] design engine: ~/.claude/hooks/design-engine-setup.sh record --engine native
```

Tell the human: *"Run these to create the real foundations, then re-run `/saki-builder:genesis` (it
resumes at G5) — or continue to seed the roadmap now and scaffold in parallel."* Genesis stays at
`scaffold-ready` until the roadmap is seeded (G5 can run regardless — it doesn't need the code).

## Phase G5 — Seed the roadmap + hand off (terminal)

Seed the disciplined loop's entry artifact and stop.

1. `/saki-builder:roadmap init` — scaffold `tasks/roadmap.md` (product name = the G0 product; default the repo name).
2. Register the **MVP as the first epic/feature** via `/saki-builder:add` — compose a rich intent from the
   G0 framing (goal · target user & job · the walking-skeleton flow · the success signal) so `/add` takes
   its autonomous fallback (no prompts). Capture the assigned id (`E1`/`F1`).
3. **Trigger-gate the follow-on scope** — anything the G0 "NOT in the MVP" list or G1 "defer" bucket
   named goes on the roadmap as `Planned` with an **objective trigger** (a prod signal/query, not a date),
   reusing `/saki-builder:pickup`'s recut/trigger-gate philosophy. Register each via `/saki-builder:add`
   **sequentially** (the id counter collides on parallel adds).

Set `phase:"handed-off"`, write state, and print:

```
GENESIS_READY: <product> — foundations approved · roadmap seeded (E1 = MVP)

✅ Product foundations set. Next:
   1. Run the G4 scaffold checklist above (if not done) — creates the real stack + design system + schema.
   2. /saki-builder:pickup E1   — writes & reviews the MVP PRD (grounds on the scaffold).
   3. /saki-builder:proto E1     — GATE 2 now PASSES (real design system exists); designs the UI + LOCKS the PRD.
   4. /saki-builder:build E1     — ships the MVP slice-by-slice.
```

`GENESIS_READY` on its own line is the terminal success sentinel.

---

## State file (single source of truth)

Maintain `tasks/.genesis-state.json`. Update after every phase transition. Timestamps via `date +%s`.

```json
{
  "product": "<name>",
  "idea": "<one-line idea>",
  "phase": "goal|research|vision|foundations|scaffold-ready|handed-off",
  "started_at": 1730000000,
  "backend": "",
  "foundations_approved": false,
  "roadmap_item": ""
}
```

## Survival & rules

- **Genesis is Phase 0 — it produces the loop's inputs, never forks the loop.** Downstream is
  `/saki-builder:pickup` → `/saki-builder:prd` → `/saki-builder:proto` → `/saki-builder:build`, unchanged.
- **One human gate, at G3 (foundations).** G0 is a lean confirm; the backend is decided in G3 (Go/Rust/Python
  prompted only when G1's architecture warrants a separate service); everything else is autonomous. Never write
  `foundations.md`/`design.md` or scaffold before G3 approval.
- **Reuse-first.** GATE 1 refuses to genesis a repo that already has a product. Reuse `frontend-design`,
  `/deep-research`, `/saki-builder:init-env`, `/saki-builder:roadmap`, `/saki-builder:add` — never re-implement them.
- **Backend is architecture-gated, not auto-defaulted.** From G1: a separate service is warranted →
  **prompt Go / Rust / Python** (never silently pick a language); full-stack Next.js covers it → **`none`**,
  and defer the language to a trigger-gated roadmap item. Frontend (Next.js + Tailwind + shadcn/ui) and DB
  (Postgres) are house defaults, overridable with a clear reason from G1/the vision.
- **The vision (G2) is throwaway and system-LESS** — it drives the foundation choice; it is not the deliverable.
- **Never fabricate research or foundations.** If G1 is offline, say so and proceed on the defaults + vision.
- **Always persist state before ending a turn** so a resume (context clear, killed turn) lands on the right phase.

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Running genesis on a repo that already has a stack/code | GATE 1 refuses — use `/saki-builder:add` → `/saki-builder:pickup` for an existing product |
| Writing `foundations.md` / scaffolding before the human approves G3 | G3 is the single BLOCKING gate — present, get approval, then write |
| Bolting a Go/Rust/Python service onto an MVP that doesn't need one | Gate on G1: separate service needed → ask Go/Rust/Python; full-stack Next.js covers it → `none`, defer the language to a trigger-gated roadmap item |
| Making the G2 vision high-fidelity or treating it as the deliverable | It's a throwaway, system-less directional mock that informs G3 — full fidelity is `/saki-builder:proto` after scaffold |
| Letting G1 research rabbit-hole into a report | Time-box it — a few targeted queries to ground G3, nothing more |
| Auto-scaffolding in Slice 1 | Slice 1 prints the G4 checklist; auto-scaffold is Slice 2 (G4 is the irreversible step) |
| Re-implementing prd/proto/pickup inside genesis | Genesis only produces their inputs and hands off — orchestrate, never fork |

## Roadmap for this skill

- **Slice 1 (this file):** G0–G3 fully · G4 = printed checklist · G5 seeds the roadmap + handoff.
- **Slice 2:** auto-run G4 (create the stack + design system + app shell + schema per the chosen backend);
  add the loop touch-ups so `/saki-builder:prd` reads `foundations.md` for greenfield grounding and
  `/saki-builder:proto` GATE 2 recognizes the freshly-scaffolded design system.
- **Slice 3:** resume/state hardening, `--restart` polish, Figma-engine interplay, follow-on trigger-gating.

See `greenfield-genesis-plan.md` for the full design rationale and evidence.
