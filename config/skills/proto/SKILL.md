---
name: proto
description: Render a faithful, throwaway UI preview of a finished PRD's COMPLETE end-to-end user journey — every user-facing step plus the connective entry/success screens that join them, each in all its reachable states — INSIDE the project's REAL app shell (nav/header/sidebar) using its real design-system components + tokens with mock data, then screenshot the full pages + states and assemble a Figma-like, journey-ordered page-overview gallery — so you see how the design looks as actual composed pages BEFORE /saki-builder:build runs. When the Figma MCP is connected, optionally also exports the same preview into Figma (editable layers, or a screenshot board) for review/edit in Figma. Sits between /saki-builder:prd and /saki-builder:build. Usage — /saki-builder:proto <prd-file.md> [--slice=N].
---

# UI Preview Stage (faithful, throwaway)

You produce **expectation-setting visibility**: what the end-user UI will look like, rendered with
the project's **real** design-system components and tokens, screenshotted across every state —
**before** `/saki-builder:build` writes a line of production code. Pipeline: `/saki-builder:prd → /saki-builder:proto → /saki-builder:build`.

This is a *preview*, not a build. Hold the line on what it is and isn't:

- **It IS faithful on**: layout, component selection, visual hierarchy, copy, look-and-feel,
  responsive behavior, **page composition within the real app shell** (nav / header / sidebar around
  the slice), and the per-state look (loading / error / empty / validation / permission).
- **It IS only approximate on**: live data density, real content lengths, true edge cases —
  these are mocked, not real.
- **It is NOT**: a backend, real data fetching, state logic, validation rules, business-rule
  implementation (PRD §10), tests, or production routes. All of that is `/saki-builder:build`.

Show this fidelity contract to the user every run. Never imply the preview makes `/saki-builder:build` trivial —
it removes the *look* risk, not the *behavior* work.

**End-to-end by default — preview the whole journey, never a curated subset:**
- **Every step, in sequence** — entry/login → each user-facing slice → success/confirmation, including the
  connective screens (landing, auth, first-run empty, intermediate result, confirmation) that join them even
  when they are not first-class §8 slices, plus the user-visible *outcome* screen of any "backend" slice. The
  flow must run start-to-finish with no gap.
- **Every reachable state** — for each screen render all states it can actually reach (happy / loading /
  empty / validation-error / server-error / permission), not just the happy path.
- **Whole PRD by default** — a no-arg run previews the entire journey; `--slice=N` and omitting a state are
  explicit, justified narrowings, never the implicit behavior.
- **Coverage is gated, not promised** — GATE 1 writes a **Screen Manifest** of every screen the finished
  PRD produces; the **Coverage Gate** (before Completion) HARD-STOPS unless every manifested screen has a
  captured frame at both viewports. All screens, no curation — a skipped screen fails the run, not a
  footnote in `index.md`.

---

## Input

Usage: `/saki-builder:proto <E<n> | prd-file.md> [--slice=N]` (filler words fine) — or `/saki-builder:proto --figma-only <gallery-dir>`
to (re)export an existing gallery to Figma without re-rendering (runs Step 6c only).

Locate the PRD exactly like `/saki-builder:build`. **Epic id (`E<n>`) — the disciplined path:** if the argument
is an epic id, read `tasks/roadmap.md`, find `### E<n>`, and resolve its `**Child PRD:**` link to
`tasks/prd-<slug>.md`. If `E<n>` has no Child PRD yet (its value is `—`), **STOP**: `E<n> has no PRD yet —
run /saki-builder:pickup E<n> first`. Otherwise take the token ending in `.md` (or matching `prd-*`), and
check, in order: `tasks/<name>`, `./<name>`, the path as given. `--slice=N` is an explicit narrowing
flag that previews one slice in isolation; the default (no flag) always previews the **complete
end-to-end journey** across every user-facing step.

**`--figma-only <gallery-dir>` mode** — skip GATE 1 → Step 6b entirely; take an existing
`tasks/proto-<slug>/` (its PNGs) and run **only Step 6c** against it. Purpose: run the Figma export on a
machine where the Figma MCP **is** connected (e.g. your Mac with Figma desktop), against a gallery rendered
elsewhere (e.g. a headless VPS / Studio run that skipped Figma — see Step 6c "headless/VPS reality"). Here
the Figma MCP is **required** — if it's absent, STOP and say so (it's the explicit purpose, not a silent skip).
The live route isn't running in this mode, so **Tier B** (screenshot board from the existing PNGs) is the
path; the `<prd-slug>` for the Figma file name comes from the gallery dir (`proto-<slug>/`). For **Tier A**
editable layers, run a full `/saki-builder:proto` on the Figma-connected machine instead (it re-renders the live route).

---

## Step 0 — Design engine (read the recorded choice, then route)

Before loading the PRD, read the project's recorded **design engine** — it decides whether this preview
is rendered **natively** (the canonical path) or seeded from a **Figma** source. Run from the repo root:
```bash
~/.claude/hooks/design-engine-setup.sh detect
```
Route on `engine`, adding a **live** Figma check when the record says `figma`. **Invariant: the native HTML
gallery is ALWAYS the canonical deliverable `/saki-builder:build` reads — Figma never becomes build's
source (honesty rail). Figma, when selected, only *seeds* the native render and/or receives an export.**

