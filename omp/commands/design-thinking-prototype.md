---
description: "Design and prototype exceptional UI/UX or frontend experiences when the problem, interaction model, visual direction, information architecture, or user journey needs evidence-led exploration before implementation."
---

# Design Thinking for Exceptional UI

Usage: `/saki-builder:design-thinking-prototype "<design question>" [context path]`

Produce a **validated direction**, not an attractive guess. Design thinking is a non-linear evidence loop:
**empathize → define → ideate → prototype → test → implement**. A failed assumption returns to the stage
that created it.

This skill operationalizes Figma's design-thinking model: the human, ambiguity, re-design, and tangibility
principles; and the desirability, feasibility, and viability lenses.
Source: https://www.figma.com/resource-library/what-is-design-thinking/

## Route the work

- Finished PRD needing a faithful, complete journey preview → `/saki-builder:proto`; it owns screen coverage,
  real-shell rendering, approval, and the PRD lock.
- Uncertain layout, interaction model, information architecture, or visual direction → run this skill.
- Isolated, already-defined production component → `/saki-builder:component` after the direction is validated.
- Validated prototype being promoted to production → use the repository's frontend implementation conventions.
  Prototype code is evidence, not production code.

Keep scope from the user's request, PRD, or issue. Missing evidence becomes an explicit assumption, never
invented user knowledge.

### Embedded `/proto` mode

When `/saki-builder:proto` loads this skill, do not route back into `/saki-builder:proto` and do not restart
product discovery. Map its existing stages onto this process:

- PRD + personas + shipped product → Empathize and Define evidence.
- Proto Step 2.5 → Ideate only for a design gap or first-of-shape screen.
- Proto Steps 5–6.5 → Prototype and expert review in the real shell.
- Proto Step 7 → human expectation and visual approval.
- `/saki-builder:build` → Implement.

Apply the evidence, three-lens, structural-option, accessibility, and validation-honesty gates below inside
those existing stages. Proto's screen coverage, resume, approval, and lock rules remain authoritative.

## 1. Empathize — ground every decision

Read the nearest available evidence, in this order:

1. Direct user research, usability findings, support evidence, and analytics.
2. Project personas, PRD, issue, domain language, and acceptance criteria.
3. The current product: shipped journey, analogous screens, design system, content, and real data shapes.
4. Competitor or precedent patterns, used as context rather than user evidence.
5. Explicit assumptions when stronger evidence does not exist.

Build a compact evidence map:

| User/context | Job and desired outcome | Friction or risk | Evidence | Confidence |
|---|---|---|---|---|

Include environment, device, frequency, domain expertise, accessibility needs, consequences of error, and
current workaround when evidence supports them. Walk the existing product before proposing a replacement;
the re-design principle starts from what already works.

**Completion criterion:** every material user claim cites evidence or is labelled `ASSUMPTION`; the primary
user, context, job, and highest-cost friction are explicit.

## 2. Define — frame one testable problem

Write the frame before drawing screens:

> **[User] needs to [outcome] in [context], but [root barrier], causing [observable consequence].**

Then state:

- **Success signal:** behavior or outcome that would demonstrate improvement.
- **Critical journey:** entry → orient → act → receive feedback → recover if needed → complete.
- **Non-goals:** boundaries that keep visual exploration from expanding product scope.
- **Design question:** one sentence the prototype must answer.
- **Design principles:** 3–5 project-specific decision rules derived from evidence.

Run the three-lens check:

| Lens | Question | Evidence | Risk to test |
|---|---|---|---|
| Desirability | Does this solve the user's actual job? | | |
| Feasibility | Can the current stack, data, and design system support it? | | |
| Viability | Does it support the product or organizational outcome over time? | | |

Trace the barrier to a root cause rather than restyling its symptom. Use repeated “why?” only while each
answer is supported by evidence or marked as an assumption.

**Completion criterion:** one primary problem, one observable success signal, explicit boundaries, and a
design question capable of rejecting at least one concept.

## 3. Ideate — diverge structurally

Generate at least three concepts that disagree about structure, not decoration:

- **Evolutionary:** deepens the strongest existing product pattern.
- **Workflow-first:** minimizes steps, memory load, and recovery cost.
- **Distinctive:** expresses the product's domain or brand through a different hierarchy or interaction model.

For each concept record:

- information hierarchy and primary action;
- interaction model and critical journey;
- responsive shape;
- one signature move tied to user, brand, or domain evidence;
- falsifiable hypothesis;
- largest usability and implementation risk;
- desirability, feasibility, and viability as `strong`, `uncertain`, or `weak`, with reasons.

A signature move earns its place only when its rationale is specific to this product. Preserve familiar
conventions where familiarity reduces risk; spend novelty on the part that creates user value.

Select one concept when evidence clearly dominates. Prototype two when the deciding risk is experiential and
cannot be resolved from existing evidence. Ask the user only when alternatives encode a product tradeoff that
a prototype cannot cheaply answer.

**Completion criterion:** concepts differ in hierarchy or interaction, every concept has a falsifiable
hypothesis, and selection follows evidence rather than taste.

## 4. Prototype — make the hypothesis tangible

Choose fidelity from the uncertainty:

- Information architecture or hierarchy uncertainty → low-fidelity but interactive.
- Workflow, state transition, or comprehension uncertainty → mid-fidelity runnable flow.
- Visual direction, component fit, responsive behavior, or feasibility uncertainty → high-fidelity frontend
  in the real app shell.

