---
name: init-env
description: Scaffold the agent development environment for a new project, for Claude Code, opencode and/or Codex. Creates the project rules file, hooks, agents, memory, and project structure.
disable-model-invocation: true
---

# Initialize Project Environment

Set up the production development environment for this project: $ARGUMENTS

This skill targets **three host engines — Claude Code, opencode and Codex.** They read different
files, so scaffolding the wrong set produces an environment that *looks* initialized and loads
nothing:

- **opencode** reads `CLAUDE.md` as a compatibility fallback but **never expands `@import` lines**,
  and ignores `.claude/settings.json`, `.claude/agents/` and `.claude/skills/` entirely.
- **Codex** does not read `CLAUDE.md` or `.claude/` at all — it reads `AGENTS.md` (the same file as
  opencode) and `.codex/`. Scaffolding the claude set for a codex repo is the loudest version of this
  failure: **everything** written is invisible to the host.

Step 0 decides which set to write; every later step is parameterized by that decision.

## Step 0 — Detect the host engine + resolve roots (ALWAYS FIRST, both modes)

Run the read-only probe, then apply the ladder:

```bash
printf 'OPENCODE=%s CODEX_THREAD_ID=%s CODEX_CI=%s CLAUDECODE=%s\n' \
  "${OPENCODE:-unset}" "${CODEX_THREAD_ID:-unset}" "${CODEX_CI:-unset}" "${CLAUDECODE:-unset}"
ls -d AGENTS.md CLAUDE.md .opencode .codex .claude/agents 2>/dev/null
SAKI_ENV="$(sed -n 's/^SAKI_PLUGIN_ROOT=//p' "$HOME/.config/opencode/.saki-env" 2>/dev/null)"
for sub in docs hooks; do
  for d in "${CLAUDE_PLUGIN_ROOT:-/nonexistent}/config/$sub" \
           "${SAKI_PLUGIN_ROOT:-/nonexistent}/config/$sub" \
           "${SAKI_ENV:-/nonexistent}/config/$sub" \
           "$HOME/.claude/$sub"; do
    [ -d "$d" ] && { echo "SAKI_$(echo "$sub" | tr a-z A-Z)=$d"; break; }
  done
done
```

**ENGINE ladder** — first match wins:

1. `$ARGUMENTS` contains `--engine <list>` → use it verbatim (explicit override). `<list>` is one or
   more of `claude|opencode|codex`, comma-separated; `both` is an alias for `claude,opencode` and
   `all` for all three.
2. `OPENCODE` is set → `opencode`.
3. `CODEX_THREAD_ID` **or** `CODEX_CI` is set → `codex`.
4. `CLAUDECODE` is set → `claude`.
5. None → `claude`.

**Both non-claude engines are tested BEFORE `CLAUDECODE`, for the same reason.** opencode *and* codex
launched from a Claude Code shell inherit `CLAUDECODE`, so testing it earlier misfires; the reverse
nesting does not occur.

> **Use `CODEX_THREAD_ID`/`CODEX_CI`, never `CODEX_HOME`, as the codex marker.** Verified against
> codex-cli 0.147.0: a codex run exports `CODEX_CI=1` and `CODEX_THREAD_ID=<uuid>` to every child,
> but exports `CODEX_HOME` **only when the caller pinned one** — so a `CODEX_HOME` test misses an
> ordinary codex run entirely. It is also the weaker signal in the other direction: an operator who
> exports `CODEX_HOME` in their shell profile would trip it while running under a different engine.
>
> `bin/engine-detect.mjs` implements this same ladder for the installer and is **kept in step with
> this list — change both together** (`test/test-engine-detect.mjs` pins the ordering). It adds one
> rung this list does not need: `CODEX_HOME` as a last-resort codex signal *below* `CLAUDECODE`,
> since the installer runs from the operator's own shell where a configured preference is the only
> hint available. It also returns `unknown` instead of defaulting to `claude`, because a wrong
> command-form recommendation is worse than saying nothing; a scaffold has to pick, so this ladder
> defaults.

**Upgrade rule** — after the ladder, if the repo already carries *another* engine's markers, add that
engine too, so a mixed team does not have one engine's setup rot:

| repo also has | add |
|---|---|
| `CLAUDE.md` or `.claude/agents/` | `claude` |
| `AGENTS.md` **plus** `.opencode/` or `opencode.json` | `opencode` |
| `.codex/` | `codex` |

`AGENTS.md` alone does **not** imply opencode: codex reads the same file, so it is shared evidence —
only an opencode-specific marker (`.opencode/`, `opencode.json`) settles it.

