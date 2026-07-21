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
---

## Context

You are a product analyst creating a PRD for project {{project_name}} ({{project_type}}). Stack: {{stack}}.

The PRD is a *bridge* from product intent to the XP planning game (`/rplan` → `/approved` → `/qa`). It owns *what* vertical slices exist and *why*; `/rplan` owns *how* to execute each slice file-by-file. Do not decompose slices into file-level atomic tasks in the PRD — that is BDUF and short-circuits `/rplan`'s confidence gate.

Format borrows from Klement (Job Story), Ulwick (outcome statements), Shape Up (appetite, no-gos, rabbit holes), and Beck/Wake (INVEST + TDD-ready slices).

## Instructions

1. Analyze the feature intent: "{{input.feature}}".

2. Produce a PRD with the following sections. **MUST** sections are required in every PRD; **MAY** sections appear only when their trigger applies.

   1. **TL;DR** (MUST) — ≤3 sentences: user problem, chosen solution shape, appetite.
   2. **Problem & Evidence** (MUST) — 1–2 sentence problem statement plus an evidence table. Tag each claim `assumed | observed | validated`.
   3. **Primary Job to be Done** (MUST) — exactly one Job Story in Klement format: `When [situation], I want to [motivation], so I can [expected outcome].` Forbidden: "As a [role], I want…" persona stories. If you have two primary jobs, this is two PRDs.
   4. **Related Jobs** (MAY, 0–3) — same format. Hard cap at 3; anything more is story-mapping and belongs elsewhere.
   5. **Desired Outcomes / Success Metrics** (MUST) — 1 primary + 2–3 secondary + 1 counter-metric, each in Ulwick outcome-statement form: `Minimize/Maximize [metric] of [object] when [context].` Each outcome lists `target number`, `measurement method`, and the JTBD it serves.
   6. **Appetite** (MUST) — denominate in **agent-iterations**, not hours: e.g. `~6 atomic agent tasks` or `1 afternoon × 1 agent`. State a recut/kill threshold.
   7. **Solution Shape** (MUST) — prose paragraph plus optional ASCII flow. *Shape*, not design. No wireframes, no DB schemas, no API signatures.
   8. **Vertical Slices** (MUST) — numbered list. Each slice: `verb-phrase title`, `Serves JTBD: …`, `Serves outcome: #…`, 1–2 sentence description of what the user can newly do after this slice ships. Apply the slice-quality test in step 3.
   9. **Acceptance Criteria per Slice** (MUST) — bullet checklist or Given/When/Then. Each criterion is executable (a test runner or human can mark it pass/fail unambiguously). Each criterion either links a §5 outcome (`→ 5.2`) OR names a guardrail (`security | validation | error-path | accessibility`). Cap: ≤5 criteria per slice — more is a split signal.
   10. **Non-Goals** (MUST, ≥2) — bullet list prefixed `✗`. The single most-skipped section and the largest source of mid-cycle scope explosion.
   11. **Rabbit Holes & Open Questions** (MUST) — two subsections. *Rabbit holes:* known traps to avoid (e.g. "do NOT generalize the session store yet"). *Open questions:* with `owner` and `decision deadline`. Sections may be empty but the header stays — its absence is a signal.
   12. **Technical Constraints** (MAY, when binding) — stack-imposed limits (e.g. "must use existing auth middleware").
   13. **Dependencies** (MAY, when external) — other PRDs, infra, third-party APIs.
   14. **Rollout & Kill Criteria** (MAY, user-facing only) — alpha → beta → GA, kill criteria.

3. Slice quality test (INVEST + atomic-for-AI). Every slice must pass all five:
   1. **Single user-visible capability.** "User can register with email" — not "auth system exists."
   2. **One ownership boundary.** Touches files in ≤2 modules. Frontend + backend + DB in one slice → split.
   3. **Test-first feasible.** A failing test can be written *before* implementation (TDD RED step).
   4. **Forward dependency only.** Slice N may depend on 1..N-1 but not N+1. Topological order = execution order.
   5. **Fits one agent iteration (~30 min).** Heuristic: >5 acceptance criteria = two slices.

4. Acceptance-criteria mapping rule. Every criterion in §9 must answer one of:
   - *Which §5 outcome does this criterion measure?* (link by ID, e.g. `→ 5.2`)
   - *Which guardrail does this criterion enforce?* (security | validation | error-path | accessibility)

   If neither, delete the criterion (YAGNI).

5. Save the PRD to `tasks/prd-{{input.feature | slugify}}.md`.

6. Ask the user whether the PRD is acceptable or needs revision.

7. After approval, hand off to `/rplan`. Each slice becomes one `/rplan` invocation, which produces the file-by-file plan and runs the confidence gate. Do **not** produce file-by-file tasks inside the PRD.

## Script

```bash
#!/bin/bash
mkdir -p tasks
```

## Validation

- [ ] PRD saved as `tasks/prd-*.md`
- [ ] All 10 MUST sections present and in order
- [ ] TL;DR ≤3 sentences
- [ ] Each evidence claim tagged `assumed | observed | validated`
- [ ] Primary JTBD uses `When … I want to … so I can …` — no "As a X, I want Y" stories
- [ ] Exactly one Primary JTBD; Related Jobs ≤3
- [ ] Outcomes use Ulwick `Minimize/Maximize … when …` form with target + method + JTBD link
- [ ] At least one counter-metric in §5
- [ ] Appetite stated in agent-iterations with a recut/kill threshold
- [ ] Solution Shape contains no wireframes, schemas, or API signatures
- [ ] Each slice passes all 5 slice-quality checks
- [ ] Each slice has ≤5 acceptance criteria
- [ ] Every acceptance criterion either links a §5 outcome OR names a guardrail
- [ ] Every §5 outcome has ≥1 criterion linking to it across the slice list
- [ ] ≥2 Non-Goals listed
- [ ] Rabbit Holes & Open Questions section present (may be empty)
- [ ] No file-level / atomic-task breakdown in the PRD (that belongs to `/rplan`)

