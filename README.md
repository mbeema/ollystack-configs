# OllyStack - OpenTelemetry Consulting Template Repository

Production-ready OpenTelemetry Collector configuration templates for enterprise consulting engagements. Covers **all major platforms** (AWS, Azure, GCP, Kubernetes, on-prem) and **all 5 telemetry signals** (Metrics, Logs, Traces, Events, Profiles).

---

## Why Hire OllyStack Experts?

Adopting OpenTelemetry across a large enterprise is not a tooling problem — it's an **architecture and strategy problem**. OllyStack consultants bring:

| Value | What You Get |
|-------|-------------|
| **Instrumentation Strategy** | OBI-first assessment — we identify which services can go zero-code with eBPF and which need SDK investment |
| **Architecture Design** | Right-sized Collector topology (agent, gateway, load-balancer) tailored to your traffic and compliance needs |
| **Platform Expertise** | Battle-tested configs for AWS, Azure, GCP, Kubernetes, and on-prem — no guessing |
| **Sampling & Cost Control** | Tail-sampling, adaptive head-sampling, and quota strategies that keep backend costs predictable |
| **Migration Paths** | Smooth migration from Datadog, New Relic, Dynatrace, or Elastic agents to vendor-neutral OTel |
| **Production Hardening** | Auth, TLS, back-pressure, retry, and HA patterns proven at scale |

> **Engagement model:** We embed with your platform team for 2-12 weeks, deliver production configs from this repository, train your engineers, and hand off full ownership. No lock-in — you keep everything.

---

## Instrumentation Strategy: OBI-First Decision Tree

Before instrumenting any service, follow this decision tree:

```
                        ┌─────────────────────┐
                        │  New service to      │
                        │  instrument?         │
                        └─────────┬───────────┘
                                  │
                    ┌─────────────▼──────────────┐
                    │  Is it running on Linux     │
                    │  kernel 5.17+ ?             │
                    └──────┬──────────────┬───────┘
                       YES │              │ NO
                ┌──────────▼──────┐  ┌────▼──────────────────┐
                │  Does it use    │  │  Use language-specific │
                │  plain HTTP/1.1 │  │  auto-instrumentation  │
                │  (no TLS at     │  │  (Java Agent, Python   │
                │  pod level,     │  │  CLI, Node --require,  │
                │  no gRPC/H2)?   │  │  .NET CLR Profiler)    │
                └──┬──────────┬───┘  └────────────────────────┘
               YES │          │ NO
          ┌────────▼───┐  ┌───▼──────────────────┐
          │  ✅ Use OBI │  │  Use language-specific│
          │  (eBPF)    │  │  auto-instrumentation │
          │  Zero-code │  │  + consider OBI for   │
          │  deploy    │  │  network-level metrics│
          └────────────┘  └───────────────────────┘

              Need custom business spans or metrics?
              ──────────────────────────────────────
              YES → Add SDK instrumentation on top
              NO  → You're done
```

### OBI vs SDK vs Traditional Auto-Instrumentation

| Approach | Zero-Code | Language Agnostic | Custom Spans | Kernel Dependent |
|----------|-----------|-------------------|--------------|------------------|
| **OBI (eBPF)** | Yes | Yes (network-level) | No | Yes (5.17+) |
| **Auto-Instrumentation** | Yes | No (per-language agents) | No | No |
| **SDK** | No | Yes | Yes | No |

**Recommendation hierarchy:**
1. **OBI first** — zero-code, language-agnostic, lowest risk
2. **Language-specific auto-instrumentation** — when OBI limitations apply (HTTPS, gRPC, HTTP/2)
3. **SDK** — only when custom business spans/metrics are needed

---

## The Future: eBPF + OBI

**OpenTelemetry eBPF Instrumentation (OBI)** is the future of zero-code observability. Instead of injecting agents into your application runtime, OBI uses **eBPF probes at the kernel level** to capture traces, metrics, and logs — completely outside your application process.

**How it works:**
- Deploys as a **DaemonSet** with `hostNetwork: true` on each node
- Attaches eBPF probes to kernel syscalls (`accept`, `connect`, `read`, `write`)
- Automatically propagates **W3C `traceparent`** headers for distributed tracing
- **Language-agnostic** at the network level — any language, any framework
- Enhanced Go support via library-level eBPF probes (net/http, database/sql, google.golang.org/grpc)

**Current limitations (being actively resolved by the OTel community):**
- Requires Linux kernel **5.17+** with BTF support
- No HTTPS header injection (operates at TCP/IP level; use a service mesh or sidecar for TLS termination)
- No gRPC/HTTP2 support yet (multiplexed streams are harder to trace at the kernel level)
- No custom business spans (by design — use SDK for that)

**Why OllyStack recommends OBI first:**
- Zero code changes, zero dependency additions, zero build-pipeline impact
- Deploy once per node, cover every pod automatically
- Eliminates "instrumentation debt" — new services are observed from day one
- Frees your developers to focus on SDK instrumentation only where it adds business value

> See each language guide in `auto-instrumentation/` for OBI + language-specific recommendations.

---

## Cost Optimization & Volume Control

Observability backends charge by **ingestion volume** — logs (GB), metrics (active series), and traces (spans). Without cost controls, telemetry costs grow linearly with infrastructure. OllyStack provides **5 levers** to reduce volume by **60-80%** without losing signal.

### The 5 Levers

```
┌──────────────────────────────────────────────────────────────────┐
│                    RAW TELEMETRY IN                               │
└──────────────────────┬───────────────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │  1. FILTER — Drop noise    │  Health checks, probes,
         │     at the gate            │  static assets, OPTIONS
         └─────────────┬──────────────┘
                       │  ~15-30% reduction
         ┌─────────────▼──────────────┐
         │  2. SEVERITY — Drop by     │  WARN+ in prod,
         │     log level              │  INFO+ in staging
         └─────────────┬──────────────┘
                       │  ~40-70% log reduction
         ┌─────────────▼──────────────┐
         │  3. CARDINALITY — Strip    │  pod_uid, container_id,
         │     high-card attributes   │  IPs, full URLs
         └─────────────┬──────────────┘
                       │  ~40-70% series reduction
         ┌─────────────▼──────────────┐
         │  4. TRUNCATE — Shrink      │  Log bodies to 4KB,
         │     oversized payloads     │  span attrs to 1KB
         └─────────────┬──────────────┘
                       │  ~20-40% storage reduction
         ┌─────────────▼──────────────┐
         │  5. SAMPLE — Keep errors   │  100% errors, 100% slow,
         │     + slow, sample rest    │  10% probabilistic catchall
         └─────────────┬──────────────┘
                       │  ~80-90% trace reduction
         ┌─────────────▼──────────────┐
         │    OPTIMIZED TELEMETRY OUT  │
         └─────────────────────────────┘
```

### Environment Profiles

<details>
<summary><strong>Production — Aggressive Cost Control (60-80% reduction)</strong></summary>

Keep only actionable data. Errors, slow traces, and WARN+ logs always preserved.

