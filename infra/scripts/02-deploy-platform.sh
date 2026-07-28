#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/../terraform/platform" && pwd)"

command -v az >/dev/null || { echo "Azure CLI is required." >&2; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required." >&2; exit 1; }

az account show >/dev/null
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"

if [[ ! -f "$PLATFORM_DIR/backend.hcl" ]]; then
  echo "Missing $PLATFORM_DIR/backend.hcl. Run 01-bootstrap-state.sh first." >&2
  exit 1
fi

if [[ ! -f "$PLATFORM_DIR/terraform.tfvars" ]]; then
  echo "Missing terraform.tfvars. Copy terraform.tfvars.example and set admin_source_cidr." >&2
  exit 1
fi

if [[ -z "${TF_VAR_linux_admin_ssh_public_key:-}" ]]; then
  echo "TF_VAR_linux_admin_ssh_public_key is not set." >&2
  exit 1
fi

if [[ -z "${TF_VAR_windows_admin_password:-}" ]]; then
  echo "TF_VAR_windows_admin_password is not set." >&2
  exit 1
fi

terraform -chdir="$PLATFORM_DIR" init -upgrade -reconfigure -backend-config=backend.hcl
terraform -chdir="$PLATFORM_DIR" fmt -check
terraform -chdir="$PLATFORM_DIR" validate
terraform -chdir="$PLATFORM_DIR" plan -out=tfplan

echo
echo "Review the plan above. Type APPLY to create the Azure resources."
read -r confirmation
if [[ "$confirmation" != "APPLY" ]]; then
  echo "Cancelled."
  exit 1
fi

terraform -chdir="$PLATFORM_DIR" apply tfplan
terraform -chdir="$PLATFORM_DIR" output
