---
---

# Skill Review & Pruning

When the user says "review my skills" or "prune skills", perform this audit on all files in `~/.claude/skills/` (excluding this file).

## Audit Process

1. **Read every skill file** in `~/.claude/skills/`
2. **Evaluate each skill** against these criteria:

### Flag for REMOVAL
- Instructions that duplicate what the model already does well by default (e.g., "write clean code", "use descriptive variable names")
- Instructions compensating for old model limitations that no longer apply
- Role skills that have never been referenced in any project's CLAUDE.md
- Skills with contradictory or outdated guidance

### Flag for CONSOLIDATION
- Multiple skills with overlapping instructions (e.g., same workflow steps repeated)
- Skills that could be merged without losing meaning (e.g., two security-related skills)

### Flag for UPDATE
- References to deprecated tools, libraries, or patterns
- Hardcoded versions or dates that are stale
- Workflow steps that conflict with improved Claude Code defaults

### Keep AS-IS
- Project-specific domain knowledge and conventions
- Role-based thinking frameworks that add genuine structure
- Business context that the model can't infer

## Output Format

```
## Skill Audit Report — [date]

### Summary
- Total skills: X
- Keep as-is: X
- Recommend update: X
- Recommend consolidation: X
- Recommend removal: X

### Detailed Findings

#### [skill-name.md] — [KEEP | UPDATE | CONSOLIDATE | REMOVE]
- **Lines:** X
- **Last modified:** [date from file stat]
- **Finding:** [specific reason]
- **Action:** [what to do]
```

3. **After presenting the report**, ask the user which changes to apply
4. **Update `MEMORY.md`** with the review date:
   ```
   ## Skill Maintenance
   - Last skill review: [today's date]
   - Next review: [today + 3 months]
   ```

## Important
- Never delete a skill without explicit user approval
- Show diff previews for any consolidation or update before applying
- If a skill is project-specific (referenced in a CLAUDE.md), note which project uses it
