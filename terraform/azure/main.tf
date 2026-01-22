# ============================================================================
# OllyStack — Azure Infrastructure for OTel Collector
# ============================================================================
# Creates:
#   1. User-Assigned Managed Identity with AKS Workload Identity federation
#   2. Role assignments for Azure Monitor, Log Analytics
#   3. Key Vault with secret for backend API keys
#   4. Log Analytics workspace (optional)
#   5. Storage Account for telemetry archival (optional)
#
# Prerequisites:
#   - AKS cluster with OIDC issuer enabled:
#       az aks update -g <rg> -n <cluster> --enable-oidc-issuer --enable-workload-identity
#   - Terraform authenticated to Azure (az login or service principal)
#
# Usage:
#   terraform init
#   terraform apply \
#     -var="resource_group_name=my-rg" \
#     -var="aks_cluster_name=my-aks" \
#     -var="aks_oidc_issuer_url=https://eastus.oic.prod-aks.azure.com/..." \
#     -var="key_vault_name=ollystack-kv"
# ============================================================================

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.45"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

data "azurerm_subscription" "current" {}

# ── User-Assigned Managed Identity ───────────────────────────────────────────
# The OTel Collector pods assume this identity via AKS Workload Identity.
# Federated credential scopes the identity to a specific namespace + SA.

resource "azurerm_user_assigned_identity" "otel_collector" {
  name                = "ollystack-otel-collector"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "otel_collector" {
  name                = "ollystack-otel-collector-federated"
  resource_group_name = data.azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.otel_collector.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
}

# ── Role Assignments ─────────────────────────────────────────────────────────

# Monitoring Metrics Publisher — send custom metrics to Azure Monitor
resource "azurerm_role_assignment" "monitoring_publisher" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.otel_collector.principal_id
}

# Monitoring Reader — read metrics (for azuremonitor receiver)
resource "azurerm_role_assignment" "monitoring_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_user_assigned_identity.otel_collector.principal_id
}

# Log Analytics Contributor — write to Log Analytics workspace
resource "azurerm_role_assignment" "log_analytics_contributor" {
  count                = var.create_log_analytics_workspace ? 1 : 0
  scope                = azurerm_log_analytics_workspace.collector[0].id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.otel_collector.principal_id
}

# Storage Blob Data Contributor — write to archive storage
resource "azurerm_role_assignment" "storage_contributor" {
  count                = var.create_storage_account ? 1 : 0
  scope                = azurerm_storage_account.archive[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.otel_collector.principal_id
}

# ── Key Vault ────────────────────────────────────────────────────────────────
# Stores backend API keys. The collector reads secrets via the Azure Key
# Vault CSI Driver or environment variables from ExternalSecrets.

resource "azurerm_key_vault" "this" {
  name                       = var.key_vault_name
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true
  tags                       = var.tags
}

# Grant the Managed Identity read access to Key Vault secrets
resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.otel_collector.principal_id
}

# Grant the Terraform caller admin access to manage secrets
resource "azurerm_role_assignment" "keyvault_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store the backend API key
resource "azurerm_key_vault_secret" "backend_api_key" {
  count        = var.backend_api_key != "" ? 1 : 0
  name         = "ollystack-backend-api-key"
  value        = var.backend_api_key
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.keyvault_secrets_officer]
}

# ── Log Analytics Workspace (optional) ───────────────────────────────────────

resource "azurerm_log_analytics_workspace" "collector" {
  count               = var.create_log_analytics_workspace ? 1 : 0
  name                = "ollystack-collector-logs"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

# ── Storage Account for Archive (optional) ───────────────────────────────────

resource "azurerm_storage_account" "archive" {
  count                    = var.create_storage_account ? 1 : 0
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.this.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "telemetry" {
  count                 = var.create_storage_account ? 1 : 0
  name                  = "telemetry-archive"
  storage_account_id    = azurerm_storage_account.archive[0].id
  container_access_type = "private"
}
