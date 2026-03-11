# Git Thinking

**Process:** Understand state → Plan action → Execute safely → Verify result

## Branching Strategy

| Branch | Purpose | Base |
|--------|---------|------|
| `main` | Production-ready code | - |
| `feature/*` | New features | `main` |
| `fix/*` | Bug fixes | `main` |
| `hotfix/*` | Urgent production fixes | `main` |

**Rules:**
- Always branch from latest `main`
- Keep branches short-lived; merge frequently
- Delete branches after merge

## Commit Conventions

**Format:** `<type>: <description>`

| Type | Use |
|------|-----|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code restructure, no behavior change |
| `docs` | Documentation only |
| `chore` | Build, CI, dependencies |
| `test` | Adding or fixing tests |

**Rules:**
- One logical change per commit
- Write in imperative mood ("Add feature" not "Added feature")
- Keep subject under 72 characters
- Add body for non-obvious changes

## PR Workflow

1. Create feature branch from `main`
2. Make focused commits
3. Push with `-u` flag: `git push -u origin feature/my-branch`
4. Create PR via `gh pr create`
5. After approval, merge (prefer squash for feature branches)

## Safe Operations

**Before destructive actions, always:**
1. Check `git status` and `git stash list`
2. Confirm with user before `--force`, `--hard`, or delete operations
3. Prefer `git stash` over discarding changes

**Prefer safe alternatives:**
| Risky | Safer |
|-------|-------|
| `git reset --hard` | `git stash` then reset |
| `git push --force` | `git push --force-with-lease` |
| `git checkout .` | `git stash` |
| `git branch -D` | `git branch -d` (checks merge status) |
| `git clean -f` | `git clean -n` (dry run first) |

## Troubleshooting

### Merge Conflicts
1. `git status` to identify conflicted files
2. Read conflicted files, understand both sides
3. Resolve manually (don't blindly accept one side)
4. `git add <resolved-files>` then `git commit`

### Undo Last Commit (not pushed)
- Keep changes: `git reset --soft HEAD~1`
- Discard changes: `git reset --hard HEAD~1` (confirm with user first)

### Recover Deleted Branch/Commit
- `git reflog` to find the commit hash
- `git checkout -b recovery-branch <hash>`

### Alembic Migration Conflicts (project-specific)
- Multiple heads: `alembic merge -m "merge heads" <rev1> <rev2>`
- DB ahead of tracking: `alembic stamp <revision>` to mark as applied
- Check state: `alembic current` and `alembic heads`

### Stash Operations
- Save: `git stash push -m "description"`
- List: `git stash list`
- Apply + keep: `git stash apply stash@{0}`
- Apply + remove: `git stash pop`

### Rebase onto Updated Main
```
git fetch origin
git rebase origin/main
# Resolve conflicts if any, then: git rebase --continue
```

## Pre-Flight Checklist

Before any git operation, verify:
- [ ] Current branch (`git branch --show-current`)
- [ ] Working tree status (`git status`)
- [ ] No uncommitted work that could be lost
- [ ] On correct base branch for the operation
