---
description: "Cross-project learning - review lessons learned, promote confirmed patterns. Applies a behavior-change admission filter and enforces the auto-load budget (evict-to-make-room, never append-only) so patterns.md stays under its ceiling. Splits promotion between your private personal overlay (instant) and the MR-governed team baseline. Run weekly."
---

# Cross-Project Reflection

Review accumulated learnings and promote confirmed patterns.

## Process

1. **Read all lesson sources**:
   - Current project: `.claude/memory/lessons-learned.md`
   - Team baseline (read-only reference): `${CLAUDE_PLUGIN_ROOT}/memory/patterns.md` (+ `patterns-<topic>.md`) — or the saki-builder repo's `memory/` if you have it checked out
   - Personal overlay: `~/.claude/memory/patterns-personal.md`
   - Other projects: search `~/.claude/projects/*/memory/lessons-learned.md`

2. **Identify promotion candidates**:
   - Pattern appears 3+ times across sessions or 2+ projects
   - Correction was made and never reverted
   - Anti-pattern caused real problems (wasted time, bugs)

   **Admission filter — the behavior-change test.** Auto-loaded memory is context budget, not an archive. Before promoting, ask: *"If this line weren't in context next session, would what I actually do change?"* Promote ONLY if yes. Keep three buckets; reject the fourth:
   1. **Env / tool / skill facts the model can't derive** — a tool's quirk (RTK, the Bash tool), a custom skill's exact behavior, your infra's specific bugs, harness behavior. Highest value: the model has no other access to these.
   2. **Preferences / policies / decisions** — team conventions, STRICT directives, review gates, recut thresholds. Not knowledge — choices the model can't infer.
   3. **Corrections to a demonstrated recurring failure** — something the model knows abstractly but skips under pressure, that cost real time 2–3×.
   4. **REJECT — generic best-practice the model already applies by default**: e.g. "empty catch blocks are bad", "hard-reload for stuck loading", "use `is not None`", standard SQL/git/language facts. These spend always-on budget for ~zero behavior change. Also reject anything already stated in a CLAUDE.md / `instructions/core.md` rule (dedupe against it).

3. **Promote confirmed patterns — route by AUDIENCE first, then scope.**

   The loop is split so teammates never conflict on one file:
   - **Personal overlay** `~/.claude/memory/patterns-personal.md` — YOUR machine only, never pushed, injected every session by the core hook. Default home for anything project-specific-to-you, experimental, or < 3 confirmations. Write freely, no review.
   - **Team baseline** `memory/patterns*.md` in the saki-builder REPO — what everyone reads. GOVERNED: changed only via **MR** (PR review). Promote here ONLY a HIGH-confidence, cross-person, stack-portable pattern.
     - Have the saki-builder repo checked out → edit `memory/patterns.md` (or the matching `patterns-<topic>.md`) → commit on a branch → open an MR.
     - Only the plugin installed (read-only cache) → do NOT write the cache. Emit an **MR-ready fragment** (the `## [Category]` block in step 5) + the one-line instruction *"open an MR adding this to saki-builder `memory/patterns.md`"*, and also drop it in your personal overlay so you keep it locally.
   - **Skill / core-rule change** → the repo's `config/skills/<name>/SKILL.md` or `instructions/core.md`, via MR (never edit the installed cache).

   | Destination | When |
   |-------------|------|
   | `~/.claude/memory/patterns-personal.md` (personal, instant) | project-specific-to-you, experimental, or < 3 confirmations — **default** |
   | Team baseline `memory/patterns.md` (via MR) | cross-stack pattern confirmed 3+×, portable across Go/React/Python — **40k hard ceiling / 37k soft cap; evict to make room (step 4), never append-only** |
   | Team baseline `memory/patterns-<topic>.md` (via MR) | confirmed pattern tied to ONE stack (react/python/go/mcp/ai/ios) |
   | Repo `config/skills/<name>/SKILL.md` (via MR) | a skill-behavior improvement everyone should get |
   | `instructions/core.md` (via MR) | a rule that must apply to every session, all projects |

   **Routing decision tree** for each new pattern:
   1. Cross-person AND confirmed 3+×/2+ projects AND stack-portable? → team baseline `patterns.md` (MR)
   2. Confirmed but tied to one stack? → team baseline `patterns-<topic>.md` (MR)
   3. About how a skill/core rule behaves, everyone should get it? → repo skill / `instructions/core.md` (MR)
   4. Everything else (yours, experimental, project-local, < 3×)? → **personal overlay** (instant, no MR)

   **Stack → topic-file mapping** (team baseline): React/Next/Vite/TS → `patterns-react.md` · Python/FastAPI/SQLAlchemy → `patterns-python.md` · Go/Gin/pgx → `patterns-go.md` · MCP/Playwright → `patterns-mcp.md` · LLM/prompt/Whisper → `patterns-ai.md` · iOS/SwiftUI/Core Image → `patterns-ios.md`. A framework/language mention → topic file FIRST.

