# OllyStack Kubernetes Deployment

One-command deployment of the OpenTelemetry Collector stack to any Kubernetes cluster.

## What Gets Deployed

```
┌─────────────────────────────────────────────────────────────┐
│  Namespace: observability                                   │
│                                                             │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  otel-agent      │  │ otel-gateway │  │ otel-cluster  │  │
│  │  (DaemonSet)     │─→│ (Deployment) │  │   -receiver   │  │
│  │                  │  │              │  │ (Deployment)  │  │
│  │  1 per node      │  │ 2-10 replicas│  │ 1 replica     │  │
│  │  OTLP + hostmet  │  │ tail-sample  │──│ k8s_cluster   │  │
│  │  + kubeletstats  │  │ + batch      │  │ + k8s_events  │  │
│  │  + filelog       │  │              │  │               │  │
│  └─────────────────┘  └──────┬───────┘  └───────────────┘  │
│                              │                              │
│  ┌───────────────────────────┴────────────────────────────┐ │
│  │  NetworkPolicy: deny-all + allow OTLP/health/metrics   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                               │
                               ▼
                     Backend (Datadog, Grafana
                     Cloud, Splunk, etc.)
```

| Component | Kind | Purpose |
|-----------|------|---------|
| **Agent** | DaemonSet | Collects host metrics, pod logs, kubelet stats; receives OTLP from apps |
| **Gateway** | Deployment (2-10) | Tail sampling, batching, exports to backend; HPA + PDB for HA |
| **Cluster Receiver** | Deployment (1) | Cluster-level metrics (nodes, deployments) and Kubernetes events |
| **NetworkPolicy** | 5 policies | Default-deny ingress, scoped OTLP/health/metrics access, controlled egress |

## Quick Start

```bash
# 1. Deploy with defaults
./deploy/quick-start.sh

# 2. Verify everything is running
./deploy/quick-start.sh status

# 3. Run the test suite
./deploy/test-telemetry.sh
```

## Configuration

All configuration is via environment variables. Set them before running `quick-start.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `OTEL_NAMESPACE` | `observability` | Kubernetes namespace for all components |
| `OTEL_COLLECTOR_IMAGE` | `otel/opentelemetry-collector-contrib` | Collector container image |
| `OTEL_COLLECTOR_VERSION` | `0.96.0` | Collector image tag |
| `BACKEND_OTLP_ENDPOINT` | `localhost:4317` | Backend OTLP gRPC endpoint |
| `BACKEND_OTLP_INSECURE` | `false` | Disable TLS to backend |
| `K8S_CLUSTER_NAME` | `my-cluster` | Cluster name added to resource attributes |
| `DEPLOYMENT_ENVIRONMENT` | `production` | Environment label (`production`, `staging`, `dev`) |
| `OTEL_LOG_LEVEL` | `info` | Collector log verbosity (`debug`, `info`, `warn`, `error`) |
| `GATEWAY_REPLICAS` | `2` | Initial gateway replica count |
| `GATEWAY_HPA_MIN_REPLICAS` | `2` | HPA minimum replicas |
| `GATEWAY_HPA_MAX_REPLICAS` | `10` | HPA maximum replicas |

### Example: Deploy to a Staging Cluster with Grafana Cloud

```bash
OTEL_NAMESPACE=observability \
K8S_CLUSTER_NAME=staging-us-west-2 \
DEPLOYMENT_ENVIRONMENT=staging \
BACKEND_OTLP_ENDPOINT=otlp-gateway-prod-us-central-0.grafana.net:443 \
GATEWAY_REPLICAS=1 \
GATEWAY_HPA_MIN_REPLICAS=1 \
GATEWAY_HPA_MAX_REPLICAS=4 \
./deploy/quick-start.sh
```

### Backend Authentication

Create a Kubernetes Secret with your backend credentials before deploying:

```bash
# Generic OTLP header (works for Grafana Cloud, Honeycomb, etc.)
kubectl -n observability create secret generic otel-secrets \
  --from-literal=OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic $(echo -n 'user:token' | base64)" \
  --from-literal=BACKEND_OTLP_AUTH_HEADER="Basic $(echo -n 'user:token' | base64)"

# Datadog
kubectl -n observability create secret generic otel-secrets \
  --from-literal=DD_API_KEY="your-datadog-api-key"

