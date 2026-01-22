# ============================================================================
# OllyStack — AWS Infrastructure Variables
# ============================================================================

variable "cluster_name" {
  description = "EKS cluster name (used for OIDC provider lookup)"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (e.g., arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE)"
  type        = string
}

variable "cluster_oidc_provider_url" {
  description = "URL of the EKS OIDC provider without https:// (e.g., oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the OTel Collector runs"
  type        = string
  default     = "observability"
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name for the OTel Collector"
  type        = string
  default     = "otel-collector"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# ── Backend secrets ──────────────────────────────────────────────────────────

variable "backend_api_key" {
  description = "API key for the observability backend (Datadog, Grafana Cloud, etc.). Stored in Secrets Manager."
  type        = string
  sensitive   = true
  default     = ""
}

variable "backend_api_key_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
  default     = "ollystack/backend-api-key"
}

# ── CloudWatch ───────────────────────────────────────────────────────────────

variable "create_cloudwatch_log_group" {
  description = "Create a CloudWatch Log Group for the collector's own logs"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Retention period for the collector CloudWatch log group"
  type        = number
  default     = 30
}

# ── S3 archive (optional) ───────────────────────────────────────────────────

variable "create_s3_archive_bucket" {
  description = "Create an S3 bucket for telemetry archival"
  type        = bool
  default     = false
}

variable "s3_archive_bucket_name" {
  description = "Name of the S3 archive bucket (must be globally unique)"
  type        = string
  default     = ""
}

variable "s3_archive_lifecycle_days" {
  description = "Days before transitioning archived telemetry to Glacier"
  type        = number
  default     = 90
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "ollystack"
    Component = "otel-collector"
  }
}
