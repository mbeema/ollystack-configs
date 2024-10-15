# Microservices Observability Demo

A self-contained demo showing end-to-end observability with OpenTelemetry. Includes three sample microservices with full instrumentation, an OTel Collector, and visualization backends (Jaeger, Prometheus, Grafana).

## What You Get

- **3 Sample Microservices** instrumented with OpenTelemetry:
  - `frontend` (port 8080) - HTTP server that takes user requests and calls the API
  - `api` (port 8081) - Business logic service that processes requests and delegates to workers
  - `worker` (port 8082) - Background processor that simulates async work
- **OTel Collector** receiving traces, metrics, and logs from all services
- **Jaeger** for distributed trace visualization
- **Prometheus** for metrics storage and querying
- **Grafana** for dashboards (pre-configured datasources)

## Quick Start

### 1. Start the Demo

```bash
cd examples/microservices-demo

# Start all services
docker compose up -d

# Watch the logs
docker compose logs -f
```

### 2. Generate Traffic

```bash
# Hit the frontend to generate traces
curl http://localhost:8080/
curl http://localhost:8080/api/users
curl http://localhost:8080/api/orders
curl http://localhost:8080/api/process

# Generate continuous traffic (run in background)
while true; do
  curl -s http://localhost:8080/api/users > /dev/null
  curl -s http://localhost:8080/api/orders > /dev/null
  curl -s http://localhost:8080/api/process > /dev/null
  sleep 2
done
```

### 3. Explore Telemetry

Open the following URLs in your browser:

| Tool | URL | What to See |
|------|-----|-------------|
| **Frontend App** | [http://localhost:8080](http://localhost:8080) | Sample application |
| **Jaeger** | [http://localhost:16686](http://localhost:16686) | Distributed traces |
| **Prometheus** | [http://localhost:9090](http://localhost:9090) | Metrics and queries |
| **Grafana** | [http://localhost:3000](http://localhost:3000) | Dashboards |

## What to Observe

### Distributed Traces (Jaeger)

1. Open [Jaeger UI](http://localhost:16686)
2. Select service `frontend` from the dropdown
3. Click "Find Traces"
4. Click on a trace to see the full request flow:
   ```
   frontend (HTTP GET /api/orders)
     -> api (HTTP GET /orders)
       -> worker (HTTP POST /process)
   ```
5. Observe:
   - **Span durations** - how long each service takes
   - **Span attributes** - HTTP method, status code, service metadata
   - **Propagated context** - trace ID flows across service boundaries
   - **Error spans** - highlighted in red when errors occur

### Metrics (Prometheus)

1. Open [Prometheus UI](http://localhost:9090)
2. Try these queries:

```promql
# Request rate per service
rate(http_server_request_duration_seconds_count[5m])

# Request latency (p95)
histogram_quantile(0.95, rate(http_server_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_server_request_duration_seconds_count{http_status_code=~"5.."}[5m])

# OTel Collector pipeline health
otelcol_receiver_accepted_spans

# Collector export success rate
rate(otelcol_exporter_sent_spans[5m])
```

### Logs

1. Check service logs via Docker:
   ```bash
   docker compose logs frontend
   docker compose logs api
   docker compose logs worker
   ```
2. Logs are also sent to the OTel Collector via OTLP
3. Each log line includes trace context (trace_id, span_id) for correlation

### Grafana Dashboards

1. Open [Grafana](http://localhost:3000) (no login required)
2. Navigate to Explore
3. Select the **Jaeger** datasource to query traces
4. Select the **Prometheus** datasource to query metrics
5. Correlate traces and metrics using the same time range

## Architecture

```
                    +----------+
                    |  User /  |
                    |  curl    |
                    +----+-----+
                         |
                    +----v-----+       +----------+       +----------+
                    | Frontend |------>|   API    |------>|  Worker  |
                    | :8080    |       |  :8081   |       |  :8082   |
                    +----+-----+       +----+-----+       +----+-----+
                         |                  |                  |
                         |    OTLP/HTTP     |    OTLP/HTTP     |
                         +-------+----------+----------+-------+
                                 |                     |
                           +-----v---------------------v-----+
                           |     OTel Collector               |
                           |     :4317 (gRPC) :4318 (HTTP)    |
                           +--+----------+----------+---------+
                              |          |          |
                    +---------v--+  +----v-----+  +-v----------+
                    |  Jaeger    |  | Prometheus|  | Debug logs |
                    |  :16686    |  |  :9090    |  | (stdout)   |
                    +------+-----+  +----+-----+  +------------+
                           |             |
                    +------v-------------v-----+
                    |        Grafana            |
                    |        :3000              |
                    +---------------------------+
```

## Configuration Files

| File | Description |
|------|-------------|
| `docker-compose.yaml` | Docker Compose stack definition |
| `collector-config.yaml` | OTel Collector configuration (created on first run) |
| `prometheus.yaml` | Prometheus scrape configuration |
| `grafana-datasources.yaml` | Grafana auto-provisioned datasources |
| `services/frontend.py` | Frontend microservice source |
| `services/api.py` | API microservice source |
| `services/worker.py` | Worker microservice source |

## Cleanup

```bash
# Stop all services
docker compose down

# Stop and remove all data
docker compose down -v

# Remove built images
docker compose down -v --rmi local
```

## Customization

### Adding Your Own Service

1. Add your service to `docker-compose.yaml`
2. Set the OTel environment variables:
   ```yaml
   environment:
     - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
     - OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
     - OTEL_SERVICE_NAME=my-service
   ```
3. Install the OpenTelemetry SDK for your language
4. Restart: `docker compose up -d`

### Changing Backends

Edit `collector-config.yaml` to add or change exporters. The collector supports 50+ backends out of the box with the contrib distribution.
