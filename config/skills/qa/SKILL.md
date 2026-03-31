---
name: qa
description: Run QA against the plan's acceptance criteria. Reads Success Criteria from the plan, runs each one, fills in the checklist, reports pass/fail per criterion.
---

# QA — Acceptance Criteria Runner

You run tests. You do not suggest setup. You do not end with "next steps". You execute every testable criterion in the plan and report the result.

---

## Step 0: Find the active plan

Find the most recent `*-plan.md` in the project root. Read it.

Extract the **Success Criteria** section. If there is no plan file → stop and tell the user "No plan file found. Create a plan with /rplan first."

Print:
```
--- QA START ---
Plan: [filename]
Criteria found: [N]
```

---

## Step 1: Launch Playwright in background (if configured)

Check:
```bash
ls /Users/asep.indrayana/WeekendProj/akuntabel/frontend/playwright.config.ts 2>/dev/null && echo "YES" || echo "NO"
```

**If YES** — launch immediately with `run_in_background: true`:
```bash
cd /Users/asep.indrayana/WeekendProj/akuntabel/frontend && npx playwright test --reporter=line 2>&1 | tee /tmp/playwright-qa-results.txt
```

**If NO** — mark all UI criteria as MANUAL and continue. Do NOT stop. Do NOT suggest setup here.

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
| `UI` | mentions page, button, form, browser, click | Playwright test — or MANUAL if not configured |

If a criterion has no test command written in the plan → run the best-fit command for its type. Do NOT skip it.

---

## Step 3: Run static checks

Always run these regardless of what criteria say:

**Go:**
```bash
cd /Users/asep.indrayana/WeekendProj/akuntabel
go vet ./... 2>&1
go build ./... 2>&1
go test ./... -count=1 -timeout 60s 2>&1
```

**Frontend:**
```bash
cd /Users/asep.indrayana/WeekendProj/akuntabel/frontend
npx tsc --noEmit 2>&1
```

**Migrations:**
```bash
ls -1 /Users/asep.indrayana/WeekendProj/akuntabel/db/migrations/ | sort
```
For each `.up.sql` file, verify a `.down.sql` counterpart exists.

---

## Step 4: Run each criterion

For every criterion from Step 2, run its test command and capture the output.

**Criterion execution rules:**
- Run it. Do not say "this requires the server to be running" and skip it — try it.
- If a server is needed and not running, note "Server not running — start with `go run cmd/api/main.go`" and mark BLOCKED, not SKIP.
- If the test command is a curl and the server responds → parse the status code and body.
- If it's a `go test` → run it and capture pass/fail.
- If the criterion has an **expected outcome** in the plan → compare actual vs expected.
- If no expected outcome is written → flag as `NO_EXPECTED_OUTCOME` (warn, not fail).

**For UI criteria without Playwright:**
- Mark as `MANUAL` with the exact browser steps to verify (from the criterion text).
- Do NOT skip. Do NOT say "set up Playwright". Generate the manual checklist.

---

## Step 5: Collect Playwright results

```bash
cat /tmp/playwright-qa-results.txt 2>/dev/null || echo "NOT_RUN"
```

Parse: `N passed`, `N failed`, `N skipped`. Map each test name back to its criterion if possible.

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
| 3 | [criterion text] | UI | 🔲 MANUAL | [expected] | [browser steps] |
| 4 | [criterion text] | API | ⚠️ NO_EXPECTED_OUTCOME | — | HTTP 200 |

### Static Checks
- go vet: ✅ PASS / ❌ FAIL
- go build: ✅ PASS / ❌ FAIL
- go test ./...: ✅ N passed / ❌ N failed
- tsc --noEmit: ✅ PASS / ❌ FAIL

### Migrations
- [filename].up.sql ↔ [filename].down.sql: ✅ paired / ❌ UNPAIRED

### Playwright (UI)
- Status: ✅ N passed / ❌ N failed / ⏭ NOT_CONFIGURED
- [list any failed test names]

---
QA STATUS: ✅ ALL PASS / ❌ [N] FAILURES / ⚠️ [N] MANUAL REQUIRED

Failures (must fix before merge):
  ❌ Criterion 2: [exact error]

Manual verification required:
  🔲 Criterion 3: [browser steps]

Criteria with no expected outcome (add to plan):
  ⚠️ Criterion 4: [write expected outcome so next QA run can auto-verify]
```

---

## Rules

- **Never stop because a tool is not installed.** Run what exists; classify what cannot run.
- **Never end with setup suggestions.** The report ends with pass/fail, not "install X".
- **MANUAL is not SKIP.** A manual criterion must have browser steps listed.
- **BLOCKED is not FAIL.** A blocked criterion (server down) must say exactly how to unblock.
- `NO_EXPECTED_OUTCOME` is a warning — it means the plan needs hardening, not that QA failed.
- If a criterion says "verify X works" with no specifics → derive the test from the plan wiring (find the endpoint, run curl against it).
- After reporting, update the plan file's Success Criteria checkboxes: `[ ]` → `[x]` for PASS, `[!]` for FAIL.
