---
name: pipeline
description: RETIRED — the autonomous /pipeline has been replaced by the epic-anchored stepwise flow. Use /saketek:roadmap → /saketek:epic → /saketek:pickup E<n> → /saketek:proto E<n> → /saketek:build E<n> instead. This tombstone only redirects; the full former pipeline is recoverable from git history.
---

# /pipeline — retired

The autonomous two-gate `/pipeline` has been **retired** in favour of the disciplined **stepwise flow**,
where every feature traces to an epic on the roadmap and each command boundary is a natural review gate.

## Use this instead

```
/saketek:roadmap init      # scaffold the epic portfolio (once per project)
/saketek:epic              # add an epic  (Goal · Job · User flow · Success signal)   [Planned]
/saketek:pickup E<n>       # seed /prd, loop /prd ↔ /prd-review to green (SHIP·READY)  [In-progress]
/saketek:proto  E<n>       # UI preview — running it IS your PRD approval
/saketek:build  E<n>       # autonomous slice-by-slice build → Shipped
```

Why: the stepwise flow makes the discipline **structural** — `/saketek:pickup` requires an epic, so there
is no cold-intent feature path — while keeping the same single human gate (at proto) without a
self-surviving mega-run.

## Recover the old pipeline

The former autonomous pipeline (the PRD ↔ review loop, both approval gates, and the state machine) is
preserved in git history:

```
git show <sha>:config/skills/pipeline/SKILL.md      # see: chore(saki-builder): finalize two-gate pipeline before retirement
```

Its front half now lives in `/saketek:pickup`; its build half is the standalone `/saketek:build`;
its front-half Stop hook was renamed to `config/hooks/pickup-completion-gate.sh`.
