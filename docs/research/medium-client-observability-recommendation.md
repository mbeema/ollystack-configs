# Multi-Cloud Observability for Medium Clients

> A practical, opinionated recommendation for organizations that need multi-cloud
> visibility without the operational complexity of hyperscale architectures.

---

## Medium Client Profile

| Dimension | Typical Range |
|-----------|--------------|
| Engineers | 50-500 |
| Microservices | 20-150 |
| Clouds | 1 primary + 1 secondary (usually AWS + Azure or GCP) |
| Signal volume | 500M - 10B events/day |
| Platform team | 2-5 people |
| Observability budget | $10K-50K/month |
| Regulatory | Some (SOC2, HIPAA) but not extreme (no GDPR data residency) |

---

## Recommended Architecture: Simplified Hybrid

Neither a full federated regional setup nor a streaming-first Kafka+Flink pipeline.
Take the best pieces of each and skip the complexity a small platform team can't staff for.

```
┌──────────────────────────────────────────────────────────┐
│                   QUERY + AI LAYER                        │
│                                                          │
│  Grafana Cloud (or self-hosted Grafana + LGTM stack)     │
│  + Grafana Assistant (NL queries, AI investigation)      │
│  + Adaptive Telemetry (auto cost reduction)              │
│  + Sift (AI-powered incident diagnostics)                │
│                                                          │
│  Single pane of glass — both clouds, all signals         │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────┴───────────────────────────────┐
│                   STORAGE LAYER                           │
│                                                          │
│  Option A: Grafana Cloud (managed — recommended)         │
│    Mimir (metrics) + Loki (logs) + Tempo (traces)        │
│    + Adaptive Metrics/Logs/Traces for cost control       │
│                                                          │
│  Option B: Self-hosted                                   │
│    ClickHouse (all signals) or LGTM stack                │
│    Hot: 7-14 days │ Cold: S3 Parquet (1 year)            │
└──────────────────────────┬───────────────────────────────┘
                           │
┌──────────────────────────┴───────────────────────────────┐
│              SINGLE GATEWAY LAYER                         │
│              (not per-region — one fleet)                 │
│                                                          │
│  OTel Collector Gateway (3-5 pods, HPA)                  │
│                                                          │
│  • Tail sampling (errors + slow + 10% probabilistic)     │
│  • PII redaction (hash emails, delete IPs)               │
│  • Cardinality reduction (strip pod_uid, container_id)   │
│  • Noise filtering (health checks, probes, OPTIONS)      │
│  • Severity routing (ERROR→hot, DEBUG→cold)              │
│                                                          │
│  NO Kafka, NO Flink — OTel Collector handles it all      │
└─────────┬────────────────────────────┬───────────────────┘
          │                            │
┌─────────┴──────────┐    ┌───────────┴──────────────────┐
│  PRIMARY CLOUD     │    │  SECONDARY CLOUD              │
│  (AWS)             │    │  (Azure or GCP)               │
│                    │    │                                │
│  ┌──────────────┐  │    │  ┌──────────────┐             │
│  │ EKS Cluster  │  │    │  │ AKS / GKE    │             │
│  │              │  │    │  │              │             │
│  │ OTel Agent   │  │    │  │ OTel Agent   │             │
│  │ (DaemonSet)  │  │    │  │ (DaemonSet)  │             │
│  │ + OBI/eBPF   │  │    │  │ + OBI/eBPF   │             │
│  │              │  │    │  │              │             │
│  │ CloudWatch   │  │    │  │ AzureMonitor │             │
│  │ receivers    │  │    │  │ receivers    │             │
│  └──────────────┘  │    │  └──────────────┘             │
│                    │    │                                │
│  EC2 / Lambda /    │    │  VMs / Functions /             │
│  Fargate workloads │    │  Container Apps                │
└────────────────────┘    └────────────────────────────────┘
```

---

## Design Decisions: What We Kept and What We Dropped

### What We Kept

