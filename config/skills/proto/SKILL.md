---
name: proto
description: Render a faithful, throwaway UI preview of a finished PRD's user-facing slices INSIDE the project's REAL app shell (nav/header/sidebar) using its real design-system components + tokens with mock data, then screenshot the full pages + states and assemble a Figma-like, journey-ordered page-overview gallery — so you see how the design looks as actual composed pages BEFORE /build runs. Sits between /prd and /build. Usage — /proto <prd-file.md> [--slice=N].
---

# UI Preview Stage (faithful, throwaway)

You produce **expectation-setting visibility**: what the end-user UI will look like, rendered with
the project's **real** design-system components and tokens, screenshotted across every state —
**before** `/build` writes a line of production code. Pipeline: `/prd → /proto → /build`.

This is a *preview*, not a build. Hold the line on what it is and isn't:

- **It IS faithful on**: layout, component selection, visual hierarchy, copy, look-and-feel,
  responsive behavior, **page composition within the real app shell** (nav / header / sidebar around
  the slice), and the per-state look (loading / error / empty / validation / permission).
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

**Persona check:** after loading the PRD, check if `.claude/personas/*.md` exists. If it does,
read the relevant persona(s) and use them to inform:
- Copy tone and vocabulary (§4 Mental Model — match their language, not technical jargon)
- Which states to emphasize (§6 "Must never experience" → always render that failure state)
- Interaction density and affordance size (§5 UI/UX Constraints — e.g. mobile context = larger tap targets)
Cite the persona when it drives a visual decision: `→ persona/buyer.md §5`.

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
- **App shell / layout** — the real page chrome the feature will live inside: a root `layout.*`
  (Next), an `app/App.tsx` / `main.*` root (Vite/Remix), or a `<Layout>` / `<AppShell>` / `<Sidebar>` /
  `<Nav>` / `<Header>` primitive. **Record its import path** — this is what Step 5b **composes around**
  the slice so the preview looks like the actual page (a real screen, not a fragment in a void). If the
  app genuinely has no chrome (a bare single-page app), note it; 5b then renders the slice alone.

Verify by grep/read, not assumption (e.g. open `components.json`, list `components/ui/`, read the
token file, open the root `layout.*` / `App.tsx`). Then branch:

| Detection | Action |
|-----------|--------|
| **Found** (components + tokens) | Record import paths (components + the app shell/layout, for 5b) + token source. Proceed — preview is 1:1. |
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

## Step 5 — Render in a throwaway harness that composes the REAL shell

Mount the screens using the project's **real** components + tokens (from Gate 2), **inside the real
app shell** (nav/header/sidebar), with mock data only — **no fetching, no backend, no state logic**.
The goal is a preview that looks like the *actual page*, not an isolated component on a blank canvas.

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
   **import the app's real layout/shell from Gate 2 (nav, header, sidebar) and render the slice
   inside it**, wrapped in the 5a mock providers with mock data. The capture then looks like the
   actual page — not a fragment in a void. ALSO create a routable **`/proto-preview` index** linking
   each slice. Drive states via a query param (`?state=empty|loading|error`), or stack all states in
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

