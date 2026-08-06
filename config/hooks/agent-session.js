#!/usr/bin/env node
'use strict'
// saki-builder — publish this session's lifecycle so a supervising agent can SEE a backgrounded run.
//
// Why: Hermes Agent / OpenClaw spawn `claude -p` in the background. A signal written only at Stop
// answers "what happened" but never "is it still alive", so the supervisor cannot separate
// working / hung / crashed / never-spawned. This hook publishes a state file that exists for the
// WHOLE lifetime of the run:
//
//   SessionStart   → status RUNNING  (so ABSENCE of the file now means "never started")
//   PostToolBatch  → heartbeat tick  (so LIVENESS is observable while it runs)
//   Stop           → terminal status parsed from the model's SAKI-RESULT: line
//   SessionEnd     → close out a still-RUNNING state (a killed run never leaves a stale RUNNING)
//
// Written to <cwd>/tasks/.saki/<session_id>.json, mirrored to <cwd>/tasks/.saki/latest.json.
// A supervisor polls latest.json: absent = never started · RUNNING + advancing heartbeat_ts = alive ·
// RUNNING + stale heartbeat_ts = hung · terminal = done. Staleness is the SUPERVISOR's judgement —
// no hook survives `kill -9`, so the run cannot report its own death.
//
// FAIL-OPEN, ALWAYS: every path exits 0 with EMPTY stdout. This hook observes; it never gates.
// PostToolBatch and Stop both support decision:"block" — we deliberately never emit it, because a
// liveness probe that can halt the run it measures is a new failure mode, not a feature.
//
// Opt-in: SAKI_AGENT_MODE=1 only (never sniffed — command hooks already run without a controlling
// terminal in ordinary interactive sessions, so TTY detection would fire on every session).
// Tunables: SAKI_HEARTBEAT_MS (default 2000), SAKI_TASK_ID (label for the supervisor).

const fs = require('fs')
const path = require('path')

const SCHEMA = 1
const TERMINAL = new Set(['DONE', 'BLOCKED', 'NEEDS_INPUT', 'UNKNOWN'])

// Line-anchored on purpose: the model narrates the same words mid-sentence ("...so I would emit
// SAKI-RESULT: ..."), and an unanchored match would classify narration as a real result.
// /g so we can take the LAST match: agent-mode.md tells the model the result line comes last, and a
// final message may legitimately quote the template earlier ("emit SAKI-RESULT: {...}") before
// reporting the real outcome. Taking the first would let a recited example outrank the truth.
const RESULT_RE = /^[ \t]*SAKI-RESULT:[ \t]*(\{.*\})[ \t]*$/gm

const now = () => new Date().toISOString()

function stateDir (cwd) {
  return path.join(cwd || process.cwd(), 'tasks', '.saki')
}

function readState (dir, sessionId) {
  try {
    return JSON.parse(fs.readFileSync(path.join(dir, `${sessionId}.json`), 'utf8'))
  } catch (_e) {
    return null
  }
}

// Atomic: write to a temp file then rename. A supervisor polls latest.json on a timer, and
// writeFileSync truncates before it writes — without the rename it can read an empty or half-written
// file and mistake it for a crash. rename(2) is atomic on the same filesystem.
function writeState (dir, sessionId, state) {
  fs.mkdirSync(dir, { recursive: true })
  const body = JSON.stringify(state, null, 2)
  for (const name of [`${sessionId}.json`, 'latest.json']) {
    const dest = path.join(dir, name)
    const tmp = `${dest}.${process.pid}.tmp`
    fs.writeFileSync(tmp, body)
    fs.renameSync(tmp, dest)
  }
}

