---
description: "RETIRED — the autonomous /pipeline has been replaced by the item-anchored stepwise flow. Use /roadmap → /add → /pickup <id> → /proto <id> → /build <id> (PRD-track) — or /add → /rplan (Plan-track) — instead. This tombstone only redirects; the full former pipeline is recoverable from git history."
---

# /pipeline — retired

The autonomous two-gate `/pipeline` has been **retired** in favour of the disciplined **stepwise flow**,
where every piece of work traces to an item on the roadmap and each command boundary is a natural review gate.

## Use this instead

```
/roadmap init      # scaffold the portfolio (once per project)
/add               # add + categorize an item (Epic·Feature·Improvement·Bug), route it  [Planned]

# PRD-track (Epic E<n> / Feature F<n>):
/pickup <id>       # seed /prd, loop /prd ↔ /prd-review to green (SHIP·READY)  [In-progress]
/proto  <id>       # UI preview — running it IS your PRD approval
/build  <id>       # autonomous slice-by-slice build → Shipped

# Plan-track (Improvement I<n> / Bug B<n>):
/rplan             # plan directly — no PRD, no proto
```

Why: the stepwise flow makes the discipline **structural** — `/add` is the one front door that
categorizes every item and routes it, so there is no cold-intent path — while keeping the same single human
gate (at proto) for PRD-track work, without a self-surviving mega-run.

## Recover the old pipeline

The former autonomous pipeline (the PRD ↔ review loop, both approval gates, and the state machine) is
preserved in git history:

```
git show <sha>:config/skills/pipeline/SKILL.md      # see: chore(saki-builder): finalize two-gate pipeline before retirement
```

Its front half now lives in `/pickup`; its build half is the standalone `/build`;
its front-half Stop hook was renamed to `config/hooks/pickup-completion-gate.sh`.
