# OllyStack — Minimal-Cost EKS Test Cluster

Throwaway EKS cluster for end-to-end testing of the OllyStack deployment pipeline.

## Cost

| Resource | Hourly | Daily |
|---|---|---|
| EKS control plane | $0.10 | $2.40 |
| t3.small node (1x) | $0.021 | $0.50 |
| **Total** | **$0.121** | **~$3.00** |

No NAT gateway, no CloudWatch logging, no private subnets — every optional cost has been eliminated.

**Destroy immediately after testing.**

## Prerequisites

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with credentials
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

```bash
cd terraform/aws-test-cluster

# Create the cluster (~15 minutes)
terraform init
terraform apply

# Configure kubectl
eval "$(terraform output -raw update_kubeconfig_command)"

# Verify
kubectl get nodes
```

## Full Test Workflow

```bash
# 1. Provision the cluster
cd terraform/aws-test-cluster
terraform init && terraform apply

# 2. Configure kubectl
eval "$(terraform output -raw update_kubeconfig_command)"

# 3. (Optional) Provision IRSA for AWS-native backends
cd ../aws
terraform apply \
  -var="cluster_name=$(cd ../aws-test-cluster && terraform output -raw cluster_name)" \
  -var="cluster_oidc_provider_arn=$(cd ../aws-test-cluster && terraform output -raw oidc_provider_arn)" \
  -var="cluster_oidc_provider_url=$(cd ../aws-test-cluster && terraform output -raw oidc_provider_url)"

# 4. Deploy OllyStack and run tests
cd ../../deploy
./quick-start.sh
./test-telemetry.sh

# 5. DESTROY — do not leave running overnight!
cd ../terraform/aws-test-cluster
terraform destroy -auto-approve
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  VPC 10.0.0.0/16                            │
│  ┌──────────────┐  ┌──────────────┐         │
│  │ Public Subnet│  │ Public Subnet│         │
│  │  10.0.1.0/24 │  │  10.0.2.0/24 │         │
│  │    (AZ-a)    │  │    (AZ-b)    │         │
│  └──────┬───────┘  └──────┬───────┘         │
│         │                 │                 │
│         └────────┬────────┘                 │
│                  │                          │
│        ┌─────────┴─────────┐                │
│        │   EKS Cluster     │                │
│        │  (1x t3.small)    │                │
│        │  Public endpoint  │                │
│        │  OIDC enabled     │                │
│        └───────────────────┘                │
└─────────────────────────────────────────────┘
```

## Connecting to terraform/aws/ (IRSA)

This cluster's OIDC outputs feed directly into the main `terraform/aws/` module:

```bash
# From this cluster
OIDC_ARN=$(terraform output -raw oidc_provider_arn)
OIDC_URL=$(terraform output -raw oidc_provider_url)

# Into the IRSA module
cd ../aws
terraform apply \
  -var="cluster_name=ollystack-test" \
  -var="cluster_oidc_provider_arn=$OIDC_ARN" \
  -var="cluster_oidc_provider_url=$OIDC_URL"
```

## Customization

| Variable | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region (us-east-1 is cheapest) |
| `cluster_name` | `ollystack-test` | EKS cluster name |
| `node_instance_type` | `t3.small` | EC2 instance type |
| `node_count` | `1` | Number of worker nodes |
