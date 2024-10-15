# Splunk Backend

## Overview

This configuration sends OpenTelemetry data to Splunk. It supports two targets:

1. **Splunk Observability Cloud (O11y)** - Managed observability platform (formerly SignalFx) via OTLP
2. **Splunk Enterprise/Cloud** - Log and event platform via HTTP Event Collector (HEC)

## Prerequisites

### Splunk Observability Cloud
1. A Splunk Observability Cloud account (https://www.splunk.com/en_us/products/observability.html)
2. An ingest access token

### Splunk Enterprise/Cloud (HEC)
1. A Splunk Enterprise or Splunk Cloud instance
2. HTTP Event Collector (HEC) enabled with a valid token

## Getting Your Credentials

### Splunk Observability Cloud

1. Log in to Splunk Observability Cloud
2. Navigate to **Settings** > **Access Tokens**
3. Create a new token or use an existing one with **Ingest** authorization scope
4. Note your realm (e.g., `us0`, `us1`, `eu0`)

### Splunk HEC

1. Log in to Splunk Web
2. Navigate to **Settings** > **Data Inputs** > **HTTP Event Collector**
3. Click **New Token** and follow the wizard
4. Note the token value and your HEC endpoint URL

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `SPLUNK_HEC_ENDPOINT` | Splunk HEC endpoint URL | `https://splunk.example.com:8088/services/collector` |
| `SPLUNK_HEC_TOKEN` | Splunk HEC token | `your-hec-token` |
| `SPLUNK_HEC_SOURCE` | Event source identifier | `otel` |
| `SPLUNK_HEC_SOURCETYPE` | Event sourcetype | `otel:metrics` |
| `SPLUNK_HEC_INDEX` | Target Splunk index | `otel_events` |
| `SPLUNK_O11Y_ACCESS_TOKEN` | Splunk O11y ingest access token | `your-access-token` |
| `SPLUNK_O11Y_REALM` | Splunk O11y realm | `us0` |

## Usage

1. Set the required environment variables:

```bash
# For Splunk HEC
export SPLUNK_HEC_ENDPOINT="https://splunk.example.com:8088/services/collector"
export SPLUNK_HEC_TOKEN="your-hec-token"

# For Splunk Observability Cloud
export SPLUNK_O11Y_ACCESS_TOKEN="your-access-token"
export SPLUNK_O11Y_REALM="us0"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

### Splunk Observability Cloud
- **Traces**: Navigate to APM > Traces
- **Metrics**: Navigate to Infrastructure > Metrics
- **Logs**: Navigate to Log Observer

### Splunk Enterprise/Cloud
- Run a search: `index=otel_events sourcetype=otel:*`

## Notes

- The Splunk HEC exporter requires the OpenTelemetry Collector Contrib distribution
- HEC supports batching for improved throughput
- Splunk O11y uses standard OTLP with an access token header
- Ensure the HEC endpoint has a valid TLS certificate or set `insecure_skip_verify: true` for testing
