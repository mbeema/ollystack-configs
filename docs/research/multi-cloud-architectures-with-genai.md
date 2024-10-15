# Multi-Cloud Observability Architectures with GenAI Integration

> Two production-proven architecture patterns for processing billions of signals
> efficiently across AWS, Azure, and GCP — with AI-powered root cause analysis,
> natural language querying, and autonomous incident response.

---

## Why Two Architectures?

There is no golden rule. The right choice depends on your constraints:

| Constraint | Architecture A | Architecture B |
|------------|---------------|---------------|
| **Data sovereignty** | Strong (GDPR, DORA, regional laws) | Flexible |
| **Team structure** | Autonomous product teams per region | Central platform team |
| **Signal volume** | 10B+ events/day, multi-region | 1B-50B events/day |
| **Cost priority** | Control egress, keep data local | Minimize storage + compute |
| **AI maturity** | Central AI brain, federated data | Embedded AI at every layer |
| **Complexity tolerance** | Higher (distributed systems expertise) | Moderate (streaming expertise) |

---

## Architecture A: Federated Regional with Central AI Brain

### Philosophy

Process signals close to the source. Store raw data regionally. Only aggregated,
sampled, PII-scrubbed signals flow to a central layer. The central layer runs
GenAI-powered correlation, natural language querying, and autonomous investigation
across all regions — without moving raw data.

### The Big Picture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CENTRAL AI LAYER                                 │
│                                                                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐  │
│  │  AI Correlation   │  │  NL Query Engine │  │  Agentic SRE        │  │
│  │  Engine           │  │                  │  │  (Incident Response) │  │
│  │                   │  │  "Why is checkout │  │                     │  │
│  │  Causal AI +      │  │   slow in EU?"   │  │  Hypothesis →       │  │
│  │  Topology Graph   │  │       ↓          │  │  Investigate →      │  │
│  │  + LLM Reasoning  │  │  PromQL/LogQL/   │  │  Validate →         │  │
│  │                   │  │  TraceQL + Fan   │  │  Remediate          │  │
│  │  Cross-region     │  │  out to regions  │  │                     │  │
│  │  pattern matching │  │                  │  │  RAG over runbooks  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Central Stores (aggregated + sampled data only)                 │   │
│  │                                                                  │   │
│  │  Metrics: Mimir/VictoriaMetrics  (aggregated, long retention)    │   │
│  │  Traces:  Tempo/Jaeger           (tail-sampled, errors + slow)   │   │
│  │  Logs:    Loki                   (error logs, SLO violations)    │   │
│  │  Knowledge: Vector DB            (embeddings for log similarity) │   │
│  │  LLM Telemetry: OTel GenAI      (token/cost/latency tracking)   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  OpAMP Control Plane (fleet management for all collectors)       │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────┬────────────────────┬───────────────────────────────┘
                     │                    │
        Aggregated   │                    │  Aggregated
        + Sampled    │                    │  + Sampled
                     │                    │
