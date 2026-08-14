#!/usr/bin/env python3
# Shared by build-opencode.sh's global and --project passes: convert a Claude subagent def to
# opencode's format (inject `mode: subagent`, drop `tools:`, map colors). Kept in ONE file so the
# two passes cannot drift — the whole point of this generator.
# Reads OPENCODE_AGENT_SRC/DST, or argv[1]/argv[2].
import re, sys
import os
src = os.environ.get("OPENCODE_AGENT_SRC") or sys.argv[1]
dst = os.environ.get("OPENCODE_AGENT_DST") or sys.argv[2]
lines = open(src, encoding="utf-8").read().splitlines(keepends=True)

# Map Claude Code named colors -> OpenCode valid values (semantic or hex)
COLOR_MAP = {
    "yellow": "warning", "orange": "warning",
    "blue": "info",   "cyan": "info",
    "green": "success",
    "red": "error",   "pink": "error",
    "purple": "accent", "violet": "accent",
}

def transform_fm_line(line):
    # Drop tools: entirely — OpenCode schema expects object|undefined, not a CSV string
    if re.match(r'^\s*tools\s*:', line):
        return None
    # Map color: <name> -> OpenCode valid semantic color
    m = re.match(r'^(\s*color\s*:\s*)(\S+)\s*$', line)
    if m:
        val = m.group(2).strip('"\'')
        mapped = COLOR_MAP.get(val.lower())
        if mapped:
            return f"{m.group(1)}{mapped}\n"
    return line

if lines and lines[0].strip() == "---":
    end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if end:
        fm_lines = lines[1:end]
        new_fm = [transform_fm_line(l) for l in fm_lines]
        new_fm = [l for l in new_fm if l is not None]
        if not any(l.strip().startswith("mode:") for l in new_fm):
            new_fm.insert(0, "mode: subagent\n")
        lines = ["---\n"] + new_fm + lines[end:]
    else:
        if not any(l.strip().startswith("mode:") for l in lines[1:]):
            lines.insert(1, "mode: subagent\n")
else:
    lines = ["---\nmode: subagent\n---\n"] + lines
open(dst, "w", encoding="utf-8").write("".join(lines))
