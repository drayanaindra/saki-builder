---
name: proto
description: Render a faithful, throwaway UI preview of a finished PRD's user-facing slices using the project's REAL design-system components + tokens with mock data, then screenshot every state via Playwright — so you see what the end user looks like BEFORE /build runs. Sits between /prd and /build. Usage — /proto <prd-file.md> [--slice=N].
---

# UI Preview Stage (faithful, throwaway)

You produce **expectation-setting visibility**: what the end-user UI will look like, rendered with
the project's **real** design-system components and tokens, screenshotted across every state —
**before** `/build` writes a line of production code. Pipeline: `/prd → /proto → /build`.

This is a *preview*, not a build. Hold the line on what it is and isn't:

- **It IS faithful on**: layout, component selection, visual hierarchy, copy, look-and-feel,
  responsive behavior, and the per-state look (loading / error / empty / validation / permission).
- **It IS only approximate on**: live data density, real content lengths, true edge cases —
  these are mocked, not real.
- **It is NOT**: a backend, real data fetching, state logic, validation rules, business-rule
  implementation (PRD §10), tests, or production routes. All of that is `/build`.

Show this fidelity contract to the user every run. Never imply the preview makes `/build` trivial —
it removes the *look* risk, not the *behavior* work.

---

## Input

Usage: `/proto <prd-file.md> [--slice=N]` (filler words fine).

Locate the PRD exactly like `/build`: take the token ending in `.md` (or matching `prd-*`), and
check, in order: `tasks/<name>`, `./<name>`, the path as given. `--slice=N` previews one slice;
default previews all user-facing slices.

---

## GATE 1 — Load the PRD (hard stop if missing)

Read the PRD. If it cannot be found/read, **STOP**:
```
HARD STOP — PRD NOT FOUND
Looked for: tasks/<name>, ./<name>, <name>
Pass a valid PRD path: /proto <prd-file.md>
```
Do NOT invent a PRD. From it, extract:
- **§8 Vertical Slices** — the work list. Keep only **user-facing** slices (a screen/route a user
  or role hits). Skip backend-only slices — there is nothing to preview.
- **§9 Acceptance Criteria** — the observable UI behaviors → which states to render.
- **§10 Business Rules & Invariants** — surfaces UI variants (e.g. "rejected if amount > balance"
  → a validation/error state to show).
- **§11 Non-Goals** — never render beyond them.

Also read any `tasks/*-flow.md` (rplan Step 2.5 Gherkin) for the slice — it already enumerates the
states the user expects. If present, it is the authoritative state list.

Print the user-facing slice list so the run is auditable.

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

Verify by grep/read, not assumption (e.g. open `components.json`, list `components/ui/`, read the
token file). Then branch:

| Detection | Action |
|-----------|--------|
| **Found** (components + tokens) | Record import paths + token source. Proceed — preview is 1:1. |
| **Partial** (tokens xor components) | Proceed, but state explicitly which half is approximate (e.g. "tokens are real, components are hand-rolled approximations"). |
| **None** | **STOP — do not fabricate.** |

On **None**, output and stop:
```
NO DESIGN SYSTEM FOUND — a faithful preview is impossible.
Rendering a preview now would invent components that /build then contradicts (guaranteed drift).
Options:
  (a) Scaffold one  — shadcn/ui + Tailwind tokens per design.md, then re-run /proto
  (b) Directional mock — I generate a looks-like mock (drift expected; expectations approximate)
  (c) Skip preview — go straight to /build
Pick a/b/c.
```
Never silently invent a component set — that is the exact failure this gate exists to prevent.

---

## Step 3 — Map slices → screens × states

For each user-facing slice, enumerate the **screens** and the **states** to render. Pull states
from §9 criteria, §10 rules, and the Gherkin (if present). Render only states the slice actually
has — do not pad:

- **happy** (mandatory) — the primary success view
- **loading** — skeleton/spinner while data resolves
- **empty** — zero-data view (first run / no results)
- **validation-error** — inline field error from an invalid input
- **server/network error** — the common toast/retry surface
- **permission-denied** — only if the slice involves multiple roles