(The preview always lives in the `proto-preview` namespace — isolation + `/build` teardown, Step 8.
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

- **Visible prototype banner (required):** render a fixed banner element in the `/proto-preview` page
  body containing the literal token `__PROTO__` and the text
  `⚡ Prototype preview — UI only · mock data · controls inert`. This does double duty: (1) it sets the
  operator's expectations so a faithful-but-inert page isn't mistaken for a broken app, and (2)
  `__PROTO__` is the **health-check sentinel** the Studio greps in the page body to confirm a real
  render (Step 5e `readySentinel`). Also keep the disposable source comment
  `// __PROTO__ — throwaway preview, do not ship` on every preview file.
- **Isolation:** preview files live only under the `proto-preview` namespace (or Storybook) so they
  are trivially deletable and can never reach production.
- **Serve & verify:** if a dev server is already running on the project's working dir (`lsof -i
  :PORT` shows it, cwd matches), reuse it — hot-reload picks up the new route; no boot needed.
  Otherwise start it. Then **verify the route actually serves** (`curl` it: expect HTTP 200, grep
  for your banner text, and check there's no `Failed to compile` / error overlay) before
  screenshotting — do not assume it came up, and never screenshot an error page (return to 5a/5c).

### 5e. (Legacy / optional) Write the live-preview manifest

> **Honesty note (2026-06-27):** the current Pipeline Studio opens the **static `preview.html`**
> (Step 6) and **ignores this manifest** — the live-dev-server bridge was removed. The static gallery
> is the real deliverable. Writing the manifest is **harmless and optional, not required**, and
> nothing downstream depends on it (`/build` does not read it). Skip this sub-step unless you have a
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

## Step 6 — Screenshot + HTML gallery via Playwright MCP

### 6a. Screenshots

First, **order the screens by the user journey** — the sequence the user actually moves through (from
the `*-flow.md` Gherkin happy path; if there's no flow doc, infer it from §9 acceptance criteria).
This order drives the page overview AND the gallery nav (Step 6b).

For **each screen, capture the full-page happy state first — the "page frame"**: the whole composed
page in the real shell (5b#1), the Figma-like overview shot. Then capture the remaining **states**
(loading / empty / validation-error / server-error). Shoot everything at **two viewports**
(design.md is mobile-first):
- **desktop** (e.g. 1280 wide)
- **mobile** (e.g. 390 wide)

Save to `tasks/proto-<prd-slug>/<slice-n>-<state>-<viewport>.png` — use **`<state>=page`** for the
full-page happy frame (e.g. `slice2-page-desktop.png`). Then write
`tasks/proto-<prd-slug>/index.md` that **leads with the page overview (the journey-ordered page
frames)**, then the per-state breakdown grouped **by slice → state**, with a one-line caption each,
under the fidelity contract (faithful vs approximate).

If a screenshot fails, retry once; if it still fails, note it in `index.md` rather than silently
dropping the state.

### 6b. Single HTML gallery (PNG-based, overview-led — opens with `file://` AND in Studio)

After all screenshots are captured, produce `tasks/proto-<prd-slug>/preview.html` — this is the
artifact Pipeline Studio opens (it serves `preview.html` **plus its sibling PNGs** read-only). **Embed
the 6a PNG screenshots via relative `<img src>`** — NOT `<iframe srcdoc>` with captured DOM. Why: a
DOM snapshot needs a running dev server to resolve its CSS (via `<base href>`), but the dev server does
**not** persist after a proto run — so a srcdoc gallery renders **unstyled** in Studio. The PNGs are
already-rendered, faithful, viewport-correct, and need no server. (Each PNG is also naturally
CSS-isolated — no bleed between frames.)

Lead with the **page overview** (the journey-ordered full-page frames = the Figma frames), then a
secondary **state detail** section.

#### Assemble `preview.html`

Pure HTML + inline `<style>`, no external JS, two sections in journey order:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    body{margin:0;font:14px/1.5 sans-serif;display:flex}
    nav{width:210px;position:sticky;top:0;height:100vh;overflow-y:auto;padding:12px;border-right:1px solid #e5e7eb;font-size:12px}
    nav .group{font-weight:700;color:#111;margin:12px 6px 4px;font-size:11px;text-transform:uppercase;letter-spacing:.04em}
    nav a{display:block;padding:4px 6px;color:#374151;text-decoration:none;border-radius:4px}
    nav a:hover{background:#f3f4f6}
    main{flex:1;padding:24px;overflow-x:auto}
    h2{font-size:15px;margin:0 0 16px;border-bottom:2px solid #e5e7eb;padding-bottom:6px}
    .frame-group{margin-bottom:48px}
    .frame-label{font-weight:600;margin-bottom:12px;font-size:13px}
    .viewport-row{display:flex;gap:24px;align-items:flex-start;flex-wrap:wrap}
    .frame-wrap{display:flex;flex-direction:column;gap:4px}
    .vp{font-size:11px;color:#9ca3af}
    img{border:1px solid #e5e7eb;border-radius:6px;display:block;max-width:100%;height:auto}
    .fidelity{background:#fef3c7;border:1px solid #fbbf24;border-radius:6px;padding:10px 14px;font-size:12px;margin-bottom:24px}
  </style>
</head>
<body>
  <nav>
    <div class="group">Overview</div>
    <!-- one <a href="#page-<slice-n>"> per screen, in JOURNEY ORDER -->
    <div class="group">States</div>
    <!-- one <a href="#state-<slice-n>-<state>"> per screen × state -->
  </nav>
  <main>
    <div class="fidelity">
      ⚡ Faithful on: layout · components · design tokens · <b>page composition in the real shell</b>.<br>
      Mock data, no behavior — click handlers + API calls are <code>/build</code>'s work, not shown here.
    </div>

    <!-- ===== SECTION 1: PAGE OVERVIEW (the Figma frames, journey order) ===== -->
    <h2>Page overview — user journey</h2>
    <!-- for each screen, in journey order: -->
    <div class="frame-group" id="page-<slice-n>">
      <div class="frame-label"><slice-n>. <screen title> — full page in the real shell</div>
      <div class="viewport-row">
        <div class="frame-wrap"><span class="vp">desktop · 1280px</span>
          <img src="<slice-n>-page-desktop.png" alt="<screen> desktop"></div>
        <div class="frame-wrap"><span class="vp">mobile · 390px</span>
          <img src="<slice-n>-page-mobile.png" alt="<screen> mobile"></div>
      </div>
    </div>

    <!-- ===== SECTION 2: STATE DETAIL (secondary — per-state) ===== -->
    <h2>State detail</h2>
    <!-- for each screen × state (the non-happy states; the happy 'page' frame is shown above): -->
    <div class="frame-group" id="state-<slice-n>-<state>">
      <div class="frame-label"><slice-n>. <screen> — <state></div>
      <div class="viewport-row">
        <div class="frame-wrap"><span class="vp">desktop · 1280px</span>
          <img src="<slice-n>-<state>-desktop.png" alt=""></div>
        <div class="frame-wrap"><span class="vp">mobile · 390px</span>
          <img src="<slice-n>-<state>-mobile.png" alt=""></div>
      </div>
    </div>
  </main>
</body>
</html>
```

Use **relative** `<img src>` (the bare PNG filename) so the Studio resolves each image as a sibling
request — `resolveProtoAsset` serves `tasks/proto-<slug>/<file>.png`. Do NOT inline base64 or use
absolute/`localhost:PORT` paths; those break the sibling-request model and bloat the file.

#### Verify

```bash
grep -c 'id="page-'  tasks/proto-<slug>/preview.html   # = number of screens (journey frames)
grep -c 'id="state-' tasks/proto-<slug>/preview.html   # = total screen × state count
```
The first count must equal the screen count, the second the state count. If short, note the missing
frames in `index.md` rather than dropping them silently.

**Note:** the gallery shows static rendered frames (layout, hierarchy, spacing, copy, the real shell)
— all a pre-build preview needs. Interactivity is intentionally absent; that is `/build`'s work.

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

State the **cleanup contract** explicitly. The **static gallery — `preview.html` + the PNGs +
`index.md` — is the deliverable Pipeline Studio actually opens** (read-only, via `/api/proto/...`);
it persists as the record regardless. The throwaway `proto-preview/*` route (incl. the
`/proto-preview` index) and the Step 5c middleware bypass also **persist after the proto run** — but
only because they are the **capture harness** and `/build`'s promotion source, **NOT** because the
Studio serves them live (it no longer does; it opens the static gallery). So the proto run must NOT
delete them, and must NOT run on a throwaway git branch that is then deleted. They remain throwaway
w.r.t. **`/build`**, the **sole owner of teardown**: it promotes the presentational components into
real routes, then deletes the `proto-preview/*` namespace and reverts the bypass. Until `/build`
runs they live in the working tree (uncommitted is fine). The `preview.json` manifest (5e), if you
wrote one, is ignored by the current Studio and is removed with the namespace at teardown.

---

## Completion Output

```
--- /proto COMPLETE ---
PRD: <prd-file>
Design system: <Found | Partial(<which half>) | scaffolded>
Slices previewed: [N user-facing]
  1. <title> — states: happy, loading, empty, error   (screens: M)
  2. ...
Screenshots: tasks/proto-<slug>/index.md  (page overview + per-state, desktop + mobile)
HTML gallery: tasks/proto-<slug>/preview.html  (PNG-based, overview-led; opens with file:// AND in Studio)
Handoff notes: tasks/proto-<slug>-notes.md
Studio Preview: opens the static gallery (tasks/proto-<slug>/preview.html) via the Preview ↗ button

Fidelity: faithful on layout/components/look/responsive/page-composition-in-real-shell/per-state;
          approximate on live data density + edge cases; no backend/logic.

Next actions:
> Open the Preview ↗ in Pipeline Studio (the static page-overview gallery)
> Review tasks/proto-<slug>/index.md and confirm the look
> /build tasks/<prd-file>  (promotes these components into real implementation)
```
(The static `preview.html` is what the Studio opens — no marker line is needed. The `preview.json`
manifest of 5e is optional/legacy and ignored by the current Studio; only mention it if you wrote one.)

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
| Rendering the slice in a void / bare canvas instead of the real page | Full-shell composition (5b#1) — import the real layout/shell and render the slice inside it |
| State-matrix-only gallery with no page-level view | Lead `preview.html` with the journey-ordered page overview (6b); demote per-state to "state detail" |
| `<iframe srcdoc>` DOM gallery (renders unstyled in Studio — no dev server persists) | Embed the 6a PNG screenshots via relative `<img src>` (6b) — already-rendered, needs no server |
| Absolute / `localhost:PORT` / base64 `img src` in the gallery | Relative PNG filenames only — `resolveProtoAsset` serves them as siblings (6b) |
| Capturing the page frame at one viewport only | Shoot both desktop (1280) and mobile (390) — design.md is mobile-first |
| Calling "Playwright's javascript_tool" | The tool is `mcp__claude-in-chrome__javascript_tool` — use the exact MCP tool name |
| Deleting the `proto-preview` route at the end of the proto run | It PERSISTS — `/build` owns teardown (Step 8). It's the capture harness + promotion source, not a deletable scratch file |
| Advertising the `preview.json` manifest as a live Studio preview | The current Studio ignores it and opens the static `preview.html`; the manifest is optional/legacy (5e) |
| Preferring a bare / Storybook harness when the real shell can mount | Prefer full-shell composition (5b#1) for page fidelity; the bare harness is the fallback only |

## Rules

- **Preview, not build.** No backend, no real data, no state logic, no tests, no prod routes.
- **PRD is source of truth.** Scope = its user-facing slices; states = its §9/§10 + the Gherkin;
  boundaries = its §11 non-goals. Never re-elicit scope.
- **Real components or stop.** Gate 2 is blocking — a faithful preview without a real design system
  is a contradiction; say so rather than fabricate.
- **Throwaway but shell-faithful.** The preview **composes the real app shell** (5b#1) for page
  fidelity, yet lands only under the `proto-preview` namespace (or Storybook, the fallback), marked
  disposable, with a cleanup contract handed to `/build`.
- **Overview first.** The gallery leads with the journey-ordered full-page frames (the Figma view);
  per-state shots are secondary detail — never a state matrix alone (6b).
- **Honest fidelity, every run.** Always show what the preview is faithful on vs approximate on.

## Script

```bash
#!/bin/bash
mkdir -p tasks
```
