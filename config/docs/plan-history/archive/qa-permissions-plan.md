# EXECUTION PLAN: QA Permission Auto-Allow Configuration

**Date:** 2026-04-17
**Confidence:** 98%
**Risk Score:** LOW
**Unknown Count:** 0 / 2 max

## Problem Statement

When running `/qa`, every Bash command and MCP tool call prompts for permission, making the QA process slow and tedious. I want to auto-allow all safe tool calls during QA, so I can run the full QA suite without manual approval — while still blocking dangerous/destructive commands via the existing `dangerous-command-guard.sh` hook.

---

## Architecture

**Two-layer safety model:**

1. **Layer 1 — Permission allow rules** (settings.json): Auto-approve known-safe tool patterns so no permission prompt appears
2. **Layer 2 — PreToolUse hook** (dangerous-command-guard.sh): Runs BEFORE every Bash command regardless of permission rules. Blocks: DROP DATABASE/TABLE/SCHEMA, TRUNCATE, DELETE without WHERE, rm -rf on critical paths, git push --force to main, git reset --hard, migrate force/down/drop, shutdown/reboot, curl|sh, chmod 777, dd

**Why this is safe:** Even if a Bash command is "allowed" by permissions, the PreToolUse hook still fires and can block it. The hook is the real safety gate; permissions just reduce friction for safe commands.

---

## Steps

| # | Action | File | Risk |
|---|--------|------|------|
| 1 | Add `permissions.allow` array to user settings with rules for: Bash QA commands (go test/build/vet, npx tsc, npx playwright, curl, ls, cat, echo, psql), MCP Playwright tools, Read, Edit | `~/.claude/settings.json` | LOW |

### Step 1 Detail — Permission Rules to Add

```json
"permissions": {
  "allow": [
    "Bash(go test *)",
    "Bash(go build *)",
    "Bash(go vet *)",
    "Bash(npx tsc *)",
    "Bash(npx tsc)",
    "Bash(npx playwright *)",
    "Bash(curl *)",
    "Bash(ls *)",
    "Bash(ls)",
    "Bash(cat *)",
    "Bash(echo *)",
    "Bash(cd *)",
    "Bash(psql *)",
    "Bash(python3 -c *)",
    "mcp__playwright",
    "Read",
    "Edit"
  ]
}
```

**Why each rule:**
- `go test/build/vet` — QA Step 3 static checks
- `npx tsc` — QA Step 3 frontend type check
- `npx playwright` — QA Step 5 Playwright test runner
- `curl` — QA Step 4 API criterion testing
- `ls`, `cat`, `echo` — QA Step 0-2 plan discovery and file checks
- `cd` — directory navigation
- `psql` — QA Step 4 DB criterion testing
- `python3 -c` — utility scripts (like model switching)
- `mcp__playwright` — QA Step 4 MCP-driven UI testing
- `Read` — reading plan files, code files
- `Edit` — updating plan file checkboxes after QA

**What stays blocked (by hook):** DROP, TRUNCATE, DELETE without WHERE, rm -rf critical paths, git force push, git reset --hard, migrate force/down/drop, shutdown, curl|sh, chmod 777, dd

---

## No-Gos

- Will NOT add blanket `Bash(*)` — only specific command prefixes
- Will NOT remove or weaken the dangerous-command-guard.sh hook
- Will NOT add `deny` rules (the hook handles blocking, not permission deny)
- Will NOT allow `Write` globally (explicit file creation should still prompt)

---

## Unknowns

None.

---

## Success Criteria

- [x] `~/.claude/settings.json` has `permissions.allow` array with all QA-relevant rules
- [ ] Running `/qa` does not prompt for permission on: go test, go build, curl, ls, npx tsc, MCP Playwright tools, Read, Edit
- [x] Dangerous commands (e.g., `DROP TABLE`) are still blocked by the hook even though Bash is allowed
- [x] Existing settings (hooks, plugins, model) are preserved

---

Status: [ ] Draft  [ ] Annotated  [x] Approved  [ ] In Progress  [x] Complete
