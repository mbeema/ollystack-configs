# ============================================================================
# OllyStack — EKS Test Cluster Variables (Auto Mode)
# ============================================================================
# Minimal variables — Auto Mode handles compute automatically.
# ============================================================================

variable "region" {
  description = "AWS region (us-east-1 is cheapest for EKS)"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "ollystack-test"
}
