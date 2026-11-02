# Operação, verificações pendentes e rollback

## Esta entrega

Somente versionamento, init com backend desativado, validate e inspeções locais.
Não executa plan, apply, destroy, import, refresh, state mv/rm/push, rotação de
credenciais ou alterações na AWS. O CI não recebe credenciais nem publica planos.

A cópia em `shared-root/rds.tf` é o fragmento do **mesmo root** K3s. Para consumo
futuro, fixar uma revisão deste repositório e comparar o fragmento com o arquivo
operacional antes de atualizar somente esse arquivo. Não remover o original,
não carregar ambos no mesmo root e não copiar o resto deste repositório sobre K3s.
Nesta entrega não há instalação automática nem mudança no checkout operacional.
O código K3s em main ainda não inclui os arquivos locais RDS/ECR/IAM: a composição
versionada valida os vínculos do fragmento, mas não é uma cópia integral da stack
operacional e não deve ser aplicada sobre seu estado.

## Próxima verificação somente leitura, com credenciais autorizadas

1. Interromper operações Terraform concorrentes antes de qualquer trabalho no
   estado; confirmar conta e região. Inventariar todos os arquivos locais ainda
   não versionados no root operacional. Proteger state e backup fora do Git com
   acesso restrito, criptografia e cópia recuperável antes de manutenção.
2. Usar DescribeDBInstances, DescribeDBSubnetGroups, DescribeSecurityGroups,
   DescribeSubnets e DescribeRouteTables para comparar ID, VPC, subnets, regras,
   estado available, criptografia, backups, proteção e PendingModifiedValues.
3. Consultar DescribeDBParameters para `default.postgres16` e confirmar
   `rds.force_ssl=1`; testar a partir do K3s com CA RDS confiável e
   `sslmode=verify-full`. Consultar pg_stat_ssl na sessão autenticada, sem logar
   DSN/senha. Autenticação anterior não comprova TLS com validação de certificado.
4. Consultar DescribeSecret (metadados, sem GetSecretValue) e políticas IAM
   efetivas. Conferir separação entre usuário master, aplicação, migração e auth,
   e grants SQL. Auth não ganha acesso ao banco nesta PR.
5. Inspecionar backups e planejar teste de restore separado, com autorização
   explícita, pois restore cria recursos e gera custo.
6. Só posteriormente considerar plan no root **completo** e no backend original,
   em janela sem concorrência; guardar saídas sensíveis fora do Git. Rejeitar
   criação, exclusão, substituição ou mudanças inesperadas. Não usar `-target`
   como prova de ausência de drift. Não há prova de plano sem mudanças nesta PR.

## Separação futura de estados (fora deste escopo)

Exige uma PR coordenada nos dois repositórios, inventário atualizado, bloqueio de
operações concorrentes, backups verificáveis e autorização específica. Preservar
um único proprietário por recurso; planejar migração dos cinco endereços e
substituir referências de rede por entradas tipadas alimentadas pelos outputs
K3s. Não copiar state completo para criar um segundo proprietário; não importar
recursos já gerenciados. Nenhum comando de migração é automatizado aqui.

## Rollback desta PR

Antes do merge: fechar a PR. Após merge: reverter o commit de consolidação via
nova PR. Não executar Terraform para reverter documentação/código. O checkout
operacional e o estado existente continuam no mesmo local; não restaurar state
antigo por causa desta PR (especialmente após a escrita concorrente observada).
Rollback de futura mudança AWS ou migração de estado requer procedimento próprio,
comparação de lineage/serial e avaliação de escritas posteriores; está fora desta
entrega. Remover código RDS do root operacional poderia planejar exclusão.