| Component | Why It's Essential |
|-----------|-------------------|
| OTel Collectors everywhere (agents + gateway) | Non-negotiable standard for multi-cloud instrumentation |
| OBI/eBPF for zero-code visibility | Massive time saver — instant RED metrics and traces without code changes |
| Tail sampling at gateway | 60-80% trace cost reduction with no visibility loss for errors |
| PII redaction + cardinality reduction | Compliance and cost optimization in one step |
| Grafana AI features (Assistant, Sift) | NL queries and AI investigation without building your own |
| Cloud-native receivers | Visibility into managed services (RDS, Azure SQL, Cloud SQL, etc.) |
| W3C Trace Context propagation | Cross-cloud trace correlation out of the box |

### What We Dropped

| Component | Why It's Unnecessary at This Scale |
|-----------|-----------------------------------|
| Kafka backbone | Can't staff Kafka operations with 2-5 people. OTel Collector's built-in `sending_queue` with persistent storage handles burst buffering well enough under 10B events/day |
| Apache Flink | Pre-aggregation via OTel Collector processors is sufficient. Flink adds operational burden that requires dedicated streaming engineers |
| Regional stores | At 2 clouds, cross-cloud egress for sampled data is affordable (~$500-2K/month). Data sovereignty handled by PII redaction at gateway, not regional isolation |
| Custom AI/RAG pipeline | Grafana Assistant + Sift provides 80% of AI value out of the box. Building your own RAG pipeline needs a dedicated ML engineer |
| OpAMP fleet management | With <20 collectors, Helm charts + ArgoCD handle config management just fine |
| Vector DB | Not enough incident volume to justify the operational overhead. Revisit at 100+ incidents/month |
| Separate per-signal collector fleets | Signal volumes at this scale don't differ enough to warrant specialized fleets |

---

## Layer-by-Layer Breakdown

### Layer 1: Instrumentation (Per Workload)

Three-tier instrumentation at every workload, regardless of cloud:

```
Tier 1: OBI/eBPF           → Automatic RED metrics + basic traces (zero code)
Tier 2: Auto-instrumentation → Framework-aware spans (minimal code)
Tier 3: SDK instrumentation  → Business logic spans + custom attributes (code)
```

**OBI (OpenTelemetry eBPF Instrumentation)** provides the baseline:
- Automatic HTTP/gRPC/DB metrics and traces without code changes
- <1% CPU overhead, works across Go, Java, Python, Node.js, .NET, Rust
- Requires Linux kernel 5.8+ (all major cloud providers support this)
- Limitation: no custom business attributes — SDK needed for "why" context

**OTel SDK + Auto-Instrumentation** adds depth where needed:
- W3C Trace Context propagation across cloud boundaries
- Custom spans for business-critical paths (checkout, payment, auth)
- OTel GenAI semantic conventions if running AI/LLM workloads

**Cloud-native receivers** for managed service telemetry:
- AWS: `awscloudwatch/*`, `awscontainerinsights`, `awsxray`
- Azure: `azuremonitor/*`, `azureeventhub`
- GCP: `googlecloudmonitoring/*`, `googlecloudspanner`

**Practical guidance**: Start with OBI on every cluster (week 1). Add auto-instrumentation
to top 10 critical services (week 3). Add SDK instrumentation only to business-critical
paths that need custom attributes (ongoing, as needed).

### Layer 2: Agent Collectors (Per Node — DaemonSet)

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
        value: "${CLOUD_PROVIDER}"    # aws | azure | gcp
        action: upsert
      - key: cloud.region
        value: "${CLOUD_REGION}"
        action: upsert
      - key: k8s.cluster.name
        value: "${CLUSTER_NAME}"
        action: upsert
      - key: deployment.environment
        value: "${ENVIRONMENT}"       # production | staging | dev
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
        hostname: otel-gateway-headless.monitoring.svc
        port: 4317
```

**Sizing**: 200-500m CPU, 256 MiB memory per node.

**Key detail**: The `loadbalancing` exporter routes spans by traceID to ensure all
spans for the same trace reach the same gateway pod — critical for tail sampling.

### Layer 3: Gateway (Single Fleet)

The gateway is the brain of the pipeline. One fleet serves both clouds:

```yaml
# Gateway — Deployment with HPA (3-5 pods)
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }

