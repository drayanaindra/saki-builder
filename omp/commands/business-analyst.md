---
---

# Business Analysis

**Ask:** What business problem are we solving? Who are the stakeholders? What decisions does this analysis need to support? What's the timeline and constraints?

**Process:** Understand context → Elicit requirements → Analyze & model → Document → Validate → Support implementation → UAT

**Never:** Jump to solutions before understanding the problem | Assume requirements are stable | Skip stakeholder sign-off | Write BRDs nobody reads | Treat all requirements equally (prioritize ruthlessly)

---

## Requirements Taxonomy

Every requirement must be classified before writing:

| Type | Definition | Example |
|------|-----------|---------|
| **Functional** | What the system must DO | "System must send invoice within 24h of order completion" |
| **Non-Functional** | How the system must PERFORM | "System must process 1000 requests/sec with <500ms latency" |
| **Business Rule** | Policy/constraint imposed by business | "Discount > 20% requires manager approval" |
| **Constraint** | Hard boundary (time, tech, legal, budget) | "Must integrate with SAP ERP by Q3" |
| **Assumption** | Conditions believed true but unverified | "All users have internet access" |
| **Dependency** | External element the feature relies on | "Requires completion of auth module first" |

**Requirement quality criteria (SMART):**
- **S**pecific — unambiguous, one interpretation only
- **M**easurable — has acceptance criterion you can test
- **A**ttainable — technically feasible within constraints
- **R**elevant — traces to a business objective
- **T**raceable — has an ID, owner, and source

---

## Elicitation Techniques

| Technique | Best For | Pitfall |
|-----------|---------|---------|
| **Structured interview** | Key stakeholders, complex processes | Interviewee says what they think you want to hear |
| **Workshop / JAD session** | Cross-functional alignment, resolving conflicts | Loud voices dominate; use facilitator techniques |
| **Document analysis** | Existing systems, policy docs, as-is flows | Docs may be outdated — verify with SMEs |
| **Observation (shadowing)** | Understanding actual work vs. stated work | Hawthorne effect: people change behavior when watched |
| **Survey / questionnaire** | Large user groups, quantifying preferences | Low response rates; can't probe follow-up |
| **Prototype / mockup** | Ambiguous UX requirements | Stakeholders anchor on prototype details not intent |
| **Benchmarking** | Best practice gaps, competitive analysis | "Industry standard" may not fit your context |

**Interview best practices:**
- Prepare 5–7 open-ended questions; leave 40% of time for follow-up
- Ask "what happens when X goes wrong?" — uncovers edge cases stakeholders forget
- End with: "Is there anything I haven't asked that you think I should know?"
- Document verbatim quotes — useful for resolving disputes later

---

## Stakeholder Analysis

**Influence-Interest Matrix:**
```
High Interest │ MANAGE CLOSELY    │ KEEP SATISFIED
              │ (key decision-    │ (senior sponsors,
              │  makers, users)   │  regulators)
──────────────┼───────────────────┼──────────────────
Low Interest  │ MONITOR           │ KEEP INFORMED
              │ (peripheral       │ (affected teams,
              │  stakeholders)    │  support staff)
              └───────────────────┘
                Low Influence       High Influence
```

**RACI Matrix (per key decision/deliverable):**
| Decision/Activity | Sponsor | PM | BA | Tech Lead | End User |
|------------------|---------|----|----|-----------|----|
| Approve requirements | A | R | R | C | I |
| Sign off UAT | A | C | C | I | R |
| Approve scope change | A | R | C | C | I |

R = Responsible, A = Accountable, C = Consulted, I = Informed
**Rule:** Only ONE Accountable per row.

---

## Process Mapping

**BPMN Notation essentials:**
- **Start event** (thin circle) → **Task** (rounded rectangle) → **Gateway** (diamond) → **End event** (thick circle)
- **Exclusive gateway (X):** only one path taken (if/else)
- **Parallel gateway (+):** all paths taken simultaneously
- **Inclusive gateway (O):** one or more paths taken
- **Swim lane:** one lane per role/system responsible for tasks

**AS-IS → TO-BE process improvement flow:**
1. Map AS-IS: document current state exactly as it is (not how it should be)
2. Identify pain points: where are the delays, errors, rework, and handoff failures?
3. Root cause each pain point (5 Whys, fishbone diagram)
4. Design TO-BE: eliminate waste, automate where ROI > cost, standardize handoffs
5. Gap analysis: what needs to change (people / process / technology)?
6. Validate TO-BE with process owners before documenting

**Process mapping checklist:**
- [ ] All roles/systems in swim lanes
- [ ] All decision points as gateways (not hidden inside tasks)
- [ ] Exception/error paths documented (not just happy path)
- [ ] Handoff points explicitly marked
- [ ] Metrics captured at key steps (time, error rate, volume)

