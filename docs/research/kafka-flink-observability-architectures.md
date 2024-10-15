# Kafka + Flink for Observability: Architecture Research (2024-2026)

> Research compiled February 2026. Covers combined architecture patterns, real-world case studies, alternatives, decision frameworks, cost models, operational guidance, sizing, migration patterns, and anti-patterns.

---

## Table of Contents

1. [Combined Architecture Patterns](#1-combined-architecture-patterns)
2. [Real-World Case Studies](#2-real-world-case-studies)
3. [End-to-End Pipeline Configurations](#3-end-to-end-pipeline-configurations)
4. [Alternatives to Kafka + Flink](#4-alternatives-to-kafka--flink)
5. [Decision Framework](#5-decision-framework)
6. [Cost Comparison](#6-cost-comparison)
7. [Operational Burden](#7-operational-burden)
8. [Sizing Guidelines](#8-sizing-guidelines)
9. [Migration Patterns](#9-migration-patterns)
10. [When NOT to Use Kafka + Flink](#10-when-not-to-use-kafka--flink)

---

## 1. Combined Architecture Patterns

### Pattern A: Kafka as Ingestion Buffer + OTel Collector Processing

The simplest Kafka integration. Kafka sits between OTel Collector agents and OTel Collector gateways, providing durable buffering.

```
┌─────────────┐    ┌───────────────────┐    ┌─────────┐    ┌──────────────────┐    ┌─────────┐
│ Applications │───▶│ OTel Agent        │───▶│  Kafka  │───▶│ OTel Gateway     │───▶│ Backend │
│ (instrumented)│   │ (kafka exporter)  │    │ Topics  │    │ (kafka receiver)  │    │ Storage │
└─────────────┘    └───────────────────┘    └─────────┘    └──────────────────┘    └─────────┘
```

**When to use:** You need burst absorption, backend decoupling, or replay capability but do NOT need complex stream processing (windowed aggregations, joins, pattern detection).

**How it works:**
- OTel Collector Agent uses the `kafkaexporter` to publish traces/metrics/logs to Kafka topics
- Kafka provides persistent buffering (hours to days of retention)
- OTel Collector Gateway uses the `kafkareceiver` to consume and forward to backends
- If the backend is down, messages accumulate in Kafka (up to retention limits)
- The Agent is unaffected as long as Kafka itself is healthy

**Key detail:** The Kafka exporter uses a synchronous producer that blocks and does not batch messages. You MUST pair it with the batch processor and queued retry exporter for production throughput.

### Pattern B: Kafka Ingestion + Flink Processing + Storage

The full-power pattern. Flink performs stateful stream processing that OTel Collector cannot do.

```
┌─────────────┐    ┌──────────┐    ┌─────────┐    ┌──────────────┐    ┌──────────────┐
│ Applications │───▶│ OTel     │───▶│  Kafka  │───▶│  Flink Jobs  │───▶│   Storage    │
│              │    │ Agents   │    │ Topics  │    │              │    │              │
└─────────────┘    └──────────┘    └─────────┘    │ - Aggregate  │    │ - ClickHouse │
                                                   │ - Enrich     │    │ - Elasticsearch│
                                                   │ - Correlate  │    │ - Iceberg/S3 │
                                                   │ - Sample     │    │ - Druid      │
                                                   └──────────────┘    └──────────────┘
```

**When to use:** You need stateful processing: cross-stream joins, complex event processing (CEP), windowed aggregations over minutes/hours, ML-based anomaly detection on streaming data, or trace assembly from distributed spans.

### Pattern C: Lambda Architecture (Streaming + Batch)

```
                                    ┌──────────────┐    ┌──────────────┐
                               ┌───▶│ Flink        │───▶│ Real-time    │
                               │    │ (streaming)  │    │ Views        │
┌──────────┐    ┌─────────┐    │    └──────────────┘    └──────┬───────┘
│ OTel     │───▶│  Kafka  │────┤                               │         ┌──────────┐
│ Agents   │    │ Topics  │    │    ┌──────────────┐    ┌──────▼───────┐ │  Query   │
└──────────┘    └─────────┘    └───▶│ Flink/Spark  │───▶│ Merged View  │◀┤  Layer   │
                                    │ (batch)      │    │ (Serving DB) │ │          │
                                    └──────────────┘    └──────────────┘ └──────────┘
```

**When to use:** You need both real-time dashboards AND historical re-processing (backfill corrections, schema migrations of telemetry data). Netflix uses this pattern extensively.

### Pattern D: Kappa Architecture (Streaming Only)

```
┌──────────┐    ┌─────────┐    ┌──────────────┐    ┌──────────────┐
│ OTel     │───▶│  Kafka  │───▶│ Flink        │───▶│ Storage      │
│ Agents   │    │ (long   │    │ (single      │    │ (serves both │
└──────────┘    │ retention│   │  streaming   │    │  real-time & │
                │  or      │    │  pipeline)   │    │  historical) │
                │  tiered) │    └──────────────┘    └──────────────┘
                └─────────┘
```

**When to use:** You want a single processing path for both real-time and historical data. Requires Kafka with long retention (tiered storage) or infinite retention. Simpler operationally than Lambda but requires careful Flink state management.

---

## 2. Real-World Case Studies

### Netflix: The Gold Standard

**Scale (2024-2025 numbers):**
- 300+ million members, 1+ billion devices generating telemetry
- 20,000+ Apache Flink jobs in production (up from 15,000 reported at Confluent Current 2024)
- 100+ Kafka clusters
- Trillions of events processed daily
- ~3 PB incoming data / ~7 PB outgoing data per day through Kafka
- 60+ PB of data processed per day total

**Atlas Observability System:**
- 17 billion metrics ingested per day
- 700 billion distributed traces per day
- 1.5 PB of log data processed daily
- Millions of alerts evaluated without overwhelming infrastructure
- Observability costs reduced to less than 5% of total infrastructure spend

**Architecture decisions:**
- **1:1 mapping** from Kafka source topic to consuming Flink job. Although this creates operational overhead (more jobs to deploy), each job is simpler to maintain, analyze, and tune.
- **Span processor:** A dedicated Flink job collects all spans for a trace, aggregates at request level and trace level, pushes aggregations to Elasticsearch and Apache Iceberg.
- **Streaming analytics for alerting:** Queries processed as data is collected, rather than polling stored data. This is how they evaluate millions of alerts efficiently.
- Atlas uses **in-memory data storage** for near real-time operational insight, enabling very large numbers of metrics to be gathered and reported very quickly.

**Key lesson:** Netflix invested heavily in a self-service Flink platform. Individual teams write and deploy their own Flink jobs. The platform team provides the base Docker images, Kubernetes integration, HA setup, and metrics out of the box.

Sources: [Netflix Tech Blog - Real-Time Distributed Graph](https://netflixtechblog.com/how-and-why-netflix-built-a-real-time-distributed-graph-part-1-ingesting-and-processing-data-80113e124acc), [Confluent Current 2024 - 15,000 Jobs at Netflix](https://current.confluent.io/2024-sessions/building-a-scalable-flink-platform-a-tale-of-15-000-jobs-at-netflix), [Four Innovation Phases of Netflix's Trillions Scale Infrastructure](https://zhenzhongxu.com/the-four-innovation-phases-of-netflixs-trillions-scale-real-time-data-infrastructure-2370938d7f01), [InfoQ - Observability Strategies at Netflix](https://www.infoq.com/presentations/stream-pipeline-observability/)

---

### DoorDash: Iguazu Platform

**Scale:**
- Hundreds of billions of events per day
- 99.99% delivery rate

**Architecture:**
- Platform name: **Iguazu**
- Apache Flink chosen for: low latency, native event-time processing, fault tolerance, out-of-the-box Kafka/Redis/Elasticsearch/S3 integration
- Flink's layered API: Data Stream API for complex logic, Flink SQL for simpler transformations
- **Each Flink job deployed as a separate Kubernetes service** in standalone mode for failure isolation and independent scalability
- Base Flink Docker image with pre-configured Kubernetes infrastructure, HA setup, and metrics
- Event publishing via Confluent Kafka REST Proxy (HTTP interface eliminates per-service Kafka connection configuration)

**Observability lesson:** DoorDash learned that "mixing different kinds of data transport through multiple messaging/queueing systems without carefully designed observability leads to operational difficulties, resulting in high data latency, significant cost, and operational overhead."

**Recent evolution (2024-2025):** Migrated from Flink writing to S3 for Snowflake loading, to Flink writing directly to Apache Iceberg for better performance and cost efficiency.

Sources: [DoorDash Engineering - Building Scalable Real Time Event Processing with Kafka and Flink](https://careersatdoordash.com/blog/building-scalable-real-time-event-processing-with-kafka-and-flink/), [DoorDash - Evolving Realtime Processing with Iceberg](https://blog.dataengineerthings.org/how-does-doordash-evolve-realtime-processing-platform-with-iceberg-15486712cfbc)

---

### Uber: M3 + Real-Time Analytics

**Scale:**
- M3 ingests 1+ billion datapoints per second
- Serves 2+ billion datapoint reads per second
- At 1.5 million datapoints/sec, achieved replication factor 3 with significantly reduced hardware costs

**Architecture:**
- **M3DB:** Distributed time series store with reverse index, configurable out-of-order writes
- **M3 Coordinator:** Prometheus sidecar providing global query/storage interface, downsampling, retention/rollup rules
- Apache Kafka for real-time data transport
- Apache Flink for stream processing
- Apache Pinot as core analytics engine (saved $2M+ replacing previous solution)
- uMetric for metrics emission, uMonitor for alerting

**Exactly-once semantics:** Uber published detailed work on real-time exactly-once ad event processing with Flink and Kafka, critical for accurate billing and fraud detection.

**Key lesson:** M3 was built to optimize every part of the metrics pipeline, giving engineers maximum storage per hardware dollar. The pre-aggregation at collection time is critical for cost efficiency.

Sources: [Uber Blog - M3 Metrics Platform](https://www.uber.com/blog/m3/), [Uber Blog - Exactly-Once Ad Event Processing](https://www.uber.com/blog/real-time-exactly-once-ad-event-processing/), [Uber Real-Time App Crash Analytics with Pinot](https://startree.ai/user-stories/uber-serving-real-time-app-crash-analytics-while-saving-2m-with-apache-pinot/), [ByteByteGo - How Uber Manages Petabytes of Real-Time Data](https://blog.bytebytego.com/p/how-uber-manages-petabytes-of-real)

---

### Shopify

**Scale:**
- 66 million Kafka messages per second during peak traffic (Black Friday / Cyber Monday)
- Kafka is the backbone for search, analytics, and inventory workflows

**Flink usage:**
- Active Flink adoption with DataDog metrics reporter and structured logging to Splunk for observability of Flink jobs themselves
- Event-driven architecture enables real-time inventory, search indexing, and analytics

Sources: [Shopify Engineering - BFCM Readiness 2025](https://shopify.engineering/bfcm-readiness-2025), [Apache Flink Adoption at Shopify](https://www.slideshare.net/sap1ens/apache-flink-adoption-at-shopify)

---

### Pinterest: Guardian Rules Engine

**Architecture:**
- Kafka + Flink powers the **Guardian Rules Engine** for real-time spam and abuse detection
- Rules execute as soon as events occur (not waiting for batch jobs)
- Flink adds real-time stream processing for pattern detection and instant action

Sources: [Pinterest Fights Spam and Abuse with Kafka and Flink](https://www.kai-waehner.de/blog/2025/07/24/pinterest-fights-spam-and-abuse-with-kafka-and-flink-a-deep-dive-into-the-guardian-rules-engine/)

---

### Lyft: Near Real-Time Analytics

**Scale:**
- Hundreds of billions of events per day
- Data latency target: less than 5 minutes

**Architecture:**
- AWS Kinesis (Kafka-equivalent) for ingestion
- Apache Flink for persisting streaming data
- Flink writes directly in Parquet format to S3/cloud storage
- Reduced cluster count by 10x, dramatically lowering operational/maintenance costs

Sources: [Lyft's Large-Scale Flink-based Near Real-Time Data Analytics Platform](https://www.alibabacloud.com/blog/lyfts-large-scale-flink-based-near-real-time-data-analytics-platform_596674)

---

### Stripe: Veneur Pipeline

**Architecture:**
- **Veneur:** Open-source distributed, fault-tolerant pipeline for observability data (not Kafka+Flink but instructive)
- Local Veneur on each host collects metrics (DogStatsD-compatible)
- Non-global metrics (counters, gauges) sent directly to storage at flush time
- Global metrics (histograms, sets) forwarded to central Veneur for aggregation using consistent hashing
- **veneur-proxy** uses consistent hash ring to route metrics to stable global aggregators
- Vendor-agnostic: can output to Datadog, SignalFx, Kafka, and others

**Key lesson:** Stripe chose pre-aggregation at collection time over a full Kafka+Flink pipeline. For metrics-only observability, simpler aggregation proxies can suffice. Kafka+Flink is overkill when your primary need is percentile pre-aggregation.

Sources: [Stripe Veneur on GitHub](https://github.com/stripe/veneur)

---

## 3. End-to-End Pipeline Configurations

### Configuration A: OTel + Kafka Buffer (No Flink)

**OTel Agent (per host/pod):**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    send_batch_size: 8192
    timeout: 200ms
  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

exporters:
  kafka:
    brokers:
      - kafka-broker-1:9092
      - kafka-broker-2:9092
      - kafka-broker-3:9092
    protocol_version: "3.0.0"
    topic: otel-traces        # separate topics per signal type
    encoding: otlp_proto
    producer:
      max_message_bytes: 10000000   # 10MB max (default 1MB too small for batched OTel)
      compression: zstd
      flush_max_messages: 500

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [kafka]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [kafka]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [kafka]
```

**OTel Gateway (consuming from Kafka):**
```yaml
receivers:
  kafka:
    brokers:
      - kafka-broker-1:9092
      - kafka-broker-2:9092
      - kafka-broker-3:9092
    protocol_version: "3.0.0"
    topic: otel-traces
    encoding: otlp_proto
    group_id: otel-gateway-traces
    initial_offset: oldest

processors:
  batch:
    send_batch_size: 8192
    timeout: 1s
  memory_limiter:
    check_interval: 1s
    limit_mib: 2048
    spike_limit_mib: 512

exporters:
  otlp:
    endpoint: tempo-distributor:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [kafka]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

**Kafka topic configuration:**
```bash
# Create topics with appropriate partitioning
kafka-topics.sh --create --topic otel-traces \
  --partitions 12 \
  --replication-factor 3 \
  --config retention.ms=86400000 \        # 24 hours retention
  --config max.message.bytes=10485760 \   # 10MB max message
  --config compression.type=zstd \
  --config segment.bytes=1073741824       # 1GB segments

kafka-topics.sh --create --topic otel-metrics \
  --partitions 12 \
  --replication-factor 3 \
  --config retention.ms=43200000 \        # 12 hours (metrics are smaller, less retention needed)
  --config max.message.bytes=10485760

kafka-topics.sh --create --topic otel-logs \
  --partitions 24 \                        # more partitions for logs (highest volume)
  --replication-factor 3 \
  --config retention.ms=86400000 \
  --config max.message.bytes=10485760
```

**Critical configuration note:** The OTel Collector Kafka exporter `max_message_bytes` MUST be updated from the default 1MB because OTel Collector batches are typically larger than 1MB. This is documented as a common production issue by SigNoz.

### Configuration B: OTel + Kafka + Flink + ClickHouse

**Flink job (trace aggregation):**
```java
// Flink job: Consume spans from Kafka, assemble traces, compute aggregations
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
env.enableCheckpointing(60000); // 60-second checkpoint interval
env.setStateBackend(new EmbeddedRocksDBStateBackend());
env.getCheckpointConfig().setCheckpointStorage("s3://flink-checkpoints/trace-assembler/");

// Kafka source
KafkaSource<Span> source = KafkaSource.<Span>builder()
    .setBootstrapServers("kafka-broker-1:9092,kafka-broker-2:9092")
    .setTopics("otel-traces")
    .setGroupId("flink-trace-assembler")
    .setStartingOffsets(OffsetsInitializer.committedOffsets(OffsetResetStrategy.EARLIEST))
    .setDeserializer(new OTelSpanDeserializer())
    .build();

// Process: Assemble spans into traces using session windows
DataStream<Span> spans = env.fromSource(source, WatermarkStrategy
    .forBoundedOutOfOrderness(Duration.ofSeconds(30))
    .withIdleness(Duration.ofMinutes(1)),
    "kafka-spans");

DataStream<TraceAggregate> traces = spans
    .keyBy(span -> span.getTraceId())
    .window(EventTimeSessionWindows.withGap(Time.seconds(60)))
    .aggregate(new TraceAggregator())  // span count, duration, error rate, service graph
    .name("trace-assembly");

// Sink: Write aggregated trace data to ClickHouse
traces.addSink(new ClickHouseSink<>(
    "jdbc:clickhouse://clickhouse:8123/observability",
    "INSERT INTO trace_aggregates (trace_id, duration_ms, span_count, error_count, root_service, timestamp) VALUES (?, ?, ?, ?, ?, ?)"
)).name("clickhouse-sink");

env.execute("Trace Assembler");
```

**Flink SQL alternative (metrics pre-aggregation):**
```sql
-- Flink SQL: Aggregate metrics from Kafka, downsample, write to ClickHouse
CREATE TABLE kafka_metrics (
    metric_name STRING,
    value DOUBLE,
    labels MAP<STRING, STRING>,
    `timestamp` TIMESTAMP(3),
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '10' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'otel-metrics',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'flink-metrics-agg',
    'format' = 'json',
    'scan.startup.mode' = 'latest-offset'
);

CREATE TABLE clickhouse_metrics_1m (
    metric_name STRING,
    avg_value DOUBLE,
    max_value DOUBLE,
    min_value DOUBLE,
    sample_count BIGINT,
    window_start TIMESTAMP(3),
    window_end TIMESTAMP(3)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:clickhouse://clickhouse:8123/observability',
    'table-name' = 'metrics_1m'
);

-- Downsample: 1-minute tumbling windows
INSERT INTO clickhouse_metrics_1m
SELECT
    metric_name,
    AVG(value) as avg_value,
    MAX(value) as max_value,
    MIN(value) as min_value,
    COUNT(*) as sample_count,
    TUMBLE_START(`timestamp`, INTERVAL '1' MINUTE) as window_start,
    TUMBLE_END(`timestamp`, INTERVAL '1' MINUTE) as window_end
FROM kafka_metrics
GROUP BY metric_name, TUMBLE(`timestamp`, INTERVAL '1' MINUTE);
```

### Configuration C: Production SigNoz-Style Stack

Based on the documented SigNoz production architecture:

```
OTel Agents ──▶ Kafka (3 brokers, 3 replicas) ──▶ SigNoz OTel Collectors ──▶ ClickHouse (3 shards, 3 replicas)
                                                          │
                                                    memory_limiter adds
                                                    back-pressure on Kafka
                                                    receiver when memory
                                                    limits are breached
```

Key production configuration points:
- ClickHouse: 3 shards, 3 replicas, coordinated by ZooKeeper
- `memory_limiter` on gateway collectors caps memory and applies back-pressure on Kafka receiver
- Kafka retention sized for worst-case backend outage duration (typically 24-72 hours)
- `max_message_bytes` increased from default 1MB to accommodate OTel batch sizes

---

## 4. Alternatives to Kafka + Flink

### 4.1 Kafka Streams (Simpler, No Separate Cluster)

**What it is:** A Java library (not a cluster) embedded in your application. Reads from Kafka, processes, writes back to Kafka.

**Strengths:**
- No separate processing cluster to manage
- Deploys as a normal application (Docker container, Kubernetes deployment)
- Automatic partition-based parallelism via consumer groups
- Exactly-once semantics with Kafka transactions
- Good for lightweight, Kafka-native transformations

**Limitations:**
- Kafka-only: can only read from and write to Kafka
- Operational visibility: relies on Confluent Monitoring; no built-in UI like Flink's dashboard
- Not ideal for complex event processing, large state, or cross-stream joins at high scale
- State stored locally on application instances (RocksDB); recovery requires replaying from Kafka changelog topics

**When to choose over Flink:**
- Processing is Kafka-to-Kafka only
- Team does not want to operate a separate processing cluster
- Processing logic is simple: filtering, enrichment, simple aggregations
- Throughput < 500K events/sec

**When Flink wins:**
- Multi-source processing (Kafka + databases + files)
- Complex event processing (CEP patterns)
- Large state that requires external checkpointing
- Need for Flink SQL or Table API for analyst-friendly queries
- Throughput > 1M events/sec with complex stateful processing

Sources: [Confluent - Flink vs Kafka Streams Comparison](https://www.confluent.io/blog/apache-flink-apache-kafka-streams-comparison-guideline-users/), [Onehouse - Spark vs Flink vs Kafka Streams](https://www.onehouse.ai/blog/apache-spark-structured-streaming-vs-apache-flink-vs-apache-kafka-streams-comparing-stream-processing-engines)

### 4.2 Apache Pulsar + Pulsar Functions

**What it is:** Pulsar is a messaging and streaming platform with built-in lightweight serverless processing (Pulsar Functions).

**Strengths:**
- Decoupled compute and storage (BookKeeper)
- Native multi-tenancy and geo-replication
- Pulsar Functions: lightweight, serverless processing without a separate cluster
- Avoids per-partition overhead for high topic counts

**Limitations:**
- Most complex to operate: Broker + BookKeeper + ZooKeeper
- Smaller ecosystem than Kafka
- Pulsar Functions are lightweight -- not a replacement for Flink-class stateful processing
- Community and adoption significantly smaller than Kafka+Flink

**When to choose:** Multi-tenant environments, geo-replication requirements, very high topic counts (100K+), or when you need lightweight serverless functions without a processing cluster.

### 4.3 RisingWave (Streaming Database)

**What it is:** A Postgres-compatible streaming database that maintains materialized views over streaming data. Write SQL, get continuously updated results.

**Strengths:**
- Postgres wire protocol: use existing SQL tools, psql, JDBC drivers
- No separate message broker needed: can consume directly from Postgres CDC, MySQL CDC, Kafka, Pulsar, Kinesis
- Materialized views are incrementally maintained (no full recomputation)
- 8,400+ GitHub stars, 136+ contributors as of Oct 2025
- Dramatically simpler than Kafka+Flink for SQL-expressible transformations

**Limitations:**
- Optimized for append-only event streams; bounded correctness for mutable data
- Newer project, less battle-tested at Netflix/Uber scale
- Cannot replace Kafka for durable event sourcing / replay
- Custom processing logic (non-SQL) is limited

**When to choose:** SQL-expressible observability analytics, real-time dashboards, when you want to eliminate Kafka+Flink complexity for teams that know SQL but not Java/Scala.

Sources: [RisingWave - Stream Processing Systems 2025](https://risingwave.com/blog/stream-processing-systems-2025-risingwave-flink-spark-trends/), [RisingWave - When to Use](https://docs.risingwave.com/faq/faq-when-to-use-risingwave)

### 4.4 Materialize (Streaming SQL Database)

**What it is:** A streaming SQL database built on differential dataflow. Maintains strongly consistent materialized views with sub-millisecond freshness.

**Strengths:**
- Full support for inserts, updates, deletes (not just append-only)
- Strong consistency guarantees (stronger than RisingWave for mutable data)
- Sub-millisecond result freshness
- Enterprise monitoring with comprehensive observability tools and freshness dashboards
- Postgres-compatible SQL

**Limitations:**
- Proprietary / source-available (not fully open-source)
- Higher cost than RisingWave for equivalent workloads
- Smaller community

**When to choose:** When strong consistency on mutable data matters, when sub-millisecond freshness is required, when you need a fully managed streaming SQL service.

Sources: [Materialize vs RisingWave Comparison](https://materialize.com/guides/materialize-vs-risingwave/)

### 4.5 Redpanda + Redpanda Connect (Benthos)

**What it is:** Redpanda is a Kafka-API-compatible streaming platform (single binary, no ZooKeeper, C++ implementation). Redpanda Connect (formerly Benthos) is a stream processing framework with 200+ connectors.

**Strengths:**
- Redpanda: single binary, auto-tuning, lower latency than Kafka, Kafka API compatible
- No ZooKeeper dependency
- Redpanda Connect: YAML-based stream processing, 200+ input/output connectors
- Dramatically simpler operations than Kafka + Flink
- Can act as a drop-in Kafka replacement for OTel Collector Kafka exporter/receiver

**Limitations:**
- Redpanda Connect is not a replacement for Flink-class stateful processing
- Smaller community than Kafka (but growing)
- Enterprise features require Redpanda commercial license

**When to choose:** When you want Kafka-compatible APIs with simpler operations, when stream processing is limited to routing/filtering/enrichment (not stateful joins/windows).

Sources: [Redpanda - Kafka Alternatives](https://www.redpanda.com/guides/kafka-alternatives), [Redpanda Connect on GitHub](https://github.com/redpanda-data/connect)

### 4.6 NATS JetStream

**What it is:** Lightweight, high-performance messaging system with durable streaming (JetStream).

**Strengths:**
- Tiny binary, starts in milliseconds, no external dependencies
- Easiest to run in Kubernetes
- Very low resource overhead
- Good for IoT, edge computing, lightweight messaging

**Limitations:**
- Not designed for high-throughput event streaming at Kafka scale
- Limited stream processing capabilities
- Smaller ecosystem for observability tooling
- Not a replacement for Kafka+Flink for serious observability pipelines

**When to choose:** Edge/IoT scenarios, lightweight messaging between microservices, when operational simplicity is paramount and throughput is moderate.

Sources: [NATS vs Kafka vs Redpanda Comparison](https://risingwave.com/blog/nats-kafka-or-redpanda-which-real-time-data-solution-is-best/), [NATS Docs - Compare](https://docs.nats.io/nats-concepts/overview/compare-nats)

### 4.7 OTel Collector Alone (When Is It Enough?)

The OTel Collector is sufficient when:

| Capability | OTel Collector | Kafka+Flink Needed |
|---|---|---|
| Filtering/routing | Yes (filter processor) | No |
| Batching | Yes (batch processor) | No |
| Attribute manipulation | Yes (attributes processor) | No |
| Sampling (tail/head) | Yes (tail_sampling processor) | No |
| Simple aggregation | Limited (aggregate processor) | Yes, for complex |
| Burst absorption | No (in-memory only) | Yes (Kafka adds persistence) |
| Backend failover | No (data lost on crash) | Yes (Kafka retains data) |
| Cross-stream correlation | No | Yes (Flink) |
| Windowed aggregation | No | Yes (Flink) |
| Trace assembly | No | Yes (Flink) |
| ML/anomaly detection | No | Yes (Flink) |

**Rule of thumb:** If you can express your processing as an OTel Collector processor pipeline and your backend can handle the direct load, you do not need Kafka or Flink. Most organizations under 1M events/sec and fewer than 500 microservices can run with OTel Collector alone.

---

## 5. Decision Framework

### Stage 0: OTel Collector Only

```
Signal volume: < 100K events/sec
Microservices: < 100
Backend: Single vendor (e.g., Datadog, Grafana Cloud)
Team size: < 5 SREs
Processing needs: Filter, batch, route, sample
```

**Architecture:** OTel Agent per host/pod -> OTel Gateway pool -> Backend

**Total infrastructure:** 0 additional clusters (just OTel Collectors)

### Stage 1: Add Kafka (Buffer Layer)

**Trigger: Any ONE of these conditions:**
- Backend outages cause data loss and you cannot tolerate that
- Traffic spikes (2-10x normal) cause OTel Collector OOMs or backend overload
- You need replay capability (re-process yesterday's telemetry with new rules)
- You need to fan-out to multiple backends (send same data to 3+ destinations)
- Signal volume > 500K events/sec sustained

```
Signal volume: 100K - 5M events/sec
Microservices: 100 - 1,000
Backend: Multiple backends or unreliable single backend
Team: 2+ engineers who understand Kafka operations
Processing needs: Buffer + all Stage 0 capabilities
```

**Architecture:** OTel Agent -> Kafka -> OTel Gateway pool -> Backend(s)

**Total infrastructure:** Kafka cluster (3-5 brokers minimum)

### Stage 2: Add Flink (Stream Processing)

**Trigger: Any ONE of these conditions:**
- You need cross-stream joins (correlate traces with metrics with logs)
- You need complex windowed aggregations (5-min percentile calculations across all services)
- You need trace assembly from distributed spans (build full traces from individual spans)
- You need real-time anomaly detection (ML models on streaming data)
- You need complex event processing (detect patterns across event streams)
- Signal volume > 5M events/sec AND you need pre-aggregation before storage

```
Signal volume: > 1M events/sec (more likely > 5M)
Microservices: > 500
Backend: Multiple backends, data lake, real-time + historical
Team: 3+ engineers with Flink experience
Processing needs: Stateful stream processing + all Stage 0-1 capabilities
```

**Architecture:** OTel Agent -> Kafka -> Flink jobs -> Storage backends

**Total infrastructure:** Kafka cluster + Flink cluster (or managed Flink)

### Decision Tree

```
Q: Can OTel Collector processors handle your processing needs?
├── YES → Q: Can your backend handle direct OTel Collector load?
│   ├── YES → Stage 0: OTel Collector Only
│   └── NO  → Q: Are traffic spikes the issue?
│       ├── YES → Stage 1: Add Kafka
│       └── NO  → Scale OTel Gateway horizontally first, then Stage 1
└── NO  → Q: Do you need stateful processing?
    ├── YES → Q: Can it be expressed as SQL?
    │   ├── YES → Consider RisingWave/Materialize (simpler) or Flink SQL
    │   └── NO  → Stage 2: Kafka + Flink
    └── NO  → Q: Is it simple routing/filtering/enrichment?
        ├── YES → Kafka Streams or Redpanda Connect
        └── NO  → Stage 2: Kafka + Flink
```

---

## 6. Cost Comparison

### Baseline: Monthly cost for processing 1M events/sec

#### OTel Collector Only (Self-hosted on Kubernetes)

| Component | Spec | Monthly Cost |
|---|---|---|
| OTel Agent (DaemonSet) | 0.5 CPU, 512MB per node, 50 nodes | ~$2,500 |
| OTel Gateway (Deployment) | 4 CPU, 8GB each, 6 replicas | ~$1,800 |
| **Total** | | **~$4,300/mo** |

#### OTel + Kafka (Self-hosted)

| Component | Spec | Monthly Cost |
|---|---|---|
| OTel Agents | Same as above | ~$2,500 |
| Kafka brokers | 8 CPU, 32GB, 2TB SSD each, 5 brokers | ~$5,000 |
| OTel Gateways | Same as above | ~$1,800 |
| Kafka operations (personnel) | ~0.25 FTE SRE | ~$5,000 |
| **Total** | | **~$14,300/mo** |

#### OTel + Kafka + Flink (Self-hosted)

| Component | Spec | Monthly Cost |
|---|---|---|
| OTel Agents | Same as above | ~$2,500 |
| Kafka brokers | 5 brokers as above | ~$5,000 |
| Flink cluster | 2 JobManagers (4CPU/8GB) + 8 TaskManagers (8CPU/32GB) | ~$6,000 |
| OTel Gateways (may be reduced) | 3 replicas if Flink handles processing | ~$900 |
| Operations (personnel) | ~0.5 FTE SRE for Kafka+Flink | ~$10,000 |
| **Total** | | **~$24,400/mo** |

#### Managed Alternatives

| Service | Monthly Cost (1M events/sec) | Notes |
|---|---|---|
| Confluent Cloud Kafka | ~$4,000-8,000 | Pay per GB ingested/stored; no ops burden |
| Confluent Cloud Flink | ~$2,500-6,000 | Pay per CFU-minute; auto-scales |
| WarpStream (BYOC) | ~$1,000-3,000 | 80% cheaper than self-hosted Kafka; object storage |
| AWS MSK + Managed Flink | ~$5,000-12,000 | Fully managed; higher per-unit cost |
| Datadog/New Relic (vendor) | ~$15,000-50,000+ | All-inclusive but highest cost at scale |

#### Cost per event comparison

| Architecture | Cost per million events | Break-even vs OTel-only |
|---|---|---|
| OTel Collector only | ~$0.0016 | Baseline |
| OTel + Kafka | ~$0.0055 | 3.4x more expensive |
| OTel + Kafka + Flink | ~$0.0094 | 5.9x more expensive |
| OTel + WarpStream | ~$0.0025 | 1.6x more expensive |
| OTel + Confluent Cloud (Kafka+Flink) | ~$0.0040 | 2.5x more expensive |

**Key insight:** Personnel costs often exceed infrastructure costs. A 0.5 FTE SRE dedicated to Kafka+Flink operations ($10K/mo) may exceed the Kafka+Flink infrastructure cost itself. This is why managed services are often cheaper despite higher per-unit prices.

**WarpStream cost advantage:** By eliminating local disks and inter-zone networking, WarpStream reduces Kafka costs by 4-10x compared to self-hosting. Storage drops from ~$0.48/GiB (local SSD) to ~$0.02/GiB (object storage) -- a 24x reduction.

Sources: [Confluent Cloud Flink Billing](https://docs.confluent.io/cloud/current/flink/concepts/flink-billing.html), [WarpStream Pricing](https://www.warpstream.com/pricing), [Confluent vs MSK Cost Comparison](https://www.vantage.sh/blog/confluent-with-flink-and-kafka-vs-msk-amazon-managed-flink)

---

## 7. Operational Burden

### Required Team Skills

#### Kafka Operations
- Broker configuration and tuning (JVM, OS, network)
- Partition strategy and rebalancing
- Replication factor management and ISR monitoring
- Consumer group management and consumer lag monitoring
- Schema Registry management (if using Avro/Protobuf)
- Security: TLS, SASL, ACLs
- Monitoring: JMX metrics (100s of metrics per broker), consumer lag across thousands of partitions
- Capacity planning: disk IO, network bandwidth, partition count
- Upgrade procedures (rolling restarts)

**Minimum team:** 1 engineer with Kafka production experience for clusters < 10 brokers.

#### Flink Operations (Harder than Kafka)
- Everything above for Kafka (since Flink reads from Kafka)
- Flink cluster management (JobManager HA, TaskManager scaling)
- Checkpoint configuration and monitoring (frequency, duration, size)
- State backend management (RocksDB tuning, state size monitoring)
- Savepoint management (for job upgrades, schema changes)
- Watermark strategy configuration (bounded out-of-orderness)
- Backpressure detection and resolution
- Memory management (Flink's complex memory model: JVM heap, managed, network, etc.)
- Job graph optimization

**Minimum team:** 2 engineers with Flink production experience. Operating Flink is "notably difficult, even harder than Kafka, because Flink not only is a distributed system but also must keep state of applications for hours or longer."

### Common Failure Modes

#### Kafka
| Failure Mode | Symptom | Impact |
|---|---|---|
| Under-replicated partitions | ISR shrinks below replication factor | Data loss risk if leader fails |
| Consumer lag growing | Consumer offset falls behind latest offset | Processing delay, eventual OOM if unbounded |
| Disk full on broker | Broker stops accepting writes | Producers block or drop data |
| Rebalancing storms | Frequent consumer group rebalances | Processing pauses, duplicate processing |
| Silent replication degradation | Kafka continues serving but safety degrades | Undetected data loss risk |
| Unclean leader election | Broker with incomplete data becomes leader | Data loss |

#### Flink
| Failure Mode | Symptom | Impact |
|---|---|---|
| Checkpoint timeout | Checkpoints take longer than interval | State loss on failure; job restart replays from last checkpoint |
| Backpressure | Operators slow down upstream | End-to-end latency increases; Kafka consumer lag grows |
| TaskManager OOM | TaskManager crashes | Job restarts from checkpoint; processing delay |
| State size explosion | RocksDB disk fills; checkpoint size grows | Slower checkpoints, longer recovery |
| Watermark stalling | Idle partitions prevent watermark advance | Windows never fire; results delayed indefinitely |
| Savepoint incompatibility | Job upgrade fails to restore from savepoint | Must start from scratch or keep old job running |

### Monitoring Kafka + Flink (What to Watch)

**Kafka metrics (via JMX, Prometheus, OTel Collector `kafkametricsreceiver`):**
- `kafka.server:UnderReplicatedPartitions` -- must be 0
- `kafka.server:IsrShrinksPerSec` / `IsrExpandsPerSec` -- should be stable
- `kafka.consumer:records-lag-max` -- consumer lag per group
- `kafka.server:BytesInPerSec` / `BytesOutPerSec` -- throughput
- `kafka.server:RequestHandlerAvgIdlePercent` -- should be > 0.5
- `kafka.log:LogEndOffset` minus `kafka.consumer:CurrentOffset` -- true lag

**Flink metrics (via Flink Metrics Reporter, Prometheus, Datadog):**
- `flink_jobmanager_job_uptime` -- job stability
- `checkpointDuration` -- p99 should be < checkpoint interval
- `lastCheckpointSize` -- state growth trend
- `numRecordsInPerSecond` / `numRecordsOutPerSecond` -- throughput
- `busyTimeMsPerSecond` -- operator utilization (backpressure indicator)
- `currentInputWatermark` -- watermark progress (stalling = problem)

**End-to-end observability:**
- Producer-to-consumer latency (instrument with OTel; correlate with trace context)
- End-to-end processing latency (timestamp at source vs. output)
- Data completeness checks (count events in vs. out over time windows)

Sources: [Mastering Apache Flink in Production](https://bigdataboutique.com/blog/mastering-apache-flink-in-production-a-guide-to-monitoring-and-optimization-0b50d7), [Kafka Metrics Monitoring Guide](https://edgedelta.com/company/knowledge-center/kafka-metrics-monitoring), [Acceldata - Kafka's 5 Biggest Challenges](https://www.acceldata.io/guide/data-observability-for-kafka-d)

---

## 8. Sizing Guidelines

### Kafka Sizing

**Step 1: Calculate throughput requirements**
```
Daily events = events_per_second * 86,400
Daily data volume = daily_events * avg_event_size_bytes
Peak throughput = sustained_throughput * peak_multiplier (typically 2-5x)
```

**Step 2: Calculate broker count**
```
Required disk throughput = peak_throughput * replication_factor
Brokers needed (disk) = Required disk throughput / per_broker_disk_throughput
Brokers needed (network) = peak_throughput * (1 + replication_factor + num_consumers) / per_broker_network_bandwidth
Brokers = MAX(brokers_disk, brokers_network, 3)  # minimum 3 for HA
```

**Step 3: Calculate partitions**
```
Partitions per topic = MAX(
    target_throughput / per_partition_throughput,    # typically 10-30 MB/s per partition
    desired_consumer_parallelism,
    3                                                # minimum for HA
)
```

**Step 4: Calculate storage**
```
Storage per broker = (daily_data_volume * retention_days * replication_factor) / num_brokers
Add 30% buffer for compaction, segment overhead, and operational headroom
```

**Reference sizing table:**

| Signal Volume | Kafka Brokers | CPU/Broker | RAM/Broker | Disk/Broker | Partitions (per topic) |
|---|---|---|---|---|---|
| 100K events/sec | 3 | 4 CPU | 16 GB | 500 GB SSD | 6 |
| 500K events/sec | 3-5 | 8 CPU | 32 GB | 1 TB SSD | 12 |
| 1M events/sec | 5-7 | 8 CPU | 32 GB | 2 TB SSD | 24 |
| 5M events/sec | 7-12 | 16 CPU | 64 GB | 4 TB SSD | 48 |
| 10M events/sec | 12-20 | 16 CPU | 64 GB | 8 TB SSD | 96 |
| 50M+ events/sec | 30+ | 32 CPU | 128 GB | 10 TB+ SSD | 200+ |

### Flink Sizing

**Step 1: Estimate parallelism**
```
Parallelism = peak_events_per_second / per_slot_throughput
Per-slot throughput depends on processing complexity:
  - Simple filter/route: 50K-100K events/sec/slot
  - Stateless transformation: 20K-50K events/sec/slot
  - Windowed aggregation: 10K-30K events/sec/slot
  - Complex CEP with large state: 5K-15K events/sec/slot
```

**Step 2: Calculate TaskManagers**
```
TaskManagers = parallelism / slots_per_taskmanager
Slots per TaskManager = CPU cores per TaskManager (typically 2-8 slots)
```

**Step 3: Memory sizing**
```
Per TaskManager:
  - JVM heap: 1-4 GB (for user code, frameworks)
  - Managed memory: 1-8 GB (for RocksDB state, sorting, caching)
  - Network buffers: 0.5-2 GB (depends on parallelism and network shuffles)
  - Total: 4-16 GB per TaskManager

JobManager:
  - 2-4 GB heap for small clusters
  - 4-8 GB for large clusters (1000+ parallelism)
  - Always deploy 2 JobManagers for HA
```

**Step 4: State backend sizing**
```
For RocksDB (recommended for production):
  - Local SSD: 2-10x the in-memory state size
  - Checkpoint storage (S3/HDFS): equals full state size per checkpoint
  - Checkpoint interval: 60-300 seconds (balance recovery time vs. checkpoint overhead)
```

**Reference sizing table:**

| Signal Volume | TaskManagers | CPU/TM | RAM/TM | Slots/TM | State Backend | Checkpoint Storage |
|---|---|---|---|---|---|---|
| 100K events/sec | 2-4 | 4 CPU | 8 GB | 4 | RocksDB | 10 GB |
| 500K events/sec | 4-8 | 8 CPU | 16 GB | 4 | RocksDB | 50 GB |
| 1M events/sec | 8-16 | 8 CPU | 32 GB | 4 | RocksDB | 100 GB |
| 5M events/sec | 20-40 | 16 CPU | 64 GB | 8 | RocksDB | 500 GB |
| 10M+ events/sec | 40-100+ | 16 CPU | 64 GB | 8 | RocksDB | 1 TB+ |

**Always add 20-30% buffer** for recovery catch-up and load spikes.

Sources: [Ververica - How to Size Your Flink Cluster](https://www.ververica.com/blog/how-to-size-your-apache-flink-cluster-general-guidelines), [Ververica - 6 Things to Consider for Flink Cluster Size](https://www.ververica.com/blog/6-things-to-consider-when-defining-your-apache-flink-cluster-size), [AWS - Best Practices for Right-Sizing Kafka Clusters](https://aws.amazon.com/blogs/big-data/best-practices-for-right-sizing-your-apache-kafka-clusters-to-optimize-performance-and-cost/), [Confluent - Kafka Streams Sizing](https://docs.confluent.io/platform/current/streams/sizing.html)

---

## 9. Migration Patterns

### Phase 1: OTel Collector Only (Starting Point)

```
Applications ──▶ OTel Agent (DaemonSet) ──▶ OTel Gateway (Deployment) ──▶ Backend
```

Establish baseline: instrument applications, deploy collectors, confirm data flows to backend. This is where 80% of organizations should start and many should stay.

### Phase 2: Add Kafka as Buffer (Non-Breaking)

**Migration approach: Shadow mode first**

```
                                              ┌──▶ Backend (primary path, unchanged)
Applications ──▶ OTel Agent ──▶ OTel Gateway ─┤
                                              └──▶ Kafka (shadow, new)
                                                      │
                                                      ▼
                                                   OTel Gateway 2 ──▶ Dev/Staging Backend
```

Steps:
1. Deploy Kafka cluster (3 brokers minimum)
2. Add `kafkaexporter` as a SECONDARY exporter on existing OTel Gateways (fan-out)
3. Deploy a second set of OTel Gateways with `kafkareceiver`, pointed at a dev/staging backend
4. Validate data completeness: compare event counts between primary and shadow paths
5. Once validated, swap: make Kafka the PRIMARY path, remove direct gateway-to-backend connection
6. Keep the direct path as a fallback for 2-4 weeks

**Key risk mitigation:**
- Never cut over all at once. Run shadow mode for at least 1 week.
- Monitor Kafka consumer lag, OTel Collector memory, backend ingestion rate.
- Ensure `max_message_bytes` is configured correctly (common production issue).

### Phase 3: Add Flink for Specific Use Cases (Incremental)

**Migration approach: Start with ONE Flink job, not a platform**

Do NOT try to replace OTel Collector processing with Flink all at once. Instead:

1. **Pick ONE high-value use case** that OTel Collector cannot do:
   - Trace assembly (assemble full traces from distributed spans)
   - Metrics downsampling (1-minute to 5-minute aggregation)
   - Anomaly detection on a specific metric

2. **Deploy a single Flink job** that reads from an existing Kafka topic and writes to a new storage destination:
   ```
   Kafka topic (otel-traces) ──▶ Flink Job (trace assembler) ──▶ ClickHouse (trace_aggregates table)
   ```

3. **Do NOT modify the existing pipeline.** The Flink job is a new consumer group on the same Kafka topic. Existing consumers are unaffected.

4. **Prove value** before expanding. Measure: did trace assembly enable new dashboards? Did downsampling reduce storage costs?

5. **Expand incrementally:** Add more Flink jobs for additional use cases. Each job reads from Kafka topics and writes to storage. Follow Netflix's pattern: 1:1 mapping from topic to Flink job.

### Phase 4: Flink as Primary Processing Layer (Full Migration)

Only reach this phase if you have 5+ Flink jobs running successfully and the team has Flink operational experience.

```
Applications ──▶ OTel Agent ──▶ Kafka ──▶ Flink Jobs ──▶ Storage Backends
                                  │                          │
                                  └── (some topics still  ──┘
                                      consumed directly by
                                      OTel Gateway for
                                      simple routing)
```

At this stage, OTel Gateways may still handle simple routing/filtering, while Flink handles stateful processing. This is the hybrid model used by Netflix and DoorDash.

### Migration Timeline

| Phase | Duration | Team Needed | Risk Level |
|---|---|---|---|
| Phase 1: OTel only | 1-3 months | 1-2 engineers | Low |
| Phase 2: Add Kafka | 2-4 weeks (shadow) + 2-4 weeks (cutover) | 2-3 engineers | Medium |
| Phase 3: First Flink job | 4-8 weeks (development + validation) | 2-3 engineers (1 with Flink experience) | Medium |
| Phase 4: Flink platform | 3-6 months | 3-5 engineers (2+ with Flink experience) | High |

---

## 10. When NOT to Use Kafka + Flink

### Anti-Pattern 1: "We Might Need It Someday"

**Scenario:** Team deploys Kafka + Flink because they anticipate future scale, but current volume is 10K events/sec.

**Why it is wrong:**
- 10K events/sec is trivially handled by OTel Collector alone (a single collector can handle 100K+ events/sec)
- Kafka + Flink adds $10K-25K/month in infrastructure + personnel costs
- Operational complexity increases by 5-10x
- Mean time to resolution for incidents increases (more systems to debug)

**Rule of thumb:** If your total signal volume is under 500K events/sec and you have no stateful processing requirements, Kafka+Flink is overkill.

### Anti-Pattern 2: "Kafka for Everything"

**Scenario:** Team routes ALL observability data through Kafka, including health checks, debug logs, and development environment telemetry.

**Why it is wrong:**
- Kafka costs scale linearly with data volume
- Most observability data should be filtered BEFORE hitting Kafka
- Health checks, readiness probes, and static asset requests should be filtered at the OTel Agent level

**Better approach:** OTel Agent filters noise first, then sends valuable signals to Kafka. Apply the cost optimization levers (filter noise, severity threshold, cardinality reduction) BEFORE the Kafka exporter.

### Anti-Pattern 3: "Flink Instead of OTel Collector Processors"

**Scenario:** Team uses Flink jobs for simple filtering, attribute manipulation, and routing that OTel Collector processors handle natively.

**Why it is wrong:**
- Flink jobs require Java/Scala/Python development, testing, deployment, monitoring
- OTel Collector processors are YAML configuration changes
- Flink adds checkpoint overhead, state management, and failure recovery complexity
- OTel Collector processors execute in microseconds; Flink adds milliseconds of latency

**Better approach:** Use OTel Collector for everything it can do (filter, transform, sample, batch, route). Only use Flink when you need capabilities OTel Collector lacks (stateful windows, joins, CEP).

### Anti-Pattern 4: "Self-Hosted Kafka+Flink Without Dedicated Team"

**Scenario:** Team of 3 SREs manages Kubernetes, databases, CI/CD, monitoring, AND self-hosted Kafka+Flink.

**Why it is wrong:**
- Kafka requires ongoing attention: partition rebalancing, disk monitoring, consumer lag, upgrades
- Flink requires deep expertise: checkpoint tuning, state management, savepoint handling, watermark debugging
- "Operating a Flink cluster is notably difficult, even harder than Kafka"
- Without dedicated personnel, incidents drag on for hours/days

**Better approach:** Either use managed services (Confluent Cloud, AWS MSK + Managed Flink) or do not add Kafka+Flink until you have dedicated personnel.

### Anti-Pattern 5: "Kafka for Backend Resilience When the Backend is Cloud-Managed"

**Scenario:** Team adds Kafka buffer in front of Datadog/Grafana Cloud/New Relic because they worry about backend outages.

**Why it is wrong:**
- Cloud-managed backends have 99.9%+ availability
- The Kafka cluster itself can have outages
- You are adding complexity to protect against a problem that rarely occurs
- OTel Collector's built-in retry and queued exporter handle transient backend issues

**When it IS warranted:** Self-hosted backends (ClickHouse, Elasticsearch, Loki) that have maintenance windows or are less reliable.

### Anti-Pattern 6: "Replacing Specialized Observability Pipelines"

**Scenario:** Team tries to replace Prometheus remote-write, Loki log ingestion, or Tempo trace pipeline with a generic Kafka+Flink pipeline.

**Why it is wrong:**
- Prometheus, Loki, and Tempo have purpose-built ingestion paths optimized for their data models
- Generic Kafka+Flink adds serialization/deserialization overhead
- These backends already handle buffering and back-pressure internally

**When Kafka IS warranted with these backends:** When you need to fan-out the same telemetry to multiple backends, or when you need pre-processing (aggregation, enrichment) before ingestion.

### The "Do You Really Need It?" Checklist

Answer these questions before adding Kafka or Flink:

```
□ Is your signal volume > 500K events/sec sustained?
□ Have you already optimized OTel Collector processors (filter, sample, batch)?
□ Do you have specific stateful processing needs OTel cannot handle?
□ Can you dedicate at least 1 FTE to Kafka operations?
□ Can you dedicate at least 1 FTE to Flink operations (if adding Flink)?
□ Have you evaluated managed alternatives (Confluent Cloud, WarpStream)?
□ Have you evaluated simpler alternatives (Kafka Streams, RisingWave)?
□ Is the ROI positive? (Will Kafka+Flink save more than it costs?)
```

If you cannot answer YES to at least 4 of these, you probably do not need Kafka+Flink.

---

## Summary: Architecture Selection Quick Reference

| Scenario | Recommended Architecture |
|---|---|
| < 100 microservices, single backend, < 100K events/sec | OTel Collector only |
| 100-500 microservices, reliable cloud backend, < 500K events/sec | OTel Collector only |
| Any scale, unreliable backend or need replay | OTel + Kafka |
| > 500K events/sec with traffic spikes > 5x | OTel + Kafka |
| Fan-out to 3+ backends | OTel + Kafka |
| Need cross-stream correlation, trace assembly | OTel + Kafka + Flink |
| Need metrics downsampling/pre-aggregation at scale | OTel + Kafka + Flink |
| Need ML/anomaly detection on streaming data | OTel + Kafka + Flink |
| SQL-expressible stream processing, team knows SQL | RisingWave or Materialize |
| Kafka-to-Kafka simple processing, no Flink expertise | Kafka Streams |
| Want Kafka APIs with simpler operations | Redpanda + Connect |
| Edge/IoT, lightweight messaging | NATS JetStream |
| Enterprise with budget, no ops team | Confluent Cloud (Kafka+Flink managed) |

---

## Sources

### Company Engineering Blogs
- [Netflix Tech Blog - Real-Time Distributed Graph](https://netflixtechblog.com/how-and-why-netflix-built-a-real-time-distributed-graph-part-1-ingesting-and-processing-data-80113e124acc)
- [Netflix - Four Innovation Phases](https://zhenzhongxu.com/the-four-innovation-phases-of-netflixs-trillions-scale-real-time-data-infrastructure-2370938d7f01)
- [DoorDash - Scalable Real-Time Event Processing](https://careersatdoordash.com/blog/building-scalable-real-time-event-processing-with-kafka-and-flink/)
- [Uber Blog - M3 Metrics Platform](https://www.uber.com/blog/m3/)
- [Uber Blog - Exactly-Once Ad Event Processing](https://www.uber.com/blog/real-time-exactly-once-ad-event-processing/)
- [Shopify Engineering - BFCM 2025](https://shopify.engineering/bfcm-readiness-2025)
- [Pinterest - Kafka and Flink for Spam Detection](https://www.kai-waehner.de/blog/2025/07/24/pinterest-fights-spam-and-abuse-with-kafka-and-flink-a-deep-dive-into-the-guardian-rules-engine/)
- [Stripe Veneur on GitHub](https://github.com/stripe/veneur)
- [Lyft - Flink-based Near Real-Time Analytics](https://www.alibabacloud.com/blog/lyfts-large-scale-flink-based-near-real-time-data-analytics-platform_596674)

### Architecture and Comparison Guides
- [Confluent - Flink vs Kafka Streams](https://www.confluent.io/blog/apache-flink-apache-kafka-streams-comparison-guideline-users/)
- [Onehouse - Spark vs Flink vs Kafka Streams](https://www.onehouse.ai/blog/apache-spark-structured-streaming-vs-apache-flink-vs-apache-kafka-streams-comparing-stream-processing-engines)
- [RisingWave - Stream Processing Systems 2025](https://risingwave.com/blog/stream-processing-systems-2025-risingwave-flink-spark-trends/)
- [Materialize vs RisingWave](https://materialize.com/guides/materialize-vs-risingwave/)
- [Redpanda - Kafka Alternatives](https://www.redpanda.com/guides/kafka-alternatives)
- [NATS Comparison](https://docs.nats.io/nats-concepts/overview/compare-nats)
- [Data Streaming Landscape 2026](https://www.kai-waehner.de/blog/2025/12/05/the-data-streaming-landscape-2026/)

### OpenTelemetry + Kafka Integration
- [SigNoz - Kafka and OpenTelemetry for Scalability](https://signoz.io/blog/maximizing-scalability-apache-kafka-and-opentelemetry/)
- [SigNoz Wiki - Kafka for Burst Handling](https://github.com/SigNoz/signoz/wiki/Using-Apache-Kafka-&-OpenTelemetry-Collector-for-better-burst-handling-for-observability-data)
- [OTel Kafka Exporter (GitHub)](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/kafkaexporter/README.md)
- [Dynatrace - Buffer Data via Kafka with OTel Collector](https://docs.dynatrace.com/docs/ingest-from/opentelemetry/collector/use-cases/kafka)
- [OpenTelemetry Collector Resiliency](https://opentelemetry.io/docs/collector/resiliency/)

### Sizing and Operations
- [Ververica - How to Size Your Flink Cluster](https://www.ververica.com/blog/how-to-size-your-apache-flink-cluster-general-guidelines)
- [Ververica - 6 Things to Consider for Flink Cluster Size](https://www.ververica.com/blog/6-things-to-consider-when-defining-your-apache-flink-cluster-size)
- [AWS - Right-Sizing Kafka Clusters](https://aws.amazon.com/blogs/big-data/best-practices-for-right-sizing-your-apache-kafka-clusters-to-optimize-performance-and-cost/)
- [Mastering Flink in Production](https://bigdataboutique.com/blog/mastering-apache-flink-in-production-a-guide-to-monitoring-and-optimization-0b50d7)
- [Kafka Metrics Monitoring Guide](https://edgedelta.com/company/knowledge-center/kafka-metrics-monitoring)

### Cost and Managed Services
- [Confluent Cloud Flink Billing](https://docs.confluent.io/cloud/current/flink/concepts/flink-billing.html)
- [Confluent Cloud Pricing](https://www.confluent.io/confluent-cloud/pricing/)
- [WarpStream Pricing](https://www.warpstream.com/pricing)
- [Confluent vs MSK vs Managed Flink Costs](https://www.vantage.sh/blog/confluent-with-flink-and-kafka-vs-msk-amazon-managed-flink)
- [WarpStream - Reducing Infrastructure Costs](https://docs.warpstream.com/warpstream/byoc/advanced-agent-deployment-options/reducing-infrastructure-costs)

### Trends and Industry Analysis
- [Top Trends for Data Streaming 2026](https://www.kai-waehner.de/blog/2025/12/10/top-trends-for-data-streaming-with-apache-kafka-and-flink-in-2026/)
- [Top Trends for Data Streaming 2025](https://www.kai-waehner.de/blog/2024/12/02/top-trends-for-data-streaming-with-apache-kafka-and-flink-in-2025/)
- [OpenTelemetry Adoption at 48.5%](https://www.cncf.io/blog/2025/11/27/from-chaos-to-clarity-how-opentelemetry-unified-observability-across-clouds/)
- [Confluent Current 2025 Innovations](https://github.com/AutoMQ/automq/wiki/Confluent-Current-2025:-Key-Innovations-in-Kafka-&-Flink)
