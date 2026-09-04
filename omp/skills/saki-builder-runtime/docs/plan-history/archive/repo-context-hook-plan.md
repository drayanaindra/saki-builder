# EXECUTION PLAN: SessionStart repo-context hook

**Date:** 2026-04-17
**Confidence:** 97%
**Risk Score:** LOW
**Unknown Count:** 1 / 2 max

## Problem Statement

When I start (or resume / clear) a Claude Code session, I want a tight, repo-aware context block injected automatically, so I (and the model) start every turn with high-signal repo state without burning tokens on duplicate info or noise.

Modeled on Cline's `<environment_details>` pattern (per the research above), but **deduplicated against what Claude Code's harness already injects** in its CLAUDE.md env block (cwd, branch, git status, last 5 commits — those are free, no point repeating).

---

## Design

### Key insight: avoid duplicating what the harness already gives

The Claude Code harness already injects at session start:

- Primary working directory
- Is git repo (true/false)
- Current branch
- `git status` (modified/staged/untracked, no `-uall`)
- Recent commits (last 5)

**The hook will only add what's missing**, in this order of value:

| Field                           | Why it's worth tokens                                                                     | Approx tokens |
| ------------------------------- | ----------------------------------------------------------------------------------------- | ------------- |
| `session: <source>`             | Tells model whether context is fresh (`startup`) or stale-after-reset (`resume`/`clear`)  | 3             |
| `top level:` (one line)         | Cheap repo-orientation, harness doesn't show                                              | 10–25         |
| `branch tracking: ↑N ↓M`        | Catches "you forgot to push" / "you're behind main"                                       | 5–10          |
| `stash: N entries` (only if >0) | Reminds about uncommitted parked work                                                     | 5             |
| `active plans: <list>`          | **Highest value** — points model at any `*-plan.md` in cwd; aligns with `/rplan` workflow | 10–40         |

**Total budget:** target ≤ 100 tokens (~400 chars). Hard cap via truncation at 2000 chars.

### Output format (Cline-style XML wrapper, dense)

```
<repo-context source="startup">
top: config/ memory/ personal/ README.md
remote: main → origin/main (↑1 ↓0)
stash: 2
plans: feature-x-plan.md, refactor-y-plan.md
</repo-context>
```

If not a git repo: emit only `top:` line. If no useful info at all: emit nothing (exit 0 silently).

### Why NOT use JSON `additionalContext`?

Plain stdout works, is simpler, easier to debug (you can `cat` the script and see what it would emit). The JSON wrapper buys nothing here — we have one hook, no need to merge with siblings, and the output is naturally formatted for the model already.

---

## Steps

| #   | Action                                                                                                                                                                                                                                           | Files (exact paths)                  | Risk | Assumption                                                                                     |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------ | ---- | ---------------------------------------------------------------------------------------------- |
| 1   | Create `repo-context.sh`: bash script that reads stdin JSON, extracts `cwd` + `source`, and emits the `<repo-context>` block. Handles non-git, no-commits, large stash, missing remote. Uses only `git`, `jq`, `ls`, `find` (already on system). | `config/hooks/repo-context.sh` (new) | LOW  | `jq` is installed (already a dependency of `rtk-rewrite.sh`)                                   |
| 2   | `chmod +x` the script                                                                                                                                                                                                                            | same                                 | LOW  | –                                                                                              |
| 3   | Add SessionStart entry to global settings: matcher `"startup\|resume\|clear"`, command `~/.claude/hooks/repo-context.sh`                                                                                                                         | `~/.claude/settings.json`            | LOW  | The existing `compact` matcher entry stays untouched (it has a different, specialized message) |
| 4   | Smoke test: run script manually with simulated stdin from this repo (`echo '{"cwd":"...","source":"startup"}' \| ./repo-context.sh`) — verify output is well-formed and ≤ 2000 chars                                                             | n/a                                  | LOW  | –                                                                                              |
| 5   | Real-world test: open a fresh `claude` session in this repo and in a non-git temp dir; verify the block appears (or appears minimal/absent) and renders correctly                                                                                | n/a                                  | LOW  | –                                                                                              |
| 6   | Document the hook in `README.md` (one-paragraph entry under hooks section)                                                                                                                                                                       | `README.md`                          | LOW  | –                                                                                              |

---

## Plan Wiring

Single flow — no UI/API/DB layers:

```
[claude session starts]
  → Claude Code harness fires SessionStart hooks (matcher matches "startup")
  → ~/.claude/hooks/repo-context.sh executes
       reads stdin JSON: {session_id, cwd, source, ...}
       cd to $cwd
       collects: top-level dir listing, git ahead/behind, stash count, *-plan.md files
       emits <repo-context>...</repo-context> block to stdout
  → harness captures stdout, injects as additional context
  → model sees it before first user message
```

---

## User Role Coverage

N/A — single-user developer tool, only role is "me" (the user of this config repo).

## Migration Checklist

N/A — no schema, no data store.

---

## Branch Points (pre-declared)

