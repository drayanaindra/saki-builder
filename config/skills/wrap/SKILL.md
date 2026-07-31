---
name: wrap
description: Full Definition of Done gate + converge-to-clean. Runs build, tests, coverage (≥80%), security scan, migration integrity, and SonarQube quality gate BEFORE committing/pushing. Only proceeds to git cleanup when all DoD gates pass. Run as the LAST step of any task. Pass `--heal` for autonomous mode (auto-fix + re-run each failing gate instead of stopping; used by /build).
---

# Wrap — Definition of Done → converge to clean

`/wrap` has two jobs, in this order:

1. **Definition of Done gate** — verify the work is actually done before it touches git
2. **Converge to clean** — commit WIP, push, remove worktrees, switch to main

**Order is law.** If ANY DoD gate fails, stop immediately. Do not commit, do not push, do not switch to main. Report what failed and the exact command to fix it.

**Two modes.** Default (manual) = fail-stop, as above. **`--heal`** (autonomous — how `/build` calls it) = a failing DoD gate is *auto-fixed and re-run* instead of stopping, under a 3-strike honesty backstop. See the **Autonomous heal mode** section below. Everything else — Phase 0 and Phases 2–6 — is identical in both modes.

---

## The invariant you must reach

After `/wrap` returns success, ALL of these hold:

1. **DoD gates all passed** — build, tests, coverage, security, migrations, quality gate
2. **No uncommitted work** — `git status --porcelain` is empty in primary checkout and every worktree
3. **No stranded commits** — every branch is pushed; `git rev-list origin/<branch>..<branch>` is empty
4. **No leftover worktrees** — `git worktree list` shows only the primary checkout
5. **Primary checkout is on `main`** (or repo default), up to date, clean tree

---

## Phase 0 — Snapshot & detect context

Pin reality before changing anything:

```bash
PRIMARY="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
git worktree list
git rev-parse --abbrev-ref HEAD
git status --porcelain
git remote -v | head -1
git fetch origin --prune
```

Detect:
- **Mode**: `--heal` present in the invocation → run in **Autonomous heal mode** (Phase-1 failures route + re-run, see the section below); otherwise default fail-stop.
- **Primary checkout** path **and its current branch** (may be a non-default feature branch with commits to push — the common `/build` case)
- **Default branch** (`git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`, fallback `main`)
- Every **linked worktree** (path + branch)
- Which trees are **dirty**
- **Project type**: look for `go.mod` (Go), `package.json` (Node), `requirements.txt` / `pyproject.toml` (Python), or combinations

If there is no `origin`, skip all push steps — still run DoD gates, commit, remove worktrees, and switch to main. Say push was skipped.

---

## Autonomous heal mode (`--heal`)

`/build` (and any TRUST-MODE caller) invokes `/wrap --heal`. In this mode a **Phase-1 DoD gate failure does not stop the run** — it is routed to the *shallowest* skill that fixes it, then the **full Phase-1 gate is re-run from the top** (a fix can ripple into another gate — new tests shift coverage, a dep bump breaks the build, a Sonar fix touches a tested line). This mirrors `/build`'s step-5.5 "re-run the tail until all clean" depth routing. Phase 0 and Phases 2–6 are unchanged: once every gate is green, the same commit → push → remove-worktrees → switch-to-main convergence runs.

**Heal routing — DoD gate → shallowest fix:**

| Failing gate | Auto-heal route |
| --- | --- |
| 1a Build (compile error) | `/approved` — fix in place (a TDD red) |
| 1b Tests (failing test) | trace the failure to its slice → `/approved` → re-run 1b |
| 1c Coverage < floor | `/qa` on the files 1c already listed as below floor → add tests → re-run 1c |
| 1d-i Deps CVE (critical/high) | bump/replace the package in place; if unfixable here, log it — the Sonar dep-risk gate at push is the backstop |
| 1e Migration unpaired | write the missing `.down.sql` via `/approved` → re-run 1e |
| 1f SonarQube FAILED | `/sonarqube:sonar-list-issues` → `/sonarqube:sonar-fix-issue` per issue → re-analyze → re-run 1f |
| 1d-ii **Secret in diff** | **Never auto-continue a real credential.** A placeholder / test / dummy value → scrub to an env var and continue. A value that looks like a live secret → **hard-stop** (`BLOCKED: DoD/secret`): an agent can't rotate a leaked credential or scrub history, and must never route it through chat. This is the one gate that stops even under `--heal`. |

