# Apache Kafka & Apache Flink Deep Dive for Observability

> Architecture, hosting options, cost modeling, advantages, and disadvantages
> for using Kafka and Flink in telemetry/observability pipelines.

---

## Table of Contents

**Part 1: Apache Kafka**
1. [Architecture](#1-kafka-architecture)
2. [KRaft (No More ZooKeeper)](#2-kraft-no-more-zookeeper)
3. [Hosting Options & Pricing](#3-kafka-hosting-options--pricing)
4. [Performance Benchmarks](#4-kafka-performance-benchmarks)
5. [Cost Modeling](#5-kafka-cost-modeling)
6. [Tiered Storage](#6-kafka-tiered-storage)
7. [Kafka + OpenTelemetry](#7-kafka--opentelemetry)
8. [Advantages for Observability](#8-kafka-advantages)
9. [Disadvantages & Risks](#9-kafka-disadvantages)

**Part 2: Apache Flink**
10. [Architecture](#10-flink-architecture)
11. [Hosting Options & Pricing](#11-flink-hosting-options--pricing)
12. [Performance Benchmarks](#12-flink-performance-benchmarks)
13. [Cost Modeling](#13-flink-cost-modeling)
14. [Flink SQL vs DataStream API](#14-flink-sql-vs-datastream-api)
15. [Checkpointing & Exactly-Once](#15-checkpointing--exactly-once)
16. [Flink + OpenTelemetry](#16-flink--opentelemetry)
17. [Common Observability Flink Jobs](#17-common-observability-flink-jobs)
18. [Advantages for Observability](#18-flink-advantages)
19. [Disadvantages & Risks](#19-flink-disadvantages)

**Part 3: Combined**
20. [When to Use What](#20-decision-framework)
21. [Combined Architecture Patterns](#21-combined-architecture-patterns)
22. [Cost Comparison: All Options](#22-total-cost-comparison)

---

# Part 1: Apache Kafka

## 1. Kafka Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kafka Cluster (KRaft)                         │
│                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│  │ Controller │  │ Controller │  │ Controller │  (Raft quorum) │
│  │ (leader)   │  │ (follower) │  │ (follower) │                │
│  └────────────┘  └────────────┘  └────────────┘                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                      Brokers                              │   │
│  │                                                           │   │
│  │  Broker 1              Broker 2              Broker 3     │   │
│  │  ┌────────────────┐   ┌────────────────┐   ┌──────────┐  │   │
│  │  │ Topic-A Part-0 │   │ Topic-A Part-1 │   │ T-A P-2  │  │   │
│  │  │ (leader)       │   │ (leader)       │   │ (leader) │  │   │
│  │  │ Topic-B Part-1 │   │ Topic-B Part-0 │   │ T-B P-2  │  │   │
│  │  │ (replica)      │   │ (leader)       │   │ (leader) │  │   │
│  │  └────────────────┘   └────────────────┘   └──────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

Producers ──write──▶ Partition Leader ──replicate──▶ Followers (ISR)
Consumers ◀──read─── Partition Leader (or nearest replica with KIP-392)
```

**Brokers**: Server processes forming the cluster. Each handles a subset of partitions. Production clusters: 3-30+ brokers depending on throughput.

**Topics & Partitions**: Topics are logical channels. Each topic is divided into partitions — the fundamental unit of parallelism. Each partition is an ordered, immutable log. The number of partitions = maximum consumer parallelism (one consumer per partition per consumer group).

**Replication & ISR**: Each partition has a replication factor (typically 3). One replica is the leader (handles reads/writes), the rest are followers. The ISR (In-Sync Replicas) set contains replicas fully caught up with the leader. With `acks=all`, a write is only acknowledged after all ISR replicas confirm.

**Consumer Groups**: Each group independently tracks offsets per partition. Multiple groups can read the same topic (fan-out). Within a group, each partition is assigned to exactly one consumer. Kafka 4.0's new consumer protocol (KIP-848) dramatically improves rebalance performance.

---

## 2. KRaft (No More ZooKeeper)

### Timeline

| Version | Date | Status |
|---------|------|--------|
| Kafka 3.3 | Oct 2022 | KRaft production-ready for new clusters |
| Kafka 3.6 | Oct 2023 | ZK-to-KRaft migration tool GA |
| Kafka 3.9 | Nov 2024 | **Last version** with ZooKeeper |
| **Kafka 4.0** | **Mar 2025** | ZooKeeper **completely removed**; KRaft-only |

### How KRaft Works

- Controller nodes (3 or 5) manage cluster metadata using Raft consensus
- Controllers maintain a metadata log (`__cluster_metadata` topic) replacing ZooKeeper znodes
- Brokers fetch metadata from controllers and apply locally
- No external dependency — Kafka is fully self-contained

### Improvements Over ZooKeeper

| Dimension | ZooKeeper | KRaft |
|-----------|-----------|-------|
| Partition limit | ~200,000 per cluster | **Millions** (tested 1.9M on 3-broker) |
| Controller failover | Minutes | Seconds |
| Operational footprint | Kafka + ZK ensemble (3-5 JVMs) | Kafka only |
| Metadata consistency | Split-brain possible | Single Raft log |

### Migration Path

1. Upgrade to Kafka 3.6+
2. Provision KRaft controller nodes alongside ZooKeeper brokers
3. Enable hybrid mode (KRaft + ZK dual-write)
4. Validate cluster health
5. Finalize: remove ZK dependency, decommission ZK ensemble

**Warning**: Migration is one-way (no rollback once finalized). Test thoroughly in staging.

---

## 3. Kafka Hosting Options & Pricing

### Self-Hosted on Kubernetes (Strimzi)

| Component | Configuration | Monthly Cost (AWS) |
|-----------|--------------|-------------------|
| Brokers (3x) | m5.xlarge (4 vCPU, 16 GB) | ~$415 |
| Storage (3x) | 1 TB gp3 EBS each | ~$240 |
| Controllers (3x) | m5.large (2 vCPU, 8 GB) | ~$208 |
| EKS cluster | Control plane | ~$73 |
| **Subtotal** | | **~$936/mo** |
| Hidden costs | LBs, NAT, cross-AZ (+25%) | ~$234 |
| **Total** | | **~$1,170/mo** |

- **Strimzi**: Free (Apache 2.0). CRDs for Kafka, Connect, MirrorMaker. KRaft support since v0.46.
- **Confluent for Kubernetes**: Requires enterprise license ($100K-500K+/year). Includes Schema Registry, ksqlDB, Control Center.

### AWS MSK

#### Provisioned (Standard Brokers, us-east-1)

| Instance | $/hour | vCPU | Memory | 3-Broker Monthly |
|----------|--------|------|--------|-----------------|
| kafka.t3.small | ~$0.05 | 2 | 2 GB | ~$108 |
| kafka.m5.large | $0.21 | 2 | 8 GB | ~$454 |
| kafka.m7g.large | $0.204 | 2 | 8 GB | ~$441 |
| kafka.m5.2xlarge | ~$0.84 | 8 | 32 GB | ~$1,814 |

- Storage: $0.10/GB-month
- Optional provisioned throughput: $0.08/MB/s-month

#### Provisioned (Express Brokers)

| Instance | $/hour | 3-Broker Monthly |
|----------|--------|-----------------|
| express.m7g.large | $0.408 | ~$881 |

- Data ingestion: $0.01/GB. Serverless storage management, faster scaling.

#### Serverless

| Component | Cost |
|-----------|------|
| Cluster-hours | $0.75/hr ($540/mo) |
| Partition-hours | $0.0015/partition/hr |
| Data In | $0.10/GB |
| Data Out | $0.05/GB |
| Storage | $0.10/GB-month |

- Limits: 200 partitions initially (auto-scales), 200 MB/s ingress, 400 MB/s egress

### Confluent Cloud

| Cluster Type | Model | Throughput | Key Feature |
|-------------|-------|-----------|-------------|
| Basic | eCKU (elastic) | 250 MB/s | Free first eCKU, multi-tenant |
| Standard | eCKU (elastic) | 250 MB/s | VPC peering |
| Enterprise | eCKU ($1.75-2.25/hr) | Scales with eCKUs | Multi-zone HA |
| Dedicated | CKU (pre-allocated) | 50 MB/s per CKU | Single-tenant, SLA |

Additional: Ingress ~$0.01-0.03/GB, Egress ~$0.01-0.03/GB, Storage ~$0.14/GB-month.

### Azure Event Hubs (Kafka-Compatible)

| Tier | Unit | Capacity | Monthly Cost |
|------|------|----------|-------------|
| Standard | TU | 1 MB/s in, 2 MB/s out | ~$22/TU |
| Premium | PU | ~5 MB/s in, 10 MB/s out | ~$740/PU |
| Dedicated | CU | ~20 MB/s in, 40 MB/s out | ~$4,932/CU |

- Native Kafka protocol support on all tiers
- Limitations: No Kafka Streams, limited partition counts vs native Kafka

### Google Cloud Managed Kafka

| Component | Rate (us-central1) |
|-----------|-------------------|
| vCPU | $0.09/vCPU-hr |
| Memory | $0.02/GiB-hr |
| Local SSD | $0.17/GiB-month |
| Persistent storage | $0.10/GiB-month |

- Committed use discounts: 20% (1-year), 40% (3-year)
- 6-vCPU cluster: ~$1,100/mo. 24-vCPU cluster: ~$4,000-8,000/mo

### Redpanda (Kafka-Compatible, No JVM)

| Deployment | Cost |
|-----------|------|
| Community (self-hosted) | Free (BSL license) |
| Serverless (managed) | Usage-based, $100 free credits |
| Dedicated (managed) | Per-cluster pricing |
| BYOC | Your cloud, Redpanda-managed |

- Claims: 6x lower TCO vs Kafka, 8-9x storage savings with tiered storage
- Single binary, no JVM, no GC pauses, no ZK/KRaft complexity

### Aiven for Kafka

| Plan | Monthly Starting | Key Features |
|------|-----------------|-------------|
| Free | $0 | 250 KB/s, 3-day retention |
| Startup | ~$290 | Basic, prototyping |
| Business | ~$725-1,900 | Kafka Connect, scaling |
| Premium | ~$2,800 | Enterprise HA |

- All-inclusive pricing (no surprise egress charges)
- Multi-cloud: AWS, GCP, Azure

### Quick Comparison

| Provider | Starting Monthly | Ops Burden | Best For |
|----------|-----------------|-----------|---------|
| Self-hosted (Strimzi) | ~$1,200 | High (you manage everything) | Maximum control, cost-sensitive |
| AWS MSK Provisioned | ~$500+ | Medium (AWS manages brokers) | AWS-native shops |
| AWS MSK Serverless | ~$540+ | Low (fully managed) | Variable workloads on AWS |
| Confluent Cloud | ~$50+ | Low | Multi-cloud, rich ecosystem |
| Azure Event Hubs | ~$22/TU | Low | Azure-native, zero ops |
| Google Cloud Managed | ~$1,100+ | Medium | GCP-native |
| Redpanda | Free-managed | Low-Medium | Performance-critical, no-JVM preference |
| Aiven | ~$290+ | Low | Multi-cloud, inclusive pricing |

---

## 4. Kafka Performance Benchmarks

### Throughput

| Scenario | Throughput | Notes |
|----------|-----------|-------|
| Single broker, sequential writes | 500-800 MB/s | Saturates disk I/O |
| 3-broker cluster, RF=3 | 200-400 MB/s aggregate | Network-bound cross-AZ |
| LinkedIn benchmark (3 machines) | **2M writes/sec** | Optimal batching, async |
| Small messages (100B), batched | 500K-1M+ msgs/sec/broker | Batch size critical |
| Large messages (10KB), batched | 50K-100K msgs/sec/broker | MB/s throughput similar |

### Latency

| Configuration | p50 | p99 | p99.9 |
|--------------|-----|-----|-------|
| acks=1, single AZ | 2-5 ms | 10-15 ms | 25-50 ms |
| acks=all, 3 ISR, single AZ | 5-10 ms | 15-30 ms | 50-100 ms |
| acks=all, cross-AZ | 10-20 ms | 30-60 ms | 100-200 ms |
| End-to-end (produce + consume) | 15-30 ms | 50-100 ms | 150-500 ms |

### Partition Limits

| Mode | Per Broker | Per Cluster |
|------|-----------|------------|
| ZooKeeper (legacy) | ~4,000 | ~200,000 |
| KRaft | 14,000+ | 1,000,000+ (tested 1.9M) |

---

## 5. Kafka Cost Modeling

### Assumptions
- Average event size: 1 KB (typical for OTel spans/metrics/logs)
- Replication factor: 3
- Retention: 24 hours (telemetry buffering) or 7 days
- 3 consumer groups (metrics backend, log backend, trace backend)

### Cost by Scale

| Events/Day | Events/Sec | Self-Hosted | AWS MSK Provisioned | AWS MSK Serverless | Confluent Cloud |
|-----------|-----------|------------|--------------------|--------------------|----------------|
| **1 Billion** | ~11,574 | $800-1,200 | $1,000-1,500 | $1,200-1,800 | $400-800 |
| **10 Billion** | ~115,740 | $5,000-8,000 | $4,000-7,000 | $5,000-8,000 | $5,000-12,000 |
| **100 Billion** | ~1.16M | $30,000-60,000 | $25,000-50,000 | N/A (limits) | $30,000-80,000 |

### Critical Cost Factor

At 100B+ events/day, **cross-AZ networking becomes the dominant cost** (up to 90% of infrastructure spend). Mitigation strategies:
- Rack-aware producers (write to nearest AZ)
- Follower fetching (KIP-392, consumers read from nearest replica)
- Compression (lz4/zstd) to reduce wire bytes
- Tiered storage to reduce local disk requirements

---

## 6. Kafka Tiered Storage

### How It Works (KIP-405)

```
Producer → Broker (local SSD) → [completed segments] → Object Storage (S3)
                                                              │
Consumer (recent data) ← Local tier                           │
Consumer (old data)    ← Remote tier (transparent) ←──────────┘
```

As log segments are sealed, they are copied to remote storage asynchronously. Local copies are deleted after `local.retention` expires. Consumers transparently fetch from remote storage for older offsets.

### Status

- **Kafka 3.9**: Tiered storage production-ready (KIP-405)
- **Kafka 4.0**: Fully supported, ongoing improvements

### Cost Impact

| Scenario | Without Tiered Storage | With Tiered Storage | Savings |
|----------|----------------------|--------------------|---------|
| 10TB retention, 7 days, RF=3 | ~$3,072/mo (all EBS) | ~$1,140/mo (24h local + S3) | **63%** |

### Vendor Support

| Vendor | Tiered Storage |
|--------|---------------|
| Apache Kafka OSS | GA (3.9+), S3 plugin |
| Confluent | GA ("Infinite Storage") |
| AWS MSK Express | Built-in managed tiering |
| Redpanda | GA, 8-9x savings claimed |
| Aiven | GA, transparent |

### Caveats

- Read amplification: S3 fetch latency 50-200ms vs <5ms local disk
- Compacted topics: not well supported with tiered storage
- Object storage API costs: GET/PUT requests add up at high read volumes

---

## 7. Kafka + OpenTelemetry

### Kafka Exporter (Agent → Kafka)

```yaml
exporters:
  kafka:
    brokers: ["kafka-1:9092", "kafka-2:9092", "kafka-3:9092"]
    topic: "otlp-spans"
    encoding: otlp_proto               # otlp_proto, otlp_json, jaeger_proto, zipkin_proto
    producer:
      compression: zstd                # none, gzip, snappy, lz4, zstd
      required_acks: -1                # 0=fire-and-forget, 1=leader, -1=all ISR
      flush_max_messages: 500
      max_message_bytes: 1048576
    partition_traces_by_id: true       # Route by traceID for trace assembly
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 5000
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
```

**Important**: The Kafka exporter uses a synchronous producer and does not batch internally. Always pair with the `batch` processor for production throughput.

**Default topics**: `otlp_spans`, `otlp_metrics`, `otlp_logs`

### Kafka Receiver (Kafka → Gateway)

```yaml
receivers:
  kafka:
    brokers: ["kafka-1:9092", "kafka-2:9092", "kafka-3:9092"]
    topic: "otlp-spans"
    group_id: "otel-gateway-traces"
    encoding: otlp_proto
    initial_offset: latest             # latest or earliest
    autocommit:
      enable: true
      interval: 5s
```

### Kafka Metrics Receiver (Monitor Kafka Itself)

```yaml
receivers:
  kafkametrics:
    brokers: ["kafka-1:9092"]
    protocol_version: "2.0.0"
    scrapers: [brokers, topics, consumers]
    collection_interval: 60s
```

### Recommended Multi-Signal Pipeline

```yaml
# Agent side: separate topics per signal
exporters:
  kafka/traces:
    brokers: ["kafka:9092"]
    topic: otlp_spans
    encoding: otlp_proto
    compression: lz4
    partition_traces_by_id: true

  kafka/metrics:
    brokers: ["kafka:9092"]
    topic: otlp_metrics
    encoding: otlp_proto
    compression: lz4

  kafka/logs:
    brokers: ["kafka:9092"]
    topic: otlp_logs
    encoding: otlp_proto
    compression: lz4

# Gateway side: separate consumer groups per signal
receivers:
  kafka/traces:
    brokers: ["kafka:9092"]
    topic: otlp_spans
    group_id: gateway-traces
    encoding: otlp_proto

  kafka/logs:
    brokers: ["kafka:9092"]
    topic: otlp_logs
    group_id: gateway-logs
    encoding: otlp_proto
```

---

## 8. Kafka Advantages

### For Observability Pipelines

| Advantage | Why It Matters |
|-----------|---------------|
| **Decoupling** | Services write to Kafka without knowing backends. Adding a new backend = adding a consumer group, no producer changes |
| **Buffering during outages** | Backend down? Kafka retains messages on disk. Backend recovers → consumers catch up. **Primary reason enterprises use Kafka** |
| **Fan-out** | Single stream consumed by multiple backends (traces → Jaeger AND Datadog, logs → ES AND S3). Each consumer group reads independently |
| **Backpressure handling** | Producers write at their rate; consumers process at their pace. No data loss during spikes |
| **Replay** | Reset consumer offsets → reprocess telemetry through new rules, reindex, backfill new backends |
| **Ordering** | Messages within a partition are strictly ordered. traceID as partition key ensures trace assembly |
| **Horizontal scaling** | Adding partitions + consumers scales linearly. Walmart: 8,500 Kafka nodes, 11B events/day |
| **Compliance/audit** | Durable audit log of all telemetry before it reaches any backend |

### The Architecture Pattern

```
[Services]
    │
    ▼
[OTel Agent] → [Kafka] → [OTel Gateway 1] → Grafana Cloud (traces)
                   │  └─→ [OTel Gateway 2] → ClickHouse (logs)
                   │  └─→ [OTel Gateway 3] → Prometheus (metrics)
                   └──→ [OTel Gateway 4] → S3 (archive)
```

---

## 9. Kafka Disadvantages

| Disadvantage | Impact | Mitigation |
|-------------|--------|-----------|
| **Operational complexity** | Needs specialized knowledge (partition rebalancing, ISR, JVM tuning). Expect 0.5-1 FTE dedicated to Kafka | Use managed service (MSK, Confluent Cloud) |
| **Cost at scale** | Cross-AZ traffic is the dominant cost (up to 90% at scale). RF=3 means 3x storage | Tiered storage, follower fetching, compression |
| **Latency addition** | 10-50ms end-to-end latency added to pipeline | Acceptable for most observability; skip Kafka for sub-ms alerting |
| **Monitoring overhead** | Must monitor Kafka itself (consumer lag, under-replicated partitions, disk, ISR shrink rate) | Use kafkametricsreceiver in OTel Collector |
| **KRaft migration** | Existing ZK clusters need multi-phase migration before Kafka 4.0 | Test in staging, follow official runbook |
| **Hidden costs** | Load balancers, NAT gateways, K8s overhead add ~25% to baseline | Budget for it from the start |
| **Overkill for small scale** | Under 1B events/day, OTel Collector persistent queues handle buffering fine | Don't add Kafka until you need it |

### When NOT to Use Kafka

- Signal volume < 1B events/day (OTel Collector with `file_storage` persistent queue suffices)
- Single backend destination (no fan-out needed)
- Team < 3 people (can't staff Kafka operations)
- Already using a managed cloud backend that handles buffering (Grafana Cloud, Datadog)
- Need sub-millisecond alerting latency

---

# Part 2: Apache Flink

## 10. Flink Architecture

### Core Components

```
┌────────────────────────────────────────────────────────────┐
│                     JobManager                              │
│                                                             │
│  ┌──────────────┐  ┌──────────┐  ┌───────────────────────┐ │
│  │ ResourceMgr  │  │Dispatcher│  │ JobMaster (per job)   │ │
│  │              │  │          │  │                        │ │
│  │ Manages slots│  │ REST API │  │ Manages execution of  │ │
│  │ Provisions   │  │ Web UI   │  │ one JobGraph          │ │
│  │ TaskManagers │  │ Submits  │  │ Coordinates checkpts  │ │
│  └──────────────┘  └──────────┘  └───────────────────────┘ │
└────────────────────────────┬───────────────────────────────┘
                             │ schedules tasks
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   TaskManagers (Workers)                      │
│                                                              │
│  TaskManager 1 (16 GB, 4 cores)                              │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐               │
│  │ Slot 0 │ │ Slot 1 │ │ Slot 2 │ │ Slot 3 │               │
│  │ 4 GB   │ │ 4 GB   │ │ 4 GB   │ │ 4 GB   │               │
│  │Source→  │ │Source→  │ │Source→  │ │Source→  │               │
│  │ Map→   │ │ Map→   │ │ Map→   │ │ Map→   │               │
│  │  Sink  │ │  Sink  │ │  Sink  │ │  Sink  │               │
│  └────────┘ └────────┘ └────────┘ └────────┘               │
│                                                              │
│  TaskManager 2 ... TaskManager N                             │
└─────────────────────────────────────────────────────────────┘
```

**JobManager**: Coordinates all distributed execution. Schedules tasks, manages checkpoints, handles failures. In HA mode, one leader + standby instances.

**TaskManager**: Executes the operators/tasks of a dataflow. Each is a JVM process with configurable memory and task slots.

**Task Slots**: Smallest unit of resource scheduling. Each slot gets a fixed memory partition. Slots do NOT isolate CPU — only memory. Multiple operators from the same job share a slot (operator chaining) for efficiency.

### State Backends

| Backend | Storage | State Limit | Throughput | Best For |
|---------|---------|------------|-----------|---------|
| **HashMapStateBackend** | JVM heap | Available JVM memory | Highest (no serialization) | Small state (<few GB), lowest latency |
| **RocksDBStateBackend** | Off-heap + local SSD | Available disk | Lower (JNI crossing) | Large state, production workloads |
| **ForSt (Flink 2.0)** | Remote object storage (S3) | Virtually unlimited | 75-120% of RocksDB | Cloud-native, elastic scaling |

### Event Time vs Processing Time

| Aspect | Event Time | Processing Time |
|--------|-----------|-----------------|
| When | When event actually occurred | When Flink processes it |
| Determinism | Fully deterministic, replayable | Non-deterministic |
| Out-of-order | Handled via watermarks | Not handled |
| Latency | Higher (wait for watermarks) | Lower |
| Use case | Accurate observability metrics | Low-latency alerting |

**Watermarks**: Special records declaring "no events with timestamp <= W will arrive." They drive event-time windows forward.

```java
WatermarkStrategy.<Event>forBoundedOutOfOrderness(Duration.ofSeconds(10))
    .withTimestampAssigner((event, timestamp) -> event.getTimestamp())
```

---

## 11. Flink Hosting Options & Pricing

### Self-Hosted on Kubernetes (Flink Kubernetes Operator)

| Scale | TaskManagers | Config Each | Monthly Cost (AWS EKS) |
|-------|-------------|------------|----------------------|
| Small (1B events/day) | 3-5 | 4 vCPU, 16 GB | $800-1,500 |
| Medium (10B events/day) | 10-20 | 8 vCPU, 32 GB | $3,000-7,000 |
| Large (100B events/day) | 50-100 | 16 vCPU, 64 GB | $15,000-50,000 |

Plus: EKS ($73/mo), S3 for checkpoints, engineering labor (biggest cost).

**Flink Kubernetes Operator** (Apache, free): Manages FlinkDeployment CRDs. v1.14.0 (Feb 2026) added Blue/Green deployment for zero-downtime upgrades.

### AWS Managed Service for Apache Flink

| Component | Rate |
|-----------|------|
| KPU-hour (1 vCPU + 4 GB) | **$0.11/hr** |
| Storage | $0.10/GB/mo (50 GB/KPU included) |
| Orchestration overhead | +1 KPU per streaming app |

| KPUs | Monthly Cost |
|------|-------------|
| 4 (small) | ~$326 |
| 16 (medium) | ~$1,305 |
| 64 (large) | ~$5,222 |
| 256 (very large) | ~$20,890 |

Throughput guidance: ~1 MB/s per KPU (stateful), up to hundreds MB/s per KPU (stateless).

### Confluent Cloud for Apache Flink

- **$0.21/CFU-hour** (Confluent Flink Unit)
- Billed per-minute granularity
- Tight Kafka integration (no data movement costs between Confluent Kafka and Flink)
- MAX_CFU parameter caps spending per compute pool

### Google Cloud Dataflow (Beam-compatible)

| Resource | Streaming Rate |
|----------|---------------|
| vCPU/hour | $0.069 |
| Memory GB/hour | $0.003557 |
| Data processed | $0.018/GB |

- CUD discounts: 20% (1-year), 40% (3-year)
- **Caveat**: Runs Apache Beam, not native Flink. Not all Flink features available.

### Azure HDInsight on AKS

- Pay-per-vcore-per-hour + AKS infrastructure costs
- Supports native Apache Flink on AKS

### Ververica Platform (Commercial Flink)

- Original Flink creators
- VERA engine: up to 2x OSS Flink speed
- Self-managed, managed service, or BYOC
- $400 sign-up credit for managed service

### Decodable (Managed Flink)

| Plan | Rate | Tasks |
|------|------|-------|
| Free | $0 | 4 concurrent |
| On Demand | $0.12/credit (1 credit = 1 small task/hr) | Unlimited |
| Enterprise | $0.10/credit | Unlimited |

### Aiven for Apache Flink

- Starting ~$0.57/hr (~$400/mo)
- Available on AWS, GCP, Azure
- 30-day free trial with $300 credit

### Quick Comparison

| Provider | Starting Monthly | Ops Burden | Best For |
|----------|-----------------|-----------|---------|
| Self-hosted (K8s Operator) | ~$800 | High | Maximum control, customization |
| AWS Managed Flink | ~$326 | Low | AWS-native, quick start |
| Confluent Cloud Flink | Variable | Low | Already on Confluent Kafka |
| Google Dataflow | Variable | Low | GCP-native (Beam, not native Flink) |
| Ververica | Contact sales | Medium | Performance-critical, enterprise |
| Decodable | Free-$0.12/credit | Low | Quick experiments, managed |
| Aiven | ~$400 | Low | Multi-cloud |

---

## 12. Flink Performance Benchmarks

### Throughput

| Source | Configuration | Throughput |
|--------|--------------|-----------|
| Yahoo Streaming Benchmark | 10-node cluster, windowed agg | ~80M events/sec |
| Alibaba (production) | Search/recommendations | **1 trillion events/day**, 470M tx/sec peak |
| PayPal (production) | Financial event processing | **1 trillion events/day** |
| IoT benchmark (2024) | 10-node K8s (16 vCPU, 64 GB each) | 1M events/sec, 95% linear to 100 nodes |
| Netflix (production) | 20,000+ jobs | Trillions of events/day across all jobs |

### Flink 2.0 Improvements (March 2025)

| Dimension | Improvement |
|-----------|------------|
| Checkpoint duration | Up to **94% reduction** |
| Recovery after failure | Up to **49x faster** |
| Cost (disaggregated state) | Up to **50% savings** |
| Stateful heavy I/O queries | 75-120% of local state throughput with remote state |

### Checkpoint Overhead

- Incremental checkpoints: 80-90%+ reduction in checkpoint I/O for large state
- Fault tolerance overhead: 5-10 seconds downtime, zero data loss
- At-least-once mode: <2% throughput impact (vs 5-20% for exactly-once)

---

## 13. Flink Cost Modeling

### Assumptions
- Average event size: 500 bytes
- Processing: moderate (windowed aggregation + filtering + enrichment)
- AWS Managed Flink: $0.11/KPU-hour
- Baseline: ~1 MB/s per KPU for moderate complexity

### Cost by Scale

| Events/Day | Data Volume | KPUs Needed | AWS Managed Monthly | Self-Hosted K8s Monthly |
|-----------|-------------|------------|--------------------|-----------------------|
| **1 Billion** | ~500 GB/day | 8-12 | **$650-970** | **$400-700** |
| **10 Billion** | ~5 TB/day | 60-90 | **$4,900-7,300** | **$3,000-5,000** |
| **100 Billion** | ~50 TB/day | 600-900 | **$49,000-73,000** | **$20,000-40,000** |

### Cost Optimization

1. **Auto-scaling**: Scale down off-peak (telemetry has 3-5x daily amplitude)
2. **Pre-aggregation**: Roll up metrics before storage (reduces downstream costs 5-10x)
3. **Spot instances**: 60-70% savings for self-hosted (requires good checkpointing)
4. **Incremental checkpoints**: 80-90% less checkpoint I/O
5. **State TTL**: Expire old state to prevent unbounded growth

---

## 14. Flink SQL vs DataStream API

| Criterion | Flink SQL | DataStream API |
|-----------|-----------|---------------|
| **Use when** | Standard aggregations, filters, joins, windows | Custom stateful logic, ML inference, CEP |
| **Coverage** | ~70% of common use cases | Remaining 30% |
| **Learning curve** | Low (ANSI SQL) | High (Java/Scala, distributed systems) |
| **Optimization** | Automatic (Apache Calcite) | Manual |
| **State access** | Implicit (managed by runtime) | Explicit (ValueState, MapState) |
| **Testing** | Harder to unit test | Standard JUnit |
| **Deployment** | Ad-hoc via SQL gateway | JAR packaging |
| **ML (2025)** | Built-in ML functions (Confluent) | Full library access (DJL, ONNX, TensorFlow) |

### Flink SQL for Observability (Example)

```sql
-- Pre-aggregate metrics: drop pod-level cardinality, keep service-level
INSERT INTO metrics_1m
SELECT
    resource_attributes['service.name'] AS service,
    metric_name,
    TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS window_start,
    AVG(metric_value) AS avg_val,
    APPROX_PERCENTILE(metric_value, 0.99) AS p99,
    MAX(metric_value) AS max_val,
    COUNT(*) AS sample_count
FROM otlp_metrics
GROUP BY
    resource_attributes['service.name'],
    metric_name,
    TUMBLE(event_time, INTERVAL '1' MINUTE);
```

### DataStream API for Observability (Example)

```java
// Tail sampling with distributed state
spans.keyBy(Span::getTraceId)
     .process(new KeyedProcessFunction<String, Span, Span>() {
         private MapState<String, List<Span>> buffer;
         private ValueState<Boolean> hasError;

         @Override
         public void processElement(Span span, Context ctx, Collector<Span> out) {
             buffer.put(span.getSpanId(), span);
             if (span.getStatus() == ERROR) hasError.update(true);
             ctx.timerService().registerEventTimeTimer(
                 span.getTimestamp() + 30_000); // 30s window
         }

         @Override
         public void onTimer(long ts, OnTimerContext ctx, Collector<Span> out) {
             boolean keep = hasError.value()
                 || maxDuration > SLOW_THRESHOLD
                 || random.nextDouble() < 0.01; // 1% baseline
             if (keep) {
                 for (Span s : buffer.values()) out.collect(s);
             }
             buffer.clear();
         }
     });
```

---

## 15. Checkpointing & Exactly-Once

### How Checkpointing Works

1. JobManager injects **checkpoint barriers** into source streams
2. Barriers flow through the DAG with data
3. When an operator receives barriers from ALL inputs, it snapshots state
4. State uploaded asynchronously to durable storage (S3, HDFS, GCS)
5. For exactly-once sinks: 2-phase commit (start transaction → checkpoint → commit)

### Exactly-Once vs At-Least-Once

| Aspect | Exactly-Once | At-Least-Once |
|--------|-------------|---------------|
| Barrier alignment | Required (operators wait) | Not required |
| Throughput impact | 5-20% reduction | <2% |
| Latency impact | Higher (alignment wait) | Lower |
| Sink requirements | 2PC-capable (Kafka, JDBC) | Any sink |
| Recovery | No duplicates | May produce duplicates |

### For Observability: At-Least-Once is Usually Sufficient

Most backends handle deduplication or idempotent writes. The throughput and latency benefits outweigh consistency concerns.

```java
env.getCheckpointConfig().setCheckpointingMode(CheckpointingMode.AT_LEAST_ONCE);
env.getCheckpointConfig().setCheckpointInterval(60_000);  // 60s
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(30_000);
env.getCheckpointConfig().setTolerableCheckpointFailureNumber(3);
```

### Production Checkpoint Configuration

```java
env.enableCheckpointing(60_000);
env.getCheckpointConfig().setCheckpointStorage("s3://bucket/flink-checkpoints");
env.getCheckpointConfig().setMaxConcurrentCheckpoints(1);
env.getCheckpointConfig().setExternalizedCheckpointRetention(
    ExternalizedCheckpointRetention.RETAIN_ON_CANCELLATION);

// Incremental checkpoints with RocksDB (80-90% less I/O)
env.setStateBackend(new EmbeddedRocksDBStateBackend(true));
```

---

## 16. Flink + OpenTelemetry

### Flink Emitting OTel Metrics (Native, Flink 2.0+)

```yaml
# flink-conf.yaml
metrics.reporters: otel
metrics.reporter.otel.factory.class: org.apache.flink.metrics.otel.OpenTelemetryMetricReporterFactory
metrics.reporter.otel.exporter.endpoint: http://otel-collector:4317
metrics.reporter.otel.exporter.protocol: gRPC
metrics.reporter.otel.service.name: my-flink-app
metrics.reporter.otel.exporter.compression: gzip
```

Exports Flink internal metrics (checkpoint duration, task latency, backpressure, record throughput) to any OTel backend.

### Flink Emitting OTel Traces

```yaml
traces.reporter.otel.factory.class: org.apache.flink.traces.otel.OpenTelemetryTraceReporterFactory
traces.reporter.otel.exporter.endpoint: http://otel-collector:4317
traces.reporter.otel.service.name: my-flink-app
```

Exports checkpoint and recovery operation traces.

### OTel Collector Flink Receiver

```yaml
receivers:
  flink:
    endpoint: http://flink-jobmanager:8081
    collection_interval: 60s
    metrics:
      - flink.jvm.memory.heap.used
      - flink.task.record.count
      - flink.job.checkpoint.count
      - flink.job.checkpoint.duration
```

Scrapes 29 metrics from Flink's REST API.

### Flink as OTel Pipeline Processor

```
OTel Agent → Kafka → Flink (heavy processing) → Kafka → OTel Gateway → Backends
```

Use when OTel Collector processors are insufficient for:
- Stateful tail sampling across large trace windows
- Complex aggregations requiring distributed state
- ML-based anomaly detection
- Cross-signal correlation (metrics + traces + logs)

---

## 17. Common Observability Flink Jobs

### Job 1: Metrics Pre-Aggregation

Drop pod/container dimensions, keep service-level resolution. **Result: 99%+ cardinality reduction**.

```sql
INSERT INTO metrics_1m
SELECT service_name, metric_name,
    TUMBLE_START(event_time, INTERVAL '1' MINUTE) AS ts,
    AVG(value) AS avg_val,
    APPROX_PERCENTILE(value, 0.99) AS p99,
    COUNT(*) AS samples
FROM raw_metrics
GROUP BY service_name, metric_name,
    TUMBLE(event_time, INTERVAL '1' MINUTE);
```

### Job 2: Trace Assembly + Tail Sampling

Buffer spans by traceID, assemble complete traces, make sampling decisions:
- 100% of errors (status_code = ERROR)
- 100% of slow traces (duration > P99)
- 10% probabilistic baseline

**Result: 60-80% trace volume reduction**.

### Job 3: Log Classification + Enrichment

Classify logs by pattern (OOM, timeout, auth failure), enrich with service catalog metadata (team owner, tier, on-call channel), route by severity to tiered storage.

**Result: 70-90% hot storage reduction**.

### Job 4: Cross-Signal Correlation

Windowed join: metric anomalies + error logs + slow traces in real-time. Topology-aware (knows service dependency graph). Fires enriched alerts with pre-correlated context.

**Result: MTTD reduction from minutes to seconds**.

### Job 5: SLO/SLI Computation

Real-time error budget burn rate calculation with multi-window alerting:
- Burn rate > 14.4 → PAGE (2% budget consumed in 1h)
- Burn rate > 6.0 → TICKET (5% budget in 6h)
- Burn rate > 1.0 → LOG (normal burn)

### Job 6: Streaming Anomaly Detection

EMA-based anomaly detection with z-score thresholds. Confluent Cloud (2025) offers built-in `ML_DETECT_ANOMALIES_ROBUST` in Flink SQL.

### Job 7: Service Topology Discovery

Build real-time service dependency graph from trace parent-child span relationships. Feed into topology visualization and impact analysis.

---

## 18. Flink Advantages

| Advantage | Why It Matters |
|-----------|---------------|
| **Stateful stream processing** | Maintains distributed state across cluster — handles trace assembly, windowed aggregation, sessionization that OTel Collector cannot |
| **Exactly-once/at-least-once** | No duplicate metrics or traces even during failures |
| **Event-time processing** | Correctly handles late-arriving telemetry via watermarks |
| **Horizontal scaling** | Proven at 1 trillion events/day (Alibaba, PayPal) |
| **Backpressure** | Propagates naturally, preventing data loss during spikes |
| **SQL + Code** | Flink SQL for 70% of use cases; DataStream API for the remaining 30% |
| **Checkpoints** | Automatic fault tolerance with sub-10-second recovery |
| **Pre-aggregation** | 5-10x downstream storage cost reduction |
| **Cross-signal correlation** | Join metrics + traces + logs in real-time |
| **ML integration** | Streaming anomaly detection, online inference |

---

## 19. Flink Disadvantages

| Disadvantage | Impact | Mitigation |
|-------------|--------|-----------|
| **Operational complexity** | Cluster management, upgrades, scaling, tuning require specialized expertise | Use managed service (AWS, Confluent, Ververica) |
| **State management** | Large state (>1TB) makes checkpointing and recovery slow; schema evolution requires planning | Flink 2.0 disaggregated state, incremental checkpoints |
| **Debugging difficulty** | Multi-layer failures (K8s + Flink + connectors + logic). Watermark debugging is notoriously hard | Good observability of Flink itself (OTel metrics) |
| **Talent scarcity** | Teams need distributed systems expertise. Flink engineers are expensive and rare | Flink SQL lowers the bar for common use cases |
| **Connector maintenance** | OSS connectors often lack production reliability | Use managed services, test thoroughly |
| **Overkill for simple ETL** | "Apache Flink is overkill for simple, stateless stream processing" — Kai Waehner | Use OTel Collector or Kafka Streams for simple cases |
| **JVM dependency** | GC pauses, memory tuning, heap configuration | Flink 2.0 off-heap state, ForSt backend |
| **Cost** | Flink cluster + Kafka cluster + monitoring = significant monthly spend | Only add Flink when OTel Collector processors are insufficient |

### When NOT to Use Flink

- Simple routing/filtering/batching → OTel Collector suffices
- Volume < 100M events/day → OTel Collector + Fluent Bit is simpler
- Team lacks distributed systems expertise
- Budget cannot support dedicated Flink operations
- Stateless ETL → Kafka Streams, Benthos, or OTel Collector
- Single-signal processing (metrics only) → Prometheus recording rules

---

# Part 3: Combined

## 20. Decision Framework

### The Three-Stage Progression

```
Stage 1: OTel Collector Only
  ├── When: <1B events/day, single backend, small team
  ├── Cost: ~$300-800/mo (agent + gateway compute)
  └── Handles: Filtering, batching, basic sampling, routing

         │ Trigger: Need buffering, fan-out, or replay
         ▼

Stage 2: OTel Collector + Kafka
  ├── When: 1-10B events/day, multiple backends, need resilience
  ├── Cost: ~$2,000-10,000/mo (add Kafka cluster)
  └── Handles: Burst absorption, multi-backend fan-out, replay, decoupling

         │ Trigger: Need complex stateful processing
         ▼

Stage 3: OTel Collector + Kafka + Flink
  ├── When: >10B events/day, need cross-signal correlation, streaming ML
  ├── Cost: ~$10,000-50,000/mo (add Flink cluster)
  └── Handles: Pre-aggregation, tail sampling at scale, anomaly detection, SLO computation
```

### Decision Checklist

| Question | If Yes → |
|----------|---------|
| Is the OTel Collector dropping data during spikes? | Add Kafka |
| Do you need to send to 3+ backends simultaneously? | Add Kafka |
| Do you need to replay/reprocess historical telemetry? | Add Kafka |
| Does tail sampling exceed single-node memory? | Add Flink |
| Do you need cross-signal correlation (metrics + traces + logs)? | Add Flink |
| Do you need streaming anomaly detection? | Add Flink |
| Do you need real-time SLO/SLI computation? | Add Flink |
| Is cardinality causing storage cost explosion? | Add Flink (pre-aggregation) |
| Can your team operate Kafka? (1+ dedicated engineer) | Prerequisite for Kafka |
| Can your team operate Flink? (1-2 dedicated engineers) | Prerequisite for Flink |

---

## 21. Combined Architecture Patterns

### Pattern A: Kafka as Buffer Only (No Flink)

```
App → OTel Agent → Kafka → OTel Gateway → Backend(s)
```

- Kafka provides buffering and fan-out
- OTel Gateway handles all processing (sampling, filtering, routing)
- **Best for**: 1-10B events/day, need resilience without Flink complexity

### Pattern B: Full Pipeline (Kafka + Flink)

```
App → OTel Agent → Kafka (raw) → Flink → Kafka (processed) → OTel Gateway → Backend(s)
```

- Flink performs heavy processing (aggregation, correlation, ML)
- Second Kafka topic holds processed output
- OTel Gateway handles final routing and export
- **Best for**: >10B events/day, need stateful stream processing

### Pattern C: Hybrid (Flink for Some Signals)

```
App → OTel Agent → Kafka
                     ├── Metrics topic → Flink (aggregation) → Storage
                     ├── Traces topic  → Flink (tail sampling) → Storage
                     └── Logs topic    → OTel Gateway (simple filter) → Storage
```

- Flink only for signals that need it (metrics aggregation, trace sampling)
- Logs go directly through OTel Gateway (simpler processing)
- **Best for**: Mixed signal volumes where one signal needs heavy processing

---

## 22. Total Cost Comparison

### Monthly Cost at 1M Events/Second (~86B events/day)

| Architecture | Infrastructure | Engineering (FTE) | Total Monthly |
|-------------|---------------|-------------------|--------------|
| **OTel Collector only** | ~$4,000-8,000 | 0.25 FTE (~$3,000) | **~$7,000-11,000** |
| **OTel + Kafka** | ~$10,000-18,000 | 0.75 FTE (~$9,000) | **~$19,000-27,000** |
| **OTel + Kafka + Flink** | ~$20,000-40,000 | 1.5 FTE (~$18,000) | **~$38,000-58,000** |
| **Managed alternative** (Confluent Cloud Kafka + Flink) | ~$15,000-35,000 | 0.5 FTE (~$6,000) | **~$21,000-41,000** |

### Cost Per Million Events

| Architecture | Cost/Million Events |
|-------------|-------------------|
| OTel Collector only | ~$0.003-0.004 |
| OTel + Kafka | ~$0.007-0.010 |
| OTel + Kafka + Flink | ~$0.015-0.022 |
| OTel + Kafka + Flink (managed) | ~$0.008-0.016 |

### The ROI Question

Flink's pre-aggregation typically reduces downstream storage costs by 5-10x. If your current storage bill is $50K/mo and Flink reduces it to $10K/mo, the $20K/mo Flink cost pays for itself.

```
Break-even formula:
  Flink cost < (Current storage cost - Storage cost after Flink pre-aggregation)

Example:
  $20K/mo (Flink) < $50K/mo - $10K/mo = $40K/mo savings
  Net savings: $20K/mo ✓
```

---

## Sources

### Kafka
- [Apache Kafka 4.0 KRaft Architecture (InfoQ)](https://www.infoq.com/news/2025/04/kafka-4-kraft-architecture/)
- [KRaft - Confluent](https://developer.confluent.io/learn/kraft/)
- [Amazon MSK Pricing](https://aws.amazon.com/msk/pricing/)
- [Confluent Cloud Pricing](https://www.confluent.io/confluent-cloud/pricing/)
- [Azure Event Hubs Pricing](https://azure.microsoft.com/en-us/pricing/details/event-hubs/)
- [Google Cloud Managed Kafka Pricing](https://cloud.google.com/managed-service-for-apache-kafka/pricing)
- [Redpanda Cloud](https://www.redpanda.com/redpanda-cloud)
- [Aiven Plans and Pricing](https://aiven.io/pricing)
- [Kafka Performance (Confluent)](https://developer.confluent.io/learn/kafka-performance/)
- [Kafka Benchmark Analysis (RisingWave)](https://risingwave.com/blog/kafka-benchmark-analysis-performance-and-latency/)
- [KIP-405: Kafka Tiered Storage](https://cwiki.apache.org/confluence/display/KAFKA/KIP-405:+Kafka+Tiered+Storage)
- [Kafka Exporter (OTel Contrib)](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/kafkaexporter/README.md)
- [Kafka Receiver (OTel Contrib)](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/kafkareceiver/README.md)
- [Uncovering Kafka's Hidden Costs (Confluent)](https://www.confluent.io/blog/understanding-and-optimizing-your-kafka-costs-part-1-infrastructure/)
- [MetaRouter: 1B Events/Day with Kafka](https://www.metarouter.io/post/how-we-process-one-billion-events-per-day-with-kafka)
- [Strimzi - Apache Kafka on Kubernetes](https://strimzi.io/)

### Flink
- [Flink Architecture](https://nightlies.apache.org/flink/flink-docs-master/docs/concepts/flink-architecture/)
- [Apache Flink 2.0.0 Release](https://flink.apache.org/2025/03/24/apache-flink-2.0.0-a-new-era-of-real-time-data-processing/)
- [AWS Managed Flink Pricing](https://aws.amazon.com/managed-service-apache-flink/pricing/)
- [Confluent Cloud Flink Billing](https://docs.confluent.io/cloud/current/flink/concepts/flink-billing.html)
- [Google Cloud Dataflow Pricing](https://cloud.google.com/dataflow/pricing)
- [Azure HDInsight Pricing](https://azure.microsoft.com/en-us/pricing/details/hdinsightonaks/)
- [Ververica Platform](https://www.ververica.com/platform)
- [Decodable Pricing](https://www.decodable.co/pricing)
- [Aiven Flink Plans](https://aiven.io/docs/products/flink/reference/plans-pricing)
- [Flink Kubernetes Operator](https://github.com/apache/flink-kubernetes-operator)
- [Flink State Backends](https://nightlies.apache.org/flink/flink-docs-master/docs/ops/state/state_backends/)
- [Flink Checkpointing](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/datastream/fault-tolerance/checkpointing/)
- [FLIP-385: OTel Reporters](https://cwiki.apache.org/confluence/display/FLINK/FLIP-385)
- [Top 10 Challenges of Flink (Decodable)](https://www.decodable.co/blog/top-10-challenges-of-apache-flink)
- [Flink is Overkill for Simple ETL (Kai Waehner)](https://www.kai-waehner.de/blog/2025/01/14/apache-flink-overkill-for-simple-stateless-stream-processing/)
- [Shopify: Optimizing Flink Applications](https://shopify.engineering/optimizing-apache-flink-applications-tips)
- [Confluent Flink Anomaly Detection](https://www.confluent.io/blog/flink-ml-anomaly-detection-for-agentic-investigation-remediation/)

### Combined
- [Netflix: Trillions-Scale Real-Time Infrastructure](https://zhenzhongxu.com/the-four-innovation-phases-of-netflixs-trillions-scale-real-time-data-infrastructure-2370938d7f01)
- [DoorDash: Kafka + Flink Event Processing](https://careersatdoordash.com/blog/building-scalable-real-time-event-processing-with-kafka-and-flink/)
- [AWS: Flink + Prometheus for Observability](https://aws.amazon.com/blogs/big-data/process-millions-of-observability-events-with-apache-flink-and-write-directly-to-prometheus/)
- [Data Streaming Trends 2026 (Kai Waehner)](https://www.kai-waehner.de/blog/2025/12/10/top-trends-for-data-streaming-with-apache-kafka-and-flink-in-2026/)

---

*Research compiled February 2026*
