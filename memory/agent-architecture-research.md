# Agent Architecture Deep Research

Comprehensive research on AI agent architectures, patterns, and best practices.
Based on: Anthropic's published work, Claude Agent SDK, LangGraph, industry research 2025-2026, and OneIntel codebase analysis.

---

## 1. Anthropic's Agent Design Philosophy

### "Building Effective Agents" (Anthropic, Dec 2024)

Core thesis: **"The most successful agent implementations use simple, composable patterns — not complex frameworks."**

### The Simplicity Principle
1. Start with **augmented LLM** (model + tools + retrieval) — not multi-agent
2. Add complexity **only when measured improvement** justifies it
3. Use frameworks for convenience, not as a crutch
4. **Agents are just LLMs in loops** — an "agent" is an LLM that calls tools in a loop until it decides it's done

### Workflows vs Agents — Critical Distinction

| | Workflows | Agents |
|---|----------|--------|
| **Control** | Predefined orchestration paths | Dynamic LLM-directed decisions |
| **When** | Predictable, repeatable tasks | Open-ended, complex reasoning |
| **Example** | "Always: extract → validate → store" | "Figure out how to solve this" |
| **OneIntel** | LangGraph engine | AGI engine |
| **Trade-off** | Predictable but rigid | Flexible but less deterministic |

### Anthropic's Pattern Hierarchy (Build Up, Don't Start Complex)

```
┌─────────────────────────────────────────────────┐
│ Level 5: Fully Autonomous Agent                  │
│   Open-ended tool loop, self-directed planning   │
├─────────────────────────────────────────────────┤
│ Level 4: Evaluator-Optimizer                     │
│   Generate → Evaluate → Refine loop             │
├─────────────────────────────────────────────────┤
│ Level 3: Orchestrator-Workers                    │
│   Dynamic planning + delegation                  │
├─────────────────────────────────────────────────┤
│ Level 2: Parallelization                         │
│   Fan-out to multiple workers, aggregate         │
├─────────────────────────────────────────────────┤
│ Level 1: Routing                                 │
│   Classify → delegate to specialized handler     │
├─────────────────────────────────────────────────┤
│ Level 0: Prompt Chaining                         │
│   Sequential LLM calls, each step defined        │
├─────────────────────────────────────────────────┤
│ Foundation: Augmented LLM                        │
│   Single model + tools + retrieval               │
└─────────────────────────────────────────────────┘
```

**Key insight**: Most production use cases need Level 0-2. Only reach for Level 3+ when simpler patterns fail.

---

## 2. The Agent Loop (Core Pattern)

### Anthropic's Canonical Agent Loop

```
while not done:
    1. OBSERVE  — Read context (messages, tool results, memory)
    2. THINK    — LLM reasons about what to do next
    3. ACT      — Execute tool call OR generate response
    4. OBSERVE  — Read tool result, update context

    If LLM generates response without tool call → done
```

This is the **universal pattern** across all agent frameworks. Everything else is orchestration around this loop.

### Claude Agent SDK Implementation

```python
# Simplified Claude Agent SDK pattern
agent = Agent(
    model="claude-opus-4-6",
    tools=[tool1, tool2, tool3],
    system_prompt="You are a helpful assistant...",
    max_turns=10,
)

# The SDK runs the agent loop internally:
result = agent.run("Solve this problem")
# Internally: LLM call → tool use → LLM call → ... → final response
```

**Key features:**
- Automatic tool loop management
- Structured output support
- Guardrail hooks (input/output validators)
- Multi-agent handoff via `transfer_to_agent` tool
- MCP server integration for tool discovery
- Streaming support for real-time output

### Tool Descriptions Are Critical

Anthropic emphasizes: **Tool descriptions are more important than system prompts for agent behavior.**

Good tool description:
```json
{
  "name": "search_knowledge_base",
  "description": "Search the company knowledge base for information. Use this when the user asks about products, policies, or procedures. Returns relevant document chunks with source citations. Prefer this over guessing answers.",
  "parameters": {
    "query": "Natural language search query. Be specific - include key terms from the user's question.",
    "filters": "Optional metadata filters: {department, date_range, doc_type}"
  }
}
```

Bad tool description:
```json
{
  "name": "search",
  "description": "Searches documents",
  "parameters": {"q": "query string"}
}
```

---

## 3. Agent Architecture Patterns

### Pattern 1: Prompt Chaining (Sequential Pipeline)

```
Input → [LLM Step 1] → [Gate/Check] → [LLM Step 2] → [Gate/Check] → Output
```