**3-strike honesty backstop (same as `/build`'s loop guard).** If the *same* gate fails the *same* way ~3 times, stop healing it. Do **not** weaken the test, suppress the finding, or converge. Emit one line and end:

```
BLOCKED: DoD/<gate> — <reason> (survived 3 heal attempts)
```

A surviving `BLOCKED:` means Phases 2–6 do **not** run — the work is genuinely not done. Never fake-green a DoD gate to reach a clean tree.

---

## Phase 1 — Definition of Done gate

Run all checks. **Any failure = STOP** (default mode) — or, under `--heal`, **route per the Autonomous heal mode section above and re-run the gate** instead of stopping (a real secret in 1d-ii always stops). Do not proceed to Phase 2 until every gate is green.

### 1a: Build

**Go:**
```bash
go build ./...
```

**Node/TypeScript:**
```bash
npx tsc --noEmit 2>&1
```

**Python:**
```bash
python -m py_compile $(find . -name "*.py" -not -path "*/.*" | head -20) 2>&1
```

**Result:** `BUILD: ✅ PASS` or `BUILD: ❌ FAIL — [error output]`. On FAIL → stop.

---

### 1b: Tests

Run the full test suite (not just the changed files):

**Go:**
```bash
go test ./... -count=1 -timeout 120s 2>&1
```

**Vitest/Jest:**
```bash
npx vitest run 2>&1 || npx jest --ci 2>&1
```

**pytest:**
```bash
python -m pytest -x -q 2>&1
```

**Result:** `TESTS: ✅ N passed` or `TESTS: ❌ N failed — [test names]`. On FAIL → stop.

---

### 1c: Coverage gate (≥80%, non-negotiable)

**The floor is 80% and cannot be lowered.** `COVERAGE_MIN` may only RAISE it. Clamped:

```bash
MIN=${COVERAGE_MIN:-80}; case "$MIN" in ''|*[!0-9]*) MIN=80;; *) [ "$MIN" -lt 80 ] && MIN=80;; esac
```

Run coverage and parse the total:

| Stack | Command |
|-------|---------|
| Vitest | `npx vitest run --coverage --coverage.reporter=json-summary` → `coverage/coverage-summary.json` |
| Jest | `npx jest --coverage --coverageReporters=json-summary` → `coverage/coverage-summary.json` |
| Go | `go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out` → `total:` line |
| pytest | `pytest --cov --cov-report=term --cov-fail-under=$MIN` |

```bash
# Node (parse json-summary)
PCT=$(python3 -c "import json;print(json.load(open('coverage/coverage-summary.json'))['total']['lines']['pct'])" 2>/dev/null)
# Go (parse total: line)
PCT=$(go tool cover -func=coverage.out 2>/dev/null | grep '^total:' | awk '{print $3}' | tr -d '%')
```

```bash
awk "BEGIN{exit !($PCT>$MIN)}" && echo "COVERAGE: ✅ ${PCT}% >= ${MIN}%" \
  || echo "COVERAGE: ❌ FAIL ${PCT}% < ${MIN}% — add tests before wrapping"
```

**Also gate changed files** (mirrors SonarQube new-code model):
```bash
BASE=$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD~1)
git diff --name-only "$BASE"...HEAD -- '*.ts' '*.tsx' '*.js' '*.go' '*.py' | grep -vE '\.test\.|_test\.|\.spec\.'
# For each changed file: read its coverage % from coverage-summary.json; fail if < MIN
```

**Result:** `COVERAGE: ✅ 84.3%` or `COVERAGE: ❌ 71.2% — files below floor: [list]`. On FAIL → stop.

No coverage tooling found → `COVERAGE: ⚠️ BLOCKED — no coverage tooling detected (install @vitest/coverage-v8, pytest-cov, etc.)`. Warn; do NOT silently pass.

---

### 1d: Security scan

**1d-i: Dependency vulnerabilities**

Do NOT block on medium/low — only critical/high block the wrap:

**Node:**
```bash
npm audit --audit-level=high --json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
vulns=d.get('vulnerabilities',{})
critical=[k for k,v in vulns.items() if v.get('severity') in ('critical','high')]
print('VULN_CRITICAL:',len(critical), critical[:3] if critical else '')
"
```

**Go:**
```bash
which govulncheck >/dev/null 2>&1 && govulncheck ./... 2>&1 | grep -E "^Vulnerability|^  ID:|^  Fixed" | head -20 \
  || echo "govulncheck not installed — skip (install: go install golang.org/x/vuln/cmd/govulncheck@latest)"
```

**Python:**
```bash
which pip-audit >/dev/null 2>&1 && pip-audit --format=json 2>/dev/null | python3 -c "
import json,sys
vulns=json.load(sys.stdin)
critical=[v for v in vulns if v.get('fix_versions')]
print('VULNERABLE_PACKAGES:',len(critical))
" || echo "pip-audit not installed — skip (install: pip install pip-audit)"
```

**Result:** `SECURITY/DEPS: ✅ 0 critical` or `SECURITY/DEPS: ❌ N critical/high — [package names]`. Critical/high → stop.

**1d-ii: Secrets scan** (grep the diff, not the whole repo)

```bash
BASE=$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD~1)
git diff "$BASE"..HEAD -- . ':(exclude)*.lock' ':(exclude)package-lock.json' | \
  grep '^+' | \
  grep -iE "(api_key|api_secret|secret_key|access_token|refresh_token|private_key|password|passwd|auth_token|bearer)\s*[=:]\s*['\"][A-Za-z0-9_\-]{8,}" | \
  grep -vE "(example|placeholder|your_|<|>|TODO|FIXME|test_key|fake|dummy)" | head -5
```

**Result:** `SECURITY/SECRETS: ✅ None found in diff` or `SECURITY/SECRETS: ❌ Potential secret in [file:line]`. On finding → stop. (The secrets hook is right — don't route around it.)

---

### 1e: Migration integrity

If `db/migrations/` (or `migrations/`) exists:

```bash
MIGRATIONS_DIR=""
[ -d "$(pwd)/db/migrations" ] && MIGRATIONS_DIR="$(pwd)/db/migrations"
[ -d "$(pwd)/migrations" ] && MIGRATIONS_DIR="$(pwd)/migrations"

if [ -n "$MIGRATIONS_DIR" ]; then
  ls "$MIGRATIONS_DIR"/*.up.sql 2>/dev/null | while read up; do
    down="${up%.up.sql}.down.sql"
    [ -f "$down" ] || echo "UNPAIRED: $up (missing $down)"
  done
fi
```

**Result:** `MIGRATIONS: ✅ All paired` or `MIGRATIONS: ❌ Unpaired: [files]`. On FAIL → stop.

---

### 1f: SonarQube quality gate (if configured)

Only if `sonar-project.properties` or `SONAR_TOKEN` env var exists:

```bash
[ -f "sonar-project.properties" ] || [ -n "$SONAR_TOKEN" ] && echo "SONAR_CONFIGURED=true" || echo "SONAR_CONFIGURED=false"
```

If configured: run `/sonarqube:sonar-quality-gate`. If gate is NOT PASSED → stop.

If not configured: `SONAR: ⏭ SKIPPED (not configured)` — this is fine; the pre-push hook will catch it on push.

---

### 1g: DoD gate verdict

Print a summary table before proceeding:

```
--- DEFINITION OF DONE GATE ---
  Build:          ✅ PASS  /  ❌ FAIL
  Tests:          ✅ N passed  /  ❌ N failed
  Coverage:       ✅ 84.3% >= 80%  /  ❌ 71.2% < 80%
  Security/Deps:  ✅ 0 critical  /  ❌ N critical
  Security/Secrets: ✅ None found  /  ❌ Found in [file]
  Migrations:     ✅ All paired  /  ⏭ No migrations dir
  SonarQube:      ✅ PASSED  /  ❌ FAILED  /  ⏭ Not configured
---
DoD: ✅ ALL PASS — proceeding to git cleanup
  — or —
DoD: ❌ BLOCKED — [N] gate(s) failed. Fix before wrapping:
  > [exact command to fix gate 1]
  > [exact command to fix gate 2]
```

If ANY gate fails → **stop here**. Do not touch git.

---

## Phase 2 — Commit all WIP

For the primary checkout **and every dirty worktree**, run with `git -C <worktree-path>`:

```bash
git -C "$WT" status --porcelain   # nothing? skip this tree
git -C "$WT" diff --stat
```

### 2a: Topology & invariant drift (runs on the work about to be committed)

Refresh `docs/project-context.md` only when this commit could have changed the system's **shape** — a
new deployable, a new cross-process edge, or a new invariant. Two scans, because the two cases have
different evidence:

**Scan A — new files (path-based).** New topology arrives as new files, and a new file is *untracked*,
so `git diff` cannot see it. List new files from both sources:

```bash
NEWF=$( { git -C "$WT" diff HEAD --name-only --diff-filter=A; \
          git -C "$WT" ls-files --others --exclude-standard; } | sort -u )
printf '%s\n' "$NEWF" | grep -cE '(^|/)(Dockerfile|Procfile|[^/]*\.tf|docker-compose[^/]*\.ya?ml|fly\.toml|Chart\.yaml)$|(^|/)(main|server|worker|app)\.(go|py|ts|js|rb)$|(^|/)cmd/[^/]+/main\.go$'
```

**Scan B — edits to existing files (content-based).** Only *registration*, *messaging*, *DDL* and
*auth-guard* shapes count. **Case-sensitive, `+++` headers stripped, `*.md` excluded, call-shape
anchored** — an unanchored `grep -i` for bare words fires on `check(`, `unique(`, `router.push`,
`npm publish` and the word "Subscribe" in prose, which would rewrite the file on nearly every commit;
and prose *describing* a route or a constraint is not a route or a constraint, so documentation is out
of scope by construction:

```bash
git -C "$WT" diff HEAD -U0 -- . ':(exclude)*.md' | grep -E '^\+' | grep -vE '^\+\+\+' | grep -cE \
 '\.(Publish|Subscribe|publish|subscribe|emit|consume|basicConsume)\(|(router|app|mux|r|srv)\.(Get|Post|Put|Patch|Delete|Handle|HandleFunc|get|post|put|patch|delete)\(|@(app|router)\.(get|post|put|patch|delete|route)\(|@(Get|Post|Put|Delete|Request)Mapping|ADD CONSTRAINT|CREATE UNIQUE INDEX|FOREIGN KEY|REFERENCES [A-Za-z_]+ ?\(|BEGIN TRANSACTION|\.Transaction\(|@Transactional|@UseGuards|require_role|login_required|requireAuth\('
```

Scan A's new files also get the **broad** edge check (a brand-new module's every outbound call is new
topology): `grep -lE 'fetch\(|axios\.|http\.(Get|Post)|requests\.|httpx\.' -- $NEWF`.

**Then:**

- **Both scans 0 → skip silently.** Print `Topology: ⏭ no boundary/invariant change`. This is the
  common case; the file is **not** touched on an ordinary commit.
- **Any hit → open `$WT/docs/project-context.md` and reconcile it.** A hit means *look*, not *rewrite*:
  if the file already describes the deployable/edge/invariant the scan found, print
  `Topology: ✓ already current` and change nothing. Edit only when something is genuinely missing or
  wrong — the Topology / Invariants / Deliberate non-goals sections and the `Last verified:` stamp —
  then stage it with the commit below. This is what keeps a false-positive cheap: one read, not a
  spurious diff.
- **Absent file → create it** from the contract's skeleton, at `$WT/docs/project-context.md`.
- **Off-contract file (predates 0.25.0)** → not an error. **Restructure it to the contract's three
  sections**: keep every topology/invariant/non-goal claim it already makes, drop the rest (business
  narrative, architecture overview, per-file notes). This is the one case where editing outside the
  three sections is correct, because the sections do not exist yet.
- **Enforce the ceiling you just wrote against** — `[ "$(wc -l < "$WT/docs/project-context.md")" -le 100 ]`;
  over 100 lines means derivable content crept in, so cut before staging.

Never restate anything derivable — god nodes, communities, module LOC and architecture tier belong to
`graphify-out/GRAPH_REPORT.md` and `/saki-builder:arch-check`. Contract (scope · banned list · skeleton ·
ceiling): `${CLAUDE_PLUGIN_ROOT}/config/docs/project-context-contract.md`.

Two known gaps, stated rather than silently missed: an outbound HTTP call added to an *existing* module
(too common to gate on — Scan B ignores `fetch(`/`axios.`), and a new edge introduced only through
config. Note either by hand when you know about it.

This never gates: a doc that cannot be written is reported, not a reason to abandon a converged tree.
Content 2a writes is staged **after** the Phase-1d secret scan, so it is out of that gate's scope —
keep it to prose and `path:line` citations, never a credential or a connection string.

Then:
- **Stage explicit paths** from `git status --porcelain` — never `git add -A` in a shared tree
- **Entanglement guard:** any file already `M` at session start that you did not author → **safe-stop** instead of sweeping it in
- **Conflict-marker hygiene:** `grep -rnE '^(<{7}|={7}|>{7})' <touched-files>` — never commit live markers
- Commit with a clear message. No force, no amend of pushed commits.

---

## Phase 3 — Land each branch and push

Push **every checkout that has commits to land** — this is the fix for the most common case: a
feature branch created **in place** (`/build`'s `git checkout -b feature/<x>`, no worktree). Build the
push list:

- The **primary checkout** when its current branch `B` is **not** the default branch and has unpushed
  commits (`git rev-list origin/$B..$B` non-empty, or `origin/$B` doesn't exist yet). **Do not skip
  this** — Phase 5 is about to switch it to main, so an unpushed feature branch here would be stranded.
- **Plus** each **linked worktree** on its branch `B`.

For each such checkout directory `DIR` (`$PRIMARY` or `$WT`) on branch `B`:

**3a. Decide the target.** Default: push `B` as-is (the MR merges it into main). Only do a local merge when a clearly identified parent branch `P` is checked out in the primary checkout.

**3b. Merge (only when parent `P` is clear):**
```bash
git -C "$PRIMARY" checkout "$P"
git -C "$PRIMARY" merge --no-ff "$B"
grep -rnE '^(<{7}|={7}|>{7})' .   # any conflict markers → SAFE-STOP
```

**3c. Push:**
```bash
git -C "$DIR" push -u origin "$B"     # $DIR = $PRIMARY (in-place feature branch) or $WT (worktree)
```

- Pushing a **feature branch** is fine. The `sonar-gate.sh` PreToolUse hook only blocks pushes to **main**. If pushing **main**, the gate fires — respect it.
- Push rejected (remote moved)? No file overlap → `git pull --rebase && push`. Overlap → **safe-stop**. Never force-push the default branch.
- Verify after: `git -C "$DIR" rev-list origin/$B..$B` must be empty.

---

## Phase 4 — Remove the worktrees

Only removable once clean (Phase 2) AND pushed (Phase 3). If standing inside a worktree you're about to remove, `cd "$PRIMARY"` first.

```bash
cd "$PRIMARY"
# Drop symlinked deps BEFORE removal (so cleanup doesn't follow them into the real tree):
# rm -f "$WT/node_modules"   ← only if it's a symlink
git worktree remove "$WT"   # refuses if dirty → means Phase 2 missed something → SAFE-STOP
git worktree prune
```

---

## Phase 5 — Switch the primary checkout to main and sync

Only now, with every gate passed + every worktree clean+pushed+removed:

```bash
cd "$PRIMARY"
DEFAULT="<default branch from Phase 0>"
git checkout "$DEFAULT"              # refuses on local changes → uncommitted work remains → SAFE-STOP
git pull --ff-only origin "$DEFAULT" || git pull --rebase origin "$DEFAULT"
git branch --merged origin/"$DEFAULT" | grep -vE "^\*|\b$DEFAULT\b"  # merged branches → safe to prune locally
```

Prune only **local** branches already merged into `origin/<default>`. Leave remote branches alone. Never delete a branch whose MR is still open.

---

## Phase 6 — Final report

**Resume manifest (best-effort):** if a manual-chain manifest exists (the newest `tasks/.<slug>-state.json`
carrying a top-level `steps` object — not `/saki-builder:build`'s `.build-*`), stamp `wrap=done`, the
terminal marker, using the `/wrap` manifest-resolution + stamp snippet in
`${CLAUDE_PLUGIN_ROOT}/config/docs/manual-chain-resume.md`. Absent or error → skip silently; it never
affects convergence.

```
--- WRAP COMPLETE ---

Definition of Done:
  ✓ Build:       PASS
  ✓ Tests:       N passed
  ✓ Coverage:    84.3% (floor 80%)
  ✓ Security:    0 critical deps, 0 secrets in diff
  ✓ Migrations:  All paired (or: No migration dir)
  ✓ SonarQube:   PASSED (or: Not configured)

Git cleanup:
  ✓ Topology:    [⏭ no boundary/invariant change | ✓ already current | updated docs/project-context.md]
  ✓ Committed:   [N commits across M trees, or "nothing to commit"]
  ✓ Pushed:      [branch → origin/branch, ahead 0]
  ✓ Worktrees:   [removed: <paths>, or "none"]
  ✓ On:          [default branch] (up to date with origin, tree clean)

Left intentionally:  [branch kept because MR still open, or "nothing"]
```

If any invariant is NOT met, replace with the **Safe-stop** for the blocker.

---

## Safe-stops

*(Under `--heal`, the DoD-gate rows below are auto-healed and re-run instead of stopping — except **Secret found in diff**, which always stops. All non-DoD rows apply in both modes.)*

| Situation | Action |
| --- | --- |
| Any DoD gate fails | Stop before Phase 2. Report gate + exact fix command. |
| Build fails | Stop. Show compiler error. |
| Test failures | Stop. List failing test names and errors. |
| Coverage below floor | Stop. List files below floor + uncovered line ranges. |
| Critical dependency vulnerability | Stop. Show `npm audit fix` or the exact package to update. |
| Secret found in diff | Stop. Name the file and line. Never route it through chat. |
| Unpaired migration | Stop. Name the missing .down.sql file. |
| SonarQube gate FAILED | Stop. Run `/sonarqube:sonar-quality-gate` to see conditions. |
| Merge conflict markers | Stop. List conflicting files. Never blind-`git add`. |
| Push to main, sonar gate not PASSED | Stop. Fix, re-run analysis. Do not bypass. |
| Push rejected with file overlap | Stop. Show incoming vs local. Never force-push main. |
| Dirty file from another session | Stop. List paths. Do not sweep into your commit. |
| `git worktree remove` refuses | Stop. Phase 2 missed something — surface it. |
| Detached HEAD in a worktree | Stop. Show commit + how to attach to a branch. |
| No `origin` remote | Skip push/prune; still run DoD, commit, remove worktrees, switch to main. |

---

## Rules

- **DoD gate is a hard pre-condition.** Not a warning, not a suggestion. A failing gate means the work is not done.
- **Order is law:** DoD gate → commit → push → remove worktrees → switch to main.
- **Stage explicit paths.** Never `git add -A` or `git add .` in a shared tree.
- **2a never gates.** It is a Phase-2 action, not a DoD gate — `Order is law` (DoD → commit → push) is unchanged. It writes `docs/project-context.md` only when the diff carries a topology or invariant signal; 0 signals means 0 writes.
- **Verify against `origin/<branch>` after `git fetch`**, not the local checkout.
- **Grep for conflict markers** after any merge.
- **No force-push of the default branch.**
- If the repo is already clean and on main, all DoD gates pass, and no worktrees exist → "already clean — nothing to do."
- **`--heal` changes only Phase 1's failure behavior** (auto-fix + re-run instead of stop), never the gates themselves nor the Phase 2–6 convergence. A real secret (1d-ii) and the 3-strike backstop still hard-stop.
