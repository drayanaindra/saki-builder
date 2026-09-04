# OMP installation

SAKI Builder supports [oh-my-pi](https://github.com/coder/oh-my-pi) as a native plugin.
The package contributes OMP skills, namespaced commands, task agents, project rules, and an
`ExtensionAPI` extension for safety gates and autonomous-run state.

## Install from the marketplace

```bash
omp plugin marketplace add https://github.com/drayanaindra/saki-builder.git
omp plugin install saki-builder@saketek
```

Start a new OMP session. Confirm discovery with `/skills`, `/agents`, and `/extensions`.
Commands use the plugin namespace, for example `/saki-builder:rplan` and `/saki-builder:qa`.

## Update

```bash
omp plugin marketplace update saketek
omp plugin upgrade saki-builder@saketek
```

Start a new session after updating the extension module. `/reload-plugins` is sufficient after
changes limited to skills, commands, agents, rules, or MCP configuration.

## Autonomous-run visibility

Set `SAKI_AGENT_MODE=1` before launching OMP when an external runner needs machine-readable state:

```bash
SAKI_AGENT_MODE=1 omp
```

The extension writes atomic JSON records under `tasks/.saki/`:

- `<session-id>.json` — the session record
- `latest.json` — the most recently started session

The record reports `running`, `finished`, `blocked`, or `failed` status and includes the last
heartbeat timestamp. This state is opt-in; ordinary interactive sessions do not write it.

## Project context

Use `/saki-builder:init-env` for an OMP-only project setup. It creates project-owned `.omp/AGENTS.md`,
`.omp/RULES.md`, `.omp/skills/` overrides, and `.omp/agents/` files without scaffolding Claude,
Codex, or OpenCode configuration.

## Safety behavior

The OMP extension applies the package's dangerous-command guard to `bash` calls, blocks detected
secrets, and protects pushes to the default branch with the configured quality gates. A blocked
`tool_call` fails closed and returns the guard's reason.

The extension also resumes unfinished SAKI build slices through OMP's `session_stop` continuation
contract. Set `SAKI_OMP_MAX_CONTINUE=0` to disable automatic continuation; the default is five
continuations per session.

## Local development

```bash
npm install
bash bin/build-omp-bundle.sh
npm run typecheck
npm run validate
```

The prepack hook regenerates both the OMP and OpenCode bundles before publishing.
