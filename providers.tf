provider "aws" {
  region              = var.aws_region
  profile             = "oficina-staging"
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Project     = "fiap-oficina"
      Environment = var.environment
      ManagedBy   = "terraform"
      Stack       = "infra-rds"
    }
  }
}

locals {
  name = "oficina-${var.environment}-postgres"
}
