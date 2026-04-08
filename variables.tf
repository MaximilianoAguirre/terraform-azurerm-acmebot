variable "resource_group_name" {
  description = "Name of the resource group where resources will be deployed"
  type        = string
}

variable "app_name_prefix" {
  description = "The name of the function app to create. Used as prefix for all resource names (max 14 characters)"
  type        = string

  validation {
    condition     = length(var.app_name_prefix) <= 14
    error_message = "app_name_prefix must be 14 characters or less."
  }
}

variable "location" {
  description = "Location for all resources. Defaults to the resource group location if not specified"
  type        = string
  default     = null
}

variable "mail_address" {
  description = "Email address for the ACME account"
  type        = string
}

variable "acme_endpoint" {
  description = "Certification authority ACME endpoint"
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"

  validation {
    condition = contains([
      "https://acme-v02.api.letsencrypt.org/directory",
      "https://acme.zerossl.com/v2/DV90/",
      "https://dv.acme-v02.api.pki.goog/directory",
      "https://acme.entrust.net/acme2/directory",
      "https://emea.acme.atlas.globalsign.com/directory"
    ], var.acme_endpoint)
    error_message = "acme_endpoint must be one of the supported ACME endpoints."
  }
}

variable "create_with_key_vault" {
  description = "Whether to create and configure a Key Vault alongside the function app"
  type        = bool
  default     = true
}

variable "key_vault_sku_name" {
  description = "Key Vault SKU tier"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku_name)
    error_message = "key_vault_sku_name must be 'standard' or 'premium'."
  }
}

variable "key_vault_base_url" {
  description = "Base URL of an existing Key Vault (e.g. https://example.vault.azure.net). Used when create_with_key_vault is false"
  type        = string
  default     = ""
}

variable "additional_app_settings" {
  description = "Additional name/value pairs appended to the function app's app settings"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "azure_dns_zones" {
  description = "List of Azure DNS zone resource IDs to grant the function app DNS Zone Contributor access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the deployment"
  type        = map(string)
  default     = {}
}

variable "auth_enabled" {
  description = "Whether to create an Azure AD app registration and configure App Service Authentication on the function app"
  type        = bool
  default     = true
}

variable "allowed_principals" {
  description = "List of principals to grant Acmebot app roles. Set issue and/or revoke to control which roles are assigned."
  type = list(object({
    object_id = string
    type      = string
    issue     = optional(bool, true)
    revoke    = optional(bool, true)
  }))
  default = []

  validation {
    condition     = alltrue([for p in var.allowed_principals : contains(["User", "Group", "ServicePrincipal"], p.type)])
    error_message = "Each principal type must be 'User', 'Group', or 'ServicePrincipal'."
  }
}

variable "template_version" {
  description = "Acmebot ARM template version to deploy: 'v4' (stable) or 'v5' (preview)"
  type        = string
  default     = "v4"

  validation {
    condition     = contains(["v4", "v5"], var.template_version)
    error_message = "template_version must be 'v4' or 'v5'."
  }
}
