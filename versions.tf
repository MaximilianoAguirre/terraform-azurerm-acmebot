terraform {
  required_version = ">= 1.9.0, < 2.0"

  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
    azapi   = { source = "azure/azapi", version = "~> 2.0" }
    http    = { source = "hashicorp/http", version = "~> 3.0" }
  }
}