// Parse the model's result line. Returns null when there is no line-anchored sentinel.
function parseResult (message) {
  if (typeof message !== 'string') return null
  RESULT_RE.lastIndex = 0
  let m, last = null
  while ((m = RESULT_RE.exec(message)) !== null) last = m   // take the LAST sentinel, not the first
  if (!last) return null
  let parsed
  try {
    parsed = JSON.parse(last[1])
  } catch (_e) {
    return null // a malformed sentinel is not a result — the caller falls back to UNKNOWN
  }
  if (!parsed || typeof parsed !== 'object') return null
  const status = String(parsed.status || '').toUpperCase()
  return {
    status: TERMINAL.has(status) ? status : 'UNKNOWN',
    task: parsed.task,
    artifacts: Array.isArray(parsed.artifacts) ? parsed.artifacts : [],
    blocked_on: parsed.blocked_on ?? null,
    auto_resolved: Array.isArray(parsed.auto_resolved) ? parsed.auto_resolved : [],
    next: parsed.next ?? null
  }
}

function onSessionStart (dir, sessionId, payload) {
  // SessionStart fires again on `compact` (and `resume`), which is routine mid-run for a long
  // autonomous build. Rewriting here would reset turns to 0, move started_at forward, and overwrite
  // task with the literal source string — i.e. the progress record would rewind while the run works.
  const prev = readState(dir, sessionId)
  if (prev && prev.status === 'RUNNING') {
    return writeState(dir, sessionId, { ...prev, heartbeat_ts: now() })
  }

  const ts = now()
  writeState(dir, sessionId, {
    schema: SCHEMA,
    status: 'RUNNING',
    session_id: sessionId,
    engine: 'claude',      // opencode writes 'opencode' into the same schema — one poller, both engines
    pid: process.ppid,
    started_at: ts,
    heartbeat_ts: ts,
    turns: 0,
    last_tool: null,
    task: process.env.SAKI_TASK_ID || payload.source || null,
    cwd: payload.cwd || process.cwd()
  })
}

function onHeartbeat (dir, sessionId, payload) {
  const prev = readState(dir, sessionId)
  if (!prev) return
  // A tool batch running AFTER a terminal Stop is proof the session did not actually end: one of the
  // sibling completion gates (build/pickup/prd-review) returned decision:"block" and pushed the model
  // back to work. Those gates run BEFORE us in the Stop array and we cannot see their verdict, so the
  // terminal write we made was provisional. Resurrect it — otherwise the heartbeat dies exactly on the
  // flagship `/build` run the gates exist for, and the supervisor reads a working run as finished.
  // `final` is set only by SessionEnd, where the process really is gone; that is never resurrected.
  if (prev.final) return
  if (prev.status !== 'RUNNING') {
    return writeState(dir, sessionId, {
      ...prev,
      status: 'RUNNING',
      resumed_after_stop: (prev.resumed_after_stop || 0) + 1,
      ended_at: null,
      heartbeat_ts: now(),
      turns: prev.turns + 1,
      last_tool: payload.tool_name || prev.last_tool
    })
  }

  // Throttle so a long build doesn't thrash the disk — but never debounce the FIRST tick, or a
  // run whose batches are slower than the window would look like it never started working.
  const throttle = Number(process.env.SAKI_HEARTBEAT_MS ?? 2000)
  if (prev.turns > 0 && Number.isFinite(throttle) && throttle > 0) {
    const since = Date.now() - Date.parse(prev.heartbeat_ts)
    if (Number.isFinite(since) && since < throttle) return
  }

  const calls = Array.isArray(payload.tool_calls) ? payload.tool_calls : []
  const last = calls.length ? calls[calls.length - 1] : null
  writeState(dir, sessionId, {
    ...prev,
    heartbeat_ts: now(),
    turns: prev.turns + 1,
    last_tool: (last && (last.tool_name || last.name)) || payload.tool_name || prev.last_tool
  })
}

