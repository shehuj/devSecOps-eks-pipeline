data "aws_caller_identity" "current" {}

# ── GitHub Actions OIDC Provider ───────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable — GitHub rotates but keeps this in the list)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project_name}-${var.environment}-github-oidc"
  }
}

# ── GitHub Actions IAM Role ────────────────────────────────────────────────────

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      # Scoped to all branches/tags in this repo — tighten to :ref:refs/heads/main for prod
      values = ["repo:${var.github_org}/${var.github_repo}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-${var.environment}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-github-actions-role"
  }
}

# Policy: ECR push (build-and-push job)
data "aws_iam_policy_document" "ecr_push" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeRepositories",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "${var.project_name}-${var.environment}-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
}

# Policy: EKS access for deploy jobs
data "aws_iam_policy_document" "eks_access" {
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:AccessKubernetesApi",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_access" {
  name   = "${var.project_name}-${var.environment}-eks-access"
  policy = data.aws_iam_policy_document.eks_access.json
}

# Policy: Terraform state (S3 + DynamoDB) for workflow-infra.yml
data "aws_iam_policy_document" "tf_state" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::devsecops-eks-pipeline-tfstate",
      "arn:aws:s3:::devsecops-eks-pipeline-tfstate/*",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/devsecops-eks-pipeline-tflock",
    ]
  }
}

resource "aws_iam_policy" "tf_state" {
  name   = "${var.project_name}-${var.environment}-tf-state"
  policy = data.aws_iam_policy_document.tf_state.json
}

# Policy: broad infra permissions for Terraform to manage VPC/EKS/ECR/IAM
# Scope this down further for production workloads
resource "aws_iam_role_policy_attachment" "github_actions_ec2" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.eks_access.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_cluster" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "github_actions_tf_state" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.tf_state.arn
}

# IAM permissions — required for Terraform to create node roles, OIDC provider, IRSA
data "aws_iam_policy_document" "iam_manage" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:PassRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "iam_manage" {
  name   = "${var.project_name}-${var.environment}-iam-manage"
  policy = data.aws_iam_policy_document.iam_manage.json
}

resource "aws_iam_role_policy_attachment" "github_actions_iam_manage" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.iam_manage.arn
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