## Examples

### Input
```
feature: "User authentication with email and social login"
```

### Output PRD

```markdown
# PRD: User Authentication

## 1. TL;DR
Let new users create an account with email/password OR Google/GitHub OAuth, and let returning
users sign back in across devices. Appetite: ~6 agent iterations. Ships the auth surface only —
no account-management UI.

## 2. Problem & Evidence
We have no way to identify users; everything is anonymous. Without identity we can't persist
state, segment usage, or charge.

| Claim | Source | Confidence |
|-------|--------|------------|
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
| # | Outcome statement | Target | Method | JTBD |
|---|-------------------|--------|--------|------|
| 5.1 | Minimize time-to-first-authenticated-action for new users | <30s p50 | analytics funnel | primary |
| 5.2 | Maximize percentage of return logins completing in one attempt | >95% | login-success metric | related-1 |
| 5.3 | Minimize duplicate-account creation rate | <2% | identity dedup audit | related-2 |
| 5.4 | Counter-metric: auth-related support tickets | <5/wk | Zendesk tag | — |

## 6. Appetite
~6 atomic agent tasks (one afternoon × one agent). If we exceed 8, recut or kill social login.

## 7. Solution Shape
[landing] → choose method → [email form | Google OAuth | GitHub OAuth] → [verify (email only)]
            → [authenticated app shell]

Sessions are JWT-based, 7-day rolling. All three methods land on the same post-auth state so the
rest of the app sees a unified `User`.

## 8. Vertical Slices
1. **Email registration** — A new user can submit email+password and receive a JWT. (JTBD: primary; outcomes: 5.1)
2. **Email login** — A returning user can sign in with email+password. (JTBD: related-1; outcomes: 5.2)
3. **Session middleware** — Protected routes reject requests without a valid JWT. (JTBD: primary, related-1; outcomes: 5.1, 5.2)
4. **Google OAuth** — A user can sign up/sign in via Google and lands in the same authenticated state as slice 1. (JTBD: primary; outcomes: 5.1, 5.3)
5. **GitHub OAuth** — Same as slice 4 for GitHub. (JTBD: primary; outcomes: 5.1)
6. **Method-reminder on duplicate signup** — If an email already exists under another method, surface "you signed up with Google — continue?" (JTBD: related-2; outcomes: 5.3, 5.4)

## 9. Acceptance Criteria per Slice

### Slice 1 — Email registration
- [ ] `POST /api/auth/register` accepts `{email, password}`, returns 201 + JWT (→ 5.1)
- [ ] Email validated (RFC 5322 + uniqueness) (validation)
- [ ] Password hashed with bcrypt cost 12, min 8 chars (security)
- [ ] Returns 422 on validation error within 100ms (error-path)
- [ ] Tests cover: happy path, duplicate email, weak password (validation)

### Slice 2 — Email login
- [ ] `POST /api/auth/login` accepts `{email, password}`, returns 200 + JWT (→ 5.2)
- [ ] Returns 401 on bad credentials with constant-time comparison (security)
- [ ] p95 latency <300ms (→ 5.2)

### Slice 3 — Session middleware
- [ ] Middleware verifies JWT signature and expiry (security)
- [ ] Attaches `req.user` on success (→ 5.1, 5.2)
- [ ] Returns 401 on missing/invalid token (error-path)
- [ ] Documented as `requireAuth()` and applied to one demo protected route (validation)

### Slice 4 — Google OAuth
- [ ] `GET /api/auth/google` initiates OAuth flow (→ 5.1)
- [ ] Callback creates user (or links to existing) and returns JWT identical in shape to slice 1 (→ 5.1)
- [ ] On email collision with method=email, returns 409 (handled by slice 6) (error-path)

### Slice 5 — GitHub OAuth
- [ ] Mirror of slice 4 for GitHub provider (→ 5.1)
- [ ] Reuses the `OAuthProvider` interface introduced in slice 4 (validation)

### Slice 6 — Method-reminder on duplicate
- [ ] On registration attempt with existing email, return 409 + `{existing_method: "google"}` (→ 5.3)
- [ ] Frontend renders "You signed up with Google — continue with Google?" CTA (→ 5.3)
- [ ] Acceptance test: register email → attempt Google with same email → reminder shown, no duplicate row (→ 5.3, 5.4)

## 10. Non-Goals
- ✗ Multi-factor authentication (deferred — separate PRD)
- ✗ Password reset / forgot-password flow (next PRD)
- ✗ Account deletion or profile edit UI
- ✗ SSO / SAML / enterprise identity providers
- ✗ Email verification *enforcement* (we send the email but don't gate access on it this iteration)

## 11. Rabbit Holes & Open Questions
**Rabbit holes:**
- Do NOT generalize `OAuthProvider` until slice 5 — premature abstraction.
- Do NOT add a refresh-token rotation scheme; 7-day JWT is sufficient for the appetite.
- Do NOT touch the existing anonymous-session migration path (separate PRD).

**Open questions:**
- [ ] JWT secret rotation strategy — owner: @ops, deadline: before slice 3 ships.
- [ ] GitHub OAuth app provisioned in prod? — owner: @indra, deadline: before slice 5.

## 12. Technical Constraints
- Must use existing `bcrypt` dependency — do not add argon2.
- Frontend uses existing `useAuth()` hook contract; do not break consumers.

## 13. Dependencies
- Google Cloud OAuth client (exists in dev, needs prod)
- GitHub OAuth app (see open question)
```
