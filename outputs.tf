# Metadados de contrato; não são outputs de recursos provisionados.
output "integration_contract" {
  description = "Nomes dos outputs que serão implementados em uma futura PR."
  value = {
    schema_version = 1
    implemented    = false
    environment    = var.environment
    region         = var.aws_region
    planned_fields = ["db_endpoint", "db_port", "db_name", "app_secret_arn", "auth_secret_arn"]
  }
}
