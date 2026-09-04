# Skill Description Audit — Step 1 Output

**Rubric (each criterion = 1 point, max 4):**
- **W1 (WHAT)** — action verb stating what the skill does
- **W2 (WHEN)** — concrete trigger condition (not "for non-trivial tasks")
- **W3 (WHEN NOT)** — excludes sibling territory in collision zone (auto-pass for orphans)
- **W4 (EXAMPLES)** — concrete trigger phrases or output structure (auto-pass for non-user-driven internal skills if W2 is strong)

**Pass threshold: ≥3/4.** Skills below threshold need rewrites in Step 3.

## Result summary

- **Pass: 20** — leave the description alone
- **Fail: 20** — rewrite candidate
- **Collision zones identified: 7**

## Pass list (20)

| Skill | Score | Note |
|---|---|---|
| dispatching-parallel-agents | 3/4 | Sharp WHAT, WHEN implicit. No examples — acceptable. |
| gateway-database | 4/4 | Lists coverage; differentiates well. |
| gateway-deploy | 3/4 | Orphan in deploy zone. |
| gateway-frontend | 4/4 | Names frameworks (React/Vue/CSS) — clear partition. |
| gateway-testing | 4/4 | Coverage list. |
| init-env | 4/4 | "for a new project" is a clean trigger. |
| persisting-progress-across-sessions | 4/4 | "Resume an interrupted run" — verb sets boundary vs persisting-agent-outputs. |
| prompt | 4/4 | **Gold standard.** "Use when you want to write a high-quality prompt from a quick idea." |
| qa | 4/4 | Reads success criteria from plan — clear hand-off from rplan-review. |
| reflect | 3/4 | "Run weekly" + "Cross-project" partitions vs retro. |
| retro | 4/4 | "before ending long sessions" + "Session" partitions vs reflect. |
| reviewer | 4/4 | **Gold standard.** "after implementing... Run before committing." |
| rplan-review | 4/4 | "Run after /rplan before /approved" — best WHEN-NOT in the set. |
| rplan-trust | 4/4 | Lists pipeline composition explicitly. |
| rupdate | 4/4 | "after the repo owner pushes new skills" + verb partitions vs sync. |
| sync | 4/4 | "Run after /reflect to push" — clear pair to rupdate. |
| auth | 3/4 | Borderline. WHEN is weak ("Setup auth flow"); could sharpen but not critical. |
| scaffold-cli | 3/4 | Borderline. Orphan zone saves it. |
| scaffold-deploy | 3/4 | Borderline. Mild collision with gateway-deploy unaddressed. |
| scaffold-tui | 3/4 | Borderline. Orphan zone saves it. |

## Fail list (20) — rewrite candidates

| Skill | Score | Failure modes | Current description |
|---|---|---|---|
| **rplan** | 1/4 | WHEN too vague ("any non-trivial task"); no exclusion vs rplan-trust; no examples | Create structured execution plan with confidence scoring and risk assessment. Use for any non-trivial task before implementation. |
| **prd** | 1/4 | No WHEN; collides with shaping-requirements + brainstorm-feature-options; no examples | Generate Product Requirements Document from feature intent/description |
| **shaping-requirements** | 1/4 | "shapes" is jargon; no WHEN; collides with prd, brainstorm-feature-options | Iteratively define problem and solution shapes. |
| **testing** | 1/4 | No WHEN; collides with gateway-testing and scaffold-* `*-and-tests`; no examples | Generate test suite for existing code |
| **approved** | 2/4 | No exclusion vs rplan-trust (which auto-approves); no example trigger | Approve the current plan and switch model to Sonnet. Enforces XP discipline... |
| **brainstorm-feature-options** | 2/4 | Internal-to-orchestrator framing ("Phase 6") is opaque to user; collides with shaping-requirements, prd | Used by the Lead agent during Phase 6 (Brainstorm) to collaboratively explore... |
| **breadboarding-workflow** | 2/4 | No WHEN; "affordances" jargon; no examples | Map UI elements and code relationships (affordances). |
| **component** | 2/4 | No WHEN; collides with scaffold-webapp | Generate UI component with component file, test, and story (optional) |
| **documenting-release** | 2/4 | No WHEN — release time? PR time? auto? | Cross-reference diffs to update README, ARCHITECTURE, CHANGELOG. |
| **gateway-api** | 2/4 | Doesn't differentiate from gateway-backend (API is server-side); no examples | Route API design/implementation tasks to the right library skill. |
| **gateway-backend** | 2/4 | Doesn't differentiate from gateway-api or gateway-database | Route backend tasks to the right library skill. Detects intent and returns specific skill file paths to load. |
| **iterating-to-completion** | 2/4 | No WHEN (auto? user-invoked?); collides loosely with orchestrating-feature | Prevents premature exit and infinite loops. Three mechanisms: Completion Promises, Scratchpads, Loop Detection. |
| **migration** | 2/4 | No WHEN; lives in scaffold zone but reads like a standalone | Generate database migration, model update, and seed data |
| **orchestrating-feature** | 2/4 | "Kernel Mode" jargon; no exclusion vs rplan-trust | 16-phase feature orchestration workflow. Runs in the main thread as Kernel Mode. Coordinates the Lead→Developer→Reviewer→TestLead→Tester assembly line. |
| **persisting-agent-outputs** | 2/4 | Mild overlap with persisting-progress-across-sessions; no concrete WHEN | Protocol for agents to write structured outputs that survive session resets and are findable by the orchestrator. |
| **reviewing-architecture** | 2/4 | Collides with rplan-review and reviewing-product-strategy; "Eng manager-mode" implies role but not trigger | Eng manager-mode plan review. Lock in the execution plan, data flow, diagrams, edge cases. |
| **reviewing-product-strategy** | 2/4 | Collides with reviewing-architecture and rplan-review; "CEO/founder-mode" same issue | CEO/founder-mode plan review. Rethink the problem, find the 10-star product, challenge premises. |
| **scaffold-api** | 2/4 | No WHEN; doesn't differentiate vs gateway-api (one routes, one generates — not stated) | Generate API endpoint with route, controller, validation, and tests |
| **scaffold-library** | 2/4 | No WHEN; collides with scaffold-webapp (both "Setup project structure") | Setup library project structure with src, build config, exports, and tests |
| **scaffold-webapp** | 2/4 | No WHEN; collides with scaffold-library and component | Setup web app page with component, layout, data fetching, and tests |

