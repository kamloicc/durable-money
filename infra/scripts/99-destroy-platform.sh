#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/../terraform/platform" && pwd)"

terraform -chdir="$PLATFORM_DIR" plan -destroy -out=destroy.tfplan

echo
echo "Type DESTROY to delete the shared Azure platform."
read -r confirmation
if [[ "$confirmation" != "DESTROY" ]]; then
  echo "Cancelled."
  exit 1
fi

terraform -chdir="$PLATFORM_DIR" apply destroy.tfplan
