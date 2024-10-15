# Elastic Backend

## Overview

This configuration sends OpenTelemetry data to Elastic APM Server or Elasticsearch. Elastic supports native OTLP ingestion via the APM Server, which stores data in Elasticsearch for visualization in Kibana.

## Prerequisites

1. An Elastic Cloud deployment or self-hosted Elastic Stack (Elasticsearch + Kibana + APM Server)
2. APM Server URL and a secret token or API key
3. Elastic Stack version 7.14+ (for native OTLP support)

## Getting Your Credentials

### Elastic Cloud

1. Log in to https://cloud.elastic.co
2. Navigate to your deployment
3. Go to **APM & Fleet** > **APM**
4. Note the **APM Server URL** (e.g., `https://your-deployment.apm.us-east-1.aws.cloud.es.io:443`)
5. Copy the **Secret Token** or create an API key under **Kibana** > **Fleet** > **Agent policies**

### Self-Hosted

1. The APM Server OTLP endpoint is available at `http://<apm-server-host>:8200`
2. The secret token is configured in `apm-server.yml` under `apm-server.auth.secret_token`

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `ELASTIC_APM_ENDPOINT` | APM Server OTLP endpoint URL | `https://your-deployment.apm.us-east-1.aws.cloud.es.io:443` |
| `ELASTIC_APM_SECRET_TOKEN` | APM Server secret token or API key | `your-secret-token` |

## Usage

1. Set the required environment variables:

```bash
export ELASTIC_APM_ENDPOINT="https://your-deployment.apm.us-east-1.aws.cloud.es.io:443"
export ELASTIC_APM_SECRET_TOKEN="your-secret-token"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Kibana > Observability > APM > Traces
- **Metrics**: Navigate to Kibana > Observability > Infrastructure > Metrics Explorer
- **Logs**: Navigate to Kibana > Observability > Logs > Stream

## Notes

- Elastic APM Server natively supports OTLP/gRPC on port 8200
- For Elastic Cloud, TLS is enabled by default
- The APM Server handles data transformation and indexing into Elasticsearch
- Index Lifecycle Management (ILM) policies manage data retention automatically
- Resource attributes are mapped to Elastic APM metadata fields
