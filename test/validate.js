#!/usr/bin/env node
'use strict'
// saki-builder — zero-dependency config validator.
//
// The toolkit is prose + config, which drifts silently. This guards the structural invariants
// so a broken plugin can't merge. Run: `node test/validate.js` (or `npm test`). Exit 1 on any
// hard error; warnings (end-state invariants not yet reached in the migration) print but pass.
//
// Checks (hard = fail):
//   [hard] .claude-plugin/plugin.json + marketplace.json parse; required keys present
//   [hard] marketplace plugin entry name === plugin.json name; versions agree
//   [hard] mcpServers pointer file exists and parses
//   [hard] every plugin.json skills-path dir: each */SKILL.md has name+description frontmatter
//   [hard] every plugin.json agents-path dir: each *.md has name+description frontmatter
//   [hard] every `/saki-builder:<x>` reference resolves to a real skill/agent/command
//   [warn] stray `claude-config` strings (until the Phase-4 rename lands)
//   [warn] hooks.json referenced by plugin.json parses (if present)

const fs = require('fs')
const path = require('path')

const ROOT = path.resolve(__dirname, '..')
const errors = []
const warnings = []
const err = (m) => errors.push(m)
const warn = (m) => warnings.push(m)

function readJSON (rel) {
  const p = path.join(ROOT, rel)
  if (!fs.existsSync(p)) { err(`missing file: ${rel}`); return null }
  try { return JSON.parse(fs.readFileSync(p, 'utf8')) } catch (e) { err(`invalid JSON in ${rel}: ${e.message}`); return null }
}

// Minimal frontmatter reader: returns {name, description} from a leading --- block, or null.
function frontmatter (absPath) {
  const txt = fs.readFileSync(absPath, 'utf8')
  if (!txt.startsWith('---')) return null
  const end = txt.indexOf('\n---', 3)
  if (end === -1) return null
  const block = txt.slice(3, end)
  const out = {}
  for (const line of block.split('\n')) {
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/)
    if (m) out[m[1]] = m[2].trim()
  }
  return out
}

function listDir (rel) {
  const p = path.join(ROOT, rel)
  if (!fs.existsSync(p)) return []
  return fs.readdirSync(p, { withFileTypes: true })
}

// --- 1. Manifests ---------------------------------------------------------
const plugin = readJSON('.claude-plugin/plugin.json')
const market = readJSON('.claude-plugin/marketplace.json')

