# ============================================================================
# OllyStack — Minimal-Cost EKS Test Cluster (Auto Mode)
# ============================================================================
# Throwaway cluster for end-to-end testing:
#   terraform apply → quick-start.sh → test-telemetry.sh → terraform destroy
#
# Cost: ~$2.40/day (EKS control plane only — compute is on-demand per pod)
#       Destroy immediately after testing!
#
# Architecture:
#   - EKS Auto Mode — AWS manages compute, networking, and storage
#   - No node groups, no ASGs, no launch templates
#   - Nodes are provisioned on-demand when pods are scheduled
#   - 2 public subnets (no NAT gateway — saves $1.08/day)
#   - Public API endpoint
#   - OIDC provider enabled (feeds IRSA into terraform/aws/ module)
#   - Deploy: ~8-10 min | Destroy: ~5 min
# ============================================================================

terraform {
  required_version = ">= 1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# ── VPC ──────────────────────────────────────────────────────────────────────
# Minimal networking: 2 public subnets, no NAT gateway, no private subnets.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs            = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # No private subnets, no NAT gateway — saves $1.08/day
  enable_nat_gateway = false
  enable_vpn_gateway = false

  # Nodes need public IPs since there's no NAT gateway
  map_public_ip_on_launch = true

  # Required tags for EKS auto-discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = 1
    "kubernetes.io/cluster/${var.cluster_name}"      = "shared"
  }

  tags = {
    Project   = "ollystack"
    ManagedBy = "terraform"
    Purpose   = "test-cluster"
  }
}

# ── EKS Cluster (Auto Mode) ─────────────────────────────────────────────────
# Auto Mode: AWS manages compute, networking addons, and storage.
# No node groups needed — nodes are provisioned when pods are scheduled.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Public endpoint only — no need for private access in a test cluster
  endpoint_public_access  = true
  endpoint_private_access = false

  # No CloudWatch logging — saves cost
  enabled_log_types = []

  # OIDC provider for IRSA (feeds into terraform/aws/ module)
  enable_irsa = true

  # Allow current caller to administer the cluster
  enable_cluster_creator_admin_permissions = true

  # ── Auto Mode ────────────────────────────────────────────────────────────
  # Enables EKS Auto Mode: AWS manages compute (NodePools), networking
  # (vpc-cni, coredns, kube-proxy), and storage (EBS CSI) automatically.
  # No eks_managed_node_groups needed.
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  tags = {
    Project   = "ollystack"
    ManagedBy = "terraform"
    Purpose   = "test-cluster"
  }
}
