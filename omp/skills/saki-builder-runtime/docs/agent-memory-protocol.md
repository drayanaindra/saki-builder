# Agent Memory Protocol

Applies to subagents (senior-pm, product-engineer, etc.) maintaining persistent memory across sessions. Each agent has its own dir: `~/.claude/agent-memory/<agent-name>/`.

## Memory types

- **user** — role, preferences, knowledge. Shapes future tone and detail level.
- **feedback** — corrections AND confirmations. Save what to keep doing, not just what to avoid.
- **project** — current initiatives, deadlines, decisions. These decay; convert relative dates to absolute.
- **reference** — pointers to external systems (Linear projects, dashboards, Slack channels).

## Save format

Each memory is its own file with frontmatter:

```markdown
---
name: {{memory name}}
description: {{specific one-line description used for relevance ranking}}
type: {{user|feedback|project|reference}}
---

{{content — for feedback/project: rule/fact, then **Why:** and **How to apply:** lines}}
```

Add a one-line pointer to `MEMORY.md` in the same dir: `- [Title](file.md) — one-line hook`. `MEMORY.md` is the index, not a store. Keep under 200 lines (truncated after).

## What NOT to save

- Code patterns, conventions, file paths, project structure → read from repo
- Git history, recent commits → `git log` / `git blame`
- Bug-fix recipes → live in code + commit messages
- Anything in CLAUDE.md
- Ephemeral task state → use plan/task tools instead

These hold even when the user asks. If they ask to save a summary, ask what was *surprising* — that's the memory worth keeping.

## When to save

- User correction ("don't", "stop X", "no not that") → feedback
- User confirmation ("yes exactly", "keep doing that") → feedback (quieter signal — watch for it)
- New facts about user role, project, external resource → user/project/reference
- User explicitly asks "remember this" → save immediately as best-fit type

## When to recall

- When memory feels relevant to the current task
- When user references prior conversation work
- MUST recall when user asks to check/recall/remember
- Don't recall if user says "ignore memory"

## Verify before recommending

A memory is a snapshot of when it was written.
- File path mentioned? Verify the file exists.
- Function/flag mentioned? Grep for it.
- User about to act? Verify current state first.

If memory conflicts with current code: trust the code. Update or remove the stale memory.

## Update vs create

Check for existing memory on the same topic before writing a new one. Update in place; don't duplicate. Remove memories that turn out wrong.

## Relation to plans/tasks

- Plans → in-flight implementation alignment
- Tasks → current-conversation step tracking
- Memory → only what should survive future conversations
