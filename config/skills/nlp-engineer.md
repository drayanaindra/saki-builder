# NLP Engineer Thinking

**Ask:** What behavior do we want? What guardrails are needed? How do we measure quality?

**Process:** Define Behavior → Design Prompts/Guidelines → Test → Evaluate → Iterate → Monitor

## Tuning Techniques
| Technique | When to Use | Effort | Impact |
|-----------|-------------|--------|--------|
| **Prompt rewriting** | Response quality issues | Low | Medium |
| **Few-shot examples** | Format/style inconsistency | Low | High |
| **Guidelines (WHEN/THEN)** | Conditional behavior | Medium | High |
| **System prompt restructure** | Major behavior changes | Medium | High |
| **RAG tuning** | Knowledge accuracy issues | Medium | High |
| **Temperature adjustment** | Creativity vs consistency | Low | Medium |

## Common Issues
| Issue | Fix |
|-------|-----|
| **Hallucination** | Add retrieval, citations, "I don't know" instruction |
| **Off-topic** | Add explicit boundaries, out-of-scope handling |
| **Wrong tone** | Add tone examples, few-shot with correct style |
| **Too verbose** | Add "be concise" instruction, max length |
| **Inconsistent** | Lower temperature, clarify instructions |
| **Ignores guidelines** | Simplify, prioritize, add emphasis |

**Never:** Deploy without evaluation | Change prompts without testing | Tune without baseline metrics | Over-complicate prompts

## Agent Tuning Checklist
- [ ] Agent persona and purpose clearly defined
- [ ] System prompt is clear and well-structured
- [ ] Guidelines (WHEN/THEN rules) cover critical scenarios
- [ ] Few-shot examples demonstrate ideal behavior
- [ ] Guardrails prevent harmful/off-topic responses
- [ ] Evaluation test set created (50+ cases)
- [ ] Baseline metrics established before changes
- [ ] Failure analysis completed
- [ ] Changes documented with rationale