- Each step has a focused task with its own prompt
- Gates between steps validate output quality
- **When**: Multi-step tasks where each step is well-defined
- **Example**: Extract entities → Validate entities → Generate report
- **OneIntel mapping**: LangGraph engine linear workflows

### Pattern 2: Routing (Classify → Delegate)

```
Input → [Classifier LLM] → Route A: [Specialized Handler A]
                          → Route B: [Specialized Handler B]
                          → Route C: [Specialized Handler C]
```

- Lightweight classifier selects the right handler
- Each handler optimized for its task type
- **When**: Distinct categories of inputs needing different treatment
- **Example**: Support ticket → {billing, technical, general}
- **OneIntel mapping**: AGI engine router teams, LangGraph router nodes

### Pattern 3: Parallelization (Fan-Out / Fan-In)

```
Input → [Decompose] → [Worker 1] ─┐
                    → [Worker 2] ─┼→ [Aggregate] → Output
                    → [Worker 3] ─┘
```

Two sub-patterns:
- **Sectioning**: Split task into independent subtasks, parallelize
- **Voting**: Run same task N times, aggregate (majority vote, best-of-N)
- **When**: Tasks decomposable into independent parts, or need reliability
- **OneIntel mapping**: AGI engine fan-out strategy

### Pattern 4: Orchestrator-Workers (Dynamic Planning)

```
Input → [Orchestrator LLM] → Plan: [Step 1, Step 2, Step 3]
                            → Execute Step 1 → [Worker]
                            → Evaluate → Replan if needed
                            → Execute Step 2 → [Worker]
                            → ...
                            → Synthesize → Output
```

- Orchestrator creates and revises plan dynamically
- Workers are specialized executors
- Plan can adapt based on intermediate results
- **When**: Complex tasks where steps aren't known in advance
- **Example**: Research → Analyze → Write report (steps emerge from research)
- **OneIntel mapping**: AGI engine plan-execute-reflect loop

### Pattern 5: Evaluator-Optimizer (Generate → Critique → Refine)

```
[Generator LLM] → Draft
       ↓
[Evaluator LLM] → Feedback (score + specific improvements)
       ↓
[Generator LLM] → Revised Draft
       ↓
[Evaluator LLM] → Feedback
       ↓
... (until quality threshold met)
```

- Separate generation from evaluation
- Evaluator provides actionable, specific feedback
- **When**: Output quality is critical and measurable
- **Example**: Code generation → code review → fix issues → re-review
- **OneIntel mapping**: AGI engine reflection phase (partial)

### Pattern 6: Multi-Agent Debate

```
[Agent A: Pro] → Argument
[Agent B: Con] → Counter-argument
[Agent A] → Rebuttal
[Agent B] → Rebuttal
[Judge] → Synthesis / Decision
```

- Adversarial agents expose blind spots
- Judge synthesizes balanced conclusion
- **When**: Decisions with trade-offs, risk assessment, controversial topics
- **OneIntel mapping**: AGI engine debate strategy

---

## 4. Memory Architecture

### Memory Types for Agents

| Type | Scope | Storage | Use Case |
|------|-------|---------|----------|
| **Conversation** | Single session | In-memory / DB | Current chat context |
| **Working Memory** | Single task | Scratchpad dict | Intermediate reasoning |
| **Episodic** | Cross-session | Vector DB | "Last time user asked X, I did Y" |
| **Semantic** | Global | Vector DB + KG | Domain knowledge, facts |
| **Procedural** | Global | Skill store | "How to do X" (learned sequences) |

### Conversation Memory Management

Problem: Context windows are finite. Long conversations overflow.

Strategies:
1. **Sliding window**: Keep last N messages (simple, loses early context)
2. **Summarization**: Periodically summarize older messages (preserves intent, loses detail)
3. **Hierarchical**: Recent messages verbatim + summaries for older + key facts extracted
4. **Selective**: Keep only messages relevant to current topic (requires relevance scoring)

**Anthropic's recommendation**: Summarization + key fact extraction is the sweet spot.

### Long-Term Memory Architecture

```
┌─────────────────────────────────────────┐
│           Agent Memory System            │
├──────────┬──────────┬───────────────────┤
│ Episodic │ Semantic │ Procedural        │
│ (events) │ (facts)  │ (skills)          │
├──────────┼──────────┼───────────────────┤
│ Vector   │ Vector + │ Structured        │
│ Store    │ KG       │ Templates         │
│ (Qdrant) │ (Neo4j)  │ (DB)              │
└──────────┴──────────┴───────────────────┘
```

