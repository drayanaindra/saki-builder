#!/usr/bin/env node
'use strict'
// saki-builder — plugin version check (SessionStart nudge).
//
// The marketplace is the git repo, so an installed copy never learns a newer version was pushed —
// updating is pull-based. This prints a one-line nudge IF the installed version is behind the latest
// on GitLab. Ambient, never blocks.
//
// FAIL-OPEN: any uncertainty (offline, no token, parse error, repo not published yet) → exit 0 with
// no output. Off with SAKI_UPDATE_CHECK_DISABLE=1.
// Tunables: SAKI_UPDATE_API (raw plugin.json URL), GITLAB_TOKEN (auth), SAKI_UPDATE_TIMEOUT_MS (default 4000).

const fs = require('fs')
const path = require('path')

if (process.env.SAKI_UPDATE_CHECK_DISABLE === '1') process.exit(0)

const UPDATE_CMD = '/plugin marketplace update saki-builder && /plugin update saketek@saki-builder'
const API = process.env.SAKI_UPDATE_API ||
  'https://gitlab.com/api/v4/projects/drayanaindra%2Fsaki-builder/repository/files/.claude-plugin%2Fplugin.json/raw?ref=main'
const TIMEOUT = Number(process.env.SAKI_UPDATE_TIMEOUT_MS || 4000)

const ok = () => process.exit(0) // fail-open

function localVersion () {
  const root = process.env.CLAUDE_PLUGIN_ROOT || path.resolve(__dirname, '..', '..')
  try {
    return String(JSON.parse(fs.readFileSync(path.join(root, '.claude-plugin', 'plugin.json'), 'utf8')).version || '').trim()
  } catch (_e) { return '' }
}

function cmp (a, b) {
  const pa = String(a).split('.').map((n) => parseInt(n, 10) || 0)
  const pb = String(b).split('.').map((n) => parseInt(n, 10) || 0)
  for (let i = 0; i < 3; i++) { if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) < (pb[i] || 0) ? -1 : 1 }
  return 0
}

async function main () {
  if (typeof fetch !== 'function') ok()
  const local = localVersion()
  if (!local) ok()

  const ctrl = new AbortController()
  const t = setTimeout(() => ctrl.abort(), TIMEOUT)
  let latest = ''
  try {
    const headers = {}
    if (process.env.GITLAB_TOKEN) headers['PRIVATE-TOKEN'] = process.env.GITLAB_TOKEN
    const res = await fetch(API, { headers, signal: ctrl.signal })
    if (!res.ok) ok()
    latest = String(JSON.parse(await res.text()).version || '').trim()
  } catch (_e) {
    ok()
  } finally {
    clearTimeout(t)
  }
  if (!latest) ok()

  if (cmp(local, latest) < 0) {
    process.stdout.write(`[saki-builder] update available: ${latest} (installed ${local}). Run:\n  ${UPDATE_CMD}\n`)
  }
  ok()
}

main().catch(() => process.exit(0))
