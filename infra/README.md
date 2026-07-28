# Durable Money Azure infrastructure

This starter creates:

- One Ubuntu 24.04 VM.
- One Windows Server 2022 VM.
- One AKS cluster using Azure CNI Overlay.
- Kubernetes namespaces for Development, Staging, Production, and the Octopus Kubernetes Agent.
- Azure Blob Storage for remote Terraform state.
- Administrative inbound access restricted to one public IPv4 CIDR.

## Local prerequisites on macOS

```bash
brew update
brew install azure-cli terraform kubectl

az login
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID_OR_NAME"
az account show --output table
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

## Generate an SSH key

```bash
ssh-keygen -t ed25519 -f "$HOME/.ssh/durable_money_azure" -C "durable-money-azure"
```

## Configure local variables

```bash
cd infra/terraform/platform
cp terraform.tfvars.example terraform.tfvars

MY_IP="$(curl -4 -s https://ifconfig.me)"
echo "$MY_IP"
```

Edit `terraform.tfvars` and set:

```hcl
admin_source_cidr = "YOUR_IP/32"
```

Then set sensitive variables in the current shell:

```bash
export TF_VAR_linux_admin_ssh_public_key="$(cat "$HOME/.ssh/durable_money_azure.pub")"
read -s "TF_VAR_windows_admin_password?Windows administrator password: "
export TF_VAR_windows_admin_password
echo
```

The password must meet Windows complexity rules. Use at least 14 characters with uppercase, lowercase, a number, and a symbol.

## Deploy

From the repository root:

```bash
./infra/scripts/01-bootstrap-state.sh
./infra/scripts/02-deploy-platform.sh
./infra/scripts/03-configure-aks.sh
./infra/scripts/04-show-access.sh
```

## Verify Linux

```bash
ssh -i "$HOME/.ssh/durable_money_azure" \
  azureadmin@"$(terraform -chdir=infra/terraform/platform output -raw linux_public_ip)"

ls -la /opt/durable-money
exit
```

## Verify Windows

Get the IP:

```bash
terraform -chdir=infra/terraform/platform output -raw windows_public_ip
```

On macOS, install Microsoft Windows App from the App Store, add a PC using that IP, and sign in with `azureadmin` and the password supplied to Terraform.

Verify these directories in PowerShell:

```powershell
Get-ChildItem C:\Apps\DurableMoney
Get-NetFirewallRule -DisplayName "Durable Money application ports"
```

## Verify AKS

```bash
kubectl get nodes -o wide
kubectl get namespaces
kubectl get resourcequota -A
```

## Destroy compute resources

```bash
./infra/scripts/99-destroy-platform.sh
```

Keep the Terraform state resource group until you no longer need the state. Delete it separately only after the platform has been destroyed.