**Episodic memory** (what OneIntel AGI engine already has):
- Store: "Task X succeeded with approach Y, context was Z"
- Retrieve: "What approach worked for similar tasks?"
- Learn: Weight successful episodes higher

**Semantic memory** (facts + relationships):
- Store: "Customer prefers email, works at Company X"
- Retrieve: Inject relevant facts into context
- Update: Overwrite stale facts with new information

**Procedural memory** (learned skills):
- Store: "To book a flight: search → select → confirm → email receipt"
- Retrieve: When similar task detected, recall proven sequence
- Refine: Improve sequences based on outcomes

---

## 5. Multi-Agent Orchestration Patterns

### Pattern A: Supervisor (Hub-and-Spoke)

```
        [Supervisor]
       /     |      \
   [Agent1] [Agent2] [Agent3]
```

- Supervisor decides who works on what
- Workers report back to supervisor
- Supervisor synthesizes final answer
- **Pros**: Clear control, easy to debug
- **Cons**: Supervisor is bottleneck, single point of failure

### Pattern B: Peer-to-Peer (Mesh)

```
   [Agent1] ←→ [Agent2]
      ↕            ↕
   [Agent3] ←→ [Agent4]
```

- Agents communicate directly
- No central coordinator
- **Pros**: No bottleneck, resilient
- **Cons**: Hard to debug, potential loops, coordination overhead

### Pattern C: Pipeline (Assembly Line)

```
[Agent1] → [Agent2] → [Agent3] → Output
```

- Each agent handles one phase
- Output of one is input to next
- **Pros**: Simple, predictable, specialized agents
- **Cons**: Sequential (slow), fragile if one stage fails

### Pattern D: Hierarchical (Tree)

```
         [Manager]
        /         \
   [Lead A]     [Lead B]
   /     \       /     \
[W1]   [W2]  [W3]   [W4]
```

- Multi-level delegation
- Each level has limited scope
- **Pros**: Scales to complex organizations
- **Cons**: Latency, lost context at each level

### Inter-Agent Communication

| Method | How | When |
|--------|-----|------|
| **Tool call** | Agent A calls "transfer_to_agent_B" | Simple handoff |
| **Shared state** | All agents read/write to shared dict | Collaborative editing |
| **Message queue** | Async pub/sub between agents | Event-driven, decoupled |
| **Blackboard** | Central knowledge store all agents access | Research, analysis |

**Anthropic's recommendation**: Start with **tool-based handoff** (simplest). Only add shared state or message queues when handoff is insufficient.

---

## 6. Agent Safety & Guardrails

### Anthropic's Safety Layers

```
┌────────────────────────────────────────┐
│ Layer 1: Input Validation               │
│   - Prompt injection detection          │
│   - Content policy check                │
│   - Rate limiting                       │
├────────────────────────────────────────┤
│ Layer 2: Tool Permission System         │
│   - Tool allowlists per agent           │
│   - Parameter validation                │
│   - Approval gates for high-risk tools  │
├────────────────────────────────────────┤
│ Layer 3: Execution Sandboxing           │
│   - Resource limits (time, memory)      │
│   - Network isolation                   │
│   - File system restrictions            │
├────────────────────────────────────────┤
│ Layer 4: Output Validation              │
│   - Content policy check                │
│   - Hallucination detection             │
│   - PII/sensitive data filtering        │
├────────────────────────────────────────┤
│ Layer 5: Monitoring & Audit             │
│   - Token/cost tracking                 │
│   - Tool call logging                   │
│   - Anomaly detection                   │
│   - Human escalation triggers           │
└────────────────────────────────────────┘
```

### Tool Risk Classification (Best Practice)

| Tier | Risk | Examples | Policy |
|------|------|----------|--------|
| **Low** | Read-only | Search, retrieve, calculate | Auto-approve |
| **Medium** | Side effects | Send email, create ticket | Log + rate limit |
| **High** | Destructive/costly | Delete data, make payment | Human approval required |
| **Critical** | Irreversible | Deploy code, transfer funds | Multi-approval + audit |

### Budget Controls
- **Token budget**: Max tokens per task/session
- **Cost budget**: Max USD per task/session
- **Time budget**: Max wall-clock time per task
- **Tool call budget**: Max tool calls per turn/task
- **Recursion limit**: Max depth for nested agent calls

---

## 7. Production Agent Patterns

### Streaming & Real-Time

```
User sends message
  ↓
Agent starts thinking (streaming tokens)
  ↓
Agent decides to call tool
  ↓ (stream pauses, show "thinking..." or tool status)
Tool executes
  ↓
Agent resumes streaming with tool result incorporated
  ↓
Final response complete
```

