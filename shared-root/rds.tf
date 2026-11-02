resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name}-postgres"
  subnet_ids = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]

  tags = {
    Name = "${local.name}-postgres"
  }
}

resource "aws_security_group" "postgres" {
  name        = "${local.name}-postgres"
  description = "RDS PostgreSQL privado"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name}-postgres"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_app" {
  security_group_id            = aws_security_group.postgres.id
  referenced_security_group_id = aws_security_group.app.id
  description                  = "PostgreSQL somente da EC2 K3s"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "app_to_postgres" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.postgres.id
  description                  = "EC2 K3s para PostgreSQL privado"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_db_instance" "postgres" {
  identifier     = "${local.name}-postgres"
  engine         = "postgres"
  engine_version = "16.15"
  instance_class = "db.t4g.micro"

  db_name                     = "oficina_db"
  username                    = "oficina_admin"
  manage_master_user_password = true

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  multi_az               = false
  availability_zone      = "us-east-2a"
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  backup_retention_period    = 1
  deletion_protection        = true
  skip_final_snapshot        = true
  auto_minor_version_upgrade = false

  performance_insights_enabled = false
  monitoring_interval          = 0

  copy_tags_to_snapshot = true

  tags = {
    Name = "${local.name}-postgres"
  }
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "rds_master_secret_arn" {
  value = try(aws_db_instance.postgres.master_user_secret[0].secret_arn, null)
}
