# Secret Management: HashiCorp Vault Integration

## Overview

This guide covers two patterns for integrating HashiCorp Vault with the OpenTelemetry Collector on Kubernetes: the Vault Agent sidecar injector and the Vault CSI Provider. Both approaches eliminate the need to store secrets in Kubernetes Secret objects.

---

## 1. Vault Agent Sidecar Pattern

The Vault Agent Injector automatically injects a sidecar container that authenticates with Vault and writes secrets to a shared volume. The collector reads secrets from rendered files or environment variables.

### Prerequisites
```bash
# Install Vault with injector enabled
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault \
  --set "injector.enabled=true" \
  --set "server.dev.enabled=false" \
  -n vault --create-namespace
```

### Configure Vault
```bash
# Enable KV secrets engine
vault secrets enable -path=otel kv-v2

# Store collector secrets
vault kv put otel/datadog api_key="your-datadog-api-key"
vault kv put otel/splunk hec_token="your-splunk-hec-token"
vault kv put otel/newrelic license_key="your-newrelic-license-key"
vault kv put otel/tls client_cert=@client.crt client_key=@client.key ca_cert=@ca.crt

# Create policy for collector
vault policy write otel-collector - <<EOF
path "otel/data/*" {
  capabilities = ["read"]
}
EOF

# Enable Kubernetes auth
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

# Create role for collector service account
vault write auth/kubernetes/role/otel-collector \
  bound_service_account_names=otel-collector \
  bound_service_account_namespaces=observability \
  policies=otel-collector \
  ttl=1h
```

### Collector Deployment with Vault annotations
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  template:
    metadata:
      annotations:
        # Enable Vault Agent injection
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "otel-collector"

        # Render secrets as environment file
        vault.hashicorp.com/agent-inject-secret-env: "otel/data/datadog"
        vault.hashicorp.com/agent-inject-template-env: |
          {{- with secret "otel/data/datadog" -}}
          DD_API_KEY={{ .Data.data.api_key }}
          {{- end }}

        # Render Splunk token
        vault.hashicorp.com/agent-inject-secret-splunk: "otel/data/splunk"
        vault.hashicorp.com/agent-inject-template-splunk: |
          {{- with secret "otel/data/splunk" -}}
          SPLUNK_HEC_TOKEN={{ .Data.data.hec_token }}
          {{- end }}

        # Render TLS certificates as files
        vault.hashicorp.com/agent-inject-secret-client.crt: "otel/data/tls"
        vault.hashicorp.com/agent-inject-template-client.crt: |
          {{- with secret "otel/data/tls" -}}
          {{ .Data.data.client_cert }}
          {{- end }}

        vault.hashicorp.com/agent-inject-secret-client.key: "otel/data/tls"
        vault.hashicorp.com/agent-inject-template-client.key: |
          {{- with secret "otel/data/tls" -}}
          {{ .Data.data.client_key }}
          {{- end }}

        # Re-render secrets periodically (auto-rotation)
        vault.hashicorp.com/agent-pre-populate-only: "false"
    spec:
      serviceAccountName: otel-collector
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0
          command: ["/bin/sh", "-c"]
          args:
            - |
              # Source environment variables from Vault-rendered file
              export $(cat /vault/secrets/env | xargs)
              export $(cat /vault/secrets/splunk | xargs)
              exec /otelcol-contrib --config=/conf/config.yaml
          volumeMounts:
            - name: config
              mountPath: /conf
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
```

### Collector config referencing Vault-rendered secrets
```yaml
exporters:
  otlp/datadog:
    endpoint: https://api.datadoghq.com
    headers:
      DD-API-KEY: ${env:DD_API_KEY}

  splunk_hec:
    endpoint: https://splunk.example.com:8088
    token: ${env:SPLUNK_HEC_TOKEN}

  otlp/secure:
    endpoint: backend.example.com:4317
    tls:
      cert_file: /vault/secrets/client.crt
      key_file: /vault/secrets/client.key
```

---

## 2. Vault CSI Provider

The Vault CSI Provider mounts Vault secrets as volumes using the Kubernetes Secrets Store CSI Driver. This avoids the sidecar pattern and uses native volume mounts.

### Install CSI Driver and Vault Provider
```bash
# Install Secrets Store CSI Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --set syncSecret.enabled=true \
  -n kube-system

# Install Vault CSI Provider
helm upgrade --install vault hashicorp/vault \
  --set "csi.enabled=true" \
  --set "injector.enabled=false" \
  -n vault
```

### SecretProviderClass for collector secrets
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: otel-collector-vault
  namespace: observability
spec:
  provider: vault
  parameters:
    vaultAddress: "https://vault.vault.svc:8200"
    roleName: "otel-collector"
    objects: |
      - objectName: "dd-api-key"
        secretPath: "otel/data/datadog"
        secretKey: "api_key"
      - objectName: "splunk-token"
        secretPath: "otel/data/splunk"
        secretKey: "hec_token"
      - objectName: "nr-license"
        secretPath: "otel/data/newrelic"
        secretKey: "license_key"
  # Sync to K8s Secret for env var usage
  secretObjects:
    - secretName: otel-collector-vault-secrets
      type: Opaque
      data:
        - objectName: dd-api-key
          key: DD_API_KEY
        - objectName: splunk-token
          key: SPLUNK_HEC_TOKEN
        - objectName: nr-license
          key: NEW_RELIC_LICENSE_KEY
```

### Collector Deployment using CSI volume
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  template:
    spec:
      serviceAccountName: otel-collector
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0
          envFrom:
            - secretRef:
                name: otel-collector-vault-secrets   # Synced from CSI
          volumeMounts:
            - name: vault-secrets
              mountPath: /vault/secrets
              readOnly: true
      volumes:
        - name: vault-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: otel-collector-vault
```

---

## Best Practices

- Use Kubernetes auth method instead of token auth for Vault; it leverages ServiceAccount identity
- Set `agent-pre-populate-only: "false"` to enable automatic secret re-rendering on rotation
- Use short TTLs (1h) on Vault roles to limit blast radius of compromised tokens
- Store TLS certificates in Vault rather than Kubernetes Secrets for centralized lifecycle management
- Prefer CSI Provider when you need volume-mounted secrets without sidecar overhead
- Prefer Agent Injector when you need templated secret rendering or dynamic environment files
- Apply least-privilege Vault policies: only grant `read` on specific paths the collector needs
- Monitor Vault audit logs for unauthorized access attempts to collector secret paths