Extend a nearby shipped page when one exists; a context-free route is a last resort. For competing concepts,
mount structurally different variants behind a shareable `?variant=` parameter and a development-only
switcher. Use one command to run the result.

Prototype the **critical journey**, not a hero frame:

- entry and orientation;
- primary task from start to completion;
- feedback after each consequential action;
- recovery from the highest-cost error;
- loading, empty, validation, permission, and server-error states when reachable;
- long, short, missing, and realistic content shapes;
- desktop and mobile, plus the breakpoint where hierarchy changes.

Use the real shell, components, tokens, typography, icon language, density, and content voice. Use mock data
behind a clear prototype seam. Keep data mutations inert unless the design question concerns mutation behavior.

Craft deliberately:

- **Hierarchy:** one unmistakable primary action; grouping follows task sequence.
- **Typography:** roles and scale express information priority before color does.
- **Color:** semantic and brand roles remain legible in every state and theme.
- **Space:** proximity communicates relationships; density matches the user's context.
- **Motion:** explains causality or state change; reduced-motion behavior preserves meaning.
- **Distinctiveness:** one or two evidence-backed signature moves, executed consistently.
- **Resilience:** content growth, localization, slow data, errors, and narrow widths retain the task.

Build semantic controls, logical focus order, visible focus, keyboard operation, named inputs, useful error
association, 44×44 CSS-pixel touch targets, WCAG AA contrast, and non-color state cues into the prototype.
Accessibility is part of the hypothesis, not a later audit.

**Completion criterion:** one command opens a runnable entry-to-completion flow; each selected concept is
shareable by URL; critical states are reachable; narrow and wide viewports have no dead ends or hidden
essential actions.

## 5. Test — seek disconfirming evidence

Write tasks and pass criteria before evaluation. Each task starts with a realistic situation and asks for an
outcome without naming the control to use.

Observe rather than coach:

- first action and next-step discoverability;
- completion, abandonment, hesitation, backtracking, and misclicks;
- comprehension of labels, status, and consequences;
- error recognition and recovery;
- confidence at irreversible or high-cost moments;
- keyboard, zoom, reduced-motion, and narrow-viewport behavior.

Use target users when available. Record participant evidence as observations and quotes, not interpretations.
With no participants, run a browser-based cognitive walkthrough and heuristic/accessibility review; label the
result **expert review — user validation outstanding**.

| Hypothesis | Evidence observed | Severity | Decision |
|---|---|---|---|

Decision values: `validated`, `revise`, or `reject`. Fix critical journey failures first and re-run the exact
failed task. Return to Empathize for a wrong user assumption, Define for a wrong problem, Ideate for a weak
concept, or Prototype for an execution flaw.

**Completion criterion:** every hypothesis has observed evidence and a decision; every critical failure is
revised and re-exercised; claims distinguish user validation from expert review.

## 6. Implement — promote the decision, not the experiment

Capture the problem and evidence, chosen concept and rejected alternatives, critical journey and state map,
component/token decisions, responsive and accessibility behavior, unresolved assumptions, and success signal.

For a complete PRD journey, run `/saki-builder:proto` to produce exhaustive screen/state coverage and approval
artifacts. For production, rewrite the validated direction using real data, business rules, error handling,
and repository conventions. Promote reusable presentational components; remove prototype switches, inert
mutations, losing variants, and prototype-only routes from production.

Verify the actual browser surface. Exercise the critical and recovery paths at mobile and desktop widths;
inspect focus order, keyboard use, loading/error behavior, overflow, and console/runtime errors. Typecheck and
run the relevant project checks after the surface works.

**Completion criterion:** the production surface preserves the validated journey and hierarchy, all reachable
states are implemented, the browser scenario passes at mobile and desktop widths, and prototype-only code is
absent from the production path.

## Exceptional UI gate

Every applicable row needs evidence before promotion:

| Quality | Pass condition |
|---|---|
| Human | Decisions trace to evidence or explicit assumptions. |
| Useful | The critical job completes without a dead end. |
| Clear | Users can identify current state, next action, and consequence. |
| Coherent | Shell, components, tokens, language, and interactions belong to one product. |
| Distinctive | Signature choices are specific to the domain or brand. |
| Resilient | Empty, loading, error, permission, long-content, and recovery states preserve the task. |
| Inclusive | Semantics, keyboard, focus, contrast, zoom, motion, and touch behavior pass. |
| Responsive | Hierarchy adapts; essential capability survives narrow widths. |
| Feasible | The direction works with real architecture, data, and performance constraints. |
| Validated | Evidence supports the hypotheses; validation level is stated honestly. |

A critical failure blocks promotion. Polish cannot compensate for a broken journey, inaccessible control,
unsupported user claim, or infeasible interaction.

## Delivery

1. **Problem:** user, context, barrier, success signal.
2. **Evidence:** sources and explicit assumptions.
3. **Concepts:** structural alternatives and three-lens tradeoffs.
4. **Prototype:** runnable URL/command, variants, journey, states, viewports.
5. **Test:** tasks, observations, failures, revisions, validation level.
6. **Decision:** winner, rationale, implementation handoff, unresolved risks.
7. **Proof:** browser scenarios and relevant checks actually run.
