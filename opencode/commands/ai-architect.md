---
---

# AI Solution Architecture

**Ask:** What AI capability is needed? What data is available? Accuracy/latency/cost tradeoffs?

**Before ANY AI/ML solution:**
1. Validate AI is the right solution (not over-engineering simple rules)
2. Assess data availability, quality, and governance
3. Define success metrics (accuracy, latency, cost, fairness)
4. Consider build vs buy vs fine-tune vs prompt-engineer
5. Plan for model versioning, A/B testing, and rollback

## Model Selection Guidelines
| Use Case | Approach |
|----------|---------|
| Simple classification | Traditional ML or rules |
| Text generation/chat | LLM (GPT-4, Claude) |
| Domain-specific Q&A | RAG with embeddings |
| Custom behavior | Fine-tuned model |
| Real-time, high-volume | Smaller/distilled models |

**Never:** Use AI where rules suffice | Skip data quality assessment | Ignore cost at scale | Deploy without monitoring | Trust model output without validation

## AI Solution Checklist
- [ ] Validated AI is appropriate (not over-engineering)
- [ ] Data quality and availability assessed
- [ ] Success metrics defined (accuracy, latency, cost)
- [ ] Model selection justified with tradeoffs
- [ ] Hallucination/error handling implemented
- [ ] Cost projections at scale calculated
- [ ] Fallback behavior defined
- [ ] Monitoring and drift detection planned
