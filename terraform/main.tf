############################################################
# Resource Group
############################################################

# Create a resource group using the generated random name
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "rg${random_string.suffix.result}"
}

############################################################
# Storage Account
############################################################

resource "azurerm_storage_account" "storage" {
  name                     = "storage${random_string.suffix.result}"
  account_tier             = "Standard"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_replication_type = "LRS"

  #tags = { environment = "staging" }
}

############################################################
# File Share
############################################################

# Create a file share inside the storage account
resource "azurerm_storage_share" "fileshare" {
  name                 = "fileshare${random_string.suffix.result}"
  storage_account_id   = azurerm_storage_account.storage.id
  quota                = 50 # size in GB (adjust as needed)
}

############################################################
# Container Registry
############################################################

resource "azurerm_container_registry" "acr" {
  name                = "acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

############################################################
# App Service Plan
############################################################

resource "azurerm_service_plan" "asp" {
  name                = "asp${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "B1"
}