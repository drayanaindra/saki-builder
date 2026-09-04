---
name: proto
description: Render a faithful, throwaway UI preview of a finished PRD's COMPLETE end-to-end user journey — every user-facing step plus the connective entry/success screens that join them, each in all its reachable states — INSIDE the project's REAL app shell (nav/header/sidebar) using its real design-system components + tokens with mock data, then screenshot the full pages + states and assemble a Figma-like, journey-ordered page-overview gallery — so you see how the design looks as actual composed pages BEFORE /saki-builder:build runs. When the Figma MCP is connected, optionally also exports the same preview into Figma (editable layers, or a screenshot board) for review/edit in Figma. Also emits a single self-contained `preview-bundle.html` — every screenshot inlined — that's easy to share as one file (email/Slack/drive, no folder). Sits between /saki-builder:prd and /saki-builder:build. Usage — /saki-builder:proto <prd-file.md> [--slice=N].
---

# UI Preview Stage (faithful, throwaway)

You produce **expectation-setting visibility**: what the end-user UI will look like, rendered with
the project's **real** design-system components and tokens, screenshotted across every state —
**before** `/saki-builder:build` writes a line of production code. Pipeline: `/saki-builder:prd → /saki-builder:proto → /saki-builder:build`.

This is a *preview*, not a build. Hold the line on what it is and isn't:

- **It IS faithful on**: layout, component selection, visual hierarchy, copy, look-and-feel,
  responsive behavior, **page composition within the real app shell** (nav / header / sidebar around
  the slice), **consistency with the product's analogous shipped pages** (a new screen reads as this
  app's next iteration, not a standalone bolt-on), and the per-state look (loading / error / empty /
  validation / permission).
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
  footnote in **§Fidelity reductions** of `index.md`.

---

## Input

Usage: `/saki-builder:proto <E<n>|F<n> | prd-file.md> [--slice=N] [--restart]` (filler words fine) — or `/saki-builder:proto --figma-only <gallery-dir>`
to (re)export an existing gallery to Figma without re-rendering (runs Step 6c only). An interrupted run
**resumes** at the next incomplete phase by default (Step 0.5); `--restart` forces a clean run from scratch.

Locate the PRD exactly like `/saki-builder:build`. **PRD-track item id (`E<n>` or `F<n>`) — the disciplined
path:** if the argument is an item id, read `tasks/roadmap.md`, find `### <id>`, and resolve its
`**Child PRD:**` link to `tasks/prd-<slug>.md`. If `<id>` has no Child PRD yet (its value is `—`), **STOP**:
`<id> has no PRD yet — run /saki-builder:pickup <id> first`. Otherwise take the token ending in `.md` (or matching `prd-*`), and
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
~/.omp/agent/hooks/design-engine-setup.sh detect
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

## Step 0.5 — Resume detection (a hard stop must not restart from zero)

`/saki-builder:proto` writes durable checkpoints to `tasks/proto-<slug>/` and the project tree as it runs,
so an interrupted run (hard stop, crash, killed turn) can **resume at the next incomplete phase** instead of
redoing expensive work — re-codifying real components (2.6), re-mounting the harness (5), or re-capturing
the headless screenshots (6a). Run this the moment the PRD path is resolved (Input/Step 0) and `<slug>` is
known — **before** GATE 1 re-writes the manifest. `--restart` forces a clean run (ignore this step; re-derive
every artifact); `--figma-only` also skips it (export-only path). Otherwise:

1. **No gallery → fresh run.** If `tasks/proto-<slug>/` does not exist, there is nothing to resume — proceed
   to GATE 1 normally.
2. **Scope must match, or don't resume.** Read the top of `screen-manifest.md`: a manifest stamped
   `PARTIAL (--slice=N)` covers ONE slice — resume only when THIS invocation passes the same `--slice=N`; a
   full manifest resumes only a no-`--slice` invocation. On any scope mismatch, do NOT resume — announce it
   and start fresh (or tell the user to pass the matching flag, or `--restart`).
3. **Walk the checkpoint ledger in order; find the highest contiguous DONE, resume at the next phase.** A
   checkpoint is DONE only when its artifact is present **AND** its own gate re-verifies — presence ≠
   correctness, a half-written file is not DONE:

| # | Phase | DONE when | Re-verify (cheap) |
|---|-------|-----------|-------------------|
| 1 | GATE 1 | `screen-manifest.md` exists | non-empty, has numbered rows |
| 2 | 2.4 | `reuse-map.md` exists | non-empty **AND derived from the real app** — a map reconstructed from the harness is NOT DONE (Step 5's correctness gate + point 7 re-check) |
| 3 | 2.6 | `design-system-updates.md` exists AND every component file it names exists | `tsc --noEmit` over those files passes (the Step 2.6 gate) |
| 4 | 5 | the `proto-preview/*` harness route exists | 5d provenance + typecheck pass; the 5c middleware bypass is still present (re-add if missing) |
| 4.5 | 5.5 | `devserver.json` exists and is schema-valid | pid alive **AND** its cwd is the project root (`lsof -a -p <pid> -d cwd`) **AND** `lsof -nP -i :<port> -sTCP:LISTEN` shows `127.0.0.1` (query by port, `-n` for numeric — see 5.5d/5.5f); if dead, foreign, or non-loopback ⇒ **NOT DONE — re-enter Step 5.5** (5.5a reuse-or-reboot), never 6a directly |
| 5 | 6a | `proto-capture.mjs` + `hotspots.json` + the page PNGs exist | Coverage-Gate diff (manifest vs `*-page-*.png`); if frames are missing, resume INTO 6a and re-run the capture to fill only the gaps |
| 6 | 6b | `preview.html`, `preview-bundle.html` **and** `index.md` exist | the Step 6b `title:` / `page:` counts; the bundle has `data:image/png;base64` refs (6b-bis); **`index.md` carries its `## Fidelity reductions` section** (an empty list is valid — a MISSING section means the producer spec never ran, so this checkpoint is NOT DONE). **On resume, do NOT write an empty list to satisfy this:** the section is *accumulated* across 5b/5c/6a/6c, which are in-context judgments with no other durable artifact, so a fresh context cannot reconstruct what an earlier run noted. Write `- (earlier reductions not recoverable — run resumed at 6b)` instead, so a silently-empty list can never read as "nothing was reduced" — if `preview.html` exists but the bundle is missing/stale, just re-run `proto-bundle.mjs` (cheap, deterministic — not a from-scratch phase) |
| 7 | 8 | `proto-<slug>/notes.md` exists | non-empty |
| 8 | 8.5 | `proto-<slug>/.prd-locked` exists (and the PRD carries `<!-- prd-locked: … -->` when the PRD file exists) | marker present |

4. **In-context-only phases never block resume.** The gap analysis (2.5), state map (Step 3), and mock-data
   reasoning (Step 4) are chat reasoning whose OUTPUT already lives in the artifacts above (2.5 → the codified
   component files + `design-system-updates.md`; 4 → the mock data baked into the harness). Do NOT re-run them
   on resume; when a later phase needs the gap-analysis summary on screen (e.g. Step 7b), **reconstruct** it
   from `reuse-map.md` + `design-system-updates.md` rather than regenerating the analysis.
5. **Approval is proven ONLY by the lock marker (Step 8.5), never by a later artifact.** Step 7's human
   approval is in-context and not durably recorded until the lock is written. So even when `preview.html` and
   the notes exist, an **unlocked** PRD resumes at **Step 7 (re-present for approval)** — never auto-lock a run
   whose approval you cannot see. The lock markers are the durable proof the human said yes.
6. **Partial-write safety.** A hard stop *inside* a phase can leave a half-written component (2.6) or harness
   file (5); the re-verify column catches it — a failing typecheck/provenance gate means that checkpoint is
   NOT DONE, so resume re-enters that phase and completes it rather than trusting a corrupt artifact. This is
   the same "verify code state, not a status flag" discipline the Coverage Gate already applies.
7. **Never reconstruct grounding from the harness — a missing map + a present harness is INCONSISTENT, not
   resumable.** If `reuse-map.md` / `screen-manifest.md` are missing while the harness or PNGs exist
   (checkpoints 1–2 not DONE but 4–5 are), the first run's grounding was skipped/broken — so the harness is
   **UNTRUSTED**. Re-derive the inventory from the REAL app (fresh Step 2.4 against `apps/**`/`src/**`); NEVER
   reverse-engineer the map from the harness's imports — that launders the original errors forward (observed:
   a resumed run rebuilt `reuse-map.md` from `StudioShell.tsx` and re-shipped every misclassification). Treat
   it as `--restart` for the grounding phases.
8. **Announce, then auto-resume.** Print one line —
   `Resuming /saki-builder:proto <slug> from <phase> (checkpoints 1–K found in tasks/proto-<slug>/).` — then
   continue at that phase. Proto auto-proceeds by design; resume inherits that. `--restart` is the escape.

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

