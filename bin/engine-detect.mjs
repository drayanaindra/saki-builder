const SUPPORTED_ENGINES = Object.freeze(["claude", "codex", "opencode"])

const RECOMMENDATIONS = Object.freeze({
  claude: {
    label: "Claude Code",
    command: "/saki-builder:<skill>",
    example: "/saki-builder:reviewer",
  },
  codex: {
    label: "Codex",
    command: "$saki-builder:<skill>",
    example: "$saki-builder:reviewer",
  },
  opencode: {
    label: "OpenCode",
    command: "/<skill>",
    example: "/reviewer",
  },
})

// Env vars a LIVE codex run exports to every child process (verified against codex-cli 0.147.0).
// These are proof that we are executing INSIDE codex, so they outrank an inherited CLAUDECODE.
const CODEX_RUN_MARKERS = Object.freeze(["CODEX_THREAD_ID", "CODEX_CI"])

function isSet(value) {
  return typeof value === "string" && value.length > 0
}

function anySet(env, names) {
  return names.some((name) => isSet(env[name]))
}

export function normalizeEngine(value) {
  if (value === undefined) return undefined
  if (SUPPORTED_ENGINES.includes(value)) return value
  throw new Error(`invalid engine '${value}'; expected one of: ${SUPPORTED_ENGINES.join("|")}`)
}

// Ladder — first match wins. Kept in step with the ENGINE ladder in
// config/skills/init-env/SKILL.md (Step 0); change both together.
//
// Ordering is the whole design here. opencode AND codex, when launched from a Claude Code shell,
// inherit CLAUDECODE — so any marker that proves a LIVE non-claude run has to be tested before it,
// or a real codex run reports "claude" and the caller recommends the wrong command form.
//
// The two codex signals are deliberately at different heights, because they prove different things:
//
//   CODEX_THREAD_ID / CODEX_CI — codex exports these to every child of a live run. Proof. Beats
//                                CLAUDECODE, which at that point can only be stale inheritance.
//   CODEX_HOME                 — only exported when the caller PINNED a home; an operator may also
//                                export it from a shell profile. That is a configured preference,
//                                not evidence of a running engine, so it sits BELOW CLAUDECODE:
//                                inside a real claude run, claude wins.
export function detectEngine({ explicitEngine, env = process.env } = {}) {
  const override = normalizeEngine(explicitEngine)
  if (override !== undefined) return override

  if (isSet(env.OPENCODE)) return "opencode"
  if (anySet(env, CODEX_RUN_MARKERS)) return "codex"
  if (isSet(env.CLAUDECODE)) return "claude"
  if (isSet(env.CODEX_HOME)) return "codex"
  return "unknown"
}

export function recommendationFor(engine) {
  if (engine === undefined || engine === "unknown") {
    return {
      label: "unknown engine",
      command: undefined,
      example: undefined,
    }
  }
  return RECOMMENDATIONS[normalizeEngine(engine)]
}

export function supportedEngines() {
  return [...SUPPORTED_ENGINES]
}
