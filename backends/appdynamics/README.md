# AppDynamics Cloud Observability Backend

## Overview

This configuration sends OpenTelemetry data to Cisco AppDynamics Cloud Observability using the OTLP HTTP protocol. AppDynamics Cloud provides native OTLP ingestion for traces, metrics, and logs, enabling full-stack observability with AI-driven insights.

## Prerequisites

1. A Cisco AppDynamics Cloud tenant
2. A client token (service principal) with OTLP ingest permissions
3. Access to the AppDynamics Cloud Observability OTLP endpoint

## Getting Your Credentials

### AppDynamics Cloud

1. Log in to the AppDynamics Cloud portal
2. Navigate to **Administration** > **API Clients** (or **Service Principals**)
3. Create a new API client or service principal
4. Assign the following roles/permissions:
   - `OTLP Ingest` (for traces, metrics, and logs)
5. Generate and copy the client token

### OTLP Endpoint

- **AppDynamics Cloud**: `https://<tenant>.observe.appdynamics.com/data/v1`

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `APPDYNAMICS_OTLP_ENDPOINT` | AppDynamics Cloud OTLP endpoint | `https://mytenant.observe.appdynamics.com/data/v1` |
| `APPDYNAMICS_CLIENT_TOKEN` | Bearer token for authentication | `eyJhbGciOi...` |

## Usage

1. Set the required environment variables:

```bash
export APPDYNAMICS_OTLP_ENDPOINT="https://mytenant.observe.appdynamics.com/data/v1"
export APPDYNAMICS_CLIENT_TOKEN="your-client-token"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to AppDynamics Cloud > Observe > Traces
- **Metrics**: Navigate to AppDynamics Cloud > Observe > Metrics Explorer
- **Logs**: Navigate to AppDynamics Cloud > Observe > Logs

## Notes

- AppDynamics Cloud Observability is the cloud-native successor to traditional AppDynamics
- The platform provides automatic service topology mapping from OTLP data
- Ensure your client token has not expired; tokens may need periodic rotation
- Data ingestion rates and retention depend on your AppDynamics Cloud license tier
- For hybrid deployments, consult Cisco documentation on connecting on-premises agents
