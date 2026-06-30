---
name: wrap
description: Converge the repo to a clean terminal state after work is done (MR green / merged) — no work left behind. Commits all WIP, lands each worktree's branch and pushes it, removes the worktree, then switches the primary checkout to an up-to-date main with a clean tree. Fully autonomous including push; safe-stops on conflicts/ambiguity. Run as the LAST step of any task. Usage — /wrap
---

# Wrap — converge to clean, leave nothing behind

You run this when a unit of work is **done** (the MR is green / merged, or the change is finished and
verified). Your single job is to drive the repository to a clean terminal state so nothing is
stranded in a worktree, uncommitted, or unpushed. This is the strict "clean as you finish" rule.

## The invariant you must reach (the whole point)

After `/wrap` returns success, ALL of these hold — verify each before reporting done:

1. **No uncommitted work** anywhere — `git status --porcelain` is empty in the primary checkout and in every worktree you touched.
2. **No stranded commits** — every branch that had work is pushed; `git rev-list origin/<branch>..<branch>` is empty for each.
3. **No leftover worktrees** — `git worktree list` shows only the primary checkout (unless a worktree was intentionally kept; say so explicitly).
4. **Primary checkout is on `main`** (or the repo default branch), up to date with `origin`, clean tree.

If you cannot reach all four, you do **not** report success — you stop at the blocker and report it (see **Safe-stops**). Order matters: **switching to main is the LAST step**, gated on 1–3 being true. Never switch to main while a worktree is still dirty — that strands the work.

---

## Step 0 — Snapshot & detect context

Pin reality before changing anything. Run from the repo:

```bash
PRIMARY="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"   # first = primary checkout
echo "Primary checkout: $PRIMARY"
git worktree list                          # all worktrees + their branches
git rev-parse --abbrev-ref HEAD            # current branch (or HEAD if detached)
git status --porcelain                     # current tree dirty?
git remote -v | head -1                    # is there an origin to push to?
git fetch origin --prune                   # make push-state checks REAL, not local-lagged
```

Record: the **primary checkout** path, the **default branch** (`git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`, fallback `main` then `master`), every **linked worktree** (path + branch), and which trees are **dirty**. If there is no `origin`, skip all push steps and say so — you can still commit, merge locally, remove worktrees, and switch to main.

> **Trust `origin/<branch>` after the fetch, never the local checkout or a board** — multi-machine/agent repos lag. (patterns.md, git-state)

---

## Step 1 — Confirm "done" (light gate, don't re-litigate)

You were invoked because the work is finished, so trust that — but do a cheap sanity pass:

- If `glab`/`gh` is available and the current branch has an open MR/PR, surface its state for context:
  `glab mr view 2>/dev/null` or `gh pr view 2>/dev/null`. **If the MR is NOT yet merged, still push (so the MR is current) but do NOT delete the branch** — it's live in review.
- Do not run the full test/quality suite here; that's QA's job and the MR already gated it. Only stop if you can see the tree is obviously broken (conflict markers from an earlier merge — Step 2 catches them).

---

## Step 2 — Commit all WIP (no work left behind)

For the primary checkout **and every dirty worktree**, commit what's there. Per worktree, run with
`git -C <worktree-path>`:

```bash
git -C "$WT" status --porcelain      # nothing? skip this tree
git -C "$WT" diff --stat
```

Then:

- **Stage explicit paths** from `git status --porcelain` — never `git add -A` / `git add .` in a shared tree; it sweeps in a concurrent session's untracked WIP. (patterns.md, explicit-path-add)
- **Entanglement guard:** any file that was already `M`/modified at *session start* and that you did not author is possibly another session's in-flight work — do NOT fold it into your commit. If unsure, list those paths and **safe-stop** instead of guessing.
- **Conflict-marker hygiene:** before committing, `grep -rnE '^(<{7}|={7}|>{7})' <touched-files>` — never commit live `<<<<<<<` markers. (patterns.md, conflict-markers)
- Commit with a clear message describing the finished work. Use a normal commit (no force, no amend of pushed commits).

If `git status` is clean everywhere, there's nothing to commit — continue.

---

## Step 3 — Land each worktree's branch and push it (autonomous)

For each linked worktree on branch `B`:

**3a. Decide the target.** Default: **`B` is the keep-branch** — the commits are already on it, and the MR is what merges `B` into main. In that case there is nothing to merge; just push `B`. Only do a local merge when there is a *clearly identified parent branch* `P` that `B` was cut from AND `P` is checked out in the primary checkout (e.g. a sub-branch feeding an integration branch). When the parent is ambiguous, **do not merge** — push `B` as-is and note it; the MR owns the path to main.

