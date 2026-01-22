# ============================================================================
# OllyStack — GCP Infrastructure Variables
# ============================================================================

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
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

# ── Secret Manager ───────────────────────────────────────────────────────────

variable "backend_api_key" {
  description = "API key for the observability backend. Stored in Secret Manager."
  type        = string
  sensitive   = true
  default     = ""
}

# ── Cloud Storage archive (optional) ─────────────────────────────────────────

variable "create_archive_bucket" {
  description = "Create a Cloud Storage bucket for telemetry archival"
  type        = bool
  default     = false
}

variable "archive_bucket_name" {
  description = "Cloud Storage bucket name (must be globally unique)"
  type        = string
  default     = ""
}

variable "archive_lifecycle_days" {
  description = "Days before transitioning archived telemetry to Coldline"
  type        = number
  default     = 90
}

# ── Labels ───────────────────────────────────────────────────────────────────

variable "labels" {
  description = "Labels applied to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    project    = "ollystack"
    component  = "otel-collector"
  }
}
