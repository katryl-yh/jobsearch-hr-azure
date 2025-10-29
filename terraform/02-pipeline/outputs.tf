# Test outputs to verify data sources are working
output "test_locals" {
  description = "Test all locals from infrastructure"
  value = {
    resource_group_name     = local.resource_group_name
    container_registry_name = local.container_registry_name
    storage_account_name    = local.storage_account_name
    file_share_name        = local.file_share_name
  }
}

output "container_group_fqdn" {
  description = "FQDN of the container group"
  value       = azurerm_container_group.dagster_pipeline.fqdn
}

output "container_group_ip" {
  description = "Public IP address of the container group"
  value       = azurerm_container_group.dagster_pipeline.ip_address
}

output "dagster_ui_url" {
  description = "URL to access Dagster UI"
  value       = "http://${azurerm_container_group.dagster_pipeline.fqdn}:3000"
}

output "container_name" {
  description = "Name of the deployed container"
  value       = azurerm_container_group.dagster_pipeline.name
}

output "container_group_name" {
  description = "Name of the container group"
  value       = azurerm_container_group.dagster_pipeline.name
}