output "rds_identifier" {
  value = aws_db_instance.postgres.identifier
}
output "db_endpoint" {
  description = "Hostname privado; porta em db_port."
  value       = aws_db_instance.postgres.address
}
output "db_port" {
  value = aws_db_instance.postgres.port
}
output "db_name" {
  description = "Banco oficina_db, compartilhado pelos contratos da API Java e Lambda auth."
  value       = aws_db_instance.postgres.db_name
}
output "db_security_group_id" {
  value = aws_security_group.postgres.id
}
output "admin_secret_arn" {
  description = "Referência não secreta; nunca o conteúdo da credencial administrativa."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
  sensitive   = false
}
