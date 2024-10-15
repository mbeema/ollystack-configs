# OllyStack Golden Configs

Pre-assembled, production-ready OpenTelemetry Collector configurations for common enterprise scenarios. Each config is a single, self-contained YAML file ready to deploy.

## Available Configs

| Config | Platform | Backend | Environment | Cost Reduction |
|--------|----------|---------|-------------|----------------|
| `aws-datadog-production.yaml` | AWS EKS | Datadog | Production | 60-80% |
| `aws-grafana-cloud-staging.yaml` | AWS EKS | Grafana Cloud | Staging | 30-50% |
| `azure-aks-elastic-production.yaml` | Azure AKS | Elastic | Production | 60-80% |
| `azure-aks-dynatrace-production.yaml` | Azure AKS | Dynatrace | Production | 60-80% |
| `gcp-gke-native-production.yaml` | GCP GKE | GCP Cloud Ops | Production | 60-80% |
| `k8s-grafana-lgtm-dev.yaml` | Generic K8s | Grafana LGTM (self-hosted) | Development | ~0% |
| `k8s-signoz-staging.yaml` | Generic K8s | SigNoz (self-hosted) | Staging | 30-50% |
| `onprem-splunk-production.yaml` | On-prem VMs | Splunk | Production | 60-80% |
| `aws-newrelic-production.yaml` | AWS EKS | New Relic | Production | 60-80% |
| `multi-backend-production.yaml` | Generic K8s | Grafana Cloud + S3 | Production | 60-80% |

## Quick Start

1. Copy the golden config closest to your setup
2. Set the required environment variables
3. Deploy

```bash
# Example: Deploy with Docker
docker run -v $(pwd)/golden-configs:/etc/otelcol:ro \
  -e DD_API_KEY=your-key \
  -e DD_SITE=datadoghq.com \
  otel/opentelemetry-collector-contrib:latest \
  --config /etc/otelcol/aws-datadog-production.yaml

# Example: Deploy on Kubernetes (as a ConfigMap)
kubectl create configmap otel-config \
  --from-file=config.yaml=golden-configs/aws-datadog-production.yaml
kubectl apply -f otel-deployment.yaml

# Example: Deploy directly with the collector binary
export DD_API_KEY=your-key
export DD_SITE=datadoghq.com
otelcol-contrib --config golden-configs/aws-datadog-production.yaml
```

## Customization

- **Add receivers**: Add to the `receivers` section and include in the appropriate `service.pipelines`
- **Change cost profile**: Adjust filter thresholds, sampling percentages, or remove filter processors entirely
- **Add backends**: Add an exporter section and include it in the pipeline exporters list
- **Adjust resources**: Change `memory_limiter` and `batch` processor settings based on your collector's available memory
- **Fan-out to multiple backends**: List multiple exporters in a pipeline (see `multi-backend-production.yaml`)

## Environment Variables

Each config documents its required variables in the file header. Common patterns:

| Variable | Used By | Description |
|----------|---------|-------------|
| `DD_API_KEY` | Datadog | Datadog API key |
| `DD_SITE` | Datadog | Datadog site (e.g., datadoghq.com) |
| `ELASTIC_APM_ENDPOINT` | Elastic | Elastic APM server URL |
| `ELASTIC_APM_TOKEN` | Elastic | Elastic APM secret token |
| `DYNATRACE_ENDPOINT` | Dynatrace | Dynatrace OTLP endpoint |
| `DYNATRACE_API_TOKEN` | Dynatrace | Dynatrace API token |
| `GCP_PROJECT_ID` | GCP Cloud Ops | Google Cloud project ID |
| `TEMPO_ENDPOINT` | Grafana LGTM | Tempo gRPC endpoint |
| `MIMIR_ENDPOINT` | Grafana LGTM | Mimir remote write endpoint |
| `LOKI_ENDPOINT` | Grafana LGTM | Loki OTLP endpoint |
| `SIGNOZ_ENDPOINT` | SigNoz | SigNoz OTLP gRPC endpoint |
| `SPLUNK_HEC_TOKEN` | Splunk | Splunk HEC token |
| `SPLUNK_HEC_ENDPOINT` | Splunk | Splunk HEC URL |
| `SPLUNK_O11Y_TOKEN` | Splunk O11y | Splunk Observability Cloud token |
| `SPLUNK_O11Y_REALM` | Splunk O11y | Splunk O11y realm (us0, us1, eu0) |
| `NEW_RELIC_API_KEY` | New Relic | New Relic Ingest License key |
| `GRAFANA_CLOUD_ENDPOINT` | Grafana Cloud | Grafana Cloud OTLP endpoint |
| `GRAFANA_CLOUD_TOKEN` | Grafana Cloud | Base64-encoded instanceID:token |
| `AWS_S3_BUCKET` | S3 Archive | S3 bucket name |
| `AWS_REGION` | AWS / S3 | AWS region |
| `K8S_NODE_NAME` | All K8s configs | Node name (via downward API) |

## Processor Pipeline Order

All configs follow the same processor ordering convention:

```
memory_limiter       -> Back-pressure protection (always first)
resourcedetection/*  -> Cloud/system resource enrichment
k8sattributes        -> Kubernetes metadata enrichment
filter/*             -> Drop unwanted telemetry
transform/*          -> Modify remaining telemetry
tail_sampling/*      -> Sample traces intelligently
redaction            -> Scrub PII patterns
batch                -> Batch for efficient export (always last)
```

## Cost Profiles

| Environment | Log Severity | Trace Sampling | Static Assets | PII Redaction |
|-------------|-------------|----------------|---------------|---------------|
| Development | All levels | 100% (no sampling) | Health checks only | No |
| Staging | INFO+ | 50% probabilistic | Health checks + static assets | No |
| Production | WARN+ | Tail-based (errors + slow + 10%) | Health checks + static assets | Yes |
