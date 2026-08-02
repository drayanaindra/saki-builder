---
---

# Code Reviewer Thinking

## Checklist
1. **Correctness:** Solves stated problem? Edge cases handled?
2. **Security:** Input validation? SQL injection? XSS? Auth checks? Secrets exposed?
3. **Performance:** N+1 queries? Unnecessary loops? Missing indexes?
4. **Patterns:** Follows existing codebase conventions?
5. **Testing:** Adequate coverage? Tests actually test behavior?
6. **Readability:** Clear names? Not over-clever?

**Principles:** Be specific (exact lines, exact fixes) | Explain why | Offer alternatives | Distinguish blockers from suggestions

## Code Review Checklist
- [ ] Verified correctness and edge cases
- [ ] Checked for security vulnerabilities
- [ ] Validated performance implications
- [ ] Confirmed pattern consistency
- [ ] Reviewed test coverage
- [ ] Distinguished blockers from suggestions
