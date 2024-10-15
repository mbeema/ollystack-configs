# Database Observability Deep Dive

> Comprehensive consulting knowledge base covering relational databases (PostgreSQL, MySQL, SQL Server, Oracle), NoSQL databases (MongoDB, Redis, Cassandra, Elasticsearch, DynamoDB), time-series databases (InfluxDB, TimescaleDB), OpenTelemetry instrumentation, query performance, connection pooling, replication monitoring, security observability, cloud-managed databases, architecture patterns, and performance anti-pattern detection.

---

## Table of Contents

### Part I: Foundations and Relational Databases
1. [Database Observability Fundamentals](#1-database-observability-fundamentals)
2. [PostgreSQL Observability](#2-postgresql-observability)
3. [MySQL/MariaDB Observability](#3-mysqlmariadb-observability)
4. [Microsoft SQL Server Observability](#4-microsoft-sql-server-observability)
5. [Oracle Database Observability](#5-oracle-database-observability)
6. [Cross-Platform Patterns and Best Practices](#6-cross-platform-patterns-and-best-practices)

### Part II: NoSQL and Specialized Databases
7. [MongoDB Observability](#1-mongodb-observability)
8. [Redis Observability](#2-redis-observability)
9. [Apache Cassandra Observability](#3-apache-cassandra-observability)
10. [Elasticsearch and OpenSearch Observability](#4-elasticsearch-and-opensearch-observability)
11. [DynamoDB Observability](#5-dynamodb-observability)
12. [Time-Series Database Observability](#6-time-series-database-observability-influxdb-and-timescaledb)
13. [Cross-Database Observability Patterns](#7-cross-database-observability-patterns)

### Part III: OpenTelemetry Database Instrumentation
14. [OTel Semantic Conventions for Database Spans](#1-otel-semantic-conventions-for-database-spans)
15. [Auto-Instrumentation for Database Clients](#2-auto-instrumentation-for-database-clients)
16. [OTel Collector Database Receivers](#3-otel-collector-database-receivers)
17. [Database Query Sanitization](#4-database-query-sanitization)
18. [Trace-to-Metric Correlation Patterns](#5-trace-to-metric-correlation-patterns)
19. [OTel Database Client Metrics](#6-otel-database-client-metrics)

### Part IV: Query Performance Observability
20. [Query Lifecycle and Execution Plans](#7-query-lifecycle-and-execution-plans)
21. [Query Plan Regression Detection](#8-query-plan-regression-detection)
22. [N+1 Query Detection via Distributed Tracing](#9-n1-query-detection-via-distributed-tracing)
23. [Slow Query Analysis Workflow](#10-slow-query-analysis-workflow)
24. [Query Tagging and Fingerprinting](#11-query-tagging-and-fingerprinting)
25. [APM Integration and Real-Time Monitoring](#12-apm-integration-and-real-time-monitoring)

### Part V: Connection Pool Observability
26. [Connection Pool Metrics and Sizing](#13-connection-pool-metrics-and-sizing)
27. [HikariCP Monitoring (Java)](#14-hikaricp-monitoring-java)
28. [PgBouncer Monitoring](#15-pgbouncer-monitoring)
29. [ProxySQL Monitoring](#16-proxysql-monitoring)
30. [Connection Leak Detection and Exhaustion Diagnosis](#17-connection-leak-detection-and-exhaustion-diagnosis)
31. [Cloud Provider Connection Limits](#18-cloud-provider-connection-limits)

### Part VI: Database Reliability and Replication
32. [Replication Lag Monitoring](#19-replication-lag-monitoring)
33. [Failover and Split-Brain Detection](#20-failover-and-split-brain-detection)
34. [Consensus Protocol Monitoring](#21-consensus-protocol-monitoring)
35. [Backup and WAL Monitoring](#22-backup-and-wal-monitoring)
36. [Database Chaos Engineering](#23-database-chaos-engineering)

### Part VII: Database Security Observability
37. [Audit Logging and Access Monitoring](#24-audit-logging-and-access-monitoring)
38. [Anomalous Query and SQL Injection Detection](#25-anomalous-query-and-sql-injection-detection)
39. [Encryption and Firewall Monitoring](#26-encryption-and-firewall-monitoring)
40. [Compliance Audit Trails](#27-compliance-audit-trails)

### Part VIII: Cloud-Managed Database Observability
41. [AWS RDS and Aurora Observability](#28-aws-rds-and-aurora-observability)
42. [Azure SQL Database Observability](#29-azure-sql-database-observability)
43. [Google Cloud SQL Observability](#30-google-cloud-sql-observability)
44. [Cloud-Native vs Bring-Your-Own Monitoring](#31-cloud-native-vs-bring-your-own-monitoring)

### Part IX: Architecture Patterns and Operations
45. [Agent-Based vs Agentless Monitoring](#32-agent-based-vs-agentless-monitoring)
46. [Sidecar Pattern for Database Proxies](#33-sidecar-pattern-for-database-proxies)
47. [Database Observability Data Pipeline](#34-database-observability-data-pipeline)
48. [Top 20 Database Alerts](#35-top-20-database-alerts)
49. [Database SLOs and SLIs](#36-database-slos-and-slis)
50. [Grafana Dashboard Best Practices](#37-grafana-dashboard-best-practices)
51. [Cost of Database Downtime](#38-cost-of-database-downtime)

### Part X: Performance Anti-Patterns
52. [N+1 Queries](#39-n1-queries)
53. [Missing Indexes](#40-missing-indexes)
54. [Connection Exhaustion](#41-connection-exhaustion)
55. [Lock Contention](#42-lock-contention)
56. [Bloat and Fragmentation](#43-bloat-and-fragmentation)
57. [Unbounded Queries and Hot Partitions](#44-unbounded-queries-and-hot-partitions)
58. [Memory Pressure and Buffer Cache](#45-memory-pressure-and-buffer-cache)
59. [Replication Lag Spirals and Transaction Log Growth](#46-replication-lag-spirals-and-transaction-log-growth)
60. [Database Observability Maturity Model](#summary-database-observability-maturity-model)

---


# Part I: Foundations and Relational Databases

---

## 1. Database Observability Fundamentals

### 1.1 The Three Pillars Applied to Databases

Traditional observability pillars -- metrics, logs, and traces -- take on database-specific characteristics that differ significantly from application-level telemetry.

#### Metrics for Databases

Database metrics fall into several categories:

| Category | Examples | Collection Method |
|----------|---------|-------------------|
| **Resource metrics** | CPU, memory, disk I/O, network | OS-level / node_exporter |
| **Engine metrics** | Buffer cache hit ratio, lock waits, checkpoint rate | Database catalog views |
| **Query metrics** | Execution count, mean duration, rows processed | Statement statistics views |
| **Replication metrics** | Lag (write/flush/replay), bytes sent/received | Replication status views |
| **Connection metrics** | Active, idle, waiting connections; pool utilization | Connection pool stats |
| **Storage metrics** | Table/index size, bloat, dead tuples, WAL generation | Storage statistics views |

**Key principle:** Database metrics must capture both the *demand* side (query workload characteristics) and the *supply* side (resource capacity and utilization). Most monitoring tools focus only on supply-side metrics, missing critical demand-side signals.

#### Logs for Databases

Database logs provide event-level detail that metrics cannot:

- **Slow query logs**: Individual queries exceeding duration thresholds, with execution plans
- **Error logs**: Authentication failures, connection rejections, replication errors, corruption
- **DDL/DML audit logs**: Schema changes, privilege grants, data modifications
- **Checkpoint/vacuum logs**: Background maintenance operations and their duration
- **Lock/deadlock logs**: Contention events with participating sessions and queries
- **Replication logs**: State changes, failover events, lag spikes

**Key principle:** Database logs must be structured, timestamped, and correlated with query identifiers to enable trace-level analysis. Raw text logs from legacy configurations are insufficient for modern observability.

#### Traces for Databases

Database traces connect application-level distributed traces to database operations:

- **Span-level visibility**: Each database call becomes a span in the distributed trace with `db.system`, `db.statement`, `db.operation`, `db.name` semantic attributes
- **Query plan correlation**: Linking slow spans to EXPLAIN ANALYZE output
- **Connection acquisition spans**: Measuring time waiting for a connection from the pool
- **Transaction boundary spans**: Visibility into transaction duration and lock hold times

**OpenTelemetry semantic conventions for databases:**
```
db.system           = "postgresql" | "mysql" | "mssql" | "oracle"
db.name             = "orders_db"
db.statement        = "SELECT * FROM orders WHERE status = ?"
db.operation         = "SELECT"
db.user             = "app_user"
db.connection_string = (redacted)
server.address      = "db-primary.internal"
server.port         = 5432
```

### 1.2 Database-Specific Signals

Beyond the three pillars, databases emit unique signals that require specialized collection and interpretation:

#### Query Performance Signals
- **Query throughput**: Queries per second (QPS), broken down by type (SELECT/INSERT/UPDATE/DELETE)
- **Query latency distribution**: p50, p95, p99 execution times -- averages mask tail latency
- **Query plan changes**: When the optimizer chooses a different execution plan, performance can shift dramatically
- **Full table scans**: Sequential scans on large tables indicate missing indexes or suboptimal queries
- **Rows examined vs. rows returned**: A high ratio indicates inefficient query execution

#### Wait Event Signals
- **I/O waits**: Time spent waiting for disk reads/writes (buffer pool misses)
- **Lock waits**: Time spent waiting to acquire row, table, or advisory locks
- **CPU waits**: Scheduler yields indicating CPU saturation
- **Network waits**: Replication or client communication delays
- **Internal waits**: Latch contention, buffer pin waits, WAL write waits

#### Lock Contention Signals
- **Lock queue depth**: Number of sessions waiting for locks
- **Lock hold duration**: How long locks are held (long-running transactions)
- **Deadlock frequency**: Deadlocks per minute/hour
- **Lock escalation events**: Row locks escalating to table locks (SQL Server)

#### Buffer/Cache Efficiency Signals
- **Buffer cache hit ratio**: Percentage of reads served from memory (target: >99% for OLTP)
- **Shared buffer utilization**: How much of allocated buffer memory is in use
- **Dirty buffer ratio**: Percentage of modified pages pending write-back
- **Checkpoint spread**: Whether checkpoints complete within their target window

#### Replication Lag Signals
- **Write lag**: Time for WAL to reach the standby
- **Flush lag**: Time for WAL to be flushed to disk on the standby
- **Replay lag**: Time for WAL to be applied on the standby
- **Bytes pending**: Volume of un-replicated data

#### Connection Pool Health Signals
- **Pool utilization**: Active connections / max pool size
- **Wait queue depth**: Clients waiting for a connection
- **Connection churn**: Rate of new connections being created
- **Idle connection ratio**: Wasted pool capacity

### 1.3 RED Method for Databases

The RED method (Rate, Errors, Duration), originally designed for request-driven microservices, adapts to databases as follows:

| Signal | Database Application | Key Metrics |
|--------|---------------------|-------------|
| **Rate** | Query throughput | Queries/sec by type (SELECT, INSERT, UPDATE, DELETE), transactions/sec (TPS), commits/sec, rollbacks/sec |
| **Errors** | Failed operations | Failed queries/sec, deadlocks/sec, connection refusals/sec, replication errors/sec, constraint violations/sec |
| **Duration** | Query latency | Mean query time, p95/p99 query time, transaction duration, lock wait time, connection acquisition time |

**PromQL examples (using generic Prometheus exporters):**

```promql
# Rate: Query throughput
rate(pg_stat_database_xact_commit{datname="mydb"}[5m])
  + rate(pg_stat_database_xact_rollback{datname="mydb"}[5m])

# Errors: Rollback ratio
rate(pg_stat_database_xact_rollback{datname="mydb"}[5m])
  / (rate(pg_stat_database_xact_commit{datname="mydb"}[5m])
     + rate(pg_stat_database_xact_rollback{datname="mydb"}[5m]))

# Duration: Average query time from pg_stat_statements
rate(pg_stat_statements_seconds_total[5m])
  / rate(pg_stat_statements_calls_total[5m])
```

### 1.4 USE Method for Database Resources

The USE method (Utilization, Saturation, Errors) applies to database *resources* rather than workload:

| Resource | Utilization | Saturation | Errors |
|----------|-------------|------------|--------|
| **CPU** | % CPU used by DB process | Run queue length, scheduler yields | N/A |
| **Memory (Buffer Pool)** | Buffer pool usage / allocated | Pages evicted/sec, cache miss rate | OOM kills, allocation failures |
| **Disk I/O** | IOPS / max IOPS, throughput / max throughput | I/O queue depth, await time | Disk errors, read/write failures |
| **Connections** | Active connections / max_connections | Connection wait queue, refused connections | Authentication failures, timeout errors |
| **Locks** | Rows/tables locked / total | Lock wait queue depth, lock wait time | Deadlocks |
| **WAL/Redo Log** | WAL generation rate / disk throughput | WAL writer stalls, log buffer waits | WAL corruption, archive failures |
| **Temp Space** | Temp table usage / allocated temp space | Temp file spills (sorts/joins to disk) | Out of temp space errors |

### 1.5 Golden Signals for Databases

Google's Four Golden Signals adapted for databases:

**1. Latency:**
- Successful query duration (p50, p95, p99)
- Failed query duration (errors should be tracked separately -- some "errors" are fast, masking true latency)
- Transaction commit latency
- Replication apply latency

**2. Traffic:**
- Queries per second (by type)
- Transactions per second
- Rows read/written per second
- Bytes sent/received per second
- Active sessions count

**3. Errors:**
- Query errors per second
- Connection errors per second
- Replication errors per second
- Deadlocks per second
- Constraint violation rate
- Timeout rate

**4. Saturation:**
- Connection pool utilization (% of max_connections used)
- Buffer cache pressure (eviction rate, miss rate)
- Disk I/O saturation (queue depth, utilization %)
- Lock contention (wait time as % of total execution time)
- Replication lag (indicates the standby cannot keep up)
- WAL/redo log utilization

### 1.6 Database Observability vs Traditional Monitoring

| Aspect | Traditional DB Monitoring | Database Observability |
|--------|--------------------------|----------------------|
| **Focus** | "Is the database up?" | "Why is this query slow for this user?" |
| **Granularity** | Instance-level metrics (CPU, memory, connections) | Query-level, transaction-level, session-level |
| **Correlation** | Siloed dashboards per database | Traces linking app requests to specific DB operations |
| **Query visibility** | Slow query log (reactive, after-the-fact) | Real-time query statistics with plan analysis |
| **Root cause** | "Disk I/O is high" (symptom) | "Query X changed plans, now doing a seq scan on table Y, causing I/O spike" (root cause) |
| **Replication** | "Replication lag is 30s" | "Lag spiked because a large transaction on the primary took 25s to replicate" |
| **Proactive** | Threshold-based alerts | Anomaly detection on query patterns, regression detection |
| **Cost awareness** | N/A | Query cost attribution, resource consumption per tenant |
| **Context** | Database metrics in isolation | Database telemetry joined with application traces, deployment events, config changes |

### 1.7 Query-Level Observability

Query-level observability is the single most impactful capability for database performance management. Here is why individual query performance matters:

**The 80/20 Rule of Database Performance:** In most production databases, 80% of resource consumption comes from fewer than 20% of distinct query patterns. Identifying and optimizing these top queries delivers outsized performance improvements.

**Query Regression Detection:** A query that ran in 5ms yesterday and runs in 500ms today -- because an index was dropped, statistics went stale, or the optimizer chose a different plan -- can be invisible at the instance level but devastating at the application level.

**Capacity Planning:** Understanding per-query resource consumption (CPU time, I/O, memory) enables accurate capacity forecasting as workload grows.

**Multi-Tenant Fairness:** In shared databases, query-level observability identifies which tenant or application component is consuming disproportionate resources.

**The Query Observability Stack:**
```
Layer 4: Distributed Trace Correlation (OTel spans with db.statement)
Layer 3: Query Plan Analysis (EXPLAIN ANALYZE, plan forcing, plan history)
Layer 2: Query Statistics (pg_stat_statements, Performance Schema, Query Store, AWR)
Layer 1: Query Logging (slow query log, auto_explain, Extended Events)
Layer 0: Instance Metrics (QPS, latency distribution, error rate)
```

Each layer provides increasing detail at increasing cost. Production systems should always have Layers 0-2 enabled, with Layer 3 on-demand and Layer 4 for critical paths.

---

## 2. PostgreSQL Observability

PostgreSQL provides the richest built-in observability instrumentation of any open-source database, through its Statistics Collector subsystem and a comprehensive set of system views.

### 2.1 pg_stat_statements

The `pg_stat_statements` extension is the single most important observability tool for PostgreSQL. It tracks execution statistics for all SQL statements executed by a server.

#### Configuration

```ini
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements'  # Requires restart
pg_stat_statements.max = 10000          # Max distinct statements tracked (default: 5000)
pg_stat_statements.track = 'top'        # top | all | none (top = only top-level statements)
pg_stat_statements.track_utility = on   # Track DDL and utility commands
pg_stat_statements.track_planning = on  # Track planning time (PG 13+)
pg_stat_statements.save = on            # Persist stats across server restarts
compute_query_id = on                   # Required for PG 14+ (auto-enabled if extension loaded)
```

After configuring, create the extension:
```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

#### Key Columns and Their Meaning

| Column | Description | Use Case |
|--------|-------------|----------|
| `userid` | OID of user who executed the statement | Per-user workload analysis |
| `dbid` | OID of database | Per-database workload analysis |
| `queryid` | Hash of normalized query | Unique query pattern identifier |
| `query` | Normalized query text (parameters replaced with $1, $2...) | Query pattern identification |
| `calls` | Number of executions | Query frequency |
| `total_exec_time` | Total execution time (ms) | Total resource impact |
| `mean_exec_time` | Average execution time (ms) | Per-call cost |
| `min_exec_time` / `max_exec_time` | Fastest / slowest execution | Variance detection |
| `stddev_exec_time` | Standard deviation of execution time | Consistency analysis |
| `rows` | Total rows returned/affected | Data volume |
| `shared_blks_hit` | Shared buffer hits | Cache efficiency |
| `shared_blks_read` | Shared buffer reads (from disk or OS cache) | I/O pressure |
| `shared_blks_dirtied` | Blocks dirtied by this query | Write amplification |
| `shared_blks_written` | Blocks written by this query | Direct I/O |
| `local_blks_hit` / `local_blks_read` | Temp table buffer stats | Temp table usage |
| `temp_blks_read` / `temp_blks_written` | Sort/hash spill to disk | work_mem pressure |
| `blk_read_time` / `blk_write_time` | I/O time (requires track_io_timing = on) | True I/O cost |
| `plans` (PG 13+) | Number of times planned | Plan cache effectiveness |
| `total_plan_time` (PG 13+) | Total planning time | Planning overhead |
| `wal_records` / `wal_bytes` (PG 13+) | WAL generated | Replication/recovery impact |
| `jit_functions` / `jit_generation_time` (PG 15+) | JIT compilation stats | JIT overhead |

#### Essential Queries

**Top 10 queries by total execution time (resource hogs):**
```sql
SELECT
    queryid,
    substr(query, 1, 80) AS query_preview,
    calls,
    round(total_exec_time::numeric, 2) AS total_time_ms,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows,
    round((100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2)
        AS cache_hit_pct
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

**Top 10 queries by mean execution time (slowest individual queries):**
```sql
SELECT
    queryid,
    substr(query, 1, 80) AS query_preview,
    calls,
    round(mean_exec_time::numeric, 2) AS avg_time_ms,
    round(max_exec_time::numeric, 2) AS max_time_ms,
    round(stddev_exec_time::numeric, 2) AS stddev_ms,
    rows / NULLIF(calls, 0) AS avg_rows
FROM pg_stat_statements
WHERE calls > 10  -- Filter out rare queries
ORDER BY mean_exec_time DESC
LIMIT 10;
```

**Queries with worst cache hit ratio (I/O intensive):**
```sql
SELECT
    queryid,
    substr(query, 1, 80) AS query_preview,
    calls,
    shared_blks_hit,
    shared_blks_read,
    round((100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2)
        AS cache_hit_pct,
    round(blk_read_time::numeric, 2) AS disk_read_time_ms
FROM pg_stat_statements
WHERE shared_blks_read > 1000  -- Only queries doing significant I/O
ORDER BY shared_blks_read DESC
LIMIT 10;
```

**Queries generating the most WAL (replication impact):**
```sql
-- PostgreSQL 13+
SELECT
    queryid,
    substr(query, 1, 80) AS query_preview,
    calls,
    wal_records,
    pg_size_pretty(wal_bytes) AS wal_generated,
    round(wal_bytes::numeric / NULLIF(calls, 0), 0) AS wal_bytes_per_call
FROM pg_stat_statements
WHERE wal_bytes > 0
ORDER BY wal_bytes DESC
LIMIT 10;
```

**Queries spilling to disk (work_mem candidates):**
```sql
SELECT
    queryid,
    substr(query, 1, 80) AS query_preview,
    calls,
    temp_blks_read + temp_blks_written AS temp_blks_total,
    round((temp_blks_read + temp_blks_written)::numeric / NULLIF(calls, 0), 0)
        AS temp_blks_per_call
FROM pg_stat_statements
WHERE temp_blks_read + temp_blks_written > 0
ORDER BY temp_blks_read + temp_blks_written DESC
LIMIT 10;
```

#### Query Normalization

`pg_stat_statements` normalizes queries by replacing literal constants with parameter placeholders:

```sql
-- These two queries:
SELECT * FROM orders WHERE customer_id = 42;
SELECT * FROM orders WHERE customer_id = 99;

-- Become one normalized entry:
SELECT * FROM orders WHERE customer_id = $1;
```

This enables tracking of query *patterns* rather than individual query instances. The `queryid` hash is computed from the normalized query parse tree, making it stable across parameter changes.

**Important limitations:**
- Query text is truncated at `track_activity_query_size` (default: 1024 bytes) -- increase for complex queries
- `pg_stat_statements_reset()` clears all statistics -- schedule periodic resets to prevent stale data
- High `pg_stat_statements.max` with `track = all` can increase shared memory usage

### 2.2 pg_stat_activity

`pg_stat_activity` provides real-time visibility into all current database sessions.

#### Key Columns

| Column | Description |
|--------|-------------|
| `pid` | Backend process ID |
| `datname` | Database name |
| `usename` | User name |
| `application_name` | Application identifier |
| `client_addr` | Client IP address |
| `state` | `active`, `idle`, `idle in transaction`, `idle in transaction (aborted)`, `fastpath function call`, `disabled` |
| `wait_event_type` | Category: `LWLock`, `Lock`, `BufferPin`, `Activity`, `Client`, `Extension`, `IO`, `IPC`, `Timeout` |
| `wait_event` | Specific wait event name |
| `query` | Current or last executed query |
| `query_start` | When the current query began |
| `xact_start` | When the current transaction began |
| `state_change` | When the state last changed |
| `backend_type` | `client backend`, `autovacuum worker`, `walwriter`, etc. |

#### Essential Queries

**Active queries with wait events:**
```sql
SELECT
    pid,
    usename,
    datname,
    state,
    wait_event_type,
    wait_event,
    now() - query_start AS query_duration,
    now() - xact_start AS xact_duration,
    substr(query, 1, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
    AND pid != pg_backend_pid()
ORDER BY query_start ASC;
```

**Long-running transactions (transaction leak detection):**
```sql
SELECT
    pid,
    usename,
    datname,
    state,
    now() - xact_start AS xact_duration,
    now() - query_start AS query_duration,
    substr(query, 1, 100) AS query_preview
FROM pg_stat_activity
WHERE state = 'idle in transaction'
    AND now() - xact_start > interval '5 minutes'
ORDER BY xact_start ASC;
```

**Blocking query chains (lock dependency tree):**
```sql
SELECT
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    substr(blocked_activity.query, 1, 60) AS blocked_query,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    substr(blocking_activity.query, 1, 60) AS blocking_query,
    now() - blocked_activity.query_start AS blocked_duration
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity
    ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity
    ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted
ORDER BY blocked_duration DESC;
```

**Connection state summary:**
```sql
SELECT
    datname,
    usename,
    state,
    count(*) AS connection_count,
    max(now() - state_change) AS longest_in_state
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY datname, usename, state
ORDER BY connection_count DESC;
```

### 2.3 pg_stat_user_tables

Provides per-table access statistics critical for understanding workload patterns and maintenance health.

#### Key Columns and Queries

**Tables needing index attention (sequential scan heavy):**
```sql
SELECT
    schemaname,
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    CASE WHEN seq_scan + idx_scan > 0
        THEN round(100.0 * seq_scan / (seq_scan + idx_scan), 2)
        ELSE 0
    END AS seq_scan_pct,
    pg_size_pretty(pg_relation_size(relid)) AS table_size
FROM pg_stat_user_tables
WHERE seq_scan > 100  -- Tables with significant sequential scans
    AND pg_relation_size(relid) > 10 * 1024 * 1024  -- Larger than 10 MB
ORDER BY seq_tup_read DESC
LIMIT 20;
```

**Tables with bloat problems (dead tuple accumulation):**
```sql
SELECT
    schemaname,
    relname AS table_name,
    n_live_tup,
    n_dead_tup,
    CASE WHEN n_live_tup > 0
        THEN round(100.0 * n_dead_tup / n_live_tup, 2)
        ELSE 0
    END AS dead_tup_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    autovacuum_count,
    vacuum_count
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC
LIMIT 20;
```

**Autovacuum effectiveness monitoring:**
```sql
SELECT
    schemaname,
    relname AS table_name,
    n_dead_tup,
    n_live_tup,
    last_autovacuum,
    autovacuum_count,
    now() - last_autovacuum AS time_since_last_autovacuum,
    -- Threshold calculation: when will autovacuum trigger?
    -- Default: 50 + 0.2 * n_live_tup
    (50 + 0.2 * n_live_tup)::bigint AS autovacuum_threshold,
    CASE WHEN n_dead_tup > (50 + 0.2 * n_live_tup)
        THEN 'OVERDUE'
        ELSE 'OK'
    END AS vacuum_status
FROM pg_stat_user_tables
WHERE n_live_tup > 1000
ORDER BY n_dead_tup DESC;
```

### 2.4 pg_stat_bgwriter

Tracks checkpoint and background writer activity -- critical for understanding I/O patterns.

```sql
SELECT
    checkpoints_timed,
    checkpoints_req,
    -- Requested checkpoints indicate WAL pressure or frequent DDL
    round(100.0 * checkpoints_req / NULLIF(checkpoints_timed + checkpoints_req, 0), 2)
        AS pct_requested_checkpoints,
    checkpoint_write_time,
    checkpoint_sync_time,
    -- Average checkpoint duration
    round(checkpoint_write_time / NULLIF(checkpoints_timed + checkpoints_req, 0), 2)
        AS avg_checkpoint_write_ms,
    round(checkpoint_sync_time / NULLIF(checkpoints_timed + checkpoints_req, 0), 2)
        AS avg_checkpoint_sync_ms,
    buffers_checkpoint,
    buffers_clean,
    buffers_backend,
    -- Backend writes indicate buffer pool pressure
    round(100.0 * buffers_backend / NULLIF(buffers_checkpoint + buffers_clean + buffers_backend, 0), 2)
        AS pct_backend_writes,
    maxwritten_clean,
    buffers_alloc
FROM pg_stat_bgwriter;
```

**Alert thresholds:**
- `pct_requested_checkpoints` > 10%: WAL generation is too high or `checkpoint_timeout` too large
- `pct_backend_writes` > 10%: `shared_buffers` too small or `bgwriter_lru_maxpages` too low
- `avg_checkpoint_sync_ms` > 30000: Disk I/O subsystem is slow
- `maxwritten_clean` increasing: Background writer cannot keep up

### 2.5 pg_stat_replication

Monitors streaming replication health from the primary server.

```sql
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    -- Byte lag calculations
    pg_wal_lsn_diff(sent_lsn, write_lsn) AS write_lag_bytes,
    pg_wal_lsn_diff(sent_lsn, flush_lsn) AS flush_lag_bytes,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes,
    -- Time-based lag (PG 10+)
    write_lag,
    flush_lag,
    replay_lag,
    sync_state,  -- async, sync, potential, quorum
    sync_priority
FROM pg_stat_replication
ORDER BY replay_lag DESC NULLS LAST;
```

**Replication slot monitoring (prevent WAL accumulation):**
```sql
SELECT
    slot_name,
    slot_type,
    database,
    active,
    pg_size_pretty(
        pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)
    ) AS retained_wal,
    pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS retained_wal_bytes
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;
```

**PromQL for replication monitoring (postgres_exporter):**
```promql
# Replication lag in seconds
pg_replication_lag{instance="primary:9187"}

# Alert: Replication lag > 30 seconds for 5 minutes
# (in Prometheus alerting rules)
# - alert: PostgreSQLReplicationLag
#   expr: pg_replication_lag > 30
#   for: 5m
#   labels:
#     severity: warning

# WAL retained by inactive slots (bytes)
pg_replication_slots_pg_wal_lsn_diff{active="false"}
```

### 2.6 pg_stat_wal (PostgreSQL 14+)

Monitors WAL generation rate -- essential for sizing replication bandwidth and archive storage.

```sql
SELECT
    wal_records,
    wal_fpi,           -- Full page images (increase after checkpoint)
    wal_bytes,
    pg_size_pretty(wal_bytes) AS wal_generated_total,
    wal_buffers_full,  -- Times WAL buffers were full (contention indicator)
    wal_write,
    wal_sync,
    wal_write_time,    -- Total time spent writing WAL (ms)
    wal_sync_time,     -- Total time spent syncing WAL (ms)
    stats_reset
FROM pg_stat_wal;
```

### 2.7 pg_stat_io (PostgreSQL 16+)

Provides granular I/O statistics broken down by backend type and I/O context.

```sql
-- I/O operations by backend type
SELECT
    backend_type,
    object,
    context,
    reads,
    read_time,
    writes,
    write_time,
    writebacks,
    writeback_time,
    extends,
    extend_time,
    hits,
    evictions,
    reuses,
    fsyncs,
    fsync_time
FROM pg_stat_io
WHERE reads > 0 OR writes > 0
ORDER BY backend_type, object, context;
```

**PostgreSQL 18 additions:** `read_bytes`, `write_bytes`, `extend_bytes` columns for byte-level I/O tracking, plus WAL I/O tracking for the first time.

### 2.8 pg_locks: Lock Monitoring and Deadlock Detection

```sql
-- Current lock contention
SELECT
    l.locktype,
    l.relation::regclass AS table_name,
    l.mode,
    l.granted,
    l.pid,
    a.usename,
    a.state,
    substr(a.query, 1, 80) AS query_preview,
    now() - a.query_start AS lock_duration
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted
ORDER BY lock_duration DESC;

-- Deadlock detection configuration
-- postgresql.conf:
-- deadlock_timeout = 1s            # Default; time to wait before checking for deadlock
-- log_lock_waits = on              # Log when sessions wait longer than deadlock_timeout
```

### 2.9 EXPLAIN ANALYZE and auto_explain

#### Manual Query Plan Analysis
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT o.*, c.name
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.status = 'pending'
    AND o.created_at > now() - interval '7 days';
```

Key plan elements to examine:
- **Seq Scan vs Index Scan**: Sequential scans on large tables indicate missing indexes
- **Nested Loop vs Hash Join vs Merge Join**: Inappropriate join methods for data sizes
- **Rows estimated vs actual**: Large discrepancies indicate stale statistics (run ANALYZE)
- **Buffers shared hit/read**: Cache efficiency for this query
- **Sort/Hash spills**: `Sort Method: external merge` means spilling to disk

#### auto_explain Extension (Automatic Slow Query Plan Logging)

```ini
# postgresql.conf
shared_preload_libraries = 'pg_stat_statements, auto_explain'

auto_explain.log_min_duration = 1000  # Log plans for queries > 1 second
auto_explain.log_analyze = on          # Include actual row counts (EXPLAIN ANALYZE)
auto_explain.log_buffers = on          # Include buffer usage
auto_explain.log_timing = on           # Include timing information
auto_explain.log_triggers = on         # Include trigger execution stats
auto_explain.log_verbose = on          # Include output column lists
auto_explain.log_format = json         # JSON format for machine parsing
auto_explain.log_nested_statements = on # Include nested statements (functions)
auto_explain.sample_rate = 1.0         # Sample rate (1.0 = all qualifying queries)
```

**Production recommendation:** Start with `log_min_duration = 5000` (5s) and lower gradually. Use `sample_rate = 0.1` on high-traffic systems to reduce overhead.

### 2.10 PostgreSQL Logging Configuration for Observability

```ini
# postgresql.conf -- Observability-optimized logging

# Slow query logging
log_min_duration_statement = 1000     # Log queries > 1 second (-1 to disable)
log_statement = 'ddl'                  # Log DDL statements (none/ddl/mod/all)

# Lock monitoring
log_lock_waits = on                    # Log when locks are held > deadlock_timeout
deadlock_timeout = 1s                  # How long to wait before deadlock check

# Checkpoint logging
log_checkpoints = on                   # Log checkpoint start/completion with stats

# Autovacuum logging
log_autovacuum_min_duration = 0        # Log all autovacuum actions (0 = all, -1 = none)

# Connection logging
log_connections = on                   # Log each connection
log_disconnections = on                # Log each disconnection with duration

# I/O timing (small overhead but very valuable)
track_io_timing = on                   # Required for blk_read_time/blk_write_time in pg_stat_statements

# Query text length
track_activity_query_size = 4096       # Increase from default 1024 for complex queries

# Logging format
log_line_prefix = '%m [%p] %q%u@%d '  # Timestamp, PID, user, database
log_destination = 'csvlog'             # CSV format for easy parsing
logging_collector = on                 # Enable log file collection
```

### 2.11 Key PostgreSQL PromQL Queries (postgres_exporter)

```promql
# === Connection Metrics ===

# Connection utilization (% of max)
pg_stat_activity_count{state="active"} / pg_settings_max_connections * 100

# Connections by state
sum by (state) (pg_stat_activity_count)

# === Performance Metrics ===

# Transaction rate
rate(pg_stat_database_xact_commit{datname="mydb"}[5m])

# Cache hit ratio (should be > 99%)
pg_stat_database_blks_hit{datname="mydb"}
  / (pg_stat_database_blks_hit{datname="mydb"}
     + pg_stat_database_blks_read{datname="mydb"}) * 100

# Rows returned vs fetched (index efficiency)
rate(pg_stat_database_tup_returned{datname="mydb"}[5m])
  / rate(pg_stat_database_tup_fetched{datname="mydb"}[5m])

# Temporary file usage (bytes)
rate(pg_stat_database_temp_bytes{datname="mydb"}[5m])

# Deadlocks per second
rate(pg_stat_database_deadlocks{datname="mydb"}[5m])

# === Replication Metrics ===

# Replication lag in seconds
pg_replication_lag

# WAL receiver status
pg_stat_wal_receiver_status

# === Table Metrics ===

# Dead tuples ratio
pg_stat_user_tables_n_dead_tup / (pg_stat_user_tables_n_live_tup + 1) * 100

# Sequential scans on large tables
pg_stat_user_tables_seq_scan{relname=~"orders|customers|transactions"}
```

### 2.12 Connection Pooling Observability: PgBouncer

PgBouncer is the most widely deployed connection pooler for PostgreSQL. Monitoring it is essential because application-visible connection behavior depends on pooler health.

#### Key PgBouncer Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `cl_active` | Client connections actively linked to a server connection | N/A (informational) |
| `cl_waiting` | Client connections waiting for a server connection | > 0 sustained for > 30s |
| `cl_cancel_req` | Client cancel requests | Sustained > 0 |
| `sv_active` | Server connections running a query | N/A (informational) |
| `sv_idle` | Server connections idle and available | Should be > 0 |
| `sv_used` | Server connections idle but recently used | N/A |
| `sv_login` | Server connections in the login process | Sustained > 0 indicates auth issues |
| `avg_query_time` | Average query time in microseconds | Monitor trend, not absolute value |
| `avg_xact_time` | Average transaction time in microseconds | > 1s in OLTP warrants investigation |
| `avg_wait_time` | Average time clients waited for a connection | > 100ms is concerning |
| `total_query_count` | Queries processed (cumulative) | Use for rate calculation |
| `total_xact_count` | Transactions processed (cumulative) | Use for rate calculation |

#### PgBouncer SHOW Commands

```sql
-- Pool statistics
SHOW POOLS;

-- Per-database statistics
SHOW STATS;

-- Per-database detailed statistics
SHOW STATS_TOTALS;

-- Server connections
SHOW SERVERS;

-- Client connections
SHOW CLIENTS;

-- Configuration
SHOW CONFIG;
```

#### PgBouncer Prometheus Exporter

Using `pgbouncer_exporter` (prometheus-community):

```promql
# Client connections waiting
pgbouncer_pools_client_waiting_connections{database="mydb"}

# Pool utilization
pgbouncer_pools_server_active_connections{database="mydb"}
  / pgbouncer_databases_pool_size{database="mydb"} * 100

# Average query time trend
rate(pgbouncer_stats_queries_duration_seconds_total{database="mydb"}[5m])
  / rate(pgbouncer_stats_queries_total{database="mydb"}[5m])

# Client wait time
pgbouncer_stats_client_wait_seconds_total
```

### 2.13 Popular PostgreSQL Monitoring Stacks

#### pgwatch2 (now pgwatch)

Open-source PostgreSQL monitoring by CYBERTEC:
- Collects 200+ metrics via SQL-based metric definitions
- Stores in PostgreSQL/TimescaleDB, InfluxDB, Graphite, or Prometheus
- Ships with 30+ pre-built Grafana dashboards
- Non-invasive: no extensions or superuser required for base metrics
- Can handle ~3,000 monitored databases per collector instance
- Supports PostgreSQL 9.0 through 17+

#### Datadog PostgreSQL Integration

- Collects from `pg_stat_*` views plus custom queries
- Deep integration with query-level metrics from `pg_stat_statements`
- Automatic query explain plan collection
- Live process monitoring with real-time query visibility
- Anomaly detection on query performance patterns

#### pg_exporter for Prometheus

- Released v1.0 in 2025, exposes 600+ metrics
- Covers core PostgreSQL internals and popular extensions
- Full coverage of `pg_stat_statements`, replication, locks, WAL, I/O
- Designed as a next-generation replacement for the older `postgres_exporter`

### 2.14 Vacuum and Bloat Monitoring

PostgreSQL's MVCC architecture means that UPDATE and DELETE operations create dead tuples. Without adequate vacuuming, tables and indexes accumulate "bloat" -- wasted space that degrades performance.

#### Bloat Estimation Query

```sql
-- Estimate table bloat using pgstattuple extension
CREATE EXTENSION IF NOT EXISTS pgstattuple;

SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
    round(
        (CASE WHEN avg_width > 0
            THEN (100 * (1 - (reltuples * avg_width)
                / (relpages * current_setting('block_size')::int)))
            ELSE 0
        END)::numeric, 2
    ) AS estimated_bloat_pct
FROM pg_stats
JOIN pg_class ON tablename = relname
JOIN pg_namespace ON relnamespace = pg_namespace.oid AND schemaname = nspname
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY schemaname, tablename, reltuples, relpages, avg_width
HAVING relpages > 100
ORDER BY estimated_bloat_pct DESC;
```

#### Autovacuum Progress Monitoring (PostgreSQL 9.6+)

```sql
SELECT
    p.pid,
    a.datname,
    a.relid::regclass AS table_name,
    a.phase,
    a.heap_blks_total,
    a.heap_blks_scanned,
    a.heap_blks_vacuumed,
    CASE WHEN a.heap_blks_total > 0
        THEN round(100.0 * a.heap_blks_vacuumed / a.heap_blks_total, 1)
        ELSE 0
    END AS pct_complete,
    a.index_vacuum_count,
    a.max_dead_tuples,
    a.num_dead_tuples
FROM pg_stat_progress_vacuum a
JOIN pg_stat_activity p ON a.pid = p.pid;
```

#### Alerting Thresholds for Vacuum/Bloat

| Metric | Warning | Critical |
|--------|---------|----------|
| Dead tuple ratio (dead / live) | > 10% | > 20% |
| Time since last vacuum | > 24 hours (OLTP) | > 72 hours |
| Table bloat estimate | > 30% | > 50% |
| Autovacuum workers active | = max_autovacuum_workers | Sustained at max |
| Transaction ID age (to wraparound) | > 500M | > 1B (out of 2B) |

**Transaction ID wraparound prevention:**
```sql
SELECT
    datname,
    age(datfrozenxid) AS xid_age,
    round(100.0 * age(datfrozenxid) / 2147483647, 2) AS pct_to_wraparound,
    CASE
        WHEN age(datfrozenxid) > 1000000000 THEN 'CRITICAL'
        WHEN age(datfrozenxid) > 500000000 THEN 'WARNING'
        ELSE 'OK'
    END AS status
FROM pg_database
ORDER BY age(datfrozenxid) DESC;
```

---

## 3. MySQL/MariaDB Observability

MySQL provides observability through the Performance Schema (introduced in MySQL 5.5, significantly enhanced in 5.6+), the sys schema (5.7+), and traditional status variables.

### 3.1 Performance Schema

The Performance Schema is MySQL's built-in instrumentation framework. It captures detailed information about server execution at a low overhead (typically 5-10%).

#### Enabling Performance Schema

```ini
# my.cnf
[mysqld]
performance_schema = ON
performance_schema_digests_size = 25000        # Max distinct statement digests
performance_schema_max_digest_length = 4096    # Max digest text length
performance_schema_events_statements_history_size = 100
performance_schema_events_waits_history_size = 100

# Enable specific consumers
performance-schema-consumer-events-statements-history = ON
performance-schema-consumer-events-waits-current = ON
performance-schema-consumer-events-waits-history = ON
performance-schema-consumer-events-stages-current = ON
performance-schema-consumer-events-stages-history = ON
```

#### events_statements_summary_by_digest

The most important Performance Schema table for query observability -- equivalent to PostgreSQL's `pg_stat_statements`.

**Top queries by total execution time:**
```sql
SELECT
    SCHEMA_NAME,
    DIGEST_TEXT,
    COUNT_STAR AS exec_count,
    ROUND(SUM_TIMER_WAIT / 1e12, 3) AS total_time_sec,
    ROUND(AVG_TIMER_WAIT / 1e12, 6) AS avg_time_sec,
    ROUND(MAX_TIMER_WAIT / 1e12, 3) AS max_time_sec,
    SUM_ROWS_SENT AS rows_sent,
    SUM_ROWS_EXAMINED AS rows_examined,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0), 0) AS examine_to_sent_ratio,
    SUM_NO_INDEX_USED + SUM_NO_GOOD_INDEX_USED AS no_index_queries,
    SUM_CREATED_TMP_TABLES AS tmp_tables,
    SUM_CREATED_TMP_DISK_TABLES AS tmp_disk_tables,
    SUM_SORT_MERGE_PASSES AS sort_merge_passes,
    FIRST_SEEN,
    LAST_SEEN
FROM performance_schema.events_statements_summary_by_digest
WHERE SCHEMA_NAME IS NOT NULL
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
```

**Queries with worst index usage:**
```sql
SELECT
    SCHEMA_NAME,
    LEFT(DIGEST_TEXT, 100) AS query_preview,
    COUNT_STAR AS exec_count,
    SUM_NO_INDEX_USED AS full_scans,
    SUM_NO_GOOD_INDEX_USED AS bad_index_choice,
    SUM_ROWS_EXAMINED,
    SUM_ROWS_SENT,
    ROUND(SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0), 0) AS rows_examined_per_sent
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_NO_INDEX_USED > 0 OR SUM_NO_GOOD_INDEX_USED > 0
ORDER BY SUM_ROWS_EXAMINED DESC
LIMIT 20;
```

#### events_waits_summary_by_event_name

Wait event analysis for MySQL -- shows where threads spend time waiting:

```sql
SELECT
    EVENT_NAME,
    COUNT_STAR AS total_waits,
    ROUND(SUM_TIMER_WAIT / 1e12, 3) AS total_wait_sec,
    ROUND(AVG_TIMER_WAIT / 1e12, 6) AS avg_wait_sec,
    ROUND(MAX_TIMER_WAIT / 1e12, 3) AS max_wait_sec
FROM performance_schema.events_waits_summary_global_by_event_name
WHERE SUM_TIMER_WAIT > 0
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 20;
```

#### memory_summary_global_by_event_name

```sql
SELECT
    EVENT_NAME,
    CURRENT_COUNT_USED AS alloc_count,
    ROUND(CURRENT_NUMBER_OF_BYTES_USED / 1024 / 1024, 2) AS current_mb,
    ROUND(HIGH_NUMBER_OF_BYTES_USED / 1024 / 1024, 2) AS high_water_mb
FROM performance_schema.memory_summary_global_by_event_name
WHERE CURRENT_NUMBER_OF_BYTES_USED > 1024 * 1024  -- > 1 MB
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;
```

### 3.2 sys Schema

The `sys` schema (built into MySQL 5.7+) provides human-readable formatted views over Performance Schema data.

**Most useful sys schema views:**

```sql
-- Top statements by total latency
SELECT * FROM sys.statements_with_runtimes_in_95th_percentile LIMIT 10;

-- Statements with full table scans
SELECT * FROM sys.statements_with_full_table_scans LIMIT 10;

-- Statements with temporary tables on disk
SELECT * FROM sys.statements_with_temp_tables LIMIT 10;

-- Statements with sorting
SELECT * FROM sys.statements_with_sorting LIMIT 10;

-- Current user activity (formatted processlist)
SELECT * FROM sys.processlist;

-- Schema table statistics (like pg_stat_user_tables)
SELECT * FROM sys.schema_table_statistics LIMIT 20;

-- Schema index statistics
SELECT * FROM sys.schema_index_statistics LIMIT 20;

-- Unused indexes (candidates for removal)
SELECT * FROM sys.schema_unused_indexes;

-- Redundant indexes (subset of another index)
SELECT * FROM sys.schema_redundant_indexes;

-- Host summary (connections, latency by host)
SELECT * FROM sys.host_summary;

-- IO by file (disk I/O hotspots)
SELECT * FROM sys.io_global_by_file_by_latency LIMIT 20;

-- InnoDB buffer pool stats by schema
SELECT * FROM sys.innodb_buffer_stats_by_schema;

-- Wait analysis
SELECT * FROM sys.waits_global_by_latency LIMIT 20;

-- Memory usage by host
SELECT * FROM sys.memory_global_by_current_bytes LIMIT 20;
```

### 3.3 SHOW PROCESSLIST and information_schema

```sql
-- Current connections with query details
SELECT
    ID,
    USER,
    HOST,
    DB,
    COMMAND,
    TIME AS duration_sec,
    STATE,
    LEFT(INFO, 100) AS query_preview
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
ORDER BY TIME DESC;

-- Connection summary by state
SELECT
    COMMAND,
    STATE,
    COUNT(*) AS count,
    MAX(TIME) AS max_duration_sec
FROM information_schema.PROCESSLIST
GROUP BY COMMAND, STATE
ORDER BY count DESC;

-- Long running queries (> 60 seconds)
SELECT
    ID,
    USER,
    HOST,
    DB,
    TIME AS duration_sec,
    STATE,
    LEFT(INFO, 200) AS query_text
FROM information_schema.PROCESSLIST
WHERE COMMAND != 'Sleep'
    AND TIME > 60
ORDER BY TIME DESC;
```

### 3.4 InnoDB Metrics

InnoDB is the default and primary storage engine. Its metrics are critical for MySQL performance observability.

#### Buffer Pool Hit Ratio

```sql
-- Buffer pool hit ratio (should be > 99% for OLTP)
SELECT
    (1 - (
        (SELECT VARIABLE_VALUE FROM performance_schema.global_status
         WHERE VARIABLE_NAME = 'Innodb_buffer_pool_reads')
        /
        NULLIF(
            (SELECT VARIABLE_VALUE FROM performance_schema.global_status
             WHERE VARIABLE_NAME = 'Innodb_buffer_pool_read_requests'),
        0)
    )) * 100 AS buffer_pool_hit_ratio;
```

**PromQL (mysqld_exporter):**
```promql
# Buffer pool hit ratio
(1 - rate(mysql_global_status_innodb_buffer_pool_reads[5m])
     / rate(mysql_global_status_innodb_buffer_pool_read_requests[5m])) * 100
```

#### InnoDB Row Operations

```sql
SELECT
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM performance_schema.global_status
WHERE VARIABLE_NAME IN (
    'Innodb_rows_read',
    'Innodb_rows_inserted',
    'Innodb_rows_updated',
    'Innodb_rows_deleted',
    'Innodb_row_lock_waits',
    'Innodb_row_lock_time',
    'Innodb_row_lock_time_avg',
    'Innodb_row_lock_time_max',
    'Innodb_deadlocks',
    'Innodb_buffer_pool_pages_total',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_dirty',
    'Innodb_buffer_pool_pages_data',
    'Innodb_buffer_pool_read_requests',
    'Innodb_buffer_pool_reads',
    'Innodb_buffer_pool_wait_free',
    'Innodb_log_waits',
    'Innodb_log_write_requests',
    'Innodb_log_writes',
    'Innodb_os_log_written',
    'Innodb_data_read',
    'Innodb_data_written',
    'Innodb_data_reads',
    'Innodb_data_writes'
)
ORDER BY VARIABLE_NAME;
```

#### Key InnoDB Formulas

| Metric | Formula | Target |
|--------|---------|--------|
| Buffer pool hit ratio | `1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests) * 100` | > 99% |
| Buffer pool utilization | `(Innodb_buffer_pool_pages_total - Innodb_buffer_pool_pages_free) / Innodb_buffer_pool_pages_total * 100` | 80-95% |
| Dirty page ratio | `Innodb_buffer_pool_pages_dirty / Innodb_buffer_pool_pages_data * 100` | < 75% |
| Row lock wait ratio | `Innodb_row_lock_waits / (Innodb_rows_read + Innodb_rows_inserted + Innodb_rows_updated + Innodb_rows_deleted) * 100` | < 1% |
| Log write ratio | `Innodb_log_writes / Innodb_log_write_requests` | Close to 1 |
| Adaptive hash index hit ratio | `Adaptive_hash_searches / (Adaptive_hash_searches + Adaptive_hash_searches_btree) * 100` | > 95% |

### 3.5 Replication Monitoring

#### Traditional Replication (Source-Replica)

```sql
-- On the replica:
SHOW REPLICA STATUS\G

-- Key fields to monitor:
-- Replica_IO_Running: Yes/No (should be Yes)
-- Replica_SQL_Running: Yes/No (should be Yes)
-- Seconds_Behind_Source: replication lag in seconds (was Seconds_Behind_Master)
-- Last_IO_Error / Last_SQL_Error: error messages
-- Exec_Source_Log_Pos vs Read_Source_Log_Pos: position gap
-- Retrieved_Gtid_Set / Executed_Gtid_Set: GTID-based tracking
```

**PromQL (mysqld_exporter):**
```promql
# Replication lag
mysql_slave_status_seconds_behind_master

# Replication thread status (1 = running, 0 = stopped)
mysql_slave_status_slave_io_running
mysql_slave_status_slave_sql_running

# Alert: Replication lag > 60 seconds
# - alert: MySQLReplicationLag
#   expr: mysql_slave_status_seconds_behind_master > 60
#   for: 5m
#   labels:
#     severity: warning

# Alert: Replication broken
# - alert: MySQLReplicationBroken
#   expr: mysql_slave_status_slave_io_running == 0 OR mysql_slave_status_slave_sql_running == 0
#   for: 1m
#   labels:
#     severity: critical
```

#### GTID-Based Replication Lag Monitoring

```sql
-- Compare GTID sets
SELECT
    @@server_uuid AS server_uuid,
    @@gtid_executed AS executed_gtids;

-- On source, get current GTID position
SELECT @@global.gtid_executed;

-- On replica, compare with source
-- The gap between source gtid_executed and replica gtid_executed shows lag in transactions
```

### 3.6 Slow Query Log Configuration

```ini
# my.cnf
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 1                           # Log queries > 1 second
log_queries_not_using_indexes = ON            # Log queries without index use
log_slow_admin_statements = ON                # Log slow DDL (ALTER TABLE, etc.)
log_slow_replica_statements = ON              # Log slow queries on replicas
min_examined_row_limit = 1000                 # Only log if examining > 1000 rows
log_throttle_queries_not_using_indexes = 60   # Rate-limit no-index log entries
log_slow_extra = ON                           # MySQL 8.0.14+ extra fields
```

**Analysis tools:**
- `mysqldumpslow` -- built-in summary tool
- `pt-query-digest` (Percona Toolkit) -- comprehensive slow query analysis
- `mysqltuner.pl` -- general tuning recommendations

### 3.7 ProxySQL Monitoring

ProxySQL is the leading MySQL proxy for connection pooling, query routing, and read/write splitting.

#### Key Monitoring Queries

```sql
-- Connection pool status per hostgroup
SELECT
    hostgroup,
    srv_host,
    srv_port,
    status,
    ConnUsed,
    ConnFree,
    ConnOK,
    ConnERR,
    MaxConnUsed,
    Queries,
    Bytes_data_sent,
    Bytes_data_recv,
    Latency_us
FROM stats_mysql_connection_pool;

-- Query digest statistics (like pg_stat_statements)
SELECT
    hostgroup,
    schemaname,
    digest_text,
    count_star,
    sum_time / 1000 AS total_time_ms,
    min_time / 1000 AS min_time_ms,
    max_time / 1000 AS max_time_ms,
    ROUND(sum_time / count_star / 1000, 3) AS avg_time_ms,
    sum_rows_sent,
    sum_rows_affected
FROM stats_mysql_query_digest
ORDER BY sum_time DESC
LIMIT 20;

-- Global statistics
SELECT * FROM stats_mysql_global;

-- Command counters
SELECT * FROM stats_mysql_commands_counters
WHERE Total_cnt > 0;
```

#### ProxySQL Prometheus Metrics (built-in since v2.1)

```promql
# Queries per second
rate(proxysql_mysql_command_query_total[5m])

# Connection pool usage
proxysql_connection_pool_conn_used{hostgroup="10"}
proxysql_connection_pool_conn_free{hostgroup="10"}

# Query latency
rate(proxysql_mysql_command_query_total_time_us[5m])
  / rate(proxysql_mysql_command_query_total_cnt[5m]) / 1000

# Slow queries
rate(proxysql_mysql_slow_queries_total[5m])

# Backend errors
rate(proxysql_connection_pool_conn_err[5m])
```

### 3.8 Group Replication / InnoDB Cluster Observability

```sql
-- Group Replication member status
SELECT
    MEMBER_ID,
    MEMBER_HOST,
    MEMBER_PORT,
    MEMBER_STATE,
    MEMBER_ROLE,
    MEMBER_VERSION
FROM performance_schema.replication_group_members;

-- Group Replication stats
SELECT
    CHANNEL_NAME,
    COUNT_TRANSACTIONS_IN_QUEUE AS trx_queued,
    COUNT_TRANSACTIONS_CHECKED AS trx_checked,
    COUNT_CONFLICTS_DETECTED AS conflicts,
    COUNT_TRANSACTIONS_ROWS_VALIDATING AS rows_validating,
    TRANSACTIONS_COMMITTED_ALL_MEMBERS AS trx_committed_all,
    LAST_CONFLICT_FREE_TRANSACTION AS last_clean_trx
FROM performance_schema.replication_group_member_stats;

-- Applier status
SELECT
    CHANNEL_NAME,
    SERVICE_STATE,
    REMAINING_DELAY,
    COUNT_TRANSACTIONS_RETRIES
FROM performance_schema.replication_applier_status;

-- Connection status
SELECT *
FROM performance_schema.replication_connection_status
WHERE CHANNEL_NAME = 'group_replication_applier';
```

**Key Group Replication alerts:**
- `MEMBER_STATE` not `ONLINE` for any member
- `COUNT_TRANSACTIONS_IN_QUEUE` growing (apply lag)
- `COUNT_CONFLICTS_DETECTED` increasing (certification conflicts)
- Flow control engaged: `group_replication_flow_control_mode = QUOTA`

---

## 4. Microsoft SQL Server Observability

SQL Server provides observability through Dynamic Management Views (DMVs), Query Store, Extended Events, and Wait Statistics -- a mature and comprehensive instrumentation framework.

### 4.1 Dynamic Management Views (DMVs)

#### sys.dm_exec_query_stats

The primary DMV for query performance analysis -- tracks cumulative statistics for cached query plans.

```sql
-- Top 20 queries by total CPU time
SELECT TOP 20
    qs.total_worker_time / 1000 AS total_cpu_ms,
    qs.execution_count,
    qs.total_worker_time / qs.execution_count / 1000 AS avg_cpu_ms,
    qs.total_elapsed_time / qs.execution_count / 1000 AS avg_duration_ms,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    qs.total_physical_reads / qs.execution_count AS avg_physical_reads,
    qs.total_logical_writes / qs.execution_count AS avg_logical_writes,
    qs.total_rows / qs.execution_count AS avg_rows,
    SUBSTRING(st.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2) + 1
    ) AS query_text,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_worker_time DESC;
```

**Top queries by total I/O:**
```sql
SELECT TOP 20
    qs.total_logical_reads + qs.total_logical_writes AS total_io,
    qs.execution_count,
    (qs.total_logical_reads + qs.total_logical_writes) / qs.execution_count AS avg_io,
    qs.total_logical_reads / qs.execution_count AS avg_reads,
    qs.total_physical_reads / qs.execution_count AS avg_physical_reads,
    qs.total_elapsed_time / qs.execution_count / 1000 AS avg_duration_ms,
    SUBSTRING(st.text,
        (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2) + 1
    ) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY total_io DESC;
```

#### sys.dm_os_wait_stats

The foundation of SQL Server performance analysis. Wait statistics reveal where SQL Server threads spend time waiting.

```sql
-- Top wait types (excluding benign/idle waits)
SELECT TOP 20
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    max_wait_time_ms,
    signal_wait_time_ms,
    wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms,
    ROUND(100.0 * wait_time_ms / SUM(wait_time_ms) OVER(), 2) AS pct_of_total_waits
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    -- Filter out idle/benign waits
    'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE',
    'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH',
    'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT',
    'BROKER_TO_FLUSH', 'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT',
    'DISPATCHER_QUEUE_SEMAPHORE', 'FT_IFTS_SCHEDULER_IDLE_WAIT',
    'XE_DISPATCHER_WAIT', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
    'HADR_FILESTREAM_IOMGR_IOCOMPLETION', 'DIRTY_PAGE_POLL',
    'BROKER_EVENTHANDLER', 'SP_SERVER_DIAGNOSTICS_SLEEP',
    'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP', 'QDS_ASYNC_QUEUE',
    'WAIT_XTP_CKPT_CLOSE', 'QDS_CLEANUP_STALE_QUERIES_TASK_MAIN_LOOP_SLEEP'
)
AND wait_time_ms > 0
ORDER BY wait_time_ms DESC;
```

#### sys.dm_exec_requests

Currently executing requests -- the SQL Server equivalent of `pg_stat_activity`.

```sql
SELECT
    r.session_id,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    r.blocking_session_id,
    r.cpu_time,
    r.total_elapsed_time,
    r.reads,
    r.writes,
    r.logical_reads,
    DB_NAME(r.database_id) AS database_name,
    SUBSTRING(st.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE r.statement_end_offset
        END - r.statement_start_offset) / 2) + 1
    ) AS current_statement,
    r.granted_query_memory,
    r.percent_complete
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
WHERE r.session_id > 50  -- Filter system sessions
ORDER BY r.total_elapsed_time DESC;
```

#### sys.dm_db_index_usage_stats

```sql
-- Identify unused indexes (candidates for removal)
SELECT
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    ius.last_user_scan,
    -- High update-to-read ratio = maintenance cost > benefit
    CASE WHEN (ius.user_seeks + ius.user_scans + ius.user_lookups) > 0
        THEN ROUND(CAST(ius.user_updates AS FLOAT)
             / (ius.user_seeks + ius.user_scans + ius.user_lookups), 2)
        ELSE ius.user_updates
    END AS update_to_read_ratio
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius
    ON i.object_id = ius.object_id
    AND i.index_id = ius.index_id
    AND ius.database_id = DB_ID()
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
    AND i.type_desc != 'HEAP'
    AND i.is_primary_key = 0
    AND i.is_unique = 0
ORDER BY ius.user_seeks + ius.user_scans + ius.user_lookups ASC;
```

### 4.2 Query Store

Query Store (SQL Server 2016+) is a built-in flight recorder for query performance. It persists query text, plans, and runtime statistics across restarts.

#### Enabling Query Store

```sql
ALTER DATABASE [MyDatabase] SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1024,
    QUERY_CAPTURE_MODE = AUTO,           -- AUTO | ALL | NONE | CUSTOM (2022+)
    SIZE_BASED_CLEANUP_MODE = AUTO,
    MAX_PLANS_PER_QUERY = 200,
    STALE_QUERY_THRESHOLD_DAYS = 30,
    WAIT_STATS_CAPTURE_MODE = ON         -- SQL Server 2017+
);
```

#### Regressed Queries Detection

```sql
-- Find queries that regressed in the last 48 hours
SELECT
    q.query_id,
    qt.query_sql_text,
    rs_recent.avg_duration / 1000 AS recent_avg_duration_ms,
    rs_baseline.avg_duration / 1000 AS baseline_avg_duration_ms,
    (rs_recent.avg_duration - rs_baseline.avg_duration) / rs_baseline.avg_duration * 100
        AS regression_pct,
    rs_recent.avg_logical_io_reads AS recent_avg_reads,
    rs_baseline.avg_logical_io_reads AS baseline_avg_reads,
    p_recent.plan_id AS recent_plan_id,
    p_baseline.plan_id AS baseline_plan_id
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p_recent ON q.query_id = p_recent.query_id
JOIN sys.query_store_runtime_stats rs_recent ON p_recent.plan_id = rs_recent.plan_id
JOIN sys.query_store_runtime_stats_interval rsi_recent
    ON rs_recent.runtime_stats_interval_id = rsi_recent.runtime_stats_interval_id
JOIN sys.query_store_plan p_baseline ON q.query_id = p_baseline.query_id
JOIN sys.query_store_runtime_stats rs_baseline ON p_baseline.plan_id = rs_baseline.plan_id
JOIN sys.query_store_runtime_stats_interval rsi_baseline
    ON rs_baseline.runtime_stats_interval_id = rsi_baseline.runtime_stats_interval_id
WHERE rsi_recent.start_time > DATEADD(HOUR, -48, GETUTCDATE())
    AND rsi_baseline.start_time BETWEEN DATEADD(DAY, -30, GETUTCDATE())
        AND DATEADD(DAY, -7, GETUTCDATE())
    AND rs_baseline.avg_duration > 0
    AND rs_recent.avg_duration > rs_baseline.avg_duration * 2  -- 2x regression
ORDER BY regression_pct DESC;
```

#### Forced Plans Monitoring

```sql
-- View all forced plans
SELECT
    q.query_id,
    qt.query_sql_text,
    p.plan_id,
    p.is_forced_plan,
    p.force_failure_count,
    p.last_force_failure_reason_desc,
    rs.avg_duration / 1000 AS avg_duration_ms,
    rs.avg_logical_io_reads,
    rs.count_executions
FROM sys.query_store_plan p
JOIN sys.query_store_query q ON p.query_id = q.query_id
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE p.is_forced_plan = 1;

-- Force a specific plan
EXEC sp_query_store_force_plan @query_id = 42, @plan_id = 7;

-- Unforce a plan
EXEC sp_query_store_unforce_plan @query_id = 42, @plan_id = 7;
```

### 4.3 Extended Events (XEvents)

Extended Events replaced SQL Trace and Profiler (deprecated). They provide lightweight, customizable event capture.

#### Useful Extended Events Sessions

```sql
-- Create session to capture slow queries and deadlocks
CREATE EVENT SESSION [QueryPerformance] ON SERVER
ADD EVENT sqlserver.sql_statement_completed (
    SET collect_statement = (1)
    ACTION (
        sqlserver.database_name,
        sqlserver.session_id,
        sqlserver.username,
        sqlserver.client_hostname,
        sqlserver.query_hash,
        sqlserver.query_plan_hash
    )
    WHERE duration > 1000000  -- > 1 second (in microseconds)
),
ADD EVENT sqlserver.xml_deadlock_report (
    ACTION (
        sqlserver.database_name,
        sqlserver.session_id
    )
),
ADD EVENT sqlserver.blocked_process_report (
    ACTION (
        sqlserver.database_name,
        sqlserver.session_id
    )
)
ADD TARGET package0.event_file (
    SET filename = N'QueryPerformance',
    max_file_size = 100,          -- MB
    max_rollover_files = 10
)
WITH (
    MAX_MEMORY = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    STARTUP_STATE = ON
);

-- Start the session
ALTER EVENT SESSION [QueryPerformance] ON SERVER STATE = START;

-- Enable blocked process report threshold
EXEC sp_configure 'blocked process threshold (s)', 10;
RECONFIGURE;
```

### 4.4 Wait Statistics Methodology

The **wait statistics methodology** is the primary approach to SQL Server performance diagnosis. The principle: every SQL Server worker thread is either *running* on CPU, *waiting* for a resource, or *in the runnable queue* waiting for CPU.

#### Top Wait Types and Their Meaning

| Wait Type | Category | Indicates | Investigation |
|-----------|----------|-----------|---------------|
| `CXPACKET` / `CXCONSUMER` | Parallelism | Parallel query execution skew | Check MAXDOP, examine parallel plans, look for data skew |
| `PAGEIOLATCH_SH/EX` | Disk I/O | Buffer pool miss, reading from disk | Increase memory, optimize queries doing large scans, check disk performance |
| `LCK_M_S`, `LCK_M_X`, `LCK_M_U`, `LCK_M_IX` | Locking | Lock contention between sessions | Identify blocking chains, optimize transactions, consider RCSI |
| `SOS_SCHEDULER_YIELD` | CPU | CPU saturation | Add CPU, optimize CPU-intensive queries, check MAXDOP |
| `WRITELOG` | Transaction Log | Log write bottleneck | Move log to faster storage, check log file autogrowth, batch transactions |
| `ASYNC_NETWORK_IO` | Network/Client | Client not consuming results fast enough | Application issue, network latency, client-side processing |
| `RESOURCE_SEMAPHORE` | Memory | Queries waiting for memory grants | Optimize queries needing large sorts/hashes, increase max server memory |
| `THREADPOOL` | Connection | Thread pool exhaustion | Increase max worker threads, fix connection leaks, reduce blocking |
| `HADR_SYNC_COMMIT` | AG Sync | Synchronous AG commit wait | Network latency to sync replica, replica I/O performance |
| `LATCH_EX/SH` | Internal | Internal structure contention | TempDB contention, page splits, hot pages |

#### Wait Statistics Snapshot Query

```sql
-- Capture wait stats delta over a time window
-- Step 1: Capture baseline
SELECT wait_type, waiting_tasks_count, wait_time_ms, signal_wait_time_ms
INTO #wait_baseline
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0;

-- Step 2: Wait for a measurement period (e.g., 5 minutes via WAITFOR)
WAITFOR DELAY '00:05:00';

-- Step 3: Calculate delta
SELECT TOP 20
    w.wait_type,
    w.waiting_tasks_count - b.waiting_tasks_count AS delta_tasks,
    w.wait_time_ms - b.wait_time_ms AS delta_wait_ms,
    w.signal_wait_time_ms - b.signal_wait_time_ms AS delta_signal_ms,
    (w.wait_time_ms - b.wait_time_ms) - (w.signal_wait_time_ms - b.signal_wait_time_ms)
        AS delta_resource_wait_ms
FROM sys.dm_os_wait_stats w
JOIN #wait_baseline b ON w.wait_type = b.wait_type
WHERE (w.wait_time_ms - b.wait_time_ms) > 0
    AND w.wait_type NOT IN (/* benign waits list from above */)
ORDER BY delta_wait_ms DESC;

DROP TABLE #wait_baseline;
```

### 4.5 Always On Availability Groups Monitoring

```sql
-- AG health overview
SELECT
    ag.name AS ag_name,
    ar.replica_server_name,
    ars.role_desc,
    ars.operational_state_desc,
    ars.connected_state_desc,
    ars.synchronization_health_desc,
    ars.last_connect_error_description
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;

-- Database-level replication health
SELECT
    ag.name AS ag_name,
    ar.replica_server_name,
    DB_NAME(drs.database_id) AS database_name,
    drs.synchronization_state_desc,
    drs.synchronization_health_desc,
    drs.is_suspended,
    drs.suspend_reason_desc,
    drs.log_send_queue_size AS log_send_queue_kb,
    drs.log_send_rate AS log_send_rate_kbps,
    drs.redo_queue_size AS redo_queue_kb,
    drs.redo_rate AS redo_rate_kbps,
    -- Estimated time to catch up
    CASE WHEN drs.redo_rate > 0
        THEN drs.redo_queue_size / drs.redo_rate
        ELSE NULL
    END AS estimated_redo_catchup_sec,
    drs.last_sent_time,
    drs.last_received_time,
    drs.last_hardened_time,
    drs.last_redone_time,
    drs.last_commit_time
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
ORDER BY ag.name, ar.replica_server_name, drs.database_id;
```

**AG alerting thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| `log_send_queue_size` | > 100 MB | > 1 GB |
| `redo_queue_size` | > 100 MB | > 1 GB |
| `synchronization_health_desc` | `PARTIALLY_HEALTHY` | `NOT_HEALTHY` |
| `is_suspended` | N/A | = 1 (true) |
| `estimated_redo_catchup_sec` | > 60 | > 300 |

### 4.6 SQL Server Agent Job Monitoring

```sql
SELECT
    j.name AS job_name,
    h.run_date,
    h.run_time,
    h.run_duration,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END AS status,
    h.message,
    -- Duration in seconds
    (h.run_duration / 10000) * 3600
    + ((h.run_duration / 100) % 100) * 60
    + (h.run_duration % 100) AS duration_seconds
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.step_id = 0  -- Job outcome step only
    AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(DAY, -7, GETDATE()), 112))
ORDER BY h.run_date DESC, h.run_time DESC;
```

### 4.7 Memory and Buffer Pool Metrics

```sql
-- Buffer pool usage by database
SELECT
    DB_NAME(database_id) AS database_name,
    COUNT(*) * 8 / 1024 AS buffer_pool_mb,
    SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) * 8 / 1024 AS dirty_pages_mb,
    ROUND(100.0 * SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS dirty_pct
FROM sys.dm_os_buffer_descriptors
GROUP BY database_id
ORDER BY buffer_pool_mb DESC;

-- Memory clerks (where memory is allocated)
SELECT TOP 20
    type AS clerk_type,
    name AS clerk_name,
    pages_kb / 1024 AS memory_mb
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 0
ORDER BY pages_kb DESC;

-- Page Life Expectancy (PLE) -- how long a page stays in buffer pool
SELECT
    object_name,
    counter_name,
    cntr_value AS page_life_expectancy_seconds
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy'
    AND object_name LIKE '%Buffer Manager%';

-- Buffer cache hit ratio
SELECT
    ROUND(
        (SELECT CAST(cntr_value AS FLOAT)
         FROM sys.dm_os_performance_counters
         WHERE counter_name = 'Buffer cache hit ratio'
             AND object_name LIKE '%Buffer Manager%')
        /
        (SELECT CAST(cntr_value AS FLOAT)
         FROM sys.dm_os_performance_counters
         WHERE counter_name = 'Buffer cache hit ratio base'
             AND object_name LIKE '%Buffer Manager%')
        * 100, 2
    ) AS buffer_cache_hit_ratio;
```

**Alerting thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Page Life Expectancy | < 300 seconds | < 60 seconds |
| Buffer Cache Hit Ratio | < 97% | < 90% |
| Memory Grants Pending | > 0 sustained | > 5 sustained |
| Stolen Pages % | > 80% of total | > 95% of total |

### 4.8 TempDB Monitoring

```sql
-- TempDB space usage by category
SELECT
    SUM(user_object_reserved_page_count) * 8 / 1024 AS user_objects_mb,
    SUM(internal_object_reserved_page_count) * 8 / 1024 AS internal_objects_mb,
    SUM(version_store_reserved_page_count) * 8 / 1024 AS version_store_mb,
    SUM(mixed_extent_page_count) * 8 / 1024 AS mixed_extents_mb,
    SUM(unallocated_extent_page_count) * 8 / 1024 AS free_space_mb
FROM sys.dm_db_file_space_usage;

-- Sessions consuming TempDB space
SELECT TOP 20
    t.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    t.user_objects_alloc_page_count * 8 / 1024 AS user_objects_mb,
    t.internal_objects_alloc_page_count * 8 / 1024 AS internal_objects_mb,
    (t.user_objects_alloc_page_count + t.internal_objects_alloc_page_count) * 8 / 1024
        AS total_tempdb_mb,
    st.text AS current_query
FROM sys.dm_db_session_space_usage t
JOIN sys.dm_exec_sessions s ON t.session_id = s.session_id
OUTER APPLY sys.dm_exec_sql_text(s.most_recent_sql_handle) st
WHERE t.user_objects_alloc_page_count + t.internal_objects_alloc_page_count > 0
ORDER BY total_tempdb_mb DESC;

-- Version store monitoring (for RCSI / snapshot isolation)
SELECT
    DB_NAME(database_id) AS database_name,
    reserved_page_count * 8 / 1024 AS version_store_mb,
    reserved_space_kb / 1024 AS reserved_mb
FROM sys.dm_tran_version_store_space_usage
ORDER BY reserved_page_count DESC;

-- Longest running transactions holding version store
SELECT TOP 5
    transaction_id,
    transaction_sequence_num,
    elapsed_time_seconds / 60 AS elapsed_minutes,
    CASE transaction_state
        WHEN 0 THEN 'Uninitialized'
        WHEN 1 THEN 'Initialized'
        WHEN 2 THEN 'Active'
        WHEN 3 THEN 'Ended'
        WHEN 4 THEN 'Commit Started'
        WHEN 5 THEN 'Prepared'
        WHEN 6 THEN 'Committed'
        WHEN 7 THEN 'Rolling Back'
        WHEN 8 THEN 'Rolled Back'
    END AS transaction_state
FROM sys.dm_tran_active_snapshot_database_transactions
ORDER BY elapsed_time_seconds DESC;
```

**TempDB alerting thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| TempDB free space | < 25% | < 10% |
| Version store size | > 50% of TempDB | > 75% of TempDB |
| Version store growth rate | > 1 GB/min sustained | > 5 GB/min sustained |
| Active transactions holding version store | > 60 minutes old | > 240 minutes old |

---

## 5. Oracle Database Observability

Oracle provides the most comprehensive built-in observability framework of any commercial database, centered around AWR, ASH, and ADDM. However, many features require the Diagnostics and Tuning Packs (additional licensing).

### 5.1 Automatic Workload Repository (AWR)

AWR is Oracle's persistent performance data store. It automatically captures database statistics as snapshots at regular intervals (default: every 60 minutes, retained for 8 days).

**Requires:** Oracle Diagnostics Pack license

#### Generating AWR Reports

```sql
-- List available snapshots
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
WHERE begin_interval_time > SYSDATE - 2
ORDER BY snap_id DESC;

-- Generate AWR report (text format)
@$ORACLE_HOME/rdbms/admin/awrrpt.sql
-- Interactive: select format (text/html), begin/end snap_id

-- Generate AWR report programmatically
SELECT output
FROM TABLE(DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_TEXT(
    l_dbid     => (SELECT dbid FROM v$database),
    l_inst_num => 1,
    l_bid      => 100,  -- Begin snap_id
    l_eid      => 105   -- End snap_id
));
```

#### Key AWR Sections to Analyze

1. **Report Summary**: DB Time, CPU time, wait time breakdown
2. **Load Profile**: Per-second and per-transaction metrics
3. **Top 5 Timed Events**: Where DB time is spent (wait event methodology)
4. **SQL Statistics**: Top SQL by elapsed time, CPU, I/O, gets, executions
5. **Instance Efficiency**: Buffer cache hit ratio, library cache hit ratio, soft parse ratio
6. **IO Statistics**: Per-file and per-tablespace I/O latency
7. **Buffer Pool Statistics**: Cache hit ratios for different pool sizes
8. **PGA Statistics**: PGA cache hit ratio, over-allocation count
9. **Undo Statistics**: Undo usage, longest query, tuned retention
10. **Latch Statistics**: Latch contention (internal locks)

#### AWR Key Metrics Query

```sql
-- AWR metric trends over 24 hours
SELECT
    s.snap_id,
    s.begin_interval_time,
    m.metric_name,
    m.average,
    m.maxval,
    m.standard_deviation
FROM dba_hist_sysmetric_summary m
JOIN dba_hist_snapshot s ON m.snap_id = s.snap_id
    AND m.dbid = s.dbid
    AND m.instance_number = s.instance_number
WHERE m.metric_name IN (
    'Database Time Per Sec',
    'CPU Usage Per Sec',
    'User Transaction Per Sec',
    'Physical Reads Per Sec',
    'Physical Writes Per Sec',
    'Redo Generated Per Sec',
    'User Calls Per Sec',
    'Executions Per Sec',
    'DB Block Gets Per Sec',
    'Consistent Read Gets Per Sec',
    'Buffer Cache Hit Ratio',
    'Library Cache Hit Ratio',
    'Current Open Cursors Count',
    'Session Count',
    'Average Active Sessions'
)
AND s.begin_interval_time > SYSDATE - 1
ORDER BY s.snap_id, m.metric_name;
```

### 5.2 Active Session History (ASH)

ASH samples active sessions every second, capturing what each session is doing (SQL, wait event, module, action). It provides granular, second-by-second visibility.

```sql
-- ASH: What is the database doing right now?
SELECT
    session_id,
    session_serial#,
    sql_id,
    event,
    wait_class,
    session_state,  -- ON CPU or WAITING
    blocking_session,
    module,
    action,
    program,
    machine,
    time_waited / 1000 AS time_waited_ms
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '5' MINUTE
ORDER BY sample_time DESC;

-- ASH: Top SQL by DB time in last hour
SELECT
    sql_id,
    COUNT(*) AS ash_samples,  -- Each sample = ~1 second of DB time
    ROUND(COUNT(*) / 60, 2) AS estimated_db_time_minutes,
    SUM(CASE WHEN session_state = 'ON CPU' THEN 1 ELSE 0 END) AS cpu_samples,
    SUM(CASE WHEN wait_class = 'User I/O' THEN 1 ELSE 0 END) AS io_samples,
    SUM(CASE WHEN wait_class = 'Concurrency' THEN 1 ELSE 0 END) AS lock_samples,
    MIN(sql_plan_hash_value) AS plan_hash
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '1' HOUR
    AND sql_id IS NOT NULL
GROUP BY sql_id
ORDER BY ash_samples DESC
FETCH FIRST 20 ROWS ONLY;

-- ASH: Wait event breakdown in last 30 minutes
SELECT
    NVL(event, 'ON CPU') AS event,
    wait_class,
    COUNT(*) AS samples,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS pct_db_time
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '30' MINUTE
GROUP BY event, wait_class
ORDER BY samples DESC
FETCH FIRST 20 ROWS ONLY;

-- ASH: Blocking session analysis
SELECT
    blocking_session,
    blocking_session_serial#,
    event AS blocked_event,
    COUNT(*) AS blocked_samples,
    COUNT(DISTINCT session_id) AS sessions_blocked
FROM v$active_session_history
WHERE sample_time > SYSDATE - INTERVAL '30' MINUTE
    AND blocking_session IS NOT NULL
GROUP BY blocking_session, blocking_session_serial#, event
ORDER BY blocked_samples DESC;
```

### 5.3 Automatic Database Diagnostic Monitor (ADDM)

ADDM analyzes AWR data automatically and generates diagnostic findings with recommendations. It runs after every AWR snapshot.

```sql
-- View latest ADDM findings
SELECT
    f.finding_id,
    f.finding_name,
    f.type AS finding_type,  -- PROBLEM, SYMPTOM, INFORMATION
    f.impact,                 -- Estimated DB time impact (microseconds)
    f.impact_type,
    f.message
FROM dba_advisor_findings f
JOIN dba_advisor_tasks t ON f.task_id = t.task_id
WHERE t.advisor_name = 'ADDM'
    AND t.execution_end > SYSDATE - 1
ORDER BY f.impact DESC;

-- View ADDM recommendations
SELECT
    r.rec_id,
    r.finding_id,
    r.rank,
    r.type AS rec_type,
    r.benefit,             -- Expected benefit in DB time reduction
    a.message AS action_message,
    a.attr1 AS action_detail
FROM dba_advisor_recommendations r
JOIN dba_advisor_actions a ON r.task_id = a.task_id AND r.rec_id = a.rec_id
JOIN dba_advisor_tasks t ON r.task_id = t.task_id
WHERE t.advisor_name = 'ADDM'
    AND t.execution_end > SYSDATE - 1
ORDER BY r.rank;

-- Run ADDM manually for a specific AWR range
DECLARE
    l_task_name VARCHAR2(100) := 'manual_addm_' || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MI');
    l_task_id   NUMBER;
BEGIN
    DBMS_ADVISOR.CREATE_TASK('ADDM', l_task_id, l_task_name);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task_name, 'START_SNAPSHOT', 100);
    DBMS_ADVISOR.SET_TASK_PARAMETER(l_task_name, 'END_SNAPSHOT', 105);
    DBMS_ADVISOR.EXECUTE_TASK(l_task_name);
END;
/
```

### 5.4 Wait Event Analysis Methodology

Oracle's wait event analysis follows the same principles as SQL Server's wait statistics but with a more granular classification system.

#### Wait Classes and Common Events

| Wait Class | Common Events | Indicates |
|------------|---------------|-----------|
| **User I/O** | `db file sequential read`, `db file scattered read` | Physical I/O (index reads, full scans) |
| **System I/O** | `log file sync`, `log file parallel write`, `control file sequential read` | Redo log writes, control file access |
| **Concurrency** | `buffer busy waits`, `enq: TX - row lock contention`, `library cache lock` | Contention between sessions |
| **Configuration** | `log buffer space`, `free buffer waits` | Undersized SGA components |
| **Commit** | `log file sync` | Commit overhead, redo log performance |
| **Network** | `SQL*Net message from client`, `SQL*Net more data from client` | Network roundtrips, client processing time |
| **Cluster** | `gc buffer busy acquire`, `gc cr grant 2-way` | RAC inter-node communication |
| **Application** | `enq: TX - row lock contention` (application-caused), `enq: TM - contention` | Application design issues |

```sql
-- V$SESSION real-time wait analysis
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.program,
    s.module,
    s.action,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.state,    -- WAITING, WAITED KNOWN TIME, WAITED SHORT TIME, WAITED UNKNOWN TIME
    s.blocking_session,
    s.blocking_session_status
FROM v$session s
WHERE s.status = 'ACTIVE'
    AND s.type = 'USER'
    AND s.wait_class != 'Idle'
ORDER BY s.seconds_in_wait DESC;

-- System-wide wait event summary
SELECT
    wait_class,
    event,
    total_waits,
    time_waited_micro / 1e6 AS time_waited_sec,
    ROUND(average_wait_in_micro / 1e3, 2) AS avg_wait_ms,
    ROUND(100 * time_waited_micro / SUM(time_waited_micro) OVER(), 2) AS pct_total
FROM v$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited_micro DESC
FETCH FIRST 20 ROWS ONLY;
```

### 5.5 Oracle Enterprise Manager vs Open-Source Alternatives

| Feature | Oracle Enterprise Manager | Open-Source Alternatives |
|---------|--------------------------|------------------------|
| AWR/ASH access | Native, full integration | Limited (requires Diagnostics Pack license) |
| Real-time SQL monitoring | Yes (SQL Monitor) | Partial (custom scripts, OEM-free views) |
| Performance Hub | Yes (12c+) | N/A |
| Alert management | Built-in with baselines | Prometheus + custom exporters |
| Multi-database | Yes (Cloud Control) | pgwatch2 concepts adapted, custom solutions |
| Cost | Included with DB license (+ Packs) | Free, but more setup effort |
| **Popular alternatives** | | **oracledb_exporter** (Prometheus), **Percona Monitoring and Management (PMM)**, **Telegraf Oracle plugin**, **Zabbix Oracle template** |

### 5.6 RAC (Real Application Clusters) Monitoring

```sql
-- RAC instance status
SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    database_status,
    active_state,
    logins
FROM gv$instance
ORDER BY inst_id;

-- Global cache (GC) transfer statistics -- key RAC performance indicator
SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE name IN (
    'gc current blocks received',
    'gc current blocks served',
    'gc cr blocks received',
    'gc cr blocks served',
    'gc current block receive time',
    'gc cr block receive time'
)
ORDER BY inst_id, name;

-- Inter-instance block transfer latency
SELECT
    instance,
    class,
    cr_block,
    cr_busy,
    cr_congested,
    current_block,
    current_busy,
    current_congested,
    -- Average transfer time in ms
    ROUND(
        CASE WHEN cr_block > 0
            THEN cr_2hop_latency / cr_block * 10  -- Convert to ms
            ELSE 0
        END, 2
    ) AS avg_cr_latency_ms
FROM gv$instance_cache_transfer
WHERE cr_block > 0 OR current_block > 0
ORDER BY instance, class;

-- RAC interconnect performance
SELECT
    inst_id,
    name,
    ip_address,
    is_public,
    source
FROM gv$cluster_interconnects;
```

**RAC alerting thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Average GC CR block receive time | > 2ms | > 10ms |
| Average GC current block receive time | > 2ms | > 10ms |
| GC buffer busy waits (% of total waits) | > 10% | > 30% |
| Cluster interconnect bandwidth utilization | > 50% | > 80% |

### 5.7 Data Guard Monitoring

```sql
-- Data Guard status on standby
SELECT
    NAME,
    VALUE,
    UNIT,
    TIME_COMPUTED
FROM V$DATAGUARD_STATS
WHERE NAME IN ('transport lag', 'apply lag', 'apply finish time', 'estimated startup time');

-- Archive log apply progress
SELECT
    PROCESS,
    STATUS,
    THREAD#,
    SEQUENCE#,
    BLOCK#,
    BLOCKS
FROM V$MANAGED_STANDBY
WHERE PROCESS IN ('MRP0', 'RFS', 'ARCH');

-- Data Guard gap detection
SELECT
    THREAD#,
    LOW_SEQUENCE#,
    HIGH_SEQUENCE#
FROM V$ARCHIVE_GAP;

-- Protection mode and role
SELECT
    DATABASE_ROLE,
    PROTECTION_MODE,
    PROTECTION_LEVEL,
    SWITCHOVER_STATUS,
    DATAGUARD_BROKER,
    GUARD_STATUS
FROM V$DATABASE;
```

**Data Guard alerting thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Transport lag | > 5 minutes | > 30 minutes |
| Apply lag | > 10 minutes | > 60 minutes |
| Archive gap sequences | > 0 | > 3 |
| Switchover status | Not `TO STANDBY` or `NOT ALLOWED` | `FAILED` |

### 5.8 PGA/SGA Memory Monitoring

```sql
-- SGA component sizes
SELECT
    name AS component,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM v$sgastat
WHERE pool IS NULL
UNION ALL
SELECT
    pool || ' - ' || name AS component,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM v$sgastat
WHERE pool IS NOT NULL AND bytes > 1024 * 1024
ORDER BY size_mb DESC;

-- SGA dynamic resize operations
SELECT
    component,
    oper_type,
    oper_mode,
    initial_size / 1024 / 1024 AS initial_mb,
    final_size / 1024 / 1024 AS final_mb,
    status,
    start_time,
    end_time
FROM v$sga_resize_ops
WHERE start_time > SYSDATE - 1
ORDER BY start_time DESC;

-- PGA usage by session
SELECT
    s.sid,
    s.serial#,
    s.username,
    s.program,
    p.pga_used_mem / 1024 / 1024 AS pga_used_mb,
    p.pga_alloc_mem / 1024 / 1024 AS pga_alloc_mb,
    p.pga_max_mem / 1024 / 1024 AS pga_max_mb
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.type = 'USER'
ORDER BY p.pga_alloc_mem DESC
FETCH FIRST 20 ROWS ONLY;

-- PGA target advice
SELECT
    pga_target_for_estimate / 1024 / 1024 AS target_mb,
    pga_target_factor AS factor,
    estd_extra_bytes_rw / 1024 / 1024 AS estd_extra_rw_mb,
    estd_pga_cache_hit_percentage AS est_hit_pct,
    estd_overalloc_count AS overalloc_count
FROM v$pga_target_advice
ORDER BY pga_target_for_estimate;

-- SGA target advice
SELECT
    sga_size AS sga_mb,
    sga_size_factor AS factor,
    estd_db_time AS est_db_time,
    estd_db_time_factor AS db_time_factor,
    estd_physical_reads AS est_phys_reads
FROM v$sga_target_advice
ORDER BY sga_size;

-- Buffer cache hit ratio
SELECT
    1 - (phy.value / (cur.value + con.value)) AS buffer_cache_hit_ratio
FROM v$sysstat phy, v$sysstat cur, v$sysstat con
WHERE phy.name = 'physical reads'
    AND cur.name = 'db block gets'
    AND con.name = 'consistent gets';
```

**Memory alerting thresholds:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Buffer cache hit ratio | < 95% | < 90% |
| Library cache hit ratio | < 95% | < 90% |
| PGA cache hit % | < 90% | < 80% |
| PGA over-allocation count | > 0 | > 100 (cumulative) |
| Shared pool free % | < 15% | < 5% |

---

## 6. Cross-Platform Patterns and Best Practices

### 6.1 Universal Database Observability Checklist

Every relational database deployment should have the following observability capabilities:

| Capability | PostgreSQL | MySQL | SQL Server | Oracle |
|------------|-----------|-------|------------|--------|
| Query statistics | pg_stat_statements | Performance Schema digests | Query Store / dm_exec_query_stats | AWR SQL statistics |
| Active sessions | pg_stat_activity | SHOW PROCESSLIST / performance_schema | dm_exec_requests | V$SESSION / ASH |
| Wait analysis | wait_event in pg_stat_activity | events_waits_summary | dm_os_wait_stats | V$SYSTEM_EVENT / ASH |
| Lock contention | pg_locks + pg_stat_activity | innodb_lock_waits (sys) | dm_tran_locks + dm_exec_requests | V$LOCK / enqueue waits |
| Replication lag | pg_stat_replication | SHOW REPLICA STATUS | dm_hadr_database_replica_states | V$DATAGUARD_STATS |
| Buffer/cache | pg_stat_bgwriter + pg_buffercache | InnoDB buffer pool status | dm_os_buffer_descriptors + PLE | V$BUFFER_POOL_STATISTICS |
| Index usage | pg_stat_user_indexes | sys.schema_index_statistics | dm_db_index_usage_stats | DBA_INDEX_USAGE (12c+) |
| Slow query logging | log_min_duration_statement | slow_query_log | Extended Events | auto trace / SQL trace |
| Execution plans | EXPLAIN ANALYZE / auto_explain | EXPLAIN FORMAT=JSON | Actual Execution Plan / Query Store | EXPLAIN PLAN / AWR SQL |
| Automatic diagnosis | N/A (manual) | N/A (manual) | Query Store regression | ADDM |

### 6.2 Universal Alerting Recommendations

**Tier 1 -- Page immediately (24x7):**
- Database down / unreachable
- Replication broken (I/O or SQL thread stopped)
- Replication lag > 5 minutes (for synchronous/near-sync requirements)
- Connection pool exhausted (0 available connections)
- Disk space < 10% free (data or WAL/redo)
- Deadlocks > 10/minute sustained

**Tier 2 -- Alert during business hours:**
- Buffer cache hit ratio < 95%
- Replication lag > 30 seconds
- Connection utilization > 80% of max
- Long-running transactions > 30 minutes
- Autovacuum/maintenance falling behind
- Query regression detected (2x+ slowdown)

**Tier 3 -- Dashboard / weekly review:**
- Index usage efficiency (unused indexes, redundant indexes)
- Table/index bloat trends
- Query pattern changes (new high-frequency queries)
- Checkpoint/flush performance trends
- Capacity forecasting (growth rates)

### 6.3 Database Observability with OpenTelemetry

OpenTelemetry provides standardized database observability through:

**1. Database client instrumentation (application side):**
```yaml
# OTel Collector receiver for database spans from instrumented apps
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  # Extract database metrics from spans
  spanmetrics:
    metrics_exporter: prometheus
    dimensions:
      - name: db.system
      - name: db.name
      - name: db.operation
    histogram:
      explicit:
        buckets: [1ms, 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 5s]
```

**2. Database metric receivers (database side):**
```yaml
receivers:
  # PostgreSQL receiver
  postgresql:
    endpoint: localhost:5432
    transport: tcp
    username: monitoring_user
    password: ${env:PG_MONITOR_PASSWORD}
    databases:
      - mydb
    collection_interval: 30s
    tls:
      insecure: true

  # MySQL receiver
  mysql:
    endpoint: localhost:3306
    username: monitoring_user
    password: ${env:MYSQL_MONITOR_PASSWORD}
    database: mydb
    collection_interval: 30s

  # SQL Server receiver
  sqlserver:
    collection_interval: 30s
    username: monitoring_user
    password: ${env:MSSQL_MONITOR_PASSWORD}
    server: localhost
    port: 1433
```

### 6.4 Cost of Observability Overhead

| Feature | Overhead | Notes |
|---------|----------|-------|
| pg_stat_statements | 1-5% CPU | Higher with `track = all` |
| track_io_timing | 0.5-2% | Depends on clock source (TSC is fastest) |
| auto_explain (sampled) | 0-5% | Use `sample_rate < 1.0` in production |
| MySQL Performance Schema | 5-10% CPU | Depends on enabled consumers |
| SQL Server Query Store | 1-3% | Minimal with `QUERY_CAPTURE_MODE = AUTO` |
| Oracle AWR snapshots | 1-3% | Every 60 minutes by default |
| Oracle ASH sampling | < 1% | 1-second sampling of V$SESSION |
| Extended Events | 0-5% | Depends on events and predicates |

### 6.5 Monitoring User Setup

**PostgreSQL:**
```sql
CREATE ROLE monitoring_user WITH LOGIN PASSWORD 'secure_password';
GRANT pg_monitor TO monitoring_user;  -- PG 10+ built-in monitoring role
GRANT EXECUTE ON FUNCTION pg_stat_statements_reset TO monitoring_user;
```

**MySQL:**
```sql
CREATE USER 'monitoring_user'@'%' IDENTIFIED BY 'secure_password';
GRANT SELECT ON performance_schema.* TO 'monitoring_user'@'%';
GRANT PROCESS ON *.* TO 'monitoring_user'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'monitoring_user'@'%';
GRANT SELECT ON sys.* TO 'monitoring_user'@'%';
```

**SQL Server:**
```sql
CREATE LOGIN monitoring_user WITH PASSWORD = 'SecurePassword1!';
CREATE USER monitoring_user FOR LOGIN monitoring_user;
GRANT VIEW SERVER STATE TO monitoring_user;
GRANT VIEW DATABASE STATE TO monitoring_user;
GRANT VIEW ANY DEFINITION TO monitoring_user;
```

**Oracle:**
```sql
CREATE USER monitoring_user IDENTIFIED BY secure_password;
GRANT CREATE SESSION TO monitoring_user;
GRANT SELECT_CATALOG_ROLE TO monitoring_user;
GRANT SELECT ANY DICTIONARY TO monitoring_user;
-- For ASH access:
GRANT ADVISOR TO monitoring_user;
```

---

## Sources

- [Pillars of Observability Explained - CodiLime](https://codilime.com/blog/pillars-observability-explained-logs-metrics-traces/)
- [Three Pillars of Observability - IBM](https://www.ibm.com/think/insights/observability-pillars)
- [PostgreSQL pg_stat_statements Documentation](https://www.postgresql.org/docs/current/pgstatstatements.html)
- [Configuring PostgreSQL for Observability - pgDash](https://pgdash.io/blog/postgres-observability.html)
- [Mastering pg_stat_statements - VirtualDBA](https://virtual-dba.com/blog/mastering-pgstatstatements-in-postgresql/)
- [pg_exporter v1.0 Released - PostgreSQL.org](https://www.postgresql.org/about/news/pg_exporter-v100-released-next-level-pg-observability-3073/)
- [Query Observability with pg_stat_monitor - Severalnines](https://severalnines.com/blog/query-observability-and-performance-tuning-with-pg_stat_monitor-and-pg_stat_statements/)
- [PostgreSQL Monitoring with Prometheus - Sysdig](https://www.sysdig.com/blog/postgresql-monitoring)
- [Monitoring PostgreSQL Replication with pg_stat_replication - CYBERTEC](https://www.cybertec-postgresql.com/en/monitoring-replication-pg_stat_replication/)
- [pg_stat_io in PostgreSQL 16 - pganalyze](https://pganalyze.com/blog/pg-stat-io)
- [PostgreSQL 18 pg_stat_io Guide - Neon](https://neon.com/postgresql/postgresql-18/pg-stat-io)
- [MySQL Statement Summary Tables - MySQL Documentation](https://dev.mysql.com/doc/refman/8.4/en/performance-schema-statement-summary-tables.html)
- [MySQL Query Digest with Performance Schema - Percona](https://www.percona.com/blog/mysql-query-digest-with-performance-schema/)
- [MySQL Key Monitoring Metrics - Sysdig](https://www.sysdig.com/blog/mysql-monitoring)
- [mysqld_exporter - Prometheus GitHub](https://github.com/prometheus/mysqld_exporter)
- [MySQL Group Replication Monitoring with Performance Schema - Mydbops](https://www.mydbops.com/blog/observability-in-mysql-group-replication-monitoring-with-performance-schema)
- [MySQL Replication Observability - MySQL Blog Archive](https://dev.mysql.com/blog-archive/mysql-8-and-replication-observability/)
- [ProxySQL Observability with Prometheus & Grafana](https://proxysql.com/blog/observability-enhancements-in-proxysql-2-1-with-prometheus-grafana/)
- [ProxySQL Statistics Documentation](https://proxysql.com/documentation/stats-statistics/)
- [sys.dm_exec_query_stats - Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql)
- [sys.dm_os_wait_stats - Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql)
- [Wait Statistics Methodology - SQLSkills (Paul Randal)](https://www.sqlskills.com/blogs/paul/wait-statistics-or-please-tell-me-where-it-hurts/)
- [Performance Tuning with SQL Server DMVs - SQLyard](https://sqlyard.com/2025/09/13/performance-tuning-with-sql-server-dmvs-a-deep-dive/)
- [SQL Server Query Store - Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store)
- [SQL Server Observability Best Practices - Last9](https://last9.io/blog/sql-server-observability/)
- [SQL Server Extended Events for Availability Groups - Microsoft Learn](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/always-on-extended-events)
- [CXPACKET Troubleshooting - Brent Ozar](https://www.brentozar.com/archive/2013/08/what-is-the-cxpacket-wait-type-and-how-do-you-reduce-it/)
- [SOS_SCHEDULER_YIELD - SQLSkills](https://www.sqlskills.com/help/waits/sos_scheduler_yield/)
- [SQL Server TempDB Best Practices - Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database)
- [Oracle AWR and ASH Explained - Learnomate](https://learnomate.org/ash-awr-oracle-performance-diagnostics/)
- [Oracle ADDM - Oracle Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/26/tdppt/reviewing-automatic-database-diagnostic-monitor-analysis.html)
- [Oracle RAC Monitoring: V$, GV$ - DBAKevlar](https://dbakevlar.com/2025/05/oracle-rac-monitoring-v-gv-and-the-rest/)
- [Oracle Data Guard Monitoring - Oracle Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/monitor-oracle-data-guard-configuration.html)
- [Oracle Database Memory Monitoring Guide - DBA Dataverse](https://dbadataverse.com/tech/letstalkoracle/2025/02/oracle-database-memory-monitoring-guide)
- [Oracle Memory Tuning Best Practices](https://giteshtrivedi.wordpress.com/2026/01/25/top-oracle-memory-tuning-best-practices-every-dba-should-know/)
- [pgwatch - PostgreSQL Monitoring Tool - CYBERTEC](https://www.cybertec-postgresql.com/en/products/pgwatch-postgresql-monitoring/)
- [PgBouncer Exporter - Prometheus Community](https://github.com/prometheus-community/pgbouncer_exporter)
- [RED Metrics and Monitoring - Splunk](https://www.splunk.com/en_us/blog/learn/red-monitoring.html)
- [Golden Signals for SRE - Sysdig](https://www.sysdig.com/blog/golden-signals-kubernetes)
- [Mastering Observability: Golden Signals, RED & USE - Medium](https://medium.com/@farhanramzan799/mastering-observability-in-sre-golden-signals-red-use-metrics-005656c4fe7d)
- [PostgreSQL Autovacuum and Bloat - PostgreSQL Documentation](https://www.postgresql.org/docs/current/routine-vacuuming.html)
- [PostgreSQL Dead Tuples: MVCC, Autovacuum, and Bloat - Skyline Codes](https://skylinecodes.substack.com/p/postgresql-dead-tuples-mvcc-autovacuum)


---

# Part II: NoSQL and Specialized Databases

---

## 1. MongoDB Observability

### 1.1 Architecture Context

MongoDB is a document-oriented database using BSON format with flexible schemas. Deployments range from standalone instances to replica sets (3+ node HA) and sharded clusters (horizontal scaling). The WiredTiger storage engine (default since 3.2) provides document-level concurrency control, compression, and an internal cache separate from the OS page cache.

**Key observability surfaces:**
- `serverStatus` command (comprehensive server metrics)
- `currentOp` (active operations in real time)
- Database Profiler (slow query capture)
- Replica set status (`rs.status()`)
- Sharded cluster diagnostics (`sh.status()`)
- WiredTiger engine statistics
- Index usage statistics (`$indexStats`)
- MongoDB Atlas monitoring (managed service)
- Prometheus exporters (`percona/mongodb_exporter`)
- OpenTelemetry MongoDB receiver

### 1.2 serverStatus Command

The `serverStatus` command is the single most important diagnostic command. Run it from the `admin` database:

```javascript
db.serverStatus()
// Or specific sections:
db.serverStatus({ connections: 1, opcounters: 1, mem: 1, wiredTiger: 1 })
```

#### 1.2.1 Connections

```javascript
db.serverStatus().connections
// Output:
{
  "current": 47,        // Active connections now
  "available": 51153,   // Remaining available connections
  "totalCreated": 12847, // Cumulative connections since startup
  "active": 12,         // Connections performing operations
  "threaded": 47,       // Connections assigned to threads
  "exhaustIsMaster": 0,
  "exhaustHello": 3,
  "awaitingTopologyChanges": 3
}
```

**Key metrics and thresholds:**

| Metric | Description | Warning | Critical |
|--------|-------------|---------|----------|
| `connections.current` | Active connections | >80% of `maxConns` | >90% of `maxConns` |
| `connections.available` | Remaining slots | <1000 | <100 |
| `connections.current / (current + available)` | Utilization ratio | >0.8 | >0.9 |
| Rate of `connections.totalCreated` | Connection churn | >100/sec (pooling issue) | >500/sec |

**Default `maxConns`**: 65536 (or 80% of system `ulimit -n`, whichever is lower).

**PromQL examples:**
```promql
# Connection utilization
mongodb_connections_current / (mongodb_connections_current + mongodb_connections_available)

# Connection creation rate (churn)
rate(mongodb_connections_totalcreated[5m])
```

#### 1.2.2 opcounters

```javascript
db.serverStatus().opcounters
// Output:
{
  "insert": 1284567,   // Cumulative inserts
  "query": 8745231,    // Cumulative queries
  "update": 2341567,   // Cumulative updates
  "delete": 456789,    // Cumulative deletes
  "getmore": 345678,   // Cumulative getMore (cursor iteration)
  "command": 15678901  // Cumulative commands (includes admin)
}
```

These are monotonically increasing counters -- always compute rates:

```promql
# Operations per second by type
rate(mongodb_opcounters_total{type="query"}[5m])
rate(mongodb_opcounters_total{type="insert"}[5m])
rate(mongodb_opcounters_total{type="update"}[5m])
rate(mongodb_opcounters_total{type="delete"}[5m])

# Total operations per second
sum(rate(mongodb_opcounters_total[5m]))
```

For replica sets, also check `opcountersRepl` which tracks replication-applied operations on secondaries.

#### 1.2.3 Network

```javascript
db.serverStatus().network
// Output:
{
  "bytesIn": 45678901234,       // Bytes received from clients
  "bytesOut": 123456789012,     // Bytes sent to clients
  "physicalBytesIn": 45678901234,
  "physicalBytesOut": 123456789012,
  "numRequests": 28504488,       // Total requests received
  "compression": {
    "snappy": { "compressor": { ... }, "decompressor": { ... } },
    "zstd": { ... },
    "zlib": { ... }
  },
  "serviceExecutorTaskStats": { ... }
}
```

```promql
# Network throughput
rate(mongodb_network_bytes_in_total[5m])
rate(mongodb_network_bytes_out_total[5m])

# Request rate
rate(mongodb_network_num_requests_total[5m])

# Average request size
rate(mongodb_network_bytes_in_total[5m]) / rate(mongodb_network_num_requests_total[5m])
```

#### 1.2.4 Memory

```javascript
db.serverStatus().mem
// Output:
{
  "bits": 64,
  "resident": 4096,   // MB - Physical RAM used by mongod process
  "virtual": 8192,    // MB - Virtual address space
  "supported": true,
  "note": "..."
}
```

| Metric | Description | Alert Condition |
|--------|-------------|-----------------|
| `mem.resident` | Physical RAM (MB) | >80% of system RAM |
| `mem.virtual` | Virtual memory (MB) | >2x resident (possible memory leak) |
| `virtual / resident` ratio | Memory mapping efficiency | >3.0 investigate |

#### 1.2.5 Locks

```javascript
db.serverStatus().locks
// Output includes lock stats per lock type:
{
  "Global": { "acquireCount": { "r": 12345, "w": 678, "W": 2 } },
  "Database": { "acquireCount": { "r": 9876, "w": 543, "R": 1 } },
  "Collection": { "acquireCount": { "r": 8765, "w": 432 } },
  "Mutex": { "acquireCount": { "r": 5678 } }
}
// Lock modes: r=shared(IS), w=exclusive(IX), R=Shared(S), W=Exclusive(X)
```

#### 1.2.6 globalLock

```javascript
db.serverStatus().globalLock
// Output:
{
  "totalTime": 123456789000,  // Microseconds since mongod start
  "currentQueue": {
    "total": 0,     // Operations waiting for lock
    "readers": 0,   // Reads waiting
    "writers": 0    // Writes waiting
  },
  "activeClients": {
    "total": 12,    // Active client connections performing ops
    "readers": 8,
    "writers": 4
  }
}
```

**Critical alert**: `globalLock.currentQueue.total > 0` sustained for >30 seconds indicates lock contention.

```promql
# Lock queue depth
mongodb_global_lock_current_queue{type="reader"}
mongodb_global_lock_current_queue{type="writer"}

# Active clients
mongodb_global_lock_client{type="reader"}
mongodb_global_lock_client{type="writer"}
```

#### 1.2.7 WiredTiger Cache Metrics

```javascript
db.serverStatus().wiredTiger.cache
// Key fields:
{
  "bytes currently in the cache": 2147483648,           // Current cache usage
  "maximum bytes configured": 3221225472,               // Cache size limit
  "bytes read into cache": 1073741824,                  // Data read from disk
  "bytes written from cache": 536870912,                // Data written to disk
  "tracked dirty bytes in the cache": 104857600,        // Dirty data pending write
  "tracked dirty pages in the cache": 1024,
  "pages evicted by application threads": 0,            // App-triggered eviction (BAD)
  "unmodified pages evicted": 5678,                     // Clean page eviction
  "modified pages evicted": 234,                        // Dirty page eviction
  "pages read into cache": 45678,
  "pages written from cache": 12345,
  "maximum page size at eviction": 10485760
}
```

**Cache sizing formula**: WiredTiger cache default = `max(256MB, 50% of (RAM - 1GB))`.

| Metric | Formula | Warning | Critical |
|--------|---------|---------|----------|
| Cache utilization | `bytes_in_cache / max_configured` | >80% | >95% |
| Dirty cache ratio | `dirty_bytes / max_configured` | >5% | >20% |
| App-thread eviction | `pages_evicted_by_app_threads` rate | >0/sec | >10/sec |
| Cache read ratio | `bytes_read / (read + written)` | N/A (informational) | N/A |

```promql
# WiredTiger cache utilization
mongodb_wiredtiger_cache_bytes / mongodb_wiredtiger_cache_max_bytes

# Dirty page ratio
mongodb_wiredtiger_cache_dirty_bytes / mongodb_wiredtiger_cache_max_bytes

# Eviction rate (app threads doing eviction = performance impact)
rate(mongodb_wiredtiger_cache_evicted_total{type="application"}[5m])
```

**Anti-pattern**: If application threads are doing eviction (`pages evicted by application threads > 0` sustained), the cache is undersized. Increase `wiredTigerCacheSizeGB` or add RAM.

### 1.3 currentOp

`currentOp` shows all in-flight operations:

```javascript
// All active operations
db.currentOp({ "active": true })

// Long-running operations (>5 seconds)
db.currentOp({ "active": true, "secs_running": { "$gt": 5 } })

// Operations waiting for locks
db.currentOp({ "waitingForLock": true })

// Operations on a specific collection
db.currentOp({ "ns": "mydb.mycollection" })

// Operations from a specific client
db.currentOp({ "client": /^10\.0\.1\./ })
```

**Output fields of interest per operation:**
```javascript
{
  "opid": 12345,
  "active": true,
  "secs_running": 45,
  "microsecs_running": 45000000,
  "op": "query",              // query, insert, update, remove, getmore, command
  "ns": "mydb.users",
  "command": { "find": "users", "filter": { "status": "active" } },
  "planSummary": "COLLSCAN",  // RED FLAG if not IXSCAN
  "numYields": 234,
  "locks": { ... },
  "waitingForLock": false,
  "client": "10.0.1.50:54321",
  "appName": "myapp",
  "connectionId": 789
}
```

**Kill a long-running operation:**
```javascript
db.killOp(12345)
```

**Key patterns to watch:**
- `planSummary: "COLLSCAN"` on large collections = missing index
- `secs_running > 30` = long-running query needs investigation
- `waitingForLock: true` sustained = lock contention
- `numYields` very high = operation yielding frequently due to contention

### 1.4 Database Profiler

The profiler captures slow operations to the `system.profile` capped collection in each database.

#### Profiler Levels

| Level | Behavior | Use Case |
|-------|----------|----------|
| 0 | Off | Production default |
| 1 | Log operations slower than `slowms` | Production recommended |
| 2 | Log ALL operations | Debugging only (heavy overhead) |

```javascript
// Check current profiler status
db.getProfilingStatus()
// { "was": 1, "slowms": 100, "sampleRate": 1.0 }

// Set profiler to level 1 with 100ms threshold
db.setProfilingLevel(1, { slowms: 100 })

// Set profiler with sampling (reduce overhead in high-throughput)
db.setProfilingLevel(1, { slowms: 50, sampleRate: 0.5 })

// Disable profiler
db.setProfilingLevel(0)
```

#### Analyzing Profiler Output

```javascript
// Find slowest queries in the last hour
db.system.profile.find({
  ts: { $gt: new Date(Date.now() - 3600000) }
}).sort({ millis: -1 }).limit(10)

// Find collection scans (missing indexes)
db.system.profile.find({
  "planSummary": "COLLSCAN",
  millis: { $gt: 100 }
})

// Find queries with high document examination ratio
db.system.profile.find({
  "docsExamined": { $gt: 1000 },
  "nreturned": { $lt: 10 }
})

// Aggregate by operation pattern
db.system.profile.aggregate([
  { $group: {
    _id: { ns: "$ns", op: "$op" },
    count: { $sum: 1 },
    avgMillis: { $avg: "$millis" },
    maxMillis: { $max: "$millis" },
    totalMillis: { $sum: "$millis" }
  }},
  { $sort: { totalMillis: -1 } }
])
```

**Profiler output key fields:**
```javascript
{
  "op": "query",
  "ns": "mydb.users",
  "command": { "find": "users", "filter": { ... } },
  "keysExamined": 0,        // Index keys scanned
  "docsExamined": 150000,   // Documents scanned
  "nreturned": 5,           // Documents returned
  "millis": 2345,           // Execution time (ms)
  "planSummary": "COLLSCAN",
  "responseLength": 4567,
  "ts": ISODate("2025-01-15T10:30:00Z")
}
```

**Index efficiency ratio**: `keysExamined / nreturned` should be close to 1.0. A ratio >10 suggests index inefficiency. `docsExamined / nreturned` >100 is a strong signal for missing or wrong index.

### 1.5 Replica Set Monitoring

#### rs.status()

```javascript
rs.status()
// Key output:
{
  "set": "rs0",
  "myState": 1,            // 1=PRIMARY, 2=SECONDARY, 7=ARBITER
  "heartbeatIntervalMillis": 2000,
  "members": [
    {
      "name": "mongo1:27017",
      "stateStr": "PRIMARY",
      "health": 1,           // 1=UP, 0=DOWN
      "uptime": 864000,
      "optime": { "ts": Timestamp(1705312200, 1), "t": 5 },
      "optimeDate": ISODate("2025-01-15T10:30:00Z"),
      "electionTime": Timestamp(1705225800, 1),
      "electionDate": ISODate("2025-01-14T10:30:00Z"),
      "configVersion": 3,
      "self": true
    },
    {
      "name": "mongo2:27017",
      "stateStr": "SECONDARY",
      "health": 1,
      "uptime": 864000,
      "optime": { "ts": Timestamp(1705312198, 1), "t": 5 },
      "optimeDate": ISODate("2025-01-15T10:29:58Z"),
      "lastHeartbeat": ISODate("2025-01-15T10:30:01Z"),
      "lastHeartbeatRecv": ISODate("2025-01-15T10:30:00Z"),
      "pingMs": 1,
      "syncSourceHost": "mongo1:27017"
    }
  ]
}
```

#### Replication Lag

```javascript
// Check replication lag from primary
rs.printSecondaryReplicationInfo()
// Output:
// source: mongo2:27017
//   syncedTo: Mon Jan 15 2025 10:29:58 GMT+0000
//   2 secs (0 hrs) behind the primary
```

**Programmatic lag calculation:**
```javascript
var primary = rs.status().members.find(m => m.stateStr === "PRIMARY");
var secondaries = rs.status().members.filter(m => m.stateStr === "SECONDARY");
secondaries.forEach(function(s) {
  var lagSecs = (primary.optime.ts.getTime() - s.optime.ts.getTime());
  print(s.name + ": " + lagSecs + " seconds behind primary");
});
```

**Oplog window** (time before oplog wraps around):
```javascript
// Check oplog size and window
db.getReplicationInfo()
// Output:
{
  "logSizeMB": 1024,
  "usedMB": 512,
  "timeDiff": 172800,        // Seconds of oplog history
  "timeDiffHours": 48,       // Hours of oplog history
  "tFirst": "Mon Jan 13 2025 10:30:00 GMT",
  "tLast": "Wed Jan 15 2025 10:30:00 GMT",
  "now": "Wed Jan 15 2025 10:30:00 GMT"
}
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Replication lag | >10 seconds | >60 seconds |
| Oplog window | <24 hours | <4 hours |
| Member health | Any member health=0 | Majority members down |
| Election events | >1 per hour | >1 per 10 minutes |

```promql
# Replication lag in seconds
mongodb_replica_set_member_replication_lag_seconds

# Oplog window hours
mongodb_replica_set_oplog_window_seconds / 3600

# Election count
increase(mongodb_replica_set_member_election_id[1h])
```

### 1.6 Sharded Cluster Monitoring

```javascript
// Overall shard status
sh.status()

// Balancer state
sh.getBalancerState()            // true/false
sh.isBalancerRunning()           // actively moving chunks?

// Chunk distribution per collection
db.getSiblingDB("config").chunks.aggregate([
  { $group: { _id: "$shard", count: { $sum: 1 } } },
  { $sort: { count: -1 } }
])

// Config server health
db.getSiblingDB("config").mongos.find().sort({ ping: -1 })

// Jumbo chunks (cannot be split/moved)
db.getSiblingDB("config").chunks.find({ jumbo: true })
```

**Sharded cluster metrics:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Chunk imbalance (max-min across shards) | >20% | >50% |
| Jumbo chunks | >0 | >10 |
| Balancer rounds with errors | >0/hour | >5/hour |
| Config server replication lag | >2 seconds | >10 seconds |
| Mongos connection count per shard | Varies by workload | >80% of shard `maxConns` |

### 1.7 Index Usage Statistics

```javascript
// Get index usage stats for a collection
db.users.aggregate([{ $indexStats: {} }])
// Output per index:
{
  "name": "status_1_createdAt_-1",
  "key": { "status": 1, "createdAt": -1 },
  "host": "mongo1:27017",
  "accesses": {
    "ops": 1234567,        // Times this index was used
    "since": ISODate("2025-01-01T00:00:00Z")
  }
}
```

**Unused index detection** -- indexes with `ops: 0` since server restart are candidates for removal (saves write overhead and storage):

```javascript
db.users.aggregate([
  { $indexStats: {} },
  { $match: { "accesses.ops": 0 } }
])
```

### 1.8 Atlas Monitoring vs Self-Hosted

| Capability | Atlas (Managed) | Self-Hosted |
|-----------|----------------|-------------|
| Real-time metrics | Built-in dashboard, 1-min granularity | DIY with exporters |
| Query Profiler | Visual Profiler UI, no `db.setProfilingLevel()` needed | Manual profiler setup |
| Performance Advisor | Automatic index recommendations | Manual `$indexStats` analysis |
| Alerts | Configurable via Atlas UI/API | DIY with Prometheus/Grafana |
| Slow query log | Downloadable, integrated with Data Explorer | `system.profile` collection |
| Real-Time Performance Panel | Live ops, network, connections | `mongostat`, `mongotop` |
| Audit Logs | M10+ tiers, downloadable | Enterprise Advanced only |
| OTel integration | Atlas receiver (`mongodbatlas` in OTel Collector) | `mongodb` receiver in OTel Collector |
| Metrics retention | Configurable up to 2 years | Depends on backend |

### 1.9 MongoDB Exporter for Prometheus

The `percona/mongodb_exporter` is the standard Prometheus exporter:

```yaml
# docker-compose example
mongodb-exporter:
  image: percona/mongodb_exporter:0.40
  environment:
    MONGODB_URI: "mongodb://otel:password@mongo1:27017,mongo2:27017,mongo3:27017/admin?replicaSet=rs0"
  command:
    - '--collect-all'
    - '--compatible-mode'   # Use prometheus-compatible metric names
    - '--discovering-mode'  # Auto-discover databases and collections
  ports:
    - "9216:9216"
```

**Key exported metrics:**
```
mongodb_up                                        # 1 if connected, 0 if not
mongodb_connections{state="current|available"}     # Connection gauge
mongodb_opcounters_total{type="insert|query|..."}  # Operation counters
mongodb_memory{type="resident|virtual"}            # Memory in MB
mongodb_wiredtiger_cache_bytes                     # WT cache usage
mongodb_wiredtiger_cache_max_bytes                 # WT cache limit
mongodb_wiredtiger_cache_dirty_bytes               # Dirty cache
mongodb_replica_set_member_state                   # Member state code
mongodb_replica_set_member_optime_date             # Optime for lag calc
mongodb_global_lock_current_queue                  # Lock queue depth
mongodb_index_usage_accesses_total                 # Per-index usage
```

### 1.10 Connection Pool Monitoring

MongoDB drivers maintain connection pools. Monitor from both the driver side and the server side:

**Server-side** (`serverStatus`):
```javascript
db.serverStatus().connections
// Plus check for connection storm patterns:
db.currentOp({ "active": true }).inprog.length
```

**Driver-side** (example: Node.js driver pool events):
```javascript
const client = new MongoClient(uri, {
  maxPoolSize: 100,
  minPoolSize: 10,
  maxIdleTimeMS: 30000,
  waitQueueTimeoutMS: 5000
});

// Monitor pool events
client.on('connectionPoolCreated', (e) => metrics.gauge('pool.size', e.options.maxPoolSize));
client.on('connectionCheckedOut', () => metrics.increment('pool.checkout'));
client.on('connectionCheckedIn', () => metrics.increment('pool.checkin'));
client.on('connectionPoolCleared', () => metrics.increment('pool.cleared'));
client.on('connectionCheckOutFailed', (e) => metrics.increment('pool.checkout_failed'));
```

### 1.11 MongoDB Alert Summary

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| High Connection Usage | `connections.current / (current + available) > 0.8` | Warning |
| Connection Exhaustion | `connections.available < 100` | Critical |
| High Replication Lag | `replication_lag > 10s` | Warning |
| Critical Replication Lag | `replication_lag > 60s` | Critical |
| Member Down | `member.health == 0` | Critical |
| WT Cache Pressure | `cache_bytes / max_bytes > 0.95` | Critical |
| WT Dirty Pages | `dirty_bytes / max_bytes > 0.20` | Warning |
| App Thread Eviction | `rate(app_evicted) > 0` | Warning |
| Lock Queue Buildup | `globalLock.currentQueue.total > 10` for 1m | Warning |
| Low Oplog Window | `oplog_window < 24h` | Warning |
| Collection Scan Detected | Profiler `COLLSCAN` on >10K docs | Warning |
| High Query Targeting | `docsExamined / nreturned > 1000` | Warning |

---

## 2. Redis Observability

### 2.1 Architecture Context

Redis is an in-memory data structure store used as a database, cache, message broker, and streaming engine. Deployment topologies include standalone, Sentinel (HA), and Redis Cluster (horizontal sharding across slots 0-16383). Since all data is in memory, memory monitoring is the single most critical observability dimension.

**Key observability surfaces:**
- `INFO` command (comprehensive server statistics)
- `SLOWLOG` (slow command capture)
- `LATENCY` monitoring framework (since Redis 2.8.13, enhanced in 6.2)
- `CLIENT LIST` / `CLIENT INFO` (connection analysis)
- `MEMORY` commands (detailed memory analysis)
- `CLUSTER INFO` / `CLUSTER NODES` (cluster state)
- Redis Sentinel events (failover monitoring)
- Redis Streams `XINFO` (consumer group monitoring)
- Prometheus: `oliver006/redis_exporter`
- RedisInsight (GUI diagnostic tool)
- OpenTelemetry Redis receiver

### 2.2 INFO Command Sections

The `INFO` command is Redis's primary diagnostic tool. It returns key-value pairs grouped by section:

```bash
# All sections
redis-cli INFO

# Specific section
redis-cli INFO memory
redis-cli INFO stats
redis-cli INFO replication
redis-cli INFO clients
redis-cli INFO keyspace
```

#### 2.2.1 INFO server

```
redis_version:7.2.4
redis_mode:standalone          # standalone, sentinel, or cluster
os:Linux 5.15.0-91-generic x86_64
tcp_port:6379
uptime_in_seconds:864000
uptime_in_days:10
hz:10                          # Server event loop frequency
configured_hz:10
```

#### 2.2.2 INFO clients

```
connected_clients:142          # Current client connections
cluster_connections:0          # Cluster bus connections
maxclients:10000               # Configured maximum
blocked_clients:3              # Clients in BLPOP/BRPOP/WAIT
tracking_clients:0             # Clients using client-side caching
clients_in_timeout_table:0
total_blocking_clients:3
total_blocking_clients_on_nokey:0
```

| Metric | Warning | Critical |
|--------|---------|----------|
| `connected_clients` | >80% of `maxclients` | >95% of `maxclients` |
| `blocked_clients` | >50 | >200 (or >50% of connected) |
| `connected_clients` rate of change | Sudden spike >2x | >5x in 1 minute |

#### 2.2.3 INFO memory

```
used_memory:1073741824              # Bytes used by Redis allocator (1 GB)
used_memory_human:1.00G
used_memory_rss:1288490188          # Resident Set Size from OS (1.2 GB)
used_memory_rss_human:1.20G
used_memory_peak:2147483648         # Peak memory usage
used_memory_peak_human:2.00G
used_memory_peak_perc:50.00%        # Current vs peak
used_memory_overhead:234567890      # Memory used for overhead (metadata)
used_memory_startup:1234567         # Memory used at startup
used_memory_dataset:839173934       # used_memory - used_memory_overhead
used_memory_dataset_perc:78.15%     # Dataset vs total
total_system_memory:16777216000     # Total system memory
total_system_memory_human:15.63G
maxmemory:4294967296                # Configured memory limit
maxmemory_human:4.00G
maxmemory_policy:allkeys-lru        # Eviction policy
mem_fragmentation_ratio:1.20        # RSS / used_memory
mem_fragmentation_bytes:214748364
mem_allocator:jemalloc-5.3.0
lazyfree_pending_objects:0
lazyfreed_objects:12345
```

**Critical memory metrics:**

| Metric | Formula | Warning | Critical |
|--------|---------|---------|----------|
| Memory utilization | `used_memory / maxmemory` | >75% | >90% |
| Fragmentation ratio | `mem_fragmentation_ratio` | >1.5 or <1.0 | >2.0 or <0.8 |
| RSS vs used | `used_memory_rss - used_memory` | >25% overhead | >50% overhead |
| Peak ratio | `used_memory / used_memory_peak` | Informational | Near peak = approaching limit |

**Fragmentation ratio interpretation:**
- `1.0 - 1.1`: Ideal -- minimal fragmentation
- `1.1 - 1.5`: Normal -- acceptable fragmentation
- `>1.5`: High fragmentation -- Redis is using more RSS than needed; consider `MEMORY PURGE` or restart
- `<1.0`: Swapping -- RSS < used_memory means OS is swapping Redis to disk -- **critical performance impact**

```promql
# Memory utilization
redis_memory_used_bytes / redis_memory_max_bytes

# Fragmentation ratio
redis_memory_used_rss_bytes / redis_memory_used_bytes

# Eviction rate
rate(redis_evicted_keys_total[5m])
```

#### 2.2.4 Memory Eviction Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `noeviction` | Return error on writes when full | Data must never be lost |
| `allkeys-lru` | Evict least recently used keys | General-purpose cache |
| `allkeys-lfu` | Evict least frequently used keys | Frequency-biased cache |
| `allkeys-random` | Evict random keys | Uniform access patterns |
| `volatile-lru` | LRU among keys with TTL set | Mixed cache + persistent |
| `volatile-lfu` | LFU among keys with TTL set | Mixed cache + persistent |
| `volatile-random` | Random among keys with TTL | Simple TTL-based cache |
| `volatile-ttl` | Evict shortest TTL first | TTL-priority cache |

**Monitor evictions:**
```promql
# Eviction rate (should be 0 for non-cache workloads)
rate(redis_evicted_keys_total[5m])

# If evictions > 0 AND maxmemory_policy == noeviction, expect OOM errors
redis_rejected_connections_total
```

#### 2.2.5 INFO stats

```
total_connections_received:456789      # Cumulative connections
total_commands_processed:12345678      # Cumulative commands
instantaneous_ops_per_sec:1234         # Current ops/sec
total_net_input_bytes:1234567890
total_net_output_bytes:9876543210
instantaneous_input_kbps:456.78
instantaneous_output_kbps:1234.56
rejected_connections:0                  # Connections rejected (maxclients)
expired_keys:234567                     # Keys expired by TTL
expired_stale_perc:0.00                # % of keys expired that were stale
evicted_keys:0                          # Keys evicted due to maxmemory
evicted_clients:0                       # Clients evicted (client-output-buffer)
keyspace_hits:8745231                   # Successful key lookups
keyspace_misses:1234567                # Failed key lookups (key not found)
pubsub_channels:5                      # Active pub/sub channels
pubsub_patterns:2                      # Active pub/sub patterns
latest_fork_usec:12345                 # Last fork duration (microseconds)
total_forks:67                         # Total fork count
```

**Hit ratio (critical for cache workloads):**
```promql
# Cache hit ratio (should be >95% for caches)
redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total)

# Or as a rate
rate(redis_keyspace_hits_total[5m]) /
  (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Hit ratio (cache) | <95% | <90% |
| `evicted_keys` rate | >0/sec (non-cache) | >100/sec |
| `rejected_connections` | >0 | >10/sec |
| `latest_fork_usec` | >500ms | >1s |
| `instantaneous_ops_per_sec` | Context-dependent | Sudden drop >50% |

#### 2.2.6 INFO replication

```
role:master                              # master or slave
connected_slaves:2                       # Number of connected replicas
slave0:ip=10.0.1.51,port=6379,state=online,offset=123456789,lag=0
slave1:ip=10.0.1.52,port=6379,state=online,offset=123456785,lag=1
master_failover_state:no-failover
master_replid:abc123def456...
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:123456789             # Primary replication offset
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576                # Replication backlog size (1MB default)
repl_backlog_first_byte_offset:122408213
repl_backlog_histlen:1048576
```

**Replication lag:**
```promql
# Lag in bytes (primary offset - replica offset)
redis_master_repl_offset - on(instance) redis_connected_slave_offset_bytes

# Lag in seconds (from slave INFO)
redis_connected_slave_lag_seconds
```

| Metric | Warning | Critical |
|--------|---------|----------|
| `connected_slaves` | Less than expected | 0 (no replicas) |
| Replication lag (seconds) | >1 second | >10 seconds |
| Replication lag (bytes) | >repl_backlog_size * 0.5 | >repl_backlog_size * 0.9 |
| `state` | Any non-`online` | `offline` |

#### 2.2.7 INFO keyspace

```
db0:keys=1234567,expires=456789,avg_ttl=3600000
db1:keys=234,expires=234,avg_ttl=86400000
```

```promql
# Total keys
redis_db_keys{db="db0"}

# Keys with TTL
redis_db_keys_expiring{db="db0"}

# Percentage with TTL
redis_db_keys_expiring / redis_db_keys
```

### 2.3 SLOWLOG

Redis SLOWLOG captures commands exceeding a time threshold.

**Configuration:**
```bash
# Set slow log threshold to 10ms (10000 microseconds)
CONFIG SET slowlog-log-slower-than 10000

# Set max entries retained
CONFIG SET slowlog-max-len 256

# In redis.conf:
slowlog-log-slower-than 10000    # microseconds (0 = log everything, -1 = disable)
slowlog-max-len 256              # Number of entries to keep
```

**Analyzing SLOWLOG:**
```bash
# Get last 10 slow entries
SLOWLOG GET 10

# Output per entry:
# 1) (integer) 14              # Unique ID
# 2) (integer) 1705312200      # Unix timestamp
# 3) (integer) 15430           # Duration in microseconds
# 4) 1) "KEYS"                 # Command + arguments
#    2) "user:*"
# 5) "10.0.1.50:54321"         # Client address
# 6) "myapp"                   # Client name

# Count of slow commands
SLOWLOG LEN

# Clear the slow log
SLOWLOG RESET
```

**Common slow command patterns:**
- `KEYS *` -- O(N) scan of all keys; use `SCAN` instead
- `SMEMBERS` on large sets -- O(N) where N is set size
- `HGETALL` on large hashes -- O(N) where N is hash size
- `SORT` on large lists -- O(N+M*log(M))
- `LRANGE 0 -1` on large lists -- O(N)
- `DEL` on large keys -- use `UNLINK` (async) instead

### 2.4 Latency Monitoring

#### Built-in Latency Monitor (since 2.8.13)

```bash
# Enable latency monitoring (set threshold in ms; 0 = disable)
CONFIG SET latency-monitor-threshold 5

# Get latest latency events by category
LATENCY LATEST
# Output:
# 1) 1) "command"          # Event name
#    2) (integer) 1705312200  # Timestamp of latest event
#    3) (integer) 15       # Latest latency (ms)
#    4) (integer) 45       # All-time max latency (ms)
# 2) 1) "fast-command"
#    2) ...

# Get latency history for a specific event
LATENCY HISTORY command
# Returns time-series of (timestamp, latency_ms) pairs

# Reset latency data
LATENCY RESET
```

**Latency event categories:**
- `command` -- Regular command execution
- `fast-command` -- O(1)/O(log N) commands
- `fork` -- Background save fork
- `rdb-unlink-temp-file` -- RDB temp file removal
- `aof-write` -- AOF fsync
- `aof-write-pending-fsync` -- AOF fsync pending
- `aof-rewrite-diff-write` -- AOF rewrite buffer
- `expire-cycle` -- Key expiration cycle
- `eviction-cycle` -- Memory eviction cycle
- `eviction-del` -- Eviction deletion

#### Extended Latency Tracking (Redis 6.2+)

Redis 6.2 added per-command latency histograms:

```bash
# Get latency percentiles for all commands
LATENCY HISTOGRAM
# Output includes per-command p50, p99, p99.9 in microseconds

LATENCY HISTOGRAM GET SET HGET
# Filter to specific commands
```

### 2.5 Redis Sentinel Monitoring

Redis Sentinel provides HA through automatic failover:

```bash
# Connect to sentinel
redis-cli -p 26379

# Get monitored masters
SENTINEL MASTERS

# Get master status
SENTINEL MASTER mymaster
# Key fields:
# - flags: "master" (healthy) or "master,s_down" or "master,o_down"
# - num-slaves: 2
# - num-other-sentinels: 2
# - quorum: 2

# Get replica list
SENTINEL SLAVES mymaster

# Get sentinel list
SENTINEL SENTINELS mymaster
```

**Sentinel detection states:**

| State | Meaning | Condition |
|-------|---------|-----------|
| `s_down` (subjective) | One sentinel thinks node is down | No response for `down-after-milliseconds` |
| `o_down` (objective) | Quorum of sentinels agree node is down | `quorum` sentinels report s_down |
| Failover triggered | New primary election | After o_down confirmed |

**Sentinel pub/sub events to monitor:**
```bash
# Subscribe to all sentinel events
redis-cli -p 26379 SUBSCRIBE +sdown -sdown +odown -odown +switch-master +failover-state-reconf-slaves
```

Key events:
- `+sdown` -- Instance entered subjectively down state
- `-sdown` -- Instance cleared subjectively down state
- `+odown` -- Instance entered objectively down state
- `+switch-master` -- **Failover completed** -- new primary elected
- `+failover-state-reconf-slaves` -- Replicas reconfigured for new primary

### 2.6 Redis Cluster Monitoring

```bash
# Cluster overview
CLUSTER INFO
# Output:
cluster_enabled:1
cluster_state:ok                    # "ok" or "fail"
cluster_slots_assigned:16384        # Should be 16384
cluster_slots_ok:16384              # Healthy slots
cluster_slots_pfail:0               # Possibly failing slots
cluster_slots_fail:0                # Failed slots
cluster_known_nodes:6               # Total nodes (3 primary + 3 replica)
cluster_size:3                      # Number of primaries
cluster_current_epoch:6
cluster_my_epoch:2
cluster_stats_messages_sent:1234567
cluster_stats_messages_received:1234567

# Node details
CLUSTER NODES
# Each line: <id> <ip:port@bus-port> <flags> <master-id> <ping-sent> <pong-recv> <epoch> <link-state> <slot-range>
```

| Metric | Warning | Critical |
|--------|---------|----------|
| `cluster_state` | -- | `fail` |
| `cluster_slots_ok` | <16384 | <16384 with no failover |
| `cluster_slots_pfail` | >0 | -- |
| `cluster_slots_fail` | -- | >0 |
| Slot coverage | <100% | <100% for >30 seconds |

### 2.7 Redis Streams Monitoring

```bash
# Stream information
XINFO STREAM mystream
# Output:
# length: 1234567              # Messages in stream
# radix-tree-keys: 1234
# radix-tree-nodes: 5678
# last-generated-id: 1705312200000-0
# entries-added: 2345678       # Total messages ever added
# first-entry: ...
# last-entry: ...
# max-deleted-entry-id: 0-0
# recorded-first-entry-id: 1705225800000-0

# Consumer group information
XINFO GROUPS mystream
# Output per group:
# name: mygroup
# consumers: 3
# pending: 456                 # Messages delivered but not ACKed (LAG indicator)
# last-delivered-id: 1705312198000-0
# entries-read: 1234000
# lag: 567                     # Messages behind the stream tail

# Consumer details
XINFO CONSUMERS mystream mygroup
# Output per consumer:
# name: consumer-1
# pending: 123                 # Unacked messages for this consumer
# idle: 5000                   # Milliseconds since last interaction
# inactive: 5000               # Milliseconds since last successful read
```

**Key stream metrics:**
```promql
# Consumer group lag (critical for event processing)
redis_stream_group_lag{stream="mystream", group="mygroup"}

# Pending entries (unacknowledged)
redis_stream_group_pending{stream="mystream", group="mygroup"}

# Stream length growth rate
rate(redis_stream_length{stream="mystream"}[5m])
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Consumer group lag | >1000 messages | >10000 messages |
| Pending entries per consumer | >500 | >5000 |
| Consumer idle time | >30 seconds | >5 minutes |
| Stream length (if unbounded) | >1M entries | >10M entries |

### 2.8 CLIENT LIST Analysis

```bash
CLIENT LIST
# Output per client (space-separated fields):
# id=123 addr=10.0.1.50:54321 fd=8 name=myapp db=0 sub=0 psub=0
# multi=-1 qbuf=0 qbuf-free=32768 obl=0 oll=0 omem=0 tot-mem=20512
# events=r cmd=get user=default lib-name=redis-py lib-ver=5.0.0
# age=3600 idle=5 flags=N

# Filter to specific patterns
CLIENT LIST TYPE normal     # Normal clients only
CLIENT LIST TYPE replica    # Replica connections
CLIENT LIST TYPE pubsub     # Pub/sub subscribers
CLIENT LIST ID 123 456      # Specific client IDs
```

**Key CLIENT LIST fields:**

| Field | Meaning | Alert Condition |
|-------|---------|-----------------|
| `age` | Connection age (seconds) | >86400 with no pool recycling |
| `idle` | Idle time (seconds) | >300 AND many connections (pool leak) |
| `qbuf` | Query buffer (bytes) | >1MB (client sending large commands) |
| `oll` | Output list length | >100 (slow consumer) |
| `omem` | Output buffer memory | >10MB (client not consuming fast enough) |
| `tot-mem` | Total memory per client | Sum across all clients >10% of maxmemory |
| `flags=b` | Blocked (BLPOP etc.) | Many blocked for long periods |
| `multi` | In MULTI transaction | >0 held for long durations |

### 2.9 Redis Memory Commands

```bash
# Overall memory report
MEMORY DOCTOR
# Returns plain-text diagnosis like:
# "Sam, I have a few things to report..."
# Checks: peak memory, fragmentation, allocator waste, replication backlog

# Memory usage for a specific key
MEMORY USAGE mykey
# Returns bytes including overhead: (integer) 72

# Memory stats breakdown
MEMORY STATS
# Returns detailed memory allocation breakdown:
# peak.allocated, total.allocated, startup.allocated, replication.backlog,
# clients.slaves, clients.normal, aof.buffer, overhead.total, keys.count,
# keys.bytes-per-key, dataset.bytes, dataset.percentage, peak.percentage,
# allocator.allocated, allocator.active, allocator.resident

# Purge jemalloc dirty pages
MEMORY PURGE

# Memory allocation sampling
MEMORY MALLOC-STATS
```

### 2.10 redis_exporter for Prometheus

```yaml
# docker-compose example
redis-exporter:
  image: oliver006/redis_exporter:v1.58.0
  environment:
    REDIS_ADDR: "redis://redis-primary:6379"
    REDIS_PASSWORD: "${REDIS_PASSWORD}"
  command:
    - '--include-system-metrics'
    - '--is-cluster'                    # Enable cluster metrics
    - '--check-streams'                 # Enable stream metrics
    - '--count-keys=user:*,session:*'   # Count keys matching patterns
  ports:
    - "9121:9121"
```

**Key exported metrics:**
```
redis_up                                          # 1 if connected
redis_uptime_in_seconds                           # Server uptime
redis_connected_clients                           # Current connections
redis_blocked_clients                             # Blocked connections
redis_memory_used_bytes                           # Used memory
redis_memory_max_bytes                            # maxmemory
redis_memory_used_rss_bytes                       # RSS
redis_mem_fragmentation_ratio                     # Fragmentation
redis_evicted_keys_total                          # Evicted keys
redis_keyspace_hits_total                         # Cache hits
redis_keyspace_misses_total                       # Cache misses
redis_commands_processed_total                    # Total commands
redis_instantaneous_ops_per_sec                   # Current ops/sec
redis_connected_slaves                            # Replica count
redis_master_repl_offset                          # Replication offset
redis_connected_slave_lag_seconds                 # Replica lag
redis_slowlog_length                              # Slow log entries
redis_slowlog_last_id                             # Latest slow log ID
redis_cluster_state                               # Cluster ok/fail
redis_db_keys{db="db0"}                           # Keys per DB
redis_stream_length{stream="..."}                 # Stream length
redis_stream_group_lag{stream="...",group="..."}  # Consumer lag
```

### 2.11 Redis Alert Summary

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| Memory Near Limit | `used_memory / maxmemory > 0.9` | Critical |
| High Fragmentation | `mem_fragmentation_ratio > 2.0` | Warning |
| Redis Swapping | `mem_fragmentation_ratio < 1.0` | Critical |
| Evictions Occurring | `rate(evicted_keys) > 0` (non-cache) | Warning |
| Low Hit Ratio | `hit_ratio < 0.90` | Warning |
| Connection Exhaustion | `connected_clients > maxclients * 0.9` | Critical |
| Replica Disconnected | `connected_slaves < expected` | Critical |
| Replication Lag | `slave_lag > 10s` | Warning |
| Cluster State Fail | `cluster_state != ok` | Critical |
| Slots Not Covered | `cluster_slots_ok < 16384` | Critical |
| Blocked Clients High | `blocked_clients > 100` | Warning |
| Consumer Group Lag | `stream_group_lag > 10000` | Warning |
| Rejected Connections | `rate(rejected_connections) > 0` | Critical |
| High Fork Time | `latest_fork_usec > 500000` | Warning |

---

## 3. Apache Cassandra Observability

### 3.1 Architecture Context

Apache Cassandra is a distributed wide-column store designed for high availability and linear scalability. It uses a peer-to-peer architecture with no single point of failure -- every node can serve reads and writes. Data is partitioned across nodes via consistent hashing and replicated according to the replication factor. The LSM-tree storage engine (memtable -> SSTable with compaction) creates unique observability challenges around compaction, tombstones, and read amplification.

**Key observability surfaces:**
- `nodetool` CLI commands (status, info, tpstats, tablehistograms, compactionstats)
- JMX metrics (the primary metrics interface; all Cassandra metrics are exposed via JMX MBeans)
- System log (`system.log`) and debug log
- Gossip protocol state
- Repair and streaming metrics
- GC monitoring (critical for JVM-based Cassandra)
- Prometheus exporters (Cassandra Exporter, DataStax MCAC)
- OpenTelemetry JMX receiver with `target_system: cassandra`

### 3.2 nodetool Commands

#### 3.2.1 nodetool status

```bash
nodetool status
# Output:
# Datacenter: dc1
# ===============
# Status=Up/Down  State=Normal/Leaving/Joining/Moving
# --  Address       Load        Tokens  Owns (effective)  Host ID   Rack
# UN  10.0.1.51     256.5 GiB   256     33.3%             abc-123   rack1
# UN  10.0.1.52     248.2 GiB   256     33.4%             def-456   rack2
# UN  10.0.1.53     251.8 GiB   256     33.3%             ghi-789   rack3
# DN  10.0.1.54     0 bytes     256     0.0%              jkl-012   rack1
```

**State codes:**
| Code | Status | State | Meaning |
|------|--------|-------|---------|
| UN | Up | Normal | Healthy, serving requests |
| DN | Down | Normal | Unreachable, expected to recover |
| UJ | Up | Joining | Bootstrap in progress |
| UL | Up | Leaving | Decommission in progress |
| UM | Up | Moving | Token range reassignment |

**Alert**: Any node not in `UN` state for more than 5 minutes requires investigation.

#### 3.2.2 nodetool info

```bash
nodetool info
# Output:
# ID                     : abc-123-def-456
# Gossip active          : true
# Native Transport active: true
# Load                   : 256.5 GiB
# Generation No          : 1705225800
# Uptime (seconds)       : 864000
# Heap Memory (MB)       : 4096.00 / 8192.00  (used / max)
# Off Heap Memory (MB)   : 512.34
# Data Center            : dc1
# Rack                   : rack1
# Key Cache              : entries 234567, size 128 MB, capacity 256 MB, 987654 hits, 1234567 requests, 0.799 recent hit rate
# Row Cache              : entries 0, size 0 bytes, capacity 0 bytes, 0 hits, 0 requests, NaN recent hit rate
# Counter Cache          : entries 1234, size 8 MB, capacity 64 MB, 5678 hits, 12345 requests, 0.460 recent hit rate
# Network Cache          : size 32 MB, overflow size: 0 bytes, capacity 64 MB
# Percent Repaired       : 98.5%
# Token                  : (lots of tokens)
```

**Key metrics from `nodetool info`:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Heap used/max | >75% | >85% |
| Key Cache hit rate | <0.85 | <0.70 |
| Percent Repaired | <95% | <80% |
| Off Heap Memory | >50% of heap | >75% of heap |

#### 3.2.3 nodetool tpstats (Thread Pool Statistics)

```bash
nodetool tpstats
# Output:
# Pool Name                    Active  Pending  Completed  Blocked  All time blocked
# ReadStage                    8       2        12345678   0        0
# MutationStage                4       0        8765432    0        0
# CounterMutationStage         0       0        1234       0        0
# ViewMutationStage            0       0        0          0        0
# GossipStage                  0       0        456789     0        0
# AntiEntropyStage             0       0        1234       0        0
# MigrationStage               0       0        12         0        0
# MiscStage                    0       0        5678       0        0
# InternalResponseStage        0       0        234567     0        0
# ReadRepairStage              0       0        12345      0        0
# RequestResponseStage         0       0        9876543    0        0
# CompactionExecutor           2       3        56789      0        0
# MemtableFlushWriter          1       0        1234       0        0
# MemtablePostFlush            0       0        2468       0        0
# MemtableReclaimMemory        0       0        1234       0        0
# Native-Transport-Requests    12      5        23456789   0        0
#
# Message type       Dropped   Latency waiting in queue (50% / 95% / 99%)
# READ               0         0.123 / 1.234 / 5.678
# RANGE_SLICE        0         0.234 / 2.345 / 8.901
# _WRITE             12        0.045 / 0.456 / 2.345
# COUNTER_MUTATION   0         N/A
# READ_REPAIR        0         0.567 / 3.456 / 12.345
# HINT               0         N/A
# MUTATION           5         0.067 / 0.678 / 3.456
```

**Critical thread pool metrics:**

| Pool | Pending Warning | Pending Critical | Blocked/Dropped |
|------|-----------------|------------------|-----------------|
| `ReadStage` | >15 | >50 | Any blocked = client impact |
| `MutationStage` | >15 | >50 | Any blocked = write failures |
| `CompactionExecutor` | >20 | >100 | Compaction falling behind |
| `MemtableFlushWriter` | >5 | >15 | Flush backlog (memtable pressure) |
| `Native-Transport-Requests` | >1000 | >5000 | Client connection saturation |

**Dropped messages = DATA LOSS or TIMEOUT**. Any non-zero dropped messages require immediate investigation:
```promql
# Dropped messages rate
rate(cassandra_dropped_message_dropped_total{message_type="MUTATION"}[5m])
rate(cassandra_dropped_message_dropped_total{message_type="READ"}[5m])
```

#### 3.2.4 nodetool tablehistograms

```bash
nodetool tablehistograms mykeyspace mytable
# Output:
# mykeyspace/mytable histograms
# Percentile  SSTables    Write Latency   Read Latency    Partition Size   Cell Count
#                          (micros)        (micros)        (bytes)
# 50%         1.00        23.00           456.00          1234             56
# 75%         2.00        34.00           789.00          5678             123
# 95%         3.00        89.00           2345.00         23456            456
# 98%         4.00        134.00          5678.00         56789            789
# 99%         5.00        234.00          12345.00        123456           1234
# Min         1.00        10.00           123.00          456              12
# Max         8.00        567.00          45678.00        567890           5678
```

**What to look for:**
- `SSTables` at p99: >10 means high read amplification (too many SSTables per read)
- `Read Latency` p99: >10ms for SSD, >50ms for HDD is concerning
- `Partition Size` p99: >100MB indicates large partitions (anti-pattern)
- `Cell Count` p99: >100K indicates wide partitions

#### 3.2.5 nodetool compactionstats

```bash
nodetool compactionstats
# Output:
# pending tasks: 12
# compaction type  keyspace   table      completed    total        unit     progress
# Compaction       mykeyspace mytable    1234567890   2345678901   bytes    52.63%
# Compaction       mykeyspace other      456789012    567890123    bytes    80.41%
#
# Active compaction remaining time:  0h12m34s
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Pending compactions | >20 | >100 |
| Compaction throughput | <50 MB/s on SSD | <20 MB/s on SSD |
| Compaction duration | >1 hour per task | >4 hours per task |

#### 3.2.6 nodetool cfstats (tablestats in newer versions)

```bash
nodetool tablestats mykeyspace.mytable
# Output includes:
# Table: mykeyspace/mytable
# SSTable count: 12
# Space used (live): 45678901234
# Space used (total): 56789012345
# Space used by snapshots (total): 1234567890
# Memtable cell count: 12345
# Memtable data size: 67890123
# Memtable off heap memory used: 1234567
# Memtable switch count: 456
# Local read count: 12345678
# Local read latency: 0.789 ms
# Local write count: 8765432
# Local write latency: 0.045 ms
# Pending flushes: 0
# Percent repaired: 98.5
# Bloom filter false positives: 1234
# Bloom filter false ratio: 0.00012
# Bloom filter space used: 2345678
# Compacted partition minimum bytes: 123
# Compacted partition maximum bytes: 567890
# Compacted partition mean bytes: 12345
# Average live cells per slice (last five minutes): 45.6
# Maximum live cells per slice (last five minutes): 234
# Average tombstones per slice (last five minutes): 2.3
# Maximum tombstones per slice (last five minutes): 45
# Dropped Mutations: 0
```

### 3.3 JMX Metrics

All Cassandra metrics are exposed via JMX. The key MBean domains are:

```
org.apache.cassandra.metrics:type=ClientRequest,scope=Read,name=Latency
org.apache.cassandra.metrics:type=ClientRequest,scope=Write,name=Latency
org.apache.cassandra.metrics:type=Compaction,name=PendingTasks
org.apache.cassandra.metrics:type=Compaction,name=CompletedTasks
org.apache.cassandra.metrics:type=Storage,name=Load
org.apache.cassandra.metrics:type=Storage,name=Exceptions
org.apache.cassandra.metrics:type=ThreadPools,path=request,scope=ReadStage,name=PendingTasks
org.apache.cassandra.metrics:type=ThreadPools,path=request,scope=MutationStage,name=PendingTasks
org.apache.cassandra.metrics:type=DroppedMessage,scope=MUTATION,name=Dropped
org.apache.cassandra.metrics:type=DroppedMessage,scope=READ,name=Dropped
org.apache.cassandra.metrics:type=Table,keyspace=*,scope=*,name=ReadLatency
org.apache.cassandra.metrics:type=Table,keyspace=*,scope=*,name=WriteLatency
org.apache.cassandra.metrics:type=Table,keyspace=*,scope=*,name=TombstoneScannedHistogram
org.apache.cassandra.metrics:type=Table,keyspace=*,scope=*,name=SSTablesPerReadHistogram
org.apache.cassandra.metrics:type=ColumnFamily,keyspace=*,scope=*,name=LiveSSTableCount
```

**Key JMX metrics with thresholds:**

| JMX MBean | Metric | Warning | Critical |
|-----------|--------|---------|----------|
| `ClientRequest.Read.Latency` | p99 read latency | >10ms (SSD) | >50ms (SSD) |
| `ClientRequest.Write.Latency` | p99 write latency | >5ms (SSD) | >25ms (SSD) |
| `Compaction.PendingTasks` | Pending compactions | >20 | >100 |
| `DroppedMessage.MUTATION.Dropped` | Dropped writes (rate) | >0/sec | >10/sec |
| `DroppedMessage.READ.Dropped` | Dropped reads (rate) | >0/sec | >10/sec |
| `Storage.Exceptions` | Storage errors | >0 | >10 |
| `Table.*.TombstoneScannedHistogram` | Tombstones per read | p99 >1000 | p99 >10000 |
| `Table.*.SSTablesPerReadHistogram` | SSTables per read | p99 >10 | p99 >20 |

### 3.4 Gossip Protocol Health

Cassandra uses the Gossip protocol for node discovery and failure detection. Every node gossips with 1-3 peers per second.

**Gossip states:**

| State | Meaning | Action |
|-------|---------|--------|
| UP | Node is reachable and healthy | Normal |
| DOWN | Node unreachable (phi accrual detector) | Investigate connectivity, check node health |
| JOINING | Node bootstrapping into cluster | Monitor progress, may take hours |
| LEAVING | Node decommissioning | Monitor progress, do not force-stop |
| MOVING | Node reassigning token ranges | Rare in vnode configs |

```bash
# View gossip state
nodetool gossipinfo
# Output per node:
# /10.0.1.51
#   generation:1705225800
#   heartbeat:12345
#   STATUS:NORMAL,-1234567890
#   LOAD:275267890123
#   SCHEMA:abc-123-def
#   DC:dc1
#   RACK:rack1
#   RELEASE_VERSION:4.1.3
#   NATIVE_TRANSPORT_ADDRESS:10.0.1.51
#   NATIVE_TRANSPORT_PORT:9042
#   HOST_ID:abc-123-def-456
#   TOKENS:<hidden>

# Check unreachable nodes
nodetool status | grep "DN"
```

**Phi accrual failure detector**: Cassandra uses phi accrual failure detection (default `phi_convict_threshold: 8`). A phi value >8 means the node is likely down. Monitor with JMX: `org.apache.cassandra.net:type=FailureDetector`.

### 3.5 Repair Monitoring

Repairs ensure data consistency across replicas by comparing Merkle trees.

```bash
# Run repair
nodetool repair mykeyspace

# Check repair status
nodetool repair_admin list
# Or (older versions):
nodetool netstats

# View repair sessions in system tables
cqlsh -e "SELECT * FROM system_distributed.repair_history WHERE keyspace_name = 'mykeyspace' LIMIT 10;"

# View parent repair sessions
cqlsh -e "SELECT * FROM system_distributed.parent_repair_history WHERE keyspace_name = 'mykeyspace' LIMIT 10;"
```

**Repair metrics:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Time since last successful repair | >gc_grace_seconds * 0.5 | >gc_grace_seconds (data loss risk) |
| Repair duration | >4 hours per node | >24 hours (may need sub-range repair) |
| Validation compaction time | >1 hour | >4 hours |
| Anti-entropy sessions failed | >0 | >3 consecutive |

**Default `gc_grace_seconds`**: 864000 (10 days). If repair does not complete within this window, resurrected data (zombie rows) can appear.

### 3.6 Hints Monitoring

Hints are stored when a write's target replica is down, to be replayed when it recovers:

```bash
# Check stored hints
nodetool gethintedhandoff
# Or:
cqlsh -e "SELECT * FROM system.hints LIMIT 10;"

# Hints directory size
du -sh /var/lib/cassandra/data/system/hints-*
```

**Hints metrics (JMX):**
```
org.apache.cassandra.metrics:type=HintedHandOffManager,name=Hints_created-10.0.1.51
org.apache.cassandra.metrics:type=HintedHandOffManager,name=Hints_not_stored-10.0.1.51
org.apache.cassandra.metrics:type=Storage,name=TotalHints
org.apache.cassandra.metrics:type=Storage,name=TotalHintsInProgress
```

| Metric | Warning | Critical |
|--------|---------|----------|
| `TotalHintsInProgress` | >1000 | >10000 |
| `Hints_not_stored` | >0 | >100 (hints dropped = data loss risk) |
| Hints directory size | >1GB | >10GB |
| Hint replay duration | >1 hour | >4 hours |

**`max_hint_window_in_ms`** (default 3 hours): After this window, hints are no longer stored. Writes during extended outages beyond this window require repair.

### 3.7 Streaming Metrics

Streaming occurs during repair, bootstrap, decommission, and rebuild operations:

```bash
# View active streams
nodetool netstats
# Output:
# Mode: NORMAL
# Not sending any streams.
# Read Repair Statistics:
# Attempted: 12345
# Mismatch (Blocking): 234
# Mismatch (Background): 567
# Pool Name                    Active  Pending  Completed
# Large messages               0       0        1234
# Small messages               0       0        5678901
# Gossip messages              0       0        234567
```

**JMX streaming metrics:**
```
org.apache.cassandra.metrics:type=Streaming,scope=*,name=IncomingBytes
org.apache.cassandra.metrics:type=Streaming,scope=*,name=OutgoingBytes
org.apache.cassandra.metrics:type=Streaming,name=TotalIncomingBytes
org.apache.cassandra.metrics:type=Streaming,name=TotalOutgoingBytes
```

### 3.8 GC Monitoring

GC is the primary performance killer in Cassandra. Long GC pauses cause:
- Dropped messages (client timeouts)
- Gossip failures (node marked DOWN)
- Coordinator timeouts

**JVM GC settings (typical for Cassandra 4.x with G1GC):**
```bash
# In jvm11-server.options:
-XX:+UseG1GC
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:MaxGCPauseMillis=300
-XX:+ParallelRefProcEnabled
-XX:+UnlockExperimentalVMOptions
-XX:+UnlockDiagnosticVMOptions
```

**GC log analysis:**
```bash
# Enable GC logging (jvm11-server.options):
-Xlog:gc=info,gc+heap=trace,gc+age=debug,gc+phases=debug:file=/var/log/cassandra/gc.log:time,uptime,level,tags:filecount=10,filesize=10m
```

**GC metrics via JMX:**
```
java.lang:type=GarbageCollector,name=G1 Young Generation
  - CollectionCount  (cumulative young GC count)
  - CollectionTime   (cumulative young GC time in ms)
  - LastGcInfo        (duration, memory before/after)

java.lang:type=GarbageCollector,name=G1 Old Generation
  - CollectionCount  (cumulative old GC count -- should be very low)
  - CollectionTime   (cumulative old GC time in ms)

java.lang:type=Memory
  - HeapMemoryUsage { init, used, committed, max }
  - NonHeapMemoryUsage { init, used, committed, max }
```

| GC Metric | Warning | Critical |
|-----------|---------|----------|
| Young GC pause duration | >200ms avg | >500ms avg |
| Old GC (Full GC) frequency | >1 per hour | >1 per 10 min |
| Old GC pause duration | >1 second | >5 seconds |
| Heap used after GC | >60% of max | >80% of max |
| GC pause % of wall clock | >5% | >10% |

```promql
# GC pause rate
rate(jvm_gc_collection_seconds_sum{gc="G1 Old Generation"}[5m])

# GC events per second
rate(jvm_gc_collection_seconds_count{gc="G1 Young Generation"}[5m])

# Heap utilization after GC
jvm_memory_bytes_used{area="heap"} / jvm_memory_bytes_max{area="heap"}
```

### 3.9 SSTable Metrics

```bash
# SSTable count per table
nodetool tablestats mykeyspace.mytable | grep "SSTable count"

# SSTable details
nodetool cfhistograms mykeyspace mytable
```

**Read amplification** = number of SSTables consulted per read. Measured by `SSTablesPerReadHistogram`:

| SSTables Per Read (p99) | Status | Action |
|--------------------------|--------|--------|
| 1-3 | Healthy | Normal for STCS/LCS |
| 4-10 | Elevated | Review compaction strategy |
| 11-20 | High | Switch to LCS or tune STCS |
| >20 | Critical | Compaction severely behind or wrong strategy |

**Compaction strategies:**
- **STCS** (SizeTieredCompactionStrategy): Default, good for write-heavy. Can cause read amplification.
- **LCS** (LeveledCompactionStrategy): Better read performance, higher write amplification. Good for read-heavy.
- **TWCS** (TimeWindowCompactionStrategy): Best for time-series data with TTL.

### 3.10 Anti-Patterns to Monitor

#### Large Partitions
```bash
# Detect large partitions
nodetool tablehistograms mykeyspace mytable | grep "99%"
# Partition size p99 > 100MB = large partition anti-pattern

# In system log:
# WARN  Compacting large partition mykeyspace/mytable:key (234567890 bytes)
```

#### Tombstone Storms
```bash
# Tombstones per read (JMX)
# org.apache.cassandra.metrics:type=Table,keyspace=mykeyspace,scope=mytable,name=TombstoneScannedHistogram
# p99 > 1000 = tombstone storm

# Default tombstone_warn_threshold: 1000
# Default tombstone_failure_threshold: 100000
```

**Signs of tombstone problems:**
- Slow range queries that scan many tombstones before finding live data
- `ReadTimeoutException` with tombstone warnings in logs
- High GC pressure (tombstones consume heap during reads)

#### Read Amplification
- Monitor `SSTablesPerReadHistogram` as above
- High read amplification means compaction is behind or wrong strategy

### 3.11 Prometheus Exporters for Cassandra

**Option 1: Instaclustr Cassandra Exporter (JMX agent)**
```bash
# Add to cassandra-env.sh:
JVM_OPTS="$JVM_OPTS -javaagent:/opt/cassandra-exporter-agent.jar=--listen=:9500"
```

**Option 2: DataStax MCAC (Metrics Collector for Apache Cassandra)**
```yaml
# metrics-collector.yaml
global:
  collectd:
    enabled: true
  prometheus:
    enabled: true
    port: 9103
```

**Option 3: OTel JMX Receiver**
```yaml
receivers:
  jmx:
    endpoint: service:jmx:rmi:///jndi/rmi://cassandra-node:7199/jmxrmi
    target_system: cassandra
    collection_interval: 60s
    resource_attributes:
      service.name: cassandra-cluster
```

### 3.12 Cassandra Alert Summary

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| Node Down | Any node in `DN` state >5 min | Critical |
| High Read Latency | p99 read latency >10ms (SSD) | Warning |
| High Write Latency | p99 write latency >5ms (SSD) | Warning |
| Dropped Mutations | `rate(dropped_mutations) > 0` | Critical |
| Dropped Reads | `rate(dropped_reads) > 0` | Critical |
| Pending Compactions High | `pending_compactions > 50` | Warning |
| Pending Compactions Critical | `pending_compactions > 100` | Critical |
| Tombstone Storm | `tombstones_scanned p99 > 1000` | Warning |
| Read Amplification | `sstables_per_read p99 > 10` | Warning |
| Heap Pressure | `heap_used / heap_max > 0.80` | Warning |
| Full GC Frequency | `old_gc > 1 per 10 min` | Critical |
| GC Pause Duration | `gc_pause > 500ms avg` | Warning |
| Hints Not Stored | `hints_not_stored > 0` | Critical |
| Repair Overdue | `time_since_repair > gc_grace_seconds * 0.8` | Warning |
| Large Partition | `partition_size p99 > 100MB` | Warning |
| Thread Pool Blocked | Any `blocked > 0` in request pools | Critical |

---

## 4. Elasticsearch and OpenSearch Observability

### 4.1 Architecture Context

Elasticsearch (and its fork, OpenSearch) is a distributed search and analytics engine built on Apache Lucene. Data is organized into indices, each split into primary and replica shards distributed across nodes. The JVM-based architecture means heap management, GC tuning, and circuit breakers are critical observability dimensions.

**Key observability surfaces:**
- Cluster Health API (`_cluster/health`)
- Node Stats API (`_nodes/stats`)
- Index Stats API (`_stats`)
- Cat APIs (`_cat/*`) for human-readable quick diagnosis
- Slow logs (search and index)
- Task Management API (`_tasks`)
- Circuit breaker monitoring
- ILM/ISM policy monitoring
- Snapshot/restore monitoring
- OpenTelemetry Elasticsearch receiver

### 4.2 Cluster Health

```bash
# Cluster health
GET _cluster/health
# Response:
{
  "cluster_name": "production",
  "status": "green",                     # green/yellow/red
  "timed_out": false,
  "number_of_nodes": 9,
  "number_of_data_nodes": 6,
  "active_primary_shards": 450,
  "active_shards": 900,                  # Primary + replica
  "relocating_shards": 0,
  "initializing_shards": 0,
  "unassigned_shards": 0,                # Should be 0 for green
  "delayed_unassigned_shards": 0,
  "number_of_pending_tasks": 0,
  "number_of_in_flight_fetch": 0,
  "task_max_waiting_in_queue_millis": 0,
  "active_shards_percent_as_number": 100.0
}
```

**Cluster status meaning:**

| Status | Meaning | Action |
|--------|---------|--------|
| `green` | All primary and replica shards assigned | Healthy |
| `yellow` | All primaries assigned, some replicas unassigned | Investigate -- data is available but not fully replicated |
| `red` | Some primary shards unassigned | **CRITICAL** -- data loss/unavailability possible |

**Unassigned shard diagnosis:**
```bash
# Why are shards unassigned?
GET _cluster/allocation/explain
# Returns reason: ALLOCATION_FAILED, NODE_LEFT, REPLICA_ADDED, etc.

# Per-index health
GET _cluster/health?level=indices

# Per-shard health
GET _cluster/health?level=shards
```

```promql
# Cluster status as number (green=0, yellow=1, red=2)
elasticsearch_cluster_health_status{color="red"} == 1

# Unassigned shards
elasticsearch_cluster_health_unassigned_shards

# Relocating shards
elasticsearch_cluster_health_relocating_shards
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Cluster status | yellow | red |
| Unassigned shards | >0 | >0 for primaries |
| Relocating shards | >10 sustained | >50 sustained (shard storm) |
| Pending tasks | >10 | >50 |
| Initializing shards | >0 for >10 min | >0 for >30 min |

### 4.3 Node Stats

```bash
GET _nodes/stats
# Or for specific node:
GET _nodes/node-1/stats
# Or specific stat categories:
GET _nodes/stats/jvm,os,process,thread_pool,indices
```

#### 4.3.1 JVM Heap

```json
{
  "jvm": {
    "mem": {
      "heap_used_in_bytes": 4294967296,
      "heap_used_percent": 52,
      "heap_max_in_bytes": 8589934592,
      "heap_committed_in_bytes": 8589934592,
      "non_heap_used_in_bytes": 234567890,
      "non_heap_committed_in_bytes": 345678901
    },
    "gc": {
      "collectors": {
        "young": {
          "collection_count": 12345,
          "collection_time_in_millis": 67890
        },
        "old": {
          "collection_count": 23,
          "collection_time_in_millis": 4567
        }
      }
    },
    "buffer_pools": {
      "mapped": { "count": 567, "used_in_bytes": 1234567890, "total_capacity_in_bytes": 1234567890 },
      "direct": { "count": 89, "used_in_bytes": 234567890, "total_capacity_in_bytes": 345678901 }
    }
  }
}
```

**Heap recommendations:**
- Set `Xms` = `Xmx` (no dynamic resizing)
- Max 50% of physical RAM, never more than ~30GB (compressed oops limit is 32GB; stay under)
- For Elasticsearch 7.x+: Use G1GC (default); for 6.x: CMS

| Metric | Warning | Critical |
|--------|---------|----------|
| `heap_used_percent` | >75% | >85% |
| Old GC frequency | >1 per 5 min | >1 per minute |
| Old GC duration | >1 second avg | >5 seconds avg |
| Young GC duration | >100ms avg | >500ms avg |

```promql
# Heap pressure
elasticsearch_jvm_memory_used_bytes{area="heap"} / elasticsearch_jvm_memory_max_bytes{area="heap"}

# GC rate
rate(elasticsearch_jvm_gc_collection_seconds_count{gc="old"}[5m])

# GC time percentage
rate(elasticsearch_jvm_gc_collection_seconds_sum{gc="old"}[5m])
```

#### 4.3.2 Thread Pools

```json
{
  "thread_pool": {
    "search": {
      "threads": 13,
      "queue": 0,          # Queued search requests
      "active": 5,
      "rejected": 0,       # Rejected requests (queue full)
      "largest": 13,
      "completed": 12345678
    },
    "write": {
      "threads": 8,
      "queue": 0,
      "active": 2,
      "rejected": 0,
      "largest": 8,
      "completed": 8765432
    },
    "search_throttled": { ... },
    "get": { ... },
    "analyze": { ... },
    "management": { ... },
    "flush": { ... },
    "refresh": { ... },
    "force_merge": { ... },
    "snapshot": { ... }
  }
}
```

**Thread pool sizing defaults:**
- `search`: `int((# of allocated processors * 3) / 2) + 1`, queue size 1000
- `write` (index/bulk/update/delete): `# of allocated processors`, queue size 10000
- `get`: `# of allocated processors`, queue size 1000

| Thread Pool | Queue Warning | Queue Critical | Rejected |
|-------------|---------------|----------------|----------|
| `search` | >100 | >500 | Any >0 = clients getting 429s |
| `write` | >200 | >5000 | Any >0 = indexing failures |
| `get` | >50 | >500 | Any >0 |
| `flush` | >5 | >10 | Rarely an issue |

```promql
# Search queue depth
elasticsearch_thread_pool_queue_count{name="search"}

# Write rejections rate
rate(elasticsearch_thread_pool_rejected_count{name="write"}[5m])

# Search rejections rate
rate(elasticsearch_thread_pool_rejected_count{name="search"}[5m])
```

#### 4.3.3 Circuit Breakers

Circuit breakers prevent OOM by limiting memory usage for specific operations:

```bash
GET _nodes/stats/breaker
```

```json
{
  "breakers": {
    "fielddata": {
      "limit_size_in_bytes": 4294967296,    # 40% of heap by default
      "estimated_size_in_bytes": 234567890,
      "overhead": 1.03,
      "tripped": 0                           # Times this breaker fired
    },
    "request": {
      "limit_size_in_bytes": 6442450944,    # 60% of heap
      "estimated_size_in_bytes": 123456789,
      "tripped": 0
    },
    "parent": {
      "limit_size_in_bytes": 8053063680,    # 95% of heap (real memory)
      "estimated_size_in_bytes": 2345678901,
      "tripped": 5                           # 5 trips = queries repeatedly too large
    },
    "in_flight_requests": {
      "limit_size_in_bytes": 8589934592,    # 100% of heap
      "estimated_size_in_bytes": 12345678,
      "tripped": 0
    }
  }
}
```

| Breaker | Alert Condition |
|---------|-----------------|
| `fielddata.tripped` | >0 (fielddata on text fields, use `.keyword` instead) |
| `request.tripped` | >0 per hour (aggregations too large) |
| `parent.tripped` | >0 (overall memory pressure) |
| `in_flight_requests.tripped` | >0 (too many concurrent requests) |

### 4.4 Index Stats

```bash
# All indices
GET _stats

# Specific index
GET myindex/_stats

# Specific metrics
GET _stats/indexing,search,merge
```

**Key indexing metrics:**
```json
{
  "indexing": {
    "index_total": 12345678,           # Cumulative indexed docs
    "index_time_in_millis": 4567890,   # Cumulative indexing time
    "index_current": 5,                # Currently indexing
    "index_failed": 0,
    "delete_total": 234567,
    "noop_update_total": 1234
  },
  "search": {
    "query_total": 8765432,            # Cumulative queries
    "query_time_in_millis": 12345678,  # Cumulative query time
    "query_current": 3,
    "fetch_total": 8765432,            # Cumulative fetches
    "fetch_time_in_millis": 2345678,
    "fetch_current": 0,
    "scroll_total": 12345,
    "scroll_time_in_millis": 567890,
    "scroll_current": 2,               # Open scroll contexts
    "suggest_total": 0
  },
  "merges": {
    "current": 2,
    "current_docs": 12345678,
    "current_size_in_bytes": 4567890123,
    "total": 5678,
    "total_time_in_millis": 23456789,
    "total_docs": 1234567890,
    "total_size_in_bytes": 456789012345
  },
  "refresh": {
    "total": 23456,
    "total_time_in_millis": 3456789
  },
  "fielddata": {
    "memory_size_in_bytes": 234567890,
    "evictions": 12                     # Should be 0 if properly sized
  }
}
```

**Derived metrics:**
```promql
# Indexing rate (docs/sec)
rate(elasticsearch_indices_indexing_index_total[5m])

# Average indexing latency per doc
rate(elasticsearch_indices_indexing_index_time_seconds_total[5m]) /
  rate(elasticsearch_indices_indexing_index_total[5m])

# Search rate (queries/sec)
rate(elasticsearch_indices_search_query_total[5m])

# Average search latency
rate(elasticsearch_indices_search_query_time_seconds_total[5m]) /
  rate(elasticsearch_indices_search_query_total[5m])

# Fetch latency (after query phase)
rate(elasticsearch_indices_search_fetch_time_seconds_total[5m]) /
  rate(elasticsearch_indices_search_fetch_total[5m])

# Fielddata evictions (should be 0)
rate(elasticsearch_indices_fielddata_evictions_total[5m])

# Merge rate
rate(elasticsearch_indices_merges_total_size_in_bytes_total[5m])
```

### 4.5 Shard-Level Metrics

```bash
# Shard sizes and distribution
GET _cat/shards?v&s=store:desc
# Output:
# index          shard prirep state   docs    store   ip         node
# logs-2025.01   0     p      STARTED 12345678 23.4gb 10.0.1.51  data-1
# logs-2025.01   0     r      STARTED 12345678 23.4gb 10.0.1.52  data-2
# logs-2025.01   1     p      STARTED 11234567 21.2gb 10.0.1.53  data-3

# Shard allocation
GET _cat/allocation?v
# Output:
# shards disk.indices disk.used disk.avail disk.total disk.percent host       ip         node
# 150    456.7gb      512.3gb   487.7gb    1000.0gb   51           10.0.1.51  10.0.1.51  data-1
# 148    445.2gb      501.8gb   498.2gb    1000.0gb   50           10.0.1.52  10.0.1.52  data-2
```

**Shard sizing guidelines:**
- Target shard size: 10-50 GB per shard
- Max shards per node: ~600-1000 (depends on heap; ~20 shards per GB of heap)
- Avoid many small shards (overhead per shard: ~10MB heap for segment metadata)

### 4.6 Search Performance

```bash
# Search stats per node
GET _nodes/stats/indices/search

# Slow search queries
GET _cat/thread_pool/search?v&h=node_name,active,queue,rejected,completed
```

**Search latency breakdown:**
- **Query phase**: Find matching doc IDs (distributed across shards)
- **Fetch phase**: Retrieve actual documents by ID from the relevant shards
- High query time: Expensive queries, too many shards, insufficient caching
- High fetch time: Large documents, many fields, stored fields access

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Avg search latency | <50ms | 50-200ms | >200ms |
| p99 search latency | <500ms | 500ms-2s | >2s |
| Search queue | <10 | 10-100 | >100 |
| Search rejections | 0 | >0/min | >10/min |
| Open scroll contexts | <100 | 100-500 | >500 (memory leak risk) |

### 4.7 Slow Log Configuration

Elasticsearch provides separate slow logs for search and indexing:

```json
// Set per-index slow log thresholds
PUT myindex/_settings
{
  "index.search.slowlog.threshold.query.warn": "10s",
  "index.search.slowlog.threshold.query.info": "5s",
  "index.search.slowlog.threshold.query.debug": "2s",
  "index.search.slowlog.threshold.query.trace": "500ms",

  "index.search.slowlog.threshold.fetch.warn": "1s",
  "index.search.slowlog.threshold.fetch.info": "800ms",
  "index.search.slowlog.threshold.fetch.debug": "500ms",
  "index.search.slowlog.threshold.fetch.trace": "200ms",

  "index.indexing.slowlog.threshold.index.warn": "10s",
  "index.indexing.slowlog.threshold.index.info": "5s",
  "index.indexing.slowlog.threshold.index.debug": "2s",
  "index.indexing.slowlog.threshold.index.trace": "500ms",

  "index.search.slowlog.level": "info",
  "index.indexing.slowlog.level": "info",
  "index.indexing.slowlog.source": "1000"   // Characters of source to log
}
```

**Slow log output** (in `<cluster>_index_search_slowlog.json` or `.log`):
```json
{
  "type": "index_search_slowlog",
  "timestamp": "2025-01-15T10:30:00,000+00:00",
  "level": "WARN",
  "component": "i.s.s.query",
  "cluster.name": "production",
  "node.name": "data-1",
  "message": "[myindex][0]",
  "took": "12.3s",
  "took_millis": "12345",
  "total_hits": "45678",
  "stats": "[]",
  "search_type": "QUERY_THEN_FETCH",
  "total_shards": "5",
  "source": "{\"query\":{\"bool\":{...}},\"size\":100}"
}
```

### 4.8 Index Lifecycle Management (ILM/ISM) Monitoring

**Elasticsearch ILM:**
```bash
# Check ILM policy status for an index
GET myindex/_ilm/explain
# Response:
{
  "indices": {
    "myindex": {
      "index": "myindex",
      "managed": true,
      "policy": "my-lifecycle-policy",
      "lifecycle_date_millis": 1705225800000,
      "age": "10d",
      "phase": "warm",
      "phase_time_millis": 1705312200000,
      "action": "complete",
      "action_time_millis": 1705312200000,
      "step": "complete",
      "step_time_millis": 1705312200000
    }
  }
}

# Check all ILM errors
GET _ilm/status
GET */_ilm/explain?only_errors=true
```

**OpenSearch ISM:**
```bash
# ISM policy status
GET _plugins/_ism/explain/myindex

# ISM errors
GET _plugins/_ism/explain/myindex?show_policy=true
```

**ILM/ISM metrics to monitor:**
| Metric | Warning | Critical |
|--------|---------|----------|
| ILM errors | >0 | >0 sustained for >1 hour |
| Phase transition time | >2x expected | >10x expected |
| Indices stuck in phase | >1 hour in transition | >24 hours |
| Rollover size exceeded | >2x target size | >5x target size |

### 4.9 Cross-Cluster Search/Replication Monitoring

```bash
# Remote cluster connections
GET _remote/info
# Response:
{
  "cluster_two": {
    "connected": true,
    "mode": "sniff",
    "seeds": ["10.0.2.51:9300"],
    "num_nodes_connected": 3,
    "max_connections_per_cluster": 3,
    "initial_connect_timeout": "30s",
    "skip_unavailable": false
  }
}

# Cross-cluster replication stats (Elasticsearch only)
GET _ccr/stats
GET _ccr/auto_follow/stats
```

### 4.10 Snapshot/Restore Monitoring

```bash
# List repositories
GET _snapshot

# List snapshots in a repository
GET _snapshot/my_backup/_all

# Snapshot status (while running)
GET _snapshot/my_backup/_current
GET _snapshot/_status

# Specific snapshot details
GET _snapshot/my_backup/snapshot_2025_01_15
# Response includes:
{
  "state": "SUCCESS",     # IN_PROGRESS, SUCCESS, FAILED, PARTIAL
  "start_time_in_millis": 1705312200000,
  "end_time_in_millis": 1705312800000,
  "duration_in_millis": 600000,
  "failures": [],
  "shards": { "total": 450, "failed": 0, "successful": 450 }
}
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Snapshot state | PARTIAL | FAILED |
| Snapshot duration | >2x baseline | >5x baseline |
| Time since last snapshot | >2x schedule | >24 hours |
| Snapshot shard failures | >0 | >10% of shards |

### 4.11 _cat API Endpoints for Quick Diagnosis

```bash
# Most useful _cat endpoints:
GET _cat/health?v                    # Cluster health summary
GET _cat/nodes?v&h=name,heap.percent,ram.percent,cpu,load_1m,disk.used_percent,node.role
GET _cat/indices?v&s=store.size:desc # Indices sorted by size
GET _cat/shards?v&s=store:desc       # Shards sorted by size
GET _cat/allocation?v                # Disk allocation per node
GET _cat/thread_pool?v&h=node_name,name,active,queue,rejected&s=rejected:desc
GET _cat/pending_tasks?v             # Pending cluster tasks
GET _cat/recovery?v&active_only=true # Active shard recoveries
GET _cat/segments?v&s=size:desc      # Segment details
GET _cat/fielddata?v&s=size:desc     # Fielddata usage per field
GET _cat/plugins?v                   # Installed plugins
GET _cat/tasks?v&detailed            # Running tasks
```

### 4.12 Elasticsearch Alert Summary

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| Cluster Red | `status == red` | Critical |
| Cluster Yellow | `status == yellow` >10 min | Warning |
| Unassigned Shards | `unassigned_shards > 0` >5 min | Warning |
| High Heap Usage | `heap_used_percent > 85%` | Critical |
| Old GC Pressure | `old_gc > 1/min` | Warning |
| Search Rejections | `rate(search_rejected) > 0` | Warning |
| Write Rejections | `rate(write_rejected) > 0` | Warning |
| Search Latency High | `avg_search_latency > 200ms` | Warning |
| Fielddata Evictions | `rate(fielddata_evictions) > 0` | Warning |
| Circuit Breaker Trips | `parent_tripped > 0` | Warning |
| Disk Watermark High | `disk_used > 85%` (high watermark) | Warning |
| Disk Watermark Flood | `disk_used > 95%` (flood stage) | Critical |
| ILM Errors | `ilm_errors > 0` | Warning |
| Snapshot Failed | `snapshot_state == FAILED` | Critical |
| Too Many Shards | `shards_per_node > 800` | Warning |
| Open Scroll Contexts | `scroll_current > 500` | Warning |

---

## 5. DynamoDB Observability

### 5.1 Architecture Context

Amazon DynamoDB is a fully managed, serverless, key-value and document database. Unlike self-hosted databases, DynamoDB observability is entirely through AWS CloudWatch metrics and DynamoDB-specific APIs. There is no server to SSH into, no JMX to query, and no `EXPLAIN` plan -- the observability model is fundamentally different from self-hosted databases.

**Key observability surfaces:**
- CloudWatch metrics (automatic, no agent needed)
- CloudWatch Contributor Insights (hot partition detection)
- DynamoDB Streams metrics
- CloudTrail (API-level audit logging)
- Auto-scaling activity logs
- AWS X-Ray integration (request-level tracing)
- OpenTelemetry: `awscloudwatch/dynamodb` receiver fragment

### 5.2 CloudWatch Metrics

DynamoDB emits metrics to CloudWatch automatically at no additional cost (basic metrics at 5-minute granularity; 1-minute with detailed monitoring).

#### 5.2.1 Capacity Metrics

```
ConsumedReadCapacityUnits     # RCU consumed (Sum per 5-min period)
ConsumedWriteCapacityUnits    # WCU consumed (Sum per 5-min period)
ProvisionedReadCapacityUnits  # Provisioned RCU (if not on-demand)
ProvisionedWriteCapacityUnits # Provisioned WCU (if not on-demand)
AccountProvisionedReadCapacityUtilization   # % of account-level RCU limit
AccountProvisionedWriteCapacityUtilization  # % of account-level WCU limit
AccountMaxReads               # Account read limit
AccountMaxWrites              # Account write limit
AccountMaxTableLevelReads     # Per-table read limit
AccountMaxTableLevelWrites    # Per-table write limit
```

**Capacity unit calculations:**
- **1 RCU** = 1 strongly consistent read of up to 4 KB, OR 2 eventually consistent reads of up to 4 KB
- **1 WCU** = 1 write of up to 1 KB
- **Transactional reads**: 2 RCU per 4 KB item
- **Transactional writes**: 2 WCU per 1 KB item

**Consumption formulas:**
```
# Consumed capacity per second (from 5-minute Sum)
consumed_rcu_per_second = ConsumedReadCapacityUnits_Sum / 300

# Utilization percentage (provisioned mode)
read_utilization = consumed_rcu_per_second / ProvisionedReadCapacityUnits * 100
write_utilization = consumed_wcu_per_second / ProvisionedWriteCapacityUnits * 100
```

```promql
# CloudWatch metrics via OTel receiver (metric names may vary by receiver)
# Consumed capacity rate
aws_dynamodb_consumed_read_capacity_units_sum / 300
aws_dynamodb_consumed_write_capacity_units_sum / 300

# Utilization
(aws_dynamodb_consumed_read_capacity_units_sum / 300) /
  aws_dynamodb_provisioned_read_capacity_units_average
```

#### 5.2.2 Throttling Metrics

```
ThrottledRequests           # Total requests throttled (table + GSI)
ReadThrottleEvents          # Read requests throttled
WriteThrottleEvents         # Write requests throttled
```

**Throttling means the request exceeded the provisioned capacity or burst capacity.** On-demand tables can also throttle if they exceed 2x the previous peak within 30 minutes.

| Metric | Warning | Critical |
|--------|---------|----------|
| `ThrottledRequests` (Sum/5min) | >0 | >100 per 5 min |
| `ReadThrottleEvents` rate | >0 | >10/sec sustained |
| `WriteThrottleEvents` rate | >0 | >10/sec sustained |
| Throttle ratio | >1% of requests | >5% of requests |

#### 5.2.3 Error Metrics

```
SystemErrors    # HTTP 500 errors from DynamoDB service (rare, AWS issue)
UserErrors      # HTTP 400 errors (validation, conditional check failures)
ConditionalCheckFailedRequests  # Conditional writes that failed the condition
TransactionConflict             # Transaction conflicts (OCC failures)
```

| Metric | Warning | Critical |
|--------|---------|----------|
| `SystemErrors` | >0 | >0 sustained (open AWS support case) |
| `UserErrors` rate | Baseline + 2x | Baseline + 5x |
| `ConditionalCheckFailedRequests` | Context-dependent | Sudden spike >10x |
| `TransactionConflict` | >1% of transactions | >5% of transactions |

#### 5.2.4 Latency Metrics

```
SuccessfulRequestLatency    # End-to-end latency for successful requests
# Dimensions: TableName, Operation (GetItem, PutItem, Query, Scan, etc.)
# Statistics: Average, Minimum, Maximum, SampleCount, p50, p99
```

**Typical SuccessfulRequestLatency values:**

| Operation | Good (p50) | Warning (p99) | Critical (p99) |
|-----------|------------|---------------|-----------------|
| GetItem | <5ms | >10ms | >25ms |
| PutItem | <10ms | >20ms | >50ms |
| Query (small) | <10ms | >25ms | >100ms |
| Scan | Varies with size | >1s | >5s |
| BatchGetItem | <20ms | >50ms | >200ms |
| BatchWriteItem | <25ms | >50ms | >200ms |
| TransactWriteItems | <25ms | >100ms | >500ms |

**Note**: DynamoDB latency is measured from the DynamoDB service, not including network transit from the client. Client-observed latency will be higher (add 1-5ms for same-region, 50-200ms for cross-region).

#### 5.2.5 Item and Size Metrics

```
ReturnedItemCount      # Items returned by Query/Scan operations
ReturnedBytes          # Bytes returned by operations
ItemCollectionSize     # Size of local secondary index item collections
TableSize              # Total table size (emitted every ~6 hours)
ItemCount              # Total item count (emitted every ~6 hours)
```

### 5.3 Contributor Insights

DynamoDB Contributor Insights identifies the most frequently accessed and throttled items, helping detect hot partitions:

```bash
# Enable Contributor Insights via CLI
aws dynamodb update-contributor-insights \
  --table-name MyTable \
  --contributor-insights-action ENABLE

# View top contributors (via CloudWatch)
aws cloudwatch get-insight-rule-report \
  --rule-name "DynamoDBContributorInsights-PKC-MyTable" \
  --start-time "2025-01-15T00:00:00Z" \
  --end-time "2025-01-15T23:59:59Z" \
  --period 3600 \
  --max-contributor-count 10
```

**Available Contributor Insights rules:**
- `DynamoDBContributorInsights-PKC-<table>` -- Most accessed partition keys (consumed capacity)
- `DynamoDBContributorInsights-PKT-<table>` -- Most throttled partition keys
- `DynamoDBContributorInsights-SKC-<table>` -- Most accessed sort keys
- `DynamoDBContributorInsights-SKT-<table>` -- Most throttled sort keys

**Hot partition indicators:**
- Single partition key consuming >3000 RCU or >1000 WCU (partition throughput limit)
- Top 1% of keys accounting for >50% of total throughput
- Throttling concentrated on specific partition keys

**Cost**: $0.02 per 100,000 DynamoDB events analyzed (approximately $4.32/month per table at 1000 ops/sec).

### 5.4 On-Demand vs Provisioned Capacity Monitoring

| Aspect | Provisioned | On-Demand |
|--------|-------------|-----------|
| Capacity metric | `ProvisionedReadCapacityUnits` available | Not applicable |
| Throttle trigger | Exceeds provisioned + burst credits | Exceeds 2x previous peak (within 30 min) |
| Key monitoring metric | Utilization % (`consumed / provisioned`) | Consumed capacity (absolute) |
| Auto-scaling | Target tracking policy | Not applicable (automatic) |
| Cost optimization | Monitor utilization, right-size | Monitor total consumed for cost control |
| Burst credits | 300 seconds of unused capacity | N/A (automatic scaling) |

**Provisioned mode monitoring:**
```promql
# Capacity utilization (target: 70% for auto-scaling headroom)
(aws_dynamodb_consumed_read_capacity_units_sum / 300) /
  aws_dynamodb_provisioned_read_capacity_units_average * 100
```

**On-demand mode monitoring:**
```promql
# Track consumed capacity trends (for cost)
aws_dynamodb_consumed_read_capacity_units_sum / 300
aws_dynamodb_consumed_write_capacity_units_sum / 300
```

### 5.5 Auto-Scaling Monitoring

DynamoDB auto-scaling uses Application Auto Scaling with target tracking:

```bash
# View auto-scaling settings
aws application-autoscaling describe-scalable-targets \
  --service-namespace dynamodb \
  --resource-id "table/MyTable"

# View scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace dynamodb \
  --resource-id "table/MyTable"

# View scaling activity
aws application-autoscaling describe-scaling-activities \
  --service-namespace dynamodb \
  --resource-id "table/MyTable"
```

**Auto-scaling metrics to monitor:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Target utilization deviation | >20% over target | >40% over target |
| Scaling cooldown violations | Frequent scale-up during cooldown | Throttling during cooldown |
| Time to scale | >5 min to react | >15 min to react |
| Scale-up frequency | >10 per hour | >30 per hour (thrashing) |

### 5.6 GSI (Global Secondary Index) Throttling

GSIs have their own provisioned capacity, independent of the base table. GSI throttling propagates back to the base table -- a throttled GSI will throttle writes to the base table.

```
# GSI-specific CloudWatch metrics (dimension: GlobalSecondaryIndexName)
ConsumedReadCapacityUnits     # GSI read consumption
ConsumedWriteCapacityUnits    # GSI write consumption
ReadThrottleEvents            # GSI read throttling
WriteThrottleEvents           # GSI write throttling
OnlineIndexConsumedWriteCapacity   # During index backfill
OnlineIndexPercentageProgress      # Index creation progress
```

**GSI write amplification**: Every write to the base table that affects GSI key attributes generates a write to the GSI. A table with 5 GSIs can generate up to 5x write amplification.

**GSI monitoring rules:**
- GSI write capacity should be >= base table write capacity (to avoid back-pressure)
- Monitor `WriteThrottleEvents` on each GSI separately
- During index backfill (`OnlineIndexPercentageProgress`), monitor for base table throttling

### 5.7 DynamoDB Streams Monitoring

```
# Streams metrics (dimension: TableName, DelegatedOperation)
GetRecords.IteratorAge       # How far behind the stream reader is (milliseconds)
GetRecords.Latency           # Latency of GetRecords calls
GetRecords.Success           # Successful GetRecords calls
ReturnedRecordsCount         # Records returned per GetRecords call
```

| Metric | Warning | Critical |
|--------|---------|----------|
| `IteratorAge` | >1 hour (3,600,000 ms) | >12 hours |
| `IteratorAge` | Approaching 24h (record expiry) | >23 hours (data loss imminent) |
| `GetRecords.Latency` | >100ms average | >500ms average |
| `ReturnedRecordsCount` | 0 sustained when expecting data | N/A |

**DynamoDB Streams records expire after 24 hours.** If `IteratorAge` approaches 24 hours, the consumer is about to lose data.

### 5.8 TTL Deletion Monitoring

```
TimeToLiveDeletedItemCount    # Items deleted by TTL per 5-minute period
```

TTL deletions are performed by a background process and:
- Do NOT consume write capacity (free)
- Are eventually consistent (may take up to 48 hours after expiry)
- Generate DynamoDB Streams records (type `REMOVE`)
- Are not counted against provisioned capacity

**Monitor TTL effectiveness:**
```promql
# TTL deletion rate
aws_dynamodb_time_to_live_deleted_item_count_sum / 300

# Compare with expected expiry rate
# If TTL deletions << expected, items may not have TTL attribute set correctly
```

### 5.9 Capacity Planning Formulas

**Read capacity estimation:**
```
# Strongly consistent reads per second
required_rcu = (reads_per_second * ceil(avg_item_size_kb / 4))

# Eventually consistent reads per second
required_rcu = ceil(reads_per_second * ceil(avg_item_size_kb / 4) / 2)

# Transactional reads per second
required_rcu = (reads_per_second * ceil(avg_item_size_kb / 4) * 2)
```

**Write capacity estimation:**
```
# Standard writes per second
required_wcu = (writes_per_second * ceil(avg_item_size_kb / 1))

# Transactional writes per second
required_wcu = (writes_per_second * ceil(avg_item_size_kb / 1) * 2)

# With GSI write amplification
total_wcu = base_wcu + sum(gsi_wcu for each GSI affected by the write)
```

**Cost comparison (us-east-1, 2025 pricing):**
```
# Provisioned mode
$0.00065 per WCU per hour = $0.4745 per WCU per month
$0.00013 per RCU per hour = $0.0949 per RCU per month

# On-demand mode
$1.25 per million write request units
$0.25 per million read request units

# Break-even point (approximately):
# If utilization > ~18% consistently, provisioned is cheaper
# If utilization < ~18% or very spiky, on-demand is cheaper
```

### 5.10 DynamoDB Alert Summary

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| Read Throttling | `ReadThrottleEvents > 0` | Warning |
| Write Throttling | `WriteThrottleEvents > 0` | Warning |
| Sustained Throttling | `ThrottledRequests > 100` per 5 min | Critical |
| System Errors | `SystemErrors > 0` | Critical |
| High Read Latency | `SuccessfulRequestLatency p99 > 25ms` (GetItem) | Warning |
| High Write Latency | `SuccessfulRequestLatency p99 > 50ms` (PutItem) | Warning |
| GSI Back-Pressure | GSI `WriteThrottleEvents > 0` | Warning |
| Stream Iterator Age | `GetRecords.IteratorAge > 3600000ms` (1h) | Warning |
| Stream Data Loss Risk | `GetRecords.IteratorAge > 82800000ms` (23h) | Critical |
| Capacity Utilization High | `consumed / provisioned > 80%` | Warning |
| Auto-Scale Thrashing | `>10 scaling events per hour` | Warning |
| Hot Partition | Contributor Insights: single key >50% of traffic | Warning |
| Table Size Growth | >10% growth per week (unexpected) | Warning |
| Transaction Conflicts High | `TransactionConflict > 5%` of txns | Warning |

---

## 6. Time-Series Database Observability: InfluxDB and TimescaleDB

### 6.1 InfluxDB Observability

#### 6.1.1 Architecture Context

InfluxDB is a purpose-built time-series database. InfluxDB OSS 2.x uses a single-node architecture with a TSM (Time-Structured Merge Tree) storage engine. InfluxDB 3.x (and InfluxDB Cloud) uses Apache Arrow, DataFusion, and Parquet for columnar storage. InfluxDB Enterprise (1.x) supports clustering. The primary observability challenges are **write throughput**, **query performance**, **series cardinality**, and **storage compaction**.

**Key observability surfaces:**
- `/metrics` Prometheus endpoint (built-in)
- `/health` and `/ready` endpoints
- `_internal` database (InfluxDB 1.x)
- InfluxDB API `/api/v2/query` for self-monitoring
- Telegraf + InfluxDB internal metrics plugin
- OpenTelemetry InfluxDB receiver (line protocol ingestion)

#### 6.1.2 Write Throughput Metrics

```
# InfluxDB 2.x Prometheus metrics
influxdb_write_req_total                    # Total write requests
influxdb_write_req_duration_seconds         # Write request latency histogram
influxdb_write_req_bytes_total              # Bytes written
influxdb_write_points_total                 # Points written (data points, not requests)
influxdb_write_points_err_total             # Failed point writes
influxdb_write_points_dropped_total         # Points dropped (e.g., past retention)

# InfluxDB 1.x _internal database
SELECT mean("writeReq") FROM "httpd" WHERE time > now() - 1h GROUP BY time(1m)
SELECT mean("pointsWrittenOK") FROM "write" WHERE time > now() - 1h GROUP BY time(1m)
```

**Write performance benchmarks:**

| Instance Size | Points/sec (typical) | Warning | Critical |
|--------------|----------------------|---------|----------|
| Small (2 CPU, 8GB) | 50K-100K | >80% sustained throughput | Write errors >0 |
| Medium (8 CPU, 32GB) | 200K-500K | >80% sustained throughput | Write errors >0 |
| Large (16 CPU, 64GB) | 500K-1M+ | >80% sustained throughput | Write errors >0 |

```promql
# Write rate (points per second)
rate(influxdb_write_points_total[5m])

# Write error rate
rate(influxdb_write_points_err_total[5m])

# Write latency p99
histogram_quantile(0.99, rate(influxdb_write_req_duration_seconds_bucket[5m]))

# Bytes written per second
rate(influxdb_write_req_bytes_total[5m])
```

#### 6.1.3 Query Performance Metrics

```
influxdb_query_req_total                     # Total query requests
influxdb_query_req_duration_seconds          # Query latency histogram
influxdb_query_req_bytes_total               # Response bytes
influxdb_query_compiling_duration_seconds    # Flux query compilation time
influxdb_query_executing_duration_seconds    # Query execution time
influxdb_query_queue_duration_seconds        # Time waiting in query queue
```

```promql
# Query rate
rate(influxdb_query_req_total[5m])

# Average query latency
rate(influxdb_query_req_duration_seconds_sum[5m]) /
  rate(influxdb_query_req_total[5m])

# Query queue time (indicates saturation)
histogram_quantile(0.99, rate(influxdb_query_queue_duration_seconds_bucket[5m]))

# Compilation vs execution ratio
rate(influxdb_query_compiling_duration_seconds_sum[5m]) /
  rate(influxdb_query_executing_duration_seconds_sum[5m])
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Query p99 latency | >1 second | >10 seconds |
| Query queue time p99 | >100ms | >1 second |
| Query error rate | >1% | >5% |
| Active queries | >50% of max concurrent | >80% of max concurrent |

#### 6.1.4 Series Cardinality (The Key Challenge)

Series cardinality is the number of unique time series (unique combinations of measurement + tag set). High cardinality is the number one performance killer for InfluxDB.

```flux
// Check series cardinality (Flux query, InfluxDB 2.x)
import "influxdata/influxdb"
influxdb.cardinality(bucket: "my-bucket", start: -1h)

// InfluxDB 1.x
SHOW SERIES CARDINALITY ON mydb
SHOW MEASUREMENT CARDINALITY ON mydb
SHOW TAG VALUES CARDINALITY WITH KEY = "host" ON mydb
```

```
# Prometheus metrics
influxdb_tsm1_shard_series_create_total      # New series created
influxdb_series_total                         # Total active series
influxdb_buckets_series_count                 # Series per bucket
```

**Cardinality thresholds:**

| Cardinality Level | Series Count | Status | Action |
|-------------------|--------------|--------|--------|
| Low | <100K | Healthy | No action |
| Moderate | 100K-1M | Monitor | Review tag design |
| High | 1M-10M | Warning | Reduce high-cardinality tags |
| Very High | >10M | Critical | Performance degradation likely; remove unbounded tags |

**High-cardinality anti-patterns:**
- Using UUIDs, user IDs, or IP addresses as tags (use fields instead)
- Unbounded tag values (request IDs, session IDs)
- Encoding timestamps or continuous values as tags
- Too many tag combinations (combinatorial explosion)

```promql
# Series creation rate (high = cardinality growth)
rate(influxdb_tsm1_shard_series_create_total[5m])

# Total series (absolute)
influxdb_series_total
```

#### 6.1.5 Shard and Compaction Metrics

```
# TSM engine metrics
influxdb_tsm1_shard_count                    # Number of shards
influxdb_tsm1_files_total{level="..."}       # TSM files by compaction level
influxdb_tsm1_disk_bytes                     # Disk usage by shard
influxdb_tsm1_cache_size_bytes               # In-memory write cache size
influxdb_tsm1_cache_writes_total             # Cache write rate
influxdb_tsm1_cache_writes_dropped_total     # Dropped writes (cache full)
influxdb_tsm1_cache_writes_err_total         # Cache write errors

# Compaction metrics
influxdb_tsm1_compact_duration_seconds       # Compaction duration
influxdb_tsm1_compact_queue_total            # Pending compaction queue
influxdb_tsm1_compact_running                # Currently running compactions
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Cache size | >80% of `cache-max-memory-size` | >95% |
| Cache writes dropped | >0 | >100/sec |
| Compaction queue | >10 | >50 (falling behind) |
| Shard count | >100 per node | >500 per node |
| TSM files per shard (level 1) | >50 | >200 |

#### 6.1.6 InfluxDB Health Endpoints

```bash
# Health check
curl -s http://localhost:8086/health
# Response:
# {"name":"influxdb","message":"ready for queries and writes","status":"pass","checks":[],"version":"2.7.3","commit":"abc123"}

# Ready check
curl -s http://localhost:8086/ready
# Response:
# {"status":"ready","started":"2025-01-15T00:00:00Z","up":"240h0m0s"}
```

### 6.2 TimescaleDB Observability

#### 6.2.1 Architecture Context

TimescaleDB is a PostgreSQL extension for time-series data. It automatically partitions data into "chunks" (time-based partitions of hypertables) and provides features like continuous aggregates, compression, and data retention policies. Since it runs on PostgreSQL, all standard PostgreSQL monitoring applies, plus TimescaleDB-specific views and functions.

**Key observability surfaces:**
- Standard PostgreSQL monitoring (`pg_stat_*` views)
- TimescaleDB information views (`timescaledb_information.*`)
- TimescaleDB-specific functions
- `pg_stat_statements` extension (query performance)
- PostgreSQL receiver in OTel Collector
- Prometheus: `postgres_exporter` with TimescaleDB queries

#### 6.2.2 Hypertable Monitoring

```sql
-- List all hypertables with size information
SELECT
  hypertable_schema,
  hypertable_name,
  num_chunks,
  num_dimensions,
  table_bytes,
  index_bytes,
  toast_bytes,
  total_bytes
FROM timescaledb_information.hypertable_stats;

-- Alternative with human-readable sizes
SELECT
  hypertable_name,
  pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as total_size,
  pg_size_pretty(hypertable_data_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as data_size,
  pg_size_pretty(hypertable_index_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as index_size,
  num_chunks
FROM timescaledb_information.hypertables
JOIN timescaledb_information.hypertable_stats USING (hypertable_schema, hypertable_name);

-- Chunk details for a specific hypertable
SELECT
  chunk_name,
  range_start,
  range_end,
  is_compressed,
  chunk_tablespace,
  pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) as chunk_size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'metrics'
ORDER BY range_start DESC
LIMIT 20;
```

**Key hypertable metrics:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Chunks per hypertable | >1000 | >10000 (planning overhead) |
| Chunk size variance | >10x between chunks | >100x |
| Uncompressed chunks (older than policy) | >0 past compression age | Many past compression age |

#### 6.2.3 Chunk Compression Monitoring

```sql
-- Compression status overview
SELECT
  hypertable_name,
  number_compressed_chunks,
  number_uncompressed_chunks,
  pg_size_pretty(before_compression_total_bytes) as before_compression,
  pg_size_pretty(after_compression_total_bytes) as after_compression,
  ROUND((1 - after_compression_total_bytes::numeric / NULLIF(before_compression_total_bytes, 0)) * 100, 1) as compression_ratio_pct
FROM timescaledb_information.compression_settings
JOIN (
  SELECT
    hypertable_name,
    count(*) FILTER (WHERE is_compressed) as number_compressed_chunks,
    count(*) FILTER (WHERE NOT is_compressed) as number_uncompressed_chunks
  FROM timescaledb_information.chunks
  GROUP BY hypertable_name
) c USING (hypertable_name);

-- Compression stats per hypertable
SELECT * FROM hypertable_compression_stats('metrics');
-- Output:
-- total_chunks: 500
-- number_compressed_chunks: 480
-- before_compression_table_bytes: 50000000000
-- before_compression_index_bytes: 10000000000
-- before_compression_toast_bytes: 1000000000
-- after_compression_table_bytes: 5000000000
-- after_compression_index_bytes: 1000000000
-- after_compression_toast_bytes: 100000000

-- Compression job status
SELECT
  job_id,
  application_name,
  schedule_interval,
  max_runtime,
  last_run_started_at,
  last_successful_finish,
  last_run_status,
  last_run_duration,
  next_start,
  total_runs,
  total_successes,
  total_failures
FROM timescaledb_information.jobs
WHERE application_name LIKE '%Compression%';
```

**Compression benchmarks (typical):**
- Text/log data: 10:1 to 20:1 compression ratio
- Numeric metrics: 5:1 to 15:1 compression ratio
- If compression ratio <3:1, check `segmentby` and `orderby` columns in compression settings

#### 6.2.4 Continuous Aggregates Monitoring

```sql
-- List continuous aggregates
SELECT
  view_name,
  view_schema,
  materialized_only,
  compression_enabled,
  finalized
FROM timescaledb_information.continuous_aggregates;

-- Continuous aggregate refresh status
SELECT
  job_id,
  application_name,
  schedule_interval,
  last_run_started_at,
  last_successful_finish,
  last_run_status,
  last_run_duration,
  next_start,
  total_runs,
  total_successes,
  total_failures
FROM timescaledb_information.jobs
WHERE application_name LIKE '%Refresh%';

-- Check materialization lag (how far behind the aggregate is)
SELECT
  view_name,
  completed_threshold,  -- Latest materialized time
  invalidation_threshold
FROM timescaledb_information.continuous_aggregates;
```

| Metric | Warning | Critical |
|--------|---------|----------|
| Refresh job failures | >0 | >3 consecutive |
| Refresh duration | >2x schedule interval | >5x schedule interval |
| Materialization lag | >2x refresh interval | >10x refresh interval |

#### 6.2.5 Retention Policy Monitoring

```sql
-- View retention policies
SELECT
  hypertable_name,
  job_id,
  schedule_interval,
  config,
  last_run_started_at,
  last_successful_finish,
  last_run_status,
  total_runs,
  total_failures
FROM timescaledb_information.jobs j
JOIN timescaledb_information.job_stats js USING (job_id)
WHERE j.proc_name = 'policy_retention';

-- Check data age distribution
SELECT
  hypertable_name,
  range_start,
  range_end,
  pg_size_pretty(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass)) as size
FROM timescaledb_information.chunks
WHERE hypertable_name = 'metrics'
ORDER BY range_start;
```

#### 6.2.6 PostgreSQL-Level Metrics for TimescaleDB

Since TimescaleDB runs on PostgreSQL, all standard PostgreSQL monitoring applies:

```sql
-- Connection monitoring
SELECT count(*), state
FROM pg_stat_activity
GROUP BY state;

-- Query performance (requires pg_stat_statements)
SELECT
  query,
  calls,
  mean_exec_time,
  total_exec_time,
  rows,
  shared_blks_hit,
  shared_blks_read
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Table bloat (important for uncompressed chunks)
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as total_size,
  n_live_tup,
  n_dead_tup,
  ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) as dead_pct
FROM pg_stat_user_tables
WHERE schemaname = '_timescaledb_internal'
ORDER BY n_dead_tup DESC
LIMIT 20;

-- WAL generation rate (important for replication)
SELECT
  pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') as wal_bytes_total,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn)) as replication_lag
FROM pg_stat_replication;

-- Buffer cache hit ratio
SELECT
  sum(blks_hit) as hits,
  sum(blks_read) as reads,
  ROUND(sum(blks_hit)::numeric / NULLIF(sum(blks_hit) + sum(blks_read), 0) * 100, 2) as hit_ratio
FROM pg_stat_database;
```

**Key PostgreSQL metrics for TimescaleDB:**

| Metric | Warning | Critical |
|--------|---------|----------|
| Buffer cache hit ratio | <95% | <90% |
| Dead tuple ratio | >10% (need VACUUM) | >30% |
| Connections used | >80% of `max_connections` | >90% |
| WAL generation rate | >1 GB/min sustained | >5 GB/min sustained |
| Replication lag | >1 MB | >100 MB |
| Lock waits | >10 concurrent | >50 concurrent |
| Long-running queries | >30 seconds | >5 minutes |

### 6.3 Cardinality Management: The Universal Time-Series Challenge

Both InfluxDB and TimescaleDB (and Prometheus, VictoriaMetrics, Mimir, etc.) face the same fundamental challenge: **series cardinality**.

**Why cardinality matters:**
- Each unique time series requires index memory
- High cardinality bloats inverted indexes
- Query planning degrades with millions of series
- Memory usage scales linearly (or worse) with cardinality

**Cardinality reduction strategies:**

| Strategy | InfluxDB | TimescaleDB |
|----------|----------|-------------|
| Avoid unbounded labels/tags | Do not use UUIDs, IPs, or session IDs as tags | Do not create indexes on high-cardinality columns |
| Aggregate before storage | Use Telegraf aggregation plugins | Use continuous aggregates |
| Drop unnecessary labels | Telegraf `tagexclude`, `fieldexclude` | Do not include in hypertable dimensions |
| Rollup old data | Downsampling tasks (Flux) | Continuous aggregates + retention |
| Retention policies | Bucket retention period | `add_retention_policy()` |
| Compression | TSM compaction (automatic) | `compress_chunk()` / compression policy |

**Cardinality monitoring queries:**

```flux
// InfluxDB: Track cardinality growth over time
import "influxdata/influxdb"

influxdb.cardinality(bucket: "my-bucket", start: -30d)
|> difference()
|> yield(name: "cardinality_growth")
```

```sql
-- TimescaleDB: Approximate cardinality of a dimension column
SELECT
  COUNT(DISTINCT host) as host_cardinality,
  COUNT(DISTINCT metric_name) as metric_cardinality,
  COUNT(DISTINCT host) * COUNT(DISTINCT metric_name) as potential_series
FROM metrics
WHERE time > now() - interval '1 hour';
```

### 6.4 Time-Series Database Alert Summary

**InfluxDB alerts:**

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| Write Errors | `rate(write_points_err) > 0` | Critical |
| Write Cache Full | `cache_writes_dropped > 0` | Critical |
| High Cardinality | `series_total > 1M` | Warning |
| Cardinality Growth | `series_creation_rate > 1000/min` | Warning |
| Query Latency High | `query_p99 > 5s` | Warning |
| Compaction Behind | `compact_queue > 20` | Warning |
| Disk Usage High | `disk_used > 80%` | Warning |
| Health Check Failed | `/health` returns non-pass | Critical |

**TimescaleDB alerts:**

| Alert Name | Condition | Severity |
|-----------|-----------|----------|
| Compression Job Failed | `last_run_status = 'Failed'` | Warning |
| Compression Behind | Uncompressed chunks older than policy | Warning |
| Refresh Job Failed | Continuous aggregate refresh failed | Warning |
| Chunk Count High | `>1000 chunks per hypertable` | Warning |
| Buffer Cache Low | `hit_ratio < 90%` | Warning |
| Dead Tuples High | `dead_tuple_ratio > 20%` | Warning |
| Connection Saturation | `connections > 80% max` | Warning |
| WAL Lag High | `replication_lag > 100MB` | Warning |
| Long Query | `query_duration > 60s` | Warning |
| Retention Job Failed | Retention policy execution failed | Warning |

---

## 7. Cross-Database Observability Patterns

### 7.1 The Four Golden Signals for Databases

Regardless of database technology, monitor these four dimensions:

| Signal | What to Measure | Example Metrics |
|--------|----------------|-----------------|
| **Latency** | Time to serve requests | Read/write latency p50, p95, p99 |
| **Traffic** | Request rate | Operations/sec, queries/sec, bytes/sec |
| **Errors** | Failed request rate | Timeouts, rejected connections, dropped messages |
| **Saturation** | Resource utilization | CPU, memory, disk, connections, queue depth |

### 7.2 USE Method Applied to Databases

For every database resource, measure **U**tilization, **S**aturation, **E**rrors:

| Resource | Utilization | Saturation | Errors |
|----------|-------------|------------|--------|
| CPU | `cpu_usage_percent` | Run queue depth, context switches | N/A |
| Memory | `memory_used / memory_max` | Swapping, OOM events | OOM kills |
| Disk I/O | `iops_used / iops_max` | I/O wait, queue depth | Disk errors |
| Disk Space | `disk_used / disk_total` | Growth rate projection | Write failures |
| Network | `bandwidth_used / bandwidth_max` | Socket backlog | Connection resets |
| Connections | `connections / max_connections` | Connection queue, wait time | Rejected connections |
| Internal Queues | `queue_depth / max_queue` | Queue growth rate | Dropped items |

### 7.3 Common Anti-Patterns Across All NoSQL Databases

| Anti-Pattern | Databases Affected | Detection | Impact |
|-------------|-------------------|-----------|--------|
| Missing indexes/inefficient access patterns | MongoDB, Cassandra, Elasticsearch | Slow queries, collection scans, high read amplification | High latency, resource waste |
| Unbounded growth | All | Disk usage trending to 100% | Outage |
| Connection leaks | MongoDB, Redis, Elasticsearch | Connection count rising without traffic increase | Connection exhaustion |
| Hot partitions/keys | DynamoDB, Cassandra, Redis Cluster | Uneven load, throttling on specific nodes/partitions | Partial outage |
| GC pressure | MongoDB, Cassandra, Elasticsearch | Long GC pauses, throughput drops | Intermittent timeouts |
| Tombstone storms | Cassandra | High tombstone count per read, slow range queries | Read degradation |
| Cardinality explosion | InfluxDB, TimescaleDB | Index bloat, memory growth, slow queries | Progressive degradation |
| Replication lag | MongoDB, Redis, Cassandra | Stale reads, failover data loss risk | Consistency issues |

### 7.4 Database Selection Guide for Observability Data

| Use Case | Recommended Database | Why |
|----------|---------------------|-----|
| Metrics (time-series) | InfluxDB, TimescaleDB, Prometheus, VictoriaMetrics | Optimized for time-series writes and range queries |
| Logs (full-text search) | Elasticsearch, OpenSearch, ClickHouse, Loki | Full-text indexing, high ingest rates |
| Traces (spans) | Elasticsearch, Cassandra (Jaeger backend), ClickHouse | Trace ID lookups, high cardinality |
| Session/cache | Redis | Sub-millisecond latency, in-memory |
| Config/metadata | MongoDB, DynamoDB | Flexible schema, document queries |
| Wide-column analytics | Cassandra, ScyllaDB | Write-heavy, partition-key access |

---

## 8. OTel Collector Integration Summary

### 8.1 Available OTel Receivers

| Database | OTel Receiver | Metrics | Logs | Notes |
|----------|--------------|---------|------|-------|
| MongoDB | `mongodb` | Yes | No | Direct metrics via `serverStatus` |
| MongoDB Atlas | `mongodbatlas` | Yes | Yes | Via Atlas API (public/private key) |
| Redis | `redis` | Yes | No | Via `INFO` command |
| Cassandra | `jmx` (target_system: cassandra) | Yes | No | Via JMX MBeans |
| Elasticsearch | `elasticsearch` | Yes | No | Via `_nodes/stats` and `_cluster/health` |
| DynamoDB | `awscloudwatch/dynamodb` | Yes | No | Via CloudWatch API |
| InfluxDB | `influxdb` | Yes (write path) | No | Receives InfluxDB line protocol |
| TimescaleDB | `postgresql` | Yes | No | Via PostgreSQL stats views |

### 8.2 OTel Collector Configuration Patterns

**Multi-database monitoring pipeline:**
```yaml
receivers:
  mongodb:
    hosts:
      - endpoint: mongo-primary:27017
    username: otel
    password: ${MONGODB_PASSWORD}
    collection_interval: 60s

  redis:
    endpoint: redis-primary:6379
    password: ${REDIS_PASSWORD}
    collection_interval: 60s

  elasticsearch:
    endpoint: http://es-node:9200
    username: otel
    password: ${ES_PASSWORD}
    collection_interval: 60s

  jmx:
    endpoint: service:jmx:rmi:///jndi/rmi://cassandra-node:7199/jmxrmi
    target_system: cassandra
    collection_interval: 60s
    jar_path: /opt/otel/opentelemetry-jmx-metrics.jar

  postgresql:
    endpoint: timescaledb-primary:5432
    username: otel
    password: ${TSDB_PASSWORD}
    databases: [metrics]
    collection_interval: 60s

processors:
  batch:
    send_batch_size: 1000
    timeout: 10s

  resource:
    attributes:
      - key: environment
        value: production
        action: upsert

exporters:
  otlphttp:
    endpoint: ${OTLP_ENDPOINT}

service:
  pipelines:
    metrics/databases:
      receivers: [mongodb, redis, elasticsearch, jmx, postgresql]
      processors: [batch, resource]
      exporters: [otlphttp]
```

### 8.3 Consulting Engagement Checklist

When onboarding a new client with NoSQL databases, assess:

- [ ] **Inventory**: Which databases, versions, and deployment topologies?
- [ ] **Current monitoring**: What metrics are already collected? Gaps?
- [ ] **Access**: Service accounts, firewall rules, JMX ports, API keys?
- [ ] **Baseline**: What are normal latency, throughput, and error rates?
- [ ] **SLOs**: What latency and availability targets exist?
- [ ] **Alerting**: What alerts exist? What are the escalation paths?
- [ ] **Capacity**: Current utilization vs. provisioned capacity?
- [ ] **Growth**: Data growth rate and capacity planning?
- [ ] **Backup/DR**: Backup monitoring, recovery testing?
- [ ] **Security**: Audit logging, encryption, access control monitoring?

---

*This document is part of the OllyStack consulting knowledge base. All metrics, thresholds, and configurations should be validated against the specific versions and deployment configurations of each client engagement.*


---

# Parts III–X: Cross-Cutting Practices

---

44. [Unbounded Queries and Hot Partitions](#44-unbounded-queries-and-hot-partitions)
45. [Memory Pressure and Buffer Cache](#45-memory-pressure-and-buffer-cache)
46. [Replication Lag Spirals and Transaction Log Growth](#46-replication-lag-spirals-and-transaction-log-growth)

---

## Part I: OpenTelemetry Database Instrumentation

---

## 1. OTel Semantic Conventions for Database Spans

### Stability Status (2025)

Database semantic conventions reached **stable** status for client spans, the `db.client.operation.duration` metric, and their respective attributes for **MariaDB, Microsoft SQL Server, MySQL, and PostgreSQL**. Other databases and metrics remain under development. Instrumentations manage migration via the `OTEL_SEMCONV_STABILITY_OPT_IN` environment variable with the `database` value to emit stable conventions.

### Span Naming Convention

The span name follows a priority cascade:

| Priority | Format | Example |
|----------|--------|---------|
| 1 (best) | `{db.query.summary}` | `SELECT orders JOIN users` |
| 2 | `{db.operation.name} {target}` | `SELECT mydb.orders` |
| 3 | `{target}` | `mydb.orders` |
| 4 (fallback) | `{db.system.name}` | `postgresql` |

Where `{target}` resolves in order: `db.collection.name` -> `db.namespace` -> `server.address:server.port`.

**Legacy convention** (pre-stable): `{db.operation} {db.name}.{db.sql.table}` (e.g., `SELECT mydb.orders`). This format is still common in existing instrumentations but is being superseded by the stable naming above.

### Core Span Attributes

#### Required Attributes

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `db.system.name` | string | DBMS product identifier | `postgresql`, `mysql`, `mariadb`, `mssql`, `mongodb`, `redis`, `elasticsearch` |

#### Conditionally Required Attributes

| Attribute | Type | Condition | Example |
|-----------|------|-----------|---------|
| `db.collection.name` | string | If readily available and single-collection operation | `orders`, `users` |
| `db.namespace` | string | If available (database name for SQL, database index for Redis) | `mydb`, `0` |
| `db.operation.name` | string | If readily available and single operation | `SELECT`, `INSERT`, `findAndModify` |
| `db.response.status_code` | string | If operation failed and status code is available | `42P01` (PG undefined table) |
| `error.type` | string | If and only if the operation failed | `timeout`, `ProgrammingError` |
| `server.port` | int | If non-default port and `server.address` is set | `5433` |

#### Recommended Attributes

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `db.query.text` | string | Database query being executed (sanitized) | `SELECT * FROM orders WHERE id = ?` |
| `db.query.summary` | string | Low-cardinality summary of the query | `SELECT orders` |
| `db.operation.batch.size` | int | Number of operations in a batch | `50` |
| `db.stored_procedure.name` | string | Name of stored procedure | `calculate_totals` |
| `server.address` | string | Logical server hostname | `db-primary.internal` |
| `network.peer.address` | string | Physical peer address | `10.0.1.42` |
| `network.peer.port` | int | Physical peer port | `5432` |

#### Opt-In Attributes (Development)

| Attribute | Type | Description |
|-----------|------|-------------|
| `db.query.parameter.<key>` | string | Query parameter values (use with extreme caution: PII risk) |
| `db.response.returned_rows` | int | Number of rows returned by the operation |

### Attribute Migration: Old to New

| Old (Experimental) | New (Stable) | Notes |
|--------------------|--------------|-------|
| `db.system` | `db.system.name` | Renamed for clarity |
| `db.name` | `db.namespace` | Broader applicability |
| `db.statement` | `db.query.text` | Clearer intent |
| `db.operation` | `db.operation.name` | Explicit naming |
| `db.sql.table` | `db.collection.name` | Works for NoSQL too |
| `db.user` | Not carried forward | Moved to resource attributes |
| `net.peer.name` | `server.address` | General networking convention |
| `net.peer.port` | `server.port` | General networking convention |

### db.system.name Values by Database

| Value | Database | Value | Database |
|-------|----------|-------|----------|
| `postgresql` | PostgreSQL | `mongodb` | MongoDB |
| `mysql` | MySQL | `redis` | Redis |
| `mariadb` | MariaDB | `elasticsearch` | Elasticsearch |
| `mssql` | SQL Server | `cassandra` | Apache Cassandra |
| `oracle` | Oracle DB | `hbase` | Apache HBase |
| `db2` | IBM Db2 | `couchdb` | CouchDB |
| `sqlite` | SQLite | `cosmosdb` | Azure Cosmos DB |
| `cockroachdb` | CockroachDB | `dynamodb` | AWS DynamoDB |
| `neo4j` | Neo4j | `memcached` | Memcached |

### SQL-Specific Conventions

For SQL databases, additional conventions apply:

```
# Span name examples for SQL operations:
SELECT mydb.orders          # db.operation.name=SELECT, db.collection.name=orders
INSERT mydb.users           # db.operation.name=INSERT, db.collection.name=users
CALL mydb.calculate_totals  # db.operation.name=CALL, db.stored_procedure.name=calculate_totals
postgresql                  # Fallback when operation and table are unknown
```

**db.query.text collection policy**: Should be collected by default ONLY if sanitization excludes sensitive information. Sanitization replaces all literal values with a `?` placeholder. Parameterized query text (with `$1`, `?`, `@param` placeholders) should NOT be further sanitized, as parameterized queries already separate code from data.

---

## 2. Auto-Instrumentation for Database Clients

### Java

Java auto-instrumentation via the OpenTelemetry Java Agent (`-javaagent:opentelemetry-javaagent.jar`) provides zero-code database instrumentation for all major database libraries.

#### Supported Libraries

| Library | Versions | What is Captured |
|---------|----------|-----------------|
| JDBC | All major drivers | All SQL queries via `java.sql` interfaces |
| Hibernate | 3.3+ | HQL/JPQL queries, session operations, entity load/save |
| R2DBC | 1.0+ | Reactive database operations |
| jOOQ | 3.1+ | Generated SQL execution |
| MyBatis | 3.2+ | Mapped SQL statements |
| Spring Data | 1.8+ | Repository method calls |
| Jedis | 1.4+ | Redis commands |
| Lettuce | 4.0+ | Async Redis commands |
| MongoDB Driver | 3.1+ | MongoDB operations (find, insert, aggregate) |
| Elasticsearch REST Client | 5.0+ | REST API calls |

#### Configuration for Database Instrumentation

```bash
# Enable database-specific settings
export OTEL_INSTRUMENTATION_JDBC_ENABLED=true
export OTEL_INSTRUMENTATION_HIBERNATE_ENABLED=true

# Control query sanitization
export OTEL_INSTRUMENTATION_COMMON_DB_STATEMENT_SANITIZER_ENABLED=true

# Enable connection pool metrics (HikariCP, c3p0, DBCP2)
export OTEL_INSTRUMENTATION_HIKARICP_ENABLED=true

# Stable semantic conventions
export OTEL_SEMCONV_STABILITY_OPT_IN=database
```

#### Example Trace Output (Java JDBC)

```
Span: SELECT mydb.orders
  db.system.name: postgresql
  db.namespace: mydb
  db.operation.name: SELECT
  db.collection.name: orders
  db.query.text: SELECT o.id, o.total FROM orders o WHERE o.user_id = ? AND o.status = ?
  server.address: db-primary.internal
  server.port: 5432
  db.client.operation.duration: 0.023s
```

### Python

#### Supported Libraries

| Library | Package | What is Captured |
|---------|---------|-----------------|
| psycopg2 | `opentelemetry-instrumentation-psycopg2` | PostgreSQL queries |
| asyncpg | `opentelemetry-instrumentation-asyncpg` | Async PostgreSQL queries |
| psycopg (v3) | `opentelemetry-instrumentation-psycopg` | PostgreSQL queries (modern driver) |
| SQLAlchemy | `opentelemetry-instrumentation-sqlalchemy` | ORM and Core queries, engine events |
| Django ORM | `opentelemetry-instrumentation-django` | Model queries, migrations |
| mysql-connector | `opentelemetry-instrumentation-mysql` | MySQL queries |
| PyMongo | `opentelemetry-instrumentation-pymongo` | MongoDB operations |
| redis-py | `opentelemetry-instrumentation-redis` | Redis commands |
| aiopg | `opentelemetry-instrumentation-aiopg` | Async PostgreSQL (aiopg) |

#### Installation and Setup

```bash
# Install all database instrumentations
pip install opentelemetry-instrumentation-psycopg2 \
            opentelemetry-instrumentation-sqlalchemy \
            opentelemetry-instrumentation-redis \
            opentelemetry-instrumentation-pymongo

# Or use auto-instrumentation bootstrap
opentelemetry-bootstrap -a install
```

#### Programmatic Setup (SQLAlchemy Example)

```python
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

# Instrument all engines
SQLAlchemyInstrumentor().instrument()

# Or instrument specific engine
from sqlalchemy import create_engine
engine = create_engine("postgresql://user:pass@localhost/mydb")
SQLAlchemyInstrumentor().instrument(engine=engine)

# With connection pool metrics enabled
SQLAlchemyInstrumentor().instrument(
    engine=engine,
    enable_commenter=True,        # Adds trace context to SQL comments
    commenter_options={
        "db_driver": True,
        "db_framework": True,
        "opentelemetry_values": True,  # Injects traceparent into SQL comments
    }
)
```

### Node.js

#### Supported Libraries

| Library | Package | What is Captured |
|---------|---------|-----------------|
| pg (node-postgres) | `@opentelemetry/instrumentation-pg` | PostgreSQL queries, connection pool |
| mysql2 | `@opentelemetry/instrumentation-mysql2` | MySQL queries |
| mysql | `@opentelemetry/instrumentation-mysql` | MySQL queries (legacy driver) |
| mongoose/mongodb | `@opentelemetry/instrumentation-mongoose` / `mongodb` | MongoDB operations |
| ioredis | `@opentelemetry/instrumentation-ioredis` | Redis commands |
| knex | `@opentelemetry/instrumentation-knex` | Query builder operations |
| Prisma | Via `@prisma/instrumentation` | All Prisma Client operations |
| Sequelize | Community instrumentation | ORM queries |
| TypeORM | Via underlying driver instrumentation | All TypeORM queries |

#### Setup Example

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { PgInstrumentation } = require('@opentelemetry/instrumentation-pg');
const { MySQL2Instrumentation } = require('@opentelemetry/instrumentation-mysql2');
const { IORedisInstrumentation } = require('@opentelemetry/instrumentation-ioredis');

const sdk = new NodeSDK({
  instrumentations: [
    new PgInstrumentation({
      enhancedDatabaseReporting: true,   // Include query parameters (caution: PII)
      addSqlCommenterComment: true,      // sqlcommenter for trace-query linking
    }),
    new MySQL2Instrumentation({
      addSqlCommenterComment: true,
    }),
    new IORedisInstrumentation({
      dbStatementSerializer: (cmdName, cmdArgs) => {
        // Custom serialization to control what is captured
        return `${cmdName} ${cmdArgs[0] || ''}`;
      },
    }),
  ],
});
sdk.start();
```

### .NET

#### Supported Libraries

| Library | Package | What is Captured |
|---------|---------|-----------------|
| SqlClient (SQL Server) | `OpenTelemetry.Instrumentation.SqlClient` | SQL Server queries |
| Npgsql (PostgreSQL) | Built-in (`Npgsql.OpenTelemetry`) | PostgreSQL queries |
| MySqlConnector | Built-in metrics via `System.Diagnostics` | MySQL queries |
| Entity Framework Core | Via underlying provider instrumentation | ORM queries |
| StackExchange.Redis | `OpenTelemetry.Instrumentation.StackExchangeRedis` | Redis commands |
| MongoDB .NET Driver | Built-in `ActivitySource` | MongoDB operations |
| Dapper | Via underlying `SqlClient`/`Npgsql` instrumentation | All Dapper queries |

#### Setup Example

```csharp
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddSqlClientInstrumentation(options =>
        {
            options.SetDbStatementForText = true;       // Capture query text
            options.SetDbStatementForStoredProcedure = true;
            options.RecordException = true;
            options.EnableConnectionLevelAttributes = true;
            // Sanitize queries to remove literal values
            options.Filter = (command) => !command.CommandText.Contains("__EFMigrations");
        })
        .AddNpgsql()
        .AddRedisInstrumentation(connection, options =>
        {
            options.SetVerboseDatabaseStatements = true;
        })
    );
```

### Go

#### Supported Libraries

| Library | Package | What is Captured |
|---------|---------|-----------------|
| database/sql | `go.opentelemetry.io/contrib/instrumentation/database/sql/otelsql` | All SQL operations via `database/sql` |
| pgx (PostgreSQL) | `github.com/exaring/otelpgx` | PostgreSQL queries (pgx v5 native) |
| go-redis | `github.com/redis/go-redis/extra/redisotel` | Redis commands |
| mongo-go-driver | `go.mongodb.org/mongo-driver` (built-in) | MongoDB operations |
| GORM | `gorm.io/plugin/opentelemetry` | ORM queries |

#### Setup Example (database/sql)

```go
import (
    "database/sql"
    "go.opentelemetry.io/contrib/instrumentation/database/sql/otelsql"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
    _ "github.com/lib/pq"
)

func main() {
    // Wrap the database driver with OpenTelemetry instrumentation
    db, err := otelsql.Open("postgres", "postgres://user:pass@localhost/mydb",
        otelsql.WithAttributes(
            semconv.DBSystemNamePostgreSQL,
            semconv.DBNamespace("mydb"),
            semconv.ServerAddress("localhost"),
            semconv.ServerPort(5432),
        ),
        otelsql.WithDBName("mydb"),
        otelsql.WithSpanOptions(otelsql.SpanOptions{
            DisableQuery: false,  // Set true to disable db.query.text capture
        }),
    )
    if err != nil {
        log.Fatal(err)
    }
    // Register DB stats metrics (connection pool)
    otelsql.RegisterDBStatsMetrics(db,
        otelsql.WithAttributes(semconv.DBSystemNamePostgreSQL),
    )
}
```

---

## 3. OTel Collector Database Receivers

The OpenTelemetry Collector provides dedicated receivers for pulling metrics directly from database systems. These complement application-side instrumentation by providing server-side visibility.

### PostgreSQL Receiver

**Component**: `postgresqlreceiver` (contrib)
**Required Privileges**: User with `pg_monitor` role or superuser

```yaml
receivers:
  postgresql:
    endpoint: ${env:POSTGRESQL_ENDPOINT}  # localhost:5432
    transport: tcp
    username: ${env:POSTGRESQL_USERNAME}
    password: ${env:POSTGRESQL_PASSWORD}
    databases:
      - mydb
      - analytics
    collection_interval: 60s
    tls:
      insecure: false
      cert_file: /etc/ssl/certs/client.crt
      key_file: /etc/ssl/private/client.key
      ca_file: /etc/ssl/certs/ca.crt
    # Enable top query and query sample collection
    query_sample_collection:
      enabled: true
    top_query_collection:
      enabled: true
    metrics:
      # Default metrics (all enabled by default)
      postgresql.backends:
        enabled: true
      postgresql.bgwriter.buffers.allocated:
        enabled: true
      postgresql.bgwriter.buffers.writes:
        enabled: true
      postgresql.bgwriter.checkpoint.count:
        enabled: true
      postgresql.bgwriter.duration:
        enabled: true
      postgresql.bgwriter.maxwritten:
        enabled: true
      postgresql.blocks_read:
        enabled: true
      postgresql.commits:
        enabled: true
      postgresql.connection.max:
        enabled: true
      postgresql.database.count:
        enabled: true
      postgresql.db_size:
        enabled: true
      postgresql.index.scans:
        enabled: true
      postgresql.index.size:
        enabled: true
      postgresql.operations:
        enabled: true
      postgresql.replication.data_delay:
        enabled: true
      postgresql.rollbacks:
        enabled: true
      postgresql.rows:
        enabled: true
      postgresql.table.count:
        enabled: true
      postgresql.table.size:
        enabled: true
      postgresql.table.vacuum.count:
        enabled: true
      postgresql.wal.age:
        enabled: true
      postgresql.wal.lag:
        enabled: true
      # Optional metrics (enable for deeper visibility)
      postgresql.database.locks:
        enabled: true
      postgresql.deadlocks:
        enabled: true
      postgresql.sequential_scans:
        enabled: true
      postgresql.blks_hit:
        enabled: true
      postgresql.temp_files:
        enabled: true
```

**Key Metrics Explained**:

| Metric | What It Tells You | Alert Threshold |
|--------|-------------------|-----------------|
| `postgresql.backends` | Active connections per database | > 80% of `max_connections` |
| `postgresql.connection.max` | Configured max connections | Static reference |
| `postgresql.replication.data_delay` | Bytes behind primary | > 100MB for OLTP |
| `postgresql.wal.lag` | Replication lag in seconds | > 5s for OLTP, > 60s for analytics |
| `postgresql.deadlocks` | Deadlock count (monotonic) | Any increase |
| `postgresql.database.locks` | Current lock count by type | Sustained > 100 |
| `postgresql.bgwriter.checkpoint.count` | Checkpoint frequency | Timed > Requested consistently |
| `postgresql.table.vacuum.count` | Vacuum frequency per table | Decreasing trend (autovacuum failing) |
| `postgresql.db_size` | Database disk usage | > 80% of allocated storage |
| `postgresql.index.scans` | Index usage frequency | 0 for large tables (unused index) |

### MySQL Receiver

**Component**: `mysqlreceiver` (contrib)
**Required Privileges**: `PROCESS`, `REPLICATION CLIENT`, and `SELECT` on `performance_schema`

```yaml
receivers:
  mysql:
    endpoint: ${env:MYSQL_ENDPOINT}  # localhost:3306
    username: ${env:MYSQL_USERNAME}
    password: ${env:MYSQL_PASSWORD}
    database: mydb
    collection_interval: 60s
    # Statement event monitoring
    statement_events:
      digest_text_limit: 120    # Truncate query text at 120 chars
      time_limit: 24h           # Only queries from last 24h
      limit: 250                # Top 250 queries by total time
    tls:
      insecure: false
    metrics:
      # InnoDB Buffer Pool
      mysql.buffer_pool.data_pages:
        enabled: true
      mysql.buffer_pool.limit:
        enabled: true
      mysql.buffer_pool.operations:
        enabled: true
      mysql.buffer_pool.pages:
        enabled: true
      mysql.buffer_pool.usage:
        enabled: true
      # Locking
      mysql.locks:
        enabled: true
      mysql.row_locks:
        enabled: true
      # I/O waits
      mysql.table.io.wait.count:
        enabled: true
      mysql.table.io.wait.time:
        enabled: true
      mysql.index.io.wait.count:
        enabled: true
      mysql.index.io.wait.time:
        enabled: true
      # Replication
      mysql.replica.sql_delay:
        enabled: true
      mysql.replica.time_behind_source:
        enabled: true
      # Optional: per-table and query metrics
      mysql.query.slow.count:
        enabled: true
      mysql.table.rows:
        enabled: true
      mysql.table.size:
        enabled: true
      mysql.table.lock_wait.read.count:
        enabled: true
      mysql.table.lock_wait.write.count:
        enabled: true
      mysql.connection.count:
        enabled: true
      mysql.connection.errors:
        enabled: true
```

### MongoDB Receiver

**Component**: `mongodbreceiver` (contrib)
**Required Privileges**: `clusterMonitor` role on `admin` database

```yaml
receivers:
  mongodb:
    hosts:
      - endpoint: ${env:MONGODB_ENDPOINT}  # localhost:27017
    username: ${env:MONGODB_USERNAME}
    password: ${env:MONGODB_PASSWORD}
    collection_interval: 60s
    tls:
      insecure: false
      ca_file: /etc/ssl/certs/mongodb-ca.crt
    metrics:
      mongodb.cache.operations:
        enabled: true
      mongodb.collection.count:
        enabled: true
      mongodb.connection.count:
        enabled: true
      mongodb.cursor.count:
        enabled: true
      mongodb.cursor.timeout.count:
        enabled: true
      mongodb.database.count:
        enabled: true
      mongodb.document.operation.count:
        enabled: true
      mongodb.global_lock.time:
        enabled: true
      mongodb.index.count:
        enabled: true
      mongodb.index.size:
        enabled: true
      mongodb.memory.usage:
        enabled: true
      mongodb.network.io.receive:
        enabled: true
      mongodb.network.io.transmit:
        enabled: true
      mongodb.network.request.count:
        enabled: true
      mongodb.object.count:
        enabled: true
      mongodb.operation.count:
        enabled: true
      mongodb.operation.latency.time:
        enabled: true
      mongodb.operation.repl.count:
        enabled: true
      mongodb.session.count:
        enabled: true
      mongodb.storage.size:
        enabled: true
```

### Redis Receiver

**Component**: `redisreceiver` (contrib)

```yaml
receivers:
  redis:
    endpoint: ${env:REDIS_ENDPOINT}  # localhost:6379
    password: ${env:REDIS_PASSWORD}
    collection_interval: 60s
    tls:
      insecure: false
    metrics:
      redis.clients.blocked:
        enabled: true
      redis.clients.connected:
        enabled: true
      redis.clients.max_input_buffer:
        enabled: true
      redis.clients.max_output_buffer:
        enabled: true
      redis.commands:
        enabled: true
      redis.commands.processed:
        enabled: true
      redis.connections.received:
        enabled: true
      redis.connections.rejected:
        enabled: true
      redis.cpu.time:
        enabled: true
      redis.db.avg_ttl:
        enabled: true
      redis.db.expires:
        enabled: true
      redis.db.keys:
        enabled: true
      redis.keys.evicted:
        enabled: true
      redis.keys.expired:
        enabled: true
      redis.keyspace.hits:
        enabled: true
      redis.keyspace.misses:
        enabled: true
      redis.maxmemory:
        enabled: true
      redis.memory.fragmentation_ratio:
        enabled: true
      redis.memory.lua:
        enabled: true
      redis.memory.peak:
        enabled: true
      redis.memory.rss:
        enabled: true
      redis.memory.used:
        enabled: true
      redis.net.input:
        enabled: true
      redis.net.output:
        enabled: true
      redis.replication.backlog_first_byte_offset:
        enabled: true
      redis.replication.offset:
        enabled: true
      redis.role:
        enabled: true
      redis.uptime:
        enabled: true
```

### Elasticsearch Receiver

**Component**: `elasticsearchreceiver` (contrib)
**Required Privileges**: `monitor` cluster privilege

```yaml
receivers:
  elasticsearch:
    endpoint: ${env:ELASTICSEARCH_ENDPOINT}  # http://localhost:9200
    username: ${env:ELASTICSEARCH_USERNAME}
    password: ${env:ELASTICSEARCH_PASSWORD}
    collection_interval: 60s
    nodes: ["_all"]
    skip_cluster_metrics: false
    indices: ["_all"]
    tls:
      insecure_skip_verify: false
      ca_file: /etc/ssl/certs/es-ca.crt
```

### Couchbase Receiver

**Component**: `couchbasereceiver` (contrib, development)

```yaml
receivers:
  couchbase:
    endpoint: ${env:COUCHBASE_ENDPOINT}  # http://localhost:8091
    username: ${env:COUCHBASE_USERNAME}
    password: ${env:COUCHBASE_PASSWORD}
    collection_interval: 60s
```

### Multi-Database Collector Pipeline

```yaml
receivers:
  postgresql:
    endpoint: pg-primary:5432
    username: otel_monitor
    password: ${env:PG_PASSWORD}
    databases: [app_db, analytics_db]
    collection_interval: 30s
  mysql:
    endpoint: mysql-primary:3306
    username: otel_monitor
    password: ${env:MYSQL_PASSWORD}
    collection_interval: 30s
  redis:
    endpoint: redis-primary:6379
    password: ${env:REDIS_PASSWORD}
    collection_interval: 15s
  mongodb:
    hosts:
      - endpoint: mongo-rs0:27017
    username: otel_monitor
    password: ${env:MONGO_PASSWORD}
    collection_interval: 30s

processors:
  batch:
    send_batch_size: 1000
    timeout: 10s
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
      - key: team
        value: platform
        action: upsert

exporters:
  otlp:
    endpoint: ${env:OTLP_ENDPOINT}
    headers:
      Authorization: "Bearer ${env:OTLP_TOKEN}"

service:
  pipelines:
    metrics/databases:
      receivers: [postgresql, mysql, redis, mongodb]
      processors: [resource, batch]
      exporters: [otlp]
```

---

## 4. Database Query Sanitization

### Why Sanitize

Database queries frequently contain sensitive data in literal values: user IDs, email addresses, credit card numbers, API keys, PHI/PII. Capturing unsanitized `db.query.text` creates compliance violations (GDPR, HIPAA, PCI-DSS) and security risks.

### Sanitization Strategies

#### Strategy 1: Instrumentation-Level Sanitization (Recommended)

Most OTel auto-instrumentation libraries sanitize by default, replacing literal values with `?`:

```sql
-- Original query
SELECT * FROM users WHERE email = 'alice@example.com' AND age > 25

-- Sanitized (captured as db.query.text)
SELECT * FROM users WHERE email = ? AND age > ?
```

**Java Agent**: Enabled by default via `OTEL_INSTRUMENTATION_COMMON_DB_STATEMENT_SANITIZER_ENABLED=true`

**Python**: Most instrumentations sanitize by default. For psycopg2:
```python
Psycopg2Instrumentor().instrument(
    enable_commenter=True,
    sanitize_query=True,  # Default: True
)
```

#### Strategy 2: OTel Collector Transform Processor

```yaml
processors:
  transform/sanitize_db:
    trace_statements:
      - context: span
        statements:
          # Replace numeric literals
          - replace_pattern(attributes["db.query.text"], "= \\d+", "= ?")
          # Replace quoted string literals
          - replace_pattern(attributes["db.query.text"], "'[^']*'", "'?'")
          # Replace IN clause values
          - replace_pattern(attributes["db.query.text"], "IN \\([^)]+\\)", "IN (?)")
```

#### Strategy 3: OTel Collector Redaction Processor

```yaml
processors:
  redaction/db:
    # Allow only these span attributes through
    allowed_keys:
      - db.system.name
      - db.namespace
      - db.operation.name
      - db.collection.name
      - db.query.summary
      - server.address
      - server.port
    # Block db.query.text entirely in high-security environments
    blocked_keys:
      - db.query.text
      - db.query.parameter.*
    # Mask patterns in allowed values
    blocked_values:
      - "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b"  # emails
      - "\\b\\d{3}-\\d{2}-\\d{4}\\b"                                # SSN
      - "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"           # credit cards
```

#### Strategy 4: sqlcommenter for Trace-Query Correlation

Instead of capturing full query text, inject trace context as SQL comments:

```sql
-- Application sends:
SELECT * FROM orders WHERE user_id = $1
/*traceparent='00-abc123-def456-01',db_driver='pg',framework='express'*/

-- Database sees the comment, logging systems can correlate
-- OTel span captures sanitized: SELECT * FROM orders WHERE user_id = ?
```

Supported by: Google sqlcommenter, OTel pg instrumentation (`addSqlCommenterComment`), SQLAlchemy (`enable_commenter`).

---

## 5. Trace-to-Metric Correlation Patterns

### The Correlation Challenge

Application traces contain database spans (client-side view), while Collector receivers produce server-side metrics. Correlating these two signals answers questions like: "Which application endpoint is causing the spike in database CPU?"

### Pattern 1: Resource Attributes as Join Keys

```
Application Trace Span:
  resource.service.name: order-service
  db.system.name: postgresql
  server.address: pg-primary.internal
  server.port: 5432
  db.namespace: orders_db

Collector PostgreSQL Metric:
  resource.server.address: pg-primary.internal
  resource.server.port: 5432
  metric: postgresql.backends = 142
```

**Join on**: `server.address` + `server.port` + `db.namespace`

### Pattern 2: Exemplars on Database Metrics

Configure the Collector to attach trace exemplars to database metrics:

```yaml
exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
    enable_open_metrics: true  # Required for exemplars
```

This allows clicking from a metric spike directly to an example trace.

### Pattern 3: sqlcommenter Trace Injection

```
# Application code (Node.js pg with sqlcommenter enabled)
# Query arrives at PostgreSQL with trace context in comments:
SELECT * FROM orders WHERE status = 'pending'
/*traceparent='00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'*/

# pg_stat_activity shows the comment
# pg_stat_statements groups by normalized query (comment stripped)
# Log-based correlation: parse traceparent from slow query log
```

### Pattern 4: Service Map from Database Spans

Aggregate `db.system.name` + `server.address` from all application spans to build a dependency map:

```
order-service ──> postgresql (pg-primary:5432/orders_db)
                  ├── SELECT orders: p50=2ms, p99=45ms
                  ├── INSERT orders: p50=5ms, p99=120ms
                  └── UPDATE orders: p50=3ms, p99=80ms
order-service ──> redis (redis-primary:6379)
                  ├── GET: p50=0.3ms, p99=2ms
                  └── SET: p50=0.4ms, p99=3ms
user-service  ──> postgresql (pg-primary:5432/users_db)
                  └── SELECT users: p50=1ms, p99=15ms
```

---

## 6. OTel Database Client Metrics

### Stable Metrics

| Metric | Type | Unit | Description |
|--------|------|------|-------------|
| `db.client.operation.duration` | Histogram | `s` | Duration of database client operations |

**Required attributes**: `db.system.name`
**Recommended attributes**: `db.collection.name`, `db.namespace`, `db.operation.name`, `db.response.status_code`, `error.type`, `server.address`, `server.port`

**Recommended histogram bucket boundaries**: `[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, 10]` (seconds)

### Development Metrics (Connection Pool)

| Metric | Type | Unit | Description |
|--------|------|------|-------------|
| `db.client.connection.count` | UpDownCounter | `{connection}` | Connections in state described by `db.client.connection.state` |
| `db.client.connection.idle.max` | UpDownCounter | `{connection}` | Max idle connections allowed |
| `db.client.connection.idle.min` | UpDownCounter | `{connection}` | Min idle connections allowed |
| `db.client.connection.max` | UpDownCounter | `{connection}` | Max open connections allowed |
| `db.client.connection.pending_requests` | UpDownCounter | `{request}` | Pending requests for a connection |
| `db.client.connection.timeouts` | Counter | `{timeout}` | Connection acquisition timeouts |
| `db.client.connection.create_time` | Histogram | `s` | Time to create a new connection |
| `db.client.connection.wait_time` | Histogram | `s` | Time to obtain a connection from pool |
| `db.client.connection.use_time` | Histogram | `s` | Time between borrowing and returning |
| `db.client.response.returned_rows` | Histogram | `{row}` | Rows returned by operation |

### Connection Pool Name Convention

The `db.client.connection.pool.name` attribute should be unique within the application. If the pool implementation does not provide a name, use:

```
{server.address}:{server.port}/{db.namespace}
# Example: pg-primary.internal:5432/orders_db
```

### Connection State Values

| Value | Description |
|-------|-------------|
| `idle` | Connection is in the pool, not in use |
| `used` | Connection is currently in use by a client |

### PromQL Examples for Database Client Metrics

```promql
# Average query duration by database and operation (p50)
histogram_quantile(0.50,
  sum(rate(db_client_operation_duration_seconds_bucket[5m])) by (le, db_namespace, db_operation_name)
)

# Error rate by database system
sum(rate(db_client_operation_duration_seconds_count{error_type!=""}[5m])) by (db_system_name)
/
sum(rate(db_client_operation_duration_seconds_count[5m])) by (db_system_name)

# Connection pool utilization
db_client_connection_count{db_client_connection_state="used"}
/
db_client_connection_max

# Connection acquisition wait time (p99)
histogram_quantile(0.99,
  sum(rate(db_client_connection_wait_time_seconds_bucket[5m])) by (le, db_client_connection_pool_name)
)

# Connection timeout rate
sum(rate(db_client_connection_timeouts_total[5m])) by (db_client_connection_pool_name)
```

---

## Part II: Query Performance Observability

---

## 7. Query Lifecycle and Execution Plans

### Query Lifecycle Stages

Every database query passes through distinct stages, each of which can be observed:

```
Client Request
    |
    v
[1. PARSE] ---- Syntax validation, object resolution
    |             Observable: parse time, syntax errors
    v
[2. PLAN] ----- Cost estimation, access path selection
    |             Observable: plan time, plan type, estimated rows vs actual
    v
[3. EXECUTE] -- Data access, joins, aggregations
    |             Observable: execution time, I/O, buffer hits, wait events
    v
[4. FETCH] ---- Result serialization, network transfer
    |             Observable: rows returned, bytes transferred, fetch time
    v
Client Response
```

### Execution Plan Analysis

#### Access Methods (from fastest to slowest, typically)

| Access Method | Description | Observable Via | Warning Sign |
|---------------|-------------|----------------|--------------|
| Index Only Scan | Data from index alone (covering index) | `EXPLAIN`, `pg_stat_user_indexes` | N/A (optimal) |
| Index Scan | Index lookup + heap fetch | `EXPLAIN`, index scan counters | Check selectivity |
| Bitmap Index Scan | Multiple index ranges -> bitmap -> heap | `EXPLAIN` | Many rows from index |
| Sequential Scan | Full table scan | `EXPLAIN`, `pg_stat_user_tables.seq_scan` | On tables > 10K rows |

#### Join Strategies

| Join Type | Best For | Observable Cost | Warning Sign |
|-----------|----------|-----------------|--------------|
| Nested Loop | Small outer table, indexed inner | O(N * index_lookup) | Outer table unexpectedly large |
| Hash Join | Medium-to-large unsorted tables | O(N + M) + memory for hash table | Hash spilling to disk (temp files) |
| Merge Join | Pre-sorted inputs | O(N + M) if sorted | Sort cost dominates when not pre-sorted |

#### PostgreSQL: Capturing Execution Plans

```sql
-- One-time analysis
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT o.id, o.total, u.name
FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.created_at > '2025-01-01';

-- Automated: auto_explain extension
-- postgresql.conf
shared_preload_libraries = 'auto_explain'
auto_explain.log_min_duration = '100ms'    -- Log plans for queries > 100ms
auto_explain.log_analyze = true             -- Include actual row counts
auto_explain.log_buffers = true             -- Include buffer usage
auto_explain.log_format = 'json'            -- Machine-parseable
auto_explain.log_nested_statements = true   -- Include queries inside functions
auto_explain.sample_rate = 0.1              -- Sample 10% of qualifying queries
```

#### MySQL: Capturing Execution Plans

```sql
-- One-time analysis
EXPLAIN ANALYZE
SELECT o.id, o.total, u.name
FROM orders o JOIN users u ON o.user_id = u.id
WHERE o.created_at > '2025-01-01';

-- Automated: performance_schema
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME = 'events_statements_history_long';

-- Query plan via events_statements_summary_by_digest
SELECT DIGEST_TEXT, COUNT_STAR, AVG_TIMER_WAIT/1000000000 as avg_ms,
       SUM_ROWS_EXAMINED, SUM_ROWS_SENT
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 20;
```

---

## 8. Query Plan Regression Detection

### What Is a Query Plan Regression?

A query plan regression occurs when the database optimizer selects a different (worse) execution plan for a previously-fast query. Common triggers:

- Statistics update after bulk data load
- Index creation or deletion
- PostgreSQL `ANALYZE` or MySQL `ANALYZE TABLE`
- Table growth crossing optimizer cost thresholds
- Parameter value changes (parameterized query with skewed distribution)

### Detection Approaches

#### Approach 1: pg_stat_statements Baseline Comparison

```sql
-- Capture baseline metrics periodically
CREATE TABLE query_plan_baseline AS
SELECT queryid, query, calls, mean_exec_time, stddev_exec_time,
       rows, shared_blks_hit, shared_blks_read,
       now() as captured_at
FROM pg_stat_statements
WHERE calls > 100;  -- Only frequently-executed queries

-- Detect regressions: queries whose mean_exec_time increased > 2x
SELECT b.queryid,
       b.query,
       b.mean_exec_time as baseline_ms,
       c.mean_exec_time as current_ms,
       c.mean_exec_time / NULLIF(b.mean_exec_time, 0) as regression_factor
FROM query_plan_baseline b
JOIN pg_stat_statements c ON b.queryid = c.queryid
WHERE c.mean_exec_time > b.mean_exec_time * 2
  AND c.calls > 50
ORDER BY regression_factor DESC;
```

#### Approach 2: Prometheus-Based Regression Alert

```yaml
# Alert on query duration regression (using OTel db.client.operation.duration)
groups:
  - name: database_query_regression
    rules:
      - alert: QueryPerformanceRegression
        expr: |
          (
            histogram_quantile(0.95, sum(rate(db_client_operation_duration_seconds_bucket[1h])) by (le, db_namespace, db_operation_name, db_collection_name))
            /
            histogram_quantile(0.95, sum(rate(db_client_operation_duration_seconds_bucket[1h] offset 1d)) by (le, db_namespace, db_operation_name, db_collection_name))
          ) > 3
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Query performance regression detected"
          description: "{{ $labels.db_operation_name }} {{ $labels.db_collection_name }} p95 latency increased >3x vs 24h ago"
```

#### Approach 3: Azure SQL Automatic Plan Correction

Azure SQL Database provides automatic tuning that detects plan regressions and forces the last known good plan:

```sql
-- Enable automatic plan correction
ALTER DATABASE current SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);

-- Monitor forced plans
SELECT reason, score, state_desc, script
FROM sys.dm_db_tuning_recommendations
WHERE type = 'FORCE_LAST_GOOD_PLAN';
```

---

## 9. N+1 Query Detection via Distributed Tracing

### What Is the N+1 Problem?

The N+1 query problem occurs when application code executes 1 query to fetch a list of N items, then N additional queries to fetch related data for each item individually, instead of a single JOIN or IN query.

### Detection via OpenTelemetry Traces

When database auto-instrumentation is active, an N+1 pattern produces a distinctive trace shape:

```
Trace: GET /api/orders (250ms total)
├── Span: SELECT orders (db)         5ms    ← The "1" query
├── Span: SELECT users (db)          2ms    ← N query #1
├── Span: SELECT users (db)          2ms    ← N query #2
├── Span: SELECT users (db)          3ms    ← N query #3
├── Span: SELECT users (db)          2ms    ← N query #4
├── ... (46 more identical spans)
└── Span: SELECT users (db)          2ms    ← N query #50
```

**Visual indicators in trace UI**:
- Parent span contains many child spans with the same `db.collection.name`
- Child spans have identical `db.operation.name` and similar `db.query.text`
- Cumulative child span duration is a large fraction of parent duration

### Automated N+1 Detection

#### Method 1: OTel Collector Span Processor (Count Child Spans)

```yaml
processors:
  # Use the span processor to add child span count
  transform/n_plus_one:
    trace_statements:
      - context: span
        statements:
          # Tag spans that might indicate N+1 (requires custom logic)
          - set(attributes["db.query.repeated"], "true")
            where attributes["db.collection.name"] != nil
```

#### Method 2: Backend Query (Jaeger/Tempo)

```
# TraceQL query in Grafana Tempo to find N+1 patterns
{ span.db.system.name != nil } | count() > 20 | by(resource.service.name)
```

#### Method 3: Application-Level Detection

```python
# Python: Detect N+1 at the ORM level with SQLAlchemy events
from sqlalchemy import event

class NPlusOneDetector:
    def __init__(self, threshold=10):
        self.threshold = threshold
        self.query_counts = {}

    def before_cursor_execute(self, conn, cursor, statement, parameters, context, executemany):
        # Normalize query (remove parameters)
        normalized = self._normalize(statement)
        self.query_counts[normalized] = self.query_counts.get(normalized, 0) + 1

        if self.query_counts[normalized] == self.threshold:
            import warnings
            warnings.warn(
                f"N+1 detected: '{normalized}' executed {self.threshold}+ times in this request",
                stacklevel=2
            )

    def _normalize(self, statement):
        import re
        return re.sub(r"'[^']*'|\b\d+\b", "?", statement)

detector = NPlusOneDetector()
event.listen(engine, "before_cursor_execute", detector.before_cursor_execute)
```

### Resolution Patterns

| Pattern | Before (N+1) | After (Optimized) |
|---------|--------------|-------------------|
| Eager Loading | `orders.each { |o| o.user }` | `Order.includes(:user).all` |
| Batch Loading | N individual SELECTs | `SELECT * FROM users WHERE id IN (...)` |
| JOIN | Separate queries | `SELECT o.*, u.* FROM orders o JOIN users u ON ...` |
| DataLoader | Per-item resolution | Batched resolution per frame |

---

## 10. Slow Query Analysis Workflow

### Phase 1: Identification

```sql
-- PostgreSQL: Find slowest queries
SELECT queryid, query, calls,
       mean_exec_time as avg_ms,
       max_exec_time as max_ms,
       total_exec_time as total_ms,
       rows,
       shared_blks_hit + shared_blks_read as total_blocks,
       CASE WHEN shared_blks_hit + shared_blks_read > 0
            THEN shared_blks_hit::float / (shared_blks_hit + shared_blks_read) * 100
            ELSE 100 END as cache_hit_pct
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- MySQL: Slow query log analysis
-- Enable in my.cnf:
-- slow_query_log = 1
-- long_query_time = 0.1
-- log_slow_extra = ON

-- Or query performance_schema:
SELECT DIGEST_TEXT, COUNT_STAR,
       ROUND(AVG_TIMER_WAIT/1000000000, 2) as avg_ms,
       ROUND(MAX_TIMER_WAIT/1000000000, 2) as max_ms,
       SUM_ROWS_EXAMINED, SUM_ROWS_SENT,
       ROUND(SUM_ROWS_EXAMINED/NULLIF(SUM_ROWS_SENT,0), 1) as examine_to_send_ratio
FROM performance_schema.events_statements_summary_by_digest
ORDER BY AVG_TIMER_WAIT DESC
LIMIT 20;
```

### Phase 2: Profiling

```sql
-- PostgreSQL: Detailed execution plan
EXPLAIN (ANALYZE, BUFFERS, TIMING, VERBOSE, FORMAT JSON)
<slow_query_here>;

-- Key indicators in the plan:
-- "Actual Rows" >> "Plan Rows" → stale statistics, run ANALYZE
-- "Seq Scan" on large table → missing index
-- "Sort Method: external merge" → work_mem too low
-- "Buffers: read" >> "Buffers: hit" → cold cache or table too large for memory

-- MySQL: Query profiling
SET profiling = 1;
<slow_query_here>;
SHOW PROFILE ALL FOR QUERY 1;
-- Shows time in: starting, checking permissions, Opening tables,
-- init, System lock, optimizing, executing, Sending data, end
```

### Phase 3: Optimization Decision Tree

```
Is the query doing a Sequential Scan on a large table?
├── YES → Does a WHERE clause filter significantly?
│         ├── YES → Create a targeted index
│         └── NO  → Consider partitioning or materialized view
└── NO  → Is it doing many Nested Loops?
          ├── YES → Is the outer table large?
          │         ├── YES → Add index on join column; consider hash join (increase work_mem)
          │         └── NO  → Check if inner table index is being used
          └── NO  → Is Sort/Hash spilling to disk?
                    ├── YES → Increase work_mem / sort_buffer_size
                    └── NO  → Check lock waits, I/O waits, network latency
```

### Phase 4: Verification

```sql
-- PostgreSQL: Compare before/after via pg_stat_statements
SELECT queryid, query,
       calls as call_count,
       mean_exec_time as avg_ms_after,
       -- Compare with baseline captured before optimization
       100 * (1 - mean_exec_time / NULLIF(baseline.mean_exec_time, 0)) as improvement_pct
FROM pg_stat_statements s
JOIN query_plan_baseline baseline USING (queryid)
WHERE s.calls > 10;
```

---

## 11. Query Tagging and Fingerprinting

### PostgreSQL: pg_stat_statements

```sql
-- queryid is a hash of the normalized query text
SELECT queryid, query, calls, mean_exec_time
FROM pg_stat_statements
WHERE queryid = 1234567890;  -- Stable across parameter values

-- Normalized form:
-- SELECT * FROM orders WHERE user_id = $1 AND status = $2
-- Regardless of actual parameter values
```

### MySQL: Query Digest

```sql
-- DIGEST is a SHA-256 hash of the normalized statement
SELECT DIGEST, DIGEST_TEXT, COUNT_STAR, AVG_TIMER_WAIT
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST = 'abc123...';

-- DIGEST_TEXT shows normalized form:
-- SELECT * FROM `orders` WHERE `user_id` = ? AND `status` = ?
```

### SQL Server: Query Hash and Plan Hash

```sql
-- query_hash groups logically identical queries
-- query_plan_hash groups queries with identical execution plans
SELECT query_hash, query_plan_hash,
       execution_count,
       total_elapsed_time / execution_count as avg_elapsed_us,
       total_logical_reads / execution_count as avg_reads
FROM sys.dm_exec_query_stats
ORDER BY total_elapsed_time DESC;
```

### Application-Level Query Tagging

```sql
-- Tag queries with application context via SQL comments
/* service:order-service, endpoint:/api/orders, version:2.1.0 */
SELECT * FROM orders WHERE status = 'pending';

-- PostgreSQL: pg_stat_activity shows the comment
-- Tools like pganalyze, Datadog, pgBadger can group by tag
```

---

## 12. APM Integration and Real-Time Monitoring

### Linking Application Code to Database Queries

APM tools provide the critical link between a slow database query and the application code that generated it. This works through the distributed trace:

```
HTTP Span: GET /api/orders (service: order-service)
  └── Application Span: OrderService.getRecentOrders()
        └── DB Span: SELECT orders (postgresql)
              db.query.text: SELECT o.* FROM orders o WHERE o.created_at > ? ORDER BY o.created_at DESC LIMIT ?
              db.client.operation.duration: 1.2s     ← Slow!

              // From the trace, you know:
              // 1. Which service triggered this query
              // 2. Which method/function called it
              // 3. The exact query text
              // 4. How long it took
              // 5. What the upstream HTTP request was
```

### Real-Time vs Historical Monitoring

| Capability | Real-Time | Historical |
|------------|-----------|------------|
| **Source** | `pg_stat_activity`, `SHOW PROCESSLIST` | `pg_stat_statements`, `performance_schema` |
| **Latency** | Sub-second | Minutes to hours |
| **Use Case** | Active incidents, blocking queries | Trend analysis, capacity planning |
| **Query Detail** | Full query text with parameters | Normalized/fingerprinted queries |
| **Overhead** | Very low (system views) | Low (background statistics) |
| **Retention** | Current moment only | Configurable (reset on restart by default) |

### Real-Time Monitoring Queries

```sql
-- PostgreSQL: Currently running queries
SELECT pid, now() - query_start as duration, state,
       wait_event_type, wait_event, query
FROM pg_stat_activity
WHERE state != 'idle'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;

-- PostgreSQL: Current lock waits
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       blocking.pid AS blocking_pid,
       blocking.query AS blocking_query,
       now() - blocked.query_start AS wait_duration
FROM pg_stat_activity blocked
JOIN pg_locks bl ON bl.pid = blocked.pid
JOIN pg_locks lo ON lo.locktype = bl.locktype
  AND lo.database IS NOT DISTINCT FROM bl.database
  AND lo.relation IS NOT DISTINCT FROM bl.relation
  AND lo.page IS NOT DISTINCT FROM bl.page
  AND lo.tuple IS NOT DISTINCT FROM bl.tuple
  AND lo.transactionid IS NOT DISTINCT FROM bl.transactionid
  AND lo.pid != bl.pid
JOIN pg_stat_activity blocking ON blocking.pid = lo.pid
WHERE NOT bl.granted;

-- MySQL: Currently running queries
SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE, INFO
FROM INFORMATION_SCHEMA.PROCESSLIST
WHERE COMMAND != 'Sleep' AND TIME > 1
ORDER BY TIME DESC;
```

---

## Part III: Connection Pool Observability

---

## 13. Connection Pool Metrics and Sizing

### Core Connection Pool Metrics

| Metric | Description | Healthy Range |
|--------|-------------|---------------|
| **Active connections** | Connections currently executing queries | < 80% of max |
| **Idle connections** | Connections in pool, available | > 20% of max |
| **Waiting threads** | Threads waiting for a connection | 0 (ideally) |
| **Max pool size** | Configured maximum | Tuned per workload |
| **Min pool size** | Configured minimum idle | Prevents cold-start latency |
| **Connection timeout rate** | Acquisition failures | 0 (any is concerning) |
| **Acquisition time** | Time to get a connection from pool | < 10ms (p99) |
| **Connection creation time** | Time to establish new connection | 50-500ms (depends on TLS, network) |
| **Connection lifetime** | How long connections are reused | 30min-1h typical max |

### Connection Pool Sizing with Little's Law

**Little's Law**: `L = lambda * W`

Applied to connection pools:
```
Required Pool Size = Average Concurrent Queries = Request Rate * Average Query Duration

Example:
  Request rate: 200 queries/second
  Average query duration: 15ms = 0.015s

  Pool Size = 200 * 0.015 = 3 connections (average)

  With safety margin for variance (p99 latency, bursts):
  Recommended Pool Size = 3 * 3 = ~10 connections
```

**HikariCP's formula** (widely cited):
```
Pool Size = Tn * (Cm - 1) + 1

Where:
  Tn = Number of simultaneous threads executing queries
  Cm = Number of simultaneous connections per transaction

  Typically Cm = 1, so Pool Size ≈ Tn
```

**PostgreSQL rule of thumb**:
```
max_connections = 100-300 (default: 100)
Each connection consumes ~10MB RAM

For a 16-core server:
  Optimal pool per application ≈ (2 * num_cores) + effective_spindle_count
  = (2 * 16) + 4 = 36 connections

  Distribute across application instances:
  If 4 app instances: 36 / 4 = 9 connections per pool
```

---

## 14. HikariCP Monitoring (Java)

### Key Metrics

HikariCP (the default Spring Boot connection pool) exposes metrics via Micrometer, which maps directly to OTel:

| HikariCP Metric | OTel Equivalent | Description |
|-----------------|-----------------|-------------|
| `hikaricp.connections.active` | `db.client.connection.count{state=used}` | Currently borrowed connections |
| `hikaricp.connections.idle` | `db.client.connection.count{state=idle}` | Available connections in pool |
| `hikaricp.connections.pending` | `db.client.connection.pending_requests` | Threads waiting for connection |
| `hikaricp.connections.max` | `db.client.connection.max` | Configured maximum pool size |
| `hikaricp.connections.min` | `db.client.connection.idle.min` | Configured minimum idle |
| `hikaricp.connections.timeout` | `db.client.connection.timeouts` | Connection acquisition timeouts |
| `hikaricp.connections.acquire` | `db.client.connection.wait_time` | Connection acquisition time histogram |
| `hikaricp.connections.creation` | `db.client.connection.create_time` | New connection creation time |
| `hikaricp.connections.usage` | `db.client.connection.use_time` | Time between borrow and return |

### Spring Boot Configuration with Metrics

```yaml
# application.yml
spring:
  datasource:
    hikari:
      pool-name: OrderServicePool
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000     # 30s max wait for connection
      idle-timeout: 600000          # 10min max idle time
      max-lifetime: 1800000         # 30min max connection lifetime
      leak-detection-threshold: 60000  # Log warning if connection held > 60s
      register-mbeans: true         # Enable JMX monitoring

management:
  metrics:
    export:
      otlp:
        enabled: true
        endpoint: http://otel-collector:4318/v1/metrics
    tags:
      service: order-service
      environment: production
```

### Alerting Rules for HikariCP

```yaml
groups:
  - name: hikaricp_alerts
    rules:
      - alert: ConnectionPoolExhaustion
        expr: |
          hikaricp_connections_active / hikaricp_connections_max > 0.9
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "HikariCP pool {{ $labels.pool }} at {{ $value | humanizePercentage }} capacity"

      - alert: ConnectionPoolWaiters
        expr: |
          hikaricp_connections_pending > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "{{ $value }} threads waiting for connection from pool {{ $labels.pool }}"

      - alert: ConnectionAcquisitionSlow
        expr: |
          histogram_quantile(0.99, rate(hikaricp_connections_acquire_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "p99 connection acquisition time > 1s for pool {{ $labels.pool }}"

      - alert: ConnectionLeakSuspected
        expr: |
          histogram_quantile(0.99, rate(hikaricp_connections_usage_seconds_bucket[5m])) > 300
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Connections held > 5min (p99) from pool {{ $labels.pool }} - possible leak"
```

---

## 15. PgBouncer Monitoring

### Pooling Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Session** | Client gets dedicated server connection for entire session | Legacy apps using prepared statements, LISTEN/NOTIFY |
| **Transaction** | Client gets server connection for each transaction | Most web applications (recommended default) |
| **Statement** | Client gets server connection per statement | Simple read-heavy workloads (no multi-statement transactions) |

### Key Metrics (from SHOW POOLS / SHOW STATS)

| Metric | Source | Description | Alert Threshold |
|--------|--------|-------------|-----------------|
| `cl_active` | SHOW POOLS | Active client connections | Monitor for trends |
| `cl_waiting` | SHOW POOLS | Clients waiting for server connection | > 0 sustained |
| `sv_active` | SHOW POOLS | Server connections executing queries | < pool_size |
| `sv_idle` | SHOW POOLS | Idle server connections | > 0 (headroom) |
| `sv_used` | SHOW POOLS | Recently used server connections (not yet idle) | Monitor |
| `sv_login` | SHOW POOLS | Server connections in login phase | > 0 sustained = slow backend |
| `avg_query_time` | SHOW STATS | Average query duration (microseconds) | Baseline + 2 stddev |
| `avg_xact_time` | SHOW STATS | Average transaction duration | Baseline + 2 stddev |
| `avg_wait_time` | SHOW STATS | Average time client waited for connection | > 100ms |
| `total_query_count` | SHOW STATS | Total queries processed | Throughput baseline |
| `total_xact_count` | SHOW STATS | Total transactions processed | Throughput baseline |

### PgBouncer Configuration for Observability

```ini
; pgbouncer.ini
[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 50
max_user_connections = 50

; Observability settings
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
stats_period = 60

; Admin access for SHOW commands
admin_users = pgbouncer_admin
stats_users = pgbouncer_stats

; Prometheus-compatible metrics (via pgbouncer_exporter)
; Deploy prometheus-community/pgbouncer_exporter alongside
```

### Prometheus pgbouncer_exporter Metrics

```yaml
# Key metrics exposed by pgbouncer_exporter
pgbouncer_pools_client_active_connections     # cl_active
pgbouncer_pools_client_waiting_connections     # cl_waiting
pgbouncer_pools_server_active_connections      # sv_active
pgbouncer_pools_server_idle_connections        # sv_idle
pgbouncer_stats_queries_duration_seconds_total # Total query time
pgbouncer_stats_queries_total                  # Total query count
pgbouncer_stats_transactions_duration_seconds_total
pgbouncer_stats_client_wait_seconds_total      # Total wait time
pgbouncer_databases_current_connections        # Per-database connections
pgbouncer_databases_max_connections            # Per-database limits
```

### PgBouncer Alerting

```yaml
groups:
  - name: pgbouncer_alerts
    rules:
      - alert: PgBouncerClientWaiting
        expr: pgbouncer_pools_client_waiting_connections > 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "{{ $value }} clients waiting for PgBouncer connection to {{ $labels.database }}"

      - alert: PgBouncerPoolSaturation
        expr: |
          pgbouncer_pools_server_active_connections
          / pgbouncer_databases_max_connections > 0.85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "PgBouncer server pool > 85% utilized for {{ $labels.database }}"

      - alert: PgBouncerHighWaitTime
        expr: |
          rate(pgbouncer_stats_client_wait_seconds_total[5m])
          / rate(pgbouncer_stats_transactions_total[5m]) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Average client wait time > 100ms for {{ $labels.database }}"
```

---

## 16. ProxySQL Monitoring

### Architecture

ProxySQL is a MySQL-aware proxy providing connection multiplexing, query routing (read/write splitting), query caching, and query mirroring. It exposes metrics via its internal stats database and a built-in Prometheus endpoint (v2.1+).

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `proxysql.pool.connections_used` | Backend connections in use | > 80% of max |
| `proxysql.pool.connections_free` | Available backend connections | < 20% of max |
| `proxysql.pool.queries` | Queries routed to each backend | Monitor distribution |
| `proxysql.pool.latency_us` | Backend connection latency | > 1000us = slow backend |
| `proxysql.slow_queries` | Slow queries per second | > 0 sustained |
| `proxysql.questions` | Total queries processed | Throughput baseline |
| `proxysql.query_cache.entries` | Cached query count | Monitor hit rate |
| `proxysql.query_cache.memory` | Cache memory usage | < configured max |
| `proxysql.query_cache.get_ok` | Cache hits | Higher = better |
| `proxysql.query_cache.get_miss` | Cache misses | Monitor ratio |
| `proxysql.client.connections_created` | New client connections | Spike detection |
| `proxysql.client.connections_connected` | Active client connections | < max_connections |
| `proxysql.multiplexing_efficiency` | Ratio of frontend to backend connections | Higher = better multiplexing |

### Prometheus Endpoint Configuration

```sql
-- Enable Prometheus endpoint in ProxySQL admin
SET admin-restapi_enabled='true';
SET admin-restapi_port=6070;
LOAD ADMIN VARIABLES TO RUNTIME;
SAVE ADMIN VARIABLES TO DISK;

-- Metrics available at http://proxysql:6070/metrics
```

### ProxySQL Query Routing Observability

```sql
-- Monitor query routing rules effectiveness
SELECT rule_id, active, match_pattern, destination_hostgroup,
       hits, flagOUT
FROM stats_mysql_query_rules
ORDER BY hits DESC;

-- Monitor backend server health
SELECT hostgroup, srv_host, srv_port, status,
       Queries, Bytes_data_sent, Bytes_data_recv,
       Latency_us, ConnUsed, ConnFree, ConnOK, ConnERR
FROM stats_mysql_connection_pool
ORDER BY hostgroup, srv_host;

-- Cache hit rate
SELECT * FROM stats_mysql_query_cache;
```

---

## 17. Connection Leak Detection and Exhaustion Diagnosis

### Connection Leak Patterns

A connection leak occurs when application code borrows a connection from the pool but fails to return it (typically due to missing `close()` or exception handling that skips cleanup).

#### Detection Indicators

| Indicator | Metric | Pattern |
|-----------|--------|---------|
| Pool usage grows monotonically | `db.client.connection.count{state=used}` | Staircase pattern (up, never down) |
| Idle connections drop to zero | `db.client.connection.count{state=idle}` | Decreasing trend to 0 |
| Wait queue grows | `db.client.connection.pending_requests` | Increasing while active stays constant |
| Timeouts increase | `db.client.connection.timeouts` | Rate increases over time |
| Connection use time is extreme | `db.client.connection.use_time` | p99 >> normal (hours vs seconds) |

#### HikariCP Leak Detection

```yaml
# Enable leak detection (Java/Spring Boot)
spring:
  datasource:
    hikari:
      leak-detection-threshold: 60000  # 60 seconds
      # Logs stack trace of thread that borrowed the leaked connection
```

Output:
```
WARN  com.zaxxer.hikari.pool.ProxyLeakTask - Connection leak detection triggered for
  org.postgresql.jdbc.PgConnection@1a2b3c4d on thread http-nio-8080-exec-42,
  stack trace follows:
    java.lang.Exception: Apparent connection leak detected
    at com.example.OrderRepository.findOrders(OrderRepository.java:42)
    at com.example.OrderService.getOrders(OrderService.java:78)
```

#### PostgreSQL Server-Side Leak Detection

```sql
-- Find long-held idle connections (possible leaked connections)
SELECT pid, usename, application_name, client_addr,
       state, now() - state_change as idle_duration,
       now() - backend_start as connection_age,
       query
FROM pg_stat_activity
WHERE state = 'idle'
  AND now() - state_change > interval '10 minutes'
ORDER BY idle_duration DESC;

-- Set server-side idle timeout as safety net
-- postgresql.conf:
idle_in_transaction_session_timeout = '5min'  -- Kill idle-in-transaction
idle_session_timeout = '30min'                -- Kill idle sessions (PG 14+)
```

### Connection Exhaustion Diagnosis Workflow

```
Connection timeout errors occurring
│
├── Check pool metrics
│   ├── Active = Max? → Pool too small OR leak
│   │   ├── Connection use_time p99 very high? → LEAK (connections not returned)
│   │   └── Connection use_time p99 normal? → Pool size too small, increase max
│   └── Active < Max? → Issue is not pool exhaustion
│       ├── Check database side: max_connections reached?
│       └── Check network: connection creation failing?
│
├── Check database-side connections
│   ├── PostgreSQL: SELECT count(*) FROM pg_stat_activity;
│   ├── MySQL: SHOW STATUS LIKE 'Threads_connected';
│   └── Compare with max_connections setting
│
└── Check for idle-in-transaction connections
    └── PostgreSQL: SELECT * FROM pg_stat_activity WHERE state = 'idle in transaction';
    └── These hold locks and consume connection slots without doing work
```

---

## 18. Cloud Provider Connection Limits

### AWS RDS Connection Limits

| Instance Class | vCPU | RAM (GB) | Max Connections (PostgreSQL) | Max Connections (MySQL) |
|---------------|------|----------|------------------------------|------------------------|
| db.t3.micro | 2 | 1 | 112 | 150 |
| db.t3.small | 2 | 2 | 225 | 300 |
| db.t3.medium | 2 | 4 | 450 | 600 |
| db.r5.large | 2 | 16 | 1,600 | 2,500 |
| db.r5.xlarge | 4 | 32 | 3,200 | 5,000 |
| db.r5.2xlarge | 8 | 64 | 5,000 | 10,000 |
| db.r5.4xlarge | 16 | 128 | 5,000 | 20,000 |

**PostgreSQL formula**: `LEAST(DBInstanceClassMemory/9531392, 5000)`
**MySQL formula**: `LEAST(DBInstanceClassMemory/12582880, 16000)`

### Monitoring Cloud Connection Usage

```yaml
# CloudWatch alarm for RDS connections
Resources:
  DatabaseConnectionAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: rds-connection-high
      MetricName: DatabaseConnections
      Namespace: AWS/RDS
      Statistic: Average
      Period: 300
      EvaluationPeriods: 3
      Threshold: 80  # percentage of max
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: DBInstanceIdentifier
          Value: !Ref DBInstance
```

### Azure SQL DTU and vCore Connection Limits

| Tier | Max Concurrent Sessions | Max Concurrent Workers |
|------|------------------------|----------------------|
| Basic (5 DTU) | 300 | 30 |
| S0 (10 DTU) | 600 | 60 |
| S3 (100 DTU) | 1,200 | 200 |
| P1 (125 DTU) | 2,400 | 200 |
| P4 (500 DTU) | 7,200 | 400 |
| 4 vCores (Gen Purpose) | 7,200 | 1,200 |
| 8 vCores (Gen Purpose) | 7,200 | 2,400 |

### Google Cloud SQL Connection Limits

| Machine Type | Max Connections (PostgreSQL) | Max Connections (MySQL) |
|-------------|------------------------------|------------------------|
| db-f1-micro | 25 | 250 |
| db-g1-small | 50 | 1,000 |
| db-n1-standard-1 | 100 | 4,000 |
| db-n1-standard-4 | 400 | 4,000 |
| db-n1-standard-16 | 500 | 4,000 |
| db-n1-highmem-16 | 500 | 4,000 |

---

## Part IV: Database Reliability and Replication Observability

---

## 19. Replication Lag Monitoring

### Why Replication Lag Matters

Replication lag is the delay between a write on the primary and when that write is visible on replicas. It directly impacts:

- **Read-after-write consistency**: Users may not see their own writes if directed to a lagging replica
- **Failover data loss**: Lag at failover time = potential data loss (RPO violation)
- **Compliance**: Financial systems may require synchronous replication (zero lag tolerance)
- **Application correctness**: Stale reads from replicas can cause business logic errors

### PostgreSQL Replication Lag Monitoring

```sql
-- On the primary: check replication status
SELECT client_addr,
       application_name,
       state,
       sent_lsn,
       write_lsn,
       flush_lsn,
       replay_lsn,
       write_lag,
       flush_lag,
       replay_lag,
       pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes
FROM pg_stat_replication;

-- On the replica: check how far behind
SELECT CASE WHEN pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn()
            THEN 0
            ELSE EXTRACT(EPOCH FROM now() - pg_last_xact_replay_timestamp())
       END AS replication_lag_seconds;
```

### MySQL Replication Lag Monitoring

```sql
-- Check replica status
SHOW REPLICA STATUS\G

-- Key fields:
-- Seconds_Behind_Source: Estimated lag in seconds (can be misleading)
-- Relay_Log_Space: Size of unreplayed relay logs
-- Read_Source_Log_Pos vs Exec_Source_Log_Pos: Position lag

-- More accurate lag measurement with heartbeat tables:
-- pt-heartbeat (Percona Toolkit) writes timestamps to primary,
-- measures delay when read on replica
-- pt-heartbeat --update --database mydb --host primary
-- pt-heartbeat --monitor --database mydb --host replica
```

### MongoDB Replication Lag Monitoring

```javascript
// Check replica set status
rs.status()

// Key fields per member:
// optimeDate: Last oplog entry applied
// optimeDurable: Last oplog entry on durable storage
// lastHeartbeat: When this member was last reached
// lag = primary.optimeDate - secondary.optimeDate

// Programmatic monitoring
db.adminCommand({ replSetGetStatus: 1 }).members.forEach(m => {
    print(`${m.name}: state=${m.stateStr}, lag=${m.optimeDate ? (new Date() - m.optimeDate)/1000 : 'N/A'}s`)
})
```

### OTel Collector Replication Metrics

```yaml
# PostgreSQL receiver captures:
# postgresql.replication.data_delay (bytes behind)
# postgresql.wal.lag (seconds behind)

# MySQL receiver captures:
# mysql.replica.sql_delay (configured delay)
# mysql.replica.time_behind_source (actual lag)
```

### Alerting Thresholds by Workload

| Workload Type | Warning Threshold | Critical Threshold | Rationale |
|---------------|-------------------|--------------------|-----------|
| OLTP (e-commerce, banking) | > 1s | > 5s | Read-after-write consistency |
| Content/CMS | > 10s | > 60s | Eventual consistency acceptable |
| Analytics replica | > 5min | > 30min | Near-real-time reporting |
| Disaster recovery | > 1min | > 10min | RPO compliance |
| Cross-region async | > 30s | > 5min | Network latency included |

### Prometheus Alerting Rules

```yaml
groups:
  - name: replication_lag
    rules:
      - alert: PostgreSQLReplicationLagHigh
        expr: postgresql_replication_data_delay > 104857600  # 100MB
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL replication lag > 100MB on {{ $labels.instance }}"

      - alert: PostgreSQLReplicationLagCritical
        expr: postgresql_wal_lag > 10  # 10 seconds
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL WAL replay lag > 10s on {{ $labels.instance }}"

      - alert: MySQLReplicationBroken
        expr: mysql_replica_time_behind_source < 0 OR absent(mysql_replica_time_behind_source)
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MySQL replication is broken on {{ $labels.instance }}"

      - alert: MySQLReplicationLagHigh
        expr: mysql_replica_time_behind_source > 30
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MySQL replication lag > 30s on {{ $labels.instance }}"
```

---

## 20. Failover and Split-Brain Detection

### Failover Monitoring Metrics

| Phase | Metric | Target |
|-------|--------|--------|
| **Detection time** | Time from primary failure to detection | < 10s (automated health checks) |
| **Decision time** | Time from detection to failover decision | < 5s (automated) |
| **Promotion time** | Time to promote replica to primary | < 30s (PostgreSQL), < 10s (MySQL Group Replication) |
| **DNS/Routing update** | Time for clients to discover new primary | < 30s (DNS TTL), < 5s (proxy-based) |
| **Total failover duration** | End-to-end | < 60s (target for most systems) |
| **Data loss window** | Unreplicated transactions at failover | 0 for sync replication, lag-dependent for async |

### Split-Brain Detection

Split-brain occurs when multiple nodes believe they are the primary, accepting writes independently. This causes data divergence and corruption.

#### Detection Patterns

```yaml
# Alert: Multiple nodes claiming primary role
groups:
  - name: split_brain
    rules:
      - alert: PostgreSQLSplitBrainDetected
        expr: count(pg_replication_is_replica == 0) > 1
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "SPLIT BRAIN: {{ $value }} PostgreSQL nodes are in primary mode"

      - alert: MySQLMultiPrimary
        expr: count(mysql_global_status_read_only == 0) > 1
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "SPLIT BRAIN: {{ $value }} MySQL nodes are writable"
```

#### Prevention Mechanisms to Monitor

| Mechanism | Database | What to Monitor |
|-----------|----------|-----------------|
| Fencing (STONITH) | PostgreSQL (Patroni) | Fencing operations count, success rate |
| Quorum-based voting | MySQL Group Replication | `group_replication_members` status |
| Witness/arbitrator | MongoDB | Arbiter node health, election events |
| Distributed lock | All (etcd, ZooKeeper) | Lock acquisition time, lease TTL |

---

## 21. Consensus Protocol Monitoring

### Raft-Based Systems (etcd, CockroachDB, TiKV)

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `raft.leader.changes` | Number of leader elections | > 3 per hour |
| `raft.term` | Current Raft term (monotonically increasing) | Unexpected jumps |
| `raft.applied_index` | Last applied log index | Lag between leader and followers |
| `raft.commit_index` | Last committed log index | Should match leader |
| `raft.proposals.committed` | Rate of committed proposals | Baseline variance |
| `raft.proposals.failed` | Failed proposals | > 0 sustained |
| `raft.network.round_trip` | Inter-node network latency | > 50ms for same-region |
| `raft.snapshot.count` | Snapshots taken for slow followers | Increasing = follower cannot keep up |

### MySQL Group Replication

```sql
-- Monitor group replication status
SELECT MEMBER_HOST, MEMBER_PORT, MEMBER_STATE, MEMBER_ROLE
FROM performance_schema.replication_group_members;

-- States: ONLINE, RECOVERING, OFFLINE, ERROR, UNREACHABLE
-- Roles: PRIMARY, SECONDARY

-- Monitor transaction flow
SELECT COUNT_TRANSACTIONS_IN_QUEUE,
       COUNT_TRANSACTIONS_CHECKED,
       COUNT_CONFLICTS_DETECTED,
       COUNT_TRANSACTIONS_ROWS_VALIDATING,
       LAST_CONFLICT_FREE_TRANSACTION
FROM performance_schema.replication_group_member_stats;
```

### MongoDB Replica Set Elections

```javascript
// Monitor election events
db.adminCommand({ replSetGetStatus: 1 })

// Key fields:
// electionCandidateMetrics.lastElectionDate
// electionCandidateMetrics.electionTerm
// electionCandidateMetrics.numCatchUpOps
// electionCandidateMetrics.priorityAtElection

// OTel MongoDB receiver captures:
// mongodb.operation.repl.count (replication operations)
```

---

## 22. Backup and WAL Monitoring

### Backup Monitoring Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| **Last successful backup time** | Timestamp of most recent completed backup | > 24h ago (daily), > 1h (hourly) |
| **Backup duration** | Time to complete backup | > 2x baseline |
| **Backup size** | Size of completed backup | Deviation > 20% from trend |
| **Backup size growth rate** | Week-over-week size change | Unexpected spike = data growth |
| **Point-in-time recovery window** | Oldest restorable point | < RPO requirement |
| **Backup verification status** | Last restore test result | Any failure |
| **WAL archival lag** | Time since last WAL segment archived | > 5min |

### PostgreSQL WAL Monitoring

```sql
-- WAL generation rate
SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') AS total_wal_bytes;

-- WAL archival status
SELECT archived_count, failed_count,
       last_archived_wal, last_archived_time,
       last_failed_wal, last_failed_time
FROM pg_stat_archiver;

-- WAL directory size
SELECT count(*) AS wal_files,
       sum(size) AS wal_size_bytes
FROM pg_ls_waldir();

-- Checkpoint status (affects WAL retention)
SELECT checkpoints_timed, checkpoints_req,
       checkpoint_write_time, checkpoint_sync_time,
       buffers_checkpoint, buffers_clean, buffers_backend
FROM pg_stat_bgwriter;
```

### MySQL Binary Log Monitoring

```sql
-- Binary log status
SHOW BINARY LOGS;
-- Shows log name, size, and encryption status

-- Current binlog position
SHOW MASTER STATUS;

-- Binary log space usage
SELECT SUM(FILE_SIZE) AS total_binlog_bytes
FROM performance_schema.binary_log_status;

-- Binlog event monitoring
SHOW BINLOG EVENTS IN 'mysql-bin.000042' LIMIT 10;
```

### Backup Monitoring Alerting

```yaml
groups:
  - name: backup_monitoring
    rules:
      - alert: BackupStale
        expr: time() - last_successful_backup_timestamp > 86400  # 24 hours
        for: 30m
        labels:
          severity: critical
        annotations:
          summary: "No successful backup in > 24h for {{ $labels.instance }}"

      - alert: WALArchivalFailing
        expr: pg_stat_archiver_failed_count > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "WAL archival failures detected on {{ $labels.instance }}"

      - alert: WALDiskSpaceHigh
        expr: postgresql_wal_age > 3600  # Oldest WAL > 1 hour old
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Old WAL files accumulating on {{ $labels.instance }}, check archival"

      - alert: BackupSizeAnomaly
        expr: |
          abs(last_backup_size_bytes - avg_over_time(last_backup_size_bytes[7d]))
          / avg_over_time(last_backup_size_bytes[7d]) > 0.3
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Backup size for {{ $labels.instance }} deviates > 30% from 7d average"
```

---

## 23. Database Chaos Engineering

### Fault Injection Categories

| Fault Type | Tools | What to Observe |
|-----------|-------|-----------------|
| Primary failure | Kill process, network partition | Failover time, data loss, client errors |
| Replica failure | Kill process | Read routing adjustment, degraded reads |
| Network latency injection | tc netem, Toxiproxy | Query timeout rate, connection pool behavior |
| Disk full | fallocate to fill disk | WAL archival failure, write errors, recovery |
| High CPU on DB host | stress-ng | Query latency increase, connection queue growth |
| Connection flood | pgbench -c 500 | Pool exhaustion handling, error responses |
| Long-running transaction | BEGIN; SELECT pg_sleep(3600); | Lock contention, bloat, replication lag |
| Corrupted replica | Modify data files | Replication divergence detection |

### Chaos Engineering with Toxiproxy

```yaml
# Toxiproxy configuration: simulate database failures for testing
# toxiproxy-server runs as a proxy between app and database

# Create proxy
toxiproxy-cli create pg_primary -l 0.0.0.0:25432 -u pg-primary:5432

# Add latency (simulate slow network)
toxiproxy-cli toxic add pg_primary -t latency -a latency=200 -a jitter=50

# Simulate connection drops (50% of connections)
toxiproxy-cli toxic add pg_primary -t reset_peer -a timeout=500

# Simulate bandwidth limit (slow queries)
toxiproxy-cli toxic add pg_primary -t bandwidth -a rate=1024  # 1KB/s

# Simulate complete outage
toxiproxy-cli toggle pg_primary
```

### Observability During Chaos Tests

| Phase | What to Measure | Expected Behavior |
|-------|-----------------|-------------------|
| Steady state | Baseline latency, throughput, error rate | Within SLO |
| Fault injection | Alert firing time, detection latency | Alerts fire within threshold |
| During fault | Error rate, degraded response quality | Graceful degradation (circuit breaker, fallback) |
| Recovery | Recovery time, data consistency | Full recovery < RTO |
| Post-recovery | Baseline return, no data loss | Metrics return to steady state |

---

## Part V: Database Security Observability

---

## 24. Audit Logging and Access Monitoring

### What to Audit

| Event Category | Examples | Compliance Driver |
|----------------|----------|-------------------|
| **Authentication** | Login success/failure, password changes | All (PCI, HIPAA, SOX, GDPR) |
| **Authorization** | GRANT/REVOKE, role changes, privilege escalation | SOX, PCI-DSS |
| **Data access** | SELECT on sensitive tables, row-level access | HIPAA, GDPR, PCI-DSS |
| **Data modification** | INSERT/UPDATE/DELETE on sensitive tables | All |
| **Schema changes** | CREATE/ALTER/DROP TABLE, index changes | SOX, Change management |
| **Administrative** | Configuration changes, backup/restore, user management | All |

### PostgreSQL Audit Configuration (pgAudit)

```sql
-- Install pgAudit extension
CREATE EXTENSION pgaudit;

-- postgresql.conf settings
shared_preload_libraries = 'pgaudit'
pgaudit.log = 'write, ddl, role'        -- Log writes, DDL, role changes
pgaudit.log_catalog = off                -- Skip system catalog queries
pgaudit.log_client = on                  -- Include client info
pgaudit.log_level = log                  -- Log level
pgaudit.log_parameter = off              -- Don't log parameter values (PII risk)
pgaudit.log_statement_once = on          -- Log statement text only once per statement

-- Object-level auditing for sensitive tables
pgaudit.role = 'auditor'
GRANT SELECT ON customers TO auditor;    -- Now all SELECTs on customers are audited
GRANT ALL ON payment_methods TO auditor; -- All operations on payment_methods audited
```

**Log output format**:
```
AUDIT: SESSION,1,1,READ,SELECT,TABLE,public.customers,SELECT id, name, email FROM customers WHERE id = $1
AUDIT: SESSION,2,1,WRITE,UPDATE,TABLE,public.orders,UPDATE orders SET status = $1 WHERE id = $2
AUDIT: SESSION,3,1,DDL,ALTER TABLE,TABLE,public.users,ALTER TABLE users ADD COLUMN phone varchar(20)
```

### MySQL Enterprise Audit

```sql
-- Install audit plugin
INSTALL PLUGIN audit_log SONAME 'audit_log.so';

-- Configure audit filtering
SET GLOBAL audit_log_policy = 'ALL';
SET GLOBAL audit_log_format = 'JSON';

-- Filter specific events
SELECT audit_log_filter_set_filter('log_writes',
  '{ "filter": { "class": { "name": "table_access", "event": { "name": ["insert", "update", "delete"] } } } }');
```

### Collecting Audit Logs with OTel Collector

```yaml
receivers:
  filelog/pg_audit:
    include:
      - /var/log/postgresql/postgresql-*.log
    operators:
      - type: regex_parser
        regex: 'AUDIT: (?P<audit_type>\w+),(?P<statement_id>\d+),(?P<substatement_id>\d+),(?P<class>\w+),(?P<command>\w+\s?\w*),(?P<object_type>\w+),(?P<object_name>[\w.]+),(?P<statement>.+)'
      - type: severity_parser
        parse_from: attributes.class
        mapping:
          warn: WRITE
          info: READ
          error: DDL

processors:
  attributes/audit:
    actions:
      - key: log.type
        value: database_audit
        action: insert
      - key: db.system.name
        value: postgresql
        action: insert

exporters:
  otlp:
    endpoint: ${env:OTLP_ENDPOINT}

service:
  pipelines:
    logs/audit:
      receivers: [filelog/pg_audit]
      processors: [attributes/audit]
      exporters: [otlp]
```

---

## 25. Anomalous Query and SQL Injection Detection

### SQL Injection Indicators in Database Logs

| Pattern | Example | Detection Method |
|---------|---------|-----------------|
| UNION-based injection | `SELECT ... UNION SELECT password FROM users` | Regex on query logs: `UNION\s+SELECT` in unexpected context |
| Tautology attack | `WHERE 1=1 OR 'a'='a'` | Always-true conditions in WHERE clauses |
| Comment-based evasion | `admin'--` | Comment sequences (`--`, `/**/`, `#`) in string literals |
| Stacked queries | `; DROP TABLE users; --` | Multiple statements in single execution |
| Time-based blind injection | `SLEEP(5)`, `pg_sleep(5)`, `WAITFOR DELAY` | Unusual sleep/delay functions in queries |
| Error-based extraction | Deliberate type errors to extract data | High rate of syntax/type errors from single source |

### Detection Queries

```sql
-- PostgreSQL: Find suspicious query patterns in pg_stat_statements
SELECT query, calls, total_exec_time, mean_exec_time
FROM pg_stat_statements
WHERE query ~* 'UNION\s+SELECT'
   OR query ~* 'OR\s+1\s*=\s*1'
   OR query ~* 'pg_sleep'
   OR query ~* 'information_schema'
   OR query ~* ';.*DROP\s+TABLE'
   OR query ~* 'LOAD_FILE|INTO\s+OUTFILE'
ORDER BY calls DESC;

-- PostgreSQL: Unusual access patterns (user accessing tables they normally don't)
SELECT usename, datname, query, calls
FROM pg_stat_statements s
JOIN pg_user u ON s.userid = u.usesysid
WHERE query LIKE '%sensitive_table%'
  AND usename NOT IN ('app_service', 'admin');
```

### Azure SQL Advanced Threat Protection

Azure SQL Database provides built-in anomaly detection:

```sql
-- View threat detection alerts
SELECT * FROM sys.event_log
WHERE event_type = 'sql_injection'
   OR event_type = 'sql_injection_vulnerability'
ORDER BY start_time DESC;

-- Detects:
-- SQL injection attempts
-- Anomalous client login patterns
-- Access from unusual locations
-- Access from potentially harmful applications
-- Brute force SQL credentials
```

### Building a Query Anomaly Baseline

```yaml
# Prometheus recording rules for query anomaly detection
groups:
  - name: query_anomaly_baseline
    rules:
      # Record hourly query rate baseline per service
      - record: db:query_rate:hourly_avg
        expr: avg_over_time(rate(db_client_operation_duration_seconds_count[1h])[7d:1h])

      # Detect anomalous query rate (> 3 standard deviations from baseline)
      - alert: AnomalousQueryRate
        expr: |
          abs(rate(db_client_operation_duration_seconds_count[5m]) - db:query_rate:hourly_avg)
          / stddev_over_time(rate(db_client_operation_duration_seconds_count[1h])[7d:1h]) > 3
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Anomalous query rate detected for {{ $labels.service_name }} -> {{ $labels.db_namespace }}"
```

---

## 26. Encryption and Firewall Monitoring

### TLS Connection Monitoring

```sql
-- PostgreSQL: Check which connections use SSL
SELECT pid, usename, client_addr, ssl, ssl_version, ssl_cipher
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid)
WHERE ssl = true;

-- Count encrypted vs unencrypted connections
SELECT ssl, count(*) as connection_count
FROM pg_stat_ssl
GROUP BY ssl;

-- MySQL: Check SSL status
SHOW STATUS LIKE 'Ssl_cipher';
SELECT USER(), CURRENT_USER(), @@ssl_cipher;

-- MySQL: Check which connections use SSL
SELECT user, host, ssl_type, ssl_cipher
FROM mysql.user
WHERE ssl_type != '';
```

### Encryption-at-Rest Verification

```sql
-- PostgreSQL: Verify data directory encryption (OS-level)
-- Check via dm-crypt/LUKS status or cloud provider encryption status

-- MySQL: Check tablespace encryption
SELECT TABLE_SCHEMA, TABLE_NAME, CREATE_OPTIONS
FROM INFORMATION_SCHEMA.TABLES
WHERE CREATE_OPTIONS LIKE '%ENCRYPTION%';

-- AWS RDS: Check encryption status
-- aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,StorageEncrypted]'
```

### Database Firewall Monitoring

```yaml
# Alert on connections from unexpected sources
groups:
  - name: db_firewall
    rules:
      - alert: DatabaseConnectionFromUnexpectedSource
        expr: |
          count by (client_addr) (pg_stat_activity_count{client_addr!~"10\\.0\\..*|172\\.16\\..*"}) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection from unexpected IP {{ $labels.client_addr }}"

      - alert: DatabaseRejectedConnections
        expr: rate(postgresql_connection_rejected_total[5m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database rejecting connections on {{ $labels.instance }}"
```

---

## 27. Compliance Audit Trails

### Requirements by Standard

| Standard | Data Access Logging | Access Control Audit | Retention | Encryption Monitoring |
|----------|--------------------|--------------------|-----------|----------------------|
| **PCI-DSS** (v4.0) | All access to cardholder data | All privilege changes | 12 months online, 1 year archive | TLS 1.2+ required, verify quarterly |
| **HIPAA** | All access to PHI | All user/role changes | 6 years | Encryption at rest + transit required |
| **SOX** | Financial data access | All admin actions | 7 years | Not explicitly required |
| **GDPR** | Personal data processing | Access control changes | Duration of processing purpose | Encryption recommended (pseudonymization) |

### Implementing a Compliance-Ready Audit Pipeline

```
Application ─────┐
                  │
Database ─────────┼──→ OTel Collector ──→ Audit Log Store (immutable)
  (pgAudit /      │       │                     │
   Audit Plugin)  │       │                     ├── WORM Storage (S3 Glacier, Azure Immutable Blob)
                  │       │                     ├── SIEM (Sentinel, Splunk, Chronicle)
Network IDS ──────┘       │                     └── Compliance Dashboard
                          │
                          └──→ Real-time Alerting (PagerDuty, OpsGenie)
                                │
                                ├── Unauthorized access attempts
                                ├── Privilege escalation
                                ├── Bulk data export
                                └── Schema changes outside change windows
```

### Sensitive Data Access Monitoring

```sql
-- PostgreSQL: Create a trigger for sensitive data access logging
CREATE TABLE audit.sensitive_data_access (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    user_name TEXT NOT NULL,
    client_addr INET,
    query TEXT,
    row_count INTEGER,
    accessed_at TIMESTAMPTZ DEFAULT now()
);

-- Monitor for bulk data exports (large SELECT results)
-- Alert when: Single query returns > 1000 rows from sensitive tables
-- Alert when: Data accessed outside business hours
-- Alert when: User accesses table for the first time
```

---

## Part VI: Cloud-Managed Database Observability

---

## 28. AWS RDS and Aurora Observability

### Performance Insights

Performance Insights provides database load analysis using the **Average Active Sessions (AAS)** metric, broken down by wait events, SQL statements, hosts, users, and databases.

> **Important**: AWS has announced end-of-life for Performance Insights on **June 30, 2026**. Organizations should migrate to **CloudWatch Database Insights** (Advanced mode) before this date.

#### Key Concepts

| Concept | Description |
|---------|-------------|
| **DB Load (AAS)** | Average number of sessions that are actively running at any point. AAS > vCPU count = database is CPU-constrained |
| **Wait Events** | What sessions are waiting for: CPU, I/O, Lock, LWLock, BufferPin, etc. |
| **Top SQL** | Queries contributing most to DB load, ranked by time spent |
| **Slice by dimension** | Filter DB load by wait, SQL, host, user, or database |

#### Wait Event Categories (PostgreSQL on RDS)

| Category | Common Events | Indicates |
|----------|---------------|-----------|
| **CPU** | `CPU` | Query execution, computation |
| **IO** | `IO:DataFileRead`, `IO:WALWrite` | Disk I/O, buffer cache misses |
| **Lock** | `Lock:transactionid`, `Lock:tuple` | Row-level lock contention |
| **LWLock** | `LWLock:BufferContent`, `LWLock:WALWrite` | Internal PostgreSQL locks |
| **BufferPin** | `BufferPin` | Buffer pool contention |
| **Client** | `Client:ClientRead`, `Client:ClientWrite` | Network latency to application |
| **IPC** | `IPC:MultixactOffsetSLRU` | Inter-process communication |

#### Performance Insights API

```python
import boto3

pi = boto3.client('pi')

# Get DB load for last hour
response = pi.get_resource_metrics(
    ServiceType='RDS',
    Identifier='db-XXXXXXXXXXXXXXXXXXXX',
    MetricQueries=[
        {
            'Metric': 'db.load.avg',
            'GroupBy': {
                'Group': 'db.wait_event',
                'Limit': 10
            }
        }
    ],
    StartTime=datetime.utcnow() - timedelta(hours=1),
    EndTime=datetime.utcnow(),
    PeriodInSeconds=60
)
```

### CloudWatch Database Insights (Successor to Performance Insights)

CloudWatch Database Insights provides two modes:

| Feature | Standard (Free) | Advanced (Paid) |
|---------|-----------------|-----------------|
| CloudWatch metrics | Yes | Yes |
| Enhanced Monitoring (OS metrics) | No | Yes |
| DB load analysis | Basic | Full (wait events, top SQL) |
| Query-level insights | No | Yes (replaces Performance Insights) |
| Retention | 14 days | 25 months |
| Pricing | Free | Per-vCPU per month |

### Aurora-Specific Observability

```yaml
# Key Aurora CloudWatch metrics to monitor
# Cluster-level
- AuroraReplicaLag                    # Replication lag in milliseconds
- AuroraReplicaLagMaximum             # Max lag across all replicas
- AuroraBinlogReplicaLag              # Binlog replication lag (MySQL)
- VolumeBytesUsed                     # Storage consumed
- VolumeReadIOPs / VolumeWriteIOPs    # Storage I/O operations

# Instance-level
- CPUUtilization
- DatabaseConnections
- FreeableMemory
- ReadLatency / WriteLatency          # I/O latency
- ReadThroughput / WriteThroughput    # I/O throughput
- BufferCacheHitRatio                 # Should be > 99%
- Deadlocks                          # Should be 0
- LoginFailures                       # Security monitoring
```

### OTel Collector for RDS Metrics

```yaml
receivers:
  # Pull CloudWatch metrics into OTel
  awscloudwatch/rds:
    region: us-east-1
    poll_interval: 60s
    metrics:
      named:
        - namespace: AWS/RDS
          period: 60s
          statistics: [Average, Maximum]
          dimensions:
            - name: DBInstanceIdentifier
              value: my-rds-instance
          metrics:
            - name: CPUUtilization
            - name: DatabaseConnections
            - name: FreeableMemory
            - name: ReadLatency
            - name: WriteLatency
            - name: BufferCacheHitRatio
            - name: ReplicaLag
            - name: Deadlocks
```

---

## 29. Azure SQL Database Observability

### Intelligent Insights

Azure SQL Database uses built-in AI to continuously monitor database usage and detect disruptive events. It generates a diagnostics log with an intelligent assessment of issues.

#### Detected Patterns

| Pattern | Description | Detection Method |
|---------|-------------|------------------|
| Reaching resource limits | DTU/vCore limits exceeded | Automated resource tracking |
| Workload increase | Sudden spike in query load | Baseline comparison |
| Memory pressure | Memory-intensive queries | Buffer pool analysis |
| Locking | Excessive lock contention | Wait statistics |
| Increased MAXDOP | Parallelism changes affecting latency | Query plan analysis |
| Pagelatch contention | Buffer latch waits | Wait event analysis |
| Missing index | Queries that would benefit from indexes | Query plan analysis |
| New query | Unknown queries affecting performance | Baseline comparison |
| Unusual wait statistic | Abnormal wait patterns | Historical comparison |
| TempDB contention | Temp table/variable contention | TempDB wait analysis |
| DTU shortage | DTU consumption approaching limits | Resource tracking |
| Plan regression | Optimizer chose worse execution plan | Plan comparison |

### Query Performance Insight

```sql
-- View top resource-consuming queries
SELECT TOP 20
    qs.query_hash,
    qs.query_plan_hash,
    qs.execution_count,
    qs.total_worker_time / qs.execution_count AS avg_cpu_us,
    qs.total_elapsed_time / qs.execution_count AS avg_duration_us,
    qs.total_logical_reads / qs.execution_count AS avg_reads,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        (CASE qs.statement_end_offset WHEN -1 THEN LEN(qt.text)
         ELSE qs.statement_end_offset END - qs.statement_start_offset)/2 + 1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY qs.total_worker_time DESC;
```

### Automatic Tuning

```sql
-- Enable all automatic tuning options
ALTER DATABASE current SET AUTOMATIC_TUNING = AUTO;

-- Or enable specific options
ALTER DATABASE current SET AUTOMATIC_TUNING
(
    FORCE_LAST_GOOD_PLAN = ON,        -- Revert plan regressions
    CREATE_INDEX = ON,                  -- Auto-create missing indexes
    DROP_INDEX = ON                     -- Auto-drop unused indexes
);

-- Monitor tuning recommendations
SELECT name, reason, score, state_desc,
       is_executable_action, is_revertable_action,
       execute_action_start_time, execute_action_duration,
       revert_action_start_time
FROM sys.dm_db_tuning_recommendations
ORDER BY score DESC;
```

### Azure Monitor Integration with OTel

```yaml
receivers:
  azuremonitor/sqldb:
    subscription_id: ${env:AZURE_SUBSCRIPTION_ID}
    tenant_id: ${env:AZURE_TENANT_ID}
    client_id: ${env:AZURE_CLIENT_ID}
    client_secret: ${env:AZURE_CLIENT_SECRET}
    resource_groups: ["my-rg"]
    services: ["Microsoft.Sql/servers/databases"]
    collection_interval: 60s
    metrics:
      - name: cpu_percent
      - name: physical_data_read_percent
      - name: log_write_percent
      - name: dtu_consumption_percent
      - name: connection_successful
      - name: connection_failed
      - name: blocked_by_firewall
      - name: deadlock
      - name: storage_percent
      - name: workers_percent
      - name: sessions_percent
```

---

## 30. Google Cloud SQL Observability

### Query Insights

Query Insights provides query-level performance monitoring directly in the Cloud Console.

#### Standard vs Enterprise Plus

| Feature | Standard | Enterprise Plus |
|---------|----------|-----------------|
| Database load graph | Yes | Yes |
| Top queries by load | Yes | Yes |
| Query plan capture | Sampled | All queries, 200 samples/min |
| Wait event analysis | No | Yes |
| Index recommendations | No | Yes (with SQL creation commands) |
| AI-powered troubleshooting | No | Yes (natural language) |
| Data retention | 7 days | 30 days |
| Query tags | Yes | Yes |

#### Enabling Query Insights

```bash
# Enable via gcloud
gcloud sql instances patch my-instance \
  --insights-config-query-insights-enabled \
  --insights-config-query-plans-per-minute=200 \
  --insights-config-query-string-length=4096 \
  --insights-config-record-application-tags \
  --insights-config-record-client-address
```

#### Query Tagging with Cloud SQL

```python
# Python: Tag queries for Cloud SQL Query Insights
# Add comments to queries for grouping in the dashboard
cursor.execute(
    "/* controller='OrderController',action='index',route='/api/orders' */ "
    "SELECT * FROM orders WHERE status = %s",
    ('pending',)
)

# Or use the sqlcommenter library for automatic tagging:
# pip install opentelemetry-sqlcommenter
# Automatically adds trace context, controller, route to SQL comments
```

### Cloud Monitoring Metrics for Cloud SQL

```yaml
# Key Cloud SQL metrics available via Google Cloud Monitoring
# (accessible via googlecloudmonitoring receiver)
cloudsql.googleapis.com/database/cpu/utilization
cloudsql.googleapis.com/database/cpu/reserved_cores
cloudsql.googleapis.com/database/memory/utilization
cloudsql.googleapis.com/database/memory/total_usage
cloudsql.googleapis.com/database/disk/utilization
cloudsql.googleapis.com/database/disk/read_ops_count
cloudsql.googleapis.com/database/disk/write_ops_count
cloudsql.googleapis.com/database/network/received_bytes_count
cloudsql.googleapis.com/database/network/sent_bytes_count
cloudsql.googleapis.com/database/postgresql/num_backends
cloudsql.googleapis.com/database/postgresql/transaction_count
cloudsql.googleapis.com/database/postgresql/replication/replica_byte_lag
cloudsql.googleapis.com/database/mysql/replication_lag
cloudsql.googleapis.com/database/state          # RUNNABLE, SUSPENDED, etc.
cloudsql.googleapis.com/database/up             # Instance availability
```

---

## 31. Cloud-Native vs Bring-Your-Own Monitoring

### Comparison Matrix

| Capability | Cloud-Native | Third-Party (Datadog, Grafana Cloud) | Self-Hosted (OTel + Prometheus + Grafana) |
|------------|-------------|--------------------------------------|------------------------------------------|
| **Setup effort** | Minimal (auto-enabled) | Medium (agent installation) | High (infrastructure management) |
| **Database-specific insights** | Deep (wait events, query plans, AI recommendations) | Good (via integrations) | Basic (metrics only, custom dashboards) |
| **Cross-cloud visibility** | Single cloud only | Multi-cloud unified | Multi-cloud unified |
| **Application trace correlation** | Limited (X-Ray/App Insights link) | Strong (APM + DB monitoring unified) | Strong (OTel end-to-end) |
| **Custom metrics/dashboards** | Limited | Extensive | Unlimited |
| **Cost at scale** | Included in DB cost + premium tiers | Per-host/per-metric pricing | Infrastructure cost only |
| **Data retention** | 14d-25mo (varies by tier) | 13mo-15mo (varies by plan) | Unlimited (self-managed) |
| **Vendor lock-in** | High | Medium | None |
| **Compliance/data residency** | Cloud-native controls | Varies by vendor | Full control |

### When to Augment Cloud-Native Tools

**Use cloud-native alone** when:
- Single-cloud environment with < 50 database instances
- Team has deep cloud-provider expertise
- Budget is constrained (cloud-native often included in DB pricing)
- Primary concern is database performance tuning (wait events, query plans)

**Add third-party or self-hosted** when:
- Multi-cloud or hybrid deployment
- Need to correlate application traces with database performance
- Require custom dashboards and alerting beyond cloud-native capabilities
- Have > 100 database instances across teams
- Need unified observability across databases, applications, and infrastructure
- Compliance requires data in specific regions or self-hosted

### Recommended Architecture: Layered Approach

```
Layer 1: Cloud-Native (always on, free/low cost)
├── AWS: Database Insights Standard (free), Enhanced Monitoring
├── Azure: Intelligent Insights, Query Performance Insight
└── GCP: Query Insights Standard (free)

Layer 2: OTel Collector (unified collection)
├── Database receivers (postgresql, mysql, mongodb, redis)
├── Cloud metrics receivers (awscloudwatch, azuremonitor, googlecloudmonitoring)
└── Application trace correlation

Layer 3: Unified Backend (single pane of glass)
├── Grafana Cloud / Self-hosted Grafana + Mimir + Loki + Tempo
├── Datadog / Splunk / New Relic
└── Custom dashboards, alerting, SLO tracking
```

---

## Part VII: Database Observability Architecture Patterns

---

## 32. Agent-Based vs Agentless Monitoring

### Comparison

| Aspect | Agent-Based | Agentless | eBPF-Based |
|--------|-------------|-----------|------------|
| **Deployment** | Binary/sidecar on DB host | Remote polling | Kernel module on DB host |
| **Data richness** | High (system + DB metrics) | Medium (DB metrics via protocol) | Very high (kernel-level visibility) |
| **Overhead** | 1-5% CPU, 50-200MB RAM | Near zero on DB host | < 1% CPU (kernel space) |
| **Network dependency** | Local collection | Requires network access to DB | Local collection |
| **Security** | Agent needs DB credentials locally | Credentials in collector | No DB credentials needed |
| **Examples** | Datadog Agent, pgwatch2 | OTel Collector receivers, Prometheus exporters | Pixie, Deepflow, Groundcover |
| **Best for** | Deep monitoring, log collection | Simple metric scraping | Zero-instrumentation visibility |

### Agent-Based Architecture

```
┌─────────────────────────────┐
│ Database Host                │
│                             │
│  ┌──────────┐  ┌─────────┐ │
│  │ PostgreSQL│  │ Agent   │ │
│  │           │←─│ (OTel   │ │
│  │           │  │ Contrib │ │
│  └──────────┘  │ Collector│ │
│                 │ w/       │ │
│                 │ postgres │ │
│                 │ receiver)│ │
│                 └────┬─────┘ │
└──────────────────────┼───────┘
                       │ OTLP
                       ▼
              ┌──────────────┐
              │ Backend      │
              │ (Grafana     │
              │  Cloud, etc.)│
              └──────────────┘
```

### Agentless Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ PostgreSQL   │     │ MySQL        │     │ Redis        │
│ (port 5432)  │     │ (port 3306)  │     │ (port 6379)  │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                     │                     │
       │ SQL protocol        │ SQL protocol        │ RESP protocol
       │                     │                     │
       ▼                     ▼                     ▼
┌─────────────────────────────────────────────────────────┐
│                Central OTel Collector                    │
│ (postgresql receiver, mysql receiver, redis receiver)    │
│                                                         │
│ Advantages:                                             │
│ - No software on database hosts                         │
│ - Centralized credential management                     │
│ - Single point of configuration                         │
│                                                         │
│ Disadvantages:                                          │
│ - No OS-level metrics (CPU, disk, memory)               │
│ - Network dependency for collection                     │
│ - Cannot collect database logs directly                  │
└─────────────────────┬───────────────────────────────────┘
                      │ OTLP
                      ▼
              ┌──────────────┐
              │ Backend      │
              └──────────────┘
```

---

## 33. Sidecar Pattern for Database Proxies

### Architecture

```
┌─────────────────────────────────────────────┐
│ Kubernetes Pod                               │
│                                             │
│  ┌──────────┐         ┌──────────────────┐  │
│  │ App      │──SQL──→│ Sidecar Proxy    │  │
│  │ Container│←result─│ (PgBouncer /     │──┼──→ PostgreSQL Primary
│  │          │         │  ProxySQL /      │  │
│  │          │         │  Envoy SQL)      │──┼──→ PostgreSQL Replica
│  └──────────┘         │                  │  │
│                       │ Exposes:         │  │
│  ┌──────────┐         │ - Connection     │  │
│  │ OTel     │←metrics─│   pool metrics   │  │
│  │ Sidecar  │         │ - Query latency  │  │
│  │ Collector│         │ - Error rates    │  │
│  └──────────┘         │ - Read/write     │  │
│                       │   split stats    │  │
│                       └──────────────────┘  │
└─────────────────────────────────────────────┘
```

### Benefits for Observability

| Benefit | Description |
|---------|-------------|
| **Transparent query capture** | Proxy sees all queries without application changes |
| **Connection pool metrics** | Centralized pool monitoring per pod |
| **Read/write split visibility** | Track routing decisions and their latency impact |
| **Query caching stats** | Cache hit/miss rates (ProxySQL) |
| **Automatic failover monitoring** | Proxy handles failover, metrics show duration |
| **Per-application isolation** | Each pod has dedicated pool, preventing noisy neighbors |

### Kubernetes Deployment Example (PgBouncer Sidecar)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      containers:
        - name: app
          image: order-service:latest
          env:
            - name: DATABASE_URL
              # Connect to sidecar PgBouncer, not directly to PostgreSQL
              value: "postgresql://user:pass@localhost:6432/orders"

        - name: pgbouncer
          image: bitnami/pgbouncer:latest
          ports:
            - containerPort: 6432
          env:
            - name: PGBOUNCER_DATABASE
              value: orders
            - name: POSTGRESQL_HOST
              value: pg-primary.database.svc.cluster.local
            - name: PGBOUNCER_POOL_MODE
              value: transaction
            - name: PGBOUNCER_DEFAULT_POOL_SIZE
              value: "10"
            - name: PGBOUNCER_MAX_CLIENT_CONN
              value: "100"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi

        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:latest
          args: ["--config=/etc/otel/config.yaml"]
          volumeMounts:
            - name: otel-config
              mountPath: /etc/otel
```

---

## 34. Database Observability Data Pipeline

### End-to-End Architecture

```
┌─────────────────── Collection ──────────────────┐
│                                                  │
│  Application          Database          Cloud    │
│  ┌─────────┐         ┌─────────┐     ┌────────┐ │
│  │ OTel SDK│         │ OTel    │     │ Cloud  │ │
│  │ (traces,│         │Collector│     │ API    │ │
│  │ metrics)│         │Receivers│     │Receiver│ │
│  └────┬────┘         └────┬────┘     └───┬────┘ │
│       │                    │              │      │
└───────┼────────────────────┼──────────────┼──────┘
        │                    │              │
        ▼                    ▼              ▼
┌─────────────────── Aggregation ─────────────────┐
│                                                  │
│  ┌──────────────────────────────────────┐        │
│  │        OTel Collector Gateway         │        │
│  │                                      │        │
│  │  Processors:                         │        │
│  │  - batch (reduce export overhead)    │        │
│  │  - filter (drop noisy metrics)       │        │
│  │  - transform (enrich, sanitize)      │        │
│  │  - tail_sampling (trace sampling)    │        │
│  │  - resource (add env, team labels)   │        │
│  └──────────────────┬───────────────────┘        │
│                     │                            │
└─────────────────────┼────────────────────────────┘
                      │
                      ▼
┌─────────────────── Storage ─────────────────────┐
│                                                  │
│  Metrics: Prometheus/Mimir/Cortex/Thanos         │
│  Traces:  Tempo/Jaeger/X-Ray                     │
│  Logs:    Loki/Elasticsearch/CloudWatch Logs     │
│  Audit:   WORM storage (S3 Glacier, immutable)   │
│                                                  │
└──────────────────────┬───────────────────────────┘
                       │
                       ▼
┌─────────────────── Analysis ────────────────────┐
│                                                  │
│  Dashboards:  Grafana (database-specific boards) │
│  Alerting:    Prometheus Alertmanager / PagerDuty│
│  SLO Tracking: Sloth / Nobl9 / Grafana SLO      │
│  Query Analysis: pganalyze / Datadog DBM         │
│  Anomaly Detection: ML-based query analysis      │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Pull vs Push for Database Metrics

| Aspect | Pull (Prometheus-style) | Push (OTLP/StatsD-style) |
|--------|------------------------|--------------------------|
| **Model** | Collector scrapes database endpoint | Database/agent pushes to collector |
| **Service discovery** | Required (DNS, K8s, Consul) | Not required (agents configured with endpoint) |
| **Firewall** | Collector must reach database port | Only outbound from agent needed |
| **Failure detection** | `up` metric = 0 when scrape fails | Absence-of-data detection required |
| **Database examples** | PostgreSQL exporter, MySQL exporter | OTel Collector receivers (pull, but collector-initiated) |
| **Best for** | Kubernetes environments with service discovery | Edge/restricted networks, cloud-managed databases |

---

## 35. Top 20 Database Alerts

### Tier 1: Critical (Page Immediately)

| # | Alert | Condition | Impact |
|---|-------|-----------|--------|
| 1 | **Database Down** | Instance unreachable for > 30s | Complete outage |
| 2 | **Replication Broken** | Replica status = ERROR/STOPPED | Data loss risk, degraded reads |
| 3 | **Storage Full** | Disk usage > 95% | Database becomes read-only or crashes |
| 4 | **Connection Exhaustion** | Active connections > 95% of max | New connections rejected |
| 5 | **Split Brain** | Multiple nodes claiming primary | Data corruption |

### Tier 2: Urgent (Respond Within 15 Minutes)

| # | Alert | Condition | Impact |
|---|-------|-----------|--------|
| 6 | **High Replication Lag** | Lag > threshold for workload type | Stale reads, failover risk |
| 7 | **Deadlocks Increasing** | Deadlock rate > 0 sustained | Transaction failures |
| 8 | **Long-Running Transaction** | Transaction active > 30min | Lock holding, bloat, replication lag |
| 9 | **CPU Saturation** | CPU > 90% for > 10min | Query latency degradation |
| 10 | **Memory Pressure** | Buffer cache hit ratio < 95% | Excessive disk I/O |

### Tier 3: Warning (Respond Within 1 Hour)

| # | Alert | Condition | Impact |
|---|-------|-----------|--------|
| 11 | **Storage Growing Fast** | Projected full within 7 days | Upcoming outage risk |
| 12 | **Backup Stale** | Last backup > 24h ago | Recovery risk |
| 13 | **WAL Archival Failing** | Failed archive count > 0 | Point-in-time recovery gap |
| 14 | **Connection Pool Waiters** | Threads waiting for connection > 0 | Latency increase |
| 15 | **Query Latency Regression** | p95 > 3x baseline | User-facing performance degradation |

### Tier 4: Informational (Review in Next Business Day)

| # | Alert | Condition | Impact |
|---|-------|-----------|--------|
| 16 | **Unused Indexes** | Index with 0 scans for 30 days | Wasted storage and write overhead |
| 17 | **Table Bloat High** | Dead tuple ratio > 20% | Query performance degradation |
| 18 | **Autovacuum Not Keeping Up** | Dead tuples increasing despite autovacuum | Growing bloat |
| 19 | **Slow Query Count Increasing** | Queries > 1s increasing trend | Workload change or regression |
| 20 | **Authentication Failures** | Login failure rate increasing | Credential issues or attack |

### Prometheus Implementation

```yaml
groups:
  - name: database_critical
    rules:
      - alert: DatabaseDown
        expr: up{job=~".*postgres.*|.*mysql.*|.*mongodb.*"} == 0
        for: 30s
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Database {{ $labels.instance }} is down"
          runbook_url: "https://wiki.example.com/runbooks/database-down"

      - alert: StorageFull
        expr: |
          (postgresql_db_size / on(instance) postgresql_disk_total) > 0.95
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Database {{ $labels.instance }} storage > 95%"

      - alert: LongRunningTransaction
        expr: |
          max(pg_stat_activity_max_tx_duration{state="active"}) > 1800
        for: 5m
        labels:
          severity: urgent
        annotations:
          summary: "Transaction running > 30min on {{ $labels.instance }}"

      - alert: TableBloatHigh
        expr: |
          pg_stat_user_tables_n_dead_tup
          / (pg_stat_user_tables_n_live_tup + pg_stat_user_tables_n_dead_tup) > 0.2
        for: 1h
        labels:
          severity: informational
        annotations:
          summary: "Table {{ $labels.relname }} on {{ $labels.instance }} has > 20% dead tuples"

      - alert: AuthenticationFailures
        expr: |
          rate(postgresql_connection_rejected_total[5m]) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Database {{ $labels.instance }} rejecting > 1 connection/s"
```

---

## 36. Database SLOs and SLIs

### Defining Database SLOs

| SLO Category | SLI (What to Measure) | SLO Target | Measurement Method |
|--------------|----------------------|------------|-------------------|
| **Availability** | Successful connection rate | 99.95% (4.38h/year downtime) | `up` metric + synthetic probes |
| **Read Latency** | p99 of SELECT query duration | < 50ms for OLTP, < 5s for OLAP | `db.client.operation.duration{db.operation.name="SELECT"}` |
| **Write Latency** | p99 of INSERT/UPDATE/DELETE duration | < 100ms for OLTP | `db.client.operation.duration{db.operation.name=~"INSERT\|UPDATE\|DELETE"}` |
| **Throughput** | Queries per second sustained | > baseline * 0.8 (no degradation > 20%) | `rate(db_client_operation_duration_seconds_count[5m])` |
| **Error Rate** | Failed queries / total queries | < 0.1% | `rate(errors) / rate(total)` |
| **Data Freshness** | Replication lag | < 5s for read replicas | `postgresql_wal_lag` or `mysql_replica_time_behind_source` |

### Error Budget Calculation

```
Monthly Error Budget = 1 - SLO target

Example for 99.95% availability:
  Error budget = 0.05% of time per month
  = 0.0005 * 30 * 24 * 60 = 21.6 minutes/month

  If an incident consumes 15 minutes:
  Remaining budget = 21.6 - 15 = 6.6 minutes
  Budget consumed = 15/21.6 = 69.4%
```

### SLO Implementation with Sloth (Prometheus-based)

```yaml
# sloth.yaml - Database availability SLO
version: "prometheus/v1"
service: "orders-database"
labels:
  team: platform
  tier: critical
slos:
  - name: "db-availability"
    objective: 99.95
    description: "Orders database must be reachable 99.95% of the time"
    sli:
      events:
        error_query: sum(rate(db_probe_failures_total{db="orders"}[{{.window}}]))
        total_query: sum(rate(db_probe_attempts_total{db="orders"}[{{.window}}]))
    alerting:
      name: OrdersDatabaseAvailability
      labels:
        team: platform
      annotations:
        runbook: "https://wiki.example.com/runbooks/orders-db-availability"
      page_alert:
        labels:
          severity: critical
      ticket_alert:
        labels:
          severity: warning

  - name: "db-read-latency"
    objective: 99.0
    description: "99% of read queries must complete within 50ms"
    sli:
      events:
        error_query: |
          sum(rate(db_client_operation_duration_seconds_count{
            db_operation_name="SELECT", db_namespace="orders"
          }[{{.window}}]))
          -
          sum(rate(db_client_operation_duration_seconds_bucket{
            db_operation_name="SELECT", db_namespace="orders", le="0.05"
          }[{{.window}}]))
        total_query: |
          sum(rate(db_client_operation_duration_seconds_count{
            db_operation_name="SELECT", db_namespace="orders"
          }[{{.window}}]))
```

---

## 37. Grafana Dashboard Best Practices

### Dashboard Organization

```
Database Observability/
├── Fleet Overview          # All databases at a glance
│   ├── Instance status (up/down)
│   ├── Connection utilization heatmap
│   ├── Replication lag across all instances
│   └── Storage utilization across all instances
│
├── Instance Detail          # Single database deep-dive
│   ├── Row 1: Availability + Connections + QPS
│   ├── Row 2: CPU + Memory + Disk I/O
│   ├── Row 3: Query Latency (p50, p95, p99) + Error Rate
│   ├── Row 4: Replication Lag + WAL Stats
│   ├── Row 5: Lock Contention + Deadlocks
│   ├── Row 6: Table Sizes + Index Usage
│   └── Row 7: Buffer Cache + Checkpoint Activity
│
├── Query Performance        # Query-level analysis
│   ├── Top queries by total time
│   ├── Top queries by average time
│   ├── Query latency trends
│   ├── N+1 detection (repeated query patterns)
│   └── Slow query log analysis
│
├── Connection Pool          # Pool monitoring
│   ├── HikariCP / PgBouncer / ProxySQL metrics
│   ├── Active vs idle vs waiting
│   ├── Acquisition time histogram
│   └── Timeout rate
│
└── Security & Compliance    # Audit dashboard
    ├── Authentication events
    ├── Privilege changes
    ├── Sensitive table access
    └── Connection source analysis
```

### Key Dashboard Design Principles

1. **USE Method for databases**: For each resource (CPU, memory, connections, locks), show **Utilization**, **Saturation**, **Errors**
2. **RED Method for queries**: For each query type, show **Rate**, **Errors**, **Duration**
3. **Time range alignment**: Default to 6h for operations, 7d for capacity planning
4. **Variable templates**: Use Grafana variables for `$instance`, `$database`, `$table`
5. **Annotation overlay**: Mark deployments, maintenance windows, incidents on database dashboards
6. **Alert integration**: Show firing alerts as annotations on relevant panels

---

## 38. Cost of Database Downtime

### Downtime Cost Formula

```
Hourly Downtime Cost = (Revenue per hour * Revenue impact %)
                     + (Employee cost per hour * Affected employees)
                     + (Recovery cost: incident responders * hours * rate)
                     + (Reputation/SLA penalty cost)

Example (E-commerce company):
  Revenue: $10M/year = $1,142/hour
  Revenue impact: 100% (database is in the critical path)
  Employees affected: 200 (support, ops, engineering)
  Average employee cost: $75/hour
  Recovery team: 5 people * $150/hour

  Hourly cost = $1,142 + (200 * $75) + (5 * $150)
             = $1,142 + $15,000 + $750
             = $16,892/hour

  Plus: SLA penalties, customer churn, brand damage (hard to quantify)
```

### Industry Benchmarks

| Company Size | Estimated Downtime Cost/Hour | Database Incidents/Year (avg) |
|-------------|------------------------------|-------------------------------|
| Small business | $1K - $10K | 10-20 |
| Mid-market | $10K - $100K | 15-30 |
| Enterprise | $100K - $1M | 5-15 |
| Large enterprise (financial) | $1M - $10M | 2-5 |

### ROI of Database Observability

```
Annual observability cost:
  OTel Collector infrastructure: $5K-$15K/year
  Backend (Grafana Cloud, Datadog): $10K-$50K/year
  Team time for setup and maintenance: $20K-$50K/year
  Total: $35K-$115K/year

Annual savings:
  Reduced MTTR (from 2h to 30min average): 75% reduction
  12 incidents/year * 1.5h saved * $50K/h = $900K/year
  Prevented incidents (detected before impact): 5 * $50K = $250K/year
  Capacity planning (avoided over-provisioning): $30K-$100K/year
  Total: ~$1.2M/year

ROI: ($1.2M - $115K) / $115K = 943%
```

---

## Part VIII: Database Performance Anti-Patterns

---

## 39. N+1 Queries

### The Anti-Pattern

Application fetches a list of N items, then makes N additional queries to fetch related data individually.

### Observable Signals

| Signal | Source | What to Look For |
|--------|--------|-----------------|
| Trace waterfall | OTel traces | Many identical child db spans under one parent |
| Span count | Trace analytics | Parent spans with > 20 db child spans |
| Query repetition | `pg_stat_statements` | Same `queryid` with very high `calls` count and low `mean_exec_time` |
| Throughput pattern | `db.client.operation.duration` | Very high QPS of fast queries from single service |

### Detection Query (PromQL)

```promql
# Services making > 50 identical DB operations per trace
# Requires trace-to-metrics conversion
sum by (service_name, db_collection_name) (
  rate(db_client_operation_duration_seconds_count[5m])
) > 50

# Combined with low latency per query (< 5ms) = N+1 pattern
histogram_quantile(0.50,
  sum(rate(db_client_operation_duration_seconds_bucket[5m])) by (le, service_name, db_collection_name)
) < 0.005
```

### Resolution Verification

After fixing (eager loading, batch query), verify:
- Child span count per parent reduces from N to 1-2
- Total request latency decreases
- QPS to affected table decreases
- Individual query count in `pg_stat_statements` drops

---

## 40. Missing Indexes

### The Anti-Pattern

Queries perform sequential scans on large tables when an index could dramatically reduce rows examined.

### Observable Signals

| Signal | Source | What to Look For |
|--------|--------|-----------------|
| Sequential scan ratio | `postgresql.sequential_scans` / total scans | High ratio on tables with > 10K rows |
| Rows examined vs returned | `db.response.returned_rows` vs `SUM_ROWS_EXAMINED` | Examine-to-return ratio > 100:1 |
| Full table scan count | MySQL `Handler_read_rnd_next` | High and increasing |
| Query latency on specific tables | `db.client.operation.duration` by `db.collection.name` | High latency correlating with large table |

### Detection Queries

```sql
-- PostgreSQL: Tables with high sequential scan ratio
SELECT schemaname, relname,
       seq_scan, idx_scan,
       seq_scan::float / NULLIF(seq_scan + idx_scan, 0) * 100 as seq_scan_pct,
       n_live_tup as row_count,
       pg_size_pretty(pg_relation_size(relid)) as table_size
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
  AND seq_scan > idx_scan
ORDER BY seq_scan_pct DESC, n_live_tup DESC;

-- PostgreSQL: Suggested indexes (via hypothetical analysis)
-- Use pg_qualstats + hypopg extensions for automated index recommendations

-- MySQL: Tables without indexes being scanned
SELECT OBJECT_SCHEMA, OBJECT_NAME,
       COUNT_STAR as access_count,
       SUM_TIMER_WAIT/1000000000 as total_wait_ms,
       COUNT_READ as reads, COUNT_WRITE as writes
FROM performance_schema.table_io_waits_summary_by_table
WHERE INDEX_NAME IS NULL
  AND COUNT_STAR > 1000
ORDER BY SUM_TIMER_WAIT DESC;
```

### Alert

```yaml
- alert: HighSequentialScanRatio
  expr: |
    pg_stat_user_tables_seq_scan
    / (pg_stat_user_tables_seq_scan + pg_stat_user_tables_idx_scan) > 0.9
    AND pg_stat_user_tables_n_live_tup > 10000
  for: 1h
  labels:
    severity: informational
  annotations:
    summary: "Table {{ $labels.relname }} has > 90% sequential scans with {{ $labels.n_live_tup }} rows"
```

---

## 41. Connection Exhaustion

### The Anti-Pattern

Application opens more connections than the database can handle, or connections are leaked (not returned to pool), eventually exhausting all available slots.

### Observable Signals

| Signal | Source | What to Look For |
|--------|--------|-----------------|
| Active connections near max | `postgresql.backends` vs `postgresql.connection.max` | > 80% utilization |
| Pool timeout rate | `db.client.connection.timeouts` | Any timeouts |
| Pool wait time | `db.client.connection.wait_time` | p99 > 1s |
| Client error rate | Application logs | "too many connections", "connection pool exhausted" |
| Idle-in-transaction | `pg_stat_activity` | `state = 'idle in transaction'` for > 5min |

### Detection (PromQL)

```promql
# Connection utilization > 80%
postgresql_backends / postgresql_connection_max > 0.8

# Connection pool timeout rate > 0
rate(db_client_connection_timeouts_total[5m]) > 0

# Connection acquisition time p99 > 5s
histogram_quantile(0.99,
  rate(db_client_connection_wait_time_seconds_bucket[5m])
) > 5
```

### Diagnosis Steps

```sql
-- Who is consuming connections?
SELECT usename, application_name, client_addr, state,
       count(*) as connections,
       count(*) FILTER (WHERE state = 'active') as active,
       count(*) FILTER (WHERE state = 'idle') as idle,
       count(*) FILTER (WHERE state = 'idle in transaction') as idle_in_tx
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY usename, application_name, client_addr, state
ORDER BY connections DESC;

-- Kill idle-in-transaction sessions older than 10 minutes
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND state_change < now() - interval '10 minutes';
```

---

## 42. Lock Contention

### The Anti-Pattern

Multiple transactions compete for the same rows or tables, creating wait chains that degrade throughput and increase latency.

### Observable Signals

| Signal | Source | What to Look For |
|--------|--------|-----------------|
| Lock wait events | Performance Insights (AAS by wait) | `Lock:transactionid`, `Lock:tuple` dominating |
| Lock count | `postgresql.database.locks` | Sustained high lock counts |
| Deadlocks | `postgresql.deadlocks` | Any increase (rate > 0) |
| Row lock waits | `mysql.row_locks` (time) | Increasing lock wait time |
| Lock wait time | `mysql.table.lock_wait.*.time` | High total wait time |

### Detection Queries

```sql
-- PostgreSQL: Current lock waits
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_query,
       blocking_activity.query AS blocking_query,
       blocked_activity.state AS blocked_state,
       now() - blocked_activity.query_start AS blocked_duration
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- MySQL: InnoDB lock waits
SELECT
    r.trx_id AS waiting_trx,
    r.trx_mysql_thread_id AS waiting_pid,
    r.trx_query AS waiting_query,
    b.trx_id AS blocking_trx,
    b.trx_mysql_thread_id AS blocking_pid,
    b.trx_query AS blocking_query,
    TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS wait_seconds
FROM information_schema.innodb_lock_waits w
JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id;
```

### Alert

```yaml
- alert: DatabaseDeadlocks
  expr: rate(postgresql_deadlocks[5m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Deadlocks detected on {{ $labels.instance }} at {{ $value }}/s"

- alert: HighLockContention
  expr: postgresql_database_locks{mode="ExclusiveLock"} > 50
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "{{ $value }} exclusive locks on {{ $labels.instance }}"
```

---

## 43. Bloat and Fragmentation

### The Anti-Pattern

In MVCC databases (PostgreSQL, MongoDB), UPDATE and DELETE operations create dead tuples. If autovacuum cannot keep up, bloat accumulates, causing table and index size growth, slower queries, and wasted I/O.

### Observable Signals

| Signal | Source | What to Look For |
|--------|--------|-----------------|
| Dead tuple count | `pg_stat_user_tables.n_dead_tup` | Increasing over time |
| Dead tuple ratio | dead / (live + dead) | > 10% = concerning, > 20% = action needed |
| Table size growth | `postgresql.table.size` | Growing without corresponding row growth |
| Autovacuum runs | `postgresql.table.vacuum.count` | Not increasing = autovacuum stalled |
| Index bloat | `pgstattuple(indexname)` | `leaf_fragmentation` > 30% |
| MongoDB storage | WiredTiger statistics | `wiredTiger.block-manager.bytes freed` vs `bytes allocated` |

### Detection Queries

```sql
-- PostgreSQL: Find bloated tables
SELECT schemaname, relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 1) as dead_pct,
       last_vacuum,
       last_autovacuum,
       pg_size_pretty(pg_total_relation_size(relid)) as total_size
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC;

-- PostgreSQL: Detailed bloat analysis with pgstattuple
SELECT * FROM pgstattuple('orders');
-- Returns: table_len, tuple_count, tuple_len, dead_tuple_count,
--          dead_tuple_len, dead_tuple_percent, free_space, free_percent

-- Index fragmentation
SELECT * FROM pgstatindex('orders_pkey');
-- Returns: tree_level, index_size, leaf_fragmentation, ...

-- MySQL/InnoDB: Check fragmentation
SELECT TABLE_SCHEMA, TABLE_NAME,
       DATA_LENGTH, INDEX_LENGTH, DATA_FREE,
       ROUND(DATA_FREE / (DATA_LENGTH + INDEX_LENGTH + DATA_FREE) * 100, 1) as frag_pct
FROM INFORMATION_SCHEMA.TABLES
WHERE DATA_FREE > 1048576  -- > 1MB free space
ORDER BY DATA_FREE DESC;
```

### Remediation Monitoring

```sql
-- After VACUUM FULL or REINDEX, verify improvement:
-- Table size should decrease
-- Dead tuple count should drop to near zero
-- Query performance should improve (verify via pg_stat_statements)

-- Monitor autovacuum effectiveness
SELECT relname,
       n_dead_tup,
       last_autovacuum,
       autovacuum_count,
       now() - last_autovacuum as time_since_last
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC;
```

---

## 44. Unbounded Queries and Hot Partitions

### Unbounded Queries

Queries without LIMIT clauses or proper WHERE filters that return or scan excessive data.

#### Detection

```sql
-- PostgreSQL: Queries with high rows returned
SELECT queryid, query, calls,
       rows / calls as avg_rows_returned,
       shared_blks_read / calls as avg_blocks_read
FROM pg_stat_statements
WHERE rows / NULLIF(calls, 0) > 10000  -- Average > 10K rows returned
ORDER BY rows DESC;

-- MySQL: Full table scans
SELECT DIGEST_TEXT, COUNT_STAR,
       SUM_ROWS_EXAMINED / COUNT_STAR as avg_rows_examined,
       SUM_ROWS_SENT / COUNT_STAR as avg_rows_sent,
       SUM_ROWS_EXAMINED / NULLIF(SUM_ROWS_SENT, 0) as examine_to_sent
FROM performance_schema.events_statements_summary_by_digest
WHERE SUM_ROWS_EXAMINED / NULLIF(COUNT_STAR, 0) > 100000
ORDER BY SUM_ROWS_EXAMINED DESC;
```

#### Alert

```yaml
- alert: UnboundedQueryDetected
  expr: |
    histogram_quantile(0.99,
      sum(rate(db_client_response_returned_rows_bucket[5m])) by (le, db_collection_name, service_name)
    ) > 10000
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "Service {{ $labels.service_name }} returning > 10K rows from {{ $labels.db_collection_name }}"
```

### Hot Partitions / Hot Keys

Skewed access patterns where a small subset of keys or partitions receive disproportionate traffic.

#### Detection

```sql
-- PostgreSQL: Per-table I/O statistics (find hot tables)
SELECT schemaname, relname,
       seq_scan, seq_tup_read,
       idx_scan, idx_tup_fetch,
       n_tup_ins, n_tup_upd, n_tup_del,
       n_tup_ins + n_tup_upd + n_tup_del as total_writes
FROM pg_stat_user_tables
ORDER BY seq_tup_read + idx_tup_fetch DESC
LIMIT 20;

-- Redis: Hot key detection
redis-cli --hotkeys
-- Reports keys with highest access frequency

-- DynamoDB: Partition key distribution
-- Monitor ConsumedReadCapacityUnits and ConsumedWriteCapacityUnits
-- per partition via CloudWatch Contributor Insights
```

#### Observable Impact

| Impact | Metric | Behavior |
|--------|--------|----------|
| Single partition overload | Partition-level I/O | One partition at limit while others idle |
| Lock contention on hot rows | Lock wait events | Same rows/pages repeatedly locked |
| Cache churn | Buffer cache hit ratio | Hot key evicts other keys, lowering global hit ratio |
| Throttling (DynamoDB) | `ThrottledRequests` | Requests rejected due to partition limit |

---

## 45. Memory Pressure and Buffer Cache

### The Anti-Pattern

When the database buffer cache is too small for the working set, every query must read from disk instead of memory, causing dramatic latency increases.

### Observable Signals

| Signal | Source | What to Look For |
|--------|--------|-----------------|
| Buffer cache hit ratio | PostgreSQL: `blks_hit / (blks_hit + blks_read)` | < 99% = investigate, < 95% = critical |
| InnoDB buffer pool hit rate | MySQL: `Innodb_buffer_pool_read_requests / (read_requests + reads)` | < 99% = investigate |
| Page faults | MongoDB: `extra_info.page_faults` | Increasing trend |
| Memory fragmentation | Redis: `redis.memory.fragmentation_ratio` | > 1.5 = high fragmentation |
| Disk read IOPS | OS/cloud metrics | Spike correlating with query latency |

### Detection Queries

```sql
-- PostgreSQL: Buffer cache hit ratio
SELECT datname,
       blks_hit, blks_read,
       ROUND(blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2) as cache_hit_pct
FROM pg_stat_database
WHERE datname NOT LIKE 'template%'
ORDER BY cache_hit_pct ASC;

-- PostgreSQL: Per-table buffer cache usage
SELECT c.relname,
       pg_size_pretty(count(*) * 8192) as buffered_size,
       ROUND(100.0 * count(*) / (SELECT setting::integer FROM pg_settings WHERE name = 'shared_buffers'), 1)
         as pct_of_shared_buffers
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.relname
ORDER BY count(*) DESC
LIMIT 20;

-- MySQL: InnoDB buffer pool efficiency
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';
-- Innodb_buffer_pool_read_requests: Total logical reads (from buffer pool)
-- Innodb_buffer_pool_reads: Reads that required disk I/O
-- Hit ratio = (read_requests - reads) / read_requests * 100
```

### Alert

```yaml
- alert: LowBufferCacheHitRatio
  expr: |
    pg_stat_database_blks_hit
    / (pg_stat_database_blks_hit + pg_stat_database_blks_read) < 0.95
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: "Buffer cache hit ratio < 95% for database {{ $labels.datname }} on {{ $labels.instance }}"
    description: "Consider increasing shared_buffers or reducing working set size"

- alert: RedisHighMemoryFragmentation
  expr: redis_memory_fragmentation_ratio > 1.5
  for: 30m
  labels:
    severity: warning
  annotations:
    summary: "Redis memory fragmentation ratio > 1.5 on {{ $labels.instance }}"
```

---

## 46. Replication Lag Spirals and Transaction Log Growth

### Replication Lag Spiral

A replication lag spiral occurs when the replica falls behind, causing it to do more work to catch up, which causes it to fall further behind.

#### Cause Chain

```
Heavy write workload on primary
    → Replica apply rate < primary write rate
        → Lag increases
            → More WAL/binlog to process
                → Replica I/O saturates
                    → Apply rate decreases further
                        → Lag increases exponentially
                            → SPIRAL
```

#### Detection

```promql
# Replication lag increasing over time (derivative > 0 sustained)
deriv(postgresql_wal_lag[5m]) > 0

# Sustained for 30 minutes = spiral
# Alert:
- alert: ReplicationLagSpiral
  expr: deriv(postgresql_wal_lag[5m]) > 0
  for: 30m
  labels:
    severity: critical
  annotations:
    summary: "Replication lag continuously increasing on {{ $labels.instance }} - possible spiral"
```

#### Remediation Monitoring

| Action | Metric to Watch | Expected Outcome |
|--------|-----------------|------------------|
| Reduce write load | `postgresql.operations{type="insert\|update\|delete"}` | Decreased rate |
| Increase replica resources | Replica CPU/IO utilization | Headroom increases |
| Enable parallel replication | MySQL: `replica_parallel_workers` | Apply rate increases |
| Rebuild replica | Replication lag | Lag drops to near zero after rebuild |

### Transaction Log Growth

Long-running transactions prevent WAL/binlog cleanup, causing disk space to grow unboundedly.

#### Detection

```sql
-- PostgreSQL: Find long-running transactions holding back WAL cleanup
SELECT pid, usename, application_name,
       state, backend_xmin,
       now() - xact_start as transaction_duration,
       query
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND state != 'idle'
ORDER BY xact_start ASC
LIMIT 10;

-- PostgreSQL: WAL retention (can't clean up old WAL segments)
SELECT redo_lsn, checkpoint_lsn,
       pg_wal_lsn_diff(pg_current_wal_lsn(), redo_lsn) as wal_retained_bytes
FROM pg_control_checkpoint();

-- MySQL: Long-running transactions
SELECT trx_id, trx_state, trx_started,
       TIMESTAMPDIFF(SECOND, trx_started, NOW()) as duration_seconds,
       trx_rows_modified, trx_query
FROM information_schema.innodb_trx
ORDER BY trx_started ASC;
```

#### Alert

```yaml
- alert: WALDiskSpaceGrowing
  expr: |
    predict_linear(postgresql_wal_size_bytes[1h], 3600 * 4) > postgresql_disk_total_bytes * 0.8
  for: 15m
  labels:
    severity: critical
  annotations:
    summary: "WAL disk space projected to reach 80% within 4h on {{ $labels.instance }}"

- alert: LongRunningTransaction
  expr: |
    pg_stat_activity_max_tx_duration{state!="idle"} > 3600
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Transaction running > 1 hour on {{ $labels.instance }}, may be blocking WAL cleanup"
```

---

## Summary: Database Observability Maturity Model

### Level 1: Reactive (Most Teams Start Here)

- Basic uptime monitoring (is the database reachable?)
- Manual slow query investigation (look at logs when users complain)
- No connection pool monitoring
- Cloud-native defaults only (CloudWatch basic metrics)

### Level 2: Proactive

- OTel Collector receivers for all databases
- Connection pool metrics (HikariCP, PgBouncer)
- Automated alerting on key metrics (Top 10 alerts from Section 35)
- Basic dashboards (instance-level)
- Slow query log collection and analysis

### Level 3: Comprehensive

- Full application trace-to-database correlation (OTel SDK + Collector)
- Query-level performance tracking (pg_stat_statements, performance_schema)
- Connection pool SLOs (acquisition time, timeout rate)
- Replication monitoring with lag alerting
- Security audit logging (pgAudit)
- N+1 detection in CI/CD (trace-based testing)

### Level 4: Optimized

- Database SLOs with error budgets
- Automated query plan regression detection
- Chaos engineering for database failures
- Cost-optimized observability pipeline (sampling, filtering)
- ML-based anomaly detection for query patterns
- Compliance-ready audit trails (immutable storage)
- Cross-cloud unified database monitoring
- Capacity planning with predictive analytics

### Consulting Engagement Roadmap

```
Week 1-2: Assessment
├── Inventory all databases (type, version, criticality)
├── Evaluate current monitoring gaps
├── Identify top 5 pain points (outages, slow queries, etc.)
└── Propose target maturity level

Week 3-4: Foundation (Level 2)
├── Deploy OTel Collector with database receivers
├── Configure connection pool metrics
├── Set up Top 10 critical alerts
└── Build fleet overview dashboard

Week 5-8: Instrumentation (Level 3)
├── Enable application-side OTel database instrumentation
├── Configure query sanitization
├── Set up trace-to-metric correlation
├── Deploy security audit logging
└── Build query performance dashboard

Week 9-12: Optimization (Level 4)
├── Define and implement database SLOs
├── Set up automated regression detection
├── Design chaos engineering tests
├── Build compliance audit pipeline
└── Knowledge transfer and documentation
```

---

*This document serves as the primary consulting knowledge base for database observability engagements. It should be updated as OpenTelemetry semantic conventions evolve and as cloud providers release new database monitoring capabilities.*

