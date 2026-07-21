# Graphify — How saki-builder Skills Use the Knowledge Graph

Source: https://graphify.net/knowledge-graph-for-ai-coding-assistants.html
        https://graphify.net/graphify-cli-commands.html
        https://graphify.net/graphify-claude-code-integration.html

## The one rule

**Read `graphify-out/GRAPH_REPORT.md` before any Grep/Glob/file-read.**
Graph traversal costs ~1.7k tokens; reading raw files costs ~123k (71.5× cheaper).

---

## Standard block (paste into any skill that reads code)

```markdown
**Graph-first reading (additive — before any file reads):**

```bash
cat graphify-out/GRAPH_REPORT.md 2>/dev/null || true
```

The report contains:
- **God nodes** — highest-degree hub concepts everything routes through. These are load-bearing
  anchors. A change touching a god node ripples further than it looks.
- **Communities** — Leiden clusters = bounded context candidates. Group your file reads by
  community: files in the same community are tightly coupled.
- **Surprising connections** — ranked cross-file/cross-modal edges, each with a plain-English
  _why_. These are the hidden couplings that file-read alone misses.
- **Rationale nodes** — design decisions extracted from docstrings and `# NOTE:`/`# WHY:`
  comments, attached as `rationale_for` edges.
- **Edge provenance** — every edge is tagged `EXTRACTED`, `INFERRED`, or `AMBIGUOUS` with a
  confidence score. Trust EXTRACTED; flag INFERRED when citing.

For targeted traversal after reading the report:
```bash
graphify query "<question>"            # BFS — broad context, good for "what does X do?"
graphify query "<question>" --dfs      # DFS — trace a specific call path
graphify query "<question>" --budget 1500   # cap answer at N tokens
graphify path "NodeA" "NodeB"          # shortest hop-by-hop path, edge type + confidence
graphify explain "NodeName"            # everything graphify knows about one node
```

Pattern: **GRAPH_REPORT.md → targeted query → then read files.** Never grep first.
Skip silently if `graphify-out/GRAPH_REPORT.md` is absent.
Build the graph once: `/saki-builder:graphify .` (also installs always-on PreToolUse hook).
```

---

## CLI command reference

### Build
```bash
graphify .                      # current directory
graphify ./src                  # specific folder
graphify https://github.com/org/repo  # clone + build
graphify . --mode deep          # more aggressive INFERRED edges
graphify . --update             # re-extract changed files only
graphify . --cluster-only       # rerun clustering, no re-extraction
graphify . --no-viz             # skip HTML, JSON + report only
graphify . --watch              # auto-rebuild on file changes
```

### Query
```bash
graphify query "what connects auth to the DB?"
graphify query "trace the payment flow" --dfs
graphify query "..." --budget 1500
graphify path "AuthService" "Database"
graphify explain "OrderProcessor"
```

### Keep fresh
```bash
graphify hook install           # post-commit + post-checkout auto-rebuild
graphify hook status
```

### Claude Code always-on (run once per project)
```bash
graphify claude install         # writes CLAUDE.md section + PreToolUse hook in settings.json
```
The PreToolUse hook fires before every Glob and Grep call:
> "graphify: Knowledge graph exists. Read GRAPH_REPORT.md for god nodes and community structure
> before searching raw files."

---

## Graph output schema (what graph.json contains)

```
nodes[]:
  id            string   — fully-qualified node identifier (file::ClassName::method)
  label         string   — human-readable name
  community     int      — Leiden cluster id
  betweenness   float    — centrality score (higher = more load-bearing)
  type          string   — class | function | module | concept | rationale | ...
  source_file   string   — file path (for file-read citations)

edges[]:
  source        string   — node id
  target        string   — node id
  relation      string   — calls | imports | rationale_for | semantically_similar_to | ...
  provenance    string   — EXTRACTED | INFERRED | AMBIGUOUS
  confidence    float    — 0.0–1.0

hyperedges[]:
  nodes[]       string[] — 3+ node ids (e.g. all classes implementing a shared protocol)
  relation      string
```

---

## When to use what

| Question | Command |
|----------|---------|
| "What are the critical components?" | Read GRAPH_REPORT.md god nodes section |
| "What bounded contexts exist?" | Read GRAPH_REPORT.md communities section |
| "How does feature X work broadly?" | `graphify query "how does X work?"` |
| "Does ServiceA actually call ServiceB?" | `graphify path "ServiceA" "ServiceB"` |
| "What does this class do?" | `graphify explain "ClassName"` |
| "Find hidden coupling in this slice" | `graphify query "what does SliceModule depend on?" --dfs` |
| "Is this a high-risk component?" | Check GRAPH_REPORT.md god nodes; `betweenness > 0.05` = high risk |
