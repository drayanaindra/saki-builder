# `docs/project-context.md` — the contract

The one hand-written context file in a project. It holds **only what no tool can derive**.

Consumers: `/saki-builder:init-env` creates it · `/saki-builder:wrap` Phase 2a refreshes it ·
`/saki-builder:rplan` and `/saki-builder:prd` read it during research.

---

## The one rule

**If a tool already derives it, it does not go in this file.** Anything mechanical has an owner that
refreshes itself; a second hand-written copy has no tiebreak when the two disagree. This is the same
rule `arch-check` states for its thresholds: *"The doc is the source of truth… never keep a second set
here"* (`config/skills/arch-check/SKILL.md:144-145`).

### Banned — with the owner that already covers it

| Never write here | Real owner | Refresh |
|---|---|---|
| God nodes / hub concepts | `graphify-out/GRAPH_REPORT.md` | automatic (post-commit + post-checkout) |
| Communities / bounded-context clusters | `graphify-out/GRAPH_REPORT.md` | automatic |
| Per-file or per-function descriptions | the code · `graphify explain <node>` | on demand |
| Module LOC, file counts, "this file is large" | `/saki-builder:arch-check` (`detect.sh`) | on demand |
| Architecture stage / tier, upgrade recommendations | `/saki-builder:arch-check` + `config/docs/modular-architecture.md` | on demand |
| Business narrative, personas, product goals | `tasks/roadmap.md`, `tasks/prd-*.md`, `.claude/personas/*.md` | per workflow |

A file that drifts into any of these rows has re-become the free-prose blob this contract exists to
prevent. Delete the section; do not "keep it in sync".

### The three sections that ARE allowed

1. **Topology** — the deployables and the edges *between* them. Graphify's extraction is AST/import-based
   and same-language, so it *"cannot see a network call, an HTTP route dispatch, a message-queue
   publish/subscribe, or any other cross-process boundary"* and reports **no path** between two services
   that are genuinely coupled at runtime (`config/docs/graphify-usage.md:143-152`). That blind spot is
   this section's entire job.
2. **Invariants** — rules that must hold across the system, each with where it is enforced. Not derivable:
   a constraint is visible in one file, but *that it is load-bearing* is not.
3. **Deliberate non-goals** — what is intentionally absent, so an agent does not helpfully add it back.

---

## Skeleton

```markdown
# Project Context — <project>

> Scope: ONLY what no tool can derive. God nodes, communities, module sizes and architecture
> tier are NOT here — `graphify-out/GRAPH_REPORT.md` and `/saki-builder:arch-check` own those.
> Last verified: <YYYY-MM-DD> (commit <sha>)

## Topology

| Deployable | Runtime | Entrypoint |
|---|---|---|
| `web` | Node 20 | `apps/web/server.ts:1` |
| `api` | Go 1.22 | `cmd/api/main.go:1` |

**Cross-boundary edges** (invisible to graphify — same-language AST extraction only):

| From | To | Transport | Call site | Handler |
|---|---|---|---|---|
| `web` | `api` | HTTP POST `/v1/orders` | `apps/web/lib/api.ts:88` | `internal/http/order.go:41` |
| `api` | `worker` | NATS `order.settled` | `internal/events/publish.go:23` | `cmd/worker/main.go:57` |

## Invariants

| Invariant | Enforced at | Breaks if |
|---|---|---|
| Every query is tenant-scoped | RLS policy `db/migrations/004_rls.sql:12` | a service connects as the owner role |
| Money is never mutated after settlement | `internal/ledger/entry.go:64` (append-only) | a direct UPDATE on `ledger_entries` |

## Deliberate non-goals

- No shared DB between `api` and `worker` — the queue is the only edge. Adding a direct read
  re-couples them.
```

A single-deployable project still earns its keep: one Topology row, the invariants, and the non-goals.
Nothing to say in a section → write `None` and keep the heading.

---

## Size ceiling — 100 lines (applies to `docs/project-context.md`, not to this contract)

Hard cap on the **artifact**. The ceiling is the anti-rot guard, not a budget: a `project-context.md`
over it has started restating derivable structure (the banned list above) or narrating history. Cut
back to the three sections.

Every row carries a `path:line` citation. An uncited topology edge or invariant is a claim, not
context — cite it or drop it.

---

## Grandfathering

A `docs/project-context.md` that **predates 0.25.0** was written to the old free-prose brief
(business context · architecture overview · key decisions). It is **off-contract, not an error**:

- Readers (`rplan`, `prd`) consume it as-is — they never validate its shape.
- The first `/saki-builder:wrap` Phase-2a trigger rewrites it in place to this contract, preserving any
  genuine topology/invariant content it already holds and dropping the rest.
- Nothing fails, warns, or blocks on an off-contract file. There is no migration to run.

---

## Rules

- **Derivable ⇒ banned.** The table above names the owner for each banned category; point at the owner
  instead of copying it.
- **Cite or drop.** Every topology edge and invariant carries `path:line`.
- **100 lines, hard.** Over the ceiling means the scope leaked.
- **Refresh on signal, never on schedule.** `/saki-builder:wrap` Phase 2a writes only when the diff shows
  a new deployable, a new cross-boundary edge, or a new invariant — an ordinary commit must not touch it.
- **Absence is fine.** Every reader skips silently when the file is missing. It is context, not a gate.