```bash
otelcol --config=collector/base/otel-agent-base.yaml \
  --config=collector/fragments/receivers/otlp.yaml \
  --config=collector/fragments/processors/memory-limiter.yaml \
  --config=collector/fragments/processors/resourcedetection-aws.yaml \
  --config=collector/fragments/processors/k8sattributes.yaml \
  --config=collector/fragments/processors/filter-logs-severity.yaml \
  --config=collector/fragments/processors/filter-logs.yaml \
  --config=collector/fragments/processors/transform-logs-cost.yaml \
  --config=collector/fragments/processors/filter-traces.yaml \
  --config=collector/fragments/processors/filter-traces-noisy.yaml \
  --config=collector/fragments/processors/transform-traces-cost.yaml \
  --config=collector/fragments/processors/filter-metrics.yaml \
  --config=collector/fragments/processors/filter-metrics-cardinality.yaml \
  --config=collector/fragments/processors/tail-sampling-composite.yaml \
  --config=collector/fragments/processors/redaction.yaml \
  --config=collector/fragments/processors/batch.yaml \
  --config=collector/fragments/exporters/otlp-grpc.yaml
```

```bash
# Environment variables
LOG_MIN_SEVERITY=SEVERITY_NUMBER_WARN   # Only WARN, ERROR, FATAL
```

</details>

<details>
<summary><strong>Staging — Balanced (30-50% reduction)</strong></summary>

Enough data for debugging, with cost controls applied.

```bash
otelcol --config=collector/base/otel-agent-base.yaml \
  --config=collector/fragments/receivers/otlp.yaml \
  --config=collector/fragments/processors/memory-limiter.yaml \
  --config=collector/fragments/processors/k8sattributes.yaml \
  --config=collector/fragments/processors/filter-logs-severity.yaml \
  --config=collector/fragments/processors/filter-logs.yaml \
  --config=collector/fragments/processors/filter-traces.yaml \
  --config=collector/fragments/processors/filter-traces-noisy.yaml \
  --config=collector/fragments/processors/filter-metrics-cardinality.yaml \
  --config=collector/fragments/processors/probabilistic-sampling-head.yaml \
  --config=collector/fragments/processors/batch.yaml \
  --config=collector/fragments/exporters/otlp-grpc.yaml
```

```bash
LOG_MIN_SEVERITY=SEVERITY_NUMBER_INFO   # INFO and above
SAMPLING_PERCENTAGE=50                  # 50% head sampling
```

</details>

<details>
<summary><strong>Development — Full Fidelity</strong></summary>

Keep everything for debugging. Only remove known noise.

```bash
otelcol --config=collector/base/otel-agent-base.yaml \
  --config=collector/fragments/receivers/otlp.yaml \
  --config=collector/fragments/processors/memory-limiter.yaml \
  --config=collector/fragments/processors/filter-logs.yaml \
  --config=collector/fragments/processors/filter-traces.yaml \
  --config=collector/fragments/processors/batch.yaml \
  --config=collector/fragments/exporters/otlp-grpc.yaml
```

</details>

### Recommended Pipeline Order

**Order matters.** Processors execute in the order listed under `service.pipelines`. The recommended order ensures enrichment happens before filtering, and filtering happens before sampling.

```yaml
service:
  pipelines:
    traces:
      processors:
        - memory_limiter            # 1. Back-pressure (always first)
        - resourcedetection         # 2. Cloud/host metadata
        - k8sattributes             # 3. K8s metadata
        - filter/traces             # 4. Drop health checks
        - filter/traces-noisy       # 5. Drop static assets, OPTIONS
        - transform/traces-cost     # 6. Strip high-card attrs, truncate
        - redaction                 # 7. Mask PII
        - tail_sampling/composite   # 8. Sample (after enrichment)
        - batch                     # 9. Batch for export (always last)

    metrics:
      processors:
        - memory_limiter
        - resourcedetection
        - k8sattributes
        - filter/metrics            # Drop idle CPU, runtime metrics
        - transform/reduce-cardinality  # Strip pod_uid, IPs, etc.
        - batch

    logs:
      processors:
        - memory_limiter
        - resourcedetection
        - k8sattributes
        - filter/log-severity       # Drop below WARN/INFO threshold
        - filter/logs               # Drop health checks, probes
        - transform/logs            # Parse JSON, extract severity
        - transform/logs-cost       # Truncate bodies, strip stacks
        - redaction                 # Mask PII
        - batch
```

> **Rule of thumb:** `memory_limiter` first, `batch` last, filter before transform, transform before sample. See `collector/fragments/processors/cost-profiles.md` for the full guide.

---

## Complete Integration Coverage

OllyStack provides **152 receiver fragments**, **39 exporter fragments**, **40 processor fragments**, **8 extension fragments**, **6 connector fragments**, and **245 total composable fragments** covering virtually every OpenTelemetry Collector Contrib integration relevant for enterprise production use. Backend configs support **15 observability platforms** including 6 self-hosted options.

### Cloud Providers

<details>
<summary><strong>AWS (18 receiver fragments)</strong></summary>

| Fragment | Service | Metrics Collected |
|----------|---------|-------------------|
| `awscloudwatch.yaml` | EC2, RDS, ALB (base) | CPU, network, disk, connections |
| `awscloudwatch-dynamodb.yaml` | DynamoDB | RCU/WCU, throttles, latency, table size |
| `awscloudwatch-rds-aurora.yaml` | RDS & Aurora | IOPS, replication lag, deadlocks, ACU |
| `awscloudwatch-apigateway.yaml` | API Gateway | Requests, latency, 4xx/5xx, WebSocket |
| `awscloudwatch-lambda.yaml` | Lambda | Invocations, duration, errors, cold starts |
| `awscloudwatch-s3.yaml` | S3 | Storage, requests, first-byte latency |
| `awscloudwatch-elasticache.yaml` | ElastiCache | Hit ratio, evictions, replication |
| `awscloudwatch-msk.yaml` | MSK (Kafka) | Broker, topic, partition metrics |
| `awscloudwatch-sqs.yaml` | SQS | Queue depth, message age, throughput |
| `awscloudwatch-sns.yaml` | SNS | Publish & delivery metrics |
| `awscloudwatch-kinesis.yaml` | Kinesis | Streams & Firehose throughput |
| `awscloudwatch-stepfunctions.yaml` | Step Functions | Execution success/failure, duration |
| `awscloudwatch-eventbridge.yaml` | EventBridge | Rule invocations, failures, Pipes |
| `awscloudwatch-elb.yaml` | ALB + NLB | Targets, latency, request count |
| `awscloudwatch-cloudfront.yaml` | CloudFront | Requests, error rate, bytes |
| `awscontainerinsights.yaml` | ECS/EKS | Container CPU, memory, network |
| `awsfirehose.yaml` | Kinesis Firehose | Receive from Firehose via HTTP |
| `awss3.yaml` | S3 (reader) | Consume archived telemetry from S3 |

</details>

<details>
<summary><strong>Azure (17 receiver fragments)</strong></summary>

