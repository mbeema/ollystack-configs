# Chronosphere Backend

## Overview

This configuration sends OpenTelemetry data to Chronosphere (now part of Palo Alto Networks). Traces are sent via OTLP/HTTP and metrics are sent via Prometheus Remote Write, matching Chronosphere's preferred ingestion protocols. Chronosphere specializes in high-cardinality metrics management and distributed tracing.

## Prerequisites

1. A Chronosphere account (or Palo Alto Networks Cloud Observability)
2. A Chronosphere API token with ingest permissions
3. Access to both the OTLP and Prometheus Remote Write endpoints

## Getting Your Credentials

### Chronosphere

1. Log in to your Chronosphere tenant
2. Navigate to **Administration** > **API Tokens**
3. Create a new API token with the following permissions:
   - `Traces Ingest` (for traces)
   - `Metrics Ingest` (for metrics via remote write)
4. Copy the generated token

### Endpoints

- **OTLP (traces)**: Provided by your Chronosphere tenant, typically `https://<company>.chronosphere.io/api/v1/otlp`
- **Remote Write (metrics)**: Provided by your Chronosphere tenant, typically `https://<company>.chronosphere.io/api/v1/remote/write`

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `CHRONOSPHERE_OTLP_ENDPOINT` | Chronosphere OTLP endpoint for traces | `https://mycompany.chronosphere.io/api/v1/otlp` |
| `CHRONOSPHERE_REMOTE_WRITE_ENDPOINT` | Chronosphere Remote Write endpoint for metrics | `https://mycompany.chronosphere.io/api/v1/remote/write` |
| `CHRONOSPHERE_API_TOKEN` | Chronosphere API token | `chrono_xxxxxxxxxxxx` |

## Usage

1. Set the required environment variables:

```bash
export CHRONOSPHERE_OTLP_ENDPOINT="https://mycompany.chronosphere.io/api/v1/otlp"
export CHRONOSPHERE_REMOTE_WRITE_ENDPOINT="https://mycompany.chronosphere.io/api/v1/remote/write"
export CHRONOSPHERE_API_TOKEN="your-api-token"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Chronosphere > Tracing > Trace Search
- **Metrics**: Navigate to Chronosphere > Metrics Explorer or Dashboards

## Notes

- Chronosphere uses Prometheus Remote Write as the primary metrics ingestion protocol
- Traces are ingested via OTLP, which Chronosphere processes and stores natively
- Chronosphere provides advanced metrics aggregation and cardinality management
- Control plane features (quotas, drop rules, aggregation rules) can reduce costs
- Chronosphere is now part of Palo Alto Networks; branding and endpoints may evolve
- Logs support may be available depending on your plan; consult Chronosphere documentation
