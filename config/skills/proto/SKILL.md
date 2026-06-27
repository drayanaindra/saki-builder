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

Pipeline Studio's live Preview serves a **running dev-server route**, so a routable `proto-preview`
route is the PRIMARY target — prefer it whenever the provider chain mocks cleanly (5a). A Storybook-
only or static-only run yields **no live Studio preview** (Studio hides the Preview button); the
screenshot gallery is still produced as a record.

1. **Throwaway route** (PREFERRED — enables the live Studio preview) — create
   `app/proto-preview/<slice>/page.tsx` (Next), or a `proto-preview` route (Vite/Remix), wrapped in
   the 5a mock providers. ALSO create a routable **`/proto-preview` index** page that links each
   slice's route — this single entry URL is what the Studio opens (and what the manifest's `route`
   points at, Step 5e). Drive states via a query param (`?state=empty|loading|error`), or stack
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
2. **Storybook**, only if a clean route can't mount — stories mount components in isolation with
   explicit decorators for the providers from 5a; no app shell, no auth, no routing. Use the
   `component` skill's `.stories.tsx` convention. (No live Studio route — screenshot gallery only;
   do NOT write a manifest, Step 5e.)
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

### 5e. Write the live-preview manifest (enables Pipeline Studio's live Preview)

If — and ONLY if — a routable `proto-preview` entry serves cleanly (5b option 1), write
`tasks/proto-<prd-slug>/preview.json` so the Studio can re-start the dev server and open the route on
demand (a headless run can't keep its own dev server alive). Compose it from the Gate-2 detection:

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

For each screen × state, navigate the preview route and capture screenshots at **two viewports**
(design.md is mobile-first):
- **desktop** (e.g. 1280 wide)
- **mobile** (e.g. 390 wide)

Save to `tasks/proto-<prd-slug>/<slice-n>-<state>-<viewport>.png`. Then write
`tasks/proto-<prd-slug>/index.md` that embeds every shot grouped **by slice → state**, with a
one-line caption each, and leads with the fidelity contract (faithful vs approximate).

If a screenshot fails, retry once; if it still fails, note it in `index.md` rather than silently
dropping the state.

### 6b. Single HTML gallery (iframe-isolated, opens with file://)

After all screenshots are captured, produce `tasks/proto-<prd-slug>/preview.html`.

#### Capture DOM (do separately for each viewport)

For each screen × state, capture at both viewports using `mcp__claude-in-chrome__resize_window`
followed by `mcp__claude-in-chrome__javascript_tool` with:
```js
return document.documentElement.outerHTML
```
Resize to **1280px** wide first → capture desktop snapshot. Then resize to **390px** → capture
mobile snapshot. (Tailwind breakpoints are baked into the rendered DOM — capturing at the real
viewport width is the only way to get correct responsive layout.)

Assert the returned string length is > 1000 chars; if truncated, chunk via
`document.head.innerHTML + document.body.innerHTML`.

#### Patch each captured snapshot

Inject `<base href="http://localhost:PORT/">` immediately after `<head>` in each snapshot. This
makes same-origin `url()` references (fonts, images, CSS chunks) resolve against the running dev
server — layout is faithful when the server is up; falls back to unstyled text/layout-only offline.

**Do NOT** try to replace `<link>` tags with inline `<style>`: dev servers (Next.js/Vite) inject CSS
via JS-driven `<style>` blocks at runtime, so `<link rel="stylesheet">` is usually absent — parsing
it finds nothing. The `<base href>` approach is simpler and correct.

#### HTML-escape each snapshot for `srcdoc` embedding

Each captured snapshot becomes an `<iframe srcdoc="...">` attribute value. HTML-escape it first:
```bash
python3 -c "import html,sys; print(html.escape(sys.stdin.read(), quote=True))" < snapshot.html
```
This converts `"` → `&quot;`, `&` → `&amp;`, `<`/`>` → `&lt;`/`&gt;`. Required — without it,
`srcdoc` terminates early on the first `"` inside the captured HTML.

#### Assemble `preview.html`

Write the gallery with pure HTML + inline `<style>` (no external JS):

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    body{margin:0;font:14px/1.5 sans-serif;display:flex}
    nav{width:200px;position:sticky;top:0;height:100vh;overflow-y:auto;padding:12px;border-right:1px solid #e5e7eb;font-size:12px}
    nav a{display:block;padding:4px 6px;color:#374151;text-decoration:none;border-radius:4px}
    nav a:hover{background:#f3f4f6}
    main{flex:1;padding:24px;overflow-x:auto}
    .state-group{margin-bottom:48px}
    .state-label{font-weight:600;margin-bottom:12px;font-size:13px}
    .viewport-row{display:flex;gap:24px;align-items:flex-start}
    .frame-wrap{display:flex;flex-direction:column;gap:4px}
    .frame-label{font-size:11px;color:#9ca3af}
    iframe{border:1px solid #e5e7eb;border-radius:6px;display:block}
    .fidelity{background:#fef3c7;border:1px solid #fbbf24;border-radius:6px;padding:10px 14px;font-size:12px;margin-bottom:24px}
  </style>
</head>
<body>
  <nav>
    <!-- one <a href="#slice-N-state"> per state, generated from the slice list -->
  </nav>
  <main>
    <div class="fidelity">
      ⚡ Faithful on: layout · components · Tailwind tokens · CSS hover/transitions.<br>
      Not interactive: click handlers + API calls stripped — that is /build's work.<br>
      Assets (fonts, images) load when dev server is running on PORT.
    </div>
    <!-- for each state: -->
    <div class="state-group" id="slice-N-state">
      <div class="state-label">Slice N — happy</div>
      <div class="viewport-row">
        <div class="frame-wrap">
          <span class="frame-label">desktop · 1280px</span>
          <iframe srcdoc="[HTML-ESCAPED DESKTOP SNAPSHOT]" width="1280" height="800" scrolling="yes"></iframe>
        </div>
        <div class="frame-wrap">
          <span class="frame-label">mobile · 390px</span>
          <iframe srcdoc="[HTML-ESCAPED MOBILE SNAPSHOT]" width="390" height="800" scrolling="yes"></iframe>
        </div>
      </div>
    </div>
  </main>
</body>
</html>
```

Each state gets its **own** `<iframe srcdoc>` — this provides CSS isolation so one state's
`position:fixed` overlays, Tailwind resets, and global CSS rules cannot bleed into adjacent states
or the gallery nav.

#### Verify

```bash
grep -o 'id="slice-' tasks/proto-<slug>/preview.html | wc -l
```
Count should equal the total state count across all slices. If short, note missing states in `index.md`.

**Note on JS interactivity:** click handlers and data fetching are intentionally absent — the gallery
shows visual states (layout, hierarchy, CSS transitions, spacing, copy) which is all a pre-build
preview needs. For live interaction, open the running dev-server route directly.

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

State the **cleanup contract** explicitly. The `proto-preview/*` route (incl. the `/proto-preview`
index), the Step 5c middleware bypass, and the `preview.json` manifest (5e) **PERSIST after the proto
run** — they are exactly what Pipeline Studio re-runs to serve the live Preview, so the proto run must
NOT delete them, and must NOT run on a throwaway git branch that is then deleted (that would erase the
live route). They remain throwaway w.r.t. **`/build`**, which is the **sole owner of teardown**: it
either promotes the components into real routes or deletes the `proto-preview/*` namespace, reverts the
bypass, and removes the manifest. Until `/build` runs they live in the working tree (uncommitted is
fine). The `index.md` + PNG gallery are a separate record and persist regardless.

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
HTML gallery: tasks/proto-<slug>/preview.html  (self-contained, open with file://)
Handoff notes: tasks/proto-<slug>-notes.md
Live preview: <PROTO_PREVIEW_MANIFEST: tasks/proto-<slug>/preview.json | none (Storybook/static run)>

PROTO_PREVIEW_MANIFEST: tasks/proto-<slug>/preview.json

Fidelity: faithful on layout/components/look/responsive/per-state;
          approximate on live data density + edge cases; no backend/logic.

Next actions:
> Open the live Preview in Pipeline Studio (the running /proto-preview route)
> Review tasks/proto-<slug>/index.md and confirm the look
> /build tasks/<prd-file>  (promotes these components into real implementation)
```
(Emit the bare `PROTO_PREVIEW_MANIFEST: …` line ONLY when 5e wrote a manifest — it is the marker the
Studio parses to enable live Preview. Omit it entirely on Storybook-only / static-only runs.)

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
| Embedding full `<html>` docs as `<section>` children | Use `<iframe srcdoc>` per state — CSS isolation, no bleed |
| Inlining CSS by parsing `<link>` tags on a dev server | Dev servers inject CSS via JS at runtime; use `<base href>` instead |
| Capturing DOM at desktop viewport for the "mobile" frame | Resize to 390px first, then capture — Tailwind breakpoints are viewport-baked |
| Embedding raw `outerHTML` in `srcdoc` without escaping | Escape first: `python3 -c "import html,sys; print(html.escape(sys.stdin.read(), quote=True))"` |
| Calling "Playwright's javascript_tool" | The tool is `mcp__claude-in-chrome__javascript_tool` — use the exact MCP tool name |
| Deleting the `proto-preview` route / manifest at the end of the proto run | They PERSIST — `/build` owns teardown (Step 8). Deleting them erases the live Preview |
| Writing a `preview.json` manifest for a Storybook-only / static-only run | Manifest + marker ONLY when a real `proto-preview` route serves (5e) — else the Studio's live boot 404s |
| Hard-coding a port (or omitting `{PORT}`) in the manifest `devCommand` | Leave the literal `{PORT}` — the Studio allocates a free port and substitutes it (5e) |
| Reaching for Storybook when a clean route would mount | Prefer the route harness (5b #1) — Storybook yields no live Studio preview |

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
