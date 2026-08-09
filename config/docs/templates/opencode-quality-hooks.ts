/**
 * opencode-quality-hooks.ts — TEMPLATE copied by /init-env into <project>/.opencode/plugin/.
 *
 * This is the opencode analogue of the per-project hooks /init-env writes into
 * `.claude/settings.json` for Claude Code. opencode has no settings-hook system; project behaviour
 * is extended with plugins, which auto-load from `.opencode/plugin/*.ts` with NO config
 * registration (verified on opencode 1.18.x).
 *
 *   Claude Code                          opencode
 *   ───────────────────────────────      ─────────────────────────────────────
 *   PostToolUse:Edit|Write → tsc         "tool.execute.after"  + input.tool === edit|write
 *   PreToolUse:Bash (git commit) → test  "tool.execute.before" + input.tool === bash, throw to block
 *
 * A `throw` inside `tool.execute.before` BLOCKS the tool call — that is the only deny mechanism
 * (same convention as the shipped safety-hooks.ts).
 *
 * ── WHAT /init-env CUSTOMISES ────────────────────────────────────────────────────────────────
 * Only the two command arrays below. Everything else is stack-agnostic.
 *
 *   Stack            TYPECHECK                          TESTS
 *   ───────────      ──────────────────────────────     ──────────────────────────────
 *   Node / TS        ["npx","tsc","--noEmit"]           ["npx","vitest","run"]
 *   Python           ["mypy","."]                       ["pytest","-q"]
 *   Go               ["go","vet","./..."]               ["go","test","./..."]
 *   Rust             ["cargo","check"]                  ["cargo","test"]
 *
 * Set a command to [] to disable that gate.
 *
 * NOTE: this file is type-checked in the saki-builder repo (tsconfig `include`), so the template
 * can never drift out of compiling against @opencode-ai/plugin.
 */
import type { Plugin } from "@opencode-ai/plugin"
import { spawnSync } from "child_process"

// ── customised by /init-env per detected stack ────────────────────────────────────────────────
const TYPECHECK: string[] = ["npx", "tsc", "--noEmit"]
const TESTS: string[] = ["npx", "vitest", "run"]

/** Cap appended tool output so a wall of compiler errors can't blow up the context. */
const MAX_DIAGNOSTIC_CHARS = 4000

function run(cmd: string[], cwd: string): { ok: boolean; out: string } {
  if (cmd.length === 0) return { ok: true, out: "" }
  const [bin, ...args] = cmd
  // `bin` is a literal from the arrays above, never user input — no shell, no injection surface.
  const r = spawnSync(bin as string, args, { cwd, encoding: "utf8", timeout: 120_000 })
  const out = `${r.stdout ?? ""}${r.stderr ?? ""}`.trim()
  // A spawn failure (binary missing) is FAIL-OPEN: a project without the toolchain installed must
  // not have every edit reported as broken. Only a real non-zero exit is a failure.
  if (r.error) return { ok: true, out: "" }
  return { ok: r.status === 0, out }
}

export const QualityHooks: Plugin = async ({ directory }: any = {}) => {
  const cwd: string = directory ?? process.cwd()

  return {
    // PostToolUse:Edit|Write → surface type errors on the tool result.
    "tool.execute.after": async (input: any, output: any) => {
      try {
        if (input?.tool !== "edit" && input?.tool !== "write") return
        const { ok, out } = run(TYPECHECK, cwd)
        if (ok) return
        output.output = `${output.output ?? ""}\n\n[typecheck FAILED]\n${out}`.slice(
          0,
          MAX_DIAGNOSTIC_CHARS
        )
      } catch {
        // Fail-open: a hook must never take down the run.
      }
    },

    // PreToolUse:Bash → gate `git commit` on the test suite. Throw = block.
    "tool.execute.before": async (input: any, output: any) => {
      if (input?.tool !== "bash") return
      let cmd = ""
      try {
        cmd = String(output?.args?.command ?? "")
        if (!/\bgit\s+commit\b/.test(cmd)) return
        if (/--no-verify/.test(cmd)) return // explicit, documented bypass
      } catch {
        return // fail-open on schema drift
      }
      // Outside the try: a thrown block must NOT be swallowed by the fail-open catch above.
      const { ok, out } = run(TESTS, cwd)
      if (!ok) {
        throw new Error(
          `Blocked: tests are failing, refusing to commit.\n${out.slice(0, MAX_DIAGNOSTIC_CHARS)}\n` +
            `Fix them, or commit with --no-verify if the bypass is intentional.`
        )
      }
    },
  }
}

export default QualityHooks
