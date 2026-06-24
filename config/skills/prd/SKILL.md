---
name: prd
description: Generate Product Requirements Document from feature intent/description
type: generate
project_types: [web-app, api, library, cli, tui]
trigger: "create PRD, generate requirements, write specification"
inputs:
  - name: feature
    description: Feature description or intent to be built
    required: true
  - name: audience
    description: Target user/audience for this feature
    required: false
    default: "end users"
  - name: research
    description: Pass --research to enable Tier-2 external grounding (deep-research + MCP) in Step 0.7. Off by default; Tier-1 local grounding always runs.
    required: false
    default: "false"
---

## Context

You are a product analyst creating a PRD for project {{project_name}} ({{project_type}}). Stack: {{stack}}.

The PRD is a *bridge* from product intent to the XP planning game (`/rplan` → `/approved` → `/qa`). It owns *what* vertical slices exist and *why*; `/rplan` owns *how* to execute each slice file-by-file. Do not decompose slices into file-level atomic tasks in the PRD — that is BDUF and short-circuits `/rplan`'s confidence gate.

Format borrows from Klement (Job Story), Ulwick (outcome statements), Shape Up (appetite, no-gos, rabbit holes), and Beck/Wake (INVEST + TDD-ready slices).

**This skill gates on substance, not just completeness.** A PRD with every section present but hollow is a failure. Two gates enforce this and neither is optional: a **Premise Gate** (Step 0) before you write anything, and a scored **PRD Quality Gate** (step 6) before you present.

## Step 0 — Scope & Premise Gate (BLOCKING — before any section)

The feature intent must survive two checks. If it can't, you don't have a PRD — you have a discovery task.

### 0a. Scope clarification

If ANY of these is ambiguous or missing from `{{input.feature}}`, ask before proceeding (accept terse 1–2 word answers; skip entirely if all four are already inferable):

```
Quick scope check:
Who?      [which user/role experiences this]
When?     [the trigger — when/how the job arises]
Output?   [one concrete example of the expected outcome]
Boundary? [what is explicitly out of scope]
```

If the user says "you decide" → make reasonable defaults and STATE them so they can correct.

### 0b. Premise pressure-test

In scratch (not yet the file), write:

1. **Load-bearing assumption** — the ONE thing that, if false, makes this PRD not worth building. Tag it `assumed | observed | validated`. If `assumed`, name the cheapest validation (a spike, 5 user calls, one metric query).
2. **Three reasons this fails / shouldn't be built** — concrete, not strawmen (e.g. "a non-product fix is 10× cheaper", "the metric we'd move isn't tied to revenue", "the job is already solved by X"). Rebut or concede each.
3. **Verdict** — proceed / recut / stop.

**If the load-bearing assumption is `assumed` AND you cannot name a cheap validation, OR two of the three failure reasons stand unrebutted → STOP.** Do not produce a polished PRD for an unvalidated premise. Tell the user: *"This needs discovery before a PRD — the load-bearing assumption [X] is unvalidated. Recommend `/shaping-requirements` or a validation spike first."*

Carry the surviving premise into §2 and the kill criteria into §6.

## Step 0.7 — Evidence Grounding (between the Premise Gate and generation)

The `observed`/`validated` tags in §2 and the constraints in §12 are only as good as their sources. Ground them in two tiers. **Every `observed`/`validated` tag MUST cite its source — an uncited upgrade is fabrication and is penalised by the Quality Gate (step 6).**

### Tier 1 — Local grounding (ALWAYS run; free, no external calls)

Before writing §2 and §12, take every claim about *this* codebase/project — technical feasibility, "uses existing X", current behaviour, stack constraints — and verify it with grep/read:

- Code confirms it → tag `observed`, cite `path:line`.
- Code contradicts it → fix the claim (or drop the slice that depended on it).
- Not found in code → leave `assumed`.

This is the cheap, high-ROI tier. It never gets skipped and never calls the network.

### Tier 2 — External grounding (OPT-IN; OFF by default)

Parse ARGUMENTS for `--research` (or an explicit user request to "ground / validate / research" the PRD). **If absent, SKIP this tier entirely** — do not call web or MCP, and do not fabricate; unbacked claims stay `assumed` and surface via the `⚠ DISCOVERY-RISK` banner / Open Questions.

