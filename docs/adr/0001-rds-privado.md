# ADR 0001 — RDS privado e Single-AZ

**Status:** Implementada no código e observada em staging; 2026-11-03. Registro consolidado a partir das fontes; não inventa data de
aprovação original nem transforma propostas em implantação.

## Contexto

Persistência precisa sobreviver ao ciclo dos pods e não deve expor PostgreSQL publicamente.

## Decisão

RDS PostgreSQL 16 privado, criptografado, SG 5432 por origem app/auth, subnet group em duas AZs e instância Single-AZ. Senha administrativa gerenciada pelo RDS; usuários runtime provisionados separadamente pela aplicação.

## Consequências e reavaliação

Isolamento e operação gerenciada, com custo fixo e dependência de rede privada/SSM para administração. Duas subnets não oferecem failover. Backup 1 dia é configuração atual, não RPO comprovado; teste de restore e eventual Multi-AZ permanecem pendentes.

## Evidências

[rds.tf](../../rds.tf), [network.tf](../../network.tf), [arquitetura](../architecture.md).
