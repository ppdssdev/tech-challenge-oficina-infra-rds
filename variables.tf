variable "environment" {
  description = "Staging acadêmico; produção requer revisão e state separado."
  type        = string
  default     = "staging"
  validation {
    condition     = var.environment == "staging"
    error_message = "Somente staging está implementado."
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "Somente us-east-2."
  }
}

variable "aws_account_id" {
  description = "Conta permitida, confirmada independentemente do contrato. Sem default."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Informe o ID de 12 dígitos da conta autorizada."
  }
}

variable "network_contract" {
  description = "Output integration_contract v3 integral do infra-k3s."
  nullable    = false
  type = object({
    schema_version         = number
    account_id             = string
    region                 = string
    environment            = string
    vpc_id                 = string
    private_subnet_ids     = list(string)
    app_security_group_id  = string
    auth_security_group_id = string
  })
  validation {
    condition     = var.network_contract.schema_version == 3
    error_message = "É obrigatório integration_contract schema_version exatamente 3."
  }
  validation {
    condition     = var.network_contract.account_id == var.aws_account_id
    error_message = "Conta do contrato difere da conta permitida."
  }
  validation {
    condition     = var.network_contract.region == var.aws_region
    error_message = "Região do contrato difere da região configurada."
  }
  validation {
    condition     = var.network_contract.environment == var.environment
    error_message = "Ambiente do contrato difere do ambiente configurado."
  }
  validation {
    condition = try(
      length(distinct(var.network_contract.private_subnet_ids)) >= 2 &&
      length(distinct(var.network_contract.private_subnet_ids)) == length(var.network_contract.private_subnet_ids) &&
      alltrue([for id in var.network_contract.private_subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))]), false
    )
    error_message = "Informe pelo menos duas subnets distintas, sem duplicatas."
  }
  validation {
    condition = (
      can(regex("^vpc-[0-9a-f]+$", var.network_contract.vpc_id)) &&
      can(regex("^sg-[0-9a-f]+$", var.network_contract.app_security_group_id)) &&
      can(regex("^sg-[0-9a-f]+$", var.network_contract.auth_security_group_id)) &&
      var.network_contract.app_security_group_id != var.network_contract.auth_security_group_id
    )
    error_message = "VPC e SGs devem ter IDs válidos; os SGs app e auth devem ser distintos."
  }
}

variable "postgres_engine_version" {
  description = "Minor 16.x explícita, confirmada na região antes do futuro plan."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^16\\.[0-9]+$", var.postgres_engine_version))
    error_message = "Fixe uma versão minor PostgreSQL 16 (16.x)."
  }
}

variable "deletion_protection" {
  description = "Desabilitar somente durante desmontagem aprovada; ver README."
  type        = bool
  default     = true
  nullable    = false
}

variable "final_snapshot_identifier" {
  description = "Nome único para snapshot final. Obrigatório antes de desabilitar proteção."
  type        = string
  default     = null
  validation {
    condition = var.final_snapshot_identifier == null ? true : (
      can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,254}$", var.final_snapshot_identifier)) &&
      !endswith(var.final_snapshot_identifier, "-") &&
      !strcontains(var.final_snapshot_identifier, "--")
    )
    error_message = "Snapshot: iniciar com letra, até 255 caracteres, sem -- ou hífen final."
  }
  validation {
    condition     = var.deletion_protection || var.final_snapshot_identifier != null
    error_message = "Defina snapshot final único antes de desabilitar deletion_protection."
  }
}
