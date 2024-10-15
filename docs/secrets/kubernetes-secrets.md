# Secret Management: Kubernetes Secrets

## Overview

This guide covers three approaches for managing OTel Collector secrets in Kubernetes, from simplest to most secure: native K8s Secrets, Sealed Secrets for GitOps, and External Secrets Operator for centralized secret stores.

---

## 1. Native Kubernetes Secrets

### Create secrets for collector credentials
```bash
# Create a secret with multiple backend API keys
kubectl create secret generic otel-collector-secrets \
  --from-literal=DD_API_KEY="your-datadog-api-key" \
  --from-literal=SPLUNK_HEC_TOKEN="your-splunk-token" \
  --from-literal=NEW_RELIC_LICENSE_KEY="your-newrelic-key" \
  -n observability
```

### Reference secrets in collector Deployment via envFrom
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  template:
    spec:
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0
          envFrom:
            - secretRef:
                name: otel-collector-secrets
          # Or mount individual keys as env vars:
          env:
            - name: OTLP_ENDPOINT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: otel-collector-secrets
                  key: DD_API_KEY
```

### Reference env vars in collector config
```yaml
exporters:
  otlp/datadog:
    endpoint: https://api.datadoghq.com
    headers:
      DD-API-KEY: ${env:DD_API_KEY}

  otlphttp/newrelic:
    endpoint: https://otlp.nr-data.net
    headers:
      api-key: ${env:NEW_RELIC_LICENSE_KEY}

  splunk_hec:
    endpoint: https://splunk-hec.example.com:8088
    token: ${env:SPLUNK_HEC_TOKEN}
```

### Mount TLS certificates from secrets
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: otel-collector-tls
  namespace: observability
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
  ca.crt: <base64-encoded-ca>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
spec:
  template:
    spec:
      containers:
        - name: otel-collector
          volumeMounts:
            - name: tls-certs
              mountPath: /certs
              readOnly: true
      volumes:
        - name: tls-certs
          secret:
            secretName: otel-collector-tls
```

---

## 2. Sealed Secrets for GitOps

Sealed Secrets encrypts secrets so they can be safely stored in Git.

### Install Sealed Secrets controller
```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

### Create a SealedSecret
```bash
# Create the secret manifest (do not apply directly)
kubectl create secret generic otel-collector-secrets \
  --from-literal=DD_API_KEY="your-datadog-api-key" \
  --from-literal=SPLUNK_HEC_TOKEN="your-splunk-token" \
  --dry-run=client -o yaml > otel-secrets.yaml

# Seal it (encrypted with the cluster's public key)
kubeseal --format=yaml < otel-secrets.yaml > otel-secrets-sealed.yaml

# Now safe to commit to Git
git add otel-secrets-sealed.yaml
git commit -m "Add sealed OTel collector secrets"
```

### SealedSecret manifest (safe for Git)
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: otel-collector-secrets
  namespace: observability
spec:
  encryptedData:
    DD_API_KEY: AgBx7k3...encrypted...
    SPLUNK_HEC_TOKEN: AgCy8l4...encrypted...
  template:
    metadata:
      name: otel-collector-secrets
      namespace: observability
```

---

## 3. External Secrets Operator

Syncs secrets from external stores (Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager) into Kubernetes Secrets.

### Install External Secrets Operator
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

### ClusterSecretStore (connects to your secret backend)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "otel-collector"
          serviceAccountRef:
            name: otel-collector
            namespace: observability
```

### ExternalSecret for collector credentials
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: otel-collector-secrets
  namespace: observability
spec:
  refreshInterval: 1h           # Sync every hour
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: otel-collector-secrets
    creationPolicy: Owner
  data:
    - secretKey: DD_API_KEY
      remoteRef:
        key: otel/datadog
        property: api_key
    - secretKey: SPLUNK_HEC_TOKEN
      remoteRef:
        key: otel/splunk
        property: hec_token
    - secretKey: NEW_RELIC_LICENSE_KEY
      remoteRef:
        key: otel/newrelic
        property: license_key
```

### Verify sync status
```bash
kubectl get externalsecret otel-collector-secrets -n observability
# STATUS should show "SecretSynced"

kubectl get secret otel-collector-secrets -n observability -o jsonpath='{.data}' | jq 'keys'
```

---

## Best Practices

- Never hardcode secrets in collector ConfigMaps; always use `${env:VAR}` syntax
- Use `envFrom` to mount all keys from a secret, avoiding individual `valueFrom` boilerplate
- Rotate secrets by updating the Secret object and restarting collector pods
- Use RBAC to restrict which ServiceAccounts can read collector secrets
- Enable encryption at rest for etcd to protect native Kubernetes Secrets
- Prefer External Secrets Operator or Sealed Secrets over plain `kubectl create secret` in production
- Set `refreshInterval` on ExternalSecrets to automatically pick up rotated credentials
