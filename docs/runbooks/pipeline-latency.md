# Runbook: Pipeline Latency

## Symptoms
- Traces arriving at the backend with significant delay (minutes instead of seconds)
- High p99 latency for trace export
- `otelcol_exporter_send_latency` histogram showing elevated values
- Batch processor triggering on timeout rather than size (indicates under-utilization or misconfigured batch)
- Real-time alerting delayed because telemetry data is stale
- Users report dashboard lag: "my spans show up 5 minutes late"

## Diagnosis

### 1. Measure end-to-end latency
```bash
# Compare span timestamp to backend ingest timestamp
# In Grafana or backend query:
# ingest_timestamp - span.end_time > 10s  => pipeline is adding latency

# Check exporter latency directly
histogram_quantile(0.99, rate(otelcol_exporter_send_latency_bucket[5m]))
histogram_quantile(0.50, rate(otelcol_exporter_send_latency_bucket[5m]))
```

### 2. Check batch processor behavior
```bash
# Timeout triggers vs size triggers
rate(otelcol_processor_batch_timeout_trigger_send[5m])
rate(otelcol_processor_batch_batch_size_trigger_send[5m])

# If timeout_trigger >> size_trigger, batch timeout is the bottleneck
# Data sits in buffer waiting for timeout instead of filling batch

# Current batch config
kubectl get configmap otel-collector-config -o yaml | grep -A5 "batch"
```

### 3. Check queue depth and drain rate
```bash
# Queue depth (items waiting to be exported)
otelcol_exporter_queue_size{job="otel-collector"}

# If queue is consistently > 0, exporter cannot keep up
# Calculate drain rate
rate(otelcol_exporter_sent_spans[5m])
rate(otelcol_exporter_sent_metric_points[5m])
```

### 4. Check network latency to backend
```bash
# From collector pod, measure round-trip time
kubectl exec -it <collector-pod> -- sh -c \
  "time wget -qO /dev/null https://otlp-gateway.example.com:4318/v1/traces"

# DNS resolution time
kubectl exec -it <collector-pod> -- sh -c \
  "time nslookup otlp-gateway.example.com"

# Check for DNS caching issues
kubectl exec -it <collector-pod> -- cat /etc/resolv.conf
```

### 5. Check TLS handshake overhead
```bash
# Measure TLS handshake separately
kubectl exec -it <collector-pod> -- sh -c \
  "curl -w 'dns: %{time_namelookup}s\ntls: %{time_appconnect}s\ntotal: %{time_total}s\n' \
   -o /dev/null -s https://otlp-gateway.example.com:4318"
```

## Resolution

### Reduce batch timeout for real-time pipelines
```yaml
processors:
  # For real-time trace pipelines
  batch/realtime:
    send_batch_size: 512
    send_batch_max_size: 1024
    timeout: 1s              # Reduce from 5s default

  # For metrics (can tolerate slightly higher latency)
  batch/metrics:
    send_batch_size: 2048
    send_batch_max_size: 4096
    timeout: 5s

  # For logs (high volume, batch efficiently)
  batch/logs:
    send_batch_size: 4096
    send_batch_max_size: 8192
    timeout: 3s
```

### Increase exporter concurrency
```yaml
exporters:
  otlp:
    endpoint: otlp-gateway.example.com:4317
    sending_queue:
      enabled: true
      num_consumers: 20      # Increase parallel senders (default 10)
      queue_size: 5000
    retry_on_failure:
      enabled: true
      initial_interval: 1s
      max_interval: 10s
```

### Fix DNS resolution delays
```yaml
# Use IP address instead of hostname for internal services
exporters:
  otlp/gateway:
    endpoint: 10.96.100.50:4317   # ClusterIP of gateway service
    tls:
      insecure: true

# Or configure DNS caching in collector pod
# Add dnsConfig to pod spec:
# spec:
#   dnsConfig:
#     options:
#       - name: ndots
#         value: "1"          # Reduce DNS search domain lookups
```

### Optimize TLS with connection pooling
```yaml
exporters:
  otlp:
    endpoint: otlp-gateway.example.com:4317
    tls:
      insecure: false
      cert_file: /certs/client.crt
      key_file: /certs/client.key
    # gRPC keepalive prevents re-establishing connections
    keepalive:
      time: 30s
      timeout: 10s
      permit_without_stream: true
```

### Use gRPC instead of HTTP for agent-to-gateway
```yaml
# Agent exporter - gRPC is more efficient for streaming
exporters:
  otlp/gateway:
    endpoint: otel-gateway:4317
    tls:
      insecure: true         # Within cluster
    compression: zstd        # Better compression than gzip

# NOT this:
# otlphttp/gateway:
#   endpoint: http://otel-gateway:4318  # HTTP has higher per-request overhead
```

### Separate pipelines by latency requirement
```yaml
service:
  pipelines:
    # Low-latency trace pipeline
    traces/realtime:
      receivers: [otlp]
      processors: [memory_limiter, batch/realtime]
      exporters: [otlp/backend]

    # Higher-latency metrics pipeline (can batch more aggressively)
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch/metrics]
      exporters: [otlp/backend]
```

## Prevention
- Set batch timeout below 5s for real-time trace and log pipelines
- Monitor end-to-end latency:
  ```
  histogram_quantile(0.99, rate(otelcol_exporter_send_latency_bucket[5m])) > 5
  ```
- Use gRPC with keepalive for agent-to-gateway communication
- Reduce `ndots` in pod DNS config to minimize lookup latency
- Enable `compression: zstd` on exporters to reduce payload size and transfer time
- Keep gateway tier geographically close to backend endpoints
- Monitor ratio of timeout triggers to size triggers: if timeout dominates, reduce batch size or timeout
- Pre-warm TLS connections using gRPC keepalive settings
- Run latency benchmarks as part of CI/CD pipeline changes