| Fragment | Service | Metrics Collected |
|----------|---------|-------------------|
| `azuremonitor.yaml` | Virtual Machines (base) | CPU, memory, disk, network |
| `azuremonitor-sqldatabase.yaml` | SQL Database | DTU, connections, deadlocks, storage |
| `azuremonitor-cosmosdb.yaml` | Cosmos DB | RU consumption, throttling, latency |
| `azuremonitor-appservice.yaml` | App Service | Requests, response time, HTTP errors |
| `azuremonitor-functions.yaml` | Azure Functions | Executions, duration, failures |
| `azuremonitor-servicebus.yaml` | Service Bus | Messages, active connections, errors |
| `azuremonitor-eventhubs.yaml` | Event Hubs | Throughput, capture, throttled requests |
| `azuremonitor-storage.yaml` | Storage (Blob/File/Queue/Table) | Transactions, latency, capacity |
| `azuremonitor-rediscache.yaml` | Redis Cache | Hit ratio, connected clients, memory |
| `azuremonitor-apimanagement.yaml` | API Management | Requests, latency, capacity |
| `azuremonitor-frontdoor.yaml` | Front Door & CDN | Requests, latency, WAF actions |
| `azuremonitor-containerapps.yaml` | Container Apps | Replicas, requests, CPU/memory |
| `azuremonitor-keyvault.yaml` | Key Vault | API hits, latency, saturation |
| `azuremonitor-appgateway.yaml` | Application Gateway | Throughput, healthy hosts, WAF |
| `azuremonitor-loadbalancer.yaml` | Load Balancer | Health probe status, SNAT, data path |
| `azuremonitor-aks.yaml` | AKS | API server, etcd, scheduler metrics |
| `azureblob.yaml` | Blob Storage (reader) | Consume telemetry from Blob Storage |

</details>

<details>
<summary><strong>GCP (16 receiver fragments)</strong></summary>

| Fragment | Service | Metrics Collected |
|----------|---------|-------------------|
| `googlecloud.yaml` | Compute/SQL/GKE (base) | CPU, memory, disk |
| `googlecloudmonitoring-cloudsql.yaml` | Cloud SQL | Connections, queries, replication |
| `googlecloudmonitoring-spanner.yaml` | Cloud Spanner | CPU, storage, latency, lock waits |
| `googlecloudmonitoring-cloudrun.yaml` | Cloud Run | Request count, latency, container |
| `googlecloudmonitoring-cloudfunctions.yaml` | Cloud Functions | Executions, duration, memory |
| `googlecloudmonitoring-pubsub.yaml` | Pub/Sub | Message count, backlog, age |
| `googlecloudmonitoring-bigquery.yaml` | BigQuery | Slots, query count, storage |
| `googlecloudmonitoring-gke.yaml` | GKE | Node, pod, container metrics |
| `googlecloudmonitoring-cloudstorage.yaml` | Cloud Storage | Request count, bytes, latency |
| `googlecloudmonitoring-memorystore.yaml` | Memorystore | Redis + Memcached metrics |
| `googlecloudmonitoring-dataflow.yaml` | Dataflow | Elements, system lag, throughput |
| `googlecloudmonitoring-cloudtasks.yaml` | Cloud Tasks | Queue depth, dispatch latency |
| `googlecloudmonitoring-loadbalancing.yaml` | Load Balancing | HTTPS, TCP/SSL, L4 metrics |
| `googlecloudmonitoring-computeengine.yaml` | Compute Engine | Enhanced CPU, disk, network |
| `googlecloudmonitoring-filestore.yaml` | Filestore | IOPS, throughput, capacity |
| `googlecloudspanner.yaml` | Spanner (direct API) | Top-N queries, lock stats, transactions |

</details>

### Databases (19 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `postgresql.yaml` | PostgreSQL | Connections, transactions, locks, replication lag |
| `mysql.yaml` | MySQL / MariaDB | Queries, buffer pool, InnoDB, replication |
| `mongodb.yaml` | MongoDB | Operations, memory, connections, opcounters |
| `redis.yaml` | Redis | Memory, keyspace, commands, persistence |
| `elasticsearch.yaml` | Elasticsearch | Cluster health, node stats, JVM, indices |
| `snowflake.yaml` | Snowflake | Billing, queries, storage, logins |
| `oracledb.yaml` | Oracle Database | Sessions, tablespace, CPU, wait events |
| `sqlserver.yaml` | SQL Server | Batch requests, lock waits, buffer cache |
| `saphana.yaml` | SAP HANA | Memory, CPU, connections, row/column store |
| `couchdb.yaml` | CouchDB | Requests, database ops, file descriptors |
| `couchbase.yaml` | Couchbase Server | Bucket ops, N1QL, XDCR, indexes |
| `cassandra.yaml` | Apache Cassandra | Read/write latency, compaction, tombstones (via JMX) |
| `timescaledb.yaml` | TimescaleDB | Hypertable sizes, chunks, compression, jobs |
| `pgbouncer.yaml` | PgBouncer | Pool utilization, wait times, saturation |
| `proxysql.yaml` | ProxySQL | Connection pools, query cache, routing |
| `memcached.yaml` | Memcached | Hit ratio, evictions, connections |
| `zookeeper.yaml` | ZooKeeper | Latency, connections, znodes, watches |
| `riak.yaml` | Riak KV | Node health, vnode ops, latencies |
| `aerospike.yaml` | Aerospike | Namespace stats, transactions, connections |
| `mongodbatlas.yaml` | MongoDB Atlas | Process metrics, disk, alerts, logs |

### Web Servers & App Platforms (8 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `nginx.yaml` | Nginx | Connections, requests (via stub_status) |
| `apache.yaml` | Apache httpd | Requests, traffic, workers (via mod_status) |
| `iis.yaml` | Microsoft IIS | Connections, requests, threads |
| `haproxy.yaml` | HAProxy | Sessions, request rates, errors |
| `jmx.yaml` | JMX (Java apps) | JVM heap, GC, threads (ActiveMQ, Cassandra, Kafka, Tomcat) |
| `flinkmetrics.yaml` | Apache Flink | JVM, jobs, operators, checkpoints |
| `apachespark.yaml` | Apache Spark | Executors, stages, shuffle, jobs |
| `bigip.yaml` | F5 BIG-IP | Virtual servers, pools, nodes |

### Messaging & Streaming (5 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `kafka.yaml` | Apache Kafka (consumer) | Consume telemetry from Kafka topics |
| `kafkametrics.yaml` | Apache Kafka (metrics) | Broker, topic, consumer group health |
| `rabbitmq.yaml` | RabbitMQ | Queues, exchanges, channels, message rates |
| `pulsar.yaml` | Apache Pulsar | Consume telemetry from Pulsar topics |
| `solace.yaml` | Solace PubSub+ | Distributed tracing via AMQP |

### SaaS & Enterprise (7 receivers)

| Fragment | Technology | Purpose |
|----------|-----------|---------|
| `mongodbatlas.yaml` | MongoDB Atlas | Cloud-hosted MongoDB monitoring |
| `cloudflare.yaml` | Cloudflare | HTTP requests, firewall events |
| `github.yaml` | GitHub | Push, PR, deployment webhooks |
| `gitlab.yaml` | GitLab | Push, MR, pipeline webhooks |
| `splunkenterprise.yaml` | Splunk Enterprise | Indexer health, search perf, license |
| `servicenow.yaml` | ServiceNow | Change/incident events via webhook |
| `activedirectoryds.yaml` | Active Directory | LDAP ops, replication, authentication |

### Kubernetes & Containers (6 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `kubeletstats.yaml` | Kubelet Stats | Pod/container CPU, memory, network, volumes |
| `k8s-cluster.yaml` | K8s Cluster | Node conditions, deployments, DaemonSets |
| `k8s-events.yaml` | K8s Events | Warning/Normal events as logs |
| `k8sobjects.yaml` | K8s Objects | Watch pods, deployments, configmaps as logs |
| `docker-stats.yaml` | Docker | Container CPU, memory, network, block I/O |
| `hostmetrics.yaml` | Host Metrics | CPU, memory, disk, network, processes, filesystem |

