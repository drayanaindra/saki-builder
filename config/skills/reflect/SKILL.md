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

3. **Promote confirmed patterns**:

   | Destination | When |
   |-------------|------|
   | `~/.claude/memory/patterns.md` | Confirmed pattern, reference only |
   | `~/.claude/CLAUDE.md` | Rule that must apply to all projects |
   | `~/.claude/skills/[role].md` | Role-specific behavior improvement |
   | Project `CLAUDE.md` | Project-specific rule |

4. **Write structured output to `~/.claude/memory/patterns.md`**:
   ```
   ## [Category]
   - [Pattern]: [description] (confidence: HIGH/MED, source: confirmed across N projects, date: [first seen])
   ```
   **IMPORTANT:** `patterns.md` is a public file. Never write specific project names in the `source` field. Use generic descriptions:
   - 1 project, 1 session → `source: 1 project`
   - 1 project, multiple sessions → `source: confirmed 2× on same project`
   - Multiple projects → `source: confirmed across N projects`

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
