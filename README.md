# saki-builder

A Claude Code plugin that adds a structured **plan → build → review** workflow to your sessions,
plus safety hooks and a learning memory that improves over time.

---

## Install

Paste these two lines inside Claude Code (no repo clone needed):

```
/plugin marketplace add https://github.com/drayanaindra/saki-builder.git
/plugin install saki-builder@saketek
```

Start a new session. Done. Every command is available as `/saki-builder:<name>`.

**Update when a new version is out:**
```
/plugin marketplace update saketek && /plugin update saki-builder@saketek
```

> The plugin auto-detects when you're behind and nudges you at session start.

### OpenCode

The same toolkit ships as an npm plugin for [OpenCode](https://opencode.ai) ≥ 1.18. Two commands:

```
opencode plugin @saketek/saki-builder --global   ← hooks (safety gates + run visibility)
npx @saketek/saki-builder install                ← skills / commands / agents / rules
```

Restart opencode — commands are bare (`/rplan`, `/prd`, `/build`, not `/saki-builder:rplan`).
The installer detects the host engine for its recommendation; use `--engine claude|codex|opencode`
to override detection when running outside the host process.
Full install, update, uninstall, and publish instructions: **[docs/OPENCODE-INSTALL.md](docs/OPENCODE-INSTALL.md)**.

### Codex

The repository includes a Codex-compatible plugin manifest and exposes the canonical workflows
through the root `skills/` directory. Install it directly from the repository:

```bash
codex plugin marketplace add https://github.com/drayanaindra/saki-builder.git
codex plugin add saki-builder@saketek
```

Full installation, skill usage, updates, and troubleshooting: **[docs/CODEX-INSTALL.md](docs/CODEX-INSTALL.md)**.

**Driving it from an agent runner?** Hermes Agent, OpenClaw, or CI spawning `claude -p` in the
background: set `SAKI_AGENT_MODE=1` and poll `tasks/.saki/latest.json` to see whether a run is alive,
hung, or finished. Full contract + supervisor loop: **[docs/AGENT-RUNNERS.md](docs/AGENT-RUNNERS.md)**.

---

## Your first session

```
/saki-builder:rplan     ← describe what you want to build; it writes a structured plan
/saki-builder:approved  ← approve the plan, then implement with the host's frontier model
/saki-builder:qa        ← runs your acceptance criteria as actual tests (curl, go test, etc.)
/saki-builder:wrap      ← commits, pushes, cleans up
```

That's the core loop for any bug or improvement. For a new feature, add two steps at the front:

```
/saki-builder:prd       ← write the product requirements first
/saki-builder:proto     ← see a throwaway UI preview before any code is written
... then rplan → approved → qa → wrap
```

---

## Commands

### Plan & Build

| Command | What it does |
|---------|-------------|
| `/saki-builder:rplan` | Write a structured plan. Reaches 96% confidence with full call-chain wiring before presenting. |
| `/saki-builder:rplan-review` | Parallel expert review of the plan (backend, frontend, DB, security, product). Run for high-risk plans. |
| `/saki-builder:approved` | Approve the plan and start implementation. |
| `/saki-builder:build` | **Autonomous end-to-end.** Pass a roadmap item id (`E3`, `I5`, `B2`) or a plan file — it runs the full chain without prompting. |

### Feature Design

| Command | What it does |
|---------|-------------|
| `/saki-builder:prd` | Turn a feature idea into a Product Requirements Document (user stories, slices, acceptance criteria). |
| `/saki-builder:prd-review` | Adversarial review of the PRD by a parallel judge panel before you build anything. |
| `/saki-builder:proto` | Render a throwaway UI preview of the PRD using your real design system + Playwright screenshots. |

### Quality & Review

| Command | What it does |
|---------|-------------|
| `/saki-builder:qa` | Run each acceptance criterion as a real test (API, unit, file, DB, or browser). Reports pass/fail per criterion. |
| `/saki-builder:reviewer` | Fresh-context code review of the current git diff. |
| `/saki-builder:wrap` | Definition-of-done gate (build, tests, coverage, secrets scan), then commit → push → clean worktrees → back to main. |

### Roadmap

| Command | What it does |
|---------|-------------|
| `/saki-builder:roadmap` | View or initialize your project's work item portfolio. |
| `/saki-builder:add` | Add a new Epic, Feature, Improvement, or Bug. Auto-assigns an id (`E3`, `F1`, `I7`, `B2`) and routes it to the right track. |
| `/saki-builder:pickup` | Start a PRD-track item: seeds `/prd`, loops review to green, stops when ready for `/proto`. |

### Maintenance

| Command | What it does |
|---------|-------------|
| `/saki-builder:retro` | Session retrospective — captures corrections and discoveries. |
| `/saki-builder:reflect` | Promotes confirmed patterns to your memory file. Run weekly. |
| `/saki-builder:sync` | Commits and pushes your memory changes to remote. |
| `/saki-builder:rupdate` | Pull latest skills and patterns from remote (run on other machines after `/sync`). |
| `/saki-builder:init-env` | Scaffold project-specific config and skill overrides for a new project. |

---

## Two workflow paths

Every piece of work enters through `/saki-builder:add`, which assigns a track:

**New feature or user journey → PRD track**
```
/saki-builder:add "description"     → assigns E<n> or F<n>
/saki-builder:pickup E<n>           → writes the PRD, loops review to green
/saki-builder:proto E<n>            → UI preview (this is your approval of the PRD)
/saki-builder:build E<n>            → autonomous implementation, slice by slice
```

**Bug or improvement → Plan track**
```
/saki-builder:add "description"     → assigns I<n> or B<n>
/saki-builder:build I<n>            → autonomous: rplan → approved → qa → reviewer → wrap
   — or step by step —
/saki-builder:rplan → /saki-builder:approved → /saki-builder:qa → /saki-builder:wrap
```

---

## Settings (one-time, optional)

The plugin can't write your personal settings. Copy what you want from
`templates/settings.recommended.json` into `~/.claude/settings.json`.

Workflow model choice is capability-based (`frontier` / `balanced` / `fast`), so each host or runner
resolves it using its own model picker. See [`config/docs/model-policy.md`](config/docs/model-policy.md).

To use RTK, SonarQube, or the macOS notifier, opt in separately — see `config/docs/hooks-personal.md`.

---

## Project-specific skill overrides

Skills have a two-level override system. The global skill is language-agnostic; a project override
tailors it to your stack:

```
~/.claude/skills/<name>/SKILL.md   ← global (this plugin)
.claude/skills/<name>/SKILL.md     ← project-specific (wins)
```

Run `/saki-builder:init-env "Go + Next.js + PostgreSQL"` in a new project to scaffold the override automatically.

---

## Memory & learning

After a session, run `/saki-builder:reflect` to promote useful patterns to your memory file.
Then `/saki-builder:sync` pushes them to your repo so they're available on other machines.

On another machine: `/saki-builder:rupdate` to pull the latest patterns in.

Memory lives in `~/.claude/memory/patterns.md` (or `memory/patterns.md` in this repo if you're using
the legacy clone install). It's auto-loaded every session so Claude always has your accumulated knowledge.

---

## Reference

- **[docs/HOW-TO.md](docs/HOW-TO.md)** — teammate onboarding guide (plugin path, no clone)
- **[docs/execution-protocol-detail.md](config/docs/execution-protocol-detail.md)** — full RESEARCH → PLAN → EXECUTE → VERIFY protocol
- **[CHANGELOG.md](CHANGELOG.md)** — what changed in each version

**Roles** — 20 specialized role personas (`architect`, `engineer`, `reviewer`, `qa`, `security-expert`,
`go-engineer`, `mobile-engineer`, and more) are available as instruction files in `config/skills/`.
Load one when you want Claude to adopt a specific domain perspective for a session.

**Hooks registered automatically:** dangerous-command guard (blocks `rm -rf`, `DROP TABLE`, force
push), RTK token optimizer, repo-context injector (emits branch/plan state at session start).

**MCP:** `@playwright/mcp` is registered for browser automation in `/saki-builder:qa` UI criteria.
Remove with `claude mcp remove playwright` if you don't want it.

---

## Uninstall

```bash
/plugin remove saki-builder         # plugin path
# or, if you used the legacy clone:
cd ~/claude-config && ./uninstall.sh
```