### Network & Infrastructure (16 receivers)

| Fragment | Technology | Purpose |
|----------|-----------|---------|
| `snmp.yaml` | SNMP (v1/v2c/v3) | Routers, switches, firewalls, printers |
| `snmp-traps.yaml` | SNMP Traps (via syslog) | Link down, temp alerts, config changes |
| `netflow.yaml` | NetFlow / sFlow / IPFIX | Network traffic flow analysis |
| `gnmi.yaml` | gNMI (streaming telemetry) | Cisco/Arista/Juniper interface counters, BGP |
| `bgp.yaml` | BGP (via exporter) | Neighbor state, prefixes, session flaps |
| `coredns.yaml` | CoreDNS | DNS queries, cache hit/miss, latency, SERVFAIL |
| `envoy.yaml` | Envoy / Istio sidecar | L4/L7 traffic, circuit breakers, upstream health |
| `hubble.yaml` | Cilium Hubble (eBPF) | L3/L4/L7 flows, DNS, drops, policy verdicts |
| `linkerd.yaml` | Linkerd | Request rates, success rates, latency, TCP |
| `traefik.yaml` | Traefik | Router/service metrics, TLS certs, retries |
| `blackbox.yaml` | Blackbox Exporter | HTTP/TCP/DNS synthetic probes |
| `conntrack.yaml` | Conntrack / TCP state | Conntrack table, TIME_WAIT, drops |
| `smokeping.yaml` | Smokeping Prober | ICMP/UDP latency, packet loss |
| `vcenter.yaml` | VMware vCenter | VMs, hosts, datastores, clusters |
| `purefa.yaml` | Pure Storage FlashArray | Volumes, hosts, array performance |
| `purefb.yaml` | Pure Storage FlashBlade | File systems, buckets, clients |
| `httpcheck.yaml` | HTTP Check (synthetic) | Endpoint availability, response time |

### Vendor Migration Receivers (7 receivers)

Accept data in vendor-native formats for seamless migration to OpenTelemetry:

| Fragment | Accepts Data From | Use Case |
|----------|-------------------|----------|
| `splunkhec-receiver.yaml` | Splunk HEC forwarders | Migrate from Splunk without changing app instrumentation |
| `datadog-receiver.yaml` | Datadog Agent | Migrate from Datadog without changing app instrumentation |
| `loki-receiver.yaml` | Promtail / Grafana Agent | Migrate from Loki push pipeline |
| `signalfx-receiver.yaml` | SignalFx Smart Agent | Migrate from Splunk Observability |
| `fluentforward.yaml` | Fluentd / Fluent Bit | Migrate from Fluentd/Fluent Bit pipelines |
| `skywalking.yaml` | Apache SkyWalking | Migrate from SkyWalking |
| `collectd.yaml` | collectd | Migrate from collectd deployments |

### AI/ML & GPU Infrastructure (3 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `dcgm-gpu.yaml` | NVIDIA DCGM | GPU utilization, temperature, power, memory, NVLink, ECC errors |
| `vllm.yaml` | vLLM / TGI / TensorRT-LLM | TTFB, tokens/sec, KV cache, queue depth, prompt/generation tokens |
| `milvus.yaml` | Milvus / Qdrant / Weaviate | Search latency, QPS, index health, segment count, collection stats |

### Platform Engineering & CI/CD (2 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `argocd.yaml` | ArgoCD | Sync status, reconciliation latency, Git request duration, app health |
| `airflow.yaml` | Apache Airflow | DAG duration, task failures, scheduler health, executor queue depth |

### Cost & Sustainability (2 receivers)

| Fragment | Technology | Key Metrics |
|----------|-----------|-------------|
| `opencost.yaml` | OpenCost (CNCF) | Cost per namespace/pod/container, CPU/memory/GPU hourly cost |
| `kepler.yaml` | Kepler (CNCF) | Energy joules per container/pod/node (CPU, DRAM, GPU, platform) |

### Security & Runtime (4 receivers)

| Fragment | Technology | Purpose |
|----------|-----------|---------|
| `falco.yaml` | Falco | Runtime security alerts (container escapes, privilege escalation) |
| `tetragon.yaml` | Cilium Tetragon | eBPF runtime enforcement events + metrics |
| `sysmon.yaml` | Windows Sysmon | Process, network, file events (MITRE ATT&CK mapped) |
| `snmp-traps.yaml` | SNMP Traps | Network device security events (link down, config changes) |

### Protocol & Utility Receivers (16 receivers)

| Fragment | Protocol / Purpose |
|----------|--------------------|
| `otlp.yaml` | OTLP (gRPC + HTTP) -- primary receiver |
| `prometheus.yaml` | Prometheus scraping |
| `jaeger.yaml` | Jaeger traces (gRPC/Thrift) |
| `zipkin.yaml` | Zipkin traces |
| `opencensus.yaml` | OpenCensus (legacy migration) |
| `statsd.yaml` | StatsD metrics |
| `carbon.yaml` | Graphite/Carbon metrics |
| `influxdb-receiver.yaml` | InfluxDB line protocol |
| `filelog.yaml` | File-based log collection |
| `syslog.yaml` | Syslog (RFC 3164/5424) |
| `journald.yaml` | Linux systemd journal |
| `tcplog.yaml` / `udplog.yaml` | TCP/UDP log ingestion |
| `windowseventlog.yaml` | Windows Event Log |
| `sshcheck.yaml` | SSH connectivity monitoring |
| `tlscheck.yaml` | TLS certificate expiry monitoring |
| `receivercreator.yaml` | Dynamic receiver discovery (K8s/Docker/host) |

### Exporters (39 fragments)

<details>
<summary><strong>All Exporter Fragments</strong></summary>

