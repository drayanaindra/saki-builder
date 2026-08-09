/**
 * test-safety-hooks.mts — prove the opencode safety guards actually BLOCK.
 *
 * Regression test for a real, shipped defect: `tool.execute.before` wrapped its whole body in
 * `try { … } catch { /* fail-open *\/ }`. Every guard signals a block by THROWING, so the catch
 * swallowed the blocks themselves — `rm -rf /`, force-push to main, secrets in argv and the
 * pre-push sonar/coverage gates were all inert while looking perfectly healthy in review.
 *
 * A guard that cannot be observed blocking is indistinguishable from no guard. This test observes
 * it, so the fail-open catch can never silently creep back over the throws.
 *
 * Run: npx tsx test/test-safety-hooks.mts
 */
import { SafetyHooks } from "../opencode/plugins/safety-hooks"

type Case = { label: string; cmd: string; tool?: string; expect: "block" | "allow" }

const CASES: Case[] = [
  // ── must BLOCK ───────────────────────────────────────────────────────────────
  { label: "catastrophic rm -rf /", cmd: "rm -rf /", expect: "block" },
  { label: "catastrophic rm -rf ~", cmd: "rm -rf ~", expect: "block" },
  { label: "force-push to main", cmd: "git push --force origin main", expect: "block" },
  { label: "force-push to master", cmd: "git push --force origin master", expect: "block" },
  {
    label: "JWT in argv",
    cmd: "curl -H 'Authorization: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abcdefghij' https://x",
    expect: "block",
  },
  { label: "sk- API key in argv", cmd: "export K=sk-abcdefghijklmnopqrstuvwxyz012345", expect: "block" },

  // ── must ALLOW (no false positives on ordinary work) ─────────────────────────
  { label: "ordinary ls", cmd: "ls -la", expect: "allow" },
  { label: "scoped rm", cmd: "rm -rf ./node_modules", expect: "allow" },
  { label: "non-force push to a feature branch", cmd: "git push origin feat/x", expect: "allow" },
  { label: "force-push to a feature branch", cmd: "git push --force origin feat/x", expect: "allow" },
  { label: "non-bash tool is ignored", cmd: "rm -rf /", tool: "edit", expect: "allow" },
]

const hooks: any = await SafetyHooks({ directory: "/tmp", worktree: "/tmp" } as any)
const before = hooks["tool.execute.before"]
if (typeof before !== "function") {
  console.error("FAIL: tool.execute.before is not registered")
  process.exit(1)
}

let failures = 0

for (const c of CASES) {
  let blocked = false
  try {
    await before({ tool: c.tool ?? "bash", sessionID: "test", callID: "c" }, { args: { command: c.cmd } })
  } catch {
    blocked = true
  }
  const got = blocked ? "block" : "allow"
  const ok = got === c.expect
  if (!ok) failures++
  console.log(`  ${ok ? "✓" : "✗"} ${c.expect.padEnd(5)} ${c.label}${ok ? "" : `  → got ${got}`}`)
}

// Malformed input must fail OPEN (never crash the host) — the one thing the catch is for.
for (const [label, arg] of [
  ["undefined output", undefined],
  ["missing args", {}],
  ["null command", { args: { command: null } }],
] as const) {
  try {
    await before({ tool: "bash", sessionID: "test", callID: "c" }, arg)
    console.log(`  ✓ allow ${label} fails open`)
  } catch {
    failures++
    console.log(`  ✗ allow ${label} fails open  → threw`)
  }
}

if (failures > 0) {
  console.error(`\nFAIL: ${failures} safety-hook case(s) wrong`)
  process.exit(1)
}
console.log("\nsafety-hooks OK — every guard observably blocks, malformed input fails open")
