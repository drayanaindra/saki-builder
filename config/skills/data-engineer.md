# Data Engineering

**Ask:** What's the data source and volume? Batch or real-time? What's the SLA for freshness? Who are the consumers?

**Process:** Understand source → Design schema → Choose pipeline pattern → Implement transformations → Enforce quality → Monitor & alert

**Never:** Build without idempotency | Use SELECT * in production pipelines | Skip schema validation | Ignore backfill impact | Store credentials in code | Write one monolithic transformation — decompose

---

## Architecture Decision

| Pattern | When to Use | Tools |
|---------|-------------|-------|
| **Batch** | Daily/hourly cadence, historical loads, high volume | Spark, dbt, Airflow |
| **Micro-batch** | Near-real-time (minutes), simpler ops than streaming | Spark Structured Streaming, Flink |
| **Streaming** | Sub-second latency, event-driven, stateful aggregations | Kafka + Flink, Kafka Streams, Spark SS |
| **ELT** | Data warehouse targets (BigQuery, Snowflake, Redshift), raw → transform in DWH | dbt + Fivetran/Airbyte |
| **ETL** | Sensitive data (mask before landing), target has strict schema | Custom Spark, Glue |

| Storage Tier | When | Format |
|-------------|------|--------|
| **Data Warehouse** | Structured, SQL-first analytics, fast BI queries | Snowflake, BigQuery, Redshift |
| **Data Lake** | Raw/unstructured, schema-on-read, ML feature store | S3/GCS + Parquet |
| **Lakehouse** | Unified: ACID + schema on DWH + open format | Delta Lake, Apache Iceberg, Apache Hudi |

---

## Pipeline Design Principles

**Idempotency (non-negotiable):** Every task must produce the same output when run multiple times. Key patterns:
- Use `INSERT OVERWRITE` / `MERGE` not `INSERT INTO` for partitions
- Parameterize by `execution_date`, not `datetime.now()`
- Delete-then-insert for full-refresh jobs

**Exactly-once semantics (streaming):**
- Use Kafka consumer group offsets + transactional producers
- Checkpoint state to durable storage (S3, HDFS) at each micro-batch boundary
- Deduplicate on a natural key + watermark window

**Incremental vs Full Refresh:**
| Strategy | When | Risk |
|----------|------|------|
| Full refresh | Small table (< 10M rows), no delete tracking needed | Safe, slow at scale |
| Append-only | Immutable events, logs | Fast, no late-arrival handling |
| Incremental merge | Mutable records, CDC | Complex, requires dedup logic |
| Partition overwrite | Large partitioned tables, date-based updates | Safe + fast if partitioned correctly |

---

## dbt Patterns

**Model materialization selection:**
| Materialization | When |
|----------------|------|
| `view` | Lightweight transforms, frequently queried small datasets |
| `table` | Slow-running queries, used by BI tools |
| `incremental` | Large tables that grow over time |
| `snapshot` | SCD Type 2 tracking |

**Incremental strategies:**
```sql
-- append (immutable events)
{{ config(materialized='incremental', unique_key='event_id', incremental_strategy='append') }}

-- merge (mutable records)
{{ config(materialized='incremental', unique_key='user_id', incremental_strategy='merge') }}

-- delete+insert (partition overwrite)
{{ config(materialized='incremental', unique_key='date_key', incremental_strategy='delete+insert',
          partition_by={'field': 'date_key', 'data_type': 'date'}) }}
```

**Always add is_incremental guard:**
```sql
WHERE {% if is_incremental() %}
  updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

**dbt Tests (mandatory per model):**
- `not_null` on all primary keys
- `unique` on all primary keys
- `accepted_values` on status/enum columns
- `relationships` for all foreign keys
- Custom: row count bounds, freshness SLAs

**dbt Contracts (dbt 1.5+):** Define `columns:` with `data_type:` for all warehouse-facing models. Breaks build on schema drift — catches upstream source changes before they silently corrupt downstream.

---

## SCD Patterns

| Type | Description | dbt Approach | When |
|------|-------------|-------------|------|
| **SCD 0** | Never change — immutable attributes | `table` / `view` | Product category names |
| **SCD 1** | Overwrite — keep only latest value | `incremental` + `merge` | Email address, phone number |
| **SCD 2** | Full history — add `valid_from`, `valid_to`, `is_current` | `snapshot` | Customer segment, price tiers |
| **SCD 3** | Keep previous + current — add `prev_value` column | `incremental` + `merge` | Address (current + previous) |

**SCD 2 snapshot config:**
```yaml
snapshots:
  - name: dim_customer_snapshot
    config:
      strategy: timestamp
      unique_key: customer_id
      updated_at: updated_at
      target_schema: snapshots
