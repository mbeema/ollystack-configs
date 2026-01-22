# ============================================================================
# OllyStack — Azure Infrastructure Variables
# ============================================================================

variable "resource_group_name" {
  description = "Azure Resource Group for OllyStack resources"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "aks_cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL (az aks show --query oidcIssuerProfile.issuerUrl)"
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

# ── Key Vault ────────────────────────────────────────────────────────────────

variable "key_vault_name" {
  description = "Name of the Azure Key Vault (must be globally unique, 3-24 chars)"
  type        = string
}

variable "backend_api_key" {
  description = "API key for the observability backend. Stored in Key Vault."
  type        = string
  sensitive   = true
  default     = ""
}

# ── Log Analytics (optional) ─────────────────────────────────────────────────

variable "create_log_analytics_workspace" {
  description = "Create a Log Analytics workspace for collector logs"
  type        = bool
  default     = false
}

variable "log_analytics_retention_days" {
  description = "Retention period for the Log Analytics workspace"
  type        = number
  default     = 30
}

# ── Blob Storage archive (optional) ─────────────────────────────────────────

variable "create_storage_account" {
  description = "Create a Storage Account for telemetry archival"
  type        = bool
  default     = false
}

variable "storage_account_name" {
  description = "Storage account name (must be globally unique, 3-24 chars, lowercase alphanumeric)"
  type        = string
  default     = ""
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
