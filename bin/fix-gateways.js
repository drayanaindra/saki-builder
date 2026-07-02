#!/usr/bin/env node
'use strict'
// saki-builder — fix gateway routing tables.
//
// gateway-* skills route to library skills BY PATH. Their tables were written aspirationally with a
// wrong base (`skills/library/<cat>/…`) and reference many skills that were never built. This:
//   - rewrites a reference whose skill EXISTS → `${CLAUDE_PLUGIN_ROOT}/config/skills/<cat>/<skill>/SKILL.md`
//   - drops the markdown TABLE ROW for a skill that does NOT exist (so a gateway never routes to a missing file)
//   - leaves non-table placeholder examples (e.g. `[absolute/path/to/SKILL.md]`) untouched
//
// Usage: node bin/fix-gateways.js [--dry]

const fs = require('fs')
const path = require('path')

const ROOT = path.resolve(__dirname, '..')
const DRY = process.argv.includes('--dry')
const REF = /skills\/library\/([a-z0-9-]+)\/([a-z0-9-]+)\/SKILL\.md/g

const gwDir = path.join(ROOT, 'config', 'skills')
const gateways = fs.readdirSync(gwDir).filter((d) => d.startsWith('gateway-'))
  .map((d) => path.join('config', 'skills', d, 'SKILL.md'))
  .filter((f) => fs.existsSync(path.join(ROOT, f)))

const exists = (cat, skill) => fs.existsSync(path.join(ROOT, 'config', 'skills', cat, skill, 'SKILL.md'))

for (const rel of gateways) {
  const abs = path.join(ROOT, rel)
  const lines = fs.readFileSync(abs, 'utf8').split('\n')
  const out = []
  let fixed = 0
  let dropped = 0
  for (const line of lines) {
    const refs = [...line.matchAll(REF)]
    if (refs.length === 0) { out.push(line); continue }
    const isTableRow = /^\s*\|/.test(line)
    const anyMissing = refs.some((m) => !exists(m[1], m[2]))
    if (isTableRow && anyMissing) { dropped++; continue } // drop the whole row for a missing skill
    // rewrite each existing ref to the portable path
    const next = line.replace(REF, (whole, cat, skill) => {
      if (!exists(cat, skill)) return whole
      fixed++
      return `\${CLAUDE_PLUGIN_ROOT}/config/skills/${cat}/${skill}/SKILL.md`
    })
    out.push(next)
  }
  const result = out.join('\n')
  console.log(`${DRY ? '[dry] ' : ''}${rel}: ${fixed} path(s) fixed, ${dropped} dead row(s) dropped`)
  if (!DRY) fs.writeFileSync(abs, result)
}
