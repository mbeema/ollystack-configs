# Dynatrace Backend

## Overview

This configuration sends OpenTelemetry data to Dynatrace using the OTLP HTTP protocol. Dynatrace supports native OTLP ingestion for traces, metrics, and logs through its ActiveGate or directly via the SaaS environment API.

## Prerequisites

1. A Dynatrace environment (SaaS or Managed)
2. A Dynatrace API token with the appropriate scopes
3. An ActiveGate with the OTLP endpoint enabled (for Managed) or direct SaaS API access

## Getting Your Credentials

### Dynatrace SaaS

1. Log in to your Dynatrace environment
2. Navigate to **Settings** > **Integration** > **API tokens** (or **Access Tokens**)
3. Click **Generate new token**
4. Grant the following scopes:
   - `openTelemetryTrace.ingest` (for traces)
   - `metrics.ingest` (for metrics)
   - `logs.ingest` (for logs)
5. Copy the generated token

### OTLP Endpoint

- **SaaS**: `https://{your-environment-id}.live.dynatrace.com/api/v2/otlp`
- **Managed (via ActiveGate)**: `https://{your-activegate-host}:9999/e/{your-environment-id}/api/v2/otlp`

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `DYNATRACE_OTLP_ENDPOINT` | Dynatrace OTLP API endpoint | `https://abc12345.live.dynatrace.com/api/v2/otlp` |
| `DYNATRACE_API_TOKEN` | Dynatrace API token with ingest scopes | `dt0c01.XXX.YYY` |

## Usage

1. Set the required environment variables:

```bash
export DYNATRACE_OTLP_ENDPOINT="https://abc12345.live.dynatrace.com/api/v2/otlp"
export DYNATRACE_API_TOKEN="dt0c01.XXX.YYY"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Dynatrace > Applications & Microservices > Distributed Traces
- **Metrics**: Navigate to Dynatrace > Observe and Explore > Metrics
- **Logs**: Navigate to Dynatrace > Observe and Explore > Logs

## Notes

- Dynatrace enriches OTLP data with its own AI-powered topology detection
- The API token must have all three ingest scopes for full observability
- Dynatrace automatically maps OTLP resource attributes to Dynatrace entities
- For Managed deployments, ensure the ActiveGate has OTLP ingestion enabled
- Rate limits and data retention depend on your Dynatrace license
