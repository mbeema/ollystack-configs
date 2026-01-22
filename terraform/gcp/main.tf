# ============================================================================
# OllyStack — GCP Infrastructure for OTel Collector
# ============================================================================
# Creates:
#   1. GCP Service Account with Workload Identity binding for GKE
#   2. IAM roles for Cloud Trace, Cloud Monitoring, Cloud Logging
#   3. Secret Manager secret for backend API keys
#   4. Cloud Storage bucket for telemetry archival (optional)
#
# Prerequisites:
#   - GKE cluster with Workload Identity enabled:
#       gcloud container clusters update CLUSTER --workload-pool=PROJECT.svc.id.goog
#   - Terraform authenticated to GCP (gcloud auth application-default login)
#
# Usage:
#   terraform init
#   terraform apply \
#     -var="project_id=my-project" \
#     -var="gke_cluster_name=my-gke"
# ============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Service Account ──────────────────────────────────────────────────────────
# GCP Service Account that the OTel Collector uses via Workload Identity.
# The K8s ServiceAccount is bound to this GCP SA.

resource "google_service_account" "otel_collector" {
  account_id   = "ollystack-otel-collector"
  display_name = "OllyStack OTel Collector"
  description  = "Service account for OpenTelemetry Collector (Workload Identity)"
  project      = var.project_id
}

# ── Workload Identity Binding ────────────────────────────────────────────────
# Allows the K8s ServiceAccount to impersonate the GCP Service Account.
# Scoped to specific namespace and ServiceAccount name.

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.otel_collector.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.service_account_name}]"
}

# ── IAM Roles ────────────────────────────────────────────────────────────────

# Cloud Trace Agent — send traces
resource "google_project_iam_member" "trace_agent" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# Monitoring Metric Writer — send metrics
resource "google_project_iam_member" "monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# Monitoring Viewer — read metrics (for googlecloudmonitoring receiver)
resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# Logging Writer — send logs
resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# Secret Manager Secret Accessor — read backend API key
resource "google_project_iam_member" "secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# Storage Object Creator — write to archive bucket (conditional)
resource "google_project_iam_member" "storage_creator" {
  count   = var.create_archive_bucket ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.otel_collector.email}"
}

# ── Secret Manager ───────────────────────────────────────────────────────────
# Stores the backend API key. The collector reads this via the GCP Secret
# Manager CSI Driver or workload code.

resource "google_secret_manager_secret" "backend_api_key" {
  secret_id = "ollystack-backend-api-key"
  project   = var.project_id

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "backend_api_key" {
  count       = var.backend_api_key != "" ? 1 : 0
  secret      = google_secret_manager_secret.backend_api_key.id
  secret_data = var.backend_api_key
}

# ── Cloud Storage Archive (optional) ─────────────────────────────────────────

resource "google_storage_bucket" "archive" {
  count                       = var.create_archive_bucket ? 1 : 0
  name                        = var.archive_bucket_name
  location                    = var.region
  project                     = var.project_id
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = var.archive_lifecycle_days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  labels = var.labels
}
