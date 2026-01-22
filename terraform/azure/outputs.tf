# ============================================================================
# OllyStack — Azure Outputs
# ============================================================================

output "managed_identity_client_id" {
  description = "Client ID of the Managed Identity (use as azure.workload.identity/client-id annotation)"
  value       = azurerm_user_assigned_identity.otel_collector.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the Managed Identity"
  value       = azurerm_user_assigned_identity.otel_collector.principal_id
}

output "managed_identity_id" {
  description = "Resource ID of the Managed Identity"
  value       = azurerm_user_assigned_identity.otel_collector.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.this.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.this.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.collector[0].workspace_id : ""
}

output "storage_account_name" {
  description = "Storage Account name for telemetry archival"
  value       = var.create_storage_account ? azurerm_storage_account.archive[0].name : ""
}

output "helm_values_snippet" {
  description = "Helm values to wire up Workload Identity (copy into your values file)"
  value       = <<-EOT
    # Add to your Helm values file (platforms/kubernetes/helm/values-agent.yaml):
    serviceAccount:
      create: true
      name: ${var.service_account_name}
      annotations:
        azure.workload.identity/client-id: ${azurerm_user_assigned_identity.otel_collector.client_id}
      labels:
        azure.workload.identity/use: "true"

    podLabels:
      azure.workload.identity/use: "true"
  EOT
}
