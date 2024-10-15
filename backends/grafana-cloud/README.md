# Grafana Cloud Backend

## Overview

This configuration sends OpenTelemetry data (traces, metrics, and logs) to Grafana Cloud using the OTLP HTTP protocol. Grafana Cloud provides managed Tempo (traces), Mimir (metrics), and Loki (logs) backends.

## Prerequisites

1. A Grafana Cloud account (free tier available at https://grafana.com/products/cloud/)
2. An OTLP endpoint and API credentials

## Getting Your Credentials

1. Log in to your Grafana Cloud portal at https://grafana.com
2. Navigate to **My Account** > **Grafana Cloud** stack
3. Click **Details** on your Grafana Cloud stack
4. Under the **OpenTelemetry** section, click **Configure**
5. Note the following values:
   - **OTLP Endpoint** (e.g., `otlp-gateway-prod-us-east-0.grafana.net`)
   - **Instance ID** (numeric)
   - **API Key** (generate one with `MetricsPublisher` role)

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `GRAFANA_OTLP_ENDPOINT` | OTLP gateway endpoint (host only) | `otlp-gateway-prod-us-east-0.grafana.net` |
| `GRAFANA_INSTANCE_ID` | Your Grafana Cloud instance ID | `123456` |
| `GRAFANA_API_KEY` | API key with MetricsPublisher role | `glc_eyJ...` |

## Generating the Authorization Header

Grafana Cloud OTLP uses HTTP Basic authentication. The header value is:

```
Basic base64(instanceId:apiKey)
```

Generate it with:

```bash
echo -n "${GRAFANA_INSTANCE_ID}:${GRAFANA_API_KEY}" | base64
```

## Usage

1. Set the required environment variables:

```bash
export GRAFANA_OTLP_ENDPOINT="otlp-gateway-prod-us-east-0.grafana.net"
export GRAFANA_INSTANCE_ID="123456"
export GRAFANA_API_KEY="glc_eyJ..."
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to your Grafana instance > Explore > Select Tempo data source
- **Metrics**: Navigate to Explore > Select Mimir/Prometheus data source
- **Logs**: Navigate to Explore > Select Loki data source

## Notes

- The OTLP endpoint supports both gRPC (port 4317) and HTTP (port 4318)
- This configuration uses OTLP/HTTP for broader compatibility
- Rate limits apply based on your Grafana Cloud plan
- TLS is required for all connections to Grafana Cloud
