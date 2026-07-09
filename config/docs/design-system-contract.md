# Design System Contract

A fixed spec for building UI components consistently across **every** saki-builder project.
This is the canonical source of truth. It is referenced by:

- **`/saki-builder:genesis`** (G3/G4) — runs **Part 0** once to produce Part A + the gold-standard component.
- **`/saki-builder:proto`** (GATE 2 + Step 2.6) — GATE 2 checks tokens conform to **Part B**; Step 2.6 builds
  every new component to **Part C** and runs the Part C self-check before it counts as done.
- **`/saki-builder:component`** — builds each component via **Part D → Part E → Part C self-check**.
- **`product-engineer` agent** — any UI work is built to this contract, not to ad-hoc taste.

**The split that makes this durable:**
- **Part A is project-local** — filled per project (lives in the repo's `design.md`).
- **Parts B–F are invariant** — carried verbatim by this file. Never edit per project.

A rule change happens once, here, in Parts B–F, and every project inherits it.
If you catch yourself wanting to edit B–F for a single project, that rule belongs in Part A instead.

**Lifecycle:**
- **From scratch** — `/saki-builder:genesis` runs **Part 0** once to produce Part A and the gold-standard
  component. Then A–F govern.
- **Existing project** — Part A is already filled (in `design.md`); skip Part 0 and go straight to Part D
  per component.

---

## Part 0 — Bootstrap  *(run ONCE per new project, from scratch — produces Part A)*

A new project has no tokens and no exemplar yet. Part 0 creates both. It runs a
single time (inside `/saki-builder:genesis` G3–G4); after it, you're in steady state and never touch it again.

**Step 1 — Pin the subject and direction.** Name the product, its user, the device,
and the page's single job. Choose a DIRECTIONAL REFERENCE from the subject's own
world (its materials, vernacular, artifacts) — a concrete anchor, never an adjective.
Do *not* spend a free design axis on an AI-default look (see Part F).

**Step 2 — Derive the token values.** From that direction, propose the Part A token
block: palette as 4–6 named hex values, two-to-three type faces with a ≤6-step scale,
the 8px spacing scale, radius/elevation/motion sets. Then critique the proposal
against the brief: if any token reads like the generic default you'd produce for *any*
similar project, revise it and say what changed and why. Write the survivors into Part A
(the repo's `design.md`).

**Step 3 — Build the first component = the gold-standard.** Pick a small but
state-rich primitive (Button or Input is ideal — small enough to perfect, rich enough
to exercise every state). Build it to the full Part C contract using the Part E
layered workflow, with extra scrutiny and a human review, because this one has no
exemplar to lean on. When it passes, record its path in Part A as
GOLD-STANDARD COMPONENT.

From this point on, every later component is "built the way that one is built,"
and Parts A–F govern. Part 0 is done forever.

---

## Part A — Project Slot  *(the only thing you edit per project — lives in the repo's `design.md`)*

```
PROJECT: <name>
PRIMARY LANGUAGE: <e.g. Bahasa Indonesia>
DIRECTIONAL REFERENCE: <1–2 concrete anchors, not adjectives>
  e.g. "On.com — image-first, stark, product as hero, generous negative space"

GOLD-STANDARD COMPONENT: <path to the one exemplar built fully to this contract>
  New components are built "the way <this> is built." This is the spec-by-example.

TOKENS (values only — the schema they must fill is fixed in Part B):
  Color roles:
    primary:        #______
    surface:        #______
    surface-raised: #______
    border:         #______
    text:           #______
    text-muted:     #______
    danger:         #______
    success:        #______
  Type:
    display face:   <family>
    body face:      <family>
    utility/mono:   <family>
    scale (px):     12 / 14 / 16 / 20 / 28 / 40   (adjust step values, keep ≤6 steps)
  Spacing scale (px): 4 / 8 / 12 / 16 / 24 / 32 / 48   (8px-based)
  Radius:  sm ___  md ___  lg ___
  Elevation: define 2–3 named shadows, no more
  Motion:  fast ___ms  base ___ms  (easing: ______)
```

---

## Part B — Token Schema  *(fixed — every project fills these, none invents new ones)*

Components read tokens. Components never hardcode a raw value.
Color is defined by **role**, not hue — `border`, not `gray-300`. A project may
recolor `primary` from red to blue and nothing else changes.

Required roles / scales that must exist in every project:

- **Color roles:** `primary`, `surface`, `surface-raised`, `border`, `text`,
  `text-muted`, `danger`, `success`. Add roles only when a real need appears; never
  add raw hues.
- **Type:** three faces max (display / body / utility), one scale of ≤6 named steps.
- **Spacing:** one 8px-based scale. All gaps, padding, margins come from it.
- **Radius / Elevation / Motion:** small fixed sets (2–3 values each). More than
  that is drift, not expressiveness.

**Rule:** if a value isn't a token, it can't ship.

### Format binding (house default: Next.js + Tailwind + shadcn/ui)

So GATE 2 can *machine-check* the schema, the roles above bind to concrete artifacts.
On the house stack, tokens live as CSS custom properties in `app/globals.css` and are
exposed to Tailwind via the `@theme` directive (Tailwind v4) or `tailwind.config.*` (v3):

```css
/* app/globals.css */
:root {
  --color-primary:        #____;
  --color-surface:        #____;
  --color-surface-raised: #____;
  --color-border:         #____;
  --color-text:           #____;
  --color-text-muted:     #____;
  --color-danger:         #____;
  --color-success:        #____;
  --radius-sm: __px; --radius-md: __px; --radius-lg: __px;
  --motion-fast: __ms; --motion-base: __ms;
}
@theme inline {              /* Tailwind v4 — makes bg-primary / text-muted etc. resolve to the vars */
  --color-primary: var(--color-primary);
  /* …one line per role… */
}
```

- **Detection contract (GATE 2 checks this):** the eight color roles above exist as
  `--color-<role>` (or the equivalent `tailwind.config` `theme.extend.colors.<role>`),
  and components reference them via Tailwind classes / `var(--color-<role>)` — never raw hex.
- **Non-house stacks** (Vue/Svelte/plain CSS): same eight roles as CSS custom properties
  under `:root`; the binding differs, the *role schema* does not.

---

## Part C — Component Contract  *(fixed — the definition of done for ANY component)*

Every component the agent produces must satisfy all of the following. This is the
universal ~80% you would otherwise duplicate into per-component templates — so it
lives here once instead.

1. **Reads from tokens.** No hardcoded colors, sizes, spacing, radii, durations.
2. **Composes from existing primitives.** Reuse before reinvent. If a primitive is
   missing, flag it — don't quietly fork one.
3. **Implements every applicable state:**
   `default · hover · focus · active · disabled` — always.
   `loading · error · empty` — wherever the component can enter them.
   A missing state is a bug, not an omission.
4. **Meets the quality floor** (Part F) — non-negotiable, never announced.
5. **Variants follow the naming convention** and each has a stated *when to use*.
6. **Ships with usage notes + one explicit "do not" rule.**
7. **Matches the gold-standard component** in structure, token usage, and file layout.

**Self-check the agent runs before declaring done (a failing box → NOT done, no exceptions):**
- [ ] Zero hardcoded values — everything traces to a token?
- [ ] Every applicable state implemented, including focus and disabled?
- [ ] Contrast ≥ 4.5:1 (text), touch target ≥ 44px, focus ring visible?
- [ ] Keyboard-operable, correct ARIA roles/labels?
- [ ] Built the way the gold-standard component is built?
- [ ] Usage notes + one "do not" rule included?

Any unchecked box → not done. This self-check is the **blocking gate** wired into
`/saki-builder:proto` Step 2.6 and `/saki-builder:component`.

---

## Part D — Per-Component Intake  *(fixed format — the ONLY thing supplied per component)*

Keep it to a few lines. The contract already carried everything universal, so you
supply only the delta that's genuinely unique to this component.

```
COMPONENT: <name> — <its one job / when it's used>
ANATOMY:   <its parts>
VARIANTS:  <each variant + when to use it>
STATES+:   <only states BEYOND the standard set — component-specific edge cases>
MUST NOT:  <anything specific to forbid>
```

If you're tempted to write "make sure it has a focus state" here — stop. That's in
the contract. Anything you'd repeat across components belongs up a layer, not here.

---

## Part E — Build Workflow  *(fixed — how the agent builds, in order)*

**Reference-component-first.** The strongest instruction is "build X the way the
gold-standard is built." One strong exemplar carries the whole contract implicitly
and drifts less than any written template. Your first well-built component becomes
the spec for every one after it.

**Build in layers, not one shot** — so reasoning surfaces where it's cheap to correct:

1. **Structure** — anatomy and hierarchy only, no styling. Boxes and content.
2. **Tokens** — apply color roles, type scale, spacing scale.
3. **States** — every applicable state from the contract.
4. **Polish** — spacing rhythm, motion, responsive behavior.

For a one-shot agent prompt, include those four as explicit sections in the prompt
itself, so the agent doesn't have to invent the order.

Always require the agent to **state its hierarchy reasoning** — what's primary,
what's secondary, and why. Making it justify the layout forces reasoning instead of
decoration.

---

## Part F — Quality Floor & Anti-Patterns  *(fixed — applies to everything, always)*

**Quality floor (met silently, never announced):**
- Responsive down to mobile (test at 375px and 1440px).
- Visible keyboard focus on every interactive element.
- Contrast ≥ 4.5:1 for text; ≥ 3:1 for large text and UI boundaries.
- Touch targets ≥ 44 × 44px.
- `prefers-reduced-motion` respected.
- One primary action per view. Secondary actions visibly subordinate.

**Anti-patterns the agent must avoid:**
- **Adjective-driven design.** "Modern / clean / sleek / pop" carry no information —
  replace every one with a reference or a constraint.
- **Raw values.** Any color/size/spacing not traceable to a token.
- **Reinventing primitives** instead of composing existing ones.
- **AI-default looks** (they appear regardless of brief, so they read as tells):
  cream `#F4F1EA` + serif + terracotta `~#D97757`; near-black + single acid accent;
  broadsheet hairline-rules + zero radius. Legitimate only if the project's
  DIRECTIONAL REFERENCE actually asks for one. Otherwise, don't spend a free axis on them.
- **One-shotting a finished screen** when structure-first would surface the hierarchy
  for cheap correction.

---

*Invariant sections: B, C, D, E, F. Edit only Part A per project (in the repo's `design.md`).*
