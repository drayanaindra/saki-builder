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
   - [Pattern]: [description] (confidence: HIGH/MED, source: [projects], date: [first seen])
   ```

5. **Clean up**:
   - Remove duplicates from lessons-learned files
   - Archive promoted patterns (mark as promoted, don't delete)
   - Update MEMORY.md if key facts changed

## Rules

- Only promote patterns with evidence from multiple sessions
- Ask user before modifying CLAUDE.md or skills
- Never auto-promote to global rules without human approval
- Keep patterns.md organized by category, not chronologically
