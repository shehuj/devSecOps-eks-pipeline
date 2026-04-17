#!/usr/bin/env bash
# update-kubeconfig.sh
#
# Convenience wrapper to update local kubeconfig for the EKS cluster.
# Requires: aws CLI, kubectl, and valid AWS credentials.
#
# Usage:
#   ./scripts/update-kubeconfig.sh
#   ./scripts/update-kubeconfig.sh --region eu-west-1

set -euo pipefail

CLUSTER_NAME="talatwo-dev"
REGION="${AWS_REGION:-us-east-1}"

# Allow region override via flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2 ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

echo "==> Updating kubeconfig"
echo "    Cluster : $CLUSTER_NAME"
echo "    Region  : $REGION"

aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION"

echo ""
echo "==> Verifying cluster access"
kubectl get nodes
