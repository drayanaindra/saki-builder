---
name: approved
description: Approve the current plan and switch model to Sonnet. Enforces XP discipline — TDD cycle (Red→Green→Refactor), commit-per-step, YAGNI check, metrics-triggered refactoring. Loads the plan's research context, reconciles plan↔code drift in place, and runs a Plan-Conformance Gate (every wiring chain verified against the diff) before /saki-builder:qa so implementation stays consistent with the approved design.
user-invocable: true
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

## Step 2: Load the plan + its research context

**If the caller (e.g. `/saki-builder:build`) named a specific plan file, use that exact path** — it pins
implementation to the intended slice, not whichever `*-plan.md` is newest. Otherwise find the most recent
`*-plan.md` in `tasks/` (workflow artifacts live under `tasks/`, not the project root). Read it. Extract:
- All steps with their Test column and Committable flag
- The **Evidence Ledger** — index every blocking item by the step number it cites. Items without a step number go in a "global" bucket.

Then load the plan's companion files (same `[task]` slug):
- **`[task]-context.md`** (the research findings `/saki-builder:rplan` pinned: existing models, schemas, file paths, patterns). If present, this is your **source of truth for existing code shape** — do NOT re-derive what it already documents (re-research wastes tokens and risks deriving a different shape than the plan assumed). If absent, note `⚠ no context file — will read code on demand` and proceed.
- **`[task]-flow.md`** (Gherkin behavior spec) if present — the implementation's observable behavior must match it.

If the plan has no Test column (old-format plan), derive TDD mode per step:
- Steps with service/domain logic → Test-First
- Steps with CRUD/handler/wiring → Test-Along
- Steps with **event emit / instrumentation** (a §5-metric `Emit <event>` step) → Test-Along — write the emit and a test asserting the emitter is called on the trigger (and NOT on the error path); never treat it as trivial Test-After, or the metric ships unrecorded
- Steps with config/migration/copy → Test-After

If the plan has no Evidence Ledger, warn (do not block):
```
⚠ Plan has no Evidence Ledger — proceeding without per-step risk surfacing.
  Recommend re-running /saki-builder:rplan to generate one before next implementation.
```

**Blocking-Set gate (readiness).** If the Evidence Ledger's **Blocking table is non-empty**, STOP — do not
implement. A verbal "approved" does not clear the readiness gate; the gate is *Blocking Set empty* (the same
bar `/saki-builder:build` auto-enforces before it runs a slice):
```
❌ Plan has [N] unresolved Blocking item(s) — not ready to implement:
  • [cited Blocking row]
Resolve each (re-run /saki-builder:rplan), or demote a genuinely non-load-bearing one to Advisory with a
cited reason. Then re-run /saki-builder:approved.
```

## Step 3: Confirm and begin

Respond with:

```
Model: SONNET | Status: Approved — XP implementation starting

Plan: [filename]
Steps: [N]
TDD mode breakdown: [N] Test-First, [N] Test-Along, [N] Test-After
```

Then immediately begin executing step by step using the XP cycle below.

**Resume manifest (best-effort):** if `tasks/.<slug>-state.json` exists (manual chain; `<slug>` = the plan
filename minus `-plan.md`), stamp `approved=in-progress` now via the **Stamp** snippet in
`${CLAUDE_PLUGIN_ROOT}/config/docs/manual-chain-resume.md` (`PLAN_FILE` = this plan). Absent file or error →
skip silently.

---

## XP Implementation Cycle (per plan step)

**Output discipline (anti-bloat, anti-hallucination).** Emit exactly ONE compact line per step on the happy path. Expand to detail ONLY on a notable event: RED unexpectedly passes, GREEN stays red, suite breaks, a YAGNI cut, a plan-drift adjustment, or a commit. Verbose per-step ceremony fills context and raises hallucination risk — keep the signal-to-noise high. The phases below are mandatory gates; only their *output* is condensed.

Compact per-step line (happy path):
```
[N/M] <step> · <TDD-mode> · RED✗→GREEN✓ · refactor:<none|what> · <commit sha|grouped>
```

For EACH step, run the cycle:

### Phase 1 — SPEC
Read the step's action, files, Test field. Pick TDD mode:

