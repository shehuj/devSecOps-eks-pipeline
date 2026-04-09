output "ecr_repository_url" {
  description = "ECR repository URL — used as image.repository in Helm values"
  value       = module.ecr.repository_url
}

output "eks_cluster_name" {
  description = "EKS cluster name — used in aws eks update-kubeconfig"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — add to GitHub Secrets as AWS_ROLE_ARN"
  value       = module.iam.github_actions_role_arn
}

output "app_irsa_role_arn" {
  description = "IRSA role ARN for Flask app pods — add to Helm serviceAccount.annotations"
  value       = module.iam.app_irsa_role_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
