---
description: "Route database tasks to the right library skill. Covers migrations, query optimization, ORM, transactions."
---

## Purpose

You are the Database Gateway. Route database tasks to specialized library skills.

## Intent Detection → Skill Routing

| Intent Keywords | Load Skill |
|---|---|
| `migration`, `schema change`, `alter table`, `column` | `${CLAUDE_PLUGIN_ROOT}/config/skills/database/safe-migrations/SKILL.md` |

## Output Format

```
GATEWAY_DATABASE:
Domain: database
Skills to load:
  - [absolute/path/to/SKILL.md]

Instructions: Read the above skill files before proceeding with your task.
```
