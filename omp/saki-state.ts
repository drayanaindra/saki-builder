import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs"
import { join } from "node:path"

const SCHEMA = 1
const TERMINAL = new Set(["DONE", "BLOCKED", "NEEDS_INPUT", "UNKNOWN"])
const RESULT_RE = /^[ \t]*SAKI-RESULT:[ \t]*(\{.*\})[ \t]*$/gm

export type OmpState = {
  schema: number
  status: "RUNNING" | "DONE" | "BLOCKED" | "NEEDS_INPUT" | "UNKNOWN"
  session_id: string
  engine: "omp"
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
  final?: boolean
}

const enabled = () => process.env.SAKI_AGENT_MODE === "1"
const now = () => new Date().toISOString()
const safeId = (id: string) => (id || "").replace(/[^A-Za-z0-9._-]/g, "") || "nosession"
const dirFor = (cwd: string) => join(cwd, "tasks", ".saki")

export function read(cwd: string, sessionId: string): OmpState | null {
  try {
    return JSON.parse(readFileSync(join(dirFor(cwd), `${safeId(sessionId)}.json`), "utf8")) as OmpState
  } catch {
    return null
  }
}

export function write(cwd: string, sessionId: string, state: OmpState): void {
  try {
    const dir = dirFor(cwd)
    mkdirSync(dir, { recursive: true })
    const body = JSON.stringify(state, null, 2)
    for (const name of [`${safeId(sessionId)}.json`, "latest.json"]) {
      const destination = join(dir, name)
      const temporary = `${destination}.${process.pid}.tmp`
      writeFileSync(temporary, body)
      renameSync(temporary, destination)
    }
  } catch {
    // Run visibility is fail-open: it must never break a coding session.
  }
}

export function start(cwd: string, sessionId: string): void {
  if (!enabled()) return
  const previous = read(cwd, sessionId)
  if (previous?.status === "RUNNING") {
    write(cwd, sessionId, { ...previous, heartbeat_ts: now() })
    return
  }
  const timestamp = now()
  write(cwd, sessionId, {
    schema: SCHEMA,
    status: "RUNNING",
    session_id: safeId(sessionId),
    engine: "omp",
    pid: process.pid,
    started_at: timestamp,
    heartbeat_ts: timestamp,
    turns: 0,
    last_tool: null,
    task: process.env.SAKI_TASK_ID || null,
    cwd,
  })
}

export function heartbeat(cwd: string, sessionId: string, tool?: string): void {
  if (!enabled()) return
  const previous = read(cwd, sessionId)
  if (!previous || previous.status !== "RUNNING" || previous.final) return
  const throttle = Number(process.env.SAKI_HEARTBEAT_MS ?? 2000)
  if (previous.turns > 0 && Number.isFinite(throttle) && throttle > 0) {
    const elapsed = Date.now() - Date.parse(previous.heartbeat_ts || "")
    if (Number.isFinite(elapsed) && elapsed < throttle) return
  }
  write(cwd, sessionId, {
    ...previous,
    heartbeat_ts: now(),
    turns: previous.turns + 1,
    last_tool: tool ?? previous.last_tool ?? null,
  })
}

export function parseResult(message: unknown): Partial<OmpState> | null {
  if (typeof message !== "string") return null
  RESULT_RE.lastIndex = 0
  let match: RegExpExecArray | null
  let last: RegExpExecArray | null = null
  while ((match = RESULT_RE.exec(message)) !== null) last = match
  if (!last) return null
  try {
    const parsed = JSON.parse(last[1]) as Record<string, unknown>
    const status = String(parsed.status || "").toUpperCase()
    return {
      status: (TERMINAL.has(status) ? status : "UNKNOWN") as OmpState["status"],
      task: typeof parsed.task === "string" ? parsed.task : null,
      artifacts: Array.isArray(parsed.artifacts) ? parsed.artifacts.filter((v): v is string => typeof v === "string") : [],
      blocked_on: typeof parsed.blocked_on === "string" ? parsed.blocked_on : null,
      auto_resolved: Array.isArray(parsed.auto_resolved)
        ? parsed.auto_resolved.filter((v): v is string => typeof v === "string")
        : [],
      next: typeof parsed.next === "string" ? parsed.next : null,
    }
  } catch {
    return null
  }
}

export function finish(
  cwd: string,
  sessionId: string,
  opts: { message?: unknown; status?: OmpState["status"]; blocked_on?: string } = {},
): void {
  if (!enabled()) return
  const previous = read(cwd, sessionId)
  if (previous && previous.status !== "RUNNING") return
  const result = parseResult(opts.message)
  const timestamp = now()
  write(cwd, sessionId, {
    ...(previous ?? {}),
    schema: SCHEMA,
    session_id: safeId(sessionId),
    engine: "omp",
    turns: previous?.turns ?? 0,
    cwd,
    status: opts.status ?? result?.status ?? "UNKNOWN",
    task: result?.task ?? previous?.task ?? null,
    artifacts: result?.artifacts ?? [],
    blocked_on: opts.blocked_on ?? result?.blocked_on ?? null,
    auto_resolved: result?.auto_resolved ?? [],
    next: result?.next ?? null,
    ended_at: timestamp,
    heartbeat_ts: timestamp,
    final: true,
  })
}
