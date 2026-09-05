---
name: design-audit
description: Audit an existing web interface against its real users, brand, design system, accessibility, and anti-slop standards; capture an immutable rendered baseline; then produce a constrained visual treatment and machine-readable handoff for /saki-builder:proto to render as a traceable before/after comparison.
model_requirement: frontier
---

# Design Audit: Evidence to Before/After

Usage:

```text
/saki-builder:design-audit <route-or-scope> [--preserve|--overhaul] [--prd=<E<n>|F<n>|prd-file.md>]
  [--auth=auto|browser|project-mock] [--restart]
```

Examples:

```text
/saki-builder:design-audit /pricing --preserve --prd=tasks/prd-pricing.md
/saki-builder:design-audit "onboarding journey" --overhaul --prd=F7
```

Produce a **rendered baseline, evidence-backed critique, bounded treatment, and proto handoff**. Do not
modify application source. The result must let a reviewer compare the same screen at the same viewport
before and after `/saki-builder:proto` renders the proposed treatment. Existing authentication is a
rendering prerequisite, not a reason to replace the UI with a login redirect.

This skill diagnoses visual and interaction quality. It does not implement the redesign, change product
behavior, invent PRD scope, or claim that visual preference proves a user or business outcome. `--auth=auto`
is the default: prefer a safe existing browser session, then a project-documented local mock/development-
auth seam. `--auth=browser` requires the former; `--auth=project-mock` requires the latter. Never persist
cookies, bearer tokens, passwords, or real user identifiers in audit artifacts.

## Core boundary

```text
shipped application
  → immutable baseline capture
  → contextual audit
  → preservation-bounded treatment
  → proto-handoff.json + proto-handoff.md
  → /saki-builder:proto <prd> --audit=<audit-dir>
  → comparison.html
```

- **This skill owns:** current-state evidence, finding severity, design treatment, preservation constraints,
  baseline screenshots, and the audit-to-proto contract.
- **`/saki-builder:proto` owns:** PRD coverage, real-shell composition, component codification, proposed-state
  screenshots, visual approval, comparison rendering, and the PRD lock.
- **The PRD owns:** screens, behavior, business rules, acceptance criteria, and non-goals.
- **`/saki-builder:build` owns:** production routes, real data/state, behavior, tests, and teardown of the
  proto harness.

When these disagree, the PRD wins on scope and behavior; the audit may only constrain presentation.

---

## Step 0 — Resolve input and artifact directory

1. Parse the route/scope, redesign mode, optional PRD, `--auth` mode, and `--restart`.
2. Default to `--preserve` and `--auth=auto`. Use `--overhaul` only when explicitly supplied.
3. Derive a filesystem-safe `<slug>` from the scope and write only under:

```text
tasks/design-audit-<slug>/
```

4. If the directory exists and `--restart` is absent, resume from the first missing or invalid artifact.
   Preserve an existing baseline PNG only when `baseline-source.json` exists and still matches the current
   source identity, capture settings, and auth contract. An orphan or unbound PNG is stale and requires
   `--restart`.
5. If `--restart` is present, replace only this skill's artifact directory. Never delete or edit application
   files.
6. Resolve `--prd` exactly as `/saki-builder:proto` does. Record its path when available; do not create or
   edit a PRD here.

Expected artifacts:

```text
tasks/design-audit-<slug>/
├── baseline/
│   ├── <screen-key>-<capture-state>-desktop.png
│   └── <screen-key>-<capture-state>-mobile.png
├── baseline-source.json
├── screen-manifest.md
├── baseline.json
├── audit.md
├── treatment.md
├── proto-handoff.json
└── proto-handoff.md
```

---

## GATE 1 — Render the real application

A visual audit requires rendered evidence. Source inspection alone cannot establish hierarchy, clipping,
contrast in context, responsive composition, or whether a page looks formulaic.

1. Detect the project's normal start command from its package/config files and existing documentation.
2. Reuse an already-running verified server or start the real application with the repository's command.
3. Use the host's browser capability when available. Otherwise use the project's installed Playwright. Probe
   before claiming neither is available.
4. Open the requested route/scope. Verify the expected app shell and target content are visible.
5. Fail on uncaught page errors, framework error boundaries, failed primary resources, or a login/error page
   captured in place of the requested authenticated screen.
