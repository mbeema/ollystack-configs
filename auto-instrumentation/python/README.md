# Python Auto-Instrumentation with OpenTelemetry

## Overview

OpenTelemetry provides multiple instrumentation approaches for Python applications. Choose based on your requirements:

## Instrumentation Approaches (Recommended Order)

| Priority | Approach | Zero-Code | Custom Spans | When to Use |
|----------|----------|-----------|--------------|-------------|
| **1st** | **OBI (eBPF)** | Yes | No | Network-level traces, zero code changes, kernel 5.17+ |
| **2nd** | **`opentelemetry-instrument` CLI** | Yes | No | Richer per-request detail with framework-aware spans |
| **3rd** | **Programmatic SDK** | No | Yes | Custom business spans, metrics, or enrichment |

---

## Approach 1: OBI — OpenTelemetry eBPF Instrumentation (Start Here)

OBI is the **lowest-risk starting point** for any Python service. It requires zero code changes, zero `pip install` additions, and zero process wrapper modifications.

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
- No framework-specific spans (e.g., Flask route names, SQLAlchemy queries)
- No custom spans (use SDK for that)

> **When OBI is not enough:** If you need framework-aware spans (Flask, Django, SQLAlchemy, Celery, etc.), HTTPS, or gRPC support, add the `opentelemetry-instrument` CLI (Approach 2).

---

## Approach 2: `opentelemetry-instrument` CLI (Richer Per-Request Detail)

The CLI wrapper provides **deep, framework-aware instrumentation** without code changes. Use this when OBI limitations apply or when you need richer trace detail.

### Step 1: Install Packages

```bash
# Core packages
pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp

# Auto-instrumentation bootstrap tool
pip install opentelemetry-instrumentation

# Automatically detect and install all relevant instrumentation packages
opentelemetry-bootstrap -a install
```

Or install specific instrumentations manually:

```bash
pip install opentelemetry-instrumentation-flask
pip install opentelemetry-instrumentation-django
pip install opentelemetry-instrumentation-requests
pip install opentelemetry-instrumentation-sqlalchemy
pip install opentelemetry-instrumentation-psycopg2
pip install opentelemetry-instrumentation-redis
pip install opentelemetry-instrumentation-celery
```

### Step 2: Use the CLI Wrapper

```bash
export OTEL_SERVICE_NAME=my-python-service
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp
export OTEL_LOGS_EXPORTER=otlp

# Wrap your application start command
opentelemetry-instrument python app.py

# Works with any Python command
opentelemetry-instrument gunicorn app:app --bind 0.0.0.0:8000
opentelemetry-instrument uvicorn main:app --host 0.0.0.0 --port 8000
opentelemetry-instrument celery -A tasks worker --loglevel=info
opentelemetry-instrument flask run --host 0.0.0.0
```

### Kubernetes Operator (Zero-Code)

If running on Kubernetes with the OTel Operator installed:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "true"
```

The Operator injects an init container with all required Python packages and sets the environment so that `opentelemetry-instrument` wraps your entrypoint.

---

## Approach 3: Programmatic SDK (Custom Business Spans Only)

Use programmatic setup **only when you need custom business spans or metrics** that the CLI wrapper does not provide automatically.

```python
# tracing.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

def configure_tracing(app=None):
    resource = Resource.create({
        SERVICE_NAME: "my-python-service",
        "deployment.environment": "production",
        "service.version": "1.0.0",
    })

    provider = TracerProvider(resource=resource)
    exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317")
    provider.add_span_processor(BatchSpanProcessor(exporter))
    trace.set_tracer_provider(provider)

    # Instrument libraries
    if app:
        FlaskInstrumentor().instrument_app(app)
    RequestsInstrumentor().instrument()
    SQLAlchemyInstrumentor().instrument()
```

Then call it from your application entry point:

```python
from flask import Flask
from tracing import configure_tracing

app = Flask(__name__)
configure_tracing(app)

@app.route("/")
def hello():
    return "Hello, World!"
```

### Creating Custom Spans

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

def process_order(order_id):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        # ... your business logic ...
        span.add_event("order_validated")
```

---

## Supported Libraries

| Library | Package |
|---------|---------|
| Flask | `opentelemetry-instrumentation-flask` |
| Django | `opentelemetry-instrumentation-django` |
| FastAPI | `opentelemetry-instrumentation-fastapi` |
| Starlette | `opentelemetry-instrumentation-starlette` |
| Tornado | `opentelemetry-instrumentation-tornado` |
| requests | `opentelemetry-instrumentation-requests` |
| urllib3 | `opentelemetry-instrumentation-urllib3` |
| aiohttp | `opentelemetry-instrumentation-aiohttp-client` |
| httpx | `opentelemetry-instrumentation-httpx` |
| SQLAlchemy | `opentelemetry-instrumentation-sqlalchemy` |
| psycopg2 | `opentelemetry-instrumentation-psycopg2` |
| asyncpg | `opentelemetry-instrumentation-asyncpg` |
| pymongo | `opentelemetry-instrumentation-pymongo` |
| Redis | `opentelemetry-instrumentation-redis` |
| Celery | `opentelemetry-instrumentation-celery` |
| gRPC | `opentelemetry-instrumentation-grpc` |
| Kafka | `opentelemetry-instrumentation-confluent-kafka` |
| boto3 (AWS) | `opentelemetry-instrumentation-botocore` |
| Logging | `opentelemetry-instrumentation-logging` |

## Key Environment Variables

| Variable | Description |
|----------|-------------|
| `OTEL_SERVICE_NAME` | Logical service name |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Collector endpoint |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` or `http/protobuf` |
| `OTEL_TRACES_EXPORTER` | `otlp`, `console`, `none` |
| `OTEL_METRICS_EXPORTER` | `otlp`, `console`, `none` |
| `OTEL_LOGS_EXPORTER` | `otlp`, `console`, `none` |
| `OTEL_RESOURCE_ATTRIBUTES` | Additional resource attributes |
| `OTEL_PROPAGATORS` | Context propagation (default: `tracecontext,baggage`) |
| `OTEL_TRACES_SAMPLER` | Sampling strategy |
| `OTEL_TRACES_SAMPLER_ARG` | Sampler argument (e.g., ratio) |
| `OTEL_PYTHON_LOG_CORRELATION` | Enable log correlation (`true`/`false`) |
| `OTEL_PYTHON_LOG_LEVEL` | Log level for OTel SDK (`debug`, `info`, etc.) |
| `OTEL_PYTHON_DISABLED_INSTRUMENTATIONS` | Comma-separated list of instrumentations to disable |

## Troubleshooting

```bash
# List detected instrumentable packages
opentelemetry-bootstrap --action=requirements

# Enable debug logging
export OTEL_PYTHON_LOG_LEVEL=debug
export OTEL_LOG_LEVEL=debug

# Export to console for local testing
export OTEL_TRACES_EXPORTER=console
opentelemetry-instrument python app.py
```

## References

- [OpenTelemetry Python](https://opentelemetry.io/docs/instrumentation/python/)
- [Auto-Instrumentation](https://opentelemetry.io/docs/instrumentation/python/automatic/)
- [Supported Libraries](https://github.com/open-telemetry/opentelemetry-python-contrib/tree/main/instrumentation)
- [OBI (eBPF) Distributed Traces](https://opentelemetry.io/docs/zero-code/obi/distributed-traces/)
