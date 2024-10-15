# Java Auto-Instrumentation with OpenTelemetry

## Overview

OpenTelemetry provides multiple instrumentation approaches for Java applications. Choose based on your requirements:

## Instrumentation Approaches (Recommended Order)

| Priority | Approach | Zero-Code | Custom Spans | When to Use |
|----------|----------|-----------|--------------|-------------|
| **1st** | **OBI (eBPF)** | Yes | No | Network-level traces, zero code changes, kernel 5.17+ |
| **2nd** | **Java Agent JAR** | Yes | No | Full-fidelity traces with framework-aware spans (HTTPS, gRPC, HTTP/2) |
| **3rd** | **SDK (programmatic)** | No | Yes | Custom business spans, metrics, or enrichment |

---

## Approach 1: OBI — OpenTelemetry eBPF Instrumentation (Start Here)

OBI is the **lowest-risk starting point** for any Java service. It requires zero code changes, zero dependency additions, and zero build-pipeline modifications.

OBI deploys as a **DaemonSet** on each Kubernetes node and uses kernel-level eBPF probes to automatically capture HTTP traces and propagate W3C `traceparent` headers.

### Prerequisites

- Linux kernel **5.17+** with BTF support
- Kubernetes cluster (DaemonSet deployment)
- Services using **plain HTTP/1.1** (not gRPC or HTTPS at the pod level)

### What OBI captures

- Inbound and outbound HTTP requests (method, path, status, duration)
- Distributed trace context propagation (W3C `traceparent`)
- Network-level metrics (request rate, error rate, latency)

### Limitations

- No HTTPS header injection (TCP/IP level only — use sidecar/mesh for TLS termination)
- No gRPC/HTTP2 support yet
- No framework-specific spans (e.g., Spring MVC controller names, JDBC queries)
- No custom spans (use SDK for that)

> **When OBI is not enough:** If you need framework-aware spans (Spring Boot, Hibernate, Kafka, etc.), HTTPS, or gRPC support, add the Java Agent (Approach 2).

---

## Approach 2: Java Agent JAR (Full-Fidelity Traces)

The Java agent provides **deep, framework-aware instrumentation** without code changes. Use this when OBI limitations apply or when you need richer trace detail.

```bash
# Download the latest agent
curl -L -o opentelemetry-javaagent.jar \
  https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Run your application with the agent
java -javaagent:/path/to/opentelemetry-javaagent.jar \
  -Dotel.service.name=my-java-service \
  -Dotel.exporter.otlp.endpoint=http://otel-collector:4317 \
  -jar my-app.jar
```

Alternatively, use the `JAVA_TOOL_OPTIONS` environment variable:

```bash
export JAVA_TOOL_OPTIONS="-javaagent:/opt/otel/opentelemetry-javaagent.jar"
export OTEL_SERVICE_NAME=my-java-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
java -jar my-app.jar
```

### Build-Time Instrumentation

For cases where runtime agent attachment is not possible, you can apply instrumentation at build time using the OpenTelemetry Gradle or Maven plugins.

**Gradle:**

```groovy
plugins {
    id("io.opentelemetry.instrumentation.muzzle-generation") version "1.32.0"
}
```

**Maven:**

```xml
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-instrumentation-api</artifactId>
    <version>1.32.0</version>
</dependency>
```

### Kubernetes Operator (Zero-Code)

If you are running on Kubernetes, the OpenTelemetry Operator can inject the agent automatically via a mutating webhook. Simply annotate your workload:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
```

The Operator will inject an init container that copies the agent JAR and sets `JAVA_TOOL_OPTIONS` automatically.

---

## Approach 3: SDK Instrumentation (Custom Business Spans Only)

Use SDK instrumentation **only when you need custom business spans or metrics** that the Java Agent does not provide automatically.

Most teams should **start with OBI or the Java Agent** and layer SDK instrumentation only where it adds measurable business value (e.g., tracking order processing stages, payment flows, or domain-specific metrics).

---

## Key Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `OTEL_SERVICE_NAME` | Logical name of the service | `order-service` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint | `http://otel-collector:4317` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | Protocol (grpc or http/protobuf) | `grpc` |
| `OTEL_TRACES_EXPORTER` | Traces exporter type | `otlp` |
| `OTEL_METRICS_EXPORTER` | Metrics exporter type | `otlp` |
| `OTEL_LOGS_EXPORTER` | Logs exporter type | `otlp` |
| `OTEL_RESOURCE_ATTRIBUTES` | Additional resource attributes | `deployment.environment=prod` |
| `OTEL_PROPAGATORS` | Context propagation format | `tracecontext,baggage` |
| `OTEL_TRACES_SAMPLER` | Sampling strategy | `parentbased_traceidratio` |
| `OTEL_TRACES_SAMPLER_ARG` | Sampler argument (e.g., ratio) | `0.1` |

## Supported Frameworks and Libraries

The Java agent automatically instruments the following (partial list):

**Web Frameworks:**
- Spring Boot / Spring MVC / Spring WebFlux
- Jakarta Servlet / JAX-RS
- Apache Struts
- Vert.x
- Micronaut
- Quarkus

**HTTP Clients:**
- Apache HttpClient
- OkHttp
- Java HttpURLConnection
- Reactor Netty
- Spring RestTemplate / WebClient

**Databases:**
- JDBC (all drivers)
- Hibernate / JPA
- MongoDB
- Cassandra
- Elasticsearch
- R2DBC

**Messaging:**
- Apache Kafka
- RabbitMQ
- JMS
- Apache Pulsar
- AWS SQS / SNS

**Other:**
- gRPC
- GraphQL
- Redis (Jedis, Lettuce)
- AWS SDK v1 and v2
- Logback / Log4j (log correlation)

## Troubleshooting

```bash
# Enable debug logging for the agent
export OTEL_JAVAAGENT_DEBUG=true

# Verify agent is loaded
java -javaagent:/opt/otel/opentelemetry-javaagent.jar -jar app.jar 2>&1 | grep "opentelemetry"
```

## References

- [OpenTelemetry Java Instrumentation](https://github.com/open-telemetry/opentelemetry-java-instrumentation)
- [Supported Libraries](https://github.com/open-telemetry/opentelemetry-java-instrumentation/blob/main/docs/supported-libraries.md)
- [Configuration Reference](https://opentelemetry.io/docs/instrumentation/java/automatic/agent-config/)
- [OBI (eBPF) Distributed Traces](https://opentelemetry.io/docs/zero-code/obi/distributed-traces/)
