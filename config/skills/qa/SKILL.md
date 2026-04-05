---
name: qa
description: Run QA against the plan's acceptance criteria. Reads Success Criteria from the plan, runs each one, fills in the checklist, reports pass/fail per criterion. Auto-generates and runs Playwright tests for UI criteria when playwright.config.ts is detected.
---

# QA — Acceptance Criteria Runner

You run tests. You do not suggest setup. You do not end with "next steps". You execute every testable criterion in the plan and report the result.

---

## Step 0: Find the active plan

Find the most recently modified `*-plan.md` in the project root:
```bash
ls -t $(pwd)/*-plan.md 2>/dev/null | head -1
```

If no plan file found → stop: "No plan file found. Run /rplan first."

Read the plan. Log which file was selected:
```
--- QA START ---
Plan: [filename]
Criteria found: [N]
```

Extract the **Success Criteria** section.

---

## Step 1: Pre-flight checks

### 1a: Detect frontend root (project-agnostic)
```bash
FRONTEND_ROOT=""
for d in "$(pwd)" "$(pwd)/frontend" "$(pwd)/src"; do
  if [ -f "$d/playwright.config.ts" ]; then
    FRONTEND_ROOT="$d"
    break
  fi
done
echo "FRONTEND_ROOT=${FRONTEND_ROOT}"
```

If `FRONTEND_ROOT` is empty → mark all UI criteria as MANUAL; skip Steps 1b, 1c, and Step 1.5 entirely.

### 1b: Ping baseURL (only if FRONTEND_ROOT found)
```bash
curl -s --max-time 3 http://localhost:4000 > /dev/null 2>&1 && echo "SERVER_UP" || echo "SERVER_DOWN"
```

If SERVER_DOWN → emit:
```
⚠️ BLOCKED: Dev server not running.
Start with: cd [FRONTEND_ROOT] && npm run dev
Playwright tests will not run. UI criteria marked BLOCKED.
```
Skip Steps 1c and 1.5; mark all UI criteria as BLOCKED (not FAIL).

### 1c: Check Playwright browsers installed
```bash
ls ~/Library/Caches/ms-playwright/chromium-* 2>/dev/null || ls ~/.cache/ms-playwright/chromium-* 2>/dev/null
```

If no match → emit:
```
⚠️ BLOCKED: Playwright browsers not installed.
Run: cd [FRONTEND_ROOT] && npx playwright install chromium
UI criteria marked BLOCKED.
```
Skip Step 1.5.

---

## Step 1.5: Generate Playwright specs for UI criteria

**Run only if pre-flight passed (FRONTEND_ROOT set, server up, browsers installed).**

For each UI criterion in the Success Criteria:

1. Extract `Playwright:` stub if present — use it verbatim
2. If no stub: derive test from `Manual:` steps (navigate → interact → assert pattern)
3. If neither exists: flag criterion as `NO_SPEC` (warn, not FAIL)

Write each spec to:
```
$FRONTEND_ROOT/e2e/qa-generated/{plan-slug}/{criterion-id}.spec.ts
```

Where:
- `plan-slug` = plan filename without `-plan.md`, lowercase, hyphens (e.g. `phase28`)
- `criterion-id` = criterion label from plan (e.g. `SC-1`, `B-SC7`)

**Spec template** (use this for every generated test):
```typescript
import { test, expect } from '../../fixtures/auth';

const TOKEN = process.env.TEST_JWT ?? '';

test.describe('[criterion-id]: [criterion description]', () => {
  test('[test name]', async ({ page, loginWithToken }) => {
    test.skip(!TOKEN, 'TEST_JWT not set — run: cp .env.test.example .env.test');
    await loginWithToken(TOKEN);
    await page.goto('[target url]');
    await page.waitForLoadState('networkidle');
    // [assertions derived from Playwright: stub or Manual: steps]
  });
});
```

**Important**: import path `../../fixtures/auth` is relative to `e2e/qa-generated/{slug}/` — adjust depth if structure differs.

If zero UI criteria found → warn "No UI criteria found — 0 specs generated, skipping Playwright" and skip Playwright run.

---

## Step 2: Classify each criterion

For each item in the Success Criteria section, classify it:

| Type | Signal | How to test |
|------|--------|-------------|
| `API` | mentions endpoint, HTTP, curl, status code | `curl -s -o /dev/null -w "%{http_code}"` |
| `GO_TEST` | mentions Go function, service, repository, unit test | `go test ./internal/[pkg]/... -run [TestName] -v` |
| `FILE` | mentions file exists, migration file, config | `ls -la [path]` |
| `DB` | mentions table, column, row, migration applied | `psql $DATABASE_URL -c "[query]"` |
| `BUILD` | always run — type check + compile | `go build ./...`, `npx tsc --noEmit` |
| `UI` | mentions page, button, form, browser, click | Playwright spec (Step 1.5) — or MANUAL/BLOCKED if not configured |

If a criterion has no test command written in the plan → run the best-fit command for its type. Do NOT skip it.

---

## Step 3: Run static checks

Always run these regardless of what criteria say.

