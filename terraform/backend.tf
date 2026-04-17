# Remote state: S3 bucket + DynamoDB lock table
# Run scripts/bootstrap-tf-backend.sh once before terraform init

terraform {
  backend "s3" {
    bucket         = "talatwo-pipeline-tfstate"
    key            = "talatwo/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "talatwo-pipeline-tflock"
  }
}
