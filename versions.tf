terraform {
  required_version = "= 1.14.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 6.38.0" }
  }
  # Backend local implícito: exclusivo deste root. Nenhuma migração automática.
}
