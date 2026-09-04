# Plan: Configure @playwright/mcp for /qa + debug sessions

**Scope (from user):** shared via claude-config repo, on-demand for /qa and debug sessions only, use `@playwright/mcp`, update /qa skill to prefer it.

**Risk:** LOW-MED. No DB, no auth, no destructive ops. Only touches dotfiles install script + one skill file + README.

**Confidence:** 98%

---

## Research Summary

**Current state (verified):**

- `~/.claude/settings.json` is symlinked from `config/settings.json` — does **not** support `mcpServers` key (Claude Code reads MCP config from `~/.claude.json`, not settings.json).
- `~/.claude.json` exists (35KB) and holds Claude-managed state (userID, OAuth, project list, etc.) — **must not** be symlinked or committed; updates must go through `claude mcp add`.
- No local MCP servers currently configured. The 3 visible (`claude.ai Atlassian/Gmail/Google Calendar`) are claude.ai-hosted, not in `~/.claude.json`.
- `install.sh` currently symlinks: `config/settings.json`, `config/docs`, `config/skills`, `config/hooks`, `memory/`. It does not touch `~/.claude.json`.
- `/qa` skill (`config/skills/qa/SKILL.md`) currently: (a) detects `playwright.config.ts`, (b) auto-generates `.spec.ts` files into `$FRONTEND_ROOT/e2e/qa-generated/{slug}/{id}.spec.ts`, (c) runs `npx playwright test ... --reporter=line`. Relies on project having Playwright + chromium installed.

**Package (verified via `npm view`):**

- Name: `@playwright/mcp`, version `0.0.70`, bin: `playwright-mcp`
- Stdio invocation: `npx -y @playwright/mcp@latest`

**`claude mcp add` syntax (verified via `--help`):**

```
claude mcp add [--scope user|project|local] [-e KEY=VAL] <name> -- <command> [args...]
```

**Idempotency check (verified):** `claude mcp get <name>` exits 0 either way, but prints `No MCP server found with name: "..."` to stdout when missing. Grepping that string is the idempotent guard.

**Constraint (verified via claude-code-guide):** Claude Code starts all configured MCP servers at session start; there is no per-skill lazy-load. "On-demand for /qa + debug" is enforced at the **skill instruction** layer (tell Claude when to use the tools), not the MCP config layer. The server process is cheap when idle; Chromium only launches when a tool is actually invoked.

---

## User Role Coverage

| Role                        | What they do                                           | How this plan affects them                                                                                                                                                                                 |
| --------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Machine owner               | Runs `./install.sh` on new machine or after `rupdate`  | `install.sh` adds an idempotent step that registers `playwright` in `~/.claude.json` via `claude mcp add --scope user`. Skipped if already registered. No prompt, no break if `claude` CLI missing.        |
| Claude during `/qa`         | Runs acceptance criteria against the plan              | Skill detects presence of `mcp__playwright__*` tools. If available → prefers MCP-driven browser control for UI criteria. If unavailable → falls back to existing `e2e/qa-generated/` Playwright spec path. |
| Claude in debug session     | User asks Claude to open a browser to verify something | User-facing guidance in `/qa` skill + README notes that `mcp__playwright__*` tools may be invoked for ad-hoc browser debugging. No code path change — this is documentation only.                          |
| Claude in non-`/qa` session | Regular coding work                                    | Skill instructions say: do **not** invoke `mcp__playwright__*` tools outside `/qa` or explicit debug requests. This keeps the "on-demand" contract even though the server is technically always loaded.    |

Edge cases handled:

- First install, no internet → `npx -y @playwright/mcp@latest` fetch fails at session start. Claude Code surfaces the error; Claude in `/qa` falls back to the existing Playwright-spec path. `install.sh` prints warning but does not fail.
- User already has a `playwright` MCP server configured (different command) → `install.sh` skips with a notice (does not overwrite).
- User doesn't have `claude` CLI on `$PATH` during `./install.sh` → step is skipped with a warning; MCP is not installed but install doesn't break.
- `/qa` skill invoked in a project with no Playwright at all → MCP-only path; no dev server / no spec generation. (Current skill already handles this with MANUAL.)

