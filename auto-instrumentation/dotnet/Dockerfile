# =============================================================================
# Dockerfile for .NET Application with OpenTelemetry Auto-Instrumentation
# =============================================================================
# Uses the CLR Profiler-based approach for zero-code instrumentation.
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build the .NET application
# -----------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

WORKDIR /src

# Copy project file(s) and restore dependencies
COPY *.csproj ./
RUN dotnet restore

# Copy source and publish
COPY . .
RUN dotnet publish -c Release -o /app/publish --no-restore

# -----------------------------------------------------------------------------
# Stage 2: Download OpenTelemetry .NET Auto-Instrumentation
# -----------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/runtime-deps:9.0 AS otel-installer

ARG OTEL_DOTNET_AUTO_VERSION=1.9.0

# Download and extract the auto-instrumentation package
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
    && mkdir -p /opt/otel-dotnet \
    && curl -sSfL "https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation/releases/download/v${OTEL_DOTNET_AUTO_VERSION}/opentelemetry-dotnet-instrumentation-linux-glibc-x64.zip" \
       -o /tmp/otel-dotnet.zip \
    && unzip /tmp/otel-dotnet.zip -d /opt/otel-dotnet \
    && rm /tmp/otel-dotnet.zip \
    && apt-get purge -y curl unzip && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Stage 3: Runtime
# -----------------------------------------------------------------------------
FROM mcr.microsoft.com/dotnet/aspnet:9.0

# Create non-root user
RUN groupadd -r appgroup && useradd -r -g appgroup -d /app -s /sbin/nologin appuser

WORKDIR /app

# Copy the published application
COPY --from=build /app/publish .

# Copy OTel auto-instrumentation files
COPY --from=otel-installer /opt/otel-dotnet /opt/otel-dotnet

# ---------------------------------------------------------------------------
# CLR Profiler Environment Variables (enables zero-code instrumentation)
# ---------------------------------------------------------------------------

# Enable the CLR Profiler
ENV CORECLR_ENABLE_PROFILING=1

# Profiler CLSID for OpenTelemetry .NET Auto-Instrumentation
ENV CORECLR_PROFILER="{918728DD-259F-4A6A-AC2B-B85E1B658318}"

# Path to the native profiler library
ENV CORECLR_PROFILER_PATH="/opt/otel-dotnet/linux-x64/OpenTelemetry.AutoInstrumentation.Native.so"

# .NET hosting hooks for managed auto-instrumentation
ENV DOTNET_ADDITIONAL_DEPS="/opt/otel-dotnet/AdditionalDeps"
ENV DOTNET_SHARED_STORE="/opt/otel-dotnet/store"
ENV DOTNET_STARTUP_HOOKS="/opt/otel-dotnet/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll"

# ---------------------------------------------------------------------------
# OpenTelemetry Configuration
# ---------------------------------------------------------------------------

# Service identification
ENV OTEL_SERVICE_NAME="my-dotnet-service"

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

# Enable log export
ENV OTEL_DOTNET_AUTO_LOGS_ENABLED="true"

# ---------------------------------------------------------------------------

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl --fail http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "MyApp.dll"]
