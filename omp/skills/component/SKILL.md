---
name: component
description: Generate UI component with component file, test, and story (optional)
type: scaffold
project_types: [web-app]
trigger: "create component, create component, add component"
inputs:
  - name: name
    description: Component name (PascalCase)
    required: true
  - name: type
    description: Component type (page, layout, ui, form, data-display)
    required: false
    default: "ui"
  - name: props
    description: Description of required props
    required: false
---

## Context

Project {{project_name}} uses {{stack}}.
Create component "{{input.name}}" of type {{input.type}}.

**Before starting:** check if `.omp/personas/*.md` exists. If it does, read the relevant
persona(s) and use them to inform copy tone, affordances, error messages, and interaction
patterns. Cite the persona section when a decision is persona-driven (e.g. `→ persona §5`).

Read AGENTS.md for component conventions.
Read existing components to understand patterns (styling, state, testing).

## Design System Contract (BLOCKING)

Every component is built to the **Design System Contract** —
`skill://saki-builder-runtime/docs/design-system-contract.md`. Load it before building. It is the
definition of done; this skill only carries the per-component *delta*.

- **Read Part A first** — the repo's `design.md` holds the project's tokens + the
  **GOLD-STANDARD COMPONENT** path. New components are built *"the way the gold-standard is built."*
  If `design.md` / a gold-standard component doesn't exist yet, this project hasn't run Part 0 — stop
  and route to `/saki-builder:genesis` (it runs the bootstrap).
- **Write the Part D intake** (a few lines) — the only per-component input:
  ```
  COMPONENT: {{input.name}} — <its one job>
  ANATOMY:   <its parts>
  VARIANTS:  <each variant + when to use it>
  STATES+:   <only states BEYOND default/hover/focus/active/disabled/loading/error/empty>
  MUST NOT:  <anything specific to forbid>
  ```
- **Build via Part E (layers, not one shot):** Structure → Tokens → States → Polish. State your
  hierarchy reasoning (what's primary/secondary and why) before styling.

## Instructions

1. **Analyze existing component patterns**
   - Check component directory structure
   - Identify: styling approach (CSS Modules, Tailwind, styled-components)
   - Identify: state management (useState, Zustand, Redux, etc.)
   - Identify: testing pattern (render tests, user-event, MSW)

2. **Create component file**
   - Path: according to project convention
     - `src/components/{{input.name}}/{{input.name}}.tsx`
     - or `src/components/{{input.name}}.tsx`
   - Props interface with TypeScript
   - Implement component according to type:
     - `ui`: presentational, props-driven
     - `form`: form state, validation, submit handler
     - `data-display`: data fetching, loading/error states
     - `layout`: children, responsive design
     - `page`: composition of other components

3. **Create barrel export** (if the project uses this pattern)
   - `src/components/{{input.name}}/index.ts`

4. **Create test file**
   - Path: co-located or in test directory
   - Tests:
     - Renders without crashing
     - Renders with different props
     - User interactions (click, type, etc)
     - Edge cases (empty data, long text, etc)

5. **Create story** (if the project uses Storybook)
   - Path: co-located `{{input.name}}.stories.tsx`
   - Default story + variants

## Validation — Part C self-check (BLOCKING; any unchecked box → NOT done)

Run the Design System Contract Part C self-check before declaring done:

- [ ] Zero hardcoded values — every color/size/spacing/radius/duration traces to a token (Part B roles)?
- [ ] Every applicable state implemented — `default · hover · focus · active · disabled` always;
      `loading · error · empty` wherever reachable?
- [ ] Contrast ≥ 4.5:1 (text), touch target ≥ 44px, focus ring visible, `prefers-reduced-motion` respected?
- [ ] Keyboard-operable, correct ARIA roles/labels?
- [ ] Built the way the **gold-standard component** (Part A) is built — same structure, token usage, file layout?
- [ ] **No Part F tell** — reads as the pinned **DIRECTIONAL REFERENCE** (`design.md` Part A), not an
      AI-default look (cream+serif+terracotta · near-black+acid · emoji-as-icon · gratuitous gradient/shadow)?
- [ ] Usage notes + one explicit "do not" rule included?
- [ ] Component renders without error; TypeScript types correct (no `any`); tests passing.

A missing state is a bug, not an omission. A raw value that isn't a token can't ship.
