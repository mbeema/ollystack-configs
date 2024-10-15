# Sidecar Topology

## Overview

The sidecar topology deploys an OpenTelemetry Collector container alongside
each application container within the same Kubernetes Pod. The collector
runs as a sidecar -- a helper container that shares the Pod's network
namespace and optionally its volumes. The application sends telemetry to
localhost, and the sidecar forwards it to a gateway or directly to a backend.

This pattern is common in service mesh architectures (similar to Envoy
sidecars in Istio) and provides strong per-service isolation.

## Architecture Diagram

```
+--------------------------------------------------------------+
|                        Kubernetes Pod                        |
|                                                              |
|  +-------------------+         +-------------------------+   |
|  |                   |  OTLP   |                         |   |
|  |   Application     | ------> |   OTel Collector        |   |
|  |   Container       |localhost |   (Sidecar)             |   |
|  |                   | :4317   |                         |   |
|  +-------------------+         +------------+------------+   |
|                                             |                |
|  Shared volumes (optional):                 |                |
|  - /var/log/app (app writes, sidecar reads) |                |
|                                             |                |
+--------------------------------------------------------------+
                                              |
                                              | OTLP/gRPC
                                              v
                              +---------------+----------------+
                              |                                |
                              |     OTel Gateway / Backend     |
                              |                                |
                              +--------------------------------+

Multiple Pods with sidecars:

  +-------+  +-------+  +-------+  +-------+
  |Pod    |  |Pod    |  |Pod    |  |Pod    |
  |App+SC |  |App+SC |  |App+SC |  |App+SC |
  +---+---+  +---+---+  +---+---+  +---+---+
      |          |          |          |
      +----------+-----+----+----------+
                       |
                       v
              +--------+--------+
              |                 |
              |    Gateway      |
              |    or Backend   |
              |                 |
              +-----------------+
```

## Data Flow

1. The application container sends telemetry via OTLP to `localhost:4317`
   (the sidecar shares the Pod network namespace).
2. The sidecar collector receives telemetry, applies lightweight processing
   (batching, memory limiting), and exports to a gateway or backend.
3. Optionally, the sidecar can read application log files from a shared
   volume mounted between the app and sidecar containers.

## Pros

- **Per-service isolation**: Each service has its own collector. A noisy
  or misbehaving service cannot affect others' telemetry collection.
- **Independent lifecycle**: The sidecar collector can be upgraded
  independently from the application (within Pod restart constraints).
- **Localhost communication**: No network hops for the first leg; the
  application sends to localhost, minimizing latency and failure modes.
- **Custom configuration per service**: Each sidecar can have a tailored
  collector configuration (e.g., different sampling rates, custom
  processors) without affecting other services.
- **Service mesh alignment**: Follows the same pattern as Envoy/Istio
  sidecars, familiar to teams using service meshes.
- **OTel Operator support**: The OpenTelemetry Operator can automatically
  inject sidecars via annotation, simplifying deployment.

## Cons

- **Resource overhead**: Every Pod gets its own collector, which adds CPU
  and memory overhead multiplied by the number of Pods.
- **Configuration sprawl**: Managing unique configs per service can become
  complex at scale. The OTel Operator helps by injecting a common sidecar
  configuration.
- **No cross-Pod processing**: Each sidecar only sees its own Pod's
  telemetry. Cross-service aggregation or tail sampling requires a
  downstream gateway.
- **Pod restart coupling**: Updating the sidecar configuration or image
  requires a Pod restart, which also restarts the application container.
- **Not suitable for DaemonSet use cases**: Host-level metrics (CPU,
  memory, disk) are better collected by a DaemonSet agent, not a sidecar.

## When to Use

- **Per-service isolation is required**: Noisy neighbors are a concern,
  or services have different reliability requirements.
- **Custom collector config per service**: Different services need
  different processors, sampling rates, or exporters.
- **Service mesh pattern**: Your team is already familiar with sidecar
  patterns from Istio/Envoy.
- **Kubernetes-native deployments**: You are running on Kubernetes and
  can leverage the OTel Operator for automatic sidecar injection.
- **Complement to a gateway**: Sidecars handle per-Pod collection;
  a gateway handles centralized processing (tail sampling, enrichment).

## Deployment Methods

### Manual Sidecar (Pod Spec)

Add the collector container directly to your Pod spec. See
`pod-with-sidecar.yaml` for a complete example.

### OTel Operator Auto-Injection

The OpenTelemetry Operator can automatically inject a sidecar collector
into any Pod that has the annotation:

```yaml
sidecar.opentelemetry.io/inject: "true"
```

See `otel-operator-sidecar.yaml` for the Operator CR that defines the
sidecar configuration.

## Files in This Directory

| File                        | Description                                      |
|-----------------------------|--------------------------------------------------|
| `otel-sidecar.yaml`        | Sidecar collector configuration                  |
| `pod-with-sidecar.yaml`    | K8s Pod spec with manual sidecar injection        |
| `otel-operator-sidecar.yaml`| OTel Operator CR for automatic sidecar injection |
