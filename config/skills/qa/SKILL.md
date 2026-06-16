---
name: qa
description: Run QA against the plan's acceptance criteria. Reads Success Criteria from the plan, runs each one, fills in the checklist, reports pass/fail per criterion. Auto-generates and runs Playwright tests for UI criteria when playwright.config.ts is detected.
---

# QA — Acceptance Criteria Runner

You run tests. You do not suggest setup. You do not end with "next steps". You execute every testable criterion in the plan and report the result.

For Playwright edge cases (auth fixture imports, `addInitScript` safety, teardown patterns, `TEST_JWT` loading, CI browser install), see the sibling reference: `~/.claude/skills/qa/playwright-patterns.md`. Read it only when generating or debugging a Playwright spec — do NOT load it eagerly.

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

### Step 0.5: Prefer flow doc for UI scenarios

Also look for a matching `*-flow.md` (Gherkin behavior spec):
```bash
FLOW_FILE="${PLAN_FILE%-plan.md}-flow.md"
[ -f "$FLOW_FILE" ] && echo "FLOW_FOUND=$FLOW_FILE" || echo "FLOW_NONE"
```

If a flow doc exists:
- **It is the source of truth for UI behavior.** Each `Scenario:` becomes one generated Playwright spec in Step 1.5.
- Non-UI criteria (API, GO_TEST, DB, BUILD, FILE) still come from the plan's Success Criteria.
- Map each `Scenario:` to a `criterion-id` of the form `FLOW-{role}-{n}` (e.g. `FLOW-kasir-1` for the first scenario under `Feature: Kasir`).
- Use `Given/Background` for setup, `When` for actions, `Then/And` as assertions.

If no flow doc exists, fall back to deriving UI specs from the plan's Success Criteria as before.

Log:
```
Flow doc: [filename or "none — using plan criteria"]
Scenarios found: [N]
```

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

If `FRONTEND_ROOT` is empty → mark all UI criteria as MANUAL; skip Steps 1b, 1c, 1d, and Step 1.5 entirely.

### 1b: Ping baseURL (only if FRONTEND_ROOT found)

