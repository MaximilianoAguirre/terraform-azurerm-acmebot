locals {
  arm_output = jsondecode(azurerm_resource_group_template_deployment.acmebot.output_content)

  function_app_name = local.arm_output.functionAppName.value
  function_app_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Web/sites/${local.function_app_name}"

  template_urls = {
    v4 = "https://raw.githubusercontent.com/polymind-inc/acmebot/master/deploy/azuredeploy_v4.json"
    v5 = "https://raw.githubusercontent.com/polymind-inc/acmebot/master/deploy/azuredeploy.json"
  }

  dns_app_settings = length(var.azure_dns_zones) > 0 ? [{
    name  = "Acmebot__AzureDns__SubscriptionId"
    value = data.azurerm_client_config.current.subscription_id
  }] : []

  location = coalesce(var.location, data.azurerm_resource_group.current.location)

  all_additional_app_settings = concat(local.dns_app_settings, var.additional_app_settings)

  parameters_content = jsonencode({
    location              = { value = local.location }
    appNamePrefix         = { value = var.app_name_prefix }
    mailAddress           = { value = var.mail_address }
    acmeEndpoint          = { value = var.acme_endpoint }
    createWithKeyVault    = { value = var.create_with_key_vault }
    keyVaultSkuName       = { value = var.key_vault_sku_name }
    keyVaultBaseUrl       = { value = var.key_vault_base_url }
    additionalAppSettings = { value = local.all_additional_app_settings }
  })
}

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "current" { name = var.resource_group_name }

data "http" "arm_template" {
  url             = local.template_urls[var.template_version]
  request_headers = { Accept = "application/json" }
}

resource "azurerm_role_assignment" "dns_zone_contributor" {
  for_each = toset(var.azure_dns_zones)

  scope                = each.value
  role_definition_name = "DNS Zone Contributor"
  principal_id         = jsondecode(azurerm_resource_group_template_deployment.acmebot.output_content).principalId.value
}

resource "azurerm_resource_group_template_deployment" "acmebot" {
  name                = "${var.app_name_prefix}-acmebot"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"
  template_content    = data.http.arm_template.response_body
  parameters_content  = local.parameters_content
  tags                = var.tags

  lifecycle {
    ignore_changes = [template_content]
  }
}

# ── Azure AD App Registration & Auth ─────────────────────────────────────────

resource "azuread_application" "acmebot" {
  count = var.auth_enabled ? 1 : 0

  display_name     = "${var.app_name_prefix}-acmebot"
  sign_in_audience = "AzureADMyOrg"

  app_role {
    allowed_member_types = ["User", "Application"]
    display_name         = "Issue Certificate"
    description          = "Allows issuing and renewing certificates"
    value                = "Acmebot.IssueCertificate"
    id                   = "00000000-0000-0000-0000-000000000001"
    enabled              = true
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    display_name         = "Revoke Certificate"
    description          = "Allows revoking certificates"
    value                = "Acmebot.RevokeCertificate"
    id                   = "00000000-0000-0000-0000-000000000002"
    enabled              = true
  }

  web {
    redirect_uris = ["https://${local.function_app_name}.azurewebsites.net/.auth/login/aad/callback"]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }
}

resource "azuread_service_principal" "acmebot" {
  count = var.auth_enabled ? 1 : 0

  client_id                    = azuread_application.acmebot[0].client_id
  app_role_assignment_required = true
}

resource "azuread_app_role_assignment" "issue_certificate" {
  for_each = var.auth_enabled ? { for idx, p in var.allowed_principals : idx => p if p.issue } : {}

  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.acmebot[0].object_id
  app_role_id         = "00000000-0000-0000-0000-000000000001"
}

resource "azuread_app_role_assignment" "revoke_certificate" {
  for_each = var.auth_enabled ? { for idx, p in var.allowed_principals : idx => p if p.revoke } : {}

  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.acmebot[0].object_id
  app_role_id         = "00000000-0000-0000-0000-000000000002"
}

resource "azapi_update_resource" "auth_settings" {
  count      = var.auth_enabled ? 1 : 0
  depends_on = [azurerm_resource_group_template_deployment.acmebot]

  type        = "Microsoft.Web/sites/config@2022-09-01"
  resource_id = "${local.function_app_id}/config/authsettingsV2"

  body = {
    properties = {
      login        = { tokenStore = { enabled = true } }
      platform     = { enabled = true, runtimeVersion = "~1" }
      httpSettings = { requireHttps = true, routes = { apiPrefix = "/.auth" } }

      globalValidation = {
        requireAuthentication       = true
        unauthenticatedClientAction = "RedirectToLoginPage"
        redirectToProvider          = "azureActiveDirectory"
      }

      identityProviders = { azureActiveDirectory = {
        enabled    = true
        validation = { allowedAudiences = ["api://${azuread_application.acmebot[0].client_id}"] }

        registration = {
          clientId     = azuread_application.acmebot[0].client_id
          openIdIssuer = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/v2.0"
        }
      } }
    }
  }
}
