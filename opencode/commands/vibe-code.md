---
---

# Vibe Code — Token-Efficient Complex Project Orchestrator

## Principle
Ship correct work fast. Burn fewer tokens doing it. Human sets direction; agent handles the rest.

---

## 1. Classify & Route (auto)

| Type | Signals | Mode |
|------|---------|------|
| Quick Fix | typo, config, one-liner | Micro: fix + read-back |
| Bug Fix | "fix", "broken", error | Speed: diagnose + fix + verify |
| Feature | "add", "build", "create" | Full: plan + build + verify |
| AI/Agent | "agent", "prompt", "LLM" | Full+NLP: + prompt design |

**Default to lightest mode that fits. User can override: "go full" or "just fix it."**

---

## 2. Token Efficiency Patterns (the real gains)

### Parallel Everything Independent
```
BAD:  Read file A → Read file B → Read file C (3 sequential rounds)
GOOD: Read file A + B + C in one parallel call (1 round)
```
- Parallel tool calls for independent reads, searches, commands
- Single round for git status + git diff + git log
- Batch glob + grep when exploring unknown code

### Read Smart, Read Once
- Read targeted sections (offset+limit) for large files, not entire files
- Extract key info on first read, don't re-read the same file
- Use Grep to locate, then Read only the relevant section
- Subagents for broad exploration; direct tools for targeted lookups

### Progressive Depth
```
Level 1: Grep/Glob → find the file and function (seconds)
Level 2: Read the specific section (one call)
Level 3: Subagent deep dive (only if L1-L2 insufficient)
```
Never start at L3. Most tasks resolve at L1-L2.

### Compact Output
- Lead with action, not reasoning
- Code speaks; don't narrate what code does
- Reference `file:line` instead of quoting code blocks back
- Skip redundant confirmations ("I've updated the file" — the tool already shows it)

### Subagent Delegation
Use Agent tool for:
- Exploring unfamiliar parts of codebase (protects main context)
- Running independent research in parallel
- Tasks that would dump large results into main context

Don't use for: simple grep, single file read, obvious next step

---

## 3. Execution Protocol

### Pre-Flight (always, even Micro)
```
1. git status (know what's dirty)
2. Read files to change (never guess content)
3. Check existing patterns (grep for similar code)
```
Parallel all three. One round.

### Implement
- One logical change at a time
- Follow existing patterns exactly (naming, style, structure)
- Verify imports and types after edit
- Run tests after each meaningful change

### Post-Flight
```
Micro:  Read-back changed lines
Speed:  Read-back + run related tests
Full:   Read-back + full test suite + regression check
```

### Gate Failures
```
Test fails → STOP → fix root cause → re-test
Don't push through. Don't "fix forward." Don't retry blindly.
```

---

## 4. Role Routing

When a decision is outside Engineering, switch explicitly:

| Question | Route to |
|----------|----------|
| What to build / why? | Product thinking |
| How to structure? | Architect thinking |
| How it looks? | Design thinking |
| How to prompt/tune? | NLP-Engineer thinking |
| Is it correct? | Reviewer thinking |
| Does it work? | QA thinking |

**Stay in role. Engineer doesn't make Product decisions. Flag and ask.**

---

## 5. Anti-Patterns

| Don't | Do |
|-------|-----|
| Read same file 3x in one task | Cache key info from first read |
| Full pipeline for a typo | Match effort to task size |
| Narrate every step | Act, show result |
| Sequential independent calls | Parallel independent calls |
| Guess file content | Read first, always |
| Gold-plate | Implement exactly what's asked |
| Fix unrelated issues | Note for later, stay focused |

---

## 6. Self-Improvement (lightweight)

After task completion, only if something went wrong:
- Issue happened 2+ times? Update relevant skill file
- A check caught nothing useful? Remove it
- A pattern saved significant tokens? Document it here
