# Security Controls

## Scan Gates — workflow-app.yml

Every push to `main` or `dev` must pass all four scan jobs before a container is built or pushed.

| Job | Tool | Blocks build? | Report |
|-----|------|--------------|--------|
| `secret-scan` | TruffleHog v3 (`--only-verified`) | Yes — any verified secret | N/A |
| `sast` | Bandit 1.7.9 | Yes — HIGH severity + HIGH confidence | `bandit-report.json` artifact |
| `sca` | Safety 3.2.3 | Yes — any known CVE in requirements | `safety-report.json` artifact |
| `sca` | Dependency Review Action | Yes — CRITICAL new deps (PR only) | GitHub PR check |
| `iac-scan` | Hadolint | Yes — Dockerfile errors | Inline |
| `iac-scan` | Checkov | Yes — CRITICAL/HIGH misconfigs | GitHub Security tab (SARIF) |
| `iac-scan` | Trivy config | Yes — CRITICAL/HIGH in Terraform + Helm | GitHub Security tab (SARIF) |
| `build-and-push` | Trivy image | Yes — CRITICAL/HIGH in container | GitHub Security tab (SARIF) |
| `build-and-push` | Trivy SBOM | No — advisory | `sbom-<sha>.json` artifact (90d) |

## CVE Suppressions

Suppressions are tracked in `app/.trivyignore`. Each entry must include:
- CVE identifier
- Reason the CVE is not exploitable in this context
- Expiry date (review before expiry)

## Infrastructure Security

| Control | Implementation |
|---------|---------------|
| No long-lived AWS credentials | OIDC only (`id-token: write` + `role-to-assume`) |
| Least-privilege IAM | Scoped policies per role (ECR push, EKS access, TF state) |
| ECR image scanning | `scan_on_push = true` in `modules/ecr/main.tf` |
| EKS control plane logs | All log types enabled in `modules/eks/main.tf` |
| Node group in private subnets | Worker nodes unreachable from internet |
| Non-root container | `runAsNonRoot: true`, `runAsUser: 1000` in Helm values |
| Read-only root filesystem | `readOnlyRootFilesystem: true` + tmpfs mount for `/tmp` |
| No privilege escalation | `allowPrivilegeEscalation: false` + `capabilities.drop: ALL` |
| Production deployment gate | GitHub environment `production` with required reviewer |

## Nightly Scans — workflow-security.yml

Runs at 02:00 UTC daily. Results appear in the GitHub Security tab.

- **Gitleaks** — full git history scan for leaked secrets
- **OWASP Dependency Check** — cross-references NVD database (broader than Safety)
- **Trivy ECR** — scans the `:main` tag with `ignore-unfixed: false` to surface all issues
- **Checkov full** — Terraform + Helm + Dockerfile with CIS benchmark
