# Full-Stack Observability on Azure AKS

Complete deployment guide for running the OllyStack OpenTelemetry stack on Azure Kubernetes Service (AKS).

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
                                                  |  Azure Backends    |
                                                  |  - Azure Monitor   |
                                                  |  - App Insights    |
                                                  |  - Managed Prom.   |
                                                  +-------------------+
```

## Prerequisites

- **Azure CLI** v2.50+ authenticated (`az login`)
- **kubectl** v1.28+
- **Helm** v3.12+
- **kustomize** v5+ (or use `kubectl -k`)
- An existing AKS cluster (v1.28+) or permissions to create one
- Azure resources:
  - Azure Monitor Workspace
  - Azure Managed Grafana (optional)
  - Application Insights resource
  - Log Analytics Workspace

## Deployment Steps

### 1. Configure Azure Environment

```bash
# Set your Azure variables
export RESOURCE_GROUP=ollystack-rg
export CLUSTER_NAME=ollystack-aks
export LOCATION=eastus
export AZURE_MONITOR_WORKSPACE_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Monitor/accounts/<name>
export APP_INSIGHTS_CONNECTION_STRING="InstrumentationKey=..."

# Verify cluster access
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
kubectl cluster-info
```

### 2. Configure Managed Identity

```bash
# Enable workload identity on the cluster (if not already)
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get the OIDC issuer URL
export AKS_OIDC_ISSUER=$(az aks show \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create managed identity for the collector
az identity create \
  --name otel-collector-identity \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

export IDENTITY_CLIENT_ID=$(az identity show \
  --name otel-collector-identity \
  --resource-group $RESOURCE_GROUP \
  --query clientId -o tsv)

# Create federated credential
az identity federated-credential create \
  --name otel-collector-federated \
  --identity-name otel-collector-identity \
  --resource-group $RESOURCE_GROUP \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:observability:otel-collector \
  --audience api://AzureADTokenExchange

# Assign roles for Azure Monitor ingestion
az role assignment create \
  --assignee $IDENTITY_CLIENT_ID \
  --role "Monitoring Metrics Publisher" \
  --scope $AZURE_MONITOR_WORKSPACE_ID
```

### 3. Deploy the OTel Stack

```bash
# Create the namespace
kubectl create namespace observability

# Deploy using Kustomize
kubectl apply -k examples/full-stack-azure-aks/

# Or deploy using Helm
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# Deploy Agent
helm install otel-agent open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-azure-aks/values.yaml \
  --set mode=daemonset

# Deploy Gateway
helm install otel-gateway open-telemetry/opentelemetry-collector \
  -n observability \
  -f examples/full-stack-azure-aks/values.yaml \
  --set mode=deployment
```

### 4. Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n observability

# Verify agent is on all nodes
kubectl get daemonset -n observability

# Check logs
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# Health check
kubectl port-forward -n observability svc/otel-agent 13133:13133 &
curl http://localhost:13133/health
```

### 5. Verify Telemetry Flow

```bash
# Check in Azure Portal:
# - Azure Monitor > Metrics
# - Application Insights > Transaction search (traces)
# - Log Analytics > Logs (KQL queries)

# Example KQL query for logs:
# ContainerLogV2 | where ContainerName == "otel-collector" | take 10

# Verify metrics via Azure Monitor REST API
az monitor metrics list \
  --resource $AZURE_MONITOR_WORKSPACE_ID \
  --metric-names "up" \
  --interval PT1M
```

## Troubleshooting

### Workload identity not working

1. Verify OIDC issuer is enabled: `az aks show --query oidcIssuerProfile`
2. Check federated credential: `az identity federated-credential list`
3. Ensure service account annotations are correct

### No data in Azure Monitor

1. Verify the managed identity has `Monitoring Metrics Publisher` role
2. Check collector logs for authentication errors
3. Ensure the Azure Monitor workspace ID is correct

## Cleanup

```bash
kubectl delete -k examples/full-stack-azure-aks/
kubectl delete namespace observability
az identity delete --name otel-collector-identity --resource-group $RESOURCE_GROUP
```