| TDD Mode | When | Cycle |
|----------|------|-------|
| Test-First | Business logic, domain rules, calculations | Write test → confirm RED → implement → confirm GREEN → refactor |
| Test-Along | Infrastructure, CRUD, handlers, wiring, **§5-metric emit / instrumentation** (an `Emit <event>` step) | Write code + test interleaved → confirm GREEN → refactor |
| Test-After | Config, migration, rename, trivial (**never an emit step** — an `Emit <event>` step is Test-Along above, so the metric can't ship unrecorded) | Implement → run existing test suite → refactor if needed |
| Human-Test-First | Auth, payment, multi-tenant security | ASK user to write/approve test → implement → confirm GREEN |

Resolve the step's blocking items as part of GREEN — never implement past a step whose unresolved item describes a real gap (missing auth, UNKNOWN, vague spec). Resolving = do the work, then delete the item citing where it was resolved.

### Phase 2 — RED (skip for Test-After / Test-Along)
Write the planned test asserting the **expected behavior** from the spec (not the implementation). Run it:
- Go: `go test ./[package]/... -run [TestName] -v -count=1`
- Frontend: `cd frontend && npm test -- --testPathPattern=[file]`

Confirm it FAILS. **If it passes → the test is wrong (asserts nothing) or the feature already exists — STOP and investigate**, print why.

### Phase 3 — GREEN
1. Write the MINIMUM code to pass the test.
2. **YAGNI:** before each new fn/struct/file — required by THIS step? breaks without it now? premature abstraction (interface w/ one impl, factory for one type, error handling for impossible states)? → if gratuitous, **cut it** (note the cut in the step line).
3. **Symbol pre-check (anti-hallucination):** before the FIRST use of any library / cross-module / unfamiliar symbol, grep or read it to confirm the name + signature exist. Prefer the shapes already pinned in `[task]-context.md`. **Never call a symbol from memory** — a hallucinated method costs a full Red→fix cycle.
4. Run the test → GREEN, then the package suite (`go test ./[package]/... -count=1`).
5. **Plan-drift check (keep the contract true):** if GREEN required deviating from the step's planned file / function / wiring, the plan is now stale — edit that plan line (and any affected **Plan Wiring** chain) in place to match what you built, appending `— adjusted in impl: <one-line why>`. Never let code and plan diverge silently; a stale plan poisons the next slice's planning.

**Hard gate:** test still red after implementation → debug, do NOT advance.

### Phase 4 — REFACTOR (metrics-triggered)
Check the files you touched: Go file >300 LOC → split · Go fn >40 LOC → extract · TSX >500 LOC → split component · same pattern 3+× → extract helper · complexity >10 → simplify. If any exceeded → refactor while keeping tests GREEN, re-run to confirm no regression. Else no-op (`refactor:none`).

### Phase 5 — COMMIT (only if Committable=Yes or last in an atomic group)
1. Full suite: `go test ./... -count=1 -timeout 60s`
2. Linter: `go vet ./...`
3. If frontend touched: `cd frontend && npx tsc --noEmit`
4. All green → stage, commit referencing the plan step, mark the step `[ ]`→`[x]` in the plan file.

**Never commit red** — fix first (hard gate). Committable=No → skip; the commit lands when the grouping step completes.

### Phase 6 — advance
Emit the compact step line, move to the next step.

---

## After All Steps Complete

### Phase 7: Plan-Conformance Gate (consistency check)

Before smoke/QA, verify the implementation matches the **approved** plan. This is the *"did we build what was approved"* gate — distinct from `/saki-builder:qa` (acceptance criteria) and `/saki-builder:reviewer` (correctness/security). It is the mechanism that makes implementation consistent after design approval.

1. Take the plan's **Plan Wiring** call-chains (`Component → api.ts fn → METHOD /path → service.fn → Model.field`) and the **Steps** table.
2. For each chain, grep the diff / codebase to confirm every named symbol exists **as wired**: the component, the api function, the route + method, the service function, the model field.
3. Classify each chain:
   - `✅ MATCHES` — every named symbol present and wired as planned.
   - `⚠ ADJUSTED` — deviates from the plan, but the plan was already reconciled in the Phase 3 drift-check (the plan line now describes what was built).
   - `✗ MISSING` — a named symbol is absent or wired differently and the plan was NOT updated. This is a real gap.
4. For every `✗ MISSING`: either fix the code to match the plan, or — if the deviation was intentional — reconcile the plan line now (Phase 3 drift rule) so it reads `⚠ ADJUSTED`. **Do not proceed to `/saki-builder:qa` with an unexplained `✗`.**

Print:
```
Plan-Conformance: [N] chains | ✅ [N] match | ⚠ [N] adjusted (plan updated) | ✗ [N] missing → [resolved how]
```

All chains must be `✅` or `⚠` before continuing.

### Phase 8: Pre-QA Smoke Check

Run the same env detection that `/saki-builder:qa` runs, so blockers surface here (with the implementer in context) instead of inside `/saki-builder:qa` (where they look like test failures):

```bash
# Frontend root (same logic as qa Step 1a)
FRONTEND_ROOT=""
for d in "$(pwd)" "$(pwd)/frontend" "$(pwd)/src"; do
  if [ -f "$d/playwright.config.ts" ]; then FRONTEND_ROOT="$d"; break; fi
done
echo "FRONTEND_ROOT=${FRONTEND_ROOT:-<none>}"

# Dev server ping (only if frontend project)
if [ -n "$FRONTEND_ROOT" ]; then
  curl -s --max-time 3 http://localhost:4000 > /dev/null 2>&1 && echo "SERVER_UP" || echo "SERVER_DOWN"
fi

# Playwright browsers (only if frontend project)
if [ -n "$FRONTEND_ROOT" ]; then
  ls ~/Library/Caches/ms-playwright/chromium-* 2>/dev/null || ls ~/.cache/ms-playwright/chromium-* 2>/dev/null || echo "NO_CHROMIUM"
fi
```

Print results. For any FAIL/DOWN/missing, surface the exact remediation command in the completion summary so the user can fix it before invoking `/saki-builder:qa`. Do NOT fix it automatically — env setup is the user's call.

### Phase 9: Stamp resume manifest (best-effort)

If a manual-chain manifest exists for this plan (`tasks/.<slug>-state.json`), stamp `approved=done` with the
final commit via the **Stamp** snippet in `${CLAUDE_PLUGIN_ROOT}/config/docs/manual-chain-resume.md`
(`PLAN_FILE` = this plan, `EXTRA='{"lastCommit":"<final sha>"}'`). Absent file or error → skip silently.

### Completion summary

```
--- IMPLEMENTATION COMPLETE ---
Steps: N/N completed
Commits: [N] commits made
TDD cycles: [N] Red→Green→Refactor completed
Refactoring: [N] metrics-triggered refactors performed
Evidence Ledger: [N] blocking items resolved during implementation, [N] remaining

XP Summary:
  Tests written first: [N]
  YAGNI items caught: [N] (things NOT built)

Plan-Conformance: [N] wiring chains | ✅ [N] | ⚠ [N] adjusted (plan reconciled)
  Plan drift reconciled: [N] step/wiring lines updated to match what was built
  [list each ⚠ adjustment: "step X — <what changed> — <why>"]

Pre-QA Smoke:
  Frontend project: [yes/no]
  Dev server: [up/down/n/a]      [if down: cd $FRONTEND_ROOT && npm run dev]
  Playwright browsers: [ok/missing/n/a]   [if missing: cd $FRONTEND_ROOT && npx playwright install chromium]

Next actions:
> /saki-builder:qa — run acceptance criteria verification
> /saki-builder:reviewer — fresh-context code review
> /saki-builder:retro — capture session learnings (if session > 30 min)
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
- **Load and trust `[task]-context.md`** — do NOT re-derive existing code shape (models, fields, signatures) it already documents; re-research wastes tokens and invites drift from the plan's assumptions
- **Never call a symbol from memory** — grep/read to confirm it exists before first use (Phase 3 symbol pre-check). A hallucinated method name costs a full Red→fix cycle
- **Keep the plan true** — any in-implementation deviation from a step's planned file/function/wiring must be reconciled back into the plan file (Phase 3 drift-check) so the contract never goes stale
- **Plan-Conformance Gate must pass before `/saki-builder:qa`** — every Plan-Wiring chain `✅ MATCHES` or `⚠ ADJUSTED` (plan updated); never advance with an unexplained `✗ MISSING`
- **One compact line per step** — expand output only on failure or a notable event (RED-passes / stays-red / YAGNI cut / drift adjustment / commit); verbose ceremony per step dilutes signal and raises hallucination risk
- If a step has no test specified and contains business logic → derive a test from the step's success criteria
- If no active plan is found, ask: "Which plan should I implement?"
- At branch points: state situation + options, choose safest default if no user response