**Roots** — `SAKI_DOCS` and `SAKI_HOOKS` come from the probe above. Use them **everywhere** instead of
hardcoding `~/.claude/…` or `${CLAUDE_PLUGIN_ROOT}` — neither resolves in an opencode-only install.
If a root does not resolve at all, say so and continue with the documented fallback behaviour of the
step; never silently skip a step because a path was missing.

State the outcome before doing any work: `ENGINE=<...>  SAKI_DOCS=<...>  SAKI_HOOKS=<...>`.

## Engine → artifact map

Every step below writes the column(s) matching `ENGINE`. When `ENGINE` names more than one engine,
write **each** column — the multi-engine recipes are designed so the rules body exists exactly once
(no drift).

| Concern | `claude` | `opencode` | `codex` |
|---|---|---|---|
| Project rules | `CLAUDE.md` (with `@import`) | `AGENTS.md` (no `@import` — not expanded) | `AGENTS.md` — **the same file as opencode**, write it once |
| Rule imports | `@~/.claude/docs/…`, `@.claude/memory/patterns.md` | `opencode.json` → `instructions[]` | none — `AGENTS.md` must be self-contained (flatten every import in) |
| Config | `.claude/settings.json` | `opencode.json` (repo root, **merged**) | `~/.codex/config.toml` (global). Per-repo config is only `[projects."<abs-path>"] trust_level` — **do not** write a repo-local `config.toml`, nothing reads it |
| Pre/PostToolUse hooks | `.claude/settings.json` `hooks` | `.opencode/plugin/quality-hooks.ts` | plugin-level `config/hooks/hooks.json`, trusted per-hash under `[hooks.state]` in `~/.codex/config.toml` — **no per-repo hook file** |
| Subagents | `.claude/agents/*.md` | `.opencode/agent/*.md` (`mode: subagent`) | `.codex/agents/*.toml` — see the schema note below |
| qa agent template source | `$SAKI_DOCS/../agents/qa.md` or `~/.claude/agents/qa.md` | `~/.config/opencode/agent/qa.md` | same source as claude, converted to TOML |
| Skill overrides | `.claude/skills/<n>/SKILL.md` | `.opencode/skill/<n>/SKILL.md` | `.codex/skills/<n>/SKILL.md` (same `SKILL.md` format as claude) |
| Project memory | `.claude/memory/` | `.claude/memory/` (same — see note) | `.claude/memory/` (same — see note) |
| Init marker | `.claude/.env-init.json` | `.opencode/.env-init.json` | `.codex/.env-init.json` |
| Verify | run a test hook | `opencode debug config --pure`, `opencode agent list --pure` | `codex plugin list`, `ls .codex/agents` |