If `--research` IS set, ground **only the highest-leverage claims** — the load-bearing assumption from Step 0b plus the §5 outcome baselines/targets — not every row, to keep cost bounded:

- Market / competitor / user-behaviour / benchmark claims → run `/deep-research` (or a single `WebSearch` for a light check); tag `validated`, cite the URL.
- Internal metric baselines / usage data → query a connected MCP server (e.g. Notion, Google Drive, an analytics DB); tag `observed`/`validated`, cite the source.
- State explicitly which rows you left `assumed` (did NOT research) so the user sees the boundary.

**Cost contract:** Tier 1 is free and always runs; Tier 2 fires only on `--research` and is capped to the load-bearing + baseline claims. A default `/prd` spends nothing on tools; a researched `/prd` spends predictably.

## Instructions

1. Analyze the feature intent: "{{input.feature}}" — having passed Step 0.

2. Produce a PRD with the following sections. **MUST** = required in every PRD; **MAY** = only when its trigger applies.

   1. **TL;DR** (MUST) — ≤3 sentences: user problem, chosen solution shape, appetite.
   2. **Problem & Evidence** (MUST) — 1–2 sentence problem statement that names a **measurable harm** (not a feature absence) plus an evidence table. Tag each claim `assumed | observed | validated`. **Evidence floor: ≥1 `validated` claim OR a named validation spike in §11. A 100%-`assumed` table ships the PRD with a `⚠ DISCOVERY-RISK` banner at the top.** Every `observed`/`validated` tag cites its source (`path:line`, URL, or MCP query) per Step 0.7 — an uncited upgrade is fabrication.
   3. **Primary Job to be Done** (MUST) — exactly one Job Story, Klement format: `When [situation], I want to [motivation], so I can [expected outcome].` Forbidden: "As a [role], I want…" persona stories. Two primary jobs = two PRDs.
   4. **Related Jobs** (MAY, 0–3) — same format. Hard cap 3.
   5. **Desired Outcomes / Success Metrics** (MUST) — 1 primary + 2–3 secondary + ≥1 counter-metric, Ulwick form: `Minimize/Maximize [metric] of [object] when [context].` Each outcome lists `target`, `basis`, `measurement method`, and the JTBD it serves.
      - **Target basis** (required): tag each target `baseline N→M` (current value known) / `benchmark` (external comparable) / `aspirational` (no baseline — allowed but flagged). A bare number with no basis is fabricated precision — fix it.
      - **Measurement feasibility** (required): the method must be instrumentable with what exists or is in-scope. If not, move the outcome to §11 Open Questions — never assert a metric you cannot measure.
      - **Counter-metric linkage** (required): the counter-metric must name *which* metric's failure mode it guards (e.g. "guards 5.1: faster onboarding gamed by skipping verification → fraud"). A counter-metric with no causal link to a gamed metric is theater — replace it.
   6. **Appetite & Kill Criteria** (MUST) —
      - *Appetite*: denominate in **agent-iterations** (`~6 atomic agent tasks`, `1 afternoon × 1 agent`) with an effort recut threshold.
      - *Kill criteria* (outcome-tied): the §5 metric + threshold at which you STOP building (e.g. "if eval pass-rate < 80% after slice 5, kill"). This is the product failing — distinct from the effort recut.
   7. **Solution Shape** (MUST) — prose + optional ASCII flow. *Shape*, not design. No wireframes, DB schemas, or API signatures.
   8. **Vertical Slices** (MUST) — numbered. Each: `verb-phrase title`, `Serves JTBD:`, `Serves outcome: #`, 1–2 sentence new-capability description. Apply the slice-quality test (step 3). **Cap ≤7 slices — >7 means this is an epic; split into multiple PRDs.** Slice 1 should be a vertical walking skeleton (end-to-end value), not horizontal plumbing.
   9. **Acceptance Criteria per Slice** (MUST) — checklist or Given/When/Then. Each criterion executable (pass/fail unambiguous). Each links a §5 outcome (`→ 5.2`) OR names a guardrail. **Guardrail menu: `security | validation | error-path | accessibility | performance | privacy | observability | cost | i18n`.** Cap ≤5 criteria/slice (more = split signal).
   10. **Non-Goals** (MUST, ≥2) — `✗`-prefixed. The most-skipped section and the biggest source of mid-cycle scope explosion.
   11. **Rabbit Holes & Open Questions** (MUST) — *Rabbit holes:* traps to avoid. *Open questions:* each with `owner` + `decision deadline`. Headers stay even if empty.
   12. **Technical Constraints** (MAY) — stack-imposed limits.
   13. **Dependencies** (MAY) — other PRDs, infra, third-party APIs.
   14. **Rollout & Staging** (MAY, user-facing) — alpha → beta → GA. (Kill criteria live in §6.)

