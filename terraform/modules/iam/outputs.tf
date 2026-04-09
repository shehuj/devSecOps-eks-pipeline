output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC — add to GitHub Secrets as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "app_irsa_role_arn" {
  description = "IRSA role ARN for Flask app pods"
  value       = aws_iam_role.app_irsa.arn
}
