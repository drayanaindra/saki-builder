---
name: plan
description: Create structured execution plan with confidence scoring and risk assessment. Use for any non-trivial task before implementation.
---

# Structured Planning

Create an execution plan following the template at ~/.claude/docs/plan-template.md.

## Process

1. **Research phase** (read-only):
   - Read all files related to the task
   - Identify existing patterns, dependencies, constraints
   - Document findings in `[task]-context.md`

2. **Plan construction**:
   - Fill in the plan template with concrete steps
   - Score each step by risk (LOW/MED/HIGH)
   - Identify assumptions for each step
   - List unknowns with resolution strategies
   - Declare branch points where execution might diverge
   - Define no-gos (what we will NOT do)
   - Set testable success criteria

3. **Confidence scoring**:
   - Calculate: (steps with no unknowns / total steps) * 100
   - Weight HIGH-risk steps 2x, MED-risk 1.5x
   - Must reach >= 90% before presenting for approval
   - If < 90%, resolve unknowns first

4. **Output**:
   - Write plan to `[task]-plan.md` in project root
   - Present summary in chat with confidence score
   - Wait for human annotation and approval

## Rules

- NEVER skip research phase
- NEVER present a plan with > 3 unknowns
- NEVER proceed to implementation without explicit approval
- If confidence < 70%, do more research instead of presenting plan