┌────────────────────┴──┐  ┌──────────────┴───────────────────────────────┐
│   REGION: US-EAST     │  │   REGION: EU-WEST                            │
│   (AWS + GCP)         │  │   (Azure + AWS)                              │
│                       │  │                                               │
│  ┌─────────────────┐  │  │  ┌─────────────────┐                         │
│  │ Regional Gateway │  │  │  │ Regional Gateway │                        │
│  │                  │  │  │  │                  │                         │
│  │ • Tail sampling  │  │  │  │ • Tail sampling  │                        │
│  │ • PII redaction  │  │  │  │ • PII redaction  │  ← GDPR enforcement   │
│  │ • Cardinality    │  │  │  │ • GDPR hashing   │                        │
│  │   reduction      │  │  │  │ • Cardinality    │                        │
│  │ • Cost routing   │  │  │  │   reduction      │                        │
│  │ • Local alerting │  │  │  │ • Cost routing   │                        │
│  │                  │  │  │  │ • Local alerting │                        │
│  └────────┬────────┘  │  │  └────────┬─────────┘                        │
│           │           │  │           │                                    │
│  ┌────────┴────────┐  │  │  ┌────────┴─────────┐                        │
│  │ Regional Stores │  │  │  │ Regional Stores   │                        │
│  │ (full fidelity) │  │  │  │ (full fidelity)   │                        │
│  │                 │  │  │  │                    │                        │
│  │ Metrics: Mimir  │  │  │  │ Metrics: Mimir    │                        │
│  │ Traces: Tempo   │  │  │  │ Traces: Tempo     │                        │
│  │ Logs: Loki/CH   │  │  │  │ Logs: Loki/CH     │                        │
│  │ Ret: 7-14 days  │  │  │  │ Ret: 14-30 days   │  ← Longer for GDPR   │
│  └─────────────────┘  │  │  └──────────────────┘                        │
│                        │  │                                               │
│  ┌──────┐  ┌──────┐   │  │  ┌──────┐  ┌──────┐                          │
│  │ AWS  │  │ GCP  │   │  │  │Azure │  │ AWS  │                          │
│  │ EKS  │  │ GKE  │   │  │  │ AKS  │  │ EKS  │                          │
│  │      │  │      │   │  │  │      │  │      │                          │
│  │OTel  │  │OTel  │   │  │  │OTel  │  │OTel  │                          │
│  │Agent │  │Agent │   │  │  │Agent │  │Agent │                          │
│  │+OBI  │  │+OBI  │   │  │  │+OBI  │  │+OBI  │                          │
│  └──────┘  └──────┘   │  │  └──────┘  └──────┘                          │
└────────────────────────┘  └──────────────────────────────────────────────┘
```

### Layer-by-Layer Breakdown

#### Layer 1: Instrumentation (Per Workload)

Three-tier instrumentation at every workload, regardless of cloud:

```
Tier 1: OBI/eBPF           → Automatic RED metrics + basic traces (zero code)
Tier 2: Auto-instrumentation → Framework-aware spans (minimal code)
Tier 3: SDK instrumentation  → Business logic spans + custom attributes (code)
```

**OBI (OpenTelemetry eBPF Instrumentation)** provides baseline visibility:
- Automatic HTTP/gRPC/DB metrics and traces without code changes
- <1% CPU overhead, works across Go, Java, Python, Node.js, .NET, Rust
- Requires Linux kernel 5.8+ (all major cloud providers support this)
- Limitation: no custom business attributes — SDK needed for "why" context

**OTel SDK + Auto-Instrumentation** for depth:
- W3C Trace Context propagation across cloud boundaries
- OTel GenAI semantic conventions for LLM workloads:
  ```
  gen_ai.system: "openai"
  gen_ai.request.model: "gpt-4o"
  gen_ai.usage.input_tokens: 1250
  gen_ai.usage.output_tokens: 380
  gen_ai.agent.name: "checkout-recommender"
  ```

**Cloud-native receivers** for managed service telemetry:
- AWS: `awscloudwatch/*`, `awscontainerinsights`, `awsxray`
- Azure: `azuremonitor/*`, `azureeventhub`
- GCP: `googlecloudmonitoring/*`, `googlecloudspanner`

#### Layer 2: Agent Collectors (Per Node — DaemonSet)

One OTel Collector DaemonSet per Kubernetes cluster (or per VM host):

```yaml
# Agent collector — runs on every node
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }
  hostmetrics:
    collection_interval: 30s
    scrapers: [cpu, memory, disk, network, filesystem]
  filelog:
    include: [/var/log/pods/*/*/*.log]
    operators:
      - type: container
        id: container-parser

processors:
  batch:
    send_batch_size: 1024
    timeout: 2s
  memory_limiter:
    check_interval: 5s
    limit_mib: 256
    spike_limit_mib: 64
  resource:
    attributes:
      - key: cloud.provider
        value: "${CLOUD_PROVIDER}"   # aws | azure | gcp
        action: upsert
      - key: cloud.region
        value: "${CLOUD_REGION}"
        action: upsert
      - key: k8s.cluster.name
        value: "${CLUSTER_NAME}"
        action: upsert
      - key: deployment.environment
        value: "${ENVIRONMENT}"
        action: upsert

exporters:
  loadbalancing:
    routing_key: traceID
    protocol:
      otlp:
        tls:
          insecure: false
    resolver:
      dns:
        hostname: regional-gateway-headless.monitoring.svc
        port: 4317
```

**Sizing**: 200-500m CPU, 256 MiB memory per node.

#### Layer 3: Regional Gateway (Per Region)

The regional gateway is the brain of each region. It handles:

1. **Tail sampling** — keep errors, slow traces, probabilistic sample the rest
2. **PII redaction** — hash emails, delete IPs, redact SSNs before any cross-region flow
3. **Cardinality reduction** — strip pod_uid, container_id, replica_set_hash
4. **Cost routing** — errors to hot storage, debug to cold, health checks to /dev/null
5. **Local alerting** — regional alerts fire without depending on the central layer

```yaml
# Regional gateway — Deployment with HPA
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }

processors:
  # MUST be first — prevents OOM
  memory_limiter:
    check_interval: 1s
    limit_mib: 1500
    spike_limit_mib: 300

  # Tail sampling: keep errors + slow + 10% probabilistic
  tail_sampling:
    decision_wait: 30s
    num_traces: 50000
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow-traces
        type: latency
        latency: { threshold_ms: 3000 }
      - name: probabilistic
        type: probabilistic
        probabilistic: { sampling_percentage: 10 }

  # PII redaction (critical for GDPR regions)
  redaction:
    blocked_values:
      - "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z]{2,}\\b"  # emails
      - "\\b\\d{3}-\\d{2}-\\d{4}\\b"                              # SSN
  attributes:
    actions:
      - key: user.email
        action: hash
      - key: http.client_ip
        action: delete
      - key: user.id
        action: hash

  # Cardinality reduction
  metricstransform:
    transforms:
      - include: ".*"
        action: update
        operations:
          - action: delete_label_value
            label: pod_uid
          - action: delete_label_value
            label: container_id

  # Cost routing
  filter:
    logs:
      exclude:
        match_type: regexp
        bodies:
          - ".*health_check.*"
          - ".*readiness_probe.*"
          - ".*liveness_probe.*"
          - ".*OPTIONS /"

  batch:
    send_batch_size: 8192
    timeout: 5s

exporters:
  # Full-fidelity to regional store
  otlp/regional:
    endpoint: regional-mimir:4317
    sending_queue:
      queue_size: 5000
      num_consumers: 10
    retry_on_failure:
      initial_interval: 5s
      max_interval: 60s

  # Aggregated + sampled to central
  otlp/central:
    endpoint: central-gateway.corp.internal:4317
    sending_queue:
      queue_size: 2000
      num_consumers: 4
    headers:
      X-Region: "${REGION}"

  # Cold storage for low-value signals
  awss3:
    s3uploader:
      region: "${AWS_REGION}"
      s3_bucket: "observability-cold-${REGION}"
      s3_partition: "year=%Y/month=%m/day=%d/hour=%H"
      file_prefix: "logs"
      marshaler: otlp_json

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, redaction, attributes, tail_sampling, batch]
      exporters: [otlp/regional, otlp/central]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, metricstransform, filter, batch]
      exporters: [otlp/regional, otlp/central]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, redaction, attributes, filter, batch]
      exporters: [otlp/regional, awss3]   # Logs stay regional + cold archive
```

**Sizing**: 2-4 CPU, 2-4 GiB memory per gateway pod. HPA on CPU (target 70%).

#### Layer 4: Regional Storage

Each region runs its own storage stack for full-fidelity data:

| Signal | Technology | Retention | Purpose |
|--------|-----------|-----------|---------|
| Metrics | Mimir (or VictoriaMetrics) | 14 days full, 90 days downsampled | Regional dashboards, alerts |
| Traces | Tempo (or Jaeger v2 on ClickHouse) | 7 days | Regional trace investigation |
| Logs | ClickHouse (hot) + S3 Parquet (cold) | 3 days hot, 1 year cold | Regional log search, compliance |
| Profiles | Pyroscope | 7 days | Regional performance profiling |

**Why ClickHouse for regional logs?**
- 6x less storage than Elasticsearch
- Handles 50+ TB/day on 10 nodes (Zomato benchmark)
- Columnar compression + sparse indexing = fast analytical queries
- Schema-on-write for alerting fields, schema-on-read for exploration

**Why Parquet + S3 for cold logs?**
- Object storage pricing (~$0.023/GB/month vs $0.10+/GB for hot)
- Queryable via DuckDB, Athena, or BigQuery for compliance audits
- Time-partitioned files enable efficient range scans

#### Layer 5: Central AI Layer

This is what makes federated observability actually work at scale.

**Component 1: AI Correlation Engine**

```
┌──────────────────────────────────────────────────┐
│              AI Correlation Engine                 │
│                                                    │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │ Topology     │  │ Causal AI    │  │ LLM      │ │
│  │ Graph        │  │ (walks the   │  │ Layer    │ │
│  │              │  │  graph for   │  │ (explains│ │
│  │ Service →    │  │  root cause) │  │  findings│ │
│  │ Service deps │  │              │  │  in NL)  │ │
│  │ Cloud→Cloud  │  │ Deterministic│  │          │ │
│  │ Region→Region│  │ not guessing │  │ RAG over │ │
│  │              │  │              │  │ runbooks │ │
│  └─────────────┘  └──────────────┘  └──────────┘ │
│                                                    │
│  Input: aggregated metrics + sampled traces +      │
│         error logs from all regions                │
│  Output: cross-region root cause analysis          │
└──────────────────────────────────────────────────┘
```

The key insight from Dynatrace, Datadog, and Grafana: **LLMs explain, causal AI decides**.
The LLM never guesses at root cause. It summarizes what the deterministic engine found.

**Component 2: Natural Language Query Engine**

Translates human questions into federated queries across regions:

```
Engineer: "Why is checkout latency high in EU?"

    → NL-to-Query translation (LLM + RAG):
      PromQL: histogram_quantile(0.99, rate(http_server_duration_bucket{
                service="checkout", cloud_region=~"eu-.*"}[5m]))
      LogQL:  {service="checkout", region=~"eu-.*"} |= "error" | logfmt
      TraceQL: {resource.service.name="checkout" && span.duration > 3s
                && resource.cloud.region =~ "eu-.*"}

    → Fan out to EU-WEST regional stores
    → Aggregate results
    → LLM summarizes: "Checkout P99 latency spiked to 4.2s in eu-west-1
       at 14:32 UTC. Root cause: Azure SQL connection pool exhaustion
       after deployment v2.4.1. 340 error traces captured. Suggested fix:
       increase max_pool_size from 20 to 50."
```

**Component 3: Agentic SRE**

Autonomous incident response using the AI Correlation Engine + RAG over runbooks:

```
1. Alert fires: "Checkout error rate > 5% in EU-WEST"
2. Agentic SRE activates:
   a. Queries regional stores for error traces (fan-out)
   b. Correlates with recent deployments (git history)
   c. Walks topology graph for upstream/downstream impact
   d. Searches vector DB for similar past incidents
   e. RAG over runbooks for remediation steps
3. Output to Slack/Teams:
   "🔍 Investigation complete:
    - Root cause: OOM in checkout-service pods after v2.4.1 deploy
    - Impact: 12% of EU checkout requests failing
    - Similar incident: INC-2847 (2025-11-03), resolved by rollback
    - Suggested action: kubectl rollout undo deployment/checkout -n prod-eu
    - Confidence: HIGH (3 correlated signals)"
4. Human approves → agent executes remediation
```

**Component 4: Vector DB for Knowledge**

```
┌─────────────────────────────────────────────┐
│              Vector DB (Milvus/Weaviate)      │
│                                               │
│  Embeddings:                                  │
│  • Past incident postmortems                  │
│  • Runbook steps                              │
│  • Error message clusters                     │
│  • Stack trace patterns                       │
│  • Slack/Teams resolution threads             │
│  • Architecture decision records              │
│                                               │
│  Used by:                                     │
│  • RAG pipeline (ground LLM responses)        │
│  • Similar incident search                    │
│  • Error deduplication                         │
│  • "Have we seen this before?" queries        │
└─────────────────────────────────────────────┘
```

**Component 5: LLM Observability (Monitor the AI itself)**

Using OTel GenAI semantic conventions to monitor AI workloads:

```yaml
# OTel GenAI attributes on every LLM call
gen_ai.system: "anthropic"
gen_ai.request.model: "claude-sonnet-4-5-20250929"
gen_ai.operation.name: "chat"
gen_ai.usage.input_tokens: 2400
gen_ai.usage.output_tokens: 850
gen_ai.agent.name: "incident-investigator"
gen_ai.conversation.id: "inc-2901-investigation"

# Custom business attributes
gen_ai.response.latency_ms: 1200
gen_ai.cost.usd: 0.024
gen_ai.hallucination.detected: false
```

Dashboard panels:
- Token usage per AI agent per day (cost tracking)
- LLM response latency P50/P95/P99
- Hallucination detection rate
- Query-to-answer accuracy (feedback loop)

#### Layer 6: Fleet Management (OpAMP)

Centralized control of all collectors across all clouds and regions:

```
OpAMP Control Plane
    ├── Push config updates to all agents/gateways
    ├── Monitor collector health (CPU, memory, queue depth)
    ├── Safe rollout/rollback of collector versions
    ├── Per-region override for GDPR/sovereignty policies
    └── Dynamic sampling rate adjustment based on budget
```

### Cost Model

```
Regional costs (per region):
  Agents:    ~$200-500/mo (CPU/memory on existing nodes)
  Gateways:  ~$500-2,000/mo (2-8 pods, 2-4 CPU each)
  Storage:   ~$2,000-10,000/mo (depends on retention + volume)

Central costs:
  AI layer:      ~$1,000-5,000/mo (LLM API + compute)
  Central store: ~$3,000-15,000/mo (aggregated data, long retention)
  Vector DB:     ~$500-2,000/mo
  OpAMP:         ~$200-500/mo

Cross-cloud egress:
  Only aggregated + sampled data crosses regions
  Typical: 5-15% of raw volume → 85-95% egress savings vs centralized
```

### When to Choose Architecture A

- Regulated industries (finance, healthcare, government)
- Multiple autonomous teams that own their observability
- Strong data sovereignty requirements (GDPR, DORA)
- Need for graceful degradation (regions work independently if central is down)
- Organizations with 50+ microservices across 3+ clouds

---

## Architecture B: Streaming-First with Embedded AI

### Philosophy

Every signal flows through a unified streaming backbone (Kafka). AI is embedded
at every layer — not just centralized. Edge intelligence at agents, stream
intelligence at Flink, and deep intelligence at the query layer. Optimized for
real-time detection and minimal storage cost.

### The Big Picture

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      UNIFIED QUERY + AI LAYER                              │
│                                                                            │
│  ┌────────────────────┐ ┌────────────────────┐ ┌────────────────────────┐  │
│  │ Grafana + AI       │ │ NL Query Interface │ │ Agentic Investigation  │  │
│  │ Assistant          │ │ (text → PromQL/    │ │                        │  │
│  │                    │ │  LogQL/TraceQL/SQL)│ │ Multi-agent swarm:     │  │
│  │ Unified dashboards │ │                    │ │ • Metrics analyzer     │  │
│  │ across all clouds  │ │ Grounded in RAG    │ │ • Log pattern matcher  │  │
│  │                    │ │ over knowledge base│ │ • Trace path analyzer  │  │
│  │ SLO tracking       │ │                    │ │ • Deploy correlator    │  │
│  │ Incident mgmt      │ │                    │ │ • Profile investigator │  │
│  └────────────────────┘ └────────────────────┘ └────────────────────────┘  │
└────────────────────────────────┬───────────────────────────────────────────┘
                                 │
┌────────────────────────────────┴───────────────────────────────────────────┐
│                      TIERED STORAGE LAYER                                  │
│                                                                            │
│  HOT (3-14 days)              WARM (14-90 days)        COLD (1-7 years)   │
│  ┌──────────────────┐         ┌─────────────────┐      ┌───────────────┐  │
│  │ ClickHouse       │         │ ClickHouse Cold │      │ S3/GCS/Azure  │  │
│  │ (metrics+logs+   │  TTL ─→ │ Storage (tiered │ TTL→ │ Blob          │  │
│  │  traces unified) │         │  to object)     │      │ (Parquet/     │  │
│  │                  │         │                 │      │  Iceberg)     │  │
│  │ OR:              │         │ OR:             │      │               │  │
│  │ Mimir (metrics)  │         │ Mimir long-term │      │ Queryable via │  │
│  │ Loki (logs)      │         │ Tempo compacted │      │ Athena/BQ/    │  │
│  │ Tempo (traces)   │         │                 │      │ DuckDB        │  │
│  └──────────────────┘         └─────────────────┘      └───────────────┘  │
│                                                                            │
│  Vector DB (Milvus/Weaviate): incident embeddings, runbook chunks,        │
│  error clusters, architecture docs                                         │
└────────────────────────────────┬───────────────────────────────────────────┘
                                 │
┌────────────────────────────────┴───────────────────────────────────────────┐
│                      STREAM PROCESSING LAYER                               │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Apache Flink Cluster                               │  │
│  │                                                                      │  │
│  │  Job 1: Metrics Aggregation                                          │  │
│  │  • Pre-aggregate high-cardinality metrics                            │  │
│  │  • Delta-of-delta compression                                        │  │
│  │  • Cardinality reduction (strip ephemeral labels)                    │  │
│  │  • Output: aggregated metrics → storage                              │  │
│  │                                                                      │  │
│  │  Job 2: Trace Assembly + Tail Sampling                               │  │
│  │  • Buffer spans by traceID (60-second window)                        │  │
│  │  • Assemble complete traces                                          │  │
│  │  • Tail sample: keep errors + slow + 10% probabilistic              │  │
│  │  • Output: sampled traces → storage                                  │  │
│  │                                                                      │  │
│  │  Job 3: Log Intelligence                                             │  │
│  │  • ML anomaly detection on log patterns (streaming)                  │  │
│  │  • Error clustering via embeddings                                   │  │
│  │  • Severity-based routing (ERROR→hot, DEBUG→cold, noise→drop)        │  │
│  │  • PII detection + redaction                                         │  │
│  │  • Output: classified logs → tiered storage                          │  │
│  │                                                                      │  │
│  │  Job 4: Cross-Signal Correlation (AI-embedded)                       │  │
│  │  • Join metrics anomalies + error logs + slow traces in real-time    │  │
│  │  • Topology-aware: knows which services call which                   │  │
│  │  • Fires enriched alerts with pre-correlated context                 │  │
│  │  • Output: correlated incidents → alerting + AI investigation        │  │
│  │                                                                      │  │
│  │  Job 5: GenAI Workload Monitoring                                    │  │
│  │  • Aggregate gen_ai.* attributes from OTel spans                     │  │
│  │  • Track token usage, cost, latency per model/agent                  │  │
│  │  • Detect cost anomalies (unexpected token spikes)                   │  │
│  │  • Output: AI observability metrics → storage + alerts               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬───────────────────────────────────────────┘
                                 │
┌────────────────────────────────┴───────────────────────────────────────────┐
│                      KAFKA BACKBONE                                        │
│                                                                            │
│  Topics:                                                                   │
│  ├── otel.metrics.raw      (all raw metrics from all clouds)              │
│  ├── otel.traces.raw       (all raw spans from all clouds)                │
│  ├── otel.logs.raw         (all raw logs from all clouds)                 │
│  ├── otel.profiles.raw     (continuous profiling data)                    │
│  ├── otel.genai.raw        (LLM/AI workload telemetry)                   │
│  ├── alerts.correlated     (output of Flink correlation job)              │
│  └── incidents.enriched    (AI-enriched incident context)                 │
│                                                                            │
│  Partitioning: by traceID (traces), service.name (metrics/logs)           │
│  Retention: 72 hours (replay window for reprocessing)                     │
│  Compression: zstd                                                         │
│  Tiered storage: auto-offload to S3 after 24 hours                        │
└────────────────────────────────┬───────────────────────────────────────────┘
                                 │
┌────────────────────────────────┴───────────────────────────────────────────┐
│                      COLLECTION LAYER                                      │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    OTel Gateway Fleet                                 │  │
│  │                    (per cloud / per cluster)                          │  │
│  │                                                                      │  │
│  │  • Receives from agents via OTLP gRPC                                │  │
│  │  • First-pass filtering (drop health checks, probes, noise)          │  │
│  │  • Resource enrichment (cloud.provider, region, cluster, env)        │  │
│  │  • Batching + compression (OTLP Arrow: 30-70% bandwidth savings)     │  │
│  │  • Export to Kafka (kafka exporter with zstd)                        │  │
│  │  • Managed via OpAMP control plane                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌──────────────────────┐ │
│  │ AWS EKS     │ │ Azure AKS   │ │ GCP GKE     │ │ On-Prem / Edge       │ │
│  │             │ │             │ │             │ │                      │ │
│  │ OTel Agent  │ │ OTel Agent  │ │ OTel Agent  │ │ OTel Agent (minimal) │ │
│  │ (DaemonSet) │ │ (DaemonSet) │ │ (DaemonSet) │ │ + NATS JetStream     │ │
│  │ + OBI/eBPF  │ │ + OBI/eBPF  │ │ + OBI/eBPF  │ │ (store-and-forward)  │ │
│  │             │ │             │ │             │ │                      │ │
│  │ CloudWatch  │ │ AzureMonitor│ │ Cloud Mon.  │ │ hostmetrics          │ │
│  │ receivers   │ │ receivers   │ │ receivers   │ │ filelog              │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └──────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────┘
```

### Layer-by-Layer Breakdown

#### Layer 1: Collection (Same as Architecture A + Edge)

Same three-tier instrumentation (OBI → Auto → SDK), with one addition:

**Edge / On-Prem**: NATS JetStream for store-and-forward telemetry:
```
Edge Device → OTel Agent → NATS JetStream (local buffer)
                                    ↓ (when connected)
                              Kafka (central backbone)
```

NATS advantages for edge:
- <20 MB memory footprint (vs 1GB+ for Kafka)
- Persistent buffering during connectivity outages
- Subject-based routing for filtering at the edge
- Automatic replay of buffered data when connection restores

#### Layer 2: Gateway Fleet

Per-cluster gateways export to Kafka instead of directly to storage:

```yaml
exporters:
  kafka/metrics:
    brokers: ["kafka-1:9092", "kafka-2:9092", "kafka-3:9092"]
    topic: "otel.metrics.raw"
    encoding: otlp_proto
    producer:
      compression: zstd
      flush_max_messages: 500

  kafka/traces:
    brokers: ["kafka-1:9092", "kafka-2:9092", "kafka-3:9092"]
    topic: "otel.traces.raw"
    encoding: otlp_proto
    producer:
      compression: zstd

  kafka/logs:
    brokers: ["kafka-1:9092", "kafka-2:9092", "kafka-3:9092"]
    topic: "otel.logs.raw"
    encoding: otlp_proto
    producer:
      compression: zstd
```

**Why Kafka as the backbone?**
1. **Burst absorption**: Handle traffic spikes without dropping signals
2. **Replay**: Reprocess historical telemetry through new Flink jobs
3. **Fan-out**: Single ingestion, multiple consumers (Flink + direct storage + alerting)
4. **Decoupling**: Backends can be down for maintenance without losing data
5. **Cross-cloud buffer**: 72-hour retention window covers any outage

#### Layer 3: Flink Stream Processing

This is the differentiator of Architecture B. Flink processes signals in-stream
with AI-embedded intelligence before anything hits storage.

**Job 1: Metrics Aggregation**
```
Kafka(otel.metrics.raw) → Flink:
  • Strip pod_uid, container_id, replica_set_hash
  • Convert /users/12345/orders → /users/*/orders
  • Aggregate per service+method+status (not per pod)
  • Result: 99%+ cardinality reduction
  → ClickHouse/Mimir (hot metrics)
