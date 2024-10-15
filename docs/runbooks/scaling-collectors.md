# Runbook: Scaling Collectors

## Symptoms
- Single collector instance at CPU or memory capacity
- Uneven load distribution across collector replicas
- Tail sampling producing incomplete traces (spans for the same trace split across collectors)
- `otelcol_exporter_queue_size` consistently near capacity
- Increasing data drop rate under load
- Latency spikes during peak traffic hours

## Diagnosis

### 1. Check per-collector throughput
```bash
# Spans per second per collector
rate(otelcol_receiver_accepted_spans{job="otel-collector"}[5m])

# Metric points per second per collector
rate(otelcol_receiver_accepted_metric_points{job="otel-collector"}[5m])

# Log records per second per collector
rate(otelcol_receiver_accepted_log_records{job="otel-collector"}[5m])

# Check resource utilization
kubectl top pods -l app=otel-collector --sort-by=cpu
kubectl top pods -l app=otel-collector --sort-by=memory
```

### 2. Identify the bottleneck tier
```bash
# Agent tier (DaemonSet) - one per node
kubectl get ds otel-collector-agent -o wide
kubectl top pods -l app=otel-collector-agent

# Gateway tier (Deployment) - shared pool
kubectl get deploy otel-collector-gateway -o wide
kubectl top pods -l app=otel-collector-gateway

# Check if agents are sending to an overloaded gateway
rate(otelcol_exporter_send_failed_spans{exporter="otlp/gateway"}[5m])
```

### 3. Check load distribution
```bash
# Compare throughput across replicas - should be roughly even
sum by (pod) (rate(otelcol_receiver_accepted_spans[5m]))

# Check if K8s Service is distributing evenly
kubectl describe endpoints otel-collector-gateway
```

### 4. Evaluate tail sampling completeness
```bash
# Check if trace-aware routing is in place
# Without it, spans for one trace may land on different collectors
# causing incomplete sampling decisions

# Sampling decision metrics
rate(otelcol_processor_tail_sampling_count_traces_sampled[5m])
rate(otelcol_processor_tail_sampling_count_traces_dropped[5m])

# If sampling_decision != expected_rate, spans may be split
```

## Resolution

### Scale agent tier (DaemonSet)
Agents run as a DaemonSet, one per node. Scaling means adjusting resources per agent.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-collector-agent
spec:
  template:
    spec:
      containers:
        - name: otel-collector
          resources:
            requests:
              cpu: "250m"
              memory: "256Mi"
            limits:
              cpu: "1000m"        # Increase if throttled
              memory: "512Mi"
          env:
            - name: GOMAXPROCS
              value: "2"          # Match CPU limit
```

### Scale gateway tier with HPA
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: otel-collector-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-collector-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
    # Custom metric: scale on queue utilization
    - type: Pods
      pods:
        metric:
          name: otelcol_exporter_queue_size
        target:
          type: AverageValue
          averageValue: "3000"     # Scale up when queue > 3000
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
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
```

### Deploy load-balancing tier for trace-aware routing
```yaml
# Load-balancer tier config (Deployment, separate from gateway)
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

exporters:
  loadbalancing:
    routing_key: "traceID"           # Route all spans of a trace to same gateway
    protocol:
      otlp:
        tls:
          insecure: true
    resolver:
      dns:
        hostname: otel-collector-gateway-headless
        port: 4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter]
      exporters: [loadbalancing]
    # Metrics and logs do not need trace-aware routing
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/gateway]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/gateway]
```

Headless service for the gateway:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: otel-collector-gateway-headless
spec:
  clusterIP: None
  selector:
    app: otel-collector-gateway
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
```

### Three-tier architecture deployment
```
Agents (DaemonSet)
    |
    v
Load Balancers (Deployment, 2-3 replicas)
    |  trace-aware routing (loadbalancing exporter)
    v
Gateways (Deployment, HPA-managed)
    |  full processing: filter, transform, sample, batch
    v
Backends (Datadog, Splunk, etc.)
```

```bash
# Deploy all three tiers
kubectl apply -f collector-agent-daemonset.yaml
kubectl apply -f collector-lb-deployment.yaml
kubectl apply -f collector-gateway-deployment.yaml
kubectl apply -f collector-gateway-hpa.yaml
```

### Manual scaling commands
```bash
# Scale gateway immediately
kubectl scale deployment otel-collector-gateway --replicas=5

# Verify scaling
kubectl rollout status deployment otel-collector-gateway
kubectl get pods -l app=otel-collector-gateway -o wide
```

## Capacity Planning Formulas

### Agent sizing (per node)
```
CPU (cores)  = (spans/sec * 0.001) + (metrics/sec * 0.0005) + (logs/sec * 0.0008)
Memory (MiB) = base(100) + (queue_size * avg_item_size_kb / 1024) + batch_buffer(50)
```

### Gateway sizing (per replica)
```
CPU (cores)  = (total_spans/sec / num_replicas * 0.002) + processor_overhead
Memory (MiB) = base(200) + (queue_size * avg_item_size_kb / 1024) + sampling_buffer
```

### Rule of thumb
| Throughput            | Agent CPU | Agent Memory | Gateway Replicas |
|-----------------------|-----------|-------------|------------------|
| < 1K spans/sec/node   | 250m      | 256Mi       | 2                |
| 1K-5K spans/sec/node  | 500m      | 512Mi       | 3-5              |
| 5K-20K spans/sec/node | 1000m     | 1Gi         | 5-10             |
| > 20K spans/sec/node  | 2000m     | 2Gi         | 10+              |

## Prevention
- Deploy HPA on gateway tier from day one; do not wait for capacity issues
- Use the `loadbalancing` exporter for all trace pipelines that use tail sampling
- Monitor per-collector throughput and set alerts when any single collector exceeds 70% capacity
- Run capacity planning quarterly based on traffic growth projections
- Use `PodDisruptionBudget` to prevent all gateway replicas from being evicted simultaneously:
  ```yaml
  apiVersion: policy/v1
  kind: PodDisruptionBudget
  metadata:
    name: otel-gateway-pdb
  spec:
    minAvailable: 2
    selector:
      matchLabels:
        app: otel-collector-gateway
  ```
- Separate metrics, traces, and logs into independent gateway pools if one signal type dominates throughput
- Use pod topology spread constraints to distribute collectors across availability zones
