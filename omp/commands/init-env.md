---
description: "Initialize OMP-native project context, rules, overrides, and agent directories."
---

# Initialize an OMP project environment

Use this skill only for OMP. OMP already discovers the installed plugin's skills, commands,
agents, rules, and extension module. This command creates only project-owned overrides and context.

## Steps

1. Confirm the current directory is the intended project root. Use `git rev-parse --show-toplevel`
   when the repository is expected to be Git-backed.
2. Preserve existing files. Never overwrite `.omp/AGENTS.md`, `.omp/RULES.md`, or project overrides.
3. Create `.omp/AGENTS.md` with the project's identity, stack, commands, constraints, and non-goals.
4. Create `.omp/RULES.md` only for short requirements that must remain active after compaction.
5. Put project skill overrides in `.omp/skills/<name>/SKILL.md` and project agents in
   `.omp/agents/<name>.md`. Each skill needs `name` and `description`; each agent needs `name`,
   `description`, and a complete instruction body.
6. Verify discovery in a new session with `/skills`, `/extensions`, and `/agents`.

Do not create `.omp/`, `.codex/`, `.opencode/`, or engine-specific settings for an OMP-only setup.