6. Resolve authentication before capture when the requested screen is protected:
   - `browser-session`: use the host browser's already-authenticated session; never export its cookies or
     tokens. Record only the redacted principal role/label needed to reproduce the visual state.
   - `project-mock`: use the project's documented local development/mock-auth seam (mock provider, demo
     principal, test identity, or dev-only session mode). Do not invent credentials, seed production data,
     or weaken real auth middleware. Record the seam and invocation without secrets.
   - `public`: use no authenticated principal for a genuinely public screen.
   If neither a safe browser session nor a documented project seam exists, mark the protected screen
   `BLOCKED` with `authRequired: true`; do not capture the login redirect as its baseline and do not claim
   the protected UI was audited.
7. Write the resolved auth contract into `baseline-source.json`, `baseline.json`, and the proto handoff:
   mode (`public`, `browser-session`, `project-mock`, or `blocked`), principal role/label, session state,
   provider boundary, and whether production auth itself was exercised. Persist no secret or cookie.

If no requested screen can be rendered, stop:

```text
HARD STOP — DESIGN AUDIT HAS NO RENDERED BASELINE
A source-only critique cannot prove visual quality. Resolve the named server/session/render blocker, then rerun.
```

An authenticated screen with a safe resolved contract is renderable even when its auth provider is mocked;
the audit must label that baseline as `project-mock` and proto must use the same principal/role for its
after-state. A `blocked` auth screen keeps the audit `partial` and cannot produce a READY handoff.

Inventory exactly the requested scope, not the whole product unless the user requested the whole product.
Walk the rendered shell and route only far enough to identify the screens and states inside that scope.

Assign each comparable screen a stable key matching:

```text
[a-z0-9][a-z0-9-]*
```

Write `screen-manifest.md`:

```markdown
# Design Audit Screen Manifest — <slug>
**Scope:** <route or journey>
**Mode:** preserve | overhaul
**PRD:** <path | none>
**Status:** Frozen

1. [key:pricing-overview] Pricing overview — `/pricing` — default
2. [key:pricing-validation] Pricing validation — `/pricing` — validation-error
```

Rules:

- One key represents one logical proto screen. `state` names the baseline state chosen for comparison and
  `captureState` maps `default`/`happy` to `page`; otherwise it matches the normalized state.
- Keys are unique and stable across baseline, handoff, and proto.
- A journey includes its in-scope loading, empty, validation, server-error, and permission states in the
  findings when safely reachable. If multiple states need separate visual comparison, use separate keys only
  when the PRD/proto manifest treats them as separate user-visible screens; otherwise compare the highest-risk
  state and list the others as required proto states.
- Never mutate real customer or production data merely to force a state.
- A blocked screen remains listed with its blocker but is excluded from a READY handoff. The final report must
  say the audit is partial.
- Do not add a destination merely because the shell advertises it; audit only the requested scope.

---

## Step 3 — Capture the immutable baseline

Capture every unblocked manifested key at both exact viewports:

```text
desktop: 1280 × 832
mobile:   390 × 844
```

Filename contract. `<capture-state>` is `page` for `default`/`happy`; otherwise it is the normalized
state name (`loading`, `empty`, `validation-error`, `server-error`, or `permission`):

```text
baseline/<screen-key>-<capture-state>-desktop.png
baseline/<screen-key>-<capture-state>-mobile.png
```
Before writing the first PNG, atomically write `baseline-source.json`:

```json
{
  "schema": 1,
  "source": {
    "scope": "/pricing",
    "revision": {
      "head": "<git-head-sha>",
      "worktreeSha256": "<sha256-of-dirty-paths-and-bytes>"
    }
  },
  "auth": {
    "mode": "project-mock",
    "required": true,
    "principal": { "role": "operator", "label": "demo operator" },
    "sessionState": "authenticated",
    "providerBoundary": "auth/session provider",
    "productionAuthExercised": false
  },
  "capture": {
    "viewports": {
      "desktop": { "width": 1280, "height": 832 },
      "mobile": { "width": 390, "height": 844 }
    },
    "zoom": 1,
    "colorScheme": "light",
    "locale": "<locale>",
    "reducedMotion": "reduce"
  }
}
```

