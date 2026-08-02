/**
 * safety-hooks.ts — OpenCode port of saki-builder's Claude Code safety hooks.
 *
 * Covers:
 *   • Catastrophic rm -rf blocking
 *   • Force-push to main/master blocking
 *   • Secret/token detection in commands
 *   • Pre-push quality gates (sonar-gate.sh + coverage-gate.sh)
 *
 * Install: symlinked into ~/.config/opencode/plugins/ by build-opencode.sh --install
 */
import type { Plugin } from "@opencode-ai/plugin"
import { spawnSync } from "child_process"
import { resolve } from "path"

// Absolute path to the gate scripts (resolved relative to this file's real location,
// which lives at opencode/plugins/ inside the claude-config repo).
const REPO = resolve(import.meta.dirname, "../..")
const HOOKS_DIR = resolve(REPO, "config/hooks")

function runGate(script: string, command: string): void {
  const result = spawnSync("bash", [resolve(HOOKS_DIR, script)], {
    env: { ...process.env, CLAUDE_TOOL_INPUT_COMMAND: command },
    encoding: "utf8",
  })
  if (result.status !== 0) {
    const msg = (result.stdout + result.stderr).trim()
    throw new Error(msg || `${script} blocked the command.`)
  }
}

export const SafetyHooks: Plugin = async () => {
  return {
    "tool.execute.before": async (input: any, output: any) => {
      if (input.tool !== "bash") return

      const cmd: string = output.args?.command ?? ""

      // ── Catastrophic rm -rf ──────────────────────────────────────────────────
      // Matches: rm -rf / | rm -rf ~ | rm -rf /* | rm -rf ~/
      if (
        /\brm\b/.test(cmd) &&
        /-(r[^-]*f|f[^-]*r)/.test(cmd) &&
        /(\/\s*$|\/\s*\*|~\s*\/?\s*$|~\s*\/\s*\*)/.test(cmd)
      ) {
        throw new Error(
          "Blocked: catastrophic rm -rf detected. Run the command manually if intentional."
        )
      }

      // ── Force-push to main/master ────────────────────────────────────────────
      if (/\bgit\s+push\b/.test(cmd) && /--force/.test(cmd) && /\b(main|master)\b/.test(cmd)) {
        throw new Error(
          "Blocked: force-push to main/master is not allowed. Push manually if this is intentional."
        )
      }

      // ── Secrets / tokens in command arguments ───────────────────────────────
      const secretPattern =
        /\b(eyJ[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36,}|xoxb-[A-Za-z0-9-]{50,})\b/
      if (secretPattern.test(cmd)) {
        throw new Error(
          "Blocked: possible secret/token detected in command. Pass credentials via environment variables."
        )
      }

      // ── Pre-push quality gates ───────────────────────────────────────────────
      // Only trigger on pushes that target main/master (same logic as the bash hooks).
      if (/\bgit\s+push\b/.test(cmd) && /\b(main|master)\b/.test(cmd)) {
        runGate("sonar-gate.sh", cmd)
        runGate("coverage-gate.sh", cmd)
      }
    },
  }
}
