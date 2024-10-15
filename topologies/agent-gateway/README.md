# Agent-Gateway Topology (Two-Tier)

## Overview

The agent-gateway topology introduces a second tier: a centralized gateway collector
that sits between the agents and the backend. Agents perform lightweight collection
and forward telemetry to the gateway. The gateway handles heavy processing such as
tail sampling, enrichment, and aggregation before exporting to the backend.

## Architecture Diagram

```
+------------------+    +------------------+    +------------------+
|     Host A       |    |     Host B       |    |     Host C       |
|                  |    |                  |    |                  |
| +------+  +---+  |    | +------+  +---+  |    | +------+  +---+  |
| | App  +->|Agt|  |    | | App  +->|Agt|  |    | | App  +->|Agt|  |
| +------+  +-+-+  |    | +------+  +-+-+  |    | +------+  +-+-+  |
+---------------+--+    +---------------+--+    +---------------+--+
                |                       |                       |
                |     OTLP/gRPC        |                       |
                +-----------+----------+-----------+-----------+
                            |                      |
                            v                      v
                   +--------+----------------------+--------+
                   |                                        |
                   |          OTel Collector (Gateway)      |
                   |                                        |
                   |  - Tail sampling                       |
                   |  - Resource enrichment                 |
                   |  - Large batch processing              |
                   |  - Aggregation                         |
                   |                                        |
                   +-------------------+--------------------+
                                       |
                                       | OTLP/gRPC
                                       v
                              +--------+--------+
                              |                 |
                              |    Backend      |
                              |  (Jaeger, etc.) |
                              |                 |
                              +-----------------+
```

## Data Flow

1. Applications export telemetry to their local agent via OTLP.
2. Agents perform lightweight processing:
   - Resource detection (host metadata)
   - Memory limiting and batching
   - No sampling at the agent level (delegated to gateway)
3. Agents forward all telemetry to the centralized gateway via OTLP.
4. The gateway performs heavy processing:
   - Tail sampling (keep error traces, slow traces, etc.)
   - Resource enrichment (add environment, cluster metadata)
   - Large-batch aggregation for efficient backend writes
5. The gateway exports processed telemetry to the backend.

## Pros

- **Centralized processing**: Configuration changes for sampling, enrichment,
  and filtering only need to be applied to the gateway.
- **Tail sampling support**: The gateway can collect spans from a full trace
  and make sampling decisions based on outcomes (errors, latency, etc.).
- **Reduced backend load**: The gateway batches and aggregates telemetry
  from many agents, reducing connections to the backend.
- **Separation of concerns**: Agents stay lightweight; heavy processing
  is offloaded to dedicated gateway infrastructure.
- **Easier upgrades**: Gateway can be upgraded independently of agents.

## Cons

- **Single gateway is a bottleneck**: One gateway instance can become a
  throughput bottleneck or single point of failure.
- **Tail sampling correctness**: Without a load balancer routing by trace ID,
  spans from the same trace may arrive at different gateway instances
  (if scaled horizontally), breaking tail sampling decisions.
  For correct tail sampling at scale, use the agent-loadbalancer-gateway topology.
- **Additional infrastructure**: Requires deploying and managing the gateway
  in addition to agents.
- **Network hop**: Adds latency from the extra hop through the gateway.

## When to Use

- **Medium deployments** with 10-50 hosts or services.
- **When tail sampling is needed** but deployment scale does not yet require
  a dedicated load-balancing tier.
- **Centralized configuration** is important for your operations team.
- **When a single gateway instance can handle the total telemetry volume**.
  If not, consider the agent-loadbalancer-gateway topology.

## Files in This Directory

| File                  | Description                                      |
|-----------------------|--------------------------------------------------|
| `otel-agent.yaml`    | Agent collector configuration (lightweight)      |
| `otel-gateway.yaml`  | Gateway collector configuration (heavy processing)|
| `docker-compose.yaml`| Docker Compose showing the two-tier topology     |