4. **Enforce the auto-load budget BEFORE you append** (team-baseline `patterns.md`, plus any `patterns-<topic>.md` / `patterns-personal.md` that is auto-loaded). These files are injected into every session, so they carry a hard ceiling of **40k chars** — measured in Unicode code points, NOT bytes (`→ × ≥ ≠` are 1 char but several bytes each). Measure with `python3 -c "import sys; print(len(open(sys.argv[1],encoding='utf-8').read()))" <file>`, never `wc -c`. Work to a **37k soft cap** so a routine promotion never trips the ceiling.

   Promotion is **make room, then add** — `/reflect` is NOT append-only for these files. If adding the new entry would cross 37k, evict first, in this order until back under cap:
   1. **Delete** entries that fail the step-2 admission filter (generic best-practice; or a duplicate of another entry / a CLAUDE.md rule).
   2. **Move** stack-specific entries to the matching `patterns-<topic>.md` (not auto-loaded).
   3. **Demote** stale low-value entries — profile: `source: 1 project` AND `confidence: MED` AND `date` older than ~4 months AND never re-confirmed — to the personal overlay or a topic file.
   4. **Merge** near-duplicates into one; **condense** the largest remaining verbose entries — tighten prose only, keeping every command/token/failure-mode and the `source`/`date`.

   Never silently delete a HIGH-confidence, still-relevant entry to make room — move or condense it instead. Note what you evicted in the reflection summary; the MR body then records the add and the evictions together.

5. **Write structured output to the chosen file**:
   ```
   ## [Category]
   - [Pattern]: [description] (confidence: HIGH/MED, source: confirmed across N projects, date: [first seen])
   ```
   **IMPORTANT:** Global memory files (`patterns.md`, `patterns-<topic>.md`) are public. Never write specific project names in the `source` field. Use generic descriptions:
   - 1 project, 1 session → `source: 1 project`
   - 1 project, multiple sessions → `source: confirmed 2× on same project`
   - Multiple projects → `source: confirmed across N projects`

   Project-local memory files (`<repo>/.claude/memory/patterns.md`) MAY use specific project context since they're scoped to that repo.

6. **Clean up**:
   - Remove duplicates from lessons-learned files
   - Archive promoted patterns (mark as promoted, don't delete)
   - Update MEMORY.md if key facts changed

7. **Sync the team baseline** (only if you edited the repo's `memory/`):
   - Personal-overlay writes need NO sync — `~/.claude/memory/patterns-personal.md` lives on your machine, never in the repo, and is injected each session.
   - Team-baseline edits go through review: run `/saki-builder:sync`, which commits them on a branch and opens (or points you at) an MR — **never a direct push to `main`**. That MR is the governance gate that keeps the shared baseline curated.

## Rules

- Only promote patterns with evidence from multiple sessions
- Every promoted line must pass the behavior-change admission filter (step 2) — reject generic best-practice the model already applies by default, and dedupe against existing CLAUDE.md / core rules
- Auto-loaded files (`patterns.md`, imported `patterns-<topic>.md`, `patterns-personal.md`) are budget-capped: promotion is make-room-then-add, never append-only — enforce the 37k soft cap (step 4) every run
- Ask user before modifying CLAUDE.md or skills
- Never auto-promote to global rules without human approval
- Keep patterns.md organized by category, not chronologically
