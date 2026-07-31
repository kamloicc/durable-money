# Durable Money Octopus deployment assets

This directory contains source-controlled deployment assets used by Octopus Deploy.

## Package scripts

- `package/linux/Deploy.sh` is copied to the root of the Linux monolith package.
- `package/windows/Deploy.ps1` is copied to the root of the Windows monolith package.

Octopus automatically executes a root-level `Deploy.sh` or `Deploy.ps1` during a
Deploy a Package step. The package scripts configure and health-check the
environment-specific service.

## Kubernetes manifest

- `kubernetes/monolith.yaml` is consumed by the Octopus Deploy Kubernetes YAML step.

The manifest intentionally contains Octopus variable expressions. Secrets remain
in Octopus and are substituted during deployment; do not commit secret values.

## Source-of-truth rules

1. Change scripts or manifests through a pull request.
2. Pull-request builds validate the assets but publish nothing.
3. A merge to `main` packages the scripts with the application and creates the
   Octopus release.
4. Never edit the packaged scripts directly on a deployment target.
5. Sensitive project variables remain stored in Octopus.