Record `revision.head` plus a deterministic SHA-256 over the sorted dirty/staged/deleted/untracked path list.
Hash each entry as UTF-8 repository-relative path + NUL + file mode/deletion marker + NUL + byte length + NUL
+ file bytes. Exclude `.git`, dependencies, build/cache output, and this audit artifact directory. A clean
tree hashes the empty sequence. On resume, recompute the revision and require the capture object to match
before trusting any PNG. A missing/mismatched source record with existing PNGs hard-stops and requires
`--restart`; never stamp current provenance onto orphan frames.


Before each capture:

- navigate through the real flow or load the exact route/state;
- wait for fonts and the screen's meaningful ready condition, not an arbitrary sleep;
- verify no horizontal overflow at mobile;
- verify the page is not an error boundary;
- keep viewport, zoom, color scheme, locale, and reduced-motion setting stable across the run.

Never recapture a valid baseline after treatment work begins. If the shipped application changes underneath
an active audit, mark the audit stale and restart it; a mixed baseline is not evidence.

Write `baseline.json` as strict JSON:

```json
{
  "schema": 1,
  "slug": "pricing",
  "capturedAt": "YYYY-MM-DDTHH:mm:ssZ",
  "source": {
    "scope": "/pricing",
    "revision": {
      "head": "<git-head-sha>",
      "worktreeSha256": "<sha256-of-dirty-paths-and-bytes>"
    },
    "url": "http://127.0.0.1:<port>/pricing"
  },
  "auth": {
    "mode": "project-mock",
    "required": true,
    "principal": { "role": "operator", "label": "demo operator" },
    "sessionState": "authenticated",
    "providerBoundary": "auth/session provider",
    "productionAuthExercised": false
  },
  "viewports": {
    "desktop": { "width": 1280, "height": 832 },
    "mobile": { "width": 390, "height": 844 }
  },
  "screens": [
    {
      "key": "pricing-overview",
      "title": "Pricing overview",
      "route": "/pricing",
      "state": "default",
      "captureState": "page",
      "baseline": {
        "desktop": "baseline/pricing-overview-page-desktop.png",
        "mobile": "baseline/pricing-overview-page-mobile.png"
      }
    }
  ]
}
```

Validate every referenced file exists, is a PNG, has the declared dimensions, and stays inside the audit
artifact directory. Absolute paths and `..` segments are forbidden. `baseline.json.source.revision` and
viewports must exactly match `baseline-source.json`; `baseline.json` completes the pre-capture provenance
record rather than replacing it. Recompute HEAD and the documented fingerprint on resume; any difference
marks the baseline stale and requires `--restart`. The literal `working-tree` is not a source identity.

---

## Step 4 — Route the audit profile

Classify every manifested screen before applying taste rules:

| Profile | Examples | Required rubric |
|---|---|---|
| `marketing` | landing, portfolio, campaign, editorial, public pricing | This skill's rendered hierarchy, brand, content, accessibility, responsiveness, and anti-default criteria; optionally read an installed `design-taste-frontend` skill for additional contextual checks |
| `product` | dashboard, settings, table, CRUD, checkout, wizard | This skill's rendered task, state, density, design-system, accessibility, responsiveness, and anti-default criteria; optionally read installed `auditing-interface-quality` and `reviewing-frontend-aesthetics` rubric skills |
| `mixed` | marketing shell plus authenticated product journey | Partition screens and apply each profile only to its matching surface |

Optional rubric skills provide criteria only. Do not inherit their output paths, phase completion signals,
source-only fallbacks, or implementation behavior. This skill's artifact directory, rendered-evidence gate,
and completion output remain authoritative. Absence of an optional rubric never blocks the built-in audit.

If `design-taste-frontend` is installed, its own scope still excludes dashboards and multi-step product UI.
Never apply landing-page composition preferences to dense product screens. Shared accessibility, token,
responsive, content, and anti-default checks in this skill always apply.

Declare one design read in `audit.md`:

```text
Reading this as: <surface> for <audience>, in <usage context>, preserving/overhauling <what>, grounded in <project design reference or shipped pattern>.
```

For marketing screens, record `DESIGN_VARIANCE`, `MOTION_INTENSITY`, and `VISUAL_DENSITY`. For product
screens, record task density, error cost, device context, and the actual design system instead of forcing
marketing dials.

---

## Step 5 — Audit from rendered evidence

Review each baseline frame and the corresponding rendered interaction. Inspect source only to verify component,
token, semantic, responsive, and performance causes behind something visible.

Audit these dimensions:

