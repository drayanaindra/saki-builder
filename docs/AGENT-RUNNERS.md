# Running saki-builder under an agent runner

How to drive saki-builder from an external supervising agent — **Hermes Agent**, **OpenClaw**, CI, or
any orchestrator that spawns a coding session as a subprocess.

The problem this solves: a runner spawns `claude -p` (or `opencode run`) **in the background** and then
goes blind. Nothing tells it whether the run is working, hung, crashed, or never started, and at the end
it has only prose to classify. saki-builder fixes that by publishing its own lifecycle through hooks.

---

## 1. The contract: poll one file

Set `SAKI_AGENT_MODE=1` and saki-builder maintains **`<cwd>/tasks/.saki/latest.json`** for the whole life
of the run. Poll it — that is the entire integration.

| What you see | What it means | What to do |
|---|---|---|
| file absent | never started — spawn failed, wrong cwd, or plugin not enabled | check the spawn |
| `status:"RUNNING"`, `heartbeat_ts` advancing | alive and working | wait |
| `status:"RUNNING"`, `heartbeat_ts` older than your threshold | **hung** | kill and retry / escalate |
| `status` is terminal | finished | read `blocked_on` / `artifacts` |

`status` is one of exactly five values:

| `status` | Meaning |
|---|---|
| `RUNNING` | in flight |
| `DONE` | finished the task |
| `BLOCKED` | hit a guardrail or a hard failure — `blocked_on` says which |
| `NEEDS_INPUT` | needs a human decision, or ran out of turns — `blocked_on` holds the one question |
| `UNKNOWN` | ended without a parseable result (drift, crash, kill) |

### While running

```json
{
  "schema": 1,
  "status": "RUNNING",
  "session_id": "0f3c8a12-…",
  "pid": 48213,
  "started_at": "2026-08-06T09:11:02Z",
  "heartbeat_ts": "2026-08-06T09:13:47Z",
  "turns": 14,
  "last_tool": "Bash",
  "task": "build I7",
  "cwd": "/Users/you/work/shop"
}
```

### When finished

```json
{
  "schema": 1,
  "status": "DONE",
  "session_id": "0f3c8a12-…",
  "started_at": "2026-08-06T09:11:02Z",
  "ended_at": "2026-08-06T09:22:31Z",
  "turns": 41,
  "task": "build I7",
  "artifacts": ["tasks/i7-csv-export-plan.md", "backend/app/api/v1/orders.py"],
  "blocked_on": null,
  "auto_resolved": ["page size default → 500 — matches existing /invoices export"],
  "next": "/saki-builder:wrap",
  "stopped_by": "model_stop_reason",
  "exit_reason": null,
  "cwd": "/Users/you/work/shop"
}
```

**Concurrency.** Every session also writes `tasks/.saki/<session_id>.json`. If you captured `session_id`
from the stream-json `init` event, read that exact file; otherwise read `latest.json`. Two concurrent runs
in one repo never lose each other's state.

**`stop_hook_active`.** Terminal states also carry this flag. `true` means one of saki-builder's own
completion gates (`/build`, `/pickup`, `/prd-review`) blocked a stop and pushed the session back to work
at least once — so a `DONE` you see may be followed by more turns. Useful if you log run shapes.

> `stopped_by` is present in the schema for forward compatibility but is **not** emitted by current
> Claude Code builds, so a turn-limit exhaustion currently surfaces as `UNKNOWN`, not `NEEDS_INPUT`.
> Don't branch on `stopped_by` today.

**Which events write it**

| Hook event | Writes |
|---|---|
| `SessionStart` | `RUNNING`, `pid`, `started_at` — this is why *absence* is meaningful |
| `PostToolBatch` | `heartbeat_ts`, `turns++`, `last_tool` (throttled — see `SAKI_HEARTBEAT_MS`) |
| `Stop` | terminal status parsed from the model's `SAKI-RESULT:` line |
| `SessionEnd` | closes a still-`RUNNING` state via `exit_reason`, so a killed run can't look alive forever |
| `Notification` | opportunistic early `NEEDS_INPUT` — did not fire in a clean headless probe, so don't depend on it |

