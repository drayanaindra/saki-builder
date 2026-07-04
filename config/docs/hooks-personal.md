# Personal (opt-in) hooks

The saki-builder plugin ships and **auto-registers** only project-neutral hooks (in
`config/hooks/hooks.json`):

| Hook | Event | What it does |
| ---- | ----- | ------------ |
| `inject-core.js` | SessionStart | injects the always-on core protocol + your personal patterns overlay |
| `repo-context.sh` | SessionStart | emits a tight repo-state block |
| `dangerous-command-guard.sh` | PreToolUse:Bash | blocks destructive commands |
| `format-staged.sh` | PreToolUse:Bash | formats staged files just before `git commit` |
| `build-completion-gate.sh` | Stop | keeps an autonomous `/saketek:build` run alive until done |
| `pipeline-completion-gate.sh` | Stop | keeps a `/saketek:pipeline` run alive to its gate |

The following hooks are **environment-specific** — they need tooling not everyone has, so they are
**shipped but NOT auto-registered**. Opt in by adding them to your own `~/.claude/settings.json`
(they live in the installed plugin under `${CLAUDE_PLUGIN_ROOT}/config/hooks/`):

| Hook | Needs | Why not shipped-on |
| ---- | ----- | ------------------ |
| `rtk-rewrite.sh` | `rtk` >= 0.23 + `jq` | RTK is a personal token-saver, not universal |
| `sonar-gate.sh` + `sonar-gate-init.sh` | SonarQube + `~/.sonar` creds | requires a SonarQube server + login |
| `sonar-secrets/` | the sonar-secrets build scripts | personal secret-scan setup |
| macOS notification (`osascript`) | macOS | platform-specific |

## Opt-in example

Add to `~/.claude/settings.json` (NOT the plugin — a plugin can't set your personal settings):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$HOME/.claude/plugins/.../config/hooks/sonar-gate.sh\"" }
        ]
      }
    ]
  }
}
```

Find the installed plugin path with `claude plugin list` / the `${CLAUDE_PLUGIN_ROOT}` a plugin hook
would see. If you develop saki-builder from a local checkout, point at `config/hooks/sonar-gate.sh`
in the repo instead.

> Disable the shipped core injection with `SAKI_CORE_DISABLE=1`. Other shipped hooks are fail-open —
> they never block a session on error.
