# IBM Instana Backend

## Overview

This configuration sends OpenTelemetry data to IBM Instana using the OTLP HTTP protocol. Instana supports OTLP ingestion either directly via the SaaS backend or through a locally deployed Instana agent, providing automatic discovery and AI-powered incident management.

## Prerequisites

1. An IBM Instana tenant (SaaS or on-premises)
2. An Instana agent key
3. Access to the Instana OTLP endpoint (SaaS) or a local Instana agent with OTLP enabled

## Getting Your Credentials

### Instana SaaS

1. Log in to your Instana dashboard
2. Navigate to **Settings** > **Agents** > **Agent Keys**
3. Copy your agent key

### OTLP Endpoint

- **SaaS (direct)**: `https://<tenant>-<unit>.instana.io`
- **Local agent**: `http://localhost:4318` (default OTLP HTTP port on the Instana agent)
- **Custom agent**: `http://<agent-host>:4318`

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `INSTANA_OTLP_ENDPOINT` | Instana OTLP endpoint | `https://mytenant-myunit.instana.io` or `http://localhost:4318` |
| `INSTANA_AGENT_KEY` | Instana agent key | `abc123def456` |

## Usage

1. Set the required environment variables:

```bash
export INSTANA_OTLP_ENDPOINT="https://mytenant-myunit.instana.io"
export INSTANA_AGENT_KEY="your-agent-key"
```

Or for local agent mode:

```bash
export INSTANA_OTLP_ENDPOINT="http://localhost:4318"
export INSTANA_AGENT_KEY="your-agent-key"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Instana > Analytics > Traces
- **Metrics**: Navigate to Instana > Infrastructure > Custom Metrics
- **Logs**: Navigate to Instana > Analytics > Logs

## Notes

- When using a local Instana agent, set `tls.insecure: true` in the exporter config
- Instana automatically correlates OTLP traces with its own infrastructure discovery
- The agent key is the same key used for Instana host agent installations
- Instana supports both OTLP/HTTP and OTLP/gRPC; this config uses HTTP for broader compatibility
- For on-premises Instana, the endpoint will be your self-hosted backend URL
- Rate limits depend on your Instana license and tenant configuration
