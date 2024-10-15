# Runbook: Upgrading the OpenTelemetry Collector

## Symptoms (Triggers for Upgrade)
- Current collector version has known CVEs or critical bugs
- New version includes needed features (new receiver, processor, or exporter)
- Vendor requires minimum collector version for compatibility
- End-of-support for current version
- Performance improvements available in newer releases

## Diagnosis (Pre-Upgrade Assessment)

### 1. Identify current version
```bash
# Check running version
kubectl exec -it <collector-pod> -- otelcol-contrib --version

# Check deployed image tag
kubectl get deployment otel-collector-gateway -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check all collector deployments/daemonsets
kubectl get deploy,ds -l app.kubernetes.io/name=otel-collector -o wide
```

### 2. Review changelog for breaking changes
```bash
# Check the release notes between current and target version
# https://github.com/open-telemetry/opentelemetry-collector/releases
# https://github.com/open-telemetry/opentelemetry-collector-contrib/releases

# Key things to check:
# - Removed components (receivers, processors, exporters)
# - Renamed configuration fields
# - Changed default values
# - Deprecated features removed
# - Go version requirements (if building custom collector)
```

### 3. Validate configuration against new version
```bash
# Download the new binary
curl -LO https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.100.0/otelcol-contrib_0.100.0_linux_amd64.tar.gz
tar xzf otelcol-contrib_0.100.0_linux_amd64.tar.gz

# Validate existing config against new binary
./otelcol-contrib validate --config=config.yaml

# Check for deprecation warnings
./otelcol-contrib validate --config=config.yaml 2>&1 | grep -i "deprecat"
```

### 4. Check component stability levels
```bash
# Components move through stability levels: development -> alpha -> beta -> stable
# Check if any components you use have changed stability or been removed
# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/cmd/otelcontribcol/components.go
```

## Resolution (Upgrade Procedure)

### Step 1: Test in a non-production environment
```bash
# Update image tag in staging
kubectl set image deployment/otel-collector-gateway \
  otel-collector=otel/opentelemetry-collector-contrib:0.100.0 \
  -n staging

# Watch for errors
kubectl rollout status deployment/otel-collector-gateway -n staging
kubectl logs -l app=otel-collector-gateway -n staging --since=5m | grep -i error
```

### Step 2: Validate data flow in staging
```bash
# Send test telemetry
telemetrygen traces --otlp-insecure --otlp-endpoint=otel-gateway.staging:4317 --traces 100
telemetrygen metrics --otlp-insecure --otlp-endpoint=otel-gateway.staging:4317 --metrics 100
telemetrygen logs --otlp-insecure --otlp-endpoint=otel-gateway.staging:4317 --logs 100

# Verify data arrives at backend
# Check dashboards, run queries, validate no data loss
```

### Step 3: Canary deployment in production
```yaml
# Deploy new version as a separate canary deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway-canary
  labels:
    app: otel-collector-gateway
    version: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector-gateway
      version: canary
  template:
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0    # New version
          # Same config, resources, volumes as production
```

```bash
# The canary pod joins the same headless service
# It receives a portion of traffic automatically
kubectl apply -f otel-gateway-canary.yaml

# Monitor canary metrics vs stable
# Compare error rates
rate(otelcol_exporter_send_failed_spans{version="canary"}[5m])
rate(otelcol_exporter_send_failed_spans{version="stable"}[5m])

# Compare latency
histogram_quantile(0.99, rate(otelcol_exporter_send_latency_bucket{version="canary"}[5m]))
histogram_quantile(0.99, rate(otelcol_exporter_send_latency_bucket{version="stable"}[5m]))
```

### Step 4: Rolling upgrade
```bash
# Once canary is validated, update the main deployment
kubectl set image deployment/otel-collector-gateway \
  otel-collector=otel/opentelemetry-collector-contrib:0.100.0

# Monitor the rollout
kubectl rollout status deployment/otel-collector-gateway

# Check for errors
kubectl logs -l app=otel-collector-gateway --since=5m | grep -iE "(error|fatal|panic)"

# Verify all pods are running new version
kubectl get pods -l app=otel-collector-gateway -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

### Step 5: Upgrade agents (DaemonSet)
```bash
# DaemonSet rolling update
kubectl set image daemonset/otel-collector-agent \
  otel-collector=otel/opentelemetry-collector-contrib:0.100.0

# DaemonSet updates one node at a time by default
kubectl rollout status daemonset/otel-collector-agent

# Verify all agents updated
kubectl get pods -l app=otel-collector-agent -o jsonpath='{range .items[*]}{.spec.nodeName}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

### Step 6: Clean up canary
```bash
kubectl delete deployment otel-collector-gateway-canary
```

## Rollback Procedure

### Immediate rollback
```bash
# Undo the last rollout
kubectl rollout undo deployment/otel-collector-gateway
kubectl rollout undo daemonset/otel-collector-agent

# Verify rollback
kubectl rollout status deployment/otel-collector-gateway
kubectl get pods -l app=otel-collector-gateway -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
```

### Rollback to a specific revision
```bash
# List revision history
kubectl rollout history deployment/otel-collector-gateway

# Rollback to specific revision
kubectl rollout undo deployment/otel-collector-gateway --to-revision=3
```

## Upgrade Checklist

Use this checklist for every collector upgrade:

```
Pre-Upgrade:
[ ] Read release notes for all versions between current and target
[ ] Check for removed or renamed configuration fields
[ ] Validate config with new binary: otelcol-contrib validate --config=config.yaml
[ ] Review component stability changes
[ ] Check Go module dependencies (if custom build)
[ ] Update custom collector builder manifest (if using OCB)

Testing:
[ ] Deploy new version in staging/dev
[ ] Run telemetrygen to validate all signal types
[ ] Verify data arrives at all backends
[ ] Check for deprecation warnings in logs
[ ] Run load test matching production throughput
[ ] Validate all custom processors/extensions work

Production:
[ ] Deploy canary (1 replica with new version)
[ ] Monitor canary for 30 minutes minimum
[ ] Compare canary metrics vs stable
[ ] Rolling upgrade gateway tier
[ ] Rolling upgrade agent tier
[ ] Monitor for 1 hour post-upgrade
[ ] Clean up canary deployment

Post-Upgrade:
[ ] Update version pins in Git
[ ] Update documentation
[ ] Notify team of completed upgrade
[ ] Record upgrade in change management system
```

## Prevention
- Pin collector versions explicitly in all manifests (never use `latest` tag)
- Subscribe to OpenTelemetry release notifications on GitHub
- Schedule quarterly upgrade reviews to avoid falling too far behind
- Maintain a CI/CD pipeline that validates config against the new version before deploying
- Keep a rollback plan documented and tested
- Use the OpenTelemetry Collector Builder (OCB) to build a custom collector with only needed components, reducing the upgrade surface area
- Track which components your configs use and monitor their stability level across releases
- Automate config validation in CI:
  ```yaml
  # .github/workflows/validate-otel-config.yaml
  jobs:
    validate:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Download collector
          run: |
            curl -LO https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.100.0/otelcol-contrib_0.100.0_linux_amd64.tar.gz
            tar xzf otelcol-contrib_0.100.0_linux_amd64.tar.gz
        - name: Validate configs
          run: |
            for config in configs/*.yaml; do
              ./otelcol-contrib validate --config="$config"
            done
  ```
