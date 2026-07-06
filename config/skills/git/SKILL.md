---
name: git
description: Plain-English git front door — you never need to know git. Describe what you want in normal words ("set up a new repo", "start a feature", "save my work", "I broke my branch", "fix this conflict", "undo that", "open a PR", "what's my state?") and saki does the SAFE git operation for you. Snapshots state first, picks the safe variant of every command, confirms only genuinely destructive actions, executes, and reports in plain language. Hands off to /saki-builder:wrap for the full end-of-task landing (build/test/coverage gates → commit → push → clean up). Usage — /saki-builder:git "<what you want in plain words>".
---

# Git — the front door for people who don't do git

**You describe the outcome in plain words. saki figures out the git.** No branch names to
remember, no reset flags to fear, no conflict markers to hand-edit. The user is never asked to
type a git command — that is the whole point of this skill.

This is the **mid-task** git helper. For the **end-of-task landing** (run the Definition-of-Done
gate, then commit → push → remove worktrees → return to a clean `main`), use
`/saki-builder:wrap` — this skill hands off to it rather than re-implementing it.

Deeper conventions (branch naming, commit types, the full safe-alternatives table) live in the
`git` persona reference — cite it when you need the table; don't duplicate the whole thing here.

---

## Order is law

**Snapshot → Classify → Pick the safe variant → Confirm if HIGH-risk → Execute → Verify → Report.**
Never skip the snapshot. Never run a destructive command without the confirm step.

---

## Phase 0 — Snapshot state (ALWAYS first)

**First, is this even a repo?**

```bash
git rev-parse --is-inside-work-tree 2>/dev/null || echo "NOT_A_REPO"
```

If `NOT_A_REPO` → this is a **start-from-nothing** case → go to the **Bootstrap** operation
below. Don't run the rest of Phase 0 (it would error).

Otherwise, pin reality before touching anything:

```bash
git rev-parse --abbrev-ref HEAD          # current branch
git status --porcelain                   # dirty? untracked?
git stash list                           # anything stashed?
git worktree list                        # extra worktrees?
git remote -v | head -1                  # is there an origin?
git fetch origin --prune 2>/dev/null     # refresh remote view (if origin exists)
```

Read the snapshot back to yourself before acting: which branch, is the tree dirty, is there an
origin, are there stashes/worktrees. Every later decision keys off this.

---

## Phase 1 — Classify the intent