processors:
  # MUST be first — prevents OOM kills
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

  # PII redaction
  attributes/pii:
    actions:
      - key: user.email
        action: hash
      - key: http.client_ip
        action: delete
      - key: user.id
        action: hash
      - key: enduser.id
        action: hash

  # Cardinality reduction
  attributes/cardinality:
    actions:
      - key: pod_uid
        action: delete
      - key: container_id
        action: delete
      - key: k8s.pod.uid
        action: delete
      - key: k8s.replicaset.name
        action: delete

  # Noise filtering
  filter/noise:
    logs:
      exclude:
        match_type: regexp
        bodies:
          - ".*health_check.*"
          - ".*readiness_probe.*"
          - ".*liveness_probe.*"
          - ".*kube-probe.*"
    traces:
      span:
        exclude:
          match_type: regexp
          attributes:
            - key: http.target
              value: "^/(healthz|readyz|livez|metrics|favicon\\.ico)"

  batch:
    send_batch_size: 8192
    timeout: 5s

exporters:
  otlp/backend:
    endpoint: "${BACKEND_ENDPOINT}"       # Grafana Cloud OTLP or self-hosted
    headers:
      Authorization: "Basic ${GRAFANA_CLOUD_TOKEN}"
    sending_queue:
      enabled: true
      queue_size: 5000
      num_consumers: 10
      storage: file_storage/queue
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 60s
      max_elapsed_time: 300s

  # Cold storage for low-value signals (optional)
  awss3/cold:
    s3uploader:
      region: "${AWS_REGION}"
      s3_bucket: "observability-cold"
      s3_partition: "year=%Y/month=%m/day=%d/hour=%H"
      marshaler: otlp_json

extensions:
  file_storage/queue:
    directory: /var/lib/otelcol/queue
    timeout: 10s
    compaction:
      on_rebound: true

service:
  extensions: [file_storage/queue]
  pipelines:
    traces:
      receivers: [otlp]
      processors:
        - memory_limiter
        - attributes/pii
        - attributes/cardinality
        - filter/noise
        - tail_sampling
        - batch
      exporters: [otlp/backend]
    metrics:
      receivers: [otlp]
      processors:
        - memory_limiter
        - attributes/cardinality
        - filter/noise
        - batch
      exporters: [otlp/backend]
    logs:
      receivers: [otlp]
      processors:
        - memory_limiter
        - attributes/pii
        - attributes/cardinality
        - filter/noise
        - batch
      exporters: [otlp/backend, awss3/cold]
