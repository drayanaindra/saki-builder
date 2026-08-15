# Installing saki-builder in OpenCode

saki-builder is distributed as an npm plugin package (`@saketek/saki-builder`) that works with
[OpenCode](https://opencode.ai) ≥ 1.18. Installing it is two commands — one for the **hooks**
(safety gates + run visibility), one for the **bundle** (skills, slash commands, agents, rules):

```bash
# 1. register the plugin so opencode runs its hooks
opencode plugin @saketek/saki-builder --global

# 2. install the skills/commands/agents/rules into ~/.config/opencode
npx @saketek/saki-builder install --global
```

Restart opencode. You now have:

- **Slash commands** — `/rplan`, `/prd`, `/build`, `/qa`, `/wrap`, `/roadmap`, and the rest
  (bare names — no `saki-builder:` prefix in opencode).
- **Agent Skills** — the same skills, loadable on demand.
- **Agents** — `product-engineer`, `qa`, `senior-pm`.
- **Rules** — the execution protocol loads every session from `~/.config/opencode/AGENTS.md`.
- **Safety hooks** — catastrophic `rm -rf`, force-push to main, and embedded secrets are blocked;
  pushes to main run the sonar/coverage gates from `config/hooks/`.
- **Run visibility (opt-in)** — with `SAKI_AGENT_MODE=1`, sessions write
  `tasks/.saki/<session>.json` + `latest.json` (same contract as headless Claude; see
  `docs/AGENT-RUNNERS.md`).

## What each command does

`opencode plugin @saketek/saki-builder --global` installs the package with Bun into
`~/.cache/opencode/node_modules/` and merges `"plugin": ["@saketek/saki-builder"]` into
`~/.config/opencode/opencode.json` using opencode's own config parser (your other settings are kept).
On the next start, opencode imports `opencode/plugins/plugin.ts` (`exports["./server"]`) and runs the
safety hooks + run-visibility event hook.

`npx @saketek/saki-builder install` copies the **bundle** (`AGENTS.md`, `agent/`, `commands/`, `skills/`)
into `~/.config/opencode/`. This step is required — opencode loads skills/commands/agents from config
directories only; a plugin module cannot contribute them. The installer:

- merges (never deletes your other files) and only touches the managed names;
- timestamp-backups real files it overwrites into `~/.config/opencode/.saki-backup-<ts>/`;
- repoints `config/docs/…` references in `AGENTS.md` to the package's absolute path so on-demand
  rule references resolve from any working directory;
- is idempotent — re-running changes nothing and creates no backup.

Pass `--target <dir>` to install into a different config dir and `--dry` to preview.

The installer prints engine-specific invocation guidance. Use `--engine claude|codex|opencode`
to override detection when the installer runs outside the host process. This option changes the
recommendation only; Claude Code and Codex plugin installation remain owned by their native CLIs.

## Manual config (equivalent)

Instead of `opencode plugin`, add the entry yourself:

```jsonc
// ~/.config/opencode/opencode.json
{
  "plugin": ["@saketek/saki-builder"]
}
```

Then run `npx @saketek/saki-builder install` for the bundle.

## Updating

```bash
opencode plugin @saketek/saki-builder --global --force   # refresh the package
npx @saketek/saki-builder install                        # refresh the bundle + AGENTS.md
```

## Uninstall

```bash
# remove the plugin entry
jq '.plugin = [.plugin[] | select(. != "@saketek/saki-builder")]' \
  ~/.config/opencode/opencode.json > /tmp/oc.json && mv /tmp/oc.json ~/.config/opencode/opencode.json
# remove the bundle files the installer managed
rm -f  ~/.config/opencode/AGENTS.md
rm -rf ~/.config/opencode/agent ~/.config/opencode/commands ~/.config/opencode/skills
```

Only remove the managed dirs if you did not have your own files in them before installing — the
installer's backup dir (`.saki-backup-<ts>/`) holds anything it replaced.

## For maintainers: publishing

The repo root is the npm package. Version, manifest, and hooks all build from the same source.

```bash
npm run typecheck && npm test && npm run smoke
bash test/test-opencode-install.sh        # installer behavior
npm pack --dry-run                        # inspect the tarball
npm publish --access public               # HUMAN GATE: needs npm credentials + `npm view @saketek/saki-builder`
```

Notes:

- The package has **zero runtime dependencies** — the plugin module is type-checked against
  `@opencode-ai/plugin` (devDep, erased at runtime) and runs as ESM under Bun regardless of
  `package.json` `type` (a nested `opencode/plugins/package.json` pins `type: module` so Node-based
  tools agree).
- `engines.opencode` declares `>=1.18.0`. Bump it only when you deliberately break older opencode.
- `npm pack` runs the `prepack` script, which regenerates `dist/opencode-bundle/` via
  `bin/build-npm-bundle.sh` (source: `build-opencode.sh --from-plugin` + `namespace-refs.js --reverse`).

## Local development from this repo (no publish)

Point a project config at the repo as a path plugin and install the bundle to a scratch dir:

```jsonc
// <project>/.opencode/opencode.json
{ "plugin": ["file:///absolute/path/to/claude-config"] }
```

```bash
bash bin/build-npm-bundle.sh
node bin/saki-install.mjs --target "$TMP/cfg"
```

## Known limits

- Skills require the bundle install step (file-discovered by opencode; not ship-able in a plugin module).
- `config/docs/…` references inside installed `commands/*.md` stay relative to the project working
  directory (pre-existing behavior); only the installed `AGENTS.md` is repointed.
- Run visibility is repo-bound, matching the Claude-side contract: sessions in non-git directories
  fall back to `worktree="/"` and the state write is dropped fail-open.
- This targets opencode's released V1 plugin system. opencode's in-progress V2 system (dev branch) is
  not yet covered.
