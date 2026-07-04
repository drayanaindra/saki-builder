---
name: reviewer
description: Launch a fresh-context code reviewer after implementing a feature or fixing a bug. Reads git diff, detects project-specific reviewer agent, reports issues with severity. Run before committing.
---

# Code Review

Launch a fresh-context review of all changes since the last commit.

## Step 1: Collect what changed

**Brief the reviewer with the COMMITTED diff only — never the working tree.** Uncommitted changes on unrelated files (someone else's WIP that drifted into the working tree) can mislead the reviewer into citing constraints/fields/imports that won't exist in production. Always pin a base ref and diff against it.

```bash
# Pick a base. Prefer the merge-base with the integration branch when reviewing a feature branch:
BASE="$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || echo HEAD~1)"
echo "Base: $BASE"

git diff "$BASE..HEAD" --stat
git diff "$BASE..HEAD"
git diff "$BASE..HEAD" --name-only
```

If reviewing uncommitted changes intentionally (e.g. pre-commit local review), use `HEAD` and warn the reviewer in the prompt: *"NOTE: this diff is uncommitted-vs-HEAD; treat working-tree state as the diff itself, not as the source of truth for unrelated files."*

## Step 1.5: Secret scan (BLOCKING — runs before the LLM review)

An LLM reviewer misses hardcoded credentials often enough that this must be a **deterministic gate**,
not a checklist item. Scan the **added lines only** (`^+`, never `+++` headers) of the committed diff
for credential patterns. This runs first because a leaked secret is a HIGH that blocks the commit
regardless of what the rest of the review finds.

**Never print a matched secret value into chat** (it would land in history/transcripts — see the
Secrets rule in CLAUDE.md). Report only `file:line` + which rule matched. If a real secret is found,
the fix is: remove it, move to an env var / secret manager, AND rotate it (committing = compromised,
even if unpushed and later amended — assume it leaked).

```bash
BASE="$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD origin/main 2>/dev/null || echo HEAD~1)"

# Added lines only, scanned against high-signal credential patterns. Map any hit back to its
# file:line via the full diff from Step 1 (grep here shows the offending line, not its number).
git diff "$BASE..HEAD" -U0 \
| grep -E '^\+' \
| grep -vE '^\+\+\+' \
| grep -EiC0 \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'ASIA[0-9A-Z]{16}' \
    -e 'gh[pousr]_[A-Za-z0-9]{30,}' \
    -e 'xox[baprs]-[A-Za-z0-9-]{10,}' \
    -e 'AIza[0-9A-Za-z_-]{35}' \
    -e 'sk-(ant-)?[A-Za-z0-9_-]{20,}' \
    -e 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}' \
    -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' \
    -e '(api[_-]?key|secret|access[_-]?key|client[_-]?secret|auth[_-]?token|password|passwd|pwd)["'"'"']?\s*[:=]\s*["'"'"'][^"'"'"']{8,}' \
  && echo "SECRETS: POSSIBLE MATCH — inspect above (do NOT paste the value into chat)" \
  || echo "SECRETS: clean"
```

Triage each hit — a match is a **finding only if the value is a real live credential**. Discard as
false positives (do NOT block on these):
- `process.env.X`, `os.environ[...]`, `os.getenv(...)`, `config.get(...)` — references, not literals.
- Obvious placeholders: `<your-token>`, `xxx`, `changeme`, `example`, `dummy`, `test`, `redacted`,
  `${...}` interpolation, all-zeros/all-`x` strings.
- Files that are meant to hold placeholders: `.env.example`, `*.sample`, fixtures/snapshots with
  clearly fake values, docs showing the *shape* of a token.

Anything left after triage is a **HIGH** and blocks the commit. Pass the surviving hits into the
Step 3 review prompt as pre-found HIGH findings (by `file:line` + rule, never the value) so the
reviewer's verdict already reflects them.

## Step 2: Detect reviewer agent

Check if a project-specific reviewer agent exists:
```bash
ls .claude/agents/reviewer.md 2>/dev/null && echo "PROJECT" || echo "GLOBAL"
```

- **PROJECT** → use `.claude/agents/reviewer.md` as the review checklist (project-specific rules)
- **GLOBAL** → use the standard checklist below

## Step 2.5: Load house review patterns (learned gotchas)

The saki-builder patterns accumulate bug classes **caught by past reviews** — many entries are
literally tagged *"caught by fresh-context reviewer"* or *"only in adversarial review"*. A
fresh-context reviewer cannot see them otherwise (it doesn't inherit the main thread's context), so
load the relevant ones and pass them into the prompt. This is the highest-signal input available: a
list of mistakes this team has already made. Read BOTH layers: the **team baseline**
(`${CLAUDE_PLUGIN_ROOT}/memory/patterns.md` + `patterns-<topic>.md`) and your **personal overlay**
(`~/.claude/memory/patterns-personal.md`).

```bash
for f in "${CLAUDE_PLUGIN_ROOT}/memory/patterns.md" "$HOME/.claude/memory/patterns-personal.md"; do
  test -f "$f" && echo "PATTERNS: $f present" || echo "PATTERNS: $f none"
done
```

If present, read it and **select only the entries that match this diff** (keep the prompt lean — do
NOT paste the whole file):
- Always include the stack-agnostic sections: **Code Quality**, **Debugging**.
- Include a stack section only if the changed files use it (infer from extensions in the Step 1
  `--name-only` list): `.go` → **Go**; `.tsx/.ts/.jsx` → **React Patterns** / **React / Frontend
  Architecture** / **Async UI / React** / **Next.js App Router**; `.py` → **Python / API** /
  **Python Async**; prompt/LLM files → **AI / LLM Integration**.
- Skip the `patterns-<topic>.md` topic files and any unrelated stacks.

If the file is absent (e.g. a project where saki-builder isn't installed), skip silently — the
checklist from Step 2 still applies.

## Step 3: Launch review

Use the Agent tool to launch a fresh-context reviewer with:
- The full git diff from Step 1
- The changed file paths
- Any surviving secret-scan hits from Step 1.5 (as pre-found HIGH findings — `file:line` + rule, never the value)
- The checklist from Step 2 (project-specific or global)
- The selected house review patterns from Step 2.5 (if `patterns.md` exists)

Agent prompt:
```
You are a thorough code reviewer operating in a fresh context — no implementation history.

Review the COMMITTED diff and changed files between [BASE] and HEAD. Apply the checklist strictly.
Flag every issue with severity: HIGH (blocks commit) / MED (should fix) / LOW (suggestion).

A deterministic secret scan already ran on this diff. Pre-found credential hits (if any) are listed
below as HIGH — carry them into your Issues list. Independently, re-scan every ADDED line for any
hardcoded credential the regex pass could have missed (bearer tokens, connection strings with inline
passwords, base64'd creds, high-entropy literals assigned to secret-ish names). Any live credential
committed to the repo is a HIGH — do NOT reproduce the secret value in your output; cite file:line
and the kind of secret only.

Pre-found secret hits: [list from Step 1.5, or "none"]

IMPORTANT: Review only what's in the committed diff. If you read a file to check context,
verify any claim against `git show <BASE>:<path>` and `git show HEAD:<path>` — do NOT cite
declarations from the working tree (uncommitted changes on unrelated files can include
WIP additions that mislead a review). When verifying schema-level invariants (UNIQUE constraints,
CHECK constraints, FKs, model fields), check both the model definition AT HEAD and the most
recent migration that creates the table — divergence between them is a reportable finding.

[If project reviewer exists: paste contents of .claude/agents/reviewer.md checklist]
[If global: use the Standard Review Checklist below]

[If patterns.md present (Step 2.5): paste the SELECTED house patterns under this header —]
House review patterns (learned from past reviews on this team's code — check the diff against
EACH one; these are real bug classes already hit here, not hypotheticals):
[selected entries from Step 2.5 — verbatim, e.g. pgx rows.Err(), tx.Commit() wrapping, Go json
tags, useMutation pre-mutation snapshot, concurrent cap-bypass, test-doubles-don't-prove-DB-behavior]

Changed files: [list from Step 1]

Diff:
[paste full git diff from BASE..HEAD]

Output format:
REVIEW COMPLETE

Files reviewed: [N]
Passed: [N] checks
Issues found: [N]

Issues:
  HIGH: [description] — [file:line]
  MED:  [description] — [file:line]
  LOW:  [description] — [file:line]

Verdict: APPROVE / REQUEST CHANGES
Reason: [one line]
```

## Standard Review Checklist (global fallback)

Used when no `.claude/agents/reviewer.md` exists.

**Correctness**
- [ ] Solves the stated problem — no off-by-one, no wrong condition
- [ ] Edge cases handled: empty input, null, zero, max values
- [ ] No logic copied from the wrong branch/version

**Security**
- [ ] No secrets or credentials hardcoded (API keys, tokens, JWTs, passwords, private keys,
      connection strings with inline passwords) — verified by the Step 1.5 secret scan AND a manual
      re-scan of added lines. Any live credential in the diff is a HIGH.
- [ ] Secrets sourced from env vars / secret manager, not literals; `.env`-style files gitignored
- [ ] User input validated before use
- [ ] No SQL string interpolation (use parameterized queries)
- [ ] Auth checks present on every protected route/function

**Performance**
- [ ] No N+1 query patterns
- [ ] No unnecessary loops over large datasets
- [ ] No blocking call in an async context

**Patterns**
- [ ] Follows existing codebase conventions (naming, structure, error handling)
- [ ] No dead code added
- [ ] No commented-out code left in

**Tests**
- [ ] Happy path covered
- [ ] At least one failure/edge case covered
- [ ] Tests assert behavior, not implementation details

## Step 4: Act on verdict

- **APPROVE** → suggest commit: `/commit` or `git commit`
- **REQUEST CHANGES** → list HIGH items, fix before committing
- **Any surviving secret-scan hit → automatic REQUEST CHANGES.** Remove the credential, move it to an
  env var / secret manager, and rotate it (assume it leaked the moment it was committed) before commit.

## Rules

- Never skip reading the diff — review without diff context is useless
- Never skip the Step 1.5 secret scan — it is a BLOCKING gate; a hardcoded credential is always a HIGH
- Never print a matched secret value into chat/output — cite `file:line` + rule only (CLAUDE.md Secrets rule)
- Load house review patterns (Step 2.5) when `patterns.md` exists — they encode bug classes already
  caught here, and a fresh-context reviewer is blind to them otherwise. Select by stack; never paste
  the whole file.
- HIGH issues block the commit — do not suggest committing with unresolved HIGHs
- Be specific: file path + line number for every issue, not "check the handler"
- Distinguish blockers from suggestions — LOW items are never blockers