```

**Sizing**: 2-4 CPU, 2-4 GiB memory per gateway pod. HPA target 70% CPU.

**Key details**:
- `file_storage` for persistent queues — survives pod restarts without data loss
- `memory_limiter` MUST be first processor — prevents OOM kills during traffic spikes
- Tail sampling with 30s decision window and 50K trace buffer handles medium-scale traffic
- All PII is hashed/deleted before leaving the gateway — compliance at the pipeline level

### Layer 4: Storage

**Managed path (Grafana Cloud)**:

| Signal | Backend | Retention | Cost Control |
|--------|---------|-----------|-------------|
| Metrics | Mimir | 13 months | Adaptive Metrics (~35% auto-reduction) |
| Logs | Loki | 30 days | Adaptive Logs (drop unused patterns) |
| Traces | Tempo | 30 days | Adaptive Traces (intelligent sampling) |
| Profiles | Pyroscope | 7 days | On-demand profiling |

**Self-hosted path (ClickHouse or LGTM)**:

| Tier | Storage | Retention | Purpose |
|------|---------|-----------|---------|
| Hot | ClickHouse (NVMe) or Mimir/Loki/Tempo | 7-14 days | Dashboards, alerting, investigation |
| Cold | S3 Parquet | 1-7 years | Compliance, historical analysis |

**Why ClickHouse for self-hosted?**
- 6x less storage than Elasticsearch
- Handles all three signal types in one system
- Columnar compression = fast analytical queries
- SigNoz and HyperDX prove this architecture works

**Why Grafana Cloud for managed?**
- SOC2 certified out of the box
- AI features (Assistant, Sift, Adaptive) included
- No storage infrastructure to operate
- LGTM stack with object storage backend keeps costs predictable

### Layer 5: AI Integration

**With Grafana Cloud (recommended for medium clients)**:

| Feature | What It Does | Value |
|---------|-------------|-------|
| **Grafana Assistant** | Natural language → PromQL/LogQL/TraceQL translation | Engineers who don't know query languages can investigate incidents |
| **Sift** | Automated diagnostic checks during incidents | Searches for new errors, recent deploys, overloaded nodes automatically |
| **Assistant Investigations** | Multi-agent AI swarm analyzes metrics + logs + traces simultaneously | 3.5x faster root cause identification (Grafana benchmark) |
| **Adaptive Telemetry** | ML identifies unused metrics, low-value logs, redundant traces | 30-50% automatic cost reduction |

**With self-hosted (if budget/team justifies)**:

| Feature | Implementation | Effort |
|---------|---------------|--------|
| NL queries | LLM API (Claude/GPT) + few-shot prompting with PromQL/LogQL examples | 2-3 days |
| Alert enrichment | LLM summarizes alert context from correlated signals | 1-2 days |
| Runbook RAG | Embed runbooks in vector DB, retrieve during incidents | 1-2 weeks |
| Full agentic SRE | Multi-agent investigation pipeline | 4-8 weeks (probably not worth it for medium clients) |

**Practical advice**: For medium clients, use Grafana's built-in AI. Don't build your own
RAG pipeline unless you have a specific, validated use case and an engineer who wants to own it.

### Layer 6: LLM/AI Workload Observability (If Applicable)

If the client runs AI/LLM workloads, add OTel GenAI semantic conventions:

```yaml
# OTel GenAI attributes tracked automatically via OpenLLMetry or SDK
gen_ai.system: "openai"                    # or anthropic, aws-bedrock
gen_ai.request.model: "gpt-4o"
gen_ai.usage.input_tokens: 1250
gen_ai.usage.output_tokens: 380
gen_ai.agent.name: "support-chatbot"
gen_ai.conversation.id: "session-12345"
```

Dashboard panels to add:
- Token usage per model per day (cost tracking)
- LLM response latency P50/P95/P99
- Error rate per model/provider
- Cost per request / per conversation
- Token budget burn rate with forecasting

Use [OpenLLMetry](https://github.com/traceloop/openllmetry) (open source, OTel-native)
or [Langfuse](https://github.com/langfuse/langfuse) (MIT, self-hostable) for automatic
LLM instrumentation without code changes.

---

## Technology Choices Summary

| Layer | Recommended | Alternative | Why |
|-------|-----------|-------------|-----|
| **Instrumentation** | OBI + OTel SDK | Grafana Alloy (OTel distribution) | Zero-code baseline + deep where needed |
| **Agent** | OTel Collector DaemonSet | Grafana Alloy DaemonSet | Standard, well-documented |
| **Gateway** | OTel Collector Deployment | Grafana Alloy Deployment | Sampling, redaction, routing in one place |
| **Metrics** | Grafana Cloud Mimir | Self-hosted VictoriaMetrics | Prometheus-compatible, long retention |
| **Logs** | Grafana Cloud Loki | Self-hosted ClickHouse | Cost-effective, label-indexed |
| **Traces** | Grafana Cloud Tempo | Self-hosted Jaeger v2 + ClickHouse | Object storage backend, cheap |
| **Dashboards** | Grafana | Grafana (both paths use it) | Universal, both clouds in one view |
| **AI** | Grafana Assistant + Sift | LLM API + custom prompts | Managed AI, no ML team needed |
| **Alerting** | Grafana Alerting | Alertmanager + PagerDuty | Unified alert rules across all signals |
| **Cost control** | Adaptive Telemetry | OTel filter + sampling processors | 30-50% automatic reduction |
| **GitOps** | ArgoCD + Helm | FluxCD + Helm | Collector config as code |

---

## The Decision: Managed vs Self-Hosted

| Factor | Grafana Cloud (Managed) | Self-Hosted |
|--------|------------------------|-------------|
| **Team size < 3** | Strongly recommended | Too much operational burden |
| **Team size 3-5** | Still recommended | Feasible if team has k8s + storage expertise |
| **Budget < $20K/mo** | Usually fits comfortably | May be cheaper at very high volume |
| **Budget $20-50K/mo** | Compare carefully | Often 40-60% cheaper on infrastructure alone |
| **AI features** | Included (Assistant, Sift, Adaptive) | Must build or buy separately |
| **Compliance (SOC2)** | Grafana Cloud is SOC2 certified | You own the entire compliance burden |
| **Data control** | Data in Grafana's infrastructure | Full control in your accounts |
| **Scaling** | Automatic | You manage capacity planning |

**Default recommendation**: Start with Grafana Cloud. Switch to self-hosted only when:
- Monthly costs exceed $30-40K AND
- You have 3+ dedicated platform engineers AND
- You have a specific data residency requirement Grafana Cloud BYOC doesn't solve

---

## Cost Estimates

### Grafana Cloud Path

```
Metrics:     ~$3,000 - $8,000/mo   (after Adaptive Metrics 35% reduction)
Logs:        ~$2,000 - $6,000/mo   (after filtering + severity routing)
Traces:      ~$1,000 - $4,000/mo   (after tail sampling 70% reduction)
Profiles:    ~$500 - $1,500/mo     (on-demand, not continuous)
AI features: included in plan
─────────────────────────────────
Total:       ~$6,500 - $19,500/mo
```

### Self-Hosted Path

```
ClickHouse cluster (3 nodes):   ~$2,000 - $5,000/mo
Grafana + LGTM stack (compute): ~$1,000 - $3,000/mo
S3 cold storage:                ~$200 - $500/mo
OTel Collectors (CPU/memory):   ~$300 - $800/mo
Infrastructure subtotal:        ~$3,500 - $9,300/mo

