# Remote state: S3 bucket + DynamoDB lock table
# Run scripts/bootstrap-tf-backend.sh once before terraform init

terraform {
  backend "s3" {
    bucket         = "devsecops-eks-pipeline-tfstate"
    key            = "devsecops-eks-pipeline/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "devsecops-eks-pipeline-tflock"
  }
}
