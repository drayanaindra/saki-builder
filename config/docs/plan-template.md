# Plan Template

Use this format for all non-trivial execution plans.

---

```markdown
# EXECUTION PLAN: [task name]

**Date:** YYYY-MM-DD
**Confidence:** [X]%
**Risk Score:** LOW / MED / HIGH
**Unknown Count:** [N] / 3 max

## Problem Statement

When [situation], I want to [action], so I can [outcome].

## Steps

| # | Action | Files | Risk | Assumption |
|---|--------|-------|------|------------|
| 1 | | | LOW/MED/HIGH | |
| 2 | | | | |

## Branch Points (pre-declared)

- Step N: If [condition] -> PAUSE (reason)
- Step M: If [condition] -> auto-handle with [approach]

## Unknowns (must be <= 3)

1. [LOW/MED/HIGH] [description] -> resolution: [strategy]
2. ...

## No-Gos

- Will NOT [explicit boundary]
- Will NOT [explicit boundary]

## Success Criteria

- [ ] [testable outcome]
- [ ] [testable outcome]

## Annotation Space

> Human: add notes, corrections, constraints here.
> Claude will revise plan based on annotations and re-score.

---
Status: [ ] Draft  [ ] Annotated  [ ] Approved  [ ] In Progress  [ ] Complete
```