---

## Plan Wiring

### Install-time flow (new)

```
user runs ./install.sh
  → script symlinks same as before
  → NEW: script checks `claude mcp get playwright` output
      if "No MCP server found" in stdout:
        claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest
          → writes mcpServers.playwright to ~/.claude.json
      else:
        echo "~ playwright MCP already configured, skipping"
  → user restarts Claude Code
  → Claude Code reads ~/.claude.json at session start
  → spawns npx -y @playwright/mcp@latest as stdio subprocess
  → exposes mcp__playwright__* tools in every session
```

### Runtime flow for `/qa` (updated)

```
/qa invoked
  → Step 0: find active plan              (unchanged)
  → Step 1a: detect FRONTEND_ROOT         (unchanged)
  → Step 1b: ping baseURL                 (unchanged)
  → NEW Step 1c: detect MCP Playwright tools availability
      if tools with prefix mcp__playwright__ are present:
        MCP_MODE = "available"
      else:
        MCP_MODE = "unavailable"
  → Step 1d: check Playwright browsers installed (unchanged; only runs if MCP_MODE=unavailable AND FRONTEND_ROOT set)
  → Step 1.5: generate specs              (unchanged; only runs if MCP_MODE=unavailable)
  → Step 2: classify criteria             (unchanged)
  → Step 3: static checks                 (unchanged)
  → Step 4: run each criterion
      UI criteria:
        if MCP_MODE=available:
          use mcp__playwright__browser_navigate + browser_click + browser_snapshot/take_screenshot + expect assertions
          map each UI criterion to a sequence of MCP tool calls
          capture pass/fail per criterion
        else:
          fall back to current Step 5 Playwright spec run
  → Step 5: run Playwright                (unchanged; only runs if MCP_MODE=unavailable AND specs generated)
  → Step 6: report                        (unchanged; adds "Mode: MCP/Playwright-spec/MANUAL" to header)
```

---

## Steps

### Step 1 — Add idempotent MCP install to `install.sh` — LOW risk

**File:** `/Users/indrayana/claude-config/install.sh`

**Change:** After the existing symlink block and before the "Done!" echo, insert a new section:

```bash
# Register @playwright/mcp at user scope (skipped if already configured
# or if `claude` CLI is not on PATH). Safe to re-run — idempotent.
echo ""
echo "Configuring MCP servers:"
if ! command -v claude >/dev/null 2>&1; then
  echo "  ~ 'claude' CLI not on PATH — skipping MCP install"
  echo "    Re-run this script after installing Claude Code CLI."
elif claude mcp get playwright 2>&1 | grep -q "^No MCP server found"; then
  if claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest >/dev/null 2>&1; then
    echo "  ✓ @playwright/mcp registered (user scope)"
  else
    echo "  ⚠ Failed to register @playwright/mcp — run manually:"
    echo "    claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest"
  fi
else
  echo "  ~ playwright MCP already configured, skipping"
fi
```

Also update the "Next steps" footer to mention MCP:

```bash
echo "  1. Restart Claude Code (claude) to pick up new config"
echo "     (MCP: /qa will now use @playwright/mcp automatically)"
```

**No-go:** Do not write to `~/.claude.json` directly — always go through `claude mcp add`.

### Step 2 — Update `/qa` skill to prefer MCP + fall back cleanly — MED risk

**File:** `/Users/indrayana/claude-config/config/skills/qa/SKILL.md`

**Change A** — Insert new sub-step after Step 1b:

```markdown
### 1c: Detect MCP Playwright availability

Check whether the session has MCP Playwright tools loaded. Tools with prefix `mcp__playwright__` are exposed when `@playwright/mcp` is registered in `~/.claude.json`.

If available → `MCP_MODE=available` (preferred path for UI criteria — no spec generation, no `npx playwright test`).
If not available → `MCP_MODE=unavailable` (fall back to the existing spec-generation flow in Step 1.5).

Log it:

    Mode: MCP-driven  (via @playwright/mcp)  — or —
    Mode: Playwright-spec (auto-generated specs under e2e/qa-generated/)
```