One screen may carry several states. Keep the list tight — duplicate-looking states collapse to one.

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

## Step 5 — Render in a throwaway, isolated harness (REAL components)

Mount the screens using the project's **real** components + tokens (from Gate 2), with mock data
only — **no fetching, no backend, no state logic**.

### 5a. Provider/context detection (do this BEFORE mounting — the #1 render failure)

Real apps wrap their UI in providers; a bare preview route that imports a component needing one
throws on first render (works on a toy app, fails on a real one). Before mounting, read the root
`layout.*` / `_app.*` / `main.*` provider chain and identify what the slice's components require:
- **theme / design-system provider**, **toast/notification context**, **i18n / locale provider**,
  **auth / session provider**, **data-layer** (React Query / SWR / Apollo).

Then wrap the preview in those providers with everything external **mocked**:
- **Never boot real auth/session or hit a DB.** Supply a mock session/user and (for i18n) a mock
  locale + messages. Stub the data-layer with static mock data.
- If the provider chain is **env-dependent and not cheaply mockable** (e.g. auth requires live keys
  at module load), do NOT fight the full app shell — fall back per Harness choice below.

### 5b. Harness choice (in priority order)

1. **Storybook**, if present — prefer it. Stories mount components in isolation with explicit
   decorators for the providers from 5a; no app shell, no auth, no routing. Use the `component`
   skill's `.stories.tsx` convention.
2. **Throwaway route**, if no Storybook and the provider chain mocks cleanly — create
   `app/proto-preview/<slice>/page.tsx` (Next), or a `proto-preview` route (Vite/Remix), wrapped in
   the 5a mock providers. Drive states via a query param (`?state=empty|loading|error`), or stack
   all states in one labelled gallery page (simpler to screenshot).
   - **Next App Router gotcha:** do NOT name the folder with a leading underscore (`_proto`,
     `__proto`). Underscore-prefixed folders are **private** and are excluded from routing → the
     route 404s. Use a routable name like `proto-preview/`. (Keep `__PROTO__` only as an in-file
     banner string, never as a folder name.)
   - **Locale apps:** if routes live under `app/[locale]/…`, place the preview there
     (`app/[locale]/proto-preview/<slice>/`) so it inherits the locale provider — but note it then
     also inherits that layout's full shell (see 5a). A sibling outside `[locale]` skips the shell
     but gets locale-redirected by i18n middleware; usually the in-`[locale]` placement + a
     middleware bypass (below) is cleanest.
3. **Standalone mock-provider harness**, if the app shell is env-locked — render just the slice's
   component subtree in a minimal page that supplies only the 5a mock providers, bypassing the real
   root layout. Lower fidelity on global chrome, but it renders; note the reduction in `index.md`.

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

- **Mark it disposable:** a visible banner/comment `// __PROTO__ — throwaway preview, do not ship`
  on every preview file.
- **Isolation:** preview files live only under the `proto-preview` namespace (or Storybook) so they
  are trivially deletable and can never reach production.
