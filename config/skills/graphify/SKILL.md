---
name: graphify
description: Build or query a knowledge graph of the current project. Self-contained — works without the global /graphify skill. Auto-installs graphifyy if missing. Enriches rplan research and arch-check with god nodes, community clusters, and path traces. Usage — /saki-builder:graphify [path|url|query] [flags]
type: analysis
user-invocable: true
---

# /saki-builder:graphify

Turns any project into a queryable knowledge graph. Self-contained: runs the graphify CLI
directly after install — does NOT require the global `/graphify` skill.

---

## Step 0 — Detect and install (always run first)

```bash
# Resolve the correct Python interpreter
PYTHON=""
GRAPHIFY_BIN=$(which graphify 2>/dev/null)

# 1. uv tool install path
if command -v uv >/dev/null 2>&1; then
    _UV_PY=$(uv tool run --from graphifyy python -c "import sys; print(sys.executable)" 2>/dev/null)
    [ -n "$_UV_PY" ] && PYTHON="$_UV_PY"
fi
# 2. Shebang from the graphify binary (pipx / direct pip)
if [ -z "$PYTHON" ] && [ -n "$GRAPHIFY_BIN" ]; then
    _SHEBANG=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
    case "$_SHEBANG" in
        *[!a-zA-Z0-9/_.@-]*) ;;
        *) "$_SHEBANG" -c "import graphify" 2>/dev/null && PYTHON="$_SHEBANG" ;;
    esac
fi
# 3. Fallback
[ -z "$PYTHON" ] && PYTHON="python3"

# Install if not importable
if ! "$PYTHON" -c "import graphify" 2>/dev/null; then
    echo "graphifyy not found — installing..."
    if command -v uv >/dev/null 2>&1; then
        uv tool install --upgrade graphifyy -q
        _UV_PY=$(uv tool run --from graphifyy python -c "import sys; print(sys.executable)" 2>/dev/null)
        [ -n "$_UV_PY" ] && PYTHON="$_UV_PY"
    else
        "$PYTHON" -m pip install graphifyy -q 2>/dev/null || \
            "$PYTHON" -m pip install graphifyy -q --break-system-packages
    fi
fi

# Verify
if ! "$PYTHON" -c "import graphify" 2>/dev/null; then
    echo "ERROR: graphifyy install failed."
    echo "Fix: run 'uv tool install graphifyy' or 'pip install graphifyy', then retry."
    exit 1
fi

# Write interpreter path — downstream skills read this
mkdir -p graphify-out
"$PYTHON" -c "import sys; open('graphify-out/.graphify_python','w',encoding='utf-8').write(sys.executable)"
echo "graphify ready: $PYTHON"
```

---

## Step 1 — Run the pipeline (CLI-first, no global skill required)

After install, run the graphify CLI directly. It handles the full pipeline (detect → extract → cluster → HTML + JSON + GRAPH_REPORT.md) without needing the global `~/.claude/skills/graphify/SKILL.md`.

**Build graph on a local path or GitHub URL:**
```bash
graphify [path|https://github.com/<owner>/<repo>] [flags]
# Examples:
graphify .                          # current directory
graphify ./src                      # subdirectory
graphify https://github.com/org/repo
```

**Common flags** (pass any the user provided):
```
--mode deep        richer semantic extraction
--update           incremental — only changed files
--cluster-only     rerun clustering on existing graph
--no-viz           skip HTML, just JSON + report
--directed         preserve edge direction
--svg / --graphml  additional export formats
--neo4j            generate Cypher for Neo4j
```

**Query an existing graph** (never rebuild):
```bash
graphify query "<question>"
graphify path "ModuleA" "ModuleB"
graphify explain "SomeNode"
```

### When the global skill IS installed (enhancement, not required)

If `~/.claude/skills/graphify/SKILL.md` exists, prefer it for corpora with **docs, papers, or images**
— it dispatches parallel Claude subagents for semantic extraction, which is 5–10× faster than the
CLI's sequential mode. Check and delegate:

```bash
GLOBAL_SKILL="$HOME/.claude/skills/graphify/SKILL.md"
if [ -f "$GLOBAL_SKILL" ]; then
    echo "Global /graphify skill found — using it for richer semantic extraction."
    # Signal to the model: invoke the global /graphify skill with all user args
else
    echo "Global /graphify skill not found — using CLI (good for code repos; install the Graphify global skill for doc/paper/image corpora)."
    # Continue with CLI path above
fi
```

For **code-only repos** (the common saki-builder case), the CLI and the global skill produce
equivalent graphs — use the CLI regardless.

---

## Step 1.5 — Wire the always-on Claude Code hook

After the pipeline completes, run:

```bash
graphify claude install
```

This does two things (idempotent — safe to re-run):
1. Writes a `CLAUDE.md` section telling Claude to read `graphify-out/GRAPH_REPORT.md` before
   answering architecture questions.
2. Installs a `PreToolUse` hook in `settings.json` that fires before every `Glob` and `Grep`
   call — Claude sees: *"graphify: Knowledge graph exists. Read GRAPH_REPORT.md for god nodes
   and community structure before searching raw files."*

From this point, every `/rplan`, `/prd`, `/prd-review`, `/rplan-review`, and `/arch-check`
invocation picks up the graph automatically — no explicit steps needed.

---

## Step 2 — Confirm outputs

After the pipeline, tell the user:

```
Graph complete. Outputs in graphify-out/
  graph.html         open in browser
  GRAPH_REPORT.md    audit report (god nodes, communities, suggested questions)
  graph.json         raw graph data (queried by /rplan and /arch-check)
```

Then paste the **God Nodes**, **Surprising Connections**, and **Suggested Questions** sections
from `graphify-out/GRAPH_REPORT.md` directly into chat. Do NOT paste the full report.

Offer the saki-builder-specific follow-up:
> "Graph ready. Run `/saki-builder:arch-check` to cross-reference god nodes with module size triggers?"

---

## saki-builder Integration (how other skills use this)

### Called by `/rplan` (research enrichment)
```bash
# /rplan checks this before file reads:
[ -f graphify-out/.graphify_python ] && [ -f graphify-out/graph.json ] || exit 0
graphify query "<task scope in one sentence>"
```

### Called by `/arch-check` (Step 2.5)
```bash
# Reads god nodes + community clusters from graph.json
$(cat graphify-out/.graphify_python) -c "
import json
from pathlib import Path
g = json.loads(Path('graphify-out/graph.json').read_text())
nodes = sorted(g['nodes'], key=lambda n: n.get('betweenness', 0), reverse=True)
for n in nodes[:8]:
    print(f\"{n['id']:60s}  betweenness={n.get('betweenness',0):.4f}\")
"
```

Both skills are **additive only** — they skip silently if `graphify-out/graph.json` is absent.
The user builds the graph once with `/saki-builder:graphify .` and all skills pick it up.

---

## Honesty Rules

- Never invent a node, edge, or betweenness score.
- If the CLI errors, show the raw error — do not fabricate a graph.
- Token cost from semantic extraction appears in `GRAPH_REPORT.md`; surface it when non-zero.
- A `GRAPH HEALTH WARNING` from the CLI must be shown to the user, not suppressed.
