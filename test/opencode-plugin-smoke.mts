/**
 * opencode-plugin-smoke.ts — verify the OpenCode server entry behaves as the plugin contract needs.
 *
 * Tests the module shape and the safety-hook gates directly (no opencode server needed):
 *   • EVERY export of plugin.ts is callable — opencode calls each one as a plugin factory, and a
 *     single non-callable export (e.g. `export const id = "saki-builder"`) makes it silently skip
 *     the whole module, leaving the plugin inert. This assertion is why that cannot recur.
 *   • the factory returns a hooks object with event + tool.execute.before/after
 *   • catastrophic `rm -rf /`, force-push to main, and embedded secrets are each rejected
 *   • a benign command passes, and the event hook is a safe no-op when SAKI_AGENT_MODE is unset
 *
 * Run: npm run smoke   (tsx test/opencode-plugin-smoke.mts)
 */
import assert from "node:assert"
import plugin from "../opencode/plugins/plugin"

// Guard the loader contract before anything else: a non-callable export here is not a style issue,
// it is a total outage of the plugin. Verified against opencode 1.18.15 on both load paths.
const mod: Record<string, unknown> = await import("../opencode/plugins/plugin")
for (const [name, value] of Object.entries(mod)) {
  assert.equal(
    typeof value,
    "function",
    `export "${name}" is ${typeof value}, not a function — opencode calls every export as a ` +
      `plugin factory and skips the ENTIRE module when one is not callable (plugin goes inert)`,
  )
}

const hooks: any = await plugin({} as any)

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
