# Agent-Only Topology

## Overview

The agent-only topology is the simplest OpenTelemetry Collector deployment pattern.
A single collector instance runs as an agent alongside (or on the same host as) the
application. The agent receives telemetry, performs lightweight processing, and exports
directly to the observability backend.

## Architecture Diagram

```
+---------------------------------------------+
|                   Host / VM                  |
|                                              |
|  +-------------+       +-----------------+   |
|  |             |  OTLP |                 |   |
|  | Application +------>+ OTel Collector  |   |
|  |             |       |   (Agent)       |   |
|  +-------------+       +--------+--------+   |
|                                 |            |
+---------------------------------------------+
                                  |
                                  | OTLP/gRPC
                                  v
                        +------------------+
                        |                  |
                        |  Backend         |
                        |  (Jaeger, Tempo, |
                        |   Grafana, etc.) |
                        |                  |
                        +------------------+
```

## Data Flow

1. Application instruments code with OpenTelemetry SDK.
2. SDK exports telemetry (traces, metrics, logs) via OTLP to the local collector agent.
3. The agent applies lightweight processing:
   - Resource detection (host metadata)
   - Head-based probabilistic sampling
   - Batching and memory limiting
4. The agent exports processed telemetry directly to the backend.

## Pros

- **Simplicity**: Single collector component to deploy and manage.
- **Low latency**: Minimal hops between application and backend.
- **Easy to debug**: Straightforward data path with no intermediaries.
- **Minimal infrastructure**: No gateway or load balancer needed.
- **Fast onboarding**: Ideal for getting started with OpenTelemetry.

## Cons

- **No tail sampling**: Head-based sampling only; cannot make sampling decisions based
  on the full trace (e.g., keep all error traces).
- **No centralized processing**: Each agent processes independently; configuration
  changes must be deployed to every host.
- **Limited scalability**: Each agent exports directly to the backend, which may
  overwhelm the backend with many agents.
- **No cross-host aggregation**: Metrics aggregation or trace-aware routing is
  not possible at this tier.
- **Single point of failure per host**: If the agent goes down, telemetry from
  that host is lost.

## When to Use

- **Small deployments** with fewer than ~10 hosts or services.
- **Development and testing** environments where simplicity matters most.
- **Proof-of-concept** setups to evaluate OpenTelemetry quickly.
- **When tail sampling is not required** -- head-based probabilistic sampling is
  sufficient for your use case.
- **When the backend can handle direct connections** from all agents without
  becoming a bottleneck.

## Files in This Directory

| File                  | Description                                         |
|-----------------------|-----------------------------------------------------|
| `otel-agent.yaml`    | Complete collector agent configuration              |
| `docker-compose.yaml`| Docker Compose showing the full agent-only topology |
