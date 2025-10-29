############################################################
# Retrieve outputs from the infrastructure layer
############################################################

# Use terraform_remote_state to access outputs from the infrastructure layer
data "terraform_remote_state" "infrastructure" {
  backend = "local"

  config = {
    path = "${path.module}/../01-infrastructure/terraform.tfstate"
  }
}

# Define locals for easier access to the outputs
locals {
  resource_group_name           = data.terraform_remote_state.infrastructure.outputs.resource_group_name
  container_registry_name       = data.terraform_remote_state.infrastructure.outputs.container_registry_name
  container_registry_login_server = data.terraform_remote_state.infrastructure.outputs.container_registry_login_server
  storage_account_name          = data.terraform_remote_state.infrastructure.outputs.storage_account_name
  file_share_name               = data.terraform_remote_state.infrastructure.outputs.file_share_name
  location                      = data.terraform_remote_state.infrastructure.outputs.location
  pipeline_container_name       = data.terraform_remote_state.infrastructure.outputs.pipeline_container_name
  duckdb_path                   = data.terraform_remote_state.infrastructure.outputs.duckdb_path
  dashboard_container_name       = data.terraform_remote_state.infrastructure.outputs.dashboard_container_name
  container_registry_admin_username = data.terraform_remote_state.infrastructure.outputs.container_registry_admin_username
  container_registry_admin_password = data.terraform_remote_state.infrastructure.outputs.container_registry_admin_password

  # Sensitive outputs will be accessed directly when needed
}

############################################################
# Retrieve storage account key directly
############################################################

data "azurerm_storage_account" "storage" {
  name                = local.storage_account_name
  resource_group_name = local.resource_group_name
}

############################################################
# App Service Plan
############################################################

resource "azurerm_service_plan" "asp" {
  name                = "asp${random_string.suffix.result}"
  resource_group_name = local.resource_group_name
  location            = local.location
  os_type             = "Linux"
  sku_name            = "B1"
}

############################################################
# Web App
############################################################

resource "azurerm_linux_web_app" "webapp" {
  name                = "alwa${random_string.suffix.result}"
  resource_group_name = local.resource_group_name
  location            = local.location
  service_plan_id     = azurerm_service_plan.asp.id

  site_config {
    always_on = false
    
    application_stack {
      docker_registry_username = local.container_registry_admin_username
      docker_registry_password = local.container_registry_admin_password
      docker_registry_url = "https://${local.container_registry_login_server}"
      docker_image_name   = "${local.dashboard_container_name}:latest"
    }

  }

  # Storage account mount for persistent data
  storage_account {
    name         = "database_mount"
    type         = "AzureFiles"
    account_name = local.storage_account_name
    share_name   = local.file_share_name
    access_key   = data.azurerm_storage_account.storage.primary_access_key
    mount_path   = "/mnt"  # Path inside the container where the volume will be mounted
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITES_PORT"                       = "8501"  # streamlit port
    "DUCKDB_PATH"                         = local.duckdb_path
  }

  # Optional: Configure authentication
  # auth_settings {
  #   enabled = true
  #   default_provider = "AzureActiveDirectory"
  # }
}