**Key**: Stream the LLM output in real-time, show tool execution status, resume streaming after tool results.

### Checkpointing & Resume

For long-running agent tasks:
1. Checkpoint state after each significant step
2. If interrupted → resume from last checkpoint
3. Store: conversation history, tool results, partial outputs, plan state

**LangGraph approach**: Built-in checkpointing via `MemorySaver` or persistent backends (Redis, PostgreSQL).

### Observability & Tracing

Essential for production agents:

```
Trace: user_request_123
  ├── Span: classify_intent (45ms)
  ├── Span: retrieve_context (120ms)
  │   ├── Span: embed_query (30ms)
  │   ├── Span: vector_search (50ms)
  │   └── Span: rerank (40ms)
  ├── Span: generate_response (850ms)
  │   ├── Span: llm_call_1 (400ms) → tool_call
  │   ├── Span: execute_tool (200ms)
  │   └── Span: llm_call_2 (250ms) → final_response
  └── Span: post_process (30ms)
```

Tools: LangSmith, Langfuse, Arize Phoenix, OpenTelemetry

### Error Recovery Patterns

| Error Type | Strategy |
|-----------|----------|
| Tool timeout | Retry with backoff (max 3) |
| Tool error (transient) | Retry once, then inform LLM |
| Tool error (permanent) | Inform LLM, let it try alternative |
| LLM rate limit | Exponential backoff |
| LLM context overflow | Summarize history, retry |
| Agent loop (>N iterations) | Force stop, summarize progress |
| Hallucination detected | Re-generate with stronger grounding |

### Context Window Management

| Strategy | When | How |
|----------|------|-----|
| **Truncation** | Simple chats | Drop oldest messages |
| **Summarization** | Long conversations | Summarize older messages periodically |
| **RAG over history** | Very long histories | Embed messages, retrieve relevant ones |
| **Hierarchical** | Production | Recent (verbatim) + Summary (older) + Facts (extracted) |
| **Sliding window + anchor** | Complex tasks | Keep system prompt + last N + key earlier messages |

---

## 8. LangGraph Architecture (Relevant to OneIntel)

### Core Concepts

```
StateGraph:
  - State: TypedDict defining all shared state
  - Nodes: Functions that read/write state
  - Edges: Connections between nodes (conditional or fixed)
  - Entry point: Starting node
  - Checkpointer: State persistence

Execution:
  State → Node A → Updated State → Conditional Edge → Node B or C → ...
```

### LangGraph Patterns

1. **ReAct Agent**: Reason → Act → Observe loop (built-in)
2. **Plan-and-Execute**: Planner node → Executor node → Replanner (if needed)
3. **Reflection**: Generator → Critic → Generator (loop until quality met)
4. **Multi-Agent**: Supervisor node routes to worker nodes
5. **Map-Reduce**: Fan-out to parallel workers → aggregate results
6. **Human-in-the-Loop**: Interrupt node → wait for human input → resume

### LangGraph vs Raw Agent Loop

| Feature | Raw Loop | LangGraph |
|---------|----------|-----------|
| State management | Manual | Built-in TypedDict |
| Checkpointing | Manual | Built-in MemorySaver |
| Branching | If/else | Conditional edges |
| Parallelism | Threading | Built-in fan-out |
| Human-in-loop | Custom | Built-in interrupt |
| Visualization | None | Graph rendering |
| Streaming | Custom | Built-in event stream |

---

## 9. Model Context Protocol (MCP)

### Architecture

```
┌──────────┐    MCP Protocol    ┌──────────────┐
│  Client   │ ←───────────────→ │  MCP Server   │
│ (Agent)   │   JSON-RPC 2.0   │  (Tool Host)  │
└──────────┘                    └──────────────┘
```

### MCP Primitives

| Primitive | Direction | Purpose |
|-----------|-----------|---------|
| **Tools** | Server → Client | Functions the agent can call |
| **Resources** | Server → Client | Data/context the agent can read |
| **Prompts** | Server → Client | Pre-built prompt templates |
| **Sampling** | Client → Server | Server can request LLM completions |

### Transport Options
- **stdio**: Local process communication (fastest)
- **SSE**: Server-Sent Events over HTTP (remote, one-way streaming)
- **Streamable HTTP**: Full bidirectional HTTP streaming (newest, recommended for remote)

### MCP Benefits for Agent Architecture
1. **Standardized tool interface**: One protocol for all tool integrations
2. **Dynamic tool discovery**: Agent discovers available tools at runtime
3. **Tool composition**: Chain MCP servers for complex capabilities
4. **Security**: Per-server authorization, tool-level permissions
5. **Portability**: Same tools work across different agent frameworks