---

## Gap Analysis Framework

```
CURRENT STATE           GAP                 DESIRED STATE
──────────────    ────────────────────    ──────────────────
What exists       What's missing/         What's needed to
today             broken/inefficient       meet the goal
──────────────    ────────────────────    ──────────────────
Process X takes   4h delay due to         Automated approval
8h end-to-end     manual approval         → 4h end-to-end

No real-time      Decision-makers         Live dashboard
inventory data    use stale reports       updated every 15min
```

**Gap analysis output format:**
| ID | Current State | Desired State | Gap Description | Impact | Priority | Recommendation |
|----|--------------|--------------|----------------|--------|----------|----------------|
| G01 | Manual invoice matching (4h) | Auto-matched (<5min) | No ERP integration | HIGH | P0 | Build SAP integration |
| G02 | No SLA tracking | SLA dashboard | Missing monitoring | MED | P1 | Add reporting module |

---

## Documentation: BRD vs FRD vs PRD vs SRS

| Document | Audience | Content | Triggers |
|----------|---------|---------|---------|
| **BRD** (Business Requirements) | Executives, sponsors | Problem statement, business objectives, high-level requirements, success metrics, ROI | Project initiation, before solution design |
| **FRD** (Functional Requirements) | Development, QA, design | Detailed functional specs, business rules, use cases, data requirements, integrations | After BRD approved, before design/development |
| **PRD** (Product Requirements) | Product + Engineering | User stories, acceptance criteria, prioritized feature list, non-goals, metrics | Agile product development |
| **SRS** (Software Requirements Spec) | Engineering, QA | System interfaces, constraints, performance specs, security requirements | Formal/regulated development environments |

**Minimum viable BRD structure:**
```markdown
# Business Requirements Document: [Project Name]
**Version:** 1.0 | **Status:** Draft/Review/Approved | **Date:** YYYY-MM-DD
**Business Owner:** [name] | **BA:** [name]

## 1. Executive Summary
[2-3 sentences: problem, proposed solution, expected benefit]

## 2. Business Problem
- Current state + pain points (with data/evidence)
- Impact of not solving (cost, risk, missed opportunity)

## 3. Business Objectives
- Objective 1: [specific, measurable outcome]
- Objective 2: ...
Success metric: [KPI + current baseline + target]

## 4. Scope
**In scope:** [bullet list]
**Out of scope:** [explicit exclusions]

## 5. High-Level Requirements
[Numbered list — functional + non-functional + constraints]

## 6. Assumptions & Dependencies
## 7. Risks & Mitigations
## 8. Stakeholders & Sign-off
```

---

## Use Cases vs User Stories vs Acceptance Criteria

| Format | Best For | Level |
|--------|---------|-------|
| **Use Case** | Complex multi-step flows, system interactions, formal/regulated environments | System-level |
| **User Story** | Agile, team understanding of user value | Feature-level |
| **Acceptance Criteria** | Testable definition of done for any requirement | Behavior-level |

**Use Case structure:**
```
Use Case ID: UC-001
Name: Process Customer Refund
Actor: Customer Service Rep
Precondition: Order exists and is in 'delivered' status
Main Flow:
  1. CSR searches for order by ID
  2. System displays order details
  3. CSR selects "Initiate Refund"
  4. System validates refund eligibility (within 30 days, not already refunded)
  5. CSR enters refund reason
  6. System processes refund and sends confirmation email
Postcondition: Refund created, customer notified, order status = 'refunded'
Alternative Flows:
  4a. Order > 30 days: System displays "Refund window expired" — End
  4b. Already refunded: System displays "Duplicate refund blocked" — End
```

**Acceptance Criteria (Given-When-Then):**
```
GIVEN [precondition]
WHEN [action/trigger]
THEN [observable, testable outcome]
```

**Quality rule:** If two people can interpret an AC differently, rewrite it until they can't.

---

## Feasibility Analysis

Before recommending a solution, assess all five dimensions:

| Dimension | Key Questions | Red Flags |
|-----------|-------------|-----------|
| **Technical** | Can the tech stack support this? Integration complexity? Data availability? | "We'd need to rebuild the core platform" |
| **Operational** | Can the org run and maintain it? Staff skills? Change readiness? | No one to operate it post-launch |
| **Economic** | Does benefit > cost? ROI timeline? Total cost of ownership? | Payback period > 3 years for tactical project |
| **Schedule** | Can it be built in time given constraints? Critical path risks? | Dependencies on 3+ external teams |
| **Legal/Compliance** | GDPR, data residency, industry regulation, contractual constraints? | Requires legal review → add 6-week buffer |

**Decision output:**
- **GO:** All five dimensions feasible → recommend
- **GO with conditions:** 3-4 feasible, 1-2 need mitigation → recommend with conditions
- **NO-GO:** 2+ dimensions infeasible → recommend alternative or phased approach

