# OpenTelemetry Instrumentation Deep Dive: All Languages

> Comprehensive technical reference covering auto-instrumentation, SDK manual instrumentation, metrics, logs, configuration, framework integrations, context propagation, sampling, performance, and production best practices for Java, .NET, Python, Node.js/TypeScript, Go, Rust, PHP, Ruby, and Swift/Mobile.

---

## Table of Contents

### Part I: Java
1. [Auto-Instrumentation Agent (javaagent)](#1-java-auto-instrumentation-agent)
2. [SDK Manual Instrumentation](#2-java-sdk-manual-instrumentation)
3. [Metrics API](#3-java-metrics-api)
4. [Logs API (Log4j2/Logback Bridge)](#4-java-logs-api)
5. [Configuration](#5-java-configuration)
6. [Spring Boot Starter](#6-spring-boot-starter)
7. [Quarkus OpenTelemetry Extension](#7-quarkus-opentelemetry-extension)
8. [Resource Detection](#8-java-resource-detection)
9. [Sampling and Context Propagation](#9-java-sampling-and-context-propagation)
10. [Performance and Pitfalls](#10-java-performance-and-pitfalls)

### Part II: .NET
11. [Auto-Instrumentation (CLR Profiler)](#11-net-auto-instrumentation)
12. [SDK Manual Instrumentation](#12-net-sdk-manual-instrumentation)
13. [Metrics API](#13-net-metrics-api)
14. [Logs API (ILogger Integration)](#14-net-logs-api)
15. [ASP.NET Core Integration](#15-aspnet-core-integration)
16. [Configuration and Resource Detection](#16-net-configuration-and-resource-detection)
17. [Performance and Pitfalls](#17-net-performance-and-pitfalls)

### Part III: Python
18. [Auto-Instrumentation](#18-python-auto-instrumentation)
19. [SDK Manual Instrumentation](#19-python-sdk-manual-instrumentation)
20. [Metrics API](#20-python-metrics-api)
21. [Logs API](#21-python-logs-api)
22. [Framework Integrations (Flask, Django, FastAPI)](#22-python-framework-integrations)
23. [Celery/Async Workers](#23-python-celery-async-workers)
24. [Configuration and Pitfalls](#24-python-configuration-and-pitfalls)

### Part IV: Node.js / TypeScript
25. [Auto-Instrumentation](#25-nodejs-auto-instrumentation)
26. [SDK Manual Instrumentation](#26-nodejs-sdk-manual-instrumentation)
27. [Metrics and Logs API](#27-nodejs-metrics-and-logs-api)
28. [Framework Integrations (Express, NestJS, Fastify, Next.js)](#28-nodejs-framework-integrations)
29. [Configuration and Pitfalls](#29-nodejs-configuration-and-pitfalls)

### Part V: Go
30. [SDK Setup](#30-go-sdk-setup)
31. [Manual Instrumentation](#31-go-manual-instrumentation)
32. [Instrumentation Libraries](#32-go-instrumentation-libraries)
33. [Metrics API](#33-go-metrics-api)
34. [Logs (slog Bridge)](#34-go-logs-slog-bridge)
35. [eBPF Auto-Instrumentation](#35-go-ebpf-auto-instrumentation)
36. [Performance and Pitfalls](#36-go-performance-and-pitfalls)

### Part VI: Rust
37. [tracing-opentelemetry Bridge](#37-rust-tracing-opentelemetry-bridge)
38. [Framework Integrations (Axum, Actix-Web)](#38-rust-framework-integrations)
39. [Metrics and Logs](#39-rust-metrics-and-logs)

### Part VII: PHP
40. [Installation and Auto-Instrumentation](#40-php-installation-and-auto-instrumentation)
41. [Manual Instrumentation](#41-php-manual-instrumentation)

### Part VIII: Ruby
42. [Rails Auto-Instrumentation](#42-ruby-rails-auto-instrumentation)
43. [Manual Instrumentation](#43-ruby-manual-instrumentation)

### Part IX: Swift / Mobile
44. [SDK Setup and URLSession](#44-swift-sdk-setup-and-urlsession)
45. [Mobile-Specific Considerations](#45-mobile-specific-considerations)

### Part X: Cross-Cutting Concepts
46. [SDK Architecture Overview](#46-sdk-architecture-overview)
47. [Context Propagation Deep Dive](#47-context-propagation-deep-dive)
48. [Semantic Conventions](#48-semantic-conventions)
49. [Sampling Deep Dive](#49-sampling-deep-dive)
50. [Auto vs Manual Instrumentation Trade-offs](#50-auto-vs-manual-instrumentation-trade-offs)
51. [Zero-Code Approaches (Operator, OBI, eBPF)](#51-zero-code-approaches)
52. [Error Handling Patterns](#52-error-handling-patterns)
53. [Testing Instrumented Code](#53-testing-instrumented-code)

---

## PART I: JAVA

---

## 1. Java Auto-Instrumentation Agent

The Java auto-instrumentation agent (`opentelemetry-javaagent.jar`) uses **Byte Buddy** for bytecode manipulation at class load time. It intercepts class loading via `java.lang.instrument` and rewrites bytecode to inject tracing, metrics, and context propagation. The **Muzzle** safety system validates version compatibility at build time to prevent `NoSuchMethodError` at runtime.

### 1.1 Setup

```bash
# Download the agent
curl -L -o opentelemetry-javaagent.jar \
  https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/latest/download/opentelemetry-javaagent.jar

# Run with agent
java -javaagent:opentelemetry-javaagent.jar \
  -Dotel.service.name=order-service \
  -Dotel.exporter.otlp.endpoint=http://localhost:4317 \
  -Dotel.traces.sampler=parentbased_traceidratio \
  -Dotel.traces.sampler.arg=0.1 \
  -jar myapp.jar
```

### 1.2 Supported Libraries (600+)

| Category | Libraries |
|---|---|
| Web Frameworks | Spring Web MVC, Spring WebFlux, JAX-RS (Jersey, RESTEasy), Servlet 2.2-6.0, JSF, Struts, Vaadin, Vert.x |
| HTTP Clients | Apache HttpClient, OkHttp, Java 11+ HttpClient, AsyncHttpClient, Netty |
| Databases | JDBC (all drivers), Hibernate, jOOQ, MyBatis, R2DBC, Cassandra, MongoDB, Redis (Jedis, Lettuce) |
| Messaging | Kafka (clients + Streams), RabbitMQ, JMS (ActiveMQ, Artemis), Pulsar, AWS SQS/SNS |
| RPC | gRPC, Apache Dubbo, Apache Thrift, Armeria |
| Cloud | AWS SDK v1/v2, Google Cloud Client Libraries |
| Logging | Log4j2, Logback, java.util.logging (auto MDC injection) |
| Frameworks | Spring Boot 2.x/3.x, Quarkus, Micronaut, Dropwizard, Play, Akka HTTP, Ktor |
| Caching | Ehcache, Hazelcast, Caffeine |
| Scheduling | Quartz, Spring Scheduling, EJB Timers |

### 1.3 Kubernetes Operator Injection

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: java-instrumentation
spec:
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.1.0
  exporter:
    endpoint: http://otel-collector:4317
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"
---
# Pod annotation
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
```

### 1.4 Disabling Specific Instrumentations

```bash
# Via system property
-Dotel.instrumentation.[name].enabled=false

# Disable JDBC instrumentation
-Dotel.instrumentation.jdbc.enabled=false

# Disable all default, enable only specific ones
-Dotel.instrumentation.default-enabled=false
-Dotel.instrumentation.spring-webmvc.enabled=true
-Dotel.instrumentation.jdbc.enabled=true
```

---

## 2. Java SDK Manual Instrumentation

### 2.1 Dependencies (Maven)

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>io.opentelemetry</groupId>
      <artifactId>opentelemetry-bom</artifactId>
      <version>1.46.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
    <dependency>
      <groupId>io.opentelemetry.instrumentation</groupId>
      <artifactId>opentelemetry-instrumentation-bom</artifactId>
      <version>2.12.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
  </dependency>
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-sdk</artifactId>
  </dependency>
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
  </dependency>
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-sdk-extension-autoconfigure</artifactId>
  </dependency>
</dependencies>
```

### 2.2 Programmatic SDK Setup

```java
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.logs.SdkLoggerProvider;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.exporter.otlp.trace.OtlpGrpcSpanExporter;
import io.opentelemetry.exporter.otlp.metrics.OtlpGrpcMetricExporter;
import io.opentelemetry.exporter.otlp.logs.OtlpGrpcLogRecordExporter;
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;
import io.opentelemetry.sdk.logs.export.BatchLogRecordProcessor;
import io.opentelemetry.semconv.ResourceAttributes;

public class OtelConfig {
    public static OpenTelemetry init() {
        Resource resource = Resource.getDefault().toBuilder()
            .put(ResourceAttributes.SERVICE_NAME, "order-service")
            .put(ResourceAttributes.SERVICE_VERSION, "2.1.0")
            .put(ResourceAttributes.DEPLOYMENT_ENVIRONMENT, "production")
            .build();

        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
            .setResource(resource)
            .addSpanProcessor(BatchSpanProcessor.builder(
                OtlpGrpcSpanExporter.builder()
                    .setEndpoint("http://localhost:4317")
                    .build())
                .setMaxQueueSize(2048)
                .setMaxExportBatchSize(512)
                .setScheduleDelay(java.time.Duration.ofSeconds(5))
                .build())
            .build();

        SdkMeterProvider meterProvider = SdkMeterProvider.builder()
            .setResource(resource)
            .registerMetricReader(PeriodicMetricReader.builder(
                OtlpGrpcMetricExporter.builder()
                    .setEndpoint("http://localhost:4317")
                    .build())
                .setInterval(java.time.Duration.ofSeconds(60))
                .build())
            .build();

        SdkLoggerProvider loggerProvider = SdkLoggerProvider.builder()
            .setResource(resource)
            .addLogRecordProcessor(BatchLogRecordProcessor.builder(
                OtlpGrpcLogRecordExporter.builder()
                    .setEndpoint("http://localhost:4317")
                    .build())
                .build())
            .build();

        OpenTelemetrySdk sdk = OpenTelemetrySdk.builder()
            .setTracerProvider(tracerProvider)
            .setMeterProvider(meterProvider)
            .setLoggerProvider(loggerProvider)
            .buildAndRegisterGlobal();

        Runtime.getRuntime().addShutdownHook(new Thread(sdk::close));
        return sdk;
    }
}
```

### 2.3 Creating Spans

```java
Tracer tracer = openTelemetry.getTracer("com.mycompany.order-service", "1.0.0");

public Order processOrder(String orderId, List<Item> items) {
    Span span = tracer.spanBuilder("ProcessOrder")
        .setSpanKind(SpanKind.INTERNAL)
        .setAttribute("order.id", orderId)
        .setAttribute("order.item_count", items.size())
        .startSpan();

    try (var scope = span.makeCurrent()) {
        // Nested spans automatically become children
        validateOrder(orderId);

        double total = calculateTotal(items);
        span.setAttribute("order.total", total);
        span.addEvent("Order validated", Attributes.of(
            AttributeKey.stringKey("order.id"), orderId));
        span.setStatus(StatusCode.OK);
        return new Order(orderId, total);
    } catch (Exception e) {
        span.recordException(e);
        span.setStatus(StatusCode.ERROR, e.getMessage());
        throw e;
    } finally {
        span.end();  // CRITICAL: Always call end()
    }
}
```

### 2.4 Async Context Propagation

```java
// Wrap Runnable/Callable to propagate context
ExecutorService executor = Context.taskWrapping(Executors.newFixedThreadPool(10));

// Or wrap individual tasks
Context current = Context.current();
executor.submit(current.wrap(() -> {
    // Context (and active span) is available here
    Span childSpan = tracer.spanBuilder("async-work").startSpan();
    try (var scope = childSpan.makeCurrent()) {
        doWork();
    } finally {
        childSpan.end();
    }
}));

// CompletableFuture
CompletableFuture.supplyAsync(() -> {
    // Context NOT automatically propagated in CompletableFuture
    // Must use Context.current().wrap() or manual inject/extract
    return compute();
}, Context.taskWrapping(executor));
```

---

## 3. Java Metrics API

```java
import io.opentelemetry.api.metrics.Meter;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.metrics.LongUpDownCounter;
import io.opentelemetry.api.metrics.ObservableDoubleGauge;
import io.opentelemetry.api.common.Attributes;

Meter meter = openTelemetry.getMeter("com.mycompany.order-service", "1.0.0");

// Counter (monotonic)
LongCounter requestCounter = meter.counterBuilder("http.server.request.total")
    .setDescription("Total HTTP requests")
    .setUnit("{request}")
    .build();
requestCounter.add(1, Attributes.of(
    AttributeKey.stringKey("http.request.method"), "POST",
    AttributeKey.stringKey("http.route"), "/api/orders"));

// Histogram (latency distribution)
DoubleHistogram requestDuration = meter.histogramBuilder("http.server.request.duration")
    .setDescription("HTTP request duration")
    .setUnit("s")
    .build();
requestDuration.record(0.045, Attributes.of(
    AttributeKey.stringKey("http.request.method"), "POST",
    AttributeKey.longKey("http.response.status_code"), 201L));

// UpDownCounter (active connections)
LongUpDownCounter activeConnections = meter.upDownCounterBuilder("http.server.active_connections")
    .setDescription("Active HTTP connections")
    .build();
activeConnections.add(1, attrs);   // connection opened
activeConnections.add(-1, attrs);  // connection closed

// ObservableGauge (async, callback-based)
ObservableDoubleGauge memGauge = meter.gaugeBuilder("jvm.memory.used")
    .setUnit("By")
    .buildWithCallback(measurement -> {
        for (MemoryPoolMXBean pool : ManagementFactory.getMemoryPoolMXBeans()) {
            measurement.record(pool.getUsage().getUsed(),
                Attributes.of(AttributeKey.stringKey("jvm.memory.pool.name"), pool.getName()));
        }
    });
```

---

## 4. Java Logs API

The OTel Log Bridge API bridges existing logging frameworks (Log4j2, Logback) into the OTel pipeline. It does NOT replace them.

### 4.1 Auto MDC Injection (javaagent)

With the javaagent attached, `trace_id`, `span_id`, and `trace_flags` are automatically injected into the MDC (Mapped Diagnostic Context). Configure your log pattern to include them:

```xml
<!-- logback.xml -->
<pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} trace_id=%X{trace_id} span_id=%X{span_id} - %msg%n</pattern>

<!-- log4j2.xml -->
<PatternLayout pattern="%d [%t] %-5p %c - trace_id=%X{trace_id} span_id=%X{span_id} - %m%n"/>
```

### 4.2 Logback Appender

```xml
<!-- logback.xml -->
<appender name="otel" class="io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender">
    <captureExperimentalAttributes>true</captureExperimentalAttributes>
    <captureCodeAttributes>true</captureCodeAttributes>
    <captureMarkerAttribute>true</captureMarkerAttribute>
    <captureKeyValuePairAttributes>true</captureKeyValuePairAttributes>
    <captureMdcAttributes>*</captureMdcAttributes>
</appender>
```

### 4.3 Log4j2 Appender

```xml
<!-- log4j2.xml -->
<Configuration packages="io.opentelemetry.instrumentation.log4j.appender.v2_17">
    <Appenders>
        <OpenTelemetry name="otel"
            captureExperimentalAttributes="true"
            captureMapMessageAttributes="true"
            captureMarkerAttribute="true"/>
    </Appenders>
</Configuration>
```

### 4.4 Programmatic Installation

```java
// Required when not using the javaagent
OpenTelemetryAppender.install(openTelemetry);
```

---

## 5. Java Configuration

### 5.1 Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OTEL_SERVICE_NAME` | `unknown_service:java` | Logical service name |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4317` | OTLP endpoint |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | `grpc` or `http/protobuf` |
| `OTEL_TRACES_EXPORTER` | `otlp` | `otlp`, `zipkin`, `console`, `none` |
| `OTEL_METRICS_EXPORTER` | `otlp` | `otlp`, `prometheus`, `none` |
| `OTEL_LOGS_EXPORTER` | `otlp` | `otlp`, `console`, `none` |
| `OTEL_TRACES_SAMPLER` | `parentbased_always_on` | Sampler type |
| `OTEL_TRACES_SAMPLER_ARG` | `1.0` | Sampler argument (ratio) |
| `OTEL_PROPAGATORS` | `tracecontext,baggage` | Context propagators |
| `OTEL_RESOURCE_ATTRIBUTES` | | `key=value,key2=value2` |
| `OTEL_BSP_MAX_QUEUE_SIZE` | `2048` | Batch processor queue size |
| `OTEL_BSP_MAX_EXPORT_BATCH_SIZE` | `512` | Batch export size |
| `OTEL_BSP_SCHEDULE_DELAY` | `5000` | Batch delay (ms) |

### 5.2 Autoconfigure SDK

```java
// Minimal setup using autoconfigure (reads env vars)
OpenTelemetrySdk sdk = AutoConfiguredOpenTelemetrySdk.builder()
    .addTracerProviderCustomizer((builder, config) ->
        builder.setSampler(Sampler.parentBased(Sampler.traceIdRatioBased(0.1))))
    .addResourceCustomizer((resource, config) ->
        resource.merge(Resource.builder()
            .put("custom.attr", "value")
            .build()))
    .build()
    .getOpenTelemetrySdk();
```

---

## 6. Spring Boot Starter

The OpenTelemetry Spring Boot Starter provides auto-configuration for Spring Boot 2.6+ and 3.1+.

### 6.1 Dependency

```xml
<dependency>
    <groupId>io.opentelemetry.instrumentation</groupId>
    <artifactId>opentelemetry-spring-boot-starter</artifactId>
</dependency>
```

### 6.2 application.properties

```properties
otel.service.name=order-service
otel.exporter.otlp.endpoint=http://localhost:4317
otel.traces.sampler=parentbased_traceidratio
otel.traces.sampler.arg=0.1
otel.instrumentation.micrometer.enabled=true
otel.instrumentation.spring-webmvc.enabled=true
otel.instrumentation.spring-webflux.enabled=true
otel.instrumentation.jdbc.enabled=true
```

### 6.3 @WithSpan Annotation

```java
import io.opentelemetry.instrumentation.annotations.WithSpan;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;

@Service
public class OrderService {

    @WithSpan("ProcessOrder")
    public Order processOrder(
            @SpanAttribute("order.id") String orderId,
            @SpanAttribute("order.item_count") int itemCount) {
        // Span automatically created and ended
        return doProcessing(orderId, itemCount);
    }
}
```

**Critical limitation:** `@WithSpan` uses Spring AOP proxies. Internal method calls within the same class are NOT intercepted:

```java
@Service
public class OrderService {
    @WithSpan
    public void methodA() {
        methodB();  // THIS CALL WILL NOT CREATE A SPAN
    }

    @WithSpan
    public void methodB() { /* ... */ }
}
```

---

## 7. Quarkus OpenTelemetry Extension

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-opentelemetry</artifactId>
</dependency>
```

### 7.1 application.properties

```properties
quarkus.otel.exporter.otlp.endpoint=http://localhost:4317
quarkus.otel.service.name=order-service
quarkus.otel.traces.sampler=parentbased_traceidratio
quarkus.otel.traces.sampler.arg=0.1

# IMPORTANT: Metrics and logs are disabled by default in Quarkus
quarkus.otel.metrics.enabled=true
quarkus.otel.logs.enabled=true
```

Quarkus auto-instruments: JAX-RS endpoints, RESTEasy, gRPC, Vert.x HTTP, JDBC, Hibernate, Kafka, SmallRye Reactive Messaging.

---

## 8. Java Resource Detection

Resource detectors populate attributes like `host.name`, `os.type`, `process.pid`, and cloud-specific metadata.

```java
// Built-in detectors (always active)
// host.name, host.arch, os.type, os.description, process.pid, process.runtime.*

// Cloud detectors (since Java Agent v2.2.0, disabled by default for performance)
// Enable via:
-Dotel.resource.providers.aws.enabled=true
-Dotel.resource.providers.gcp.enabled=true

// Programmatic
Resource resource = Resource.getDefault().merge(
    Resource.create(Attributes.of(
        ResourceAttributes.SERVICE_NAME, "order-service",
        ResourceAttributes.SERVICE_VERSION, "2.1.0",
        ResourceAttributes.DEPLOYMENT_ENVIRONMENT, "production",
        AttributeKey.stringKey("team"), "platform")));
```

Cloud detectors for AWS (EC2, ECS, EKS, Lambda, Elastic Beanstalk) and GCP (GCE, GKE, Cloud Run, Cloud Functions) are available in `opentelemetry-java-contrib`.

---

## 9. Java Sampling and Context Propagation

### 9.1 Sampling

```java
import io.opentelemetry.sdk.trace.samplers.Sampler;

// Always sample (development)
Sampler.alwaysOn()

// Never sample
Sampler.alwaysOff()

// Ratio-based (10%)
Sampler.traceIdRatioBased(0.1)

// Parent-based with ratio root (production recommended)
Sampler.parentBased(Sampler.traceIdRatioBased(0.1))
```

### 9.2 Context Propagation

```java
import io.opentelemetry.context.propagation.TextMapGetter;
import io.opentelemetry.context.propagation.TextMapSetter;
import io.opentelemetry.context.Context;

// Inject into outgoing headers
TextMapSetter<Map<String, String>> setter = Map::put;
openTelemetry.getPropagators().getTextMapPropagator()
    .inject(Context.current(), headers, setter);

// Extract from incoming headers
TextMapGetter<HttpServletRequest> getter = new TextMapGetter<>() {
    @Override public Iterable<String> keys(HttpServletRequest carrier) {
        return Collections.list(carrier.getHeaderNames());
    }
    @Override public String get(HttpServletRequest carrier, String key) {
        return carrier.getHeader(key);
    }
};
Context extractedCtx = openTelemetry.getPropagators().getTextMapPropagator()
    .extract(Context.current(), request, getter);
```

---

## 10. Java Performance and Pitfalls

### 10.1 Performance Overhead

| Metric | Typical Impact |
|---|---|
| Latency per request | +1-5ms |
| CPU overhead | +2-5% |
| Memory overhead | +50-200MB |
| Startup time | +2-10s (bytecode transformation) |

### 10.2 Common Pitfalls

1. **Forgetting `span.end()`**: Causes memory leaks. Always use try/finally.
2. **Missing context propagation in async**: Use `Context.current().wrap()` or `Context.taskWrapping(executor)`.
3. **@WithSpan on internal calls**: Spring AOP proxies don't intercept self-invocation.
4. **High-cardinality attributes**: Never use user IDs, request IDs, or UUIDs as metric attributes.
5. **Not closing SDK on shutdown**: Add `Runtime.getRuntime().addShutdownHook(new Thread(sdk::close))`.
6. **BatchSpanProcessor defaults too large**: Tune `maxQueueSize` and `maxExportBatchSize` for your throughput.

---

## PART II: .NET

---

## 11. .NET Auto-Instrumentation

.NET auto-instrumentation uses two mechanisms:
- **DOTNET_STARTUP_HOOKS** for .NET 6+ (startup hook injection)
- **CLR Profiler** for bytecode-level instrumentation (required for .NET Framework 4.6.2+)

Latest version: 1.14.0.

### 11.1 Installation

```bash
# Linux
curl -sSfL https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/latest/download/otel-dotnet-auto-install.sh | bash

# Environment variables
export OTEL_SERVICE_NAME=order-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export DOTNET_STARTUP_HOOKS=$HOME/.otel-dotnet-auto/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll
export OTEL_DOTNET_AUTO_HOME=$HOME/.otel-dotnet-auto
```

### 11.2 Supported Libraries

| Category | Libraries |
|---|---|
| Web | ASP.NET Core, ASP.NET (MVC, WebAPI, WebForms), WCF |
| HTTP Clients | HttpClient, WebRequest, RestSharp |
| Databases | SqlClient, Entity Framework Core, Npgsql, MySqlConnector, StackExchange.Redis |
| Messaging | MassTransit, NServiceBus, RabbitMQ.Client, Confluent.Kafka |
| RPC | gRPC (Grpc.Net.Client, Grpc.AspNetCore) |
| Cloud | AWS SDK, Azure SDK |
| Logging | ILogger, Serilog, NLog, log4net |

### 11.3 Kubernetes Operator

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-dotnet: "true"
```

---

## 12. .NET SDK Manual Instrumentation

**Critical .NET difference:** .NET uses `System.Diagnostics` API natively. The mapping is:
- `TracerProvider` → `TracerProvider`
- `Tracer` → `ActivitySource`
- `Span` → `Activity`
- `Attributes` → `Tags`

### 12.1 Setup (Program.cs)

```csharp
using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService("order-service", serviceVersion: "2.1.0")
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = "production"
        }))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSqlClientInstrumentation(options => options.SetDbStatementForText = true)
        .AddEntityFrameworkCoreInstrumentation()
        .AddSource("OrderService")  // CRITICAL: Register your ActivitySource names
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://localhost:4317");
        }))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddMeter("OrderService")
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://localhost:4317");
        }))
    .WithLogging(logging => logging
        .AddOtlpExporter());

// Simplified (v1.8+): Configure OTLP for all signals in one call
// builder.Services.AddOpenTelemetry().UseOtlpExporter();
```

### 12.2 Creating Spans (Activities)

```csharp
using System.Diagnostics;

public class OrderService
{
    private static readonly ActivitySource Source = new("OrderService", "1.0.0");

    public async Task<Order> ProcessOrderAsync(string orderId, List<Item> items)
    {
        // StartActivity() returns null when no listeners! Always use ?.
        using var activity = Source.StartActivity("ProcessOrder", ActivityKind.Internal);
        activity?.SetTag("order.id", orderId);
        activity?.SetTag("order.item_count", items.Count);

        try
        {
            var total = await CalculateTotalAsync(items);
            activity?.SetTag("order.total", total);
            activity?.AddEvent(new ActivityEvent("Order validated",
                tags: new ActivityTagsCollection { { "order.id", orderId } }));
            activity?.SetStatus(ActivityStatusCode.Ok);
            return new Order(orderId, total);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);
            throw;
        }
    }
}
```

**Critical:** `StartActivity()` returns `null` when no listeners are registered. Always use null-conditional operators (`activity?.SetTag()`). Forgetting `.AddSource("OrderService")` in setup causes ALL activities to be silently dropped.

---

## 13. .NET Metrics API

```csharp
using System.Diagnostics.Metrics;

public class OrderMetrics
{
    private readonly Counter<long> _requestCounter;
    private readonly Histogram<double> _requestDuration;
    private readonly UpDownCounter<long> _activeConnections;

    public OrderMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create("OrderService", "1.0.0");

        _requestCounter = meter.CreateCounter<long>(
            "http.server.request.total",
            unit: "{request}",
            description: "Total HTTP requests");

        _requestDuration = meter.CreateHistogram<double>(
            "http.server.request.duration",
            unit: "s",
            description: "HTTP request duration");

        _activeConnections = meter.CreateUpDownCounter<long>(
            "http.server.active_connections");
    }

    public void RecordRequest(string method, int statusCode, double duration)
    {
        // Use TagList for stack-allocated tags (better performance)
        var tags = new TagList
        {
            { "http.request.method", method },
            { "http.response.status_code", statusCode }
        };
        _requestCounter.Add(1, tags);
        _requestDuration.Record(duration, tags);
    }
}

// Observable gauge (async callback)
meter.CreateObservableGauge("process.memory.usage", () =>
    new Measurement<long>(GC.GetTotalMemory(false), new TagList { { "gc.gen", "total" } }));
```

---

## 14. .NET Logs API

```csharp
// In Program.cs
builder.Logging.AddOpenTelemetry(options =>
{
    options.IncludeFormattedMessage = true;
    options.IncludeScopes = true;
    options.ParseStateValues = true;
    options.AddOtlpExporter();
});
```

ILogger automatically correlates `TraceId` and `SpanId` when called within an active span. Structured logging attributes become log record attributes:

```csharp
logger.LogInformation("Order {OrderId} processed with total {Total}", orderId, total);
// Produces: order_id=123, total=99.99 as log attributes
```

### High-Performance Logging

```csharp
// Use LoggerMessage source generator for zero-allocation logging
public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Order {OrderId} processed")]
    public static partial void OrderProcessed(ILogger logger, string orderId);
}
```

---

## 15. ASP.NET Core Integration

Auto-instrumented with `.AddAspNetCoreInstrumentation()`:

```csharp
.WithTracing(tracing => tracing
    .AddAspNetCoreInstrumentation(options =>
    {
        // Filter out health checks and static files
        options.Filter = context =>
            !context.Request.Path.StartsWithSegments("/health") &&
            !context.Request.Path.StartsWithSegments("/ready");

        // Enrich spans with custom data
        options.EnrichWithHttpRequest = (activity, request) =>
        {
            activity.SetTag("tenant.id", request.Headers["X-Tenant-Id"].FirstOrDefault());
        };
        options.EnrichWithHttpResponse = (activity, response) =>
        {
            activity.SetTag("http.response.content_length", response.ContentLength);
        };
    }))
```

---

## 16. .NET Configuration and Resource Detection

### 16.1 Environment Variables

Same `OTEL_*` variables as Java, plus .NET-specific:

| Variable | Description |
|---|---|
| `OTEL_DOTNET_AUTO_HOME` | Auto-instrumentation install directory |
| `OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES` | Additional ActivitySource names |
| `OTEL_DOTNET_AUTO_METRICS_ADDITIONAL_SOURCES` | Additional Meter names |

### 16.2 Resource Detection

```csharp
.ConfigureResource(resource => resource
    .AddService("order-service", serviceVersion: "2.1.0")
    .AddDetector(new ContainerResourceDetector())
    .AddDetector(new HostDetector())
    .AddDetector(new ProcessDetector())
    .AddDetector(new ProcessRuntimeDetector()))
```

---

## 17. .NET Performance and Pitfalls

### 17.1 Performance

| Metric | Typical Impact |
|---|---|
| Latency per request | +0.5-3ms |
| CPU overhead | +2-6% |
| RPS regression (high throughput) | ~15% at 270k+ RPS |
| RPS regression (typical) | 2-6% at <10k RPS |

### 17.2 Key Optimizations

```csharp
// 1. Check IsAllDataRequested before expensive operations
if (activity?.IsAllDataRequested == true)
{
    activity.SetTag("expensive.data", ComputeExpensiveData());
}

// 2. Use TagList (stack-allocated) instead of KeyValuePair arrays
var tags = new TagList { { "key", "value" } };

// 3. Filter health check endpoints
options.Filter = ctx => !ctx.Request.Path.StartsWithSegments("/health");
```

### 17.3 Common Pitfalls

1. **Not calling `.AddSource("Name")`**: Activities silently dropped. Every ActivitySource name must be registered.
2. **Not using null-conditional on Activity**: `StartActivity()` returns null without listeners.
3. **Disposing TracerProvider too early**: Pending spans are lost. Use `IHostedService` lifetime.
4. **Using `activity.SetTag()` without null check**: `NullReferenceException` in production.
5. **High-cardinality tags on metrics**: Same as Java -- never use user IDs or request IDs.

---

## PART III: PYTHON

---

## 18. Python Auto-Instrumentation

Python auto-instrumentation uses **monkey patching** -- modifying library functions at runtime by replacing them with wrapped versions that create spans, record metrics, and propagate context.

### 18.1 Setup

```bash
pip install opentelemetry-distro          # API, SDK, bootstrap, instrument CLI
opentelemetry-bootstrap -a install        # Auto-detect and install instrumentors
pip install opentelemetry-exporter-otlp   # OTLP gRPC and HTTP exporters
```

### 18.2 Running

```bash
opentelemetry-instrument \
  --traces_exporter otlp \
  --metrics_exporter otlp \
  --service_name my-service \
  --exporter_otlp_endpoint http://localhost:4317 \
  python app.py

# Gunicorn
opentelemetry-instrument gunicorn myapp.wsgi:application --workers 4

# Uvicorn (ASGI)
opentelemetry-instrument uvicorn myapp:app --host 0.0.0.0
```

### 18.3 Supported Libraries

| Category | Libraries |
|---|---|
| Web Frameworks | Flask, Django, FastAPI, Starlette, Tornado, Falcon, Pyramid, aiohttp, Bottle |
| HTTP Clients | requests, httpx, urllib, urllib3 |
| Databases | psycopg2/psycopg, mysql-connector-python, pymysql, SQLAlchemy, asyncpg, pymongo |
| Caching | redis, pymemcache, elasticsearch |
| Messaging | celery, pika, confluent-kafka, kafka-python |
| RPC | grpcio |
| Cloud | boto3/botocore |
| Logging | logging (stdlib) |
| Templating | jinja2 |

### 18.4 Kubernetes Operator

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "true"
```

---

## 19. Python SDK Manual Instrumentation

### 19.1 Full SDK Setup

```python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.semconv.resource import ResourceAttributes

resource = Resource.create({
    ResourceAttributes.SERVICE_NAME: "order-service",
    ResourceAttributes.SERVICE_VERSION: "2.1.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production",
})

tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(BatchSpanProcessor(
    OTLPSpanExporter(endpoint="http://localhost:4317", insecure=True),
    max_queue_size=2048, max_export_batch_size=512, schedule_delay_millis=5000,
))
trace.set_tracer_provider(tracer_provider)

meter_provider = MeterProvider(resource=resource, metric_readers=[
    PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint="http://localhost:4317", insecure=True),
        export_interval_millis=60000,
    )
])
metrics.set_meter_provider(meter_provider)

tracer = trace.get_tracer(__name__, "1.0.0")
```

### 19.2 Creating Spans

```python
from opentelemetry.trace import SpanKind, StatusCode, Status, Link

def process_order(order_id):
    with tracer.start_as_current_span("process_order", kind=SpanKind.INTERNAL,
                                       attributes={"order.id": order_id}) as span:
        try:
            result = validate_order(order_id)
            span.set_attribute("order.total", result["total"])
            span.add_event("Order validated", {"items_count": result["items"]})
            span.set_status(Status(StatusCode.OK))
            return result
        except Exception as exc:
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, str(exc)))
            raise

# Nested spans automatic via context
def validate_order(order_id):
    with tracer.start_as_current_span("validate_order") as span:
        span.set_attribute("order.id", order_id)
        return {"total": 99.99, "items": 3}
```

### 19.3 Span Links (batch processing)

```python
links = [Link(span_ctx, {"message.id": msg.id})
         for msg in messages if span_ctx.is_valid]
with tracer.start_as_current_span("process_batch",
                                   kind=SpanKind.CONSUMER, links=links):
    process_messages(messages)
```

---

## 20. Python Metrics API

```python
meter = metrics.get_meter(__name__, "1.0.0")

# Counter (monotonic)
http_requests = meter.create_counter("http.server.request.total", unit="1")
http_requests.add(1, {"http.request.method": "GET"})

# UpDownCounter
active_conns = meter.create_up_down_counter("http.server.active_connections", unit="1")
active_conns.add(1, {"service": "api"})    # open
active_conns.add(-1, {"service": "api"})   # close

# Histogram
request_duration = meter.create_histogram("http.server.request.duration", unit="s")
request_duration.record(0.15, {"http.route": "/orders"})

# ObservableGauge (async, callback-based)
import psutil
def cpu_callback(options):
    for i, pct in enumerate(psutil.cpu_percent(percpu=True)):
        options.observe(pct, {"cpu.core": str(i)})
meter.create_observable_gauge("system.cpu.utilization", callbacks=[cpu_callback])

# ObservableCounter (async monotonic)
def disk_io_callback(options):
    for name, io in psutil.disk_io_counters(perdisk=True).items():
        options.observe(io.read_bytes, {"disk": name, "direction": "read"})
meter.create_observable_counter("system.disk.io", callbacks=[disk_io_callback])
```

---

## 21. Python Logs API

```python
import logging
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter

logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(
        OTLPLogExporter(endpoint="http://localhost:4317", insecure=True)))

handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
logging.getLogger().addHandler(handler)
```

Logs within a span automatically get `trace_id` and `span_id`. Auto-instrumentation adds `otelTraceID`, `otelSpanID`, `otelTraceSampled` fields.

---

## 22. Python Framework Integrations

### 22.1 Flask

```python
from opentelemetry.instrumentation.flask import FlaskInstrumentor

app = Flask(__name__)

FlaskInstrumentor().instrument_app(app,
    request_hook=lambda span, environ: span.set_attribute("tenant.id",
        environ.get("HTTP_X_TENANT_ID", "unknown")),
    response_hook=lambda span, status, headers: None)
```

### 22.2 Django

```python
# settings.py
INSTALLED_APPS = ['opentelemetry.instrumentation.django', ...]

# Or programmatic
from opentelemetry.instrumentation.django import DjangoInstrumentor
DjangoInstrumentor().instrument(
    request_hook=lambda span, request: None,
    response_hook=lambda span, request, response:
        span.set_attribute("user.id", str(request.user.id) if request.user.is_authenticated else "anonymous"),
    is_sql_commentor_enabled=True)  # Injects trace context into SQL comments
```

Environment variables: `OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION` controls middleware ordering.

### 22.3 FastAPI

```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

app = FastAPI()
FastAPIInstrumentor.instrument_app(app,
    server_request_hook=lambda span, scope: span.set_attribute("tenant.id",
        dict(scope.get("headers", [])).get(b"x-tenant-id", b"").decode()))
```

---

## 23. Python Celery/Async Workers

**Critical:** CeleryInstrumentor MUST be initialized AFTER fork using the `worker_process_init` signal. `BatchSpanProcessor` is NOT fork-safe.

```python
from celery.signals import worker_process_init

@worker_process_init.connect(weak=False)
def init_celery_tracing(**kwargs):
    # Re-initialize OTel in each worker process
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

from opentelemetry.instrumentation.celery import CeleryInstrumentor
CeleryInstrumentor().instrument()
```

Context propagation from web request to Celery worker is automatic when both are instrumented.

### Gunicorn Fork Safety

```python
# gunicorn.conf.py
def post_fork(server, worker):
    from opentelemetry import trace
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

    provider = TracerProvider(resource=resource)
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
```

---

## 24. Python Configuration and Pitfalls

### 24.1 Key Environment Variables

| Variable | Description |
|---|---|
| `OTEL_PYTHON_LOG_CORRELATION` | Enable trace context in logs |
| `OTEL_PYTHON_DISABLED_INSTRUMENTATIONS` | Comma-separated list to disable |
| `OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION` | `first` or `last` |

### 24.2 Performance

| Metric | Typical Impact |
|---|---|
| Per-span overhead | +0.1-0.5ms |
| CPU overhead | +1-3% |
| Memory overhead | +20-50MB |
| Full auto-instrumentation | +0.5-2ms/request |

### 24.3 Common Pitfalls

1. **Fork safety**: Re-initialize OTel in Gunicorn `post_fork` and Celery `worker_process_init`.
2. **Thread safety**: Spans are NOT thread-safe across threads.
3. **Not calling `shutdown()`**: Pending spans are lost on exit.
4. **Using `SimpleSpanProcessor` in production**: Blocks on each span. Always use `BatchSpanProcessor`.
5. **Forgetting `opentelemetry-bootstrap`**: Missing auto-detected instrumentors.

---

## PART IV: NODE.JS / TYPESCRIPT

---

## 25. Node.js Auto-Instrumentation

Node.js auto-instrumentation uses **require hooks** (CommonJS) or **loader hooks** (ESM) via `require-in-the-middle` to intercept module loading and wrap library functions.

### 25.1 Supported Libraries

| Category | Libraries |
|---|---|
| Web Frameworks | express, fastify, koa, hapi, restify, nestjs-core, connect |
| HTTP | http, https, fetch (undici) |
| Databases | pg, mysql2, mongodb, redis, ioredis, tedious, knex |
| Messaging | amqplib, kafka (kafkajs) |
| RPC | @grpc/grpc-js |
| Logging | winston, pino, bunyan |
| Other | graphql, dataloader, dns, net, fs, socket.io, aws-sdk, cucumber |

### 25.2 Setup

```bash
npm install @opentelemetry/api \
  @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-grpc \
  @opentelemetry/exporter-metrics-otlp-grpc
```

```bash
# Run with require hook (CJS)
node --require ./instrumentation.js app.js

# Run with loader hook (ESM, Node >= 20)
node --import ./instrumentation.mjs app.mjs

# Disable noisy instrumentations
OTEL_NODE_DISABLED_INSTRUMENTATIONS="fs,dns,net"
```

---

## 26. Node.js SDK Manual Instrumentation

### 26.1 instrumentation.ts

```typescript
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-grpc';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { resourceFromAttributes } from '@opentelemetry/resources';
import { ATTR_SERVICE_NAME } from '@opentelemetry/semantic-conventions';

const sdk = new NodeSDK({
  resource: resourceFromAttributes({
    [ATTR_SERVICE_NAME]: 'order-service',
    'service.version': '2.1.0',
    'deployment.environment': 'production',
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://localhost:4317',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: 'http://localhost:4317' }),
    exportIntervalMillis: 60000,
  }),
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-fs': { enabled: false },
    '@opentelemetry/instrumentation-dns': { enabled: false },
  })],
});

sdk.start();
process.on('SIGTERM', () => sdk.shutdown().then(() => process.exit(0)));
```

### 26.2 Creating Spans

```typescript
import { trace, SpanKind, SpanStatusCode, context } from '@opentelemetry/api';

const tracer = trace.getTracer('order-service', '1.0.0');

async function processOrder(orderId: string): Promise<Order> {
  return tracer.startActiveSpan('process_order',
    { kind: SpanKind.INTERNAL, attributes: { 'order.id': orderId } },
    async (span) => {
      try {
        const result = await validateOrder(orderId);
        span.setAttribute('order.total', result.total);
        span.addEvent('Order validated', { 'items_count': result.items });
        span.setStatus({ code: SpanStatusCode.OK });
        return result;
      } catch (error) {
        span.recordException(error as Error);
        span.setStatus({
          code: SpanStatusCode.ERROR,
          message: (error as Error).message
        });
        throw error;
      } finally {
        span.end();  // Always end the span
      }
    });
}
```

---

## 27. Node.js Metrics and Logs API

### 27.1 Metrics

```typescript
import { metrics } from '@opentelemetry/api';

const meter = metrics.getMeter('order-service', '1.0.0');

const counter = meter.createCounter('http.server.request.total', {
  unit: '{request}',
  description: 'Total HTTP requests',
});

const histogram = meter.createHistogram('http.server.request.duration', {
  unit: 's',
  description: 'HTTP request duration',
});

const updown = meter.createUpDownCounter('http.server.active_connections');

// Observable gauge
const memGauge = meter.createObservableGauge('process.runtime.nodejs.memory.heap_used', {
  unit: 'By',
});
memGauge.addCallback((result) => {
  result.observe(process.memoryUsage().heapUsed);
});
```

### 27.2 Logs

Winston and Pino auto-instrumentation automatically injects `trace_id`, `span_id`, `trace_flags` into log records.

```typescript
// Manual trace context injection
import { trace, context } from '@opentelemetry/api';

function getTraceContext() {
  const span = trace.getSpan(context.active());
  if (span) {
    const ctx = span.spanContext();
    return { traceId: ctx.traceId, spanId: ctx.spanId };
  }
  return {};
}

// OTLP log export
import { LoggerProvider, BatchLogRecordProcessor } from '@opentelemetry/sdk-logs';
import { OTLPLogExporter } from '@opentelemetry/exporter-logs-otlp-grpc';

const loggerProvider = new LoggerProvider({ resource });
loggerProvider.addLogRecordProcessor(
  new BatchLogRecordProcessor(new OTLPLogExporter({ url: 'http://localhost:4317' }))
);
```

---

## 28. Node.js Framework Integrations

### 28.1 Express

Auto-instrumented by `@opentelemetry/instrumentation-http` and `@opentelemetry/instrumentation-express`. Custom spans in route handlers:

```typescript
app.get('/api/orders/:id', async (req, res) => {
  return tracer.startActiveSpan('getOrder', async (span) => {
    span.setAttribute('order.id', req.params.id);
    try {
      const order = await db.findOrder(req.params.id);
      span.setStatus({ code: SpanStatusCode.OK });
      res.json(order);
    } catch (err) {
      span.recordException(err as Error);
      span.setStatus({ code: SpanStatusCode.ERROR });
      res.status(500).json({ error: 'Internal error' });
    } finally {
      span.end();
    }
  });
});
```

### 28.2 NestJS

Auto-instrumented via `@opentelemetry/instrumentation-nestjs-core`. Custom interceptor:

```typescript
@Injectable()
export class TracingInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const span = trace.getSpan(otelContext.active());
    const handler = context.getHandler().name;
    const controller = context.getClass().name;
    span?.setAttribute('nestjs.controller', controller);
    span?.setAttribute('nestjs.handler', handler);
    return next.handle();
  }
}
```

### 28.3 Next.js

```typescript
// instrumentation.ts (Next.js 13.4+)
export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Only instrument in Node.js runtime (not Edge)
    await import('./otel-setup');
  }
}
```

With `@vercel/otel` (simplified):
```typescript
import { registerOTel } from '@vercel/otel';
export function register() {
  registerOTel({ serviceName: 'my-nextjs-app' });
}
```

---

## 29. Node.js Configuration and Pitfalls

### 29.1 Key Environment Variables

| Variable | Description |
|---|---|
| `OTEL_NODE_ENABLED_INSTRUMENTATIONS` | Comma-separated enabled list |
| `OTEL_NODE_DISABLED_INSTRUMENTATIONS` | Comma-separated disabled list |
| `OTEL_NODE_RESOURCE_DETECTORS` | `env,host,os,process,serviceinstance` |

### 29.2 Resource Detection

Built-in: `envDetector`, `hostDetector`, `osDetector`, `processDetector`, `serviceInstanceIdDetector`. Cloud: `@opentelemetry/resource-detector-aws`, `@opentelemetry/resource-detector-gcp`, `@opentelemetry/resource-detector-container`.

### 29.3 Performance

| Metric | Typical Impact |
|---|---|
| Per-request overhead | +0.5-2ms |
| CPU overhead | +1-3% |
| Memory overhead | +10-30MB |

### 29.4 Common Pitfalls

1. **ESM monkey-patching**: Cannot monkey-patch ESM modules. Use `--experimental-loader` or `--import` hooks.
2. **Load order**: Instrumentation MUST load before any library imports. Use `--require` or `--import`.
3. **Async context loss**: Use `context.bind()` for event emitters and callbacks.
4. **Using `startSpan` instead of `startActiveSpan`**: `startSpan` doesn't set context, child spans won't be linked.
5. **Not handling SIGTERM**: Pending spans are lost without graceful shutdown.
6. **fs/dns noise**: Disable `fs` and `dns` instrumentation unless specifically needed.

---

## PART V: GO

---

## 30. Go SDK Setup

### 30.1 Installation

```bash
go get go.opentelemetry.io/otel \
  go.opentelemetry.io/otel/sdk \
  go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc \
  go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc \
  go.opentelemetry.io/otel/sdk/metric
```

### 30.2 Full SDK Initialization

```go
package main

import (
    "context"
    "log"
    "time"

    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
    "go.opentelemetry.io/otel/sdk/metric"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.26.0"
)

func initOTel(ctx context.Context) (func(), error) {
    res, err := resource.New(ctx,
        resource.WithAttributes(
            semconv.ServiceName("order-service"),
            semconv.ServiceVersion("2.1.0"),
            semconv.DeploymentEnvironment("production"),
        ),
        resource.WithHost(),
        resource.WithProcess(),
        resource.WithOS(),
        resource.WithContainer(),
    )
    if err != nil {
        return nil, err
    }

    // Traces
    traceExporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint("localhost:4317"),
        otlptracegrpc.WithInsecure())
    if err != nil {
        return nil, err
    }

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithResource(res),
        sdktrace.WithBatcher(traceExporter,
            sdktrace.WithMaxQueueSize(2048),
            sdktrace.WithMaxExportBatchSize(512),
            sdktrace.WithBatchTimeout(5*time.Second)),
        sdktrace.WithSampler(sdktrace.ParentBased(
            sdktrace.TraceIDRatioBased(0.1))),
    )
    otel.SetTracerProvider(tp)

    // Metrics
    metricExporter, err := otlpmetricgrpc.New(ctx,
        otlpmetricgrpc.WithEndpoint("localhost:4317"),
        otlpmetricgrpc.WithInsecure())
    if err != nil {
        return nil, err
    }

    mp := metric.NewMeterProvider(
        metric.WithResource(res),
        metric.WithReader(metric.NewPeriodicReader(metricExporter,
            metric.WithInterval(60*time.Second))),
    )
    otel.SetMeterProvider(mp)

    // Propagation
    otel.SetTextMapPropagator(
        propagation.NewCompositeTextMapPropagator(
            propagation.TraceContext{},
            propagation.Baggage{}))

    shutdown := func() {
        ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancel()
        tp.Shutdown(ctx)
        mp.Shutdown(ctx)
    }
    return shutdown, nil
}
```

---

## 31. Go Manual Instrumentation

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/codes"
    "go.opentelemetry.io/otel/trace"
)

var tracer = otel.Tracer("mycompany.com/order-service",
    trace.WithInstrumentationVersion("1.0.0"))

func ProcessOrder(ctx context.Context, orderID string, items []Item) (*Order, error) {
    ctx, span := tracer.Start(ctx, "ProcessOrder",
        trace.WithSpanKind(trace.SpanKindInternal),
        trace.WithAttributes(
            attribute.String("order.id", orderID),
            attribute.Int("order.item_count", len(items)),
        ))
    defer span.End()

    if err := validateOrder(ctx, orderID); err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }

    total := calculateTotal(ctx, items)
    span.SetAttributes(attribute.Float64("order.total", total))
    span.AddEvent("Order validated", trace.WithAttributes(
        attribute.String("order.id", orderID)))
    span.SetStatus(codes.Ok, "")
    return &Order{ID: orderID, Total: total}, nil
}

// Nested spans: just pass ctx
func validateOrder(ctx context.Context, orderID string) error {
    ctx, span := tracer.Start(ctx, "validateOrder")
    defer span.End()
    // validation logic
    return nil
}
```

---

## 32. Go Instrumentation Libraries

### 32.1 HTTP Server (otelhttp)

```go
import "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

mux := http.NewServeMux()
mux.HandleFunc("/api/orders", handleOrders)
handler := otelhttp.NewHandler(mux, "http-server",
    otelhttp.WithMessageEvents(otelhttp.ReadEvents, otelhttp.WriteEvents))
http.ListenAndServe(":8080", handler)
```

### 32.2 HTTP Client (otelhttp Transport)

```go
client := &http.Client{
    Transport: otelhttp.NewTransport(http.DefaultTransport),
}
resp, err := client.Get("https://api.example.com/data")
```

### 32.3 Gin

```go
import "go.opentelemetry.io/contrib/instrumentation/github.com/gin-gonic/gin/otelgin"

r := gin.New()
r.Use(otelgin.Middleware("order-service"))
```

### 32.4 Echo

```go
import "go.opentelemetry.io/contrib/instrumentation/github.com/labstack/echo/otelecho"

e := echo.New()
e.Use(otelecho.Middleware("order-service"))
```

### 32.5 gRPC

```go
import "go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"

// Server
grpcServer := grpc.NewServer(
    grpc.StatsHandler(otelgrpc.NewServerHandler()))

// Client
conn, _ := grpc.Dial("localhost:50051",
    grpc.WithStatsHandler(otelgrpc.NewClientHandler()))
```

### 32.6 Database (otelsql)

```go
import "github.com/XSAM/otelsql"
import semconv "go.opentelemetry.io/otel/semconv/v1.26.0"

db, err := otelsql.Open("postgres", dsn,
    otelsql.WithAttributes(semconv.DBSystemPostgreSQL),
    otelsql.WithDBName("orders"))

// Or wrap existing driver
otelsql.Register("instrumented-postgres",
    otelsql.WithAttributes(semconv.DBSystemPostgreSQL))
db, _ := sql.Open("instrumented-postgres", dsn)
```

### 32.7 GORM

```go
import "github.com/uptrace/opentelemetry-go-extra/otelgorm"

db, _ := gorm.Open(postgres.Open(dsn), &gorm.Config{})
db.Use(otelgorm.NewPlugin())
```

### 32.8 Redis

```go
import "github.com/redis/go-redis/extra/redisotel/v9"

rdb := redis.NewClient(&redis.Options{Addr: "localhost:6379"})
rdb.AddHook(redisotel.NewTracingHook())
```

### 32.9 AWS SDK v2

```go
import "go.opentelemetry.io/contrib/instrumentation/github.com/aws/aws-sdk-go-v2/otelaws"

cfg, _ := config.LoadDefaultConfig(ctx)
otelaws.AppendMiddlewares(&cfg.APIOptions)
```

### 32.10 Kafka (Sarama)

```go
import "go.opentelemetry.io/contrib/instrumentation/github.com/IBM/sarama/otelsarama"

producer := otelsarama.WrapSyncProducer(config, syncProducer)
consumer := otelsarama.WrapConsumerGroupHandler(handler)
```

---

## 33. Go Metrics API

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/attribute"
    "go.opentelemetry.io/otel/metric"
)

meter := otel.Meter("mycompany.com/order-service")

// Synchronous Counter
requestCounter, _ := meter.Int64Counter("http.server.request.total",
    metric.WithDescription("Total HTTP requests"),
    metric.WithUnit("{request}"))
requestCounter.Add(ctx, 1,
    metric.WithAttributes(attribute.String("http.method", "GET")))

// Synchronous Histogram
requestDuration, _ := meter.Float64Histogram("http.server.request.duration",
    metric.WithDescription("HTTP request duration"),
    metric.WithUnit("s"))
requestDuration.Record(ctx, 0.045,
    metric.WithAttributes(attribute.String("http.route", "/orders")))

// Synchronous UpDownCounter
activeConns, _ := meter.Int64UpDownCounter("http.server.active_connections")
activeConns.Add(ctx, 1)   // open
activeConns.Add(ctx, -1)  // close

// Async Observable Gauge
meter.Float64ObservableGauge("process.runtime.go.mem.heap_alloc",
    metric.WithUnit("By"),
    metric.WithFloat64Callback(func(ctx context.Context, o metric.Float64Observer) error {
        var m runtime.MemStats
        runtime.ReadMemStats(&m)
        o.Observe(float64(m.HeapAlloc))
        return nil
    }))
```

---

## 34. Go Logs (slog Bridge)

```go
import (
    "log/slog"
    "go.opentelemetry.io/contrib/bridges/otelslog"
    "go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
    sdklog "go.opentelemetry.io/otel/sdk/log"
)

// Setup
logExporter, _ := otlploggrpc.New(ctx)
logProvider := sdklog.NewLoggerProvider(
    sdklog.WithResource(res),
    sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)))

logger := otelslog.NewLogger("my-service",
    otelslog.WithLoggerProvider(logProvider))
slog.SetDefault(logger)

// Usage -- trace_id/span_id automatically correlated
slog.InfoContext(ctx, "Order processed",
    slog.String("order.id", orderID),
    slog.Float64("order.total", total))
```

---

## 35. Go eBPF Auto-Instrumentation

Go doesn't support traditional auto-instrumentation (no bytecode manipulation). Instead, eBPF-based instrumentation runs as a sidecar:

```yaml
# Kubernetes Operator annotation
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-go: "true"
    instrumentation.opentelemetry.io/otel-go-auto-target-exe: /app/server
```

Supported: HTTP (`net/http`), gRPC, database/sql. Captures RED metrics (Rate, Error, Duration) without code changes.

```go
// Or programmatic (non-Kubernetes)
import "go.opentelemetry.io/auto"

inst, err := auto.NewInstrumentation(
    auto.WithTarget(auto.NewTargetArgs{Exe: "/app/server"}),
    auto.WithServiceName("order-service"),
    auto.WithGlobal(),
)
defer inst.Close()
```

**Limitations:** Cannot capture custom attributes, business context, or non-HTTP/gRPC protocols. Best used as a starting point before adding SDK instrumentation.

---

## 36. Go Performance and Pitfalls

### 36.1 Performance

| Metric | Impact |
|---|---|
| Per-span overhead | ~1-2μs (microseconds) |
| Memory per span | ~300 bytes |
| HTTP middleware | +0.1-0.5ms |
| gRPC interceptor | +0.05-0.2ms |

Go's OTel SDK is highly optimized with zero-allocation paths for hot metric recording.

### 36.2 Common Pitfalls

1. **Forgetting `defer span.End()`**: Memory leak, span never exported.
2. **Not passing `ctx`**: Child spans won't be linked. Always propagate `context.Context`.
3. **`otel.Tracer()` outside `init`**: Returns noop tracer before provider is set. Call after `otel.SetTracerProvider()`.
4. **High-cardinality metric attributes**: Same as all languages.
5. **Missing `otel.SetTextMapPropagator()`**: Context not propagated across services.
6. **Using `context.Background()` in handlers**: Loses trace context. Use the request context.
7. **Not shutting down providers**: `defer shutdown()` in main.

---

## PART VI: RUST

---

## 37. Rust tracing-opentelemetry Bridge

Rust uses the `tracing` crate ecosystem, bridged to OTel via `tracing-opentelemetry`.

### 37.1 Dependencies (Cargo.toml)

```toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
tracing-opentelemetry = "0.28"
opentelemetry = "0.28"
opentelemetry_sdk = { version = "0.28", features = ["rt-tokio"] }
opentelemetry-otlp = { version = "0.28", features = ["tonic"] }
opentelemetry-semantic-conventions = "0.28"
```

### 37.2 Setup

```rust
use opentelemetry::global;
use opentelemetry_sdk::{trace::SdkTracerProvider, Resource};
use opentelemetry_otlp::SpanExporter;
use opentelemetry_semantic_conventions::resource::SERVICE_NAME;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

fn init_tracing() -> SdkTracerProvider {
    let exporter = SpanExporter::builder().with_tonic().build()
        .expect("OTLP exporter");
    let provider = SdkTracerProvider::builder()
        .with_batch_exporter(exporter)
        .with_resource(Resource::builder()
            .with_attribute(KeyValue::new(SERVICE_NAME, "order-service"))
            .build())
        .build();
    global::set_tracer_provider(provider.clone());

    let otel_layer = tracing_opentelemetry::layer()
        .with_tracer(global::tracer("order-service"));

    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env())
        .with(otel_layer)
        .with(tracing_subscriber::fmt::layer())
        .init();

    provider
}
```

### 37.3 Using #[instrument]

```rust
use tracing::{instrument, info, error};

#[instrument(name = "ProcessOrder", skip(items), fields(order.id = %order_id, order.item_count = items.len()))]
async fn process_order(order_id: &str, items: Vec<Item>) -> Result<Order, OrderError> {
    info!("Starting order processing");

    let total = calculate_total(&items).await?;
    tracing::Span::current().record("order.total", total);

    info!(order.total = total, "Order processed successfully");
    Ok(Order { id: order_id.into(), total })
}

#[instrument(err)]  // Automatically records error as span event
async fn calculate_total(items: &[Item]) -> Result<f64, OrderError> {
    Ok(items.iter().map(|i| i.price * i.quantity as f64).sum())
}
```

---

## 38. Rust Framework Integrations

### 38.1 Axum

```rust
use axum::{Router, routing::get, extract::Path, Json};
use axum_tracing_opentelemetry::middleware::OtelAxumLayer;

#[tokio::main]
async fn main() {
    let _provider = init_tracing();
    let app = Router::new()
        .route("/api/orders/:id", get(get_order))
        .layer(OtelAxumLayer::default());
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

#[instrument(skip_all, fields(order.id = %id))]
async fn get_order(Path(id): Path<String>) -> Json<Order> {
    tracing::info!("Fetching order");
    Json(fetch_from_db(&id).await)
}
```

### 38.2 Actix-Web

```rust
use actix_web::{web, App, HttpServer};
use actix_web_opentelemetry::RequestTracing;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let _provider = init_tracing();
    HttpServer::new(|| {
        App::new()
            .wrap(RequestTracing::new())
            .route("/api/orders/{id}", web::get().to(get_order))
    })
    .bind("0.0.0.0:8080")?.run().await
}
```

---

## 39. Rust Metrics and Logs

### 39.1 Metrics

```rust
use opentelemetry::{global, KeyValue};

fn init_metrics() -> SdkMeterProvider {
    let exporter = opentelemetry_otlp::MetricExporter::builder()
        .with_tonic().build().expect("metric exporter");
    let provider = SdkMeterProvider::builder()
        .with_periodic_exporter(exporter).build();
    global::set_meter_provider(provider.clone());
    provider
}

async fn record_metrics() {
    let meter = global::meter("my-rust-service");
    let counter = meter.u64_counter("orders.created")
        .with_description("Total orders created").build();
    let histogram = meter.f64_histogram("http.server.request.duration")
        .with_unit("s").build();

    counter.add(1, &[KeyValue::new("order.type", "standard")]);
    histogram.record(0.045, &[KeyValue::new("http.method", "POST")]);
}
```

### 39.2 Logs via opentelemetry-appender-tracing

```rust
use opentelemetry_appender_tracing::layer::OpenTelemetryTracingBridge;
use opentelemetry_sdk::logs::SdkLoggerProvider;

fn init_logs() -> SdkLoggerProvider {
    let exporter = opentelemetry_otlp::LogExporter::builder()
        .with_tonic().build().expect("log exporter");
    let provider = SdkLoggerProvider::builder()
        .with_batch_exporter(exporter).build();
    let otel_log_layer = OpenTelemetryTracingBridge::new(&provider);
    tracing_subscriber::registry()
        .with(otel_log_layer)
        .with(tracing_subscriber::fmt::layer())
        .init();
    provider
}
```

---

## PART VII: PHP

---

## 40. PHP Installation and Auto-Instrumentation

PHP instrumentation uses a C extension (`ext-opentelemetry`) that hooks into PHP's engine, plus Composer packages for framework-specific auto-instrumentation.

### 40.1 Installation

```bash
# Install the C extension
pecl install opentelemetry
echo "extension=opentelemetry.so" >> $(php -r "echo php_ini_loaded_file();")
php --ri opentelemetry  # verify

# Install SDK and auto-instrumentation
composer require \
    open-telemetry/sdk \
    open-telemetry/exporter-otlp \
    open-telemetry/opentelemetry-auto-slim \
    open-telemetry/transport-grpc
```

### 40.2 Zero-Code Auto-Instrumentation

```bash
export OTEL_PHP_AUTOLOAD_ENABLED=true
export OTEL_SERVICE_NAME=my-php-service
export OTEL_TRACES_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_PROPAGATORS=tracecontext,baggage
export OTEL_TRACES_SAMPLER=parentbased_traceidratio
export OTEL_TRACES_SAMPLER_ARG=0.1

php artisan serve   # Laravel -- instrumentation happens automatically
```

### 40.3 Framework Packages

```bash
composer require open-telemetry/opentelemetry-auto-laravel   # Laravel
composer require open-telemetry/opentelemetry-auto-symfony   # Symfony
```

**Laravel** auto-instruments: HTTP requests, DB queries, cache operations, queue jobs, view rendering, console commands.

**Symfony** auto-instruments: HTTP kernel, console commands, HTTP client, Messenger messages.

---

## 41. PHP Manual Instrumentation

```php
<?php
use OpenTelemetry\API\Trace\SpanKind;
use OpenTelemetry\API\Trace\StatusCode;
use OpenTelemetry\SDK\Trace\TracerProviderBuilder;
use OpenTelemetry\SDK\Trace\SpanProcessor\BatchSpanProcessorBuilder;
use OpenTelemetry\Contrib\Otlp\SpanExporterFactory;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SDK\Common\Attribute\Attributes;

// --- SDK Setup ---
$resource = ResourceInfo::create(Attributes::create([
    'service.name' => 'my-php-service',
    'service.version' => '1.0.0',
    'deployment.environment' => 'production',
]));

$exporter = (new SpanExporterFactory())->create();
$tracerProvider = (new TracerProviderBuilder())
    ->addSpanProcessor(
        (new BatchSpanProcessorBuilder($exporter))
            ->setMaxQueueSize(2048)
            ->setMaxExportBatchSize(512)
            ->build()
    )
    ->setResource($resource)
    ->build();

$tracer = $tracerProvider->getTracer('mycompany.com/order-service', '1.0.0');

// --- Manual Spans ---
function processOrder(string $orderId, array $items): void
{
    global $tracer;

    $span = $tracer->spanBuilder('ProcessOrder')
        ->setSpanKind(SpanKind::KIND_INTERNAL)
        ->setAttribute('order.id', $orderId)
        ->setAttribute('order.item_count', count($items))
        ->startSpan();

    $scope = $span->activate();

    try {
        $span->addEvent('order.validated', ['order.id' => $orderId]);
        $total = calculateTotal($items);
        $span->setAttribute('order.total', $total);
        $span->setStatus(StatusCode::STATUS_OK);
    } catch (\Throwable $e) {
        $span->recordException($e, ['exception.escaped' => true]);
        $span->setStatus(StatusCode::STATUS_ERROR, $e->getMessage());
        throw $e;
    } finally {
        $scope->detach();
        $span->end();
    }
}

// --- Metrics ---
$meter = \OpenTelemetry\API\Globals::meterProvider()->getMeter('my-php-service');

$requestCounter = $meter->createCounter('http.server.requests', '{request}');
$requestDuration = $meter->createHistogram('http.server.request.duration', 's');

$requestCounter->add(1, ['http.method' => 'POST', 'http.route' => '/api/orders']);
$requestDuration->record(0.045, ['http.method' => 'POST', 'http.status_code' => 201]);

$tracerProvider->shutdown();
```

---

## PART VIII: RUBY

---

## 42. Ruby Rails Auto-Instrumentation

### 42.1 Gemfile

```ruby
gem 'opentelemetry-sdk'
gem 'opentelemetry-exporter-otlp'
gem 'opentelemetry-instrumentation-all'  # 53+ instrumentation libraries
```

### 42.2 config/initializers/opentelemetry.rb

```ruby
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/instrumentation/all'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'my-rails-app'
  c.service_version = '1.0.0'

  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: 'http://localhost:4317',
      ),
      max_queue_size: 2048,
      max_export_batch_size: 512,
      schedule_delay: 5000,
    )
  )

  c.traces_sampler = OpenTelemetry::SDK::Trace::Samplers.parent_based(
    root: OpenTelemetry::SDK::Trace::Samplers.trace_id_ratio_based(0.1)
  )

  c.use_all({
    'OpenTelemetry::Instrumentation::Rails' => {
      enable_recognize_route: true,
    },
    'OpenTelemetry::Instrumentation::ActiveRecord' => {
      db_statement: :obfuscate,
    },
    'OpenTelemetry::Instrumentation::Sidekiq' => {
      span_naming: :job_class,
      propagation_style: :link,
    },
    'OpenTelemetry::Instrumentation::Redis' => {
      db_statement: :obfuscate,
    },
  })
end
```

### 42.3 Supported Libraries

| Category | Libraries |
|---|---|
| Web Frameworks | Rails, Sinatra, Rack, Grape |
| HTTP Clients | Net::HTTP, Faraday, Excon, Ethon, RestClient |
| Databases | ActiveRecord, PG, MySQL2, Trilogy, Mongo |
| Caching | Redis, Dalli (Memcached) |
| Background Jobs | Sidekiq, Delayed Job, Resque, Concurrent Ruby |
| Messaging | Bunny (RabbitMQ), RubyKafka |
| Cloud | AWS SDK, AWS Lambda |
| GraphQL | GraphQL Ruby |

---

## 43. Ruby Manual Instrumentation

```ruby
MyTracer = OpenTelemetry.tracer_provider.tracer('mycompany.com/order-service', '1.0.0')

class OrderService
  def process_order(order_id, items)
    MyTracer.in_span(
      'ProcessOrder',
      attributes: { 'order.id' => order_id, 'order.item_count' => items.length },
      kind: :internal
    ) do |span|
      span.add_event('order.validated', attributes: { 'order.id' => order_id })

      total = calculate_total(items)
      span.set_attribute('order.total', total)

      charge_payment(order_id, total)
      span.status = OpenTelemetry::Trace::Status.ok('Order processed')
    end
  rescue StandardError => e
    span = OpenTelemetry::Trace.current_span
    span.record_exception(e)
    span.status = OpenTelemetry::Trace::Status.error(e.message)
    raise
  end

  private

  def calculate_total(items)
    MyTracer.in_span('calculateTotal') do |span|
      total = items.sum { |i| i[:price] * i[:quantity] }
      span.set_attribute('calculated.total', total)
      total
    end
  end
end
```

### Sinatra

```ruby
require 'sinatra/base'
require 'opentelemetry/sdk'
require 'opentelemetry/instrumentation/sinatra'

OpenTelemetry::SDK.configure do |c|
  c.service_name = 'my-sinatra-app'
  c.use 'OpenTelemetry::Instrumentation::Sinatra'
end

class MyApp < Sinatra::Base
  get '/api/orders/:id' do
    span = OpenTelemetry::Trace.current_span
    span.set_attribute('order.id', params[:id])
    json Order.find(params[:id])
  end
end
```

### Sidekiq

```ruby
class OrderProcessor
  include Sidekiq::Job

  def perform(order_id)
    span = OpenTelemetry::Trace.current_span
    span.set_attribute('order.id', order_id)
    Order.find(order_id).process!
  end
end
```

---

## PART IX: SWIFT / MOBILE

---

## 44. Swift SDK Setup and URLSession

### 44.1 Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.10.0"),
]
```

### 44.2 SDK Initialization

```swift
import OpenTelemetryApi
import OpenTelemetrySdk
import OtlpGrpcExporter
import URLSessionInstrumentation

func initializeOpenTelemetry() {
    let resource = Resource(attributes: [
        ResourceAttributes.serviceName.rawValue: AttributeValue.string("my-ios-app"),
        ResourceAttributes.serviceVersion.rawValue: AttributeValue.string(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"),
        "device.model": AttributeValue.string(UIDevice.current.model),
        "os.version": AttributeValue.string(UIDevice.current.systemVersion),
    ])

    let otlpExporter = OtlpTraceExporter(channel: /* gRPC channel */)

    let tracerProvider = TracerProviderBuilder()
        .with(resource: resource)
        .add(spanProcessor: BatchSpanProcessor(
            spanExporter: otlpExporter,
            scheduleDelay: 5.0, maxQueueSize: 2048, maxExportBatchSize: 512
        ))
        .build()

    OpenTelemetry.registerTracerProvider(tracerProvider: tracerProvider)
}
```

### 44.3 URLSession Instrumentation

```swift
let urlSessionInstrumentation = URLSessionInstrumentation(
    configuration: URLSessionInstrumentationConfiguration(
        shouldInstrument: { request in
            return request.url?.host == "api.mycompany.com"
        },
        nameSpan: { request in
            return "\(request.httpMethod ?? "GET") \(request.url?.path ?? "/")"
        }
    )
)
```

### 44.4 Manual Spans

```swift
let tracer = OpenTelemetry.instance.tracerProvider
    .get(instrumentationName: "my-ios-app", instrumentationVersion: "1.0.0")

func fetchOrder(orderId: String) async throws -> Order {
    let span = tracer.spanBuilder(spanName: "fetchOrder")
        .setSpanKind(spanKind: .client)
        .setAttribute(key: "order.id", value: orderId)
        .startSpan()
    defer { span.end() }

    do {
        let order = try await apiClient.getOrder(id: orderId)
        span.status = .ok
        return order
    } catch {
        span.status = .error(description: error.localizedDescription)
        span.addEvent(name: "exception", attributes: [
            "exception.type": AttributeValue.string(String(describing: type(of: error))),
            "exception.message": AttributeValue.string(error.localizedDescription),
        ])
        throw error
    }
}
```

---

## 45. Mobile-Specific Considerations

| Concern | Recommendation |
|---|---|
| **Battery** | Use aggressive batching (30s+ intervals), sample at 1-5% |
| **Network** | Buffer spans offline, flush on connectivity restoration |
| **Lifecycle** | Flush spans on `applicationDidEnterBackground` |
| **Payload size** | Minimize attributes; mobile bandwidth is constrained |
| **Session correlation** | Use a session ID attribute to group spans per user session |

---

## PART X: CROSS-CUTTING CONCEPTS

---

## 46. SDK Architecture Overview

All OTel SDKs share a common architecture with three parallel signal pipelines:

```
TRACING:   TracerProvider --> Tracer --> Span
                |                        |
                +-- Resource             +-- Attributes, Events, Links, Status
                +-- Sampler              +-- SpanProcessor(s) --> SpanExporter(s)

METRICS:   MeterProvider --> Meter --> Instrument (Counter, Histogram, Gauge)
                |                        |
                +-- Resource             +-- Attributes (dimensions)
                +-- View(s)              +-- MetricReader(s) --> MetricExporter(s)

LOGGING:   LoggerProvider --> Logger --> LogRecord
                |                        |
                +-- Resource             +-- Timestamp, Severity, Body, Attributes
                                         +-- LogRecordProcessor(s) --> LogRecordExporter(s)
```

**Provider** is the entry point (created once at startup). **Tracer/Meter/Logger** is scoped to an instrumentation library. **Processor** sits between creation and export (batch, filter). **Exporter** sends data out of process. **Resource** is shared across all signals.

---

## 47. Context Propagation Deep Dive

### 47.1 W3C TraceContext Format

```
traceparent: {version}-{trace-id}-{parent-id}-{trace-flags}
             00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01

version:     00 (always "00")
trace-id:    32 hex chars (16 bytes)
parent-id:   16 hex chars (8 bytes)
trace-flags: 01 = sampled
```

The `tracestate` header carries vendor-specific data:
```
tracestate: congo=t61rcWkgMzE,rojo=00f067aa0ba902b7
```

### 47.2 B3 Format (Legacy, Zipkin)

```
# Single-header (preferred)
b3: {trace-id}-{span-id}-{sampling-state}-{parent-span-id}

# Multi-header (deprecated)
X-B3-TraceId / X-B3-SpanId / X-B3-ParentSpanId / X-B3-Sampled
```

### 47.3 Baggage Header

```
baggage: tenant_id=acme-corp,user_tier=premium;ttl=300,feature_flags=new_checkout
```

### 47.4 Configuration

```bash
OTEL_PROPAGATORS=tracecontext,baggage     # W3C (default, recommended)
OTEL_PROPAGATORS=b3                       # Zipkin single-header
OTEL_PROPAGATORS=tracecontext,baggage,b3  # Support both during migration
```

---

## 48. Semantic Conventions

### 48.1 HTTP (Stable)

| Attribute | Example |
|---|---|
| `http.request.method` | `GET` |
| `url.path` | `/orders` |
| `http.response.status_code` | `200` |
| `http.route` | `/orders/:id` |
| `server.address` | `api.example.com` |
| `server.port` | `443` |

### 48.2 Database (Stable)

| Attribute | Example |
|---|---|
| `db.system` | `postgresql` |
| `db.namespace` | `orders_db` |
| `db.operation.name` | `SELECT` |
| `db.query.text` | `SELECT * FROM orders WHERE id = ?` |
| `db.collection.name` | `orders` |

### 48.3 Messaging (Stable)

| Attribute | Example |
|---|---|
| `messaging.system` | `kafka` |
| `messaging.operation.type` | `publish` |
| `messaging.destination.name` | `orders-topic` |
| `messaging.message.id` | `msg-123` |

### 48.4 RPC

| Attribute | Example |
|---|---|
| `rpc.system` | `grpc` |
| `rpc.service` | `OrderService` |
| `rpc.method` | `GetOrder` |
| `rpc.grpc.status_code` | `0` |

### 48.5 Resource Attributes

| Attribute | Example | Description |
|---|---|---|
| `service.name` | `order-service` | Required: logical service name |
| `service.version` | `2.1.0` | Service version |
| `service.namespace` | `ecommerce` | Service grouping |
| `deployment.environment` | `production` | Deployment environment |
| `telemetry.sdk.language` | `go` | SDK language |
| `host.name` | `ip-10-0-1-42` | Hostname |
| `container.id` | `abc123def456` | Container ID |
| `k8s.pod.name` | `order-service-7b9c` | Kubernetes pod |
| `cloud.provider` | `aws` | Cloud provider |
| `cloud.region` | `us-east-1` | Cloud region |

---

## 49. Sampling Deep Dive

| Sampler | Behavior | Use Case |
|---|---|---|
| `AlwaysOn` | 100% of spans | Development, testing |
| `AlwaysOff` | 0% of spans | Disable tracing |
| `TraceIdRatioBased(0.1)` | 10% by trace ID hash | Cost reduction |
| `ParentBased(root)` | Respect parent; use root for new traces | Production default |
| Custom | Arbitrary logic | Priority/error sampling |

**Head sampling** (SDK-side): Reduces volume but may miss important traces.

**Tail sampling** (Collector-side): Never misses errors/slow traces but is memory-intensive.

**Recommended production:** `ParentBased(TraceIdRatioBased(0.1))` at SDK + Collector tail sampling for errors and slow traces.

---

## 50. Auto vs Manual Instrumentation Trade-offs

| Aspect | Auto-Instrumentation | Manual Instrumentation |
|---|---|---|
| Setup effort | Minimal (agent/hook) | Significant (code changes) |
| Coverage | Framework-level (HTTP, DB, RPC) | Any code path |
| Custom attributes | Limited | Full control |
| Business context | None | Rich domain attributes |
| Maintenance | Low (agent updates) | Higher (code + SDK updates) |
| Performance visibility | Infrastructure-level | Business-level |

**Recommendation:** Start with auto-instrumentation for baseline coverage, then progressively add manual spans for business-critical operations, custom attributes, and domain-specific context.

---

## 51. Zero-Code Approaches

### 51.1 OTel Operator for Kubernetes

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: my-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4317
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.1.0
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.49b0
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.54.0
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:1.14.0
---
# Pod annotations
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
    instrumentation.opentelemetry.io/inject-python: "true"
    instrumentation.opentelemetry.io/inject-nodejs: "true"
    instrumentation.opentelemetry.io/inject-dotnet: "true"
    instrumentation.opentelemetry.io/inject-go: "true"   # eBPF sidecar
```

### 51.2 Comparison

| Approach | Languages | Depth | Custom Attrs | Code Changes |
|---|---|---|---|---|
| Language Agent (javaagent, CLR) | Java, .NET | Deep | Limited | None |
| Require/Import Hooks | Node.js, Python | Deep | Limited | None |
| eBPF (OBI) | All | Surface (RED) | None | None |
| Go eBPF | Go only | Medium | None | None |
| Manual SDK | All | Full | Full | Yes |

---

## 52. Error Handling Patterns

Always pair `RecordError`/`RecordException` with `SetStatus(Error)`. `RecordError` adds an event with exception details; `SetStatus` marks the span as failed in the UI.

| Language | Record Error | Set Status |
|---|---|---|
| Java | `span.recordException(e)` | `span.setStatus(StatusCode.ERROR, msg)` |
| .NET | `activity?.RecordException(e)` | `activity?.SetStatus(ActivityStatusCode.Error, msg)` |
| Python | `span.record_exception(exc)` | `span.set_status(Status(StatusCode.ERROR, msg))` |
| Node.js | `span.recordException(err)` | `span.setStatus({ code: SpanStatusCode.ERROR, message })` |
| Go | `span.RecordError(err)` | `span.SetStatus(codes.Error, msg)` |
| Rust | `#[instrument(err)]` or manual | `span.set_status(StatusCode::Error, msg)` |
| PHP | `$span->recordException($e)` | `$span->setStatus(StatusCode::STATUS_ERROR, msg)` |
| Ruby | `span.record_exception(e)` | `span.status = Status.error(msg)` |

**Status codes:** `Unset` (default), `Ok` (explicit success), `Error` (operation failed).

**Guidelines:**
- Do NOT set `Error` for HTTP 404 (normal behavior)
- DO set `Error` for 5xx, unhandled exceptions, timeouts
- Only set `Ok` explicitly when the span represents a business operation that succeeded

---

## 53. Testing Instrumented Code

All languages provide in-memory exporters for testing. Use `SimpleSpanProcessor` (synchronous) in tests for deterministic results.

### Go

```go
exporter := tracetest.NewInMemoryExporter()
tp := sdktrace.NewTracerProvider(
    sdktrace.WithSyncer(exporter),
    sdktrace.WithSampler(sdktrace.AlwaysSample()),
)
otel.SetTracerProvider(tp)

// Run code, then assert:
spans := exporter.GetSpans()
assert(len(spans) == 2)
assert(spans[0].Name == "ProcessOrder")
exporter.Reset()
```

### Java

```java
InMemorySpanExporter exporter = InMemorySpanExporter.create();
SdkTracerProvider tp = SdkTracerProvider.builder()
    .addSpanProcessor(SimpleSpanProcessor.create(exporter))
    .build();

// Run code, then assert:
List<SpanData> spans = exporter.getFinishedSpanItems();
assertEquals(2, spans.size());
assertEquals("ProcessOrder", spans.get(0).getName());
exporter.reset();
```

### Python

```python
from opentelemetry.sdk.trace.export.in_memory import InMemorySpanExporter
from opentelemetry.sdk.trace.export import SimpleSpanProcessor

exporter = InMemorySpanExporter()
tp = TracerProvider()
tp.add_span_processor(SimpleSpanProcessor(exporter))
trace.set_tracer_provider(tp)

# Run code, then assert:
spans = exporter.get_finished_spans()
assert len(spans) == 2
assert spans[0].name == "ProcessOrder"
exporter.clear()
```

### Node.js

```typescript
import { InMemorySpanExporter, SimpleSpanProcessor } from '@opentelemetry/sdk-trace-base';

const exporter = new InMemorySpanExporter();
const provider = new NodeTracerProvider();
provider.addSpanProcessor(new SimpleSpanProcessor(exporter));
provider.register();

// Run code, then assert:
const spans = exporter.getFinishedSpans();
expect(spans).toHaveLength(2);
expect(spans[0].name).toBe('ProcessOrder');
exporter.reset();
```

### .NET

```csharp
var exportedItems = new List<Activity>();
var tp = Sdk.CreateTracerProviderBuilder()
    .AddSource("OrderService")
    .AddInMemoryExporter(exportedItems)
    .Build();

// Run code, then assert:
Assert.Equal(2, exportedItems.Count);
Assert.Equal("ProcessOrder", exportedItems[0].DisplayName);
```

### Ruby

```ruby
exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
OpenTelemetry::SDK.configure { |c| c.add_span_processor(processor) }

# Run code, then:
spans = exporter.finished_spans
assert_equal 2, spans.length
```

### PHP

```php
$exporter = new InMemoryExporter();
$tp = (new TracerProviderBuilder())
    ->addSpanProcessor(new SimpleSpanProcessor($exporter))->build();

// Run code, then:
$spans = $exporter->getSpans();
$this->assertCount(2, $spans);
```

---

## Quick Reference: Language Comparison Matrix

| Feature | Java | .NET | Python | Node.js | Go | Rust | PHP | Ruby |
|---|---|---|---|---|---|---|---|---|
| **Auto-instrumentation** | javaagent (Byte Buddy) | CLR Profiler + Startup Hooks | Monkey patching | Require/Import hooks | eBPF only | None | C extension + Composer | Gem hooks |
| **Supported libraries** | 600+ | 30+ | 30+ | 35+ | 13+ (manual) | 5+ (manual) | 10+ | 53+ |
| **K8s Operator** | Yes | Yes | Yes | Yes | Yes (eBPF) | No | No | No |
| **Span API** | Span | Activity | Span | Span | Span | tracing::Span | Span | Span |
| **Null safety** | No | Yes (Activity?) | No | No | No | No | No | No |
| **Async context** | Context.wrap() | AsyncLocal | Native async/await | AsyncLocalStorage | context.Context | tokio tasks | N/A (request-scoped) | Fiber/Thread |
| **Log bridge** | Log4j2/Logback MDC | ILogger | logging handler | winston/pino | slog bridge | tracing bridge | N/A | N/A |
| **Typical overhead** | 1-5ms, 2-5% CPU | 0.5-3ms, 2-6% CPU | 0.5-2ms, 1-3% CPU | 0.5-2ms, 1-3% CPU | 0.1-0.5ms, <1% CPU | <0.1ms, <1% CPU | 1-3ms, 2-4% CPU | 1-3ms, 2-4% CPU |

---

## Production Checklist (All Languages)

1. **Set `service.name`** -- without it, all telemetry is attributed to `unknown_service`
2. **Set `deployment.environment`** -- enables filtering prod vs staging in backends
3. **Use `ParentBased(TraceIdRatioBased(0.1))`** -- 10% sampling is a good starting point
4. **Use `BatchSpanProcessor`** -- never `SimpleSpanProcessor` in production
5. **Add shutdown hooks** -- flush pending spans on SIGTERM
6. **Filter health checks** -- exclude `/health`, `/ready`, `/live` from traces
7. **Avoid high-cardinality attributes** -- never use user IDs or request IDs as metric dimensions
8. **Always call `span.end()`** -- forgetting causes memory leaks and missing data
9. **Propagate context** -- ensure `traceparent` header flows across all service boundaries
10. **Test with in-memory exporters** -- validate instrumentation in CI/CD

---

*This document is part of the OllyStack consulting knowledge base. For collector configuration, see [opentelemetry-collector-deep-dive.md](opentelemetry-collector-deep-dive.md).*
