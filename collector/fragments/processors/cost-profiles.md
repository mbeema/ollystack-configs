# Cost Optimization Profiles

Recommended processor fragment combinations for different environments.
Apply these as additional `--config` layers on top of your base pipeline.

## Production — Aggressive Cost Control

Keep only actionable data. Typical savings: **60-80% volume reduction**.

```bash
otelcol --config=base.yaml \
  --config=filter-logs-severity.yaml \          # WARN+ only (drop INFO/DEBUG)
  --config=filter-logs.yaml \                   # Drop health checks
  --config=transform-logs-cost.yaml \           # Truncate bodies, strip stacks
  --config=filter-traces.yaml \                 # Drop health check spans
  --config=filter-traces-noisy.yaml \           # Drop static assets, OPTIONS
  --config=transform-traces-cost.yaml \         # Remove high-card attrs, truncate
  --config=filter-metrics-cardinality.yaml \    # Strip pod_uid, IPs, etc.
  --config=filter-metrics.yaml \                # Drop idle CPU, runtime metrics
  --config=tail-sampling-composite.yaml \       # Keep errors + slow, sample 10%
  --config=redaction.yaml \                     # Mask PII
  --config=batch.yaml
```

Environment variables:
```bash
LOG_MIN_SEVERITY=SEVERITY_NUMBER_WARN  # Only WARN, ERROR, FATAL
```

## Staging — Balanced

Enough data for debugging, with cost controls. Typical savings: **30-50%**.

```bash
otelcol --config=base.yaml \
  --config=filter-logs-severity.yaml \          # INFO+ (drop DEBUG)
  --config=filter-logs.yaml \                   # Drop health checks
  --config=filter-traces.yaml \                 # Drop health check spans
  --config=filter-traces-noisy.yaml \           # Drop static assets, OPTIONS
  --config=filter-metrics-cardinality.yaml \    # Strip pod_uid, IPs
  --config=probabilistic-sampling-head.yaml \   # 50% head sampling
  --config=batch.yaml
```

Environment variables:
```bash
LOG_MIN_SEVERITY=SEVERITY_NUMBER_INFO
SAMPLING_PERCENTAGE=50
```

## Development — Full Fidelity

Keep everything for debugging. Only remove known noise.

```bash
otelcol --config=base.yaml \
  --config=filter-logs.yaml \       # Drop health checks only
  --config=filter-traces.yaml \     # Drop health check spans only
  --config=batch.yaml
```

## Pipeline Order

**Order matters.** Processors run in the order they appear in the `service.pipeline` section.
The recommended order for cost optimization:

```yaml
service:
  pipelines:
    traces:
      processors:
        - memory_limiter          # 1. Back-pressure (always first)
        - resourcedetection       # 2. Add cloud/host metadata
        - k8sattributes           # 3. Add K8s metadata
        - filter/traces           # 4. Drop health checks
        - filter/traces-noisy     # 5. Drop static assets, OPTIONS
        - transform/traces-cost   # 6. Strip high-card attrs, truncate
        - redaction               # 7. Mask PII
        - tail_sampling/composite # 8. Sample (after enrichment, before batch)
        - batch                   # 9. Batch for export (always last)

    metrics:
      processors:
        - memory_limiter
        - resourcedetection
        - k8sattributes
        - filter/metrics          # Drop idle CPU, runtime metrics
        - transform/reduce-cardinality  # Strip high-card attributes
        - cumulativetodelta       # Convert to delta if backend prefers it
        - batch

    logs:
      processors:
        - memory_limiter
        - resourcedetection
        - k8sattributes
        - filter/log-severity     # Drop below WARN/INFO
        - filter/logs             # Drop health checks
        - transform/logs          # Parse JSON, extract severity
        - transform/logs-cost     # Truncate bodies, strip stacks
        - redaction               # Mask PII
        - batch
```