**Change B** — Renumber current `1c` (browser install check) to `1d` and gate it: "Run only if `MCP_MODE=unavailable` AND `FRONTEND_ROOT` set."

**Change C** — Update Step 1.5 opening: "Run only if pre-flight passed **AND `MCP_MODE=unavailable`**."

**Change D** — Update Step 4 UI criteria block to:

```markdown
**For UI criteria:**

- If `MCP_MODE=available` → drive the browser directly via `mcp__playwright__*` tools:
  1. `mcp__playwright__browser_navigate` to the target URL
  2. `mcp__playwright__browser_snapshot` or `browser_take_screenshot` to observe state
  3. `mcp__playwright__browser_click` / `browser_type` / `browser_fill_form` for interactions
  4. Assert the `Expected outcome:` from the plan against the observed snapshot/URL/DOM
  5. Record PASS/FAIL per criterion. No spec file is written.
- If `MCP_MODE=unavailable` and spec was generated in Step 1.5 → result comes from Step 5 Playwright output.
- If `MCP_MODE=unavailable` and Playwright not configured → mark MANUAL with exact browser steps.
- If server was BLOCKED → mark BLOCKED.
```

**Change E** — Update Step 5 opening: "Run only if Step 1.5 generated at least 1 spec (i.e. `MCP_MODE=unavailable`)."

**Change F** — Update Step 6 report template to include the mode line under the title:

```markdown
--- QA REPORT: [task name] ---
Mode: MCP-driven (or) Playwright-spec (or) MANUAL
```

**Change G** — Add a new rule under "## Rules":

```markdown
- **MCP tools are only for /qa and explicit debug sessions.** Do not invoke `mcp__playwright__*` tools during regular coding work. This keeps the "on-demand" contract even though the MCP server is always loaded.
```

**No-go:** Do not delete the existing spec-generation path (Step 1.5, Step 5). It remains the fallback for any machine where MCP install failed or the CLI wasn't available at install time.

### Step 3 — Document in `README.md` — LOW risk

**File:** `/Users/indrayana/claude-config/README.md`

**Change A** — Under the "Hooks" section or a new "MCP Servers" section near the end, add:

```markdown
## MCP Servers

| Server            | Scope | Purpose                                                                                                                                           |
| ----------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `@playwright/mcp` | User  | Browser automation for `/qa` UI criteria and ad-hoc debug sessions. Installed by `install.sh` via `claude mcp add --scope user`. See `/qa` skill. |

`install.sh` registers MCP servers at user scope via `claude mcp add`. The config lives in `~/.claude.json` (machine-local, not in this repo — it holds OAuth state and other Claude-managed data). On a new machine, `./install.sh` re-registers anything missing. To remove: `claude mcp remove playwright`.

Usage policy:

- `/qa` skill auto-detects `mcp__playwright__*` tools and uses them for UI criteria.
- Outside `/qa` or explicit debug requests, Claude should not invoke `mcp__playwright__*` tools (per skill rule).
- If the MCP server is unavailable on a given machine, `/qa` falls back to its existing Playwright-spec generation path under `e2e/qa-generated/`.
```

**Change B** — Update the `/qa` row in the Workflow table:

```markdown
| `/qa` | Run each acceptance criterion from the plan as an actual test. Reports pass/fail per criterion. Uses `@playwright/mcp` for UI criteria when available; falls back to auto-generated Playwright specs otherwise. |
```

---

## Migration Checklist

N/A — no DB schema changes.

---

## Implementation Completeness Checklist

**User Coverage**

- [x] Every user role that touches this feature is listed (machine owner, Claude in /qa, Claude in debug, Claude in other sessions)
- [x] Each role has full path traced: UI → endpoint → service → DB (install flow + runtime flow written above)
- [x] Permission/auth check present for each role (N/A — local dotfiles + skill, no auth)
- [x] Edge cases per role documented (no internet, CLI missing, already configured, no Playwright in project)

