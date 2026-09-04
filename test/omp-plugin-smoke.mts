import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"

const cwd = mkdtempSync(join(tmpdir(), "saki-omp-") )
process.env.SAKI_AGENT_MODE = "1"
process.env.SAKI_HEARTBEAT_MS = "0"

try {
  const events = new Map<string, (payload: Record<string, unknown>, context: any) => unknown>()
  const { default: extension } = await import("../omp/extension")
  extension({
    on(event, handler) {
      events.set(event, handler)
    },
  })

  const context = { cwd, sessionManager: { getSessionId: () => "omp smoke/session" } }
  await events.get("session_start")?.({}, context)
  const running = JSON.parse(readFileSync(join(cwd, "tasks/.saki/latest.json"), "utf8"))
  assert.equal(running.status, "RUNNING")
  assert.equal(running.engine, "omp")
  await assert.rejects(
    async () => {
      await events.get("tool_call")?.({ toolName: "bash", input: { command: "rm -rf /" } }, context)
    },
    /Destructive rm -rf/,
  )
  await events.get("tool_call")?.({ toolName: "bash", input: { command: "printf safe" } }, context)
  await events.get("tool_result")?.({ toolName: "bash" }, context)

  writeFileSync(
    join(cwd, "tasks/.build-smoke-state.json"),
    JSON.stringify({ slices: [{ status: "in_progress" }] }),
  )
  const continuation = (await events.get("session_stop")?.({}, context)) as
    | { continue?: boolean; additionalContext?: string }
    | undefined
  assert.equal(continuation?.continue, true)
  assert.match(String(continuation?.additionalContext), /BUILD INCOMPLETE/)
  rmSync(join(cwd, "tasks/.build-smoke-state.json"))

  await events.get("session_stop")?.(
    { last_assistant_message: 'SAKI-RESULT: {"status":"DONE","task":"smoke","artifacts":["ok"]}' },
    context,
  )
  const finished = JSON.parse(readFileSync(join(cwd, "tasks/.saki/latest.json"), "utf8"))
  assert.equal(finished.status, "DONE")
  assert.equal(finished.final, true)
  assert.equal(finished.task, "smoke")
  console.log("omp-plugin smoke OK")
} finally {
  rmSync(cwd, { recursive: true, force: true })
}