---

## 10. OneIntel Agent Architecture — Current State & Analysis

### Three-Engine Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Agent Orchestration                     │
├──────────────┬──────────────────┬────────────────────────┤
│   PARLANT    │    LANGGRAPH     │       AGI              │
│  Guidelines  │  Workflow DAG    │  Goal-Directed         │
│  WHEN/THEN   │  Node execution  │  Plan-Execute-Reflect  │
│              │  Conditional     │  Memory + Learning     │
│  Best for:   │  Best for:       │  Best for:             │
│  Support     │  Business        │  Research,             │
│  agents      │  processes       │  Analysis              │
├──────────────┴──────────────────┴────────────────────────┤
│               Shared Infrastructure                       │
│  MCP Gateway │ RAG Pipeline │ LLM Router │ Intelligence  │
│  Tool Exec   │ Retrieval    │ Provider   │ Dispatcher    │
│              │ Embedding    │ Selection  │ Memory/Profile│
└─────────────────────────────────────────────────────────┘
```

### What's Well-Architected

1. **Engine abstraction** (BaseEngine interface) — clean swappability
2. **Intelligence pre/post hooks** — decouple memory/learning from core engine
3. **MCP gateway** — unified tool interface across all engines
4. **Team orchestration** — supervisor/fan-out/debate strategies
5. **Handover system** — virtual tools for seamless agent→human transfer
6. **AGI guardrails** — cost/token/rate/tool-tier limits
7. **Execution tracking** (LangGraph) — node-by-node debugging
8. **Learned knowledge** — episodic memory + skill extraction

### Critical Gaps vs Best Practices

| # | Gap | Anthropic Best Practice | Impact |
|---|-----|------------------------|--------|
| 1 | **Tool loop is duplicated** across 3 engines | Single tool execution layer | HIGH — bugs fix 3x, auth inconsistent |
| 2 | **No structured output** support | Claude's tool_use for structured responses | MEDIUM — validation, type safety |
| 3 | **No evaluator-optimizer pattern** | Generate → evaluate → refine loop | MEDIUM — quality improvement |
| 4 | **Inconsistent state management** | Unified state schema across engines | MEDIUM — multi-engine composition |
| 5 | **No streaming for AGI** | Stream intermediate steps | MEDIUM — UX for long tasks |
| 6 | **No checkpointing** for long AGI tasks | Resume from last checkpoint | MEDIUM — reliability |
| 7 | **No observability/tracing** | OpenTelemetry spans per step | HIGH — debugging in production |
| 8 | **Error recovery is basic** | Retry backoff, circuit breaker, fallback | MEDIUM — resilience |
| 9 | **Episodic memory has no importance ranking** | Weight episodes by outcome quality | LOW — learning efficiency |
| 10 | **No agent evaluation framework** | Task completion metrics, tool efficiency | HIGH — can't measure improvement |
| 11 | **Config explosion** (JSON blobs) | Dedicated models for workflow/handover | MEDIUM — maintenance burden |
| 12 | **MCP connections in-memory only** | Persistent connection management | MEDIUM — server restart loses tools |

### Recommended Architecture Improvements

**Phase 1 — Foundation (1-2 weeks)**
- [ ] Extract common `ToolExecutor` class from all 3 engines
- [ ] Add retry backoff + circuit breaker to tool execution
- [ ] Unify session state schema across engines
- [ ] Add OpenTelemetry tracing (spans for each engine step)

**Phase 2 — Quality (3-4 weeks)**
- [ ] Add evaluator-optimizer loop (generate → score → refine if score < threshold)
- [ ] Implement streaming for AGI engine intermediate steps
- [ ] Add checkpointing for AGI tasks (resume after crash)
- [ ] Build agent evaluation pipeline (task completion, tool efficiency, response quality)
- [ ] Add structured output support (JSON schema validation)

**Phase 3 — Scale (1-2 months)**
- [ ] Persistent MCP connection management (reconnect on restart)
- [ ] Add agent versioning (A/B test different configs)
- [ ] Build comprehensive observability dashboard (traces, costs, quality)
- [ ] Implement advanced memory: importance ranking, memory consolidation, forgetting
- [ ] Add cross-engine composition (Parlant for chat → LangGraph for workflow → Parlant for response)

---

## 11. Agent Evaluation

### Task-Level Metrics

| Metric | What | How |
|--------|------|-----|
| **Task completion rate** | Did the agent achieve the goal? | LLM-as-judge or human review |
| **Tool efficiency** | Min tool calls to achieve goal? | Count tool calls vs optimal |
| **Response quality** | Accurate, helpful, safe? | RAGAS-style metrics |
| **Latency** | Time to complete task | Wall-clock measurement |
| **Cost** | Tokens + tool calls cost | Token counting + API costs |
| **User satisfaction** | Did the user like it? | Thumbs up/down, NPS |

### Benchmarks

| Benchmark | Tests | Best For |
|-----------|-------|----------|
| **SWE-bench** | Code generation + testing | Coding agents |
| **GAIA** | General AI assistants | Multi-step reasoning |
| **WebArena** | Web browsing tasks | Browser agents |
| **ToolBench** | Tool use across APIs | Tool-calling agents |
| **AgentBench** | Multi-domain tasks | General agents |

### Evaluation Pipeline (Recommended for OneIntel)

```
1. Define test cases: {input, expected_behavior, ground_truth}
2. Run agent on test cases
3. Score each response:
   - Correctness (vs ground truth)
   - Faithfulness (grounded in retrieved context)
   - Tool use quality (right tools, right args)
   - Safety (no harmful content)