> **codex subagents are TOML, and the schema differs from the other two — two traps:**
> 1. There is **no `tools:` allow-list.** Restrict a read-only agent with `sandbox_mode = "read-only"`
>    instead; omitting it does not make the agent read-only.
> 2. **Do not port the `model:` line.** The claude/opencode agents name `sonnet`/`opus`, which are not
>    codex model ids — a wrong id breaks the agent. Omit `model` and let
>    `agents.default_subagent_model` apply.
>
> Required keys: `name`, `description`, `developer_instructions`. Also accepted: `model`,
> `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, `skills.config`. Built-in agents are
> `default`, `worker`, `explorer`; a custom agent of the same name takes precedence.

> **Codex skills/commands come from the plugin, not from a scaffold.** Installing the saki-builder
> plugin (`docs/CODEX-INSTALL.md`) brings the whole skill set; init-env does not scaffold it. Do
> **not** also symlink `config/skills/` into `$CODEX_HOME/skills/` — that creates a second,
> version-skewed copy of every skill and eats the skills context budget. `.codex/skills/` is for
> *project-specific overrides* only.
>
> The installed id is **`saki-builder@saketek`** — `saketek` is the marketplace name in both catalogs
> (`.claude-plugin/marketplace.json` for Claude Code, `.agents/plugins/marketplace.json` for codex),
> so the plugin registers under the same id on either host. It appears in `~/.codex/config.toml` as
> `[plugins."saki-builder@saketek"]`, which is what `CodexSkillsProof`-style checks read.

> **Memory stays at `.claude/memory/` under every engine.** It is a directory label, not a Claude
> runtime dependency — `/saki-builder:reflect` and `/saki-builder:retro` write there regardless of
> host, and opencode loads it through `instructions[]`. Do not "fix" this to `.opencode/memory/`
> without also updating those two skills.

Directory spellings: opencode accepts both singular and plural (`.opencode/agent/` and
`.opencode/agents/`, likewise `command`/`skill`/`plugin`). Use the **singular** forms above — they
match the `opencode.json` config keys. Project plugins in `.opencode/plugin/` auto-load with **no**
config registration.

> **opencode resolves project scope from the GIT ROOT.** In a directory that is not a git repo,
> `.opencode/` and a project `opencode.json` are ignored *entirely* — the scaffold writes files that
> nothing ever reads. Before writing the opencode set, confirm `git rev-parse --show-toplevel`
> succeeds; if it does not, run `git init` first (headless mode) or tell the user (interactive).
> Write `.opencode/` and `opencode.json` at that **git root**, not at the current working directory —
> from a subdirectory opencode loads the subdir's config *and* the root's, but from the root it only
> loads the root's, so the root is the only placement that works from everywhere in the repo.

## Invocation modes

Detect the mode from `$ARGUMENTS` and the repo, then follow the matching rule for Step 1:

- **Interactive (default)** — a human ran `/saki-builder:init-env`. Ask for project name, business context, key
  constraints as normal.
- **Non-interactive / PRD-driven** — `$ARGUMENTS` contains a path to a PRD (e.g.
  `tasks/prd-*.md` / `docs/prd/**/prd.md`), OR no `$ARGUMENTS` were given but a `tasks/prd-*.md`
  exists in the repo. This happens when a tool (e.g. pipeline-studio) runs `/saki-builder:init-env` headless in a
  SINGLE turn before a build. In this mode you have **no human to ask** and **one turn to finish** —
  so do NOT run the full 14-step Process below. Instead run this **LEAN, BOUNDED scaffold** and
  complete ALL of it before stopping:

  > **Headless scaffold — do every item, in order, then STOP. You are NOT done until the init
  > marker for `ENGINE` exists AND you have committed.** Do not pause, do not ask, do not
  > narrate alternatives — just create the files.
  >
  > 0. Run **Step 0** (engine + roots). Read the PRD; DERIVE project name, business context,
  >    constraints, and **tech stack** from it (TL;DR / problem / JTBD / any stack notes). For an
  >    empty repo with no stack files, infer the stack from the PRD ("a Next.js app" → Node/TS).
  >    Default anything unstated; never prompt. If an existing env dir is FOREIGN, back it up first
  >    (see Step 1 backup rule).
  > 1. The **rules file** for `ENGINE` (lean, <100 lines) — Step 2 below, but skip the interactive
  >    "ask user" parts. `claude` → `CLAUDE.md`; `opencode` → `AGENTS.md` **plus** the
  >    `opencode.json` `instructions[]` wiring (without it the rules load empty); `both` → both.
  > 2. The three agents — `reviewer`, `qa`, `planner` — into the engine's agent dir, Steps 5–7
  >    (`reviewer` + `qa` are what `/saki-builder:build` invokes).
  > 3. `.claude/memory/patterns.md` and `.claude/memory/lessons-learned.md` — Step 11 below (the
  >    import target + raw inbox).
  > 4. The marker — Step 12 below (`config` MUST be `$HOME`).
  > 5. Self-commit — Step 14 below (`git add` only the created paths + `commit --no-verify`).
  >
  > **Deliberately SKIP in headless mode** (heavier / better done interactively later; and the hooks
  > would interfere with the autonomous build that runs right after): git-provider auth (Step 1b —
  > login needs a human), the design engine (Step 1c — needs a human choice + the Figma MCP),
  > the hook/plugin gates (Step 4), `docs/project-context.md` (Step 3),
  > `.claude/hooks/` scripts (Step 8), skill overrides (Step 9), Playwright infra (Step 10), the
  > product roadmap (Step 11b). The operator can run `/saki-builder:init-env` interactively later to
  > add these.

## Process

1. **Detect project context**:
   - Read package.json, pyproject.toml, go.mod, Cargo.toml to detect tech stack
   - Check for an existing rules file (`CLAUDE.md` / `AGENTS.md`) and env dir (`.claude/` / `.opencode/`)
   - Identify test framework, linter, type checker
   - **Interactive mode:** ask user for project name, business context, key constraints.
     **Non-interactive / PRD-driven mode:** derive all of these from the PRD (see "Invocation modes") — do NOT ask.
   - **If an existing env dir is FOREIGN** (present but its `.env-init.json` is missing or its
     `config` ≠ this machine's `$HOME` — i.e. it came from another saki-builder install, so its import
     paths / hook scripts / agents won't resolve here): back it up FIRST — for the engine's own dir
     and rules file:
     ```bash
     ts=$(date +%Y%m%d-%H%M%S)
     # per ENGINE: .claude + CLAUDE.md · .opencode + AGENTS.md + opencode.json · .codex + AGENTS.md
     [ -d .claude ]   && mv .claude   ".claude.bak-$ts"
     [ -f CLAUDE.md ] && mv CLAUDE.md "CLAUDE.md.bak-$ts"
     [ -d .opencode ] && mv .opencode ".opencode.bak-$ts"
     [ -d .codex ]    && mv .codex    ".codex.bak-$ts"
     [ -f AGENTS.md ] && mv AGENTS.md "AGENTS.md.bak-$ts"
     ```
     Only move the dirs/files belonging to the engine(s) you are about to scaffold. Never overwrite a
     foreign env dir in place. **`opencode.json` is the exception — merge it, never move it** (Step 4);
     a project may legitimately own one.

1b. **Set up git-provider access** (INTERACTIVE mode only — SKIP in headless/PRD-driven mode):
    Full MR/PR/commit/review access needs the repo's provider CLI installed and authenticated. Run
    the read-only detector from the repo root and act on its `status`:
    ```bash
    "$SAKI_HOOKS/repo-auth-setup.sh"
    ```
    It classifies the git remote's host → provider CLI (`*github*` → `gh`, `*gitlab*` → `glab`,
    including self-hosted like `gitlab.example.com`) and reports install + auth state:

    | status | do this |
    |--------|---------|
    | `READY` | ✓ note "authed to HOST as ACCOUNT"; confirm access with the printed `glab mr list` / `gh pr list`, then continue |
    | `NEEDS_INSTALL` | tell the user to run the printed `action` themselves (e.g. `! brew install glab`), then re-run the detector |
    | `NEEDS_LOGIN` | tell the user to run the printed `action` themselves (e.g. `! glab auth login --hostname HOST`) — the token MUST NOT pass through chat (secrets rule) — then re-run to confirm `READY` |
    | `NO_REMOTE` (fresh project) | ask which provider they want (GitHub / GitLab / a self-hosted host); install the CLI if missing, have them `! <cli> auth login`, then re-check with the chosen host: `"$SAKI_HOOKS/repo-auth-setup.sh" . <host>`. Offer `git remote add origin <url>` if they have the URL. |
    | `UNKNOWN_HOST` | ask whether HOST is GitHub or GitLab, then treat it as that provider and re-check |

    **Never** run `auth login` yourself and **never** accept a pasted token — the user completes the
    interactive login in their own terminal via the `!` prefix; the detector is read-only and only
    tells you the exact command. An MCP-based git-provider server is an optional advanced alternative,
    but the CLI already covers MR/commit/review — defer MCP unless the user asks for it.

1c. **Choose + record the design engine** (INTERACTIVE mode only — SKIP in headless/PRD-driven mode):
    `/saki-builder:proto` can preview a PRD two ways — **native** (render the project's real design system
    into an HTML gallery; the canonical path `/saki-builder:build` reads) or **figma** (use a connected
    Figma design as the SOURCE via the Figma MCP, routed by seat capability). Record the project's choice
    so proto routes on it:
    ```bash
    "$SAKI_HOOKS/design-engine-setup.sh" detect
    ```
    Then ask the user **native or figma** (default **native** — always available, no external dependency):
    - **native** → `"$SAKI_HOOKS/design-engine-setup.sh" record --engine native`
    - **figma** → verify the live Figma MCP + seat by calling the Figma MCP **`whoami`** tool (a bash hook
      cannot see the MCP — you MUST call the tool yourself):
      - **Not connected** → tell the user to connect the Figma MCP (Figma desktop app running, or the
        first-party Figma plugin authed), then re-check. If they can't connect now, record `native` and
        note they can re-run this step later.
      - **Connected** → read the seat and map it → capability: `view`/`dev` → **read** (design-to-code
        only); `edit`/`editor`/`full`/`design` → **write** (read + can also export to canvas); unknown →
        **read** (conservative). Ask for the Figma **source file URL** proto should read from, then record:
        ```bash
        "$SAKI_HOOKS/design-engine-setup.sh" record --engine figma \
          --seat <seat> --capability <read|write> --source "<figma-file-url>" --handle "<whoami handle>"
        ```
    `whoami` returns only a handle + seat tier (not secrets), so nothing sensitive passes through chat. The
    record lands at `.claude/design-engine.json`; `/saki-builder:proto` Step 0 reads it and routes.

2. **Create the project rules file** (lean, <100 lines). Same **body** for every engine:
   - Project identity and business context
   - Tech stack and key commands the agent can't guess
   - Detect project stage (Stage 1-4) based on model count, file sizes, team size
   - Add a "Bounded Contexts" table (ask user or infer from project structure)
   - Add "Architecture Stage" section noting current stage and transition triggers
   - Project-specific rules only (don't duplicate global)
   - Essential checklists

   What differs is **where the body lives and how the shared docs get imported**:

   - **`claude`** → `CLAUDE.md`, body + these `@import` lines:
     - `@~/.claude/docs/ddd-patterns.md`
     - `@~/.claude/docs/modular-architecture.md`
     - `@.claude/memory/patterns.md` — the promoted store for THIS repo (created in Step 11). Do NOT
       import `lessons-learned.md` (raw inbox — keeps context lean).
   - **`opencode`** → `AGENTS.md`, body **with no `@import` lines at all** (opencode does not expand
     them — an `@import` here is a silent no-op, which is exactly the bug this step exists to avoid).
     The same three imports are wired in Step 4 via `opencode.json` `instructions[]`.
   - **`codex`** → `AGENTS.md`, body with no `@import` lines — same file, same reason as opencode.
     **But codex has no `instructions[]` equivalent**, so there is nowhere to wire the three imports:
     paste the content that matters **inline** into `AGENTS.md` (flattened), or accept that those docs
     never load. Writing `@import` lines and moving on is the silent-no-op failure again, one step
     removed. If `ENGINE` also includes `opencode`, write `AGENTS.md` **once** — both engines read it.
   - **more than one engine, including `claude`** → write the body **once** into `AGENTS.md`, then make
     `CLAUDE.md` a thin wiring file:
     ```markdown
     @AGENTS.md
     @~/.claude/docs/ddd-patterns.md
     @~/.claude/docs/modular-architecture.md
     @.claude/memory/patterns.md
     ```
     opencode and codex read `AGENTS.md` and ignore `CLAUDE.md`; Claude Code reads `CLAUDE.md` and
     pulls the body in. One body, no drift.

     ⚠ With `codex` in the set, the three `@import` lines above load for **claude only** — codex does
     not expand them and has no `instructions[]`. Flatten anything codex must actually see into
     `AGENTS.md` itself.

3. **Create docs/project-context.md** — the ONE hand-written context file, scoped to what no tool derives:
   - Read the contract first — `$SAKI_DOCS/project-context-contract.md` (Step 0 resolved `SAKI_DOCS`
     across the plugin install, the opencode install, and the `~/.claude` symlink). It is the source of
     truth for scope, the banned list, the skeleton, and the 100-line ceiling. **If it does not resolve,
     still emit the three sections below** — an unreadable contract must not silently degrade the
     scaffold back to free prose. Exactly three sections, each a **level-2 `## ` heading, spelled
     verbatim** — `wrap` §2a treats a file with none of these three headings as off-contract and
     restructures it, so a fallback scaffold that uses bold labels instead would be rewritten on its
     first trigger:
     - `## Topology` — deployables (runtime + entrypoint `path:line`) and the **cross-boundary edges**
       between them (HTTP / queue / RPC, with call site + handler). This is graphify's blind spot: its
       extraction is same-language AST-based, so it sees no path across a process boundary.
     - `## Invariants` — rules that must hold system-wide, each with where it is enforced (`path:line`).
     - `## Deliberate non-goals` — what is intentionally absent, so nobody "helpfully" adds it back.
     - A `Last verified: <date> (commit <sha>)` stamp above the first heading.
   - **Do NOT write** god nodes, communities, per-file descriptions, module LOC, architecture stage, or
     business narrative — `graphify-out/GRAPH_REPORT.md`, `/saki-builder:arch-check` and the roadmap/PRDs
     already own those, and a second copy has no tiebreak. Nothing to say in a section → `None`.
   - Single-deployable project → one Topology row plus the invariants; still worth writing.
   - `/saki-builder:wrap` Phase 2a refreshes this file when a diff adds a deployable, a cross-boundary
     edge, or an invariant — so it stays true instead of rotting from the first commit.

