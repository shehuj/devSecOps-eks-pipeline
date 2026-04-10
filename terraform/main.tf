# Module orchestration — ordered by dependency chain:
#   vpc → eks → iam (needs EKS OIDC) → ecr (independent)

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "eks" {
  source             = "./modules/eks"
  project_name       = var.project_name
  environment        = var.environment
  aws_region         = var.aws_region
  cluster_version    = var.eks_cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  depends_on = [module.vpc]
}

module "iam" {
  source                            = "./modules/iam"
  project_name                      = var.project_name
  environment                       = var.environment
  aws_region                        = var.aws_region
  github_org                        = var.github_org
  github_repo                       = var.github_repo
  existing_github_actions_role_name = var.existing_github_actions_role_name
  eks_oidc_provider_url             = module.eks.oidc_provider_url
  eks_oidc_provider_arn             = module.eks.oidc_provider_arn

  depends_on = [module.eks]
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
  environment  = var.environment
}
