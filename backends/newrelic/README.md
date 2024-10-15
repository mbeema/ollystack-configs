# New Relic Backend

## Overview

This configuration sends OpenTelemetry data to New Relic using the OTLP HTTP protocol. New Relic natively supports OTLP ingestion for traces, metrics, and logs without requiring any proprietary agents or exporters.

## Prerequisites

1. A New Relic account (free tier available at https://newrelic.com/signup)
2. A New Relic Ingest License key (not a User key)

## Getting Your Credentials

1. Log in to https://one.newrelic.com
2. Click on your user icon in the bottom-left corner
3. Select **API Keys**
4. Find or create an **INGEST - LICENSE** key type
5. Copy the key value (starts with a region prefix, e.g., `eu01xx...` or has no prefix for US)

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `NEW_RELIC_API_KEY` | New Relic Ingest License key | `your-license-key-nral` |

### OTLP Endpoints by Region

| Region | Endpoint |
|---|---|
| US | `https://otlp.nr-data.net:4318` |
| EU | `https://otlp.eu01.nr-data.net:4318` |

## Usage

1. Set the required environment variable:

```bash
export NEW_RELIC_API_KEY="your-license-key-nral"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to New Relic One > APM & Services > Distributed Tracing
- **Metrics**: Navigate to New Relic One > Query Your Data > run `FROM Metric SELECT *`
- **Logs**: Navigate to New Relic One > Logs

## Notes

- New Relic uses standard OTLP/HTTP on port 4318 -- no proprietary exporter needed
- The `Api-Key` header is used for authentication (Ingest License key)
- Data is available in New Relic One within seconds of ingestion
- New Relic automatically maps OTLP resource attributes to entity metadata
- For EU accounts, update the endpoint to `https://otlp.eu01.nr-data.net:4318`
- Compression (gzip) is recommended for reduced bandwidth usage
