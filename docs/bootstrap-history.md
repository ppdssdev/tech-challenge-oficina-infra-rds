# Oficina — infraestrutura RDS

Bootstrap de contratos Terraform. **Nenhum recurso cloud implementado ou provisionado.**
Sem provider AWS, backend remoto ativo, data sources ou recursos. `integration_contract`
é apenas metadado com `implemented=false`; não contém IDs/endpoints reais.

Responsabilidade futura: RDS PostgreSQL privado, DB subnet group, SG de banco, criptografia, backups, proteção contra exclusão e referências dos segredos.

## CI e validação local

```sh
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
python3 scripts/bootstrap_policy.py
python3 -m venv .venv
. .venv/bin/activate
pip install checkov==3.2.471
checkov --directory . --framework terraform --compact
```

Terraform 1.14.6 no CI; Python 3.12. Check `Terraform validation and security`.
Checkov roda sem soft-fail; nesta fase não há recursos para avaliar controles AWS.
A política estática adicional impede introduzir recursos inadvertidamente.
A PR que implementar infraestrutura deve substituir essa barreira por regras reais
(e.g. criptografia, acesso privado, IAM mínimo), incluir provider fixado e lockfile.
Não executar plan/apply/destroy nesta etapa. Exemplos de ambientes não contêm segredos.

## Integrações futuras

Campos previstos: db_endpoint, db_port, db_name, app_secret_arn, auth_secret_arn. Nunca exportar senha, chave privada ou kubeconfig.
Consome VPC, subnets privadas e SGs app/auth da stack K3s; cria regras 5432 somente dessas origens. Não lê state remoto completo. Flyway e usuários SQL pertencem à aplicação; auth terá apenas SELECT da view versionada.

[Contratos e ordem de provisionamento](https://github.com/ppdssdev/tech-challenge-oficina/blob/feature/fase3-multirepo-bootstrap/docs/fase3/aws-infrastructure-dependencies.md).
Após inicialização: PR obrigatório, CI e revisão. Nenhum deploy habilitado.

## Revisão corretiva do bootstrap

Aprovação deste bootstrap não representa conclusão da Fase 3. O workflow atual
executa **CI**, inclusive em push main; não implementa CD automático. Environments
existentes não são prova de deployment. Nenhum recurso AWS foi implementado aqui.

O checkout padrão de `pull_request` testa o merge sintético (GITHUB_SHA), enquanto
`github.event.pull_request.head.sha` identifica o HEAD da PR. Registrar ambos, base,
repo e run ID/attempt ao relacionar checks e artifacts. Nunca chamar o SHA de merge
de CI de HEAD da PR nem de release implantada.

`integration_contract` é metadado com implemented=false; `planned_fields` enumera
nomes previstos. Não é conjunto de outputs reais consumíveis. Ainda faltam recursos,
interfaces tipadas entre stacks e testes de integração. O CI não gera plano nem
publica artifact de infraestrutura; Checkov sem recursos não comprova controles AWS.

[Matriz, contratos e diagnóstico de governança](https://github.com/ppdssdev/tech-challenge-oficina/blob/feature/fase3-multirepo-bootstrap/docs/fase3/corrective-review.md).
[Rastreabilidade e gates de CD](https://github.com/ppdssdev/tech-challenge-oficina/blob/feature/fase3-multirepo-bootstrap/docs/fase3/cicd-strategy.md).
