# Plan: git-provider account setup for `/init-env`

**Status:** Awaiting approval → implementing non-destructive artifacts
**Risk tier:** MED (new files, auth-adjacent). Actual login/install/push is user-executed, never by Claude.
**Confidence:** 94%

## Objective

When `/saki-builder:init-env` runs, ensure the repo has **full MR/PR/commit/review access**
through the correct git-provider CLI. Detect the provider from the git remote, then guide the
user through install + login. For a fresh project (no remote), ask which provider to use.

## Decisions (defaults chosen while user away — CLI-first)

| Decision | Choice | Why |
|----------|--------|-----|
| Access method | **CLI-first** (`gh`/`glab`) | Already gives MR/commit/review; `glab` installed + partly authed. MCP deferred (advanced, needs token scoping). |
| Placement | **Reusable read-only script + init-env step** | Idempotent, re-runnable standalone (`~/.claude/hooks/repo-auth-setup.sh`), testable in isolation. |
| Login flow | **Detect + instruct user to run** via `!` prefix | Honors the BLOCKING secrets rule — token never enters chat. Claude never runs `auth login`. |

## Provider → CLI map

| Host pattern | Provider | CLI | Install |
|--------------|----------|-----|---------|
| `*github*` | github | `gh` | `brew install gh` |
| `*gitlab*` (incl. `gitlab.solveeducation.org`) | gitlab | `glab` | `brew install glab` |
| other (self-hosted, bitbucket, gitea) | unknown | — | skill asks the user |

## Verified command semantics (tested live)

- `glab auth status --hostname H` → exit 0 authed / exit 1 not. `gh` identical.
- Remote forms to parse: scp-SSH `git@host:path`, `ssh://user@host:port/path`, `https://host/path`.
- Account name: glab prints `... as USER (`; gh prints `... account USER (` → regex `(as|account) <user>`.

## Artifacts

### 1. `config/hooks/repo-auth-setup.sh` (NEW, read-only)
Detects host → maps to CLI → checks install + auth → prints a `<repo-auth>` block:
```
<repo-auth>
status: READY | NEEDS_LOGIN | NEEDS_INSTALL | NO_REMOTE | UNKNOWN_HOST
provider: gitlab | github | none | unknown
host: <host>
cli: glab | gh | -
cli_installed: yes | no | n/a
authed: yes | no | n/a
account: <user>            # only when READY
action: <exact next command>
note: run it yourself with `! <cmd>` — never paste the token into chat
</repo-auth>
```
- Prefers `origin`, falls back to first remote; `[path]` arg (default `.`) + optional `[override_host]` (for fresh-repo re-check after user picks a provider).
- Always exits 0 (advisory, never blocks). Never echoes a token — masks by construction.
- Clean-code: guard clauses, helper fns (`extract_host`, `classify`, `check_auth`, `get_account`), `main "$@"` guarded by `BASH_SOURCE` so the test can `source` it.

### 2. `config/hooks/test-repo-auth-setup.sh` (NEW)
Sources the script, asserts `extract_host` + `classify` over: github https/ssh, gitlab.com scp-ssh,
self-hosted gitlab, ssh://…:port, bitbucket (→unknown), empty (→NO_REMOTE). No real auth needed.

### 3. `config/skills/init-env/SKILL.md` (EDIT)
- Add **Step 1b — Set up git-provider access (INTERACTIVE only)**: run the script, branch on `status`:
  - `READY` → note "✓ authed to HOST as USER", verify with `glab mr list`/`gh pr list`, continue.
  - `NEEDS_INSTALL` → tell user `! brew install <cli>`, re-run.
  - `NEEDS_LOGIN` → tell user `! <cli> auth login --hostname HOST` (they run it), re-run to confirm READY.
  - `NO_REMOTE` / `UNKNOWN_HOST` → ask which provider (GitHub/GitLab/self-hosted host); install+login; optionally set remote.
  - MCP mentioned as an optional advanced add-on (deferred).
- Add Step 1b to the headless **"Deliberately SKIP"** list (login needs a human; would stall the autonomous build).

## Out of scope (this pass)
- Git-provider MCP server wiring (deferred; CLI already covers MR/commit/review).
- A standalone `/repo-auth` slash command (script is already re-runnable; trivial future add).
- Auto-installing CLIs or auto-running `auth login` (user-executed by design).

## Verification
- `bash config/hooks/test-repo-auth-setup.sh` → all URL-parse asserts pass.
- Run script live in this repo → expect `NEEDS_LOGIN gitlab.com glab` (remote is `git@gitlab.com:...`, not authed).
- `shellcheck` clean (if available).