**Never re-elicit scope.** Scope comes from the PRD — its journey, its §9/§10 states, its §11 boundaries.
Do not go back to the user to re-ask what is already written; a gap in the PRD routes through the
Convergence loop, not through a question.

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
  shows must be a surface `/saki-builder:build` builds). If it's not in §8, **enter the Convergence loop** —
  invoke `/saki-builder:prd`/`/saki-builder:prd-review` to add it, re-derive the manifest, continue — do NOT
  stop; proto and PRD must agree, reached by looping, not by pausing.
- **The surface is genuinely out of scope** (§11) → it must NOT be a live affordance in the shell. Note
  it, and treat the dangling nav item as a shell-fidelity bug to remove, not a screen to invent.
This is distinct from "never invent a feature beyond §11": that forbids *adding* scope; this forbids
*shipping a shell that promises scope the journey doesn't cover*. The reconciliation is two-way.

Also read any `tasks/*-flow.md` (rplan Step 2.5 Gherkin) for the slice — it already enumerates the
states the user expects. If present, it is the authoritative state list.

**Persona check:** after loading the PRD, check if `.omp/personas/*.md` exists. If it does,
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
count** for the whole run. Lead the file with the shareable header (below) so it is legible to a teammate
who wasn't in the run:

### screen-manifest.md

```markdown
# Screen Manifest — <prd-slug>
**Owner:** <@name | unassigned> · **Status:** Frozen | PARTIAL (--slice=N) · **Updated:** <YYYY-MM-DD>
**PRD @** <path>@<git sha>
```
The Coverage Gate (before Completion) hard-checks that every row has a captured
frame. It is "what the flow looks like when the PRD is complete" written down once, so completeness is
*verifiable*, not asserted. Derive it mechanically from the PRD — do NOT pause to let scope be negotiated
down; the manifest is the floor, not a proposal. A no-arg run manifests the ENTIRE journey; only an
explicit `--slice=N` may scope the manifest to one slice, and it is then labelled `PARTIAL` at the top of
the file and in the Completion Output — never the default. **Do not start rendering (Step 3+) until the
manifest is written.**

**Enumerate with critical thinking + curiosity — the manifest is a CEILING to reach, not a floor to clear
(this is where screens go missing).** The Coverage Gate only checks that *manifested* screens were captured —
it is **blind to a screen you never listed**, so a thin, mechanically-derived manifest sails through every
downstream gate while the gallery is missing a screen (the exact failure observed). Mechanical derivation sets
the floor; **curiosity raises it to the real ceiling.** Before freezing the manifest, interrogate the PRD like
a skeptical senior designer — for every slice / criterion / rule / affordance ask *"what screen does this imply
that I have NOT listed?"*:
- **Every §9 criterion / §10 rule** — each `When X then Y` and each invariant (`rejected if amount > balance`,
  `only one active`) implies a state/screen (the rejection view, the at-limit view). Listed?
- **Every branch & error path** — a decision point has ≥2 outcomes; a fallible action has a failure screen
  (declined, upload failed, not-found, expired/invalid link, timeout). Are BOTH sides listed, not just the
  happy one?
- **Every role** (§10) — multi-role flows have per-role screens (admin view vs member view, the
  pending-approval wait screen).
