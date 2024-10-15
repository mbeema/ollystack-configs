# OllyStack Tuning Guide

The definitive reference for optimizing OpenTelemetry Collector performance, cost, and reliability. This guide answers the question every client asks: *"I have X throughput, Y budget, Z backend — give me the numbers."*

---

## Table of Contents

1. [Topology Decision Tree](#1-topology-decision-tree)
2. [Collector Resource Sizing](#2-collector-resource-sizing)
3. [Memory Limiter Tuning](#3-memory-limiter-tuning)
4. [Batch Processor Tuning](#4-batch-processor-tuning)
5. [Queue and Retry Strategy](#5-queue-and-retry-strategy)
6. [Processor Cost Table](#6-processor-cost-table)
7. [Sampling Strategy](#7-sampling-strategy)
8. [Exporter Optimization](#8-exporter-optimization)
9. [Cost-Per-Signal Math](#9-cost-per-signal-math)
10. [Tuning Checklist](#10-tuning-checklist)

---

## 1. Topology Decision Tree

The single biggest architectural decision. Get this wrong and no amount of tuning fixes it.

```
                    What's your total cluster throughput?
                    ─────────────────────────────────────
                                    │
                    ┌───────────────┼───────────────┐
                    │               │               │
               < 5K spans/sec  5K–50K spans/sec  > 50K spans/sec
                    │               │               │
                    ▼               ▼               ▼
              ┌──────────┐   ┌──────────┐    ┌──────────────┐
              │ Agent-    │   │ Agent +  │    │ Agent + LB + │
              │ Only      │   │ Gateway  │    │ Gateway      │
              │           │   │ (2-tier) │    │ (3-tier)     │
              └──────────┘   └──────────┘    └──────────────┘

   Need tail sampling?
   ├── No  → Agent-only is fine (head-sample at agent if needed)
   └── Yes → You MUST have a gateway tier (tail sampling needs full traces)

   Need trace-aware routing?
   ├── No  → 2-tier (agents export directly to gateway Deployment)
   └── Yes → 3-tier (agents → load-balancer → gateway via traceID routing)
```

### Topology Comparison

| Factor | Agent-Only | Agent + Gateway | Agent + LB + Gateway |
|--------|-----------|----------------|---------------------|
| **Complexity** | Low | Medium | High |
| **Resource overhead** | Baseline | +2-4 pods | +4-8 pods |
| **Tail sampling** | No | Yes (with caveats) | Yes (correct) |
| **Cost optimization** | Head sampling only | Full processor chain | Full + trace-correct |
| **Max throughput** | ~5K spans/sec/node | ~50K spans/sec total | Unlimited (scale gateways) |
| **Blast radius** | Per-node | Gateway is SPOF unless HA | Fully resilient |
| **Best for** | Dev/staging, small prod | Most production clusters | High-volume, regulated |

### When Agent-Only Is Enough

Agent-only works if ALL of these are true:
- Total cluster throughput < 5K spans/sec
- Head-based sampling is acceptable (no need to keep all error traces)
- No cross-node processing needed (no service graph connector)
- Backend does its own aggregation (Datadog, New Relic, Dynatrace)

### When You Need 3-Tier

You need the load-balancer tier when:
- Using tail sampling AND the gateway has >1 replica
- Without trace-aware routing, spans from the same trace land on different gateways
- Each gateway makes independent (wrong) sampling decisions
- Result: incomplete traces in your backend

---

## 2. Collector Resource Sizing

### The Formula

```
Agent (per node):
  CPU (cores)  = (spans/sec × 0.001) + (metrics/sec × 0.0005) + (logs/sec × 0.0008)
  Memory (MiB) = 100 + (queue_size × avg_item_KB ÷ 1024) + 50

Gateway (per replica):
  CPU (cores)  = (total_ingest/sec ÷ num_replicas × 0.002) + processor_overhead
  Memory (MiB) = 200 + (queue_size × avg_item_KB ÷ 1024) + sampling_buffer
```

`processor_overhead` depends on which processors you enable (see [Section 6](#6-processor-cost-table)).

### Sizing Table — Agent (DaemonSet)

| Throughput per node | CPU Request | CPU Limit | Memory Request | Memory Limit | Batch Size | Notes |
|---------------------|-------------|-----------|----------------|--------------|------------|-------|
| < 500 spans/sec | 100m | 250m | 128Mi | 256Mi | 2048 | Minimal workload |
| 500–2K spans/sec | 250m | 500m | 256Mi | 512Mi | 4096 | Typical microservices |
| 2K–5K spans/sec | 500m | 1000m | 512Mi | 1Gi | 8192 | **Default — most production** |
| 5K–10K spans/sec | 1000m | 2000m | 1Gi | 2Gi | 8192 | High-traffic nodes |
| > 10K spans/sec | 2000m | 4000m | 2Gi | 4Gi | 16384 | Consider splitting by signal |

### Sizing Table — Gateway (Deployment)

| Total cluster throughput | Replicas | CPU/replica | Memory/replica | Queue Size | Notes |
|--------------------------|----------|-------------|----------------|------------|-------|
| < 5K spans/sec | 2 | 500m / 1000m | 512Mi / 1Gi | 5000 | Minimal HA |
| 5K–20K spans/sec | 2–3 | 1000m / 2000m | 1Gi / 2Gi | 5000 | HPA: 2–5 |
| 20K–50K spans/sec | 3–5 | 2000m / 4000m | 2Gi / 4Gi | 10000 | **Default gateway** |
| 50K–100K spans/sec | 5–10 | 2000m / 4000m | 4Gi / 8Gi | 10000 | 3-tier recommended |
| > 100K spans/sec | 10+ | 4000m / 8000m | 8Gi / 16Gi | 20000 | Split pipelines by signal |

### Key Sizing Rules

1. **Set GOMAXPROCS to match CPU limit.** The Go runtime defaults to all host cores, which wastes memory on scheduling overhead in containers.
   ```yaml
   env:
     - name: GOMAXPROCS
       value: "2"  # Match your CPU limit
   ```

2. **Memory limit = memory_limiter.limit_mib + 20% headroom.** If `limit_mib: 512`, set container memory limit to ~614Mi (round to 640Mi or 1Gi).

3. **Request:Limit ratio of 1:2 is optimal.** Tighter ratios waste resources during idle; wider ratios risk noisy-neighbor throttling.

4. **Scale gateways horizontally, agents vertically.** Agents are DaemonSets (can't add more per node), so give them more CPU/memory. Gateways are Deployments — add replicas.

---

## 3. Memory Limiter Tuning

The memory limiter is not optional. Without it, a traffic spike OOMKills your collector, and you lose *everything* in the queue.

### How It Works

```
                     Container Memory Limit (e.g., 1Gi)
┌────────────────────────────────────────────────────────────┐
│                                                            │
│  ┌──────────────────────────────────────┐                  │
│  │  memory_limiter.limit_mib (e.g. 800) │ ← Soft limit    │
│  │  ┌───────────────────────┐           │                  │
│  │  │ spike_limit_mib (200) │           │ ← Hard limit     │
│  │  │                       │           │   (refuse data   │
│  │  │  Normal operation     │           │    above this)   │
│  │  └───────────────────────┘           │                  │
│  └──────────────────────────────────────┘                  │
│                                                            │
│  ~~~~~~~~ 20% headroom for GC, goroutines, OS ~~~~~~~~~~~  │
└────────────────────────────────────────────────────────────┘
```

When memory crosses `limit_mib - spike_limit_mib`, the limiter starts **refusing new data** (returning errors to senders) and **force-flushing** batches. When it drops below, normal operation resumes.

### Fixed MiB vs. Percentage

| Mode | When to Use | Config |
|------|-------------|--------|
| **`limit_mib` + `spike_limit_mib`** | VMs, bare-metal, or when you want explicit control | Agent: `512` / `128`; Gateway: `2048` / `512` |
| **`limit_percentage` + `spike_limit_percentage`** | Containers with cgroup memory limits (K8s) | `75` / `20` (recommended for K8s) |

**Percentage mode is better for Kubernetes** because it auto-scales when you change the container memory limit. Fixed MiB requires updating both the container limit AND the config.

### Calculation

```
Container memory limit:    1Gi (1024 MiB)
  minus 20% headroom:      -204 MiB  (GC, goroutines, OS overhead)
  = limit_mib:             820 MiB
  minus spike_limit_mib:   -200 MiB  (burst headroom)
  = soft limit:            620 MiB   (limiter activates here)
```

Or with percentages: `limit_percentage: 80`, `spike_limit_percentage: 20`.

### Check Interval

| Value | Behavior |
|-------|----------|
| `1s` (default) | Responsive. Good for agents with volatile traffic. |
| `5s` | Less CPU overhead. Fine for gateways with steady traffic. |
| `100ms` | Very aggressive. Use only if OOMKills happen between 1s checks. |

**Rule:** If you're getting OOMKilled despite having a memory limiter, reduce `check_interval` to `500ms` before increasing memory.

---

## 4. Batch Processor Tuning

The batch processor is the most impactful tuning knob for throughput and latency. Every batch send incurs network overhead (TCP handshake, TLS, HTTP headers, gRPC framing). Larger batches amortize that overhead across more items.

### The Three Parameters

| Parameter | What It Does | Agent Default | Gateway Default |
|-----------|-------------|---------------|-----------------|
| `timeout` | Max time to wait before sending a partial batch | `200ms` | `5s` |
| `send_batch_size` | Target items per batch (triggers send when reached) | `8192` | `8192` |
| `send_batch_max_size` | Hard cap per batch (0 = unlimited) | `0` | `16384` |

### How They Interact

```
Items arrive continuously...

Case 1: High traffic (> send_batch_size / timeout items/sec)
  → Batch fills to send_batch_size quickly
  → Sent immediately, timeout never fires
  → Latency ≈ time to fill batch (milliseconds)

Case 2: Low traffic
  → Batch doesn't fill before timeout
  → Sent when timeout fires (partial batch)
  → Latency = timeout value

Case 3: Traffic burst
  → Batch fills instantly, may exceed send_batch_size
  → send_batch_max_size caps the batch (prevents huge exports)
  → Multiple batches sent in rapid succession
```

### Decision Matrix

| Scenario | timeout | send_batch_size | send_batch_max_size | Why |
|----------|---------|-----------------|---------------------|-----|
| **Agent (low-latency)** | `200ms` | `8192` | `0` (unlimited) | Agent buffers briefly, gateway handles heavy batching |
| **Gateway (throughput)** | `5s` | `8192` | `16384` | Longer timeout = fuller batches = fewer exports |
| **Real-time traces** | `1s` | `512` | `1024` | When trace delay must be <2s end-to-end |
| **Metrics pipeline** | `10s` | `8192` | `16384` | Metrics tolerate higher latency; batch efficiency matters |
| **Log pipeline (high vol)** | `3s` | `16384` | `32768` | Logs are large; bigger batches reduce per-log overhead |
| **Low-traffic dev** | `30s` | `512` | `1024` | Don't send nearly-empty batches every 200ms |

### How to Know If Your Batch Size Is Wrong

Monitor these two metrics:

```promql
# Timeout triggers (batch sent because timeout fired, not because it was full)
rate(otelcol_processor_batch_timeout_trigger_send[5m])

# Size triggers (batch sent because it reached send_batch_size)
rate(otelcol_processor_batch_batch_size_trigger_send[5m])
```

| Ratio | Diagnosis | Action |
|-------|-----------|--------|
| Size triggers >> timeout triggers | High traffic, batches fill quickly | Increase `send_batch_size` for efficiency |
| Timeout triggers >> size triggers | Low traffic, batches sent half-empty | Increase `timeout` or decrease `send_batch_size` |
| Roughly equal | Well-tuned | Leave it alone |

### Batch Size and Memory

Each batch consumes memory. The formula:

```
Memory per batch ≈ send_batch_max_size × avg_item_size

Example (traces):
  send_batch_max_size = 16384 spans
  avg span size = 1 KB
  Memory per batch ≈ 16 MiB

  With 3 pipelines (traces + metrics + logs):
  Total batch memory ≈ 48 MiB
```

Factor this into your memory limiter calculation.

---

## 5. Queue and Retry Strategy

The sending queue buffers data between the batch processor and the exporter. If the backend is slow or down, the queue prevents data loss — up to a point.

### Queue Sizing

```
queue_size = how many BATCHES (not items) the queue can hold

Items in queue = queue_size × send_batch_size

Duration buffered = queue_size × send_batch_size ÷ ingest_rate

Example:
  queue_size = 5000 batches
  send_batch_size = 8192 items
  ingest_rate = 10,000 spans/sec
  Duration = 5000 × 8192 ÷ 10000 = 4096 seconds ≈ 68 minutes of buffer
```

### Queue Sizing Table

| Scenario | queue_size | num_consumers | Approximate Buffer | Memory Cost |
|----------|-----------|---------------|-------------------|-------------|
| **Agent (to gateway)** | `5000` | `10` | ~68 min at 1K/sec | ~40 MiB |
| **Gateway (to backend)** | `10000` | `20` | ~136 min at 1K/sec | ~80 MiB |
| **High-traffic gateway** | `20000` | `40` | ~27 min at 10K/sec | ~160 MiB |
| **Cost-sensitive** | `2000` | `5` | ~27 min at 1K/sec | ~16 MiB |

### num_consumers (Parallelism)

`num_consumers` controls how many goroutines concurrently drain the queue and send to the backend.

| Value | When | Notes |
|-------|------|-------|
| `5` | Low throughput, single-core agent | Minimal goroutine overhead |
| `10` | **Default agent** | Good balance |
| `20` | **Default gateway** | Backends can handle parallel sends |
| `40` | High throughput, backend supports it | Check backend connection limits |
| `50+` | Rarely needed | Diminishing returns; may hit backend rate limits |

**How to know if you need more consumers:** If `otelcol_exporter_queue_size` is consistently >0 but the backend isn't failing, your consumers can't drain fast enough. Increase `num_consumers`.

### Retry Strategy

| Parameter | Agent | Gateway | Why |
|-----------|-------|---------|-----|
| `initial_interval` | `5s` | `5s` | Don't hammer a failing backend |
| `max_interval` | `30s` | `60s` | Gateway retries longer (more at stake) |
| `max_elapsed_time` | `300s` (5 min) | `600s` (10 min) | After this, data is dropped |
| `randomization_factor` | `0.5` | `0.5` | Jitter prevents thundering herd |
| `multiplier` | `1.5` | `1.5` | Exponential backoff: 5s → 7.5s → 11s → 17s → 25s → 30s (capped) |

### Persistent Queues

For gateways where data loss is unacceptable:

```yaml
sending_queue:
  enabled: true
  storage: file_storage/persistent_queue  # Survives collector restarts
  queue_size: 10000
  num_consumers: 20
```

**Cost:** Disk I/O. Persistent queues write to disk on every enqueue and dequeue. Use SSDs. Budget ~10 MiB/sec disk throughput for 10K items/sec.

**When to enable:** Gateway tier only. Agents should not use persistent queues (adds latency and disk requirements to every node).

---

## 6. Processor Cost Table

Not all processors are equal. Some are nearly free; others consume significant CPU. **Order matters** — put cheap filters before expensive transforms.

### CPU Cost Per Processor

| Processor | CPU Cost | Memory Cost | Latency Added | Notes |
|-----------|----------|-------------|---------------|-------|
| `memory_limiter` | Negligible | Negligible | <1μs | Must be first. Just reads cgroup memory. |
| `resourcedetection` | Low (startup) | Negligible | 0 (one-time) | Runs once at startup, caches result |
| `resource` | Low | Negligible | <1μs | Static attribute add/update |
| `k8sattributes` | Low–Medium | ~50 MiB cache | <100μs | Watches K8s API; cache size depends on cluster size |
| `attributes` | Low | Negligible | <10μs | Simple key/value operations |
| `filter` (simple) | Low | Negligible | <10μs | String equality checks |
| `filter` (regex) | **Medium** | Negligible | ~100μs | Regex is expensive. Prefer exact match. |
| `transform` (OTTL) | **Medium–High** | Low | ~50–500μs | Depends on statement complexity |
| `redaction` | **Medium** | Low | ~100μs per regex | Each blocked_values pattern is a regex scan |
| `groupbytrace` | **High** | **High** (proportional to traces in flight) | ~seconds | Holds all spans until trace completes |
| `tail_sampling` | **High** | **High** (proportional to decision_wait × throughput) | decision_wait (e.g., 10s) | Holds all spans for decision_wait duration |
| `batch` | Low | Medium (batch buffer) | timeout value | Must be last. |
| `span` | Low | Negligible | <10μs | Rename spans from attributes |
| `metricstransform` | Low–Medium | Low | <50μs | Depends on number of rename rules |
| `cumulativetodelta` | Medium | Medium (state per series) | <100μs | Maintains state for every unique time series |
| `probabilistic_sampler` | **Negligible** | Negligible | <1μs | Hash comparison only |

### Optimization Rules

1. **Filter before transform.** A `filter` that drops 50% of data is cheap. Every dropped item is one less item for the expensive `transform` or `tail_sampling` to process.

2. **Simple filters before regex filters.** `attributes["http.route"] == "/health"` is O(1). `IsMatch(body, ".*health.*")` is O(n) on body length.

3. **Tail sampling is the most expensive processor.** It holds ALL spans in memory for `decision_wait` duration.
   ```
   Memory for tail_sampling ≈ decision_wait × ingest_rate × avg_span_size
   Example: 10s × 5000 spans/sec × 1 KB = 50 MiB just for sampling buffer
   ```

4. **k8sattributes cache scales with cluster size.** For a 500-node cluster with 10 pods/node, the cache holds ~5000 pod entries × ~2 KB each ≈ 10 MiB. For 5000 nodes, budget ~100 MiB.

5. **Redaction regex count matters.** Each `blocked_values` pattern runs against every attribute value. 3 patterns on spans with 20 attributes = 60 regex evaluations per span. Keep patterns under 5.

### Recommended Pipeline Order (with costs)

```yaml
processors:
  - memory_limiter              # ~0 CPU    — safety valve
  - resourcedetection           # ~0 CPU    — one-time at startup
  - k8sattributes               # Low CPU   — cache lookup
  - resource                    # ~0 CPU    — static attribute set
  - filter/traces               # Low CPU   — exact string match
  - filter/traces-noisy         # Low CPU   — exact string match
  - filter/metrics-cardinality  # Low CPU   — metric name match
  - filter/logs-severity        # Low CPU   — integer comparison
  - transform/traces-cost       # Med CPU   — OTTL truncation
  - transform/logs-cost         # Med CPU   — OTTL truncation
  - redaction                   # Med CPU   — regex per attribute
  - tail_sampling/composite     # HIGH CPU  — hold + decide (gateway only)
  - batch                       # Low CPU   — buffer and flush
```

**Key insight:** By filtering 40-60% of data before reaching `tail_sampling`, you reduce the sampling buffer by 40-60% and proportionally reduce CPU.

---

## 7. Sampling Strategy

### Head vs. Tail Sampling

| Factor | Head Sampling | Tail Sampling |
|--------|--------------|---------------|
| **Where** | Agent (at ingestion) | Gateway (after full trace available) |
| **Decision basis** | Random probability OR attribute match | Full trace: status, latency, attributes |
| **Can keep all errors** | No (doesn't know outcome yet) | Yes |
| **Can keep slow traces** | No (doesn't know total latency) | Yes |
| **Memory cost** | Zero (decide immediately) | High (buffer entire traces for decision_wait) |
| **CPU cost** | Negligible | High |
| **Requires gateway** | No | Yes |

### Sampling Rate Recommendations

| Environment | Strategy | Keep Rate | Expected Cost Savings |
|-------------|----------|-----------|----------------------|
| **Production** | Tail: 100% errors + 100% slow (>2s) + 10% probabilistic | ~15-20% of traces | 80-85% trace cost reduction |
| **Staging** | Head: 50% probabilistic | 50% of all traces | 50% trace cost reduction |
| **Development** | None (keep all) | 100% | 0% |
| **High-traffic prod** | Tail: 100% errors + 100% slow (>5s) + 5% probabilistic | ~8-12% of traces | 88-92% trace cost reduction |
| **Cost-critical prod** | Tail: 100% errors + 100% slow (>2s) + 1% probabilistic | ~3-5% of traces | 95-97% trace cost reduction |

### Choosing the Latency Threshold

The `slow-traces` policy threshold depends on your SLOs:

| Application Type | Suggested Threshold | Reasoning |
|-------------------|-------------------|-----------|
| API services (p99 < 200ms) | `500ms` | 2.5× p99 catches real outliers |
| Web applications (p99 < 1s) | `2000ms` | Standard default |
| Batch/async jobs | `10000ms` | Jobs are inherently slow |
| Database queries | `1000ms` | Slow queries are the #1 perf issue |

**Formula:** Set threshold to ~2-3× your p99 latency. If p99 is 800ms, threshold = 2000ms.

### Choosing the Probabilistic Rate

The probabilistic catchall determines your "normal traffic" visibility:

| Rate | What You Get | Monthly span volume (at 10K spans/sec input) |
|------|-------------|----------------------------------------------|
| 1% | Enough to detect trends, not debug individual requests | ~260M spans |
| 5% | Good for aggregate analysis + occasional debugging | ~1.3B spans |
| 10% | **Recommended default.** Debug most issues. | ~2.6B spans |
| 25% | High visibility. Use if cost isn't a concern. | ~6.5B spans |
| 50% | Near-full visibility. Staging default. | ~13B spans |

### Tail Sampling Memory Budget

```
Buffer memory = decision_wait × ingest_rate × avg_span_size × (1 - pre_filter_drop_rate)

Example (production with filters):
  decision_wait = 10s
  ingest_rate = 10,000 spans/sec (at gateway, after agent-level filtering)
  avg_span_size = 1 KB
  pre_filter_drop_rate = 40% (health checks, static assets already dropped)

  Buffer = 10 × 10000 × 1KB × 0.6 = 60 MiB

Without filters:
  Buffer = 10 × 10000 × 1KB × 1.0 = 100 MiB
```

This is why filters before tail_sampling matter — 40 MiB saved in this example.

### `num_traces` Setting

Set `num_traces` to the maximum number of **concurrent traces** in the sampling buffer:

```
num_traces = decision_wait × unique_traces_per_second

Example: 10s wait × 2000 unique traces/sec = 20,000
Add 5× headroom: num_traces = 100,000

Default: 100,000 (handles up to 10K unique traces/sec with 10s wait)
```

If `otelcol_processor_tail_sampling_count_traces_dropped` is >0, increase `num_traces`.

---

## 8. Exporter Optimization

### Compression

| Algorithm | CPU Cost | Compression Ratio | When to Use |
|-----------|----------|-------------------|-------------|
| `none` | 0 | 1:1 | Agent → Gateway within same cluster (no bandwidth constraint) |
| `gzip` | Medium | 3-5× | **Default.** Gateway → external backend over internet |
| `zstd` | Medium-High | 4-8× | Better ratio than gzip, higher CPU. Use for high-volume log pipelines |

**Per-signal compression effectiveness:**

| Signal | Typical Compression Ratio (gzip) | Why |
|--------|----------------------------------|-----|
| Logs | 8-15× | Highly repetitive text, JSON structures |
| Traces | 3-5× | Moderate repetition (attributes, resource) |
| Metrics | 2-4× | Already compact (numeric values, short labels) |

**Recommendation:**
- Agent → Gateway (in-cluster): `compression: none` (saves CPU, network is free)
- Gateway → External backend: `compression: gzip` (saves bandwidth, worth the CPU)
- High-volume logs to remote backend: `compression: zstd` (best ratio for text)

### gRPC vs HTTP

| Factor | gRPC (port 4317) | HTTP (port 4318) |
|--------|-------------------|-------------------|
| **Throughput** | Higher (streaming, binary protobuf) | Lower (request/response, JSON or protobuf) |
| **Latency** | Lower (persistent connections, multiplexing) | Higher (connection overhead per batch) |
| **CPU** | Lower (binary serialization) | Higher (JSON parsing if used) |
| **Firewall-friendliness** | Requires HTTP/2 support | Works through any HTTP proxy |
| **Load balancer support** | Needs gRPC-aware LB (L7) | Any L4/L7 LB works |

**Recommendation:**
- Agent → Gateway: Always gRPC (in-cluster, no firewall issues)
- Gateway → Backend: gRPC if supported; HTTP if behind a proxy or the backend requires it
- Browser → Collector: HTTP (browsers can't do gRPC natively)

### Connection Tuning

```yaml
# Agent → Gateway (in-cluster, gRPC)
exporters:
  otlp:
    endpoint: otel-gateway:4317
    tls:
      insecure: true                    # In-cluster, no TLS needed
    compression: none                    # Skip compression in-cluster
    keepalive:
      time: 30s                          # Send keepalive pings
      timeout: 10s                       # Wait for pong
      permit_without_stream: true        # Keep connection alive even when idle

# Gateway → Backend (external, gRPC)
exporters:
  otlp:
    endpoint: otlp.backend.com:4317
    compression: gzip
    timeout: 30s                         # Per-export timeout
    keepalive:
      time: 30s
      timeout: 10s
      permit_without_stream: true
```

### Backend Rate Limits

Many backends enforce ingestion rate limits. If you exceed them:

| Symptom | Cause | Fix |
|---------|-------|-----|
| 429 Too Many Requests | Rate limit exceeded | Reduce `num_consumers`, add more gateways, or increase backend tier |
| Queue growing, slow drain | Backend can't keep up | Reduce ingest rate (sample more aggressively) or scale backend |
| Intermittent 503 | Backend overloaded | Increase `initial_interval` in retry config |

---

## 9. Cost-Per-Signal Math

This is where the consulting value lives. Every optimization lever has a dollar amount.

### Backend Pricing Reference (approximate, as of 2025)

| Backend | Traces | Metrics | Logs |
|---------|--------|---------|------|
| **Datadog** | $1.70/M spans (ingested) | $0.05/custom metric/month | $0.10/GB (ingested) |
| **New Relic** | $0.30/GB (all signals) | $0.30/GB | $0.30/GB |
| **Splunk** | $3.00/GB (traces) | by host license | $2.00/GB (ingested) |
| **Grafana Cloud** | $0.50/M spans | $8/1K active series/month | $0.50/GB |
| **Elastic** | Resource-based (ECU) | Resource-based | Resource-based |
| **Dynatrace** | $0.00225/span | $0.001/metric/month | $0.0035/GB |
| **GCP Cloud Ops** | $0.20/M spans | Free (first 150M pts) | $0.50/GB |
| **AWS X-Ray** | $5.00/M spans (sampled) | N/A | N/A |
| **Self-hosted** | Compute + storage cost | Compute + storage cost | Compute + storage cost |

*Prices are approximate and vary by commitment tier. Always verify with vendor.*

### ROI Per Optimization Lever

**Scenario:** 50-node K8s cluster, 100 microservices, 10K spans/sec, 50K metrics/sec, 5 GB/hr logs

#### Traces (10,000 spans/sec = 864M spans/day)

| Lever | Volume Reduction | Spans Saved/day | Datadog Savings/month | Grafana Savings/month |
|-------|-----------------|-----------------|----------------------|----------------------|
| Filter health checks | 15% | 130M | $6,630 | $1,944 |
| Filter static assets + OPTIONS | 10% | 86M | $4,420 | $1,296 |
| Strip high-card attributes | 0% spans, ~30% bytes | — | — (span count stays same) | — |
| Tail sample: keep errors + slow + 10% | 80% | 691M | $35,240 | $10,368 |
| **Combined** | **~85%** | **~734M** | **~$37,400/month** | **~$11,016/month** |

#### Logs (5 GB/hr = 120 GB/day)

| Lever | Volume Reduction | GB Saved/day | Datadog Savings/month | Splunk Savings/month |
|-------|-----------------|-------------|----------------------|---------------------|
| Severity filter (WARN+ only) | 60% | 72 GB | $216 | $4,320 |
| Drop health/probe logs | 10% | 12 GB | $36 | $720 |
| Truncate bodies to 4 KB | 20% | 24 GB | $72 | $1,440 |
| **Combined** | **~70%** | **~84 GB** | **~$252/month** | **~$5,040/month** |

#### Metrics (50,000 active series)

| Lever | Series Reduction | Series Saved | Grafana Savings/month |
|-------|-----------------|-------------|----------------------|
| Drop pod_uid, container_id labels | 40% | 20,000 | $160 |
| Drop idle CPU, runtime metrics | 15% | 7,500 | $60 |
| **Combined** | **~50%** | **~25,000** | **~$200/month** |

### Total Monthly Savings Example

| Backend | Before Optimization | After (Production Profile) | Monthly Savings |
|---------|--------------------|-----------------------------|-----------------|
| Datadog | ~$52,000 | ~$14,000 | **~$38,000** |
| Grafana Cloud | ~$15,000 | ~$4,000 | **~$11,000** |
| Splunk | ~$48,000 | ~$15,000 | **~$33,000** |

*These are illustrative. Actual savings depend on your specific traffic patterns, backend pricing tier, and which optimizations you apply.*

---

## 10. Tuning Checklist

Use this checklist when setting up a new collector deployment.

### Before Deploy

- [ ] **Choose topology** (Section 1): agent-only, 2-tier, or 3-tier based on throughput and sampling needs
- [ ] **Size resources** (Section 2): CPU/memory based on expected throughput
- [ ] **Set GOMAXPROCS** to match CPU limit
- [ ] **Configure memory limiter** (Section 3): Use percentage mode for K8s, ensure 20% headroom to container limit
- [ ] **Tune batch processor** (Section 4): Match timeout and batch size to latency requirements
- [ ] **Size queues** (Section 5): Calculate buffer duration; enable persistent queue on gateway
- [ ] **Order processors** (Section 6): Cheap filters first, expensive processors after
- [ ] **Choose sampling** (Section 7): Head (agent) or tail (gateway), set rates per environment
- [ ] **Configure exporter** (Section 8): gRPC in-cluster, compression for external; set keepalive

### After Deploy (First 24 Hours)

- [ ] Check `otelcol_process_memory_rss` stays below 70% of limit
- [ ] Check `otelcol_exporter_send_failed_*` is 0
- [ ] Check `otelcol_exporter_queue_size` trends to 0 (queue drains)
- [ ] Check batch triggers: size vs. timeout ratio is reasonable
- [ ] Check `otelcol_receiver_refused_*` is 0 (no back-pressure)
- [ ] Verify tail sampling decisions: `otelcol_processor_tail_sampling_count_traces_sampled` > 0
- [ ] Run `./deploy/test-telemetry.sh` to confirm end-to-end flow

### Ongoing (Weekly)

- [ ] Review memory headroom trend (is it growing?)
- [ ] Review queue depth trend (is the backend keeping up?)
- [ ] Check for new error-level exporter failures
- [ ] Validate sampling rate matches target (check `otelcol_processor_tail_sampling_sampling_decision`)
- [ ] Compare actual cost vs. estimated savings from Section 9

### Tuning Signals

| Metric | Healthy | Action If Unhealthy |
|--------|---------|---------------------|
| `otelcol_process_memory_rss / container_limit` | < 70% | Increase memory limit or reduce batch/queue sizes |
| `otelcol_exporter_queue_size / queue_capacity` | < 25% | If > 75%, increase `num_consumers` or scale replicas |
| `otelcol_exporter_send_failed_*` | 0 | Check backend connectivity, auth, rate limits |
| `rate(otelcol_receiver_refused_*[5m])` | 0 | Memory limiter is activating — increase memory or reduce ingest |
| `batch timeout triggers / total triggers` | < 50% | If > 80%, reduce `send_batch_size` or increase `timeout` |
| `otelcol_processor_tail_sampling_count_traces_dropped` | 0 | Increase `num_traces` |
| `rate(otelcol_process_cpu_seconds[5m])` | < 70% of limit | Add CPU or reduce processor complexity |

---

## Further Reading

- [Cost Profiles](../collector/fragments/processors/cost-profiles.md) — per-environment processor bundles
- [Scaling Collectors Runbook](runbooks/scaling-collectors.md) — capacity planning and HPA
- [Pipeline Latency Runbook](runbooks/pipeline-latency.md) — latency troubleshooting
- [Collector High Memory Runbook](runbooks/collector-high-memory.md) — OOM prevention
- [Collector Dropping Data Runbook](runbooks/collector-dropping-data.md) — queue and exporter failures
