---
name: clean-code
description: SonarQube clean-code standard, applied at write-time. Invoke before writing or modifying code so the change passes the SonarQube quality gate the first time instead of failing it later. Auto-loaded by /saki-builder:build during implementation. Covers Reliability (bugs), Security (vulnerabilities/hotspots), Maintainability (code smells), and the Clean-as-You-Code model the gate grades on.
---

# SonarQube Clean Code Standard (write-time)

Apply these rules WHILE writing code. They are the companion to the **Pre-merge Gate** in
`CLAUDE.md` (which enforces SonarQube at `git push`) and `xp-principles.md` (TDD + refactoring
thresholds). Goal: write the change clean so the gate passes the first time — never write-then-fix.

## Clean as You Code (what the gate grades)

The quality gate is evaluated on **new / changed code** (your diff), not the whole repo — so every
rule below applies to the lines you touch. Default gate conditions on new code:

- Coverage **≥ 80%** (SonarQube new-code) — `/saki-builder:qa` enforces the same **≥ 80% NON-NEGOTIABLE** floor locally first (`COVERAGE_MIN`, clamped — no lowering, no spike/skip bypass), so you clear coverage *before* the gate, not at it
- Duplicated lines **< 3%**
- **0** new Bugs, Vulnerabilities, and unreviewed Security Hotspots
- Maintainability / Reliability / Security rating **A**

SonarQube classifies every finding as a **Bug** (reliability), **Vulnerability** / **Security
Hotspot** (security), or **Code Smell** (maintainability). The three sections below map to those.

## Reliability — don't write bugs

- **Null safety**: check before dereference. `if x is not None:` (Python — not `if x:`, which drops `0`/`""`/`False`), `Optional`/null guards, optional chaining. Never deref a value that can be null/undefined.
- **Resource management**: always close what you open — `with` (Python), try-with-resources (Java), `defer`/`Close()` (Go), `using` (C#). Never leak files, sockets, DB connections.
- **Check return values** that signal failure; don't ignore error returns (Go `err`, syscall results).
- **No identical operands**: both sides of `==`, `&&`, `||`, `-` being identical is a bug. Same for self-assignment.
- **Correct equality**: objects via `.equals`/`===`/value-equality, not reference `==`; never `==` on floats.
- **Exhaustive branching**: cover every `switch`/`enum` case or supply a `default`.
- **Loops must progress**: the condition variable must change; no unintended infinite loops.
- **No unreachable code** after `return`/`throw`/`break`.

## Security — no vulnerabilities, review hotspots

- **No hardcoded secrets** (keys, tokens, passwords, connection strings). Also blocked by the secrets hook — keep them in env/secret stores.
- **No injection**: parameterize SQL and shell/OS commands. Never string-concatenate untrusted input into a query, command, path, or HTML (XSS).
- **Validate & sanitize all external input** (request bodies, params, headers, file uploads) at the boundary.
- **Strong crypto only**: no MD5/SHA-1 for security, no DES/RC4, no ECB mode, no hardcoded IV/salt. Use vetted libraries; never roll your own.
- **Transport & auth**: don't disable TLS/cert verification; set `Secure`/`HttpOnly`/`SameSite` on cookies; enforce least privilege.
- **Don't log sensitive data** (PII, secrets, full tokens). Never `eval`/dynamic-exec untrusted strings; avoid insecure deserialization.

## Maintainability — no code smells

- **Cognitive complexity ≤ 15** per function (SonarQube default); cyclomatic ≤ 10. Split or flatten when exceeded.
- **Size limits**: function ≤ 40 LOC, parameters ≤ 7. (Aligns with `xp-principles.md`: Go file > 300, TSX > 500 → refactor.)
- **DRY**: extract shared logic at the 3rd repetition; no copy-paste blocks (gate fails > 3% duplication).
- **Guard clauses over nesting**: max ~3 levels of control nesting; return early instead of deep `if/else` pyramids. No nested ternaries.
- **No magic numbers/strings**: name a constant; define a constant for any literal repeated 3+ times.
- **No dead code**: remove unused variables, parameters, imports, private methods, and commented-out code. Don't comment out — delete (git remembers).
- **Exception handling**: never swallow (`catch {}` / bare `except: pass`). Catch the narrowest type; log with context or rethrow; don't catch-and-rethrow the same exception unchanged. (Python async: `except BaseException` in startup/lifespan loops — see `xp-principles.md`.)
- **Naming**: descriptive, conventional for the language (camelCase/snake_case/PascalCase as the ecosystem dictates). No single-letter names except loop indices.
- **Simplify boolean logic**: no `if (cond) return true; else return false;` → `return cond`. Remove redundant conditions and double negatives.
- **Single responsibility**: one function = one job. No side effects hidden behind innocent names.
- **No leftover `TODO`/`FIXME`** in merged code — resolve it or track it in the issue tracker.

## Testing (gate conditions)

- Coverage: `/saki-builder:qa`'s **Coverage Gate** enforces a **non-negotiable ≥ 80%** floor (`COVERAGE_MIN`, **default 80**, clamped so it can only be raised) before push — it also gates the *changed files* to mirror SonarQube's new-code model; SonarQube's ≥80% new-code condition is the final check. Write tests with the code (TDD per `xp-principles.md`).
- Cover the failure path of every invariant/guard you add, not just the happy path.
- No flaky/ignored tests left enabled.

## Workflow

1. Write the change applying the rules above.
2. The analysis hook runs on save; `/sonarqube:sonar-analyze <file>` checks a file on demand.
3. Before push, the **Pre-merge Gate** runs: `/sonarqube:sonar-quality-gate` → `/sonarqube:sonar-list-issues` → fix → re-analyze → push.
4. To fix a specific finding by rule: `/sonarqube:sonar-fix-issue`.
