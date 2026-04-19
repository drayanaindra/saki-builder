---
name: approved
description: Approve the current plan and switch model to Sonnet. Enforces XP discipline — TDD cycle (Red→Green→Refactor), commit-per-step, YAGNI check, and metrics-triggered refactoring during implementation.
---

# Plan Approved — XP Implementation Mode

The user has reviewed and approved the current plan. Do the following in order:

## Step 1: Switch model to Sonnet

Run this bash command to update the model in settings:

```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude' / 'settings.json'
s = json.loads(p.read_text())
s['model'] = 'claude-sonnet-4-6'
p.write_text(json.dumps(s, indent=2))
print('Model set to claude-sonnet-4-6')
"
```

## Step 2: Load the plan

Find the most recent `*-plan.md` in the project root. Read it. Extract all steps with their Test column and Committable flag.

If the plan has no Test column (old-format plan), derive TDD mode per step:
- Steps with service/domain logic → Test-First
- Steps with CRUD/handler/wiring → Test-Along
- Steps with config/migration/copy → Test-After

## Step 3: Confirm and begin

Respond with:

```
Model: SONNET | Status: Approved — XP implementation starting

Plan: [filename]
Steps: [N]
TDD mode breakdown: [N] Test-First, [N] Test-Along, [N] Test-After
```

Then immediately begin executing step by step using the XP cycle below.

---

## XP Implementation Cycle (per plan step)

For EACH step in the plan, follow this cycle:

### Phase 1: SPEC — Read the step

Read the step's action, files, and Test field. Determine TDD mode:

| TDD Mode | When | Cycle |
|----------|------|-------|
| Test-First | Business logic, domain rules, calculations | Write test → confirm RED → implement → confirm GREEN → refactor |
| Test-Along | Infrastructure, CRUD, handlers, wiring | Write code + test interleaved → confirm GREEN → refactor |
| Test-After | Config, migration, rename, trivial | Implement → run existing test suite → refactor if needed |
| Human-Test-First | Auth, payment, multi-tenant security | ASK user to write/approve test → implement → confirm GREEN |

Print:
```
[STEP N/M] [step description]
  TDD: [Test-First / Test-Along / Test-After / Human-Test-First]
  Test: [test function name from plan, or "derive from spec"]
  Files: [list]
```

### Phase 2: RED — Write the failing test

**Skip this phase for Test-After and Test-Along modes.**

1. Write the test file/function specified in the plan's Test column
2. The test must assert the EXPECTED BEHAVIOR from the plan specification, NOT the implementation
3. Run the test:
   - Go: `go test ./[package]/... -run [TestName] -v -count=1`
   - Frontend: `cd frontend && npm test -- --testPathPattern=[file]`
4. Confirm it FAILS (RED). If it passes → the test is wrong (testing nothing) or the feature already exists. Investigate before proceeding.

Print:
```
  RED ✗ [TestName] — [failure reason, e.g. "function not found", "nil pointer"]
```

### Phase 3: GREEN — Write minimum code to pass

1. Implement the MINIMUM code needed to make the test pass
2. **YAGNI check:** Before writing each new function/struct/file, ask:
   - Is this required by the current step? If no → don't write it
   - Will the code break without it? If no → don't write it
   - Am I adding error handling for impossible states? If yes → remove it
   - Am I abstracting prematurely (interface with one impl, factory for one type)? If yes → simplify
3. Run the test again. Confirm it PASSES (GREEN).
4. Run the full test suite for the package: `go test ./[package]/... -count=1`

Print:
```
  GREEN ✓ [TestName] passed
  Suite: [N] passed, [N] failed (if any failures, fix before proceeding)
```

**If test still fails after implementation:** Debug. Do NOT move on with a failing test. This is a hard gate.

### Phase 4: REFACTOR — Clean up (metrics-triggered)

Check these metrics on the files you just modified:

| Metric | Threshold | Action |
|--------|-----------|--------|
| Go file LOC | > 300 lines | Split into focused files |
| Go function LOC | > 40 lines | Extract helper functions |
| TSX file LOC | > 500 lines | Split component |
| Duplication | Same pattern 3+ times in codebase | Extract shared helper |
| Cyclomatic complexity | > 10 per function | Simplify conditionals |

If ANY threshold is exceeded:
1. Refactor while keeping tests GREEN
2. Run tests after refactoring to confirm no regression
3. Print: `REFACTOR: [what was done] — tests still GREEN ✓`

If NO threshold exceeded:
- Print: `REFACTOR: metrics OK — no refactoring needed`

### Phase 5: COMMIT — Small release

**Only if step is marked Committable=Yes (or is the last in an atomic group):**

1. Run full project test suite: `go test ./... -count=1 -timeout 60s`
2. Run linter: `go vet ./...`
3. If frontend was touched: `cd frontend && npx tsc --noEmit`
4. If ALL pass → stage and commit with descriptive message referencing the plan step
5. Mark step as complete in the plan file: `[ ]` → `[x]`

Print:
```
  COMMIT: Step N/M — [commit message summary]
  Tests: [N] passed | Vet: clean | TSC: clean
```

**If tests fail:** Fix before committing. Do NOT commit with failing tests. This is a hard gate.

**If step is Committable=No:** Skip this phase, continue to next step. The commit happens when the completing step finishes.

### Phase 6: NEXT — Move to next step

Print progress:
```
[DONE] Step N/M — [1-line summary]
[NEXT] Step N+1/M — [next step description]
```

---

## After All Steps Complete

```
--- IMPLEMENTATION COMPLETE ---
Steps: N/N completed
Commits: [N] commits made
TDD cycles: [N] Red→Green→Refactor completed
Refactoring: [N] metrics-triggered refactors performed

XP Summary:
  Tests written first: [N]
  YAGNI items caught: [N] (things NOT built)
  
Next actions:
> /qa — run acceptance criteria verification
> /reviewer — fresh-context code review
> /retro — capture session learnings (if session > 30 min)
```

---

## Rules

- Do NOT ask for further confirmation — the user has already approved
- Do NOT re-summarize the plan — start step 1 immediately
- Do NOT skip the RED phase for Test-First steps — a test that never failed proves nothing
- Do NOT write more code than the test requires (GREEN = minimum to pass, nothing more)
- Do NOT refactor without running tests before and after
- Do NOT commit with failing tests — ever
- Do NOT add features/abstractions not in the plan step (YAGNI)
- If a step has no test specified and contains business logic → derive a test from the step's success criteria
- If no active plan is found, ask: "Which plan should I implement?"
- At branch points: state situation + options, choose safest default if no user response