4. **Create the config + quality gates.** Both engines gate the same two things: type-check after an
   edit, tests before a commit. Pick the stack's commands from the Tech Stack Detection table at the
   bottom, then write the row for `ENGINE`.

   **`claude` → `.claude/settings.json` with hooks:**

   For Python projects:
   - PostToolUse:Edit|Write -> run type checker (mypy/pyright)
   - PreToolUse (git commit hook script) -> run tests (pytest)

   For TypeScript/JavaScript projects:
   - PostToolUse:Edit|Write -> run type checker (tsc --noEmit)
   - PreToolUse (git commit hook script) -> run tests (jest/vitest)

   For Go projects:
   - PostToolUse:Edit|Write -> run vet (go vet)
   - PreToolUse (git commit hook script) -> run tests (go test)

   **`opencode` → `opencode.json` + a project plugin.** opencode has no settings-hook system; project
   behaviour is extended with plugins, which auto-load from `.opencode/plugin/*.ts` with no
   registration.

   a. **`opencode.json` at the repo root — MERGE, never overwrite.** A project may already own one.
      Read it (if present), add only the keys below, write it back. Keep the user's other keys.
      ```jsonc
      {
        "$schema": "https://opencode.ai/config.json",
        "instructions": [
          "<SAKI_DOCS>/ddd-patterns.md",
          "<SAKI_DOCS>/modular-architecture.md",
          ".claude/memory/patterns.md"
        ]
      }
      ```
      Substitute the **absolute** `SAKI_DOCS` from Step 0 — `instructions[]` accepts absolute paths,
      relative paths and globs, and tolerates entries that do not exist yet (a missing path does not
      break startup, so ordering against Step 11 is not a hazard). These three entries are the
      opencode equivalent of the `CLAUDE.md` `@import` block — **without them the project rules load
      with none of the shared docs**, which is the core failure this skill's opencode support exists
      to fix. Do NOT add `AGENTS.md` to `instructions[]`; opencode loads it automatically.

   b. **`.opencode/plugin/quality-hooks.ts`** — copy the template and patch the two command arrays for
      the detected stack:
      ```bash
      mkdir -p .opencode/plugin
      cp "$SAKI_DOCS/templates/opencode-quality-hooks.ts" .opencode/plugin/quality-hooks.ts
      ```
      Then edit `TYPECHECK` and `TESTS` at the top of the copied file (the template documents the
      per-stack values; set an array to `[]` to disable that gate). If `$SAKI_DOCS` did not resolve,
      write the file from the mapping in the Tech Stack Detection table instead of skipping the step:
      `tool.execute.after` + `input.tool === "edit"|"write"` runs the type checker and appends failures
      to `output.output`; `tool.execute.before` + `input.tool === "bash"` matches `git commit` (skip
      when `--no-verify` is present) and **throws** to block when tests fail. A `throw` in
      `tool.execute.before` is the only deny mechanism opencode offers.

   NOTE for every engine: the catastrophic-command guard (`rm -rf /`, force-push to main, secrets in
   argv) is already active globally — `dangerous-command-guard.sh` via the saki-builder plugin on
   Claude Code, `safety-hooks.ts` via the opencode plugin. Do NOT recreate it per project.