```

**Job 2: Trace Assembly + Sampling**
```
Kafka(otel.traces.raw) → Flink:
  • Buffer spans by traceID (60-second window)
  • Assemble complete traces from cross-cloud spans
  • Tail sample:
    - 100% of errors (status_code = ERROR)
    - 100% of slow traces (duration > P99 threshold)
    - 100% of traces touching GenAI services
    - 10% probabilistic for everything else
  • Result: 60-80% trace volume reduction
  → ClickHouse/Tempo (hot traces)
```

**Job 3: Log Intelligence (AI-embedded)**
```
Kafka(otel.logs.raw) → Flink:
  • ML model: streaming anomaly detection on log patterns
  • Embedding model: cluster similar errors in real-time
  • PII detection + redaction (regex + ML classifier)
  • Route by intelligence:
    - Anomalous/error logs → hot storage (ClickHouse)
    - Normal operational logs → warm storage (ClickHouse cold tier)
    - Debug/health check logs → cold storage (S3 Parquet)
    - Noise (probes, OPTIONS) → /dev/null
  • Result: 70-90% hot storage reduction
  → Tiered storage
```

**Job 4: Cross-Signal Correlation**
```
Kafka(otel.metrics.raw + otel.traces.raw + otel.logs.raw) → Flink:
  • Windowed join: correlate metric anomalies with error traces
  • Topology-aware: knows service dependency graph
  • When correlation detected:
    - Create enriched alert with pre-correlated context
    - Include: metric anomaly + related errors + sample trace IDs
    - Publish to alerts.correlated topic
  → Alertmanager → Agentic AI investigation
