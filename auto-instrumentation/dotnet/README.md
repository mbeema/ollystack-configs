# .NET Auto-Instrumentation with OpenTelemetry

## Overview

OpenTelemetry provides multiple instrumentation approaches for .NET applications. Choose based on your requirements:

## Instrumentation Approaches (Recommended Order)

| Priority | Approach | Zero-Code | Custom Spans | When to Use |
|----------|----------|-----------|--------------|-------------|
| **1st** | **OBI (eBPF)** | Yes | No | Network-level traces, zero code changes, kernel 5.17+ |
| **2nd** | **CLR Profiler auto-instrumentation** | Yes | No | Richer .NET-specific traces (ASP.NET Core, EF Core, HttpClient, etc.) |
| **3rd** | **NuGet SDK packages** | No | Yes | Custom business spans, metrics, or enrichment |

---

## Approach 1: OBI — OpenTelemetry eBPF Instrumentation (Start Here)

OBI is the **lowest-risk starting point** for any .NET service. It requires zero code changes, zero NuGet additions, and zero CLR profiler configuration.

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
- No framework-specific spans (e.g., ASP.NET Core route names, Entity Framework queries)
- No custom spans (use SDK for that)

> **When OBI is not enough:** If you need .NET-specific framework spans (ASP.NET Core, EF Core, HttpClient, etc.), HTTPS, or gRPC support, add the CLR Profiler (Approach 2).

---

## Approach 2: CLR Profiler Auto-Instrumentation (Richer .NET-Specific Traces)

This approach uses the OpenTelemetry .NET Automatic Instrumentation package, which leverages the CLR profiler to intercept method calls without code changes. Use this when OBI limitations apply or when you need richer trace detail.

### Install the auto-instrumentation package

```bash
# Download and install
curl -sSfL https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/latest/download/otel-dotnet-auto-install.sh | bash
```

### Set environment variables

```bash
# Enable the CLR profiler
export CORECLR_ENABLE_PROFILING=1
export CORECLR_PROFILER="{918728DD-259F-4A6A-AC2B-B85E1B658318}"
export CORECLR_PROFILER_PATH="/opt/otel-dotnet/linux-x64/OpenTelemetry.AutoInstrumentation.Native.so"

# Auto-instrumentation home directory
export DOTNET_ADDITIONAL_DEPS="/opt/otel-dotnet/AdditionalDeps"
export DOTNET_SHARED_STORE="/opt/otel-dotnet/store"
export DOTNET_STARTUP_HOOKS="/opt/otel-dotnet/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll"

# OTel configuration
export OTEL_SERVICE_NAME=my-dotnet-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production"

# Run the application
dotnet MyApp.dll
```

### Kubernetes Operator (Zero-Code)

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-dotnet: "true"
```

The Operator handles all profiler environment variables and file injection automatically.

---

## Approach 3: NuGet SDK Packages (Custom Business Spans Only)

Use NuGet SDK packages **only when you need custom business spans or metrics** that the CLR Profiler does not provide automatically.

### Step 1: Install NuGet Packages

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol

# Traces
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Instrumentation.SqlClient
dotnet add package OpenTelemetry.Instrumentation.EntityFrameworkCore
dotnet add package OpenTelemetry.Instrumentation.GrpcNetClient
dotnet add package OpenTelemetry.Instrumentation.StackExchangeRedis

# Metrics
dotnet add package OpenTelemetry.Instrumentation.Runtime
dotnet add package OpenTelemetry.Instrumentation.Process

# Logs
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol.Logs
```

### Step 2: Configure in Program.cs

```csharp
using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

// Configure OpenTelemetry
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(
        serviceName: builder.Configuration["OTEL_SERVICE_NAME"] ?? "my-dotnet-service",
        serviceVersion: "1.0.0"))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSqlClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddGrpcClientInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddProcessInstrumentation()
        .AddOtlpExporter())
    .WithLogging(logging => logging
        .AddOtlpExporter());

var app = builder.Build();
```

See `otel-config.cs` for the complete configuration example.

### Creating Custom Spans

```csharp
using System.Diagnostics;

// .NET uses System.Diagnostics.ActivitySource (maps to OTel Tracer)
private static readonly ActivitySource ActivitySource = new("MyApp.OrderService");

public async Task ProcessOrder(string orderId)
{
    using var activity = ActivitySource.StartActivity("ProcessOrder");
    activity?.SetTag("order.id", orderId);

    // ... business logic ...

    activity?.AddEvent(new ActivityEvent("OrderValidated"));
}
```

---

## Supported Libraries

| Library | Instrumentation Type |
|---------|---------------------|
| ASP.NET Core | Traces, Metrics |
| HttpClient / HttpWebRequest | Traces |
| SQL Client (System.Data.SqlClient) | Traces |
| Entity Framework Core | Traces |
| gRPC Client | Traces |
| StackExchange.Redis | Traces |
| MassTransit | Traces |
| NServiceBus | Traces |
| Elastic.Clients.Elasticsearch | Traces |
| MongoDB | Traces |
| MySqlConnector | Traces |
| Npgsql (PostgreSQL) | Traces |
| WCF | Traces |
| .NET Runtime | Metrics |
| Process | Metrics |
| ILogger | Logs |

## Key Environment Variables

| Variable | Description |
|----------|-------------|
| `OTEL_SERVICE_NAME` | Service name |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector endpoint |
| `CORECLR_ENABLE_PROFILING` | Enable CLR profiler (`1` or `0`) |
| `CORECLR_PROFILER` | Profiler CLSID |
| `CORECLR_PROFILER_PATH` | Path to native profiler library |
| `OTEL_DOTNET_AUTO_TRACES_ENABLED_INSTRUMENTATIONS` | Comma-separated list of enabled trace instrumentations |
| `OTEL_DOTNET_AUTO_METRICS_ENABLED_INSTRUMENTATIONS` | Comma-separated list of enabled metric instrumentations |
| `OTEL_DOTNET_AUTO_LOGS_ENABLED` | Enable log export (`true`/`false`) |

## References

- [OpenTelemetry .NET](https://opentelemetry.io/docs/instrumentation/net/)
- [Auto-Instrumentation](https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation)
- [NuGet Packages](https://www.nuget.org/profiles/OpenTelemetry)
- [OBI (eBPF) Distributed Traces](https://opentelemetry.io/docs/zero-code/obi/distributed-traces/)