1. Task and information hierarchy
2. Brand and directional-reference coherence
3. Typography and reading measure
4. Layout, spacing rhythm, density, and responsive transformation
5. Color roles, contrast, and theme consistency
6. Component consistency and design-system reuse
7. Affordance, hover, focus, active, disabled, and loading feedback
8. Empty, validation, server-error, and permission recovery
9. Keyboard navigation, semantics, labels, alt text, and touch targets
10. Motion purpose, reduced motion, stability, and visual performance
11. Content specificity, voice, realistic data, and action clarity
12. AI-default composition tells not justified by the product's own-world reference

A pattern is not a finding merely because it appears on an anti-slop list. Cite the product-specific reason it
fails here. A centered hero, purple accent, serif, card grid, or glass surface is legitimate when the brand,
content, task, or directional reference supports it.

Do not assign a universal taste score. It creates false precision and rewards checkbox gaming. Use:

- `BLOCKING`: unusable, inaccessible, broken, misleading, or prevents faithful proto handoff
- `MAJOR`: materially harms comprehension, trust, task completion, or responsive use
- `MODERATE`: visible inconsistency, weak hierarchy, or unjustified generic pattern
- `MINOR`: polish with bounded user effect

Every finding in `audit.md` must use this schema:

```markdown
### DA-001 — Recommended plan has no visual priority
- **Screen:** `pricing-overview`
- **Region:** plan comparison
- **Severity:** MAJOR
- **Category:** hierarchy
- **Evidence:** all plans use equal size, contrast, elevation, and CTA treatment in both baseline viewports
- **User effect:** scanning does not reveal the intended default decision
- **Preserve:** plan names, prices, feature content, route behavior, and analytics identifiers
- **Treatment:** create one recommended emphasis variant using the existing accent and type scale
- **Proto acceptance:** a first scan reveals one recommended plan without hiding alternatives
- **Source anchor:** `<component-or-token-path:line>`
```

Also record 2–5 concrete positive findings. The treatment must preserve what already works, not erase the
product's identity to make every screen conform to a generic premium aesthetic.

Claims about conversion, comprehension, trust, or task success without user/analytics evidence must be marked
`HYPOTHESIS`. Rendered evidence can prove visual properties; it cannot prove business outcomes.

---

## Step 6 — Write the bounded treatment

Write `treatment.md` with exactly these sections:

```markdown
# Design Treatment — <slug>

## Design read
## Preserve
## Retire
## Introduce
## Screen treatments
## Component contract
## Responsive and state contract
## Acceptance
## Non-goals
```

Rules:

- **Preserve mode:** keep URLs, information architecture, primary navigation labels, form field names/order,
  analytics identifiers, legal/consent copy, logo/wordmark, content semantics, working accessibility behavior,
  and product behavior unless the user explicitly approved a change elsewhere.
- **Overhaul mode:** may change visual language and composition, but still may not change behavior or PRD scope.
- Prefer existing components and tokens. Extend a real component only when a finding cannot be resolved by
  composition. Add a new component only after proving no existing component or variant covers the need.
- Distinguish structural treatment from decoration. Fix hierarchy, sequence, density, and recovery before
  adding texture or motion.
- Every `Introduce` item cites one or more finding IDs. Every acceptance item is observable in proto.
- Do not prescribe exact raw CSS values when the design system already owns that decision. Refer to token roles
  and component variants.

---

## GATE 7 — Write the proto handoff

Write both a human-readable `proto-handoff.md` and strict machine-readable `proto-handoff.json`.

`proto-handoff.json` schema:

```json
{
  "schema": 1,
  "status": "ready",
  "audit": "tasks/design-audit-pricing",
  "mode": "preserve",
  "profile": "marketing",
  "prd": "tasks/prd-pricing.md",
  "viewports": {
    "desktop": { "width": 1280, "height": 832 },
    "mobile": { "width": 390, "height": 844 }
  },
  "findings": "audit.md",
  "treatment": "treatment.md",
  "auth": {
    "mode": "project-mock",
    "required": true,
    "principal": { "role": "operator", "label": "demo operator" },
    "sessionState": "authenticated",
    "providerBoundary": "auth/session provider",
    "productionAuthExercised": false,
    "simulationRequired": true
  },
  "screens": [
    {
      "key": "pricing-overview",
      "title": "Pricing overview",
      "route": "/pricing",
      "state": "default",
      "captureState": "page",
      "baseline": {
        "desktop": "baseline/pricing-overview-page-desktop.png",
        "mobile": "baseline/pricing-overview-page-mobile.png"
      },
      "findingIds": ["DA-001"]
    }
  ]
}
```

