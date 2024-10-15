# Secret Management: AWS Secrets

## Overview

This guide covers three approaches for managing OTel Collector secrets on AWS EKS: IAM Roles for Service Accounts (IRSA) for native AWS service authentication, AWS Secrets Manager for API keys and tokens, and the AWS Secrets Store CSI Driver for mounting secrets as volumes.

---

## 1. IRSA (IAM Roles for Service Accounts)

IRSA allows the collector pod to assume an IAM role without storing any credentials. This is the preferred approach for AWS-native exporters (CloudWatch, X-Ray, S3, Kinesis).

### Create IAM policy for collector
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "OTelXRayExporter",
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"
      ],
      "Resource": "*"
    },
    {
      "Sid": "OTelCloudWatchExporter",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:/otel/*",
        "arn:aws:logs:*:*:log-group:/otel/*:*"
      ]
    },
    {
      "Sid": "OTelS3Exporter",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::my-otel-bucket",
        "arn:aws:s3:::my-otel-bucket/*"
      ]
    },
    {
      "Sid": "OTelKinesisExporter",
      "Effect": "Allow",
      "Action": [
        "kinesis:PutRecord",
        "kinesis:PutRecords",
        "kinesis:DescribeStream"
      ],
      "Resource": "arn:aws:kinesis:*:*:stream/otel-*"
    },
    {
      "Sid": "OTelCloudWatchReceiver",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
        "tag:GetResources"
      ],
      "Resource": "*"
    }
  ]
}
```

### Create IAM role with IRSA trust policy
```bash
# Create the policy
aws iam create-policy \
  --policy-name OtelCollectorPolicy \
  --policy-document file://otel-policy.json

# Get OIDC provider for EKS cluster
OIDC_PROVIDER=$(aws eks describe-cluster --name my-cluster \
  --query "cluster.identity.oidc.issuer" --output text | sed 's|https://||')

# Create the role with trust policy
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:observability:otel-collector",
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name OtelCollectorRole \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name OtelCollectorRole \
  --policy-arn arn:aws:iam::123456789012:policy/OtelCollectorPolicy
```

### Annotate Kubernetes ServiceAccount
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: observability
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/OtelCollectorRole
```

### Collector config (no credentials needed)
```yaml
# AWS exporters automatically use IRSA when running on EKS
exporters:
  awsxray:
    region: us-east-1

  awscloudwatchlogs:
    region: us-east-1
    log_group_name: "/otel/collector"
    log_stream_name: "traces"

  awss3:
    region: us-east-1
    s3uploader:
      s3_bucket: my-otel-bucket
      s3_prefix: telemetry
```

---

## 2. AWS Secrets Manager

For third-party API keys (Datadog, Splunk, New Relic) that cannot use IRSA.

### Store secrets in AWS Secrets Manager
```bash
# Store individual secrets
aws secretsmanager create-secret \
  --name otel/datadog-api-key \
  --secret-string "your-datadog-api-key"

aws secretsmanager create-secret \
  --name otel/splunk-hec-token \
  --secret-string "your-splunk-hec-token"

# Or store as JSON (multiple keys in one secret)
aws secretsmanager create-secret \
  --name otel/collector-credentials \
  --secret-string '{"DD_API_KEY":"your-dd-key","SPLUNK_TOKEN":"your-splunk-token","NR_KEY":"your-nr-key"}'
```

### Add Secrets Manager permissions to IAM policy
```json
{
  "Sid": "OTelSecretsAccess",
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:otel/*"
  ]
}
```

---

## 3. AWS Secrets Store CSI Driver

Mount AWS Secrets Manager secrets as files or sync them to Kubernetes Secrets.

### Install the CSI driver and AWS provider
```bash
# Install Secrets Store CSI Driver
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true \
  --set rotationPollInterval=3600s \
  -n kube-system

# Install AWS provider
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

### SecretProviderClass for collector
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: otel-collector-aws-secrets
  namespace: observability
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "otel/collector-credentials"
        objectType: "secretsmanager"
        jmesPath:
          - path: DD_API_KEY
            objectAlias: dd-api-key
          - path: SPLUNK_TOKEN
            objectAlias: splunk-token
          - path: NR_KEY
            objectAlias: nr-key
  # Sync to Kubernetes Secret for env var usage
  secretObjects:
    - secretName: otel-collector-secrets
      type: Opaque
      data:
        - objectName: dd-api-key
          key: DD_API_KEY
        - objectName: splunk-token
          key: SPLUNK_HEC_TOKEN
        - objectName: nr-key
          key: NEW_RELIC_LICENSE_KEY
```

### Collector Deployment with CSI volume
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector-gateway
  namespace: observability
spec:
  template:
    spec:
      serviceAccountName: otel-collector    # Must have IRSA annotation
      containers:
        - name: otel-collector
          image: otel/opentelemetry-collector-contrib:0.100.0
          envFrom:
            - secretRef:
                name: otel-collector-secrets  # Synced from CSI
          volumeMounts:
            - name: aws-secrets
              mountPath: /secrets
              readOnly: true
      volumes:
        - name: aws-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: otel-collector-aws-secrets
```

---

## Best Practices

- Use IRSA for all AWS-native exporters and receivers; never store AWS access keys in secrets
- Scope IAM policies to specific resources (log groups, S3 buckets, Kinesis streams) rather than using `"Resource": "*"`
- Use AWS Secrets Manager for third-party credentials (Datadog, Splunk, New Relic API keys)
- Enable automatic rotation on Secrets Manager secrets and set `enableSecretRotation=true` on the CSI driver
- Use `jmesPath` in SecretProviderClass to extract individual fields from JSON secrets
- Tag all IAM roles and secrets with `team:observability` for cost allocation and access auditing
- Enable CloudTrail logging for `secretsmanager:GetSecretValue` calls to audit secret access
- Restrict the IRSA trust policy to specific ServiceAccount names and namespaces
