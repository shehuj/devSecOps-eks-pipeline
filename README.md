# DevSecOps EKS Pipeline

End-to-end DevSecOps pipeline: **code → scan → build → deploy** to AWS EKS using Terraform and GitHub Actions.

## Stack

| Layer | Technology |
|-------|-----------|
| App | Python Flask (flask-store) |
| Container registry | Amazon ECR (`talatwo-flask-store`) |
| Container orchestration | Amazon EKS (`talatwo-dev`, Kubernetes 1.33) |
| Infrastructure as Code | Terraform ~> 5.0 |
| CI/CD | GitHub Actions |
| Helm | flask-store chart (dev values) |

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
       [deploy-dev]      helm upgrade --atomic → dev namespace
              │
              ▼
       [smoke-test]      /health + /products curl checks
```

**Infrastructure workflow** (`workflow-infra.yml`): IaC scan → tf validate → tf plan → manual approval → tf apply

**Nightly workflow** (`workflow-security.yml`): Gitleaks full history + OWASP DepCheck + Trivy ECR + Checkov CIS

**Cleanup workflow** (`workflow-cleanup.yml`): Manual teardown — undeploy apps → drain ECR → terraform destroy → (optional) destroy backend

## Workflows Summary

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `workflow-app.yml` | Push to `main`/`dev`, PR | Secret scan + SAST + SCA + IaC scan + unit tests → build → dev → smoke test |
| `workflow-infra.yml` | Push to `main`/`dev` (`terraform/**`), manual | IaC scan → tf validate → tf plan → manual approval → tf apply |
| `workflow-security.yml` | Nightly 02:00 UTC, manual | Gitleaks + OWASP DepCheck + Trivy ECR + Checkov CIS benchmark |
| `workflow-cleanup.yml` | Manual only | Undeploy Helm releases → drain ECR → terraform destroy → (optional) destroy S3/DynamoDB backend |

## Repository Structure

```
├── .github/workflows/
│   ├── workflow-app.yml        # Main CI/CD pipeline
│   ├── workflow-infra.yml      # Terraform EKS provisioning
│   ├── workflow-security.yml  # Nightly deep scans
│   └── workflow-cleanup.yml   # Full teardown (manual)
├── app/
│   ├── src/                    # Flask application source
│   ├── tests/                  # pytest unit tests
│   ├── Dockerfile              # Multi-stage, non-root, Alpine
│   └── requirements*.txt
├── helm/flask-store/           # Helm chart with dev values
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
# Creates: talatwo-pipeline-tfstate (S3) + talatwo-pipeline-tflock (DynamoDB)

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
# Creates: talatwo-dev EKS cluster, talatwo-flask-store ECR repo, VPC, IAM

# Note the outputs — you'll need these as GitHub Secrets:
# - github_actions_role_arn  → AWS_ROLE_ARN
# - ecr_repository_url       → ECR_REPOSITORY
```

### 3. Configure GitHub Secrets

In your repo → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_REGION` | `us-east-1` |
| `AWS_ROLE_ARN` | Output from `terraform output github_actions_role_arn` |

### 4. Configure GitHub Environment

Settings → Environments → Create:
- `dev` — add yourself as required reviewer (gates deploys and cleanup)

### 5. Push and watch the pipeline

```bash
git add .
git commit -m "initial commit"
git push origin dev
```

## AWS IAM Role

The pipeline uses OIDC — no long-lived credentials. The role `prod-GitHubActionsRole` must:

1. Have a trust policy that allows `repo:shehuj/devSecOps-eks-pipeline:*`
2. Have the `TerraformDeploy` inline policy attached (covers ECR, EKS, KMS, IAM, VPC, CloudWatch Logs, S3, DynamoDB)

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
kubectl get pods -n dev
```

## Teardown

To destroy all AWS resources when done:

1. Go to **Actions → Cleanup — Undeploy & Destroy Infrastructure → Run workflow**
2. Type `talatwo-dev` in the confirmation field
3. Check **"Also destroy S3 state bucket + DynamoDB lock table?"** only if you want a full wipe
4. Approve the `dev` environment gate when prompted

**Teardown order:**

```
confirm (dev gate)
       │
       ├─ [undeploy-apps]  helm uninstall dev → delete namespace
       ├─ [drain-ecr]      delete all ECR image versions
       │
       └──────────────────── both complete ────────────────────┐
                                                               │
                                                        [tf-destroy]
                                                        terraform destroy
                                                        (EKS, VPC, IAM, ECR)
                                                               │
                                                    [destroy-backend] ← optional
                                                    delete S3 + DynamoDB
```

## Security Controls

See [SECURITY.md](SECURITY.md) for the full scan gate matrix and infrastructure hardening details.