`profile` is `marketing`, `product`, or `mixed`. `prd` may be `null` when no PRD was supplied. `audit` and a
non-null `prd` are repository-root-relative identities and must resolve inside the project root. `findings`,
`treatment`, and every `screens[].baseline` value are audit-directory-relative and must resolve inside the
normalized audit directory. No path may be absolute or contain `..`.

`proto-handoff.md` must contain:

```markdown
# Proto Handoff — <slug>
**Status:** READY | PARTIAL
**Audit:** tasks/design-audit-<slug>
**PRD:** <path | none>
**Mode:** preserve | overhaul
**Profile:** marketing | product | mixed
**Viewports:** desktop=1280x832; mobile=390x844

## Screen pairs
| Key | Screen | Route/state | Desktop baseline | Mobile baseline | Finding IDs |
```

The handoff is `ready` only when:

- every protected screen has a resolved auth contract; `blocked` auth screens force `partial`;
- the handoff auth contract names the principal role/label and session state proto must simulate, without
  containing credentials, cookies, bearer tokens, or real user identifiers;
- `project-mock` baselines cite the project's documented mock/development-auth seam;
- `browser-session` baselines record no exported session material and proto must still use a deterministic
  mock principal for the after-state;
- `baseline-source.json` exists, matches the current source/capture identity, and binds every preserved PNG;
- every JSON key is unique and appears in `screen-manifest.md`;
- every screen has both valid baseline PNGs at the exact dimensions;
- every finding ID exists in `audit.md`;
- every visual treatment cites a finding or an explicit preserved strength;
- no item changes PRD behavior or scope;
- no BLOCKING finding remains;
- no screen required for the comparison is blocked.

Otherwise set status to `partial`, explain the blockers in both handoff files, and do not tell proto to consume
it. Never relabel partial evidence as ready.

---

## Step 8 — Route to proto

When `--prd` resolved and the handoff is READY, recommend exactly:

```text
/saki-builder:proto <resolved-prd> --audit=tasks/design-audit-<slug>
```

Proto must render the PRD's complete journey. The audit screen set may be a subset, but every audit key must
map to a proto manifest row. Proto compares only mapped keys; new PRD screens remain after-only in the normal
journey gallery.

When no PRD was supplied, the audit is still complete, but direct proto handoff is not. Recommend:

```text
/saki-builder:prd "Apply tasks/design-audit-<slug>/treatment.md without changing behavior or scope"
```

Then run proto with the resulting PRD and `--audit`. Do not invent a PRD inside this skill.

---

## Completion output

```text
--- DESIGN AUDIT COMPLETE ---
Scope: <route/journey>
Mode: preserve | overhaul
Profile: marketing | product | mixed
Baseline: N/N screens captured at desktop 1280x832 and mobile 390x844
Findings: blocking N | major N | moderate N | minor N
Preserved strengths: N
Audit: tasks/design-audit-<slug>/audit.md
Treatment: tasks/design-audit-<slug>/treatment.md
Handoff: READY | PARTIAL — tasks/design-audit-<slug>/proto-handoff.md

Next:
> /saki-builder:proto <prd> --audit=tasks/design-audit-<slug>
```

Do not claim the design improved yet. Improvement is a hypothesis until the proposed state is rendered and
reviewed in proto's before/after comparison; user or usability validation is still required for outcome claims.

## Invariants

- Application source is read-only during audit.
- Baseline screenshots are captured before treatment and never silently replaced.
- Visual findings come from rendered evidence; source inspection explains causes.
- Marketing and product surfaces use different profile rules.
- The product's own brand and directional reference beat generic anti-slop preferences.
- No universal taste score.
- Every proposed change traces to evidence; every preservation rule survives the handoff.
- PRD owns scope and behavior; audit owns visual diagnosis; proto owns visual proof.
- Same key, state, viewport, and dimensions before and after or no comparison claim.
- Baseline PNGs without matching pre-capture `baseline-source.json` provenance are stale, never resumable.
- Protected screens use a safe browser session or a documented project mock; auth redirects are never
  mislabeled as authenticated baselines.
- Auth metadata is redacted and deterministic; no cookie, token, password, or real identifier enters an
  artifact.
