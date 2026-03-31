---
name: reviewer
description: Launch a fresh-context code reviewer after implementing a feature or fixing a bug. Reads git diff, detects project-specific reviewer agent, reports issues with severity. Run before committing.
---

# Code Review

Launch a fresh-context review of all changes since the last commit.

## Step 1: Collect what changed

```bash
git diff HEAD --stat
git diff HEAD
```

If no uncommitted changes, check the last commit:
```bash
git diff HEAD~1 HEAD --stat
git diff HEAD~1 HEAD
```

List changed files:
```bash
git diff HEAD --name-only
```

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

Review the following diff and changed files. Apply the checklist strictly.
Flag every issue with severity: HIGH (blocks commit) / MED (should fix) / LOW (suggestion).

[If project reviewer exists: paste contents of .claude/agents/reviewer.md checklist]
[If global: use the Standard Review Checklist below]

Changed files: [list from Step 1]

Diff:
[paste full git diff]

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
