# Runbook: Collector Dropping Data

## Symptoms
- `otelcol_exporter_send_failed_spans` counter increasing
- `otelcol_exporter_send_failed_metric_points` counter increasing
- `otelcol_exporter_send_failed_log_records` counter increasing
- `otelcol_exporter_queue_capacity` consistently at maximum
- Collector logs: "Dropping data because sending_queue is full"
- Gaps in backend dashboards, missing traces or log entries
- `otelcol_processor_dropped_spans` or `otelcol_processor_dropped_log_records` increasing

## Diagnosis

### 1. Check exporter queue health
```bash
# Queue utilization percentage (should stay below 75%)
otelcol_exporter_queue_size / otelcol_exporter_queue_capacity * 100

# Failed send attempts by exporter
rate(otelcol_exporter_send_failed_spans[5m])
rate(otelcol_exporter_send_failed_metric_points[5m])
rate(otelcol_exporter_send_failed_log_records[5m])

# Retry count - high values indicate persistent backend issues
rate(otelcol_exporter_retry_count[5m])
```

### 2. Check backend availability
```bash
# Test OTLP endpoint connectivity
curl -v https://otlp-gateway.example.com:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{"resourceSpans":[]}'

# DNS resolution
nslookup otlp-gateway.example.com

# Network connectivity from collector pod
kubectl exec -it <collector-pod> -- wget -qO- --spider https://otlp-gateway.example.com:4318
```

### 3. Check for authentication issues
```bash
# Look for 401/403 in collector logs
kubectl logs <collector-pod> | grep -E "(401|403|Unauthorized|Forbidden)"

# Verify API key is mounted
kubectl exec -it <collector-pod> -- env | grep API_KEY
```

### 4. Check incoming data volume
```bash
# Spikes in incoming data can overwhelm the queue
rate(otelcol_receiver_accepted_spans[5m])
rate(otelcol_receiver_accepted_metric_points[5m])
rate(otelcol_receiver_accepted_log_records[5m])
```

## Resolution

### Increase queue size (buys time during transient backend issues)
```yaml
exporters:
  otlp:
    sending_queue:
      enabled: true
      num_consumers: 20       # Increase parallel senders (default 10)
      queue_size: 10000       # Increase buffer (default 5000)
```

### Enable persistent queue (survives collector restarts)
```yaml
exporters:
  otlp:
    sending_queue:
      enabled: true
      storage: file_storage/otlp_queue
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s  # Retry for up to 5 minutes

extensions:
  file_storage/otlp_queue:
    directory: /var/lib/otelcol/queue
    timeout: 10s
    compaction:
      on_start: true
      directory: /tmp/otelcol_compaction
```

### Fix backend authentication
```bash
# Rotate API key
kubectl create secret generic otel-api-key \
  --from-literal=api-key=<new-key> \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart collector to pick up new secret
kubectl rollout restart deployment otel-collector
```

### Scale exporters with load balancing
```yaml
exporters:
  loadbalancing:
    protocol:
      otlp:
        endpoint: otel-collector-gateway-headless:4317
        tls:
          insecure: true
    resolver:
      dns:
        hostname: otel-collector-gateway-headless
        port: 4317
```

### Reduce incoming volume with filtering
```yaml
processors:
  filter/drop-health:
    error_mode: ignore
    traces:
      span:
        - 'attributes["http.route"] == "/healthz"'
        - 'attributes["http.route"] == "/readyz"'
    logs:
      log_record:
        - 'severity_number < SEVERITY_NUMBER_WARN'
```

## Prevention
- Monitor queue utilization with alert at 75%:
  ```
  otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.75
  ```
- Enable persistent queues for all production exporters
- Set `retry_on_failure` with reasonable `max_elapsed_time` (300s)
- Configure dead-letter queue (export to file/S3) for data that cannot be sent
- Implement backpressure via `memory_limiter` to prevent unbounded ingestion
- Run separate pipelines for traces, metrics, and logs so one failing backend does not block others
- Establish baseline throughput and alert on sudden spikes in `otelcol_receiver_accepted_*`
