# DevSecOps EKS Pipeline

End-to-end DevSecOps pipeline: **code → scan → build → deploy** to AWS EKS using Terraform and GitHub Actions.

## Stack

| Layer | Technology |
|-------|-----------|
| App | Python Flask (flask-store) |
| Container registry | Amazon ECR |
| Container orchestration | Amazon EKS (Kubernetes 1.30) |
| Infrastructure as Code | Terraform ~> 5.0 |
| CI/CD | GitHub Actions |
| Helm | flask-store chart (dev / staging / prod values) |

## Pipeline Overview

```
Push to main/dev
       │
       ├─ [secret-scan]  TruffleHog — verified secrets only
       ├─ [sast]         Bandit — Python HIGH/HIGH severity gate
       ├─ [sca]          Safety + Dependency Review
       ├─ [iac-scan]     Hadolint + Checkov + Trivy config
       └─ [unit-tests]   pytest
              │
              ▼ (all pass)
       [build-and-push]  Docker build → Trivy image scan → ECR push + SBOM
              │
              ▼
       [deploy-staging]  helm upgrade --atomic → staging namespace
              │
              ▼
       [smoke-test]      /health + /products curl checks
              │
              ▼ (main branch only)
       [manual approval] GitHub environment gate
              │
              ▼
       [deploy-prod]     helm upgrade --atomic → prod namespace
```

**Infrastructure workflow** (`workflow-infra.yml`): IaC scan → tf validate → tf plan → manual approval → tf apply

**Nightly workflow** (`workflow-security.yml`): Gitleaks full history + OWASP DepCheck + Trivy ECR + Checkov CIS

## Repository Structure

```
├── .github/workflows/
│   ├── workflow-app.yml        # Main CI/CD pipeline
│   ├── workflow-infra.yml      # Terraform EKS provisioning
│   └── workflow-security.yml  # Nightly deep scans
├── app/
│   ├── src/                    # Flask application source
│   ├── tests/                  # pytest unit tests
│   ├── Dockerfile              # Multi-stage, non-root, Alpine
│   └── requirements*.txt
├── helm/flask-store/           # Helm chart with dev/staging/prod values
├── terraform/
│   ├── modules/
│   │   ├── vpc/                # VPC, 3 public + 3 private subnets, NAT
│   │   ├── eks/                # EKS cluster, managed node group, OIDC
│   │   ├── ecr/                # ECR repo with lifecycle policy
│   │   └── iam/                # GitHub Actions OIDC role, IRSA role
│   └── *.tf                    # Root module orchestration
└── scripts/
    ├── bootstrap-tf-backend.sh # One-time S3 + DynamoDB setup
    └── update-kubeconfig.sh    # Local kubeconfig helper
```

## Quick Start

### 1. Bootstrap (run once locally)

```bash
# Prerequisites: AWS CLI, Terraform >= 1.9, kubectl, Helm 3

# Create S3 state bucket + DynamoDB lock table
chmod +x scripts/bootstrap-tf-backend.sh
./scripts/bootstrap-tf-backend.sh

# Copy and fill in variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars — set github_org = "shehuj"
```

### 2. Provision Infrastructure

```bash
cd terraform/
terraform init
terraform plan
terraform apply

# Note the outputs — you'll need these as GitHub Secrets:
# - github_actions_role_arn  → AWS_ROLE_ARN
# - ecr_repository_url       → ECR_REPOSITORY
```

### 3. Configure GitHub Secrets

In your repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | Output from `terraform output github_actions_role_arn` |
| `ECR_REPOSITORY` | Output from `terraform output ecr_repository_url` (repo name only, not full URL) |

### 4. Configure GitHub Environments

Settings → Environments → Create:
- `staging` — no required reviewers (auto-deploy)
- `production` — add yourself as required reviewer

### 5. Push and watch the pipeline

```bash
git add .
git commit -m "initial commit"
git push origin main
```

## Local Development

```bash
cd app/
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt -r requirements-dev.txt

# Run tests
pytest tests/ -v

# Run locally
python -m src.app
# → http://localhost:5000/health
# → http://localhost:5000/products
```

## Accessing the Cluster

```bash
./scripts/update-kubeconfig.sh
kubectl get nodes
kubectl get pods -n staging
kubectl get pods -n prod
```

## Security Controls

See [SECURITY.md](SECURITY.md) for the full scan gate matrix and infrastructure hardening details.
