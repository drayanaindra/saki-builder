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
 *
 * ── FAIL-OPEN PATCH (opencode 1.18.x) ───────────────────────────────────────────────────────
 * The opencode Event schema changed: in 1.18.x the payload does NOT live under `event.properties`,
 * so `event.properties.info` threw "undefined is not an object" inside the plugin dispatcher and
 * took down EVERY run. All event/hook bodies are now wrapped in try/catch and read defensively with
 * top-level fallbacks, so a schema drift can never crash the host again. `client.app.log` (not in
 * the 1.18.14 client API) was replaced with console.warn.
 */
import type { Plugin } from "@opencode-ai/plugin"
import { spawnSync } from "child_process"
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "fs"
import { resolve } from "path"
import * as state from "./saki-state"

// Where the bash gate scripts live. SAKI_PLUGIN_ROOT is written by bin/opencode-bridge.sh and points
// at the INSTALLED plugin; the relative fallback keeps a plain repo clone working unchanged.
const REPO = process.env.SAKI_PLUGIN_ROOT ?? resolve(import.meta.dirname, "../..")
const HOOKS_DIR = resolve(REPO, "config/hooks")

// Bounded so a re-prompt loop can never become the runaway it exists to prevent — same doctrine as
// build-completion-gate.sh's circuit breaker, and persisted to a sidecar for the same reason: an
// in-memory counter resets on every plugin reload, which makes a "bounded" loop unbounded in exactly
// the long-lived process the bound exists for.
const MAX_CONTINUE = Number(process.env.SAKI_OC_MAX_CONTINUE ?? 5)

function continueCount(cwd: string, sid: string, bump = false): number {
  const f = resolve(cwd, "tasks", ".saki", `${sid.replace(/[^A-Za-z0-9._-]/g, "")}.continues`)
  let n = 0
  try {
    n = Number(readFileSync(f, "utf8").trim()) || 0
  } catch {
    n = 0
  }
  if (bump) {
    try {
      mkdirSync(resolve(cwd, "tasks", ".saki"), { recursive: true })
      writeFileSync(f, String(n + 1))
    } catch {
      /* fail-open: if we cannot persist, do not continue — the safe direction is to stop */
      return MAX_CONTINUE
    }
  }
  return n
}

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
      // Opt-in, checked HERE and not only inside saki-state: the session.idle arm below can spend
      // tokens and edit files via client.session.prompt(). Without this gate, an ORDINARY interactive
      // opencode session in any repo that has ever run /build would get up to 5 unrequested
      // "continue" prompts after the user stopped it. Matches the Claude side's strict `=== '1'`.
      if (process.env.SAKI_AGENT_MODE !== "1") return
      try {
        // FAIL-OPEN + crash-proof: the opencode Event schema changed across versions. In some builds
        // the payload lives under `event.properties`; in 1.18.x it does not, so `event.properties`
        // is undefined and `event.properties.info` throws "undefined is not an object" inside the
        // plugin dispatcher — which took down EVERY run. Read defensively and fall back to top-level
        // fields so a schema drift can never crash the host again.
        const props = event?.properties
        const info = props?.info ?? event?.info
        const sid = props?.sessionID ?? event?.sessionID ?? info?.id ?? ""
        if (!sid) return
        // A child/sub session must never clobber its parent's state file — the Claude hook refuses on
        // agent_id for the same reason.
        if (info?.parentID) return

        switch (event?.type) {
          case "session.created":
            return state.start(CWD, sid)

          case "session.error": {
            const err = props?.error ?? event?.error
            const msg = err?.message ?? err ?? "session error"
            return state.finish(CWD, sid, {
              status: "BLOCKED",
              blocked_on: String(msg),
            })
          }

          case "session.idle": {
            const left = remainingSlices(CWD)
            if (left > 0) {
              const used = continueCount(CWD, sid)
              // Log FIRST: the record must exist even if the re-prompt below is impossible.
              // console.warn is fail-open and has no dependency on a client method that may not
              // exist in this opencode version (client.app.log is not in the 1.18.14 client API).
              console.warn(`SAKI-INCOMPLETE: ${left} slice(s) remaining (continue ${used}/${MAX_CONTINUE})`)
              if (used < MAX_CONTINUE) {
                continueCount(CWD, sid, true)
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
            // `session.idle` may carry only { sessionID }. When there is no assistant text to parse,
            // finish() falls through to UNKNOWN — which is the honest answer, not a silent DONE.
            return state.finish(CWD, sid, { message: info?.summary ?? info?.title })
          }

          default:
        }
      } catch {
        /* fail-open: a malformed event payload must never abort the host run */
      }
    },

    "tool.execute.after": async (input: any) => {
      const sid = input?.sessionID ?? input?.sessionId ?? ""
      if (sid) state.heartbeat(CWD, sid, input?.tool)
    },

    "tool.execute.before": async (input: any, output: any) => {
      if (input?.tool !== "bash") return

      // ── Crash-proof, but ONLY around reading the input ──────────────────────
      // Schema drift must never take down the host run, so the READ is guarded. The read is the
      // only thing that can throw accidentally.
      //
      // The blocking checks below are deliberately OUTSIDE this try. They signal a block by
      // throwing, so a catch wrapped around them swallows the block itself: for ~1 release every
      // guard in this file was inert — `rm -rf /`, force-push to main, secrets in argv and the
      // pre-push sonar/coverage gates all threw, were caught here, and the command ran anyway.
      // Never widen this try to cover a `throw` that means "deny". See test/test-safety-hooks.mts.
      let cmd = ""
      try {
        cmd = String(output?.args?.command ?? "")
      } catch {
        return // unreadable input → fail open, nothing to inspect
      }
      if (!cmd) return

      // ── Catastrophic rm -rf ────────────────────────────────────────────────
      // Matches: rm -rf / | rm -rf ~ | rm -rf /* | rm -rf ~/
      const rmRfPattern = /(^|\s)rm\s+-[rf]+\s+(\/\s*$|[*~/]+\s*$|~\s*\/?\s*$|~\s*\/\s*)/
      if (rmRfPattern.test(cmd)) {
        throw new Error(
          "Blocked: catastrophic rm -rf detected. Run the command manually if intentional."
        )
      }

      // ── Force-push to main/master ──────────────────────────────────────────
      if (/\bgit\s+push\b/.test(cmd) && /--force/.test(cmd) && /\b(main|master)\b/.test(cmd)) {
        throw new Error(
          "Blocked: force-push to main/master is not allowed. Push manually if this is intentional."
        )
      }

      // ── Secrets / tokens in command arguments ──────────────────────────────
      const secretPattern =
        /\b(eyJ[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36,}|xoxb-[A-Za-z0-9-]{50,})\b/
      if (secretPattern.test(cmd)) {
        throw new Error(
          "Blocked: possible secret/token detected in command. Pass credentials via environment variables."
        )
      }

      // ── Pre-push quality gates ─────────────────────────────────────────────
      // Only trigger on pushes that target main/master (same logic as the bash hooks).
      if (/\bgit\s+push\b/.test(cmd) && /\b(main|master)\b/.test(cmd)) {
        runGate("sonar-gate.sh", cmd)
        runGate("coverage-gate.sh", cmd)
      }
    },
  }
}
