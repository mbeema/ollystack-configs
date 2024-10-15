# Go Instrumentation with OpenTelemetry

## Overview

Unlike Java, Python, Node.js, and .NET, **Go does not support traditional auto-instrumentation** because Go compiles to native binaries without a runtime that can intercept calls dynamically. This makes Go a prime candidate for **eBPF-based instrumentation**.

## Instrumentation Approaches (Recommended Order)

| Priority | Approach | Zero-Code | Custom Spans | When to Use |
|----------|----------|-----------|--------------|-------------|
| **1st** | **OBI (eBPF)** | Yes | No | Default choice — zero-code, network-level traces |
| **2nd** | **Go eBPF library probes** | Yes | No | Enhanced Go-specific coverage (net/http, database/sql, gRPC) |
| **3rd** | **Manual SDK** | No | Yes | Custom business spans, metrics, or enrichment |

---

## Approach 1: OBI — OpenTelemetry eBPF Instrumentation (Recommended)

OBI is the **recommended starting point** for Go services. Because Go has no runtime agent, eBPF is the only true zero-code option.

OBI deploys as a **DaemonSet** on each node and uses kernel-level eBPF probes to automatically capture HTTP traces and propagate W3C `traceparent` headers — no code changes, no recompilation.

### Prerequisites

- Linux kernel **5.17+** with BTF support
- Kubernetes cluster (DaemonSet deployment)
- Services using **plain HTTP/1.1** (not gRPC or HTTPS at the pod level)

### Deployment

OBI runs as a DaemonSet with `hostNetwork: true`. See the [OBI documentation](https://opentelemetry.io/docs/zero-code/obi/distributed-traces/) for deployment manifests.

### What OBI captures for Go

- Inbound and outbound HTTP requests (method, path, status, duration)
- Distributed trace context propagation (W3C `traceparent`)
- Network-level metrics (request rate, error rate, latency)

### Limitations

- No HTTPS header injection (TCP/IP level only — use sidecar/mesh for TLS termination)
- No gRPC/HTTP2 support yet
- No custom spans (use SDK for that)
- Kernel 5.17+ required

> **When OBI is not enough:** If your Go service uses gRPC, HTTP/2, or you need custom business spans, add the Go eBPF library probes (Approach 2) or SDK instrumentation (Approach 3).

---

## Approach 2: Go eBPF Library Probes (Enhanced Go Coverage)

The OpenTelemetry Go eBPF instrumentation project provides library-level probes that go beyond network-level tracing. These attach to specific Go standard library functions.

### Prerequisites

- OpenTelemetry Operator installed in the cluster
- Linux kernel 4.19+ with BTF support
- Pods must run with sufficient privileges for eBPF

### Usage

Annotate your deployment:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-go: "true"
    instrumentation.opentelemetry.io/otel-go-auto-target-exe: "/app/server"
```

The `otel-go-auto-target-exe` annotation specifies the path to the Go binary inside the container.

### Supported libraries

- `net/http` (client and server)
- `database/sql`
- `google.golang.org/grpc` (client and server)

### Limitations

- Requires privileged containers or specific Linux capabilities
- Does not support custom spans
- Binary must not be stripped (needs DWARF debug info) in some implementations
- Limited to the supported library list above

---

## Approach 3: Manual SDK Instrumentation (Advanced Use Cases)

Use SDK instrumentation **only when you need custom business spans, metrics, or fine-grained control** that eBPF cannot provide.

### Install Dependencies

```bash
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/sdk
go get go.opentelemetry.io/otel/sdk/trace
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
go get go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc
go get go.opentelemetry.io/otel/sdk/metric
go get go.opentelemetry.io/otel/propagation
go get go.opentelemetry.io/otel/semconv/v1.26.0
```

### Instrumentation Libraries

For common frameworks, use the contrib instrumentation libraries:

```bash
# HTTP
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp

# gRPC
go get go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc

# Database
go get go.opentelemetry.io/contrib/instrumentation/database/sql/otelsql

# AWS SDK
go get go.opentelemetry.io/contrib/instrumentation/github.com/aws/aws-sdk-go-v2/otelaws

# Gin
go get go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin

# Echo
go get go.opentelemetry.io/contrib/instrumentation/github.com/labstack/echo/otelecho
```

### Basic Setup

See `main.go` in this directory for a complete example. The key steps are:

```go
// 1. Create a Resource
resource := resource.NewWithAttributes(
    semconv.SchemaURL,
    semconv.ServiceNameKey.String("my-go-service"),
)

// 2. Create an OTLP exporter
exporter, _ := otlptracegrpc.New(ctx, otlptracegrpc.WithEndpoint("otel-collector:4317"))

// 3. Create a TracerProvider
tp := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
    sdktrace.WithResource(resource),
)
otel.SetTracerProvider(tp)
defer tp.Shutdown(ctx)

// 4. Set propagator
otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
    propagation.TraceContext{},
    propagation.Baggage{},
))
```

### Instrumenting HTTP

```go
// Wrap your HTTP handler with otelhttp
handler := otelhttp.NewHandler(mux, "server")
http.ListenAndServe(":8080", handler)

// Wrap outgoing HTTP client
client := &http.Client{
    Transport: otelhttp.NewTransport(http.DefaultTransport),
}
```

### Instrumenting gRPC

```go
// Server
grpcServer := grpc.NewServer(
    grpc.StatsHandler(otelgrpc.NewServerHandler()),
)

// Client
conn, _ := grpc.Dial(addr,
    grpc.WithStatsHandler(otelgrpc.NewClientHandler()),
)
```

## Key Libraries

| Library | Import Path |
|---------|-------------|
| Core API | `go.opentelemetry.io/otel` |
| SDK (Traces) | `go.opentelemetry.io/otel/sdk/trace` |
| SDK (Metrics) | `go.opentelemetry.io/otel/sdk/metric` |
| OTLP Trace Exporter (gRPC) | `go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc` |
| OTLP Metric Exporter (gRPC) | `go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc` |
| Propagation | `go.opentelemetry.io/otel/propagation` |
| Semantic Conventions | `go.opentelemetry.io/otel/semconv/v1.26.0` |
| HTTP Instrumentation | `go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp` |
| gRPC Instrumentation | `go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc` |
| SQL Instrumentation | `go.opentelemetry.io/contrib/instrumentation/database/sql/otelsql` |
| Gin Middleware | `go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin` |

## Troubleshooting

```go
// Enable verbose OTel SDK logging
import "go.opentelemetry.io/otel/sdk/trace"

tp := sdktrace.NewTracerProvider(
    sdktrace.WithBatcher(exporter),
    // Use a simple span processor for debugging (exports immediately)
    // sdktrace.WithSyncer(exporter),
)
```

```bash
# Set OTel SDK log level via env
export OTEL_LOG_LEVEL=debug
```

## References

- [OpenTelemetry Go](https://opentelemetry.io/docs/instrumentation/go/)
- [Go Contrib Instrumentations](https://github.com/open-telemetry/opentelemetry-go-contrib/tree/main/instrumentation)
- [eBPF Auto-Instrumentation](https://github.com/open-telemetry/opentelemetry-go-instrumentation)
- [OBI (eBPF) Distributed Traces](https://opentelemetry.io/docs/zero-code/obi/distributed-traces/)
