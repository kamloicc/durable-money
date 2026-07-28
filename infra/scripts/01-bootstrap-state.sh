#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(cd "$SCRIPT_DIR/../terraform/bootstrap" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/../terraform/platform" && pwd)"

command -v az >/dev/null || { echo "Azure CLI is required." >&2; exit 1; }
command -v terraform >/dev/null || { echo "Terraform is required." >&2; exit 1; }

az account show >/dev/null
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"

terraform -chdir="$BOOTSTRAP_DIR" init -upgrade
terraform -chdir="$BOOTSTRAP_DIR" fmt -check
terraform -chdir="$BOOTSTRAP_DIR" validate
terraform -chdir="$BOOTSTRAP_DIR" plan -out=tfplan
terraform -chdir="$BOOTSTRAP_DIR" apply tfplan

terraform -chdir="$BOOTSTRAP_DIR" output -raw backend_hcl > "$PLATFORM_DIR/backend.hcl"
chmod 600 "$PLATFORM_DIR/backend.hcl"

cat <<MESSAGE

Terraform backend created.
Generated: $PLATFORM_DIR/backend.hcl

The Storage Blob Data Contributor role can take several minutes to become effective.
Continue with infra/scripts/02-deploy-platform.sh.
MESSAGE
