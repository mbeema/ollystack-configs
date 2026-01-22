# ============================================================================
# OllyStack — AWS Infrastructure for OTel Collector
# ============================================================================
# Creates:
#   1. IAM Role with IRSA trust policy (EKS pods assume this role)
#   2. IAM policies for X-Ray, CloudWatch, S3, Secrets Manager
#   3. Secrets Manager secret for backend API keys
#   4. CloudWatch Log Group (optional)
#   5. S3 bucket for telemetry archival (optional)
#
# Usage:
#   terraform init
#   terraform apply -var="cluster_name=my-cluster" \
#                   -var="cluster_oidc_provider_arn=arn:aws:iam::..." \
#                   -var="cluster_oidc_provider_url=oidc.eks..."
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

data "aws_caller_identity" "current" {}

# ── IAM Role (IRSA) ─────────────────────────────────────────────────────────
# The OTel Collector pods assume this role via IRSA (IAM Roles for Service
# Accounts). The trust policy scopes the role to a specific namespace and
# ServiceAccount — no other pod can assume it.

resource "aws_iam_role" "otel_collector" {
  name = "ollystack-otel-collector-${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.cluster_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.cluster_oidc_provider_url}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${var.cluster_oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# ── IAM Policy: X-Ray ───────────────────────────────────────────────────────
# Allows the collector to send traces to AWS X-Ray.

resource "aws_iam_role_policy" "xray" {
  name = "ollystack-xray"
  role = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "XRayWrite"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── IAM Policy: CloudWatch ──────────────────────────────────────────────────
# Allows the collector to send metrics (EMF) and logs to CloudWatch, and
# read CloudWatch metrics (for the awscloudwatch receiver).

resource "aws_iam_role_policy" "cloudwatch" {
  name = "ollystack-cloudwatch"
  role = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchMetricsWrite"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchMetricsRead"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsWrite"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ollystack/*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ollystack/*:*"
        ]
      }
    ]
  })
}

# ── IAM Policy: Secrets Manager (read-only) ─────────────────────────────────
# Allows the collector to read backend API keys from Secrets Manager.

resource "aws_iam_role_policy" "secrets" {
  name = "ollystack-secrets-read"
  role = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.backend_api_key.arn
        ]
      }
    ]
  })
}

# ── IAM Policy: S3 Archive (conditional) ────────────────────────────────────

resource "aws_iam_role_policy" "s3_archive" {
  count = var.create_s3_archive_bucket ? 1 : 0
  name  = "ollystack-s3-archive"
  role  = aws_iam_role.otel_collector.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArchiveWrite"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.archive[0].arn,
          "${aws_s3_bucket.archive[0].arn}/*"
        ]
      }
    ]
  })
}

# ── Secrets Manager ──────────────────────────────────────────────────────────
# Stores the backend API key. The collector reads this via the AWS Secrets
# Store CSI Driver or the External Secrets Operator.

resource "aws_secretsmanager_secret" "backend_api_key" {
  name                    = var.backend_api_key_name
  description             = "OllyStack OTel Collector backend API key"
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "backend_api_key" {
  count         = var.backend_api_key != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.backend_api_key.id
  secret_string = var.backend_api_key
}

# ── CloudWatch Log Group ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "collector" {
  count             = var.create_cloudwatch_log_group ? 1 : 0
  name              = "/ollystack/collector"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.tags
}

# ── S3 Archive Bucket (optional) ─────────────────────────────────────────────

resource "aws_s3_bucket" "archive" {
  count  = var.create_s3_archive_bucket ? 1 : 0
  bucket = var.s3_archive_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "archive" {
  count  = var.create_s3_archive_bucket ? 1 : 0
  bucket = aws_s3_bucket.archive[0].id

  rule {
    id     = "glacier-transition"
    status = "Enabled"

    transition {
      days          = var.s3_archive_lifecycle_days
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  count  = var.create_s3_archive_bucket ? 1 : 0
  bucket = aws_s3_bucket.archive[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "archive" {
  count  = var.create_s3_archive_bucket ? 1 : 0
  bucket = aws_s3_bucket.archive[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