Engineer time (0.5-1 FTE):     ~$5,000 - $10,000/mo  (opportunity cost)
─────────────────────────────────
Total (with people cost):       ~$8,500 - $19,300/mo
```

The managed path is often comparable or cheaper when you factor in engineering time.
Self-hosted becomes clearly cheaper only above ~$30K/mo managed spend with an existing
platform team.

### Cross-Cloud Egress (Both Paths)

```
Sampled + aggregated data crossing clouds:
  ~5-15% of raw volume after gateway processing
  Typical: 100GB - 1TB/month cross-cloud transfer
  Cost: ~$500 - $2,000/mo in egress fees

  This is affordable because:
  • Tail sampling removes 60-80% of traces
  • Noise filtering drops 20-30% of logs
  • Cardinality reduction compresses metrics 50%+
  • Only processed data crosses cloud boundaries
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-4)

| Week | Action | Outcome |
|------|--------|---------|
| 1 | Deploy OBI/eBPF on all Kubernetes clusters | Instant RED metrics + traces for every service, zero code changes |
| 2 | Deploy OTel Agent DaemonSets with resource attributes | Host metrics, container logs, cloud/region/cluster metadata |
| 3 | Connect to Grafana Cloud (or deploy self-hosted storage) | Signals flowing to dashboards |
| 4 | Import starter dashboards (K8s, host, service overview) | Baseline visibility across both clouds |

**Quick win**: Full multi-cloud visibility in 4 weeks with no application code changes.

### Phase 2: Optimization (Weeks 5-8)

| Week | Action | Outcome |
|------|--------|---------|
| 5 | Deploy gateway with noise filtering + severity routing | Drop health checks, probes, OPTIONS — 20-30% volume reduction |
| 6 | Enable tail sampling on gateway | 60-80% trace cost reduction |
| 7 | Add PII redaction + cardinality reduction processors | Compliance + additional 20-30% cost reduction |
| 8 | Enable Adaptive Telemetry (managed) or tune sampling rates (self-hosted) | Additional 30-50% automatic reduction |

**Quick win**: 50-70% total storage cost reduction vs unoptimized baseline.

### Phase 3: Cloud Integration (Weeks 9-10)

| Week | Action | Outcome |
|------|--------|---------|
| 9 | Add cloud-native receivers (CloudWatch, AzureMonitor/GCP Cloud Monitoring) | Managed service metrics (RDS, Azure SQL, Lambda, etc.) |
| 10 | Add auto-instrumentation to top 10 critical services | Deep traces for checkout, auth, payment, search paths |

**Quick win**: Visibility into managed services + business-critical trace paths.

### Phase 4: AI + Alerting (Weeks 11-12)

