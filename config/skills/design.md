# Design Thinking

## UI/UX Stack
- **Component Library:** shadcn/ui (copy-paste components built on Radix UI primitives)
- **Styling:** Tailwind CSS 4 (CSS-first config, `@theme` directive, no `tailwind.config.js`)
- **Design System:** Follow shadcn/ui patterns — use existing components before creating custom ones
- **Vibe Blocks:** 2,000+ UI component library (Relume + Custom/shadcn) — check vibe-blocks for pre-built sections before building from scratch
- **Web Design Guidelines:** Accessibility (WCAG), UX best practices, design auditing — reference for reviews and compliance checks

**Before ANY UI change:**
1. Check design system for existing patterns
2. Use design tokens (CSS variables, Tailwind classes)
3. Plan responsive behavior (mobile-first)
4. Consider accessibility (contrast 4.5:1, keyboard nav, ARIA labels)
5. Include loading/error/empty states

**Never:** Use random colors/spacing | Skip responsive | Ignore accessibility | Create one-off components

## UI Implementation Checklist
- [ ] Using design tokens (not hardcoded values)
- [ ] Mobile-first responsive design
- [ ] Semantic HTML (button, nav, header)
- [ ] ARIA labels for accessibility
- [ ] Loading/error/empty states included
- [ ] Keyboard navigation works
- [ ] Color contrast passes (4.5:1)
- [ ] Touch targets 44px+

## Quick Reference
### UI Changes
1. Check design system → Plan with accessibility → Implement mobile-first → Test breakpoints

---

