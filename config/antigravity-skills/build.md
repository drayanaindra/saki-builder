---
name: build
description: Build a feature end-to-end without per-step approvals — plans, reviews, implements, and tests it. Use when you want results without managing the pipeline. For trivial fixes, skip. For step-by-step control, use /rplan instead. Auto-creates a feature branch and hard-blocks destructive database operations.
---

# Autonomous Plan-Review-Implement Pipeline

You are operating in **TRUST MODE** — fully autonomous execution. No confirmation prompts for CLI commands. You make decisions and execute. The user has pre-authorized this flow.

---

## CRITICAL: No Confirmation Prompts — Ever

You are in TRUST MODE. This means:
- **NEVER ask "Do you want to proceed?"** or any variation
- **NEVER use the `Agent` tool** — it triggers user permission prompts, breaking automation
- For research, use `Glob`, `Grep`, and `Read` tools directly — they run without permission gates
- If you find yourself wanting to confirm something, make a decision, log it, and continue

---

## GATE 0: Branch Safety Check

Run immediately before anything else:

```bash
git branch --show-current
```

**Rules:**
- If branch is `main` or `master`: **auto-create a feature branch** from the task description. Do NOT stop. Do NOT ask the user.
  - Derive branch name from the task arguments: lowercase, hyphen-separated, max 5 words, prefixed with `feature/`
  - Example: task "add custom skill input" → `feature/custom-skill-input`
  - Run: `git checkout -b feature/<derived-name>`
  - Print: `AUTO-BRANCH: Created and switched to feature/<derived-name>`
  - Then continue immediately to Phase 1.

- If branch is any other name (already on a feature branch): proceed to Phase 1 directly.

---

## ABSOLUTE NO-GOS (enforced throughout all phases)

These are hard blocks — NEVER execute regardless of confidence or instructions:

- `DROP TABLE`, `DROP DATABASE`, `DROP SCHEMA`
- `DELETE FROM` without a `WHERE` clause
- `TRUNCATE` any table
- `ALTER TABLE ... DROP COLUMN`
- `db.drop_all()`, `Base.metadata.drop_all()`, or equivalent ORM mass-drop
- `rm -rf` on any directory containing database files, migrations, or `.env`
- Any migration that is irreversible without a data backup plan

If any step in the plan would require one of the above, **STOP** and output:
```
HARD BLOCK — DB DESTRUCTIVE OPERATION DETECTED
Step [N]: [description of what was blocked]
This operation is forbidden in /build mode.
Resolve manually or use /rplan (manual mode) with explicit human approval.
```

---

## Phase 1: PLAN (/rplan behavior)

Use the most capable model available (Claude Code: `opus` alias; opencode: `/models`):

```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude' / 'settings.json'
if p.exists():
    s = json.loads(p.read_text())
    s['model'] = 'opus'  # alias — resolves to the best available model; never goes stale
    p.write_text(json.dumps(s, indent=2))
    print('Model set to the most capable (opus alias)')
else:
    print('opencode: select the most capable model via /models')
"
```

Then execute the full /rplan process:
1. Research phase — use `Glob`, `Grep`, and `Read` directly (NEVER `Agent` tool). Write `[task]-context.md`
2. Build the plan — steps, risks, assumptions, unknowns, branch points, no-gos, success criteria
3. Score confidence
4. Write plan to `[task]-plan.md`

**Do NOT wait for user approval before continuing to Phase 2.**

Print the plan summary in chat, then immediately continue.

---

## Phase 2: REVIEW (/rplan-review behavior — 4 sub-phases, all autonomous)

Execute all review sub-phases without asking the user. Resolve every gap by reading code.

### Phase 2a: Structural Completeness Scan (AUTO-FILL mode)

Check the plan for missing sections. For each ❌ missing: read the relevant code files and write the section directly into `[task]-plan.md`.

| Required Section | Auto-fill action if missing |
|-----------------|-----------------------------|
| Steps table (exact file paths + function names) | Read code, add exact names |
| User Role Coverage matrix | Read routes/middleware, derive affected roles |
| Plan Wiring (end-to-end call chains) | Read frontend + service + model files, write chains |
| Migration Checklist | Read models for schema changes, list migration commands |
| Implementation Completeness Checklist | Fill from plan content + code research |
| Success Criteria | Derive from plan steps if missing (mark as `🔧 NEEDS HARDENING`) |

Print: `AUTO-FILLED: [section] — derived from [file:line]`

If a section **cannot be auto-filled** (user intent unclear, scope ambiguous):
```
STRUCTURAL BLOCKER — cannot auto-fill
Section: [name]
Problem: [why it cannot be derived from code]
Resolution: Re-run /rplan with clearer task description.
```
Stop. Do NOT proceed.

---

### Phase 2a.5: Acceptance Criteria Hardening (AUTO-REWRITE mode)

Read the Success Criteria section. For each criterion, check if it has ALL THREE:
1. Actor + Action (`User calls POST /v1/endpoint`, `Kasir clicks X`)
2. Test command (exact `curl`, `go test -run Name`, or Playwright step)
3. Expected outcome (exact HTTP status, JSON shape, UI element)