function onStop (dir, sessionId, payload) {
  const prev = readState(dir, sessionId) || { schema: SCHEMA, session_id: sessionId, turns: 0 }
  const result = parseResult(payload.last_assistant_message)
  const ts = now()

  // No parseable sentinel is genuinely UNKNOWN — except a turn-limit exhaustion, which is the one
  // no-sentinel case we CAN name: the run was cut off mid-work and wants another turn.
  // NOTE: `stopped_by` is documented for Stop but is ABSENT from the live payload on current builds
  // (observed keys: cwd, effort, hook_event_name, last_assistant_message, permission_mode, prompt_id,
  // session_id, stop_hook_active, transcript_path). The branch is kept because it is forward-compatible
  // and costs nothing — when the field is missing we simply fall through to UNKNOWN, which is honest.
  let status = result ? result.status : 'UNKNOWN'
  if (!result && payload.stopped_by === 'turn_limit') status = 'NEEDS_INPUT'

  writeState(dir, sessionId, {
    ...prev,
    schema: SCHEMA,
    status,
    task: (result && result.task) || prev.task || null,
    artifacts: (result && result.artifacts) || [],
    blocked_on: (result && result.blocked_on) ?? null,
    auto_resolved: (result && result.auto_resolved) || [],
    next: (result && result.next) ?? null,
    stopped_by: payload.stopped_by ?? null,
    // TRUE when a sibling Stop gate (build/pickup/prd-review completion) blocked this stop and pushed
    // the session back to work. A supervisor seeing a terminal status with this set knows the run was
    // held open at least once — i.e. "finished" here may still be followed by more turns.
    stop_hook_active: payload.stop_hook_active === true,
    ended_at: ts,
    heartbeat_ts: ts
  })
}

function onSessionEnd (dir, sessionId, payload) {
  const prev = readState(dir, sessionId)
  if (!prev) return
  if (prev.status !== 'RUNNING') {
    // Stop already wrote the real outcome — keep it, but seal it so a stray later event can't reopen it.
    return writeState(dir, sessionId, { ...prev, final: true, exit_reason: payload.exit_reason ?? null })
  }

  const ts = now()
  writeState(dir, sessionId, {
    ...prev,
    // The session died without Stop ever running (kill, crash, abort). `prompt_input_exit` is the
    // one exit_reason that means "waiting on a human", not "lost".
    status: payload.exit_reason === 'prompt_input_exit' ? 'NEEDS_INPUT' : 'UNKNOWN',
    exit_reason: payload.exit_reason ?? null,
    final: true,           // the process is gone — nothing may resurrect this
    ended_at: ts,
    heartbeat_ts: ts
  })
}

function main () {
  if (process.env.SAKI_AGENT_MODE !== '1') return

  let raw = ''
  try {
    raw = fs.readFileSync(0, 'utf8')
  } catch (_e) {
    return
  }

  let payload
  try {
    payload = JSON.parse(raw)
  } catch (_e) {
    return
  }
  if (!payload || typeof payload !== 'object') return

  // A subagent must never overwrite its parent's state file.
  if (payload.agent_id || payload.agent_type) return

  const sessionId = String(payload.session_id || '').replace(/[^A-Za-z0-9._-]/g, '') || 'nosession'
  const dir = stateDir(payload.cwd)

  switch (payload.hook_event_name) {
    case 'SessionStart': return onSessionStart(dir, sessionId, payload)
    case 'PostToolBatch':
    case 'PostToolUse': return onHeartbeat(dir, sessionId, payload)
    case 'Stop': return onStop(dir, sessionId, payload)
    case 'SessionEnd': return onSessionEnd(dir, sessionId, payload)
    case 'Notification': {
      // Opportunistic only — this event did not fire in a clean headless probe, so nothing depends
      // on it. When it does fire for an input prompt, it is the earliest possible NEEDS_INPUT signal.
      const t = payload.notification_type
      if (t !== 'agent_needs_input' && t !== 'idle_prompt') return
      const prev = readState(dir, sessionId)
      if (!prev || prev.status !== 'RUNNING') return
      return writeState(dir, sessionId, {
        ...prev,
        status: 'NEEDS_INPUT',
        blocked_on: payload.message || 'session is waiting for input',
        heartbeat_ts: now()
      })
    }
    default:
  }
}

try {
  main()
} catch (_e) {
  /* fail-open */
}
process.exit(0) // always allow; never print
