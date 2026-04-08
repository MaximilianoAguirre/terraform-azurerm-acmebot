output "function_app_name" {
  description = "The generated function app name"
  value       = local.arm_output.functionAppName.value
}

output "principal_id" {
  description = "The managed identity principal ID of the function app"
  value       = local.arm_output.principalId.value
}

output "tenant_id" {
  description = "The managed identity tenant ID of the function app"
  value       = local.arm_output.tenantId.value
}

output "key_vault_name" {
  description = "The Key Vault name if created, otherwise empty string"
  value       = local.arm_output.keyVaultName.value
}

output "deployment_id" {
  description = "The ID of the ARM template deployment"
  value       = azurerm_resource_group_template_deployment.acmebot.id
}

output "application_id" {
  description = "The Azure AD application (client) ID for the Acmebot app registration"
  value       = var.auth_enabled ? azuread_application.acmebot[0].client_id : null
}

output "application_object_id" {
  description = "The Azure AD application object ID, for external role assignments"
  value       = var.auth_enabled ? azuread_application.acmebot[0].object_id : null
}