**Database & Migrations**

- [x] N/A — no schema change

**API Layer**

- [x] N/A — no API change

**Service / Business Logic**

- [x] Every service function modified or created is named with its file path (install.sh step, SKILL.md steps A-G, README.md changes A-B)
- [x] Side effects listed (MCP server spawns at session start; chromium launches only on tool invocation)
- [x] Error cases handled (CLI missing → warn+skip; add fails → warn+print manual command; MCP unavailable at runtime → fallback path)

**Frontend**

- [x] N/A — no UI change (the runtime `mcp__playwright__*` tool calls are behavioral, not a UI change to this repo)

**Plan Wiring**

- [x] Install-time flow written end-to-end (`./install.sh` → `claude mcp add` → `~/.claude.json` → next session → MCP subprocess)
- [x] Runtime flow written end-to-end (`/qa` → Step 1c detect → Step 4 MCP-driven OR Step 5 Playwright-spec)
- [x] Each step names exact file, function, and change (no "update X" vagueness)

---

## Assumptions (explicit, testable)

1. **`claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest` creates a user-scope entry in `~/.claude.json`.** Testable: run the command, then `claude mcp get playwright` should return non-"No MCP server found" output.
2. **The MCP tool prefix is `mcp__playwright__<toolname>`.** Claude Code's standard naming convention. Exact tool names (e.g. `browser_navigate`, `browser_snapshot`) are discoverable at runtime once the server is loaded — the skill references them by pattern, not exact name, so the instructions remain correct even if tool names shift slightly across `@playwright/mcp` versions.
3. **`npx -y @playwright/mcp@latest` does not require pre-installed chromium in the target project.** `@playwright/mcp` manages its own browser binaries.
4. **`install.sh` is idempotent after this change.** The `grep "No MCP server found"` check ensures re-runs don't create duplicate registrations or fail.

---

## Branch Points

- **If `claude mcp get` output format changes** (unlikely but possible in a future CLI version): the `grep "No MCP server found"` idempotency check would fail-open (i.e., try to re-add and `claude mcp add` would error). → Recommendation: catch the add failure and print the manual recovery command (already handled in Step 1).
- **If `@playwright/mcp` renames tools in a future version** (e.g. `browser_goto` → `browser_navigate`): the skill references the prefix pattern, not exact names. Claude reads the available tool list at runtime. → No plan change needed unless the prefix itself changes.
- **If the user later wants truly on-demand loading** (start `@playwright/mcp` only on `/qa` invocation): Claude Code doesn't support this at the config layer today. → Would require a custom PreToolUse hook that conditionally spawns the server, or a skill-launched subprocess. Out of scope for this plan; revisit if session-start cost becomes measurable.

---

## Success Criteria

Each criterion has an **Expected outcome** — `/qa` will compare actual vs expected.

### SC-1 — install.sh idempotency (fresh) — FILE/BUILD

**Command:** Remove any existing entry first, then run install.sh:

    claude mcp remove playwright 2>/dev/null; bash /Users/indrayana/claude-config/install.sh 2>&1 | tail -20

**Expected outcome:** Output contains `✓ @playwright/mcp registered (user scope)`. `claude mcp get playwright` returns a server block (not "No MCP server found").

### SC-2 — install.sh idempotency (re-run) — FILE

**Command:**

    bash /Users/indrayana/claude-config/install.sh 2>&1 | tail -20

**Expected outcome:** Output contains `~ playwright MCP already configured, skipping`. `claude mcp get playwright` still returns the same server block.

### SC-3 — install.sh survives missing claude CLI — FILE

**Command:** Simulate missing CLI:

    PATH=/usr/bin:/bin bash /Users/indrayana/claude-config/install.sh 2>&1 | tail -5

**Expected outcome:** Output contains `~ 'claude' CLI not on PATH — skipping MCP install`. Exit code 0. No server registered, no failure.

