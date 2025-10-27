variable "resource_group_location" {
  type        = string
  default     = "swedencentral"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "storage_account_name_prefix" {
  type        = string
  default     = "st"
  description = "Prefix of the storage account name that's combined with a random ID so name is unique in your Azure subscription."
}