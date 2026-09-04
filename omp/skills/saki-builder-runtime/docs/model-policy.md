# Model capability policy

Skills describe the capability they need, not a vendor model name. The portable model requirement
used by the workflow is:

| Requirement | Meaning |
|---|---|
| `frontier` | The highest-capability model available in the current host and account |
| `balanced` | A capable general-purpose model when frontier quality is unnecessary |
| `fast` | The fastest acceptable model for low-risk, mechanical work |
| `inherit` | Keep the model selected by the caller |

`frontier` is a capability contract, not a model identifier. It must not be translated to `opus`,
`sonnet`, `haiku`, `claude-*`, `anthropic/*`, or an equivalent name from another provider.

## Resolution

The host or external runner resolves the requirement before execution:

| Host | Resolution rule |
|---|---|
| Claude Code | Use the host model picker and choose the highest-capability available model, or pass the host's model option from a runner. Never rewrite `~/.claude/settings.json` from a skill. |
| OpenCode | Use `/models` or the runner's OpenCode model option. Keep the provider/model value in OpenCode configuration; do not infer it from a Claude alias. |
| Codex | Use the session's selected model or the runner's Codex model option. Do not write Claude or OpenCode configuration. |
| Gemini/Antigravity | Keep the host-selected model, or use its model picker when available. |

If the host does not expose a model selector, inherit the current model and state that the workflow
requested `frontier`; do not claim a concrete model was selected. The workflow can still execute, but
the caller decides whether that satisfies its quality bar.

## Skill metadata

Skills that need the highest reasoning quality declare this in frontmatter:

```yaml
model_requirement: frontier
```

The metadata helps installers, runners, and future host adapters route the skill. It is advisory to
hosts that do not implement model routing; the skill body must retain the short resolution rule above.
