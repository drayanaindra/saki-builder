#!/usr/bin/env python3
"""Generate the OMP-facing tree from the canonical Claude sources."""

from __future__ import annotations

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SKILLS = ROOT / "config" / "skills"
OUTPUT = ROOT / "omp"
OUTPUT_SKILLS = OUTPUT / "skills"
OUTPUT_COMMANDS = OUTPUT / "commands"
OUTPUT_AGENTS = ROOT / "agents"
OUTPUT_RULES = ROOT / "rules"
RUNTIME_SKILL = OUTPUT_SKILLS / "saki-builder-runtime"


def rewrite(text: str, skill_names: dict[str, str]) -> str:
    replacements = {
        "${CLAUDE_PLUGIN_ROOT}/config/docs/": "skill://saki-builder-runtime/docs/",
        "${SAKI_PLUGIN_ROOT}/config/docs/": "skill://saki-builder-runtime/docs/",
        "config/docs/": "skill://saki-builder-runtime/docs/",
        "${CLAUDE_PLUGIN_ROOT}/config/hooks/": "skill://saki-builder-runtime/hooks/",
        "${SAKI_PLUGIN_ROOT}/config/hooks/": "skill://saki-builder-runtime/hooks/",
        "config/hooks/": "skill://saki-builder-runtime/hooks/",
        "${CLAUDE_PLUGIN_ROOT}/memory/": "skill://saki-builder-runtime/memory/",
        "${SAKI_PLUGIN_ROOT}/memory/": "skill://saki-builder-runtime/memory/",
        "~/.claude/": "~/.omp/agent/",
    }
    for source, target in replacements.items():
        text = text.replace(source, target)

    def skill_ref(match: re.Match[str]) -> str:
        path = match.group(1).strip("/")
        for source, name in sorted(skill_names.items(), key=lambda item: len(item[0]), reverse=True):
            if path == source:
                return f"skill://{name}"
            if path.startswith(f"{source}/"):
                suffix = path[len(source) + 1:]
                if Path(suffix).suffix in {".sh", ".py", ".js", ".mjs", ".ts"}:
                    return f"${{SAKI_PLUGIN_ROOT}}/omp/skills/{name}/{suffix}"
                return f"skill://{name}/{suffix}"
        return match.group(0)

    text = re.sub(
        r"\$\{(?:CLAUDE_PLUGIN_ROOT|SAKI_PLUGIN_ROOT)\}/config/skills/([^\s)`'\"]+)",
        skill_ref,
        text,
    )
    text = re.sub(r"(?<![\w/])config/skills/([^\s)`'\"]+)", skill_ref, text)
    text = text.replace("CLAUDE_PLUGIN_ROOT", "SAKI_PLUGIN_ROOT")
    text = text.replace(".claude/", ".omp/")
    return text

def rewrite_tree(directory: Path, skill_names: dict[str, str]) -> None:
    text_suffixes = {".md", ".sh", ".js", ".json", ".py", ".yml", ".yaml"}
    for path in directory.rglob("*"):
        if not path.is_file() or path.is_symlink() or path.suffix not in text_suffixes:
            continue
        if RUNTIME_SKILL in path.parents:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        path.write_text(rewrite(text, skill_names), encoding="utf-8")


def copy_skill_sources() -> dict[str, str]:
    if OUTPUT_SKILLS.exists():
        shutil.rmtree(OUTPUT_SKILLS)
    OUTPUT_SKILLS.mkdir(parents=True)

    skill_names: dict[str, str] = {}
    sources = sorted(SOURCE_SKILLS.rglob("SKILL.md"))
    for source in sources:
        relative = source.parent.relative_to(SOURCE_SKILLS).as_posix()
        name = source.parent.name
        if name in skill_names.values():
            raise SystemExit(f"duplicate OMP skill name: {name}")
        skill_names[relative] = name
        skill_names[f"{relative}/SKILL.md"] = name
        destination = OUTPUT_SKILLS / name
        shutil.copytree(source.parent, destination, symlinks=True)

    runtime = RUNTIME_SKILL
    runtime.mkdir(parents=True)
    (runtime / "SKILL.md").write_text(
        "---\n"
        "name: saki-builder-runtime\n"
        "description: Read-only package assets used by SAKI Builder OMP skills.\n"
        "disable-model-invocation: true\n"
        "---\n\n"
        "This skill contains portable SAKI Builder documentation and hook scripts. "
        "Use skill://saki-builder-runtime/<path> when a workflow references an asset.\n",
        encoding="utf-8",
    )
    shutil.copytree(ROOT / "config" / "docs", runtime / "docs", symlinks=True)
    shutil.copytree(ROOT / "config" / "hooks", runtime / "hooks", symlinks=True)
    shutil.copytree(ROOT / "memory", runtime / "memory", symlinks=True)
    return skill_names