**Detect project root** (where `go.mod` or `package.json` lives):
```bash
PROJECT_ROOT="$(pwd)"
[ -f "$(pwd)/go.mod" ] && PROJECT_ROOT="$(pwd)"
[ -f "$(pwd)/../go.mod" ] && PROJECT_ROOT="$(pwd)/.."
```

**Go (if go.mod exists):**
```bash
cd $PROJECT_ROOT && go vet ./... 2>&1
cd $PROJECT_ROOT && go build ./... 2>&1
cd $PROJECT_ROOT && go test ./... -count=1 -timeout 60s 2>&1
```

**Frontend (if FRONTEND_ROOT set):**
```bash
cd $FRONTEND_ROOT && npx tsc --noEmit 2>&1
```

**Migrations (look for db/migrations/ in project root):**
```bash
ls -1 $PROJECT_ROOT/db/migrations/ 2>/dev/null | sort
```
For each `.up.sql` file, verify a `.down.sql` counterpart exists.

---

## Step 4: Run each criterion

For every criterion from Step 2, run its test command and capture the output.

**Criterion execution rules:**
- Run it. Do not say "this requires the server to be running" and skip it — try it.
- If a server is needed and not running → mark BLOCKED with exact start command, not SKIP.
- If the test command is a curl and the server responds → parse the status code and body.
- If it's a `go test` → run it and capture pass/fail.
- If the criterion has an **expected outcome** in the plan → compare actual vs expected.
- If no expected outcome is written → flag as `NO_EXPECTED_OUTCOME` (warn, not fail).

**For UI criteria:**
- If spec was generated in Step 1.5 → result comes from Step 5 Playwright output
- If Playwright not configured → mark MANUAL with exact browser steps
- If server was BLOCKED → mark BLOCKED

---

## Step 5: Run Playwright + collect results

**Run only if Step 1.5 generated at least 1 spec:**
```bash
cd $FRONTEND_ROOT && npx playwright test e2e/qa-generated/ --reporter=line 2>&1 | tee /tmp/playwright-qa-results.txt
```

Then collect:
```bash
cat /tmp/playwright-qa-results.txt 2>/dev/null || echo "NOT_RUN"
```

Parse: `N passed`, `N failed`, `N skipped`. Map each test name back to its criterion.

---

## Step 6: Report

Fill in the plan's Success Criteria checklist and print the full report:

```
--- QA REPORT: [task name] ---

### Acceptance Criteria

| # | Criterion | Type | Result | Expected | Actual |
|---|-----------|------|--------|----------|--------|
| 1 | [criterion text] | API | ✅ PASS | HTTP 200 | HTTP 200 |
| 2 | [criterion text] | GO_TEST | ❌ FAIL | pass | FAIL: [error] |
| 3 | [criterion text] | UI | ✅ PASS | not /masuk | http://localhost:4000/pos |
| 4 | [criterion text] | UI | 🔲 MANUAL | [expected] | [browser steps] |
| 5 | [criterion text] | API | ⚠️ NO_EXPECTED_OUTCOME | — | HTTP 200 |

### Static Checks
- go vet: ✅ PASS / ❌ FAIL
- go build: ✅ PASS / ❌ FAIL
- go test ./...: ✅ N passed / ❌ N failed
- tsc --noEmit: ✅ PASS / ❌ FAIL

### Migrations
- [filename].up.sql ↔ [filename].down.sql: ✅ paired / ❌ UNPAIRED

### Playwright (UI)
- Status: ✅ N passed / ❌ N failed / ⏭ NOT_CONFIGURED / ⚠️ BLOCKED
- Frontend root: [FRONTEND_ROOT or "not detected"]
- [list any failed test names]

---
QA STATUS: ✅ ALL PASS / ❌ [N] FAILURES / ⚠️ [N] MANUAL REQUIRED

Failures (must fix before merge):
  ❌ Criterion 2: [exact error]

Manual verification required:
  🔲 Criterion 4: [browser steps]

Criteria with no expected outcome (add to plan):
  ⚠️ Criterion 5: [write expected outcome so next QA run can auto-verify]
```

---

## Rules

- **Never stop because a tool is not installed.** Run what exists; classify what cannot run.
- **Never end with setup suggestions.** The report ends with pass/fail, not "install X".
- **MANUAL is not SKIP.** A manual criterion must have browser steps listed.
- **BLOCKED is not FAIL.** A blocked criterion (server down) must say exactly how to unblock.
- **UI criteria with a generated spec are NOT MANUAL** — they get a PASS/FAIL from Playwright.
- `NO_EXPECTED_OUTCOME` is a warning — it means the plan needs hardening, not that QA failed.
- `NO_SPEC` is a warning — criterion had no `Playwright:` stub and no `Manual:` steps to derive from.
- If a criterion says "verify X works" with no specifics → derive the test from the plan wiring.
- After reporting, update the plan file's Success Criteria checkboxes: `[ ]` → `[x]` for PASS, `[!]` for FAIL.
- **Never hardcode project paths.** All paths derived from `$(pwd)`, `FRONTEND_ROOT`, `PROJECT_ROOT`.