```

**Job 5: GenAI Workload Monitoring**
```
Kafka(otel.genai.raw) → Flink:
  • Aggregate token usage per model, per agent, per hour
  • Detect cost anomalies (>2 std dev from baseline)
  • Track latency distributions per model
  • Calculate per-request cost
  → AI Observability Dashboard
```

#### Layer 4: Tiered Storage

Single unified storage with automatic tiering:

**Option A: ClickHouse-Centric (Recommended for cost efficiency)**

```
ClickHouse Cluster:
  ├── Hot tier (NVMe SSD): 3-14 days, all signal types
  │   • Sparse indexing (1 entry per 8K rows)
  │   • LZ4 compression for fast queries
  │   • Schema: metrics, logs, traces in separate tables
  │
  ├── Warm tier (gp3 EBS): 14-90 days
  │   • ZSTD compression for better ratios
  │   • Same schema, auto-migrated via TTL
  │
  └── Cold tier (S3): 90 days - 7 years
      • Parquet format via ClickHouse S3 table engine
      • Queryable on-demand (slower but cheap)
      • Compliance and historical analysis
```

**Option B: LGTM Stack (Recommended for Grafana ecosystem)**

```
Mimir:     Metrics (hot: 14 days, long-term: 1 year via object storage)
Loki:      Logs (hot: 7 days, label-indexed, chunks in object storage)
Tempo:     Traces (all in object storage, Parquet format, constant-time ID lookup)
Pyroscope: Profiles (hot: 7 days)
```

#### Layer 5: AI Query + Investigation Layer

**Multi-Agent Investigation Swarm** (inspired by Grafana Assistant Investigations):

```
Alert fires → Orchestrator Agent activates:

  ┌─────────────────────────────────────────────────────────┐
  │                  Orchestrator Agent                      │
  │  (coordinates investigation, synthesizes findings)       │
  └──────┬──────────┬──────────┬──────────┬─────────────────┘
         │          │          │          │
  ┌──────┴───┐ ┌────┴─────┐ ┌─┴────────┐ ┌┴──────────────┐
  │ Metrics  │ │ Log      │ │ Trace    │ │ Deploy        │
  │ Analyzer │ │ Pattern  │ │ Path     │ │ Correlator    │
  │          │ │ Matcher  │ │ Analyzer │ │               │
  │ Queries  │ │ Searches │ │ Finds    │ │ Checks git    │
  │ Mimir/CH │ │ Loki/CH  │ │ Tempo/CH │ │ history,      │
  │ for      │ │ for      │ │ for slow │ │ CI/CD events, │
  │ anomalies│ │ errors   │ │ paths    │ │ config changes│
  └──────┬───┘ └────┬─────┘ └─┬────────┘ └┬──────────────┘
         │          │          │           │
  ┌──────┴──────────┴──────────┴───────────┴──────────────┐
  │              RAG Knowledge Base                        │
  │  • Past incident postmortems (embeddings)             │
  │  • Runbook steps (chunked + embedded)                 │
  │  • Architecture decision records                      │
  │  • Slack resolution threads                           │
  │  • Similar error pattern history                      │
  └───────────────────────────────────────────────────────┘
         │
  ┌──────┴──────────────────────────────────────────────┐
  │              LLM Synthesis Layer                     │
  │  • Combines all agent findings                      │
  │  • Generates human-readable summary                 │
  │  • Proposes remediation steps (from RAG runbooks)   │
  │  • Confidence scoring                               │
  │  • Delivers to Slack/Teams/PagerDuty                │
  └─────────────────────────────────────────────────────┘