3. Slice quality test (INVEST + atomic-for-AI). Every slice passes all five:
   1. **Single user-visible capability.** "User can register with email" — not "auth system exists."
   2. **One ownership boundary.** ≤2 modules. FE+BE+DB in one slice → split.
   3. **Test-first feasible.** A failing test can be written before implementation (TDD RED).
   4. **Forward dependency only.** Slice N depends on 1..N-1, never N+1. Topological order = execution order. **Tiebreak: among dependency-eligible slices, sequence the one that retires the most risk (validates the load-bearing assumption) first.**
   5. **Fits one agent iteration (~30 min).** >5 acceptance criteria = two slices.

   Plus: **every slice traces to the primary or a related job** (no orphan slices).

4. Acceptance-criteria mapping rule. Every criterion in §9 answers one of:
   - Which §5 outcome does it measure? (`→ 5.x`)
   - Which guardrail does it enforce? (menu in §9)

   If neither → delete it (YAGNI).

5. **Self-Critique (BLOCKING — run before scoring).** Answer each; fix in-place, don't just flag:
   1. Is the Primary JTBD the *real* job, or a feature description dressed as a job? Rewrite if dressed.
   2. Does every slice trace to a JTBD? Cut or re-tie orphans.
   3. Is any §5 metric un-instrumentable with what exists/in-scope? Move to Open Questions.
   4. Could the primary metric be hit while harming the user — and does a counter-metric guard that exact path?
   5. Is Slice 1 a vertical walking skeleton, or horizontal plumbing mislabeled as vertical?
   6. Any target with fabricated precision (no basis tag)? Justify or tag `aspirational`.
   7. If the load-bearing assumption (Step 0) is false, does the PRD admit it (DISCOVERY-RISK banner / open question)?

6. **PRD Quality Gate (BLOCKING — replaces a presence-only checklist).** Score = 100 − Σ deductions. Every deduction cites the section/slice it came from; an uncited deduction is invalid.

   | Issue | Δ |
   |-------|---|
   | Step 0 Premise Gate not run / load-bearing assumption not stated | BLOCK (score 0) |
   | Primary JTBD in persona form ("As a…") | BLOCK |
   | Problem statement names no measurable harm | −5 |
   | Evidence table 100% `assumed`, no validation spike | −10 |
   | Claim tagged `observed`/`validated` with no cited source (`path:line` / URL / MCP) | −5 each |
   | Tier-1 local grounding skipped (codebase claims left `assumed` without a grep/read attempt) | −5 |
   | §5 outcome with a target but no basis tag | −3 each |
   | §5 measurement method not instrumentable and not an Open Question | −3 each |
   | Counter-metric names no metric/failure-mode it guards | −5 |
   | Kill criteria missing or not outcome-tied | −8 |
   | Orphan slice (serves no JTBD) | −5 each |
   | §5 outcome with no slice criterion linking to it | −5 each |
   | Acceptance criterion neither links an outcome nor names a guardrail | −3 each |
   | Slice fails any INVEST check | −5 each |
   | >7 slices, not split | −8 |
   | Non-Goals < 2 | −5 |
   | Self-Critique (step 5) not run | −10 |

   **Thresholds:**

   | Score | Action |
   |-------|--------|
   | ≥ 90 | Present the PRD |
   | 75–89 | Fix cited deductions, re-score — do NOT present |
   | < 75 | Return to Step 0 / discovery; the premise or shape is too weak |

   A score of 100 requires an explicit line: *"Premise validated, evidence floor met, all outcomes based + measurable + linked, every slice INVEST and JTBD-traced, kill criteria outcome-tied."* Do not lower deductions to clear the bar — that is the failure mode this gate exists to prevent.

