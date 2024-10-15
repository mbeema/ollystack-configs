# How Tech Giants Process Billions of Signals: Infrastructure Deep Dive

## Scale at a Glance

| Company | System | Scale | Storage |
|---------|--------|-------|---------|
| **Google** | Monarch | **950B time series**, 2.2 TB/sec ingestion, 750 TB in-memory | Custom in-memory TSDB, zone-sharded |
| **Netflix** | Atlas + Edgar + Mantis | **1.2B+ time series**, trillions events/day, 5 TB logs/day | In-memory (Atlas), Cassandra (traces), Elasticsearch (logs), Druid (analytics) |
| **Meta** | ODS/Gorilla + Scuba/Kraken | **150B time series/day**, 12M data points/sec (2015, far more now) | In-memory (Gorilla, 12x compression), HBase backing |
| **Uber** | M3 + Jaeger | **6.6B active time series**, 1B datapoints/sec ingestion | M3DB (11x compression) |
| **AWS** | CloudWatch | **1.2T API requests/mo**, 5 PB logs ingested/day | Proprietary cell-based, S3 tiered |
| **LinkedIn** | InGraphs + Pinot | **100B+ records**, 4,000+ Kafka brokers | Apache Pinot + Kafka |

---

## 1. Netflix (Most Publicly Documented)

### Core Systems

- **Atlas** — In-memory dimensional time series DB. All metrics in JVM heap/off-heap, roaring bitmap indexes, custom stack-based query language. ~2 week retention.
- **Atlas Streaming Eval** — Push-based alerting (replaced polling that had 45-min delays). Queries hashed and distributed to evaluation nodes; metrics pushed in real-time.
- **Spectator + SpectatorD** — Thin client libs (Java, C++, Python, Go, JS) + high-perf sidecar daemon. Apps emit to local SpectatorD via UDP/Unix socket, which aggregates and publishes to Atlas.
- **Edgar** — Distributed tracing on Open-Zipkin. Spans flow through **Mantis** (chained stream processing jobs) for buffering and **tail-based sampling** (20% volume reduction). Stored in **Cassandra** with Zstd compression (71% cost reduction, 35x more data than prior Elasticsearch setup).
- **Mantis** — Real-time stream processing for trillions of events/day. SQL-like streaming queries over raw event streams without pre-aggregation.
- **Druid** — 2M events/sec, 115B rows/day for playback quality analytics.

### Scale Numbers

| Metric | Scale |
|--------|-------|
| Metrics ingestion | 1.2+ billion time series, billions of data points per minute into Atlas |
| Event ingestion (global) | Trillions of events per day across Kafka and Flink |
| Kafka message throughput | 1+ million messages per second per topic, tens of thousands of topics |
| Playback telemetry (Druid) | 2+ million events per second, 115 billion rows per day |
| Log events (Elasticsearch) | 3+ billion documents indexed per day, 5+ TB/day ingested |
| Elasticsearch infrastructure | 700-800 production nodes across ~100 clusters |
| TimeSeries Data Layer writes | Up to 10 million writes per second |
| Flink jobs | 20,000+ Apache Flink jobs in production |
| Monitored devices | 300+ million devices across 4 major UIs |

### Streaming Backbone

Apache Kafka (1M+ msgs/sec/topic, tens of thousands of topics) + 20,000+ Apache Flink jobs.

### Technology Stack

| Layer | Technology |
|-------|------------|
| Message broker | Apache Kafka (tens of thousands of topics, trillions of messages/day) |
| Stream processing | Apache Flink (20,000+ jobs), Mantis (operational/observability streams) |
| Real-time analytics | Apache Druid (subsecond queries over trillions of rows) |
| Metrics (time series) | Atlas (in-memory, JVM heap/off-heap) |
| Distributed traces | Apache Cassandra (Zstd-compressed, migrated from Elasticsearch) |
| Logs | Elasticsearch (700-800 nodes, 100 clusters, 5-day retention) |
| Metrics client | Spectator (Java, C++, Python, Go, JS) |
| Metrics sidecar | SpectatorD (high-performance daemon, text protocol) |
| Tracing | Open-Zipkin (modified) |

### Notable Architectural Patterns

- **Four Phases of Real-Time Infrastructure Evolution (2015-2021)**: Netflix was among the first to scale open-source Kafka and Flink to handle 1 trillion events/day (~2017), then scaled another 20x by 2021.
- **TimeSeries Data Abstraction Layer (2024)**: Purpose-built for immutable temporal event data. Temporal partitioning with event bucketing, multiple storage backends (Cassandra, Elasticsearch), up to 10 million writes/sec.
- **Title Launch Observability**: Each microservice exposes a "Title Health" endpoint answering the "Insight Triad": Is it healthy? If not, why not? How to fix it?

