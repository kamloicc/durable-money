output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "linux_vm_name" {
  value = azurerm_linux_virtual_machine.linux.name
}

output "linux_public_ip" {
  value = azurerm_public_ip.linux.ip_address
}

output "linux_ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.linux.ip_address}"
}

output "windows_vm_name" {
  value = azurerm_windows_virtual_machine.windows.name
}

output "windows_public_ip" {
  value = azurerm_public_ip.windows.ip_address
}

output "windows_rdp_target" {
  value = azurerm_public_ip.windows.ip_address
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.platform.name
}

output "aks_get_credentials_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.platform.name} --name ${azurerm_kubernetes_cluster.platform.name} --admin --overwrite-existing"
}

output "post_apply_commands" {
  value = <<-EOT
    az aks get-credentials --resource-group ${azurerm_resource_group.platform.name} --name ${azurerm_kubernetes_cluster.platform.name} --admin --overwrite-existing
    kubectl apply -f ../../kubernetes/bootstrap/namespaces.yaml
    kubectl get nodes
    kubectl get namespaces
  EOT
}
