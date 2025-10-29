variable "resource_group_location" {
  type        = string
  default     = "swedencentral"
  description = "Location of the resource group."
}

variable "container_name" {
  description = "Name of the Azure Container Instance"
  type        = string
  default     = "jobmarket-pipeline"
}

variable "dashboard_container_name" {
  description = "Name of the dashboard container"
  type        = string
  default     = "jobmarket-dashboard"
}

variable "pipeline_container_name" {
  description = "Name of the pipeline container"
  type        = string
  default     = "jobmarket-pipeline"
}

variable "image_name" {
  description = "Docker image name"
  type        = string
  default     = "jobmarket-pipeline:latest"
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "duckdb_path" {
  description = "Path to DuckDB database file"
  type        = string
  default     = "/mnt/data/job_ads.duckdb"
}