5. **Create the `planner` agent**:
   - Read-only planning subagent
   - Tools: Read, Grep, Glob, WebFetch, WebSearch
   - Model: the most capable model available (fast enough for exploration; quality matters)

6. **Create the `reviewer` agent**:
   - Fresh-context code reviewer
   - Tools: Read, Grep, Glob, Bash
   - Model: the most capable model available (thorough review needs the best model)

7. **Create the `qa` agent**:
   - Copy from the global template: `claude` → `~/.claude/agents/qa.md`; `opencode` →
     `~/.config/opencode/agent/qa.md`
   - The global template auto-detects the stack at runtime (Python/Go/TS/Rust)
   - No customization needed — it reads `pyproject.toml`, `package.json`, etc. to pick the right commands
   - This agent is invoked programmatically (not by user via /saki-builder:qa)
   - Usage by the orchestrator: `Agent(subagent_type="qa", prompt="Verify criteria for: [task]. Plan: [path]")`

   **Where Steps 5–7 write, and in what shape:**

   - **`claude`** → `.claude/agents/<name>.md`, frontmatter as described above (`tools:` as a CSV
     string, `model: <most capable model>`, optional `color:`).
   - **`opencode`** → `.opencode/agent/<name>.md`, with three mandatory frontmatter differences —
     these are the same transforms `build-opencode.sh` applies to the shipped agents, and getting them
     wrong makes opencode reject or mis-register the agent:
     1. add `mode: subagent`;
     2. **drop the `tools:` CSV line** — opencode's schema expects an object, not a comma-separated
        string, so a Claude-style `tools:` line is a validation error. Use `permission:` if the agent
        genuinely needs a restriction, otherwise omit;
     3. qualify the model as `provider/model` (e.g. `anthropic/claude-opus-4-x`), and map any named
        `color:` to an opencode value (`yellow`/`orange`→`warning`, `blue`/`cyan`→`info`,
        `green`→`success`, `red`/`pink`→`error`, `purple`/`violet`→`accent`).
   - **`both`** → write both directories. The bodies are identical; only the frontmatter differs.

