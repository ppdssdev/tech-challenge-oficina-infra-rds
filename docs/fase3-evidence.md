# Evidências consolidadas — Fase 3, Grupo 97

Pedro Paulo dos Santos Silva · Discord pedropaulo6447. Auditoria: 2026-11-03.
Baseline deste repositório: `51bb0557156a42e0f6f71c05bc304a6e9af362bf`. Alterações desta PR são somente documentais.
Não houve deploy, alteração funcional, Terraform apply/state nem pipeline.

A fonte central de status é a [entrega Fase 3](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/README.md), com
[matriz](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/evidence-matrix.md),
[coleta operacional](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/operational-evidence.md),
[diagramas](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/deployment-architecture.md)
e [RFCs/ADRs](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/decisions.md).
Links novos em main dependem do merge da PR documental da API; durante revisão,
consultar a branch da PR. Fontes de código anteriores permanecem fixadas por SHA.

| Evidência | Situação |
|---|---|
| Implementação | Código/main auditado, não só bootstrap |
| CI da baseline | Success conforme run abaixo; não equivale a deploy |
| Cloud | Consultas somente leitura e inventário SSM registrados centralmente |
| OIDC/CD | PR preparatória aberta; SCP impede auditoria provider; sem CD main |
| Produção | Não implantada/demonstrada nesta entrega |
| Evidências históricas | Resultados datados, não estado atual |

[CI RDS](https://github.com/ppdssdev/tech-challenge-oficina-infra-rds/actions/runs/41625940842).
Observado: PostgreSQL 16.15/db.t4g.micro, available, oficina_db, privado,
criptografado, Single-AZ, retention 1 dia, deletion protection true, subnet group em
duas AZs. SG 5432 aceita somente os SGs app/auth. Nenhuma sessão SQL foi aberta.
Pendentes: Flyway/checksums reais, roles/grants/TLS efetivos e restore/RPO/RTO.

Reprodução: `terraform init -backend=false -input=false`, `terraform validate`,
`python scripts/bootstrap_policy.py`; AWS somente leitura:
`aws rds describe-db-instances --db-instance-identifier oficina-staging-postgres
--query 'DBInstances[].{{Status:DBInstanceStatus,Public:PubliclyAccessible,MultiAZ:MultiAZ}}'`.
Selecionar perfil/região explicitamente; não publicar saída completa com endpoints.

Consulta complementar GitHub: PR/checks obrigatórios, zero aprovações humanas
exigidas; soat-architecture ainda não adicionado neste repo. Subject OIDC usa IDs
imutáveis e diverge da trust por nomes na PR K3s #5. Correções de IAM/governança
não fazem parte desta PR documental.
[Fontes e comandos](https://github.com/ppdssdev/tech-challenge-oficina/blob/main/docs/fase3/governance-audit.md).
