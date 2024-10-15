# Self-Hosted Backend

## Overview

This directory contains configurations for self-hosted observability backends:

1. **Jaeger + Prometheus** - Open-source tracing (Jaeger) and metrics (Prometheus) stack
2. **SigNoz** - All-in-one open-source observability platform (traces, metrics, logs)

## Option 1: Jaeger + Prometheus

### Components

- **Jaeger** - Distributed tracing backend (receives OTLP/gRPC traces)
- **Prometheus** - Metrics backend (receives metrics via Remote Write)

### Prerequisites

- Jaeger v1.35+ (supports native OTLP ingestion) or Jaeger v2
- Prometheus v2.40+ (supports Remote Write receiver)
- Docker or Kubernetes for deployment

### Quick Start with Docker

```bash
# Start Jaeger with OTLP gRPC enabled
docker run -d --name jaeger \
  -p 4317:4317 \
  -p 16686:16686 \
  jaegertracing/all-in-one:latest

# Start Prometheus with remote write receiver
docker run -d --name prometheus \
  -p 9090:9090 \
  -v ./prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest \
  --enable-feature=remote-write-receiver \
  --config.file=/etc/prometheus/prometheus.yml
```

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `JAEGER_ENDPOINT` | Jaeger OTLP gRPC endpoint | `jaeger:4317` |
| `PROMETHEUS_ENDPOINT` | Prometheus Remote Write endpoint | `http://prometheus:9090/api/v1/write` |

### Verifying Data

- **Traces**: Open Jaeger UI at `http://localhost:16686`
- **Metrics**: Open Prometheus UI at `http://localhost:9090`

---

## Option 2: SigNoz

### Overview

SigNoz is an open-source, full-stack observability platform that supports traces, metrics, and logs. It uses ClickHouse as its storage backend and natively supports OTLP ingestion.

### Prerequisites

- SigNoz v0.20+ (installed via Docker Compose or Helm)
- Docker Compose or Kubernetes cluster

### Quick Start with Docker Compose

```bash
git clone https://github.com/SigNoz/signoz.git
cd signoz/deploy
docker compose -f docker/clickhouse-setup/docker-compose.yaml up -d
```

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `SIGNOZ_ENDPOINT` | SigNoz OTLP gRPC endpoint | `signoz-otel-collector:4317` |

### Verifying Data

- Open SigNoz UI at `http://localhost:3301`
- Navigate to Traces, Metrics, or Logs tabs

## Notes

- Self-hosted backends give you full control over data storage and retention
- Consider storage requirements when planning capacity
- Jaeger supports multiple storage backends (Elasticsearch, Cassandra, Badger, ClickHouse)
- Prometheus data retention is configured via `--storage.tsdb.retention.time`
- SigNoz uses ClickHouse which is optimized for time-series and columnar data
- For production use, deploy with persistent storage and appropriate resource limits
