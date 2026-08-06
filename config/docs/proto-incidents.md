# /saki-builder:proto — incident record (why each gate exists)

**Loaded on demand, never automatically.** `config/skills/proto/SKILL.md` carries the *rules*; this file
carries the *war stories* that produced them. Read it when you are about to weaken, remove, or argue with
a proto gate — every entry below is a failure that actually shipped.

Each heading names the gate's owning Step so the rule and its rationale stay linked in both directions.

---

## Screen Manifest — a thin manifest passes a gate that is blind to it (GATE 1)

A run listed only the PRD's explicit §8 slices in `screen-manifest.md`. Every implied screen — error paths,
role branches, entry/exit glue, shell affordances — never made the list. The Coverage Gate then compared
captured frames against the *manifest* and passed, while the gallery was missing screens the PRD plainly
required. **The gate verifies captured == manifested; it is blind to an omission in the manifest itself.**
That is why GATE 1 interrogates the PRD with curiosity ("what screen does this criterion imply?") before
freezing the manifest, rather than transcribing §8 mechanically.

## Reuse map — the "design-wise correct" render that isn't the app (Step 2.4)

The most common proto failure: a render that is defensible as design but does **not** look like the existing
application, because the agent self-initiated a fresh design of the navbar / sidebar / feature screen instead
of composing the components already implemented. Presence of a good-looking screen is not evidence it reused
the real implementation — which is why Step 5d's provenance check greps for the recorded import paths.

## Gap analysis — spec-and-rebuild of something already shipped (Step 2.4 Guard)

A run sent an already-implemented component into the 2.5 gap analysis as "new", specced it, and rebuilt it
differently. A `NEW` row is a **claim of absence** and must be proven by an empty grep of the real app.

## Codify-before-render — approving a stand-in (Step 2.6)

The original order rendered an *approximation* of a new component and codified it only after approval. The
human therefore approved a stand-in, and `/saki-builder:build` later rebuilt the real component differently.
Reversing the order (add it for real, then design with it) removed the drift entirely.

## Grounding — reinvented components under an invented brand (Step 5 gate)

A run skipped Step 2.4 and shipped reinvented components under a brand the app does not use. Prose-level
BLOCKING proved insufficient, so the Grounding gate became mechanical: no `reuse-map.md` / `screen-manifest.md`
⇒ no render.

## Resume — grounding laundered forward from the harness (Step 0.5 pt 7)

A resumed run found `reuse-map.md` missing but the harness present, and rebuilt the map by reverse-engineering
`StudioShell.tsx`'s imports. That re-shipped every original misclassification with fresh confidence. A missing
map plus a present harness is **inconsistent, not resumable** — the harness is UNTRUSTED and grounding is
re-derived from the real app.

## Capture — an error page screenshotted for every screen (Step 6a + Coverage Gate)

A missing import crashed the harness. The Next error boundary rendered for all screens, every PNG file
existed, and a presence-only Coverage Gate **PASSED** on a gallery of identical error frames. Two gates came
out of this: 6a hard-fails a frame whose live DOM lacks the `__PROTO__` sentinel or that throws a `pageerror`,
and the Coverage Gate asserts frames are DISTINCT — presence is not correctness.

## Figma Tier A — a wrong assumption about localhost (Step 6c)

An earlier draft warned that Tier A could not capture `localhost` because the server is remote. That is wrong:
capture is **client-side** (`capture.js` runs in the browser), so localhost works. Tier A's real requirement is
a browser session plus `capture.js`, not server→localhost reachability. Verified 2026-06-28.

## Name drift — typing the spec's product name onto a real screen (Step 2.4 name-drift check)

A net-new screen was rendered with the PRD/roadmap product name typed in, while the implemented UI renders a
different brand — the "Builder Workflow Studio" vs implemented "Saki Studio" drift. For a new screen the brand
is resolved from the real shell, and a mismatch is flagged for reconciliation, never auto-typed from the spec.

## Restatement drift — a Step that violated its own anti-pattern table (I2, 2026-07-20)

Before the Rules + Anti-patterns sections were collapsed, the same rule was stated in three places. Step 6c
line 1440 wrote `` `javascript_tool` `` — the exact loose form the anti-pattern table warned against two
sections below. Nobody noticed because keeping three copies in sync is not something anyone actually does.
This is the incident that motivated collapsing the restatement into the Steps plus one invariants list.
