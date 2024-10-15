# Runbook: Collector High CPU Usage

## Symptoms
- Collector pods CPU-throttled by Kubernetes (cgroup throttling)
- `otelcol_process_cpu_seconds` total spiking or sustained high usage
- Increased end-to-end pipeline latency
- Kubernetes events: `CPUThrottling`, pod restarts due to liveness probe failures
- `container_cpu_cfs_throttled_periods_total` increasing for collector containers
- Collector logs show slow processing warnings or timeout errors

## Diagnosis

### 1. Check current CPU usage
```bash
# Prometheus queries
rate(otelcol_process_cpu_seconds_total{job="otel-collector"}[5m])

# CPU throttling percentage
rate(container_cpu_cfs_throttled_periods_total{container="otel-collector"}[5m])
/ rate(container_cpu_cfs_periods_total{container="otel-collector"}[5m]) * 100

# Kubectl
kubectl top pods -l app=otel-collector
kubectl describe pod <collector-pod> | grep -A3 "cpu"
```

### 2. Identify CPU-intensive processors
```bash
# Time spent in each processor
otelcol_processor_batch_timeout_trigger_send{job="otel-collector"}

# Check if transform processor with complex OTTL is the cause
# High values indicate regex or parsing overhead
rate(otelcol_processor_incoming_items{job="otel-collector"}[5m])

# Check span/log processing rates - sudden spikes cause CPU spikes
rate(otelcol_receiver_accepted_spans{job="otel-collector"}[5m])
rate(otelcol_receiver_accepted_log_records{job="otel-collector"}[5m])
```

### 3. Capture CPU profile with pprof
```bash
# Enable pprof extension in collector config
# extensions:
#   pprof:
#     endpoint: 0.0.0.0:1777

# Capture 30-second CPU profile
curl http://localhost:1777/debug/pprof/profile?seconds=30 > cpu.prof
go tool pprof -http=:8080 cpu.prof

# Check goroutine count (high count may indicate resource exhaustion)
curl http://localhost:1777/debug/pprof/goroutine?debug=1 | head -5
```

### 4. Check processor chain length
```bash
# Count processors in each pipeline - more processors = more CPU
kubectl get configmap otel-collector-config -o yaml | grep "processors:" -A20

# Check for regex-heavy processors
kubectl get configmap otel-collector-config -o yaml | grep -c "regexp"
```

## Resolution

### Simplify regex patterns in filter and transform processors
```yaml
# BEFORE: Expensive regex
processors:
  filter/expensive:
    logs:
      log_record:
        - 'IsMatch(body, "(?i).*error.*timeout.*connection.*refused.*")'

# AFTER: Use simpler string operations where possible
processors:
  filter/efficient:
    logs:
      log_record:
        - 'IsMatch(body, "error") and IsMatch(body, "timeout")'
```

### Use efficient OTTL expressions
```yaml
# BEFORE: Multiple regex replacements
processors:
  transform/expensive:
    log_statements:
      - context: log
        statements:
          - replace_all_patterns(attributes, "key", ".*sensitive.*", "REDACTED")

# AFTER: Target specific keys
processors:
  transform/efficient:
    log_statements:
      - context: log
        statements:
          - set(attributes["password"], "REDACTED") where attributes["password"] != nil
          - set(attributes["token"], "REDACTED") where attributes["token"] != nil
```

### Reduce filter complexity by pre-filtering at the receiver
```yaml
# Use receiver-level filtering instead of processor filtering
receivers:
  filelog:
    include:
      - /var/log/app/*.log
    exclude:
      - /var/log/app/debug-*.log    # Exclude at source
      - /var/log/app/health-*.log
    operators:
      - type: filter
        expr: 'body matches "^\\s*$"'  # Drop empty lines at receiver
```

### Offload processing to gateway tier
```yaml
# Agent config - minimal processing
processors:
  memory_limiter:
    limit_mib: 256
  batch:
    send_batch_size: 1024
    timeout: 1s
# Do NOT run transform, filter, or tail_sampling on agents

# Gateway config - full processing chain
processors:
  memory_limiter:
    limit_mib: 2048
  filter/noise:
    # Complex filtering here
  transform/enrich:
    # Attribute manipulation here
  tail_sampling:
    # Sampling decisions here
  batch:
    send_batch_size: 8192
    timeout: 5s
```

### Increase CPU limits
```yaml
# Kubernetes deployment
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"         # Increase from 1000m
    memory: "1024Mi"
```

### Scale horizontally
```bash
# Scale gateway tier
kubectl scale deployment otel-collector-gateway --replicas=5

# Or apply HPA
kubectl autoscale deployment otel-collector-gateway \
  --cpu-percent=60 \
  --min=2 \
  --max=10
```

## Prevention
- Benchmark processor chains in staging before deploying to production
  ```bash
  # Use the telemetrygen tool to load-test
  telemetrygen traces --otlp-insecure --rate 1000 --duration 60s
  ```
- Monitor CPU usage with alerts:
  ```
  rate(otelcol_process_cpu_seconds_total[5m]) > 0.8  # Alert at 80%
  ```
- Avoid regex in hot paths; prefer exact match or simple string operations
- Keep agent processor chains short (memory_limiter + batch only)
- Move complex processing (sampling, enrichment, filtering) to the gateway tier
- Use `connectors` instead of duplicating processors across pipelines
- Profile CPU periodically with pprof in staging to catch regressions
- Set CPU requests equal to limits to avoid throttling in production
