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
  # Sensitive outputs will be accessed directly when needed
}

############################################################
# Azure Container Instance for Dagster pipeline
############################################################

# Azure Container Instance for Dagster pipeline
resource "azurerm_container_group" "dagster_pipeline" {
  name                = local.pipeline_container_name
  location            = local.location
  resource_group_name = local.resource_group_name
  ip_address_type     = "Public"
  dns_name_label      = "${local.pipeline_container_name}-${random_string.suffix.result}"
  os_type             = "Linux"
  restart_policy      = "OnFailure"  # Restart only on failure

  container {
    name   = local.pipeline_container_name
    image  = "${local.container_registry_login_server}/${local.pipeline_container_name}"
    cpu    = var.cpu_cores
    memory = var.memory_gb

    ports {
      port     = 3000
      protocol = "TCP"
    }

    # Environment variables for Dagster
    environment_variables = {
      DUCKDB_PATH          = var.duckdb_path
      # DAGSTER_HOME         = var.dagster_home  # disabled for cost-fix, DAGSTER_HOME -> /tmp/dagster_home
      DBT_PROFILES_DIR     = var.dbt_profiles_dir
    }

    # Add liveness and readiness probes
    liveness_probe {
      http_get {
        path = "/"
        port = 3000
      }
      initial_delay_seconds = 120
      period_seconds        = 60
      timeout_seconds       = 10
      failure_threshold     = 10
    }

    readiness_probe {
      http_get {
        path   = "/"
        port   = 3000
        scheme = "http"
      }
      initial_delay_seconds = 10
      period_seconds        = 10
      timeout_seconds       = 5
      success_threshold     = 1
      failure_threshold     = 3
    }

    # Mount Azure File Share for persistent DuckDB storage
    volume {
      name       = "duckdb-storage"
      mount_path = "/mnt"
      read_only  = false

      storage_account_name = local.storage_account_name
      storage_account_key  = data.terraform_remote_state.infrastructure.outputs.storage_account_primary_key
      share_name          = local.file_share_name
    }
  } 
    

  # Use ACR credentials for private registry access
  image_registry_credential {
    server   = local.container_registry_login_server
    username = data.terraform_remote_state.infrastructure.outputs.container_registry_admin_username
    password = data.terraform_remote_state.infrastructure.outputs.container_registry_admin_password
  }

  tags = var.tags
}

# Random suffix for unique DNS names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

############################################################
# End of file
############################################################