- **Every entry & exit** — how does the user *first arrive* (deep link, email, first-run empty) and what is the
  *terminal* screen for **each** path (success — and each failure's dead-end)?
- **Every shell affordance** (Gate 2 walk) — does each nav / menu / CTA / clickable-row destination have a row?
- **Every transition** — is there an intermediate / loading / confirmation screen between two steps the flow
  glosses over?
Any screen this surfaces that the **PRD covers** → **add it to the manifest**. Any it surfaces that the **PRD
does NOT cover** → that's a coverage gap → **Convergence loop** (fix the PRD, re-derive). Run this
interrogation once, explicitly, and note the rows it added — an *unquestioned* manifest is precisely how a
screen goes uncovered.

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

## Convergence loop — proto ⇄ `/saki-builder:prd` (autonomous; the human gate is the VISUAL, not the abstract)

**Why a loop, not a pause.** Without a rendered screen a human can't judge scope in the abstract — *"is this
surface in scope?"* is unanswerable as text but obvious as a picture. So when proto surfaces a blocker whose
root cause is **the PRD doesn't cover what the journey needs**, it does NOT stop and ask — it **converges
autonomously** by adjusting the PRD through its owner, then presents the finished visual as the *single* human
gate (Step 7 → lock 8.5). Mirrors `/saki-builder:build`'s `/saki-builder:wrap --heal` convergence and
`/saki-builder:pickup`'s `/saki-builder:prd ⇄ /saki-builder:prd-review` loop.

**Route every fork by DESIGN gap vs COVERAGE gap:**
- **Design gap** (how a screen *looks* / holds the journey — a BIG design-only 🔶) → proto resolves it itself
  with senior-designer rigor (Step 2.5). **No loop.**
- **Coverage gap** (the PRD doesn't *cover* what the journey needs — a dead-end shell affordance with no
  screen (GATE 1), a journey step / backend-outcome screen with no §8 home, a scope-altering 🔶 (Step 2.5), an
  uncovered state a §9 criterion implies, a screen the Coverage Gate can't source) → **enter this loop.** Proto
  must never invent scope itself (scope is `/saki-builder:prd`'s — Step 8.5), so it **delegates** the fix.

**The loop (bounded, autonomous):**
1. **Name the gap** precisely — which affordance / step / screen the journey needs, and where the PRD is
   silent (cite §8 / §9 / §11).
2. **Adjust the PRD via its owner** — invoke **`/saki-builder:prd-review`** when the gap is a
   coverage/criteria hole in *existing* slices, or **`/saki-builder:prd`** when a genuinely *new* surface/slice
   must be added. Pass the named gap. The PRD skill makes + owns the scope change; proto never hand-edits scope.
3. **Re-derive downstream** — re-run from **GATE 1** (rewrite the Screen Manifest from the updated PRD) → Reuse
   Map (2.4) → render (5) → capture (6) → Coverage Gate. Lean on Step 0.5 resume so unaffected artifacts aren't
   rebuilt.
4. **Re-check + record.** Log each pass's PRD adjustment (what changed · why) to
   `tasks/proto-<slug>/prd-adjustments.md`. If any coverage blocker remains, loop again.

**Convergence + escape.** The loop ends when GATE 1's shell-walk **and** the Coverage Gate find **zero
uncovered surfaces** — every affordance maps to a captured screen, every journey step has a §8 home. **Bound it
at ≤3 passes.** If it still can't converge (PRD and journey keep disagreeing), the blocker is a genuine
**product** question, not a coverage mechanic — **only then** stop and surface it (situation · options ·
recommendation), because more autonomous passes will only drift (the "recut > fix-then-fix" signal).

**Human gate = the result.** Present at Step 7 with a **"PRD adjusted this run"** changelog (from
`prd-adjustments.md`) so the single gate is informed; Step 7 approval + the Step 8.5 lock freeze the reconciled
PRD. No mid-flight scope pause — the human judges scope by *seeing* it.

---

## GATE 2 — Design-system detection (BLOCKING — the honesty gate)

A faithful preview is only possible if the project has a real, code-level design system to render.
This gate is the entire reason "1:1" is true rather than aspirational. Detect:

- **Component library** — `components.json` + `components/ui/*` (shadcn/ui); or MUI / Chakra /
  Mantine / Ant Design / Radix in `package.json`; or a local `src/components/` (or `app/components`)
  library with reusable primitives.
- **Tokens** — Tailwind `@theme` directive / `tailwind.config.*`; CSS custom properties
  (`--color-*`, `:root` vars); a `tokens.*` / `theme.*` file. The canonical shape is the
  **Design System Contract Part B** role schema (`skill://saki-builder-runtime/docs/design-system-contract.md`):
  the eight color roles (`primary · surface · surface-raised · border · text · text-muted · danger · success`)
  should exist as `--color-<role>` / `theme.colors.<role>`. If `design.md` (the project's Part A block) is
  present, read it — it names the token source. Tokens that exist but don't fill the Part B roles = **Partial**.
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
page's **current-state screenshot** as the visual baseline you design the delta against.

**A brand-new screen has no direct predecessor — but it is NEVER a blank canvas (BLOCKING anchor).** It
always has a **nearest-analogous shipped page**: the closest same-product surface by *shape* — a list, a
detail view, a form, a wizard step, a settings pane, a dashboard. Find it (grep the real feature dirs for the
same shape, not the same nouns), open it, and make ITS composition the baseline the new screen inherits:
**page scaffold** (where the header / primary action / sidebar sit), **content density + spacing rhythm**,
and the **interaction model** (how rows / cards / forms behave elsewhere in THIS app). A net-new feature that
invents its own layout paradigm — even from perfectly correct design-system components — reads as *a different
product bolted on*, not this product's next iteration. That anchor is the whole difference between
"design-wise correct" and "looks like the same app grew a feature," and its absence is the #1 cause of a
proto that feels standalone per-task instead of continuous product development. Record the chosen anchor in
the Reuse Map (below); it is what Step 2.5's page-consistency check and Step 5d's coherence check verify
against. Only if a genuinely-honest search finds NO analogous shipped surface (a first-of-its-kind product
shape) is there nothing to anchor to — say so explicitly in `reuse-map.md`, don't skip silently.

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

Write a **Reuse Map** to `tasks/proto-<prd-slug>/reuse-map.md`, led by the shareable header, one row per screen:

### reuse-map.md

```markdown
# Reuse Map — <prd-slug>
**Owner:** <@name | unassigned> · **Status:** Derived from the real app · **Updated:** <YYYY-MM-DD>
**PRD @** <path>@<git sha>
```


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
- **NEW** → no equivalent exists → flows to Step 2.5 for a spec. **Only genuinely-absent surfaces.** Each
  NEW *screen* row MUST also record its **anchor** — the nearest-analogous shipped page it inherits
  composition from (`anchor: <page> @ <path>`), or `anchor: none (first-of-shape)` if an honest search found
  none. A NEW *component* inherits its anchor from the screen it lives on; it needs no separate one.

**Reuse-first is the rule, not a preference:** if a screen is largely already implemented, proto's job is
to mount the real implementation with mock data — not to redesign it. Do NOT send an EXISTING component to
the 2.5 gap analysis; the gap analysis is only for what the app does not yet have. The provenance check
(5d) later verifies the render actually imported every EXISTING/shell row here.

**A `NEW` classification is a CLAIM OF ABSENCE — prove it.** Before marking any screen/component `NEW`, grep
the REAL feature dirs (`apps/**`, `src/components/**` beyond `ui/`, `src/features/**`, `modules/**`,
`pages/**`) for a component matching its surface/nouns; only an **empty** result justifies `NEW`. Never mark
`NEW` because the current or a prior proto harness didn't import it — the harness is not the source of truth,
the real app is. A misclassified `NEW` is precisely what makes proto reinvent a component that already exists
(observed: `SaasBar`/`LoginScreen` marked NEW, `PipelineGraph`/`StreamPanel` stubbed — all four shipped).

**Name-drift check (net-new screens only — a flag, never an auto-pick).** For a screen with **no
EXISTING/PRIMITIVE Reuse-Map row** (a genuinely-new surface) that will render the product/brand name,
resolve the brand string from the **implemented** design system / app shell — grep the real shell for the
rendered brand literal (the wordmark in the real `TopBar` / login / app-bar) — and compare it to the
product/brand name the PRD or roadmap uses. If they **differ**, do NOT type the spec's title into the
render — proto's job is to look like the *shipped* app, so **default to the implemented brand automatically**,
log the drift to `prd-adjustments.md`, and surface it at Step 7 (the human sees the rendered brand and can
confirm/override there). Don't pause mid-run. A *deliberate rebrand* is a scope change, not a proto tweak →
route it through the **Convergence loop** (`/saki-builder:prd`), never hand-type a new brand into the render:
```
NAME DRIFT — new screen "<name>": spec/roadmap name "<spec>" ≠ the brand the implemented UI renders
("<real>", <path>). Rendered with the implemented brand "<real>"; logged for Step-7 confirmation.
(Intentional rebrand? → Convergence loop via /saki-builder:prd, not a proto edit.)
```
The drift this exists to catch, concretely: a spec titled **"Builder Workflow Studio"** rendered onto a screen
whose implemented shell says **"Saki Studio"**.

This is **redundant for reused screens**: an EXISTING row is imported verbatim (Step 5), so the real brand
comes along automatically — the check earns its keep only where there is no component to import.

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

**🔶 escalation — decide it like a senior designer; only a SCOPE change pauses.** Judge the change by what it touches:
- **SMALL** (local to one screen, absorbable as a variant/component) → it isn't really 🔶; resolve it as
  ⚠️/❌ and note it.
- **BIG but design-only** (shell/nav restructure, a page's layout paradigm, a net-new pattern, or a ripple
  across >1 screen — all *within* the PRD's scope) → **auto-resolve; do NOT pause.** But decide it with the
  rigor of a **senior UI/UX designer**, not a snap pick: (1) enumerate 2–3 real options; (2) judge each against
  the **existing design language** (does it still read as the same shipped app?), the **cost ladder** (the
  lowest rung that faithfully holds the journey), the **interaction** the journey needs, **cross-screen
  consistency**, **accessibility** (4.5:1 contrast, keyboard, landmarks), and **responsive** behavior at both
  viewports; (3) commit to the option that is most faithful to the real app at the lowest cost, and add the
  minimum — never a bigger redesign than the journey forces. Then **record the decision** in
  `design-system-updates.md` (the options weighed · the pick · the rejected alternatives + why · the screens
  affected), build it in **Step 2.6**, and let **Step 7b** be the human's review/reversal point — the same
  auto-proceed-then-review backstop the gap analysis already uses. Never force-fit and never *silently*
  redesign: auto-resolving means a **reasoned, recorded** design decision, not an unexamined one.
- **BIG that alters SCOPE** (new features/screens, not just layout/pattern — beyond §8/§11) → **this is not a
  design decision proto may make** (it violates "never invent a feature beyond §11"), so proto **delegates**:
  **enter the Convergence loop** — invoke `/saki-builder:prd`/`/saki-builder:prd-review` to reconcile scope
  (GATE 1's two-way rule), re-derive, and continue — rather than pausing mid-run. The human judges the added
  scope at Step 7 by *seeing* it rendered, not as an abstract prompt. (If the loop can't converge in ≤3 passes,
  THEN surface it — a genuine product question.)

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
   **Match the project's format exactly — the two ways this goes wrong:** writing `var(--token-name)` in
   component files for an **MUI** project (MUI tokens live in `theme.ts` — consume via `tokens.status.*` /
   `theme.palette.*`, never CSS vars the project never defined), and adding **CSS custom properties to a TS
   tokens object** (`theme.ts`). They are mirror images of the same mistake: using another stack's token
   syntax.
5. **States** — hover, focus, disabled, loading, error, selected — only what the component actually needs
6. **Accessibility** — ARIA role, keyboard behavior, contrast check (4.5:1 minimum)
7. **Consistency check (component + page)** — name 2–3 closest existing components; note deviations and why.
   **For a net-new screen, ALSO name its Step-2.4 anchor page and the composition it inherits** — layout
   paradigm, header / primary-action placement, density + spacing rhythm, interaction model — and justify
   every deviation from it. An unjustified new layout paradigm is the defect that makes a feature read as a
   standalone product; if the screen genuinely needs a paradigm the anchor can't host, that is a 🔶 (design
   change), not a silent divergence.
   **When the Step-2.4 anchor is `none` (first-of-shape — a page shape the app has never had),
   page-anchoring is impossible; fidelity then rests on the materials + idioms that DO have siblings:**
   (i) compose inside the real app shell — never a bare page; (ii) real design-system tokens/primitives
   only — build any new pattern to the design-system-contract + the `frontend-design` skill, never
   free-hand it; (iii) borrow the app's cross-cutting idioms — empty / loading / selection states, panel
   chrome, spacing rhythm — from existing screens even though the layout is new (*new composition, same
   vocabulary*). Mark the screen **`first-of-shape`** so Step 7 eyeballs it hardest: it is the one screen
   with no sibling to auto-check against, so it carries the highest residual look-risk.

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

**Auto-proceed after presenting** — do NOT pause for confirmation. Present the gap analysis and
proposed specs inline, then immediately continue to **Step 2.6** (codify the confirmed additions into the
real design system) and on to rendering. The user reviews and adjusts at **Step 7b** ("do you want to
revise any of them?") — that is the backstop, and Step 7.5 applies any revision to the real component.
Pausing at Step 2.5 before any render exists adds a blocking round-trip with no concrete artifact to react
to; Step 7b, after the screenshots, is the more actionable review point.

If the user explicitly says "stop and let me review specs" mid-run, honor it — but do not pause by default.

If all components exist (no ⚠️/❌ entries), state "No design system extensions needed" and
proceed to Step 3.

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

**Build every NEW/⚠️ component to the Design System Contract** (`skill://saki-builder-runtime/docs/design-system-contract.md`):
tokens-only (Part B roles, no raw values), every applicable state (Part C.3), the Part F quality floor, and
built the way the project's **gold-standard component** (`design.md` Part A) is built. Real component, not an
approximation — that's the whole point of codifying before render.

**Gate (BLOCKING — a component that fails is NOT done):**
1. **Part C self-check** passes for each new/⚠️ component — zero hardcoded values (all trace to Part B
   tokens) · `default·hover·focus·active·disabled` present + `loading·error·empty` where reachable · contrast
   ≥ 4.5:1 · touch target ≥ 44px · visible focus ring · keyboard-operable + correct ARIA · matches the
   gold-standard. Any unchecked box → fix before Step 5, do not render an incomplete component.
2. **Typecheck** the new components/tokens before Step 5 — they are imported next, so a broken one crashes
   every frame.

Codify the ✅-confirmed ⚠️/❌ **and any BIG design-only 🔶 that Step 2.5 auto-decided** (it is now
a concrete set of component/layout changes — build it here, per its recorded decision). **Never build a
scope-altering 🔶** — that one routed to `/saki-builder:prd`, not here. If 2.5 found no ⚠️/❌/🔶 to build, state
"No additions to codify" and continue to Step 3.

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

**Grounding gate (BLOCKING — the Reuse Map + Screen Manifest must exist AND be correct before any render).** Step 5
composes against the Step 2.4 **Reuse Map** and the GATE 1 **Screen Manifest**; without them there is
nothing to compose against and the 5d provenance grep passes *vacuously* (zero rows) — exactly how a real
run shipped reinvented components under an invented brand. So before mounting anything, hard-verify both
artifacts exist and are non-empty:
```bash
S=tasks/proto-<prd-slug>
[ -s "$S/reuse-map.md" ]       || echo "MISSING reuse-map.md"
[ -s "$S/screen-manifest.md" ] || echo "MISSING screen-manifest.md"
```
If either is missing or empty, **HARD-STOP** — do NOT render:
```
HARD STOP — GROUNDING MISSING
Step 5 cannot render: <which file(s)> absent or empty.
The Reuse Map (Step 2.4) + Screen Manifest (GATE 1) are the reuse-first contract every render composes
against. Without them, proto reinvents components that already exist (the exact drift this gate prevents).
Write both (re-run Step 2.4 / GATE 1), then resume at Step 5.
```

**Existence is not correctness — verify the map is RIGHT, not just present.** A reuse-map can exist yet
misclassify already-implemented components as `NEW`, or stub them as a "stand-in" — the exact failure a real
run shipped (`SaasBar`/`LoginScreen` marked NEW though both exist; `PipelineGraph`/`StreamPanel` stubbed). So
also verify, per reuse-map row:
```bash
# (a) every NEW row must be PROVEN ABSENT — grep the real feature dirs for a matching component/surface:
grep -RilE "<component-or-surface-noun>" apps src --include=*.tsx 2>/dev/null | grep -v proto
#     NON-EMPTY ⇒ the component EXISTS ⇒ the NEW row is misclassified ⇒ HARD-STOP (reclassify EXISTING, import it)
# (b) reject any row that says "stand-in" / "faithful MUI representation" / "NOTE" for a component that exists —
#     EXISTING ⇒ imported verbatim, NEVER stubbed.
```
If any `NEW` row resolves to a real component, or any row stubs an existing one, **HARD-STOP** — fix the map
(reclassify EXISTING + import the real path), then re-render. A map **reconstructed from the existing harness**
rather than the real app is the classic cause of this — Step 0.5 forbids it.

This gate runs whenever Step 5 runs — it is **not** a special case for any mode: `--figma-only` and the
**no-UI PRD branch** (GATE 1) never reach Step 5 (they bypass rendering), and `--restart` re-derives the
Manifest (GATE 1) + Reuse Map (Step 2.4) upstream, so both exist by the time Step 5 runs. It **complements,
never duplicates** Step 0.5 (resume ledger — checks these on *resume*), Step 5d (provenance — checks the
render's *content*), and the Coverage Gate (frame *coverage*): it is the one check that the grounding
artifacts **exist at all** on a fresh run.

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
and note the lost chrome in **§Fidelity reductions** of `index.md`.

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
   chrome**, so **append the fidelity reduction to §Fidelity reductions in `index.md`** ("rendered without the app shell").
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
  (The Reuse Map is guaranteed present + non-empty here by the **Step 5 Grounding gate**, so this provenance
  grep can never pass *vacuously* on an absent/empty map — the hole that once shipped reinvented components.
  This bullet checks the render's *content*; the gate guarantees the *contract* exists.)
- **Anchor-coherence check (net-new screens — the "same product" gate):** the provenance grep above proves a
  screen used real *components*; it does NOT prove a NEW screen composes like the rest of the app. For every
  NEW screen with a Step-2.4 `anchor` (not `none`), verify its harness **imports the same app shell as the
  anchor page** and **composes within it** (same header / primary-action placement and sidebar use), rather
  than mounting a bespoke full-page layout. Mechanically: the shell import path must be present, and the
  screen must not introduce its own top-level page chrome (`<header>` / bespoke nav / a full-bleed root that
  bypasses the shell). If a NEW screen renders outside the shell or invents a layout paradigm the anchor
  doesn't use **without a 2.5-recorded 🔶 justification**, **HARD-STOP: "net-new screen diverges from its
  anchor `<page>` — compose within the shell / mirror its scaffold, or record the paradigm change as a 🔶."**
  **Match the import PATH, never the bare component name** — grep for `from '<recorded-path>'` (or the aliased
  form), not `CloneOverlay`/`LiveLog` as a word: the name appears in the harness's own header comment
  ("reuses `LiveLog`…"), so a bare-name grep false-passes on a divergent harness that only *mentions* the
  anchor in prose. Anchor the pattern to a real `import` line (same comment-trap as parsing mixed tool/model
  output — match the structural token, not the word).
  This is the render-time backstop for the "per-task standalone" defect — it catches at capture time what the
  2.4 anchor and 2.5 page-consistency check specify, so the human at Step 7 never has to.
  **A `none` (first-of-shape) screen is exempt from this *mirror* check — there is no sibling to mirror —
  but NOT from coherence:** it must still pass the universal shell/provenance import above (composed in the
  real shell, real tokens, no bespoke page chrome) AND carry the `first-of-shape` flag into `index.md`. The
  coherence it can't get from a sibling comes from the shell + real materials; the flag routes the residual
  look-risk to the Step-7 human. So `none` is never a silent escape from every check — only from the one
  check that needs a sibling that doesn't exist.
- **Serve & verify:** getting a server up is **Step 5.5** (self-run) — it reuses a running one, else boots
  it, triages a failed boot, and records `devserver.json`. Do not restate that logic here. Once 5.5 reports
  READY, smoke-test the route with `curl` (expect HTTP 200, no `Failed to compile`).
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

## Step 5.5 — Bring the app up (self-run)

The capture (6a) renders a **served** route. If nothing is serving, every frame fails the render gate and
the Coverage Gate hard-stops the run — so "the project isn't running" must be something proto **fixes**,
not something it dies on. This step owns the whole server lifecycle: reuse an existing one, else boot it,
triage a failed boot, and tear down only what proto itself started.

### 5.5a. Reuse first — never kill what you didn't start

```bash
lsof -i :"$PORT" -sTCP:LISTEN            # -> pid
lsof -a -p "$PID" -d cwd                 # -> cwd; must equal the project root
```
cwd match **and** `curl` 200 ⇒ **reuse it**, record `owner: human`. A human's server is never killed at
teardown (5.5f) — hot-reload picks up the new preview route, so no boot is needed. This is the single home
of the reuse-detection rule; 5d points here rather than restating it.

Otherwise `owner: proto` and continue to 5.5b.

### 5.5b. Derive the boot command

From the Gate-2 framework + `package.json` scripts (`dev` → `start` → `serve`), with the package manager
read from the lockfile. npm needs `-- ` before flags (`npm run dev -- --host …`); pnpm/yarn forward
directly — the same composition rule 5e states. Bind **`127.0.0.1`** on a free port; add `--strictPort`
for Vite.

Reuse Step 7a's free-port **scan algorithm**, *not* its literal `8999–9100` range — that range is for the
static gallery server. A dev server scans upward from its framework default (3000 / 5173 / …).

### 5.5c. Boot in its OWN process group, logged, recorded

**Spawn mechanism (BLOCKING — 5.5f's teardown depends on it).** Spawn into a **new process group** and
derive `pgid` from the new leader. Use **Node's `detached`** — it is portable, and proto already depends on
Node for the 6a capture:

```js
// __PROTO__ throwaway — boot the dev server in its OWN process group.
import { spawn } from 'node:child_process'; import { openSync } from 'node:fs'
import { execSync } from 'node:child_process'
const out = openSync(`tasks/proto-${SLUG}/devserver.log`, 'a')
const child = spawn(CMD, ARGS, { detached: true, stdio: ['ignore', out, out] })
child.unref()
const pgid = execSync(`ps -o pgid= -p ${child.pid}`).toString().trim()   // the NEW group
```

> **Do NOT use `setsid`** — it is util-linux and **absent on macOS** (`command -v setsid` fails on stock
> Darwin), so the boot would die with "command not found" and burn all 3 strikes on a platform problem
> rather than a project one. Node's `detached: true` is the portable equivalent. A plain `cmd &` from a
> non-interactive shell is also wrong: it does **not** create a new group, it inherits the launching
> shell's — Step 7a's idiom (`( … & )`) is exactly that shape, so copying it verbatim would record *this
> session's own* pgid and 5.5f's group-kill would take down the working shell.

Write `tasks/proto-<slug>/devserver.json` — every field has a named consumer:

```json
{ "url": "http://127.0.0.1:5241", "port": 5241, "pid": 48213, "pgid": 48213,
  "owner": "proto", "cmd": "npm run dev -- --host 127.0.0.1 --port 5241 --strictPort",
  "log": "tasks/proto-<slug>/devserver.log" }
```
`url`→6a · `pid`+`pgid`→5.5f teardown · `owner`→kill rights · `cmd`→identity re-verify + the HARD STOP
re-run line + retry re-derivation · `log`→triage and the stop message.

**Artifact safety (BLOCKING):**
- **Never overwrite an existing `.env`.** Placeholder seeding (5.5e) writes a *new* file only
  (`.env.proto.local`, or the framework's local-override name), created only if absent.
- **Ignore the artifacts via `.git/info/exclude`, NOT the tracked `.gitignore`.** proto runs against
  arbitrary repos; `.git/info/exclude` is local-only and never committed, so ignoring `devserver.json` /
  `devserver.log` / the placeholder env file cannot clobber the user's tracked `.gitignore` or be swept
  into a later `git add -A` in their project. Append-only, dedupe-checked.
- **Scrub `KEY=VALUE`-shaped lines** from any log excerpt printed to console/chat or read back into
  context — dev servers dump resolved config at boot, and a boot that failed for a *non-env* reason may
  still have loaded a real `.env`.
- `devserver.log` is left on disk for inspection (local-only) and removed with the run directory at
  `/saki-builder:build` teardown.

### 5.5d. Wait for ready, then verify the bind

Poll `curl` until HTTP 200 or a **90s** timeout (cold Turbopack/Vite builds are slow). Then **verify the
bind is loopback** — query by **port**, with `-n` for numeric output:

```bash
lsof -nP -i :"$PORT" -sTCP:LISTEN        # must show 127.0.0.1 — never * or 0.0.0.0
```

> Two traps this avoids, both verified on macOS: (1) **`-n` is required** — without it `lsof` resolves the
> address and prints `localhost:PORT`, so a grep for the literal `127.0.0.1` finds nothing and the gate
> false-negatives on every run. (2) **Query by port, not `-p $PID`** — the recorded pid is often the
> `npm`/`pnpm` wrapper, and the listening socket belongs to an unrecorded grandchild, so `-p $PID` returns
> empty and the gate can never pass for npm-run projects.

A `--host` flag is a *request*, not a guarantee: a custom `node server.js` with a hardcoded
`app.listen(port)` ignores it and binds every interface. Since 5c leaves the preview route
**auth-bypassed**, a non-loopback bind would expose an unauthenticated route to the network — which
matters most in the headless/VPS contexts this skill already targets. Treat it as a boot failure (triage;
HARD STOP if the framework offers no host override). **Never proceed to 6a on an unverified bind.**

### 5.5e. Triage ladder

Ordered; each rung detects, fixes, and re-boots once. **Every retry re-derives the full command from
5.5b** — never a partial patch of the prior attempt's string, so the `127.0.0.1` bind can't be silently
dropped. **Each re-boot rewrites `devserver.json` in place**, so the record always reflects the last
attempt.

| Signal in the log | Fix | Strike? |
|---|---|---|
| `Cannot find module` / no `node_modules` | install in **frozen mode** — `npm ci` · `pnpm install --frozen-lockfile` · `yarn install --frozen-lockfile` — bounded by a **300s** timeout | yes |
| `Invalid environment variables` / missing env | seed **non-resolvable placeholders** into a new local-override file (never the real `.env`) | yes |
| `EADDRINUSE` / port busy | next free port from 5.5b's scan | yes |
| type/compile error in `proto-preview/*` | **exits the ladder immediately** — a harness bug, not a boot bug; return to 5d's typecheck | **no** |

Frozen mode is what makes install-script execution trustworthy: a bare `npm install` may resolve *new*
transitive versions when `package.json` and the lockfile disagree, running postinstall scripts nobody vetted.

**Placeholder definition (BLOCKING).** A placeholder must be syntactically valid but point at a
**non-resolvable** target — never copied verbatim from `.env.example`, whose values commonly *do* resolve
locally (`postgresql://postgres:postgres@localhost:5432/app_dev`). A resolvable value silently connects the
preview to a real local datastore — exactly what the "never hit live auth / mock the data layer" rule
forbids. Use a reserved or non-routable host (`.invalid` TLD, `10.255.255.1`) for any key naming a host or URL.

**Genuine handoffs stop on rung one, no strikes burned:** a real secret the app needs to boot, or an
interactive auth prompt. These are human handoffs, never routed around.

**3-strike guard** ⇒ stop with situation + the exact re-run command + where it resumes:

```
5.5 HARD STOP — CANNOT BOOT after 3 attempts.
  Last error: <one-line summary from the log>
  Re-run manually: <the derived cmd>
  Full log: tasks/proto-<slug>/devserver.log (last 20 lines above)
  → Fix the error above, then re-run /saki-builder:proto <prd> — it resumes at Step 5.5.
```

### 5.5f. Teardown by ownership — at Step 8, and on every abnormal exit

**Timing.** Teardown fires at **Step 8**, *after* Step 7.5 has had its chance to re-verify and re-capture
— **not** after 6a. Step 7.5 re-curls the route for the `__PROTO__` sentinel and re-screenshots affected
frames whenever Step 7b's tweak invitation is taken; killing the server at 6a breaks that mainstream path.

**Kill safety (BLOCKING — both guards required before any signal):**

```bash
# 1. Identity — is this still OUR server? Same cwd check 5.5a uses for reuse.
[ "$(lsof -a -p "$PID" -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-)" = "$PROJECT_ROOT" ] \
  || { echo "skip: pid $PID is no longer this project's server"; exit 0; }
# 2. Self-kill guard — never signal our own group.
[ "$PGID" != "$(ps -o pgid= -p $$ | tr -d ' ')" ] || { echo "skip: own process group"; exit 0; }
kill -- -"$PGID"
```
1. **Identity** — a recycled PID may now be an unrelated process. Verify by **cwd**, not by matching the
   recorded `cmd` against `ps -o command=`: npm rewrites its own process title on exec (the `--`
   separator is stripped, so `npm run dev -- --host …` renders as `npm run dev --host …`), which makes a
   literal `cmd` substring match fail for **every npm project** — the server would then never be killed
   and every run would leak an auth-bypassed listener. cwd is stable across that rewrite.
2. **Self-kill guard** — never signal a group that is our own. Identity alone is not sufficient before a
   group-wide kill; this is what makes 5.5c's `detached` spawn enforceable at the call site.

Kill the **process group**, not a bare `kill <pid>`: the recorded pid is often the `npm`/`pnpm` wrapper,
and killing it alone orphans the real vite/next child — the same class as 7a's gotcha #1.

**Abnormal exits.** Teardown is a run-wide trap/finally over **every** exit path after 5.5c succeeds — the
Coverage Gate HARD STOP, the capture's non-zero exit, the ≤3-pass convergence bound, and a human abort.
Otherwise an auth-bypassed listener survives the run. Belt-and-braces: a **fresh** (non-resume) run that
finds a **stale** `owner: proto` record reaps that pid before booting — **using both guards above**, never
a bare kill.

`owner: human` → never killed; log that it was left running.

**Scope note.** This is *proto's own* Step 8, and it tears down the dev-server **process** only. It does
**not** touch the `proto-preview` route or the 5c middleware bypass — those persist for
`/saki-builder:build` to promote and delete. (`/saki-builder:build` has a same-numbered Step 8 that owns
*route* teardown; the two are different objects and must not be collapsed.)

**Studio note.** Step 7a skips serving when `$SAKI_OUT` is set because *its* server would have to outlive
the turn to be useful (a human clicks the URL later) — and under Studio's headless spawn it would die with
the turn, while Studio serves the gallery itself anyway. Step 5.5's server has the opposite requirement:
it only needs to live until Step 7.5 resolves **within the run**, so it backgrounds in **both** terminal
and Studio contexts. Do not "consistency-fix" this into a `$SAKI_OUT`
skip; that breaks capture under Studio.

**Convergence-loop churn.** Each pass of the ≤3-pass convergence loop re-enters render → capture, so the
server may be booted and torn down up to 3 extra times. Self-healing (5.5a is idempotent) — noted so the
repetition isn't read as a bug.

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
- **Neither works:** fall back to the MCP and **append to §Fidelity reductions in `index.md`** that capture was local-only
  (not VPS-reproducible) — never silently skip.

**Order the screens by the user journey** (from the `*-flow.md` Gherkin happy path; else infer from §9) —
this order drives the gallery (6b). For **each screen capture the page frame first** (the Figma overview
shot of the whole composed page in the real shell, 5b#1), then the other **states** (loading / empty /
validation-error / server-error), at **BOTH viewports** — desktop (1280) and mobile (390); `design.md` is
mobile-first, so a desktop-only capture hides the layout the design actually optimizes for. Save
`tasks/proto-<prd-slug>/<slice-n>-<state>-<viewport>.png` (use `<state>=page` for the happy frame).

**One script does both** — screenshots every frame AND measures each journey hotspot (6a-bis) in the same
headless pass, emitting `hotspots.json` for 6b. Write it to `tasks/proto-<prd-slug>/proto-capture.mjs` and
run from the repo root — the URL comes from **Step 5.5's `devserver.json`**, never a guessed port
(`node tasks/proto-<slug>/proto-capture.mjs`; `PROTO_URL` still overrides for manual debugging):

**Template:** `skill://saki-builder-runtime/docs/templates/proto-capture-template.mjs`.

**Transcribe contract (four steps, not a description):**
1. **Read** the template.
2. **Fill in** its `SCREENS` array from THIS run's journey — one entry per screen in `screen-manifest.md`
   order, each screen's `states` mapping state→`?state=` suffix, and its 6a-bis `anchor`. The placeholder
   entries (`slug:'slice1'`, `sel:'[data-testid="primary-cta"]'`) are examples — shipping them unedited
   captures a route that does not exist.
3. **Write** the completed result to `tasks/proto-<slug>/proto-capture.mjs`.
4. **Run** `node tasks/proto-<slug>/proto-capture.mjs` from the repo root. `BASE` comes from Step 5.5's
   `devserver.json`; `PROTO_URL` still overrides for manual debugging.

Never reinvent this script from memory — the `__PROTO__` live-DOM sentinel gate, the `pageerror` hook and
the error-boundary check are the three things that stop a crashed render from being screenshotted, and a
hand-rolled capture silently drops them.

**The capture script HARD-FAILS (non-zero exit + `CAPTURE FAILED`) on any frame that crashed, rendered the
error boundary, or lacked the `__PROTO__` sentinel in the LIVE DOM — a crashed render is NEVER
screenshotted.** So a clean (zero) exit means every attempted frame genuinely rendered; that is the
authoritative render check (not the 5d curl, which only sees SSR HTML and misses a client-side throw). If
it prints `CAPTURE FAILED`, STOP and do not proceed to the gallery: the named frames hit a provider (5a) or
auth (5c) failure — fix and re-run. (This is the exact "error page captured N× as identical frames"
false-green the gate exists to prevent.) For a failed non-page **state** shot (loading/error) you may note
it in **§Fidelity reductions** of `index.md`; a failed **page** (whole-screen) frame is a **Coverage-Gate failure** — fix it and
re-capture, never note-and-skip a screen. Then write `index.md` per the producer spec below.

### index.md (the human review surface)

This is the one artifact a human actually reads at Step 7b, and the record the run leaves behind. It is
**accumulated, not written once** — eight sites across this skill say "note it in `index.md`", and every one
appends to **§Fidelity reductions** below. Write it with exactly these sections:

```markdown
# Preview — <prd-slug>
**Owner:** <@name | unassigned> · **Status:** Awaiting review | Approved · **Updated:** <YYYY-MM-DD>
**PRD @** <path>@<git sha>          ← version pin: which PRD revision this gallery reflects

## Journey overview
<the journey-ordered page frames, desktop + mobile, in the order the user walks them>

## Fidelity reductions
<one line per reduction — an EMPTY list is a valid, meaningful result. Never omit the section.>
- App shell: not composed (env-locked auth provider) — bare harness used [5b#2]
- Capture:   MCP local-only, not VPS-reproducible [6a]
- State:     `slice3/loading` frame failed, noted not captured [6a]
- Hotspot:   `slice2 → slice3` anchor not measurable [6a-bis]
- Figma:     skipped — seat is read-only [6c]

## Decision log
<link `prd-adjustments.md` (Convergence-loop changes) + any 🔶 design decision and its rationale>
```

**§Fidelity reductions is the honesty contract.** Anything the run could not do faithfully lands there as
one line with its owning step in brackets — never dropped silently, never buried in prose. A *screen* that
failed to capture is NOT a fidelity reduction; that is a Coverage-Gate HARD STOP.

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

**Template:** `skill://saki-builder-runtime/docs/templates/proto-gallery-template.html` — the full gallery markup lives there,
not inline, so this skill doesn't carry ~100 lines of HTML into every run.

**Transcribe contract (not a description — do these four things):**
1. **Read** `skill://saki-builder-runtime/docs/templates/proto-gallery-template.html`.
2. **Fill in** its `SCREENS` array from 6a (PNG filenames per state × viewport) + 6a-bis (hotspot rects,
   as percentages). The array is the only part you change; the surrounding logic does not change.
3. **Write** the completed result to `tasks/proto-<slug>/preview.html`.
4. Keep `img src` **relative** (sibling PNG filenames) — never absolute, never `localhost:PORT`, never
   base64 (base64 belongs only in the 6b-bis shareable bundle).

Never reinvent this markup from memory: the state/viewport toggles and the hotspot overlay geometry are
load-bearing, and a hand-rolled gallery silently loses the click-through Flow that makes it Figma-like.

Use **relative** `<img src>` (the bare PNG filename) so the Studio resolves each as a sibling —
`resolveProtoAsset` serves `tasks/proto-<slug>/<file>.png`. No base64, no absolute/`localhost:PORT` paths.

The header's **⬇ Shareable file** CTA (`<a href="preview-bundle.html" download>`) links to the sibling
single-file bundle (6b-bis) so a reviewer can grab the one-file copy straight from the gallery. It downloads
wherever the gallery dir is served as files — `file://` and the Step 7a local static server both serve every
sibling — and 6b-bis **strips this CTA from the bundle itself** (the bundle IS the download; a self-link
there would dangle when shared alone). The bundle must exist for the click to resolve, so the CTA is a no-op
until 6b-bis has run.

#### Verify

```bash
grep -c 'title:' tasks/proto-<slug>/preview.html   # = screen count (one SCREENS entry per journey frame)
grep -c 'page:'  tasks/proto-<slug>/preview.html   # >= screen count (every screen has a page frame)
# This screen count MUST equal the Screen Manifest count (GATE 1) — the Coverage Gate below enforces it.
```
Open it (`file://`) and confirm: **Flow** advances on hotspot click, **Overview** shows the journey with
arrows, the **viewport** toggle swaps frames, **state** toggles flip per-screen states. If a frame or
hotspot is missing, append it to **§Fidelity reductions** in `index.md` — never drop silently.

**Note:** the gallery is interactive as a **Figma-style frame-to-frame flow** (click-through between
captured frames + state/viewport toggles). It does NOT run live behavior (validation, API calls, real
state) — that remains `/saki-builder:build`'s work.

### 6b-bis. Single-file shareable bundle (`preview-bundle.html`)

`preview.html` embeds its frames by **relative** `<img src>` (a bare PNG filename), so it only renders next
to its sibling PNGs — Pipeline Studio serves the two together, but the file **can't be shared alone**
(emailing/dropping just `preview.html` shows broken images). Produce an **additive** companion that inlines
every screenshot as a `data:image/png;base64,…` URI — **one self-contained `.html` file** anyone can open by
double-click, attach to Slack/email, or drop in a drive, with **no folder and no server**. It is a twin of
the gallery (same Flow / Overview / state + viewport toggles), not a replacement: `preview.html` stays the
canonical artifact Studio opens and `/saki-builder:build` reads; the bundle is only the shareable copy.

Generate it mechanically from the finished `preview.html` + the captured PNGs — write
`tasks/proto-<prd-slug>/proto-bundle.mjs` and run it from the repo root
(`node tasks/proto-<slug>/proto-bundle.mjs`). It swaps each quoted PNG filename in the `SCREENS` array for
its base64 data URI, changing **only** the image sources — the gallery logic is untouched:

```js
// __PROTO__ throwaway — bundle preview.html + sibling PNGs into ONE self-contained, shareable file.
// preview.html stays relative-src (Studio serves it + siblings); THIS is the portable twin you can send.
// Deleted at /saki-builder:build teardown. Run from repo root: node tasks/proto-<slug>/proto-bundle.mjs
import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const DIR = dirname(fileURLToPath(import.meta.url))                 // = tasks/proto-<slug>/
const SRC = join(DIR, 'preview.html'), OUT = join(DIR, 'preview-bundle.html')

let html = readFileSync(SRC, 'utf8')
const pngs = readdirSync(DIR).filter(f => f.endsWith('.png'))
if (!pngs.length) { console.error('BUNDLE FAILED — no PNGs in ' + DIR + ' (run the 6a capture first)'); process.exit(1) }

let inlined = 0
for (const png of pngs) {
  const uri = 'data:image/png;base64,' + readFileSync(join(DIR, png)).toString('base64')
  for (const q of ['"', "'"]) {                                    // match the filename WITH its quotes — a unique token, so replace-all is safe
    const needle = q + png + q
    if (html.includes(needle)) { html = html.split(needle).join(q + uri + q); inlined++ }
  }
}
html = html.replace('<title>Proto — ', '<title>Proto (shareable) — ')
html = html.replace(/\s*<a class="dl" id="dl"[^>]*>[^<]*<\/a>/, '')  // the bundle IS the shareable file — drop its own "download" CTA (a self-link dangles when shared alone)

const left = html.match(/['"][\w./-]*\.png['"]/g) || []            // a referenced frame with no PNG on disk = a noted-omitted state (Step 3), not a page frame
if (left.length) console.error('BUNDLE WARNING — ' + left.length + ' frame ref(s) left relative (missing PNG):\n' + left.join('\n'))

writeFileSync(OUT, html)
console.log(`bundled ${inlined} image ref(s) → preview-bundle.html (${(statSync(OUT).size/1048576).toFixed(1)} MB · one self-contained file, no siblings needed)`)
```

**Verify it truly stands alone** — copy just the one file elsewhere and open it:
```bash
S=tasks/proto-<slug>
grep -c 'data:image/png;base64' "$S/preview-bundle.html"   # > 0 — screenshots are inlined
cp "$S/preview-bundle.html" /tmp/proto-share-check.html && echo "open /tmp/proto-share-check.html — every frame must still render with NO sibling PNGs present"
```
The Coverage Gate guarantees every *page* frame exists at both viewports, so those always inline; only a
deliberately-omitted non-page *state* (Step 3) can stay a relative ref (the WARNING lists it) — acceptable,
since the page frames carry the journey. **Re-run `proto-bundle.mjs` after any Step 7.5 re-capture** so the
shared file reflects the final, approved gallery (a one-command, idempotent rebuild). Size note: base64 adds
~⅓ over the raw PNGs, so a large journey bundles to a few MB — fine for email/Slack; if a recipient balks at
the size, send the folder (or a zip of `tasks/proto-<slug>/`) instead.

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
reduction to §Fidelity reductions in `index.md`** ("Figma export skipped — seat is read-only; use an editor/dev seat to export")
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
   via the browser MCP tool **`mcp__claude-in-chrome__javascript_tool`** (use that exact, fully-qualified
   name — it does not belong to Playwright, and the unprefixed short form does not resolve), or temporarily
   add the `<script src=…capture.js>` tag (throwaway,
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
reduction to **§Fidelity reductions** in `index.md` rather than dropping silently. Record the Figma file URL and which tier you
produced; surface both in the Completion Output.

---

## Step 6.5 — Part F tell-check on the rendered output (BLOCKING fidelity gate)

GATE 2 grades *tokens* and Step 2.6 grades *components* — neither can see slop that emerges only
when real components are **composed into a screen**: a gradient hero, emoji-as-icons, an equal-weight
card grid with no hierarchy, everything centered, generic filler copy, or a palette that drifted onto
an AI-default look. Those are **rendered-level tells** (Design System Contract Part F), invisible to a
token check. This is the enforcement that catches them on the **captured screenshots** — *before* the
human sees them in Step 7, so the human reviews design intent, not slop the skill should have caught.

**Run on every PNG captured in Step 6a.** Grade each screenshot against two keys:

1. **The Part F tell-list** (color + composition) — cream+serif+terracotta · near-black+acid ·
   broadsheet-hairline+zero-radius · gradient hero · emoji-as-icons · equal-weight grid / no
   hierarchy · everything-centered · lorem/generic copy. A hit is a **fidelity defect**, not a taste
   quibble.
2. **The pinned DIRECTIONAL REFERENCE** (`design.md` Part A) — the reference-judge question:
   *"Given the reference = <design.md DIRECTIONAL REFERENCE>, does this screen read as **that**, or as
   the mean any app would produce?"* The reference is the grading key — never a fixed checklist alone
   (a checklist passes costume-slop; only the reference catches the tasteful-but-generic drift).

**Legitimacy escape (Part F's own rule):** a tell is a defect only when it's a *default drift*. If the
pinned DIRECTIONAL REFERENCE genuinely asks for it (a neon-signage product truly is near-black+acid),
it passes — cite the reference line that licenses it.

**Verdict + routing (BLOCKING):**
- **CLEAN** (no tell, or every tell licensed by the reference) → proceed to Step 7.
- **TELL FOUND** → fix at its source (color-level → re-token via Step 2.6; layout/copy-level →
  re-compose in the Step 5 harness), **re-capture that screen (Step 6a)**, and re-run this gate. Never
  present a screen carrying an unlicensed tell to the human.

Under `/saki-builder:build` (autonomous) this routes and re-runs like proto's other fidelity gates; in
a manual run, surface the per-screen tell + one-line fix. Step 7's human review is for *journey +
design intent* — never for catching slop this gate exists to stop.

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
> 2. "Now that you're seeing the real components rendered, do you want to revise any of them? (The specs
>    were auto-applied in Step 2.5 using existing conventions, and Step 2.6 already built them as real
>    design-system components — a change now is a tweak to the real component, applied in Step 7.5.)"

Iterate on **look and components only** (component choice, layout, copy, spacing, states shown, token
names, variant naming). If the user wants behavior changes, that is a PRD/rplan concern, not proto — say so
and point back. If the user wants a *big* structural change the existing design can't hold, that is a 🔶
(Step 2.5 rules): design-only → decide it here with the same senior-designer rigor, apply it in Step 7.5, and
re-screenshot; scope-altering (new features/screens) → route back to `/saki-builder:prd`, never invent it here.

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
  with the `__PROTO__` sentinel — and re-screenshot only the affected frames. Then **re-run
  `proto-bundle.mjs`** (6b-bis) so `preview-bundle.html` reflects the re-captured frames — a one-command,
  idempotent rebuild.

`/saki-builder:build` then promotes these real presentational components (mock data → real data + state + tests +
backend wiring); it does NOT re-invent them. Write that as a hard dependency in the handoff notes (Step 8):
"Design system was updated per `design-system-updates.md` (built in Step 2.6, finalized in 7.5). `/saki-builder:build`
MUST use these real components — do NOT re-invent them."

---

## Step 8 — Handoff to `/saki-builder:build`

Write `tasks/proto-<slug>/notes.md` capturing, per screen: the **real components chosen**,
the **token references** used, and the **states** confirmed. Purpose: `/saki-builder:build` **promotes** these
presentational components (mock data → real data + state + tests + backend wiring) instead of
re-picking from scratch.

State the **cleanup contract** explicitly. The **static gallery — `preview.html` + `preview-bundle.html` + the PNGs +
`index.md`** — is the deliverable that persists as the record; **Pipeline Studio opens `preview.html`**
(read-only, via `/api/proto/...`), while `preview-bundle.html` is the single-file copy you share (6b-bis).
It persists as the record regardless. The throwaway `proto-preview/*` route (incl. the
`/proto-preview` index) and the Step 5c middleware bypass also **persist after the proto run** — but
only because they are the **capture harness** and `/saki-builder:build`'s promotion source, **NOT** because the
Studio serves them live (it no longer does; it opens the static gallery). So the proto run must NOT
delete them, and must NOT run on a throwaway git branch that is then deleted. They remain throwaway
w.r.t. **`/saki-builder:build`**, the **sole owner of teardown**: it promotes the presentational components into
real routes, then deletes the `proto-preview/*` namespace and reverts the bypass. Until `/saki-builder:build`
runs they live in the working tree (uncommitted is fine). The `preview.json` manifest (5e), if you
wrote one, is ignored by the current Studio and is removed with the namespace at teardown.

**Dev-server teardown (Step 5.5f) fires here** — after Step 7.5 has had its chance to re-verify and
re-capture. Kill only what proto started: `owner: proto` in `tasks/proto-<slug>/devserver.json` ⇒ verify
identity + the self-kill guard, then `kill -- -<pgid>`; `owner: human` ⇒ leave it running and say so. The
run's server artifacts — `devserver.json` and `devserver.log` — are local-only (ignored via
`.git/info/exclude`, never the tracked `.gitignore`) and are removed with the run directory at
`/saki-builder:build` teardown. This tears down the **process** only: the `proto-preview` route and the 5c
bypass persist exactly as described above.

---

## Coverage Gate (BLOCKING — every manifested screen is captured, no negotiation)

Before the Completion Output, hard-verify the run covered the WHOLE journey. This gate is the reason
"covers all screens" is true rather than aspirational — it is not optional, and it is NOT satisfied by
"the important screens." A no-arg run passes this gate only at 100% coverage.
(The manifest's *existence* is already assured upstream by the **Step 5 Grounding gate**; this gate verifies
*coverage* — every manifested screen has a captured, distinct frame — not existence, so the two never duplicate.)

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

**Both recoveries need a live server.** If Step 8's teardown (5.5f) already ran, re-enter **5.5a** first —
reuse-or-reboot — before re-rendering or re-running the 6a capture. Re-capturing against a torn-down server
just reproduces the failure.

**Screens are all-or-fail; only states are individual.** A genuinely-unreachable *state* (loading/error)
on a *present* screen may still be noted-and-omitted per Step 3. A missing *screen* is never acceptable —
fix it and re-capture. `--slice=N` is the only way the manifest may be smaller than the full journey, and
that run is stamped `PARTIAL` everywhere so it can never be mistaken for full coverage.

---

## Step 8.5 — Lock the approval (the explicit freeze before `/saki-builder:build`)

This is the **terminal act of the PRD phase**: with the UI/UX approved (Step 7) and the journey fully
captured (Coverage Gate passed), **freeze the requirements** so `/saki-builder:build` — which hard-refuses an
unlocked PRD — can proceed to `/saki-builder:rplan`. `/saki-builder:proto` is the **single lock writer**: a UI PRD
locks here after approval; a no-UI PRD (GATE 1 branch) jumps straight here on the human's confirmation.
Do **not** lock a `PARTIAL` (`--slice=N`) run — a partial preview hasn't approved the whole journey; print
`Not locking — PARTIAL run (--slice). Re-run /saki-builder:proto with no --slice to lock.` and skip this step.

Write the approval into the gallery **always**, and into the PRD file **when it exists** (two artifacts in PRD-first order, one in proto-first). `<@approver>` = the PRD header `Owner` if set, else
`@<git config user.name>`, else `unassigned`; `<YYYY-MM-DD>` = `date +%F`. Never emit either before the
human has approved (Step 7 / the no-UI confirm) — the marker IS the approval record.

1. **Gallery marker (always)** — write `tasks/proto-<slug>/.prd-locked` containing one line:
   `<@approver> · <YYYY-MM-DD> · prd:prd-<slug>.md · ui:tasks/proto-<slug>/`  (`ui:none` for a no-UI PRD).
   The `prd:` field names the PRD this approval froze. GATE 1.5 verifies it against the PRD it was
   handed, so one gallery's approval can never be inherited by a different file that happens to derive
   the same slug.
   This is the artifact that exists in **both** pipeline orders. The gallery is proto's own output, so it
   is always present at Step 8.5 — whereas the PRD file is only guaranteed in PRD-first order.
2. **Header marker (when the PRD file exists)** — add, in the PRD's top comment block, on its own line:
   `<!-- prd-locked: <@approver> · <YYYY-MM-DD> · ui:tasks/proto-<slug>/ -->`  (`ui:none` for a no-UI PRD).
   Skip this and items 3–4 if there is no PRD file yet (a proto-before-PRD run) — the gallery marker
   already records the approval, and `/saki-builder:build` GATE 1.5 accepts either. Do **not** create a
   PRD here; writing requirements is `/saki-builder:prd`'s job.
3. **Header Status** — set the header field to `**Status:** Locked`.
4. **§15 reference** — in §15 Screens & UI Reference, append `**UI approved:** tasks/proto-<slug>/ · <date>`
   so the locked artifact points at this approved gallery. If §15 is absent on a UI PRD (an older PRD that
   didn't persist its screens), create it from the Screen Manifest first. Skip item 4 for a no-UI PRD.

Then announce it plainly:
```
🔒 APPROVAL LOCKED — requirements frozen (tasks/proto-<slug>/.prd-locked · Status: Locked · ui:tasks/proto-<slug>/).
   /saki-builder:build tasks/prd-<slug>.md can now proceed (it refuses an unlocked PRD).
```
The lock is `/saki-builder:proto`'s only write-back into the PRD — it **never** edits scope, criteria, or rules
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
  🔶 Design change (P)  →  [auto-decided & applied (senior-designer rationale in design-system-updates.md) | reconciled via Convergence loop → see prd-adjustments.md | none]

PRD adjusted this run: tasks/proto-<slug>/prd-adjustments.md  (Convergence-loop changes /saki-builder:prd made to close coverage gaps — review at approval; or "none — PRD covered the whole journey")
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
Shareable bundle: tasks/proto-<slug>/preview-bundle.html  (single self-contained file — every screenshot inlined; send as one attachment, no folder needed)
Handoff notes: tasks/proto-<slug>/notes.md
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
> Share tasks/proto-<slug>/preview-bundle.html — one self-contained file (screenshots inlined; no sibling folder needed)
> Review tasks/proto-<slug>/index.md and confirm the look
> /saki-builder:build tasks/<prd-file>  (the PRD is now 🔒 Locked — build proceeds; promotes these components into real implementation, design system already updated)
```
(The static `preview.html` is what the Studio opens — no marker line is needed. The `preview.json`
manifest of 5e is optional/legacy and ignored by the current Studio; only mention it if you wrote one.)

---

## Invariants

The Steps above are the single normative home for every gate — each invariant below is a one-line
reject-on-sight cue naming the Step that owns it. Rationale and the observed failure behind each gate live
in `skill://saki-builder-runtime/docs/proto-incidents.md` (read on demand, not loaded every run).

- **Preview, not build** — no backend, real data, state logic, tests, or prod routes (Intro · Step 5).
- **PRD is the source of truth; never re-elicit scope** — journey from §8, states from §9/§10, boundaries from §11 (GATE 1).
- **Never curate the journey** — every user-visible step and every reachable state, entry→success; `--slice` is explicit, never the default (GATE 1 · Step 3).
- **Never freeze a manifest you derived mechanically** — interrogate the PRD for implied screens first; the Coverage Gate is blind to a screen you never listed (GATE 1).
- **Never fabricate a design system** — no components + tokens ⇒ STOP and offer scaffold/mock/skip (GATE 2).
- **Never redesign what is already implemented** — inventory it, import it verbatim, prove it with the provenance grep (Step 2.4 · Step 5d).
- **Never render without grounding** — missing or wrong `reuse-map.md`/`screen-manifest.md` ⇒ HARD STOP; on resume re-derive from the real app, never from the harness (Step 5 gate · Step 0.5 pt 7).
- **Never send an implemented component to gap analysis as NEW** — a `NEW` row is a claim of absence, proven by an empty grep (Step 2.4 Guard).
- **Climb the cost ladder, then codify before rendering** — reuse ✅ < scale ⚠️ < add ❌ < propose 🔶, adding only what the screen forces; a confirmed addition is built for real *before* the render, never approximated (Step 2.5 · Step 2.6).
- **Never pause mid-run on a coverage gap** — delegate to `/saki-builder:prd`, re-derive, loop **≤3 passes**; the human gate is the finished VISUAL at Step 7 (Convergence loop · Step 7b).
- **Never boot real auth or a DB to render a preview** — mock session/locale/data-layer (Step 5a).
- **Never let a preview route reach production** — `proto-preview` namespace + `__PROTO__` banner + the cleanup contract (Step 5d · Step 8).
- **Never abort because the app isn't running** — Step 5.5 reuses or boots it, triages the failure, and verifies the bind is loopback (Step 5.5).
- **Never trust a `curl` 200 as the render check** — it sees SSR HTML; the authoritative gate is the `__PROTO__` sentinel in the **LIVE DOM**, plus no `pageerror`/error boundary (Step 5d · Step 6a).
- **Never screenshot a crashed render, and never ship duplicate frames** — a missing sentinel fails the frame; **byte-identical** page frames fail the Coverage Gate. Presence is not correctness (Step 6a · Coverage Gate).
- **Never capture one viewport** — **BOTH** desktop (1280) and mobile (390); `design.md` is mobile-first (Step 6a).
- **Figma export is additive and honest** — only when the MCP is connected, always state the tier, never the canonical deliverable (Step 6c).
- **Proto is the single lock writer** — it stamps the freeze marker + §15 UI reference only, never scope; never locks a `--slice` PARTIAL run (Step 8.5).

## Script

```bash
#!/bin/bash
mkdir -p tasks
```
