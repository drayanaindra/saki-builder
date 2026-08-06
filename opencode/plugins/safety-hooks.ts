/**
 * safety-hooks.ts — OpenCode port of saki-builder's Claude Code safety hooks + run visibility.
 *
 * Covers:
 *   • Catastrophic rm -rf blocking
 *   • Force-push to main/master blocking
 *   • Secret/token detection in commands
 *   • Pre-push quality gates (sonar-gate.sh + coverage-gate.sh)
 *   • Run visibility — the same tasks/.saki/ state file headless Claude writes (see saki-state.ts)
 *
 * ── KNOWN NON-PARITY WITH CLAUDE CODE ────────────────────────────────────────────────────────
 * Claude Code's `Stop` hook can DENY a stop (`decision:"block"`), which is how saki-builder forces
 * an autonomous /build to run to completion. opencode has no equivalent: `session.idle` is an
 * EVENT, not a gate — by the time it fires the turn is already over. We therefore do the two things
 * that ARE possible and say so plainly rather than implying parity:
 *   1. write the terminal state + log `SAKI-INCOMPLETE: <n> slices remaining` when work is left, and
 *   2. attempt a bounded re-prompt via client.session.prompt(), capped by SAKI_OC_MAX_CONTINUE.
 * If the client cannot re-prompt (the API is not reachable from the plugin context), the run simply
 * ends with an accurate INCOMPLETE record. Work that MUST be forced to completion belongs on
 * headless Claude. See docs/AGENT-RUNNERS.md §7.
 *
 * Install: symlinked into ~/.config/opencode/plugins/ by bin/opencode-bridge.sh
 */
import type { Plugin } from "@opencode-ai/plugin"
import { spawnSync } from "child_process"
import { existsSync, readFileSync, readdirSync } from "fs"
import { resolve } from "path"
import * as state from "./saki-state"

// Where the bash gate scripts live. SAKI_PLUGIN_ROOT is written by bin/opencode-bridge.sh and points
// at the INSTALLED plugin; the relative fallback keeps a plain repo clone working unchanged.
const REPO = process.env.SAKI_PLUGIN_ROOT ?? resolve(import.meta.dirname, "../..")
const HOOKS_DIR = resolve(REPO, "config/hooks")

// Bounded so a re-prompt loop can never become the runaway it exists to prevent — same doctrine as
// build-completion-gate.sh's circuit breaker. Counted per session, in memory.
const MAX_CONTINUE = Number(process.env.SAKI_OC_MAX_CONTINUE ?? 5)
const continues = new Map<string, number>()

/** Remaining actionable slices in a /build manifest, or 0 when there is no live build. */
function remainingSlices(cwd: string): number {
  try {
    const dir = resolve(cwd, "tasks")
    if (!existsSync(dir)) return 0
    let remaining = 0
    for (const f of readdirSync(dir)) {
      if (!f.startsWith(".build-") || !f.endsWith("-state.json")) continue
      const doc = JSON.parse(readFileSync(resolve(dir, f), "utf8"))
      for (const s of doc?.slices ?? []) {
        const st = String(s?.status ?? "").trim().toLowerCase().replace(/[\s_]+/g, "-")
        if (st !== "done" && st !== "blocked") remaining++
      }
    }
    return remaining
  } catch {
    return 0 // unreadable manifest → assume nothing pending; never invent work
  }
}

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

export const SafetyHooks: Plugin = async ({ client, directory, worktree }: any = {}) => {
  const CWD: string = worktree ?? directory ?? process.cwd()

  return {
    // ── Run visibility ───────────────────────────────────────────────────────
    // Mirrors config/hooks/agent-session.js so one supervisor poller serves both engines.
    // Every arm is best-effort; saki-state swallows its own errors.
    event: async ({ event }: any) => {
      const sid = event?.properties?.sessionID ?? event?.properties?.info?.id ?? ""
      if (!sid) return

      switch (event?.type) {
        case "session.created":
          return state.start(CWD, sid)

        case "session.error":
          return state.finish(CWD, sid, {
            status: "BLOCKED",
            blocked_on: String(event?.properties?.error?.message ?? event?.properties?.error ?? "session error"),
          })

        case "session.idle": {
          const left = remainingSlices(CWD)
          if (left > 0) {
            const used = continues.get(sid) ?? 0
            // Log FIRST: the record must exist even if the re-prompt below is impossible.
            console.warn(`SAKI-INCOMPLETE: ${left} slice(s) remaining (continue ${used}/${MAX_CONTINUE})`)
            if (used < MAX_CONTINUE) {
              continues.set(sid, used + 1)
              try {
                await client.session.prompt({
                  path: { id: sid },
                  body: { parts: [{ type: "text", text: "continue" }] },
                })
                return // still working — do not write a terminal state
              } catch {
                /* cannot re-prompt from here — fall through and record the truth */
              }
            }
          }
          return state.finish(CWD, sid, { message: event?.properties?.info?.summary })
        }

        default:
      }
    },

    "tool.execute.after": async (input: any) => {
      const sid = input?.sessionID ?? input?.sessionId ?? ""
      if (sid) state.heartbeat(CWD, sid, input?.tool)
    },

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
