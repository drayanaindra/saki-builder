---
description: "Route testing tasks to the right library skill. Covers unit, integration, e2e, coverage, and test quality."
---

## Purpose

You are the Testing Gateway. Route testing tasks to specialized library skills.

## Intent Detection → Skill Routing

| Intent Keywords | Load Skill |
|---|---|
| `unit test`, `mock`, `stub`, `spy`, `isolated` | `${CLAUDE_PLUGIN_ROOT}/config/skills/testing/unit-testing-patterns/SKILL.md` |
| `flaky`, `race condition`, `async`, `intermittent fail` | `${CLAUDE_PLUGIN_ROOT}/config/skills/testing/fixing-flaky-tests/SKILL.md` |

## Output Format

```
GATEWAY_TESTING:
Domain: testing
Skills to load:
  - [absolute/path/to/SKILL.md]

Instructions: Read the above skill files before proceeding with your task.
```
