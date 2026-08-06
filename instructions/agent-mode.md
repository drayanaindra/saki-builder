# saki-builder — agent mode (autonomous runner)

**This section OVERRIDES the Readiness Gate and Next Actions sections of the always-on core above.**
It is injected only when `SAKI_AGENT_MODE=1` — i.e. this session was spawned by an agent runner
(Hermes Agent, OpenClaw, CI) via `claude -p` / `opencode run`. **There is no human at the keyboard.**

## Approval — nobody is going to approve

The core's Readiness Gate ends "…Unknowns ≤ 3, human approves." In agent mode that clause is **void**:
the gate is satisfied when the **Blocking Evidence Set is empty**, and you proceed. Do not wait, do not
ask "shall I continue", do not end a turn holding a question you could have answered from the code.

## Forks — decide, and leave a record

Branch Points §2 (the AUTO-RESOLVED ladder) is the **default** path for every fork, including ones §3
would send to a human. Take the stated lean → serve the acceptance criteria → pick the simplest
reversible option. **Record each decision in the plan/PRD file** (not just in chat — chat scrolls away
and no human will read it) and list it in `auto_resolved` of your result line.

§3 still applies to exactly two things, and for these you **stop** rather than idle-wait:
a **HIGH-tier irreversible action** (DB migration, auth change, delete, push) and a genuine
**intent question** no file can answer. Emit `"status":"NEEDS_INPUT"` with the one specific question in
`blocked_on`, then end the turn. A stopped run is resumable; a hung one is not.

## Guardrails are unchanged

§4 holds exactly as written. A Non-Goal, a `🔒 INVARIANT`, or an ABSOLUTE NO-GO may **never** be crossed
by an AUTO-RESOLVED decision. Crossing one is the genuine `BLOCKED:` — emit `"status":"BLOCKED"`.
Secrets rules (core § Secrets) are likewise unchanged: never put a credential in the result line.

## Result contract — replaces the `--- DONE ---` Next Actions block

End your **final** message with one line, at line start, nothing after it:

```
SAKI-RESULT: {"status":"DONE","task":"<what you were asked to do>","artifacts":["path",...],"blocked_on":null,"auto_resolved":["<question> → <decision> — <why>"],"next":"<the command a human would run next, or null>"}
```

- `status` — `DONE` (finished) · `BLOCKED` (guardrail//hard failure, `blocked_on` says which) ·
  `NEEDS_INPUT` (the two §3 cases above, `blocked_on` holds the ONE question).
- One line, valid JSON, no fences, no trailing prose. The supervisor matches it anchored to line start,
  so never write `SAKI-RESULT:` mid-sentence when narrating.
- A `tasks/.saki/latest.json` file is written for you by the lifecycle hook — you do **not** write it.

The human-facing `--- DONE ---` / `Next actions:` block above is optional in agent mode; the result line
is not. If you emit both, the result line comes last.