---

## Business Case Construction

**Structure:**
1. **Problem statement** — cost/impact of current state (quantified)
2. **Options considered** — at least 3: do nothing, minimum viable, full solution
3. **Cost-benefit analysis** — for each option:
   - One-time costs (build, migration, training)
   - Recurring costs (license, maintenance, support)
   - Benefits (cost savings, revenue gain, risk reduction) — quantify in $
   - Net Present Value (NPV) / ROI / payback period
4. **Recommendation** — preferred option with rationale
5. **Risk summary** — top 3 risks + mitigations
6. **Decision requested** — explicit ask with deadline

**Cost-benefit template:**
| | Option A: Do Nothing | Option B: MVP | Option C: Full |
|-|---------------------|--------------|---------------|
| One-time cost | $0 | $150K | $400K |
| Annual cost | $80K (manual labor) | $20K | $10K |
| Annual benefit | $0 | $120K | $200K |
| Year 1 NPV | $(80K) | $(50K) | $(210K) |
| Year 3 NPV | $(240K) | $130K | $180K |
| **Payback** | Never | 18 months | 24 months |

---

## UAT Planning

**UAT phases:**
1. **Test plan** — scope, entry criteria, exit criteria, test environment, roles
2. **Test scenario design** — business-flow based (not technical unit tests)
3. **Test execution** — business users run scenarios; log defects with severity
4. **Defect triage** — BA + Dev + UAT lead: fix vs defer vs won't fix
5. **Re-test** — verify fixes
6. **Sign-off** — formal acceptance with documented residual risks

**Defect severity:**
| Severity | Definition | Example |
|----------|-----------|---------|
| **Critical** | Blocks core business function, no workaround | Order cannot be placed |
| **High** | Major function broken, workaround exists | Report shows wrong totals |
| **Medium** | Minor function incorrect, easy workaround | Wrong default date on filter |
| **Low** | Cosmetic, no functional impact | Button label typo |

**Exit criteria (minimum):**
- [ ] 100% of P0/P1 scenarios executed
- [ ] 0 Critical defects open
- [ ] High defects < 2 (or documented mitigation)
- [ ] Business owner signed off in writing

---

## Change Impact Assessment

**Impact dimensions:**
- **People:** Who is affected? Training needed? Resistance expected?
- **Process:** Which processes change? What's the AS-IS → TO-BE delta?
- **Technology:** What systems change? Integration impacts? Data migration?
- **Policy/Compliance:** What rules/regulations apply?

**Change impact matrix:**
| Stakeholder Group | Impact Level | Impact Type | Action Required |
|------------------|-------------|-------------|----------------|
| Warehouse staff | HIGH | Process change (new scan workflow) | Training + job aids |
| Finance team | MED | Report format changes | 2-hour walkthrough |
| IT Operations | LOW | New system to monitor | Add to monitoring runbook |

---

## BA Checklist

**Before any analysis:**
- [ ] Business objective stated and agreed (not just "build feature X")
- [ ] Key stakeholders identified and mapped (influence/interest matrix)
- [ ] Scope boundaries written (in / out of scope)

**Requirements:**
- [ ] All requirements classified (functional / non-functional / constraint / rule)
- [ ] Each requirement has: ID, owner, priority, source, test criteria
- [ ] Assumptions explicitly listed and owner-confirmed
- [ ] Dependencies identified and communicated

**Documentation:**
- [ ] Right document type chosen for audience (BRD / FRD / PRD)
- [ ] Process maps include exception/error paths
- [ ] All acronyms and domain terms defined in glossary

**Sign-off:**
- [ ] Stakeholders reviewed — not just "sent to" but "walked through"
- [ ] Open items tracked with owner + due date
- [ ] Version controlled (dated, author, change log)

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| **Solution-first requirements** | "We need a dashboard" instead of "managers can't see real-time inventory" | Start with problem; derive solution |
| **Requirements by committee** | Every stakeholder adds gold plating; scope explodes | RACI: one Accountable; BA facilitates, not aggregates |
| **Vague acceptance criteria** | "System should be fast / user-friendly / reliable" | Rewrite with measurable threshold: "<2s load, 99.9% uptime" |
| **Happy path only** | Edge cases surface in UAT or production | Always ask: "What happens when X fails?" |
| **Frozen requirements** | Change requests locked out → system doesn't fit final need | Build change control process; distinguish in-scope changes from scope creep |
| **Big up-front documentation** | 80-page BRD nobody reads | Right-size to audience and complexity; use lean docs + workshops |
| **Skipping feasibility** | Solution committed before constraints discovered | Assess all 5 feasibility dimensions before recommending |
| **Missing non-functional requirements** | System "works" but can't handle load / fails audit | NFRs are equally contractual — specify, test, and sign off |
