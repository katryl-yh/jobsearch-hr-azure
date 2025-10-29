output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "container_registry_name" {
  description = "Name of the container registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Login server URL of the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the container registry"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "container_registry_admin_password" {
  description = "Admin password for the container registry"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_primary_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "file_share_name" {
  description = "Name of the file share"
  value       = azurerm_storage_share.data.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

output "pipeline_container_name" {
  description = "Name of the pipeline container"
  value = var.pipeline_container_name
}

output "dashboard_container_name" {
  description = "Name of the dashboard container"
  value = var.dashboard_container_name
}

output "duckdb_path" {
  description = "Path to the DuckDB database"
  value       = var.duckdb_path
}