8. **Create project hook scripts** (if needed) — `claude` → `.claude/hooks/`, `opencode` → extend
   `.opencode/plugin/quality-hooks.ts` from Step 4b rather than adding shell scripts:
   - protect-files.sh (block edits to .env, lock files — project-specific patterns)
   - pre-commit-check.sh (run tests before commit) — already covered by Step 4b under opencode
   - NOTE: the global dangerous-command guard is already active for every engine (see Step 4). Do NOT
     recreate it per-project.

9. **Scaffold project-specific skill overrides** — `claude` → `.claude/skills/<name>/SKILL.md`;
   `opencode` → `.opencode/skill/<name>/SKILL.md` (both are file-discovered at project scope; the
   body format is identical, so only the directory changes).

   Create an `rplan-review` override tailored to the detected stack.
   Use the global `rplan-review` SKILL.md as the base structure, but replace
   the generic expert agent prompts with project-specific ones:

   | Stack detected | Expert agents to generate |
   |----------------|--------------------------|
   | Go | Go Engineer (ctx, error handling, service layer patterns) |
   | Python/FastAPI | Python Engineer (Pydantic, async, dependency injection) |
   | Rust | Rust Engineer (ownership, error types, async runtime) |
   | Next.js/React | Frontend Engineer (App Router or Pages Router, state, auth) |
   | Vue/Nuxt | Frontend Engineer (Composition API, Pinia, SSR) |
   | PostgreSQL | DB/Security (migrations, RLS if multi-tenant, SQL safety) |
   | MySQL/SQLite | DB/Security (migrations, query safety) |
   | Multi-tenant | add RLS/tenant isolation checks to DB agent |

   Each agent prompt must include:
   - The project's specific conventions (from the project rules file)
   - File path patterns specific to this project
   - Domain-specific blockers (e.g., missing tenant guard for multi-tenant apps)
   - Output format: `[DOMAIN] REVIEW / Blockers / Warnings` (Phase 3 classifies each as Blocking/Advisory — do NOT propose a numeric adjustment)

   Also create a `qa` skill override that extends the global
   qa skill's Playwright logic. The override should:
   - Document the project's API base URL and dev server start command
   - Note any project-specific auth strategy (JWT keys, cookie name, OAuth vs token)
   - Leave Playwright generation logic (Step 1.5 template) unchanged — it is project-agnostic

   Optionally create a `prd-review` override when the repo
   has domain-specific judges or a house style. Use the global as the base structure and:
   - Replace the four judge prompts with project-specific lenses (domain metric model, house JTBD style)
   - Keep Phase 1's executable-criteria gate (`[auto]`/`[manual]` tag, invariant failure-path) and
     the Phase 3 manual-test checklist unchanged — both are project-agnostic and load-bearing
   - Document the project's `[auto]` verification commands (curl base URL, test runner) so the
     manual-test checklist cleanly separates from what `/saki-builder:qa` will automate

