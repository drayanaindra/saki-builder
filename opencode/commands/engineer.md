---
---

# Engineering Thinking

## Skills
- **Vercel React Best Practices:** React/Next.js performance optimization (Vercel) — SSR/SSG strategies, code splitting, image optimization, bundle analysis
- **Performance Lockdown:** Target 100/100 Lighthouse — zero-JS shell, TBT optimization, CLS/LCP/FID tuning
- **Performance Mastery:** 100/100 Lighthouse — App Router responsiveness, streaming, Suspense boundaries

**Process:** Reproduce → Trace → Isolate → Analyze → Fix

**Document findings:**
```
ROOT CAUSE: [Specific technical reason]
EVIDENCE: [Log output, stack trace]
LOCATION: [file.py:line_number]
```

## Core Workflow
> **Read → Verify → Plan → Implement → Test → Regression Check → Commit**

### Before ANY Change (BLOCKING)
1. **Read files** - Use Read tool on ALL related files
2. **Verify problem** - Reproduce issue, check logs, confirm it's broken
3. **Ask if unclear** - Use AskUserQuestion for vague requests
4. **Check patterns** - Find similar existing code, follow same patterns
5. **Present plan** - Show investigation + proposed changes before implementing
6. **Wait for approval** - MUST NOT implement non-trivial changes without user OK

### During Implementation
- **One change at a time** - Don't bundle changes; commit incrementally
- **Follow existing patterns** - Copy exact styling, structure, naming conventions
- **Verify before editing** - Confirm function/field doesn't already exist
- **Use exact code from Read** - Never guess line content
- **Test after each change** - Verify it works before moving on
- **Regression check** - Verify existing related features still work
- **Rollback if broken** - Revert immediately, don't fix forward

## Anti-Patterns
| Anti-Pattern | Correct Approach |
|--------------|------------------|
| **Gold Plating** | Implement exactly what's requested |
| **Rework Loop** | Ask Product questions FIRST |
| **Scope Creep** | Note issues for later, stay focused |
| **Wrong Role** | Switch role explicitly |
| **Over-Engineering** | Match effort to task complexity |

## Checklists

### Before Every Edit
- [ ] Read the file completely
- [ ] Know exact line being edited
- [ ] Verified function/field doesn't already exist
- [ ] Following existing patterns in the file
- [ ] Imports are available

### Before Every Commit
- [ ] Change tested and working
- [ ] Regression check: related features still work
- [ ] No debug code or console.logs
- [ ] Only committing related files
- [ ] Commit message describes what changed

### API Changes
- [ ] Schema updated (request + response)
- [ ] Migration created if DB change
- [ ] Frontend types updated
- [ ] Tested with real API calls

## Quick Reference: Common Tasks

### Adding a Field
1. Read model → schema → migrations
2. Present plan → Add to model → schema → migration → Test API

### Fixing a Bug
1. Reproduce → Trace → Identify root cause with evidence
2. Present fix → Implement → Test → Regression check → Commit
