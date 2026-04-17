# Data Analysis

**Ask:** What decision needs to be made? Who is the audience? What data is available and how fresh? What's the confidence threshold needed for action?

**Process:** Clarify question → Explore data → Validate data quality → Analyze → Interpret → Communicate → Drive action

**Never:** Analyze without understanding the business question | Conflate correlation with causation | Present p-values without practical significance | Skip data quality checks | Show charts without a headline insight | Let "interesting" findings replace "actionable" findings

---

## Exploratory Data Analysis (EDA) Methodology

**EDA is structured, not exploratory aimlessness.** Follow this order:

1. **Shape & types** — row count, column count, dtypes, memory size. Spot schema issues early.
2. **Missing values** — `df.isnull().sum()`. Classify: MCAR / MAR / MNAR. Decide: drop, impute, flag.
3. **Distributions** — histograms for numeric (check skew, outliers, bimodality). Value counts for categoricals. `describe()` for summary stats.
4. **Outliers** — Z-score (>3σ) for normal; IQR method for skewed. Decide: data error, valid extreme, or domain-specific (investigate before dropping).
5. **Correlations** — heatmap for numeric pairs. Cramér's V for categorical pairs. Flag multicollinearity (>0.8) for modeling.
6. **Time patterns** — plot the series before any aggregation. Look for: trend, seasonality, structural breaks, anomalies.
7. **Cross-tabulations** — segment by key dimensions (cohort, geography, product). Does the pattern hold within segments? (Simpson's Paradox check)
8. **Hypotheses** — write down 3–5 hypotheses after EDA before confirming any single one.

**EDA red flags:**
- Distributions with impossible values (negative age, revenue > company total revenue)
- Suspiciously round numbers (manual data entry)
- Timestamps all at midnight (date truncation, not real events)
- Primary key duplicates (join inflation risk)
- Dramatic spikes/drops at period boundaries (reporting/ETL artifacts)

---

## SQL Power Patterns

**Window functions (use over self-joins):**
```sql
-- Running total
SUM(revenue) OVER (PARTITION BY user_id ORDER BY event_date) AS running_revenue

-- Rank within group
ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) AS rank_in_category

-- Period-over-period comparison (no self-join)
LAG(revenue, 7) OVER (PARTITION BY product_id ORDER BY date) AS revenue_7d_ago

-- Moving average
AVG(daily_revenue) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS rolling_7d_avg

-- Percentile within group
NTILE(4) OVER (ORDER BY ltv) AS ltv_quartile
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_revenue
```

**CTEs for readability and reuse:**
```sql
WITH
active_users AS (
  SELECT user_id
  FROM users
  WHERE last_active_date >= CURRENT_DATE - 30
),
user_revenue AS (
  SELECT user_id, SUM(amount) AS total_revenue
  FROM orders
  WHERE user_id IN (SELECT user_id FROM active_users)
  GROUP BY user_id
)
SELECT
  a.user_id,
  COALESCE(r.total_revenue, 0) AS revenue
FROM active_users a
LEFT JOIN user_revenue r USING (user_id)
```

**Query optimization checklist:**
- [ ] Filter early (push WHERE conditions into CTEs/subqueries before joining)
- [ ] JOIN on indexed columns — verify with EXPLAIN / query plan
- [ ] Avoid functions on indexed columns in WHERE: `WHERE DATE(created_at) = '2024-01-01'` → use range instead
- [ ] SELECT only needed columns (no `SELECT *`)
- [ ] LIMIT during development; remove for production aggregations
- [ ] Use `APPROX_COUNT_DISTINCT` for cardinality estimates on large tables
- [ ] Partition pruning: always filter on partition column in WHERE

**Aggregation traps:**
```sql
-- Trap: COUNT(*) includes NULLs; COUNT(col) doesn't
SELECT COUNT(*), COUNT(email) FROM users  -- different if email is nullable

-- Trap: AVG ignores NULLs (often inflates metric)
-- Use COALESCE if NULLs should be zero:
AVG(COALESCE(order_value, 0))

-- Trap: Joining before aggregating inflates rows (fan-out)
-- Aggregate first in CTE, then join
```

---

## Statistical Foundations

**Hypothesis testing workflow:**
1. **State null hypothesis (H₀):** "There is no difference between groups A and B"
2. **Choose test:** t-test (means, normal), Mann-Whitney U (non-normal), chi-square (proportions), ANOVA (3+ groups)
3. **Set significance level (α):** 0.05 (standard), 0.01 (high-stakes decisions), 0.10 (exploratory)
4. **Calculate p-value**
5. **Check practical significance** — statistically significant ≠ practically meaningful
6. **State conclusion** in plain language, not "p < 0.05"

**Key stats concepts:**
| Concept | Plain-language meaning | Common mistake |
|---------|----------------------|----------------|
| **p-value** | Probability of seeing this result if H₀ were true | "p-value is the probability the result is due to chance" (wrong) |
| **Confidence interval** | Range likely to contain the true value 95% of trials | "95% chance the true value is in this interval" (wrong) |
| **Effect size** | Magnitude of the difference (Cohen's d, relative lift) | Reporting significant p-value with negligible effect |
| **Statistical power** | Probability of detecting a real effect (target ≥ 80%) | Running underpowered tests → false negatives |
| **Type I error (α)** | False positive — rejecting true H₀ | Fishing for significance across many metrics |
| **Type II error (β)** | False negative — failing to reject false H₀ | Stopping test too early |

**Effect size benchmarks (Cohen's d):**
- Small: d = 0.2 | Medium: d = 0.5 | Large: d = 0.8
- For business: always report relative lift (%) alongside absolute change

---

## A/B Testing

**Design phase (before running):**
1. **Define ONE primary metric** (more = p-hacking risk)
2. **Calculate required sample size:** use power analysis (α=0.05, power=0.8, minimum detectable effect)
   - Rule of thumb: n ≈ 16 × σ² / δ² per group (t-test approximation)
3. **Define run duration:** minimum 1–2 full business cycles (usually 2 weeks)
4. **Randomization unit:** user-level (not session-level) to avoid leakage
5. **Define guardrail metrics:** metrics that must NOT degrade (e.g., revenue, NPS)

**Analysis phase:**
```
Primary metric test:
  - Calculate conversion rate / mean per group
  - Run appropriate significance test
  - Report: lift (%), p-value, 95% CI for lift, sample sizes

Guardrail checks:
  - Test each guardrail metric
  - If any guardrail is statistically significantly negative → DO NOT SHIP

Segmentation analysis (only after primary result):
  - Only explore pre-defined segments
  - Apply Bonferroni correction for multiple comparisons: α_adjusted = α / n_tests
```

**A/B testing pitfalls:**
| Pitfall | Description | Fix |
|---------|-------------|-----|
| **Peeking** | Stopping early when p < 0.05 | Pre-commit to sample size; use sequential testing |
| **Multiple comparisons** | Testing 20 metrics → 1 will be significant by chance | Pre-define primary metric; correct for multiples |
| **Network effects** | Treatment group users interact with control group users | Cluster randomization (by household, team, geography) |
| **Novelty effect** | Users engage with new feature just because it's new | Run test long enough to see post-novelty behavior |
| **Sample ratio mismatch** | Groups aren't the right size (SRM) | Check group sizes before analyzing; SRM = randomization bug |
| **Interaction effects** | Multiple tests running simultaneously contaminate results | Isolate test populations or use factorial design |

---

## Metric Frameworks

**North Star Metric:**
One metric that best captures the value delivered to customers AND correlates with long-term business health.
- Rule: must be a leading indicator, not a lagging one (revenue is lagging; "weekly active learners" is leading)
- Decompose into input metrics: 3–5 levers that drive the North Star

**HEART Framework (user experience metrics):**
| Dimension | What to Measure | Example |
|-----------|----------------|---------|
| **H**appiness | Satisfaction, NPS, CSAT | Post-session NPS score |
| **E**ngagement | Depth of interaction | Sessions per user per week |
| **A**doption | New feature uptake | % users who used feature in week 1 |
| **R**etention | Return rate | D7, D30, D90 retention |
| **T**ask success | Goal completion | % of checkout flows completed |

**AARRR Pirate Metrics:**
| Stage | Metric | Question |
|-------|--------|---------|
| **Acquisition** | New users / sessions | Where are users coming from? |
| **Activation** | % completing key first action | Did they have a good first experience? |
| **Retention** | Return rate at D1/D7/D30 | Do they come back? |
| **Revenue** | ARPU, conversion rate, LTV | Are they paying? |
| **Referral** | Viral coefficient, invite rate | Do they bring others? |

**OKR linkage:** Every metric tracked should trace to an OKR Key Result. Metrics not connected to an OKR are vanity metrics — track them separately or drop them.

---

## Cohort & Funnel Analysis

**Cohort analysis:**
```sql
-- Retention cohort: % of users from signup week still active in week N
WITH cohort AS (
  SELECT
    user_id,
    DATE_TRUNC('week', first_active_date) AS cohort_week
  FROM users
),
activity AS (
  SELECT
    c.user_id,
    c.cohort_week,
    DATE_DIFF('week', c.cohort_week, DATE_TRUNC('week', e.event_date)) AS weeks_since_cohort
  FROM cohort c
  JOIN events e USING (user_id)
)
SELECT
  cohort_week,
  weeks_since_cohort,
  COUNT(DISTINCT user_id) AS active_users,
  COUNT(DISTINCT user_id) * 100.0
    / FIRST_VALUE(COUNT(DISTINCT user_id)) OVER (
        PARTITION BY cohort_week ORDER BY weeks_since_cohort
      ) AS retention_pct
FROM activity
GROUP BY 1, 2
ORDER BY 1, 2
```

**Funnel analysis — what to look for:**
1. Identify each conversion step and calculate step-by-step conversion rate
2. Find the biggest drop-off (highest absolute loss, not just % loss)
3. Segment the funnel: do high-value users drop off at a different step?
4. Time-to-convert: are users taking days to complete steps that should take minutes?
5. Re-entry: what % of users who dropped at step N eventually return?

---

## Insight Communication

**What → So What → Now What framework:**
```
WHAT:     "Feature adoption dropped 18% last week, from 42% to 34%"
SO WHAT:  "At this rate, we miss our Q2 adoption target by ~2,500 users.
           This correlates with the onboarding change deployed Monday."
NOW WHAT: "Recommend reverting the onboarding change this week and A/B testing
           the new flow before full rollout. ETA to recover: ~10 days."
```

**Rule:** If you can't write the "Now What," the analysis isn't done.

**Audience calibration:**
| Audience | Lead with | Include | Omit |
|---------|----------|---------|------|
| **Executive** | Business impact + recommendation | 1 chart, key number, action | Methodology, SQL, error bars |
| **Product/PM** | User behavior insight + opportunity | Segmentation, trends, comparison | Raw data dumps |
| **Engineering** | Technical root cause | Query logic, data lineage, anomaly details | Business context fluff |
| **Data team** | Methodology + reproducibility | SQL, assumptions, caveats | High-level story only |

**Dashboard design principles:**
1. **One headline number** — most important KPI, prominently placed
2. **Context always** — never show a number without: period, trend, and target
3. **Signal > noise** — remove gridlines, 3D charts, rainbow colors, pie charts with >5 slices
4. **Consistent time windows** — use same period across all charts unless comparison is the point
5. **Action-oriented labels** — "Revenue is 12% below target" not "Revenue: $4.2M"
6. **Drilldown path** — summary → segment → individual record (for investigation)

---

## Anomaly Detection

**Statistical methods:**
| Method | When | Formula |
|--------|------|---------|
| **Z-score** | Normally distributed, no seasonality | z = (x − μ) / σ; flag \|z\| > 3 |
| **IQR method** | Skewed distributions | flag x < Q1 − 1.5×IQR or x > Q3 + 1.5×IQR |
| **Rolling z-score** | Time series with trend | compare day to rolling 28-day mean/std |
| **Seasonal decomposition** | Strong seasonality (weekly, monthly) | STL decomposition; check residual for anomalies |
| **Percentage change** | Business-friendly, simple | flag if WoW % change > 2σ of historical WoW changes |

**Anomaly investigation checklist:**
- [ ] Is this a data quality issue (pipeline failure, schema change)?
- [ ] Is this a product change (deploy, feature launch, experiment)?
- [ ] Is this an external event (holiday, news event, marketing campaign)?
- [ ] Is this real user behavior change?
- [ ] Does the anomaly persist after 24h (rules out one-time data glitches)?

---

## Data Storytelling

**Principles:**
1. **Audience first** — what does this person care about? What decision are they making?
2. **One core message** — what is the single most important thing they should take away?
3. **Build to the insight** — don't dump all charts; sequence them to tell a story
4. **Make the insight unavoidable** — annotate the key point directly on the chart
5. **Quantify the stakes** — "this costs $X/month" or "this affects Y% of users"
6. **Explicitly recommend** — end with a clear action, not "something to think about"

**Chart selection:**
| Question | Chart type |
|---------|-----------|
| How is X trending over time? | Line chart |
| How do groups compare? | Bar chart (horizontal for long labels) |
| What's the distribution? | Histogram or box plot |
| What's the relationship between X and Y? | Scatter plot |
| What's the composition? | Stacked bar (avoid pie for >4 slices) |
| What's the geographic pattern? | Choropleth map |
| How does a metric change across two dimensions? | Heatmap |

---

## Analyst Checklist

**Before analysis:**
- [ ] Business question stated in plain language (not "analyze the data")
- [ ] Success defined: what answer would change the decision?
- [ ] Data sources identified and freshness verified
- [ ] Grain of analysis defined (user-level? session-level? daily aggregate?)

**During analysis:**
- [ ] Data quality checked (nulls, duplicates, impossible values, date ranges)
- [ ] Joins validated (row count before/after join; no unexpected fan-out)
- [ ] Aggregations spot-checked against known totals
- [ ] Segments behave consistently (no Simpson's Paradox)

**Before sharing:**
- [ ] Insight passes "So What → Now What" test
- [ ] Caveats and limitations stated (sample size, data gaps, assumptions)
- [ ] Key number passes "smell test" (does this make business sense?)
- [ ] SQL/analysis is reproducible and documented
- [ ] Audience-appropriate format chosen

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| **Metric shopping** | Run analysis 10 ways until something is significant | Pre-register hypothesis and primary metric before analysis |
| **Chart soup** | 15 charts with no narrative | Pick 3 charts that tell the story; annotate the key insight |
| **Average blindness** | Reporting only means, hiding bimodal distributions | Show distribution, not just mean; segment before averaging |
| **Ignoring base rates** | "5% conversion improvement!" (from 1% → 1.05%) | Always show absolute change AND relative change |
| **Survival bias** | Analyzing only active users for retention | Include churned users; use full cohorts |
| **Spurious correlation** | Two unrelated metrics trend together | Test mechanism, not just correlation; add confounders |
| **Presenting without recommending** | "Interesting findings, something to consider" | Every analysis ends with explicit recommendation |
| **Analysis paralysis** | Perfect data doesn't exist; waiting for it | State confidence level; act on best available data with documented caveats |
| **Vanity metrics** | High numbers that don't correlate with business value | Tie every metric to a business outcome; audit quarterly |