# New Relic
kubectl -n observability create secret generic otel-secrets \
  --from-literal=BACKEND_OTLP_AUTH_HEADER="Api-Key your-newrelic-license-key"
```

See `docs/secrets/` for detailed guides on Vault, AWS Secrets Manager, and Azure Key Vault integration.

## Files

| File | Description |
|------|-------------|
| `quick-start.sh` | Deploy/delete/status — single entry point for the full stack |
| `networkpolicy.yaml` | 5 NetworkPolicy resources for namespace security isolation |
| `test-telemetry.sh` | End-to-end test: pod health, endpoints, metrics, send test data |

## Commands Reference

### quick-start.sh

```bash
./deploy/quick-start.sh              # Deploy the full stack
./deploy/quick-start.sh --dry-run    # Preview rendered manifests (no apply)
./deploy/quick-start.sh status       # Show pods, services, HPA status
./deploy/quick-start.sh --delete     # Tear down everything
```

### test-telemetry.sh

```bash
./deploy/test-telemetry.sh           # Full test suite
./deploy/test-telemetry.sh health    # Pod readiness + health endpoints only
./deploy/test-telemetry.sh send      # Send test traces/metrics/logs
./deploy/test-telemetry.sh status    # Check collector self-metrics
```

Install `telemetrygen` for send tests (optional — falls back to port check without it):

```bash
go install github.com/open-telemetry/opentelemetry-collector-contrib/cmd/telemetrygen@latest
```

## NetworkPolicy Details

The `networkpolicy.yaml` enforces least-privilege network access:

| Policy | Scope | Allows |
|--------|-------|--------|
| `default-deny-ingress` | All pods | Nothing (baseline deny) |
| `allow-agent-ingress` | Agent pods | OTLP 4317/4318 from any namespace, health 13133, metrics 8888 from monitoring |
| `allow-gateway-ingress` | Gateway pods | OTLP from agents + cluster-receiver only, health, metrics from monitoring |
| `allow-cluster-receiver-ingress` | Cluster receiver | Health 13133, metrics 8888 from monitoring |
| `allow-collector-egress` | All collector pods | DNS (53), kube-apiserver (443/6443), kubelet (10250), external backends (443/4317/4318) |

**Requires** a CNI that supports NetworkPolicy (Calico, Cilium, Azure CNI, GKE Dataplane V2).

## Alternative Deployment Methods

This quick-start uses raw manifests with `envsubst`. For more advanced setups:

| Method | Path | When to Use |
|--------|------|-------------|
| **Helm** | `platforms/kubernetes/helm/` | Production with Helm-managed releases |
| **Kustomize** | `examples/full-stack-{aws,azure,gcp}/` | Cloud-specific overlays (IRSA, Workload Identity) |
| **OTel Operator** | `platforms/kubernetes/operator/` | Auto-instrumentation injection, operator-managed lifecycle |

```bash
# Helm deployment
cd platforms/kubernetes/helm
helmfile sync

# Kustomize (e.g., AWS EKS)
kubectl apply -k examples/full-stack-aws-eks/

# OTel Operator CRs (requires operator installed)
kubectl apply -f platforms/kubernetes/operator/
```

## Troubleshooting

### Pods stuck in Pending

```bash
kubectl -n observability describe pod <pod-name>
# Common: insufficient CPU/memory, node selector mismatch, taints
```

### Agent CrashLoopBackOff

```bash
kubectl -n observability logs -l app.kubernetes.io/name=otel-agent --tail=50
# Common: invalid config YAML, missing RBAC permissions, kubelet TLS
```

### Gateway not receiving data

```bash
# Check agent → gateway connectivity
kubectl -n observability exec -it <agent-pod> -- wget -qO- http://otel-gateway:13133

# Check gateway logs for exporter errors
kubectl -n observability logs -l app.kubernetes.io/name=otel-gateway --tail=50 | grep -i error
```

### NetworkPolicy blocking traffic

```bash
# Temporarily remove policies to verify
kubectl -n observability delete networkpolicy --all

# Re-apply after confirming
kubectl apply -f deploy/networkpolicy.yaml
```

See `docs/runbooks/` for detailed operational runbooks covering memory, CPU, data loss, auth failures, and scaling.
