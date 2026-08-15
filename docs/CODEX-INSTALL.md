# Installing SAKI Builder in Codex

SAKI Builder is a skills-first Codex plugin. It packages planning, implementation, QA, review,
architecture, security, deployment, and learning-loop workflows under the `saki-builder` namespace.

Codex requires a plugin manifest at `.codex-plugin/plugin.json` and discovers bundled workflows from
the plugin's `skills/` directory. This repository provides both in the repository root.

## Requirements

- Codex CLI with plugin support (`codex plugin --help` should work).
- Git, if installing from the repository.

Codex plugins are also available from the ChatGPT desktop app. The same package can be used by both
supported Codex surfaces. See the [official plugin packaging guide](https://developers.openai.com/plugins/build/plugins).

## Install from the repository

The repository includes its Codex marketplace catalog, so you do not need to create a marketplace
file or copy the plugin manually. Install it directly from the Git repository:

```bash
codex plugin marketplace add https://gitlab.com/drayanaindra/saki-builder.git
codex plugin add saki-builder@saketek
```

For a local checkout, use its repository root as the marketplace source:

```bash
codex plugin marketplace add /absolute/path/to/claude-config
codex plugin add saki-builder@saketek
```

The repository's `.agents/plugins/marketplace.json` points Codex at the bundled plugin source.

### Manual/local development fallback

If you want to develop against a checkout without adding the Git marketplace, clone the repository
into your personal Codex plugin directory:

```bash
mkdir -p "$HOME/.codex/plugins"
git clone https://gitlab.com/drayanaindra/saki-builder.git \
  "$HOME/.codex/plugins/saki-builder"
```

For local development, use a symlink instead so edits are picked up immediately:

```bash
mkdir -p "$HOME/.codex/plugins"
ln -sfn /absolute/path/to/claude-config \
  "$HOME/.codex/plugins/saki-builder"
```

## Personal marketplace fallback

The commands above are the recommended installation path. If you need a personal marketplace entry
instead, create `~/.agents/plugins/marketplace.json` with this entry:

```json
{
  "name": "personal",
  "interface": {
    "displayName": "Personal"
  },
  "plugins": [
    {
      "name": "saki-builder",
      "source": {
        "source": "local",
        "path": "./.codex/plugins/saki-builder"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Developer Tools"
    }
  ]
}
```

The `source.path` is resolved relative to the marketplace root, so this points to
`~/.codex/plugins/saki-builder`.

Install the plugin:

```bash
codex plugin list
codex plugin add saki-builder@personal
```

Start a new Codex session after installation. Codex loads plugin skills for new sessions.

If the shared installer is used from a shell where Codex cannot expose `CODEX_HOME`, pass
`--engine codex` to make its post-install guidance use `$saki-builder:<skill>` explicitly.

## Verify the installation

Inside a new Codex session, run:

```text
/skills
```

You should see skills such as `saki-builder:rplan`, `saki-builder:build`, `saki-builder:qa`, and
`saki-builder:reviewer`.

## Use the workflow

Codex can activate skills automatically when your request matches their descriptions. You can also
invoke one explicitly by typing `$` and selecting the skill, or by mentioning its full name:

```text
$saki-builder:rplan
Create an execution plan for adding CSV export to the orders page.
```

A typical feature flow is:

```text
$saki-builder:rplan          Create the implementation plan.
$saki-builder:rplan-review   Review the plan for missing work and risks.
$saki-builder:approved       Approve the plan and prepare implementation.
$saki-builder:build          Implement the approved plan.
$saki-builder:qa             Run the plan's acceptance checks.
$saki-builder:reviewer       Review the final diff before commit.
```

You can also use natural language, for example:

```text
Create a plan before changing this authentication flow, then wait for my approval.
```

## Common skills

| Skill | Use it for |
| --- | --- |
| `saki-builder:rplan` | Plan a non-trivial change with risks and acceptance criteria. |
| `saki-builder:rplan-review` | Adversarially review an implementation plan. |
| `saki-builder:build` | Implement a finished PRD or plan-track item. |
| `saki-builder:qa` | Verify acceptance criteria and record results. |
| `saki-builder:reviewer` | Run a fresh-context review of the diff. |
| `saki-builder:clean-code` | Apply maintainability and quality rules while coding. |
| `saki-builder:gateway-backend` | Route backend work to the relevant library skill. |
| `saki-builder:gateway-frontend` | Route frontend work to the relevant library skill. |
| `saki-builder:gateway-testing` | Route testing and quality-assurance work to the relevant skill. |

## Update the plugin

For a cloned installation:

```bash
git -C "$HOME/.codex/plugins/saki-builder" pull
codex plugin add saki-builder@personal
```

For a symlinked development checkout, pull or edit the repository directly, then start a new Codex
session. If the old skill metadata remains, reinstall it with `codex plugin add saki-builder@personal`.

Inspect configured marketplaces with:

```bash
codex plugin marketplace list
```

## Remove the plugin

For a cloned installation:

```bash
codex plugin remove saki-builder
rm -rf "$HOME/.codex/plugins/saki-builder"
```

For a symlinked installation, remove only the link:

```bash
unlink "$HOME/.codex/plugins/saki-builder"
```

## Troubleshooting

### `saki-builder` does not appear in `codex plugin list`

Check that the marketplace and plugin manifest exist:

```bash
test -f "$HOME/.agents/plugins/marketplace.json"
test -f "$HOME/.codex/plugins/saki-builder/.codex-plugin/plugin.json"
codex plugin marketplace list
```

### The plugin installs but skills do not appear

Start a new session, then run `/skills`. Confirm that the plugin contains the root `skills/` directory
and directories with `SKILL.md` files. Codex reads each skill's `name` and `description` before
loading its full instructions.

### A Claude or OpenCode command does not work

Codex uses skills rather than Claude's `/saki-builder:<command>` or OpenCode's bare command loader.
Use `/skills` and invoke the Codex skill as `$saki-builder:<skill-name>`. Claude hooks and OpenCode
runtime plugins are separate integrations and are not installed by the Codex plugin.

## References

- [OpenAI: Package your plugin](https://developers.openai.com/plugins/build/plugins)
- [OpenAI: Build skills](https://developers.openai.com/codex/skills)
- [OpenAI: Plugin architecture](https://developers.openai.com/plugins/concepts/plugins)
