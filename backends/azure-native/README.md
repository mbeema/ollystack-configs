# Azure Native Backend

## Overview

This configuration sends OpenTelemetry data to Azure Monitor / Application Insights. Azure Monitor provides distributed tracing, metrics, and log analytics through its Application Insights component and Log Analytics workspaces.

## Prerequisites

1. An Azure subscription
2. An Application Insights resource (workspace-based recommended)
3. The connection string from the Application Insights resource
4. The OpenTelemetry Collector Contrib distribution (includes the Azure Monitor exporter)

## Getting Your Credentials

1. Log in to the Azure Portal (https://portal.azure.com)
2. Navigate to your **Application Insights** resource (or create one)
3. On the **Overview** page, copy the **Connection String**
   - Format: `InstrumentationKey=xxx;IngestionEndpoint=https://xxx.in.applicationinsights.azure.com/;...`

### Creating an Application Insights Resource

1. In the Azure Portal, click **Create a resource**
2. Search for **Application Insights**
3. Click **Create**
4. Select your subscription and resource group
5. Choose a name, region, and select **Workspace-based** resource mode
6. Link to a Log Analytics workspace
7. Click **Review + Create** > **Create**

## RBAC Roles

### Minimal (Export Only)

The service principal needs:

| Role | Purpose |
|---|---|
| **Monitoring Metrics Publisher** | Write custom metrics to Azure Monitor |

The Application Insights connection string handles authentication for trace and log ingestion.

### Full (Export + Azure Monitor Receiver for All Services)

If you're using the Azure Monitor receiver fragments to pull metrics from Azure services, add:

| Role | Purpose |
|---|---|
| **Monitoring Reader** | Read metrics from Azure Monitor for all resource types |
| **Reader** | List resources within resource groups |

## Available Azure Monitor Receiver Fragments

Each fragment pulls metrics for a specific Azure service. Compose only the fragments you need:

| Fragment | Azure Service | Key Metrics |
|----------|--------------|-------------|
| `azuremonitor.yaml` | Virtual Machines | CPU, memory, disk, network, availability |
| `azuremonitor-sqldatabase.yaml` | SQL Database / Elastic Pool / Managed Instance | DTU/vCore, storage, connections, deadlocks, replication |
| `azuremonitor-cosmosdb.yaml` | Cosmos DB | RU consumption, throttling (429s), latency, storage, replication, integrated cache |
| `azuremonitor-appservice.yaml` | App Service (Web Apps) + App Service Plans | Requests, response time, HTTP errors, CPU, memory, connections, IO |
| `azuremonitor-functions.yaml` | Azure Functions | Execution count, duration units, requests, CPU, memory, health |
| `azuremonitor-servicebus.yaml` | Service Bus | Messages in/out, active/dead-lettered, throttled requests, server errors, connections |
| `azuremonitor-eventhubs.yaml` | Event Hubs | Throughput bytes, connections, throttled requests, capture backlog |
| `azuremonitor-storage.yaml` | Storage Accounts (Blob, File, Queue, Table) | Transactions, capacity, ingress/egress, latency, availability per service |
| `azuremonitor-rediscache.yaml` | Azure Cache for Redis + Enterprise | Cache hit/miss, evictions, server load, memory, connections, replication lag |
| `azuremonitor-apimanagement.yaml` | API Management (APIM) | Requests, capacity, gateway duration, backend duration, failures |
| `azuremonitor-frontdoor.yaml` | Front Door & CDN (Standard/Premium/Classic) | Requests, latency, origin health, byte hit ratio, WAF |
| `azuremonitor-containerapps.yaml` | Container Apps | Requests, replicas, CPU (nanoCores), memory (working set), network, restarts |
| `azuremonitor-keyvault.yaml` | Key Vault | API hit/miss, latency, availability, saturation |
| `azuremonitor-appgateway.yaml` | Application Gateway (L7 LB) | Throughput, connections, response codes, latency, backend health, capacity units, WAF |
| `azuremonitor-loadbalancer.yaml` | Load Balancer (L4) | VIP/DIP availability, SNAT ports, connections, packet/byte counts |
| `azuremonitor-aks.yaml` | AKS (Kubernetes Service) | Node CPU/memory/disk, pod status, autoscaler metrics |

### Example: Composing Fragments

```bash
otelcol --config=collector/base/otel-gateway-base.yaml \
        --config=collector/fragments/receivers/azuremonitor.yaml \
        --config=collector/fragments/receivers/azuremonitor-sqldatabase.yaml \
        --config=collector/fragments/receivers/azuremonitor-cosmosdb.yaml \
        --config=collector/fragments/receivers/azuremonitor-servicebus.yaml \
        --config=collector/fragments/processors/batch.yaml \
        --config=collector/fragments/exporters/azuremonitor.yaml
```

## Environment Variables

| Variable | Description | Example |
|---|---|---|
| `AZURE_MONITOR_CONNECTION_STRING` | Application Insights connection string | `InstrumentationKey=00000000-...;IngestionEndpoint=https://...` |
| `AZURE_TENANT_ID` | Azure AD tenant ID (for receiver) | `00000000-0000-0000-0000-000000000000` |
| `AZURE_CLIENT_ID` | Azure AD client (service principal) ID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_CLIENT_SECRET` | Azure AD client secret | `your-secret` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `00000000-0000-0000-0000-000000000000` |
| `AZURE_RESOURCE_GROUP` | Resource group to monitor | `my-resource-group` |
| `AZURE_CLOUD` | Cloud environment (default: AzureCloud) | `AzureCloud` |
| `AZURE_MONITOR_INTERVAL` | Polling interval (default: 60s) | `60s` |

## Usage

1. Set the required environment variables:

```bash
export AZURE_MONITOR_CONNECTION_STRING="InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://eastus-0.in.applicationinsights.azure.com/;LiveEndpoint=https://eastus.livediagnostics.monitor.azure.com/"

# For Azure Monitor receiver (pulling metrics):
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_RESOURCE_GROUP="your-resource-group"
```

2. Reference the `exporter.yaml` in your OpenTelemetry Collector configuration.

## Verifying Data

- **Traces**: Navigate to Azure Portal > Application Insights > Transaction Search
- **Metrics**: Navigate to Application Insights > Metrics
- **Logs**: Navigate to Application Insights > Logs (run Kusto queries against `traces`, `requests`, `dependencies` tables)
- **Application Map**: Navigate to Application Insights > Application Map

## Notes

- The Azure Monitor exporter maps OTLP data to Application Insights data model
- Traces become `requests` and `dependencies` in Application Insights
- Metrics are stored in Azure Monitor Metrics (both pre-aggregated and log-based)
- Logs are stored in the linked Log Analytics workspace
- The connection string contains all routing information (no separate endpoint configuration needed)
- Sampling can be configured at the Collector level using processors
- For AKS workloads, consider using Managed Identity for authentication
- Event Hubs metrics receiver (`azuremonitor-eventhubs.yaml`) pulls metrics ABOUT Event Hubs; the separate `azureeventhub.yaml` receiver consumes data FROM Event Hubs — use both for complete coverage
