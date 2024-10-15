# Secret Management: Azure Key Vault

## Overview

This guide covers integrating the OpenTelemetry Collector with Azure Key Vault on AKS, using Managed Identity for authentication and the Azure Key Vault CSI Driver for mounting secrets into collector pods.

---

## 1. Managed Identity on AKS

Azure Managed Identity eliminates the need for storing credentials for Azure-native services. The collector pod inherits permissions from the identity assigned to its node pool or workload.

### Enable Workload Identity on AKS
```bash
# Enable OIDC issuer and workload identity on the cluster
az aks update \
  --resource-group my-rg \
  --name my-aks-cluster \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get the OIDC issuer URL
OIDC_ISSUER=$(az aks show --resource-group my-rg --name my-aks-cluster \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)
```

### Create a User-Assigned Managed Identity
```bash
# Create managed identity for collector
az identity create \
  --resource-group my-rg \
  --name otel-collector-identity

# Get identity client ID and principal ID
CLIENT_ID=$(az identity show --resource-group my-rg --name otel-collector-identity \
  --query "clientId" -o tsv)
PRINCIPAL_ID=$(az identity show --resource-group my-rg --name otel-collector-identity \
  --query "principalId" -o tsv)
IDENTITY_ID=$(az identity show --resource-group my-rg --name otel-collector-identity \
  --query "id" -o tsv)
```

### Grant permissions for Azure Monitor exporter
```bash
# Grant Monitoring Metrics Publisher role
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --role "Monitoring Metrics Publisher" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/my-rg"

# Grant Log Analytics Contributor for log export
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --role "Log Analytics Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/my-rg"
```

### Create federated credential for workload identity
```bash
az identity federated-credential create \
  --name otel-collector-federated \
  --identity-name otel-collector-identity \
  --resource-group my-rg \
  --issuer $OIDC_ISSUER \
  --subject "system:serviceaccount:observability:otel-collector" \
  --audience "api://AzureADTokenExchange"
```

### Kubernetes ServiceAccount with workload identity
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: observability
  annotations:
    azure.workload.identity/client-id: "<client-id-of-managed-identity>"
  labels:
    azure.workload.identity/use: "true"
```

---

## 2. Azure Key Vault for Third-Party Secrets

Store API keys and tokens for non-Azure backends in Azure Key Vault.

### Create Key Vault and store secrets
```bash
# Create Key Vault
az keyvault create \
  --resource-group my-rg \
  --name otel-collector-kv \
  --location eastus \
  --enable-rbac-authorization true

# Grant the managed identity access to secrets
az role assignment create \
  --assignee-object-id $PRINCIPAL_ID \
  --role "Key Vault Secrets User" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/my-rg/providers/Microsoft.KeyVault/vaults/otel-collector-kv"

# Store secrets
az keyvault secret set --vault-name otel-collector-kv --name dd-api-key --value "your-datadog-key"
az keyvault secret set --vault-name otel-collector-kv --name splunk-hec-token --value "your-splunk-token"
az keyvault secret set --vault-name otel-collector-kv --name nr-license-key --value "your-newrelic-key"
az keyvault secret set --vault-name otel-collector-kv --name otlp-client-cert --file client.crt
az keyvault secret set --vault-name otel-collector-kv --name otlp-client-key --file client.key
```

---

## 3. Azure Key Vault CSI Driver

### Install the CSI driver (enabled by default on AKS)
```bash
# Enable the Key Vault CSI driver add-on if not already enabled
az aks enable-addons \
  --resource-group my-rg \
  --name my-aks-cluster \
  --addons azure-keyvault-secrets-provider

# Verify installation
kubectl get pods -n kube-system -l app=secrets-store-csi-driver
kubectl get pods -n kube-system -l app=secrets-store-provider-azure
```

### SecretProviderClass for collector secrets
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: otel-collector-keyvault
  namespace: observability
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    clientID: "<client-id-of-managed-identity>"    # Workload Identity
    keyvaultName: "otel-collector-kv"
    tenantId: "<azure-tenant-id>"
    objects: |
      array:
        - |
          objectName: dd-api-key
          objectType: secret
        - |
          objectName: splunk-hec-token
          objectType: secret
        - |
          objectName: nr-license-key
          objectType: secret
        - |
          objectName: otlp-client-cert
          objectType: secret
        - |
          objectName: otlp-client-key
          objectType: secret
  # Sync to Kubernetes Secret for env var usage
  secretObjects:
    - secretName: otel-collector-kv-secrets
      type: Opaque
      data:
        - objectName: dd-api-key
          key: DD_API_KEY
        - objectName: splunk-hec-token
          key: SPLUNK_HEC_TOKEN
        - objectName: nr-license-key
          key: NEW_RELIC_LICENSE_KEY
```

### Collector Deployment with Key Vault CSI
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  template:
    metadata:
      labels:
        app: otel-collector-gateway
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: otel-collector
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0
          args: ["--config=/conf/config.yaml"]
          envFrom:
            - secretRef:
                name: otel-collector-kv-secrets
          volumeMounts:
            - name: config
              mountPath: /conf
            - name: keyvault-secrets
              mountPath: /secrets
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
        - name: keyvault-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: otel-collector-keyvault
```

### Collector config referencing synced secrets
```yaml
exporters:
  # Azure-native: uses Managed Identity (no secrets needed)
  azuremonitor:
    connection_string: ${env:APPLICATIONINSIGHTS_CONNECTION_STRING}

  # Third-party: uses Key Vault secrets synced to env vars
  otlp/datadog:
    endpoint: https://api.datadoghq.com
    headers:
      DD-API-KEY: ${env:DD_API_KEY}

  splunk_hec:
    endpoint: https://splunk.example.com:8088
    token: ${env:SPLUNK_HEC_TOKEN}

  # TLS certs mounted as files from Key Vault
  otlp/secure:
    endpoint: backend.example.com:4317
    tls:
      cert_file: /secrets/otlp-client-cert
      key_file: /secrets/otlp-client-key
```

---

## Secret Rotation

### Enable automatic rotation
```bash
# Enable auto-rotation on the AKS add-on
az aks addon update \
  --resource-group my-rg \
  --name my-aks-cluster \
  --addon azure-keyvault-secrets-provider \
  --enable-secret-rotation \
  --rotation-poll-interval 2m
```

### Rotate a secret
```bash
# Update the secret in Key Vault
az keyvault secret set --vault-name otel-collector-kv --name dd-api-key --value "new-api-key"

# CSI driver automatically picks up new version within rotation-poll-interval
# Synced Kubernetes Secret is also updated automatically

# Restart collector to pick up new env vars (if not using file-based config)
kubectl rollout restart deployment otel-collector-gateway -n observability
```

---

## Best Practices

- Use Workload Identity (not pod-managed identity) for AKS clusters running Kubernetes 1.22+
- Use Managed Identity for all Azure-native exporters (Azure Monitor, Blob Storage, Data Explorer)
- Store third-party API keys in Key Vault and mount via CSI driver
- Enable RBAC authorization on Key Vault instead of access policies
- Scope Key Vault access to "Key Vault Secrets User" role (read-only) for collector identity
- Enable auto-rotation with a poll interval appropriate for your rotation schedule
- Use separate Key Vault instances for production and non-production environments
- Enable Key Vault diagnostics logging to monitor secret access patterns
- Tag all secrets with `service:otel-collector` for auditing and lifecycle management