10. **Scaffold Playwright test infrastructure** (if frontend detected) — engine-agnostic, identical
   for every engine:

   a. Install dotenv if not present: `npm install dotenv --save-dev`

   b. Create `e2e/fixtures/auth.ts` using the `base.extend<>` fixture pattern:
   ```typescript
   // Fill in the auth strategy for this project (replace the comment below)
   import { test as base } from '@playwright/test';
   type AuthFixtures = { loginWithToken: (token: string) => Promise<void> };
   export const test = base.extend<AuthFixtures>({
     loginWithToken: async ({ page }, use) => {
       await use(async (token: string) => {
         test.skip(!process.env.TEST_JWT, 'TEST_JWT not set');
         // TODO: replace with this project's auth strategy
         // e.g. localStorage keys, cookie name, session storage key
         await page.addInitScript(
           ({ accessToken, refreshToken }: { accessToken: string; refreshToken: string }) => {
             localStorage.setItem('access_token', accessToken);
             localStorage.setItem('refresh_token', refreshToken);
           },
           { accessToken: token, refreshToken: 'placeholder-refresh' },
         );
       });
       await page.evaluate(() => localStorage.clear());
     },
   });
   export { expect } from '@playwright/test';
   ```

   c. Add `dotenv.config({ path: '.env.test' })` to top of `playwright.config.ts`
      (Playwright does NOT auto-load `.env.test` — Next.js does, Playwright doesn't)

   d. Create `e2e/qa-generated/.gitkeep`

   e. Add to `.gitignore`:
   ```
   .env.test
   e2e/qa-generated/*.spec.ts
   ```

   f. Create `.env.test` with placeholder:
   ```
   TEST_JWT=
   ```
   Note to user: "Fill in TEST_JWT with a long-lived (≥24h) dev token for Playwright auth tests"

11. **Initialize memory** (two files, two roles — mirror the global `~/.claude/memory/` split). These
   paths are the **same for every engine** (see the note under the artifact map):
   - Create `.claude/memory/lessons-learned.md` (empty template) — the **raw inbox**. `/saki-builder:retro`
     appends session learnings here. **NOT** imported into the rules file (unpromoted/noisy — keeping it
     out keeps always-on context lean).
   - Create `.claude/memory/patterns.md` (empty template) — the **promoted store**. `/saki-builder:reflect` writes
     confirmed project-specific patterns here. This is the file the project rules `@import`
     (Step 2, `claude`) or `instructions[]` (Step 4a, `opencode`) point at, so promoted patterns
     auto-load into `/saki-builder:prd` / `/saki-builder:rplan` / `/saki-builder:build`. Seed it with a
     header comment: `# Project Learned Patterns` + `> Promoted by /saki-builder:reflect from lessons-learned.md.
     Auto-loaded via the project rules file. Raw notes live in lessons-learned.md.`

11b. **Offer the product roadmap** (INTERACTIVE mode only — SKIP in headless/PRD-driven mode):
    disciplined product work starts from a roadmap of items. Ask once:
    `Set up a product roadmap now? It's how work gets started — /saki-builder:add categorizes each item
    (epic · feature · improvement · bug) and routes it. (y/n)`
    - **y** → scaffold `tasks/roadmap.md` via `/saki-builder:roadmap init` (ask for the product name, default
      the repo name), then offer to add the first 1–3 items with `/saki-builder:add`. Don't force it — one
      item is enough to demonstrate the flow; the rest can be added later.
    - **n** → skip; note the operator can run `/saki-builder:roadmap init` + `/saki-builder:add` anytime. Do not
      block init on this.

12. **Write the init marker** — the durable "this repo's agent env was initialized by THIS config"
    stamp that tools use to detect env state. It goes in the engine's own dir:
    `claude` → `.claude/.env-init.json`; `opencode` → `.opencode/.env-init.json`; `both` → **both
    paths, identical content**. Write exactly:
    ```bash
    write_marker() {                      # $1 = .claude | .opencode ; $2 = engines value
      mkdir -p "$1"
      cat > "$1/.env-init.json" <<EOF
    {
      "tool": "pipeline-studio-init-env",
      "config": "$HOME",
      "engines": $2,
      "version": 1,
      "createdAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
    EOF
    }
    # ENGINE=claude   → write_marker .claude   '["claude"]'
    # ENGINE=opencode → write_marker .opencode '["opencode"]'
    # ENGINE=both     → write_marker .claude '["claude","opencode"]'; write_marker .opencode '["claude","opencode"]'
    ```
    `config` MUST be the literal value of `$HOME` so a repo carrying a marker from another machine/config
    reads as FOREIGN (its `config` won't match this `$HOME`). `tool` and `version` keep their existing
    values — external readers (pipeline-studio) match on them. `engines` is additive: it records what
    was actually scaffolded so a later run can tell a single-engine repo from a dual one.

13. **Verify**:
    - **`claude`** — run a test hook to confirm it fires.
    - **`opencode`** — run both, from the repo root, and check the output names what you just wrote:
      ```bash
      opencode debug config --pure   # → your instructions[] entries appear
      opencode agent list --pure     # → planner / reviewer / qa appear
      ```
      `--pure` skips external plugins so the check reflects config discovery, not plugin side-effects.
      An agent missing here is almost always the `tools:` CSV line from Step 7 that should have been
      dropped.
    - Show a summary of what was created, grouped by engine.

14. **Non-interactive / PRD-driven mode only — self-commit the env** so the repo is clean before any
    downstream build branches:
    - Stage ONLY the paths this skill ACTUALLY created (never `git add -A` — don't sweep unrelated/
      concurrent edits; and never name a path you didn't create — `git add` of a missing pathspec
      exits non-zero and stages nothing, breaking the commit). For the LEAN headless scaffold that is,
      per engine:
      - `claude` → `git add CLAUDE.md .claude`
      - `opencode` → `git add AGENTS.md opencode.json .opencode .claude/memory`
      - `both` → `git add CLAUDE.md AGENTS.md opencode.json .claude .opencode`

      (Only add `docs/project-context.md` / `e2e` / `.env.test` etc. if a fuller scaffold actually
      created them — they are SKIPPED in lean headless mode.)
    - Commit with the hook bypass so the just-installed pre-commit test gate can't block a project
      that has no tests yet: `git -c commit.gpgsign=false commit --no-verify -m "chore(agent-env): initialize agent environment"`.
    - (Interactive mode: leave the changes unstaged for the human to review/commit — do NOT self-commit.)

## Tech Stack Detection

| File | Stack | Type Checker | Test Runner | Linter |
|------|-------|-------------|-------------|--------|
| pyproject.toml | Python | mypy | pytest | ruff |
| package.json | Node/TS | tsc --noEmit | vitest/jest | eslint |
| go.mod | Go | go vet | go test | golangci-lint |
| Cargo.toml | Rust | cargo check | cargo test | clippy |
