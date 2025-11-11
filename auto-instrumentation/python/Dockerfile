# =============================================================================
# Dockerfile for Python Application with OpenTelemetry Auto-Instrumentation
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build / Install Dependencies
# -----------------------------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies for packages with C extensions (psycopg2, grpcio)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Copy application source
COPY . .

# Run the bootstrap tool to detect and install any missing instrumentation
# packages based on the libraries present in requirements.txt
RUN pip install --no-cache-dir --prefix=/install opentelemetry-instrumentation && \
    PATH=/install/bin:$PATH \
    PYTHONPATH=/install/lib/python3.12/site-packages \
    opentelemetry-bootstrap -a install --prefix=/install || true

# -----------------------------------------------------------------------------
# Stage 2: Runtime
# -----------------------------------------------------------------------------
FROM python:3.12-slim

# Install runtime-only dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY --from=builder /app /app

# ---------------------------------------------------------------------------
# OpenTelemetry Configuration
# ---------------------------------------------------------------------------

# Service identification
ENV OTEL_SERVICE_NAME="my-python-service"

# OTLP exporter endpoint
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"
ENV OTEL_EXPORTER_OTLP_PROTOCOL="grpc"

# Resource attributes
ENV OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.namespace=default,service.version=1.0.0"

# Exporters
ENV OTEL_TRACES_EXPORTER="otlp"
ENV OTEL_METRICS_EXPORTER="otlp"
ENV OTEL_LOGS_EXPORTER="otlp"

# Propagation
ENV OTEL_PROPAGATORS="tracecontext,baggage"

# Sampling
ENV OTEL_TRACES_SAMPLER="parentbased_always_on"

# Log correlation -- injects trace_id and span_id into Python log records
ENV OTEL_PYTHON_LOG_CORRELATION="true"

# ---------------------------------------------------------------------------

# Switch to non-root user
USER appuser

EXPOSE 8000

# Use opentelemetry-instrument as the entrypoint wrapper.
# It automatically instruments all detected libraries at startup.
ENTRYPOINT ["opentelemetry-instrument"]

# Default command -- override in docker-compose or K8s as needed
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000", "--workers", "4", "--timeout", "120"]
