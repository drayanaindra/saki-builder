import { mkdirSync, existsSync, readdirSync, readFileSync, statSync, writeFileSync } from "node:fs"
import { spawnSync } from "node:child_process"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"
import * as state from "./saki-state"

type EventValue = Record<string, unknown>
type ExtensionContext = {
  cwd: string
  sessionManager: { getSessionId(): string }
}
type EventResult = { continue?: boolean; additionalContext?: string }
type ExtensionApi = {
  on(
    event: string,
    handler: (
      payload: EventValue,
      context: ExtensionContext,
    ) => void | EventResult | Promise<void | EventResult>,
  ): void
}

type Slice = { status?: unknown; steps?: Record<string, unknown> }

const PLUGIN_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const HOOKS_ROOT = resolve(PLUGIN_ROOT, "config/hooks")
process.env.SAKI_PLUGIN_ROOT ??= PLUGIN_ROOT
const SECRET_RE = /\b(eyJ[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36,}|xoxb-[A-Za-z0-9-]{50,})\b/
const MAX_CONTINUE_RAW = Number(process.env.SAKI_OMP_MAX_CONTINUE ?? 5)
const MAX_CONTINUE = Number.isFinite(MAX_CONTINUE_RAW) && MAX_CONTINUE_RAW >= 0 ? MAX_CONTINUE_RAW : 5
const ACTIVE_MINUTES = Number(process.env.BUILD_GATE_ACTIVE_MINUTES ?? 45)

function normalized(value: unknown): string {
  return String(value ?? "").trim().toLowerCase().replace(/[\s_]+/g, "-")
}

function runGate(script: string, command: string): void {
  const path = resolve(HOOKS_ROOT, script)
  if (!existsSync(path)) throw new Error(`Missing SAKI safety gate: ${path}`)
  const result = spawnSync("bash", [path], {
    env: { ...process.env, CLAUDE_TOOL_INPUT_COMMAND: command },
    encoding: "utf8",
  })
  if (result.error) throw result.error
  if (result.status !== 0) {
    const message = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim()
    throw new Error(message || `${script} blocked the command.`)
  }
}

function readSlices(cwd: string): Slice[] {
  const tasks = resolve(cwd, "tasks")
  if (!existsSync(tasks)) return []
  let newest: { path: string; mtime: number } | undefined
  for (const name of readdirSync(tasks)) {
    if (!name.startsWith(".build-") || !name.endsWith("-state.json")) continue
    const path = join(tasks, name)
    let mtime: number
    try {
      mtime = statSync(path).mtimeMs
    } catch {
      continue
    }
    if (Date.now() - mtime > ACTIVE_MINUTES * 60_000) continue
    if (!newest || mtime > newest.mtime) newest = { path, mtime }
  }
  if (!newest) return []
  try {
    const parsed = JSON.parse(readFileSync(newest.path, "utf8")) as { slices?: unknown }
    if (Array.isArray(parsed.slices)) return parsed.slices as Slice[]
    if (parsed.slices && typeof parsed.slices === "object") return Object.values(parsed.slices) as Slice[]
  } catch {
    return []
  }
  return []
}

function sliceFinished(slice: Slice): boolean {
  const status = normalized(slice.status)
  if (status === "blocked") return true
  if (status !== "done") return false
  if (!slice.steps || typeof slice.steps !== "object") return true
  for (const key of ["qa", "reviewer"]) {
    if (key in slice.steps && normalized(slice.steps[key]) !== "done") return false
  }
  return true
}

function remainingSlices(cwd: string): number {
  return readSlices(cwd).filter((slice) => !sliceFinished(slice)).length
}

function continuationFile(cwd: string, sessionId: string): string {
  const safe = sessionId.replace(/[^A-Za-z0-9._-]/g, "") || "nosession"
  return resolve(cwd, "tasks", ".saki", `${safe}.continues`)
}

function continuationCount(cwd: string, sessionId: string, bump = false): number {
  const path = continuationFile(cwd, sessionId)
  let count = 0
  try {
    count = Number(readFileSync(path, "utf8").trim()) || 0
  } catch {
    count = 0
  }
  if (bump) {
    try {
      mkdirSync(dirname(path), { recursive: true })
      writeFileSync(path, String(count + 1))
    } catch {
      return MAX_CONTINUE
    }
  }
  return count
}

function commandFrom(payload: EventValue): string {
  const direct = payload.input
  if (direct && typeof direct === "object") {
    return String((direct as EventValue).command ?? "")
  }
  return String(payload.command ?? "")
}

function messageFrom(payload: EventValue): unknown {
  return payload.last_assistant_message ?? payload.message ?? payload.content
}

export default function sakiBuilder(pi: ExtensionApi): void {
  pi.on("session_start", (_event, context) => {
    state.start(context.cwd, context.sessionManager.getSessionId())
  })

  pi.on("tool_call", (payload) => {
    const toolName = String(payload.toolName ?? payload.tool_name ?? "")
    if (toolName !== "bash") return
    const command = commandFrom(payload)
    if (!command) return
    runGate("dangerous-command-guard.sh", command)
    if (SECRET_RE.test(command)) {
      throw new Error("Blocked: possible secret/token detected in command. Use environment variables.")
    }
    if (/\bgit\s+push\b/.test(command) && /\b(main|master)\b/.test(command)) {
      runGate("sonar-gate.sh", command)
      runGate("coverage-gate.sh", command)
    }
  })

  pi.on("tool_result", (payload, context) => {
    const toolName = String(payload.toolName ?? payload.tool_name ?? "")
    state.heartbeat(context.cwd, context.sessionManager.getSessionId(), toolName || undefined)
  })

  pi.on("session_stop", (payload, context) => {
    if (process.env.SAKI_AGENT_MODE !== "1") return
    const sessionId = context.sessionManager.getSessionId()
    const left = remainingSlices(context.cwd)
    if (left > 0) {
      const used = continuationCount(context.cwd, sessionId)
      console.warn(`SAKI-INCOMPLETE: ${left} slice(s) remaining (continue ${used}/${MAX_CONTINUE})`)
      if (used < MAX_CONTINUE) {
        continuationCount(context.cwd, sessionId, true)
        return {
          continue: true,
          additionalContext:
            `BUILD INCOMPLETE — ${left} unfinished slice(s) remain. Continue the next slice through `
            + `/saki-builder:rplan, /saki-builder:approved, /saki-builder:qa, and `
            + `/saki-builder:reviewer. Mark a slice done only after QA and review pass.`,
        }
      }
    }
    state.finish(context.cwd, sessionId, { message: messageFrom(payload) })
  })

  pi.on("session_shutdown", (_payload, context) => {
    state.finish(context.cwd, context.sessionManager.getSessionId())
  })
}