## UI Component Patterns Reference
Source: [The Component Gallery](https://component.gallery/components/) — 75 components, 3000+ implementations across major design systems.

### Component Catalog (by category)

**Layout & Structure:** Card, Header, Footer, Hero, Stack, Separator, Drawer
**Navigation:** Navigation, Breadcrumbs, Tabs, Pagination, Skip link, Stepper
**Data Display:** Table, List, Avatar, Badge, Icon, Image, Tree view, Video
**Feedback:** Alert, Toast, Empty state, Progress bar, Progress indicator, Skeleton, Spinner
**Overlay:** Modal, Popover, Tooltip, Dropdown menu
**Forms:** Button, Button group, Checkbox, Combobox, Color picker, Date input, Datepicker, Fieldset, File upload, Form, Label, Radio button, Rating, Rich text editor, Search input, Segmented control, Select, Slider, Text input, Textarea, Toggle
**Typography:** Heading, Link, Quote, Visually hidden
**Media:** Carousel, Image, Video

### Key Component Patterns & Accessibility

#### Accordion
- **HTML:** Use `<details>`/`<summary>` for no-JS fallback, OR `<h2>` + `<button aria-expanded>`
- **A11y:** `aria-expanded`, `aria-controls` linking button→content, hide decorative SVGs with `aria-hidden="true"`
- **Tip:** Prefer allowing multiple items open simultaneously; ensure content visible if JS fails

#### Button
- **HTML:** Always use `<button type="button|submit|reset">`, never styled `<div>` or `<a>`
- **Variants:** Primary, Secondary, Destructive, Ghost, Icon-only, Split, Toggle
- **A11y:** Icon-only buttons MUST have `aria-label` or visually hidden text; native `<button>` gets keyboard support for free
- **Tip:** Use action-specific labels ("Delete item", not "OK"); min touch target 44px; DON'T use `cursor: pointer` on buttons (reserve for links)

#### Card
- **Variants:** Standard, Content (media+text), Product, Image, Callout, Document
- **A11y:** Proper heading hierarchy inside cards, alt text for images, keyboard nav for interactive cards, focus indicators
- **Tip:** Clear visual hierarchy with distinct content zones; avoid color-only information

#### Modal / Dialog
- **HTML:** Use native `<dialog>` element where possible
- **A11y:** `role="dialog"`, focus trap (tab cycles within modal), restore focus on close, Escape to dismiss
- **Tip:** Always provide close via X button + Escape + backdrop click; keep content minimal

#### Toast / Notification
- **HTML:** Use `role="status"` or `role="alert"` (for urgent), `aria-live="polite"` or `"assertive"`
- **A11y:** Don't rely solely on color; include dismiss mechanism; auto-dismiss timing should be generous (5s+)
- **Tip:** Stack multiple toasts; position consistently (top-right or bottom-center)

#### Navigation
- **HTML:** `<nav aria-label="Main">` wrapping `<ul>`/`<li>` list structure
- **A11y:** `aria-current="page"` on active link, keyboard arrow navigation, visible focus states
- **Variants:** Horizontal (primary), Vertical/Side (hierarchical), Bottom (mobile), Mega menu

#### Tabs
- **HTML:** `role="tablist"` container, `role="tab"` buttons, `role="tabpanel"` content
- **A11y:** `aria-selected="true|false"`, `aria-controls` + `aria-labelledby` linking, arrow keys cycle tabs, Tab key exits tablist
- **Tip:** Consider accordion fallback on mobile; hidden content reduces discoverability

#### Table
- **HTML:** Semantic `<table>`, `<thead>`, `<th scope="col|row">`, `<caption>`
- **A11y:** Never use tables for layout; provide sort indicators with `aria-sort`; use `aria-describedby` for complex tables
- **Tip:** Responsive strategies: horizontal scroll, stacked cards on mobile, or priority columns

#### Form
- **HTML:** `<form>`, `<fieldset>`, `<legend>`, `<label for="id">`
- **A11y:** Every input needs a visible `<label>`; group related fields with `<fieldset>`+`<legend>`; error messages linked via `aria-describedby`
- **Tip:** Validate on blur (not keystroke); show errors inline near the field; must work without JS

#### Empty State
- **Pattern:** Illustration/icon + contextual message + CTA button
- **Tip:** Explain WHY content is absent; provide actionable next step ("Create your first project"); keep tone helpful not blaming

#### Skeleton / Loading
- **A11y:** Use `aria-busy="true"` on loading container, `aria-label="Loading"` or visually hidden text
- **Tip:** Match skeleton shapes to actual content layout; subtle pulse animation; avoid for fast loads (<300ms)

#### Stepper / Progress Indicator
- **A11y:** `aria-current="step"` on active step, `aria-label` describing progress ("Step 2 of 4")
- **Tip:** Show completed/current/upcoming states; allow backward navigation to completed steps

### Universal Accessibility Checklist (per component)
1. **Keyboard:** All interactive elements reachable and operable via keyboard alone
2. **Screen reader:** Semantic HTML + ARIA roles/states/properties where needed
3. **Focus:** Visible focus indicator (2px+ outline), logical focus order
4. **Color:** Never rely on color alone; maintain 4.5:1 contrast (3:1 for large text)
5. **Motion:** Respect `prefers-reduced-motion`; no auto-playing animations
6. **Touch:** Minimum 44x44px touch targets on mobile
7. **States:** Communicate disabled, loading, error, expanded, selected states to AT

### Top Design Systems to Reference
| System | Tech | Strengths |
|--------|------|-----------|
| Radix UI | React | Unstyled, fully accessible primitives |
| shadcn/ui | React + Tailwind | Copy-paste components, good defaults |
| Headless UI | React/Vue | Unstyled, accessible, Tailwind-ready |
| GOV.UK | Vanilla | Gold standard accessibility & research |
| Carbon | React/Vue/Angular/WC | Enterprise-grade, comprehensive |
| Chakra UI | React | Good DX, accessible, themeable |
| Polaris | React | E-commerce patterns, tone-of-voice guides |
| Ant Design | React | Comprehensive, CJK-friendly |
| Material/MUI | React | Familiar patterns, extensive docs |
| Flowbite | Tailwind | Ready-made Tailwind components |
