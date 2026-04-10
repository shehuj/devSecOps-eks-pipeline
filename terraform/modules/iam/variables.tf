variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "existing_github_actions_role_name" {
  description = "Name of the pre-existing IAM role for GitHub Actions (not managed by this Terraform)"
  type        = string
  default     = "prod-GitHubActionsRole"
}

variable "eks_oidc_provider_url" {
  description = "EKS cluster OIDC provider URL (for IRSA)"
  type        = string
}

variable "eks_oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN (for IRSA)"
  type        = string
}