```

**Tiered AI Autonomy** (start conservative, graduate):

| Level | Capability | Human Gate |
|-------|-----------|------------|
| 1 (Default) | Read-only investigation, generate summary | Always |
| 2 | Investigation + suggest remediation with commands | Always |
| 3 | Investigation + execute safe actions (scale up, restart) | Approval required |
| 4 | Full autonomous response for known incident patterns | Audit log only |

### Cost Model

```
Kafka cluster:
  3-5 brokers, ~$3,000-8,000/mo (or Confluent Cloud / MSK Serverless)

Flink cluster:
  5-10 task managers, ~$2,000-6,000/mo

Storage (ClickHouse):
  Hot:  3-5 nodes, NVMe, ~$3,000-10,000/mo
  Warm: auto-tiered, ~$1,000-3,000/mo
  Cold: S3, ~$200-500/mo (per TB)

AI layer:
  LLM API costs: ~$500-3,000/mo (depends on investigation volume)
  Vector DB: ~$500-1,000/mo
  Flink ML models: included in Flink cluster

OTel Collectors:
  Agents: ~$200-500/mo (CPU/memory on existing nodes)
  Gateways: ~$500-2,000/mo per cloud

Total: ~$10,000-35,000/mo for a mid-size multi-cloud deployment
  (vs $50,000-200,000/mo for equivalent SaaS vendor coverage)