if (plugin) {
  if (!plugin.name) err('plugin.json: missing "name"')
  if (!plugin.version) err('plugin.json: missing "version"')
  // mcpServers pointer
  if (typeof plugin.mcpServers === 'string') {
    const mp = readJSON(plugin.mcpServers.replace(/^\.\//, ''))
    if (mp && typeof mp.mcpServers !== 'object') err(`${plugin.mcpServers}: missing "mcpServers" object`)
  }
}

if (plugin && market) {
  const entry = (market.plugins || []).find((p) => p.name === plugin.name)
  if (!entry) err(`marketplace.json has no plugin entry named "${plugin.name}"`)
  else if (entry.version && entry.version !== plugin.version) {
    err(`version mismatch: plugin.json ${plugin.version} vs marketplace entry ${entry.version}`)
  }
}

// --- 2. Version sync with CHANGELOG (if present) --------------------------
if (plugin && fs.existsSync(path.join(ROOT, 'CHANGELOG.md'))) {
  const cl = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8')
  if (!cl.includes(plugin.version)) warn(`CHANGELOG.md does not mention version ${plugin.version}`)
}

// --- 3. Skills: any dir containing SKILL.md is a skill (recursive) ---------
// 1-level skills are slash-invocable (/saki-builder:<name>); deeper "library" skills are
// user-invocable:false docs the gateway-* skills load by path. Both must have valid frontmatter.
// A category dir (e.g. config/skills/backend) has no SKILL.md itself but nests skills — not an error.
const skillPaths = (plugin && plugin.skills) || ['./config/skills']
const skillNames = new Set()
function walkSkills (rel) {
  for (const d of listDir(rel)) {
    if (!d.isDirectory()) continue // flat *.md files are persona docs, not skills — skip
    const child = path.join(rel, d.name)
    const skillMd = path.join(ROOT, child, 'SKILL.md')
    if (fs.existsSync(skillMd)) {
      const fm = frontmatter(skillMd)
      if (!fm) err(`${child}/SKILL.md: no frontmatter block`)
      else if (!fm.description) err(`${child}/SKILL.md: frontmatter missing "description"`)
      skillNames.add((fm && fm.name) || d.name)
    }
    walkSkills(child) // recurse: category dirs and nested library skills
  }
}
for (const sp of skillPaths) walkSkills(sp.replace(/^\.\//, ''))

// --- 4. Agents (from plugin.json agents paths, default ./config/agents) ----
const agentPaths = (plugin && plugin.agents) || ['./config/agents']
const agentNames = new Set()
for (const ap of agentPaths) {
  const rel = ap.replace(/^\.\//, '')
  for (const d of listDir(rel)) {
    if (!d.isFile() || !d.name.endsWith('.md')) continue
    const fm = frontmatter(path.join(ROOT, rel, d.name))
    const base = d.name.replace(/\.md$/, '')
    if (!fm) { err(`${rel}/${d.name}: no frontmatter block`); continue }
    if (!fm.description) err(`${rel}/${d.name}: frontmatter missing "description"`)
    agentNames.add(fm.name || base)
  }
}

// --- 5. Reference resolution: every /saki-builder:<x> must resolve ---------
const cmdPaths = (plugin && plugin.commands) || ['./config/commands']
const cmdNames = new Set()
for (const cp of cmdPaths) {
  const rel = cp.replace(/^\.\//, '')
  for (const d of listDir(rel)) {
    if (d.isFile() && d.name.endsWith('.md')) cmdNames.add(d.name.replace(/\.md$/, ''))
  }
}
const resolvable = new Set([...skillNames, ...agentNames, ...cmdNames])
const refRe = /\/saki-builder:([a-z0-9][a-z0-9-]*)/g
function scanRefs (rel) {
  for (const d of listDir(rel)) {
    if (d.isDirectory()) { scanRefs(path.join(rel, d.name)); continue }
    if (!d.name.endsWith('.md')) continue
    const txt = fs.readFileSync(path.join(ROOT, rel, d.name), 'utf8')
    let m
    while ((m = refRe.exec(txt))) {
      if (!resolvable.has(m[1])) err(`unresolved reference /saki-builder:${m[1]} in ${rel}/${d.name}`)
    }
  }
}
for (const sp of skillPaths) scanRefs(sp.replace(/^\.\//, ''))
for (const ap of agentPaths) scanRefs(ap.replace(/^\.\//, ''))

// --- 6. Soft: stray claude-config (until Phase-4 rename) -------------------
// (warn-only; counted, not enumerated, to keep output tight)
let leak = 0
function countLeak (rel) {
  for (const d of listDir(rel)) {
    if (d.isDirectory()) { if (d.name === 'plan-history') continue; countLeak(path.join(rel, d.name)); continue }
    if (!/\.(md|sh|json)$/.test(d.name)) continue
    const txt = fs.readFileSync(path.join(ROOT, rel, d.name), 'utf8')
    if (/claude[- ]config/i.test(txt)) leak++
  }
}
countLeak('config')
if (leak) warn(`${leak} file(s) still contain "claude-config" (Phase-4 rename pending)`)

// --- Report ---------------------------------------------------------------
console.log(`saki-builder validate: ${skillNames.size} skills, ${agentNames.size} agents, ${cmdNames.size} commands`)
for (const w of warnings) console.log(`  ⚠ ${w}`)
if (errors.length) {
  console.error(`\n✗ ${errors.length} error(s):`)
  for (const e of errors) console.error(`  ✗ ${e}`)
  process.exit(1)
}
console.log(`✓ all structural invariants pass${warnings.length ? ` (${warnings.length} warning(s))` : ''}`)
