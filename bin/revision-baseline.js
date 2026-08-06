#!/usr/bin/env node
'use strict'
// revision-baseline.js — measure the PRD revision-pass baseline across runs.
//
// WHY THIS EXISTS. Epic E1 ("proto-first loop") is Blocked on a discovery item: its headline outcome
// 5.1 — "minimize post-gate PRD revision passes" — was tagged `aspirational` because its cited
// baseline turned out to measure a different quantity (proto's RENDERED-OUTPUT corrections, not PRD
// revision passes). Without a measured starting point the epic cannot tell whether it worked, so
// three judges rejected it. E1 unblocks on a measured baseline from real PRD-first runs.
//
// WHAT IT READS, cheapest source first:
//   1. `<!-- revision-passes: N -->` in the PRD header — the durable counter, stamped by
//      /saki-builder:prd-review each time it APPLIES fixes. This is the authoritative source.
//   2. `tasks/.prd-review-<slug>-state.json` → review.rounds / review.blockers_fixed — the loop's own
//      live record. Accurate while a run exists, but `tasks/` is gitignored and state files rotate,
//      so it is a fallback, not the baseline.
//   3. `tasks/prd-<slug>-review.md` → the `**Round:** N` header — a per-round artifact, used only to
//      corroborate and to surface runs that never reached green.
//
// A round is a REVISION PASS only if fixes were applied. A review that read the PRD and changed
// nothing is not a pass, and the `blocked` escape applies no fixes either — counting those would
// inflate the baseline in the flattering direction, which is the exact error E1's review caught.
//
// Usage:  node bin/revision-baseline.js          # table + summary
//         node bin/revision-baseline.js --json   # machine-readable

const fs = require('fs')
const path = require('path')

const ROOT = path.resolve(__dirname, '..')
const TASKS = path.join(ROOT, 'tasks')
const JSON_OUT = process.argv.includes('--json')

const read = (p) => { try { return fs.readFileSync(p, 'utf8') } catch (_e) { return null } }
const readJSON = (p) => { try { return JSON.parse(fs.readFileSync(p, 'utf8')) } catch (_e) { return null } }

function slugsFromPRDs () {
  if (!fs.existsSync(TASKS)) return []
  return fs.readdirSync(TASKS)
    .filter((f) => f.startsWith('prd-') && f.endsWith('.md') && !f.endsWith('-review.md'))
    .map((f) => f.slice(4, -3))
    .sort()
}

function measure (slug) {
  const prd = read(path.join(TASKS, `prd-${slug}.md`))
  const state = readJSON(path.join(TASKS, `.prd-review-${slug}-state.json`))
  const record = read(path.join(TASKS, `prd-${slug}-review.md`))

  // 1. the durable counter
  const stamped = prd && /^<!--\s*revision-passes:\s*(\d+)\s*-->/m.exec(prd)
  // 2. the loop's live record
  const rounds = state?.review?.rounds ?? null
  const blockersFixed = state?.review?.blockers_fixed ?? null
  // 3. corroboration
  const recordRound = record && /\*\*Round:\*\*\s*(\d+)/.exec(record)
  const verdict = state?.review?.verdict ??
    (record && (/<!--\s*review-verdict:\s*([A-Z-]+)/.exec(record) || /\*\*Verdict:\*\*\s*([A-Z-]+)/.exec(record) || /Verdict:\s*\*\*([A-Z-]+)/.exec(record))?.[1]) ?? null
  const phase = state?.phase ?? null

  // A run counts toward the baseline only when it actually reached green — an in-flight or blocked
  // run has an unknown final pass count, and averaging it in would understate the true cost.
  const reachedGreen = phase === 'green' || verdict === 'SHIP'

  let passes = null
  let source = 'none'
  if (stamped) { passes = Number(stamped[1]); source = 'prd-header (durable)' }
  else if (rounds !== null) { passes = blockersFixed > 0 ? rounds : 0; source = 'state-file (fallback)' }
  else if (recordRound) { passes = Number(recordRound[1]); source = 'review-record (corroboration)' }

  return { slug, passes, source, rounds, blockersFixed, verdict, phase, reachedGreen, hasPRD: !!prd }
}

const rows = slugsFromPRDs().map(measure)
const usable = rows.filter((r) => r.reachedGreen && r.passes !== null)

if (JSON_OUT) {
  console.log(JSON.stringify({
    measured: usable.length,
    baseline: usable.length ? usable.reduce((a, r) => a + r.passes, 0) / usable.length : null,
    rows
  }, null, 2))
  process.exit(0)
}

console.log('PRD revision-pass baseline (E1 outcome 5.1)\n')
console.log('  ' + 'PRD'.padEnd(46) + 'passes  source                        verdict         green?')
console.log('  ' + '-'.repeat(46) + '------  ----------------------------  --------------  ------')
for (const r of rows) {
  console.log('  ' +
    r.slug.slice(0, 44).padEnd(46) +
    String(r.passes ?? '—').padEnd(8) +
    r.source.padEnd(30) +
    String(r.verdict ?? '—').padEnd(16) +
    (r.reachedGreen ? 'yes' : 'no'))
}

console.log('')
if (!usable.length) {
  console.log('  BASELINE: NOT MEASURABLE YET — 0 runs reached green.')
  console.log('')
  console.log('  Every PRD on disk is either in-flight, REVISE, or blocked. A revision-pass count from a')
  console.log('  run that never converged is not a baseline: the remaining passes are unknown, and')
  console.log('  averaging it in would understate the real cost — the same class of error that got E1')
  console.log("  rejected (a cited baseline that measured a different quantity).")
  console.log('')
  console.log('  To measure it: run /saki-builder:pickup <E|F id> on a real PRD-track item and let the')
  console.log('  prd ↔ prd-review loop reach SHIP · READY. prd-review now stamps <!-- revision-passes: N -->')
  console.log('  into the PRD header on every round it applies fixes, so the run measures itself.')
} else {
  const avg = usable.reduce((a, r) => a + r.passes, 0) / usable.length
  console.log(`  BASELINE: ${avg.toFixed(1)} revision passes per PRD  (n=${usable.length} run${usable.length > 1 ? 's' : ''} that reached green)`)
  if (usable.length < 2) {
    console.log('  ⚠ n=1 — E1 asks for 1–2 runs. A second raises confidence before the epic rests on it.')
  }
}