| recorded `engine` | live check | how this run behaves → resolved mode |
|---|---|---|
| `native`, or `status: NONE` (no record) | — | proceed exactly as below — native render → gallery. Step 6c export keeps its normal optional-when-connected behavior. → **`native`** |
| `figma` | call the Figma MCP **`whoami`** — it FAILS / MCP absent here | **fall back to native** for this run; note once: *"design engine is figma but the Figma MCP isn't reachable here — rendered native; run `/saki-builder:proto --figma-only <gallery>` on a Figma-connected machine to export."* → **`native`** |
| `figma` | `whoami` OK, `figma_capability: read` (View/Dev seat) + `figma_source` set | **design-to-code reference**: still render natively, but seed each screen from the Figma source (Step 5's figma-reference note). Skip the Step 6c write-export — the seat can't write; note it. → **`figma-read`** |
| `figma` | `whoami` OK, `figma_capability: write` | design-to-code reference (when a `figma_source` is set) **and** run the Step 6c export normally. → **`figma-write`** |

Carry the **resolved mode** (`native` / `figma-read` / `figma-write`) forward — Steps 5 and 6c read it.
**The live check always wins over the record**: recorded `figma` but MCP down → `native`; recorded
capability `write` but the live seat is now read-only → `figma-read`. Note the downgrade; never fail the
run over an engine mismatch. A `--figma-only` run ignores Step 0 (it is an export-only path by definition).

---

## GATE 1 — Load the PRD (hard stop if missing)

Read the PRD. If it cannot be found/read, **STOP**:
```
HARD STOP — PRD NOT FOUND
Looked for: tasks/<name>, ./<name>, <name>
Pass a valid PRD path: /saki-builder:proto <prd-file.md>
```
Do NOT invent a PRD. From it, extract:
- **§8 Vertical Slices** — the work list. Include every slice with any **user-visible** outcome — a
  screen/route a user hits, OR the result / confirmation / notification screen a "backend" slice produces.
  Skip a slice only when it has *no* user-visible surface at all (pure infra/migration). A backend slice is
  not automatically skippable: if its effect is something the user eventually sees, render that outcome
  screen so the journey has no gap.
- **§9 Acceptance Criteria** — the observable UI behaviors → which states to render.
- **§10 Business Rules & Invariants** — surfaces UI variants (e.g. "rejected if amount > balance"
  → a validation/error state to show).
- **§11 Non-Goals** — never render beyond them.

**Assemble the complete journey, not just the slices.** From the slices + §9 + the Gherkin, lay out the
full end-to-end path the user walks: the **entry point** (landing/login), every user-facing step in
sequence, the **connective screens** that join them (auth, first-run empty, intermediate confirmations),
and the **terminal** success/confirmation. Add these entry/connective/terminal screens to the screen list
even when they are not standalone §8 slices — the deliverable is one continuous journey, not a set of
isolated slice previews. Guard: connective screens are *journey glue* (the app's real login/landing/success,
the minimal confirmation a step implies), not new scope — never invent a feature beyond §11.

**No dead-end affordances — cover every surface the app shell exposes (BLOCKING completeness check).**
Once the app shell is detected (Gate 2), **walk its real navigation**: every header/nav item, every
sidebar/menu entry, and every primary affordance that implies a destination (a clickable row → a detail
view, a "+"/CTA → a create surface). **Each one must map to a rendered proto screen in the journey
list.** A shell that advertises `Activity`, `Completed`, or a clickable card while the proto renders only
the §8 slices produces dead-end affordances — the exact "I didn't see the end-to-end UI" failure. Resolve
every gap one of two ways, never silently:
- **The surface is in scope** → add it to the journey AND ensure the PRD defines it (a surface the proto
  shows must be a surface `/saki-builder:build` builds — if it's not in §8, flag it back as a PRD gap to add first;
  proto and PRD must agree).
- **The surface is genuinely out of scope** (§11) → it must NOT be a live affordance in the shell. Note
  it, and treat the dangling nav item as a shell-fidelity bug to remove, not a screen to invent.
This is distinct from "never invent a feature beyond §11": that forbids *adding* scope; this forbids
*shipping a shell that promises scope the journey doesn't cover*. The reconciliation is two-way.

Also read any `tasks/*-flow.md` (rplan Step 2.5 Gherkin) for the slice — it already enumerates the
states the user expects. If present, it is the authoritative state list.

**Persona check:** after loading the PRD, check if `.claude/personas/*.md` exists. If it does,
read the relevant persona(s) and use them to inform:
- Copy tone and vocabulary (§4 Mental Model — match their language, not technical jargon)
- Which states to emphasize (§6 "Must never experience" → always render that failure state)
- Interaction density and affordance size (§5 UI/UX Constraints — e.g. mobile context = larger tap targets)
Cite the persona when it drives a visual decision: `→ persona/buyer.md §5`.

**Write the Screen Manifest — the coverage contract (BLOCKING artifact, no negotiation).** Enumerate
EVERY screen the finished PRD produces — the entry point, every §8 user-visible slice, every backend-slice
*outcome* screen, every connective glue screen, every shell nav/affordance destination (Gate 2's walk),
and the terminal success — as a numbered list to `tasks/proto-<prd-slug>/screen-manifest.md`, each row
tagged `[slice §8.N]` / `[glue]` / `[shell-affordance]` / `[outcome]`. This list is the **canonical screen
count** for the whole run: the Coverage Gate (before Completion) hard-checks that every row has a captured
frame. It is "what the flow looks like when the PRD is complete" written down once, so completeness is
*verifiable*, not asserted. Derive it mechanically from the PRD — do NOT pause to let scope be negotiated
down; the manifest is the floor, not a proposal. A no-arg run manifests the ENTIRE journey; only an
explicit `--slice=N` may scope the manifest to one slice, and it is then labelled `PARTIAL` at the top of
the file and in the Completion Output — never the default. **Do not start rendering (Step 3+) until the
manifest is written.**

**No-UI PRD branch (`/saki-builder:proto` is still the freeze gate).** If the finished PRD produces **no
user-visible screen** — every slice is pure infra/backend with no route and no outcome/confirmation/
notification screen a user ever sees (no §15 inventory, no user-visible surface on any slice) — there is
nothing to preview. Do **NOT** fabricate screens. Skip **Gate 2 and Steps 2.5–8 entirely** (a backend PRD
needs no design system, so Gate 2's STOP must not fire here) and go straight to **Step 8.5 (Lock the PRD)**:
here `/saki-builder:proto` serves only as the **explicit freeze gate** before build. Tell the
human plainly — *"This PRD has no user-visible screens — nothing to preview; running proto now freezes the
requirements for build"* — and on their confirmation write the lock with `ui:none`. This keeps
`/saki-builder:proto` the single lock writer for **every** PRD, so `/saki-builder:build` (which hard-refuses an
unlocked PRD) has one consistent gate regardless of whether the feature has UI.

---

## GATE 2 — Design-system detection (BLOCKING — the honesty gate)

A faithful preview is only possible if the project has a real, code-level design system to render.
This gate is the entire reason "1:1" is true rather than aspirational. Detect:

- **Component library** — `components.json` + `components/ui/*` (shadcn/ui); or MUI / Chakra /
  Mantine / Ant Design / Radix in `package.json`; or a local `src/components/` (or `app/components`)
  library with reusable primitives.
- **Tokens** — Tailwind `@theme` directive / `tailwind.config.*`; CSS custom properties
  (`--color-*`, `:root` vars); a `tokens.*` / `theme.*` file.
- **Framework / harness** — React, Next.js, Vite, Remix, Vue, SvelteKit (from `package.json` +
  config files) — decides how to mount a preview route, and whether Storybook is present.
- **App shell / layout** — the real page chrome the feature will live inside: a root `layout.*`
  (Next), an `app/App.tsx` / `main.*` root (Vite/Remix), or a `<Layout>` / `<AppShell>` / `<Sidebar>` /
  `<Nav>` / `<Header>` primitive. **Record its import path** — this is what Step 5b **composes around**
  the slice so the preview looks like the actual page (a real screen, not a fragment in a void). If the
  app genuinely has no chrome (a bare single-page app), note it; 5b then renders the slice alone.

Verify by grep/read, not assumption (e.g. open `components.json`, list `components/ui/`, read the
token file, open the root `layout.*` / `App.tsx`). Then branch:

| Detection | Action |
|-----------|--------|
| **Found** (components + tokens) | Record import paths (components + the app shell/layout, for 5b) + token source. **Always run Step 2.5** — slices may need components not yet in the library. |
| **Partial** (tokens xor components) | State which half is real vs. approximate. **Run Step 2.5** to design the missing half as proper extensions. |
| **None** | **STOP — do not fabricate.** |

On **None**, output and stop:
```
NO DESIGN SYSTEM FOUND — a faithful preview is impossible.
Rendering a preview now would invent components that /saki-builder:build then contradicts (guaranteed drift).
Options:
  (a) Scaffold one  — shadcn/ui + Tailwind tokens per design.md, then re-run /saki-builder:proto
  (b) Directional mock — I generate a looks-like mock (drift expected; expectations approximate)
  (c) Skip preview — go straight to /saki-builder:build
Pick a/b/c.
```
Never silently invent a component set — that is the exact failure this gate exists to prevent.

---

## Step 2.4 — Existing-implementation inventory (reuse-first grounding — BLOCKING frame)

**The most common proto failure is a "design-wise correct" render that does NOT look like the existing
app** — the agent self-initiates a fresh design of the navbar / sidebar / feature screen instead of
**composing the real, already-implemented components**. This step exists to flip the frame from
*"design the screens"* to *"assemble the actual app"*. Run it BEFORE the gap analysis (2.5).

**Think like the designer at their desk: look at the real page first, then reason about the delta.** A
senior designer doesn't start from the spec — they open the *existing* app, see what already ships, and
only then ask three questions per screen: **(a) where does a component need to be *added*?** **(b) which
existing component needs to *scale* (a variant)?** **(c) how does the user *interact* here, and does the
current component set support that interaction?** Those three questions ARE the gap analysis (2.5) — 2.4 is
the "look first" that must precede them. So for any screen that **modifies an existing page**, capture that
page's **current-state screenshot** as the visual baseline you design the delta against (a brand-new screen
with no predecessor skips this — there is nothing to look at yet).

Gate 2 detected the design *system* (primitives + shell) and the *app shell import path*. That is not
enough: a journey usually reuses **existing feature-level implementation** too — a page already built, a
card / table / list-row / form / detail view that ships in the real app today. Inventory it:

1. **Shell** — confirm the ACTUAL navbar / sidebar / header component import paths (from Gate 2). These
   are imported verbatim; they are never re-drawn.
2. **Per screen in the journey** — grep the real feature area for already-implemented components/screens
   this screen reuses. Search where the app keeps features, not just the design system:
   `src/features/**`, `app/**` (route/page components), `src/components/**` **beyond** `ui/`, `modules/**`,
   `pages/**`. Match by the screen's nouns (the entity, the list, the detail) and by the nav destination.
3. **Read what you find** — open each candidate to confirm it renders the surface this screen needs
   (don't match on filename alone).

Write a **Reuse Map** to `tasks/proto-<prd-slug>/reuse-map.md`, one row per screen:

```
Reuse Map — <prd-slug>
──────────────────────────────────────────────────────────────────
screen                 building block            classification   import path
Products (list)        AppShell (nav+sidebar)    EXISTING         @/components/layout/AppShell
Products (list)        ProductTable              EXISTING         @/features/products/ProductTable
Products (list)        Button, Badge             PRIMITIVE        design-system (Gate 2)
New Product (form)      ProductForm               NEW              — (spec in 2.5)
```

- **EXISTING** → the component/screen is already implemented → **import & compose VERBATIM.** Proto NEVER
  re-approximates an EXISTING component into a "design-wise correct but different" version. The fidelity
  target is the **existing app's look**, not a fresh design of it.
- **PRIMITIVE** → a design-system primitive (Gate 2) → use as-is.
- **NEW** → no equivalent exists → flows to Step 2.5 for a spec. **Only genuinely-absent surfaces.**

**Reuse-first is the rule, not a preference:** if a screen is largely already implemented, proto's job is
to mount the real implementation with mock data — not to redesign it. Do NOT send an EXISTING component to
the 2.5 gap analysis; the gap analysis is only for what the app does not yet have. The provenance check
(5d) later verifies the render actually imported every EXISTING/shell row here.

---

## Step 2.5 — Design System Gap Analysis (always runs after Gate 2)

**Scope rule — library vs. custom layer (critical for MUI/Chakra/Mantine/Ant Design projects):**
If the project uses an npm component library (MUI, Chakra, Mantine, Ant Design, Radix, Headless UI),
treat **all of that library's primitives as ✅ by default** — do NOT list them individually (Paper,
Button, TextField, Avatar, etc. are ✅ implied). Enumerate **only**:
- Custom business components built on top of the library (e.g. `SaasBar`, `BuildRow`, `EmptyState`)
- Business-semantic tokens not yet in the token file (e.g. `tokens.status.review` if missing)

A table that lists 15 trivially-✅ MUI primitives before one real ❌ buries the signal. Focus only
on the non-trivial layer.

**Cross-reference scope (IMPORTANT):** check ONLY the Gate 2 library paths (`src/components/`,
`components/ui/`, etc.). Explicitly **exclude** `src/proto/**`, `proto-preview/**`, and any
Storybook story files — components found there are NOT in the design system. Also grep the previous
proto harness files for any named exports NOT in `src/components/` — each is a candidate ❌ Missing
that survived the last run un-codified.

Classify each custom component **against the Step 2.4 Reuse Map** — gap analysis is only for what the app
does NOT yet have:

- ✅ **Exists** — found in the Gate 2 library path **OR the Step 2.4 Reuse Map (an already-implemented
  shell / feature component)** → **import & use VERBATIM**, never re-spec or re-approximate it. An EXISTING
  Reuse-Map row is out of scope for this analysis; it is composed, not designed.
- ⚠️ **Variant needed** — base component exists but lacks a required style variant or semantic token
- ❌ **Missing** — no equivalent in `src/components/`, the npm library, or the Reuse Map (genuinely new)
- 🔶 **Needs design change** — the existing design/pattern can't host this screen *well* with a variant or
  a single new component: the journey needs the app **shell/nav restructured**, a page's **layout paradigm
  changed**, a **pattern the design system doesn't have**, or a fix that **ripples across >1 screen**. The
  rung above ❌ — reach it only when adding a component isn't enough (escalation below).

**Guard — do not spec-and-rebuild something already implemented.** Before writing any ⚠️/❌ spec, confirm
it isn't an EXISTING row in the Reuse Map. Re-creating an implemented navbar/sidebar/feature component as
a "new" spec is the exact self-initiated-build failure this gate must prevent.

**The cost ladder — climb only as high as the screen forces you (concise + faithful).** Reuse (✅) < scale
(⚠️) < add (❌) < propose a design change (🔶). Each rung is more expensive and less faithful than the one
below, so pick the LOWEST rung that works and add the minimum — never jump to a new component when a variant
does, never redesign when a component does. Judge each screen's needed **interaction** here too: a component
that renders the right pixels but can't support the interaction the journey needs is a ⚠️ (scale it), not a ✅.

**🔶 escalation — propose, don't force-fit, and don't silently redesign.** Judge the change by size:
- **SMALL** (local to one screen, absorbable as a variant/component) → it isn't really 🔶; resolve it as
  ⚠️/❌ and note it.
- **BIG** (shell/nav, a page's layout paradigm, a net-new pattern, or a ripple across >1 screen) → **STOP and
  PROPOSE**: write a 4–6 line design-change proposal — *what the existing design constrains · the option(s) ·
  the rough cost · the screens affected* — and PAUSE for the human, exactly like the Step 2.5 confirm below.
  Never force the journey into a design that can't hold it; never self-initiate a big redesign without
  sign-off. If the approved change alters **scope** (new features/screens, not just layout/pattern), that is a
  **PRD concern** — point back to `/saki-builder:prd` to reconcile (GATE 1's two-way rule), then re-run proto. A
  layout/pattern/component change that stays within the PRD's scope proceeds here (built in Step 2.6).

**For ⚠️ variants — library project branching rule:**
- If the variant is **purely stylistic** (a color set, a size, a border tweak) on a single library
  component → resolve via **theme override** (add to `theme.ts` `components.MuiChip.variants`,
  `components.MuiButton.styleOverrides`, etc. for MUI; `extendTheme` in Chakra). Do NOT create a
  wrapper file — theme overrides are the idiomatic path and keep MUI's `sx`/palette integration intact.
- If the variant **combines multiple primitives** or contains interaction logic → create a local
  wrapper component file.

For every ⚠️ and ❌, produce a **component spec** that thinks like a UI/UX designer:

1. **Name** — follow existing naming conventions (PascalCase; mirror library patterns like
   `SaasBar`, `StatusBadge`, not `status_badge` or `badge_status`)
2. **Resolution path** — for ⚠️: "theme override in `theme.ts`" or "new wrapper file"; for ❌: "new file"
3. **Variants / props** — list prop names using the same vocabulary as existing components
   (e.g. if library uses `variant="primary|secondary"`, new components use the same `variant` key)
4. **Design tokens** — list any new token additions required, **in the format the project already uses**:
   - MUI TS tokens object → `tokens.status.review: '#a371f7'` in `theme.ts`
   - Tailwind CSS v4 → `@theme { --color-status-review: ... }` in globals
   - Tailwind CSS v3 → `theme.extend.colors.status.review` in `tailwind.config.*`
   - CSS custom properties → `--color-status-review: ...` in `:root` in globals
   Prefer extending existing token scales. If a token already exists, cite it — do NOT duplicate.
5. **States** — hover, focus, disabled, loading, error, selected — only what the component actually needs
6. **Accessibility** — ARIA role, keyboard behavior, contrast check (4.5:1 minimum)
7. **Consistency check** — name 2–3 closest existing components; note deviations and why

Present the gap analysis as a labelled table before rendering. Example format (library-based project
— MUI-style; replace token format with the project's actual format):
```
Design System Gap Analysis
──────────────────────────────────────────────────────────────────
MUI library           — all primitives (Button, Paper, etc.) ✅ baseline

Custom layer:
⚠️  status token set         — tokens.status.review missing from theme.ts
❌  SaasBar                   — custom app bar (Logo + plan Chip + Avatar + Logout)
❌  EmptyState                 — icon + title + description + optional CTA

Proposed additions:
1. tokens.status.review (⚠️ theme override — theme.ts)
   Add: tokens.status.review: '#a371f7'  (consistent with existing status palette)

2. SaasBar (❌ new component — src/components/SaasBar.tsx)
   Props: appName, planLabel, user: { name, avatarUrl }, onLogout
   Uses: MUI AppBar + Chip + Avatar + IconButton; tokens.brand for logo color
   A11y: nav landmark, logout button aria-label="Sign out"

3. EmptyState (❌ new component — src/components/EmptyState.tsx)
   Props: icon, title, description, action?: { label, onClick }
   Tokens: none new — uses existing Typography + spacing
   A11y: presentational; action inherits Button a11y
```

**Pause here and ask for confirmation** — this now gates real code, not just a render:
> "These specs will be **codified into the real design system next (Step 2.6), then rendered as the real
> components** — so what you approve in Step 7 is the real component, not an approximation. Confirm the
> specs to proceed, or adjust any now. This is the cheapest correction point — before any real code is
> written."

Do NOT proceed to Step 2.6 / rendering until the user confirms (or silently adjusts and re-presents if the
user requests a change). This is the cheapest point to catch a wrong component direction — before any real
design-system code is written.

If all components exist (no ⚠️/❌ entries), state "No design system extensions needed" and
proceed to Step 3 without a pause.

---

## Step 2.6 — Codify confirmed additions into the real design system (BEFORE rendering)

> **Add first, then design with it — the designer's order.** A designer adds a component to the library,
> then places instances; they don't sketch a throwaway and rebuild it. So the moment the Step 2.5 specs are
> confirmed, build them for **real** — before Step 5 renders — so the proto composes real components
> everywhere (EXISTING from 2.4 + these NEW/⚠️ ones) and the Step 7 approval is on the real thing. This
> closes the old fidelity gap (a human approved an *approximation* of a NEW component that `/saki-builder:build` then
> rebuilt differently) and removes the build-it-twice duplication.

Apply each confirmed ⚠️/❌ from Step 2.5 using the resolution path its spec already named — now, pre-render:
- **⚠️ variant (stylistic, single primitive)** → add to the theme file (`components.MuiX.variants` /
  `styleOverrides`, `extendTheme`, Tailwind `@theme` / config, or `:root` CSS vars — the project's format
  detected in 2.5). No wrapper file for a purely stylistic variant.
- **⚠️ variant (multi-primitive / logic)** or **❌ missing** → a new component file at the Gate-2 location
  (`src/components/…`), presentational only (no data / no logic), consuming tokens via the project's detected
  mechanism, exported from the barrel if one exists, following the existing prop / naming / file conventions.
- **Tokens first** → add only the approved tokens in the project's format; extend existing scales, never
  duplicate or add speculative ones.
- **Update `design.md`** — add the new component(s) with a one-line entry matching the existing style.
- **Write `tasks/proto-<prd-slug>/design-system-updates.md`** (project's actual token format):
  ```
  Design System Updates — <prd-slug>
  ═══════════════════════════════════
  New component files:      - SaasBar (src/components/SaasBar.tsx)
  Theme overrides added:    - components.MuiChip.variants: status color set (success/warning/error)
  Token additions:          - tokens.status.review: '#a371f7'  (or --color-status-review: #a371f7)
  ```

**Gate:** typecheck the new components/tokens before Step 5 — they are imported next, so a broken one crashes
every frame. Codify only ✅-confirmed ⚠️/❌ — **never a 🔶** (a big design change is escalated in 2.5 for
sign-off, not built here). If 2.5 found no ⚠️/❌, state "No additions to codify" and continue to Step 3.

---

## Step 3 — Map slices → screens × states

For each screen in the journey (every user-facing step + the connective screens from GATE 1),
enumerate the **states** to render. Pull states from §9 criteria, §10 rules, and the Gherkin (if present).
Render **every state the screen can actually reach** — default to the full set below; omit a state only
when it is genuinely impossible for that screen, and say which and why. The bias is completeness, not
curation:

- **happy** (mandatory) — the primary success view
- **loading** — skeleton/spinner while data resolves
- **empty** — zero-data view (first run / no results)
- **validation-error** — inline field error from an invalid input
- **server/network error** — the common toast/retry surface
- **permission-denied** — only if the slice involves multiple roles

One screen may carry several states. Collapse only states that render pixel-identical; never drop a
reachable state just to shorten the list.

---

## Step 4 — Mock data (honest density, not lorem-perfect)

Generate mock data that exposes real layout stress, since this is the one axis where a preview can
mislead:
- **long** strings (a name/title near the realistic max), to test truncation/wrap
- **many** rows (a full list/table), to test density and scroll
- an **empty** set, for the empty state
- realistic value shapes (currency, dates, status enums) matching the domain in the PRD

Do NOT use uniform short lorem-ipsum that hides overflow and density problems — that produces a
preview that lies.

---

## Step 5 — Render in a throwaway harness that composes the REAL shell

Mount the screens by **composing the real, already-implemented components** — the app shell
(nav/header/sidebar) AND every **EXISTING** feature component in the Step 2.4 Reuse Map — plus the
Gate 2 primitives + tokens, with mock data only — **no fetching, no backend, no state logic**. **Import
the actual implemented components; never hand-write a re-creation of them.** The goal is a preview that
looks like the **existing app**, not a fresh design of it and not an isolated component on a blank canvas.
A "design-wise correct" render that doesn't match the shipped implementation is a failure, not an
approximation — reuse the real component instead (Step 2.4). Every component is now **real**: EXISTING ones
from the 2.4 Reuse Map, and the NEW/⚠️ ones just codified in **Step 2.6**, all imported by their real
design-system paths. **Nothing is approximated** — there is no bespoke stand-in for a NEW component anymore
(2.6 built it), so the Step 7 approval lands on the real component.

**Figma-reference (only when Step 0 resolved to `figma-read` / `figma-write`).** Before mounting each
screen, pull its design intent from the recorded `figma_source` via the Figma MCP read tools —
`get_design_context` (layout, spacing, component names, tokens) and `get_screenshot` (the visual target)
for the matching frame. Use it to **guide the native render** (which components, order, spacing, copy),
mapping Figma layers onto the project's REAL design-system components from Gate 2 — never hand-copy pixels
or invent components the design system lacks. The output is still the native gallery; Figma is the
reference, not the deliverable. If a screen has no matching Figma frame, render it natively from the PRD as
usual and note the gap. In `native` mode, skip this entirely.

### 5a. Provider/context detection (do this BEFORE mounting — the #1 render failure)

Real apps wrap their UI in providers; a bare preview route that imports a component needing one
throws on first render (works on a toy app, fails on a real one). Before mounting, read the root
`layout.*` / `_app.*` / `main.*` provider chain and identify what the slice's components require:
- **theme / design-system provider**, **toast/notification context**, **i18n / locale provider**,
  **auth / session provider**, **data-layer** (React Query / SWR / Apollo).

**Two distinct jobs — keep them separate (this is the heart of full-shell composition):**
- **Providers → MOCK** (theme, toast, i18n/locale, auth/session, data-layer): wrap the preview in
  them with everything external **mocked**. Never boot real auth/session or hit a DB — supply a mock
  session/user, a mock locale + messages, and stub the data-layer with static mock data.
- **Layout / chrome → RENDER REAL** (the app shell from Gate 2: nav, header, sidebar, footer): these
  are presentational, so **render them for real around the slice** — that is what makes the preview
  look like the actual page. Do NOT mock or strip the shell.

If the provider chain is **env-dependent and not cheaply mockable** (e.g. auth requires live keys at
module load) so the real shell can't mount, do NOT fight it — fall back to the bare harness (5b#2),
and note the lost chrome in `index.md`.

### 5b. Harness choice (in priority order — by page-composition fidelity)

What the user ultimately sees is the **captured** screenshots (Step 6), embedded in the static
`preview.html` that Pipeline Studio opens. So the harness's only job is to **render the slice the way
the real page will look** — the more it composes the real app shell, the more faithful the capture.
(There is no live Studio route to optimize for: the Studio opens the static gallery, not a dev server.)

1. **Full-shell composition** (PREFERRED) — create the throwaway preview under
   `app/proto-preview/<slice>/page.tsx` (Next) or a `proto-preview` route (Vite/Remix), and have it
   **import the app's real layout/shell from Gate 2 (nav, header, sidebar) AND the EXISTING feature
   components from the Step 2.4 Reuse Map, and render the slice inside them**, wrapped in the 5a mock
   providers with mock data. Import the real components by their recorded paths — do not re-draw a
   navbar/sidebar/feature component the app already ships. The capture then looks like the
   actual page — not a fragment in a void, and not a redesign of it. ALSO create a routable
   **`/proto-preview` index** linking each slice. Drive states via a query param (`?state=empty|loading|error`), or stack all states in
   one labelled page.
   - **Next App Router gotcha:** do NOT name the folder with a leading underscore (`_proto`,
     `__proto`). Underscore-prefixed folders are **private** / non-routed → the route 404s. Use a
     routable name like `proto-preview/`. (Keep `__PROTO__` only as an in-file banner string.)
   - **Locale apps:** place the preview under `app/[locale]/proto-preview/<slice>/` so it inherits the
     locale provider **AND that layout's real shell** — which is exactly what full-shell composition
     wants. (A sibling outside `[locale]` skips the shell; prefer the in-`[locale]` placement + the 5c
     middleware bypass.)
2. **Bare / standalone harness** (FALLBACK — only when the real shell can't mount) — when the app
   shell pulls **env-locked** providers (e.g. auth requires live keys at module load) that can't be
   cheaply mocked, render just the slice's component subtree in a minimal page supplying only the 5a
   mock providers, bypassing the real root layout. This is the old default; it **loses the global
   chrome**, so **note the fidelity reduction in `index.md`** ("rendered without the app shell").
   **Storybook** (`.stories.tsx`, the `component` skill's convention) is an equivalent isolation
   option here.

(The preview always lives in the `proto-preview` namespace — isolation + `/saki-builder:build` teardown, Step 8.
It is a **capture harness**, not a live route.)

### 5c. Auth gate (default-deny middleware)

Many apps run **default-deny** auth middleware: any route not in a public allowlist redirects to
`/login`. A preview route will be redirected (`307 → /login`) and never render. Add a **scoped,
reverted-on-cleanup** bypass so ONLY the preview namespace skips auth — real routes are unaffected,
so a running dev server / the user's session sees no behavior change:

```ts
// __PROTO__ — dev-only preview routes bypass auth (throwaway; remove on cleanup)
if (strippedPathname.startsWith('/proto-preview')) return intlMiddleware(request);
```

Place it at the TOP of the middleware, before the auth check. Record it in the cleanup contract
(Step 8) — it must be reverted with the route.

### 5d. Mount, mark, serve

- **Visible prototype banner (required):** render a banner element in the `/proto-preview` page
  body containing the literal token `__PROTO__` and the text
  `⚡ Prototype preview — UI only · mock data · controls inert`. This does double duty: (1) it sets the
  operator's expectations so a faithful-but-inert page isn't mistaken for a broken app, and (2)
  `__PROTO__` is the **health-check sentinel** the Studio greps in the page body to confirm a real
  render (Step 5e `readySentinel`). Also keep the disposable source comment
  `// __PROTO__ — throwaway preview, do not ship` on every preview file.
  **Place it in normal document flow (a static block at the end of the body), NOT `position:fixed`/`sticky`.**
  A fixed/overlay banner renders at the *first viewport's* edge, so in a **full-page** capture (Step 6a,
  `fullPage:true`) it lands in the MIDDLE of a tall page and overlaps real content — a capture-fidelity bug
  that's invisible on a short desktop page but obvious on a long mobile one. In-flow = it appears once,
  cleanly, after all content, at every viewport.
- **Isolation:** preview files live only under the `proto-preview` namespace (or Storybook) so they
  are trivially deletable and can never reach production.
- **Typecheck/lint the harness FIRST (cheap pre-render catch):** before serving, run the project's
  typechecker/linter over the generated `proto-preview/*` files (`tsc --noEmit`, `eslint <files>`, or the
  repo's own script). A used-but-not-imported symbol or a type error is a runtime crash that renders the
  error boundary (real, observed: `useState` used without importing it → `ReferenceError` on every render).
  Catching it here costs one command; missing it costs a whole gallery of captured error frames.
- **Provenance check FIRST (BLOCKING — proves the render reuses the real implementation):** before
  serving, grep the generated `proto-preview/*` files and confirm they **`import` the real app shell AND
  every EXISTING feature component named in the Step 2.4 Reuse Map**, by their recorded import paths.
  Mechanical — for each EXISTING/shell row, its recorded import path must appear as an import somewhere
  in the harness:
  ```bash
  # run once per EXISTING/shell row; empty result ⇒ that real component was NOT imported ⇒ HARD-STOP
  grep -Rl "<recorded-import-path>" app/proto-preview src/proto-preview 2>/dev/null
  ```
  If a screen the Reuse Map marked **EXISTING** was instead rendered from bespoke markup (the recorded
  path is not imported anywhere in its harness file), **HARD-STOP: "re-approximated an implemented
  component — import `<path>` instead."** Fix the harness to import the real component, then continue.
  This is the check that stops a "design-wise correct but not the existing app" render before it is ever
  captured — presence of a designed screen is not proof it reused the real implementation.
  **Extend the same check to every NEW row:** Step 2.6 made it real, so its design-system import path must
  ALSO appear in the harness — a NEW component rendered from bespoke stand-in markup instead of its codified
  file is the same failure (**import `<path>` instead**). After 2.6 there are no approximations to render.
- **Serve & verify:** if a dev server is already running on the project's working dir (`lsof -i
  :PORT` shows it, cwd matches), reuse it — hot-reload picks up the new route; no boot needed.
  Otherwise start it. Then smoke-test the route with `curl` (expect HTTP 200, no `Failed to compile`).
  **Treat `curl` as a smoke test only, NOT the render gate:** curl sees the *SSR HTML*, so a CLIENT-side
  throw (a missing provider/import that crashes on hydration) still returns 200 with the SSR banner while
  the browser shows the error boundary — a green curl on a broken page. The **authoritative** render check
  is the headless capture's per-frame hard gate (6a): it requires the `__PROTO__` sentinel in the LIVE DOM
  and fails on any `pageerror` / error boundary. Do not assume the route came up; never screenshot an error
  page (return to 5a/5c).

### 5e. (Legacy / optional) Write the live-preview manifest

> **Honesty note (2026-06-27):** the current Pipeline Studio opens the **static `preview.html`**
> (Step 6) and **ignores this manifest** — the live-dev-server bridge was removed. The static gallery
> is the real deliverable. Writing the manifest is **harmless and optional, not required**, and
> nothing downstream depends on it (`/saki-builder:build` does not read it). Skip this sub-step unless you have a
> specific reason; if you do write it, do not advertise it as enabling a live preview.

If — and ONLY if — a routable `proto-preview` entry serves cleanly (5b option 1), you MAY write
`tasks/proto-<prd-slug>/preview.json` for forward-compat. Compose it from the Gate-2 detection:

```json
{
  "devCommand": "npm run dev -- --host 127.0.0.1 --port {PORT} --strictPort",
  "route": "/proto-preview",
  "readySentinel": "__PROTO__",
  "framework": "vite"
}
```

- `devCommand` — a shell template; **leave the literal `{PORT}`** in place (the Studio substitutes a
  free port). **Bind to `127.0.0.1`** (Vite `--host 127.0.0.1`; Next `-H 127.0.0.1`). Compose for the
  repo's package manager: npm needs `-- ` before flags (`npm run dev -- --host …`); pnpm/yarn forward
  directly (`pnpm dev --host …`). Add `--strictPort` for Vite (Next errors on a busy port already).
- `route` — the `/proto-preview` index entry (5b). `readySentinel` — `__PROTO__` (the visible banner,
  5d). `framework` — informational.

Then **emit a machine-readable marker on its own line** so the Studio's stream parser finds it:
```
PROTO_PREVIEW_MANIFEST: tasks/proto-<prd-slug>/preview.json
```
Storybook-only / static-only runs (5b options 2–3) do NOT write a manifest or the marker — the Studio
then shows no live Preview for that run (the screenshot gallery still stands as the record).

---

## Step 6 — Screenshot + interactive Figma-flow gallery via headless Playwright

### 6a. Capture — screenshots + hotspots in one headless pass

**Engine (VPS-critical).** Capture renders the served route (5d) to PNGs. Prefer **headless Playwright**:
it runs with no desktop browser and no extension, so it works identically on your laptop AND on a headless
VPS — which is the whole point of the static gallery. The **claude-in-chrome MCP** (`mcp__claude-in-chrome__*`)
is the **local-only fallback**, used only when Playwright can't be made available.

- **Detect:** `node_modules/.bin/playwright --version` (already a dep in many JS repos) — if present, use it.
- **Install (local dev):** `npm i -D playwright && npx playwright install chromium` (~150 MB, needs network).
- **Bootstrap (headless VPS — run ONCE per image):** `npx playwright install --with-deps chromium`. The
  `--with-deps` flag also `apt-get`s the system libraries + base fonts that headless chromium needs on a bare
  Linux box; **without it chromium either fails to launch or renders `□` tofu** for missing glyphs. Two font
  follow-ups for faithful text: (1) the app uses `system-ui`/`-apple-system`, which on Linux falls back to
  whatever is installed — for parity with macOS, pin a UI font in the image (`apt-get install -y fonts-inter`,
  or drop the `.ttf` in + `fc-cache -f`); (2) **emoji** in the UI (e.g. the 💬 badge) need
  `fonts-noto-color-emoji` or they render as tofu. (Containers: bake all of this into the Dockerfile, not the
  run step.)
- **Neither works:** fall back to the MCP and **note in `index.md`** that capture was local-only
  (not VPS-reproducible) — never silently skip.

**Order the screens by the user journey** (from the `*-flow.md` Gherkin happy path; else infer from §9) —
this order drives the gallery (6b). For **each screen capture the page frame first** (the Figma overview
shot of the whole composed page in the real shell, 5b#1), then the other **states** (loading / empty /
validation-error / server-error), at **two viewports** — desktop (1280) and mobile (390). Save
`tasks/proto-<prd-slug>/<slice-n>-<state>-<viewport>.png` (use `<state>=page` for the happy frame).

**One script does both** — screenshots every frame AND measures each journey hotspot (6a-bis) in the same
headless pass, emitting `hotspots.json` for 6b. Write it to `tasks/proto-<prd-slug>/proto-capture.mjs` and
run from the repo root (`PROTO_URL=http://localhost:<port>/proto-preview node tasks/proto-<slug>/proto-capture.mjs`):

```js
// __PROTO__ throwaway — headless capture: screenshots + journey hotspots in one pass. Deleted at /saki-builder:build teardown.
import { chromium } from 'playwright'          // npm i -D playwright && npx playwright install chromium
import { writeFileSync, mkdirSync } from 'node:fs'
import { dirname } from 'node:path'; import { fileURLToPath } from 'node:url'

const OUT = dirname(fileURLToPath(import.meta.url))           // = tasks/proto-<slug>/
const BASE = process.env.PROTO_URL || 'http://localhost:5173/proto-preview'   // the served route (5d)
const VIEWPORTS = { desktop: [1280, 832], mobile: [390, 844] }

// One entry per SCREEN in journey order. `states` maps state→a suffix on BASE (a ?state= value or path).
// `anchor` (6a-bis) = the control that advances to the next screen: CSS `sel`, or {role,name}. Omit on last.
const SCREENS = [
  { slug:'slice1', states:{ page:'?state=happy', empty:'?state=empty', error:'?state=error' },
    anchor:{ to:1, label:'<affordance>', sel:'[data-testid="primary-cta"]' } },
  // …one per screen in journey order. Last screen: anchor:{ to:0, label:'↺ Restart', sel:'…' } or no anchor
]
const pct = (b,W,H) => b && { x:+(b.x/W*100).toFixed(2), y:+(b.y/H*100).toFixed(2), w:+(b.width/W*100).toFixed(2), h:+(b.height/H*100).toFixed(2) }

mkdirSync(OUT, { recursive:true })
const browser = await chromium.launch()
const hotspots = {}                                          // slug -> { to, label, desktop:{}, mobile:{} }
const FAILED = []                                            // frames that crashed/blanked — must NOT be screenshotted
for (const [vp,[W,H]] of Object.entries(VIEWPORTS)) {
  const ctx = await browser.newContext({ viewport:{width:W,height:H}, deviceScaleFactor:2 })
  const page = await ctx.newPage()
  let pageErr = null
  page.on('pageerror', e => { pageErr = e.message })         // a CLIENT-side throw during render (missing import/provider)
  for (const s of SCREENS) {
    for (const [state, suffix] of Object.entries(s.states)) {
      pageErr = null
      await page.goto(BASE + suffix, { waitUntil:'networkidle' })
      // HARD render gate — NEVER screenshot a crashed/blank render (the "error page captured N×" false-green).
      // The sentinel must be in the LIVE DOM (not just SSR HTML — a client throw slips past a curl of the SSR).
      const rendered = await page.waitForSelector('text=__PROTO__', { timeout:8000 }).then(()=>true).catch(()=>false)
      const boundary = await page.locator("text=/couldn['’]t load|Application error|__next_error__|Unhandled Runtime Error/i").count()
      if (!rendered || pageErr || boundary) {                // fail the frame, do NOT capture it
        FAILED.push(`${s.slug}-${state}-${vp}: ${pageErr || (boundary ? 'error boundary rendered' : 'no __PROTO__ sentinel in DOM')}`)
        continue                                             // fix 5a (providers) / 5c (auth), then re-run
      }
      await page.waitForTimeout(400)
      await page.screenshot({ path:`${OUT}/${s.slug}-${state}-${vp}.png` })
    }
    if (s.anchor && (s.anchor.sel || s.anchor.name)) {        // measure hotspot on the page state
      await page.goto(BASE + s.states.page, { waitUntil:'networkidle' }); await page.waitForTimeout(300)
      const loc = s.anchor.sel ? page.locator(s.anchor.sel).first()
                               : page.getByRole(s.anchor.role||'button', { name:new RegExp(s.anchor.name) }).first()
      const box = await loc.boundingBox().catch(()=>null)
      hotspots[s.slug] = Object.assign(hotspots[s.slug]||{ to:s.anchor.to, label:s.anchor.label }, { [vp]: pct(box,W,H) })
    }
  }
  await ctx.close()
}
await browser.close()
writeFileSync(`${OUT}/hotspots.json`, JSON.stringify(hotspots, null, 2))
if (FAILED.length) {                                          // ANY crashed frame ⇒ capture FAILED; never proceed to the gallery
  console.error('CAPTURE FAILED — these frames did not render (fix providers 5a / auth 5c, never ship an error frame):\n' + FAILED.join('\n'))
  process.exit(1)                                            // non-zero exit halts the run BEFORE the Coverage Gate / gallery
}
console.log('captured screenshots + hotspots.json')
```

**The capture script HARD-FAILS (non-zero exit + `CAPTURE FAILED`) on any frame that crashed, rendered the
error boundary, or lacked the `__PROTO__` sentinel in the LIVE DOM — a crashed render is NEVER
screenshotted.** So a clean (zero) exit means every attempted frame genuinely rendered; that is the
authoritative render check (not the 5d curl, which only sees SSR HTML and misses a client-side throw). If
it prints `CAPTURE FAILED`, STOP and do not proceed to the gallery: the named frames hit a provider (5a) or
auth (5c) failure — fix and re-run. (This is the exact "error page captured N× as identical frames"
false-green the gate exists to prevent.) For a failed non-page **state** shot (loading/error) you may note
it in `index.md`; a failed **page** (whole-screen) frame is a **Coverage-Gate failure** — fix it and
re-capture, never note-and-skip a screen. Then write `index.md` leading with the journey-ordered page
frames + the fidelity contract.

**Mobile-fidelity check (BLOCKING — the mobile frame must be a real mobile layout, not a squished desktop).**
Proto renders the project's REAL components, so a non-responsive component yields a genuinely broken mobile
frame — surface it, never ship it silently. After capture, OPEN the mobile (390) PNGs and verify each:
- **No horizontal overflow** — content fits the 390 width; nothing is clipped off the right edge, no
  side-scroll. (A `fullPage` shot that's far wider than 390 is the tell — a row/grid that didn't stack.)
- **The app shell adapted** — a fixed desktop sidebar must collapse/hide (or move to a chip row / drawer)
  below the breakpoint, not eat half a 390px screen. The header nav stays usable.
- **No crushed multi-column layouts** — board/kanban/columns and side-by-side cards must stack vertically
  on mobile; a 3-up row crammed into 390 (truncated titles, wrapped badges/labels) is a fail.
- **Controls reachable** — form fields and CTAs go full-width / stack rather than overflow.
- **No oversized gaps** — a desktop grid that collapses to one column on mobile leaves a large empty band
  between the chrome (collapsed sidebar / tab row) and the page content: the default `align-content:stretch`
  splits the leftover viewport height *between* the auto rows. Fix by making the content row absorb the
  slack (`grid-rows-[auto_1fr]` on mobile, reset `md:grid-rows-none`) or `content-start` — the empty space
  belongs at the bottom, not between the menu and the page.
If any mobile frame fails, the cause is almost always a **non-responsive real component** (a fixed-width
shell grid, a horizontal-only flex, a badge/label with no `whitespace-nowrap`/`shrink-0`). That is a
**design-system gap** — treat it like a Step 2.5 ⚠️: fix the responsive layout in the real component
(`flex-col md:flex-row`, hide/transform the sidebar at the breakpoint, etc.), re-capture, and re-verify
BEFORE presenting. Do not present a broken mobile frame and call it "approximate" — responsiveness is a
look-fidelity property proto exists to derisk, not a `/saki-builder:build` behavior concern.

### 6a-bis. The hotspot anchors (input to the 6a script)

The flow is clickable because each screen knows the control that advances to the next. For every screen
except the last, give the 6a script that control via `anchor` — a CSS `sel` (prefer a stable `data-testid`)
or `{role, name}` — taken from the `*-flow.md` happy path (the primary CTA / the field filled / the row
opened). The script resolves it, reads its rect, converts to **% of the viewport** (scales at any display
size) for BOTH viewports, and writes `hotspots.json` as `{ slug: { to, label, desktop:{x,y,w,h},
mobile:{x,y,w,h} } }` — paste these straight into 6b's `SCREENS[*].hot`. The last screen loops (`to:0`) or
omits its anchor. If a selector can't resolve, the script records `null` — the rail + Prev/Next still
navigate; never hand-fabricate coordinates.

### 6b. Interactive Figma-flow gallery (PNG-based — opens with `file://` AND in Studio)

After all screenshots + hotspots are captured, produce `tasks/proto-<prd-slug>/preview.html` — the
artifact Pipeline Studio opens (it serves `preview.html` **plus its sibling PNGs** read-only). **Embed
the 6a PNGs via relative `<img src>`** — NOT `<iframe srcdoc>` captured DOM (which renders **unstyled**
with no dev server). The PNGs are already-rendered, faithful, viewport-correct, and need no server.

It is a **Figma-style design-studio** view with two modes + two toggles:
- **Flow** (default) — one screen on a dark canvas with **click-through hotspots** (6a-bis) overlaid on
  the real controls; clicking advances to the next journey screen. Left **journey rail** + Prev/Next +
  `H` to flash all hotspots. This is the Figma prototype mode.
- **Overview** — every screen's page frame in **journey order** with arrows between them (the Figma
  board); click a frame to jump into Flow there.
- **State toggle** — per screen, flip between its captured states (page / loading / empty / error).
- **Viewport toggle** — desktop (1280) ↔ mobile (390).

#### Assemble `preview.html`

Self-contained: inline `<style>` + inline `<script>`, **no external/CDN deps**. Frames are driven by a
`SCREENS` array in journey order; each screen lists its state→viewport PNGs and its hotspot. Fill the
`SCREENS` array from 6a (PNG names) + 6a-bis (hotspot rects); the template logic does not change.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Proto — <prd-slug></title>
<style>
  :root{--bg:#1e1e1e;--panel:#2c2c2c;--line:#3d3d3d;--text:#e6e6e6;--muted:#9b9b9b;--accent:#0d99ff}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);font:13px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
  header{display:flex;align-items:center;gap:14px;padding:10px 16px;border-bottom:1px solid var(--line);background:var(--panel);position:sticky;top:0;z-index:10}
  .spacer{flex:1}
  .seg{display:inline-flex;border:1px solid var(--line);border-radius:7px;overflow:hidden}
  .seg button{background:transparent;color:var(--muted);border:0;padding:5px 11px;font:inherit;cursor:pointer}
  .seg button.on{background:var(--accent);color:#fff}
  .hint{color:var(--muted);font-size:11px}.hint kbd{background:#000;border:1px solid var(--line);border-radius:4px;padding:0 5px}
  .fidelity{margin:0;padding:8px 16px;background:#2a2410;border-bottom:1px solid #4a3d12;color:#e8c97a;font-size:12px}
  .wrap{display:flex;min-height:calc(100vh - 92px)}
  nav{width:210px;border-right:1px solid var(--line);padding:12px;flex-shrink:0}
  nav .lbl{font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:var(--muted);margin:6px 4px}
  nav a{display:flex;gap:8px;align-items:center;padding:7px 8px;border-radius:6px;color:var(--text);text-decoration:none;cursor:pointer;font-size:12px}
  nav a:hover{background:#333}nav a.on{background:#0d99ff22;color:#cde8ff}
  nav a .n{width:18px;height:18px;border-radius:50%;background:#3d3d3d;display:grid;place-items:center;font-size:11px;flex-shrink:0}
  nav a.on .n{background:var(--accent);color:#fff}
  main{flex:1;display:flex;flex-direction:column;align-items:center;padding:24px;overflow:auto}
  .caption{color:var(--muted);margin-bottom:12px;text-align:center}.caption b{color:var(--text)}
  .states{display:flex;gap:6px;margin-bottom:14px}
  .states button{background:var(--panel);border:1px solid var(--line);color:var(--muted);border-radius:6px;padding:4px 10px;font:inherit;cursor:pointer}
  .states button.on{border-color:var(--accent);color:#cde8ff}
  .stage{position:relative;display:inline-block;box-shadow:0 12px 40px rgba(0,0,0,.55);border-radius:10px;overflow:hidden;background:#0d1117}
  .stage img{display:block;width:auto;max-width:min(1180px,90vw);height:auto}.stage.mobile img{max-width:min(360px,90vw)}
  .hot{position:absolute;border-radius:6px;cursor:pointer}
  .hot::after{content:attr(data-label);position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);white-space:nowrap;font-size:11px;font-weight:600;color:#fff;background:var(--accent);padding:3px 8px;border-radius:5px;opacity:0;transition:opacity .12s;pointer-events:none}
  .hot:hover,.hot.flash{box-shadow:0 0 0 2px var(--accent),0 0 0 6px #0d99ff44;background:#0d99ff22}
  .hot:hover::after,.hot.flash::after{opacity:1}
  .navrow{display:flex;gap:10px;align-items:center;margin-top:16px}
  .navrow button{background:var(--panel);border:1px solid var(--line);color:var(--text);border-radius:7px;padding:7px 14px;cursor:pointer;font:inherit}
  .dots{display:flex;gap:6px}.dot{width:8px;height:8px;border-radius:50%;background:#555;cursor:pointer}.dot.on{background:var(--accent)}
  .grid{display:none;flex-wrap:wrap;gap:30px;padding:28px;justify-content:center}
  body.overview .grid{display:flex}body.overview .wrap{display:none}
  .card .ttl{font-size:12px;color:var(--muted);margin-bottom:8px}.card .ttl b{color:var(--text)}
  .card img{display:block;max-width:420px;border-radius:8px;box-shadow:0 8px 26px rgba(0,0,0,.5);border:1px solid var(--line);cursor:pointer}
  body.overview.mobile .card img{max-width:200px}.arrow{align-self:center;color:var(--accent);font-size:26px}
</style></head>
<body class="flow desktop">
<header>
  <b>Proto · <prd-slug></b>
  <span class="hint">click <span style="color:var(--accent)">blue</span> hotspots · <kbd>H</kbd> flash</span>
  <span class="spacer"></span>
  <div class="seg" id="mode"><button data-mode="flow" class="on">Flow</button><button data-mode="overview">Overview</button></div>
  <div class="seg" id="vp"><button data-vp="desktop" class="on">Desktop</button><button data-vp="mobile">Mobile</button></div>
</header>
<p class="fidelity">⚡ Faithful on layout · real components · design tokens · the real app shell. Mock data; click-through is a Figma-style flow between captured frames — live behavior is <code>/saki-builder:build</code>'s job.</p>
<div class="wrap">
  <nav><div class="lbl">User journey</div><div id="rail"></div></nav>
  <main>
    <div class="caption" id="cap"></div>
    <div class="states" id="states"></div>
    <div class="stage" id="stage"><img id="frame" alt=""></div>
    <div class="navrow"><button id="prev">‹ Prev</button><div class="dots" id="dots"></div><button id="next">Next ›</button></div>
  </main>
</div>
<div class="grid" id="grid"></div>
<script>
// One entry per SCREEN in journey order. states.page is mandatory; add empty/loading/error as captured.
// hot (from 6a-bis): the affordance that advances to screen index `to`. Last screen: {to:0,label:'↺ Restart'} or omit.
const SCREENS = [
  { title:'<screen 1 title>', cap:'<one-line caption>',
    states:{ page:{desktop:'slice1-page-desktop.png',mobile:'slice1-page-mobile.png'} },
    hot:{ to:1, label:'<affordance>', desktop:{x:0,y:0,w:0,h:0}, mobile:{x:0,y:0,w:0,h:0} } },
  // …one object per screen in journey order…
];
const $=s=>document.querySelector(s),stage=$('#stage'),frame=$('#frame'),cap=$('#cap'),
  rail=$('#rail'),dots=$('#dots'),statesBar=$('#states'),grid=$('#grid');
let cur=0,st='page',vp='desktop';
function render(){
  const s=SCREENS[cur];if(!s.states[st])st='page';
  frame.src=s.states[st][vp];frame.alt=s.title;stage.className='stage'+(vp==='mobile'?' mobile':'');
  cap.innerHTML='<b>'+(cur+1)+'. '+s.title+'</b>'+(s.cap?'<br>'+s.cap:'');
  statesBar.innerHTML='';Object.keys(s.states).forEach(k=>{const b=document.createElement('button');b.textContent=k;b.className=k===st?'on':'';b.onclick=()=>{st=k;render()};statesBar.appendChild(b)});
  stage.querySelectorAll('.hot').forEach(h=>h.remove());
  const c=s.hot&&s.hot[vp];if(c&&st==='page'){const a=document.createElement('a');a.className='hot';a.dataset.label=s.hot.label;a.style.cssText='left:'+c.x+'%;top:'+c.y+'%;width:'+c.w+'%;height:'+c.h+'%';a.onclick=()=>setScreen(s.hot.to);stage.appendChild(a)}
  rail.innerHTML='';dots.innerHTML='';SCREENS.forEach((g,i)=>{const a=document.createElement('a');a.className=i===cur?'on':'';a.innerHTML='<span class="n">'+(i+1)+'</span>'+g.title;a.onclick=()=>setScreen(i);rail.appendChild(a);const d=document.createElement('span');d.className='dot'+(i===cur?' on':'');d.onclick=()=>setScreen(i);dots.appendChild(d)});
}
function setScreen(i){cur=(i+SCREENS.length)%SCREENS.length;st='page';render()}
function renderGrid(){grid.innerHTML='';SCREENS.forEach((s,i)=>{const c=document.createElement('div');c.className='card';c.innerHTML='<div class="ttl"><b>'+(i+1)+'. '+s.title+'</b></div><img src="'+s.states.page[vp]+'">';c.querySelector('img').onclick=()=>{document.body.classList.remove('overview');$('#mode [data-mode=flow]').click();setScreen(i)};grid.appendChild(c);if(i<SCREENS.length-1){const ar=document.createElement('div');ar.className='arrow';ar.textContent='→';grid.appendChild(ar)}})}
$('#mode').onclick=e=>{const b=e.target.closest('button');if(!b)return;document.querySelectorAll('#mode button').forEach(x=>x.classList.toggle('on',x===b));document.body.classList.toggle('overview',b.dataset.mode==='overview');if(b.dataset.mode==='overview')renderGrid()};
$('#vp').onclick=e=>{const b=e.target.closest('button');if(!b)return;document.querySelectorAll('#vp button').forEach(x=>x.classList.toggle('on',x===b));vp=b.dataset.vp;document.body.classList.toggle('mobile',vp==='mobile');render();renderGrid()};
$('#prev').onclick=()=>setScreen(cur-1);$('#next').onclick=()=>setScreen(cur+1);
addEventListener('keydown',e=>{if(e.key.toLowerCase()==='h')stage.querySelectorAll('.hot').forEach(h=>{h.classList.add('flash');setTimeout(()=>h.classList.remove('flash'),900)});if(e.key==='ArrowRight')setScreen(cur+1);if(e.key==='ArrowLeft')setScreen(cur-1)});
render();
</script>
</body>
</html>
```

Use **relative** `<img src>` (the bare PNG filename) so the Studio resolves each as a sibling —
`resolveProtoAsset` serves `tasks/proto-<slug>/<file>.png`. No base64, no absolute/`localhost:PORT` paths.

#### Verify

```bash
grep -c 'title:' tasks/proto-<slug>/preview.html   # = screen count (one SCREENS entry per journey frame)
grep -c 'page:'  tasks/proto-<slug>/preview.html   # >= screen count (every screen has a page frame)
# This screen count MUST equal the Screen Manifest count (GATE 1) — the Coverage Gate below enforces it.
```
Open it (`file://`) and confirm: **Flow** advances on hotspot click, **Overview** shows the journey with
arrows, the **viewport** toggle swaps frames, **state** toggles flip per-screen states. If a frame or
hotspot is missing, note it in `index.md` — never drop silently.

**Note:** the gallery is interactive as a **Figma-style frame-to-frame flow** (click-through between
captured frames + state/viewport toggles). It does NOT run live behavior (validation, API calls, real
state) — that remains `/saki-builder:build`'s work.

---

## Step 6c — (optional) Export to Figma  [only when the Figma MCP is connected]

Push the **same** captured proto into a Figma file so it can be reviewed/edited in Figma alongside
(not instead of) the static gallery. This is **strictly additive**: the static `preview.html` gallery
remains the canonical deliverable, and `/saki-builder:build` reads the gallery + handoff notes (Step 8), never Figma.

**Connection gate (skip silently if absent).** Check whether the **first-party** Figma MCP is connected
— i.e. the write-to-canvas tools `generate_figma_design`, `create_new_file`, `upload_assets` are
available. If they are NOT, **skip this step silently**: do not block the run, do not tell the user to
install Figma (unless they ask). Use the first-party server's write-to-canvas tools — do **not** wire
the old third-party plugin-bridge (`cursor-talk-to-figma`); the first-party server writes to canvas now,
so the bridge is unnecessary. Write-to-canvas is a Figma **beta** (currently free, slated to become
usage-based paid) — that's another reason it stays optional, never a hard dependency.

**Also respect the resolved design-engine mode (Step 0).** If the mode is **`figma-read`** (a View/Dev
seat that can read but not write), the write-to-canvas tools will fail — **skip the export with a noted
reduction in `index.md`** ("Figma export skipped — seat is read-only; use an editor/dev seat to export")
rather than attempting a call that errors. **`figma-write`** proceeds with the export below. A plain
`native` / `--figma-only` run doesn't resolve a seat capability (Step 0 only calls `whoami` for the figma
engine), so it keeps 6c's original try-when-connected behavior — if a read-only seat blocks the write, the
Verify step below records the reduction rather than dropping it silently.

**Where this runs — headless/VPS reality (path A, the default).** The desktop Figma MCP (`127.0.0.1:3845`)
is **local-only**, and a headless `claude -p` run (how Pipeline Studio and a VPS spawn proto) **can't
complete interactive OAuth** — so on a VPS/Studio run the Figma MCP is normally absent and this step **skips
silently, which is correct**; the static gallery is the deliverable. To get the export, run it **where Figma
is connected**: on your Mac (Figma desktop, authed) use **`--figma-only <gallery-dir>`** (see Input) against
the gallery the VPS produced. This **decouples** the unattended render (VPS) from the interactive Figma
round-trip (your machine) — no tunnels, no token-in-config, no OAuth-in-headless.

> **Deferred (path B) — Figma export INSIDE a headless VPS run.** Possible but not yet wired: it needs a
> **remote** Figma MCP authenticated **non-interactively** (a token/PAT in an `Authorization` header, not
> OAuth — the run inherits Studio's spawn env, so a token can flow in). **Reachability is NOT the blocker**
> (Tier A's `capture.js` runs in the browser / headless Playwright; Tier B is pure HTTP upload). The one open
> question is whether the remote Figma MCP supports **static-token auth + `upload_assets`/`generate_figma_design`**
> — verify against Figma's beta before relying on it. Until then, use path A above.

If connected, produce the export in two fidelity tiers (mirror the skill's honesty rails — always state
which tier you got):

### Tier A — live editable layers (PREFERRED)
1. `search_design_system` / `get_libraries` **first** → resolve the project's **real Figma** component
   library, so generated layers map onto actual components + variables, not loose vectors.
2. `create_new_file` → name it `Proto: <prd-slug>`.
3. `generate_figma_design` to capture the **running** `proto-preview` route (Step 5d) into the file,
   **per screen in journey order** (Step 6a) — full-page happy frame first, then the other states. Each
   capture: call the tool with the `fileKey` (no `captureId`) → it returns a `captureId`; ensure
   `capture.js` (`https://mcp.figma.com/mcp/html-to-design/capture.js`) is loaded on the page — inject it
   via the browser MCP `javascript_tool`, or temporarily add the `<script src=…capture.js>` tag (throwaway,
   remove at teardown); open the route with the `#figmacapture=<captureId>&figmaendpoint=…&figmadelay=1000`
   hash; then poll `generate_figma_design` with the `captureId` every ~5s until `completed`. One
   `captureId` per page.

**Localhost works — capture is client-side (verified 2026-06-28).** An earlier draft warned the remote
server couldn't reach `localhost`; that's wrong. `capture.js` runs **in the browser**, serializes the DOM,
and uploads to Figma — the browser (which reaches localhost) is the bridge, so the hosted server never
touches the dev port. Tier A's real requirement is a **browser session** that can open the proto-preview
URL with `capture.js` present (no desktop server / tunnel needed). If no browser/capture path is available,
fall back to Tier B. (For EXTERNAL, non-localhost URLs, `capture.js` must be injected via Playwright.)

### Tier B — screenshot board (FALLBACK, guaranteed)
1. `create_new_file` → `Proto: <prd-slug>`.
2. `upload_assets` (`count` = number of PNGs) → it returns single-use `submitUrl`s; POST each PNG to its
   `submitUrl` (`curl -F "file=@<file>.png;type=image/png" <submitUrl>` — multipart `file` field
   preferred, the filename becomes the layer name). Upload the `tasks/proto-<slug>/*.png` frames — page
   overview first (journey order), then per-state — mirroring the two `preview.html` sections (Step 6b).
   These are flat images, **not** editable layers; say so.

**Verify + record.** Confirm `create_new_file` returned a file URL. If `generate_figma_design` /
`upload_assets` errors, retry once, then fall through (Tier A → Tier B → static-only) and note the
reduction in `index.md` rather than dropping silently. Record the Figma file URL and which tier you
produced; surface both in the Completion Output.

---

## Step 7 — Present + expectation check

### 7a. Serve a clickable local preview (terminal runs only)

When `/saki-builder:proto` runs from a **terminal** (not under Pipeline Studio), start a throwaway static server on
the gallery dir so the result hands back a **clickable URL** instead of a `file://` path. Under Pipeline
Studio (`$SAKI_OUT` is set — Studio spawns headless with `stdio:'ignore'`, so a backgrounded server would
die with the turn and its stdout is never read), **skip this**: Studio serves the gallery itself and its
**Preview ↗** button opens it via `/api/proto/<base64-cwd>/…/preview.html`.

```bash
if [ -z "$SAKI_OUT" ]; then
  pkill -f "http\.server 8999" 2>/dev/null; sleep 0.4   # reclaim a stale 8999 if any (see gotcha #1)
  PORT=$(python3 -c "import socket
for p in range(8999,9100):
    s=socket.socket()
    try: s.bind(('127.0.0.1',p)); s.close(); print(p); break
    except OSError: s.close()")                          # reuse 8999 when free, else first free 9000+
  ( python3 -m http.server "$PORT" --bind 127.0.0.1 --directory tasks/proto-<slug> >/dev/null 2>&1 & )
  echo "Local preview: http://127.0.0.1:$PORT/preview.html"
fi
```

Three gotchas this guards — **all hit in a real test**, do not "simplify" them away:
1. **Kill pattern must match the args, not `python3`.** The real process is `Python -m http.server 8999 …`
   (the framework binary is capital `Python`), so `pkill -f "python3.*http.server"` matches **nothing**
   and stale servers pile up. Match `http\.server 8999`.
2. **Fixed-port + stale listener = silent WRONG gallery.** A leftover server on 8999 serving a *different*
   `proto-<slug>` will answer the request and you'll preview the wrong prototype with no error. The
   free-port scan (after the kill) + a fresh `--bind 127.0.0.1` makes the URL hit *this* run's server.
3. **Advertise `127.0.0.1`, never `localhost`.** macOS resolves `localhost` → IPv6 `::1` first; a default
   `http.server` binds IPv4 only, so `http://localhost:PORT` can miss our server (or hit a stale IPv6 one
   bound to `*:PORT`). `http://127.0.0.1:PORT/preview.html` is deterministic. Stop it later with
   `pkill -f "http\.server <port>"`.

### 7b. Present

Show `index.md`. Restate the fidelity contract. Ask **two approval questions**:

> 1. "Does this match what you expected the end user to see — or adjust before `/saki-builder:build`?"
> 2. "Now that you're seeing the real components rendered, do you want to revise any of them? (You
>    confirmed the specs in 2.5 and Step 2.6 already built them as real design-system components — a change
>    now is a tweak to the real component, applied in Step 7.5.)"

Iterate on **look and components only** (component choice, layout, copy, spacing, states shown, token
names, variant naming). If the user wants behavior changes, that is a PRD/rplan concern, not proto — say so
and point back. If the user wants a *big* structural change the existing design can't hold, that is a 🔶
(Step 2.5 escalation) — surface it as a design-change proposal, don't force it in here.

**Both questions must be approved before proceeding.** If the user approves the journey but wants a
component change, **edit the real component** (it already lives in the design system from 2.6), re-screenshot
the affected frames, and present again. Do NOT proceed past Step 7.5 until both are green.

---

## Step 7.5 — Finalize the components after visual approval

The components are already **real** — Step 2.6 built them before rendering — so this step is now light:
apply any visual tweak the human asked for in Step 7 to the **real** component (not an approximation), then
re-verify. If Step 7 produced no change requests, this step is a no-op; the design system is already in its
final state.

- **Apply Step-7 tweaks** to the real component / theme file using the same resolution paths as Step 2.6
  (theme override for a purely stylistic variant, the component file otherwise). Update `design.md` and
  `tasks/proto-<prd-slug>/design-system-updates.md` if the change added or renamed anything.
- **Verify** the adjusted component still renders in the `proto-preview` route — `curl` returns HTTP 200
  with the `__PROTO__` sentinel — and re-screenshot only the affected frames.

`/saki-builder:build` then promotes these real presentational components (mock data → real data + state + tests +
backend wiring); it does NOT re-invent them. Write that as a hard dependency in the handoff notes (Step 8):
"Design system was updated per `design-system-updates.md` (built in Step 2.6, finalized in 7.5). `/saki-builder:build`
MUST use these real components — do NOT re-invent them."

---

## Step 8 — Handoff to `/saki-builder:build`

Write `tasks/proto-<prd-slug>-notes.md` capturing, per screen: the **real components chosen**,
the **token references** used, and the **states** confirmed. Purpose: `/saki-builder:build` **promotes** these
presentational components (mock data → real data + state + tests + backend wiring) instead of
re-picking from scratch.

State the **cleanup contract** explicitly. The **static gallery — `preview.html` + the PNGs +
`index.md` — is the deliverable Pipeline Studio actually opens** (read-only, via `/api/proto/...`);
it persists as the record regardless. The throwaway `proto-preview/*` route (incl. the
`/proto-preview` index) and the Step 5c middleware bypass also **persist after the proto run** — but
only because they are the **capture harness** and `/saki-builder:build`'s promotion source, **NOT** because the
Studio serves them live (it no longer does; it opens the static gallery). So the proto run must NOT
delete them, and must NOT run on a throwaway git branch that is then deleted. They remain throwaway
w.r.t. **`/saki-builder:build`**, the **sole owner of teardown**: it promotes the presentational components into
real routes, then deletes the `proto-preview/*` namespace and reverts the bypass. Until `/saki-builder:build`
runs they live in the working tree (uncommitted is fine). The `preview.json` manifest (5e), if you
wrote one, is ignored by the current Studio and is removed with the namespace at teardown.

---

## Coverage Gate (BLOCKING — every manifested screen is captured, no negotiation)

Before the Completion Output, hard-verify the run covered the WHOLE journey. This gate is the reason
"covers all screens" is true rather than aspirational — it is not optional, and it is NOT satisfied by
"the important screens." A no-arg run passes this gate only at 100% coverage.

1. Read `tasks/proto-<prd-slug>/screen-manifest.md` (GATE 1) — the canonical screen list.
2. For EVERY screen row, confirm a captured `page` frame exists at BOTH viewports
   (`<slug>-page-desktop.png` AND `<slug>-page-mobile.png`) AND the screen has a `SCREENS` entry in
   `preview.html`.
3. Diff the manifest against what was actually captured:

```bash
S=tasks/proto-<slug>
MANIFEST=$(grep -cE '^[0-9]+\.' "$S/screen-manifest.md")     # screens the PRD requires
DESK=$(ls "$S"/*-page-desktop.png 2>/dev/null | wc -l | tr -d ' ')   # screens captured (desktop)
MOB=$(ls "$S"/*-page-mobile.png  2>/dev/null | wc -l | tr -d ' ')    # screens captured (mobile)
GALLERY=$(grep -c 'title:' "$S/preview.html")               # screens in the gallery
echo "manifest=$MANIFEST desktop=$DESK mobile=$MOB gallery=$GALLERY"
# DISTINCTNESS — presence is NOT correctness. Byte-identical page frames = a non-varying / crashed render
# (the "same error page captured N× and the gate still passed" false-green). Portable hash: Linux md5sum | macOS md5 -q.
hash1(){ command -v md5sum >/dev/null && md5sum "$1" | awk '{print $1}' || md5 -q "$1"; }
DISTINCT=$(for f in "$S"/*-page-desktop.png; do hash1 "$f"; done | sort -u | wc -l | tr -d ' ')
echo "distinct-desktop-page-frames=$DISTINCT   (must equal manifest when manifest>1)"
```

**All four counts must be equal, AND the page frames must be DISTINCT.** Two independent hard checks:

1. **Coverage** — if `desktop < manifest` (or `mobile`/`gallery` < manifest), the run is INCOMPLETE — a
   screen was skipped. HARD STOP, never a note in `index.md`:
```
HARD STOP — PROTO INCOMPLETE
Manifest requires N screens; only M captured (desktop=…, mobile=…, gallery=…).
Missing: <list the manifest rows that have no page frame>.
/saki-builder:proto covers the WHOLE journey — every screen, no curation. Render the missing screen(s), re-run the
capture, then re-run the Coverage Gate. Do NOT emit the Completion Output while any manifested screen is
uncaptured.
```

2. **Distinctness / fidelity** — with `manifest > 1`, if `DISTINCT < manifest` the page frames are not all
   different: two screens rendered byte-identically, which almost always means a **non-varying render or an
   error page captured for every screen** (real, observed: a missing import crashed the harness → the same
   Next error boundary was screenshotted for all screens, yet all files existed so a presence-only gate
   PASSED). HARD STOP — presence is not correctness:
```
HARD STOP — PROTO FRAMES NOT DISTINCT
manifest=N but only DISTINCT=K unique desktop page frames — some screens rendered identically.
Likely cause: the render didn't vary per screen, OR an error page was captured for every screen (check for
a Next.js error boundary; re-run the 6a capture, which now hard-fails on a missing __PROTO__ sentinel / a
pageerror / an error boundary — a clean capture exit is required). Fix the harness (5a/5c), re-capture,
re-run the Coverage Gate. Do NOT emit the Completion Output while any two page frames are byte-identical.
```
(If two screens are legitimately near-identical, they are the same screen — merge them in the manifest;
the gate is right to flag it.)

**Screens are all-or-fail; only states are individual.** A genuinely-unreachable *state* (loading/error)
on a *present* screen may still be noted-and-omitted per Step 3. A missing *screen* is never acceptable —
fix it and re-capture. `--slice=N` is the only way the manifest may be smaller than the full journey, and
that run is stamped `PARTIAL` everywhere so it can never be mistaken for full coverage.

---

## Step 8.5 — Lock the PRD (the explicit freeze before `/saki-builder:build`)

This is the **terminal act of the PRD phase**: with the UI/UX approved (Step 7) and the journey fully
captured (Coverage Gate passed), **freeze the requirements** so `/saki-builder:build` — which hard-refuses an
unlocked PRD — can proceed to `/saki-builder:rplan`. `/saki-builder:proto` is the **single lock writer**: a UI PRD
locks here after approval; a no-UI PRD (GATE 1 branch) jumps straight here on the human's confirmation.
Do **not** lock a `PARTIAL` (`--slice=N`) run — a partial preview hasn't approved the whole journey; print
`Not locking — PARTIAL run (--slice). Re-run /saki-builder:proto with no --slice to lock.` and skip this step.

Write the lock into the PRD file (the one loaded in GATE 1):
1. **Header marker** — add, in the PRD's top comment block, on its own line:
   `<!-- prd-locked: <@approver> · <YYYY-MM-DD> · ui:tasks/proto-<slug>/ -->`  (`ui:none` for a no-UI PRD).
   `<@approver>` = the PRD header `Owner` if set, else `@<git config user.name>`, else `unassigned`;
   `<YYYY-MM-DD>` = `date +%F`. The **absence** of this marker is what `/saki-builder:build` blocks on, so writing
   it is what unblocks the build — never emit it before the human has approved (Step 7 / the no-UI confirm).
2. **Header Status** — set the header field to `**Status:** Locked`.
3. **§15 reference** — in §15 Screens & UI Reference, append `**UI approved:** tasks/proto-<slug>/ · <date>`
   so the locked artifact points at this approved gallery. If §15 is absent on a UI PRD (an older PRD that
   didn't persist its screens), create it from the Screen Manifest first. Skip step 3 for a no-UI PRD.

Then announce it plainly:
```
🔒 PRD LOCKED — requirements frozen (Status: Locked · ui:tasks/proto-<slug>/).
   /saki-builder:build tasks/prd-<slug>.md can now proceed (it refuses an unlocked PRD).
```
The lock is `/saki-builder:proto`'s one write-back into the PRD — it **never** edits scope, criteria, or rules
(that stays `/saki-builder:prd`); it only stamps the freeze marker + the design reference.

---

## Completion Output

```
--- /saki-builder:proto COMPLETE ---
PRD: <prd-file>
PRD status: 🔒 Locked — <@approver> · <date>  (requirements frozen; ui:tasks/proto-<slug>/ | none)   [or: not locked — PARTIAL --slice run]
Design system: <Found | Partial(<which half>) | scaffolded>

Design System Gap Analysis:
  ✅ Existing (N components used as-is)
  ⚠️ Extended (M variants added)  →  see design-system-updates.md
  ❌ New (K components created)   →  see design-system-updates.md
  🔶 Design change (P)  →  [proposed — paused for sign-off | approved & applied | none]
  (or: No extensions needed — all components already existed)

Design system updated: tasks/proto-<slug>/design-system-updates.md  (built in Step 2.6, before render)
  Added: <list of new component files>
  Tokens: <list of new token names, or "none">

Journey previewed: entry → [N user-visible steps] → success   (continuous, no gaps)
  1. <title> — states: happy, loading, empty, validation-error, server-error[, permission]
  2. ...
  (connective screens — login / landing / result / success — marked [glue])
Screen manifest: tasks/proto-<slug>/screen-manifest.md   (canonical list of every screen)
Reuse Map: tasks/proto-<slug>/reuse-map.md   (existing shell + feature components imported verbatim · new = specced)
Coverage Gate: PASSED — N/N manifested screens captured at both viewports   (or: PARTIAL — --slice=N)
Screenshots: tasks/proto-<slug>/index.md  (page overview + per-state, desktop + mobile)
HTML gallery: tasks/proto-<slug>/preview.html  (PNG-based Figma-flow: click-through + overview + state/viewport toggles; opens file:// AND in Studio)
Handoff notes: tasks/proto-<slug>-notes.md
Local preview: http://127.0.0.1:<port>/preview.html  (terminal runs — Cmd/Ctrl-click to open · stop: pkill -f "http.server <port>")
Studio Preview: opens the static gallery (tasks/proto-<slug>/preview.html) via the Preview ↗ button
Figma export: <Figma file URL — Tier A editable layers | Tier B screenshot board | skipped (no Figma MCP)>

Fidelity: faithful on layout/components/look/responsive/page-composition-in-real-shell/per-state;
          approximate on live data density + edge cases; no backend/logic.
Design system: updated before /saki-builder:build — new components are real, not approximations.

Next actions:
> Open the local preview: http://127.0.0.1:<port>/preview.html  (terminal runs — served in Step 7a)
> Open the Preview ↗ in Pipeline Studio (the static page-overview gallery)
> Open the exported Figma file to review/edit the layers (if Step 6c ran)
> Review tasks/proto-<slug>/index.md and confirm the look
> /saki-builder:build tasks/<prd-file>  (the PRD is now 🔒 Locked — build proceeds; promotes these components into real implementation, design system already updated)
```
(The static `preview.html` is what the Studio opens — no marker line is needed. The `preview.json`
manifest of 5e is optional/legacy and ignored by the current Studio; only mention it if you wrote one.)

---

## Anti-patterns (reject on sight) — the honesty rails

| Anti-pattern | Fix |
|--------------|-----|
| Skipping Step 2.5 when Gate 2 is "Found" | Gap analysis runs regardless — slices may need components not yet in the library |
| Listing MUI/Chakra/Mantine primitives (Button, Paper, etc.) individually as ✅ | For npm-library projects, all library primitives are ✅ by default — list only the custom business component layer |
| Cross-referencing `src/proto/**` or `proto-preview/**` when checking if a component exists | Those are throwaway harness files — a component found there is NOT in the design system; exclude them from the scan |
| Proceeding to render without confirming component specs | Step 2.5 requires explicit user confirmation before Step 3 — cheapest correction point |
| Naming new tokens or components outside existing conventions | Follow existing naming patterns exactly (same key names, same scale prefixes, same casing) |
| Adding speculative tokens "we might need later" | Only add tokens explicitly required by the approved spec |
| Creating a wrapper file for a ⚠️ purely stylistic MUI/Chakra variant | Theme overrides (`components.MuiX.variants`) are the correct path — new files only for multi-primitive composites |
| Writing `var(--token-name)` in component files for an MUI project | MUI tokens live in `theme.ts` — consume via `tokens.status.*` or `theme.palette.*`, not CSS vars the project never defined |
| Adding CSS custom properties to a TS tokens object (`theme.ts`) | Match the project's token format exactly (see Step 2.5 token format detection) |
| Letting `/saki-builder:build` re-invent components instead of using the Step 2.6 additions | Design system update runs in Step 2.6 (before render), finalized in 7.5; handoff notes must name the real component files |
| Rendering an *approximation* of a NEW component and codifying it only after approval | Codify confirmed ⚠️/❌ in **Step 2.6 BEFORE render** — proto composes the real component and Step 7 approves the real thing (the old approximate-first order let a human approve a stand-in that /saki-builder:build then rebuilt differently) |
| Force-fitting a journey the existing design can't host, or self-initiating a big redesign | 🔶 escalation (2.5) — SMALL absorbs as ⚠️/❌; BIG **stops and PROPOSES** a design change for human sign-off; a scope change routes back to /saki-builder:prd |
| Designing the delta from the component grep without ever looking at the existing page | Capture the current-state screenshot of any modified page first (2.4) — designers look before they design |
| Jumping to a new component when a variant would do (or a redesign when a component would do) | Climb the cost ladder to the lowest rung that works — reuse < scale < add < propose (2.5) |
| Inventing components when no design system exists | Gate 2 STOP — offer scaffold / mock / skip |
| Lorem-perfect data hiding overflow & density | Long strings + many rows + an empty case |
| Wiring real backend / data fetching / state logic | Mock only — that work is `/saki-builder:build` |
| Preview routes that can ship to prod | `proto-preview` namespace + banner + cleanup contract |
| Folder named `_proto`/`__proto` in Next App Router → 404 | Routable name (`proto-preview`); `_`-prefix = private/non-routed |
| Preview route 307-redirects to `/login` | Default-deny middleware — add the scoped Step 5c bypass |
| Claiming 1:1 after a Partial detection | Flag exactly which half is approximate |
| Curating to the "important" states/slices instead of the whole journey | E2E by default (GATE 1 + Step 3) — every reachable state, every user-visible step, entry→success; `--slice` or omitting a state must be explicit + justified, never the default. Still never invent a state genuinely impossible for the screen. |
| Rendering before writing the Screen Manifest | GATE 1 — enumerate every screen (slices + glue + backend outcomes + shell affordances + success) into `screen-manifest.md` first; it is the canonical count the Coverage Gate checks. No manifest = no rendering. |
| Emitting the Completion Output while a manifested screen has no captured frame | Coverage Gate is BLOCKING — every row in `screen-manifest.md` needs a page frame at BOTH viewports; a missing screen is a HARD STOP, not a note in `index.md`. |
| Note-and-skipping a whole screen because a shot failed | Only a missing non-page *state* may be noted; a missing *screen* (page frame) fails the Coverage Gate — fix and re-capture (6a / Coverage Gate). |
| Bare preview route that throws on a missing provider | Step 5a — detect + wrap in mock providers, or use Storybook |
| Booting real auth/DB to render a preview | Mock the session/locale/data-layer; never hit live auth |
| Screenshotting a compile-error / error page | Fix the provider (5a) first; never capture an error as the "preview" |
| Swallowing the `__PROTO__` sentinel (`waitForSelector(...).catch(()=>{})`) then screenshotting anyway | HARD-gate it (6a): the sentinel must be in the LIVE DOM; a missing sentinel / a `pageerror` / an error boundary FAILS the frame (skip it) and the capture exits non-zero — a crashed render is never captured |
| Coverage Gate passing on N present-but-byte-identical frames (an error page captured for every screen) | Assert DISTINCTNESS + no error boundary (Coverage Gate): `DISTINCT < manifest` ⇒ HARD STOP. Presence ≠ correctness |
| Trusting a `curl` 200 of SSR HTML as the render check | `curl` is a smoke test only — a CLIENT-side throw passes it while the browser shows the error boundary; the live-DOM sentinel gate (6a) is authoritative, and typecheck/lint the harness (5d) before capture |
| Declaring done without verifying the server serves | `lsof`/curl the route before screenshotting |
| Rendering the slice in a void / bare canvas instead of the real page | Full-shell composition (5b#1) — import the real layout/shell and render the slice inside it |
| Re-approximating an already-implemented navbar/sidebar/feature component into a "design-wise correct" but *different* look (self-initiating a fresh design of the screen) | Reuse-first grounding — inventory the existing implementation (Step 2.4 Reuse Map), import & compose the real components verbatim, and prove it with the 5d provenance check. The preview must look like the *existing app*, not a redesign of it |
| Sending an already-implemented component to the 2.5 gap analysis as "new" | Check the Reuse Map first — EXISTING rows are imported, only genuinely-absent surfaces get a 2.5 spec |
| State-matrix-only gallery with no journey flow | Build the Figma-flow gallery (6b): a click-through Flow + a journey-ordered Overview; per-screen states are a toggle, never a bare matrix |
| Plain static PNG list (no hotspots / no flow) when the journey is known | Wire 6a-bis hotspots so clicking the real control advances screen→screen — that is the Figma-prototype feel |
| `<iframe srcdoc>` DOM gallery (renders unstyled in Studio — no dev server persists) | Embed the 6a PNG screenshots via relative `<img src>` (6b) — already-rendered, needs no server |
| Absolute / `localhost:PORT` / base64 `img src` in the gallery | Relative PNG filenames only — `resolveProtoAsset` serves them as siblings (6b) |
| Capturing the page frame at one viewport only | Shoot both desktop (1280) and mobile (390) — design.md is mobile-first |
| Calling "Playwright's javascript_tool" | The tool is `mcp__claude-in-chrome__javascript_tool` — use the exact MCP tool name |
| Deleting the `proto-preview` route at the end of the proto run | It PERSISTS — `/saki-builder:build` owns teardown (Step 8). It's the capture harness + promotion source, not a deletable scratch file |
| Advertising the `preview.json` manifest as a live Studio preview | The current Studio ignores it and opens the static `preview.html`; the manifest is optional/legacy (5e) |
| Preferring a bare / Storybook harness when the real shell can mount | Prefer full-shell composition (5b#1) for page fidelity; the bare harness is the fallback only |
| Making Figma export a hard dependency / telling the user to install Figma unprompted | Step 6c is optional — skip silently when the Figma MCP isn't connected; the static gallery is the deliverable |
| Assuming Tier A can't capture localhost because the server is remote | Capture is **client-side** (`capture.js` in a browser) — localhost works; Tier A's real need is a browser session + `capture.js`, not server→localhost reachability (6c) |
| Wiring the old third-party plugin-bridge (`cursor-talk-to-figma`) to write to Figma | The first-party server writes to canvas now — use `generate_figma_design` / `create_new_file` / `upload_assets` (6c) |
| Treating the Figma file as the canonical deliverable or as `/saki-builder:build`'s source | Static gallery + handoff notes stay canonical; Figma export is an extra review surface, `/saki-builder:build` doesn't read it |

## Rules

- **Preview, not build.** No backend, no real data, no state logic, no tests, no prod routes.
- **PRD is source of truth.** Scope = its full user journey (every user-visible step + the connective
  entry/success screens that join them); states = its §9/§10 + the Gherkin; boundaries = its §11 non-goals.
  Never re-elicit scope.
- **End-to-end by default.** Always render the complete journey — every user-visible step (incl.
  backend-slice outcome screens), the connective entry/success screens between them, and every reachable
  state per screen. A no-arg run covers the whole PRD; `--slice=N` and omitting a state are explicit,
  justified narrowings, never the implicit default.
- **Coverage is gated, not asserted — and presence is not correctness.** GATE 1 writes a Screen Manifest of
  every screen the finished PRD produces; the **Coverage Gate** (before Completion) hard-stops unless every
  manifested screen has a captured frame at both viewports **AND the page frames are DISTINCT** (byte-identical
  frames = a non-varying/crashed render, e.g. an error page captured for every screen). The capture itself
  (6a) hard-fails on a missing `__PROTO__` sentinel in the live DOM / a `pageerror` / an error boundary, so a
  crashed render is never screenshotted. Every screen, no curation, no negotiation — a missing OR duplicated
  screen fails the run. Screens are all-or-fail; only individual states may be reasoned about (Step 3).
- **Real components or stop.** Gate 2 is blocking — a faithful preview without a real design system
  is a contradiction; say so rather than fabricate.
- **Reuse the real implementation, don't redesign it.** Existing implemented shell + feature components
  are inventoried (Step 2.4 Reuse Map) and **imported verbatim** — proto composes the actual app, so the
  preview looks like the *existing app*, never a "design-wise correct but different" fresh design of it.
  Only genuinely-absent surfaces are specced (2.5), and the 5d **provenance check** proves every
  EXISTING/shell row was actually imported before any frame is captured.
- **Design system first, always.** Gap analysis (Step 2.5) runs every time. Missing components get a spec,
  user confirmation, and are codified into the real design system in **Step 2.6 — before the proto is even
  rendered**, so the preview shows real components, never approximations (finalized after visual approval in
  7.5); never during `/saki-builder:build`. Be consistent: new components follow existing naming, token scales, and
  prop conventions exactly.
- **Climb the cost ladder, add the minimum (the designer's discipline).** Reuse an existing component (✅) <
  scale one (⚠️ variant) < add a new one (❌) < propose a design change (🔶). Look at the existing page first
  (2.4), pick the LOWEST rung that works, and add only what the screen forces — judging the needed
  interaction, not just the pixels. **Add first, then design with it:** confirmed additions are built for
  real in Step 2.6 *before* rendering. A 🔶 that is *big* (shell/nav, a page's layout paradigm, a net-new
  pattern, or a >1-screen ripple) is **proposed and paused for a human**, never force-fit or silently
  redesigned; a change that alters scope routes back to `/saki-builder:prd`.
- **Throwaway but shell-faithful.** The preview **composes the real app shell** (5b#1) for page
  fidelity, yet lands only under the `proto-preview` namespace (or Storybook, the fallback), marked
  disposable, with a cleanup contract handed to `/saki-builder:build`.
- **Figma-flow gallery.** `preview.html` is a click-through prototype: a **Flow** (hotspots advance
  screen→screen) + a journey-ordered **Overview**, with per-screen state + viewport toggles — never a
  bare state matrix (6b).
- **Honest fidelity, every run.** Always show what the preview is faithful on vs approximate on.
- **Figma export is additive & honest (6c).** Only when the Figma MCP is connected; prefer Tier A
  editable layers, fall back to Tier B screenshots when no browser/capture path is available, and always state
  which tier you produced. Never a hard dependency; never the canonical deliverable for `/saki-builder:build`.
- **Proto is the lock gate (Step 8.5).** On approval (Step 7) — or, for a no-UI PRD, on the human's freeze
  confirmation — `/saki-builder:proto` writes `Status: Locked` + `<!-- prd-locked: … -->` into the PRD: the explicit
  freeze `/saki-builder:build` enforces before `/saki-builder:rplan`. It is the **single lock writer** for every PRD.
  It stamps only the freeze marker + the §15 UI reference — never scope, criteria, or rules (that stays
  `/saki-builder:prd`). Never lock a `PARTIAL` (`--slice`) run.

## Script

```bash
#!/bin/bash
mkdir -p tasks
```
