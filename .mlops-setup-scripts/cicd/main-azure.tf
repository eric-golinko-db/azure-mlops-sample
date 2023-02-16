resource "databricks_group" "mlops-service-principal-group-staging" {
  display_name = "azure-mlops-sample-service-principals"
  provider     = databricks.staging
}

resource "databricks_group" "mlops-service-principal-group-prod" {
  display_name = "azure-mlops-sample-service-principals"
  provider     = databricks.prod
}

module "azure_create_sp" {
  depends_on = [databricks_group.mlops-service-principal-group-staging, databricks_group.mlops-service-principal-group-prod]
  source     = "databricks/mlops-azure-project-with-sp-creation/databricks"
  providers = {
    databricks.staging = databricks.staging
    databricks.prod    = databricks.prod
    azuread            = azuread
  }
  service_principal_name       = "azure-mlops-sample-cicd"
  project_directory_path       = "/azure-mlops-sample"
  azure_tenant_id              = var.azure_tenant_id
  service_principal_group_name = "azure-mlops-sample-service-principals"
}

data "databricks_current_user" "staging_user" {
  provider = databricks.staging
}

provider "databricks" {
  alias = "staging_sp"
  host  = "https://adb-staging.net"
  token = module.azure_create_sp.staging_service_principal_aad_token
}

provider "databricks" {
  alias = "prod_sp"
  host  = "https://adb-prod.net"
  token = module.azure_create_sp.prod_service_principal_aad_token
}

module "staging_workspace_cicd" {
  source = "./common"
  providers = {
    databricks = databricks.staging_sp
  }
  git_provider = var.git_provider
  git_token    = var.git_token
}

module "prod_workspace_cicd" {
  source = "./common"
  providers = {
    databricks = databricks.prod_sp
  }
  git_provider = var.git_provider
  git_token    = var.git_token
}

// Additional steps for Azure DevOps. Create staging and prod service principals for an enterprise application.
data "azuread_client_config" "current" {}

resource "azuread_application" "azure-mlops-sample-aad" {
  display_name = "azure-mlops-sample"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "staging_service_principal" {
  application_id               = module.azure_create_sp.staging_service_principal_application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "prod_service_principal" {
  application_id               = module.azure_create_sp.prod_service_principal_application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

// Output values
output "stagingAzureSpApplicationId" {
  value     = module.azure_create_sp.staging_service_principal_application_id
  sensitive = true
}

output "stagingAzureSpClientSecret" {
  value     = module.azure_create_sp.staging_service_principal_client_secret
  sensitive = true
}

output "stagingAzureSpTenantId" {
  value     = var.azure_tenant_id
  sensitive = true
}

output "prodAzureSpApplicationId" {
  value     = module.azure_create_sp.prod_service_principal_application_id
  sensitive = true
}

output "prodAzureSpClientSecret" {
  value     = module.azure_create_sp.prod_service_principal_client_secret
  sensitive = true
}

output "prodAzureSpTenantId" {
  value     = var.azure_tenant_id
  sensitive = true
}
