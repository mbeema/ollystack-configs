# Axiom Backend

## Overview

This configuration sends OpenTelemetry data to Axiom using the OTLP HTTP protocol. Axiom provides native OTLP ingestion for traces, metrics, and logs with unlimited data retention and powerful query capabilities. Separate exporter instances are used so you can route different signals to different datasets if needed.

## Prerequisites

1. An Axiom account (cloud or self-hosted)
2. An API token with ingest permissions
3. A dataset created to receive the telemetry data

## Getting Your Credentials

### Axiom Cloud

1. Log in to [app.axiom.co](https://app.axiom.co)
2. Navigate to **Settings** > **API Tokens**
3. Click **New API Token**
4. Grant the `Ingest` permission for your target dataset(s)
5. Copy the generated token

### Create a Dataset

1. Navigate to **Datasets** in the Axiom UI
2. Click **New Dataset**
3. Name your dataset (e.g., `otel-traces`, `otel-metrics`, `otel-logs`, or a single `otel-data`)
4. You can use one dataset for all signals or separate datasets per signal

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `AXIOM_API_TOKEN` | Axiom API token with ingest permissions | `xaat-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AXIOM_DATASET` | Axiom dataset name | `otel-data` |

## Usage

1. Set the required environment variables:

```bash
export AXIOM_API_TOKEN="xaat-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export AXIOM_DATASET="otel-data"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

### Using Separate Datasets per Signal

To send different signals to different datasets, override the `X-Axiom-Dataset` header per exporter instance in your collector configuration, or create separate environment variables for each signal type.

## Verifying Data

- **Traces**: Navigate to Axiom > Datasets > your dataset > Stream or Query
- **Metrics**: Navigate to Axiom > Datasets > your dataset > Query
- **Logs**: Navigate to Axiom > Datasets > your dataset > Stream

## Notes

- Axiom organizes all data into datasets; each dataset can hold any type of telemetry
- The `X-Axiom-Dataset` header determines which dataset receives the data
- For separate datasets per signal, create multiple exporter instances with different dataset headers
- Axiom provides zero-config dashboards for common OpenTelemetry data
- API tokens can be scoped to specific datasets for security
- Axiom supports both OTLP/HTTP and OTLP/gRPC protocols
- Data retention is unlimited on all Axiom plans
