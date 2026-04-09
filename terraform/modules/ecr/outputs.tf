output "repository_url" {
  description = "ECR repository URL — used as image.repository in Helm values"
  value       = aws_ecr_repository.flask_store.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.flask_store.arn
}
