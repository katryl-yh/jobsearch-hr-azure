############################################################
# Resource Group
############################################################

# Create a resource group using the generated random name
resource "azurerm_resource_group" "main" {
  location = var.resource_group_location
  name     = "arg${random_string.suffix.result}"
}

############################################################
# Container Registry
############################################################

resource "azurerm_container_registry" "main" {
  name                = "acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

############################################################
# Storage Account
############################################################

resource "azurerm_storage_account" "main" {
  name                     = "asa${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

############################################################
# File Share
############################################################

# Create a file share inside the storage account
resource "azurerm_storage_share" "data" {
  name                 = "ass${random_string.suffix.result}"
  storage_account_id   = azurerm_storage_account.main.id
  quota                = 50
}

############################################################
# File Share Directories
############################################################
# Create required folders in the file share

resource "azurerm_storage_share_directory" "dagster_home" {
  name                 = "dagster_home"
  storage_share_id     = azurerm_storage_share.data.url
  #depends_on           = [azurerm_storage_share.data]
}

resource "azurerm_storage_share_directory" "dbt" {
  name                 = ".dbt"
  storage_share_id     = azurerm_storage_share.data.url
  #depends_on           = [azurerm_storage_share.data]
}

resource "azurerm_storage_share_directory" "data" {
  name                 = "data"
  storage_share_id     = azurerm_storage_share.data.url
  #depends_on           = [azurerm_storage_share.data]
}

############################################################
# .env File Generation
############################################################

# Generate .env files from templates using Terraform outputs
resource "local_file" "env_dashboard" {
  filename = "${path.root}/../../.env.dashboard"
  content = templatefile("${path.module}/templates/env.dashboard.tpl", {
    acr_name       = azurerm_container_registry.main.name
    container_name = var.dashboard_container_name
    tag           = var.image_tag
    duckdb_path   = var.duckdb_path
  })
}

resource "local_file" "env_pipeline" {
  filename = "${path.root}/../../.env.pipeline"
  content = templatefile("${path.module}/templates/env.pipeline.tpl", {
    acr_name       = azurerm_container_registry.main.name
    container_name = var.pipeline_container_name
    tag           = var.image_tag
    duckdb_path   = var.duckdb_path
  })
}

############################################################
# dbt profiles.yml Generation
############################################################

resource "local_file" "profiles" {
  filename = "${path.root}/profiles.yml"
  content = templatefile("${path.module}/templates/profiles.tpl", {
    duckdb_path   = var.duckdb_path
  })
}

resource "azurerm_storage_share_file" "profiles" {
  name                 = "profiles.yml"
  storage_share_id     = azurerm_storage_share.data.url
  path                 = ".dbt"  # Directory path within the share
  source               = "${path.root}/profiles.yml"
}