```

---

## Orchestration (Airflow/Prefect/Dagster)

**DAG/Flow design rules:**
- One DAG = one logical pipeline (not one per table)
- Prefer `@task` (TaskFlow API) over Operators where possible
- Set `max_active_runs=1` for pipelines with data dependencies
- Always set `retries=3, retry_delay=timedelta(minutes=5)` for network I/O tasks
- Use `trigger_rule=TriggerRule.ALL_DONE` for cleanup tasks
- Never use XCom for large data — pass file paths/S3 keys, not payloads

**Backfill safety checklist:**
- [ ] Task is idempotent for past execution_dates
- [ ] `catchup=False` set intentionally (or `True` with idempotency verified)
- [ ] Downstream dependencies notified before backfill
- [ ] Source system can handle historical queries

**Airflow anti-patterns:**
- Top-level DB connections in DAG file (re-evaluated every scheduler heartbeat → connection pool exhaustion)
- `Variable.get()` in task definition (use environment variables or Airflow Connections instead)
- Fat PythonOperator tasks (extract callable to module for testability)

---

## Data Quality

**Quality dimensions:**
| Dimension | Check Type | Example |
|-----------|-----------|---------|
| Completeness | NOT NULL, row count floor | `COUNT(*) > yesterday * 0.8` |
| Freshness | Max timestamp recency | `MAX(event_time) > NOW() - INTERVAL 2h` |
| Uniqueness | Primary key duplicates | `COUNT(*) = COUNT(DISTINCT id)` |
| Validity | Domain rules | `status IN ('active','inactive','pending')` |
| Consistency | Cross-table referential integrity | FK join = 0 orphans |
| Accuracy | Business logic spot-checks | `revenue = quantity * unit_price ± 0.01` |

**Data Observability (dbt):**
```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests: [unique, not_null]
      - name: status
        tests:
          - accepted_values:
              values: ['placed','shipped','delivered','cancelled']
    tests:
      - dbt_utils.recency:
          datepart: hour
          field: created_at
          interval: 2
```

---

## Storage & Performance

**Partitioning strategy:**
- Partition by the column most commonly used in WHERE filters (usually date)
- Partition granularity: daily for most DWH tables; hourly only for high-volume streams
- Never partition by high-cardinality columns (user_id, UUID) — creates too many small files

**Clustering/sorting:**
- Cluster by columns used in GROUP BY or JOIN keys after partition column
- Snowflake: `CLUSTER BY (date_key, customer_id)`
- BigQuery: `CLUSTER BY customer_id, product_id` (up to 4 columns)

**File format selection:**
| Format | Best For | Notes |
|--------|---------|-------|
| **Parquet** | Analytics, columnar reads, Spark | Industry default for lake |
| **Delta Lake** | ACID on lake, UPDATE/DELETE/MERGE | Requires Spark/Databricks |
| **Iceberg** | Multi-engine ACID (Spark+Trino+Flink) | Open standard, vendor-neutral |
| **ORC** | Hive-heavy workloads | Older, less ecosystem support |
| **Avro** | Row-based, schema evolution, streaming | Good for Kafka schema registry |

---

## Data Contracts & Lineage

**Data contract (producer promise to consumer):**
```yaml
# data_contract.yaml
id: orders.fct_orders
schema:
  - name: order_id
    type: string
    required: true
    unique: true
  - name: total_amount
    type: decimal(10,2)
    required: true
sla:
  freshness: 2h
  availability: 99.5%
quality:
  row_count_min: 1000
  null_rate_max: 0.001
```

**Lineage checklist:**
- [ ] All source tables documented with owner + update cadence
- [ ] Column-level lineage captured (OpenLineage / dbt docs)
- [ ] Downstream consumers notified of schema changes
- [ ] Data contracts version-controlled alongside pipeline code

---

## Pipeline Design Checklist

**Before building:**
- [ ] Source schema and update cadence documented
- [ ] Target schema designed (dimensions, facts, naming convention)
- [ ] Idempotency strategy chosen (overwrite / merge / append)
- [ ] Backfill strategy defined
- [ ] SLA defined (freshness, row count bounds)

**During build:**
- [ ] No `SELECT *` — enumerate columns explicitly
- [ ] No hardcoded dates — use `{{ execution_date }}` or parameterize
- [ ] Transformations decomposed (staging → intermediate → marts)
- [ ] dbt tests on all primary keys (unique + not_null)
- [ ] Error handling: failed tasks alert within SLA window

**Before shipping:**
- [ ] Full backfill tested on historical date range
- [ ] Duplicate check on final output
- [ ] Schema matches downstream consumer expectations (contract validated)
- [ ] Runbook written: how to re-run, backfill, investigate failures

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| `INSERT INTO` instead of `MERGE`/overwrite | Duplicates on re-run | Use `MERGE` or `INSERT OVERWRITE PARTITION` |
| `datetime.now()` in pipeline logic | Non-idempotent; fails backfill | Use parameterized `execution_date` |
| Monolithic transformation | Untestable, hard to debug, no lineage | Decompose: stage → intermediate → mart |
| No null handling on keys | Silent data loss | NOT NULL + `COALESCE` on join keys |
| Ignoring late-arriving data | Incorrect aggregations | Use watermarks (streaming) or reprocessing window (batch) |
| One giant DAG | All-or-nothing failure, slow debug | Split by domain/cadence; use modular sub-DAGs |
| XCom for large data | Metadata DB bloat, serialization limits | Pass S3 paths / GCS URIs instead |
| `SELECT *` in production | Schema drift propagation | Always enumerate columns |
| No data contracts | Silent breaking changes | Define + enforce contracts on warehouse models |
| Schema drift ignored | Downstream consumers silently break | Use dbt contracts + CI schema validation |
