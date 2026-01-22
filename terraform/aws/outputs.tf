# ============================================================================
# OllyStack — AWS Outputs
# ============================================================================
# These outputs feed into Helm values or Kubernetes manifests.
#
# Example usage with Helm:
#   helm install otel-collector open-telemetry/opentelemetry-collector \
#     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw irsa_role_arn)
# ============================================================================

output "irsa_role_arn" {
  description = "IAM Role ARN for the OTel Collector ServiceAccount (use as eks.amazonaws.com/role-arn annotation)"
  value       = aws_iam_role.otel_collector.arn
}

output "irsa_role_name" {
  description = "IAM Role name"
  value       = aws_iam_role.otel_collector.name
}

output "secret_arn" {
  description = "Secrets Manager secret ARN for the backend API key"
  value       = aws_secretsmanager_secret.backend_api_key.arn
}

output "secret_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.backend_api_key.name
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for the collector"
  value       = var.create_cloudwatch_log_group ? aws_cloudwatch_log_group.collector[0].name : ""
}

output "s3_archive_bucket" {
  description = "S3 bucket name for telemetry archival"
  value       = var.create_s3_archive_bucket ? aws_s3_bucket.archive[0].id : ""
}

output "s3_archive_bucket_arn" {
  description = "S3 bucket ARN for telemetry archival"
  value       = var.create_s3_archive_bucket ? aws_s3_bucket.archive[0].arn : ""
}

# ── Helm values snippet ─────────────────────────────────────────────────────

output "helm_values_snippet" {
  description = "Helm values to wire up the IRSA role (copy into your values file)"
  value       = <<-EOT
    # Add to your Helm values file (platforms/kubernetes/helm/values-agent.yaml):
    serviceAccount:
      create: true
      name: ${var.service_account_name}
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.otel_collector.arn}

    # Environment variables for the collector:
    extraEnvs:
      - name: AWS_REGION
        value: ${var.region}
      - name: AWS_STS_REGIONAL_ENDPOINTS
        value: regional
  EOT
}
