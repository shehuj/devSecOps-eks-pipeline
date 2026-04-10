data "aws_caller_identity" "current" {}

# ── GitHub Actions OIDC Provider ───────────────────────────────────────────────
# Pre-existing — read only, not managed by this Terraform

data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

# ── GitHub Actions IAM Role (existing) ────────────────────────────────────────
# Using pre-existing role — not managed by this Terraform

data "aws_iam_role" "github_actions" {
  name = var.existing_github_actions_role_name
}

# ── App IRSA Role ──────────────────────────────────────────────────────────────
# Allows Flask pods in the prod namespace to assume this role

data "aws_iam_policy_document" "app_irsa_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.eks_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:prod:flask-store"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.eks_oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_irsa" {
  name               = "${var.project_name}-${var.environment}-app-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.app_irsa_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-app-irsa-role"
  }
}
