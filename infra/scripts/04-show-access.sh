#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/../terraform/platform" && pwd)"

terraform -chdir="$PLATFORM_DIR" output

echo
echo "Linux SSH command:"
terraform -chdir="$PLATFORM_DIR" output -raw linux_ssh_command
echo

echo "Windows RDP IP:"
terraform -chdir="$PLATFORM_DIR" output -raw windows_rdp_target
echo
