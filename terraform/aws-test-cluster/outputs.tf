# ============================================================================
# OllyStack — EKS Test Cluster Outputs
# ============================================================================
# OIDC outputs feed directly into the terraform/aws/ IRSA module.
# ============================================================================

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS Kubernetes version"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — pass to terraform/aws/ as cluster_oidc_provider_arn"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL (without https://) — pass to terraform/aws/ as cluster_oidc_provider_url"
  value       = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
}

output "update_kubeconfig_command" {
  description = "Run this command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
