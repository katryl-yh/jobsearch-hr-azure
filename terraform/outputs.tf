output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "azurerm_storage_share_name" {
  value = azurerm_storage_share.fileshare.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "app_service_plan_name" {
  value = azurerm_service_plan.asp.name
}
