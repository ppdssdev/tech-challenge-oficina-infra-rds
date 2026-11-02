# Falha se a minor selecionada não estiver disponível na região.
data "aws_rds_engine_version" "postgres" {
  engine  = "postgres"
  version = var.postgres_engine_version
}

# Sem fallback silencioso para uma classe mais cara.
data "aws_rds_orderable_db_instance" "postgres" {
  engine                      = "postgres"
  engine_version              = data.aws_rds_engine_version.postgres.version
  instance_class              = "db.t4g.micro"
  storage_type                = "gp3"
  vpc                         = true
  supports_storage_encryption = true
}

resource "aws_db_instance" "postgres" {
  # checkov:skip=CKV_AWS_157:Single-AZ é decisão explícita para staging acadêmico.
  # checkov:skip=CKV_AWS_118:Enhanced Monitoring desabilitado para reduzir custo de staging.
  # checkov:skip=CKV_AWS_129:Logs exportados ao CloudWatch ficam para revisão de custo/observabilidade.
  # checkov:skip=CKV_AWS_353:Performance Insights desabilitado para reduzir custo de staging.
  # checkov:skip=CKV_AWS_354:Performance Insights desabilitado; não há dados PI a criptografar.
  # checkov:skip=CKV_AWS_161:IAM DB auth fora do escopo; aplicações terão usuários SQL próprios.
  # checkov:skip=CKV2_AWS_30:Query logging exige parameter group adicional; fora do escopo desta stack mínima.
  identifier                   = local.name
  engine                       = "postgres"
  engine_version               = data.aws_rds_engine_version.postgres.version
  engine_lifecycle_support     = "open-source-rds-extended-support-disabled"
  instance_class               = data.aws_rds_orderable_db_instance.postgres.instance_class
  allocated_storage            = 20
  max_allocated_storage        = 0
  storage_type                 = "gp3"
  storage_encrypted            = true
  multi_az                     = false
  publicly_accessible          = false
  db_subnet_group_name         = aws_db_subnet_group.postgres.name
  vpc_security_group_ids       = [aws_security_group.postgres.id]
  port                         = 5432
  db_name                      = "oficina_db"
  username                     = "oficina_admin"
  manage_master_user_password  = true
  performance_insights_enabled = false
  monitoring_interval          = 0
  backup_retention_period      = 7
  backup_window                = "03:00-04:00"
  maintenance_window           = "sun:05:00-sun:06:00"
  auto_minor_version_upgrade   = true
  allow_major_version_upgrade  = false
  apply_immediately            = false
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = false
  final_snapshot_identifier    = var.final_snapshot_identifier
  delete_automated_backups     = false
  copy_tags_to_snapshot        = true

  depends_on = [aws_vpc_security_group_ingress_rule.postgres]
}
