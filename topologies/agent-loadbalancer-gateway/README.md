# Agent-LoadBalancer-Gateway Topology (Three-Tier)

## Overview

The agent-loadbalancer-gateway topology is the production-grade pattern for
deployments that require correct tail sampling at scale. It introduces a
load-balancing tier between agents and gateways. The load balancer routes
spans by trace ID, ensuring that ALL spans belonging to a single trace
arrive at the SAME gateway instance. This is a hard requirement for tail
sampling to produce correct results.

Without trace-ID-aware routing, spans from the same trace can land on
different gateway instances. Each gateway only sees a partial trace and
cannot make accurate sampling decisions (e.g., "keep all spans if any
span has an error").

## Architecture Diagram

```
+----------+   +----------+   +----------+   +----------+
|  Host A  |   |  Host B  |   |  Host C  |   |  Host D  |
|  +-----+ |   |  +-----+ |   |  +-----+ |   |  +-----+ |
|  | App | |   |  | App | |   |  | App | |   |  | App | |
|  +--+--+ |   |  +--+--+ |   |  +--+--+ |   |  +--+--+ |
|     |    |   |     |    |   |     |    |   |     |    |
|  +--+--+ |   |  +--+--+ |   |  +--+--+ |   |  +--+--+ |
|  | Agt | |   |  | Agt | |   |  | Agt | |   |  | Agt | |
|  +--+--+ |   |  +--+--+ |   |  +--+--+ |   |  +--+--+ |
+-----+----+   +-----+----+   +-----+----+   +-----+----+
      |              |              |              |
      +--------------+--------------+--------------+
                           |
                           v
              +------------+-------------+
              |                          |
              |   OTel Load Balancer     |
              |                          |
              |   routing_key: traceID   |
              |   (consistent hashing)   |
              |                          |
              +-----+----------+--------+
                    |          |
          +---------+          +---------+
          |                              |
          v                              v
  +-------+--------+           +--------+-------+
  |                |           |                |
  |   Gateway #1   |           |   Gateway #2   |
  |                |           |                |
  |  tail_sampling |           |  tail_sampling |
  |  enrichment    |           |  enrichment    |
  |  batching      |           |  batching      |
  |                |           |                |
  +-------+--------+           +--------+-------+
          |                              |
          +---------+          +---------+
                    |          |
                    v          v
              +-----+----------+-----+
              |                      |
              |       Backend        |
              |   (Jaeger, Tempo,    |
              |    Grafana, etc.)    |
              |                      |
              +----------------------+
```

## Data Flow

1. Applications export telemetry to their local agent via OTLP.
2. Agents perform lightweight processing (resource detection, batching,
   memory limiting) and forward to the load balancer.
3. The load balancer examines each span's trace ID and uses consistent
   hashing to route ALL spans with the same trace ID to the SAME gateway
   instance.
4. Each gateway instance receives complete traces (all spans for a given
   trace ID). It performs tail sampling, enrichment, and batching.
5. Gateways export processed telemetry to the backend.

## Why Trace-ID Routing Matters

Tail sampling requires visibility into the complete trace to make decisions.
For example, a policy like "keep all spans if any span has status ERROR"
requires that the gateway sees every span in the trace. If spans are
distributed across multiple gateways via round-robin or random routing,
no single gateway has the full picture:

```
WITHOUT trace-ID routing (BROKEN tail sampling):

  Trace ABC: span1 -> Gateway #1  (sees 1/3 of trace)
  Trace ABC: span2 -> Gateway #2  (sees 1/3 of trace)
  Trace ABC: span3 -> Gateway #1  (sees 2/3 of trace)

  Neither gateway can make a correct sampling decision.

WITH trace-ID routing (CORRECT tail sampling):

  Trace ABC: span1 -> Gateway #1  (sees 1/3 of trace)
  Trace ABC: span2 -> Gateway #1  (sees 2/3 of trace)
  Trace ABC: span3 -> Gateway #1  (sees 3/3 = complete trace)

  Gateway #1 has the full trace and can correctly decide to keep or drop.
```

## Pros

- **Correct tail sampling at scale**: Trace-ID routing guarantees each
  gateway sees complete traces.
- **Horizontal scalability**: Add more gateway replicas as volume grows;
  the load balancer distributes traces evenly.
- **Centralized processing**: Sampling policies, enrichment, and filtering
  are configured only on the gateways.
- **High availability**: Multiple gateway replicas provide redundancy.
- **Separation of concerns**: Each tier has a clear, focused responsibility.

## Cons

- **Increased complexity**: Three tiers to deploy, configure, and monitor.
- **Load balancer is a critical component**: If the load balancer fails,
  telemetry flow stops. Consider running multiple LB replicas.
- **Consistent hashing rebalancing**: When gateways are added or removed,
  some traces in flight may be split across old and new assignments during
  the rebalancing window.
- **Higher resource requirements**: Three tiers consume more infrastructure
  than simpler topologies.

## When to Use

- **Large-scale production deployments** with 50+ hosts or services.
- **When tail sampling is required** and you need to scale gateways
  horizontally.
- **High-volume telemetry** environments where a single gateway cannot
  handle the throughput.
- **Multi-cluster or multi-region** deployments that need centralized
  processing with correct sampling.

## Kubernetes Considerations

In Kubernetes, the load balancer uses DNS-based service discovery with a
headless Service for the gateway StatefulSet. This allows the load
balancer to discover individual gateway pod IPs and route by trace ID.

```yaml
# Headless service for gateway pod discovery
apiVersion: v1
kind: Service
metadata:
  name: otel-gateway-headless
spec:
  clusterIP: None
  selector:
    app: otel-gateway
  ports:
    - port: 4317
      targetPort: 4317
```

## Files in This Directory

| File                       | Description                                        |
|----------------------------|----------------------------------------------------|
| `otel-agent.yaml`         | Agent collector configuration                      |
| `otel-loadbalancer.yaml`  | Load balancer with traceID routing                 |
| `otel-gateway.yaml`       | Gateway with tail sampling                         |
| `docker-compose.yaml`     | Docker Compose showing the three-tier topology     |
