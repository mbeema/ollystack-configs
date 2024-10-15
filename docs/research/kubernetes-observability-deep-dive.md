# Kubernetes Observability Deep Dive: Comprehensive Consulting Knowledge Base

## Executive Summary

Kubernetes observability encompasses the full spectrum of visibility into containerized workloads: from infrastructure metrics and container logs to distributed traces, security events, cost attribution, and GitOps deployment tracking. With **82% of organizations running Kubernetes in production** (CNCF 2025) and observability costs cited as the **#1 concern**, mastering Kubernetes observability is essential for enterprise consulting engagements.

This document provides a complete technical reference covering metrics architecture, logging patterns, OpenTelemetry integration, service mesh observability, eBPF instrumentation, cost management, security monitoring, troubleshooting workflows, multi-cluster federation, and production operations -- with specific metric names, PromQL queries, YAML configurations, and 2024-2025 industry statistics.

---

## Table of Contents

1. [Kubernetes Metrics Architecture](#1-kubernetes-metrics-architecture)
2. [Kubernetes Logging Architecture](#2-kubernetes-logging-architecture)
3. [Kubernetes Events and Resource Observability](#3-kubernetes-events-and-resource-observability)
4. [Health Checks and Probes](#4-health-checks-and-probes)
5. [Golden Signals for Kubernetes](#5-golden-signals-for-kubernetes)
6. [Dashboard and Visualization Patterns](#6-dashboard-and-visualization-patterns)
7. [OpenTelemetry Operator for Kubernetes](#7-opentelemetry-operator-for-kubernetes)
8. [OTel Auto-Instrumentation in Kubernetes](#8-otel-auto-instrumentation-in-kubernetes)
9. [Kubernetes Attributes Processor](#9-kubernetes-attributes-processor)
10. [Kubernetes OTel Receivers](#10-kubernetes-otel-receivers)
11. [Service Mesh Observability](#11-service-mesh-observability)
12. [eBPF-Based Kubernetes Observability](#12-ebpf-based-kubernetes-observability)
13. [Network Observability](#13-network-observability)
14. [Kubernetes Cost Observability](#14-kubernetes-cost-observability)
15. [Kubernetes Security Observability](#15-kubernetes-security-observability)
16. [GitOps Observability](#16-gitops-observability)
17. [Kubernetes Troubleshooting with Observability](#17-kubernetes-troubleshooting-with-observability)
18. [Multi-Cluster and Multi-Tenant Observability](#18-multi-cluster-and-multi-tenant-observability)
19. [Production Operations and Best Practices](#19-production-operations-and-best-practices)
20. [Market and Adoption Statistics (2024-2025)](#20-market-and-adoption-statistics-2024-2025)
21. [Reference Architecture](#21-reference-architecture)

---

## 1. Kubernetes Metrics Architecture

### 1.1 The Metrics Pipeline

The Kubernetes metrics pipeline follows a layered architecture:

```
cAdvisor (embedded in kubelet)
  → kubelet /metrics endpoints
    → metrics-server (for kubectl top / HPA)
    → kube-state-metrics (object state as metrics)
      → Prometheus / OTel Collector (collection & storage)
```

### 1.2 cAdvisor Metrics (Container-Level)

cAdvisor is embedded in the kubelet since Kubernetes 1.12. It auto-discovers all containers on a node and exposes metrics at `/metrics/cadvisor` on port 10250.

**CPU Metrics:**
```
container_cpu_usage_seconds_total              # Cumulative CPU time consumed
container_cpu_user_seconds_total               # Cumulative user CPU time
container_cpu_system_seconds_total             # Cumulative system CPU time
container_cpu_cfs_periods_total                # Elapsed CFS enforcement intervals
container_cpu_cfs_throttled_periods_total       # Throttled CFS periods
container_cpu_cfs_throttled_seconds_total       # Total throttled duration
```

**Memory Metrics:**
```
container_memory_working_set_bytes             # What OOMKiller uses (KEY metric)
container_memory_usage_bytes                   # Includes cache (misleading)
container_memory_rss                           # Resident Set Size
container_memory_cache                         # Page cache
container_memory_swap                          # Swap usage
container_memory_failcnt                       # Memory limit hit count
```

**Network Metrics:**
```
container_network_receive_bytes_total          # Bytes received
container_network_receive_packets_total        # Packets received
container_network_receive_errors_total         # Receive errors
container_network_receive_packets_dropped_total # Received packets dropped
container_network_transmit_bytes_total         # Bytes transmitted
container_network_transmit_packets_total       # Packets transmitted
container_network_transmit_errors_total        # Transmit errors
container_network_transmit_packets_dropped_total # Transmitted packets dropped
```

**Filesystem Metrics:**
```
container_fs_usage_bytes                       # Bytes consumed on filesystem
container_fs_limit_bytes                       # Filesystem limit
container_fs_reads_total / writes_total        # I/O operation counts
container_fs_read_bytes_total / write_bytes_total # I/O byte counts
container_fs_io_current                        # I/Os currently in progress
```

**Labels:** `container`, `pod`, `namespace`, `image`, `id`, `name`

### 1.3 Kubelet Metrics Endpoints

The kubelet exposes four distinct endpoints:

| Endpoint | Purpose | Key Metrics |
|----------|---------|-------------|
| `/metrics` | Kubelet operational metrics | `kubelet_running_pods`, `kubelet_pod_start_duration_seconds`, `kubelet_pleg_relist_duration_seconds`, `kubelet_volume_stats_*`, `kubelet_evictions` |
| `/metrics/cadvisor` | Container resource usage | All `container_*` metrics above |
| `/metrics/probes` | Health probe results | `prober_probe_total`, `prober_probe_duration_seconds` |
| `/metrics/resource` | Resource metrics (since 1.18) | `node_cpu_usage_seconds_total`, `node_memory_working_set_bytes`, `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes` |

### 1.4 kube-state-metrics (KSM)

KSM v2.13+ listens to the Kubernetes API server and generates metrics about object *desired state* and *current state* (not resource usage).

**Pod Metrics:**
```
kube_pod_info{pod,namespace,host_ip,pod_ip,node,created_by_kind,uid}
kube_pod_status_phase{phase}                   # Pending, Running, Succeeded, Failed, Unknown
kube_pod_status_ready{condition}               # true, false, unknown
kube_pod_container_status_running / waiting / terminated
kube_pod_container_status_waiting_reason{reason}
  # CrashLoopBackOff, ErrImagePull, ImagePullBackOff, CreateContainerConfigError
kube_pod_container_status_terminated_reason{reason}
  # OOMKilled, Error, Completed, ContainerCannotRun, Evicted
kube_pod_container_status_restarts_total
kube_pod_container_resource_requests{resource,unit}
kube_pod_container_resource_limits{resource,unit}
kube_pod_owner{owner_kind,owner_name}
kube_pod_labels / kube_pod_annotations
```

**Deployment Metrics:**
```
kube_deployment_spec_replicas
kube_deployment_status_replicas_available / unavailable / updated / ready
kube_deployment_status_condition{condition,status}
  # Available, Progressing, ReplicaFailure
kube_deployment_metadata_generation / status_observed_generation
```

**StatefulSet Metrics:**
```
kube_statefulset_replicas / status_replicas_ready / current / updated
kube_statefulset_status_current_revision / update_revision
```

**DaemonSet Metrics:**
```
kube_daemonset_status_desired_number_scheduled / current / available
kube_daemonset_status_number_misscheduled / unavailable / ready
```

**Job / CronJob Metrics:**
```
kube_job_status_active / succeeded / failed
kube_job_status_start_time / completion_time
kube_cronjob_status_active / last_schedule_time / last_successful_time
kube_cronjob_next_schedule_time
```

**Node Metrics:**
```
kube_node_info{kernel_version,os_image,container_runtime_version,kubelet_version}
kube_node_status_condition{condition,status}
  # Ready, MemoryPressure, DiskPressure, PIDPressure, NetworkUnavailable
kube_node_status_capacity{resource,unit}       # cpu, memory, pods, ephemeral_storage
kube_node_status_allocatable{resource,unit}
kube_node_spec_unschedulable / taint
```

**PVC / PV Metrics:**
```
kube_persistentvolumeclaim_status_phase{phase}  # Pending, Bound, Lost
kube_persistentvolumeclaim_resource_requests_storage_bytes
kube_persistentvolume_status_phase{phase}       # Available, Bound, Released, Failed
kube_persistentvolume_capacity_bytes
```

**HPA Metrics:**
```
kube_horizontalpodautoscaler_spec_min_replicas / max_replicas
kube_horizontalpodautoscaler_status_current_replicas / desired_replicas
kube_horizontalpodautoscaler_status_condition{condition}
  # AbleToScale, ScalingActive, ScalingLimited
```

**ResourceQuota / Namespace / Service / Ingress / NetworkPolicy:**
```
kube_resourcequota{resource,type}              # type: hard, used
kube_namespace_status_phase{phase}             # Active, Terminating
kube_service_info / spec_type
kube_ingress_info / path / tls
kube_networkpolicy_spec_ingress_rules / egress_rules
```

### 1.5 metrics-server vs Prometheus vs Custom Metrics API

| Feature | metrics-server | Prometheus | Custom Metrics API |
|---------|---------------|------------|-------------------|
| **Purpose** | `kubectl top`, HPA CPU/memory | Full time-series DB | HPA on any metric |
| **Storage** | Latest value only (in-memory) | Historical time-series | Adapter layer |
| **Memory** | ~40MB / 100 nodes | 1-2GB / 100K series | Varies |
| **API** | `metrics.k8s.io/v1beta1` | PromQL | `custom.metrics.k8s.io` |
| **Retention** | None | Days to years | None (delegates) |
| **Status** | Required for HPA | CNCF Graduated, 54K+ stars | KEDA (CNCF Graduated 2024) |

**Prometheus 3.0** (Nov 2024): Native histograms, UTF-8 metric names, OTLP ingestion endpoint, remote write 2.0.

### 1.6 Node-Level Metrics (node_exporter)

Prometheus node_exporter (v1.8+) runs as a DaemonSet, exposing hardware/OS metrics:

```
# CPU
node_cpu_seconds_total{cpu,mode}           # mode: user,system,idle,iowait,irq,steal
node_load1 / node_load5 / node_load15
node_pressure_cpu_waiting_seconds_total    # PSI CPU pressure (Linux 4.20+)

# Memory
node_memory_MemTotal_bytes / MemFree_bytes / MemAvailable_bytes
node_memory_Buffers_bytes / Cached_bytes / SwapTotal_bytes / SwapFree_bytes
node_pressure_memory_waiting_seconds_total

# Disk
node_disk_io_time_seconds_total{device}
node_disk_read_bytes_total / written_bytes_total
node_disk_reads_completed_total / writes_completed_total
node_pressure_io_waiting_seconds_total

# Filesystem
node_filesystem_size_bytes{mountpoint,device,fstype}
node_filesystem_free_bytes / avail_bytes
node_filesystem_files / files_free          # Inodes

# Network
node_network_receive_bytes_total{device} / transmit_bytes_total
node_network_receive_errs_total / transmit_errs_total
node_network_speed_bytes / up / mtu_bytes
node_nf_conntrack_entries / entries_limit
```

### 1.7 Control Plane Metrics

**API Server (kube-apiserver):**
```
apiserver_request_total{verb,resource,code}
apiserver_request_duration_seconds_bucket{verb,resource}
apiserver_current_inflight_requests{request_kind}   # mutating, readOnly
apiserver_dropped_requests_total{request_kind}
apiserver_flowcontrol_dispatched_requests_total{flow_schema,priority_level}
apiserver_flowcontrol_rejected_requests_total
apiserver_admission_webhook_admission_duration_seconds_bucket
apiserver_audit_event_total
```

**etcd:**
```
etcd_server_has_leader                             # Must always be 1
etcd_server_leader_changes_seen_total              # Should be very low
etcd_server_proposals_committed_total / pending / failed_total
etcd_disk_wal_fsync_duration_seconds_bucket         # Critical: >100ms is warning
etcd_disk_backend_commit_duration_seconds_bucket
etcd_mvcc_db_total_size_in_bytes                   # Default quota: 2GB, max 8GB
etcd_network_peer_round_trip_time_seconds_bucket
```

**Scheduler (kube-scheduler):**
```
scheduler_schedule_attempts_total{result}           # scheduled, unschedulable, error
scheduler_scheduling_attempt_duration_seconds_bucket
scheduler_pending_pods{queue}                       # active, backoff, unschedulable
scheduler_preemption_attempts_total
```

**Controller Manager:**
```
workqueue_adds_total{name} / depth / queue_duration_seconds_bucket
workqueue_work_duration_seconds_bucket / retries_total
node_collector_evictions_total{zone}
leader_election_master_status{name}
```

---

## 2. Kubernetes Logging Architecture

### 2.1 Container Log Path and Lifecycle

```
Application stdout/stderr
  → Container Runtime (containerd/CRI-O)
    → /var/log/pods/<namespace>_<pod-name>_<pod-uid>/<container-name>/<restart-count>.log
      → Symlinked from /var/log/containers/<pod-name>_<namespace>_<container-name>-<id>.log
```

**CRI log format:**
```
2024-11-15T14:32:01.123456789Z stdout F This is a complete log line
2024-11-15T14:32:01.123456789Z stderr P This is a partial log li
2024-11-15T14:32:01.123456790Z stderr F ne that was split
```
Format: `<timestamp> <stream> <tag> <message>` -- `F` = full line, `P` = partial

### 2.2 Log Rotation and Retention

```yaml
# kubelet configuration
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
containerLogMaxSize: "10Mi"       # Default: 10MB per log file
containerLogMaxFiles: 5            # Default: 5 rotated files per container
```

Default = **50MB max per container** (5 x 10MB). When a pod is deleted, all logs are immediately deleted. Log forwarding agents are essential.

### 2.3 Node-Level Logging Agents (DaemonSet Pattern)

**OTel Collector as DaemonSet** (recommended):

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/*/*.log
    exclude:
      - /var/log/pods/*/otc-container/*.log
    start_at: end
    include_file_path: true
    operators:
      - type: router
        id: get-format
        routes:
          - output: parser-cri
            expr: 'body matches "^[^ Z]+ "'
      - type: regex_parser
        id: parser-cri
        regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout_type: gotime
          layout: '2006-01-02T15:04:05.999999999Z07:00'
      - type: regex_parser
        id: extract-metadata-from-filepath
        regex: '^.*\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[a-f0-9\-]+)\/(?P<container_name>[^\._]+)\/(?P<restart_count>\d+)\.log$'
        parse_from: attributes["log.file.path"]
      - type: move
        from: attributes.namespace
        to: resource["k8s.namespace.name"]
      - type: move
        from: attributes.pod_name
        to: resource["k8s.pod.name"]
      - type: move
        from: attributes.container_name
        to: resource["k8s.container.name"]
```

**Agent comparison:**
| Agent | Language | Memory Footprint | Strengths |
|-------|----------|-----------------|-----------|
| **Fluent Bit** | C | 128-256MB | CNCF Graduated, lowest resource usage |
| **OTel Collector** | Go | 256-512MB | Unified pipeline (metrics+logs+traces) |
| **Vector** | Rust | 256-512MB | High throughput, VRL transform language |
| **Fluentd** | Ruby | 512MB-1GB | Plugin ecosystem, legacy support |

### 2.4 Sidecar Logging Pattern

Use when: application writes to files (not stdout), different log streams need different pipelines, or multi-tenant isolation. **Trade-off:** ~50-128MB memory per pod vs single DaemonSet per node.

### 2.5 Kubernetes Audit Logs

Four audit levels:

| Level | Records | Performance Impact |
|-------|---------|-------------------|
| `None` | Nothing | None |
| `Metadata` | User, timestamp, resource, verb | Low |
| `Request` | Metadata + request body | Medium |
| `RequestResponse` | Metadata + request + response body | High |

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
  - level: None
    verbs: ["watch"]
  - level: Metadata
    resources:
      - group: ""
        resources: ["secrets", "configmaps", "tokenreviews"]
  - level: Request
    resources:
      - group: ""
        resources: ["pods", "pods/log"]
    verbs: ["create", "update", "patch", "delete"]
  - level: Metadata
    omitStages: ["RequestReceived"]
```

### 2.6 Structured Logging (KEP-3077)

GA in Kubernetes 1.27. All components support JSON output via `--logging-format=json`:
```json
{"ts":1700000000.000,"caller":"server.go:123","msg":"Starting API server","v":0}
```

### 2.7 Multi-Tenant Log Isolation

```yaml
# Loki multi-tenancy via OTel Collector
processors:
  attributes:
    actions:
      - key: loki.tenant
        from_attribute: k8s.namespace.name
        action: upsert
```

---

## 3. Kubernetes Events and Resource Observability

### 3.1 Key Events by Category

**Pod Lifecycle:**
| Event Reason | Type | Description |
|-------------|------|-------------|
| `Scheduled` | Normal | Pod assigned to node |
| `FailedScheduling` | Warning | No nodes available |
| `Pulling` / `Pulled` | Normal | Image pull lifecycle |
| `Created` / `Started` | Normal | Container lifecycle |
| `BackOff` | Warning | CrashLoopBackOff |
| `Unhealthy` | Warning | Probe failure |
| `OOMKilling` | Warning | Container OOM killed |
| `EvictionThresholdMet` | Warning | Node eviction triggered |

**Node Events:** `NodeReady`, `NodeNotReady`, `NodeHasSufficientMemory`, `SystemOOM`
**Volume Events:** `SuccessfulAttachVolume`, `FailedMount`, `VolumeResizeFailed`
**Deployment Events:** `ScalingReplicaSet`, `SuccessfulCreate`, `FailedCreate`
**HPA Events:** `SuccessfulRescale`, `FailedComputeMetricsReplicas`

### 3.2 Events TTL and Persistence

- Default TTL: **1 hour** (configurable via `--event-ttl`)
- Events are deduplicated by incrementing `count` and updating `lastTimestamp`
- Persistence strategies: Event Exporter to Loki/ES, k8sobjects OTel receiver, custom controllers

### 3.3 Resource Quota Monitoring

```promql
# Quota usage approaching limits (>80%)
(kube_resourcequota{type="used"} / kube_resourcequota{type="hard"}) > 0.8
```

### 3.4 PVC/PV Monitoring

```promql
# PVC space >85% used
(kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes) > 0.85

# Unbound PVCs
kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1

# PV in Released/Failed state
kube_persistentvolume_status_phase{phase=~"Released|Failed"} == 1
```

---

## 4. Health Checks and Probes

### 4.1 Probe Types

| Probe | Purpose | On Failure |
|-------|---------|-----------|
| **Liveness** | Is container running? | Kubelet kills container |
| **Readiness** | Can container serve traffic? | Removed from Service endpoints |
| **Startup** | Has container started? (GA 1.20) | Blocks other probes |

**Mechanisms:** `httpGet` (200-399), `tcpSocket` (port open), `exec` (exit 0), `grpc` (GA 1.27)

### 4.2 Probe Metrics

```promql
# Probe failure rate
rate(prober_probe_total{result="failed"}[5m])

# Slow probes (>1s average)
(rate(prober_probe_duration_seconds_sum[5m]) / rate(prober_probe_duration_seconds_count[5m])) > 1
```

### 4.3 Common Anti-Patterns

1. **Liveness checks dependencies** -- if DB is down, all pods killed. Fix: liveness checks process only
2. **Missing startup probe** -- JVM needs 60s but liveness starts at 15s. Fix: add startup probe
3. **Timeout too aggressive** -- 1s default is too tight. Fix: set 3-5s timeouts
4. **Same endpoint for liveness and readiness** -- different semantics needed. Fix: `/livez` vs `/readyz`
5. **Exec probes with expensive operations** -- database queries as liveness. Fix: lightweight checks

---

## 5. Golden Signals for Kubernetes

### 5.1 Per-Pod

```promql
# CPU usage rate (cores)
rate(container_cpu_usage_seconds_total{container!="", container!="POD"}[5m])

# CPU throttling percentage (KEY: >25% = performance degradation)
rate(container_cpu_cfs_throttled_periods_total{container!=""}[5m])
  / rate(container_cpu_cfs_periods_total{container!=""}[5m]) * 100

# Memory working set (what OOMKiller uses)
container_memory_working_set_bytes{container!="", container!="POD"}

# Memory as % of limit (>90% = OOMKill risk)
container_memory_working_set_bytes / on(namespace,pod,container)
  kube_pod_container_resource_limits{resource="memory"} * 100

# OOM killed containers
kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}

# Container restart rate
rate(kube_pod_container_status_restarts_total[1h])

# Pods in CrashLoopBackOff
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} > 0

# Network I/O and errors
rate(container_network_receive_bytes_total{pod!=""}[5m])
rate(container_network_receive_errors_total{pod!=""}[5m])
```

### 5.2 Per-Deployment

```promql
# Replicas mismatch (desired vs available)
kube_deployment_spec_replicas - kube_deployment_status_replicas_available

# Stuck rollout (>10 min)
(kube_deployment_spec_replicas != kube_deployment_status_replicas_available)
  and (changes(kube_deployment_status_replicas_updated[10m]) == 0)

# Deployment not progressing
kube_deployment_status_condition{condition="Progressing", status="false"} == 1
```

### 5.3 Per-Node

```promql
# CPU allocation ratio (overcommitment)
sum by (node) (kube_pod_container_resource_requests{resource="cpu"})
  / on(node) kube_node_status_allocatable{resource="cpu"} * 100

# Node conditions
kube_node_status_condition{condition="Ready", status="true"} == 0           # NOT Ready
kube_node_status_condition{condition="MemoryPressure", status="true"} == 1
kube_node_status_condition{condition="DiskPressure", status="true"} == 1
kube_node_status_condition{condition="PIDPressure", status="true"} == 1

# Actual CPU utilization
1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))

# Actual memory utilization
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

### 5.4 Per-Cluster

```promql
# API server error rate
sum(rate(apiserver_request_total{code=~"5.."}[5m]))
  / sum(rate(apiserver_request_total[5m])) * 100

# API server latency (p99, non-streaming)
histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!~"WATCH|CONNECT"}[5m])) by (le))

# etcd has leader (must be 1)
etcd_server_has_leader == 1

# etcd WAL fsync p99 (>10ms concerning, >100ms critical)
histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))

# etcd database size vs quota
etcd_mvcc_db_total_size_in_bytes / (2 * 1024 * 1024 * 1024) * 100
```

### 5.5 Per-Namespace

```promql
# Resource quota utilization
kube_resourcequota{type="used"} / kube_resourcequota{type="hard"} * 100

# OOMKills per namespace
sum by (namespace) (kube_pod_container_status_last_terminated_reason{reason="OOMKilled"})

# Container restarts per namespace (last hour)
sum by (namespace) (increase(kube_pod_container_status_restarts_total[1h]))
```

---

## 6. Dashboard and Visualization Patterns

### 6.1 Cluster Overview Dashboard (19-Panel Design)

**Row 1: Health Summary (stat panels)**
- Total Nodes / Ready Nodes
- Total Pods / Running Pods
- Pending Pods, Failed Pods
- Container Restarts (24h), OOMKills (24h)

**Row 2: API Server & etcd**
- API server request rate by verb (time series)
- API server error rate % (time series)
- API server latency p50/p95/p99 (time series)
- etcd database size (gauge)
- etcd WAL fsync latency (time series)
- etcd leader changes 24h (stat)

**Row 3: Cluster Resource Utilization**
- Cluster CPU utilization (gauge + time series)
- Cluster memory utilization (gauge + time series)
- CPU requests vs allocatable per node (stacked bar)
- Memory requests vs allocatable per node (stacked bar)

**Row 4: Top Consumers**
- Top 10 CPU-consuming pods (bar chart)
- Top 10 memory-consuming pods (bar chart)
- Top 10 most-restarting pods (table)

### 6.2 Namespace Drill-Down Dashboard

Template variable: `$namespace` = `label_values(kube_namespace_status_phase{phase="Active"}, namespace)`

Panels: Pod status pie chart, resource quota table, deployments status table, CPU/memory by pod, network I/O, PVC usage.

### 6.3 Workload-Specific Dashboards

**Deployment:** Replica status over time, rollout status, per-pod CPU/memory, HPA scaling events.
**StatefulSet:** Per-pod PVC usage, ordinal status, rolling update revision.
**DaemonSet:** Per-node scheduling status, misscheduled nodes.
**Job/CronJob:** Success/failure rate, duration, missed schedules:
```promql
# Overdue CronJobs
kube_cronjob_next_schedule_time < time()
```

### 6.4 Capacity Planning Dashboard

```promql
# Predict CPU requests 30 days from now
predict_linear(sum(kube_pod_container_resource_requests{resource="cpu"})[7d:1h], 30*24*3600)

# Request-to-usage ratio (right-sizing indicator)
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m]))
  / sum(kube_pod_container_resource_requests{resource="cpu"})
```

---

## 7. OpenTelemetry Operator for Kubernetes

### 7.1 Installation

```bash
# Prerequisites: cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml

# Install OTel Operator via Helm
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace opentelemetry-operator-system \
  --create-namespace \
  --set admissionWebhooks.certManager.enabled=true \
  --set manager.collectorImage.repository=otel/opentelemetry-collector-contrib
```

CRDs provided: **OpenTelemetryCollector**, **Instrumentation**, **OpAMPBridge**

### 7.2 Deployment Modes

#### DaemonSet Mode (Node-Level Collection)

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-agent
spec:
  mode: daemonset
  image: otel/opentelemetry-collector-contrib:0.115.0
  env:
    - name: K8S_NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
  resources:
    requests: { cpu: 200m, memory: 256Mi }
    limits: { cpu: "1", memory: 1Gi }
  volumes:
    - name: varlogpods
      hostPath: { path: /var/log/pods }
  volumeMounts:
    - name: varlogpods
      mountPath: /var/log/pods
      readOnly: true
  config:
    receivers:
      filelog:
        include: ["/var/log/pods/*/*/*.log"]
      kubeletstats:
        collection_interval: 20s
        auth_type: serviceAccount
        endpoint: "https://${env:K8S_NODE_NAME}:10250"
        insecure_skip_verify: true
        metric_groups: [node, pod, container, volume]
      hostmetrics:
        collection_interval: 30s
        scrapers: { cpu: {}, disk: {}, filesystem: {}, load: {}, memory: {}, network: {} }
      otlp:
        protocols:
          grpc: { endpoint: 0.0.0.0:4317 }
    processors:
      k8sattributes:
        filter:
          node_from_env_var: K8S_NODE_NAME
        extract:
          metadata: [k8s.namespace.name, k8s.pod.name, k8s.node.name, k8s.deployment.name]
      memory_limiter: { limit_mib: 800, spike_limit_mib: 200, check_interval: 1s }
      batch: { send_batch_size: 10000, timeout: 5s }
    exporters:
      otlp:
        endpoint: otel-gateway.observability:4317
        tls: { insecure: true }
    service:
      pipelines:
        logs:
          receivers: [filelog]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [otlp]
        metrics:
          receivers: [kubeletstats, hostmetrics, otlp]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [otlp]
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [otlp]
```

**Best for:** Log collection, node metrics, host metrics, receiving application telemetry locally.

#### Deployment Mode (Gateway/Aggregation)

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
spec:
  mode: deployment
  replicas: 3
  resources:
    requests: { cpu: 500m, memory: 512Mi }
    limits: { cpu: "2", memory: 2Gi }
  autoscaler:
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilization: 70
  config:
    receivers:
      otlp:
        protocols:
          grpc: { endpoint: 0.0.0.0:4317 }
          http: { endpoint: 0.0.0.0:4318 }
    processors:
      memory_limiter: { limit_mib: 1800, spike_limit_mib: 500, check_interval: 1s }
      batch: { send_batch_size: 10000, timeout: 5s }
    exporters:
      otlp: { endpoint: backend.example.com:4317 }
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
```

**Best for:** Centralized processing, tail sampling, multi-backend export, HPA scaling.

#### StatefulSet Mode (Prometheus + Target Allocator)

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-prometheus
spec:
  mode: statefulset
  replicas: 3
  targetAllocator:
    enabled: true
    allocationStrategy: consistent-hashing
    prometheusCR:
      enabled: true
      serviceMonitorSelector: {}
      podMonitorSelector: {}
  config:
    receivers:
      prometheus:
        config:
          scrape_configs: []  # Managed by Target Allocator
    processors:
      batch: {}
    exporters:
      otlp: { endpoint: backend:4317 }
    service:
      pipelines:
        metrics:
          receivers: [prometheus]
          processors: [batch]
          exporters: [otlp]
```

**Best for:** Distributed Prometheus scraping, stable pod identities, PVC support.

#### Sidecar Mode (Per-Pod)

Inject via annotation: `sidecar.opentelemetry.io/inject: "otel-sidecar"`

**Best for:** Multi-tenant isolation, per-pod Collector configuration. **Trade-off:** Highest resource overhead.

**K8s 1.29+ Native Sidecars:** Operator automatically uses init containers with `restartPolicy: Always`, ensuring Collector starts before and stops after the application.

### 7.3 Sizing Guidelines

| Cluster Size | DaemonSet (agent) | Gateway (Deployment) |
|---|---|---|
| Small (<50 nodes) | 100m/128Mi per node | 250m/256Mi, 2 replicas |
| Medium (50-200 nodes) | 200m/256Mi per node | 500m/512Mi, 3-5 replicas |
| Large (200+ nodes) | 250m/256Mi per node | 1000m/1Gi, 5-10 with HPA |

**Rules of thumb:**
- `memory_limiter` = 80-90% of container memory limit
- ~500m CPU per 10,000 spans/second
- ~2KB memory per active Prometheus time series

---

## 8. OTel Auto-Instrumentation in Kubernetes

### 8.1 Instrumentation CRD

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: otel-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector.observability:4317
  propagators: [tracecontext, baggage, b3]
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.11.0
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.49b0
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.56.0
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:1.9.0
  go:
    image: ghcr.io/open-telemetry/opentelemetry-go-instrumentation/autoinstrumentation-go:v0.18.0-alpha
```

### 8.2 Injection Annotations

```yaml
# Pod or Deployment template annotations
instrumentation.opentelemetry.io/inject-java: "true"
instrumentation.opentelemetry.io/inject-python: "true"
instrumentation.opentelemetry.io/inject-nodejs: "true"
instrumentation.opentelemetry.io/inject-dotnet: "true"
instrumentation.opentelemetry.io/inject-go: "true"       # eBPF sidecar
```

Values: `"true"` (same namespace), `"name"` (specific Instrumentation), `"ns/name"` (cross-namespace), `"false"` (opt-out).

**Namespace-level:** Apply annotations to namespace metadata to instrument all pods.

### 8.3 Injection Mechanism

1. Mutating admission webhook intercepts pod creation
2. Adds init container that copies agent/SDK to shared `emptyDir` volume
3. Sets environment variables: `JAVA_TOOL_OPTIONS=-javaagent:...`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, etc.
4. **Go exception:** Uses eBPF sidecar (not init container), requires `SYS_PTRACE`, `SYS_BPF`, `shareProcessNamespace: true`

### 8.4 Resource Overhead per Language

| Language | Mechanism | Startup Overhead | CPU Overhead | Memory Overhead |
|---|---|---|---|---|
| **Java** | Javaagent bytecode | 200-500ms | 2-5% | 50-150MB |
| **Python** | Monkey-patching | 100-300ms | 3-8% | 30-80MB |
| **Node.js** | `--require` hook | 50-200ms | 2-5% | 20-50MB |
| **.NET** | CLR profiler | 100-300ms | 2-4% | 30-80MB |
| **Go** | eBPF sidecar | Minimal | 1-3% | 50-100MB |

### 8.5 Key Gotchas

- Annotations must be on `spec.template.metadata`, not `spec.metadata`
- Changing Instrumentation CRD requires pod restart (`kubectl rollout restart`)
- Go: only supports net/http, gRPC, gin, gorilla/mux, echo, database/sql; requires Linux kernel 5.x
- Python: conflicts with gevent/eventlet
- Node.js: ESM modules have limited support
- .NET AOT: cannot be auto-instrumented
- Multi-container pods: use `instrumentation.opentelemetry.io/container-names` annotation

---

## 9. Kubernetes Attributes Processor

### 9.1 Configuration

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount
    passthrough: false
    filter:
      node_from_env_var: K8S_NODE_NAME  # DaemonSet: only watch local node
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.pod.start_time
        - k8s.deployment.name
        - k8s.statefulset.name
        - k8s.daemonset.name
        - k8s.replicaset.name
        - k8s.job.name
        - k8s.cronjob.name
        - k8s.node.name
        - k8s.container.name
        - container.id
        - container.image.name
        - container.image.tag
      labels:
        - tag_name: app
          key: app.kubernetes.io/name
          from: pod
        - tag_name: version
          key: app.kubernetes.io/version
          from: pod
        - tag_name: team
          key: team
          from: namespace
      annotations:
        - tag_name: commit_sha
          key: git.commit.sha
          from: pod
    pod_association:
      - sources:
          - from: resource_attribute
            name: k8s.pod.ip
      - sources:
          - from: resource_attribute
            name: k8s.pod.uid
      - sources:
          - from: connection
```

### 9.2 Pod Association Methods

- **Connection-based:** Uses incoming connection IP. Works for DaemonSet; fails through load balancers.
- **Resource attribute-based:** Matches on pre-set attributes (`k8s.pod.ip`, `k8s.pod.uid`). More reliable for gateways.
- **Best practice:** Use both, in order. Use `node_from_env_var` in DaemonSet mode to reduce API server pressure.

**Performance:** ~1-2KB per pod cached. On a 1000-pod cluster with node filtering, each Collector caches 30-100 pods.

---

## 10. Kubernetes OTel Receivers

### 10.1 k8s_cluster Receiver (Deploy as single Deployment)

Collects cluster-level state metrics (replacement for kube-state-metrics in OTel):

```yaml
receivers:
  k8s_cluster:
    collection_interval: 30s
    auth_type: serviceAccount
    node_conditions_to_report: [Ready, MemoryPressure, DiskPressure, PIDPressure]
    allocatable_types_to_report: [cpu, memory, ephemeral-storage]
```

Key metrics: `k8s.pod.phase`, `k8s.deployment.desired/available`, `k8s.node.condition_ready`, `k8s.container.restarts`, `k8s.resource_quota.hard_limit/used`, `k8s.hpa.current_replicas/desired_replicas`.

### 10.2 k8sobjects Receiver (Events and Object Changes)

```yaml
receivers:
  k8sobjects:
    objects:
      - name: events
        mode: watch               # Stream real-time changes
      - name: pods
        mode: watch
        field_selector: "status.phase=Failed"
      - name: deployments
        mode: pull                 # Periodic snapshot
        interval: 60s
        group: "apps"
```

### 10.3 kubeletstats Receiver (Deploy as DaemonSet)

```yaml
receivers:
  kubeletstats:
    collection_interval: 15s
    auth_type: serviceAccount
    endpoint: "https://${env:K8S_NODE_NAME}:10250"
    insecure_skip_verify: true
    metric_groups: [node, pod, container, volume]
```

Key metrics: `k8s.node.cpu.usage`, `k8s.pod.memory.working_set`, `k8s.container.cpu.usage`, `k8s.volume.available/capacity`.

### 10.4 Recommended Three-Receiver Architecture

| Collector | Mode | Receivers | Purpose |
|-----------|------|-----------|---------|
| **Node Agent** | DaemonSet | kubeletstats, filelog, hostmetrics, otlp | Per-node collection |
| **Cluster Collector** | Deployment (1 replica) | k8s_cluster, k8sobjects | Cluster state |
| **Prometheus Scraper** | StatefulSet + TA | prometheus | Distributed scraping |
| **Gateway** | Deployment + HPA | otlp | Aggregation, processing, export |

---

## 11. Service Mesh Observability

### 11.1 Istio / Envoy

**Standard Metrics:**
| Metric | Type | Description |
|---|---|---|
| `istio_requests_total` | Counter | Total requests (labels: response_code, source/destination workload/namespace) |
| `istio_request_duration_milliseconds` | Histogram | Request latency |
| `istio_request_bytes` / `response_bytes` | Histogram | Body sizes |
| `istio_tcp_sent_bytes_total` / `received_bytes_total` | Counter | TCP bytes |
| `istio_tcp_connections_opened_total` / `closed_total` | Counter | TCP connections |

**OTLP Trace Export (Istio 1.22+):**
```yaml
apiVersion: telemetry.istio.io/v1
kind: Telemetry
metadata:
  name: otel-tracing
  namespace: istio-system
spec:
  tracing:
    - providers:
        - name: otel-tracing
      randomSamplingPercentage: 10.0
```

### 11.2 Linkerd

Golden metrics via Rust-based proxy (port 4191): `request_total`, `response_total`, `response_latency_ms`, plus route-level and TCP metrics. Integrates with OTel via Prometheus scraping.

### 11.3 Cilium Service Mesh

eBPF-based L3/L4/L7 visibility **without sidecars**. Hubble metrics:

| Metric | Description |
|---|---|
| `hubble_flows_processed_total` | Total flows processed |
| `hubble_drop_total` | Dropped packets with reason |
| `hubble_dns_queries_total` / `responses_total` | DNS monitoring |
| `hubble_http_requests_total` / `responses_total` | HTTP monitoring |
| `hubble_http_request_duration_seconds` | HTTP latency |

### 11.4 Mesh vs Application Instrumentation

| Aspect | Service Mesh | Application Instrumentation |
|---|---|---|
| **Scope** | Network-level RED metrics | Business logic, DB queries, cache |
| **Trace Depth** | Service-to-service hops only | Internal operations, function calls |
| **Setup** | Zero-code, infrastructure-level | SDK/agent required |
| **Best Together** | Backbone trace with service edges | Fills in internal detail |

---

## 12. eBPF-Based Kubernetes Observability

### 12.1 Cilium Hubble

Network flow visibility (L3/L4/L7), DNS monitoring, identity-aware mapping, policy verdict logging. Runs within Cilium agent DaemonSet.

### 12.2 Grafana Beyla / OpenTelemetry eBPF Instrumentation (OBI)

Donated to OpenTelemetry May 2025. Auto-instruments HTTP/gRPC/SQL/Redis/Kafka without code changes.

```yaml
# DaemonSet deployment
env:
  - name: BEYLA_OPEN_PORT
    value: "80,443,8080,3000,5432,6379"
  - name: BEYLA_OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://otel-collector.observability:4317"
```

Metrics: `http.server.request.duration`, `rpc.server.duration`, `db.client.operation.duration`.

### 12.3 Pixie (CNCF Sandbox)

Auto-captures full request/response bodies for HTTP, gRPC, MySQL, PostgreSQL, Redis, Kafka, DNS via eBPF. In-cluster storage. PxL scripting language. Overhead: 2-5% CPU, 1-2GB memory per node.

### 12.4 Kepler (Energy Metrics)

eBPF + RAPL sensors for power consumption per container/pod/node:
```
kepler_container_joules_total       # Total energy consumed
kepler_container_core_joules_total  # CPU core energy
kepler_container_dram_joules_total  # DRAM energy
kepler_container_gpu_joules_total   # GPU energy
```

### 12.5 Tetragon (Security Observability)

eBPF-based process execution, file access, and network monitoring with **inline enforcement** (Sigkill/Override actions).

### 12.6 Performance Comparison

| Tool | CPU Overhead | Memory/Node | Scope |
|---|---|---|---|
| Cilium Hubble | 1-3% | 256-512MB | Network flows |
| Beyla / OBI | 1-3% | 100-300MB | HTTP/gRPC/DB |
| Pixie | 2-5% | 1-2GB | Full protocol parsing |
| Kepler | <1% | 50-100MB | Energy metrics |
| Tetragon | 1-2% | 256-512MB | Security events |

**Key advantage:** eBPF overhead is per-node, not per-pod.

---

## 13. Network Observability

### 13.1 CoreDNS Metrics

```promql
# DNS request rate
sum(rate(coredns_dns_requests_total[5m])) by (server, zone, type)

# NXDOMAIN rate (misconfigured services)
sum(rate(coredns_dns_responses_total{rcode="NXDOMAIN"}[5m]))

# Cache hit ratio (should be >90%)
sum(rate(coredns_cache_hits_total[5m]))
  / (sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))

# DNS latency p99 (should be <5ms internal, <100ms external)
histogram_quantile(0.99, sum(rate(coredns_dns_request_duration_seconds_bucket[5m])) by (le))
```

### 13.2 Ingress Controller Metrics

**NGINX Ingress Controller** (port 10254):
```
nginx_ingress_controller_requests{ingress,namespace,service,status,method}
nginx_ingress_controller_request_duration_seconds
nginx_ingress_controller_ssl_expire_time_seconds
```

**Traefik** (configurable port):
```
traefik_service_requests_total{service,code,method}
traefik_service_request_duration_seconds
traefik_tls_certs_not_after
```

**Envoy Gateway:** Native OTLP export for metrics, traces, and access logs.

### 13.3 CNI Metrics

**Cilium:** `cilium_endpoint_count`, `cilium_drop_count_total`, `cilium_forward_count_total`, `cilium_policy_count`, `cilium_bpf_map_ops_total`

**Calico (Felix):** `felix_active_local_policies`, `felix_iptables_save_calls`, `felix_int_dataplane_failures`, `felix_cluster_num_workload_endpoints`

### 13.4 NetworkPolicy Observability

Kubernetes itself does not log policy decisions. CNI-specific capabilities required:
- **Cilium:** Hubble `AUDIT` mode for safe policy testing. `hubble observe --verdict DROPPED`
- **Calico:** `Log` action in NetworkPolicy rules
- **GKE Dataplane V2:** Built-in policy logging via `--enable-network-policy-logging`

---

## 14. Kubernetes Cost Observability

### 14.1 OpenCost (CNCF Incubating, Oct 2024)

Open standard for K8s cost monitoring. Runs alongside Prometheus, reads cloud provider pricing APIs.

**Key Metrics:**
```promql
# Monthly CPU cost per namespace
sum(container_cpu_allocation{namespace!=""} * on(node) group_left() node_cpu_hourly_cost) by (namespace) * 730

# Idle CPU cost per node
(1 - sum(container_cpu_allocation) by (node) / sum(kube_node_status_allocatable{resource="cpu"}) by (node))
  * on(node) group_left() node_cpu_hourly_cost * 730
```

**API:** `/allocation` (by namespace/deployment/pod/label), `/assets` (infrastructure), `/cloudCost` (cloud billing).

**2024-2025:** Plugin framework for all IT spending, carbon cost tracking, MCP integration for AI agents, FOCUS spec alignment.

### 14.2 Kubecost (Commercial, IBM/Apptio)

Built on OpenCost. V3 architecture uses S3-compatible storage. Identifies **30-50% potential cost reduction**. kubectl-cost CLI plugin.

### 14.3 Right-Sizing: VPA and Goldilocks

**VPA modes:** `Off` (recommend only), `Initial` (set at creation), `Auto` (continuously adjust).

**Goldilocks:** Auto-creates VPA objects in `Off` mode for every deployment. Dashboard provides Guaranteed QoS and Burstable QoS recommendations.

### 14.4 Waste Detection

```promql
# CPU requests > actual usage (wasted CPU)
sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"})
  - sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))

# Idle pods (CPU usage < 1% of request for >1 hour)
count by (namespace) (
  (rate(container_cpu_usage_seconds_total{container!=""}[1h])
    / on(namespace,pod,container) kube_pod_container_resource_requests{resource="cpu"}) < 0.01
)

# Orphaned PVCs
kube_persistentvolumeclaim_status_phase{phase="Pending"} == 1
kube_persistentvolume_status_phase{phase="Released"} == 1
```

### 14.5 Industry Statistics

- **99.94% of clusters are over-provisioned** (Cast AI 2025)
- Average CPU utilization: **10-25%**, memory: **18-35%**
- **68% of organizations** overspend by 20-40%+
- **88%** saw K8s TCO increase in past year
- Typical achievable reduction: **35-50%** with optimization

### 14.6 FinOps

**FOCUS 1.3** (Dec 2025): Split cost allocation for shared resources like K8s pods.
**Models:** Showback (awareness) → Chargeback (billing back) → Hybrid (showback dev, chargeback prod).

---

## 15. Kubernetes Security Observability

### 15.1 Runtime Security Monitoring

**Falco (CNCF Graduated):**
- DaemonSet, eBPF-based syscall monitoring
- Detects: reverse shells, sensitive file reads, crypto mining, container escapes, privilege escalation
- Outputs to Slack, PagerDuty, SIEM via Falcosidekick
- Default rules cover shell in container, sensitive file access, unexpected outbound connections

**Tetragon (CNCF, Cilium sub-project):**
- eBPF with **inline runtime enforcement** -- blocks operations in-kernel
- TracingPolicy CRDs for file access, process execution, network monitoring
- `matchActions: [{action: Sigkill}]` -- kills process before execution completes
- **Falco detects (camera), Tetragon enforces (guard)**. Many teams use both.

**KubeArmor (CNCF Sandbox):**
- Linux Security Modules (AppArmor, BPF-LSM, SELinux)
- File access control, process whitelisting, network control per workload

### 15.2 Image Scanning

**Trivy Operator:** Auto-scans workloads, generates `VulnerabilityReport` / `SbomReport` CRDs, exports Prometheus metrics. **87% of production images have at least one major vulnerability**.

### 15.3 Pod Security Standards (PSS)

Three profiles: **Privileged** (unrestricted), **Baseline** (prevents known escalations), **Restricted** (maximum hardening).

```yaml
metadata:
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 15.4 Supply Chain Security

**Sigstore:** Cosign (sign/verify images), Fulcio (keyless CA), Rekor (transparency log).
**Kyverno/Policy Controller:** Admission controllers verifying image signatures before deployment.
**EU Cyber Resilience Act (CRA):** Mandates SBOMs for software products (2025).

### 15.5 Audit Log Security Patterns

```yaml
# High-value patterns to detect
verb=create resource=pods/exec         # Someone exec'ing into pods
verb=create resource=clusterrolebindings # Privilege escalation
verb=get resource=secrets (unusual user) # Credential theft
verb=delete resource=events            # Evidence tampering
```

**Key stat:** **90% of organizations** experienced at least one K8s security incident in the past 12 months. New clusters face first attack within **18 minutes**.

---

## 16. GitOps Observability

### 16.1 Argo CD Metrics

```promql
# Sync status overview
argocd_app_info{sync_status="Synced|OutOfSync", health_status="Healthy|Degraded|Progressing"}

# Sync failures
sum(increase(argocd_app_sync_total{phase="Failed"}[1h])) by (name)

# Reconciliation latency
histogram_quantile(0.99, rate(argocd_app_reconcile_bucket[5m]))

# Out-of-sync applications
count(argocd_app_info{sync_status="OutOfSync"})
```

### 16.2 Flux CD Metrics

```promql
# Failed reconciliations
gotk_reconcile_condition{type="Ready", status="False", kind, name, namespace}

# Reconciliation duration p99
histogram_quantile(0.99, rate(gotk_reconcile_duration_seconds_bucket[5m]))
```

### 16.3 Deployment Tracking

**Argo CD Rollouts** with automated analysis:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
spec:
  metrics:
  - name: success-rate
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        query: |
          sum(rate(http_requests_total{status=~"2.*",app="{{args.service-name}}"}[5m]))
          / sum(rate(http_requests_total{app="{{args.service-name}}"}[5m]))
```

### 16.4 Grafana Deployment Annotations

```bash
# From CI/CD pipeline
curl -X POST http://grafana:3000/api/annotations \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"dashboardUID":"k8s-overview","time":'$(date +%s000)',"tags":["deploy"],"text":"Deployed v1.2.3"}'
```

### 16.5 GitOps Feedback Loop

Deploy (Git) → Observe (OTel) → Detect (alerts) → Respond (auto-rollback) → Record (Git) → Learn (SLO burn-rate)

---

## 17. Kubernetes Troubleshooting with Observability

### 17.1 CrashLoopBackOff

```promql
rate(kube_pod_container_status_restarts_total[15m]) > 0
```
Check: exit codes (1=app error, 137=OOMKilled, 139=segfault, 143=SIGTERM), `kubectl logs --previous`, Events section.

### 17.2 OOMKilled

```promql
# Approaching OOM
container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.9

# Predict OOM (1h extrapolation)
predict_linear(container_memory_working_set_bytes[1h], 3600) > container_spec_memory_limit_bytes
```
Check: container limit vs node pressure, JVM heap vs container limits, memory leak patterns.

### 17.3 Pending Pod

```promql
kube_pod_status_phase{phase="Pending"} == 1
```
Causes: insufficient resources, node selector mismatch, PVC not bound, ResourceQuota exceeded, PodDisruptionBudget blocking.

### 17.4 ImagePullBackOff

```promql
kube_pod_container_status_waiting_reason{reason="ImagePullBackOff"} > 0
```
Causes: wrong image name/tag, missing imagePullSecret, registry rate limiting (Docker Hub: 100 pulls/6h anonymous), architecture mismatch.

### 17.5 DNS Resolution Failures

```promql
# DNS errors
sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m]))

# Cache hit ratio drop
sum(rate(coredns_cache_hits_total[5m])) / (sum(rate(coredns_cache_hits_total[5m])) + sum(rate(coredns_cache_misses_total[5m])))
```
Common: CoreDNS CPU bottleneck, `ndots:5` causing excessive lookups, IPVS DNS delays.

### 17.6 Node Pressure and Eviction

```promql
kube_node_status_condition{condition="MemoryPressure", status="true"} == 1
kube_node_status_condition{condition="DiskPressure", status="true"} == 1
kube_pod_status_reason{reason="Evicted"} > 0
```
Eviction priority: BestEffort → Burstable → Guaranteed.

### 17.7 API Server / etcd Issues

```promql
# API server throttling
sum(rate(apiserver_flowcontrol_rejected_requests_total[5m])) by (priority_level)

# etcd disk latency (>10ms concerning, >100ms critical)
histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))

# etcd leader instability
increase(etcd_server_leader_changes_seen_total[1h]) > 3
```

---

## 18. Multi-Cluster and Multi-Tenant Observability

### 18.1 Metrics Federation

**Thanos:** Sidecar per Prometheus, uploads to object storage, global query with dedup. Best for self-hosted. Single Prometheus maxes at ~10M active series.

**Mimir (Grafana Labs):** 40x faster than Cortex, native multi-tenancy, handles billions of series. Best for centralized platform.

### 18.2 Multi-Cluster OTel Architecture

```
Cluster A:                       Central:
  DaemonSet (agents)  ──────→  Gateway Collector ──→ Backend
  Deployment (cluster)    ↗       (Mimir/Loki/Tempo)
Cluster B:               /
  DaemonSet (agents)  ──/
  Deployment (cluster)
```

**Cluster labeling:**
```yaml
processors:
  resource:
    attributes:
    - key: k8s.cluster.name
      value: "production-us-east-1"
      action: upsert
```

### 18.3 Tenant Isolation

- **Mimir/Loki/Tempo:** `X-Scope-OrgID` header for hard multi-tenancy
- Per-tenant ingestion limits, query limits, retention policies
- Data physically separated in object storage

### 18.4 Federation Topology

| Pattern | Best For | Risk |
|---------|---------|------|
| **Hub-Spoke** | <50 clusters | Hub = SPOF |
| **Mesh** | Geo-distributed | Complex networking |
| **Hierarchical** | 100+ clusters | Most complex, most scalable |

---

## 19. Production Operations and Best Practices

### 19.1 Top 20 Critical Kubernetes Alerts

```yaml
# 1. Node not ready
KubeNodeNotReady:
  expr: kube_node_status_condition{condition="Ready",status="true"} == 0
  for: 5m

# 2. Pod CrashLooping
KubePodCrashLooping:
  expr: rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
  for: 15m

# 3. OOMKilled
KubePodOOMKilled:
  expr: kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1

# 4. Deployment replicas mismatch
KubeDeploymentReplicasMismatch:
  expr: kube_deployment_spec_replicas != kube_deployment_status_ready_replicas
  for: 15m

# 5. PVC filling up
KubePersistentVolumeFillingUp:
  expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85

# 6-7. Node disk/memory pressure
KubeNodeDiskPressure / KubeNodeMemoryPressure:
  expr: kube_node_status_condition{condition="DiskPressure|MemoryPressure",status="true"} == 1

# 8. CPU throttling >25%
CPUThrottlingHigh:
  expr: container_cpu_cfs_throttled_periods_total / container_cpu_cfs_periods_total > 0.25

# 9-10. etcd leader changes / disk latency
EtcdLeaderChanges:
  expr: increase(etcd_server_leader_changes_seen_total[1h]) > 3
EtcdHighFsyncDuration:
  expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.5

# 11-12. API server errors / latency
KubeAPIServerErrors:
  expr: sum(rate(apiserver_request_total{code=~"5.."}[5m])) / sum(rate(apiserver_request_total[5m])) > 0.01
KubeAPIServerLatency:
  expr: histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb!="WATCH"}[5m])) by (le)) > 1

# 13. Pods pending too long
KubePodPendingTooLong:
  expr: kube_pod_status_phase{phase="Pending"} == 1
  for: 15m

# 14. DaemonSet not scheduled
KubeDaemonSetNotScheduled:
  expr: kube_daemonset_status_desired_number_scheduled - kube_daemonset_status_current_number_scheduled > 0

# 15. Job failed
KubeJobFailed:
  expr: kube_job_status_failed > 0

# 16. HPA maxed out
KubeHPAMaxedOut:
  expr: kube_horizontalpodautoscaler_status_current_replicas == kube_horizontalpodautoscaler_spec_max_replicas

# 17. Container memory near limit
ContainerMemoryNearLimit:
  expr: container_memory_working_set_bytes / container_spec_memory_limit_bytes > 0.9

# 18. CoreDNS errors
CoreDNSErrorsHigh:
  expr: sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[5m])) > 1

# 19. Certificate expiring
KubeCertificateExpiring:
  expr: apiserver_client_certificate_expiration_seconds_bucket{le="604800"} > 0

# 20. Cluster capacity exhaustion prediction
ClusterCPUCapacityExhaustion:
  expr: predict_linear(sum(kube_pod_container_resource_requests{resource="cpu"})[6h:5m], 86400)
        > sum(kube_node_status_allocatable{resource="cpu"})
```

### 19.2 Alert Fatigue Reduction

- Alert on **symptoms** (error rate, latency), not causes (CPU)
- Use **SLO burn-rate** alerting instead of thresholds
- Group related alerts, route by severity
- Regular monthly alert hygiene reviews
- Result: **>60% noise reduction**, up to **85% MTTR improvement**

### 19.3 High Availability Patterns

- **Agents (DaemonSet):** One per node, no HA concern
- **Gateway (Deployment):** 2+ replicas behind K8s Service, `/health` and `/ready` endpoints
- **Tail sampling HA:** `loadbalancing` exporter with consistent hashing, 3+ gateway replicas
- **Prometheus:** 2 replicas with Thanos deduplication
- **Loki/Tempo/Mimir:** Microservice mode with replication factor 3

### 19.4 Data Retention Strategy

| Tier | Duration | Resolution | Storage |
|------|----------|-----------|---------|
| **Hot** | 24-48h | Full fidelity | Prometheus local TSDB |
| **Warm** | 7-30 days | Full fidelity | Thanos/Mimir + object storage |
| **Cold** | 90-365 days | 5m/1h downsampled | Object storage |
| **Archive** | 1-3 years | Maximum downsampled | Cold storage |

**Logs:** Error/warning 30-90 days, debug 7-14 days, audit 365+ days.
**Traces:** All 7-14 days, errors 30-90 days, sampled 1-10% long-term.

### 19.5 Observability Cost Benchmarks

- Well-optimized: **5-15% of cluster infrastructure spend**
- Unoptimized: **20-30%+ of infrastructure spend**
- Key levers: cardinality reduction, log filtering, tail sampling, tiered retention
- Tiered retention reduces costs by **40%+** while maintaining visibility

### 19.6 Disaster Recovery

1. Object storage cross-region replication for metrics/logs/traces
2. Dashboards and config stored in Git (GitOps)
3. Infrastructure as Code for entire observability stack
4. RPO: 5-15 min (metrics), 0 (logs if dual-writing)
5. RTO: 15-60 min with IaC recreation

---

## 20. Market and Adoption Statistics (2024-2025)

### 20.1 Kubernetes Adoption

- **82% production use** (CNCF 2025), projected **>90% by 2027**
- **84% run K8s on multiple clouds** (CNCF 2024)
- **88% saw TCO increase** in past year
- **77%** report ongoing cluster operational issues

### 20.2 Monitoring Tool Adoption

- **Prometheus:** Used by **89%** of K8s operators (Grafana 2024)
- **OpenTelemetry:** **85%** investing, **43%** still investigating (earlier in adoption curve)
- **70%** of teams rely on **4+ observability technologies**
- **62 different tools** reported across survey respondents
- **76%** use open-source licensing for observability

### 20.3 Market Size

| Source | 2025 Value | Growth |
|--------|-----------|--------|
| Research Nester | $28.5B → $172.1B (2035) | 19.7% CAGR |
| Mordor Intelligence | $2.9B → $6.93B (2031) | 15.62% CAGR |
| Datadog revenue | $3.3B (2025) | Largest pure-play vendor |

### 20.4 Key Challenges

1. **Cost** -- #1 concern across all surveys
2. **Tool sprawl** -- 4+ tools average, 13 tools/9 vendors in enterprises
3. **Operational complexity** -- 70% cite as top pain point
4. **<50% instrumentation coverage** in many organizations
5. **Alert fatigue** -- 52% report false alert floods

---

## 21. Reference Architecture

```
                                      +-----------------------+
                                      |   Observability       |
                                      |   Backend             |
                                      |   (Mimir/Loki/Tempo   |
                                      |    or Datadog/etc.)   |
                                      +-----------^-----------+
                                                  |
                                      +-----------+-----------+
                                      |   OTel Gateway        |
                                      |   (Deployment + HPA)  |
                                      |   - Tail sampling     |
                                      |   - Batch processing  |
                                      |   - Multi-backend     |
                                      +-----------^-----------+
                                                  |
                  +-------------------------------+-------------------------------+
                  |                               |                               |
      +-----------+-----------+       +-----------+-----------+       +-----------+-----------+
      |   OTel DaemonSet      |       |   OTel Cluster        |       |   OTel StatefulSet    |
      |   (per-node agent)    |       |   (single replica)    |       |   (Prometheus + TA)   |
      |   - kubeletstats      |       |   - k8s_cluster       |       |   - Target Allocator  |
      |   - filelog           |       |   - k8sobjects        |       |   - ServiceMonitor    |
      |   - hostmetrics       |       |   - Events            |       |   - PodMonitor        |
      |   - OTLP receiver     |       |   - Pod phases        |       |                       |
      |   - k8sattributes     |       |   - Node conditions   |       |                       |
      +-----------^-----------+       +-----------------------+       +-----------------------+
                  |
      +-----------+-----------+
      |   Applications        |
      |   - Auto-instrumented |
      |     (Java/Python/     |
      |      Node.js/.NET)    |
      |   - eBPF instrumented |
      |     (Go/Beyla/OBI)    |
      |   - Service Mesh      |
      |     (Istio/Linkerd/   |
      |      Cilium)          |
      +-----------------------+

      Security Layer:               Cost Layer:              GitOps Layer:
      - Falco (DaemonSet)           - OpenCost               - Argo CD metrics
      - Tetragon (DaemonSet)        - Kubecost               - Flux CD metrics
      - Trivy Operator              - VPA/Goldilocks          - Deployment annotations
      - K8s Audit Logs              - Cloud billing APIs      - Rollout analysis
```

---

## Sources

### Kubernetes Core
- [Kubernetes Documentation: Metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- [kube-state-metrics GitHub](https://github.com/kubernetes/kube-state-metrics)
- [Prometheus node_exporter](https://github.com/prometheus/node_exporter)
- [Kubernetes Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [KEP-3077: Structured Logging](https://github.com/kubernetes/enhancements/tree/master/keps/sig-instrumentation/3077-contextual-logging)

### OpenTelemetry
- [OTel Operator for Kubernetes](https://opentelemetry.io/docs/platforms/kubernetes/operator/)
- [OTel Auto-instrumentation](https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/)
- [k8sattributesprocessor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor)
- [k8s_cluster Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver)
- [kubeletstats Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kubeletstatsreceiver)
- [k8sobjects Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sobjectsreceiver)
- [Target Allocator](https://opentelemetry.io/docs/platforms/kubernetes/operator/target-allocator/)

### eBPF and Service Mesh
- [Cilium Hubble](https://github.com/cilium/hubble)
- [OpenTelemetry eBPF Instrumentation (OBI)](https://opentelemetry.io/docs/zero-code/obi/)
- [Grafana Beyla 2.0](https://grafana.com/blog/2025/02/10/grafana-beyla-2.0/)
- [Pixie (CNCF)](https://www.cncf.io/projects/pixie/)
- [Kepler](https://github.com/sustainable-computing-io/kepler)
- [Tetragon](https://tetragon.io/)
- [Istio Observability](https://istio.io/latest/docs/tasks/observability/)
- [Linkerd Proxy Metrics](https://linkerd.io/2-edge/reference/proxy-metrics/)

### Cost and Security
- [OpenCost](https://www.opencost.io/)
- [FOCUS Specification](https://focus.finops.org/)
- [Cast AI K8s Cost Benchmark 2025](https://cast.ai/kubernetes-cost-benchmark/)
- [Falco](https://falco.org/)
- [KubeArmor](https://kubearmor.io/)
- [Trivy Operator](https://aquasecurity.github.io/trivy-operator/)
- [Sigstore](https://sigstore.dev/)

### Industry Reports
- [CNCF Annual Survey 2024-2025](https://www.cncf.io/reports/)
- [Grafana Labs Observability Survey 2025](https://grafana.com/observability-survey/2025/)
- [Splunk State of Observability 2025](https://www.splunk.com/en_us/blog/observability/state-of-observability-2025.html)
- [New Relic 2025 Observability Forecast](https://newrelic.com/resources/report/observability-forecast/2025)
- [Spectro Cloud K8s State Report 2024](https://www.spectrocloud.com/resources/)

### GitOps
- [Argo CD Metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- [Flux CD Monitoring](https://fluxcd.io/flux/monitoring/)
- [CDEvents (CNCF)](https://cdevents.dev/)
