---
name: gateway-api
description: Route API design/implementation tasks to the right library skill.
type: gateway
tier: core
domains: [api, rest, graphql]
trigger: "REST API, GraphQL, endpoint, route, OpenAPI, Swagger, webhook, versioning, pagination"
user-invocable: false
---

## Purpose

You are the API Gateway. Route API tasks to specialized library skills.

## Intent Detection → Skill Routing

| Intent Keywords | Load Skill |
|---|---|
| `validation`, `sanitize`, `input`, `schema` | `skill://input-validation` |

## Output Format

```
GATEWAY_API:
Domain: api
Skills to load:
  - [absolute/path/to/SKILL.md]

Instructions: Read the above skill files before proceeding with your task.
```
