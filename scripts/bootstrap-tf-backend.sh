#!/usr/bin/env bash
# bootstrap-tf-backend.sh
#
# Run ONCE before `terraform init` to create the S3 state bucket and DynamoDB
# lock table. Requires AWS CLI configured with credentials that have S3 + DynamoDB
# permissions.
#
# Usage:
#   chmod +x scripts/bootstrap-tf-backend.sh
#   ./scripts/bootstrap-tf-backend.sh

set -euo pipefail

BUCKET="bathbucket31"
TABLE="dyning_table"
REGION="us-east-1"

echo "==> Bootstrapping Terraform backend"
echo "    Bucket : $BUCKET"
echo "    Table  : $TABLE"
echo "    Region : $REGION"
echo ""

# ── S3 Bucket ──────────────────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "[SKIP] Bucket $BUCKET already exists"
else
  echo "[CREATE] S3 bucket: $BUCKET"
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION"

  # Block all public access
  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  # Enable versioning (allows state recovery)
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  # Enable server-side encryption
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'

  echo "[OK] Bucket $BUCKET created and hardened"
fi

# ── DynamoDB Lock Table ────────────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "$TABLE" --region "$REGION" 2>/dev/null; then
  echo "[SKIP] DynamoDB table $TABLE already exists"
else
  echo "[CREATE] DynamoDB table: $TABLE"
  aws dynamodb create-table \
    --table-name "$TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

  echo "[WAIT] Waiting for table to become active..."
  aws dynamodb wait table-exists --table-name "$TABLE" --region "$REGION"
  echo "[OK] DynamoDB table $TABLE ready"
fi

echo ""
echo "==> Bootstrap complete. Next steps:"
echo "    1. Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars"
echo "    2. Fill in your values (github_org, etc.)"
echo "    3. cd terraform && terraform init"
echo "    4. terraform apply (first run — creates OIDC role + EKS cluster)"
echo "    5. Copy the 'github_actions_role_arn' output to GitHub Secrets as AWS_ROLE_ARN"
echo "    6. Copy the 'ecr_repository_url' output to GitHub Secrets as ECR_REPOSITORY"