4. Aggregate metrics
5. Compare against baseline
6. Report regressions
```

---

## 12. Claude Agent SDK — Detailed Architecture

### Two Interaction Modes (Python)

| Feature | `query()` | `ClaudeSDKClient` |
|---|---|---|
| Session | Creates new each time | Reuses same session |
| Conversation | Single exchange | Multi-exchange with context |
| Interrupts | Not supported | Supported |
| Use case | One-off automation | Chat interfaces, follow-ups |

### Key Configuration Options

```python
ClaudeAgentOptions:
  system_prompt     # Custom or preset (e.g., 'claude_code')
  allowed_tools     # Tool allowlist
  disallowed_tools  # Tool denylist (checked first, overrides allows)
  permission_mode   # acceptEdits, bypassPermissions, etc.
  mcp_servers       # MCP server configurations
  agents            # Named sub-agent definitions with own tools/prompts
  max_turns         # Execution turn limit
  max_budget_usd    # Cost cap
  thinking          # adaptive/enabled/disabled + effort (low/medium/high/max)
  output_format     # Structured JSON schema outputs
  hooks             # Lifecycle callbacks (PreToolUse, PostToolUse, Stop)
  can_use_tool      # Custom per-tool permission callback
  enable_file_checkpointing  # Rewind/restore file changes
  sandbox           # Sandbox execution settings