## Collision zones (need partition rewrites in Step 3)

### Zone 1 — Planning/orchestration (4 of 6 fail)
**Members:** rplan ❌, rplan-review ✅, rplan-trust ✅, approved ❌, orchestrating-feature ❌, iterating-to-completion ❌
**Partition principle:** rplan = plan only; approved = gate between plan and impl; rplan-trust = full pipeline; orchestrating-feature = multi-agent assembly line; iterating-to-completion = anti-loop guardrail (auto-loaded, not user-invoked); rplan-review = adversarial review.
**Rewrite priority:** HIGH — this zone is the most-invoked and the most-collided.

### Zone 2 — Spec/shaping (3 of 5 fail)
**Members:** prd ❌, shaping-requirements ❌, brainstorm-feature-options ❌, prompt ✅, breadboarding-workflow ❌
**Partition principle:** prd = formal output document; shaping-requirements = pre-PRD problem framing; brainstorm-feature-options = inside orchestrating-feature only; prompt = rewrite a prompt string; breadboarding-workflow = UI/code mapping diagram.
**Rewrite priority:** HIGH — these all sound similar to a cold reader.

### Zone 3 — Plan review (3 of 3 fail vs rplan-review which passes)
**Members:** reviewing-architecture ❌, reviewing-product-strategy ❌, rplan-review ✅
**Partition principle:** rplan-review = mechanical structural + parallel experts; reviewing-architecture = single-pass eng-mgr lens on execution; reviewing-product-strategy = single-pass founder lens on premises.
**Rewrite priority:** MEDIUM.

### Zone 4 — Gateways (2 of 6 fail)
**Members:** gateway-api ❌, gateway-backend ❌, gateway-database ✅, gateway-deploy ✅, gateway-frontend ✅, gateway-testing ✅
**Partition principle:** the api/backend distinction is the only ambiguous one. API ⊂ backend in most stacks. Need explicit "API surface design (routes, contracts, OpenAPI) — for general server logic see gateway-backend."
**Rewrite priority:** MEDIUM (only 2 of 6 broken).

### Zone 5 — Scaffolds (4 of 10 fail)
**Members:** scaffold-api ❌, scaffold-cli ✅, scaffold-deploy ✅, scaffold-library ❌, scaffold-tui ✅, scaffold-webapp ❌, migration ❌, auth ✅, component ❌, testing ❌
**Partition principle:** scaffold-* generate code, gateway-* return skill paths. Library vs webapp distinction = "publishable package" vs "user-facing app". Component is webapp-internal. Migration is database-specific. Testing-the-skill (without scaffold prefix) is the wildest — collides with gateway-testing and every "and-tests" suffix.
**Rewrite priority:** HIGH for `testing` (most collision-prone), MEDIUM for the rest.

### Zone 6 — Persistence (1 of 2 fail)
**Members:** persisting-agent-outputs ❌, persisting-progress-across-sessions ✅
**Partition principle:** outputs = structured artifacts agents write; progress = orchestration state for resumption.
**Rewrite priority:** LOW — only one needs sharpening.

### Zone 7 — Standalone fails
**Members:** breadboarding-workflow ❌, documenting-release ❌
**Partition:** no siblings, just need WHEN added.
**Rewrite priority:** LOW.

## Recommendations going into Step 3

1. **Tackle Zone 1 first** (planning/orchestration) — highest invocation rate, biggest payoff.
2. **Then Zone 2** (spec/shaping) — most user-confusing terminology.
3. **Then Zone 5** (scaffolds) — high count of fails.
4. **Defer Zones 3, 4, 6, 7** — fewer fails, lower routing-error risk.
5. **Borderline 3/4 passes** (auth, scaffold-cli, scaffold-deploy, scaffold-tui) — leave alone unless touching their zone for other reasons.

## Open question for user

**`brainstorm-feature-options` is described as "Used by the Lead agent during Phase 6"** — that's an internal-to-`orchestrating-feature` skill. Two options:
- **a)** Rewrite as a proper user-invokable skill with its own trigger
- **b)** Mark it explicitly as "internal to orchestrating-feature; not for direct invocation" so the harness routes around it

Which is intent? Same question applies to `iterating-to-completion` (sounds like an auto-applied guardrail, not a user command) and `persisting-agent-outputs` (a "protocol", not an action).