def write_omp_specific_skills() -> None:
    (OUTPUT_SKILLS / "init-env" / "SKILL.md").write_text(
        """---
name: init-env
description: Initialize OMP-native project context, rules, overrides, and agent directories.
disable-model-invocation: true
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

Do not create `.claude/`, `.codex/`, `.opencode/`, or engine-specific settings for an OMP-only setup.
""",
        encoding="utf-8",
    )
    (OUTPUT_SKILLS / "update" / "SKILL.md").write_text(
        """---
name: update
description: Update the installed SAKI Builder OMP plugin and refresh its marketplace metadata.
user-invocable: true
---

# Update SAKI Builder for OMP

Run the OMP-native update flow:

```bash
omp plugin marketplace update saketek
omp plugin upgrade saki-builder@saketek
```

Start a new session after updating extension modules. Run `/reload-plugins` when only skills,
commands, rules, or MCP content changed.
""",
        encoding="utf-8",
    )



def parse_frontmatter(path: Path) -> tuple[str | None, str | None, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return None, None, "\n".join(lines).strip()
    try:
        end = lines.index("---", 1)
    except ValueError:
        return None, None, "\n".join(lines).strip()
    fields = {}
    for line in lines[1:end]:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip().strip("\"'")
    return fields.get("name"), fields.get("description"), "\n".join(lines[end + 1 :]).strip()


def generate_commands(skill_names: dict[str, str]) -> None:
    if OUTPUT_COMMANDS.exists():
        shutil.rmtree(OUTPUT_COMMANDS)
    OUTPUT_COMMANDS.mkdir(parents=True)
    for source in sorted(SOURCE_SKILLS.iterdir()):
        if source.is_dir() and (source / "SKILL.md").is_file():
            fallback_name = source.name
            path = OUTPUT_SKILLS / fallback_name / "SKILL.md"
        elif source.is_file() and source.suffix == ".md":
            fallback_name = source.stem
            path = source
        else:
            continue
        name, description, body = parse_frontmatter(path)
        command_name = name or fallback_name
        header = "---\n"
        if description:
            escaped = description.replace('"', '\\"')
            header += f'description: "{escaped}"\n'
        header += "---\n\n"
        output = OUTPUT_COMMANDS / f"{command_name}.md"
        output.write_text(rewrite(header + body + "\n", skill_names), encoding="utf-8")


def generate_agents(skill_names: dict[str, str]) -> None:
    if OUTPUT_AGENTS.exists():
        shutil.rmtree(OUTPUT_AGENTS)
    OUTPUT_AGENTS.mkdir(parents=True)
    for source in sorted((ROOT / "config" / "agents").glob("*.md")):
        text = source.read_text(encoding="utf-8")
        text = re.sub(
            r"tools:\s*(.*)",
            lambda match: "tools: "
            + ", ".join(
                dict.fromkeys(
                    [
                        *(
                            {
                                "Read": "read",
                                "Edit": "edit",
                                "Write": "write",
                                "Bash": "bash",
                                "Glob": "glob",
                                "Grep": "grep",
                                "WebSearch": "web_search",
                                "WebFetch": "browser",
                            }.get(item.strip(), item.strip().lower())
                            for item in match.group(1).split(",")
                        ),
                        "task",
                    ]
                )
            ),
            text,
            count=1,
        )
        text = text.replace("the Agent tool", "the task tool")
        (OUTPUT_AGENTS / source.name).write_text(rewrite(text, skill_names), encoding="utf-8")


def generate_rules(skill_names: dict[str, str]) -> None:
    OUTPUT_RULES.mkdir(parents=True, exist_ok=True)
    source = ROOT / "instructions" / "core.md"
    original = source.read_text(encoding="utf-8")
    marker = "## Execution Protocol"
    text = (
        "# saki-builder OMP rules\n\n"
        "This is the standing operating protocol every saki-builder OMP session inherits. "
        "Detailed references are available through the `saki-builder-runtime` skill.\n\n"
        + original[original.index(marker) :]
    )
    text = text.replace("@~/.claude/memory/patterns.md", "Use the host's configured memory when available.")
    (OUTPUT_RULES / "saki-builder.md").write_text(rewrite(text, skill_names), encoding="utf-8")


def main() -> None:
    skill_names = copy_skill_sources()
    rewrite_tree(OUTPUT_SKILLS, skill_names)
    write_omp_specific_skills()
    generate_commands(skill_names)
    generate_agents(skill_names)
    generate_rules(skill_names)
    print(
        f"OMP bundle generated: {len(list(OUTPUT_SKILLS.glob('*')))} skills, "
        f"{len(list(OUTPUT_COMMANDS.glob('*.md')))} commands, "
        f"{len(list(OUTPUT_AGENTS.glob('*.md')))} agents"
    )


if __name__ == "__main__":
    main()
