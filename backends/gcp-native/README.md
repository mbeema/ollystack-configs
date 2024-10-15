# GCP Native Backend

## Overview

This configuration sends OpenTelemetry data to Google Cloud native observability services:

- **Cloud Trace** - Distributed tracing
- **Cloud Monitoring** - Metrics and dashboards
- **Cloud Logging** - Log management and analysis

## Prerequisites

1. A Google Cloud project with the following APIs enabled:
   - Cloud Trace API
   - Cloud Monitoring API
   - Cloud Logging API
2. A service account with appropriate IAM roles (or Workload Identity for GKE)
3. The OpenTelemetry Collector Contrib distribution (includes the Google Cloud exporter)

## IAM Roles

### Minimal (Export Only)

| Role | Purpose |
|---|---|
| `roles/cloudtrace.agent` | Write traces to Cloud Trace |
| `roles/monitoring.metricWriter` | Write metrics to Cloud Monitoring |
| `roles/logging.logWriter` | Write logs to Cloud Logging |

### Full (Export + Cloud Monitoring Receiver for All Services)

If you're using the Cloud Monitoring receiver fragments to pull metrics from GCP services, add:

| Role | Purpose |
|---|---|
| `roles/monitoring.viewer` | Read metrics from Cloud Monitoring for all resource types |

## Available Cloud Monitoring Receiver Fragments

Each fragment pulls metrics for a specific GCP service. Compose only the fragments you need:

| Fragment | GCP Service | Key Metrics |
|----------|------------|-------------|
| `googlecloud.yaml` | Compute Engine (basic), Cloud SQL (basic), GKE (basic), LB (basic) | CPU, memory, disk, network |
| `googlecloudmonitoring-cloudsql.yaml` | Cloud SQL (MySQL, PostgreSQL, SQL Server) | CPU, memory, disk, IOPS, connections, queries, replication, InnoDB/PG-specific |
| `googlecloudmonitoring-spanner.yaml` | Cloud Spanner | CPU, storage, API latency, transactions, sessions, locks |
| `googlecloudmonitoring-cloudrun.yaml` | Cloud Run (services + jobs) | Requests, latency, CPU/memory utilization, instance count, billable time |
| `googlecloudmonitoring-cloudfunctions.yaml` | Cloud Functions (1st + 2nd gen) | Execution count, duration, memory, active instances, network egress |
| `googlecloudmonitoring-pubsub.yaml` | Pub/Sub | Message throughput, backlog (undelivered messages), oldest unacked age, dead letter, push latency |
| `googlecloudmonitoring-bigquery.yaml` | BigQuery | Query count, execution time, scanned bytes, slot utilization, storage, streaming inserts |
| `googlecloudmonitoring-gke.yaml` | GKE (Google Kubernetes Engine) | Container CPU/memory/restarts, node resources, pod network/volumes, autoscaler |
| `googlecloudmonitoring-cloudstorage.yaml` | Cloud Storage (GCS) | API request count, object count, total bytes, network, replication, autoclass |
| `googlecloudmonitoring-memorystore.yaml` | Memorystore (Redis + Memcached) | Cache hit ratio, evictions, CPU, memory, connections, replication lag, commands |
| `googlecloudmonitoring-dataflow.yaml` | Dataflow | Jobs, element count, data watermark age, system lag, vCPU/memory billing |
| `googlecloudmonitoring-cloudtasks.yaml` | Cloud Tasks | Queue depth, task attempts, dispatch latency, API request count |
| `googlecloudmonitoring-loadbalancing.yaml` | Cloud Load Balancing (all types) | HTTPS, TCP/SSL proxy, internal/external L4 — requests, latency, connections, RTT |
| `googlecloudmonitoring-computeengine.yaml` | Compute Engine (enhanced) | Disk IOPS/latency, guest agent (Ops Agent), firewall insights, integrity monitoring |
| `googlecloudmonitoring-filestore.yaml` | Filestore (managed NFS) | Capacity, free space, read/write IOPS, throughput, connected clients |

### Example: Composing Fragments

```bash
otelcol --config=collector/base/otel-gateway-base.yaml \
        --config=collector/fragments/receivers/googlecloud.yaml \
        --config=collector/fragments/receivers/googlecloudmonitoring-cloudsql.yaml \
        --config=collector/fragments/receivers/googlecloudmonitoring-pubsub.yaml \
        --config=collector/fragments/receivers/googlecloudmonitoring-cloudrun.yaml \
        --config=collector/fragments/processors/batch.yaml \
        --config=collector/fragments/exporters/googlecloud.yaml
```

## Getting Your Credentials

### Service Account Key (for non-GCP environments)

1. Go to the Google Cloud Console > IAM & Admin > Service Accounts
2. Create a new service account or select an existing one
3. Grant the required roles listed above
4. Click **Keys** > **Add Key** > **Create new key** > **JSON**
5. Save the key file and set `GOOGLE_APPLICATION_CREDENTIALS` to its path

### GKE (Workload Identity)

1. Enable Workload Identity on your GKE cluster
2. Create a Kubernetes service account
3. Bind it to the Google Cloud service account with the required roles
4. No key file needed -- authentication is automatic

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `GCP_PROJECT_ID` | Google Cloud project ID | `my-project-123` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service account key file (non-GCP only) | `/path/to/sa-key.json` |
| `GCP_MONITORING_INTERVAL` | Polling interval (default: 60s) | `60s` |

## Usage

1. Set the required environment variables:

```bash
export GCP_PROJECT_ID="my-project-123"
# If running outside GCP:
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/sa-key.json"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Google Cloud Console > Trace > Trace List
- **Metrics**: Navigate to Cloud Console > Monitoring > Metrics Explorer
- **Logs**: Navigate to Cloud Console > Logging > Logs Explorer

## Notes

- On GCE, GKE, Cloud Run, or Cloud Functions, credentials are obtained automatically via metadata server
- The Google Cloud exporter maps OTLP traces to Cloud Trace format and OTLP metrics to Cloud Monitoring format
- Custom metrics appear under the `custom.googleapis.com/opencensus/` or `workload.googleapis.com/` prefix
- Cloud Monitoring has limits on the number of custom metric descriptors per project
- For GKE, Workload Identity is the recommended authentication method
- Logs sent through the exporter appear in Cloud Logging with the resource type `generic_task`
- Pub/Sub metrics receiver (`googlecloudmonitoring-pubsub.yaml`) pulls metrics ABOUT Pub/Sub; the separate `googlecloudpubsub.yaml` receiver consumes data FROM Pub/Sub — use both for complete coverage
- 2nd gen Cloud Functions are backed by Cloud Run; some metrics appear under both `cloudfunctions.googleapis.com` and `run.googleapis.com`
