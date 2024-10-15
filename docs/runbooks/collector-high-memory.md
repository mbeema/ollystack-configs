# Runbook: Collector High Memory Usage

## Symptoms
- Collector pods OOMKilled repeatedly
- `otelcol_process_memory_rss` exceeds 80% of pod memory limit
- `memory_limiter` processor dropping data (logs show "Memory usage is above hard limit")
- Kubernetes events: `OOMKilled`, `Evicted`

## Diagnosis

### 1. Check current memory usage
```bash
# Prometheus query
otelcol_process_memory_rss{job="otel-collector"}

# Kubectl
kubectl top pods -l app=otel-collector
kubectl describe pod <collector-pod> | grep -A5 "Last State"
```

### 2. Identify the cause
```bash
# Check queue sizes - large queues consume memory
otelcol_exporter_queue_size{job="otel-collector"}

# Check batch processor buffer
otelcol_processor_batch_batch_size_trigger_send{job="otel-collector"}

# Check if specific pipeline is the culprit
otelcol_receiver_accepted_spans{job="otel-collector"}
otelcol_receiver_accepted_metric_points{job="otel-collector"}
otelcol_receiver_accepted_log_records{job="otel-collector"}
```

### 3. Check for memory leaks
```bash
# Enable pprof and capture heap profile
curl http://localhost:1777/debug/pprof/heap > heap.prof
go tool pprof heap.prof
```

## Resolution

### Immediate: Increase memory_limiter thresholds
```yaml
processors:
  memory_limiter:
    limit_mib: 1024        # Increase from 512
    spike_limit_mib: 256   # Increase from 128
    check_interval: 1s
```

### Reduce queue sizes
```yaml
exporters:
  otlp:
    sending_queue:
      queue_size: 500      # Reduce from default 5000
```

### Reduce batch sizes
```yaml
processors:
  batch:
    send_batch_size: 4096  # Reduce from 8192
    send_batch_max_size: 8192
    timeout: 2s            # Reduce from 5s
```

### Scale horizontally
```bash
kubectl scale deployment otel-collector-gateway --replicas=3
```

## Prevention
- Set `memory_limiter` as the **first** processor in every pipeline
- Set pod memory limits to 2x the `memory_limiter.limit_mib` value
- Monitor `otelcol_process_memory_rss` with alerts at 70% and 85%
- Use `sending_queue.queue_size` proportional to available memory
- Enable tail sampling to reduce trace volume before export