**Derive the dev-server URL from the project — never hardcode the port.** `playwright.config.ts` `baseURL` is the source of truth (a project-local qa override SKILL.md may also document it). Only fall back to `:3000` if nothing is found. (Common trap: another project's server may answer on a different port — pinging a hardcoded port can read a *different app* as "up".)

```bash
# Source of truth: playwright.config baseURL (handles PLAYWRIGHT_BASE_URL ?? 'http://localhost:PORT')
BASE_URL=$(grep -oE "https?://localhost:[0-9]+" "$FRONTEND_ROOT/playwright.config.ts" 2>/dev/null | head -1)
BASE_URL=${BASE_URL:-http://localhost:3000}
curl -s --max-time 3 "$BASE_URL" > /dev/null 2>&1 && echo "SERVER_UP ($BASE_URL)" || echo "SERVER_DOWN ($BASE_URL)"
```

Use `$BASE_URL` (not a hardcoded host) for all subsequent navigation/MCP/Playwright steps. If SERVER_DOWN → emit:

```
⚠️ BLOCKED: Dev server not running.
Start with: cd [FRONTEND_ROOT] && npm run dev
Playwright tests will not run. UI criteria marked BLOCKED.
```

Skip Steps 1c, 1d, and 1.5; mark all UI criteria as BLOCKED (not FAIL).

### 1c: Detect MCP Playwright availability

Check whether the session has MCP Playwright tools loaded. Tools with prefix `mcp__playwright__` are exposed when `@playwright/mcp` is registered in `~/.claude.json` (installed by `claude-config/install.sh`).

- If available → `MCP_MODE=available` — preferred path for UI criteria. No spec generation, no `npx playwright test`. Skip Step 1d and Step 1.5.
- If not available → `MCP_MODE=unavailable` — fall back to the existing spec-generation flow (Step 1d, Step 1.5, Step 5).

Log it:

```
Mode: MCP-driven  (via @playwright/mcp)
— or —
Mode: Playwright-spec (auto-generated specs under e2e/qa-generated/)
```

### 1d: Check Playwright browsers installed

Run only if `MCP_MODE=unavailable` AND `FRONTEND_ROOT` set.

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

**Run only if pre-flight passed (FRONTEND_ROOT set, server up, browsers installed) AND `MCP_MODE=unavailable`.** When `MCP_MODE=available`, skip this step entirely — UI criteria are driven directly via `mcp__playwright__*` tools in Step 4.

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
import { test, expect } from "../../fixtures/auth";

const TOKEN = process.env.TEST_JWT ?? "";

test.describe("[criterion-id]: [criterion description]", () => {
  test("[test name]", async ({ page, loginWithToken }) => {
    test.skip(!TOKEN, "TEST_JWT not set — run: cp .env.test.example .env.test");
    await loginWithToken(TOKEN);
    await page.goto("[target url]");
    await page.waitForLoadState("networkidle");
    // [assertions derived from Playwright: stub or Manual: steps]
  });
});
```

**Important**: import path `../../fixtures/auth` is relative to `e2e/qa-generated/{slug}/` — adjust depth if structure differs.

If zero UI criteria found → warn "No UI criteria found — 0 specs generated, skipping Playwright" and skip Playwright run.

---

## Step 2: Classify and prioritize each criterion

For each item in the Success Criteria section, classify it:

| Type      | Signal                                               | How to test                                                      |
| --------- | ---------------------------------------------------- | ---------------------------------------------------------------- |
| `API`     | mentions endpoint, HTTP, curl, status code           | `curl -s -o /dev/null -w "%{http_code}"`                         |
| `GO_TEST` | mentions Go function, service, repository, unit test | `go test ./internal/[pkg]/... -run [TestName] -v`                |
| `FILE`    | mentions file exists, migration file, config         | `ls -la [path]`                                                  |
| `DB`      | mentions table, column, row, migration applied       | `psql $DATABASE_URL -c "[query]"`                                |
| `BUILD`   | always run — type check + compile                    | `go build ./...`, `npx tsc --noEmit`                             |
| `UI`      | mentions page, button, form, browser, click          | Playwright spec (Step 1.5) — or MANUAL/BLOCKED if not configured |

If a criterion has no test command written in the plan → run the best-fit command for its type. Do NOT skip it.

### 2a: Risk-based prioritization

After classifying, tag each criterion with a risk priority:

| Priority | Domain signals | Execution order |
| -------- | -------------- | --------------- |
| `CRITICAL` | payment, auth, login, delete, multi-tenant, RLS, token, checkout | Run first |
| `HIGH` | DB write (INSERT/UPDATE), stock deduction, journal posting | Run second |
| `NORMAL` | Read-only, UI display, file existence, build check | Run last |

**Fail-fast rule:** If ANY `CRITICAL` criterion fails → stop execution immediately. Report what passed and what failed. Do not continue to HIGH/NORMAL criteria — a CRITICAL failure means the feature is unsafe to ship.

Log prioritization:

```
Risk prioritization:
  CRITICAL: [N] criteria (run first, fail-fast)
  HIGH:     [N] criteria
  NORMAL:   [N] criteria
```

---

## Step 2.5: Exploratory test derivation

**Think like a senior QA:** For each criterion, derive 2-3 edge cases that the plan author probably didn't think of. These are NOT in the acceptance criteria — they are additional probes to catch hidden bugs.

### Derivation rules by criterion type

| Type | Edge cases to derive |
| ---- | -------------------- |
| `API` | (1) Send request with missing required field → expect 400/422. (2) Send request with wrong type (string where number expected) → expect 400/422. (3) Send request without auth token → expect 401. |
| `UI` | (1) Double-click the primary action button rapidly → should not create duplicates. (2) Submit form with all fields empty → should show validation errors, not crash. (3) Paste special characters (`<script>alert(1)</script>`, `'; DROP TABLE`) in text inputs → should be escaped/rejected. |
| `GO_TEST` | (1) Call function with zero-value arguments → should return error, not panic. (2) Call function with nil context → should return error. (3) If function accepts numeric input, try boundary: 0, -1, MaxInt64. |
| `DB` | (1) Query with non-existent tenant ID → should return empty, not error. (2) Check that the operation respects RLS (query without tenant context should fail). (3) If inserting numeric values, try 0 and maximum values. |

### Execution

For each criterion:
1. Derive the edge cases based on type rules above
2. Tag each derived case as `EXPLORATORY`
3. Run them using the same tooling as the parent criterion (curl, go test, MCP browser, psql)
4. Record PASS/FAIL — an exploratory FAIL is a warning, not a blocker (unless it reveals a crash or security issue)

Log:
```
Exploratory derivation:
  [Criterion ID]: [N] edge cases derived
    EXPL-1: [description] → [PASS/FAIL]
    EXPL-2: [description] → [PASS/FAIL]
```

**Security-critical exploratory failures** (panic, 500 on bad input, XSS reflection, SQL error in response body) are auto-promoted to CRITICAL FAIL — these block the build.

---

## Step 2.7: Diff-aware regression detection

Identify what changed since the base branch and map to related test files.

### Detection

```bash
git diff main --name-only 2>/dev/null || git diff HEAD~5 --name-only 2>/dev/null
```

### Mapping rules

| Changed file pattern | Related tests to run |
| -------------------- | -------------------- |
| `internal/pos/*.go` | `go test ./internal/pos/... -v`, `e2e/pos.spec.ts`, `e2e/qa-generated/**/pos*` |
| `internal/accounting/*.go` | `go test ./internal/accounting/... -v` |
| `internal/inventory/*.go` | `go test ./internal/inventory/... -v`, `e2e/persediaan/*` |
| `internal/[pkg]/*.go` | `go test ./internal/[pkg]/... -v`, `e2e/**/[pkg]*` |
| `frontend/src/features/[feat]/**` | `e2e/qa-generated/[feat]/*`, `e2e/[feat]*` |
| `frontend/src/app/(dashboard)/[page]/**` | `e2e/**/[page]*` |
| `db/migrations/*` | Run `migrate` dry-run check, verify migration pairing |

### Execution

1. Collect changed files from git diff
2. Map each to related test files/packages using the rules above
3. Run ALL mapped tests (deduplicated) — these run IN ADDITION to static checks
4. Report results in "REGRESSION" section

Log:
```
Regression detection:
  Changed files: [N]
  Mapped test targets: [N]
  [file] → [test target]
  ...
```

If no changed files detected (clean working tree on main) → skip regression, log: "No diff from main — regression detection skipped."

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

- If `MCP_MODE=available` → drive the browser directly via `mcp__playwright__*` tools:
  1. `mcp__playwright__browser_navigate` to the target URL
  2. `mcp__playwright__browser_snapshot` or `browser_take_screenshot` to observe state
  3. `mcp__playwright__browser_click` / `browser_type` / `browser_fill_form` for interactions
  4. Assert the `Expected outcome:` from the plan against the observed snapshot/URL/DOM
  5. Record PASS/FAIL per criterion. No spec file is written under `e2e/qa-generated/`.
- If `MCP_MODE=unavailable` and spec was generated in Step 1.5 → result comes from Step 5 Playwright output.
- If `MCP_MODE=unavailable` and Playwright not configured → mark MANUAL with exact browser steps.
- If server was BLOCKED → mark BLOCKED.

---

## Step 4.5: Data integrity checks

**Run for any criterion that involves a write operation** (POST, PUT, DELETE, or DB-type criteria). Senior QA always verifies the actual data, not just the API response.

### When to run

If the criterion's test involves:
- `curl` with `-X POST`, `-X PUT`, or `-X DELETE`
- `psql` with INSERT, UPDATE, DELETE
- MCP browser form submission that triggers a write

### What to check

For each write-operation criterion, generate and run verification queries:

| Write type | Verification query |
| ---------- | ------------------ |
| Create (POST/INSERT) | `SELECT COUNT(*) FROM [table] WHERE [identifying fields match]` → expect 1 |
| Update (PUT/UPDATE) | `SELECT [changed_field] FROM [table] WHERE [id]` → expect new value |
| Delete (DELETE) | `SELECT COUNT(*) FROM [table] WHERE [id]` → expect 0 |
| Financial (journal/payment) | `SELECT SUM(debit) - SUM(credit) FROM journal_entries WHERE [txn]` → expect 0 (balanced) |
| Inventory (stock change) | `SELECT stock FROM products WHERE [id]` → expect previous - qty_sold |
| Multi-tenant write | `SELECT COUNT(*) FROM [table] WHERE tenant_id != '[test_tenant]' AND [new_record_fields]` → expect 0 (no cross-tenant leak) |

### Execution

```bash
psql $DATABASE_URL -c "[generated verification query]"
```

If `$DATABASE_URL` is not set → mark all data integrity checks as `BLOCKED: DATABASE_URL not set`.

Log:
```
Data integrity:
  [Criterion ID]: [write type]
    DI-1: [query description] → [PASS/FAIL] ([actual value])
    DI-2: [tenant isolation check] → [PASS/FAIL]
```

**Tenant isolation failures are auto-promoted to CRITICAL FAIL.**

---

## Step 4.7: Negative input probes

**Run for every API-type criterion.** Senior QA always tests what happens with bad input.

### Probe set (per API criterion)

For each API endpoint identified in the criterion:

| Probe | What to send | Expected response |
| ----- | ------------ | ----------------- |
| `NEG-1: Empty body` | `curl -X [METHOD] [URL] -H "Content-Type: application/json" -d '{}'` | 400 or 422 |
| `NEG-2: Missing required field` | Same as criterion's curl but remove one required field | 400 or 422 |
| `NEG-3: Wrong type` | Same as criterion's curl but send string where number expected (e.g. `"qty": "abc"`) | 400 or 422 |
| `NEG-4: No auth` | Same as criterion's curl but remove Authorization header | 401 |
| `NEG-5: XSS probe` | Same as criterion's curl but inject `<script>alert(1)</script>` in a string field | 400/422, or 200 with escaped output (NOT raw reflection) |

### For UI criteria with forms (MCP mode)

If `MCP_MODE=available` and the criterion involves form submission:

1. Navigate to the form page
2. Click the submit button WITHOUT filling any fields → expect validation errors
3. Fill a text field with `<script>alert(1)</script>` → submit → check the value is escaped in the page snapshot (not reflected as raw HTML)

### Execution

Run each probe and record the HTTP status code. A probe PASSES if:
- The server returns the expected error status (400/401/422)
- The server does NOT return 500 (internal server error = unhandled bad input = bug)
- The server does NOT reflect XSS payloads unescaped

**500 responses to bad input are auto-promoted to HIGH FAIL** — they indicate missing input validation.

Log:
```
Negative probes:
  [Criterion ID] ([METHOD] [URL]):
    NEG-1: empty body → [status] [PASS/FAIL]
    NEG-2: missing field → [status] [PASS/FAIL]
    NEG-3: wrong type → [status] [PASS/FAIL]
    NEG-4: no auth → [status] [PASS/FAIL]
    NEG-5: XSS probe → [status] [PASS/FAIL]
```

---

## Step 5: Run Playwright + collect results

**Run only if Step 1.5 generated at least 1 spec (i.e. `MCP_MODE=unavailable`). When `MCP_MODE=available`, skip — UI results came from Step 4 MCP tool calls.**

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
Mode: MCP-driven  (or: Playwright-spec  (or: MANUAL — no FRONTEND_ROOT)

### Acceptance Criteria (priority order: CRITICAL → HIGH → NORMAL)

| # | Criterion | Type | Priority | Result | Expected | Actual |
|---|-----------|------|----------|--------|----------|--------|
| 1 | [criterion text] | API | CRITICAL | ✅ PASS | HTTP 200 | HTTP 200 |
| 2 | [criterion text] | GO_TEST | HIGH | ❌ FAIL | pass | FAIL: [error] |
| 3 | [criterion text] | UI | NORMAL | ✅ PASS | not /masuk | $BASE_URL/pos |

### Exploratory Testing

| Criterion | Edge Case | Result | Finding |
|-----------|-----------|--------|---------|
| SC-1 | EXPL-1: double-click submit | ✅ PASS | No duplicates |
| SC-1 | EXPL-2: empty form submit | ❌ FAIL | 500 error (missing validation) |
| SC-2 | EXPL-1: zero quantity | ✅ PASS | Returns 422 |

Exploratory summary: [N] probes, [N] passed, [N] failed, [N] security-critical

### Regression Testing

| Changed file | Test target | Result |
|-------------|-------------|--------|
| internal/pos/service.go | go test ./internal/pos/... | ✅ PASS |
| frontend/src/features/pos/* | e2e/pos.spec.ts | ✅ PASS |

Regression summary: [N] targets, [N] passed, [N] failed

### Data Integrity

| Criterion | Check | Query | Result | Actual |
|-----------|-------|-------|--------|--------|
| SC-1 | Row created | SELECT COUNT(*) ... | ✅ PASS | 1 |
| SC-1 | Journal balanced | SUM(debit)-SUM(credit) | ✅ PASS | 0 |
| SC-1 | Tenant isolation | COUNT WHERE tenant != X | ✅ PASS | 0 |

Data integrity summary: [N] checks, [N] passed, [N] failed

### Negative Input Probes

| Criterion | Probe | Status | Result |
|-----------|-------|--------|--------|
| SC-1 | NEG-1: empty body | 422 | ✅ PASS |
| SC-1 | NEG-2: missing field | 422 | ✅ PASS |
| SC-1 | NEG-3: wrong type | 500 | ❌ FAIL (unhandled) |
| SC-1 | NEG-4: no auth | 401 | ✅ PASS |
| SC-1 | NEG-5: XSS probe | 422 | ✅ PASS |

Negative probe summary: [N] probes, [N] passed, [N] failed

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
### QA Score

| Category | Weight | Passed | Total | Score |
|----------|--------|--------|-------|-------|
| Acceptance criteria | 40% | [N] | [N] | [N]% |
| Regression tests | 25% | [N] | [N] | [N]% |
| Exploratory probes | 20% | [N] | [N] | [N]% |
| Negative probes | 15% | [N] | [N] | [N]% |
| **OVERALL** | **100%** | | | **[N]%** |

QA STATUS: ✅ ALL PASS ([N]%) / ❌ [N] FAILURES ([N]%) / ⚠️ [N] MANUAL REQUIRED

CRITICAL failures (must fix immediately):
  ❌ [security/crash issues from exploratory or negative probes]

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
- **MCP Playwright tools are only for `/qa` and explicit debug sessions.** Do not invoke `mcp__playwright__*` tools during regular coding work. This keeps the "on-demand" contract even though the MCP server is always loaded at session start.