- **Serve & verify:** if a dev server is already running on the project's working dir (`lsof -i
  :PORT` shows it, cwd matches), reuse it — hot-reload picks up the new route; no boot needed.
  Otherwise start it. Then **verify the route actually serves** (`curl` it: expect HTTP 200, grep
  for your banner text, and check there's no `Failed to compile` / error overlay) before
  screenshotting — do not assume it came up, and never screenshot an error page (return to 5a/5c).

---

## Step 6 — Screenshot via Playwright MCP

For each screen × state, navigate the preview route and capture screenshots at **two viewports**
(design.md is mobile-first):
- **desktop** (e.g. 1280 wide)
- **mobile** (e.g. 390 wide)

Save to `tasks/proto-<prd-slug>/<slice-n>-<state>-<viewport>.png`. Then write
`tasks/proto-<prd-slug>/index.md` that embeds every shot grouped **by slice → state**, with a
one-line caption each, and leads with the fidelity contract (faithful vs approximate).

If a screenshot fails, retry once; if it still fails, note it in `index.md` rather than silently
dropping the state.

---

## Step 7 — Present + expectation check

Show `index.md`. Restate the fidelity contract. Ask:
> "Does this match what you expected the end user to see — or adjust before `/build`?"

Iterate on **look only** (component choice, layout, copy, spacing, states shown). If the user wants
behavior changes, that is a PRD/rplan concern, not proto — say so and point back.

---

## Step 8 — Handoff to `/build`

Write `tasks/proto-<prd-slug>-notes.md` capturing, per screen: the **real components chosen**,
the **token references** used, and the **states** confirmed. Purpose: `/build` **promotes** these
presentational components (mock data → real data + state + tests + backend wiring) instead of
re-picking from scratch.

State the **cleanup contract** explicitly: the `proto-preview/*` namespace (or proto stories) **and
the Step 5c middleware bypass** are throwaway — `/build` either promotes the components into real
routes or deletes them, and reverts the bypass. Neither may rot in the repo. If the preview ran on a
throwaway git branch, that branch is deleted after the screenshots are saved (the `index.md` + PNGs
persist outside the branch).

---

## Completion Output

```
--- /proto COMPLETE ---
PRD: <prd-file>
Design system: <Found | Partial(<which half>) | scaffolded>
Slices previewed: [N user-facing]
  1. <title> — states: happy, loading, empty, error   (screens: M)
  2. ...
Screenshots: tasks/proto-<slug>/index.md  (desktop + mobile)
Handoff notes: tasks/proto-<slug>-notes.md

Fidelity: faithful on layout/components/look/responsive/per-state;
          approximate on live data density + edge cases; no backend/logic.

Next actions:
> Review tasks/proto-<slug>/index.md and confirm the look
> /build tasks/<prd-file>  (promotes these components into real implementation)
```

---

## Anti-patterns (reject on sight) — the honesty rails

| Anti-pattern | Fix |
|--------------|-----|
| Inventing components when no design system exists | Gate 2 STOP — offer scaffold / mock / skip |
| Lorem-perfect data hiding overflow & density | Long strings + many rows + an empty case |
| Wiring real backend / data fetching / state logic | Mock only — that work is `/build` |
| Preview routes that can ship to prod | `proto-preview` namespace + banner + cleanup contract |
| Folder named `_proto`/`__proto` in Next App Router → 404 | Routable name (`proto-preview`); `_`-prefix = private/non-routed |
| Preview route 307-redirects to `/login` | Default-deny middleware — add the scoped Step 5c bypass |
| Claiming 1:1 after a Partial detection | Flag exactly which half is approximate |
| Padding states the slice doesn't have | Render only states from §9 / §10 / the Gherkin |
| Bare preview route that throws on a missing provider | Step 5a — detect + wrap in mock providers, or use Storybook |
| Booting real auth/DB to render a preview | Mock the session/locale/data-layer; never hit live auth |
| Screenshotting a compile-error / error page | Fix the provider (5a) first; never capture an error as the "preview" |
| Declaring done without verifying the server serves | `lsof`/curl the route before screenshotting |

## Rules

- **Preview, not build.** No backend, no real data, no state logic, no tests, no prod routes.
- **PRD is source of truth.** Scope = its user-facing slices; states = its §9/§10 + the Gherkin;
  boundaries = its §11 non-goals. Never re-elicit scope.
- **Real components or stop.** Gate 2 is blocking — a faithful preview without a real design system
  is a contradiction; say so rather than fabricate.
- **Throwaway and isolated.** Everything lands under `__proto`/Storybook, marked disposable, with a
  cleanup contract handed to `/build`.
- **Honest fidelity, every run.** Always show what the preview is faithful on vs approximate on.

## Script

```bash
#!/bin/bash
mkdir -p tasks
```
