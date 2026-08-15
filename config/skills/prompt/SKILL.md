---
name: prompt
description: "Expand a one-line prompt into a structured 6-section prompt: Role, Task, Context, Reasoning, Stop, Output. Use when you want to write a high-quality prompt from a quick idea."
---

# Prompt Expander

Take the ARGUMENTS (a one-line prompt) and expand it into a structured prompt using the 6-section framework below.

## Step 1: Parse the one-liner

Read ARGUMENTS. If empty or missing, ask: **"What's your one-line prompt?"** and wait.

If the prompt is ambiguous (no clear domain, no clear action), ask **ONE** clarifying question before expanding. Do not guess blindly.

## Step 2: Infer each section

For each section below, think carefully about what the one-liner implies, then write a precise, usable value.

### Role
The expert persona the AI should embody. Infer from the domain and task:
- Code task → the language/framework engineer (e.g. "Senior Go engineer", "React frontend engineer")
- Architecture task → "Software Architect"
- Security task → "Security Engineer"
- Writing task → "Technical Writer"
- Data task → "Data Engineer / Analyst"
- DevOps task → "DevOps / SRE Engineer"
- General → "Expert assistant with deep knowledge in [inferred domain]"

### Task
Restate the one-liner as a precise, verb-driven instruction. No vagueness.
- Bad: "fix the bug"
- Good: "Identify the root cause of the auth token expiry issue in the JWT validation middleware and write a targeted fix that handles both expired and malformed tokens without breaking the happy path."

### Context
What background the AI needs. Infer from the task domain and ask the user to fill in gaps:
- Current tech stack (infer from CLAUDE.md if available, otherwise state "[Add: language/framework/version]")
- Relevant files or modules ("[Add: file paths]" if unknown)
- Constraints (performance, backward compatibility, scope limits)
- What has already been tried (if a fix task)
- "Working in: [project name from CLAUDE.md if present]"

### Reasoning
The step-by-step thinking approach to apply:
- What to read/investigate first
- What tradeoffs to consider
- What assumptions to validate before acting
- What edge cases to think through
- Format as a numbered list of thinking steps (not solution steps)

### Stop (condition)
When to stop generating:
- Scope boundary: "Stop after [specific deliverable]. Do NOT include [out-of-scope thing]."
- Completion signal: "Stop when [testable outcome is achieved]."
- Length limit if appropriate: "Limit to [N lines / N functions / one file]."
- Branch point: "If [condition], stop and ask before continuing."

### Output
The format, structure, and length of the response:
- Format: code block / markdown / numbered list / table / prose / mixed
- Language: [programming language if code output]
- Length: short (< 10 lines) / medium (< 50 lines) / full solution
- Tone: direct and terse / explanatory / teaching-focused
- "Include: [what must be in the output]"
- "Exclude: [what to omit — boilerplate, comments, tests, etc.]"

## Step 3: Output the structured prompt

Format the output as a copy-pasteable markdown block:

---
**Role:** [value]

**Task:** [value]

**Context:**
[value — multi-line if needed]

**Reasoning:**
1. [step]
2. [step]
3. [step]

**Stop:** [value]

**Output:** [value]

---

## Step 4: Ask what to do next

After presenting the expanded prompt, ask:

> Save to `.prompts/[kebab-case-task-name].md`? Or use this immediately?

If user says "use it" or similar → execute the expanded prompt right away.
If user says "save" → write to `.prompts/[filename].md` in the project root.
If user edits a section → revise and re-present before asking again.

## Rules

- NEVER fill in Context specifics you don't know — use `[Add: ...]` placeholders
- NEVER make the Task vague — sharpen it, even if it means rewriting substantially
- Ask ONE clarifying question at most — don't interview the user
- The Stop section is NOT optional — always define scope boundaries
- Output section must name the FORMAT (code block, list, prose, etc.)