| Week | Action | Outcome |
|------|--------|---------|
| 11 | Enable Grafana Assistant + Sift AI features | Natural language queries + automated incident diagnostics |
| 12 | Build SLO dashboards, configure alerting rules, integrate PagerDuty/Opsgenie | Production-ready alerting with AI-assisted investigation |

**Quick win**: "Ask in English, get answers" + 3.5x faster root cause identification.

### Phase 5: Maturity (Ongoing)

| Action | Trigger |
|--------|---------|
| Add SDK instrumentation to services as needed | When OBI + auto-instrumentation isn't deep enough |
| Add LLM observability (GenAI conventions) | When AI workloads are in production |
| Evaluate self-hosted migration | When managed costs exceed $30-40K/mo |
| Add continuous profiling (Pyroscope) | When performance optimization becomes a priority |
| Evaluate Kafka backbone | When signal volume exceeds 10B events/day consistently |

---

## Key Principles

1. **OTel everywhere** — Single instrumentation standard across all clouds
2. **eBPF first** — Zero-code visibility on day one, add depth incrementally
3. **Process at the gateway** — Filter, sample, redact before data hits storage
4. **Don't over-engineer** — No Kafka, no Flink, no custom AI until you outgrow the basics
5. **Managed until proven otherwise** — Platform team time is more expensive than SaaS fees
6. **Cost-aware from day one** — Sampling and filtering are not optimizations, they're architecture
7. **AI as a feature, not a project** — Use vendor AI features instead of building your own
8. **12 weeks to production** — Achievable with a 2-3 person team following this roadmap

---

## When to Upgrade to a Larger Architecture

Signals that you've outgrown this architecture:

| Signal | Current Limit | Next Step |
|--------|--------------|-----------|
| Events/day > 10B consistently | Gateway can't keep up | Add Kafka backbone for buffering |
| Platform team grows to 5+ | Can absorb more complexity | Consider self-hosted for cost savings |
| 3+ clouds or 5+ regions | Single gateway fleet becomes a bottleneck | Move to regional gateways (Architecture A) |
| Need real-time streaming ML | OTel processors aren't flexible enough | Add Flink for stream processing (Architecture B) |
| Strict data residency (GDPR) | PII redaction isn't sufficient | Move to federated regional stores (Architecture A) |
| 100+ incidents/month | Need knowledge base for pattern matching | Add vector DB + RAG pipeline |
| Monthly cost > $40K managed | ROI for self-hosted is clear | Migrate to self-hosted with dedicated team |

When you hit these signals, refer to the full architecture proposals in
[multi-cloud-architectures-with-genai.md](./multi-cloud-architectures-with-genai.md).

---

## Sources

- [Grafana Assistant + Sift GA](https://grafana.com/about/press/2025/10/08/grafana-labs-revolutionizes-ai-powered-observability-with-ga-of-grafana-assistant-and-introduces-assistant-investigations/)
- [Grafana AI Found Root Cause 3.5x Faster](https://grafana.com/blog/2025/11/17/a-tale-of-two-incident-responses-how-our-ai-assist-helped-us-find-the-cause-3-5x-faster/)
- [Grafana Adaptive Telemetry Suite](https://grafana.com/blog/2025/10/08/adaptive-telemetry-suite-in-grafana-cloud/)
- [OpenTelemetry eBPF Instrumentation (OBI)](https://opentelemetry.io/docs/zero-code/obi/)
- [OTel Collector Gateway Deployment](https://opentelemetry.io/docs/collector/deploy/gateway/)
- [OTel Collector Scaling](https://opentelemetry.io/docs/collector/scaling/)
- [Load-Balancing Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/loadbalancingexporter/README.md)
- [Zomato: ClickHouse at 50TB/day](https://www.zomato.com/blog/building-a-cost-effective-logging-platform-using-clickhouse-for-petabyte-scale/)
- [Stripe: Observability on AWS Managed Prometheus](https://aws.amazon.com/solutions/case-studies/stripe-architects-case-study/)
- [OpenLLMetry by Traceloop](https://github.com/traceloop/openllmetry)
- [Langfuse](https://github.com/langfuse/langfuse)
- [OTel GenAI Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/gen-ai/)

---

*Recommendation compiled February 2026*