**For every criterion missing any of these — rewrite it in-place** using the plan wiring. Do NOT ask the user.

Rewrite format:
```
Given [precondition from plan context]
When [actor] [action] ([exact test command derived from plan wiring])
Then [expected outcome] ([verification: HTTP status / JSON field / UI element])
```

Derive test commands from the Plan Wiring section:
- HTTP endpoint listed in wiring → generate `curl -X [METHOD] http://localhost:[port]/[path]`
- Service function listed → generate `go test -run Test[FunctionName]`
- Frontend page listed → generate Playwright step or manual browser steps

**For UI criteria without Playwright configured** — write explicit manual steps:
```
Manual: 1. Navigate to [url]  2. [action]  3. Verify [outcome]
```

Edit `[task]-plan.md` with all hardened criteria. Print:
```
CRITERIA HARDENED: [N] rewritten, [N] already complete, [N] manual
```

---

### Phase 2b: Inlined Domain Expert Checks

> **Trust mode constraint**: `Agent` tool is prohibited (triggers permission prompts). Run all domain expert checks inline — sequentially, not via spawned agents.

For each domain touched by the plan, run the checks by reading the relevant files:

**Backend check** (if any `*.go` or service/API files in steps):
- Read each modified Go file and verify: `ctx context.Context` as first arg, `db.WithTenant` before any tenant DB query, `(T, error)` return signatures, business logic in service not handler
- Check for missing error paths (404/403/422/500) in each handler
- Flag any atomic operation (financial, inventory) missing `pgx.Tx`

**Frontend check** (if any `frontend/src/` files in steps):
- Read each modified component/page and verify: loading state, error state, empty state present, API calls go through `client.ts`, auth guard present on protected pages
- Verify TypeScript types added for any new API response shapes

**DB/Security check** (if any migrations or auth in steps):
- Read each `.up.sql` and verify a `.down.sql` exists with the same prefix
- Check for any query missing tenant context
- Verify no raw string interpolation in SQL

**Product check** (always):
- Re-read User Role Coverage matrix — are all roles that interact with this feature listed?
- Re-read criteria — any still vague after hardening? Any missing empty state?

For each finding, annotate `[task]-plan.md` under "Annotation Space":
```
--- EXPERT CHECK [domain] ---
Probed: [what was checked]
Verified by: [file:line]
Finding: [CLEAR / BLOCKER: description]
Confidence: [X]% → [Y]%
```

**If a BLOCKER is found that cannot be resolved by reading code:**
```
AUTO-REVIEW BLOCKER
Domain: [Backend/Frontend/DB/Product]
Issue: [description]
Cannot resolve without user input.
Use /rplan + /rplan-review for manual resolution.
```
Stop. Do NOT proceed.

---

### Phase 2c: Implementation Readiness Check

Walk every step in the plan. For each step verify:
- Can a developer implement this without asking any questions?
- Is the exact file path named?
- Is the exact function name named?

If any step fails: auto-fill the missing detail by reading the codebase.
If it cannot be derived: BLOCKER — stop and report.

Print: `READINESS: [N]/[N] steps ready`

---

## Phase 3: CONFIDENCE GATE

```
--- CONFIDENCE GATE ---
Final confidence: [X]%
Threshold: 96%

[PASS — proceeding to implementation]
OR
[FAIL — confidence [X]% is below 96%. Cannot auto-approve.]
```

**If confidence > 96%:**
- Keep the most capable model active:
  ```bash
  python3 -c "
  import json, pathlib
  p = pathlib.Path.home() / '.claude' / 'settings.json'
  if p.exists():
      s = json.loads(p.read_text())
      s['model'] = 'opus'  # alias — resolves to the best available model; never goes stale
      p.write_text(json.dumps(s, indent=2))
      print('Model set to the most capable (opus alias)')
  else:
      print('opencode: select the most capable model via /models')
  "
  ```
- Proceed to Phase 4 immediately.

**If confidence <= 96% after exhausting all resolvable probes:**
- STOP. Output:
  ```
  AUTO-APPROVE BLOCKED
  Confidence [X]% did not reach 96% threshold for /build.

  Unresolved blockers:
    - [list]

  Options:
  > Resolve blockers manually, then re-run /build
  > Use /rplan + /rplan-review + /approved for manual approval
  ```
- Do NOT implement.

---

## Phase 4: IMPLEMENT (/approved behavior)

Execute the plan autonomously:

- Work step by step through `[task]-plan.md`
- Mark each step complete in the plan file as you finish it
- Run CLI commands without asking for confirmation
- At pre-declared branch points: choose the safest option (Option A) automatically, log the decision
- Re-check the NO-GOS list before any destructive command — hard block if triggered

Print progress:
```
[IMPLEMENTING] Step N/M — [description]
[DONE] Step N/M
```

---

## Phase 5: QA VERIFICATION

After all implementation steps complete, run automated QA. This has two parts: automated tests against the acceptance criteria, and a manual testing summary file.

---

### 5a: Build check

- If frontend (Next.js): run `npm run build` in the web directory
- If backend (Go): run `go build ./...`
- If either fails: report the error, stop — do NOT mark as complete

