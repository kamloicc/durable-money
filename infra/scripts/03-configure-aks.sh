#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/../terraform/platform" && pwd)"
NAMESPACE_FILE="$(cd "$SCRIPT_DIR/../kubernetes/bootstrap" && pwd)/namespaces.yaml"

command -v az >/dev/null || { echo "Azure CLI is required." >&2; exit 1; }
command -v kubectl >/dev/null || { echo "kubectl is required." >&2; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required." >&2; exit 1; }

RESOURCE_GROUP="$(terraform -chdir="$PLATFORM_DIR" output -raw resource_group_name)"
AKS_NAME="$(terraform -chdir="$PLATFORM_DIR" output -raw aks_cluster_name)"

az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_NAME" \
  --admin \
  --overwrite-existing

kubectl apply -f "$NAMESPACE_FILE"

echo
kubectl get nodes -o wide
kubectl get namespaces
kubectl get resourcequota -A
