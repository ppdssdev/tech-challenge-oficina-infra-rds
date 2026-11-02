# Oficina — PostgreSQL RDS / Fase 3

Stack Terraform independente implementada para revisão, **ainda não provisionada**.
Região `us-east-2`, perfil `oficina-staging`, ambiente `staging`. Rede real ainda
indisponível; nenhum plan, apply ou destroy foi executado nesta implementação.

## Escopo

Cria cinco recursos: RDS PostgreSQL 16, DB subnet group, SG exclusivo e duas regras
standalone de ingresso TCP 5432, com origem nos SGs API/K3s e Lambda auth.
Não cria VPC, subnet, EC2, ECR, IAM, NAT, endpoint, S3 ou DynamoDB.
O [contrato e arquitetura](docs/architecture.md) detalha fronteiras e validações.
O [README anterior](docs/bootstrap-history.md) foi preservado como histórico.

RDS: `db.t4g.micro`, Single-AZ, gp3 20 GiB criptografado com chave AWS gerenciada,
sem crescimento automático de armazenamento, sem IP público, réplicas, Enhanced
Monitoring ou Performance Insights. Monitorar espaço livre antes de carga real.
Extended Support pago desabilitado explicitamente. A minor 16.x é obrigatória,
sem default inventado; data sources conferem versão e oferta regional da classe.
Se indisponível, o futuro plan falha; não há troca automática para classe mais cara.
Minor upgrades automáticos habilitados; revisar a versão fixada após upgrades
para evitar tentativa de downgrade. Major upgrades desabilitados.

A senha administrativa é gerada/gerenciada pelo RDS no Secrets Manager. Terraform
não lê seu conteúdo. Outputs: `rds_identifier`, `db_endpoint` (hostname), `db_port`,
`db_name` (`oficina_db`), `db_security_group_id`, `admin_secret_arn`.
O output `db_name` deriva do recurso RDS. ARN é referência, não segredo.
Usuários SQL de privilégio mínimo, migrations e segredos app/auth são trabalho
posterior das aplicações; não usar a conta administrativa no runtime.

