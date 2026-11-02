# Consultas executadas somente em um futuro plan/apply autorizado.
data "aws_vpc" "network" {
  id = var.network_contract.vpc_id
}

data "aws_subnet" "private" {
  for_each = toset(var.network_contract.private_subnet_ids)
  id       = each.value
}

data "aws_security_group" "clients" {
  for_each = {
    app  = var.network_contract.app_security_group_id
    auth = var.network_contract.auth_security_group_id
  }
  id = each.value
}

resource "aws_db_subnet_group" "postgres" {
  name       = local.name
  subnet_ids = var.network_contract.private_subnet_ids
  lifecycle {
    precondition {
      condition     = data.aws_vpc.network.owner_id == var.aws_account_id
      error_message = "A VPC deve pertencer à conta permitida."
    }
    precondition {
      condition = alltrue([for subnet in data.aws_subnet.private :
        subnet.vpc_id == var.network_contract.vpc_id &&
        subnet.owner_id == var.aws_account_id && !subnet.map_public_ip_on_launch
      ])
      error_message = "Subnets devem ser da conta/VPC esperadas e sem atribuição automática de IP público."
    }
    precondition {
      condition     = length(toset([for subnet in data.aws_subnet.private : subnet.availability_zone_id])) >= 2
      error_message = "São obrigatórias pelo menos duas AZs distintas."
    }
    precondition {
      condition = alltrue([for sg in data.aws_security_group.clients :
        sg.vpc_id == var.network_contract.vpc_id && split(":", sg.arn)[4] == var.aws_account_id
      ])
      error_message = "SGs app e auth devem pertencer à conta/VPC esperadas."
    }
  }
}

resource "aws_security_group" "postgres" {
  name        = local.name
  description = "PostgreSQL privado: somente API/K3s e Lambda auth"
  vpc_id      = var.network_contract.vpc_id
  # Sem ingress inline ou egress: respostas são permitidas pelo comportamento stateful.
  depends_on = [aws_db_subnet_group.postgres]
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = {
    app  = var.network_contract.app_security_group_id
    auth = var.network_contract.auth_security_group_id
  }
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL de ${each.key}"
}
