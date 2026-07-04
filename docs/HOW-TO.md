# saki-builder — how to use it (teammate guide)

saki-builder is a Claude Code **plugin**: a shared, vetted toolkit of planning/build/review skills,
domain agents, safety hooks, an always-on execution protocol, and a split learning loop. It's
**personal-scale** — everyone gets the same tools and works solo with them. Team coordination
(tracking, ownership, intake) is out of scope here.

## Install (no clone)

```
> /plugin marketplace add https://gitlab.com/drayanaindra/saki-builder.git
> /plugin install saki-builder@saki-builder
```

Start a new session so the commands load. That's it — no repo clone, no `install.sh`, no symlinks.

**Update** any time (pull-based — a new version doesn't reach you until you pull it):

```
> /saki-builder:update            # reports where you stand + the exact commands
> /plugin marketplace update saki-builder && /plugin update saki-builder@saki-builder
```

A SessionStart hook also nudges you when you're behind (fail-open; never blocks).

## What you get

- **Every command is namespaced** `/saki-builder:<name>` — e.g. `/saki-builder:rplan`,
  `/saki-builder:build`, `/saki-builder:prd`, `/saki-builder:qa`, `/saki-builder:reviewer`,
  `/saki-builder:wrap`. Run `/help` to see them all.
- **Always-on rules** — a SessionStart hook injects the execution protocol (plan-first, confidence
  gate ≥90%, risk tiers, response header, next-actions). No CLAUDE.md editing needed. Disable with
  `SAKI_CORE_DISABLE=1`.
- **Safety hooks** (auto-registered): destructive-command guard, staged-file formatter, autonomous-run
  completion gates, a repo-context injector.

## The flow

`prd → prd-review → proto → rplan → rplan-review → approved → qa → reviewer → wrap`, or let
`/saki-builder:build` / `/saki-builder:pipeline` drive it end-to-end. Each command right-sizes itself.

## Settings you must merge yourself

A plugin can't ship permissions/model/env. Copy what you want from
`templates/settings.recommended.json` into your own `~/.claude/settings.json` (do **not** copy its
`hooks` — the plugin registers those).

## The learning loop (split)

- **Personal overlay** `~/.claude/memory/patterns-personal.md` — yours, private, injected every
  session, never pushed. `/saki-builder:reflect` writes here by default.
- **Team baseline** `memory/patterns*.md` — the shared, curated layer. Changes land only via **MR**
  (`/saki-builder:sync` opens a branch + MR). See `config/docs/learning-loop.md`.

## Opt-in personal hooks

RTK, SonarQube, and the macOS notifier are shipped but **not** auto-registered (they need tooling not
everyone has). Opt in via your own settings — see `config/docs/hooks-personal.md`.

## Owner / maintainer (developing saki-builder itself)

Work from a checkout and install it as a **local-path marketplace** so edits flow on reload:

```
> /plugin marketplace add /path/to/saki-builder        # the repo dir
> /plugin install saki-builder@saki-builder
```

Before pushing: `npm test` (the validator) must pass — the pre-push hook enforces it
(`git config core.hooksPath .githooks` to enable). Bump `.claude-plugin/plugin.json` + `CHANGELOG.md`
together (the validator checks version sync). The legacy `install.sh` symlink flow still works but is
deprecated in favor of the plugin.