- **Step 1**: If `jq` is unexpectedly missing → script silently exits 0 (mirrors `rtk-rewrite.sh` behavior at lines 16–18). No degraded UX, no error to the model.
- **Step 1**: If `cwd` is `$HOME` or root `/` → emit nothing. (Heuristic: if `cwd == HOME` we're not in a project, no value in scanning.)
- **Step 1**: If repo is huge (top-level has >50 entries) → truncate to first 20 + "(N more)".
- **Step 5**: If hook output appears garbled or doubles up with harness env block → re-evaluate whether to keep `top:` field (it's the only one with mild risk of overlap with rare `-uall` listings).

---

## Unknowns (must be ≤ 2)

1. **[LOW]** Does Claude Code's harness env block refresh on `--resume` and `/clear`, or is it a one-shot from session-creation time? If it refreshes, my hook adds less marginal value on those events; if it doesn't, the hook is highly valuable then. → resolution: ship the hook, observe behavior on next `/clear` and `--resume`, adjust matcher if needed (cheap).

---

## No-Gos

- Will NOT include RTK token-savings stats (vanity metric, costs tokens, doesn't change model behavior — RTK's actual savings come from the existing rewrite hook).
- Will NOT include `MEMORY.md` summary (already imported via `~/.claude/CLAUDE.md` chain).
- Will NOT duplicate cwd / branch / git status / recent commits — harness already provides these.
- Will NOT make network calls (must run in <500 ms).
- Will NOT use external dependencies beyond `git`, `jq`, `ls`, `find` (all already present).
- Will NOT block session start on any error — script exits 0 unconditionally.
- Will NOT emit anything if there's nothing useful to say (avoid empty `<repo-context></repo-context>` noise).

---

## Implementation Completeness Checklist

Most template items are N/A (no DB / no API / no frontend). Adapted to relevant ones:

**Hook script**

- [x] Exact file path: `config/hooks/repo-context.sh`
- [x] Symlink target: `~/.claude/hooks/repo-context.sh` (already a symlink to `config/hooks/`)
- [x] Stdin contract documented (reads JSON, extracts `cwd` + `source`)
- [x] Stdout contract documented (`<repo-context>` block, ≤ 2000 chars)
- [x] Exit codes: always 0 (per SessionStart spec, errors don't block; we want graceful degradation)
- [x] Edge cases: non-git, no commits, no remote, large stash, large tree, missing jq, HOME as cwd

**Settings wiring**

- [x] File path: `~/.claude/settings.json`
- [x] Exact JSON delta drafted (matcher + command)
- [x] Coexistence with existing `compact` matcher entry verified (separate entries in array, no conflict)

**Documentation**

- [x] README entry planned (one paragraph under hooks)

---

## Success Criteria

- [ ] Running `echo '{"cwd":"/Users/indrayana/claude-config","source":"startup"}' | ~/.claude/hooks/repo-context.sh` outputs a well-formed `<repo-context>` block in <500 ms
- [ ] Same command with `cwd: /tmp` outputs minimal block (top: line only, no git fields)
- [ ] Same command with `cwd: $HOME` outputs nothing (silent exit 0)
- [ ] Output is ≤ 2000 characters in this repo
- [ ] After wiring settings.json, opening a fresh `claude` session in this repo shows the block in the model's first turn (verify by asking "what do you see in your environment?")
- [ ] After wiring, opening `claude` in a non-git scratch dir shows minimal/no block (no errors)
- [ ] Existing `compact` matcher hook still fires after `/compact` (regression check)
- [ ] No `[rtk]` warnings or shell errors in `claude --debug` output at session start
- [ ] README updated with hook description

---

## Self-Review Results (Step 6 of /rplan)

Ran the deterministic checklist + project-aware checks:

| Check                                                         | Result                                                                             |
| ------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Vague steps                                                   | Pass — every step names exact file path                                            |
| Missing file paths                                            | Pass                                                                               |
| Schema completeness                                           | N/A (no API)                                                                       |
| Auth guards                                                   | N/A (no auth surface)                                                              |
| Error paths                                                   | Pass — script exits 0 on any error, hook spec says SessionStart can't block anyway |
| Empty states                                                  | Pass — silent exit when nothing useful to emit                                     |
| Wiring gaps                                                   | Pass — single flow traced end-to-end above                                         |
| Project-aware (multi-tenancy / atomic / design-system / l10n) | All N/A                                                                            |

**Domain spot-check skipped** — risk is LOW (no DB, no auth, no payment, no multi-tenant).

**Issues found and fixed:** Originally drafted the hook to also emit cwd, branch, and git status. Caught during research that the Claude Code harness already injects these in the env block (visible in current system prompt). Removed those fields → ~70% token reduction on the hook output, no information loss.

---

## Annotation Space

> Human: add notes here. Especially: confirm or redirect on the `top:` field — keep, drop, or only emit when repo has <20 top-level entries?

---

Status: [x] Draft [ ] Annotated [ ] Approved [ ] In Progress [ ] Complete
Confidence Gate: [x] All checklist items checked [x] Confidence ≥ 96% [x] Unknowns ≤ 2
