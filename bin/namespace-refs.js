#!/usr/bin/env node
'use strict'
// saki-builder — namespace internal skill references.
//
// Plugin skills/commands are invoked namespaced (/saki-builder:<name>). This rewrites BARE
// internal references (/rplan, /prd, /build, …) in skill + agent bodies to /saki-builder:<name>,
// but ONLY for names that are actually OUR skills (top-level dirs in config/skills). External
// commands (/code-review, /security-review, /simplify, /verify, /init, /review, /clear) are not
// in that set, so they are left bare automatically — same policy ed-harness uses.
//
// Guards against false hits:
//   - lookbehind (?<![\w:./~*-]) — the slash must not be inside a path (skills/rplan, ./sync.sh,
//     ~/x, **/prd.md) or an already-namespaced ref (/saki-builder:rplan → "rplan" preceded by ':').
//   - lookahead  (?![-\w/])  — the name must be whole and not a path segment (/rplan/template.md)
//     or a longer skill (/prd never matches inside /prd-review).
//
// Usage:  node bin/namespace-refs.js --dry   (preview, writes nothing)
//         node bin/namespace-refs.js         (apply)

const fs = require('fs')
const path = require('path')

const ROOT = path.resolve(__dirname, '..')
const DRY = process.argv.includes('--dry')
const PREFIX = 'saki-builder'

// OUR invocable skills = top-level dirs under config/skills (nested library skills are
// user-invocable:false docs, never slash-invoked, so not namespace targets).
const skillsRoot = path.join(ROOT, 'config', 'skills')
const names = fs.readdirSync(skillsRoot, { withFileTypes: true })
  .filter((d) => d.isDirectory() && fs.existsSync(path.join(skillsRoot, d.name, 'SKILL.md')))
  .map((d) => d.name)
  .sort((a, b) => b.length - a.length) // longest first (defensive)

// One combined alternation, whole-word, not-already-namespaced, not-a-path.
const alt = names.map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')
const re = new RegExp(`(?<![\\w:./~*-])/(${alt})(?![-\\w/.])`, 'g')

// Walk .md files under a root dir (recursive) or a single file.
function mdFiles (rel) {
  const abs = path.join(ROOT, rel)
  if (!fs.existsSync(abs)) return []
  if (fs.statSync(abs).isFile()) return rel.endsWith('.md') ? [rel] : []
  const out = []
  for (const d of fs.readdirSync(abs, { withFileTypes: true })) {
    if (d.isDirectory()) out.push(...mdFiles(path.join(rel, d.name)))
    else if (d.name.endsWith('.md')) out.push(path.join(rel, d.name))
  }
  return out
}

const targets = [...mdFiles('config/skills'), ...mdFiles('config/agents')]
let totalHits = 0
let filesChanged = 0
const perFile = []

for (const rel of targets) {
  const abs = path.join(ROOT, rel)
  const txt = fs.readFileSync(abs, 'utf8')
  let hits = 0
  const next = txt.replace(re, (_m, n) => { hits++; return `/${PREFIX}:${n}` })
  if (hits > 0) {
    totalHits += hits
    filesChanged++
    perFile.push([rel, hits])
    if (!DRY) fs.writeFileSync(abs, next)
  }
}

perFile.sort((a, b) => b[1] - a[1])
console.log(`${DRY ? '[dry-run] ' : ''}namespace-refs: ${names.length} skill names, ${totalHits} refs across ${filesChanged} files`)
for (const [rel, hits] of perFile.slice(0, 20)) console.log(`  ${String(hits).padStart(4)}  ${rel}`)
if (perFile.length > 20) console.log(`  … +${perFile.length - 20} more files`)
if (DRY) console.log('\n(no files written — rerun without --dry to apply)')
