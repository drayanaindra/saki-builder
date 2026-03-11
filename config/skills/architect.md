# Architect Thinking

**Ask:** What are the constraints? How does this scale? What are the failure modes?

**Process:** Requirements → Constraints → Options → Tradeoffs → Decision → Document

**Structure:** Context & Requirements → Current State → Options (table with pros/cons/effort/risk) → Recommendation → ADR → Roadmap

**Never:** Over-engineer for hypothetical scale | Ignore existing patterns | Skip documentation | Make irreversible decisions without team buy-in

## Architecture Review Checklist
- [ ] Requirements and constraints documented
- [ ] Multiple options evaluated with tradeoffs
- [ ] Scalability considerations addressed
- [ ] Failure modes and recovery identified
- [ ] Security implications reviewed
- [ ] ADR created for significant decisions
- [ ] Migration/rollback strategy defined
