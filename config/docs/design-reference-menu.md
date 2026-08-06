# Design Reference Menu

A curated set of design archetypes — a **last-resort elicitation aid**, not the primary way to choose
a look. The primary path is the Design System Contract's **Part 0 Step 1**: pin a DIRECTIONAL
REFERENCE from the product's *own world* (materials, vernacular, artifacts). This menu exists only for
when a non-designer stalls on that — it gives them an axis to calibrate against and a springboard back
to their own world.

**⚠ An archetype is a springboard, never a destination.** Picking a row raw reproduces the exact
AI-default *tells* the contract's Part F names — R4 Aesop → cream+serif+terracotta, R6 Poster →
near-black+acid, R2 Duolingo → cream+serif+warm-orange. Always push past the archetype: *"Closest to
Aesop-restrained? Good — now what in YOUR product's world gives that restraint?"* The own-world anchor
is what makes it specific; the archetype only names the neighbourhood.

**How the skills use it**
- `/saki-builder:genesis` Part 0 Step 1 — **only if** the world-questions stall: offer a pick-1 axis via
  `AskUserQuestion`, then redirect to an own-world anchor. Feed that anchor (not the archetype) to Step 2.
- `/saki-builder:proto` — inherits the pinned own-world reference from `design.md`; the reference-judge grades
  output against **Part F tells + the pinned reference**, not against a menu row.
- **Calibration axes, not a paint-by-numbers:** use a row to locate warm↔cool · dense↔airy · quiet↔loud,
  then leave. Blends are fine as *starting* coordinates ("Stripe structure + Duolingo warmth").

---

## Quick navigator (pick by feel)

| | **Cool / precise** | **Warm / human** | **Bold / expressive** |
|---|---|---|---|
| **Dense** | R1 Linear · R8 Terminal | R3 Stripe | R6 Poster |
| **Balanced** | R7 Apple · R12 GOV.UK | R2 Duolingo · R5 Notion | R9 Indie |
| **Airy** | — | R4 Aesop · R10 Editorial · R11 Calm | — |

Axes the menu spans: warm↔cool · dense↔airy · quiet↔loud · playful↔serious · restrained↔expressive.
If two products would pick the same row, they're not differentiated enough — that's the coverage test.

---

## The archetypes

### R1 · Linear — *the calm instrument*
- **Feels:** precise · calm · keyboard-first
- **Best for:** developer tools, B2B pro apps, anything power-users live in daily
- **Tokens:** cool grey-blue neutrals + one restrained accent · grotesque sans, tight tracking, small sizes · dense-but-breathing · 6–8px radius, hairline borders, near-flat elevation · motion: minimal & fast · **signature:** everything has a shortcut; keyboard-first
- **Slop-trap:** goes cold and lifeless — all grey, zero warmth, feels like a spec
- **Not this if:** audience is casual or first-time (too austere)

### R2 · Duolingo — *the warm coach*
- **Feels:** warm · rewarding · encouraging (playful, never childish)
- **Best for:** learning, health, habit, consumer onboarding — anything that must *feel kind*
- **Tokens:** warm palette + one friendly accent · rounded sans, generous sizes · balanced density · pill/12–16px radius, soft shadows · motion: rewarding micro-interactions (count-ups, gentle bounce) · **signature:** progress made emotional (streaks, celebration)
- **Slop-trap:** tips into childish — emoji overload, cartoon mascots, exclamation-mark copy
- **Not this if:** audience is expert/professional (reads as unserious)

### R3 · Stripe — *the trusted operator*
- **Feels:** precise · trustworthy · typographic
- **Best for:** fintech, payments, B2B where **credibility** is the conversion
- **Tokens:** cool neutrals + a confident single accent (often blue/indigo) · clean sans, strong type hierarchy · structured, generous-but-dense · 8px radius, subtle depth · motion: smooth, purposeful · **signature:** the docs/typography carry the brand; nothing feels risky
- **Slop-trap:** becomes generic-SaaS (the exact gradient-hero mean) if the type discipline drops
- **Not this if:** you want warmth or play (too buttoned-up)

### R4 · Aesop — *the quiet premium*
- **Feels:** restrained · premium · editorial
- **Best for:** luxury, lifestyle, commerce, hospitality — where **subtraction** signals quality
- **Tokens:** warm paper + near-black ink, near-monochrome, one muted accent used *once* · refined serif + sans, generous leading · airy (space is the luxury) · minimal/no radius, hairline rules, no shadow · motion: barely-there · **signature:** precise baseline rhythm; understated, specific copy
- **Slop-trap:** **costume luxury** — black + gold + centered serif + "Timeless Elegance" (passes a naive checklist, still slop)
- **Not this if:** the product is utilitarian or data-heavy (restraint reads as empty)

### R5 · Notion — *the calm canvas*
- **Feels:** approachable · flexible · content-forward
- **Best for:** productivity, docs, knowledge tools, flexible workspaces
- **Tokens:** soft neutrals, low chroma · humanist sans + occasional serif accent · balanced, content-first · 4–6px radius, very subtle borders · motion: gentle · **signature:** the content is the UI; chrome recedes
- **Slop-trap:** so neutral it disappears — no point of view, indistinguishable from a wiki template
- **Not this if:** you need energy or a strong first impression (too quiet)

