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

## Step 2: Detect reviewer agent

Check if a project-specific reviewer agent exists:
```bash
ls .claude/agents/reviewer.md 2>/dev/null && echo "PROJECT" || echo "GLOBAL"
```

- **PROJECT** → use `.claude/agents/reviewer.md` as the review checklist (project-specific rules)
- **GLOBAL** → use the standard checklist below

## Step 3: Launch review

Use the Agent tool to launch a fresh-context reviewer with:
- The full git diff from Step 1
- The changed file paths
- The checklist from Step 2 (project-specific or global)

Agent prompt:
```
You are a thorough code reviewer operating in a fresh context — no implementation history.

Review the COMMITTED diff and changed files between [BASE] and HEAD. Apply the checklist strictly.
Flag every issue with severity: HIGH (blocks commit) / MED (should fix) / LOW (suggestion).

IMPORTANT: Review only what's in the committed diff. If you read a file to check context,
verify any claim against `git show <BASE>:<path>` and `git show HEAD:<path>` — do NOT cite
declarations from the working tree (uncommitted changes on unrelated files can include
WIP additions that mislead a review). When verifying schema-level invariants (UNIQUE constraints,
CHECK constraints, FKs, model fields), check both the model definition AT HEAD and the most
recent migration that creates the table — divergence between them is a reportable finding.

[If project reviewer exists: paste contents of .claude/agents/reviewer.md checklist]
[If global: use the Standard Review Checklist below]

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
- [ ] No secrets or credentials hardcoded
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

## Rules

- Never skip reading the diff — review without diff context is useless
- HIGH issues block the commit — do not suggest committing with unresolved HIGHs
- Be specific: file path + line number for every issue, not "check the handler"
- Distinguish blockers from suggestions — LOW items are never blockers