### ⚠ Staleness is YOUR judgement, not the run's

**No hook survives `kill -9`.** If a session is SIGKILLed, the OOM killer takes it, or the machine dies,
nothing can write a terminal status and the file stays `RUNNING` forever. That is irreducible.

So the supervisor owns the timeout. Pick a `SAKI_STALE_SECONDS` from your slowest legitimate tool call —
**300s is a sane default** (a long test suite or install can legitimately run several minutes between tool
batches; anything under ~120s will produce false kills). Treat `now - heartbeat_ts > SAKI_STALE_SECONDS`
as dead. `pid` is in the file if you want to confirm with a liveness check before killing.

---

## 2. Spawning a run

```bash
SAKI_AGENT_MODE=1 \
SAKI_TASK_ID="build I7" \
claude -p "/saki-builder:build I7" \
  --permission-mode acceptEdits \
  --output-format stream-json --verbose \
  </dev/null
```

- `</dev/null` is **required** — headless Claude waits on an open stdin otherwise.
- `--verbose` is **required** with `--output-format stream-json`.
- `SAKI_TASK_ID` is optional; it just labels `task` in the state file so your logs read well.

### Permission mode — and why the safety gates still hold

| Mode | Use when |
|---|---|
| `acceptEdits` | **default recommendation** — file edits flow, Bash still honours the allowlist |
| `bypassPermissions` | fully unattended runs where an allowlist prompt would deadlock |

`bypassPermissions` disables the *permission* layer, **not** the hook layer. saki-builder's `PreToolUse`
gates — `dangerous-command-guard.sh`, `coverage-gate.sh`, `format-staged.sh` — still fire and can still
deny a tool call (verified by probe). Permission mode is a convenience setting; the gates are the actual
guard. Do not disable the gates to make a runner quieter.

---

## 3. What agent mode changes in the session

With `SAKI_AGENT_MODE=1`, `instructions/agent-mode.md` is layered over the always-on core:

- **"human approves" is void.** The readiness gate is satisfied when the Blocking Evidence Set is empty;
  the session proceeds instead of waiting for an approval that will never come.
- **Forks are decided, not escalated.** The `AUTO-RESOLVED` ladder becomes the default for every
  reversible fork, and each decision is recorded in the plan file (not just chat) and echoed in
  `auto_resolved`.
- **Two things still stop the run:** a HIGH-tier irreversible action (DB migration, auth, delete, push)
  and a genuine intent question. Both emit `NEEDS_INPUT` with one specific question and **end the turn** —
  a stopped run is resumable, a hung one is not.
- **Guardrails are unchanged.** A Non-Goal, a `🔒 INVARIANT`, or an ABSOLUTE NO-GO is never crossed by an
  auto-decision; crossing one is a real `BLOCKED`.

Without the env var, nothing above applies and interactive sessions behave exactly as before.

---

## 4. Environment variables

| Variable | Default | Effect |
|---|---|---|
| `SAKI_AGENT_MODE` | unset | `1` enables agent mode + the state file. **Nothing else turns it on** — never sniffed |
| `SAKI_TASK_ID` | unset | label written to `task` in the state file |
| `SAKI_HEARTBEAT_MS` | `2000` | minimum gap between heartbeat writes; `0` disables the throttle |
| `SAKI_CORE_DISABLE` | unset | `1` suppresses all injected instructions |
| `BUILD_GATE_MAX_BLOCKS` | `5` | how many no-progress stops `/build` tolerates before letting the session end |
| `BUILD_GATE_ACTIVE_MINUTES` | `45` | how long a build manifest is considered live |
| `BUILD_GATE_DISABLE` | unset | `1` disables the `/build` completion gate |

> `SAKI_AGENT_MODE` is checked with **strict equality against `"1"`** — `true`, `yes`, and `0` all mean off.

