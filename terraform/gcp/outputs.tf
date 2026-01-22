# ============================================================================
# OllyStack — GCP Outputs
# ============================================================================

output "service_account_email" {
  description = "GCP Service Account email (use as iam.gke.io/gcp-service-account annotation)"
  value       = google_service_account.otel_collector.email
}

output "service_account_name" {
  description = "GCP Service Account resource name"
  value       = google_service_account.otel_collector.name
}

output "secret_name" {
  description = "Secret Manager secret name for the backend API key"
  value       = google_secret_manager_secret.backend_api_key.secret_id
}

output "archive_bucket_name" {
  description = "Cloud Storage bucket name for telemetry archival"
  value       = var.create_archive_bucket ? google_storage_bucket.archive[0].name : ""
}

output "helm_values_snippet" {
  description = "Helm values to wire up Workload Identity (copy into your values file)"
  value       = <<-EOT
    # Add to your Helm values file (platforms/kubernetes/helm/values-agent.yaml):
    serviceAccount:
      create: true
      name: ${var.service_account_name}
      annotations:
        iam.gke.io/gcp-service-account: ${google_service_account.otel_collector.email}

    # Environment variables for the collector:
    extraEnvs:
      - name: GCP_PROJECT_ID
        value: ${var.project_id}
  EOT
}