### Sources

- [Atlas Docs - Overview](https://netflix.github.io/atlas-docs/overview/)
- [Introducing Atlas (Netflix TechBlog)](https://netflixtechblog.com/introducing-atlas-netflixs-primary-telemetry-platform-bd31f4d8ed9a)
- [Improved Alerting with Atlas Streaming Eval](https://netflixtechblog.com/improved-alerting-with-atlas-streaming-eval-e691c60dc61e)
- [Building Netflix's Distributed Tracing Infrastructure](https://netflixtechblog.com/building-netflixs-distributed-tracing-infrastructure-bb856c319304)
- [Edgar: Solving Mysteries Faster with Observability](https://netflixtechblog.com/edgar-solving-mysteries-faster-with-observability-e1a76302c71f)
- [Mantis (Netflix Open Source)](https://netflix.github.io/mantis/)
- [Netflix Spectator (GitHub)](https://github.com/Netflix/spectator)
- [SpectatorD (GitHub)](https://github.com/Netflix-Skunkworks/spectatord)
- [Netflix TimeSeries Data Abstraction Layer](https://netflixtechblog.com/introducing-netflix-timeseries-data-abstraction-layer-31552f6326f8)
- [Title Launch Observability at Netflix Scale](https://netflixtechblog.com/title-launch-observability-at-netflix-scale-8efe69ebd653)
- [The Four Innovation Phases of Netflix's Trillions Scale Infrastructure](https://zhenzhongxu.com/the-four-innovation-phases-of-netflixs-trillions-scale-real-time-data-infrastructure-2370938d7f01)

---

## 2. Google

### Monarch — Planet-Scale Time Series Database

Monarch is Google's globally-distributed, in-memory time series database and the backbone of all Google monitoring.

**Scale numbers (July 2019 VLDB paper):**
- **~950 billion time series** stored
- **~750 TB of compressed data** held in memory
- **2.2 TB/sec ingestion rate**
- **Millions of queries served per second**
- Ingestion rate nearly doubled in 6 months after enabling disk I/O metrics
- **38 zones** in the Field Hints Index

**Architecture:**
- Regionalized zones for reliability and scalability, with global query and configuration planes
- Primary principle: local monitoring in regional zones + global management and querying
- Ingestion Routers receive data globally, determine destination zone(s)
- Lexicographic sharding enables zones to scale to tens of thousands of leaves
- Schematized tables with typed key columns; data model is relational, not just key-value
- Supports exemplars that link metrics to Dapper traces

### Borgmon -> Prometheus Lineage

- **Borgmon (2003)**: Built alongside Borg. Introduced alerting on SLOs rather than server health. Decentralized model.
- Ex-Google SREs built **Prometheus** at SoundCloud (2012-2013), directly inspired by Borgmon.
- **Monarch** built to outgrow Borgmon's decentralized limitations.

### Dapper — Distributed Tracing

Foundational system that inspired Jaeger, Zipkin, and the OpenTelemetry tracing specification.

- Low overhead, application-level transparency, ubiquitous deployment
- **Dynamic sampling**: 100% for errors and rare endpoints, probabilistic otherwise
- **Hard 2-week TTL** on trace data
- Integration with Monarch via exemplars

### Google Cloud Products

- **Cloud Trace**: Customer-facing tracing inspired by Dapper; native OTLP ingestion via `telemetry.googleapis.com`
- **Managed Service for Prometheus**: Built on top of Monarch
- **Thanos**: CNCF project described as an "unintentional open source evolution" of Monarch

### Sources

- [Monarch VLDB Paper (Google Research)](https://research.google/pubs/monarch-googles-planet-scale-in-memory-time-series-database/)
- [Dapper Paper (Google Research)](https://research.google/pubs/dapper-a-large-scale-distributed-systems-tracing-infrastructure/)
- [Google SRE Book - Practical Alerting (Borgmon)](https://sre.google/sre-book/practical-alerting/)
- [GCP OpenTelemetry Adoption](https://www.infoq.com/news/2025/09/gcp-opentelemetry-adoption/)

---

## 3. Meta/Facebook

### ODS + Gorilla: Time Series Metrics

- **2 billion unique time series**, **12 million data points added per second** (2015; far larger now)
- 2024 numbers: **150 billion+ time series indexed per day**
- Gorilla handles **40,000+ queries/sec** at peak (vs. 450/sec for original HBase-backed ODS)
- 26-hour in-memory retention window

**Gorilla compression innovation:**
- XOR-based floating-point compression: stores XOR difference between consecutive values
- Delta-of-delta timestamp encoding
- Achieves **12x compression** (16 bytes -> 1.37 bytes average per data point)
- Open-sourced as **Beringei**
- These techniques now used industry-wide by Prometheus, VictoriaMetrics, and others

### Scuba -> Kraken: Real-Time Structured Log Analytics

- Ingests **millions of rows (events) per second**
- Processes **~1 million queries per day**
- Target latency: 2-3s P95, 10-100ms average
- Data available for querying **within 1 minute** of publication
- Grew from terabyte to petabyte scale
- **Kraken** (next-gen replacement) decouples storage from query serving, provides configurable tradeoffs

### Sources

- [Gorilla VLDB Paper](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf)
- [Meta's Next-gen Monitoring Platform (VLDB)](https://www.vldb.org/pvldb/vol15/p3522-mo.pdf)
- [Building Resilient Monitoring at Meta](https://atscaleconference.com/building-resilient-monitoring-at-meta/)

---

## 4. Uber

### M3: Metrics Platform

- **6.6 billion active time series** stored
- **1 billion+ datapoints ingested per second**
- **2 billion+ datapoint reads served per second**
- Aggregates **500 million metrics/sec**, persisting **20 million resulting metrics/sec** globally
- **11x compression ratio**
- A single metric emission can produce **100 million unique time series** at Uber's scale

**Architecture:**
- **M3DB**: Distributed time series database with embedded inverted index
- **M3 Coordinator**: Bridges Prometheus and M3DB
- **M3 Aggregator**: Stateful, cluster-aware downsampling
- **M3QL**: Custom query language (alongside PromQL support)
- Variable retention: 2 days to 5 years at configurable granularity (1s to 10m)
- M3 founding team started **Chronosphere**

### Jaeger v2 (November 2024)

- Rebuilt with **OpenTelemetry Collector at the core**
- Single binary configurable for different roles (collector, ingester, query)
- Storage V2 API: Natively supports OTLP payloads
- Storage backends: Cassandra, Elasticsearch, ClickHouse
- Battle-tested: **20 billion+ requests/day** at Naver
- Jaeger v1 deprecated January 2026

### uMonitor: Alerting

- **125,000 alert configurations** checking **700 million data points** across **1.4 million time series every second**

### Sources

- [M3: Uber's Open Source Metrics Platform](https://www.uber.com/blog/m3/)
- [Uber's Billion Data Point Challenge](https://www.uber.com/blog/billion-data-point-challenge/)
- [Observability at Scale: Uber's Alerting Ecosystem](https://www.uber.com/blog/observability-at-scale/)
- [Jaeger v2 Released (CNCF)](https://www.cncf.io/blog/2024/11/12/jaeger-v2-released-opentelemetry-in-the-core/)

---

## 5. AWS CloudWatch

### Scale Numbers

- **1.2 trillion API requests per month**
- **5 petabytes of log data ingested daily**
- **600 billion log events processed per week** via CloudWatch Logs Insights
- **18 billion automated alarm conditions** evaluated annually
- Average account: 2.5 million datapoints/day (up 18% YoY), 850 log groups (up 29%)
- CloudWatch RUM: 2.4 billion sessions/month

### Architecture

- **Cell-based architecture**: Each cell self-contained for resilience
- **Region-isolated storage**: Metrics stored per Region, cross-Region aggregation at query time
- **Disaggregated microservices**: Low coupling, well-defined APIs

### X-Ray -> OpenTelemetry Transition

- X-Ray SDKs and Daemon enter **maintenance mode February 25, 2026**
- **AWS Distro for OpenTelemetry (ADOT)** is the recommended replacement
- Native OTLP endpoint support added to X-Ray
- ADOT enables sending to multiple backends simultaneously

### Notable Customer: Stripe

- 500M metrics every 10 seconds on **Amazon Managed Prometheus + Amazon Managed Grafana**
- 3,000 engineers across 360 teams
- Five key changes: sharding, aggregation, tiered storage, streaming alerts, isolation

### Sources

- [AWS CloudWatch Statistics 2025](https://sqmagazine.co.uk/aws-cloudwatch-statistics/)
- [How Amazon CloudWatch Works](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_architecture.html)
- [AWS X-Ray Transitions to OpenTelemetry](https://www.infoq.com/news/2025/11/aws-opentelemetry/)
- [Stripe Observability on AWS](https://aws.amazon.com/solutions/case-studies/stripe-architects-case-study/)

---

## 6. LinkedIn

### InGraphs + Apache Pinot

- **100+ Kafka clusters with 4,000+ brokers**
- **Hundreds of billions of records** in Pinot, **1 billion records/day** ingested
- Streaming pipeline: 50,000 messages/sec, enriching with 40 additional fields
- Data freshness: under 1 minute from Kafka to queryable

### ThirdEye: Anomaly Detection

- Monitors **100,000+ time series** across 50+ teams
- Real-time anomaly detection and root-cause analysis
- Leverages Apache Pinot and RocksDB
- Unsupervised ML algorithms for automatic outlier detection

### Sources

- [LinkedIn InGraphs](https://engineering.linkedin.com/blog/2017/08/ingraphs--monitoring-and-unexpected-artwork)
- [Introducing ThirdEye (LinkedIn)](https://engineering.linkedin.com/blog/2019/01/introducing-thirdeye--linkedins-business-wide-monitoring-platfor)
- [Real-Time Analytics with Apache Pinot (LinkedIn)](https://engineering.linkedin.com/blog/2022/real-time-analytics-on-network-flow-data-with-apache-pinot)

---

## 7. Apple

Apple is notably secretive, but job postings and open-source contributions reveal:

- **FoundationDB**: Core storage layer for iCloud/CloudKit (billions of databases)
- **Cassandra**: Exabytes of data, millions of queries
- **Kubernetes, Prometheus, Jaeger**: Used for container orchestration, metrics, and tracing
- **OpenTelemetry**: Required skill for observability roles
- Building "next-gen observability systems" for Search, AIML Infrastructure, and Apple Intelligence
- Presenting on "Leveraging eBPFs and OpenTelemetry to Auto-instrument for Exemplars" at KubeCon EU 2025

### Sources

- [Apple AIML Observability Job Posting](https://jobs.apple.com/en-us/details/200619552-3760/aiml-sr-software-engineer-aiml-observability)

---

## 8. Common Infrastructure Patterns

### Streaming Layer

All use **Kafka** as the universal telemetry bus. **Flink** for stream processing with exactly-once semantics. **Pulsar** emerging for long-retention workloads with decoupled compute/storage.

### Storage Hierarchy

```
Hot (in-memory)  ->  Warm (SSD/block)  ->  Cold (S3/object storage)
  hours-days          days-weeks              months-years
```

### Log Storage: ClickHouse Displacing Elasticsearch

- Zomato: 50+ TB/day, 150M events/min on just 10 nodes, saving $1M+/year
- Columnar storage = 5x better compression than Elasticsearch inverted indices
- Elasticsearch's inverted index maps every term to document IDs — a 50-field log requires updating 50 separate index structures, causing write amplification

### Time-Series DB Comparison

| System | Active Series | Ingestion Rate | Architecture | Compression |
|--------|--------------|----------------|--------------|-------------|
| Monarch (Google) | 950B | TB/s | In-memory, zone-sharded | Custom |
| M3 (Uber) | 6.6B | 1B points/s | Distributed, configurable retention | 11x |
| Gorilla (Meta) | 2B+ | 12M+ points/s | In-memory, replicated | 12x (XOR) |
| Atlas (Netflix) | 1.2B+ | Streaming | Streaming analytics | Custom |
| Mimir (Grafana) | 1B | 50M samples/s | Ring-sharded microservices | Object storage |
| VictoriaMetrics | Billions | Millions/s | Single binary or cluster | 20x |

---

## 9. Sampling Strategies at Scale

### Head Sampling

- Decision at trace initiation, before spans generated
- Computationally cheap, no buffering required
- Cannot make decisions based on trace characteristics (errors, latency)
- Common: percentage-based probabilistic (e.g., keep 10%)

### Tail Sampling

- Waits until trace is complete to decide
- At 1,000 traces/sec with 60-second wait = 60,000 traces buffered simultaneously
- Significant memory pressure but catches all errors and outliers
- Netflix: 20% volume reduction with tail-based sampling

### Adaptive Sampling (Industry Direction)

- ML-driven automatic rate adjustment based on error rates, anomalies, load, query patterns, cost budgets
- Grafana acquired **TailCtrl** (2024) for adaptive trace sampling
- **Adaptive Traces** GA at ObservabilityCON 2025
- Considered the gold standard for production sampling

### OpenTelemetry Sampling Milestones (2025)

- v1.0 of Tracing specification
- Focus on **consistent sampling** across distributed systems
- Ensuring same keep/drop decision across all services in a trace

---

## 10. Cost Management at Scale

**96% of organizations** actively taking steps to control observability costs.

### Strategy 1: Data Volume Reduction (30-80% savings)

**Grafana Adaptive Telemetry Suite:**
- Adaptive Metrics: ~35% reduction in metrics costs
- Adaptive Logs: Drop unused/low-value logs
- Adaptive Traces: Tail-sampling to keep only valuable traces
- Adaptive Profiles: Dynamic profiling detail adjustment

**Cribl Stream:** 30-50% volume reduction ($3.5B valuation, Aug 2024)

### Strategy 2: Tiered Storage

- Hot (in-memory/SSD) -> Warm (block) -> Cold (object storage)
- ClickHouse tiered storage: ad-hoc queries on petabytes of cold data
- Grafana Tempo: All traces in object storage from the start

### Strategy 3: Cardinality Control

- Strip high-cardinality labels at collector (pod UIDs, container IDs, replica set hashes)
- Aggregate by removing ephemeral dimensions
- OTel Collector processors: filter, transform, attributes

### Strategy 4: Platform Migration

- **Stripe**: Proprietary vendor -> Amazon Managed Prometheus + Grafana
- **Uber**: Cut hundreds of thousands in license fees -> open-source stack (Prometheus + Thanos + Grafana)

### Strategy 5: Value-Based Instrumentation

Monitorama 2024 consensus: "Storing every raw event usually only benefits the vendor." Aggregate where possible, store raw only for high-value signals.

---

## 11. OpenTelemetry Adoption

### Adoption Numbers (2025)

- **79% of organizations** using OpenTelemetry
- **48% actively using** in production
- **45% YoY increase** in GitHub commits (2024)
- **10,000 individual contributors** from 1,200 companies
- Surpassed Kubernetes as the **largest CNCF project by contributors** (2024)
- **81% consider OTel mature enough** for production
- **46% achieving 20%+ ROI**

### Major Enterprise Adopters

- **eBay**: OTel Collector reduced resource consumption ~90% vs metricbeat
- **Shopify**: Migrated to OTel, presenting at KubeCon EU 2025
- **Stripe**: OTel with Honeycomb for tracing + managed Prometheus/Grafana
- **Apple**: Investing in OTel + eBPF integration
- **AWS**: X-Ray SDKs -> ADOT (maintenance mode Feb 2026)
- **Google**: Cloud Trace accepts native OTLP

### 2025-2026 OTel Roadmap

- Collector v1.0 stabilization
- Profiling as fourth signal type (2024)
- Consistent sampling across distributed systems
- Semantic conventions for LLM/AI observability
- Growing eBPF integration for zero-instrumentation telemetry

### Sources

- [Grafana OpenTelemetry Report](https://grafana.com/opentelemetry-report/)
- [eBay Pivoting to OpenTelemetry](https://innovation.ebayinc.com/stories/why-and-how-ebay-pivoted-to-opentelemetry/)
- [OpenTelemetry Sampling Milestones](https://opentelemetry.io/blog/2025/sampling-milestones/)
- [OpenTelemetry Collector Benchmarks](https://opentelemetry.io/docs/collector/benchmarks/)

---

## 12. Reference Architecture (Composite)

```
[Applications / Services]
        |
   [OTel SDK / eBPF / Auto-instrumentation]
        |
   [OTel Collector Fleet]  -- filter, sample, aggregate, route
        |
   [Kafka / Pulsar]  -- buffer, decouple, replay
        |
   +---------+---------+---------+
   |         |         |         |
 [Flink]  [Flink]   [Flink]   [Direct]
   |         |         |         |
 Metrics    Logs     Traces    Alerts
   |         |         |         |
 [Mimir/  [Click-  [Tempo/   [Alert-
  M3/VM/   House/   Click-    manager/
  AMP]     Loki]    House]    PagerDuty]
   |         |         |
   +----+----+----+----+
        |
   [Grafana / Custom UI]
        |
   [Adaptive Telemetry / Cost Controls]
```

### Key Design Principles (Observed Across All)

1. **Decouple ingestion from storage** via Kafka/Pulsar
2. **Pre-aggregate before storage** via Flink or OTel Collector processors
3. **Use columnar storage** (ClickHouse, Parquet) over inverted indices for write-heavy workloads
4. **Tier storage** by age and access frequency
5. **Sample intelligently** — adaptive/tail over head sampling
6. **Control cardinality** at the collector, not the backend
7. **Standardize on OpenTelemetry** for vendor independence
8. **In-memory first** for hot data with aggressive compression (11-12x ratios)
9. **Streaming-first alerting** — evaluate queries as data arrives, not by polling
10. **Separate ingestion, processing, and query planes** for independent scaling

---

*Research compiled February 2026*