| Category | Fragment | Backend |
|----------|----------|---------|
| **Protocol** | `otlp-grpc.yaml` | OTLP gRPC (universal) |
| | `otlp-http.yaml` | OTLP HTTP (universal) |
| | `debug.yaml` | Debug/console output |
| | `zipkin.yaml` | Zipkin traces |
| | `loki.yaml` | Grafana Loki (log labels from resource attrs) |
| | `syslog-exporter.yaml` | Syslog (RFC 5424, TCP/UDP) |
| **AWS** | `awsxray.yaml` | AWS X-Ray |
| | `awscloudwatchlogs.yaml` | CloudWatch Logs |
| | `awsemf.yaml` | CloudWatch EMF |
| | `awss3.yaml` | S3 (archival/data lake) |
| | `awskinesis.yaml` | Kinesis (streaming) |
| **Azure** | `azuremonitor.yaml` | Azure Monitor |
| | `azuredataexplorer.yaml` | Azure Data Explorer (Kusto) |
| | `azureblobstorage.yaml` | Azure Blob Storage (archival/compliance) |
| **GCP** | `googlecloud.yaml` | Google Cloud Operations |
| | `googlemanagedprometheus.yaml` | Google Managed Prometheus |
| | `googlecloudpubsub-exporter.yaml` | Cloud Pub/Sub |
| | `googlecloudstorage.yaml` | Cloud Storage (archival/compliance) |
| **APAC / China** | `alibabacloud.yaml` | Alibaba Cloud Log Service (SLS) |
| | `tencentcloud.yaml` | Tencent Cloud Log Service (CLS) |
| **Open Source** | `prometheus-remote-write.yaml` | Prometheus / Thanos / Mimir / Cortex / VictoriaMetrics |
| | `kafka.yaml` | Apache Kafka |
| | `clickhouse.yaml` | ClickHouse |
| | `cassandra.yaml` | Apache Cassandra |
| | `opensearch.yaml` | OpenSearch |
| | `influxdb.yaml` | InfluxDB v1/v2/Cloud |
| | `alertmanager.yaml` | Prometheus Alertmanager |
| | `pulsar-exporter.yaml` | Apache Pulsar |
| | `file.yaml` | Local file output |
| | `loadbalancing.yaml` | Load-balanced fan-out |
| **Commercial** | `datadog.yaml` | Datadog |
| | `splunkhec.yaml` | Splunk (HEC) |
| | `signalfx.yaml` | Splunk Observability (SignalFx) |
| | `honeycomb.yaml` | Honeycomb (OTLP + markers) |
| | `coralogix.yaml` | Coralogix |
| | `sumologic.yaml` | Sumo Logic |
| | `logzio.yaml` | Logz.io |
| | `sentry.yaml` | Sentry |
| | `logicmonitor.yaml` | LogicMonitor |

</details>

### Backends (15 platforms + 6 self-hosted)

Pre-built backend configurations with correct endpoints, authentication, retry/queue settings, and pipeline wiring. Each backend includes an `exporter.yaml` and `README.md` with setup instructions.

**Cloud-Native Backends:**

| Backend | Directory | Protocol | Auth | Key Environment Variables |
|---------|-----------|----------|------|---------------------------|
| **AWS Native** | `backends/aws-native/` | X-Ray + EMF + CloudWatch Logs | IAM role / env credentials | `AWS_REGION` |
| **Azure Native** | `backends/azure-native/` | Azure Monitor | Connection string | `AZURE_CONNECTION_STRING` |
| **GCP Native** | `backends/gcp-native/` | Cloud Operations | Service account | `GOOGLE_APPLICATION_CREDENTIALS` |

**Enterprise SaaS APM:**

<details>
<summary><strong>9 platforms — Datadog, Splunk, New Relic, Dynatrace, Elastic, Grafana Cloud, AppDynamics, Instana, ServiceNow</strong></summary>

| Backend | Directory | Protocol | Auth | Key Environment Variables |
|---------|-----------|----------|------|---------------------------|
| **Datadog** | `backends/datadog/` | Datadog native exporter | API key | `DD_API_KEY`, `DD_SITE` |
| **Splunk** | `backends/splunk/` | HEC (logs/metrics) + OTLP (traces) | HEC token + access token | `SPLUNK_HEC_TOKEN`, `SPLUNK_HEC_ENDPOINT`, `SPLUNK_O11Y_TOKEN` |
| **New Relic** | `backends/newrelic/` | OTLP HTTP | API key header | `NEW_RELIC_API_KEY` |
| **Dynatrace** | `backends/dynatrace/` | OTLP HTTP | API token header | `DYNATRACE_ENDPOINT`, `DYNATRACE_API_TOKEN` |
| **Elastic** | `backends/elastic/` | OTLP HTTP | Bearer token | `ELASTIC_APM_ENDPOINT`, `ELASTIC_APM_TOKEN` |
| **Grafana Cloud** | `backends/grafana-cloud/` | OTLP HTTP (per-signal endpoints) | Basic auth | `GRAFANA_CLOUD_INSTANCE`, `GRAFANA_CLOUD_API_KEY` |
| **Cisco AppDynamics** | `backends/appdynamics/` | OTLP HTTP | Bearer token | `APPDYNAMICS_OTLP_ENDPOINT`, `APPDYNAMICS_CLIENT_TOKEN` |
| **IBM Instana** | `backends/instana/` | OTLP HTTP | x-instana-key header | `INSTANA_OTLP_ENDPOINT`, `INSTANA_AGENT_KEY` |
| **ServiceNow (Lightstep)** | `backends/servicenow/` | OTLP HTTP | Bearer token | `SERVICENOW_OTLP_ENDPOINT`, `LIGHTSTEP_ACCESS_TOKEN` |

All SaaS backends send **Traces + Metrics + Logs** (all 3 signals).

</details>

**Emerging / Modern Platforms:**

| Backend | Directory | Protocol | Auth | Key Environment Variables |
|---------|-----------|----------|------|---------------------------|
| **Chronosphere** | `backends/chronosphere/` | OTLP (traces) + Prometheus RW (metrics) | API token header | `CHRONOSPHERE_OTLP_ENDPOINT`, `CHRONOSPHERE_REMOTE_WRITE_ENDPOINT`, `CHRONOSPHERE_API_TOKEN` |
| **Axiom** | `backends/axiom/` | OTLP HTTP (per-signal) | Bearer token + dataset header | `AXIOM_API_TOKEN`, `AXIOM_DATASET` |

**Self-Hosted Open Source (6 options):**

<details>
<summary><strong>Grafana LGTM, SigNoz, VictoriaMetrics, Uptrace, OpenObserve, Jaeger+Prometheus</strong></summary>

| Config | Stack | Signals | Protocol | Key Environment Variables |
|--------|-------|---------|----------|---------------------------|
| `self-hosted/grafana-lgtm.yaml` | Tempo + Mimir + Loki | Traces + Metrics + Logs | OTLP gRPC (Tempo) + Prometheus RW (Mimir) + OTLP HTTP (Loki) | `TEMPO_ENDPOINT`, `MIMIR_ENDPOINT`, `LOKI_ENDPOINT` |
| `self-hosted/signoz.yaml` | SigNoz (ClickHouse) | Traces + Metrics + Logs | OTLP gRPC | `SIGNOZ_ENDPOINT` |
| `self-hosted/victoriametrics.yaml` | VictoriaMetrics + VictoriaTraces | Metrics + Traces | Prometheus RW + OTLP gRPC | `VICTORIAMETRICS_ENDPOINT`, `VICTORIATRACES_ENDPOINT` |
| `self-hosted/uptrace.yaml` | Uptrace (ClickHouse) | Traces + Metrics + Logs | OTLP gRPC | `UPTRACE_ENDPOINT`, `UPTRACE_DSN` |
| `self-hosted/openobserve.yaml` | OpenObserve | Traces + Metrics + Logs | OTLP HTTP | `OPENOBSERVE_ENDPOINT`, `OPENOBSERVE_USER`, `OPENOBSERVE_PASSWORD` |
| `self-hosted/jaeger-prometheus.yaml` | Jaeger + Prometheus | Traces + Metrics | OTLP gRPC + Prometheus RW | `JAEGER_ENDPOINT`, `PROMETHEUS_ENDPOINT` |

</details>

**Backend Selection Guide:**

