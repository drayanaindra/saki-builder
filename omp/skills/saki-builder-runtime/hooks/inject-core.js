#!/usr/bin/env node
'use strict'
// saki-builder — inject the always-on core protocol at session start.
//
// A plugin can't ship a global CLAUDE.md, so this SessionStart hook injects the standing rules
// as `additionalContext`. It layers the split learning loop:
//   1. instructions/core.md                  — the always-on protocol (shipped, team-wide)
//   2. ~/.claude/memory/patterns-personal.md — each machine's PRIVATE overlay (never shipped) [if present]
//
// The CURATED team-baseline patterns are wired in Phase 3 (learnings split) — deliberately NOT
// injected here, so the owner's raw personal patterns.md is not broadcast to teammates as "baseline".
//
// FAIL-OPEN: any error → exit 0 with no output; a hook must never block a session.
// Disable with SAKI_CORE_DISABLE=1.
//
// AGENT MODE: when SAKI_AGENT_MODE=1 (session spawned by a runner — Hermes, OpenClaw, CI — via
// `claude -p` / `opencode run`, no human at the keyboard), instructions/agent-mode.md is layered
// LAST so its overrides win by position as well as by explicit statement. Opt-in by env only:
// sniffing (TTY absence, CI, --print) would misfire, because command hooks already run without a
// controlling terminal in ordinary interactive sessions.

const fs = require('fs')
const os = require('os')
const path = require('path')

// Strict equality — an unset var, "0", "true", or "" all mean interactive.
function agentMode () {
  return process.env.SAKI_AGENT_MODE === '1'
}

function main () {
  if (process.env.SAKI_CORE_DISABLE === '1') return ''

  const root = process.env.CLAUDE_PLUGIN_ROOT || path.resolve(__dirname, '..', '..')
  const parts = []

  const read = (p, label) => {
    try {
      if (fs.existsSync(p)) {
        const txt = fs.readFileSync(p, 'utf8').trim()
        if (txt) parts.push(label ? `\n<!-- ${label} -->\n${txt}` : txt)
      }
    } catch (_e) { /* fail-open per source */ }
  }

  read(path.join(root, 'instructions', 'core.md'))
  read(path.join(os.homedir(), '.claude', 'memory', 'patterns-personal.md'), 'personal overlay (this machine)')
  if (agentMode()) {
    read(path.join(root, 'instructions', 'agent-mode.md'), 'agent mode (autonomous runner)')
  }

  return parts.join('\n')
}

try {
  const context = main()
  if (context) {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext: context }
    }))
  }
  process.exit(0)
} catch (_e) {
  process.exit(0) // fail-open
}
