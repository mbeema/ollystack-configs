# =============================================================================
# Multi-stage Dockerfile for Java Application with OpenTelemetry Auto-Instrumentation
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build the Java application
# -----------------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /app

# Copy dependency descriptors first for better layer caching
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests -B

# -----------------------------------------------------------------------------
# Stage 2: Download OpenTelemetry Java Agent
# -----------------------------------------------------------------------------
FROM curlimages/curl:latest AS otel-agent

ARG OTEL_AGENT_VERSION=2.11.0

RUN curl -L -o /tmp/opentelemetry-javaagent.jar \
    https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar

# -----------------------------------------------------------------------------
# Stage 3: Runtime
# -----------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-alpine

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create directory for OTel agent
RUN mkdir -p /opt/otel

# Copy the OTel Java agent from the download stage
COPY --from=otel-agent /tmp/opentelemetry-javaagent.jar /opt/otel/opentelemetry-javaagent.jar

# Copy the built application from the build stage
COPY --from=build /app/target/*.jar /app/app.jar

# ---------------------------------------------------------------------------
# OpenTelemetry Configuration via Environment Variables
# ---------------------------------------------------------------------------

# Attach the OTel Java agent to every JVM process started in this container
ENV JAVA_TOOL_OPTIONS="-javaagent:/opt/otel/opentelemetry-javaagent.jar"

# Service identification
ENV OTEL_SERVICE_NAME="my-java-service"

# OTLP exporter endpoint (adjust to your collector address)
ENV OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"

# Protocol: grpc (default) or http/protobuf
ENV OTEL_EXPORTER_OTLP_PROTOCOL="grpc"

# Resource attributes for additional metadata
ENV OTEL_RESOURCE_ATTRIBUTES="deployment.environment=production,service.namespace=default,service.version=1.0.0"

# Exporters for each signal
ENV OTEL_TRACES_EXPORTER="otlp"
ENV OTEL_METRICS_EXPORTER="otlp"
ENV OTEL_LOGS_EXPORTER="otlp"

# Propagation format
ENV OTEL_PROPAGATORS="tracecontext,baggage"

# Sampling (default: always_on; use parentbased_traceidratio for production)
ENV OTEL_TRACES_SAMPLER="parentbased_always_on"

# ---------------------------------------------------------------------------

WORKDIR /app

# Switch to non-root user
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=15s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
