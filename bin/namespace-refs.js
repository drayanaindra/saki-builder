#!/usr/bin/env node
'use strict'
// saki-builder — namespace internal skill references.
//
// Plugin skills/commands are invoked namespaced (/saki-builder:<name>). This rewrites BARE
// internal references (/rplan, /prd, /build, …) in skill + agent bodies to /saki-builder:<name>,
// but ONLY for names that are actually OUR skills (top-level dirs in config/skills). External
// commands (/code-review, /security-review, /simplify, /verify, /init, /review, /clear) are not
// in that set, so they are left bare automatically.
//
// Guards against false hits:
//   - lookbehind (?<![\w:./~*-]) — the slash must not be inside a path (skills/rplan, ./sync.sh,
//     ~/x, **/prd.md) or an already-namespaced ref (/saki-builder:rplan → "rplan" preceded by ':').
//   - lookahead  (?![-\w/])  — the name must be whole and not a path segment (/rplan/template.md)
//     or a longer skill (/prd never matches inside /prd-review).
//
// REVERSE (--reverse): the inverse pass, for opencode. opencode registers our skills under their
// BARE name (/rplan), so a bridged body telling the model to run /saki-builder:rplan points at a
// command that does not exist there. --reverse strips the namespace back off, guarded the same way:
// a path context (skills/saki-builder:rplan, ./saki-builder:qa) is never touched.
//
// Usage:  node bin/namespace-refs.js --dry                    (preview, writes nothing)
//         node bin/namespace-refs.js                          (apply, forward, repo skills+agents)
//         node bin/namespace-refs.js --reverse --dir <path>   (strip namespace under <path>)
//         node bin/namespace-refs.js --dir config --exclude antigravity-skills --exclude plan-history

const fs = require('fs')
const path = require('path')

const ROOT = path.resolve(__dirname, '..')
const DRY = process.argv.includes('--dry')
const REVERSE = process.argv.includes('--reverse')
const PREFIX = 'saki-builder'

// --dir <path>: scan this tree instead of the repo's config/skills + config/agents. Required when
// rewriting a BRIDGED output dir (e.g. ~/.config/opencode/skills) rather than the sources.
const dirFlag = process.argv.indexOf('--dir')
const DIR = dirFlag !== -1 ? process.argv[dirFlag + 1] : null
// Reject a missing value AND a following flag: `--dir --dry` would otherwise set DIR='--dry',
// scan a nonexistent tree, and print "0 refs across 0 files" with exit 0 — a silent no-op that
// reads exactly like "already fully namespaced".
if (dirFlag !== -1 && (!DIR || DIR.startsWith('--'))) {
  console.error('namespace-refs: --dir needs a path')
  process.exit(1)
}

// --exclude <substring>: repeatable. Skips any file whose path (relative to BASE) contains the
// substring. This gates FILE SELECTION only — the regex and its guards are untouched.
//
// Why it exists: `mdFiles` recurses over every `.md` under BASE, so `--dir config` would also rewrite
// config/antigravity-skills/ — which setup-antigravity.sh installs into a Gemini/Antigravity runtime
// where the `saki-builder:` namespace does not exist at all — and config/docs/plan-history/, which is
// historical record. Rewriting either points text at a command its reader cannot resolve.
const EXCLUDES = []
for (let i = 0; i < process.argv.length; i++) {
  if (process.argv[i] !== '--exclude') continue
  const val = process.argv[i + 1]
  // Reject a missing value AND a following flag, so `--exclude --dry` can't silently swallow --dry
  // and leave the run unfiltered — the failure mode this flag exists to prevent.
  if (!val || val.startsWith('--')) {
    console.error('namespace-refs: --exclude needs a substring')
    process.exit(1)
  }
  EXCLUDES.push(val)
}
// Track which excludes actually fired. An --exclude that matches nothing is the dangerous case: the
// run still prints "(excluding X)" while rewriting the very tree X was meant to protect. Excludes are
// BASE-relative, so the natural repo-relative spelling (`config/antigravity-skills` under
// `--dir config`) matches nothing — a typo and a wrong prefix look identical without this check.
const EXCLUDE_HITS = new Set()

