---
name: reflect
description: Cross-project learning - review lessons learned, promote confirmed patterns to global config. Run weekly.
---

# Cross-Project Reflection

Review accumulated learnings and promote confirmed patterns.

## Process

1. **Read all lesson sources**:
   - Current project: `.claude/memory/lessons-learned.md`
   - Global patterns: `~/.claude/memory/patterns.md`
   - Other projects: search `~/.claude/projects/*/memory/lessons-learned.md`

2. **Identify promotion candidates**:
   - Pattern appears 3+ times across sessions or 2+ projects
   - Correction was made and never reverted
   - Anti-pattern caused real problems (wasted time, bugs)

3. **Promote confirmed patterns** — route by scope, not just confidence:

   | Destination | When |
   |-------------|------|
   | `~/.claude/CLAUDE.md` | Rule that must apply to all projects (binding behavior across all stacks) |
   | `~/.claude/skills/[skill]/SKILL.md` | Skill-specific behavior improvement (global skill change) |
   | `~/.claude/memory/patterns.md` | Generic + stack-portable pattern (recurs across any project in that stack: Go, React, Python, etc.) |
   | `~/.claude/memory/patterns-<topic>.md` | Niche stack-specific pattern (only fires on one stack — e.g. iOS/SwiftUI/Core Image → `patterns-ios.md`). Create a new topic file when 5+ entries accumulate for one niche stack and add a pointer in `patterns.md`. |
   | Project `<repo>/.claude/memory/patterns.md` | Project-specific pattern (cited as "same project N×", not portable). Only when project exists locally; otherwise fall back to a topic file. |
   | Project `<repo>/.claude/skills/[skill]/SKILL.md` | Project-specific skill override (project-tailored review/qa/rplan-review variant) |
   | Project `<repo>/CLAUDE.md` | Project-specific rule (always-on for that repo) |

   **Routing decision tree** for each new pattern:
   1. Is it about *how Claude works* (workflow, tone, gates)? → `CLAUDE.md` or skill file
   2. Is it portable across any project in this stack? → global `patterns.md`
   3. Does it only fire on one niche stack (e.g. iOS image processing)? → `patterns-<topic>.md`
   4. Cited as "same project N×" and project lives locally? → that project's `.claude/memory/patterns.md`
   5. Project not local but pattern is stack-specific? → topic file (`patterns-<topic>.md`)

4. **Write structured output to the chosen file**:
   ```
   ## [Category]
   - [Pattern]: [description] (confidence: HIGH/MED, source: confirmed across N projects, date: [first seen])
   ```
   **IMPORTANT:** Global memory files (`patterns.md`, `patterns-<topic>.md`) are public. Never write specific project names in the `source` field. Use generic descriptions:
   - 1 project, 1 session → `source: 1 project`
   - 1 project, multiple sessions → `source: confirmed 2× on same project`
   - Multiple projects → `source: confirmed across N projects`

   Project-local memory files (`<repo>/.claude/memory/patterns.md`) MAY use specific project context since they're scoped to that repo.

5. **Clean up**:
   - Remove duplicates from lessons-learned files
   - Archive promoted patterns (mark as promoted, don't delete)
   - Update MEMORY.md if key facts changed

6. **Sync to repo** (if claude-config is installed):
   - After writing to `~/.claude/memory/patterns.md`, remind user to run:
     ```bash
     cd ~/claude-config && ./sync.sh
     ```
   - This commits and pushes the updated learnings so other machines stay in sync.

## Rules

- Only promote patterns with evidence from multiple sessions
- Ask user before modifying CLAUDE.md or skills
- Never auto-promote to global rules without human approval
- Keep patterns.md organized by category, not chronologically
