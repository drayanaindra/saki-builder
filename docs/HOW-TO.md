# saki-builder — teammate guide

saki-builder adds a structured **plan → build → review** workflow to Claude Code, plus safety hooks
and a shared learning memory. Everyone installs the same plugin and works solo with it.

---

## Install

Paste these two lines inside Claude Code:

```
/plugin marketplace add https://github.com/drayanaindra/saki-builder.git
/plugin install saki-builder@saketek
```

Start a new session. Every command is now available as `/saki-builder:<name>`.

**Stay up to date:**

```
/plugin marketplace update saketek && /plugin update saki-builder@saketek
```

> A session-start nudge tells you when you're behind — you'll never miss an update.

---

## Your first session

```
/saki-builder:rplan     ← describe what you want to build; it writes a plan
/saki-builder:approved  ← approve the plan, Claude implements
/saki-builder:qa        ← runs your acceptance criteria as actual tests
/saki-builder:wrap      ← commits, pushes, cleans up
```

For a new feature, use the design stage before `rplan`:

```
/saki-builder:design-thinking-prototype  ← run when the UI problem or direction is still uncertain
/saki-builder:prd                        ← write product requirements
/saki-builder:proto                      ← render and approve the complete PRD journey
```

Run `/help` to see the full command list.

---

## What's always on

Once installed, these work in every session automatically — no CLAUDE.md edits needed:

- **Execution protocol** — plan-first, confidence gate, risk tiers, response header, next-actions
- **Destructive command guard** — blocks `rm -rf`, `DROP TABLE`, `git push --force` before they run
- **Repo context injector** — emits branch/plan state at session start so Claude always knows where you are

Disable the protocol with `SAKI_CORE_DISABLE=1` if needed.

---

## Settings (one-time)

The plugin can't write your personal settings. Copy what you want from
`templates/settings.recommended.json` into your `~/.claude/settings.json`.

RTK, SonarQube, and the macOS notifier are opt-in — see `config/docs/hooks-personal.md`.

---

## Learning memory

After a session, `/saki-builder:reflect` promotes useful patterns to your memory file.
`/saki-builder:sync` pushes them to the repo so they're available on other machines.

- **Your private patterns** live in `~/.claude/memory/patterns-personal.md` — never shared.
- **Shared baseline** lives in `memory/patterns*.md` — changes go through a branch + MR.

---

## Developing saki-builder itself

Work from a local checkout, installed as a local-path marketplace so edits load on session restart:

```
/plugin marketplace add /path/to/saki-builder
/plugin install saki-builder@saketek
```

Before pushing: `npm test` must pass (the pre-push hook enforces it).
Bump `.claude-plugin/plugin.json` and `CHANGELOG.md` together — the validator checks they're in sync.