### R6 · Brutalist Poster — *the loud statement*
- **Feels:** loud · kinetic · confident
- **Best for:** events, culture, streetwear, launches, brands that must be *unmissable*
- **Tokens:** committed 2-colour (often acid/hot on near-black or bone) · heavy display type, huge scale contrast, tight tracking · structured grid with tension · no/sharp radius, no shadow · motion: expressive, bold · **signature:** type IS the hero; hierarchy = scale (billing, headlines)
- **Slop-trap:** **busy-generic** — festival gradient + emoji + equal cards = noise, not energy (loud without a spine)
- **Not this if:** the product needs calm, trust, or long reading (exhausting)

### R7 · Apple / Things — *the refined focus*
- **Feels:** refined · focused · considered
- **Best for:** premium consumer software, tools that want to feel *inevitable*
- **Tokens:** cool near-white, tight neutral palette, sparing accent · SF-like sans, precise scale · airy, lots of white · 10–14px radius, subtle depth/blur · motion: fluid, physical · **signature:** obsessive alignment; every gap is intentional
- **Slop-trap:** hollow imitation — big whitespace with nothing considered inside it
- **Not this if:** you're dense/data-heavy or scrappy-indie (too precious)

### R8 · Terminal / Bloomberg — *the dense instrument*
- **Feels:** utilitarian · information-dense · no-nonsense
- **Best for:** ops dashboards, trading, monitoring, data-heavy internal tools
- **Tokens:** dark, cool · mono for all data, tabular numerals · maximum density · no radius, thin dividers · one status accent scale (green/amber/red), nothing decorative · motion: none (data must be still) · **signature:** scannable in 2s, every pixel is information
- **Slop-trap:** consumer-app defaults bolted on — gradient hero + emoji stat cards on a data tool
- **Not this if:** audience is casual (overwhelming) — this is for people who stare at it all day

### R9 · Indie / Gumroad — *the playful character*
- **Feels:** cheerful · characterful · human
- **Best for:** creator tools, indie SaaS, products that win on *personality*
- **Tokens:** warm + saturated, confident colour blocking · chunky sans, sometimes a display quirk · balanced, a little loose · chunky radius, hard/offset shadows (not soft) · motion: bouncy, characterful · **signature:** one memorable, slightly irreverent detail
- **Slop-trap:** random-fun — mismatched colours and effects with no system, "quirky" as an excuse for chaos
- **Not this if:** you need enterprise trust or premium restraint

### R10 · Editorial / NYT — *the literary authority*
- **Feels:** authoritative · literary · story-first
- **Best for:** media, long-form, research, content-led products
- **Tokens:** restrained, near-monochrome + one editorial accent · serif headlines + clean sans body, real column measure · airy, columnar · minimal radius, hairline rules · motion: restrained · **signature:** typography does the work; reads like a considered page
- **Slop-trap:** blog-template — serif headline slapped on a generic card layout
- **Not this if:** the product is a fast-interaction tool (reading rhythm fights utility)

### R11 · Calm / Oura — *the serene ambient*
- **Feels:** serene · ambient · gentle
- **Best for:** wellness, meditation, sleep, reflective/personal data
- **Tokens:** deep dark or soft dusk, low-contrast-but-accessible · light sans, generous leading · airy · soft radius, no hard edges · **gradients used *well*** (subtle, atmospheric), generative/organic motion · **signature:** the interface breathes; motion is the mood
- **Slop-trap:** the wellness cliché — purple-blue gradient + lotus emoji + "Find your calm"
- **Not this if:** the task is urgent or dense (ambient = slow, wrong for speed)

### R12 · GOV.UK — *the plain trust*
- **Feels:** plain · accessible · trustworthy
- **Best for:** civic, health, high-stakes forms, anything where **clarity is safety**
- **Tokens:** high-contrast, minimal palette, one clear action colour · system font, large legible sizes · balanced, generous line length · minimal radius, strong focus states · motion: none/functional only · **signature:** ruthless legibility; zero decoration, WCAG AA+ by default
- **Slop-trap:** dressing it up — adding "polish" (gradients, icons) that erodes the clarity that IS the design
- **Not this if:** the product competes on delight or brand expression (plainness reads as unfinished)

---

## Anti-reference (fill this too)

Picking what it must **NOT** feel like is as sharp as picking what it should. Common anti-refs:
`generic SaaS dashboard` · `Bootstrap admin template` · `costume-luxury (black+gold)` · `wellness-gradient
cliché` · `childish/emoji-heavy` · `enterprise-2010`. The reference-judge uses this as its reject set.

## Rendering in the interview

```
Which should it feel like?  (pick 1–2)
 ◉ R2 Duolingo   — warm, rewarding, encouraging
 ○ R1 Linear     — precise, calm, keyboard-first
 ○ R4 Aesop      — quiet, premium, restrained
 ○ R3 Stripe     — precise, trustworthy, typographic
And one it must NOT feel like?  → [ generic SaaS dashboard ]
```
`AskUserQuestion` renders each option with its vibe line as the description; the user picks, and the
skill copies that row's tokens into the brief's §2.

## Mapping to the pressure tests (proof of coverage)

| Pressure test | Archetype |
|---|---|
| #1 warm education app | **R2 Duolingo** |
| #2 dev platform | **R1 Linear** + **R8 Terminal** |
| #3 boutique hotel | **R4 Aesop** |
| #4 music festival | **R6 Poster** |
| wow / year-in-review | **R11 Calm** (ambient motion) + a **creative concept** |

All four hand-built tests fall cleanly on a menu row — evidence the 12 span the real space rather
than clustering. A product that fits *none* of these is the signal to add R13, not to force a bad pick.
