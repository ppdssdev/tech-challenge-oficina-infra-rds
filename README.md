# Oficina — RDS existente (Fase 3)

O RDS `oficina-staging-postgres` já foi provisionado em `us-east-2` pelo
**root Terraform local do K3s**, junto com a rede. Este repositório passa a guardar
em [`shared-root/rds.tf`](shared-root/rds.tf) o código original, sem mudanças nos
cinco endereços ou nas configurações provisionadas. Não é uma stack independente.

**Não executar apply neste repositório nem inicializar um estado RDS separado.**
O estado autoritativo continua no checkout operacional K3s. Não copiar o estado
para este repositório, não remover o `rds.tf` operacional e não transformar o
fragmento em um `module`: isso mudaria endereços e exigiria migração coordenada.
O diretório `shared-root` depende das declarações do K3s e não valida sozinho.
A raiz permanece apenas com metadados, sem recursos ou backend operacional.

## Validação segura

Terraform 1.14.6 / AWS provider 6.38.0; lockfile proveniente do root operacional.

```sh
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
python3 scripts/bootstrap_policy.py
python3 scripts/validate_shared_root.py /caminho/checkout-k3s
```

O último comando extrai o commit K3s fixado em diretório temporário, adiciona o
fragmento e executa somente init/validate. Não lê nem copia state, tfvars ou
alterações locais. O CI faz a mesma composição sem credenciais AWS; não há deploy.
Checkov avalia o fragmento com exceções explícitas dos riscos existentes.

## Integração preservada

| Contrato K3s | Referência original preservada |
| --- | --- |
| `vpc_id` | `aws_vpc.this.id` |
| `private_subnet_ids` | `aws_subnet.private` ordenadas por chave |
| `app_security_group_id` | `aws_security_group.app.id` |

Como o root é compartilhado, as referências usam os mesmos recursos que alimentam
os outputs K3s; não se adiciona `terraform_remote_state`. O SG `auth` não possui
regra para o banco hoje. O fragmento conserva `rds_endpoint` e
`rds_master_secret_arn`; o ARN master é uma referência administrativa, não uma
credencial para a aplicação. `db_endpoint`, `db_port`, `db_name`,
`app_secret_arn` e `auth_secret_arn` continuam contratos futuros; o metadado
`integration_contract.implemented=false` indica que a interface independente
não foi implementada. Não publicar senhas em outputs.

Veja [evidências e riscos](docs/evidence.md) e [operação e rollback](docs/runbook.md).