7. Save the PRD to `tasks/prd-{{input.feature | slugify}}.md`. Lead the file with the score line and (if any) the `⚠ DISCOVERY-RISK` banner.

8. Present the PRD with its score, then ask: acceptable, or revise?

9. After approval, hand off to `/rplan` — one invocation per slice. Do NOT produce file-by-file tasks in the PRD.

## Script

```bash
#!/bin/bash
mkdir -p tasks
```

## Anti-patterns (reject on sight)

| Anti-pattern | Looks like | Fix |
|--------------|-----------|-----|
| Persona story | "As a user, I want to log in" | Klement: "When I return on a new device, I want to sign in quickly, so I can resume." |
| Horizontal slice as vertical | "Build the API layer" / "Set up the database" | Re-slice by user-visible capability: "User can submit X and see Y." |
| Orphan slice | A slice with no `Serves JTBD` that traces | Cut it, or tie it to a real job. |
| Evidence theater | Every claim tagged `assumed` | Get one `validated`, or list a validation spike + DISCOVERY-RISK banner. |
| Fabricated target | "<30s p50" with no current baseline | Tag `baseline N→M` or `aspirational`; never bare precision. |
| Goodhart counter-metric | "support tickets" guarding an unrelated speed metric | Name the metric + failure mode the counter-metric actually guards. |
| Effort kill ≠ product kill | "kill if > 8 tasks" as the only kill line | Add outcome-tied kill: the §5 metric+threshold at which the product is failing. |

## Validation (mechanical pre-flight — necessary, not sufficient; the Quality Gate is the real bar)