### SC-4 — MCP server starts at session load — API

**Command:** In a new Claude Code session after install, check:

    claude mcp list 2>&1 | grep playwright

**Expected outcome:** Line includes `playwright:` and shows the npx command. No `✗ Failed` indicator.

### SC-5 — /qa skill detects MCP_MODE correctly — FILE

**Command:**

    grep -n "MCP_MODE" /Users/indrayana/claude-config/config/skills/qa/SKILL.md

**Expected outcome:** At least 4 hits — one in the new 1c step (detect), one in the 1d gate (only if unavailable), one in the 1.5 gate, one in Step 4.

### SC-6 — /qa skill fallback preserved — FILE

**Command:**

    grep -n "e2e/qa-generated" /Users/indrayana/claude-config/config/skills/qa/SKILL.md

**Expected outcome:** ≥1 hit remaining (the fallback spec path is not removed).

### SC-7 — README documents MCP section — FILE

**Command:**

    grep -n "@playwright/mcp" /Users/indrayana/claude-config/README.md

**Expected outcome:** ≥2 hits (MCP table + updated /qa row).

### SC-8 — MCP-driven UI criterion (MANUAL, only runnable with an active UI plan) — UI / MANUAL

**Manual steps:** In a project with a UI `/rplan`-generated plan, run `/qa`. Inspect the report header.

**Expected outcome:** `Mode: MCP-driven` appears under the QA report title, and UI criteria show PASS/FAIL (not NO_SPEC / MANUAL) without any file being written under `e2e/qa-generated/`.

---

## Self-Review Results (Step 6 built-in)

### Deterministic checklist (7/7 pass)

| #   | Check               | Result                                                               |
| --- | ------------------- | -------------------------------------------------------------------- |
| 1   | Vague steps         | PASS — each step names exact file path, section, and textual change  |
| 2   | Missing file paths  | PASS — all three target files use absolute paths                     |
| 3   | Schema completeness | N/A                                                                  |
| 4   | Auth guards         | N/A                                                                  |
| 5   | Error paths         | PASS — CLI missing, add-fail, MCP unavailable at runtime all handled |
| 6   | Empty states        | N/A (no new UI in this repo)                                         |
| 7   | Wiring gaps         | PASS — both install flow and runtime flow traced end-to-end          |

### Project-aware checks

- No multi-tenancy, atomic ops, design system, or localization apply to this dotfiles repo. All skipped.

### HIGH-risk domain spot-check

- Not triggered — overall risk is LOW-MED (no DB migration, no auth change, no payment, no multi-tenant security).

### Issues found and fixed

- **Fixed during self-review:** initial draft referenced "mcpServers in settings.json" (wrong path — clarified to `~/.claude.json` and added explicit reason why settings.json can't hold it).
- **Fixed during self-review:** initial draft had no fallback path if MCP add fails during install → added warning + manual command print.
- **Fixed during self-review:** initial draft omitted the "don't use mcp tools outside /qa" rule → added as Change G in Step 2.

---

## Confidence: 98%

- Base: 4/4 steps fully specified = 100%
- Deductions: 0 unchecked items, 0 unresolved MED/HIGH unknowns, 0 missing roles
- Cap at 98% — two LOW unknowns acknowledged but not blocking:
  1. Exact `mcp__playwright__*` tool name list (resolved at runtime)
  2. Whether `@playwright/mcp` spawns chromium at server startup or only on first tool call (either way, the "on-demand" contract is preserved by skill instructions)

**Risk: LOW-MED.** Install.sh change is the highest-risk piece (MED) because it touches the onboarding path; self-contained fallback (CLI missing → skip with warning) keeps it safe. Skill and README are LOW.

**Pre-present gate (5/5 pass):**

1. Can a developer implement each step without clarifying questions? ✓
2. Are all user roles covered? ✓
3. Migrations listed? ✓ (N/A)
4. Wiring end-to-end? ✓
5. Success criteria testable? ✓