**3b. Merge (only when a parent `P` is clear):**
```bash
git -C "$PRIMARY" checkout "$P"
git -C "$PRIMARY" merge --no-ff "$B"
grep -rnE '^(<{7}|={7}|>{7})' .      # any conflict markers → SAFE-STOP
```
Conflict → stop, list the files, propose resolution. Never blind-`git add` after a conflict.

**3c. Push (this is the autonomous push you're authorized to do):**
```bash
git -C "$WT" push origin "$B"        # or push $P from $PRIMARY if you merged
```
- **Pushing a feature branch is fine** — the SonarQube `sonar-gate.sh` PreToolUse hook only blocks pushes to **main**. If the branch you push *is* `main`/default (work done directly on main), the gate fires; run `/sonarqube:sonar-quality-gate` first, and if it's not PASSED, **safe-stop** (do not bypass).
- **Push rejected (remote moved)?** Inspect the incoming commit's touched files. No file overlap with yours → `git pull --rebase && push`. Overlap → **safe-stop** and resolve. **Never force-push `main`/default.** (patterns.md, push-race-recovery)
- After pushing, verify nothing is stranded: `git -C "$WT" rev-list origin/$B..$B` must be empty.

---

## Step 4 — Remove the worktrees

A worktree is only removable once it is clean (Step 2) AND pushed (Step 3). If you are *standing inside*
a worktree you're about to remove, `cd "$PRIMARY"` first.

```bash
cd "$PRIMARY"
# If the worktree borrowed deps via symlink (e.g. node_modules), drop the symlink BEFORE removal
# so cleanup doesn't follow it into the real tree:  rm -f "$WT/node_modules"   (only if it's a symlink)
git worktree remove "$WT"            # refuses if dirty — that means Step 2 missed something → SAFE-STOP
git worktree prune
```

(patterns.md, throwaway-worktree: drop the symlink before `worktree remove`.)

---

## Step 5 — Switch the primary checkout to main and sync

Only now, with every worktree clean+pushed+removed:

```bash
cd "$PRIMARY"
DEFAULT="<default branch from Step 0>"
git checkout "$DEFAULT"             # refuses on local changes → means uncommitted work remains → SAFE-STOP
git pull --ff-only origin "$DEFAULT" || git pull --rebase origin "$DEFAULT"
git branch --merged origin/"$DEFAULT" | grep -vE "^\*|\b$DEFAULT\b"   # local branches fully merged → safe to prune
```

Prune only **local** branches already merged into `origin/<default>` (recoverable from origin). Leave **remote** branches alone — the MR platform deletes them on merge; for `[gone]` cleanup use the existing `/clean_gone` skill. Never delete a branch whose MR is still open.

---

## Step 6 — Verify the invariant & report

Re-check all four invariant points, then print:

```
--- WRAP COMPLETE ---
Clean state reached:
  ✓ Committed:   [N commits across M trees, or "nothing to commit"]
  ✓ Pushed:      [branch → origin/branch, ahead 0]
  ✓ Worktrees:   [removed: <paths>, or "none"]
  ✓ On:          [default branch] (up to date with origin, tree clean)

Left intentionally:  [branch kept because MR still open, or "nothing"]
```

If any invariant point is NOT met, replace the success report with the **Safe-stop** for the blocker.

---

## Safe-stops (state situation + options + recommendation, default safest)

Stop and report — do **not** push past these autonomously:

| Situation | Action |
| --- | --- |
| Merge conflict (markers present) | Stop. List conflicting files + a resolution plan. Never blind-`git add`. |
| Parent branch for a merge is ambiguous | Don't merge. Push `B` as-is; note the MR owns the path to main. |
| Push to **main/default** but SonarQube gate not PASSED | Stop. Run `/sonarqube:sonar-quality-gate`, fix, re-run — do not bypass. |
| Push rejected with file overlap | Stop. Show incoming vs local; resolve before retry. Never force-push main. |
| Dirty file that predates this session / looks like another session's WIP | Stop. List the paths; do not sweep them into your commit. |
| `git worktree remove` refuses (still dirty) | Stop. Something in Step 2 was missed — surface it. |
| Detached HEAD in a worktree | Stop. Show the commit + how to attach it to a branch before it's lost. |
| No `origin` remote | Skip push/prune; still commit, remove worktrees, switch to main; say push was skipped. |

## Rules

- **Order is law:** commit → land+push → remove worktrees → *then* switch to main. Switching to main is gated on a clean, pushed state — never strand a dirty worktree.
- **No work left behind** is the contract: a branch with an open MR is kept (not deleted); commits are always pushed before a worktree is removed.
- Autonomous through **push of a feature branch**; the only hard human/automation gate is **push to main**, which the SonarQube hook enforces — respect it, don't route around it.
- Re-verify against `origin/<branch>` after `git fetch`, not the local checkout. Stage explicit paths. Grep for conflict markers after any merge. Never force-push the default branch.
- If the repo is already clean and on main with no worktrees, say "already clean — nothing to do" and stop.
