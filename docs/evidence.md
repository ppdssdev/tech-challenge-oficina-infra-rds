# Evidências — 2026-11-02

## Origem e propriedade

- RDS main inspecionada: `64387f0424365ff250aac7b851c63d17b7ff6e10` (bootstrap).
- K3s main e checkout operacional: `2314744b57fdccb86802a773159f24b97b977e49`.
- Fonte recuperada: `~/tech-challenge-oficina-infra-k3s/rds.tf`, não rastreada
  no Git local. Cópia byte a byte em `shared-root/rds.tf`; SHA em `rds-source.sha256`.
- Estado autoritativo encontrado: `~/tech-challenge-oficina-infra-k3s/terraform.tfstate`.
  Backend local; contém rede, K3s, ECR e RDS. Nenhum estado RDS separado encontrado.
- Cinco endereços preservados: `aws_db_instance.postgres`,
  `aws_db_subnet_group.postgres`, `aws_security_group.postgres`,
  `aws_vpc_security_group_ingress_rule.postgres_from_app`,
  `aws_vpc_security_group_egress_rule.app_to_postgres`.
- Estado inicial serial 33, Terraform 1.14.6, SHA-256
  `d20100112cc182ae6d9ad1126d897cc370d40fac9e4172a30c7957593114b4ec`.
- Durante a inspeção houve escrita externa concorrente: serial 35 às 07:36 UTC,
  SHA-256 `b7c7ccbcafca4f27ef6862f16087f8131c948239888dbb8e5e22a3485ea69741`.
  A segunda leitura contém `aws_iam_role_policy.app_secrets`. Esta tarefa não
  escreveu no checkout operacional, em state ou backup. Não alegamos imutabilidade
  global do arquivo nem identificamos o processo externo responsável.

## Evidência local versus confirmação operacional

| Controle | Código / estado local observado | Limite da evidência |
| --- | --- | --- |
| Banco | PostgreSQL 16.15, db.t4g.micro, oficina_db, us-east-2a | available/autenticação: confirmação do solicitante; não repetida |
| Rede | Mesma VPC K3s; duas subnets privadas us-east-2a/b, sem IP público; tabelas privadas sem rotas externas explícitas | Não consultado EC2 ao vivo |
| SG | Entrada TCP/5432 exclusivamente do SG app; saída app/5432 para SG postgres; SG postgres sem saída | Sem liberação para auth ou CIDR público; drift não verificado |
| Criptografia | gp3 20 GiB, storage_encrypted=true | Política KMS e uso atual não auditados |
| Credenciais | manage_master_user_password=true; username oficina_admin; senha ausente do código | Não acessamos GetSecretValue; rotação não testada |
| Backups | Retenção 1 dia, copy_tags_to_snapshot=true | Restauração e existência de snapshots recentes não testadas |
| Exclusão | deletion_protection=true; skip_final_snapshot=true | Se proteção for removida, exclusão pode perder dados sem snapshot final |
| TLS | Parameter group do estado: default.postgres16 | rds.force_ssl efetivo, negociação TLS e verificação do hostname não consultados |
| IAM app | Serial 35 contém GetSecretValue limitado aos três nomes app-db-password, jwt-secret e admin-password, com sufixo de ARN ?????? | Nenhum grant master nessa política; outras políticas anexadas/SQL GRANTs não auditadas |

AWS CLI retornou `NoCredentials` em STS e DescribeDBInstances. Não há evidência
nova do ambiente ao vivo. O compose da aplicação é configuração de desenvolvimento;
seus valores locais não foram transportados para Terraform ou usados no RDS.

## Riscos preservados, sem correção automática

O scanner Checkov 3.2.471 encontrou 24 verificações aprovadas e **7 falhas** nos
cinco recursos, sem erros de parsing. O CI exige exatamente esta baseline por
ID e endereço; qualquer diferença requer revisão. Isso não significa aprovação
de segurança. Não há supressões globais nem soft-fail.

| Checkov | Configuração atual / risco |
| --- | --- |
| CKV_AWS_161 | Autenticação IAM não habilitada; auditar usuários SQL e grants mínimos |
| CKV_AWS_226 | Atualização minor automática desativada; estabelecer janela de atualização |
| CKV_AWS_118 | Enhanced Monitoring desativado |
| CKV_AWS_129 | Exportação de logs RDS não configurada |
| CKV_AWS_353 | Performance Insights desativado |
| CKV_AWS_157 | Single-AZ; indisponibilidade em falha de AZ |
| CKV2_AWS_30 | Query logging não configurado |

Além do scanner: retenção curta, ausência de snapshot final, state local sem
backend remoto/locking compartilhado e operações concorrentes são riscos abertos.
Não mudar parâmetros apenas para fazer o scanner passar nesta consolidação.

## Referências para verificações pendentes

A documentação AWS descreve `rds.force_ssl` e conexão com `sslmode=verify-full`:
https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Concepts.General.SSL.html.
O default de PostgreSQL 16 não substitui verificar o parâmetro efetivo e o cliente.

A HashiCorp documenta que mover recursos entre módulos/estados exige preservar
bindings: https://developer.hashicorp.com/terraform/cli/state/move.
State e planos podem conter segredos:
https://developer.hashicorp.com/terraform/language/manage-sensitive-data.

## Validações executadas nesta entrega

- `terraform fmt -check -recursive`, política estática e `git diff --check`: aprovados.
- `terraform init -backend=false` e `terraform validate` da raiz: aprovados.
- Composição do fragmento com K3s no commit fixado: `init -backend=false
  -lockfile=readonly` e `validate` aprovados em diretório temporário sem estado.
  Foi usado o provider 6.38.0 instalado localmente, conferido pelo lockfile;
  o mirror local é reportado pelo Terraform como `unauthenticated` (sem nova
  verificação de assinatura via registry). O sandbox inicialmente bloqueou o
  handshake local do provider; a validação foi repetida fora desse isolamento.
- Checkov: 24 passes / 7 falhas conhecidas / 0 skips / 0 erros de parsing;
  gate de baseline aprovado. Não houve plano, teste SQL ou teste de recuperação.