- [ ] Step 0 Premise Gate run; load-bearing assumption stated + tagged
- [ ] PRD saved as `tasks/prd-*.md`, with score line + any DISCOVERY-RISK banner at top
- [ ] All MUST sections present and in order
- [ ] TL;DR ≤3 sentences; problem statement names a measurable harm
- [ ] Evidence floor met (≥1 validated OR named spike); each claim tagged
- [ ] Step 0.7 Tier-1 local grounding run; codebase claims verified by grep/read and cited or left `assumed`
- [ ] Every `observed`/`validated` claim cites a source; Tier-2 (web/MCP) run only if `--research` set
- [ ] Exactly one Primary JTBD in Klement form; Related Jobs ≤3
- [ ] Each §5 outcome: Ulwick form + target + basis tag + measurement + JTBD link
- [ ] ≥1 counter-metric, linked to the metric/failure-mode it guards
- [ ] Appetite in agent-iterations + outcome-tied kill criteria
- [ ] Solution Shape has no wireframes/schemas/API signatures
- [ ] ≤7 slices, each passing all 5 INVEST checks + JTBD-traced
- [ ] Each slice ≤5 criteria; each criterion links an outcome OR names a guardrail
- [ ] Every §5 outcome has ≥1 linking criterion
- [ ] ≥2 Non-Goals; Rabbit Holes & Open Questions present
- [ ] Self-Critique (step 5) run; Quality Gate scored ≥90 with cited deductions
- [ ] No file-level / atomic-task breakdown (that's `/rplan`)

## Examples

### Example A — CRUD-shaped feature (auth)

```markdown
# PRD: User Authentication
> Quality Gate: 96/100. ✅ premise validated · evidence floor met · all outcomes based+linked.

## 1. TL;DR
Let new users create an account with email/password OR Google/GitHub OAuth, and let returning
users sign back in across devices. Appetite: ~6 agent iterations. Ships the auth surface only —
no account-management UI.

## 2. Problem & Evidence
Measurable harm: everything is anonymous, so we can't persist state, segment usage, or charge —
0% of sessions are attributable today.

| Claim | Source | Tag |
|-------|--------|-----|
| 70% of target users already have Google accounts | StatCounter 2026-Q1 | observed |
| Email signup is table-stakes | industry convention | assumed |
| GitHub login matters for our developer audience | 4 user interviews 2026-04 | validated |

## 3. Primary Job to be Done
When I land on the app for the first time, I want to create an account using credentials I
already trust, so I can start using the product without inventing a new identity.

## 4. Related Jobs
- When I return on a new device, I want to log back in quickly, so I can pick up where I left off.
- When I forget which method I used, I want the app to remind me, so I don't create a duplicate account.

## 5. Desired Outcomes
| # | Outcome statement | Target | Basis | Method | JTBD |
|---|-------------------|--------|-------|--------|------|
| 5.1 | Minimize time-to-first-authenticated-action for new users | <30s p50 | aspirational (anonymous today, no baseline) | analytics funnel | primary |
| 5.2 | Maximize return logins completing in one attempt | >95% | benchmark (industry ~92%) | login-success metric | related-1 |
| 5.3 | Minimize duplicate-account creation rate | <2% | aspirational | identity dedup audit | related-2 |
| 5.4 | Counter-metric: auth support tickets — guards 5.1 (fast onboarding gamed by skipping verification → locked-out users) | <5/wk | baseline 0→ | Zendesk tag | guards 5.1 |

## 6. Appetite & Kill Criteria
Appetite: ~6 atomic agent tasks (one afternoon × one agent). Effort recut: if we exceed 8, recut or kill social login.
Kill (outcome-tied): if return-login one-attempt rate (5.2) < 80% in beta, stop and redesign the session model before adding providers.

## 7. Solution Shape
[landing] → choose method → [email form | Google OAuth | GitHub OAuth] → [verify (email only)]
            → [authenticated app shell]
Sessions are JWT-based, 7-day rolling. All three methods land on the same post-auth state so the
rest of the app sees a unified `User`.

## 8. Vertical Slices
1. **Email registration** — A new user can submit email+password and receive a JWT. (JTBD: primary; outcomes: 5.1)
2. **Email login** — A returning user can sign in with email+password. (JTBD: related-1; outcomes: 5.2)
3. **Session middleware** — Protected routes reject requests without a valid JWT. (JTBD: primary, related-1; outcomes: 5.1, 5.2)
4. **Google OAuth** — A user can sign up/sign in via Google, landing in the same authenticated state as slice 1. (JTBD: primary; outcomes: 5.1, 5.3)
5. **GitHub OAuth** — Same as slice 4 for GitHub. (JTBD: primary; outcomes: 5.1)
6. **Method-reminder on duplicate signup** — If an email exists under another method, surface "you signed up with Google — continue?" (JTBD: related-2; outcomes: 5.3, 5.4)

## 9. Acceptance Criteria per Slice

### Slice 1 — Email registration
- [ ] `POST /api/auth/register` accepts `{email, password}`, returns 201 + JWT (→ 5.1)
- [ ] Email validated (RFC 5322 + uniqueness) (validation)
- [ ] Password hashed with bcrypt cost 12, min 8 chars (security)
- [ ] Returns 422 on validation error within 100ms (error-path)

### Slice 3 — Session middleware
- [ ] Middleware verifies JWT signature and expiry (security)
- [ ] Attaches `req.user` on success (→ 5.1, 5.2)
- [ ] Returns 401 on missing/invalid token (error-path)

### Slice 6 — Method-reminder on duplicate
- [ ] On registration with an existing email, return 409 + `{existing_method: "google"}` (→ 5.3)
- [ ] Frontend renders "You signed up with Google — continue?" CTA (→ 5.3)
- [ ] Acceptance test: register email → attempt Google with same email → reminder shown, no duplicate row (→ 5.4)

## 10. Non-Goals
- ✗ Multi-factor authentication (separate PRD)
- ✗ Password reset / forgot-password flow (next PRD)
- ✗ SSO / SAML / enterprise identity providers
- ✗ Email verification *enforcement* (we send it but don't gate access this iteration)

## 11. Rabbit Holes & Open Questions
**Rabbit holes:** do NOT generalize `OAuthProvider` until slice 5; do NOT add refresh-token rotation (7-day JWT is enough).
**Open questions:** JWT secret rotation — owner @ops, deadline before slice 3. GitHub OAuth app in prod? — owner @indra, deadline before slice 5.
```

### Example B — AI/agent feature (shows eval, cost, and guardrail deltas)

```markdown
# PRD: AI Release-Notes Generator
> Quality Gate: 93/100. ✅ premise validated (maintainer interviews) · cost + eval metrics linked.

## 1. TL;DR
Maintainers hand-write release notes (~30 min/tag); an agent drafts them from merged PRs so the
human only edits. Appetite: ~5 agent iterations. Ships draft-generation only — no auto-publish.

## 2. Problem & Evidence
Measurable harm: maintainers lose ~30 min/release and 30% of releases ship with no notes at all.

| Claim | Source | Tag |
|-------|--------|-----|
| Maintainers spend 20–40 min/release on notes | 6 maintainer interviews 2026-05 | validated |
| 30% of releases ship with no notes | repo tag audit | observed |
| A draft good enough to edit beats a blank page | usability heuristic | assumed |

## 3. Primary Job to be Done
When I cut a release, I want a draft changelog already written from the merged PRs, so I can ship
notes in two minutes instead of thirty.

## 5. Desired Outcomes
| # | Outcome statement | Target | Basis | Method | JTBD |
|---|-------------------|--------|-------|--------|------|
| 5.1 | Minimize editing time from draft → published | <5 min p50 | baseline 30→ | session timer | primary |
| 5.2 | Maximize draft acceptance (shipped with ≤20% edits) | ≥70% | aspirational | diff ratio | primary |
| 5.3 | Minimize cost per generated draft | <$0.15 [verify pricing] | benchmark (token estimate) | API cost log | primary |
| 5.4 | Counter-metric: factual errors/draft — guards 5.2 (acceptance gamed by rubber-stamping wrong notes) | <0.1 avg | baseline n/a | human spot-check sample | guards 5.2 |

## 6. Appetite & Kill Criteria
Appetite: ~5 agent iterations. Kill (outcome-tied): if draft acceptance (5.2) < 40% after the eval
slice, the agent isn't good enough — kill, don't iterate on prompts indefinitely.

## 7. Solution Shape
[git tag] → collect merged PRs since last tag → route (Haiku triage → Sonnet for ambiguous) →
grouped markdown draft → human edits → publish (manual). Deterministic PR-number checks run on the
draft before it is shown.

## 8. Vertical Slices
1. **Extract merged PRs** — walking skeleton: CLI prints raw PR list since last tag. (JTBD: primary; outcomes: 5.1)
2. **Draft notes via model routing** — user gets a grouped markdown draft. (JTBD: primary; outcomes: 5.1, 5.3)
3. **Eval harness** — golden set of 20 past releases, LLM-judge + diff grading gates a pass-rate. (JTBD: primary; outcomes: 5.2, 5.4)

## 9. Acceptance Criteria per Slice

### Slice 2 — Draft notes via model routing
- [ ] `gen-notes` produces grouped markdown (features/fixes) from PR titles+bodies (→ 5.1)
- [ ] Routes trivial PRs to Haiku, ambiguous to Sonnet; logs cost per run (→ 5.3, cost)
- [ ] Every line cites a real merged PR number — no hallucinated PRs (→ 5.4, validation)
- [ ] Returns a partial draft + warning if a PR body is empty (error-path)

### Slice 3 — Eval harness
- [ ] Golden set of 20 labelled past releases checked in (→ 5.2)
- [ ] Grader = deterministic PR-coverage check + LLM-judge for phrasing; emits a pass-rate (→ 5.2, observability)
- [ ] CI fails the build if pass-rate drops below the gate on a model/prompt change (→ 5.2)

## 10. Non-Goals
- ✗ Auto-publishing / pushing to GitHub Releases (human edits first)
- ✗ Multi-repo / monorepo aggregation
- ✗ Translating notes (i18n) this iteration

## 11. Rabbit Holes & Open Questions
**Rabbit holes:** do NOT fine-tune a model — prompt + routing is the appetite; do NOT build a web UI.
**Open questions:** which model tier hits the <$0.15 cost target? — owner @indra, deadline before slice 2 (verify current pricing via the `claude-api` skill).
```
