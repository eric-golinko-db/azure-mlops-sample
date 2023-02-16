resource "databricks_git_credential" "service_principal_git_token" {
  git_username          = "azure-mlops-sample-cicd"
  git_provider          = var.git_provider
  personal_access_token = var.git_token
}