---

## 5. Supervisor loop (copy-paste)

```bash
#!/usr/bin/env bash
# Spawn a saki-builder run and supervise it. Exits with the run's outcome.
set -u
REPO="$1"; TASK="$2"
STALE=${SAKI_STALE_SECONDS:-300}
STATE="$REPO/tasks/.saki/latest.json"

rm -f "$STATE"
( cd "$REPO" && SAKI_AGENT_MODE=1 SAKI_TASK_ID="$TASK" \
    claude -p "$TASK" --permission-mode acceptEdits \
    --output-format stream-json --verbose </dev/null >"$REPO/.saki-run.log" 2>&1 ) &
RUN_PID=$!

# Wait for the run to announce itself — absence past this point means it never started.
for _ in $(seq 30); do [ -f "$STATE" ] && break; sleep 1; done
[ -f "$STATE" ] || { echo "NEVER_STARTED"; kill $RUN_PID 2>/dev/null; exit 3; }

while :; do
  status=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['status'])" "$STATE" 2>/dev/null || echo READ_ERR)
  case "$status" in
    RUNNING|READ_ERR)
      age=$(python3 -c "
import json,sys,datetime
d=json.load(open(sys.argv[1]))
hb=datetime.datetime.fromisoformat(d['heartbeat_ts'].replace('Z','+00:00'))
print(int((datetime.datetime.now(datetime.timezone.utc)-hb).total_seconds()))" "$STATE" 2>/dev/null || echo 0)
      if [ "$age" -gt "$STALE" ]; then
        echo "HUNG (no heartbeat for ${age}s) — killing"; kill -9 $RUN_PID 2>/dev/null; exit 4
      fi
      sleep 5 ;;
    DONE)        echo "DONE";        exit 0 ;;
    BLOCKED)     echo "BLOCKED: $(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('blocked_on'))" "$STATE")"; exit 1 ;;
    NEEDS_INPUT) echo "NEEDS_INPUT: $(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('blocked_on'))" "$STATE")"; exit 2 ;;
    UNKNOWN)     echo "UNKNOWN — see .saki-run.log"; exit 5 ;;
  esac
done
```

---

## 6. Provisioning a fresh box

```bash
bash bin/agent-setup.sh            # idempotent, no TTY required
```

It adds the marketplace, installs and enables the plugin, and prints the exact spawn command. Re-running
is a no-op. Already have saki-builder installed? You don't need it.

---

## 7. opencode

`opencode run` gets the same `tasks/.saki/` schema, so **one supervisor loop serves both engines**.
Bridge the plugin into opencode once:

```bash
bash bin/opencode-bridge.sh        # installs skills, AGENTS.md, agents and the safety plugin
```

**One honest difference.** Claude Code's `Stop` hook can *deny* a stop and force the session to continue;
opencode has no equivalent — `session.idle` is an event, not a gate. The opencode plugin therefore writes
the terminal state and logs `SAKI-INCOMPLETE: <n> slices remaining` when work is left, and attempts a
bounded re-prompt (`SAKI_OC_MAX_CONTINUE`, default 5) rather than guaranteeing continuation. If your
workflow depends on the run being *forced* to completion, use headless Claude for that job.

---

## 8. Troubleshooting

| Symptom | Cause |
|---|---|
| no `tasks/.saki/` at all | `SAKI_AGENT_MODE` not `1`, or the plugin isn't enabled — check `claude plugin list` |
| file appears but never leaves `RUNNING` | run was SIGKILLed — see §1 staleness; use `SAKI_STALE_SECONDS` |
| `status:"UNKNOWN"` on a run that clearly worked | the model didn't end with a line-anchored `SAKI-RESULT:` line; check the tail of the log |
| session hangs forever with no output | missing `</dev/null` on the spawn |
| `--output-format stream-json` errors | add `--verbose` |
| hooks fire in interactive sessions too | expected — they short-circuit in the shell before node starts |