// OUR invocable skills = top-level dirs under config/skills (nested library skills are
// user-invocable:false docs, never slash-invoked, so not namespace targets).
const skillsRoot = path.join(ROOT, 'config', 'skills')
const names = fs.readdirSync(skillsRoot, { withFileTypes: true })
  .filter((d) => d.isDirectory() && fs.existsSync(path.join(skillsRoot, d.name, 'SKILL.md')))
  .map((d) => d.name)
  .sort((a, b) => b.length - a.length) // longest first (defensive)

// One combined alternation, whole-word, not-already-namespaced, not-a-path.
// Forward: /rplan -> /saki-builder:rplan.  Reverse: /saki-builder:rplan -> /rplan.
// Both share the same lookbehind/lookahead guards, so a path context is never rewritten either way.
// The two directions need DIFFERENT trailing guards. Forward must reject a trailing `.` because
// `/rplan/template.md` and `/prd.md` are path/file references that were never commands. Reverse
// cannot: `/saki-builder:rplan` is unambiguously a command, and it ends a sentence constantly
// ("…then run /saki-builder:rplan."). Blocking `.` there silently left ~18 refs namespaced — a
// command opencode does not have. `/` stays blocked in both so real paths are never rewritten.
const alt = names.map((n) => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|')
const re = REVERSE
  ? new RegExp(`(?<![\\w:./~*-])/${PREFIX}:(${alt})(?![-\\w/])`, 'g')
  : new RegExp(`(?<![\\w:./~*-])/(${alt})(?![-\\w/.])`, 'g')
const replace = REVERSE ? (n) => `/${n}` : (n) => `/${PREFIX}:${n}`

// Walk .md files under a root dir (recursive) or a single file. Paths are relative to BASE.
const BASE = DIR ? path.resolve(DIR) : ROOT
function mdFiles (rel) {
  const abs = path.join(BASE, rel)
  if (!fs.existsSync(abs)) return []
  // When BASE itself is a file, `rel` is '.', which never ends in .md — test the real path instead,
  // so `--dir path/to/AGENTS.md` targets that one file.
  if (fs.statSync(abs).isFile()) return abs.endsWith('.md') ? [rel] : []
  const out = []
  for (const d of fs.readdirSync(abs, { withFileTypes: true })) {
    const child = path.join(rel, d.name)
    const hit = EXCLUDES.find((e) => child.includes(e))
    if (hit) { EXCLUDE_HITS.add(hit); continue }
    if (d.isDirectory()) out.push(...mdFiles(child))
    else if (d.name.endsWith('.md')) out.push(child)
  }
  return out
}

const targets = DIR ? mdFiles('.') : [...mdFiles('config/skills'), ...mdFiles('config/agents')]

const deadExcludes = EXCLUDES.filter((e) => !EXCLUDE_HITS.has(e))
if (deadExcludes.length) {
  console.error(`namespace-refs: --exclude matched nothing: ${deadExcludes.join(', ')}`)
  console.error('  excludes are relative to --dir; under `--dir config` use `antigravity-skills`, not `config/antigravity-skills`.')
  process.exit(1)
}
let totalHits = 0
let filesChanged = 0
const perFile = []

for (const rel of targets) {
  const abs = path.join(BASE, rel)
  const txt = fs.readFileSync(abs, 'utf8')
  let hits = 0
  const next = txt.replace(re, (_m, n) => { hits++; return replace(n) })
  if (hits > 0) {
    totalHits += hits
    filesChanged++
    perFile.push([rel, hits])
    if (!DRY) fs.writeFileSync(abs, next)
  }
}

perFile.sort((a, b) => b[1] - a[1])
console.log(`${DRY ? '[dry-run] ' : ''}namespace-refs${REVERSE ? ' [reverse]' : ''}: ${names.length} skill names, ${totalHits} refs across ${filesChanged} files${DIR ? ` under ${DIR}` : ''}${EXCLUDES.length ? ` (excluding ${EXCLUDES.join(', ')})` : ''}`)
for (const [rel, hits] of perFile.slice(0, 20)) console.log(`  ${String(hits).padStart(4)}  ${rel}`)
if (perFile.length > 20) console.log(`  … +${perFile.length - 20} more files`)
if (DRY) console.log('\n(no files written — rerun without --dry to apply)')
