# Terraform AzureRM AcmeBot

Terraform module that deploys [Acmebot](https://github.com/polymind-inc/acmebot) via its ARM template. Acmebot is an Azure Function App that automates SSL/TLS certificate issuance and renewal using the ACME protocol (Let's Encrypt, ZeroSSL, Google Trust Services, etc.) with Azure Key Vault storage.

## How it works

1. An Azure Function App is deployed with the Acmebot application
2. Certificates are requested via the Acmebot dashboard (`https://<func>.azurewebsites.net/dashboard`)
3. Acmebot performs DNS-01 validation by creating `_acme-challenge` TXT records in the configured DNS zones
4. Issued certificates are stored in Azure Key Vault
5. A timer trigger automatically renews certificates approaching expiry
6. Azure services (App Service, Front Door, Application Gateway, etc.) consume certificates from Key Vault

## Usage

### Basic

```hcl
module "ssl_certs" {
  source = "./modules/ssl-certs"

  resource_group_name = "rg-acmebot"
  app_name_prefix     = "acmebot"
  mail_address        = "admin@example.com"
  tags                = { environment = "production" }
}
```

### With Azure DNS integration

```hcl
module "acmebot" {
  source = "MaximilianoAguirre/terraform-azurerm-acmebot"

  resource_group_name = "rg-acmebot"
  app_name_prefix     = "acmebot"
  mail_address        = "admin@example.com"

  azure_dns_zones = [
    "/subscriptions/xxx/resourceGroups/rg-dns/providers/Microsoft.Network/dnszones/example.com",
    "/subscriptions/xxx/resourceGroups/rg-dns/providers/Microsoft.Network/dnszones/example.org",
  ]
}
```

When `azure_dns_zones` is provided, the module automatically:
- Configures the `Acmebot__AzureDns__SubscriptionId` app setting
- Assigns the **DNS Zone Contributor** role to the function app's managed identity on each zone

### With Azure AD authentication

```hcl
module "acmebot" {
  source = "MaximilianoAguirre/terraform-azurerm-acmebot"

  resource_group_name = "rg-acmebot"
  app_name_prefix     = "acmebot"
  mail_address        = "admin@example.com"

  # Grant dashboard access to specific users and groups
  allowed_principals = [
    { object_id = "aaaa-bbbb-cccc-dddd", type = "User" },                          # both roles (default)
    { object_id = "eeee-ffff-0000-1111", type = "Group" },                          # both roles (default)
    { object_id = "2222-3333-4444-5555", type = "User", issue = true, revoke = false }, # issue only
  ]
}
```

When `auth_enabled` is `true` (the default), the module:
- Creates an Azure AD app registration with `Acmebot.IssueCertificate` and `Acmebot.RevokeCertificate` app roles
- Configures App Service Authentication (v2) on the function app with Azure AD as the identity provider
- Assigns both app roles to each principal in `allowed_principals`

Set `auth_enabled = false` to skip authentication setup entirely.

### With an existing Key Vault

```hcl
module "acmebot" {
  source = "MaximilianoAguirre/terraform-azurerm-acmebot"

  resource_group_name   = "rg-acmebot"
  app_name_prefix       = "acmebot"
  mail_address          = "admin@example.com"
  create_with_key_vault = false
  key_vault_base_url    = "https://my-keyvault.vault.azure.net"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.0, < 2.0 |
| <a name="requirement_azapi"></a> [azapi](#requirement_azapi) | ~> 2.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement_azuread) | ~> 3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement_azurerm) | ~> 4.0 |
| <a name="requirement_http"></a> [http](#requirement_http) | ~> 3.0 |



## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_name_prefix"></a> [app_name_prefix](#input_app_name_prefix) | The name of the function app to create. Used as prefix for all resource names (max 14 characters) | `string` | n/a | yes |
| <a name="input_mail_address"></a> [mail_address](#input_mail_address) | Email address for the ACME account | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource_group_name](#input_resource_group_name) | Name of the resource group where resources will be deployed | `string` | n/a | yes |
| <a name="input_acme_endpoint"></a> [acme_endpoint](#input_acme_endpoint) | Certification authority ACME endpoint | `string` | `"https://acme-v02.api.letsencrypt.org/directory"` | no |
| <a name="input_additional_app_settings"></a> [additional_app_settings](#input_additional_app_settings) | Additional name/value pairs appended to the function app's app settings | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_allowed_principals"></a> [allowed_principals](#input_allowed_principals) | List of principals to grant Acmebot app roles. Set issue and/or revoke to control which roles are assigned. | <pre>list(object({<br/>    object_id = string<br/>    type      = string<br/>    issue     = optional(bool, true)<br/>    revoke    = optional(bool, true)<br/>  }))</pre> | `[]` | no |
| <a name="input_auth_enabled"></a> [auth_enabled](#input_auth_enabled) | Whether to create an Azure AD app registration and configure App Service Authentication on the function app | `bool` | `true` | no |
| <a name="input_azure_dns_zones"></a> [azure_dns_zones](#input_azure_dns_zones) | List of Azure DNS zone resource IDs to grant the function app DNS Zone Contributor access | `list(string)` | `[]` | no |
| <a name="input_create_with_key_vault"></a> [create_with_key_vault](#input_create_with_key_vault) | Whether to create and configure a Key Vault alongside the function app | `bool` | `true` | no |
| <a name="input_key_vault_base_url"></a> [key_vault_base_url](#input_key_vault_base_url) | Base URL of an existing Key Vault (e.g. https://example.vault.azure.net). Used when create_with_key_vault is false | `string` | `""` | no |
| <a name="input_key_vault_sku_name"></a> [key_vault_sku_name](#input_key_vault_sku_name) | Key Vault SKU tier | `string` | `"standard"` | no |
| <a name="input_location"></a> [location](#input_location) | Location for all resources. Defaults to the resource group location if not specified | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input_tags) | Tags to apply to the deployment | `map(string)` | `{}` | no |
| <a name="input_template_version"></a> [template_version](#input_template_version) | Acmebot ARM template version to deploy: 'v4' (stable) or 'v5' (preview) | `string` | `"v4"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_id"></a> [application_id](#output_application_id) | The Azure AD application (client) ID for the Acmebot app registration |
| <a name="output_application_object_id"></a> [application_object_id](#output_application_object_id) | The Azure AD application object ID, for external role assignments |
| <a name="output_deployment_id"></a> [deployment_id](#output_deployment_id) | The ID of the ARM template deployment |
| <a name="output_function_app_name"></a> [function_app_name](#output_function_app_name) | The generated function app name |
| <a name="output_key_vault_name"></a> [key_vault_name](#output_key_vault_name) | The Key Vault name if created, otherwise empty string |
| <a name="output_principal_id"></a> [principal_id](#output_principal_id) | The managed identity principal ID of the function app |
| <a name="output_tenant_id"></a> [tenant_id](#output_tenant_id) | The managed identity tenant ID of the function app |
<!-- END_TF_DOCS -->
