# =============================================================================
# Dockerfile for Node.js Application with OpenTelemetry Auto-Instrumentation
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Install Dependencies
# -----------------------------------------------------------------------------
FROM node:22-alpine AS builder

WORKDIR /app

# Copy dependency descriptors first for better layer caching
COPY package.json package-lock.json* ./

# Install production dependencies only
RUN npm ci --omit=dev

# Copy application source
COPY . .

# -----------------------------------------------------------------------------
# Stage 2: Runtime
# -----------------------------------------------------------------------------
FROM node:22-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy node_modules and app from builder
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app .

# ---------------------------------------------------------------------------
# OpenTelemetry Configuration
# ---------------------------------------------------------------------------

# Load the tracing setup BEFORE the application code.
# This ensures all require() calls are intercepted for auto-instrumentation.
ENV NODE_OPTIONS="--require ./tracing.js"

# Service identification
ENV OTEL_SERVICE_NAME="my-node-service"

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

# ---------------------------------------------------------------------------

# Switch to non-root user
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/health || exit 1

# Use dumb-init to handle signals properly (PID 1 problem)
ENTRYPOINT ["dumb-init", "--"]

CMD ["node", "app.js"]
