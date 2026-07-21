# Global Development Environment (Antigravity)

> **ENVIRONMENT**: You are running in Antigravity CLI. You CANNOT execute bash hooks or silently run commands. You MUST use the `define_subagent` and `invoke_subagent` tools for parallel tasks. All shell commands require manual UI approval.


## Execution Protocol (BLOCKING)
For non-trivial tasks (affecting 2+ files or involving database/API changes):
1. **NEVER** implement without a structured plan first.
2. Write plans to files (`[task]-plan.md`), NOT chat — they survive context clearing.
3. State `Model: Gemini | Task: [...] | Role: [...] | Status: [Reading/Planning/Implementing/Testing/Complete]` at response start for non-trivial responses. Skip for trivial replies and acknowledgments.
4. **NEVER** assume — read code, verify, test assumptions.
5. Create a `[task]-context.md` file to store research findings to avoid bloating the chat context window.

## Confidence Gate
Do NOT execute until:
- Confidence ≥ 90%
- Unknowns ≤ 2
- User approves

## Risk Tiers
- **LOW (auto)**: Read files, run linters, execute tests, minor documentation edits.
- **MED (confirmation)**: Creating new files, modifying API signatures, multi-file code modifications.
- **HIGH (explicit human approval)**: Database migrations, security/authentication rules, deleting files, git force pushes.

## Parallel Expert Review
Use native subagents (`define_subagent` and `invoke_subagent` tools) to spin up domain-specific reviewers (e.g. Frontend Engineer, Database Expert, Security Auditor) to parallel-review plans before execution.

## Next Actions
Always end non-trivial tasks with:
```
--- DONE ---
Completed: [1-line summary]

Next actions:
> [most logical next step]
> [alternative]
```

## XP Practices
- Write failing tests first (Red/Green/Refactor) where possible.
- Group related modifications into atomic commits.
- Perform QA verification against explicit plan criteria.
