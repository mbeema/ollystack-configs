# Full-Stack Observability on Google Cloud GKE

Complete deployment guide for running the OllyStack OpenTelemetry stack on Google Kubernetes Engine (GKE).

## Architecture

```
+------------------+     +------------------+     +-------------------+
|  Application     |     |  OTel Agent      |     |  OTel Gateway     |
|  Pods            +---->+  (DaemonSet)     +---->+  (Deployment)     |
|  (instrumented)  |     |  per node        |     |  centralized      |
+------------------+     +------------------+     +--------+----------+
                                                           |
                         +------------------+              |
                         |  Cluster         |              |
                         |  Receiver        +--------------+
                         |  (Deployment)    |              |
                         +------------------+              v
                                                  +--------+----------+
                                                  |  GCP Backends      |
                                                  |  - Cloud Trace     |
                                                  |  - Cloud Monitoring|
                                                  |  - Cloud Logging   |
                                                  +-------------------+
```

## Prerequisites

- **gcloud CLI** authenticated (`gcloud auth login`)
- **kubectl** v1.28+
- **Helm** v3.12+
- **kustomize** v5+ (or use `kubectl -k`)
- A GCP project with billing enabled
- An existing GKE cluster (v1.28+) or permissions to create one
- APIs enabled:
  - Cloud Trace API
  - Cloud Monitoring API
  - Cloud Logging API
  - Kubernetes Engine API

## Deployment Steps

### 1. Configure GCP Environment

```bash
# Set your GCP variables
export PROJECT_ID=my-ollystack-project
export CLUSTER_NAME=ollystack-gke
export REGION=us-central1
export ZONE=us-central1-a

# Authenticate and set project
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable \
  container.googleapis.com \
  cloudtrace.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com

# Get cluster credentials
gcloud container clusters get-credentials $CLUSTER_NAME \
  --region $REGION \
  --project $PROJECT_ID

kubectl cluster-info
```

### 2. Configure Workload Identity

```bash
# Enable Workload Identity on the cluster (if not already)
gcloud container clusters update $CLUSTER_NAME \
  --region $REGION \
  --workload-pool="${PROJECT_ID}.svc.id.goog"

# Create a GCP service account for the collector
gcloud iam service-accounts create otel-collector \
  --display-name="OTel Collector Service Account" \
  --project $PROJECT_ID

export GSA_EMAIL=otel-collector@${PROJECT_ID}.iam.gserviceaccount.com

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/cloudtrace.agent"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/monitoring.metricWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${GSA_EMAIL}" \
  --role="roles/logging.logWriter"

# Bind the Kubernetes SA to the GCP SA
gcloud iam service-accounts add-iam-policy-binding $GSA_EMAIL \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[observability/otel-collector]"
```

### 3. Deploy the OTel Stack

```bash
# Create namespace
kubectl create namespace observability

# Deploy using Kustomize
kubectl apply -k examples/full-stack-gcp-gke/

# Or deploy using Helm
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Deploy Agent
helm install otel-agent open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-gcp-gke/values.yaml \
  --set mode=daemonset

# Deploy Gateway
helm install otel-gateway open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-gcp-gke/values.yaml \
  --set mode=deployment

# Deploy Cluster Receiver
helm install otel-cluster open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-gcp-gke/values.yaml \
  --set mode=deployment \
  --set clusterReceiver.enabled=true
```

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n observability

# Verify agent is on all nodes
kubectl get daemonset -n observability

# Check collector logs
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# Health check
kubectl port-forward -n observability svc/otel-agent 13133:13133 &
curl http://localhost:13133/health
```

### 5. Verify Telemetry Flow

```bash
# Check traces in Cloud Trace
gcloud trace traces list --project $PROJECT_ID --limit 10

# Check metrics in Cloud Monitoring
gcloud monitoring dashboards list --project $PROJECT_ID

# Check logs in Cloud Logging
gcloud logging read \
  'resource.type="k8s_container" AND resource.labels.namespace_name="observability"' \
  --project $PROJECT_ID \
  --limit 10 \
  --format json
```

## Configuration Files

| File | Description |
|------|-------------|
| `kustomization.yaml` | Kustomize overlay with GCP-specific patches |
| `values.yaml` | Helm values for full GKE deployment |

## Troubleshooting

### Workload Identity not working

1. Verify Workload Identity is enabled: `gcloud container clusters describe $CLUSTER_NAME --format='get(workloadIdentityConfig)'`
2. Check SA annotation: `kubectl get sa otel-collector -n observability -o yaml`
3. Test from a pod: `gcloud auth list` inside the collector pod

### No traces in Cloud Trace

1. Check that Cloud Trace API is enabled
2. Verify the service account has `roles/cloudtrace.agent`
3. Look for authentication errors in collector logs

### Permission denied errors

1. Ensure the GCP SA has all required roles
2. Verify the Workload Identity binding exists
3. Check that the K8s SA is annotated correctly

## Cleanup

```bash
kubectl delete -k examples/full-stack-gcp-gke/
kubectl delete namespace observability
gcloud iam service-accounts delete $GSA_EMAIL --project $PROJECT_ID
```
