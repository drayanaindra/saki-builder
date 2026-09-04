---
description: "RETIRED — the autonomous /saki-builder:pipeline has been replaced by the item-anchored stepwise flow. Use /saki-builder:roadmap → /saki-builder:add → /saki-builder:pickup <id> → /saki-builder:proto <id> → /saki-builder:build <id> (PRD-track) — or /saki-builder:add → /saki-builder:rplan (Plan-track) — instead. This tombstone only redirects; the full former pipeline is recoverable from git history."
---

# /saki-builder:pipeline — retired

The autonomous two-gate `/saki-builder:pipeline` has been **retired** in favour of the disciplined **stepwise flow**,
where every piece of work traces to an item on the roadmap and each command boundary is a natural review gate.

## Use this instead

```
/saki-builder:roadmap init      # scaffold the portfolio (once per project)
/saki-builder:add               # add + categorize an item (Epic·Feature·Improvement·Bug), route it  [Planned]

# PRD-track (Epic E<n> / Feature F<n>):
/saki-builder:pickup <id>       # seed /saki-builder:prd, loop /saki-builder:prd ↔ /saki-builder:prd-review to green (SHIP·READY)  [In-progress]
/saki-builder:proto  <id>       # UI preview — running it IS your PRD approval
/saki-builder:build  <id>       # autonomous slice-by-slice build → Shipped

# Plan-track (Improvement I<n> / Bug B<n>):
/saki-builder:rplan             # plan directly — no PRD, no proto
```

Why: the stepwise flow makes the discipline **structural** — `/saki-builder:add` is the one front door that
categorizes every item and routes it, so there is no cold-intent path — while keeping the same single human
gate (at proto) for PRD-track work, without a self-surviving mega-run.

## Recover the old pipeline

The former autonomous pipeline (the PRD ↔ review loop, both approval gates, and the state machine) is
preserved in git history:

```
git show <sha>:skill://pipeline      # see: chore(saki-builder): finalize two-gate pipeline before retirement
```

Its front half now lives in `/saki-builder:pickup`; its build half is the standalone `/saki-builder:build`;
its front-half Stop hook was renamed to `skill://saki-builder-runtime/hooks/pickup-completion-gate.sh`.