```
Already on a cloud provider?
├── AWS only         → backends/aws-native/
├── Azure only       → backends/azure-native/
├── GCP only         → backends/gcp-native/
└── Multi-cloud      → backends/grafana-cloud/ or backends/datadog/

Current vendor to migrate FROM?
├── Datadog          → backends/datadog/   (or migrate away using datadog-receiver)
├── Splunk           → backends/splunk/    (or migrate away using splunkhec-receiver)
├── New Relic        → backends/newrelic/
├── Dynatrace        → backends/dynatrace/
├── Elastic/ELK      → backends/elastic/
├── AppDynamics      → backends/appdynamics/
├── Instana          → backends/instana/
├── ServiceNow       → backends/servicenow/
└── Chronosphere     → backends/chronosphere/

Want full control (self-hosted)?
├── Full-stack OSS          → self-hosted/grafana-lgtm.yaml  (most popular)
├── Lightweight all-in-one  → self-hosted/signoz.yaml or self-hosted/openobserve.yaml
├── Metrics-focused         → self-hosted/victoriametrics.yaml
├── ClickHouse-based APM    → self-hosted/uptrace.yaml
└── Minimal (traces+metrics)→ self-hosted/jaeger-prometheus.yaml
```

**Vendor Migration Path:**

Migrate from a vendor agent to OTel Collector without changing application instrumentation:

| Migrating From | Migration Receiver | Send To |
|----------------|-------------------|---------|
| Splunk Universal Forwarder | `splunkhec-receiver.yaml` | Any backend |
| Datadog Agent | `datadog-receiver.yaml` | Any backend |
| Promtail / Grafana Agent | `loki-receiver.yaml` | Any backend |
| SignalFx Smart Agent | `signalfx-receiver.yaml` | Any backend |
| Fluentd / Fluent Bit | `fluentforward.yaml` | Any backend |
| Apache SkyWalking | `skywalking.yaml` | Any backend |
| collectd | `collectd.yaml` | Any backend |

> **Key insight:** Nearly every modern backend now accepts **OTLP natively**. The `otlp-grpc.yaml` and `otlp-http.yaml` exporter fragments are the universal adapters — backend configs primarily add the correct endpoint URL, authentication headers, and signal-specific routing.

### Processors (40 fragments)

**Core Pipeline:**

| Fragment | Purpose |
|----------|---------|
| `batch.yaml` | Batch telemetry for efficient export |
| `memory-limiter.yaml` | Back-pressure and OOM protection |
| `attributes.yaml` | Add/update/delete/hash attributes |
| `resource.yaml` | Modify resource attributes |
| `resourcedetection-{aws,azure,gcp,system}.yaml` | Auto-detect cloud/host metadata |
| `k8sattributes.yaml` | Kubernetes pod/namespace/node enrichment |
| `groupbytrace.yaml` | Group spans by trace ID |
| `groupbyattrs.yaml` | Group telemetry by attributes, promote to resource level |
| `routing.yaml` | Route to different exporters based on attributes |
| `span.yaml` | Modify span names from attributes |

**Filtering & Cost Control:**

| Fragment | Purpose | Typical Savings |
|----------|---------|-----------------|
| `filter-logs-severity.yaml` | Configurable severity threshold (drop below WARN/INFO) | 40-70% log volume |
| `filter-logs.yaml` | Drop health checks, K8s probes, noisy sidecars | 10-20% log volume |
| `filter-traces.yaml` | Drop health check and synthetic monitoring spans | 10-15% trace volume |
| `filter-traces-noisy.yaml` | Drop static assets, OPTIONS, favicon, /metrics | 15-30% trace volume |
| `filter-metrics.yaml` | Drop idle CPU, internal/runtime metrics | 10-20% metric series |
| `filter-metrics-cardinality.yaml` | Strip pod_uid, container_id, IPs from metrics | 40-70% series reduction |

**Transformation & Cost Optimization:**

| Fragment | Purpose | Typical Savings |
|----------|---------|-----------------|
| `transform-logs.yaml` | Parse JSON bodies, extract severity | — |
| `transform-logs-cost.yaml` | Truncate bodies, strip stack traces from non-errors | 30-60% log volume |
| `transform-metrics.yaml` | Rename metrics, remove high-cardinality attrs | — |
| `transform-traces.yaml` | OTTL-based span transformation | — |
| `transform-traces-cost.yaml` | Strip high-card attrs, truncate values, dedupe semconv | 20-40% trace volume |
| `metricstransform.yaml` | Rename metrics and labels with declarative rules | — |
| `cumulativetodelta.yaml` | Convert cumulative metrics to delta temporality | — |
| `deltatorate.yaml` | Convert delta sum metrics to per-second rate | — |

**Sampling:**

| Fragment | Strategy | Use Case |
|----------|----------|----------|
| `tail-sampling-error.yaml` | Keep all error traces | Never miss failures |
| `tail-sampling-latency.yaml` | Keep slow traces (> threshold) | Catch performance issues |
| `tail-sampling-composite.yaml` | Errors + slow + probabilistic catchall | Production recommended |
| `probabilistic-sampling-head.yaml` | Head-based probabilistic % | Simple volume control |

**Security & Compliance:**

| Fragment | Purpose |
|----------|---------|
| `redaction.yaml` | Mask credit cards, SSNs, emails, JWTs, DB URIs, OAuth tokens, cloud keys |
| `security-event-enrichment.yaml` | MITRE ATT&CK tagging, OCSF category mapping, severity normalization |
| `compliance-filtering.yaml` | PCI-DSS / HIPAA / SOX / SOC 2 / GDPR tagging with retention policies |

**Enrichment:**

| Fragment | Purpose |
|----------|---------|
| `geoip-enrichment.yaml` | MaxMind GeoIP2 IP-to-location enrichment |
| `query-sanitization.yaml` | Normalize SQL queries, replace literals with placeholders |
| `slo-indicator-tagging.yaml` | Tag spans with availability/latency SLI indicators |
| `service-mesh-metadata.yaml` | Detect Istio/Linkerd/Cilium/Consul, add mTLS and mesh context |
| `dns-enrichment.yaml` | DNS normalization, tunneling detection, NXDOMAIN/SERVFAIL tagging |
| `network-topology-enrichment.yaml` | CIDR-to-zone mapping, east-west vs north-south traffic classification |

> See `collector/fragments/processors/cost-profiles.md` for recommended per-environment bundles (Production / Staging / Development) with pipeline ordering.

### Extensions (8 fragments)

| Fragment | Purpose |
|----------|---------|
| `bearertokenauth.yaml` | Bearer token auth for exporters (Grafana Cloud, Honeycomb) |
| `basicauth.yaml` | HTTP Basic Auth for Elasticsearch, Grafana, legacy endpoints |
| `oauth2auth.yaml` | OAuth2 client credentials with auto-refresh for SaaS backends |
| `oidcauth.yaml` | OIDC JWT validation for multi-tenant collector auth (Okta, Entra ID) |
| `sigv4auth.yaml` | AWS Signature V4 for X-Ray, AMP, CloudWatch |
| `health-check.yaml` | Collector health endpoint for K8s liveness/readiness probes |
| `pprof.yaml` | Go pprof profiling endpoint for performance debugging |
| `zpages.yaml` | In-process diagnostic pages (tracez, rpcz) |

### Connectors (6 fragments)

| Fragment | Purpose |
|----------|---------|
| `spanmetrics.yaml` | Generate RED metrics (Rate, Error, Duration) from traces |
| `servicegraph.yaml` | Generate service dependency graph metrics from traces |
| `count.yaml` | Count spans, logs, and metrics by conditions (errors, DB queries) |
| `routing.yaml` | Cross-pipeline routing by attributes (security→SIEM, errors→long-retention) |
| `failover.yaml` | Automatic failover between priority-ordered backend pipelines |
| `forward.yaml` | Zero-transform data forwarding between pipeline stages |

