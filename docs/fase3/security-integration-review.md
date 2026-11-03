# Integração privada CPF: inventário e gates de dados

Adendo de revisão de 2026-11-03 sobre a PR [RDS #8](https://github.com/ppdssdev/tech-challenge-oficina-infra-rds/pull/8), base documental `ab627ed206a08dcaf5d418d17a10fa44ac079447`. Preserva [evidência histórica](../fase3-evidence.md), [arquitetura](../architecture.md) e README. Esta revisão preparou consultas; **não executou inventário no RDS e não confirma fixtures A/B/C/D existentes**. Contagens antigas e banco descartável da CI não são inventário de staging.

## Contrato e consultas somente leitura

Fontes imutáveis Java: [V1](https://github.com/ppdssdev/tech-challenge-oficina/blob/469984555ea3b1d0d40580ada20144e2d01550b1/src/main/resources/db/migration/V1__create_schema.sql), [V8](https://github.com/ppdssdev/tech-challenge-oficina/blob/469984555ea3b1d0d40580ada20144e2d01550b1/src/main/resources/db/migration/V8__add_customer_active.sql), [V11](https://github.com/ppdssdev/tech-challenge-oficina/blob/469984555ea3b1d0d40580ada20144e2d01550b1/src/main/resources/db/migration/V11__create_explicit_customer_identity_view.sql). A view `auth.customer_identity_v2` contém CPF canônico não ambíguo; `active` vem de `auth.customer_access`, com ausência equivalente a falso. `public.customers.active` é outro estado. `work_orders.customer_id` define ownership. Não inferir que cliente comercial ativo pode autenticar.

O [inventário reader](fixture-reader-inventory.sql) acessa apenas a view e o estado da própria conexão; o [inventário auditor](fixture-auditor-inventory.sql) exige leitura preexistente de `public.customers` e `public.work_orders`. Não ampliar o reader `oficina_lambda` para executar a segunda consulta. Ambos usam `BEGIN READ ONLY`, timeout e `ROLLBACK`, sem CPF, UUID, senha, token ou corpo de OS no resultado. Exigir `read_only=t` e `tls=t` em staging; os scripts exibem esses indicadores e não substituem a avaliação do operador. Uma falha de privilégio ou ausência de relação é bloqueio: não executar bootstrap, migrations, grants nem testes de escrita para investigar.

As contagens mostram somente candidatos. Mesmo `two_owner_candidates=true` não comprova origem sintética, allowlist ou fixtures. A seleção A/B/C/D precisa de inventário privado com proveniência autorizada. O preflight da [Lambda #6](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/6) compara quatro CPFs parametrizados, estados V2 e allowlist; ele deve ocorrer antes da janela, com os dados mantidos fora do Git e dos logs.

## Comandos por ambiente

No host do operador, usando sessão temporária já configurada:

```bash
test "$(aws --profile oficina-staging --region us-east-2 sts get-caller-identity --query Account --output text)" = 797781632267
aws --profile oficina-staging --region us-east-2 rds describe-db-instances \
  --db-instance-identifier oficina-staging-postgres \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Public:PubliclyAccessible,Endpoint:Endpoint.Address,Port:Endpoint.Port,Engine:EngineVersion}'
aws --profile oficina-staging --region us-east-2 lambda get-function-concurrency \
  --function-name oficina-staging-auth
```

Interromper se conta/região/recurso divergir, RDS não estiver privado ou concorrência não for zero. Preencher `RDS_HOST` apenas com o endpoint retornado e conferido; `RDS_CA` deve apontar à CA confiável previamente aprovada, não a certificado copiado de conexão não autenticada. Nenhuma senha em variável, argv ou log.

Em host privado já autorizado com alcance ao RDS, da raiz deste repositório:

```bash
read -r -p 'Endpoint RDS validado: ' RDS_HOST
read -r -p 'Arquivo CA RDS aprovado: ' RDS_CA
psql -X -W "host=$RDS_HOST port=5432 dbname=oficina_db user=oficina_lambda sslmode=verify-full sslrootcert=$RDS_CA connect_timeout=3 options='-c default_transaction_read_only=on'" \
  -f docs/fase3/fixture-reader-inventory.sql
```

Alternativa a partir do operador, por sessão SSM já autorizada para o nó K3s confirmado, em terminal dedicado (não executada nesta entrega):

```bash
read -r -p 'Endpoint RDS validado: ' RDS_HOST
read -r -p 'Instância SSM validada: ' K3S_INSTANCE
aws --profile oficina-staging --region us-east-2 ssm start-session \
  --target "$K3S_INSTANCE" --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "host=$RDS_HOST,portNumber=5432,localPortNumber=15432"
```

Em outro terminal, com os mesmos valores aprovados:

```bash
read -r -p 'Endpoint RDS validado: ' RDS_HOST
read -r -p 'Arquivo CA RDS aprovado: ' RDS_CA
psql -X -W "host=$RDS_HOST hostaddr=127.0.0.1 port=15432 dbname=oficina_db user=oficina_lambda sslmode=verify-full sslrootcert=$RDS_CA connect_timeout=3 options='-c default_transaction_read_only=on'" \
  -f docs/fase3/fixture-reader-inventory.sql
```

`hostaddr` determina o destino TCP; `host` continua sendo o nome RDS verificado pelo TLS. Nunca trocar `host` por localhost, desabilitar verificação ou abrir ingress. Auditar que o listener 15432 é da sessão aprovada e encerrar a sessão ao terminar. Para executar `fixture-auditor-inventory.sql`, substituir usuário e arquivo somente por papel auditor **já autorizado** com leitura das tabelas; senha continua em prompt oculto. Não usar automaticamente o segredo administrativo. Sem esse acesso, registrar inventário parcial/bloqueado.

No smoke corretivo da Lambda, o equivalente explícito é `db_transport: "ssm-loopback"` e `ssm_tunnel_attested: true`, mantendo `db_host` igual ao hostname RDS e a CA real. O modo é condicionado à revisão e testes do adapter; não implica abertura da janela.

## Plano mínimo se dados faltarem — não executar neste passo

| Papel privado | Dados mínimos planejados | Verificação anterior à janela |
|---|---|---|
| A/B | Dois clientes distintos, CPF sintético canônico válido, identidades V2 explicitamente ativas; uma OS de cada cliente com veículo correspondente | Proveniência sintética; allowlist de ambos; duas OS pertencem a donos distintos; ambos GET com dono retornam 200 |
| C | Um cliente sintético distinto presente em V2 com identidade inativa | Presente na allowlist para testar inatividade, não simples rejeição pela allowlist |
| D | CPF sintético válido distinto, reservado no inventário, sem cliente/view correspondente | Ausência por SELECT; não inserir cliente D |

Uma aprovação futura separada deve definir responsável, valores privados, colisões/ambiguidades, veículos/OS válidos, mecanismo de preparo, snapshot/reversão e alteração necessária da allowlist. Não gerar valores nesta revisão, não reutilizar pessoas reais nem tratar dígitos verificadores como prova de origem sintética. Não inserir SQL de bootstrap no runbook operacional. A criação de OS pela aplicação pode ter efeitos de outbox; revisar esses efeitos antes de aprovar preparo. Não apagar dados para "limpar" a demonstração.

## Evidência, CI e integração documental

Validação local desta revisão: as duas consultas executaram com sucesso em PostgreSQL 16 descartável, Docker `--network none`, sem portas publicadas, schema V1/V8/V11 e banco vazio. O reader foi repetido com papel restrito a `USAGE auth`/`SELECT auth.customer_identity_v2`, sem grants nas tabelas públicas, e passou. Transações reportaram read-only e terminaram em rollback; TLS foi falso pelo socket Unix local, portanto esse teste comprova SQL/privilégio mínimo, **não** TLS de staging, fixtures nem conexão real. Container e dados temporários foram removidos. Nenhum bootstrap foi executado no RDS.

Registrar UTC, SHAs, conexão read-only/TLS, contagens agregadas e exit code; inventário privado mantém CPFs/UUIDs e a associação A/B/C/D. Não anexar arquivo de entrada, hash dele, tokens ou consultas parametrizadas com valores. Janela Lambda continua bloqueada até recuperação independente, prazo limitado, gates e leitura final de concorrência zero; este inventário não a autoriza. Aceites permanecem OS própria **200**, sem token **401**, CUSTOMER em ADMIN **403**, OS alheia **404**. Divergência JWKS/PEM deve bloquear a evidência, sem alterar Java nesta frente.

`.github/workflows/ci.yml` valida Terraform e política estática, sem provar dados, grants, TLS ou conectividade de staging. O CI não executa estas consultas. Automação operacional SSM/Lambda é manual, condicionada aos gates e distinta de CD. Não modificar IAM, Terraform ou acessos para ultrapassar bloqueios.

Ordem de integração preservada: [API #13](https://github.com/ppdssdev/tech-challenge-oficina/pull/13) antes de [API #14](https://github.com/ppdssdev/tech-challenge-oficina/pull/14); [Lambda #6](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/6) e sua correção antes de [Lambda #7](https://github.com/ppdssdev/tech-challenge-oficina-auth-lambda/pull/7). Relacionados: [K3s #6](https://github.com/ppdssdev/tech-challenge-oficina-infra-k3s/pull/6) e [RDS #8](https://github.com/ppdssdev/tech-challenge-oficina-infra-rds/pull/8). Reconsultar heads/checks antes da integração futura; não fazer merge nesta frente.