O banco inicial é `oficina_db`, compatível com a API Java e a Lambda auth.
Na API, configurar `SPRING_DATASOURCE_URL` com
`jdbc:postgresql://<db_endpoint>:5432/oficina_db?sslmode=verify-full` e a CA RDS
confiável no cliente. Na Lambda, `DB_HOST`, `DB_PORT` e `DB_NAME` recebem os
respectivos outputs; seu contrato exige `oficina_db` e porta 5432.
O contrato de rede continua sendo `integration_contract` v3 do K3s.
Veja o [mapeamento dos consumidores](docs/architecture.md#compatibilidade-java-e-lambda).

## Contrato v3 e preparação futura

Somente depois de provisionar e aprovar a rede K3s, exportar o output canônico.
Exemplo para execução **futura**, no root infra-rds, com bash e jq:

```bash
set -euo pipefail
umask 077
contract_tmp=$(mktemp ./network-contract.XXXXXX)
trap 'rm -f "$contract_tmp"' EXIT
terraform -chdir=../tech-challenge-oficina-infra-k3s output -json integration_contract \
  | jq -e '{network_contract: .}' > "$contract_tmp"
mv "$contract_tmp" network.auto.tfvars.json
```

O comando apenas lê o output do produtor; não copiar state, credenciais ou tfvars
K3s. O arquivo gerado é ignorado pelo Git. Registrar revisão Git do produtor,
ambiente, conta, data de exportação e hash SHA256 do JSON no registro da implantação.
Regenerar após mudanças de rede; usar o arquivo inteiro e nunca editar IDs à mão.
Antes de cada implantação, comparar com nova exportação do produtor para detectar
contrato obsoleto. Validações de existência/VPC não detectam sozinhas uma rede antiga
que ainda exista. Não publicar `terraform output -json` sem selecionar o output.

Copiar `environments/staging.tfvars.example` para um `.tfvars` local ignorado.
Preencher a conta autorizada independentemente do contrato e a minor PostgreSQL.
Consultar futuramente, com AWS CLI e autorização de leitura:

```bash
aws --profile oficina-staging --region us-east-2 rds describe-db-engine-versions \
  --engine postgres --query 'DBEngineVersions[?starts_with(EngineVersion, `16.`)].EngineVersion'
aws --profile oficina-staging --region us-east-2 rds describe-orderable-db-instance-options \
  --engine postgres --engine-version "$POSTGRES_MINOR" --db-instance-class db.t4g.micro
```

Confirmar gp3, criptografia, disponibilidade nas AZs e custos. O `.tfvars` de staging
precisa ser fornecido explicitamente com `-var-file` no futuro; apenas o contrato
`.auto.tfvars.json` é carregado automaticamente. Produção é rejeitada nesta fase.
Não executar plan enquanto a rede real e o contrato não estiverem disponíveis.

## State e backend

Backend atual: **local implícito**, `terraform.tfstate` exclusivamente neste root,
ignorado pelo Git junto de backups e planos. Nunca usar o state K3s, copiar backups
sobre o state ativo ou executar migração/importação automática. Não há dependência
de `terraform_remote_state`. States anteriores vazios foram informados no contexto;
esta etapa não lê nem altera seu conteúdo.

O backend local tem locking local, sem coordenação entre máquinas. Usar um único
operador e não executar operações concorrentes. State deve ficar em disco protegido,
com acesso restrito e backup operacional autorizado; não é artifact público de CI.
Estratégia futura: backend S3 aprovado, criptografado, versionado, chave exclusiva
`infra-rds/staging/terraform.tfstate`, IAM restrito e `use_lockfile = true`.
Locking nativo S3 dispensa DynamoDB. Bucket, migração e permissões exigem etapa
separada autorizada. Nada disso é criado por esta stack. Workspaces não substituem
a separação de backend e permissões entre stacks/ambientes.

## Backups e desmontagem segura

Backups automáticos por 7 dias, janela diária 03:00–04:00 UTC; manutenção domingo
05:00–06:00 UTC. Alterações usam janela de manutenção (`apply_immediately=false`).
`delete_automated_backups=false` preserva backups pelo prazo de retenção após exclusão;
`skip_final_snapshot=false` exige snapshot final. Snapshot manual final permanece
até exclusão explícita e pode continuar gerando custo. Teste de restore é pendente.

Procedimento **futuro**, sujeito a aprovação específica, nunca executado nesta etapa:

1. Suspender escrita das aplicações, revisar dependências e plano de recuperação;
   verificar backup recente e, conforme necessidade, snapshot manual já disponível.
2. Definir `final_snapshot_identifier` único (sem colisão com snapshots existentes).
   Registrar responsável, retenção e como restaurar o banco e suas credenciais.
3. Alterar `deletion_protection=false`, revisar plano dessa alteração e aplicar
   somente após autorização. Confirmar na AWS que a proteção foi desabilitada.
4. Revisar separadamente a destruição RDS; exigir snapshot final, sem remover state,
   proteção ou snapshots para contornar erros. A alteração da variável, sozinha,
   não desabilita a proteção que ainda estiver ativa na AWS.
5. Após autorização de desmontagem, verificar snapshot disponível e backups retidos.
   Remover dependências Lambda/ENIs e RDS antes da rede K3s. Excluir snapshots antigos
   somente mediante decisão explícita de retenção. Considerar credenciais na restauração:
   não pressupor que o ARN do segredo gerenciado sobreviva à exclusão da instância.

## Validação local e CI

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
python3 -m venv .venv
.venv/bin/pip install checkov==3.2.471 bc-python-hcl2==0.4.3
.venv/bin/python scripts/bootstrap_policy.py
.venv/bin/checkov --directory . --framework terraform --compact --skip-download \
  --skip-path .venv --skip-path .terraform
git diff --check
```

Terraform 1.14.6 e provider AWS 6.38.0 fixados, lockfile com checksums oficiais.
Init obtém apenas provider; validate e testes não consultam AWS nem precisam do
contrato real. A política usa AST HCL para verificar inventário fechado, contrato,
preconditions bloqueantes, ingressos, RDS, outputs e isolamento. Fixa também
`db_name=oficina_db` e verifica que a regressão para `oficina` é rejeitada. Não demonstra
conectividade real nem substitui o futuro plan. CI permanece sem deploy e sem
credenciais AWS. Checkov mantém falhas bloqueantes; exceções pontuais comentadas
em rds.tf cobrem Single-AZ, monitoring/PI/logs e IAM DB auth fora do escopo.

Conferência local desta correção (2026-11-02): `fmt -check -recursive` aprovado,
6 testes da política aprovados (incluindo mutações), Checkov com 27 verificações
aprovadas, zero falhas e as 7 exceções preexistentes; `git diff --check` aprovado.
`terraform validate` foi executado, mas não concluiu: o sandbox bloqueou o socket
Unix local do provider com `setsockopt: operation not permitted`. É necessário
repetir esse comando em ambiente que permita a comunicação local com o plugin;
isso não exige operações AWS. Compatibilidade Java/Lambda/v3 conferida por leitura
dos checkouts irmãos, sem teste de conectividade ou execução das aplicações.

## Custos e pendências

Principais custos: horas da instância (provavelmente a maior parcela para esta
configuração), 20 GiB gp3, Secrets Manager/requests e snapshots/backups além da
franquia aplicável. Créditos excedentes de CPU burst e tráfego entre AZs também
podem gerar cobrança. Sem estimativa numérica ou promessa de gratuidade: consultar
[preços RDS PostgreSQL](https://aws.amazon.com/rds/postgresql/pricing/) e
[Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/) antes da aprovação.
SG e subnet group não adicionam computação. Snapshot final continua custando após
excluir RDS. Single-AZ reduz custo, mas não oferece failover entre AZs.

Pendências: revisão desta stack, rede K3s provisionada, contrato real e proveniência,
conta aprovada, minor/oferta regional, permissões RDS/EC2 de leitura/Secrets Manager,
orçamento, futuro plan revisado, provisionamento autorizado e testes de conexão
privada/TLS/backup/restore. Lambda e aplicações precisam resolver separadamente
acesso ao Secrets Manager; subnets isoladas não oferecem acesso à API pública do
serviço só por autorizar TCP 5432. NAT e VPC endpoints não fazem parte desta etapa.