```

### When to Choose Architecture B

- Cloud-native organizations with streaming expertise
- Need real-time anomaly detection (not just dashboards)
- Cost-sensitive: want maximum control over data pipeline
- IoT / edge deployments that need store-and-forward
- Organizations that want AI embedded in the pipeline, not bolted on
- Teams comfortable with Kafka + Flink operations

---

## Head-to-Head Comparison

| Dimension | Architecture A (Federated) | Architecture B (Streaming) |
|-----------|---------------------------|---------------------------|
| **Data flow** | Regional stores → aggregated central | All signals → Kafka → Flink → tiered storage |
| **AI placement** | Central AI brain queries federated stores | AI embedded in Flink + query layer |
| **Latency to insight** | Seconds (regional) to minutes (cross-region) | Sub-second (Flink streaming) |
| **Data sovereignty** | Native (data stays regional) | Requires Kafka geo-partitioning |
| **Operational complexity** | High (N regional stacks + central) | High (Kafka + Flink + storage) |
| **Failure mode** | Regions work independently | Kafka outage = pipeline stall |
| **Cost at 10B events/day** | ~$20-50K/mo | ~$15-35K/mo |
| **Cost at 100B events/day** | ~$100-250K/mo | ~$60-150K/mo |
| **GenAI integration** | Central RAG + NL query | Streaming ML + Central RAG + NL query |
| **Best for** | Regulated, multi-team, autonomous | Real-time, cost-optimized, streaming-native |

---

## Hybrid: Combine Both

Many organizations will benefit from combining elements:

```
Architecture A's regional processing
  + Architecture B's Kafka backbone (per region)
  + Architecture B's Flink jobs (per region, for pre-aggregation)
  + Architecture A's central AI brain (for cross-region intelligence)