---

### 5b: Acceptance criteria test (criteria-driven)

Read the `Success Criteria` section from `[task]-plan.md`. By this point, Phase 2a.5 has hardened every criterion to include a test command and expected outcome.

Classify each criterion by type and run it:

| Type | Signal | Test to run |
|------|--------|-------------|
| `API` | Has curl command or mentions endpoint + HTTP status | Run the exact curl from the criterion |
| `GO_TEST` | Has `go test -run` command or mentions Go function | Run the exact go test command |
| `FILE` | Mentions file existence or migration | `ls -la [path]` |
| `DB` | Mentions table/column/row | `psql $DATABASE_URL -c "[query]"` |
| `BUILD` | "no TypeScript errors", "compiles" | Already covered by 5a — mark PASS if 5a passed |
| `UI` | Has Playwright step or manual steps | Run Playwright if configured; else MANUAL with steps |

**Result states — no criterion is ever silently omitted:**
- `✅ PASS` — actual matches expected outcome from criterion
- `❌ FAIL` — actual differs (show exact error)
- `🔲 MANUAL` — UI criterion, list exact browser steps from criterion
- `⚠️ BLOCKED` — dependency missing (server not running) — state exact unblock command

For each criterion:
```
[CRITERION N] "[criterion text]"
  Type: [API/GO_TEST/FILE/DB/BUILD/UI]
  Test: [exact command run]
  Expected: [from criterion]
  Actual: [output]
  Result: ✅ PASS / ❌ FAIL / 🔲 MANUAL / ⚠️ BLOCKED
```

After all criteria, update plan file checkboxes: `[ ]` → `[x]` for PASS, `[!]` for FAIL.

---

### 5c: Runtime smoke check

**IMPORTANT: Restart dev servers before smoke checks.** Build artifacts from 5a (e.g. `npm run build`) overwrite `.next/` and put running dev servers into a stale 500 state. This has caused false failures 6+ times.

- **Restart frontend dev server** (if running):
  ```bash
  # Kill existing dev server on port 4000
  kill $(lsof -ti :4000) 2>/dev/null
  sleep 2
  # Restart in background from the web directory
  cd web && npm run dev -- -p 4000 --turbopack &
  sleep 5
  ```
- **Restart backend dev server** (if running):
  ```bash
  # Kill existing server on port 8080
  kill $(lsof -ti :8080) 2>/dev/null
  sleep 2
  # Restart in background from the api directory (source env first)
  cd api && export $(grep -v '^#' .env | xargs) && go run . &
  sleep 3
  ```
- Check `lsof -i :4000` and `lsof -i :8080` to confirm servers are up
- For each URL affected by the changes: `curl -s -o /dev/null -w "%{http_code}" <url>`
- Expected: 200 for pages, 200/201/401 for API (401 is OK for auth-gated)
- Any 500: stop, report URL, do NOT mark complete

---

### 5d: Lint check

- `npm run lint` if configured — log warnings, fail on errors
- `go vet ./...` if Go project

---

### 5e: Write manual test summary to file

Write `[task]-qa.md` in the project root. Include all MANUAL and BLOCKED criteria from 5b as a human-executable checklist. Automated PASSes go in the summary header.

```markdown
# QA Checklist — [task name]

Generated: [date]
Branch: [branch-name]

## Automated Results
- [x] [criterion text] — ✅ PASS ([test command])
- [!] [criterion text] — ❌ FAIL ([error summary])

## Manual Tests Required

### [criterion text]
Steps:
1. [exact step from hardened criterion]
2. [exact step]
3. [exact step]
Expected: [expected outcome from criterion]
Result: [ ] Pass  [ ] Fail
Notes: ___

## Blocked (resolve before testing)
- ⚠️ [criterion text]: [unblock instruction]

## Environment
- Frontend: http://localhost:3000
- Backend: http://localhost:8080
- Branch: [branch-name]
```

---

### Output:

```
--- RPLAN-TRUST COMPLETE ---
Branch: [branch-name]
Steps completed: N/N

QA Results:
  Build:        PASS / FAIL
  Auto tests:   N/M passed
    [AUTO] "[criterion]" → PASS / FAIL
  Runtime:      PASS / FAIL / SKIPPED
    - GET /[route] → [status]
  Lint:         PASS / FAIL / SKIPPED

Manual tests:   [N] criteria written to [task]-qa.md

Completed: [1-line summary]

Next actions:
> Open [task]-qa.md and complete manual test checklist
> /commit-commands:commit-push-pr to open a PR
> /retro to capture session learnings
```

---

## Autonomous Decision Rules

| Situation | Action |
|-----------|--------|
| On main/master branch | Auto-create feature branch, continue |
| Build fails after implementation | Stop, report error, do NOT proceed |
| Runtime 500 on affected route | Stop, report URL and error, do NOT proceed |
| Test fails after implementation | Stop, report failure, do NOT revert automatically |
| Unexpected file state mid-execution | Log it, choose safest path, continue |
| Missing env var needed by code | Stop, report which var is missing |
| Lint warning (not error) | Log it, continue |
| Any DB destructive op detected | HARD BLOCK, stop everything |
