# OllyStack Terraform Modules

Infrastructure prerequisites for deploying the OTel Collector on AWS, Azure, or GCP. These modules create the **IAM roles, secrets, and storage** that the collector needs — not the collector itself (that's Helm's job).

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Terraform (run once per cluster)                       │
│                                                         │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ IAM Role │  │ Secret Store │  │ Archive Storage  │  │
│  │ (IRSA /  │  │ (Secrets Mgr │  │ (S3 / Blob /    │  │
│  │  WI / WI)│  │  / Key Vault │  │  GCS) [optional] │  │
│  │          │  │  / Secret Mgr│  │                  │  │
│  └────┬─────┘  └──────┬───────┘  └────────┬─────────┘  │
│       │               │                   │             │
│       │  Outputs: role_arn, secret_name, bucket_name    │
└───────┼───────────────┼───────────────────┼─────────────┘
        │               │                   │
        ▼               ▼                   ▼
┌─────────────────────────────────────────────────────────┐
│  Helm (run to deploy/upgrade collector)                 │
│                                                         │
│  ServiceAccount annotation → IAM Role                   │
│  SecretProviderClass       → Secret Store               │
│  Exporter config           → Archive Storage            │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

| Tool | Minimum Version | Notes |
|------|----------------|-------|
| Terraform | >= 1.5.7 | Required by EKS module v21 |
| AWS Provider | >= 6.0 | Required by EKS module v21 |
| AWS CLI | v2 | For `aws eks update-kubeconfig` |
| kubectl | 1.35+ | Match your cluster version |
| Helm | 3.x | For deploying the collector |

## Quick Start

### AWS Test Cluster (from scratch)

Spin up a minimal-cost EKS cluster (~$3/day) for testing:

```bash
cd terraform/aws-test-cluster

terraform init
terraform apply

# Configure kubectl
$(terraform output -raw update_kubeconfig_command)

# Verify
kubectl get nodes
```

Then set up IRSA (using outputs from the test cluster):

```bash
cd ../aws

terraform init
terraform apply \
  -var="cluster_name=$(cd ../aws-test-cluster && terraform output -raw cluster_name)" \
  -var="cluster_oidc_provider_arn=$(cd ../aws-test-cluster && terraform output -raw oidc_provider_arn)" \
  -var="cluster_oidc_provider_url=$(cd ../aws-test-cluster && terraform output -raw oidc_provider_url)"

# Get the IRSA role ARN for Helm
terraform output irsa_role_arn
```

### AWS (existing EKS cluster + IRSA)

```bash
cd terraform/aws

terraform init
terraform apply \
  -var="cluster_name=prod-us-east-1" \
  -var="cluster_oidc_provider_arn=arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE" \
  -var="cluster_oidc_provider_url=oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE" \
  -var="backend_api_key=your-datadog-or-grafana-key"

# Get the IRSA role ARN for Helm
terraform output irsa_role_arn
```

Then deploy the collector:

```bash
cd ../../platforms/kubernetes/helm

helm install otel-collector open-telemetry/opentelemetry-collector \
  -f values-agent.yaml \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(cd ../../terraform/aws && terraform output -raw irsa_role_arn)
```

### Azure (AKS + Workload Identity)

```bash
cd terraform/azure

terraform init
terraform apply \
  -var="resource_group_name=my-rg" \
  -var="aks_cluster_name=my-aks" \
  -var="aks_oidc_issuer_url=$(az aks show -g my-rg -n my-aks --query oidcIssuerProfile.issuerUrl -o tsv)" \
  -var="key_vault_name=ollystack-kv" \
  -var="backend_api_key=your-api-key"

# Get the Managed Identity client ID for Helm
terraform output managed_identity_client_id
```

Then deploy:

```bash
helm install otel-collector open-telemetry/opentelemetry-collector \
  -f values-agent.yaml \
  --set serviceAccount.annotations."azure\.workload\.identity/client-id"=$(cd ../../terraform/azure && terraform output -raw managed_identity_client_id) \
  --set podLabels."azure\.workload\.identity/use"=true
```

### GCP (GKE + Workload Identity)

```bash
cd terraform/gcp

terraform init
terraform apply \
  -var="project_id=my-project" \
  -var="gke_cluster_name=my-gke" \
  -var="backend_api_key=your-api-key"

# Get the GCP SA email for Helm
terraform output service_account_email
```

Then deploy:

```bash
helm install otel-collector open-telemetry/opentelemetry-collector \
  -f values-agent.yaml \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=$(cd ../../terraform/gcp && terraform output -raw service_account_email)
```

## Module Versions

| Module | Version | Notes |
|--------|---------|-------|
| terraform-aws-modules/eks/aws | ~> 21.0 | EKS cluster + node groups |
| terraform-aws-modules/vpc/aws | ~> 6.0 | VPC networking |
| EKS Kubernetes | 1.35 | Latest standard-support version |
| Node AMI | AL2023_x86_64_STANDARD | Amazon Linux 2023 (AL2 is EOL) |

## What Each Module Creates

### AWS (`terraform/aws/`)

| Resource | Purpose |
|----------|---------|
| IAM Role (IRSA) | Assumed by collector pods via EKS OIDC federation |
| IAM Policy: X-Ray | `xray:PutTraceSegments`, `xray:PutTelemetryRecords` |
| IAM Policy: CloudWatch | `cloudwatch:PutMetricData`, `logs:PutLogEvents`, `cloudwatch:GetMetricData` |
| IAM Policy: Secrets Manager | `secretsmanager:GetSecretValue` (scoped to specific secret) |
| IAM Policy: S3 (optional) | `s3:PutObject`, `s3:GetObject` for telemetry archival |
| Secrets Manager Secret | Stores backend API key |
| CloudWatch Log Group (optional) | `/ollystack/collector` with configurable retention |
| S3 Bucket (optional) | Encrypted, private, with Glacier lifecycle |

### AWS Test Cluster (`terraform/aws-test-cluster/`)

| Resource | Purpose |
|----------|---------|
| VPC + 2 public subnets | Minimal networking (no NAT gateway) |
| EKS Cluster (K8s 1.35) | Control plane with public endpoint |
| Managed Node Group | 1x t3.small AL2023 node |
| Cluster Addons | vpc-cni, coredns, kube-proxy, eks-pod-identity-agent |
| OIDC Provider | Feeds into terraform/aws/ for IRSA |

### Azure (`terraform/azure/`)

| Resource | Purpose |
|----------|---------|
| User-Assigned Managed Identity | Assumed by collector pods via AKS Workload Identity |
| Federated Identity Credential | Scoped to namespace + ServiceAccount |
| Role: Monitoring Metrics Publisher | Send custom metrics to Azure Monitor |
| Role: Monitoring Reader | Read metrics (azuremonitor receiver) |
| Role: Log Analytics Contributor (optional) | Write to Log Analytics workspace |
| Role: Storage Blob Data Contributor (optional) | Write to archive storage |
| Key Vault | Stores backend API key with RBAC authorization |
| Log Analytics Workspace (optional) | Configurable retention |
| Storage Account (optional) | TLS 1.2, private, with blob container |

### GCP (`terraform/gcp/`)

| Resource | Purpose |
|----------|---------|
| Service Account | Used by collector via GKE Workload Identity |
| Workload Identity Binding | `roles/iam.workloadIdentityUser` scoped to namespace + SA |
| Role: Cloud Trace Agent | Send traces to Cloud Trace |
| Role: Monitoring Metric Writer | Send metrics to Cloud Monitoring |
| Role: Monitoring Viewer | Read metrics (googlecloudmonitoring receiver) |
| Role: Logging Writer | Send logs to Cloud Logging |
| Role: Secret Manager Accessor | Read backend API key |
| Role: Storage Object Creator (optional) | Write to archive bucket |
| Secret Manager Secret | Stores backend API key |
| Cloud Storage Bucket (optional) | Uniform access, Coldline lifecycle |

## Variables Reference

### Common Variables (all modules)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `namespace` | No | `observability` | K8s namespace for the collector |
| `service_account_name` | No | `otel-collector` | K8s ServiceAccount name |
| `backend_api_key` | No | `""` | Backend API key (stored in secret store) |

### AWS-Specific

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `cluster_name` | **Yes** | — | EKS cluster name |
| `cluster_oidc_provider_arn` | **Yes** | — | EKS OIDC provider ARN |
| `cluster_oidc_provider_url` | **Yes** | — | EKS OIDC provider URL (without `https://`) |
| `region` | No | `us-east-1` | AWS region |
| `create_s3_archive_bucket` | No | `false` | Create S3 archive bucket |
| `s3_archive_bucket_name` | If archive | — | Globally unique bucket name |

### Azure-Specific

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `resource_group_name` | **Yes** | — | Azure Resource Group |
| `aks_cluster_name` | **Yes** | — | AKS cluster name |
| `aks_oidc_issuer_url` | **Yes** | — | AKS OIDC issuer URL |
| `key_vault_name` | **Yes** | — | Key Vault name (globally unique, 3-24 chars) |
| `location` | No | `eastus` | Azure region |
| `create_storage_account` | No | `false` | Create archive storage |

### GCP-Specific

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_id` | **Yes** | — | GCP project ID |
| `gke_cluster_name` | **Yes** | — | GKE cluster name |
| `region` | No | `us-central1` | GCP region |
| `create_archive_bucket` | No | `false` | Create archive bucket |
| `archive_bucket_name` | If archive | — | Globally unique bucket name |

## Outputs

Each module outputs values that feed directly into Helm:

| Output | AWS | Azure | GCP |
|--------|-----|-------|-----|
| **Identity** | `irsa_role_arn` | `managed_identity_client_id` | `service_account_email` |
| **Secret** | `secret_arn` / `secret_name` | `key_vault_name` / `key_vault_uri` | `secret_name` |
| **Archive** | `s3_archive_bucket` | `storage_account_name` | `archive_bucket_name` |
| **Helm snippet** | `helm_values_snippet` | `helm_values_snippet` | `helm_values_snippet` |

## State Management

For production, store Terraform state remotely:

```hcl
# Add to main.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "ollystack/aws/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Full Deployment Workflow

```bash
# 1. Provision infrastructure (one-time per cluster)
cd terraform/aws
terraform init && terraform apply

# 2. Deploy collector (repeatable)
cd ../../platforms/kubernetes/helm
helmfile sync

# 3. Verify
cd ../../deploy
./test-telemetry.sh
```

## Cleanup (Test Cluster)

```bash
# Destroy in reverse order
cd terraform/aws
terraform destroy

cd ../aws-test-cluster
terraform destroy
```
