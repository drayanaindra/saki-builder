---
name: retro
description: Session retrospective - extract learnings from corrections, failures, and successes. Run before ending long sessions.
---

# Session Retrospective

Review the current session and extract learnings.

## Process

1. **Scan session** for:
   - Corrections the user made (HIGH confidence learning)
   - Assumptions that turned out wrong
   - Approaches that failed before finding the right one
   - Patterns that worked well
   - Tools or commands that were useful

2. **Classify each learning**:
   - **CORRECTION** (HIGH): User explicitly corrected a behavior
   - **DISCOVERY** (MED): Found something non-obvious through investigation
   - **PATTERN** (MED): Recurring approach that proved effective
   - **ANTI-PATTERN** (HIGH): Approach that failed and should be avoided

3. **Write to memory**:
   - Append to project memory: `.claude/memory/lessons-learned.md`
   - Format:
     ```
     ## [Date] - [Session Topic]
     - [CORRECTION] [what was wrong] -> [what's correct]
     - [DISCOVERY] [what was found]
     - [PATTERN] [what works]
     - [ANTI-PATTERN] [what to avoid]
     ```

4. **Check for promotion candidates**:
   - If a learning appears 3+ times across sessions -> flag for `/reflect`
   - If a correction is about a global behavior (not project-specific) -> flag for global promotion

## Rules

- Be concise: one line per learning
- Only record non-obvious learnings (skip things Claude already knows)
- Never record session-specific details (task names, file paths that won't be relevant later)
- Focus on reusable patterns and corrections
