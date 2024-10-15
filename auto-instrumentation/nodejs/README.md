# Node.js Auto-Instrumentation with OpenTelemetry

## Overview

OpenTelemetry provides multiple instrumentation approaches for Node.js applications. Choose based on your requirements:

## Instrumentation Approaches (Recommended Order)

| Priority | Approach | Zero-Code | Custom Spans | When to Use |
|----------|----------|-----------|--------------|-------------|
| **1st** | **OBI (eBPF)** | Yes | No | Network-level traces, zero code changes, kernel 5.17+ |
| **2nd** | **`--require` / Operator injection** | Yes | No | Richer framework-aware spans (Express, Fastify, DB drivers, etc.) |
| **3rd** | **Manual SDK** | No | Yes | Custom business spans, metrics, or enrichment |

---

## Approach 1: OBI — OpenTelemetry eBPF Instrumentation (Start Here)

OBI is the **lowest-risk starting point** for any Node.js service. It requires zero code changes, zero `npm install` additions, and zero `--require` flags.

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
- No framework-specific spans (e.g., Express route names, PostgreSQL queries)
- No custom spans (use SDK for that)

> **When OBI is not enough:** If you need framework-aware spans (Express, Fastify, database drivers, etc.), HTTPS, or gRPC support, add `--require` instrumentation (Approach 2).

---

## Approach 2: `--require` / Operator Injection (Richer Framework-Aware Traces)

This approach loads instrumentation **before** your application code, providing deep framework-aware traces. Use this when OBI limitations apply or when you need richer trace detail.

### Step 1: Install Packages

```bash
npm install @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-grpc \
  @opentelemetry/exporter-metrics-otlp-grpc \
  @opentelemetry/resources \
  @opentelemetry/semantic-conventions
```

### Step 2a: Using `--require` Flag

Create a `tracing.js` file (see `tracing.js` in this directory), then start your app with:

```bash
export OTEL_SERVICE_NAME=my-node-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

node --require ./tracing.js app.js
```

Or set `NODE_OPTIONS` so it applies to all Node.js processes:

```bash
export NODE_OPTIONS="--require ./tracing.js"
export OTEL_SERVICE_NAME=my-node-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317

node app.js
# or
npm start
```

### Step 2b: Programmatic Setup

Import the tracing setup at the very top of your entry file, **before** any other imports:

```javascript
// app.js
require('./tracing');  // MUST be first

const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.send('Hello, World!');
});

app.listen(3000);
```

### Step 2c: Using ES Modules

For ESM-based projects, use the `--import` flag instead:

```bash
node --import ./tracing.mjs app.mjs
```

### Kubernetes Operator (Zero-Code)

If running on Kubernetes with the OTel Operator:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: "true"
```

The Operator injects the SDK and auto-instrumentation packages via an init container.

---

## Approach 3: Manual SDK (Custom Business Spans Only)

Use manual SDK instrumentation **only when you need custom business spans or metrics** that `--require` auto-instrumentation does not provide automatically.

```javascript
const { trace } = require('@opentelemetry/api');

const tracer = trace.getTracer('my-module');

async function processOrder(orderId) {
  return tracer.startActiveSpan('process_order', async (span) => {
    try {
      span.setAttribute('order.id', orderId);
      // ... business logic ...
      span.addEvent('order_validated');
      return result;
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: trace.SpanStatusCode.ERROR, message: error.message });
      throw error;
    } finally {
      span.end();
    }
  });
}
```

---

## Supported Libraries

The `@opentelemetry/auto-instrumentations-node` meta-package automatically instruments:

**Web Frameworks:**
- Express
- Fastify
- Koa
- Hapi
- Nest.js (via Express/Fastify)
- Restify

**HTTP:**
- http / https (built-in)
- undici / fetch
- axios (via http)

**Databases:**
- PostgreSQL (pg)
- MySQL / MySQL2
- MongoDB (mongoose via mongodb driver)
- Redis (ioredis, redis)
- Knex
- Sequelize (via underlying driver)
- Prisma (via underlying driver)

**Messaging:**
- Kafka (kafkajs)
- RabbitMQ (amqplib)
- AWS SQS (via aws-sdk)

**Other:**
- gRPC (@grpc/grpc-js)
- GraphQL
- Winston / Bunyan / Pino (log correlation)
- AWS SDK v2 and v3
- DNS
- Net

## Key Environment Variables

| Variable | Description |
|----------|-------------|
| `OTEL_SERVICE_NAME` | Logical service name |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector endpoint (default: `http://localhost:4317`) |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` or `http/protobuf` |
| `OTEL_TRACES_EXPORTER` | `otlp`, `console`, `none` |
| `OTEL_METRICS_EXPORTER` | `otlp`, `console`, `none` |
| `OTEL_LOGS_EXPORTER` | `otlp`, `console`, `none` |
| `OTEL_RESOURCE_ATTRIBUTES` | Comma-separated key=value resource attributes |
| `OTEL_PROPAGATORS` | Propagation formats (default: `tracecontext,baggage`) |
| `OTEL_TRACES_SAMPLER` | Sampling strategy |
| `OTEL_TRACES_SAMPLER_ARG` | Sampler argument |
| `OTEL_LOG_LEVEL` | SDK log level (`debug`, `info`, `warn`, `error`) |
| `NODE_OPTIONS` | Set to `--require ./tracing.js` for auto-load |

## Troubleshooting

```bash
# Export to console for local debugging
export OTEL_TRACES_EXPORTER=console
export OTEL_LOG_LEVEL=debug
node --require ./tracing.js app.js

# Verify instrumentation is loaded
node -e "require('./tracing'); console.log('OTel loaded successfully')"
```

## References

- [OpenTelemetry Node.js](https://opentelemetry.io/docs/instrumentation/js/getting-started/nodejs/)
- [Auto-Instrumentations](https://github.com/open-telemetry/opentelemetry-js-contrib/tree/main/metapackages/auto-instrumentations-node)
- [SDK Configuration](https://opentelemetry.io/docs/instrumentation/js/manual/)
- [OBI (eBPF) Distributed Traces](https://opentelemetry.io/docs/zero-code/obi/distributed-traces/)
