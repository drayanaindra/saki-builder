import assert from "node:assert/strict"
import {
  detectEngine,
  normalizeEngine,
  recommendationFor,
  supportedEngines,
} from "../bin/engine-detect.mjs"

const emptyEnv = {}

assert.deepEqual(supportedEngines(), ["claude", "codex", "opencode"])
assert.equal(normalizeEngine("codex"), "codex")
assert.equal(normalizeEngine(undefined), undefined)
assert.throws(() => normalizeEngine("other"), /invalid engine 'other'/)

assert.equal(detectEngine({ explicitEngine: "codex", env: { OPENCODE: "1" } }), "codex")
assert.equal(detectEngine({ env: { OPENCODE: "1", CLAUDECODE: "1", CODEX_HOME: "/tmp/codex" } }), "opencode")
assert.equal(detectEngine({ env: { CLAUDECODE: "1", CODEX_HOME: "/tmp/codex" } }), "claude")
assert.equal(detectEngine({ env: { CODEX_HOME: "/tmp/codex" } }), "codex")
assert.equal(detectEngine({ env: emptyEnv }), "unknown")

// ── a LIVE codex run ────────────────────────────────────────────────────────────
// codex exports CODEX_THREAD_ID + CODEX_CI to every child (codex-cli 0.147.0). CODEX_HOME is NOT
// exported unless the caller pinned one, so these are the only markers an ordinary codex run has.
assert.equal(detectEngine({ env: { CODEX_THREAD_ID: "01a0-…" } }), "codex")
assert.equal(detectEngine({ env: { CODEX_CI: "1" } }), "codex")

// 🔒 THE ORDERING THAT MATTERS. A codex run launched from a Claude Code shell inherits CLAUDECODE —
// exactly as opencode does. Proof of a live codex run must outrank that stale inheritance, or the
// installer recommends claude's command form to a codex user.
assert.equal(detectEngine({ env: { CLAUDECODE: "1", CODEX_THREAD_ID: "01a0-…" } }), "codex")
assert.equal(detectEngine({ env: { CLAUDECODE: "1", CODEX_CI: "1" } }), "codex")

// ...but opencode still outranks codex: opencode is checked first, and nothing about a codex marker
// should change that (an opencode run never sets one).
assert.equal(detectEngine({ env: { OPENCODE: "1", CODEX_THREAD_ID: "01a0-…" } }), "opencode")

// ...and CODEX_HOME stays BELOW CLAUDECODE, because it is a configured preference (an operator can
// export it from a shell profile), not evidence of a running engine. Inside a real claude run,
// claude wins — this is the assertion above, restated here as the deliberate counterpart.
assert.equal(detectEngine({ env: { CLAUDECODE: "1", CODEX_HOME: "/tmp/codex" } }), "claude")

// An explicit override beats every marker, including a live codex run.
assert.equal(detectEngine({ explicitEngine: "claude", env: { CODEX_THREAD_ID: "01a0-…" } }), "claude")

assert.deepEqual(recommendationFor("claude"), {
  label: "Claude Code",
  command: "/saki-builder:<skill>",
  example: "/saki-builder:reviewer",
})
assert.deepEqual(recommendationFor("codex"), {
  label: "Codex",
  command: "$saki-builder:<skill>",
  example: "$saki-builder:reviewer",
})
assert.deepEqual(recommendationFor("opencode"), {
  label: "OpenCode",
  command: "/<skill>",
  example: "/reviewer",
})
assert.deepEqual(recommendationFor("unknown"), {
  label: "unknown engine",
  command: undefined,
  example: undefined,
})

console.log("engine-detect OK")
