/**
 * saki-state.ts — the opencode half of saki-builder's run-visibility contract.
 *
 * Writes the SAME `tasks/.saki/<session_id>.json` (+ `latest.json`) schema that the Claude Code
 * hook `config/hooks/agent-session.js` writes, so ONE supervisor poller serves both engines:
 *
 *   absent .................................. never started
 *   RUNNING + heartbeat_ts advancing ........ alive
 *   RUNNING + heartbeat_ts stale ............ hung (supervisor's judgement — see below)
 *   DONE | BLOCKED | NEEDS_INPUT | UNKNOWN .. finished
 *
 * Event mapping (opencode has no Stop-gate equivalent — see safety-hooks.ts for the honest gap):
 *   session.created     → RUNNING
 *   tool.execute.after  → heartbeat (throttled)
 *   session.error       → BLOCKED
 *   session.idle        → terminal
 *
 * FAIL-OPEN: every export swallows its own errors. A visibility probe must never break the run
 * it is watching. Nothing here throws.
 */
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "fs"
import { join } from "path"

const SCHEMA = 1
const TERMINAL = new Set(["DONE", "BLOCKED", "NEEDS_INPUT", "UNKNOWN"])

// Line-anchored, exactly as on the Claude side: the model narrates these words mid-sentence, and an
// unanchored match would classify narration as a real result.
// /g + take the LAST match — a final message may quote the template before the real outcome.
const RESULT_RE = /^[ \t]*SAKI-RESULT:[ \t]*(\{.*\})[ \t]*$/gm

export type SakiState = {
  schema: number
  status: "RUNNING" | "DONE" | "BLOCKED" | "NEEDS_INPUT" | "UNKNOWN"
  session_id: string
  engine: "opencode"
  pid?: number
  started_at?: string
  heartbeat_ts?: string
  ended_at?: string
  turns: number
  last_tool?: string | null
  task?: string | null
  artifacts?: string[]
  blocked_on?: string | null
  auto_resolved?: string[]
  next?: string | null
  cwd?: string
}

const enabled = () => process.env.SAKI_AGENT_MODE === "1"
const now = () => new Date().toISOString()
const dirFor = (cwd: string) => join(cwd, "tasks", ".saki")
const safeId = (id: string) => (id || "").replace(/[^A-Za-z0-9._-]/g, "") || "nosession"

export function read(cwd: string, sessionId: string): SakiState | null {
  try {
    return JSON.parse(readFileSync(join(dirFor(cwd), `${safeId(sessionId)}.json`), "utf8"))
  } catch {
    return null
  }
}

export function write(cwd: string, sessionId: string, state: SakiState): void {
  try {
    const dir = dirFor(cwd)
    mkdirSync(dir, { recursive: true })
    const body = JSON.stringify(state, null, 2)
    // Atomic: writeFileSync truncates first, so a polling supervisor can read a partial file.
    for (const name of [`${safeId(sessionId)}.json`, "latest.json"]) {
      const dest = join(dir, name)
      const tmp = `${dest}.${process.pid}.tmp`
      writeFileSync(tmp, body)
      renameSync(tmp, dest)
    }
  } catch {
    /* fail-open */
  }
}

export function start(cwd: string, sessionId: string): void {
  if (!enabled()) return
  const ts = now()
  write(cwd, sessionId, {
    schema: SCHEMA,
    status: "RUNNING",
    session_id: safeId(sessionId),
    engine: "opencode",
    pid: process.pid,
    started_at: ts,
    heartbeat_ts: ts,
    turns: 0,
    last_tool: null,
    task: process.env.SAKI_TASK_ID || null,
    cwd,
  })
}

export function heartbeat(cwd: string, sessionId: string, tool?: string): void {
  if (!enabled()) return
  const prev = read(cwd, sessionId)
  if (!prev || prev.status !== "RUNNING") return // never resurrect a finished session

  // Throttle so a long run doesn't thrash the disk — but never debounce the FIRST tick, or a run
  // whose tool calls are slower than the window looks like it never started working.
  const throttle = Number(process.env.SAKI_HEARTBEAT_MS ?? 2000)
  if (prev.turns > 0 && Number.isFinite(throttle) && throttle > 0) {
    const since = Date.now() - Date.parse(prev.heartbeat_ts || "")
    if (Number.isFinite(since) && since < throttle) return
  }

  write(cwd, sessionId, {
    ...prev,
    heartbeat_ts: now(),
    turns: prev.turns + 1,
    last_tool: tool ?? prev.last_tool ?? null,
  })
}

/** Parse the model's result line. Returns null when there is no line-anchored sentinel. */
export function parseResult(message: unknown) {
  if (typeof message !== "string") return null
  RESULT_RE.lastIndex = 0
  let m: RegExpExecArray | null
  let last: RegExpExecArray | null = null
  while ((m = RESULT_RE.exec(message)) !== null) last = m
  if (!last) return null
  try {
    const p = JSON.parse(last[1])
    if (!p || typeof p !== "object") return null
    const status = String(p.status || "").toUpperCase()
    return {
      status: (TERMINAL.has(status) ? status : "UNKNOWN") as SakiState["status"],
      task: p.task ?? null,
      artifacts: Array.isArray(p.artifacts) ? p.artifacts : [],
      blocked_on: p.blocked_on ?? null,
      auto_resolved: Array.isArray(p.auto_resolved) ? p.auto_resolved : [],
      next: p.next ?? null,
    }
  } catch {
    return null // a malformed sentinel is not a result — the caller falls back to UNKNOWN
  }
}

export function finish(
  cwd: string,
  sessionId: string,
  opts: { message?: unknown; status?: SakiState["status"]; blocked_on?: string } = {},
): void {
  if (!enabled()) return
  const prev = read(cwd, sessionId)
  if (prev && prev.status !== "RUNNING") return // already terminal — never overwrite the real outcome

  const result = parseResult(opts.message)
  const ts = now()
  // `...prev` FIRST — everything after it is the freshly computed outcome and must win. Spreading
  // prev last would let a stale `task` from session.created shadow the one the model just reported.
  write(cwd, sessionId, {
    ...(prev ?? {}),
    schema: SCHEMA,
    session_id: safeId(sessionId),
    engine: "opencode",
    turns: prev?.turns ?? 0,
    cwd,
    status: opts.status ?? result?.status ?? "UNKNOWN",
    task: result?.task ?? prev?.task ?? null,
    artifacts: result?.artifacts ?? [],
    blocked_on: opts.blocked_on ?? result?.blocked_on ?? null,
    auto_resolved: result?.auto_resolved ?? [],
    next: result?.next ?? null,
    ended_at: ts,
    heartbeat_ts: ts,
  } as SakiState)
}