### OCB Manifest

The custom collector build (`collector/builder/manifest.yaml`) includes **84 receivers**, **42 exporters**, **21 processors**, **17 extensions**, and **6 connectors** — totaling **170 components**. Fragment library provides **152 receiver fragments**, **39 exporter fragments**, **40 processor fragments**, **8 extension fragments**, and **6 connector fragments** with signal-specific, cost-optimization, sampling, security, AI/ML, and enrichment variants.

---

## Getting Started in 5 Minutes

The fastest way to get a production-ready OTel Collector config:

**Option A: Use a Golden Config (recommended)**
```bash
# Copy a pre-assembled config for your stack
./bin/ollystack golden aws-datadog-production.yaml my-config.yaml

# Set required environment variables
export DD_API_KEY="your-datadog-api-key"
export DD_SITE="datadoghq.com"

# Deploy
otelcol --config=my-config.yaml
```

**Option B: Interactive Wizard**
```bash
./bin/ollystack init
# Follow the prompts: platform → backend → signals → environment
# Output: a composed config ready to deploy
```

**Option C: Manual Fragment Composition**
```bash
./bin/ollystack merge -o my-config.yaml \
  collector/base/otel-agent-base.yaml \
  collector/fragments/receivers/otlp.yaml \
  collector/fragments/processors/memory-limiter.yaml \
  collector/fragments/processors/batch.yaml \
  collector/fragments/exporters/otlp-grpc.yaml
```

---

## Golden Configs — Deploy in Minutes

Pre-assembled, production-ready configurations for the most common enterprise scenarios. Each is a single YAML file with inline documentation.

| Config | Platform | Backend | Environment | Cost Reduction |
|--------|----------|---------|-------------|----------------|
| [`aws-datadog-production.yaml`](golden-configs/aws-datadog-production.yaml) | AWS EKS | Datadog | Production | 60-80% |
| [`aws-grafana-cloud-staging.yaml`](golden-configs/aws-grafana-cloud-staging.yaml) | AWS EKS | Grafana Cloud | Staging | 30-50% |
| [`azure-aks-elastic-production.yaml`](golden-configs/azure-aks-elastic-production.yaml) | Azure AKS | Elastic | Production | 60-80% |
| [`azure-aks-dynatrace-production.yaml`](golden-configs/azure-aks-dynatrace-production.yaml) | Azure AKS | Dynatrace | Production | 60-80% |
| [`gcp-gke-native-production.yaml`](golden-configs/gcp-gke-native-production.yaml) | GCP GKE | GCP Cloud Ops | Production | 60-80% |
| [`k8s-grafana-lgtm-dev.yaml`](golden-configs/k8s-grafana-lgtm-dev.yaml) | Generic K8s | Grafana LGTM | Development | ~0% |
| [`k8s-signoz-staging.yaml`](golden-configs/k8s-signoz-staging.yaml) | Generic K8s | SigNoz | Staging | 30-50% |
| [`onprem-splunk-production.yaml`](golden-configs/onprem-splunk-production.yaml) | On-prem VMs | Splunk | Production | 60-80% |
| [`aws-newrelic-production.yaml`](golden-configs/aws-newrelic-production.yaml) | AWS EKS | New Relic | Production | 60-80% |
| [`multi-backend-production.yaml`](golden-configs/multi-backend-production.yaml) | Generic K8s | Grafana Cloud + S3 | Production | 60-80% |

> See [`golden-configs/README.md`](golden-configs/README.md) for detailed usage and customization guide.

---

## Operational Documentation

### Tuning & Optimization

| Guide | What It Covers |
|-------|---------------|
| **[Tuning Guide](docs/tuning-guide.md)** | Collector sizing tables, batch/queue/memory tuning, processor CPU cost table, sampling strategy with cost math, exporter compression, topology decision tree, backend pricing ROI |

### Runbooks

Step-by-step guides for day-2 OTel Collector operations, each following **Symptoms → Diagnosis → Resolution → Prevention**.

| Runbook | When to Use |
|---------|-------------|
| [Collector High Memory](docs/runbooks/collector-high-memory.md) | OOMKilled, memory pressure |
| [Collector Dropping Data](docs/runbooks/collector-dropping-data.md) | Queue full, send failures |
| [Collector High CPU](docs/runbooks/collector-high-cpu.md) | CPU throttling, latency spikes |
| [Pipeline Latency](docs/runbooks/pipeline-latency.md) | Delayed traces, slow exports |
| [Exporter Auth Failures](docs/runbooks/exporter-auth-failures.md) | 401/403 errors, token expiry |
| [Scaling Collectors](docs/runbooks/scaling-collectors.md) | Capacity planning, horizontal scaling |
| [Upgrade Collector](docs/runbooks/upgrade-collector.md) | Version upgrades, rollback |

### Secret Management

| Guide | Platform |
|-------|----------|
| [Kubernetes Secrets](docs/secrets/kubernetes-secrets.md) | Any K8s cluster |
| [Vault Integration](docs/secrets/vault-integration.md) | HashiCorp Vault |
| [AWS Secrets](docs/secrets/aws-secrets.md) | AWS EKS (IRSA + Secrets Manager) |
| [Azure Key Vault](docs/secrets/azure-keyvault.md) | Azure AKS (Managed Identity) |

### Collector Self-Monitoring

| Resource | Description |
|----------|-------------|
| [Grafana Dashboard](dashboards/collector-health.json) | 19-panel dashboard: CPU, memory, receivers, processors, exporters, pipeline throughput |
| [Prometheus Alerts](dashboards/collector-alerts.yaml) | 6 alert rules: high memory, CPU, exporter failures, data drops, queue saturation |

### Kubernetes Deployment

One-command deployment of the full collector stack to any Kubernetes cluster.

```bash
# Deploy with defaults (namespace: observability)
./deploy/quick-start.sh

# Custom backend and cluster name
BACKEND_OTLP_ENDPOINT=tempo.monitoring:4317 \
K8S_CLUSTER_NAME=prod-us-east \
./deploy/quick-start.sh

# Check status
./deploy/quick-start.sh status

# Run end-to-end tests
./deploy/test-telemetry.sh

# Tear down
./deploy/quick-start.sh --delete
```

**What gets deployed:**

```
Namespace: observability
├── otel-agent (DaemonSet)          1 per node — OTLP, hostmetrics, kubeletstats, filelog
├── otel-gateway (Deployment)       2-10 replicas — tail sampling, batching, export to backend
├── otel-cluster-receiver (Deployment)  1 replica — cluster metrics + K8s events
├── NetworkPolicy                   Default-deny + scoped OTLP/health/metrics access
├── HPA                             Auto-scale gateway on CPU/memory
└── PDB                             Guarantee ≥1 gateway pod during disruptions
```

| Config Variable | Default | Description |
|-----------------|---------|-------------|
| `OTEL_NAMESPACE` | `observability` | Kubernetes namespace |
| `BACKEND_OTLP_ENDPOINT` | `localhost:4317` | Backend OTLP gRPC endpoint |
| `K8S_CLUSTER_NAME` | `my-cluster` | Cluster name in resource attributes |
| `DEPLOYMENT_ENVIRONMENT` | `production` | Environment label |
| `GATEWAY_REPLICAS` | `2` | Initial gateway replicas |
| `OTEL_COLLECTOR_VERSION` | `0.96.0` | Collector image tag |

