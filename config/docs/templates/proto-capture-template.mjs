// __PROTO__ throwaway — headless capture template for /saki-builder:proto Step 6a.
// TRANSCRIBE CONTRACT: (1) read this file, (2) fill the SCREENS array from this run's real
// journey (GATE 1 manifest order + 6a-bis anchors), (3) write the completed result to
// tasks/proto-<slug>/proto-capture.mjs, (4) run `node tasks/proto-<slug>/proto-capture.mjs`.
// Do NOT reinvent this from memory: the __PROTO__ live-DOM sentinel gate, the pageerror hook
// and the error-boundary check are what stop a crashed render being screenshotted.
// Screenshots every frame AND measures each journey hotspot in one headless pass, emitting
// hotspots.json for 6b. THIS FILE is the permanent template; the per-run COPY you write to
// tasks/proto-<slug>/proto-capture.mjs is the throwaway one deleted at /saki-builder:build teardown.
import { chromium } from 'playwright'          // npm i -D playwright && npx playwright install chromium
import { writeFileSync, mkdirSync, readFileSync, existsSync } from 'node:fs'
import { dirname, join } from 'node:path'; import { fileURLToPath } from 'node:url'

const OUT = dirname(fileURLToPath(import.meta.url))           // = tasks/proto-<slug>/
// The served route comes from Step 5.5's record — a native read, no `jq` dependency.
// NEVER default to a guessed port: a wrong URL yields a gallery of failed frames, and
// `localhost` resolves to IPv6 ::1 first on macOS while the server binds IPv4 (7a gotcha #3).
function baseUrl () {
  if (process.env.PROTO_URL) return process.env.PROTO_URL     // manual-debug override
  const rec = join(OUT, 'devserver.json')
  if (!existsSync(rec)) throw new Error(`devserver.json missing in ${OUT} — Step 5.5 did not run (or its record was cleaned). Re-run /saki-builder:proto; it resumes at Step 5.5.`)
  let parsed                                                  // a half-written record is EXPECTED (see Step 0.5)
  try { parsed = JSON.parse(readFileSync(rec, 'utf8')) }
  catch { throw new Error(`devserver.json is not valid JSON — a partial write. Re-enter Step 5.5.`) }
  const { url } = parsed
  if (!url) throw new Error(`devserver.json has no "url" — the record is stale/partial. Re-enter Step 5.5.`)
  return `${url}/proto-preview`
}
const BASE = baseUrl()
const VIEWPORTS = { desktop: [1280, 832], mobile: [390, 844] }

// One entry per SCREEN in journey order. `states` maps state→a suffix on BASE (a ?state= value or path).
// `anchor` (6a-bis) = the control that advances to the next screen: CSS `sel`, or {role,name}. Omit on last.
const SCREENS = [
  { slug:'slice1', states:{ page:'?state=happy', empty:'?state=empty', error:'?state=error' },
    anchor:{ to:1, label:'<affordance>', sel:'[data-testid="primary-cta"]' } },
  // …one per screen in journey order. Last screen: anchor:{ to:0, label:'↺ Restart', sel:'…' } or no anchor
]
const pct = (b,W,H) => b && { x:+(b.x/W*100).toFixed(2), y:+(b.y/H*100).toFixed(2), w:+(b.width/W*100).toFixed(2), h:+(b.height/H*100).toFixed(2) }

mkdirSync(OUT, { recursive:true })
const browser = await chromium.launch()
const hotspots = {}                                          // slug -> { to, label, desktop:{}, mobile:{} }
const FAILED = []                                            // frames that crashed/blanked — must NOT be screenshotted
for (const [vp,[W,H]] of Object.entries(VIEWPORTS)) {
  const ctx = await browser.newContext({ viewport:{width:W,height:H}, deviceScaleFactor:2 })
  const page = await ctx.newPage()
  let pageErr = null
  page.on('pageerror', e => { pageErr = e.message })         // a CLIENT-side throw during render (missing import/provider)
  for (const s of SCREENS) {
    for (const [state, suffix] of Object.entries(s.states)) {
      pageErr = null
      await page.goto(BASE + suffix, { waitUntil:'networkidle' })
      // HARD render gate — NEVER screenshot a crashed/blank render (the "error page captured N×" false-green).
      // The sentinel must be in the LIVE DOM (not just SSR HTML — a client throw slips past a curl of the SSR).
      const rendered = await page.waitForSelector('text=__PROTO__', { timeout:8000 }).then(()=>true).catch(()=>false)
      const boundary = await page.locator("text=/couldn['’]t load|Application error|__next_error__|Unhandled Runtime Error/i").count()
      if (!rendered || pageErr || boundary) {                // fail the frame, do NOT capture it
        FAILED.push(`${s.slug}-${state}-${vp}: ${pageErr || (boundary ? 'error boundary rendered' : 'no __PROTO__ sentinel in DOM')}`)
        continue                                             // fix 5a (providers) / 5c (auth), then re-run
      }
      await page.waitForTimeout(400)
      await page.screenshot({ path:`${OUT}/${s.slug}-${state}-${vp}.png` })
    }
    if (s.anchor && (s.anchor.sel || s.anchor.name)) {        // measure hotspot on the page state
      await page.goto(BASE + s.states.page, { waitUntil:'networkidle' }); await page.waitForTimeout(300)
      const loc = s.anchor.sel ? page.locator(s.anchor.sel).first()
                               : page.getByRole(s.anchor.role||'button', { name:new RegExp(s.anchor.name) }).first()
      const box = await loc.boundingBox().catch(()=>null)
      hotspots[s.slug] = Object.assign(hotspots[s.slug]||{ to:s.anchor.to, label:s.anchor.label }, { [vp]: pct(box,W,H) })
    }
  }
  await ctx.close()
}
await browser.close()
writeFileSync(`${OUT}/hotspots.json`, JSON.stringify(hotspots, null, 2))
if (FAILED.length) {                                          // ANY crashed frame ⇒ capture FAILED; never proceed to the gallery
  console.error('CAPTURE FAILED — these frames did not render (fix providers 5a / auth 5c, never ship an error frame):\n' + FAILED.join('\n'))
  process.exit(1)                                            // non-zero exit halts the run BEFORE the Coverage Gate / gallery
}
console.log('captured screenshots + hotspots.json')
