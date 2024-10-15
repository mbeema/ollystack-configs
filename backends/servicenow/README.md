# ServiceNow Cloud Observability (Lightstep) Backend

## Overview

This configuration sends OpenTelemetry data to ServiceNow Cloud Observability (formerly Lightstep) using the OTLP HTTP protocol. ServiceNow Cloud Observability was built natively on OpenTelemetry and provides full support for OTLP ingestion of traces, metrics, and logs.

## Prerequisites

1. A ServiceNow Cloud Observability (Lightstep) account
2. A project with an access token
3. Access to the OTLP ingest endpoint

## Getting Your Credentials

### ServiceNow Cloud Observability

1. Log in to [app.lightstep.com](https://app.lightstep.com) or your ServiceNow Cloud Observability instance
2. Navigate to **Settings** > **Access Tokens**
3. Create a new access token or copy an existing one
4. Note the project name associated with the token

### OTLP Endpoint

- **Default**: `https://ingest.lightstep.com`
- **EU region**: `https://ingest.eu.lightstep.com` (if applicable)

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `SERVICENOW_OTLP_ENDPOINT` | ServiceNow Cloud Observability ingest endpoint | `https://ingest.lightstep.com` |
| `LIGHTSTEP_ACCESS_TOKEN` | Lightstep/ServiceNow access token | `abc123xyz789` |

## Usage

1. Set the required environment variables:

```bash
export SERVICENOW_OTLP_ENDPOINT="https://ingest.lightstep.com"
export LIGHTSTEP_ACCESS_TOKEN="your-access-token"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Cloud Observability > Explorer > Traces
- **Metrics**: Navigate to Cloud Observability > Notebooks or Dashboards
- **Logs**: Navigate to Cloud Observability > Explorer > Logs

## Notes

- ServiceNow Cloud Observability was one of the founding contributors to OpenTelemetry
- The platform is built natively on OpenTelemetry data formats, ensuring excellent compatibility
- Access tokens are scoped to projects; use separate tokens for different environments
- The service supports both OTLP/HTTP and OTLP/gRPC protocols
- Microsatellites (on-premises collectors) can also be used as intermediary endpoints
- Data retention and rate limits depend on your ServiceNow Cloud Observability plan
