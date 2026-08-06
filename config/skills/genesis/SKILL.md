---
name: genesis
description: Start a product FROM SCRATCH — the greenfield entry point that runs BEFORE the roadmap/pickup/prd/proto/build loop can work. On an empty repo the normal loop can't start (/saki-builder:proto hard-STOPs "NO DESIGN SYSTEM FOUND"; /saki-builder:prd has no stack or code to ground against; /saki-builder:pickup needs a product that already exists). `/saki-builder:genesis "<product idea>"` fills that gap by manufacturing the preconditions the loop assumes, in the order a real product is born: G0 MVP goal (the one end-to-end thing the product must let a user do) → G1 bounded "how to build this MVP" research → G2 a low-fidelity vision mock with mock data (how the end looks, BEFORE a design system exists) → G3 the foundations spec (stack · design system · architecture · initial schema) behind ONE human approval gate → G4 scaffold the foundations → G5 seed tasks/roadmap.md with the MVP epic and STOP. Then the existing loop runs at full fidelity: /saki-builder:pickup E1 → /saki-builder:prd → /saki-builder:proto (GATE 2 now PASSES) → /saki-builder:build. Does NOT fork or replace the loop — it only produces its inputs, then converges onto it. Slice 1: G4 is a printed checklist the human runs (auto-scaffold is Slice 2). Usage — /saki-builder:genesis "<one-line product idea>" [--restart].
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
[FOUNDATIONS EXIST]  ← the precise precondition /saki-builder:pickup, /saki-builder:prd, /saki-builder:proto already assume
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
   server-rendered vs SPA, sync vs job-queue). *(The frontend/backend split itself is NOT a decision —
   it's a hard rule; see G3. This is about the architecture WITHIN that split, and the backend language.)*
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
- **Part F tell-check on the rendered mock (BLOCKING — it anchors G3).** Before showing the human, grade
  `vision.html` against the Design System Contract **Part F tell-list** (gradient hero · emoji-as-icons ·
  equal-weight grid / no hierarchy · everything-centered · cream+serif+terracotta · near-black+acid ·
  generic copy). No DIRECTIONAL REFERENCE exists yet (it's pinned in G3 Part 0 Step 1), so this is the
  **checklist half only** — it stops an obvious AI-default look from anchoring a sloppy G3 choice; the full
  reference-judge runs later on the real screens (`/saki-builder:proto` Step 6.5). A tell → re-render the
  mock; never let a default look set the product's direction.

State plainly: *"This is a throwaway vision of the end-state to align on look + inform the foundations —
the real design system gets scaffolded next."*

## Phase G3 — Foundations spec  ⟵ **THE human gate** (approve before anything is written)

Set `phase:"foundations"`. Decide the **detailed requirements of what to build**. Each decision is
recorded with a **cited rationale + the rejected alternative** (`/saki-builder:prd` §7 Decision-Log
discipline). Ground every choice in G1 research + the G2 vision + the MVP goal.

**⛔ HARD RULE — frontend/backend separation (from scratch, NON-NEGOTIABLE).** Every genesis product is
laid out as **two separate top-level folders — `frontend/` and `backend/`** — from the very first commit.
This applies to **EVERY** MVP, however simple, and it **overrides any unified full-stack default**: there is
**no** single Next.js app that serves both the UI and the API. Frontend and backend never share one app or
one folder. The split is fixed; only the backend *language* is chosen at the gate below.

**Stack — house defaults auto-applied; the `frontend/`+`backend/` split is fixed, only the backend LANGUAGE is chosen at G3 (always prompted unless already specified):**

| Layer | Default (auto-applied) | How chosen |
|-------|------------------------|-----------|
| **Frontend** (`frontend/`) | **Next.js + Tailwind + shadcn/ui** | House default, scaffolded into the `frontend/` folder — matches `/saki-builder:proto` GATE 2's shadcn/Tailwind path, so proto recognizes the scaffold. Override only if G1/the vision clearly points elsewhere. |
| **Database** (`backend/`) | **Postgres** | House default, owned by the backend. Override only with a clear reason from G1. |
| **Backend** (`backend/`) | **always a separate service; language ALWAYS prompted unless already specified** | A separate `backend/` service is **always** created (the hard rule above — never folded into the frontend). The **language** is resolved so: **(1)** if the prompt/idea **or a project file** (G1 research, the G2 vision, any existing requirement/stack doc) **already specifies the backend language/stack → use that requirement** — record it + cite the source, do **not** prompt. **(2)** Otherwise → **always PROMPT the human**: *"Backend language — **Go, Rust, Python, or TypeScript/Node**?"* Never silently default. Ground the recommendation in G1's architecture (async/job-queue/compute-heavy → Go/Rust/Python; UI-adjacent API → TypeScript/Node) but still ask. Record the pick + one-line why. |

**Also decide (each: decision · why · rejected alternative):**
- **Design-system approach — run Part 0 of the Design System Contract**
  (`${CLAUDE_PLUGIN_ROOT}/config/docs/design-system-contract.md`). This is the *one* time it runs.
  - **Part 0 Step 1** — pin the DIRECTIONAL REFERENCE by **eliciting** it (the human can't invent one from a
    blank prompt): ask about the product's *world* not its look — and for abstract products with no physical
    world (analytics/infra/B2B), the second gear is what it *replaces* + the moment of use; reject BOTH adjectives AND default looks
    (check the Part F tell-list explicitly — e.g. "dark + red accent" = the near-black+acid tell) then redirect to the world,
    and use `design-reference-menu.md` only as a last-resort axis-calibrator + springboard back to own-world —
    never the destination (a raw archetype pick reproduces a Part F tell). See the contract's Step 1 method.
    Result: 1–2 concrete anchors from the product's own world (materials, vernacular, artifacts), never an
    adjective ("modern/clean"), and never an AI-default look (Part F) unless the reference actually asks for it.
  - **Part 0 Step 2** — derive the token values from that direction (palette 4–6 hex · ≤6-step type scale ·
    8px spacing · radius/elevation/motion), then critique against the brief: revise any token that reads
    like the generic default you'd produce for *any* similar project, and say what changed. shadcn/ui
    primitives + Tailwind tokens is the default binding (Part B "Format binding").
  - The surviving tokens + the DIRECTIONAL REFERENCE + any bespoke component families the G2 vision implies
    become the **Part A block** written to `design.md` (below), and feed G4 as the primitive/app-shell spec.
- **Analytics / measurement** — **GA4 is the default** so the product is measurable from release day:
  wire `gtag.js` into the app shell behind a `NEXT_PUBLIC_GA_MEASUREMENT_ID` env (no-op when the env is
  empty — same feature-flag-via-empty-env discipline as every optional integration). Feeds G4 as a
  scaffold step and is the default measurement Method for `/saki-builder:prd` §5 metrics. Override only
  with a clear reason from G1 (e.g. a privacy-first product picks a cookieless analytics stack).
- **Architecture** — the ONE load-bearing decision from G1 (not a component diagram). Cite `docs/modular-architecture.md`.
- **Initial DB schema** — entities + relations at **shape altitude** (the nouns and how they relate),
  NOT full DDL. Full migrations are `/saki-builder:rplan`'s job later. Cite `docs/ddd-patterns.md`.

**Write two artifacts** (only after the human approves — see the gate):
- `foundations.md` (repo root) — the foundations spec + Decision Log. This is also the **greenfield-mode
  marker** the loop's touch-ups key off (`/saki-builder:prd` reads it instead of grepping empty code).
- `design.md` (repo root) — the project's **Part A block** from the Design System Contract, filled with the
  Part 0-derived values (PROJECT · PRIMARY LANGUAGE · DIRECTIONAL REFERENCE · the eight color roles +
  type/spacing/radius/elevation/motion tokens · and a `GOLD-STANDARD COMPONENT:` line left as
  `<pending — built in G4>`). This is the design system doc `/saki-builder:proto` GATE 2 reads; Parts B–F stay
  invariant in the contract and are never copied here.

**THE GATE (BLOCKING — HIGH risk, hard to reverse).** Present the foundations to the human in plain
English — stack (incl. the backend pick), the architecture decision, the schema shape, the design-system
approach, the analytics default (GA4) — and ask: *"Approve these foundations to scaffold, or adjust?"* Do **NOT** write `foundations.md`
/ `design.md` or advance to G4 until the human approves. On approval, write both artifacts, set
`phase:"scaffold-ready"`, and record the approval in the state file (the durable proof — Step G4 trusts it).

## Phase G4 — Scaffold the foundations  (Slice 1 = a printed checklist the human runs)

Set `phase:"scaffold-ready"`. The scaffold produces the real preconditions the loop needs: a stack
skeleton, a **real design system (tokens + primitives + app shell)**, and the **initial schema/migration**
— enough that `/saki-builder:proto` GATE 2 passes and `/saki-builder:prd` can ground §16 against real code.

**Slice 1 does NOT auto-run the scaffold** (it is the irreversible file-creation step — automated in
Slice 2). Instead, print a concrete, copy-pasteable checklist derived from the approved `foundations.md`,
e.g. (default frontend in `frontend/` + the separate backend in `backend/`):

```
G4 — Scaffold checklist (run these, then continue with /saki-builder:init-env):
  ⛔ HARD RULE: frontend and backend are SEPARATE top-level folders — never one app.
  Frontend + design system  (frontend/):
    [ ] npx create-next-app@latest frontend --ts --tailwind --app --eslint
    [ ] (cd frontend && npx shadcn@latest init)     # tokens + primitives (matches proto GATE 2)
    [ ] write the design.md Part A tokens into frontend/app/globals.css as --color-<role> vars + @theme
        (Design System Contract Part B "Format binding" — the 8 roles proto GATE 2 checks)
    [ ] add the app shell (nav/header/sidebar) + the vision's implied primitives from design.md
    [ ] build the GOLD-STANDARD component (Part 0 Step 3: Button or Input) fully to the
        Design System Contract Part C, via the Part E layers, with a human review — then record its
        path in design.md's `GOLD-STANDARD COMPONENT:` line (every later component is built its way)
  Analytics (measurement — default GA4):
    [ ] wire gtag.js into the app shell reading NEXT_PUBLIC_GA_MEASUREMENT_ID (no-op when env is empty)
    [ ] expose a typed track(event, params) helper — the call site for §5 metric events
  Backend  (backend/  —  <TypeScript/Node | Go | Rust | Python>):
    [ ] scaffold the service skeleton for <language> under backend/ (one load-bearing arch decision from foundations.md)
    [ ] expose the API base URL to the frontend via an env var (never hardcode the backend origin)
  Database (Postgres — owned by backend/):
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

1. `/saki-builder:roadmap init "<product>"` — scaffold `tasks/roadmap.md`, **passing the G0 product name** so
   init does not prompt (it only asks when no name is supplied; default the repo name).
2. Register the **MVP as the first epic** via `/saki-builder:add --epic "<rich intent>"` — compose the rich
   intent from the G0 framing (goal · target user & job · the walking-skeleton flow · the success signal) as a
   **complete PRD-track shape**. **Pass `--epic` explicitly**: with a complete shape it triggers `/saki-builder:add`'s
   autonomous-orchestrator fallback (recorded with **no prompt**) AND makes the id deterministic — on a
   just-initialized roadmap the MVP is always **E1**. Capture the id (it will be `E1`) and use it verbatim below.
3. **Trigger-gate the follow-on scope** — anything the G0 "NOT in the MVP" list or G1 "defer" bucket
   named goes on the roadmap as `Planned` with an **objective trigger** (a prod signal/query, not a date),
   reusing `/saki-builder:pickup`'s recut/trigger-gate philosophy. Register each via `/saki-builder:add`
   **sequentially** (the id counter collides on parallel adds).

Before the handoff, **probe whether the design system is actually on disk** — the same signal
`/saki-builder:proto` GATE 2 checks (a real component library + a token source), **not** `design.md` (only a
doc). This stops the sentinel from claiming a precondition that isn't there:

```bash
{ [ -f components.json ] || ls src/components/ui/* >/dev/null 2>&1; } \
  && { ls tailwind.config.* >/dev/null 2>&1 || grep -rqs -- '--color-' .; } \
  && echo SCAFFOLD_DONE || echo SCAFFOLD_PENDING
```

Set `phase:"handed-off"`, write state, and print — **branch the message on the probe** so the human is never
told `/saki-builder:proto` can run when it can't:

**If `SCAFFOLD_DONE`:**
```
GENESIS_READY: <product> — foundations approved · roadmap seeded (E1 = MVP) · scaffold: done

✅ Product foundations set — the real design system is on disk. Next:
   1. /saki-builder:pickup E1   — writes & reviews the MVP PRD (grounds on the scaffold).
   2. /saki-builder:proto E1    — GATE 2 passes (design system exists); designs the UI + LOCKS the PRD.
   3. /saki-builder:build E1    — ships the MVP slice-by-slice.
```

**If `SCAFFOLD_PENDING`** (the Slice-1 default — G4 is a printed checklist the human still runs):
```
GENESIS_READY: <product> — foundations approved · roadmap seeded (E1 = MVP) · scaffold: PENDING

✅ Product foundations decided. ⚠ The design system is NOT on disk yet — /saki-builder:proto will stop at
   GATE 2 until you scaffold it. Next:
   1. Run the G4 scaffold checklist above FIRST, then /saki-builder:init-env — creates the real stack +
      design system + schema. (Re-run /saki-builder:genesis afterward to re-probe, or just continue once done.)
   2. /saki-builder:pickup E1   — writes & reviews the MVP PRD.
   3. /saki-builder:proto E1    — GATE 2 passes ONCE the scaffold exists; designs the UI + LOCKS the PRD.
   4. /saki-builder:build E1    — ships the MVP slice-by-slice.
```

`GENESIS_READY` on its own line is the terminal success sentinel — **both** branches emit it; the `scaffold:`
field and the body tell the human whether `/saki-builder:proto` can run yet.

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
- **One human gate, at G3 (foundations).** G0 is a lean confirm; the frontend/backend split is fixed and the
  backend *language* is decided in G3 — **always prompt Go/Rust/Python/TypeScript-Node, unless the prompt or a
  file already specifies it** (then honor that, no prompt); everything else is autonomous. Never write
  `foundations.md`/`design.md` or scaffold before G3 approval.
- **Reuse-first.** GATE 1 refuses to genesis a repo that already has a product. Reuse `frontend-design`,
  `/deep-research`, `/saki-builder:init-env`, `/saki-builder:roadmap`, `/saki-builder:add` — never re-implement them.
- **Frontend and backend are ALWAYS separate top-level folders (`frontend/` + `backend/`) — HARD RULE, no
  exceptions.** From scratch there is no unified full-stack app; a `backend/` service always exists. The
  backend **language** is **always prompted** (*Go / Rust / Python / TypeScript-Node*) — **unless the prompt
  or a project file already specifies it**, in which case honor that stated requirement and skip the prompt.
  Never silently default the language. Frontend (Next.js + Tailwind + shadcn/ui) and DB (Postgres, owned by
  the backend) are house defaults, overridable with a clear reason from G1/the vision.
- **The vision (G2) is throwaway and system-LESS** — it drives the foundation choice; it is not the deliverable.
- **Never fabricate research or foundations.** If G1 is offline, say so and proceed on the defaults + vision.
- **Always persist state before ending a turn** so a resume (context clear, killed turn) lands on the right phase.

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Running genesis on a repo that already has a stack/code | GATE 1 refuses — use `/saki-builder:add` → `/saki-builder:pickup` for an existing product |
| Writing `foundations.md` / scaffolding before the human approves G3 | G3 is the single BLOCKING gate — present, get approval, then write |
| Co-mingling frontend and backend in one app/folder (e.g. a single full-stack Next.js serving UI + API) | HARD RULE: always split into top-level `frontend/` + `backend/` from scratch — even a simple MVP; there is no unified-app option |
| Silently defaulting the backend language (or skipping the prompt) | The split is mandatory; the language is **always prompted** — Go/Rust/Python/TypeScript-Node — UNLESS the prompt or a project file already specifies it (then honor that requirement, cite the source, don't prompt) |
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
