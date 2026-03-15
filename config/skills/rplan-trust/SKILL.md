---
name: rplan-trust
description: Fully autonomous plan-review-implement pipeline. Runs /rplan -> /rplan-review -> /approved automatically if confidence >96%. Structural completeness scan before probing. Auto-creates feature branch if on main. QA check after implementation. No user confirmation needed for CLI commands. Hard blocks on DB destructive ops.
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
This operation is forbidden in /rplan-trust mode.
Resolve manually or use /rplan (manual mode) with explicit human approval.
```

---

## Phase 1: PLAN (/rplan behavior)

Switch model to Opus:

```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.claude' / 'settings.json'
s = json.loads(p.read_text())
s['model'] = 'claude-opus-4-6'
p.write_text(json.dumps(s, indent=2))
print('Model set to claude-opus-4-6')
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

## Phase 2: REVIEW (/rplan-review behavior — structural scan + confidence-driven probing)

Execute adversarial review autonomously in two sub-phases.

### Phase 2a: Structural Completeness Scan (AUTO-FILL mode)

**Do NOT ask the user. Resolve gaps by reading code.**

Check the plan for missing sections:

| Required Section | Present? | Auto-fill action if missing |
|-----------------|----------|-----------------------------|
| Steps table (exact file paths + function names) | | If vague, read code and add exact names |
| User Role Coverage matrix | | Read routes/deps and derive which roles are affected |
| Plan Wiring (end-to-end call chains) | | Read frontend + service + model files and write chains |
| Migration Checklist | | Read models for schema changes, list alembic commands |
| Implementation Completeness Checklist | | Fill in from plan content + code research |
| Success Criteria (testable) | | Derive from plan steps if missing |

For each ❌ missing section:
1. Read the relevant code files to gather the missing information
2. Write the section directly into `[task]-plan.md`
3. Print: `AUTO-FILLED: [section] — derived from [file:line]`

If a section **cannot be auto-filled** (e.g., user intent is unclear, feature scope is ambiguous):
```
STRUCTURAL BLOCKER — cannot auto-fill
Section: [name]
Problem: [why it cannot be derived from code]
Resolution: Re-run /rplan with clearer task description, or use /rplan manually.
```
Stop. Do NOT proceed to Phase 2b.

### Phase 2b: Content Depth Probing

After all structural sections are present, run the adversarial probe loop.

- Identify all unknowns, risky assumptions, suspicious confidence scores, HIGH-risk steps
- For each probe: **read the actual code/files to verify** — do NOT guess
- Annotate `[task]-plan.md` under "Annotation Space" with each finding
- Recalculate confidence after each probe

**Do NOT ask the user questions.** Resolve each question by reading code.

Print each probe:
```
--- REVIEW PROBE [N] ---
Probing: [assumption or unknown]
Verified by: [file:line or command run]
Finding: [what was found]
Confidence: [X]% → [Y]%
```

**Keep probing until confidence > 96%.** No fixed round limit. Stop only when:
- Confidence > 96% AND no remaining HIGH-risk unprobed items → proceed to Phase 3
- A BLOCKER is found that cannot be resolved by reading code → stop, report blocker

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
- Switch model to Sonnet:
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
- Proceed to Phase 4 immediately.

**If confidence <= 96% after exhausting all resolvable probes:**
- STOP. Output:
  ```
  AUTO-APPROVE BLOCKED
  Confidence [X]% did not reach 96% threshold for /rplan-trust.

  Unresolved blockers:
    - [list]

  Options:
  > Resolve blockers manually, then re-run /rplan-trust
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

### 5b: Acceptance criteria test

Read the `Success Criteria` section from the active `[task]-plan.md`. For each criterion, classify it:

**Automatable** — can be verified by curl, CLI command, file existence check, or grep:
- HTTP status checks (e.g. "page loads without error" → `curl -w "%{http_code}"`)
- API response shape (e.g. "returns JSON with `data` field" → `curl | jq`)
- File exists (e.g. "migration file created" → `ls`)
- Build output (e.g. "no TypeScript errors" → already covered by 5a)
- Config presence (e.g. "env var added to .env.example" → `grep`)

**Manual-only** — requires human eyes, browser interaction, or live data:
- UI rendering/visual correctness
- Form interactions (type, click, submit)
- Auth flows (OAuth redirects)
- AI output quality (e.g. "skill names are properly normalized")
- End-to-end flows requiring login

Run all automatable criteria. For each:
```
[AUTO] "[criterion text]"
  Test: [command run]
  Result: PASS / FAIL
  Detail: [output or error if FAIL]
```

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

Write a file `[task]-qa.md` in the project root with all manual-only criteria, formatted as a checklist for the human to verify:

```markdown
# QA Manual Test Checklist — [task name]

Generated: [date]
Branch: [branch-name]

## Automated Results (already verified)
- [x] [criterion] — PASS
- [x] [criterion] — PASS

## Manual Tests Required

### [criterion 1]
**What to test:** [specific steps to reproduce]
**Expected:** [what success looks like]
**Result:** [ ] Pass  [ ] Fail
**Notes:** ___

### [criterion 2]
...

## Environment
- Frontend: http://localhost:4000
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