Map the user's plain-English request to ONE operation. When ambiguous, state your reading and the
safe default, then proceed (don't stall on a vote).

| The user says… | Operation | The safe action |
| --- | --- | --- |
| "start a project / it's not a repo yet / set this up" | **Bootstrap** | `git init` → sensible `.gitignore` → first commit on the default branch. For login + remote, hand off to `/saki-builder:init-env`. |
| "start a feature / fix / new work" | **Branch** | `git fetch` → branch from latest default: `feature/*` or `fix/*`. Stash dirty WIP first, re-apply after. |
| "save this / commit / snapshot my work" | **Commit** | Stage **explicit paths** → one focused commit, imperative message (`feat:`/`fix:`/…). |
| "get me up to date / sync / pull latest" | **Sync** | `git pull --rebase` (or `--ff-only`); on conflict → drop into **Resolve**. |
| "publish / push / open a PR" | **Publish** | `git push -u origin <branch>` → `gh pr create` (`glab mr create` on GitLab). Never push straight to `main`. |
| "undo that / go back / I made a mistake" | **Undo** | Prefer reversible: `git revert`, `git reset --soft`, `git stash`. `--hard` only with explicit confirm. |
| "I broke my branch / lost a commit / recover" | **Recover** | `git reflog` → show the lost commit → offer `git checkout -b recovery <hash>`. Nothing is deleted. |
| "there's a conflict / it won't merge" | **Resolve** | Guide through each conflicted file; verify no markers remain before continuing. |
| "put this aside / stash / clean slate for a sec" | **Stash** | `git stash push -m "<why>"`; list/pop by name. Never discard. |
| "what's going on / where am I / status" | **Inspect** | Read Phase 0 back in plain language. Read-only. |
| "wrap up / land this / I'm done" | **Land** | **Hand off to `/saki-builder:wrap`** — do not re-implement the DoD gate here. |

### Bootstrap (start from nothing)

When Phase 0 said `NOT_A_REPO`:

1. `git init` and set the default branch to `main` (`git branch -m main`).
2. Add a stack-appropriate `.gitignore` (detect `package.json` / `go.mod` / `pyproject.toml`;
   skip if one already exists).
3. Stage **explicit paths** and make the first commit (`chore: initial commit`).
4. **Remote + provider login is owned by `/saki-builder:init-env`** — don't `gh/glab auth` or
   create a remote here; point the user there: "Repo created locally. Run `/saki-builder:init-env`
   to connect it to GitHub/GitLab."

### Conflict resolution — what's automatic vs what saki confirms

Faithful answer to "does it auto-resolve?": **the mechanical cases, yes; real content clashes,
saki proposes and you approve** — but the user never hand-edits a conflict marker either way.

- **Auto-resolve silently (mechanical, no data loss):** adjacent non-overlapping hunks git flagged
  only by proximity; generated/lock files (`package-lock.json`, `go.sum`) → regenerate or take the
  incoming side; a rebase where one side is a pure superset. The user isn't bothered.
- **Analyze → propose → one-tap confirm (real content clash):** both sides changed the same logic.
  saki reads both, explains the difference in plain words, proposes a concrete merged result, and
  asks yes/no. The user approves intent — they don't touch markers.
- **Never blind-pick a side.** Auto-choosing "ours"/"theirs" on a content clash silently loses work.
  When saki genuinely can't tell, it stops and shows both sides (or offers `git merge --abort`).

Either way, after resolving: `grep -rnE '^(<{7}|={7}|>{7})' <touched-files>` must come back empty
before continuing.

---

## Phase 2 — Pick the safe variant, then confirm only if HIGH-risk

**Always reach for the safe alternative** (fuller table in the `git` persona):

| If the intent implies… | Don't | Do |
| --- | --- | --- |
| discard changes | `git reset --hard` / `git checkout .` | `git stash` (recoverable) |
| overwrite remote | `git push --force` | `git push --force-with-lease` |
| delete a branch | `git branch -D` | `git branch -d` (refuses if unmerged) |
| clean files | `git clean -f` | `git clean -n` first (dry run), show the list |

**Risk tiers — confirm before executing:**

- **LOW (auto):** inspect, stash, branch, commit, `git pull` on a clean tree, push a **feature** branch, revert. Just do it.
- **HIGH (always confirm first):** `--hard` reset, `--force`/`--force-with-lease`, deleting a branch/worktree, **any push to `main`/default**, `git clean -f`, `rebase`/history rewrite of shared branches. State exactly what will happen and what's recoverable, then wait for a yes.

---

## Phase 3 — Execute with the rails on

These are non-negotiable safety rails — they are why the user can trust saki with git:

- **Stage explicit paths, never `git add -A`/`.`** in a tree that may hold another session's or a
  teammate's WIP. Before committing, `git diff --cached` and confirm only the intended hunks are staged.
- **Entanglement guard:** any file already modified at Phase-0 snapshot that you didn't author →
  **safe-stop**, don't sweep it into your commit.
- **Verify against `origin/<branch>` after `git fetch`**, never the local checkout or a board.
- **Conflict-marker hygiene:** after any merge/rebase/resolve,
  `grep -rnE '^(<{7}|={7}|>{7})' <touched-files>` — never commit live markers.
- **Never force-push the default branch.** Feature branches only, and only with `--force-with-lease`.
- **Push-race recovery:** push rejected because remote moved? No file overlap →
  `git pull --rebase && push`. Overlap → **safe-stop**, show incoming vs local. Never force `main`.
- **Secrets:** never let a token/key/password into a commit or the chat. If the secrets hook blocks
  a commit, it's right — remove the secret, don't bypass it.

---

## Phase 4 — Verify, then report in plain language

Confirm the outcome, then tell the user what changed **without git jargon**:

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
git rev-list origin/<branch>..<branch> 2>/dev/null   # empty = fully pushed
```

Report shape:

```
Done — [what happened, in plain words].
You're now on: [branch] · [clean / N files changed] · [pushed / local only]
Recoverable if needed: [stash name / commit hash / "git revert <hash>"], or "nothing to undo".
Next: [the single most useful next step, e.g. "run /saki-builder:git \"open a PR\"" or "/saki-builder:wrap to land it"].
```

---

## Safe-stops

| Situation | Action |
| --- | --- |
| Intent implies a HIGH-risk action | Describe exactly what happens + what's recoverable. Wait for a yes. |
| Working tree dirty when switching/branching | Stash first (named), re-apply after. Never discard silently. |
| Merge/rebase leaves conflict markers | Stop. List the files. Walk the user through, or `git merge --abort`. Never blind-`git add`. |
| Push rejected (remote moved) | No overlap → `pull --rebase && push`. Overlap → stop, show both sides. |
| A file changed by another session/teammate | Stop. Name the paths. Don't commit work you didn't author. |
| Asked to push to `main`/default | Confirm intent; respect any pre-push gate (Sonar/coverage). Prefer a branch + PR. |
| Secret detected in the diff | Stop. Name the file:line. Never route the secret through chat. |
| "Land / wrap up / done" | Hand off to `/saki-builder:wrap` — don't run the DoD gate here. |
| No `origin` remote | Do the local operation; say push was skipped (nothing to push to). |

---

## Rules

- **The user never needs to know a git command.** Translate intent → safe operation → plain report.
- **Snapshot before every operation.** State drives the decision.
- **Reversible by default.** Reach for stash/revert/`--soft` before anything that destroys work.
- **Confirm only what's genuinely destructive** — don't nag on safe operations.
- **Landing belongs to `/saki-builder:wrap`.** This skill covers everything up to that point.
