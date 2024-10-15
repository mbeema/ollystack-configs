# OpenTelemetry Collector Deep Dive: Architecture, Components, and Operations

> A comprehensive guide covering the OpenTelemetry Collector's internals, all major components with production-ready YAML configurations, deployment patterns, performance tuning, security, OTTL transformations, Kubernetes operations, troubleshooting, and migration strategies.

---

## Table of Contents

1. [Architecture Deep Dive](#1-architecture-deep-dive)
2. [Deployment Patterns](#2-deployment-patterns)
3. [Configuration Deep Dive](#3-configuration-deep-dive)
4. [Performance and Tuning](#4-performance-and-tuning)
5. [Receivers](#5-receivers)
6. [Processors](#6-processors)
7. [Exporters](#7-exporters)
8. [Connectors](#8-connectors)
9. [Extensions](#9-extensions)
10. [OTTL (OpenTelemetry Transformation Language)](#10-ottl-opentelemetry-transformation-language)
11. [Security](#11-security)
12. [Self-Monitoring and Observability](#12-self-monitoring-and-observability)
13. [Kubernetes Operations](#13-kubernetes-operations)
14. [Troubleshooting](#14-troubleshooting)
15. [Migration Guides](#15-migration-guides)
16. [Production Checklist](#16-production-checklist)

---

## 1. Architecture Deep Dive

### 1.1 Collector Binary Types

The OpenTelemetry Collector ships in three distribution tiers:

**Core Distribution (`otelcol`)**
- Contains only officially maintained, first-party components from the `go.opentelemetry.io/collector` Go module.
- Includes essentials: OTLP receiver/exporter, batch processor, memory_limiter processor, debug exporter, and core extensions (health_check, pprof, zpages).
- Smallest binary footprint, smallest attack surface.
- Suitable when you only need OTLP-in/OTLP-out with basic processing.

**Contrib Distribution (`otelcol-contrib`)**
- Includes everything in Core **plus** all community-contributed components from `opentelemetry-collector-contrib`.
- Contains 200+ receivers, processors, exporters, extensions, and connectors.
- **Not recommended for production** because the oversized binary includes components you do not need, increasing attack surface and resource consumption.
- Ideal for development, testing, and evaluation.

**Custom Distribution (via OCB -- OpenTelemetry Collector Builder)**
- The **recommended production approach**: build a custom binary containing only the components your environment requires.
- Uses a `builder-config.yaml` (also called `manifest.yaml`) to declare exactly which components to include.
- Produces a single statically-linked Go binary.

```yaml
# builder-config.yaml (OCB manifest)
dist:
  name: otelcol-custom
  description: "Production OTel Collector for Acme Corp"
  output_path: ./build/otelcol-custom
  otelcol_version: "0.114.0"

receivers:
  - gomod: go.opentelemetry.io/collector/receiver/otlpreceiver v0.114.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/prometheusreceiver v0.114.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/filelogreceiver v0.114.0

processors:
  - gomod: go.opentelemetry.io/collector/processor/batchprocessor v0.114.0
  - gomod: go.opentelemetry.io/collector/processor/memorylimiterprocessor v0.114.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/attributesprocessor v0.114.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/resourceprocessor v0.114.0

exporters:
  - gomod: go.opentelemetry.io/collector/exporter/otlpexporter v0.114.0
  - gomod: go.opentelemetry.io/collector/exporter/debugexporter v0.114.0

extensions:
  - gomod: go.opentelemetry.io/collector/extension/zpagesextension v0.114.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/healthcheckextension v0.114.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/pprofextension v0.114.0

connectors:
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/connector/spanmetricsconnector v0.114.0
```

Build commands:
```bash
# Install OCB
go install go.opentelemetry.io/collector/cmd/builder@latest

# Build from manifest
builder --config=builder-config.yaml
```

### 1.2 Internal Architecture: The Pipeline Model

The Collector's core abstraction is the **pipeline**. Every pipeline handles exactly one signal type (traces, metrics, or logs) and consists of three ordered stages:

```
┌──────────────────────────────────────────────────────────────────────┐
│                        OpenTelemetry Collector                       │
│                                                                      │
│  ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐       │
│  │Receiver │──>│Processor │──>│Processor │──>│ Exporter │       │
│  │  A      │    │  1       │    │  2       │    │  X       │       │
│  └─────────┘    └──────────┘    └──────────┘    └──────────┘       │
│       │                                              │              │
│       │         ┌──────────┐    ┌──────────┐         │              │
│       └────────>│Processor │──>│ Exporter │         │              │
│                 │  3       │    │  Y       │         │              │
│  ┌─────────┐   └──────────┘    └──────────┘         │              │
│  │Receiver │─────────────────────────────────────────┘              │
│  │  B      │                                                        │
│  └─────────┘                                                        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │              Extensions (health_check, pprof, zpages)      │     │
│  └────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────┘
```

**Receivers** are entry points:
- **Push-based**: listen on an endpoint (OTLP gRPC/HTTP, Zipkin, Jaeger, syslog)
- **Pull-based**: actively scrape targets (Prometheus, hostmetrics, awscloudwatch)
- A single receiver instance can feed multiple pipelines via a **fan-out consumer**.

**Processors** transform data in order. The YAML declaration order determines execution order. Common processors: batch, memory_limiter, attributes, filter, transform, tail_sampling, resource.

**Exporters** are exit points. A single exporter instance can be shared across multiple pipelines via **fan-in** merging.

Data flow with fan-out and fan-in:
```
Receiver A ─┐                           ┌─> Exporter X
             ├──fan-out──> [P1 → P2 → P3] ──fan-in──┤
Receiver B ─┘                           └─> Exporter Y
```

### 1.3 Connectors

Connectors (v0.60+) act as **both an exporter and a receiver**, bridging two pipelines. They enable cross-signal derivation (e.g., generating metrics from traces).

| Connector | Input Signal | Output Signal | Purpose |
|-----------|-------------|---------------|---------|
| `spanmetrics` | Traces | Metrics | Generate R.E.D. metrics (Rate, Error, Duration) from spans |
| `count` | Traces/Metrics/Logs | Metrics | Count telemetry items, emit as metrics |
| `forward` | Any | Same | Forward data between pipelines (merge/fork) |
| `servicegraph` | Traces | Metrics | Build service dependency graph metrics |
| `routing` | Any | Same | Route data to different pipelines based on attributes |
| `failover` | Any | Same | Failover between exporter pipelines |

### 1.4 Extensions

Extensions provide capabilities **outside** the pipeline data path:

**Diagnostic Extensions:**

| Extension | Default Port | Purpose |
|-----------|-------------|---------|
| `health_check` | `:13133` | HTTP health endpoint for liveness/readiness probes |
| `pprof` | `:1777` | Go pprof profiling endpoints (CPU, memory, goroutine) |
| `zpages` | `:55679` | In-process diagnostic pages (pipeline status, trace samples) |

**Authentication Extensions:**

| Extension | Purpose |
|-----------|---------|
| `bearertokenauth` | Authenticate with static bearer token or token from file |
| `oauth2clientauth` | OAuth 2.0 client credentials flow |
| `basicauth` | HTTP Basic authentication |
| `oidcauth` | OpenID Connect authentication for receivers |
| `sigv4auth` | AWS Signature V4 authentication |

**Storage Extensions:**

| Extension | Purpose |
|-----------|---------|
| `file_storage` | Persistent queue storage for exporters |
| `db_storage` | Database-backed persistent storage |

### 1.5 Memory Management

**GOMEMLIMIT (Current Best Practice):**

The `GOMEMLIMIT` environment variable tells the Go runtime GC to target a specific memory ceiling, reducing GC thrashing without wasting memory on the deprecated ballast extension (removed in v0.104.0).

Formula:
```
GOMEMLIMIT = 80% of hard memory limit
```

**memory_limiter Processor:**

Even with `GOMEMLIMIT`, the `memory_limiter` processor is essential. It applies backpressure when memory exceeds thresholds, preventing OOM kills.

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 1800           # Hard limit (~90% of container limit)
    spike_limit_mib: 500      # Maximum expected spike
```

**Critical rule**: `memory_limiter` must be the **first** processor in every pipeline.

Production memory configuration for a 2 GiB container:
```
Container limit:    2048 MiB
GOMEMLIMIT:         1600 MiB  (80%)
memory_limiter:     1800 MiB  (90%)
spike_limit_mib:     500 MiB
```

### 1.6 Internal Data Model (pdata)

The `pdata` package is the in-memory representation of all telemetry within the Collector:

- **Based on OTLP Protobuf**: Enables zero-copy translation to/from OTLP wire format.
- **Three signal types**: `pdata.Traces`, `pdata.Metrics`, `pdata.Logs`
- **Ownership transfer**: When a processor calls `ConsumeTraces()` on the next processor, ownership of the data transfers.
- **Exclusive mode**: If any processor declares `MutatesData: true`, data is **cloned** at fan-out points.
- **Shared mode**: If no processor mutates data, all pipelines see the **same** data instance (zero copies).

---

## 2. Deployment Patterns

### 2.1 The Three Deployment Tiers

**Tier 0: No Collector (SDK Direct Export)**
```
Application (with OTel SDK) ──OTLP──> Backend
```
Simplest setup but no centralized processing, retry, or buffering.

**Tier 1: Agent Mode**
```
Application ──OTLP──> Collector (Agent) ──OTLP──> Backend
```
Collector runs co-located with the application. Handles retry, buffering, batching, enrichment.

**Tier 2: Agent + Gateway (Recommended for Production)**
```
Application ──OTLP──> Collector (Agent) ──OTLP──> Collector (Gateway) ──OTLP──> Backend
```
Agents do minimal processing; Gateways do heavy processing (tail sampling, aggregation, routing).

### 2.2 Kubernetes Deployment Modes

**DaemonSet (Agent Mode)**
- One Collector pod per node.
- Collects node-level metrics (kubeletstats, hostmetrics), scrapes local pods, receives OTLP.
- Low resource overhead per pod (~256 MiB memory, 250m CPU typical).

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-agent
spec:
  template:
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-custom:latest
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          env:
            - name: GOMEMLIMIT
              value: "400MiB"
            - name: K8S_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
```

**Deployment/StatefulSet (Gateway Mode)**
- Centralized processing cluster, typically 3+ replicas.
- StatefulSet preferred when using persistent queues (`file_storage` extension).
- Use `PodDisruptionBudget` to ensure availability during upgrades.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-gateway
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: otel-gateway
              topologyKey: kubernetes.io/hostname
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-custom:latest
          resources:
            requests:
              cpu: "2"
              memory: 4Gi
            limits:
              cpu: "4"
              memory: 4Gi
          env:
            - name: GOMEMLIMIT
              value: "3200MiB"
```

**Sidecar (Per-Pod Agent)**
- One Collector container per application pod.
- Maximum isolation; each app gets its own pipeline configuration.
- Higher total resource usage (sidecar per pod vs. one DaemonSet agent per node).
- As of Kubernetes 1.29+, the OTel Operator uses **native sidecars** (init containers with `restartPolicy: Always`).

**Deployment Mode Comparison:**

| Mode | Workload Type | Best For | Key Characteristics |
|------|---------------|----------|---------------------|
| **DaemonSet** | One pod per node | Node-level collection (logs, host metrics, kubelet stats) | Low latency, local data, `hostmetrics` and `filelog` receivers |
| **Deployment** | Scalable replica set | Gateway/aggregation, cluster-wide receivers | Horizontally scalable, stateless processing |
| **StatefulSet** | Ordered, stable pods | Tail sampling, load-balancing exporter, persistent storage | Stable hostnames, persistent volumes |
| **Sidecar** | Per-pod container | Application-specific collection, strict isolation | Fast offloading, per-app config |

### 2.3 OpenTelemetry Operator for Kubernetes

The OTel Operator provides two Custom Resource Definitions (CRDs):

**OpenTelemetryCollector CRD:**
```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
  namespace: observability
spec:
  mode: deployment          # deployment, daemonset, sidecar, statefulset
  replicas: 3
  image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.96.0
  resources:
    limits:
      cpu: "2"
      memory: 4Gi
    requests:
      cpu: 500m
      memory: 1Gi
  env:
    - name: OTEL_EXPORTER_TOKEN
      valueFrom:
        secretKeyRef:
          name: otel-secrets
          key: api-token
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      memory_limiter:
        check_interval: 1s
        limit_mib: 3200
        spike_limit_mib: 800
      batch:
        send_batch_size: 8192
        timeout: 200ms
    exporters:
      otlp:
        endpoint: "${env:BACKEND_ENDPOINT}"
        headers:
          Authorization: "Bearer ${env:OTEL_EXPORTER_TOKEN}"
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
```

**Instrumentation CRD (Auto-Instrumentation):**
```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: auto-instrumentation
spec:
  exporter:
    endpoint: http://otel-agent-collector.otel.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
  go:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-go:latest
```

Activate per-pod via annotations:
```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
    # or: inject-python, inject-nodejs, inject-dotnet, inject-go
```

### 2.4 Scaling Strategies

**Load Balancing with the `loadbalancing` Exporter:**

Uses **consistent hashing** to route data to specific backend collector instances. Critical for tail-based sampling (all spans for a trace must land on the same gateway) and spanmetrics (service-level aggregation).

```yaml
exporters:
  loadbalancing:
    protocol:
      otlp:
        timeout: 1s
    resolver:
      dns:
        hostname: otel-gateway-headless.otel.svc.cluster.local
        port: 4317
    routing_key: traceID   # or "service" for spanmetrics
```

**Component Scaling Categories:**
- **Stateless components** (most processors, most exporters): Scale freely with horizontal replicas.
- **Scrapers** (Prometheus receiver, hostmetrics): Must use target allocation (OTel Operator TargetAllocator) to avoid duplicate scrapes.
- **Stateful components** (tail_sampling, spanmetrics): Require consistent hashing via loadbalancing exporter.

### 2.5 High Availability Patterns

**Active-Active Gateways:**
```
                   ┌──> Gateway A ──┐
Agents ──> LB ────┤                 ├──> Backend
                   └──> Gateway B ──┘
```

**Persistent Queuing for Crash Recovery:**
```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol/queue
    timeout: 10s
    compaction:
      directory: /var/lib/otelcol/queue
      on_start: true
      on_rebound: true

exporters:
  otlp:
    endpoint: backend:4317
    sending_queue:
      enabled: true
      storage: file_storage
      queue_size: 10000
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
```

### 2.6 Edge/IoT Deployment

- **Custom OCB builds** with minimal components produce binaries under 30 MB.
- **SQLite-backed storage** for intermittent connectivity.
- **GOMEMLIMIT** set very low (e.g., 64MiB) for memory-constrained devices.
- Use `file_storage` extension with aggressive compaction to manage disk on edge devices.

---

## 3. Configuration Deep Dive

### 3.1 Complete Production Configuration Example

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        max_recv_msg_size_mib: 4
        max_concurrent_streams: 200
        keepalive:
          server_parameters:
            max_connection_idle: 11s
            max_connection_age: 30s
            max_connection_age_grace: 5s
          enforcement_policy:
            min_time: 10s
            permit_without_stream: true
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins: ["*"]

  prometheus:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 30s
          static_configs:
            - targets: ['localhost:8888']

  filelog:
    include: [/var/log/pods/*/*/*.log]
    operators:
      - type: router
        routes:
          - output: json_parser
            expr: 'body matches "^\\{"'
      - id: json_parser
        type: json_parser
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%fZ'

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 1800
    spike_limit_mib: 500

  batch:
    send_batch_size: 8192
    send_batch_max_size: 0
    timeout: 5s

  resource:
    attributes:
      - key: environment
        value: "${env:DEPLOY_ENV}"
        action: upsert
      - key: cluster
        value: "${env:CLUSTER_NAME}"
        action: upsert

  attributes:
    actions:
      - key: db.statement
        action: delete
      - key: http.request.header.authorization
        action: delete

  filter:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
        - 'attributes["http.route"] == "/readyz"'

  tail_sampling:
    decision_wait: 10s
    num_traces: 100000
    expected_new_traces_per_sec: 10000
    policies:
      - name: errors
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-traces
        type: latency
        latency: {threshold_ms: 1000}
      - name: probabilistic
        type: probabilistic
        probabilistic: {sampling_percentage: 10}

exporters:
  otlp/backend:
    endpoint: "backend.example.com:4317"
    tls:
      cert_file: /etc/otel/tls/cert.pem
      key_file: /etc/otel/tls/key.pem
    compression: zstd
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 5000
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
    timeout: 30s

  debug:
    verbosity: basic
    sampling_initial: 5
    sampling_thereafter: 200

connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 5s, 10s]
    dimensions:
      - name: http.method
      - name: http.status_code
    metrics_flush_interval: 15s

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  pprof:
    endpoint: localhost:1777
  zpages:
    endpoint: localhost:55679
  file_storage:
    directory: /var/lib/otelcol/storage

service:
  extensions: [health_check, pprof, zpages, file_storage]
  telemetry:
    logs:
      level: info
      encoding: json
    metrics:
      level: detailed
      address: 0.0.0.0:8888
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource, attributes, filter, batch]
      exporters: [spanmetrics, otlp/backend]
    traces/sampled:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, batch]
      exporters: [otlp/backend]
    metrics:
      receivers: [otlp, prometheus, spanmetrics]
      processors: [memory_limiter, resource, batch]
      exporters: [otlp/backend]
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, resource, attributes, batch]
      exporters: [otlp/backend]
```

### 3.2 Environment Variable Substitution

| Syntax | Example | Notes |
|--------|---------|-------|
| Naked `$ENV` | `$API_KEY` | Simple, limited character set |
| Braces `${ENV}` | `${API_KEY}` | Disambiguates from surrounding text |
| Provider `${env:ENV}` | `${env:API_KEY}` | Recommended; explicit about source |

Additional providers:

| Provider | Syntax | Purpose |
|----------|--------|---------|
| `env` | `${env:VAR_NAME}` | Environment variable |
| `file` | `${file:/path/to/file}` | File contents |
| `http` | `${http://config-server/config.yaml}` | Remote HTTP config |
| `s3` | `${s3://bucket/path}` | AWS S3 (with ADOT distribution) |

Default values (v0.100+):
```yaml
exporters:
  otlp:
    endpoint: "${env:OTEL_ENDPOINT:-localhost:4317}"
```

**Important**: Environment variable expansion happens **at startup only**. Changes require a Collector restart.

### 3.3 Configuration Sources and Providers

```bash
# File (default)
otelcol --config=/etc/otel/config.yaml

# Multiple files (merged in order)
otelcol --config=file:/etc/otel/base.yaml --config=file:/etc/otel/overrides.yaml

# HTTP source
otelcol --config=http://config-server:8080/collector-config.yaml

# Environment variable containing YAML
otelcol --config=env:OTEL_CONFIG
```

### 3.4 Configuration Validation

```bash
# Validate configuration without starting
otelcol validate --config=config.yaml
```

---

## 4. Performance and Tuning

### 4.1 Benchmarks and Throughput Numbers

| Metric | Throughput | Resources | Notes |
|--------|-----------|-----------|-------|
| Traces (simple pipeline) | ~20,000 spans/sec | 2 CPU, 2 GiB RAM | OTLP in, batch, OTLP out |
| Traces (with tail sampling) | ~10,000 spans/sec | 2 CPU, 4 GiB RAM | Memory for trace assembly |
| Metrics (simple pipeline) | ~50,000 data points/sec | 1 CPU, 1 GiB RAM | OTLP in, batch, OTLP out |
| Logs (simple pipeline) | ~30,000 log records/sec | 1 CPU, 1 GiB RAM | OTLP in, batch, OTLP out |

**Resource estimation formulas:**
- CPU: ~1 core per 10,000 spans/sec with standard pipeline
- Memory: ~1 GiB per 10,000 spans/sec baseline, plus:
  - Tail sampling: +2-4 GiB for 100K concurrent traces
  - Large batch sizes: +proportional to `send_batch_max_size * avg_span_size`
  - Queue depth: +proportional to `queue_size * send_batch_size * avg_span_size`

**Right-sizing for Kubernetes:**

| Throughput | CPU Request | CPU Limit | Memory Request | Memory Limit | GOMEMLIMIT |
|-----------|------------|-----------|----------------|-------------|------------|
| 5K spans/sec | 500m | 1000m | 512Mi | 1Gi | 800MiB |
| 20K spans/sec | 2000m | 4000m | 2Gi | 2.5Gi | 1600MiB |
| 50K spans/sec | 4000m | 8000m | 4Gi | 5Gi | 3200MiB |

**Always leave 20% headroom** between memory requests and limits for Go runtime overhead.

### 4.2 Batch Processor Tuning

The batch processor evaluates three conditions and flushes whichever triggers first:
1. Batch size reaches `send_batch_size`
2. Timer reaches `timeout`
3. Batch size reaches `send_batch_max_size` (hard cap)

| Setting | Low Latency | High Throughput | Balanced |
|---------|------------|----------------|----------|
| `send_batch_size` | 256 | 8192-16384 | 4096-8192 |
| `send_batch_max_size` | 512 | 0 (unlimited) | 16384 |
| `timeout` | 200ms | 10s | 5s |

### 4.3 Queue and Retry Settings

```yaml
exporters:
  otlp/backend:
    endpoint: backend:4317
    sending_queue:
      enabled: true
      num_consumers: 10        # Parallel workers consuming from the queue
      queue_size: 5000         # Max batches in queue (not items)
      storage: file_storage    # Optional: persistent queue
    retry_on_failure:
      enabled: true
      initial_interval: 5s    # First retry delay
      max_interval: 30s       # Cap on exponential backoff
      max_elapsed_time: 300s  # Give up after 5 minutes
    timeout: 30s               # Per-request timeout
```

**Queue sizing math:**
```
Total buffered items = queue_size * send_batch_size
Memory usage ≈ queue_size * send_batch_size * avg_item_size

Example: 1000 * 4096 * 500B ≈ 2 GB
```

**Monitoring queue health:**
- `otelcol_exporter_queue_capacity` -- total queue capacity
- `otelcol_exporter_queue_size` -- current queue depth
- Alert when `queue_size / queue_capacity > 0.7` for more than 5 minutes.

### 4.4 gRPC vs HTTP Performance

| Aspect | OTLP/gRPC | OTLP/HTTP |
|--------|-----------|-----------|
| Protocol | HTTP/2 with Protobuf | HTTP/1.1 or HTTP/2 with Protobuf or JSON |
| Multiplexing | Native (HTTP/2 streams) | Only with HTTP/2 |
| Performance | Slightly better at high throughput | Near-identical with binary Protobuf |
| Compatibility | Requires HTTP/2; blocked by some proxies | Works everywhere; passes through any HTTP proxy |
| Default ports | 4317 (receiver) | 4318 (receiver) |

**Recommendation**: Use gRPC for collector-to-collector and collector-to-backend. Use HTTP for SDK-to-collector when clients traverse load balancers or firewalls.

### 4.5 Compression

| Algorithm | Compression Ratio | CPU Cost | Notes |
|-----------|------------------|----------|-------|
| `none` | 1:1 | None | Use only on localhost communication |
| `gzip` | 5-10x | Moderate | Required by OTLP spec; safe default |
| `zstd` | 5-10x | Low | Higher throughput than gzip; preferred when supported |
| `snappy` | 3-5x | Very low | Fastest compression; lower ratios |

```yaml
exporters:
  otlp:
    endpoint: backend:4317
    compression: zstd          # gzip, zstd, snappy, none
```

**OTel Arrow Protocol** (advanced): Uses Apache Arrow columnar format for an additional 2-7x bandwidth reduction over standard OTLP/gRPC with zstd, particularly effective for metrics.

### 4.6 Connection Pooling and Keep-Alive

```yaml
# gRPC Receiver Keep-Alive
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        max_recv_msg_size_mib: 4
        max_concurrent_streams: 200
        keepalive:
          server_parameters:
            max_connection_idle: 11s
            max_connection_age: 30s
            max_connection_age_grace: 5s
          enforcement_policy:
            min_time: 10s
            permit_without_stream: true

# HTTP Exporter Connection Settings
exporters:
  otlphttp:
    endpoint: https://backend:4318
    max_idle_conns: 100
    max_idle_conns_per_host: 10
    max_conns_per_host: 50
    idle_conn_timeout: 90s
```

---

## 5. Receivers

### 5.1 OTLP Receiver (gRPC + HTTP)

The primary ingestion endpoint for OpenTelemetry-native instrumentation.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        max_recv_msg_size_mib: 16
        keepalive:
          server_parameters:
            max_connection_age: 300s
            max_connection_age_grace: 60s
            time: 30s
            timeout: 10s
          enforcement_policy:
            min_time: 10s
            permit_without_stream: true
        tls:
          cert_file: /certs/server.crt
          key_file: /certs/server.key
          client_ca_file: /certs/ca.crt    # enables mTLS
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins: ["https://app.example.com"]
          allowed_headers: ["*"]
          max_age: 7200
        tls:
          cert_file: /certs/server.crt
          key_file: /certs/server.key
```

### 5.2 Prometheus Receiver

Scrapes metrics from Prometheus-compatible `/metrics` endpoints with full SD support.

```yaml
receivers:
  prometheus:
    config:
      global:
        scrape_interval: 30s
        scrape_timeout: 10s
      scrape_configs:
        # Static target scraping
        - job_name: my-service
          scrape_interval: 15s
          static_configs:
            - targets: ["service-a:8080", "service-b:8080"]

        # Kubernetes pod service discovery
        - job_name: kubernetes-pods
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              target_label: __address__
              regex: (.+)
              replacement: ${1}:${2}
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
```

### 5.3 Filelog Receiver

Tails log files from disk and parses them into structured OTel log records.

```yaml
receivers:
  filelog:
    include: ["/var/log/app/*.log", "/var/log/syslog"]
    exclude: ["/var/log/app/*.gz"]
    start_at: end                    # 'end' avoids re-ingesting history
    poll_interval: 500ms
    max_concurrent_files: 64
    fingerprint_size: 1kb

    # Multiline: join stack traces
    multiline:
      line_start_pattern: '^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}'

    operators:
      - type: regex_parser
        id: parse_timestamp
        regex: '^(?P<timestamp>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}[.\d]*[Z]?[\+\-\d:]*)\s+(?P<severity>\w+)\s+(?P<message>.*)'
        timestamp:
          parse_from: attributes.timestamp
          layout_type: gotime
          layout: '2006-01-02T15:04:05.000Z'
        severity:
          parse_from: attributes.severity

      - type: json_parser
        id: parse_json
        if: 'body matches "^\\s*\\{"'
        timestamp:
          parse_from: attributes.timestamp
          layout: '%Y-%m-%dT%H:%M:%S.%fZ'
        severity:
          parse_from: attributes.level
          mapping:
            error: [err, error, ERROR, ERR]
            warn: [warn, warning, WARN, WARNING]
            info: [info, INFO]
            debug: [debug, DEBUG, trace, TRACE]

      - type: move
        from: attributes["log.file.name"]
        to: resource["log.file.name"]

    # Checkpoint storage for restart resilience
    storage: file_storage
```

**Available operator types:** regex_parser, json_parser, severity_parser, time_parser, move, add, remove, copy, flatten, key_value_parser, csv_parser, xml_parser, uri_parser, scope_name, trace_parser, router.

### 5.4 Hostmetrics Receiver

Collects system-level metrics: CPU, memory, disk, filesystem, network, per-process.

```yaml
receivers:
  hostmetrics:
    collection_interval: 60s
    # root_path: /hostfs    # Mount host filesystem for containers
    scrapers:
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
          system.cpu.load_average.1m:
            enabled: true
          system.cpu.load_average.5m:
            enabled: true
          system.cpu.load_average.15m:
            enabled: true
      memory:
        metrics:
          system.memory.utilization:
            enabled: true
      disk:
        metrics:
          system.disk.io:
            enabled: true
          system.disk.operations:
            enabled: true
      filesystem:
        metrics:
          system.filesystem.utilization:
            enabled: true
        exclude_mount_points:
          mount_points: ["/proc", "/sys", "/dev", "/run"]
          match_type: strict
        exclude_fs_types:
          fs_types: ["proc", "sysfs", "devfs", "tmpfs"]
          match_type: strict
      network:
        metrics:
          system.network.io:
            enabled: true
          system.network.connections:
            enabled: true
          system.network.errors:
            enabled: true
      paging: {}
      processes: {}
      process:
        include:
          match_type: regexp
          names: [".*"]
        mute_process_name_error: true
        mute_process_exe_error: true
        mute_process_io_error: true
```

### 5.5 Kubernetes Receivers

**k8s_cluster Receiver** -- Cluster-level metrics from the API server (single-replica Deployment):
```yaml
receivers:
  k8s_cluster:
    collection_interval: 30s
    auth_type: serviceAccount
    node_conditions_to_report: [Ready, MemoryPressure, DiskPressure, PIDPressure]
    allocatable_types_to_report: [cpu, memory, storage, ephemeral-storage]
```

**k8s_events Receiver** -- Kubernetes events as OTel log records:
```yaml
receivers:
  k8s_events:
    auth_type: serviceAccount
    namespaces: []            # empty = all namespaces
```

**kubeletstats Receiver** -- Node/pod/container resource metrics (DaemonSet):
```yaml
receivers:
  kubeletstats:
    collection_interval: 30s
    auth_type: serviceAccount
    endpoint: https://${K8S_NODE_NAME}:10250
    insecure_skip_verify: true
    metric_groups: [node, pod, container, volume]
    extra_metadata_labels: [container.id, k8s.volume.type]
```

### 5.6 JMX Receiver

Pulls metrics from Java applications via JMX.

```yaml
receivers:
  jmx:
    endpoint: service:jmx:rmi:///jndi/rmi://localhost:9999/jmxrmi
    target_system: jvm       # Built-in: jvm, activemq, cassandra, kafka, tomcat, wildfly
    collection_interval: 60s
    username: jmx_user
    password: jmx_pass
    jar_path: /opt/otel/opentelemetry-jmx-metrics.jar
```

### 5.7 Database Receivers

```yaml
# PostgreSQL
receivers:
  postgresql:
    endpoint: localhost:5432
    username: postgres
    password: ${POSTGRESQL_PASSWORD}
    databases: [mydb, postgres]
    collection_interval: 60s
    tls:
      insecure: false
      ca_file: /certs/ca.crt

# MySQL
  mysql:
    endpoint: localhost:3306
    username: otel
    password: ${MYSQL_PASSWORD}
    collection_interval: 60s

# MongoDB
  mongodb:
    hosts:
      - endpoint: localhost:27017
    username: otel
    password: ${MONGODB_PASSWORD}
    collection_interval: 60s

# Redis
  redis:
    endpoint: localhost:6379
    password: ${REDIS_PASSWORD}
    collection_interval: 60s
```

### 5.8 Cloud Receivers

**AWS CloudWatch:**
```yaml
receivers:
  awscloudwatch:
    region: us-east-1
    poll_interval: 5m
    metrics:
      named:
        - namespace: AWS/EC2
          period: 300s
          metrics:
            - metric_name: CPUUtilization
              statistics: [Average, Maximum]
            - metric_name: NetworkIn
              statistics: [Sum]
        - namespace: AWS/RDS
          period: 300s
          metrics:
            - metric_name: CPUUtilization
              statistics: [Average]
            - metric_name: DatabaseConnections
              statistics: [Sum]
```

**Azure Monitor:**
```yaml
receivers:
  azuremonitor:
    tenant_id: ${AZURE_TENANT_ID}
    client_id: ${AZURE_CLIENT_ID}
    client_secret: ${AZURE_CLIENT_SECRET}
    subscription_id: ${AZURE_SUBSCRIPTION_ID}
    collection_interval: 60s
    resource_groups:
      - name: my-resource-group
        resources:
          - resource_type: Microsoft.Compute/virtualMachines
            metrics:
              - name: Percentage CPU
              - name: Available Memory Bytes
```

### 5.9 Kafka Receiver

```yaml
receivers:
  kafka:
    brokers: ["kafka-1:9092", "kafka-2:9092"]
    topic: otel-traces
    encoding: otlp_proto
    group_id: otel-collector
    initial_offset: latest
    auth:
      sasl:
        mechanism: PLAIN
        username: ${KAFKA_USER}
        password: ${KAFKA_PASS}
      tls:
        insecure: false
        ca_file: /certs/kafka-ca.crt
```

---

## 6. Processors

### 6.1 Batch Processor

The most impactful single knob for throughput.

```yaml
processors:
  batch:
    send_batch_size: 8192      # Target batch size (items)
    send_batch_max_size: 0     # 0 = unlimited (no hard cap)
    timeout: 5s                # Max time before flushing
```

### 6.2 Memory Limiter Processor

**Must be first processor in every pipeline.**

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 1800
    spike_limit_mib: 500
```

### 6.3 Attributes Processor

Manipulate span, metric, and log attributes.

```yaml
processors:
  attributes/example:
    actions:
      - key: db.statement
        action: delete
      - key: http.request.header.authorization
        action: delete
      - key: user.email
        action: hash
      - key: environment
        value: production
        action: upsert
      - key: http.url
        from_attribute: http.target
        action: insert
      - key: old.name
        action: delete
        # Rename pattern: insert new from old, then delete old
```

**Action types:** insert, update, upsert, delete, hash, extract (regex), convert (type).

### 6.4 Resource Processor

Add, update, or delete resource-level attributes.

```yaml
processors:
  resource:
    attributes:
      - key: environment
        value: "${env:DEPLOY_ENV}"
        action: upsert
      - key: cluster
        value: "${env:CLUSTER_NAME}"
        action: upsert
      - key: deployment.version
        value: "v2.3.1"
        action: upsert
```

### 6.5 Filter Processor

Drop telemetry based on OTTL conditions.

```yaml
processors:
  filter/traces:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
        - 'attributes["http.route"] == "/readyz"'
        - 'attributes["http.method"] == "OPTIONS"'
        - 'IsMatch(attributes["http.user_agent"], ".*(bot|crawler|spider).*")'

  filter/logs:
    error_mode: ignore
    logs:
      log_record:
        - 'severity_number < 9'              # Drop DEBUG and below
        - 'IsMatch(body, "Health check.*")'

  filter/metrics:
    error_mode: ignore
    metrics:
      metric:
        - 'name == "http.server.duration" and resource.attributes["service.name"] == "test-svc"'
```

### 6.6 Transform Processor

Modify/enrich data using OTTL statements while keeping it in the pipeline.

```yaml
processors:
  transform/enrich:
    error_mode: ignore
    trace_statements:
      - context: span
        statements:
          - set(attributes["deployment.environment"], "production") where resource.attributes["k8s.namespace.name"] == "prod"
          - set(status.code, 2) where attributes["http.status_code"] >= 500
          - set(status.message, "Server Error") where attributes["http.status_code"] >= 500

    log_statements:
      - context: log
        statements:
          # Redact email addresses
          - replace_pattern(body, "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", "[EMAIL REDACTED]")
          - set(severity_text, "ERROR") where severity_number >= 17

    metric_statements:
      - context: datapoint
        statements:
          - set(attributes["region"], "us-east-1") where resource.attributes["cloud.region"] == "us-east-1"
```

### 6.7 Tail Sampling Processor

Makes sampling decisions after collecting all spans for a trace.

```yaml
processors:
  tail_sampling:
    decision_wait: 10s                 # Wait time for all spans to arrive
    num_traces: 100000                 # Max concurrent traces in memory
    expected_new_traces_per_sec: 10000
    policies:
      # Always keep errors
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]

      # Always keep slow traces (>1s)
      - name: slow-traces
        type: latency
        latency:
          threshold_ms: 1000

      # Keep specific service traces
      - name: critical-services
        type: string_attribute
        string_attribute:
          key: service.name
          values: [payment-service, auth-service]

      # Probabilistic fallback for everything else
      - name: probabilistic
        type: probabilistic
        probabilistic:
          sampling_percentage: 10

      # Composite: combine policies with rates
      - name: composite-policy
        type: composite
        composite:
          max_total_spans_per_second: 5000
          policy_order: [errors, slow-traces, critical-services, probabilistic]
          rate_allocation:
            - policy: errors
              percent: 100
            - policy: slow-traces
              percent: 50
            - policy: critical-services
              percent: 100
            - policy: probabilistic
              percent: 10
```

**Important**: Requires consistent hashing via the `loadbalancing` exporter so all spans for a trace land on the same gateway.

### 6.8 Probabilistic Sampler Processor

Head-based sampling -- makes instant per-span/per-log decisions.

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 25       # Keep 25% of traces
    hash_seed: 22573              # Consistent hash seed
```

### 6.9 K8s Attributes Processor

Enriches telemetry with Kubernetes metadata by querying the K8s API.

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount
    passthrough: false
    filter:
      node_from_env_var: K8S_NODE_NAME
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.deployment.name
        - k8s.node.name
        - k8s.container.name
        - k8s.replicaset.name
      labels:
        - tag_name: app
          key: app.kubernetes.io/name
        - tag_name: version
          key: app.kubernetes.io/version
      annotations:
        - tag_name: team
          key: team
    pod_association:
      - sources:
          - from: resource_attribute
            name: k8s.pod.ip
      - sources:
          - from: connection
```

### 6.10 Resource Detection Processor

Auto-detects cloud/host/container metadata.

```yaml
processors:
  resourcedetection:
    detectors: [env, system, docker, gcp, aws, azure]
    timeout: 5s
    override: false

  # AWS-specific
  resourcedetection/aws:
    detectors: [env, ec2, ecs, eks]
    timeout: 5s

  # GCP-specific
  resourcedetection/gcp:
    detectors: [env, gcp]
    timeout: 5s

  # Azure-specific
  resourcedetection/azure:
    detectors: [env, azure]
    timeout: 5s
```

### 6.11 Metrics Transform Processor

Rename metrics, aggregate, and manipulate metric data.

```yaml
processors:
  metricstransform:
    transforms:
      - include: system.cpu.utilization
        action: update
        new_name: cpu_utilization_percent
        operations:
          - action: aggregate_labels
            label_set: [cpu]
            aggregation_type: mean
      - include: ^system\.disk\.(.*)$
        match_type: regexp
        action: update
        new_name: disk_$1
```

### 6.12 Cumulative to Delta Processor

Converts cumulative metrics to delta temporality.

```yaml
processors:
  cumulativetodelta:
    include:
      match_type: strict
      metrics: []           # empty = convert all cumulative metrics
    max_stale: 5m           # Timeout for tracked metric series
```

Required for backends preferring delta metrics (Datadog, Azure Monitor).

### 6.13 Redaction Processor

Removes or masks sensitive data for GDPR/HIPAA/PCI-DSS compliance.

```yaml
processors:
  redaction:
    allow_all_keys: true
    blocked_values:
      # Credit card numbers
      - "\\b[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{1,4}\\b"
      # SSN (US)
      - "\\b[0-9]{3}-[0-9]{2}-[0-9]{4}\\b"
      # Email addresses
      - "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
      # Bearer tokens
      - "(?i)(bearer\\s+)[a-zA-Z0-9\\-._~+/]+"
      # AWS access key IDs
      - "\\bAKIA[0-9A-Z]{16}\\b"
    summary: debug
```

### 6.14 Recommended Pipeline Processor Order

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp, jaeger, zipkin]
      processors:
        - memory_limiter          # FIRST: protect from OOM
        - resourcedetection/aws   # Enrich with cloud metadata
        - k8sattributes           # Enrich with K8s metadata
        - resource                # Add static resource attributes
        - attributes/example      # Manipulate data attributes
        - filter/traces           # Drop unwanted spans
        - transform/traces        # OTTL transformations
        - redaction               # Remove sensitive data
        - tail_sampling           # Sampling decision
        - batch                   # LAST: batch for export efficiency
      exporters: [otlp/backend, spanmetrics]

    metrics:
      receivers: [otlp, prometheus, hostmetrics]
      processors:
        - memory_limiter
        - resourcedetection/aws
        - k8sattributes
        - resource
        - filter/metrics
        - transform/metrics
        - cumulativetodelta       # If backend needs delta temporality
        - batch
      exporters: [prometheusremotewrite]

    logs:
      receivers: [otlp, filelog, syslog]
      processors:
        - memory_limiter
        - resourcedetection/aws
        - k8sattributes
        - resource
        - transform/logs          # Parse JSON, extract severity
        - filter/logs             # Drop health checks, low severity
        - redaction               # Remove PII
        - batch
      exporters: [loki]
```

**Golden rules:**
1. `memory_limiter` is ALWAYS first
2. Enrichment processors (resourcedetection, k8sattributes, resource) come early
3. Filter and transform processors come in the middle (reduce data before export)
4. Sampling processors come after enrichment but before batch
5. `batch` is ALWAYS last

---

## 7. Exporters

### 7.1 OTLP gRPC Exporter

```yaml
exporters:
  otlp:
    endpoint: tempo.observability.svc:4317
    timeout: 30s
    compression: gzip
    tls:
      cert_file: /certs/client.crt
      key_file: /certs/client.key
      ca_file: /certs/ca.crt
    headers:
      Authorization: "Bearer ${API_TOKEN}"
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 5000
      # storage: file_storage    # Persistent queue
```

### 7.2 OTLP HTTP Exporter

```yaml
exporters:
  otlphttp:
    endpoint: https://otlp.example.com
    compression: gzip
    timeout: 30s
    headers:
      Authorization: "Bearer ${API_TOKEN}"
    tls:
      cert_file: /certs/client.crt
      key_file: /certs/client.key
      ca_file: /certs/ca.crt
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 5000
```

OTLP HTTP auto-appends `/v1/traces`, `/v1/metrics`, `/v1/logs` to the endpoint.

### 7.3 Prometheus Remote Write Exporter

Push metrics to Prometheus-compatible endpoints (Thanos, Cortex, Mimir, Grafana Cloud).

```yaml
exporters:
  prometheusremotewrite:
    endpoint: https://prometheus.example.com/api/v1/write
    timeout: 30s
    headers:
      Authorization: "Bearer ${PROM_TOKEN}"
      X-Scope-OrgID: "tenant-1"    # Multi-tenant (Cortex/Mimir)
    resource_to_telemetry_conversion:
      enabled: true                 # Critical: converts OTel resource attrs to Prometheus labels
    external_labels:
      cluster: prod-us-east-1
      environment: production
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 5000
```

### 7.4 Prometheus Exporter (Pull-Based)

Exposes a `/metrics` endpoint for Prometheus to scrape.

```yaml
exporters:
  prometheus:
    endpoint: 0.0.0.0:8889
    namespace: otel                # Prefix added to all metric names
    const_labels:
      environment: production
    send_timestamps: true
    metric_expiration: 5m
    resource_to_telemetry_conversion:
      enabled: true
    enable_open_metrics: true
```

### 7.5 Loki Exporter

```yaml
exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      attributes:
        service.name: ""
        k8s.namespace.name: ""
      resource:
        service.name: "service_name"
        k8s.namespace.name: "namespace"
        k8s.pod.name: "pod"
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
```

Keep Loki label cardinality low -- high-cardinality attributes should NOT be promoted to labels.

### 7.6 Debug Exporter

```yaml
exporters:
  debug:
    verbosity: detailed       # basic, normal, detailed
    sampling_initial: 5
    sampling_thereafter: 200
```

Never use in production at high verbosity.

### 7.7 File Exporter

```yaml
exporters:
  file:
    path: /var/otel/export/otel-export.json
    rotation:
      max_megabytes: 100
      max_backups: 10
      max_days: 30
    format: json
    flush_interval: 5s
```

### 7.8 Kafka Exporter

```yaml
exporters:
  kafka:
    brokers: ["kafka-1:9092", "kafka-2:9092"]
    topic: otel-traces
    encoding: otlp_proto
    producer:
      max_message_bytes: 1048576
      required_acks: -1          # All ISRs must acknowledge
      compression: gzip
    auth:
      sasl:
        mechanism: PLAIN
        username: ${KAFKA_USER}
        password: ${KAFKA_PASS}
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
```

Use separate topics per signal type (`otel-traces`, `otel-metrics`, `otel-logs`).

### 7.9 Load Balancing Exporter

```yaml
exporters:
  loadbalancing:
    routing_key: traceID         # traceID or service
    protocol:
      otlp:
        timeout: 30s
        compression: gzip
    resolver:
      dns:
        hostname: otel-collector-headless.observability.svc.cluster.local
        port: 4317
      # Alternative: static list
      # static:
      #   hostnames: [collector-1:4317, collector-2:4317]
```

### 7.10 Cloud Exporters

**AWS X-Ray:**
```yaml
exporters:
  awsxray:
    region: us-east-1
    indexed_attributes:
      - otel.resource.service.name
      - otel.resource.deployment.environment
```

**AWS CloudWatch Logs:**
```yaml
exporters:
  awscloudwatchlogs:
    log_group_name: /otel/my-service
    log_stream_name: collector-01
    region: us-east-1
```

**Google Cloud:**
```yaml
exporters:
  googlecloud:
    project: my-gcp-project
    metric:
      prefix: custom.googleapis.com/opentelemetry
```

**Azure Monitor:**
```yaml
exporters:
  azuremonitor:
    connection_string: ${AZURE_MONITOR_CONNECTION_STRING}
    max_batch_size: 1024
    max_batch_interval: 10s
```

### 7.11 Datadog Exporter

```yaml
exporters:
  datadog:
    api:
      key: ${DD_API_KEY}
      site: datadoghq.com
    metrics:
      resource_attributes_as_tags: true
      histograms:
        mode: distributions
    traces:
      trace_buffer: 500
```

### 7.12 Splunk HEC Exporter

```yaml
exporters:
  splunk_hec:
    token: ${SPLUNK_HEC_TOKEN}
    endpoint: https://splunk-hec.example.com:8088
    source: otel
    sourcetype: otel
    index: main
    max_connections: 100
```

### 7.13 Elastic APM (via OTLP)

Elastic natively supports OTLP ingestion -- no special exporter needed:

```yaml
exporters:
  otlp/elastic:
    endpoint: https://apm-server.example.com:8200
    headers:
      Authorization: "Bearer ${ELASTIC_APM_SECRET_TOKEN}"
    compression: gzip
```

---

## 8. Connectors

### 8.1 Span Metrics Connector

Generates R.E.D. (Rate, Error, Duration) metrics from trace data.

```yaml
connectors:
  spanmetrics:
    namespace: span.metrics
    histogram:
      explicit:
        buckets: [2ms, 4ms, 6ms, 8ms, 10ms, 50ms, 100ms, 200ms, 400ms, 800ms, 1s, 5s, 10s, 30s, 60s]
    dimensions:
      - name: service.name
      - name: span.kind
      - name: http.method
      - name: http.status_code
    dimensions_cache_size: 1000
    aggregation_temporality: "AGGREGATION_TEMPORALITY_CUMULATIVE"
    metrics_flush_interval: 15s
```

**Pipeline wiring:**
```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [spanmetrics, otlp/traces]     # spanmetrics = exporter
    metrics/spanmetrics:
      receivers: [spanmetrics]                    # spanmetrics = receiver
      processors: [batch]
      exporters: [prometheusremotewrite]
```

**Metrics produced:** `span.metrics.calls` (counter), `span.metrics.duration` (histogram).

### 8.2 Service Graph Connector

Computes service dependency graph metrics.

```yaml
connectors:
  servicegraph:
    latency_histogram_buckets: [2ms, 4ms, 6ms, 8ms, 10ms, 50ms, 100ms, 200ms, 400ms, 800ms, 1s, 5s, 10s]
    dimensions: [service.name, http.method, http.status_code]
    store:
      ttl: 2s
      max_items: 1000
```

**Metrics produced:** `traces_service_graph_request_total`, `traces_service_graph_request_failed_total`, `traces_service_graph_request_server_seconds`, `traces_service_graph_request_client_seconds`.

### 8.3 Count Connector

Counts telemetry items and emits as metrics.

```yaml
connectors:
  count:
    spans:
      span.count:
        description: "Total count of spans received"
      error.span.count:
        description: "Count of error spans"
        conditions:
          - 'status.code == STATUS_CODE_ERROR'
        attributes:
          - key: service.name
    logs:
      log.record.count:
        description: "Count of log records by severity"
        conditions:
          - 'severity_number >= SEVERITY_NUMBER_WARN'
        attributes:
          - key: severity_text
```

### 8.4 Routing Connector

Routes data to different pipelines based on OTTL conditions.

```yaml
connectors:
  routing:
    default_pipelines: [traces/default]
    error_mode: ignore
    table:
      - condition: 'resource.attributes["deployment.environment"] == "production"'
        pipelines: [traces/production]
      - condition: 'resource.attributes["deployment.environment"] == "staging"'
        pipelines: [traces/staging]
      - condition: 'resource.attributes["service.name"] == "payment-service"'
        pipelines: [traces/high-priority]
```

**Pipeline wiring:**
```yaml
service:
  pipelines:
    traces/intake:
      receivers: [otlp]
      exporters: [routing]
    traces/production:
      receivers: [routing]
      processors: [tail_sampling, batch]
      exporters: [otlp/production]
    traces/staging:
      receivers: [routing]
      processors: [probabilistic_sampler, batch]
      exporters: [otlp/staging]
    traces/high-priority:
      receivers: [routing]
      processors: [batch]
      exporters: [otlp/production]
```

### 8.5 Forward Connector

Bridges two pipelines of the same signal type. Zero configuration.

```yaml
connectors:
  forward: {}
```

**Merging pipelines:**
```yaml
service:
  pipelines:
    logs/structured:
      receivers: [otlp]
      processors: [transform/json-parse]
      exporters: [forward]
    logs/syslog:
      receivers: [syslog]
      processors: [transform/syslog-parse]
      exporters: [forward]
    logs:
      receivers: [forward]
      processors: [filter/logs, batch]
      exporters: [loki]
```

---

## 9. Extensions

### 9.1 Health Check Extension

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
    path: "/health"
    check_collector_pipeline:
      enabled: true
      exporter_failure_threshold: 5
```

### 9.2 pprof Extension

```yaml
extensions:
  pprof:
    endpoint: localhost:1777
    block_profile_fraction: 3
    mutex_profile_fraction: 5
```

Profiling commands:
```bash
go tool pprof http://localhost:1777/debug/pprof/profile?seconds=30   # CPU
go tool pprof http://localhost:1777/debug/pprof/heap                  # Memory
go tool pprof http://localhost:1777/debug/pprof/goroutine             # Goroutines
```

### 9.3 zpages Extension

```yaml
extensions:
  zpages:
    endpoint: localhost:55679
```

Access `http://localhost:55679/debug/tracez` for live span samples and pipeline status.

### 9.4 File Storage Extension

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol/storage
    timeout: 10s
    compaction:
      directory: /var/lib/otelcol/storage
      on_start: true
      on_rebound: true
```

### 9.5 Authentication Extensions

```yaml
extensions:
  bearertokenauth:
    token: "${env:OTEL_AUTH_TOKEN}"

  basicauth/server:
    htpasswd:
      inline: |
        ${env:BASIC_AUTH_USERNAME}:${env:BASIC_AUTH_PASSWORD}

  basicauth/client:
    client_auth:
      username: "${env:EXPORT_USERNAME}"
      password: "${env:EXPORT_PASSWORD}"

  oauth2client:
    client_id: "${env:OAUTH_CLIENT_ID}"
    client_secret: "${env:OAUTH_CLIENT_SECRET}"
    token_url: https://auth.example.com/oauth2/token
    scopes: ["api.telemetry"]

  oidc:
    issuer_url: https://auth.example.com/realms/telemetry
    audience: otel-collector
```

---

## 10. OTTL (OpenTelemetry Transformation Language)

### 10.1 Syntax and Grammar

OTTL is a domain-specific language for transforming, filtering, and manipulating telemetry within the Collector.

**Statement structure:**
```
<editor_function>(<arguments>) where <boolean_expression>
```

**Contexts:**

| Context | Signal | Access Scope |
|---------|--------|-------------|
| `resource` | All | Resource-level attributes |
| `scope` | All | Instrumentation scope attributes |
| `span` | Traces | Span name, status, kind, attributes, events |
| `spanevent` | Traces | Span event attributes |
| `metric` | Metrics | Metric name, type, description, unit |
| `datapoint` | Metrics | Datapoint value, attributes, timestamps |
| `log` | Logs | Log body, severity, attributes |

### 10.2 Editor Functions

| Function | Description | Example |
|----------|-------------|---------|
| `set` | Set a field value | `set(attributes["env"], "prod")` |
| `delete_key` | Remove a map key | `delete_key(attributes, "secret")` |
| `delete_matching_keys` | Remove keys by pattern | `delete_matching_keys(attributes, "internal\\..*")` |
| `truncate_all` | Truncate all strings | `truncate_all(attributes, 256)` |
| `replace_match` | Replace full string by glob | `replace_match(attributes["url"], "/health*", "/redacted")` |
| `replace_pattern` | Replace by regex | `replace_pattern(attributes["email"], "^(.+)@(.+)$", "****@\\2")` |
| `merge_maps` | Combine maps | `merge_maps(attributes, body["labels"], "upsert")` |
| `keep_keys` | Keep only specified keys | `keep_keys(attributes, ["http.method", "http.status_code"])` |
| `flatten` | Flatten nested maps | `flatten(body, depth=2)` |
| `limit` | Limit map entries | `limit(attributes, 50)` |

### 10.3 Converter Functions

| Converter | Description | Example |
|-----------|-------------|---------|
| `Concat` | Concatenate fields | `Concat([attributes["first"], attributes["last"]], " ")` |
| `SHA256` | SHA-256 hash | `SHA256(attributes["email"])` |
| `IsMatch` | Regex match test | `IsMatch(attributes["url"], "/api/v[0-9]+")` |
| `Int` | Convert to int64 | `Int(attributes["status_code"])` |
| `ParseJSON` | Parse JSON to map | `ParseJSON(body)` |
| `Len` | Return length | `Len(attributes)` |
| `Substring` | Extract substring | `Substring(attributes["id"], 0, 8)` |
| `Time` | Parse time string | `Time(attributes["ts"], "%Y-%m-%dT%H:%M:%S")` |

### 10.4 OTTL Cookbook: Practical Examples

**1. Redact PII from Log Bodies:**
```yaml
processors:
  transform/redact_pii:
    log_statements:
      - context: log
        statements:
          - replace_pattern(body, "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", "[EMAIL]")
          - replace_pattern(body, "\\b\\d{3}-\\d{2}-\\d{4}\\b", "[SSN]")
          - replace_pattern(body, "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b", "[CC]")
          - replace_pattern(body, "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", "[IP]")
```

**2. Enrich Spans with Environment Classification:**
```yaml
processors:
  transform/classify:
    trace_statements:
      - context: span
        statements:
          - set(attributes["env.tier"], "critical") where IsMatch(resource.attributes["service.name"], "(payment|auth|order).*")
          - set(attributes["env.tier"], "standard") where attributes["env.tier"] == nil
          - set(attributes["is_slow"], true) where end_time_unix_nano - start_time_unix_nano > 5000000000
```

**3. Filter Health Check Noise:**
```yaml
processors:
  filter/noise:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
        - 'attributes["http.route"] == "/readyz"'
        - 'attributes["http.route"] == "/livez"'
        - 'attributes["http.route"] == "/metrics"'
        - 'attributes["http.method"] == "OPTIONS"'
        - 'IsMatch(attributes["http.user_agent"], ".*(bot|crawler|spider|probe).*")'
```

**4. Hash Sensitive Attributes:**
```yaml
processors:
  transform/hash:
    trace_statements:
      - context: span
        statements:
          - set(attributes["user.id"], SHA256(attributes["user.id"])) where attributes["user.id"] != nil
          - set(attributes["user.email"], SHA256(attributes["user.email"])) where attributes["user.email"] != nil
```

**5. Extract Structured Data from Log Body:**
```yaml
processors:
  transform/parse:
    log_statements:
      - context: log
        statements:
          - merge_maps(attributes, ParseJSON(body), "upsert") where IsMatch(body, "^\\{")
          - set(severity_text, attributes["level"]) where attributes["level"] != nil
```

**6. Truncate Large Attributes for Cost Control:**
```yaml
processors:
  transform/truncate:
    trace_statements:
      - context: span
        statements:
          - truncate_all(attributes, 1024)
          - limit(attributes, 50)
    log_statements:
      - context: log
        statements:
          - truncate_all(attributes, 4096)
          - set(body, Substring(body, 0, 8192)) where Len(body) > 8192
```

**7. Strip Kubernetes Cardinality Bombs:**
```yaml
processors:
  transform/cardinality:
    metric_statements:
      - context: datapoint
        statements:
          - delete_key(attributes, "k8s.pod.uid")
          - delete_key(attributes, "container.id")
          - delete_matching_keys(attributes, ".*\\.ip$")
```

**8. Set Span Status from HTTP Status Code:**
```yaml
processors:
  transform/status:
    trace_statements:
      - context: span
        statements:
          - set(status.code, 2) where attributes["http.status_code"] >= 500
          - set(status.message, "Server Error") where attributes["http.status_code"] >= 500
          - set(status.code, 1) where attributes["http.status_code"] >= 200 and attributes["http.status_code"] < 400
```

---

## 11. Security

### 11.1 TLS Configuration

**Server-side TLS (Receivers):**
```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /certs/server.crt
          key_file: /certs/server.key
```

**Client-side TLS (Exporters):**
```yaml
exporters:
  otlp:
    endpoint: backend:4317
    tls:
      ca_file: /certs/ca.crt
      insecure: false
```

**Mutual TLS (mTLS):**
```yaml
# Server side - verify client certificates
receivers:
  otlp:
    protocols:
      grpc:
        tls:
          cert_file: /certs/server.crt
          key_file: /certs/server.key
          client_ca_file: /certs/client-ca.crt

# Client side - present client certificate
exporters:
  otlp:
    endpoint: backend:4317
    tls:
      ca_file: /certs/ca.crt
      cert_file: /certs/client.crt
      key_file: /certs/client.key
```

### 11.2 Authentication Extensions

**Bearer Token:**
```yaml
extensions:
  bearertokenauth:
    token: "${env:OTEL_AUTH_TOKEN}"

receivers:
  otlp:
    protocols:
      grpc:
        auth:
          authenticator: bearertokenauth
```

**OAuth2 Client Credentials:**
```yaml
extensions:
  oauth2client:
    client_id: "${env:OAUTH_CLIENT_ID}"
    client_secret: "${env:OAUTH_CLIENT_SECRET}"
    token_url: https://auth.example.com/oauth2/token
    scopes: ["api.telemetry"]

exporters:
  otlphttp:
    endpoint: https://backend.example.com
    auth:
      authenticator: oauth2client
```

### 11.3 Secret Management

**Environment Variables (simplest):**
```yaml
exporters:
  otlp:
    endpoint: "${env:OTEL_EXPORTER_ENDPOINT}"
    headers:
      Authorization: "Bearer ${env:API_TOKEN}"
```

**Kubernetes Secrets:**
```yaml
spec:
  template:
    spec:
      containers:
        - name: otel-collector
          env:
            - name: API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: otel-secrets
                  key: api-token
          volumeMounts:
            - name: tls-certs
              mountPath: /certs
              readOnly: true
      volumes:
        - name: tls-certs
          secret:
            secretName: otel-tls-certs
```

### 11.4 Network Security: Port Exposure

| Port | Protocol | Component | Exposure |
|------|----------|-----------|----------|
| 4317 | gRPC | OTLP Receiver | Internal only |
| 4318 | HTTP | OTLP Receiver | Internal only |
| 8888 | HTTP | Internal metrics | Monitoring only |
| 8889 | HTTP | Prometheus exporter | Monitoring only |
| 13133 | HTTP | Health check | Internal + load balancer |
| 55679 | HTTP | zPages | Debug only, never expose externally |
| 1777 | HTTP | pprof | Debug only, never expose externally |

### 11.5 PII Redaction (Defense in Depth)

```yaml
processors:
  # Layer 1: Transform to redact patterns in values
  transform/redact:
    log_statements:
      - context: log
        statements:
          - replace_pattern(body, "password=\\S+", "password=[REDACTED]")
          - replace_pattern(body, "Bearer\\s+\\S+", "Bearer [REDACTED]")

  # Layer 2: Remove sensitive attribute keys
  attributes/strip:
    actions:
      - key: db.connection_string
        action: delete
      - key: http.request.header.cookie
        action: delete

  # Layer 3: Allowlist for strictest compliance
  redaction/final:
    allow_all_keys: false
    allowed_keys:
      - http.method
      - http.status_code
      - service.name
```

---

## 12. Self-Monitoring and Observability

### 12.1 Self-Telemetry Configuration

```yaml
service:
  telemetry:
    logs:
      level: info                  # debug, info, warn, error
      encoding: json
    metrics:
      level: detailed              # none, basic, normal, detailed
      address: 0.0.0.0:8888
```

### 12.2 Key Internal Metrics

**Receiver metrics:**
- `otelcol_receiver_accepted_spans` -- Spans successfully received
- `otelcol_receiver_accepted_metric_points` -- Metric points received
- `otelcol_receiver_accepted_log_records` -- Log records received
- `otelcol_receiver_refused_spans` -- Spans refused (backpressure)

**Exporter metrics:**
- `otelcol_exporter_sent_spans` -- Spans successfully exported
- `otelcol_exporter_send_failed_spans` -- Spans that failed to export
- `otelcol_exporter_queue_size` -- Current queue depth
- `otelcol_exporter_queue_capacity` -- Total queue capacity

**Processor metrics:**
- `otelcol_processor_dropped_spans` -- Spans dropped by filter processor
- `otelcol_processor_batch_batch_send_size` -- Actual batch sizes sent

**Runtime metrics:**
- `process_runtime_total_alloc_bytes` -- Total memory allocated
- `process_cpu_seconds_total` -- Total CPU time consumed

### 12.3 Data Flow Verification

```bash
# Step 1: Verify receivers are accepting data
curl -s http://localhost:8888/metrics | grep otelcol_receiver_accepted

# Step 2: Verify processors are not dropping everything
curl -s http://localhost:8888/metrics | grep otelcol_processor_dropped

# Step 3: Verify exporters are sending data
curl -s http://localhost:8888/metrics | grep otelcol_exporter_sent

# Step 4: Check queue health
curl -s http://localhost:8888/metrics | grep otelcol_exporter_queue

# Step 5: Synthetic testing with telemetrygen
telemetrygen traces --otlp-endpoint localhost:4317 --otlp-insecure --traces 100
telemetrygen metrics --otlp-endpoint localhost:4317 --otlp-insecure --metrics 100
telemetrygen logs --otlp-endpoint localhost:4317 --otlp-insecure --logs 100
```

---

## 13. Kubernetes Operations

### 13.1 RBAC Requirements

**k8sattributes processor:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
  - apiGroups: [""]
    resources: ["pods", "namespaces", "nodes"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["apps"]
    resources: ["replicasets"]
    verbs: ["get", "watch", "list"]
  - apiGroups: [""]
    resources: ["nodes/proxy"]
    verbs: ["get"]
```

**k8s_cluster receiver (additional permissions):**
```yaml
rules:
  - apiGroups: [""]
    resources: ["events", "namespaces", "nodes", "pods", "services", "endpoints", "replicationcontrollers", "resourcequotas"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "watch", "list"]
```

**Helm chart presets for automatic RBAC:**
```yaml
# values.yaml
presets:
  kubernetesAttributes:
    enabled: true
  kubeletMetrics:
    enabled: true
  clusterMetrics:
    enabled: true
  kubernetesEvents:
    enabled: true
```

### 13.2 Resource Recommendations

| Workload | CPU Request | CPU Limit | Memory Request | Memory Limit |
|----------|-------------|-----------|----------------|--------------|
| DaemonSet (low traffic) | 100m | 500m | 128Mi | 512Mi |
| DaemonSet (medium traffic) | 250m | 1 | 256Mi | 1Gi |
| Gateway (medium) | 500m | 2 | 512Mi | 2Gi |
| Gateway (high throughput) | 1 | 4 | 1Gi | 4Gi |
| Sidecar | 50m | 200m | 64Mi | 256Mi |

### 13.3 HPA Configuration

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
spec:
  mode: deployment
  replicas: 2
  minReplicas: 2
  maxReplicas: 10
  autoscaler:
    behavior:
      scaleUp:
        stabilizationWindowSeconds: 30
        policies:
          - type: Pods
            value: 2
            periodSeconds: 60
      scaleDown:
        stabilizationWindowSeconds: 300
        policies:
          - type: Pods
            value: 1
            periodSeconds: 120
    targetCPUUtilization: 60
    targetMemoryUtilization: 70
```

### 13.4 Multi-Mode Architecture Pattern

```
[DaemonSet Collectors] ──────> [Gateway Deployment/StatefulSet]
  - filelog receiver              - otlp receiver
  - hostmetrics receiver          - tail_sampling processor
  - kubeletstats receiver         - batch processor
  - k8sattributes processor       - exporters to backends
```

---

## 14. Troubleshooting

### 14.1 Debug Exporter Usage

```yaml
exporters:
  debug:
    verbosity: detailed
    sampling_initial: 5
    sampling_thereafter: 200

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp, debug]     # Add debug alongside production exporter
```

### 14.2 Verbose Logging

```yaml
service:
  telemetry:
    logs:
      level: debug
```

CLI override (no config change needed):
```bash
./otelcol --config=config.yaml --set=service.telemetry.logs.level=debug
```

### 14.3 Configuration Validation

```bash
# Validate config before deployment
./otelcol validate --config=config.yaml

# In Kubernetes, use init container
initContainers:
  - name: validate-config
    image: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.96.0
    command: ["otelcol-contrib", "validate", "--config=/conf/config.yaml"]
```

### 14.4 Performance Bottleneck Identification

| Symptom | Likely Cause | Metric to Check |
|---------|-------------|-----------------|
| Growing queue size | Backend too slow or unavailable | `otelcol_exporter_queue_size` |
| High memory usage | Large batches, insufficient limits | `process_runtime_total_alloc_bytes` |
| Refused data at receiver | Collector overloaded | `otelcol_receiver_refused_*` |
| Failed exports | Backend connectivity or auth issues | `otelcol_exporter_send_failed_*` |
| Slow batch processing | Batch size too large | `otelcol_processor_batch_batch_send_size` |
| OOM kills | memory_limiter misconfigured | Container restart count |

### 14.5 Common Error Messages

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `bind: address already in use` | Port conflict | Change endpoint port |
| `connection refused` | Backend not reachable | Verify endpoint URL, DNS, network policies |
| `context deadline exceeded` | Request timeout | Increase timeout, check backend health |
| `TLS handshake failed` | Certificate mismatch | Verify cert paths, CA chain, expiry |
| `no such host` | DNS resolution failure | Check CoreDNS, network policies |
| `rpc error: code = Unavailable` | gRPC endpoint down | Check backend status, retry config |
| `dropping data due to memory limit` | memory_limiter triggered | Increase memory limits or add HPA |
| `failed to get token` | OAuth2/auth failure | Verify credentials, token URL, scopes |
| `pipeline not configured` | Component not in service.pipelines | Add component to correct pipeline |
| `unknown component` | Component not in Collector build | Use contrib image or build custom with OCB |

### 14.6 Kubernetes Connectivity Debugging

```bash
kubectl exec -it otel-collector-xxx -- sh

# DNS resolution
nslookup backend-service.namespace.svc.cluster.local

# Port connectivity
nc -zv backend-service 4317

# Certificate chain
openssl s_client -connect backend-service:4317 -servername backend-service
```

---

## 15. Migration Guides

### 15.1 Jaeger Agent/Collector to OTel Collector

**Phase 1: Deploy OTel Collector with Jaeger Receiver (parallel operation)**
```yaml
receivers:
  jaeger:
    protocols:
      thrift_compact:
        endpoint: 0.0.0.0:6831    # Same port as Jaeger Agent
      thrift_binary:
        endpoint: 0.0.0.0:6832
      thrift_http:
        endpoint: 0.0.0.0:14268
      grpc:
        endpoint: 0.0.0.0:14250
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

exporters:
  otlp/jaeger:
    endpoint: jaeger-collector:4317     # Keep sending to Jaeger
  otlp/new_backend:
    endpoint: new-backend:4317          # Also send to new backend

service:
  pipelines:
    traces:
      receivers: [jaeger, otlp]
      processors: [batch]
      exporters: [otlp/jaeger, otlp/new_backend]   # Dual-ship
```

**Phase 2:** Migrate SDKs incrementally (service by service) from Jaeger Agent to OTel SDK + OTLP.

**Phase 3:** Remove Jaeger receiver once all services migrated.

### 15.2 Fluentd/Fluent Bit to OTel Collector for Logs

**Approach A: Bridge Pattern (minimal disruption)**
```yaml
receivers:
  fluentforward:
    endpoint: 0.0.0.0:8006          # Accept from existing Fluent Bit agents
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317      # Accept from new/migrated services

service:
  pipelines:
    logs:
      receivers: [fluentforward, otlp]
      processors: [batch]
      exporters: [otlp]
```

**Fluent Bit output config (point to OTel Collector):**
```ini
[OUTPUT]
    Name          forward
    Match         *
    Host          otel-collector
    Port          8006
```

**Approach B: Direct Replacement with Filelog Receiver** -- use the filelog receiver with CRI log format parsing (see Section 5.3).

### 15.3 Prometheus Node Exporter to hostmetrics Receiver

**Metric name mapping:**

| Node Exporter | hostmetrics Receiver |
|---------------|---------------------|
| `node_cpu_seconds_total` | `system.cpu.time` |
| `node_memory_MemTotal_bytes` | `system.memory.usage` (state=total) |
| `node_memory_MemAvailable_bytes` | `system.memory.usage` (state=available) |
| `node_disk_read_bytes_total` | `system.disk.io` (direction=read) |
| `node_disk_written_bytes_total` | `system.disk.io` (direction=write) |
| `node_filesystem_size_bytes` | `system.filesystem.usage` |
| `node_network_receive_bytes_total` | `system.network.io` (direction=receive) |
| `node_load1` | `system.cpu.load_average.1m` |

**Phase 1:** Run both, compare metrics. **Phase 2:** Update dashboards. **Phase 3:** Remove Node Exporter.

### 15.4 Dual-Shipping During Migration

```yaml
exporters:
  otlp/legacy:
    endpoint: legacy-backend:4317
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      queue_size: 5000

  otlp/new:
    endpoint: new-backend:4317
    retry_on_failure:
      enabled: true
    sending_queue:
      enabled: true
      queue_size: 5000

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/legacy, otlp/new]     # Fan out to both
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/legacy, otlp/new]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/legacy, otlp/new]
```

Each exporter operates independently -- failure in one does not block the other. Each gets its own retry and sending queue.

**Advanced: Different processing per destination**
```yaml
service:
  pipelines:
    logs/premium:
      receivers: [otlp]
      processors: [batch/fast]
      exporters: [otlp/new]          # All logs to new backend

    logs/legacy:
      receivers: [otlp]
      processors: [filter/drop_debug, batch/slow]
      exporters: [otlp/legacy]       # Only WARN+ to legacy
```

### 15.5 Version Compatibility and Upgrade Strategies

- **Release cadence**: Core and Contrib release approximately every 2 weeks.
- **Collector core and contrib versions must match** (e.g., 0.96.0 with 0.96.0).
- **OTLP protocol is stable and backward-compatible**: older SDKs work with newer Collectors.
- **Always pin versions**: `image: ...opentelemetry-collector-contrib:0.96.0@sha256:<digest>`

**Upgrade checklist:**
1. Read the changelog for breaking changes
2. Validate config: `otelcol validate --config=config.yaml`
3. Test in staging with production-like traffic
4. Canary deploy to a subset of collectors
5. Monitor internal metrics during rollout
6. Keep rollback plan with previous container image tag

---

## 16. Production Checklist

### Critical Settings

```yaml
# Environment variables
# GOMEMLIMIT=<80% of memory limit>

processors:
  memory_limiter:              # MUST be first processor in every pipeline
    check_interval: 1s
    limit_mib: 1800

  batch:
    send_batch_size: 8192
    timeout: 5s

exporters:
  otlp:
    endpoint: backend:4317
    compression: zstd
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 1000
      storage: file_storage    # Persistent queue
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  file_storage:
    directory: /var/lib/otelcol/storage
```

### Eight Production Rules

1. **Always use `GOMEMLIMIT`** set to 80% of container memory limit.
2. **Always place `memory_limiter` as the first processor** in every pipeline.
3. **Always use the `batch` processor** for production workloads.
4. **Always enable `sending_queue` with `retry_on_failure`** on exporters.
5. **Always use compression** (`zstd` preferred, `gzip` as fallback).
6. **Build custom distributions with OCB** -- never run `otelcol-contrib` in production.
7. **Use persistent queues** (`file_storage`) for crash recovery in gateway deployments.
8. **Monitor self-telemetry metrics** at `:8888/metrics` and alert on queue saturation.

### Alerting Rules for Collector Health

```yaml
# Alert when exporter queue is filling up
- alert: OTelCollectorQueueSaturation
  expr: otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.7
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "OTel Collector exporter queue > 70% full"

# Alert when exports are failing
- alert: OTelCollectorExportFailure
  expr: rate(otelcol_exporter_send_failed_spans[5m]) > 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "OTel Collector failing to export spans"

# Alert when receiver is refusing data (backpressure)
- alert: OTelCollectorReceiverRefused
  expr: rate(otelcol_receiver_refused_spans[5m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "OTel Collector receiver refusing spans (backpressure)"

# Alert on collector restarts (likely OOM)
- alert: OTelCollectorRestarting
  expr: changes(process_start_time_seconds{job="otel-collector"}[15m]) > 1
  labels:
    severity: critical
  annotations:
    summary: "OTel Collector restarting frequently (possible OOM)"
```

---

## Sources

### Official Documentation
- [OpenTelemetry Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
- [OpenTelemetry Collector Architecture](https://opentelemetry.io/docs/collector/architecture/)
- [Build a Custom Collector with OCB](https://opentelemetry.io/docs/collector/extend/ocb/)
- [Collector Distributions](https://opentelemetry.io/docs/collector/distributions/)
- [Gateway Deployment Pattern](https://opentelemetry.io/docs/collector/deployment/gateway/)
- [Deploy the Collector](https://opentelemetry.io/docs/collector/deploy/)
- [Scaling the Collector](https://opentelemetry.io/docs/collector/scaling/)
- [Collector Benchmarks](https://opentelemetry.io/docs/collector/benchmarks/)
- [Collector Resiliency](https://opentelemetry.io/docs/collector/resiliency/)
- [Collector Troubleshooting](https://opentelemetry.io/docs/collector/troubleshooting/)
- [Internal Telemetry](https://opentelemetry.io/docs/collector/internal-telemetry/)
- [Extensions Documentation](https://opentelemetry.io/docs/collector/components/extension/)
- [Connectors Documentation](https://opentelemetry.io/docs/collector/components/connector/)
- [Security Configuration Best Practices](https://opentelemetry.io/docs/security/config-best-practices/)
- [Handling Sensitive Data](https://opentelemetry.io/docs/security/handling-sensitive-data/)

### Kubernetes
- [OpenTelemetry Operator for Kubernetes](https://opentelemetry.io/docs/platforms/kubernetes/operator/)
- [Injecting Auto-instrumentation](https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/)
- [Helm Chart Configuration](https://opentelemetry.io/docs/platforms/kubernetes/helm/collector/)
- [HPA Configuration](https://opentelemetry.io/docs/platforms/kubernetes/operator/horizontal-pod-autoscaling/)
- [OpenTelemetry Operator (GitHub)](https://github.com/open-telemetry/opentelemetry-operator)

### Component READMEs (GitHub)
- [Memory Limiter Processor](https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/memorylimiterprocessor/README.md)
- [Batch Processor](https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/batchprocessor/README.md)
- [SpanMetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/spanmetricsconnector/README.md)
- [Load Balancing Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/exporter/loadbalancingexporter/README.md)
- [Count Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/countconnector/README.md)
- [Routing Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/routingconnector/README.md)
- [Forward Connector](https://github.com/open-telemetry/opentelemetry-collector/blob/main/connector/forwardconnector/README.md)
- [Transform Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/transformprocessor/README.md)
- [Redaction Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/redactionprocessor/README.md)
- [TLS Configuration](https://github.com/open-telemetry/opentelemetry-collector/blob/main/config/configtls/README.md)

### OTTL
- [OTTL Language Specification (GitHub)](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/ottl/LANGUAGE.md)
- [OTTL Functions Reference (GitHub)](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/ottl/ottlfuncs/README.md)
- [Mastering OTTL (Dash0)](https://www.dash0.com/guides/opentelemetry-transformation-language-ottl)
- [OTTL Cookbook (Honeycomb)](https://www.honeycomb.io/blog/ottl-cookbook-common-solutions-data-transformation-problems)
- [OTTL Recipes (Better Stack)](https://betterstack.com/community/guides/observability/ottl-patterns/)

### Community Guides
- [Mastering the Memory Limiter Processor (Dash0)](https://www.dash0.com/guides/opentelemetry-memory-limiter-processor)
- [Mastering the Batch Processor (Dash0)](https://www.dash0.com/guides/opentelemetry-batch-processor)
- [OpenTelemetry Collector Complete Guide (SigNoz)](https://signoz.io/blog/opentelemetry-collector-complete-guide/)
- [Securing Your OpenTelemetry Collector (Medium)](https://medium.com/opentelemetry/securing-your-opentelemetry-collector-1a4f9fa5bd6f)
- [Monitoring the OTel Collector (Better Stack)](https://betterstack.com/community/guides/observability/monitoring-otel-collector/)
- [Collector Deployment Modes in Kubernetes (New Relic)](https://newrelic.com/blog/infrastructure-monitoring/opentelemetry-collector-deployment-modes-in-kubernetes)
- [Production-Ready OTel Collector (base14)](https://docs.base14.io/blog/production-ready-otel-collector/)

### Migration
- [Migrating from Jaeger (OpenTelemetry Blog)](https://opentelemetry.io/blog/2023/jaeger-exporter-collector-migration/)
- [Jaeger SDK Migration (Jaeger)](https://www.jaegertracing.io/sdk-migration/)
- [Fluent Forward Receiver (Dash0)](https://www.dash0.com/guides/opentelemetry-fluent-forward-receiver)
- [Host Metrics vs Node Exporter Comparison](https://luppeng.wordpress.com/2025/07/26/comparing-the-key-hardware-and-os-metris-exposed-by-prometheus-node-exporter-and-opentelemetry-collectors-host-metrics-receiver/)