```

This gives you:
- Regional data sovereignty (A)
- Streaming pre-aggregation and burst handling (B)
- Real-time anomaly detection per region (B)
- Cross-region AI correlation (A)
- Cost efficiency from Flink cardinality reduction (B)

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)
- Deploy OTel Collector agents (DaemonSet) on all clusters
- Deploy OBI/eBPF for zero-code baseline visibility
- Add resource attributes: cloud.provider, region, cluster, environment
- Basic OTLP export to chosen storage (Grafana Cloud, ClickHouse, or vendor)
- **Quick win**: Immediate visibility into all services across all clouds

### Phase 2: Intelligence (Weeks 5-8)
- Deploy regional gateways with tail sampling + PII redaction
- Add cost routing: filter noise, route by severity
- Deploy Kafka backbone (Architecture B) or regional stores (Architecture A)
- Implement cardinality reduction processors
- **Quick win**: 50-70% storage cost reduction

### Phase 3: Streaming (Weeks 9-12) — Architecture B only
- Deploy Flink cluster with metrics aggregation and trace assembly jobs
- Implement streaming log classification
- Add cross-signal correlation job
- **Quick win**: Real-time anomaly detection, pre-correlated alerts

### Phase 4: AI Integration (Weeks 13-16)
- Deploy vector DB, ingest runbooks and past incident postmortems
- Implement NL query engine (LLM + RAG over telemetry)
- Build agentic SRE investigation workflow (Level 1: read-only)
- Add LLM observability (OTel GenAI conventions)
- **Quick win**: "Ask in English, get PromQL answers"

### Phase 5: Autonomous Operations (Weeks 17-24)
- Graduate agentic SRE to Level 2 (suggest remediation)
- Implement streaming ML anomaly detection in Flink
- Add adaptive sampling (dynamic rate adjustment based on budget)
- Build feedback loops (engineer corrections improve AI accuracy)
- **Quick win**: 3.5x faster root cause identification (Grafana benchmark)

---

## Key Principles (Both Architectures)

1. **OTel everywhere** — Single instrumentation standard across all clouds
2. **eBPF baseline** — Zero-code visibility from day one
3. **Process close to source** — Filter, sample, redact before data moves
4. **Kafka decouples** — Never let downstream failures drop signals
5. **Columnar > inverted index** — ClickHouse/Parquet for observability, not Elasticsearch
6. **AI explains, not guesses** — LLMs summarize causal AI findings, not hallucinate root causes
7. **Tiered everything** — Hot/warm/cold storage, tiered AI autonomy, tiered sampling
8. **Monitor the monitors** — OTel GenAI conventions for AI workload observability
9. **Cost-aware by default** — Adaptive telemetry from day one, not as an afterthought
10. **Human in the loop** — Start with read-only AI, graduate to autonomous with guardrails

---

## Sources

### Multi-Cloud Architecture
- [CNCF: How OpenTelemetry Unified Observability Across Clouds](https://www.cncf.io/blog/2025/11/27/from-chaos-to-clarity-how-opentelemetry-unified-observability-across-clouds/)
- [Google Cloud: Hybrid/Multi-Cloud Monitoring Patterns](https://docs.cloud.google.com/architecture/hybrid-and-multi-cloud-monitoring-and-logging-patterns)
- [Datadog: Hybrid Network Observability Reference Architecture](https://www.datadoghq.com/architecture/hybrid-cloud-network-observability/)
- [Dynatrace: Multi-Cloud Push with Grail](https://www.webpronews.com/dynatraces-multi-cloud-push-unifying-aws-azure-and-gcp-in-ai-driven-operations/)

### OpenTelemetry Collector Patterns
- [OTel Collector Gateway Deployment](https://opentelemetry.io/docs/collector/deploy/gateway/)
- [OTel Collector Scaling](https://opentelemetry.io/docs/collector/scaling/)
- [OTel Collector Survey 2026](https://opentelemetry.io/blog/2026/otel-collector-follow-up-survey-analysis/)
- [Load-Balancing Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/loadbalancingexporter/README.md)
- [OTLP Arrow Production Results (ServiceNow)](https://opentelemetry.io/blog/2024/otel-arrow-production/)

### GenAI in Observability
- [Dynatrace Hypermodal AI + Davis CoPilot](https://www.dynatrace.com/news/blog/hypermodal-ai-dynatrace-expands-davis-ai-with-davis-copilot/)
- [Datadog Bits AI SRE](https://www.datadoghq.com/blog/bits-ai-sre/)
- [Grafana Assistant Investigations](https://grafana.com/about/press/2025/10/08/grafana-labs-revolutionizes-ai-powered-observability-with-ga-of-grafana-assistant-and-introduces-assistant-investigations/)
- [Grafana: AI Found Root Cause 3.5x Faster](https://grafana.com/blog/2025/11/17/a-tale-of-two-incident-responses-how-our-ai-assist-helped-us-find-the-cause-3-5x-faster/)
- [New Relic AI GA](https://newrelic.com/blog/how-to-relic/nrai-agentic-ga)
- [Elastic AI Assistant for Observability](https://www.elastic.co/docs/solutions/observability/ai/observability-ai-assistant)
- [IBM Instana Agentic AI](https://www.ibm.com/new/announcements/resolve-incidents-faster-with-ibm-instana-intelligent-incident-investigation-powered-by-agentic-ai)
- [AWS DevOps Agent](https://www.infoq.com/news/2025/12/aws-devops-agents/)

### OTel GenAI Semantic Conventions
- [GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)
- [Datadog OTel GenAI Support](https://www.datadoghq.com/blog/llm-otel-semantic-convention/)
- [OpenLLMetry by Traceloop](https://github.com/traceloop/openllmetry)
- [Langfuse](https://github.com/langfuse/langfuse)

### eBPF + OBI
- [OpenTelemetry eBPF Instrumentation (OBI)](https://opentelemetry.io/docs/zero-code/obi/)
- [OBI First Release](https://opentelemetry.io/blog/2025/obi-announcing-first-release/)
- [Apple: eBPF + OTel Exemplars (KubeCon EU 2025)](https://opentelemetry.io/blog/2025/kubecon-eu/)

### Storage + Cost
- [Zomato: ClickHouse at 50TB/day](https://www.zomato.com/blog/building-a-cost-effective-logging-platform-using-clickhouse-for-petabyte-scale/)
- [HyperDX: Why ClickHouse Over Elasticsearch](https://www.hyperdx.io/blog/why-clickhouse-over-elasticsearch-observability)
- [Grafana Adaptive Telemetry Suite](https://grafana.com/blog/2025/10/08/adaptive-telemetry-suite-in-grafana-cloud/)
- [Stripe: Observability on AWS Managed Prometheus](https://aws.amazon.com/solutions/case-studies/stripe-architects-case-study/)

### Streaming Infrastructure
- [Netflix: Four Innovation Phases of Trillions-Scale Infrastructure](https://zhenzhongxu.com/the-four-innovation-phases-of-netflixs-trillions-scale-real-time-data-infrastructure-2370938d7f01)
- [DoorDash: Scalable Event Processing with Kafka + Flink](https://careersatdoordash.com/blog/building-scalable-real-time-event-processing-with-kafka-and-flink/)
- [AWS: Flink + Prometheus for Observability](https://aws.amazon.com/blogs/big-data/process-millions-of-observability-events-with-apache-flink-and-write-directly-to-prometheus/)

### OpAMP Fleet Management
- [OpAMP Specification](https://opentelemetry.io/docs/specs/opamp/)
- [IBM Instana OpAMP GA](https://www.ibm.com/new/announcements/ibm-instana-announces-ga-of-fleet-management-for-opentelemetry-collectors-powered-by-opamp)

---

*Research compiled February 2026*