```

### Sub-Agent Pattern
```python
agents={"code-reviewer": AgentDefinition(
    description="Expert code reviewer",
    prompt="Analyze code quality",
    tools=["Read", "Glob", "Grep"]
)}
```
- Sub-agents get fresh, isolated context windows
- Parent delegates via `Task` tool
- Sub-agent may consume 10K+ tokens internally but returns 1-2K token summary
- **Critical for context management** — prevents main agent's context from bloating

### Claude Code's Built-in Tools (14)
| Category | Tools |
|---|---|
| File ops | Read, Write, Edit, MultiEdit |
| Search | Glob, Grep |
| Execution | Bash |
| Web | WebSearch, WebFetch |
| Orchestration | Task (sub-agents), AskUserQuestion, TodoWrite |

### Context Window Management (Claude Code)
- **Auto-compaction** at ~92% context usage
- Clears older tool outputs first, then summarizes conversation
- Persistent rules in `CLAUDE.md` (always loaded, never compacted)
- `/compact` with focus directives preserves specific topics
- Sub-agents get fresh context (key isolation pattern)

---

## 13. Context Engineering for Agents

Anthropic's principle: **"Context engineering > prompt engineering"** — curating optimal tokens during inference matters more than crafting the perfect prompt.

### "Context Rot" Problem
- Model degradation with increased context length (n² attention)
- System prompts need "the right altitude" — specific enough to guide, flexible enough for heuristics

### Three Strategies for Long-Horizon Tasks

**1. Compaction**
Summarize conversation approaching limit. Preserve: architectural decisions, unresolved bugs, implementation details. Discard: redundant tool outputs, repetitive messages.

**2. Structured Note-Taking (Agentic Memory)**
Agents write persistent notes outside context window. Example: Claude playing Pokemon maintains strategic notes across thousands of game steps and context resets.

**3. Sub-Agent Architectures**
Main agent coordinates; specialized sub-agents handle focused tasks with clean context. Each may consume 10K+ tokens but returns condensed 1-2K summaries.

### Tool Design for Context Efficiency
- Self-contained, minimal functional overlap
- **"Just-In-Time" retrieval**: Lightweight identifiers loaded on demand vs pre-loading all data
- Hybrid pattern: CLAUDE.md loads upfront (persistent context), glob/grep for just-in-time file retrieval

---

## 14. Long-Running Agent Harness Patterns

### Two-Agent System
1. **Initializer Agent** — first session; sets up environment, creates plan
2. **Coding Agent** — subsequent sessions; incremental progress per feature

### Session Orientation Protocol
Each session starts by:
1. Read progress notes + git history
2. Run smoke tests
3. Select highest-priority incomplete feature
4. Work incrementally
5. Document and commit before close

### Error Recovery Patterns
| Problem | Solution |
|---------|----------|
| Premature completion | Enforce feature list; single-feature-per-session |
| Undocumented progress | Mandatory git commits + progress file updates |
| Incomplete testing | Browser automation (Puppeteer MCP) for e2e |
| Context init overhead | Guided startup checklist |

---

## 15. MCP Updates (Nov 2025 Specification)

### New Capabilities
- **Tasks**: Track long-running server work
- **Tool calling in sampling**: Servers include tool definitions in sampling requests
- **Server-side agent loops**: Multi-step reasoning within MCP servers
- **Parallel tool calls**: Concurrent execution support
- **Asynchronous operations**: Non-blocking patterns

### Governance (Dec 2025)
MCP donated to **Agentic AI Foundation (AAIF)** under Linux Foundation, co-founded by Anthropic, Block, and OpenAI. Industry standard with 97M+ monthly SDK downloads.

---

## 16. Key Architecture Principles (Consolidated)

1. **Start simple, add complexity only when measured improvement justifies it**
2. **Single-threaded master loop** with disciplined tools beats complex multi-agent swarms
3. **Context is a precious, finite resource** — manage it aggressively
4. **Sub-agents for isolation** — clean context windows, condensed summaries back to parent
5. **Tools need HCI-level design effort** — documentation, examples, clear descriptions
6. **External artifacts as memory** — progress files, git history, structured notes persist across sessions
7. **Verification loops** — give agents something to check their own work against
8. **Human checkpoints** — mandatory gates for destructive/high-value actions
9. **Workflows for predictable tasks, agents for open-ended ones** — don't over-agent
10. **Agent-Computer Interface (ACI)** — invest in tool design equal to HCI effort

---

## 17. Modern Agent Frameworks Landscape (2025-2026)

### Framework Comparison

| Framework | Architecture | Strengths | Best For |
|-----------|-------------|-----------|----------|
| **LangGraph** | State machine graphs | Checkpointing, human-in-loop, typed state | Production agents with complex flow |
| **CrewAI** | Role-playing crews | Fast prototyping, Crews + Flows modes | Structured team workflows |
| **AutoGen** (MS) | Multi-agent conversations | Async messaging, visual Studio builder | Multi-party dialogues |
| **OpenAI Agents SDK** | Handoffs + guardrails | Provider-agnostic, voice support (2026) | Simple agent chains with safety |
| **AWS Strands** | Model-driven, A2A | Bedrock integration, graph/swarm/workflow | AWS-native deployments |
| **Google ADK** | MCP-native, A2A | Gemini + Claude + LiteLLM, deep MCP | Multi-model, interoperable agents |
| **Claude Agent SDK** | Single-threaded loop | Sub-agents, hooks, file checkpointing | Code agents, tool-heavy tasks |

### Key Trends 2026
- **Flow engineering** > prompt engineering — designing control flow and state transitions matters more
- **72% of enterprise AI projects** use multi-agent architectures (up from 23% in 2024)
- **Market**: $7.6B in 2025 → projected $196.6B by 2034
- **Interoperability**: MCP (Anthropic) + A2A (Google) both under Linux Foundation
- **Human-on-the-loop** replacing human-in-the-loop (oversight, not bottleneck)

### LangGraph Deep Dive (Most Relevant to OneIntel)

**Immutable state**: Each update creates new version (not mutation). Typed schemas enforce consistency.

**Checkpointing**: `InMemorySaver` (dev) or `AsyncPostgresSaver` (prod). A 2-hour task can survive pod restart.

**Human-in-the-loop — Two mechanisms**:
- **Static interrupts**: `interrupt_before`/`interrupt_after` on compile — nodes that always need review
- **Dynamic interrupts**: `interrupt()` function pausing based on runtime state
- Resume with `Command(resume="response")`

**Graph patterns**: Static edges (predictable) + conditional edges (adaptive) + fan-out/fan-in (parallel).

### Agent Memory Frameworks

| Framework | Architecture | Best For |
|-----------|-------------|----------|
| **Mem0** | Managed SaaS, graph memory, MMR reranking | Fastest to production |
| **Zep** | Temporal knowledge graph, tracks fact changes over time | Enterprise, evolving facts |
| **Letta** (ex-MemGPT) | Memory as agent state, editable blocks, visual debugging | Persistent agent identity |

### Inter-Agent Protocols

| Protocol | Owner | Transport | Status |
|----------|-------|-----------|--------|
| **MCP** | Anthropic → AAIF/Linux Foundation | JSON-RPC, stdio/SSE/HTTP | 97M+ monthly downloads |
| **A2A** | Google → Linux Foundation | HTTP + SSE + JSON-RPC | v0.3, 50+ partners |

### Agent Observability (2026 Standard)

- **OpenTelemetry** standardized semantic conventions for AI agent observability
- 89% of organizations have implemented agent observability
- Platforms: LangSmith, Braintrust, Maxim, Arize Phoenix
- Key: trace spans per step (classify, retrieve, generate, tool_call)

### Advanced Tool Use Patterns (Anthropic)

- **Tool Search Tool**: Thousands of tools without context consumption (tool metadata indexed, searched on demand)
- **Programmatic Tool Calling**: Code execution environment for dynamic tool invocation
- **Agent Skills**: Repeatable workflows, now open standard. Partners: Atlassian, Canva, Figma, Notion
- **Key insight**: Popular agents use surprisingly few tools (~12 for Claude Code)

---

## 18. OneIntel Gap Analysis — Updated with Framework Research

### New Gaps Identified

| # | Gap | Industry Standard | Priority |
|---|-----|-------------------|----------|
| 1 | **No immutable state** | LangGraph's typed state versioning | MEDIUM |
| 2 | **No checkpointing to PostgreSQL** | LangGraph AsyncPostgresSaver | HIGH for AGI |
| 3 | **No dynamic interrupts** | LangGraph `interrupt()` function | MEDIUM |
| 4 | **No A2A protocol support** | Google's agent interoperability standard | LOW (future) |
| 5 | **No temporal memory** | Zep-style fact evolution tracking | MEDIUM |
| 6 | **No agent skills as open standard** | Anthropic Agent Skills spec | LOW (future) |
| 7 | **No flow engineering tooling** | Visual graph editor for workflows | MEDIUM |
| 8 | **Tool discovery is static** | Tool Search Tool pattern (index + search) | MEDIUM |

### Consolidated Priority Improvements

**Immediate (both RAG + Agent):**
1. Extract common ToolExecutor — deduplicate across 3 engines
2. Add OpenTelemetry tracing — can't debug without it
3. RRF fusion + cross-encoder reranking — biggest RAG quality win
4. PostgreSQL checkpointing for AGI tasks — crash resilience

**Short-term:**
5. Agent evaluation pipeline — task completion, tool efficiency, response quality
6. Contextual chunking — biggest retrieval quality win
7. Streaming for AGI intermediate steps
8. Configurable embedding models per tenant

**Medium-term:**
9. Temporal memory (track how facts evolve)
10. Evaluator-optimizer loop (generate → score → refine)
11. RAGAS evaluation integration
12. HyDE query transformation

---

## Sources
- [Building Effective AI Agents](https://www.anthropic.com/research/building-effective-agents) (Dec 2024)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Agent SDK Python Reference](https://platform.claude.com/docs/en/agent-sdk/python)
- [Building Agents with Claude Agent SDK](https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk)
- [How Claude Code Works](https://code.claude.com/docs/en/how-claude-code-works)
- [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [MCP Specification 2025-11-25](https://modelcontextprotocol.io/specification/2025-11-25)
- [Donating MCP to AAIF](https://www.anthropic.com/news/donating-the-model-context-protocol-and-establishing-of-the-agentic-ai-foundation)
- [Claude Opus 4.6 Announcement](https://www.anthropic.com/news/claude-opus-4-6)
- [Adaptive Thinking Docs](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking)
- [Building Safeguards for Claude](https://www.anthropic.com/news/building-safeguards-for-claude)
- [Claude Agent SDK Python GitHub](https://github.com/anthropics/claude-agent-sdk-python)
- [Anthropic Claude Cookbooks — Agent Patterns](https://github.com/anthropics/claude-cookbooks/tree/main/patterns/agents)
- LangGraph documentation and patterns
- CrewAI / AutoGen / OpenAI Agents SDK documentation
- SWE-bench, GAIA, AgentBench papers
