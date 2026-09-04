# Skill Complexity Audit

**Goal:** Reduce slash-menu surface for the target user (context + expectations, less technical). Classify each of 40 skills as VISIBLE, POWER-USER, or INTERNAL. Recommend what to hide.

**Decision principle:** When in doubt, hide. Cost of hiding a skill the user could have used is small (Claude can still invoke it). Cost of exposing a skill they can't understand is high (confusion, abandonment).

## Classification rubric

| Bucket | Criteria | What it means |
|---|---|---|
| **VISIBLE** | User can describe a goal that maps directly to this skill. Description readable without knowing other skills. Non-technical user sees value. | Stays in `/` menu. Description audit applies. |
| **POWER-USER** | Real entry point but only valuable to someone who already knows the pipeline. Description references workflow positioning. | Hide by default. Power user can still invoke if they know the name. |
| **INTERNAL** | Building block, guardrail, protocol, or router. Invoked by other skills, not the user. Description literally says "used by X agent" or "protocol for Y." | Hide. Claude calls it internally. |

## Classification (all 40)

### VISIBLE — 21 skills

User can describe a goal in plain language that maps to this skill.

| Skill | Why visible |
|---|---|
| `auth` | "Set up login" |
| `component` | "Make me a button component" |
| `documenting-release` | "Update the changelog" |
| `init-env` | "Set up Claude in this project" |
| `migration` | "Add a database migration" |
| `prd` | "Write a PRD for this feature" |
| `prompt` | "Improve this prompt" |
| `qa` | "Test what we just built" |
| `reflect` | "Weekly learning review" |
| `retro` | "Wrap up this session" |
| `reviewer` | "Review my code" |
| `rplan` | "Plan this task" |
| `rupdate` | "Pull config updates" |
| `scaffold-api` | "Create an API endpoint" |
| `scaffold-cli` | "Make a CLI command" |
| `scaffold-deploy` | "Generate Dockerfile" |
| `scaffold-library` | "Set up a library project" |
| `scaffold-tui` | "Build a TUI screen" |
| `scaffold-webapp` | "Create a web page" |
| `sync` | "Push learning to git" |
| `testing` | "Generate tests for this" |

### POWER-USER — 6 skills

Recommend hiding. Each has a reason the target user wouldn't pick it correctly.

| Skill | Recommendation | Why |
|---|---|---|
| `approved` | **Hide** | "Approve a plan" is a workflow step, not a goal. The user just says "go ahead" naturally — Claude can pick up the cue without a dedicated command. |
| `orchestrating-feature` | **Hide** | "16-phase feature orchestration workflow with Lead→Developer→Reviewer→TestLead→Tester assembly line" is intimidating to a non-technical user. Fold into `/rplan` or expose only via `/rplan-trust`. |
| `reviewing-architecture` | **Hide** | "Eng manager-mode review" is a niche angle. `/reviewer` should offer this as an option internally, not as a separate command. |
| `reviewing-product-strategy` | **Hide** | "CEO/founder-mode review" — same issue. Niche angle, should be an option inside `/reviewer` or `/rplan`, not a top-level command. |
| `rplan-review` | **Hide** | Internal step of the rplan→approved pipeline. "Run after /rplan before /approved" — that's pipeline mechanics, not a user goal. |
| `rplan-trust` | **Keep visible — but rename** | This is actually the *best* command for a less-technical user — "I trust the plan, just do the whole thing." But the name `rplan-trust` doesn't communicate that. Suggest renaming to `/build` or `/ship-feature`. Decision deferred — rename is a separate change. |

### INTERNAL — 13 skills

Hide. These are building blocks, not commands.

| Skill | Why internal |
|---|---|
| `brainstorm-feature-options` | "Used by the Lead agent during Phase 6" — explicitly bound to `orchestrating-feature` |
| `breadboarding-workflow` | "Map UI elements and code relationships (affordances)" — sub-step technique, no standalone user goal |
| `dispatching-parallel-agents` | Orchestration mechanic, not a user command |
| `gateway-api` | Router — receives intent, returns paths to deeper skills |
| `gateway-backend` | Router |
| `gateway-database` | Router |
| `gateway-deploy` | Router |
| `gateway-frontend` | Router |
| `gateway-testing` | Router |
| `iterating-to-completion` | Auto-applied guardrail. User would never invoke. |
| `persisting-agent-outputs` | "Protocol for agents to write structured outputs" — convention, not action |
| `persisting-progress-across-sessions` | Resume protocol used by orchestrator |
| `shaping-requirements` | "Iteratively define problem and solution shapes" — pre-planning sub-step. Capability is real, but the name and framing assume you already know what "shapes" means. If exposed, needs full rewrite. |

## Net effect

- Before: **40** entries on slash menu
- After: **21–22** entries on slash menu (depending on `rplan-trust` decision)
- **~45% reduction in user-facing surface**

## Open implementation question

**How does "hiding" actually work mechanically?** I don't know off the top of my head whether Claude Code's harness has a frontmatter flag like `visible: false` or `internal: true` to keep a skill loaded but excluded from the `/` menu, or whether hiding requires moving the file out of `config/skills/`.

Three possibilities:
1. **Frontmatter flag exists** — add `visible: false` (or whatever the field is called) to the 19 hidden skills. Cleanest.
2. **No flag, must move files** — relocate hidden skills to `config/skills-internal/` or similar, update any code that loads them. Bigger change.
3. **Description-only signal** — prefix internal skill descriptions with "Internal — not for direct invocation." The harness still surfaces them, but Claude knows to route around them. Weakest, but no infra change.

This needs to be answered before any hiding work begins. **Action: research what mechanism Claude Code actually supports** — read the harness docs / settings.json / hook config, or test by adding a flag to one skill and observing the `/` menu.

## Decisions needed from user

1. **Confirm the 19 skills to hide** (6 power-user + 13 internal). Any you want kept visible?
2. **`rplan-trust` rename** — defer, do later, or decide now?
3. **Hiding mechanism** — want me to research what the harness supports, or do you already know?

## What comes next

Once the visible/hidden split is locked and the hiding mechanism is known:

- **Step A:** Apply hiding to the 19 skills (mechanism TBD)
- **Step B:** Description rewrite, but only for the 21 surviving visible skills. Of those 21, the audit table from Step 1 says ~10 currently fail the description rubric (prd, rplan, testing, scaffold-api, scaffold-library, scaffold-webapp, component, migration, documenting-release, plus borderline ones). Manageable scope.
- **Step C:** Verify slash menu reads cleanly to a fresh reader.

Total surviving work after pivot is **smaller** than the original 40-description audit, and far higher leverage.
