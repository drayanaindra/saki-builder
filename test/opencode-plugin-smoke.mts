/**
 * opencode-plugin-smoke.ts — verify the OpenCode server entry behaves as the plugin contract needs.
 *
 * Tests the V1 module shape and the safety-hook gates directly (no opencode server needed):
 *   • importing `server` from plugin.ts returns a hooks object with event + tool.execute.before/after
 *   • catastrophic `rm -rf /`, force-push to main, and embedded secrets are each rejected
 *   • a benign command passes, and the event hook is a safe no-op when SAKI_AGENT_MODE is unset
 *
 * Run: npm run smoke   (tsx test/opencode-plugin-smoke.ts)
 */
import assert from "node:assert"
import { server } from "../opencode/plugins/plugin"

const hooks: any = await server({} as any)

assert.ok(hooks, "server() returned a hooks object")
assert.equal(typeof hooks.event, "function", "hooks.event is a function")
assert.equal(typeof hooks["tool.execute.before"], "function", "tool.execute.before is a function")
assert.equal(typeof hooks["tool.execute.after"], "function", "tool.execute.after is a function")

const exec = (command: string) =>
  hooks["tool.execute.before"]({ tool: "bash", sessionID: "s", callID: "c" }, { args: { command } })

await assert.rejects(exec("rm -rf /"), /catastrophic rm -rf/, "rm -rf / must be blocked")
await assert.rejects(
  exec("git push --force origin main"),
  /force-push/,
  "force-push to main must be blocked",
)
await assert.rejects(
  exec("curl -H 'Authorization: Bearer sk-test123456789012345678901234567890' https://x"),
  /secret/,
  "embedded secrets must be blocked",
)

await exec("git status") // benign command must pass

await hooks.event({ event: { id: "x", type: "session.created", properties: {} } }) // no-op without agent mode

console.log("opencode-plugin smoke OK")
