# Datadog Backend

## Overview

This configuration sends OpenTelemetry data to Datadog using the native Datadog exporter for the OpenTelemetry Collector. Datadog supports traces (APM), metrics, and logs ingestion via OpenTelemetry.

## Prerequisites

1. A Datadog account (trial available at https://www.datadoghq.com/)
2. A Datadog API key
3. The OpenTelemetry Collector Contrib distribution (includes the Datadog exporter)

## Getting Your Credentials

1. Log in to your Datadog account
2. Navigate to **Organization Settings** > **API Keys**
3. Click **New Key** to create a new API key
4. Copy the API key value

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `DD_API_KEY` | Datadog API key | `abcdef1234567890abcdef1234567890` |
| `DD_SITE` | Datadog site (defaults to `datadoghq.com`) | `datadoghq.com`, `datadoghq.eu`, `us5.datadoghq.com` |

### Datadog Sites

| Site | Region |
|---|---|
| `datadoghq.com` | US1 (default) |
| `us3.datadoghq.com` | US3 |
| `us5.datadoghq.com` | US5 |
| `datadoghq.eu` | EU1 |
| `ap1.datadoghq.com` | AP1 |

## Usage

1. Set the required environment variables:

```bash
export DD_API_KEY="your-datadog-api-key"
export DD_SITE="datadoghq.com"  # optional, defaults to datadoghq.com
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to APM > Traces in Datadog
- **Metrics**: Navigate to Metrics > Explorer in Datadog
- **Logs**: Navigate to Logs > Search in Datadog

## Notes

- The Datadog exporter is only available in the OpenTelemetry Collector Contrib distribution
- Host metadata and tags are automatically collected
- Trace sampling can be configured in the Datadog exporter or via Collector processors
- Resource attributes are mapped to Datadog tags automatically
