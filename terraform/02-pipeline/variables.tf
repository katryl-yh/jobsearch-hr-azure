variable "duckdb_path" {
  description = "Path to DuckDB file in mounted storage"
  type        = string
  default     = "/mnt/data/job_ads.duckdb"
}

variable "dagster_home" {
  description = "Path to Dagster home directory in mounted storage"
  type        = string
  default     = "/mnt/dagster_home"
}

variable "dbt_profiles_dir" {
  description = "Path to DBT profiles directory in mounted storage"
  type        = string
  default     = "/mnt/.dbt"
}

variable "cpu_cores" {
  description = "Number of CPU cores for the container"
  type        = number
  default     = 2
}

variable "memory_gb" {
  description = "Amount of memory in GB for the container"
  type        = number
  default     = 8
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "jobmarket-analytics"
    Component   = "pipeline"
  }
}