**Alternative deployment methods:** [Helm](platforms/kubernetes/helm/), [Kustomize](examples/full-stack-aws-eks/), [OTel Operator](platforms/kubernetes/operator/)

> See [`deploy/README.md`](deploy/README.md) for full configuration reference, backend auth setup, NetworkPolicy details, and troubleshooting.

### Infrastructure as Code (Terraform)

Terraform modules for the IAM roles, secrets, and storage the collector needs before Helm deploys it.

```bash
# 1. Provision IAM + secrets (one-time per cluster)
cd terraform/aws && terraform apply -var="cluster_name=prod-us-east-1" ...

# 2. Deploy collector with the role ARN from Terraform
helm install otel-collector open-telemetry/opentelemetry-collector \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw irsa_role_arn)
```

| Module | Creates |
|--------|---------|
| [`terraform/aws/`](terraform/aws/) | IRSA role, X-Ray + CloudWatch + S3 policies, Secrets Manager |
| [`terraform/azure/`](terraform/azure/) | Managed Identity + Workload Identity, Key Vault, Monitor roles |
| [`terraform/gcp/`](terraform/gcp/) | Service Account + Workload Identity, Cloud Trace/Monitoring/Logging roles, Secret Manager |

> See [`terraform/README.md`](terraform/README.md) for full variable reference, outputs, and end-to-end workflow.

---

## Quickstart Flowchart

```
1. Pick your platform          -->  platforms/{aws,azure,gcp,kubernetes,onprem}/
2. Choose deployment tier      -->  agent / gateway / agent+gateway / agent+LB+gateway
3. Select backend              -->  backends/{grafana-cloud,datadog,elastic,splunk,newrelic,...}/
                                    (15 platforms + 6 self-hosted options)
4. Choose instrumentation      -->  OBI (eBPF) first, then auto-instrumentation, then SDK
                                    (see decision tree above)
5. Apply cost profile          -->  Production / Staging / Dev
                                    (see Cost Optimization section above)
6. Add sampling strategy       -->  sampling/{tail,head,composite,...}
7. Enable auto-instrumentation -->  auto-instrumentation/{java,python,nodejs,...}
8. Validate & deploy           -->  make validate && make dev-up
```

## Architecture: Fragment-Based Composition

The core design principle is **composable fragments** — small, reusable YAML snippets for each OTel Collector component. A consultant merges fragments to produce a complete collector config:

```
base config + receiver fragments + processor fragments + exporter fragments = complete config
```

Use the OTel Collector's native `--config` multi-file support:

```bash
otelcol --config=collector/base/otel-agent-base.yaml \
        --config=collector/fragments/receivers/otlp.yaml \
        --config=collector/fragments/receivers/hostmetrics.yaml \
        --config=collector/fragments/processors/batch.yaml \
        --config=collector/fragments/exporters/otlp-grpc.yaml
```

Or use the OllyStack CLI:

```bash
./bin/ollystack merge -o merged-config.yaml \
  collector/base/otel-agent-base.yaml \
  collector/fragments/receivers/otlp.yaml \
  collector/fragments/processors/batch.yaml \
  collector/fragments/exporters/otlp-grpc.yaml
```

### Three Deployment Tiers

| Tier | Role | Deployment | Use Case |
|------|------|------------|----------|
| **Agent** | Lightweight local collector | DaemonSet / host service | Collect host/container telemetry |
| **Load Balancer** | Trace-aware routing | Deployment (2+ replicas) | Route by traceID for tail sampling |
| **Gateway** | Centralized processing | Deployment + HPA | Sampling, enrichment, export to backends |

## Directory Structure

```
OllyStack/
├── bin/ollystack                    # CLI config generator
├── golden-configs/                  # 10 pre-assembled deploy-ready configs
├── collector/
│   ├── builder/manifest.yaml        # Custom collector build (OCB)
│   ├── base/                        # Foundation configs (agent, gateway)
│   └── fragments/                   # Composable YAML snippets
│       ├── receivers/               # 152 data ingestion fragments (OTLP, cloud, DB, network, AI/ML, security)
│       ├── processors/              # 40 transform, filter, sample, enrich, security fragments
│       ├── exporters/               # 39 backend export fragments
│       ├── extensions/              # 8 auth, health, diagnostics fragments
│       └── connectors/              # 6 cross-pipeline bridge fragments
├── platforms/                       # Platform-specific deployments
│   ├── aws/                         # EKS, ECS, EC2, Lambda
│   ├── azure/                       # AKS, VMs, Functions, App Service
│   ├── gcp/                         # GKE, Compute Engine, Cloud Run, Cloud Functions
│   ├── kubernetes/                  # Generic K8s (any distro)
│   └── onprem/                      # Linux (systemd) + Windows
├── terraform/
│   ├── aws/                         # IRSA, Secrets Manager, CloudWatch, S3
│   ├── azure/                       # Managed Identity, Key Vault, Monitor roles
│   └── gcp/                         # Workload Identity, Secret Manager, IAM
├── docs/
│   ├── tuning-guide.md              # Sizing, batch, queue, sampling, cost math
│   ├── runbooks/                    # 7 operational runbooks
│   └── secrets/                     # 4 secret management guides
├── deploy/
│   ├── quick-start.sh               # One-command K8s deployment
│   ├── networkpolicy.yaml           # Namespace security isolation (5 policies)
│   └── test-telemetry.sh            # End-to-end telemetry test suite
├── dashboards/
│   ├── collector-health.json        # Grafana dashboard (19 panels)
│   └── collector-alerts.yaml        # Prometheus alert rules (6 alerts)
├── sampling/                        # Sampling strategies
├── topologies/                      # Deployment topologies
├── auto-instrumentation/            # Language-specific auto-instrumentation
├── backends/                        # 15 backend configs (AWS, Azure, GCP, Datadog, Splunk, ...)
├── examples/                        # Full-stack examples
├── dev/                             # Local development (Docker Compose)
└── scripts/                         # Utility scripts
```

## Key Design Decisions

- **`${ENV_VAR}` parameterization** — all configs are portable across environments
- **Fragment-based composition** — no monolithic configs; use `--config` multi-file support
- **Backend-agnostic core** — exporters live in `backends/`, swap anytime
- **Profiling included** — future-proofed for OTel profiling signal
- **IaC for every platform** — Helm, Terraform, CloudFormation, ARM/Bicep, Ansible

## Verification

```bash
make validate              # Validate all collector YAML configs
make lint                  # YAML lint all files
make dev-up                # Start local dev stack (Collector + Jaeger + Prometheus + Grafana)
make dev-down              # Tear down dev stack
make generate-telemetry    # Generate sample telemetry for testing
```

## Requirements

- [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) v0.96+
- [yq](https://github.com/mikefarah/yq) v4+ (for config merging)
- [yamllint](https://github.com/adrienverdelhan/yamllint) (for linting)
- Docker & Docker Compose (for local dev)
- Helm 3+ (for Kubernetes deployments)

## License

Proprietary — OllyStack Consulting. All rights reserved.
