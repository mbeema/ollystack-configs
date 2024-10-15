# Runbook: Exporter Authentication Failures

## Symptoms
- `otelcol_exporter_send_failed_spans` increasing with HTTP 401 or 403 errors
- Collector logs: "Unauthorized", "Forbidden", "invalid credentials", "token expired"
- `otelcol_http_client_response_status_code{status_code="401"}` counter rising
- Data stops flowing to a specific backend while other exporters work normally
- Backend dashboards show sudden data gap starting at a specific time
- Certificate-related errors: "x509: certificate has expired", "TLS handshake failure"

## Diagnosis

### 1. Identify the failing exporter
```bash
# Check which exporter is failing
kubectl logs <collector-pod> --since=10m | grep -E "(401|403|Unauthorized|Forbidden|expired|x509)"

# Check per-exporter failure rates
rate(otelcol_exporter_send_failed_spans[5m])
rate(otelcol_exporter_send_failed_metric_points[5m])

# Filter by exporter name
otelcol_exporter_send_failed_spans{exporter="otlp/datadog"}
```

### 2. Check token or API key validity
```bash
# Verify the secret is mounted correctly
kubectl exec -it <collector-pod> -- env | grep -i "API_KEY\|TOKEN\|SECRET"

# Check if the secret exists and has data
kubectl get secret otel-exporter-credentials -o jsonpath='{.data}' | jq 'keys'

# Decode and inspect (first few characters only)
kubectl get secret otel-exporter-credentials -o jsonpath='{.data.api-key}' | base64 -d | head -c 10
echo "..."

# Test the credential directly
curl -v -H "Authorization: Bearer $(kubectl get secret otel-exporter-credentials -o jsonpath='{.data.api-key}' | base64 -d)" \
  https://api.backend.example.com/v1/health
```

### 3. Check certificate validity
```bash
# Check client certificate expiry
kubectl exec -it <collector-pod> -- openssl x509 -in /certs/client.crt -noout -enddate

# Check server certificate
openssl s_client -connect otlp-gateway.example.com:4317 -servername otlp-gateway.example.com </dev/null 2>/dev/null | openssl x509 -noout -enddate

# Check full certificate chain
openssl s_client -connect otlp-gateway.example.com:4317 -showcerts </dev/null 2>&1 | grep -E "(depth|expire)"
```

### 4. Check IAM permissions (cloud backends)
```bash
# AWS: Check IRSA annotation on service account
kubectl get sa otel-collector -o yaml | grep -A5 "annotations"

# AWS: Verify IAM role trust policy
aws iam get-role --role-name OtelCollectorRole --query 'Role.AssumeRolePolicyDocument'

# AWS: Test permissions
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::123456789012:role/OtelCollectorRole \
  --role-session-name test \
  --web-identity-token "$(cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token)"

# Azure: Check managed identity
kubectl get pod <collector-pod> -o yaml | grep -A3 "aadpodiidentity"

# GCP: Check workload identity
kubectl get sa otel-collector -o yaml | grep "iam.gke.io/gcp-service-account"
```

### 5. Check for endpoint URL changes
```bash
# Verify the endpoint is reachable
kubectl exec -it <collector-pod> -- wget -qO- --spider https://otlp.backend.example.com:4317

# Check if the backend has changed its endpoint
# Common changes: domain migration, port changes, path prefix updates
kubectl get configmap otel-collector-config -o yaml | grep "endpoint"
```

## Resolution

### Rotate API key or token
```bash
# Update the Kubernetes secret
kubectl create secret generic otel-exporter-credentials \
  --from-literal=api-key="<new-api-key>" \
  --from-literal=app-key="<new-app-key>" \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart collector pods to pick up new secret
kubectl rollout restart deployment otel-collector
kubectl rollout status deployment otel-collector
```

### Renew TLS certificates
```bash
# Generate new client certificate (example with cfssl)
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem \
  -config=ca-config.json -profile=client \
  collector-csr.json | cfssljson -bare collector

# Update the TLS secret
kubectl create secret tls otel-collector-tls \
  --cert=collector.pem \
  --key=collector-key.pem \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart collector
kubectl rollout restart deployment otel-collector
```

### Fix IAM role policy (AWS)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
```
```bash
aws iam put-role-policy \
  --role-name OtelCollectorRole \
  --policy-name OtelExporterPolicy \
  --policy-document file://policy.json
```

### Update endpoint URL
```yaml
exporters:
  otlp/backend:
    endpoint: new-otlp.backend.example.com:4317   # Updated endpoint
    headers:
      Authorization: "Bearer ${env:API_TOKEN}"
    tls:
      insecure: false
      ca_file: /certs/ca.crt
```

### Use environment variable references for secrets
```yaml
# Collector config referencing env vars (not hardcoded)
exporters:
  otlp/datadog:
    endpoint: https://api.datadoghq.com
    headers:
      DD-API-KEY: ${env:DD_API_KEY}

  otlphttp/newrelic:
    endpoint: https://otlp.nr-data.net
    headers:
      api-key: ${env:NEW_RELIC_LICENSE_KEY}

  otlphttp/splunk:
    endpoint: https://ingest.signalfx.com/v2/trace/otlp
    headers:
      X-SF-Token: ${env:SPLUNK_ACCESS_TOKEN}
```

## Prevention
- Automate token rotation with a CronJob or external secrets operator:
  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: otel-credentials
  spec:
    refreshInterval: 1h
    secretStoreRef:
      name: vault-backend
      kind: ClusterSecretStore
    target:
      name: otel-exporter-credentials
    data:
      - secretKey: api-key
        remoteRef:
          key: otel/api-key
  ```
- Monitor certificate expiry with the `tlscheck` receiver:
  ```yaml
  receivers:
    tlscheck:
      targets:
        - url: https://otlp-gateway.example.com:4317
        - url: https://api.datadoghq.com:443
      collection_interval: 24h
  ```
- Set alerts for certificate expiry (warn at 30 days, critical at 7 days):
  ```
  tlscheck_time_left_seconds < 604800  # 7 days
  ```
- Never hardcode secrets in collector config; always use `${env:VAR}` or mounted secrets
- Use managed identities (IRSA, Workload Identity, Managed Identity) instead of long-lived API keys
- Document all credential rotation procedures and test them quarterly
- Enable audit logging on the backend to detect credential misuse
