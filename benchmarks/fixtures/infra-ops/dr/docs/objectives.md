# Recovery objectives

Agreed with finance and operations on 2026-06-30. Every store below is a system of record unless the last column
says otherwise. RPO = data we accept to lose; RTO = time until the service is back on that store.

| Store | Holds | RPO | RTO | Backup mechanism (where it is declared) |
|---|---|---|---|---|
| orders — RDS `larder-orders-v2` | orders, payment state | 5 min | 1 h | RDS automated backups + PITR (`iac/modules/db`); nightly `pg_dump` (`dr/k8s`) |
| ledger — RDS `larder-ledger` | payouts, refunds | 5 min | 1 h | RDS automated backups + PITR; AWS Backup daily (`iac/envs/prod/backup.tf`) |
| inventory — CNPG `inventory` | stock per SKU and site | 15 min | 30 min | barman WAL archive + base backup (`dr/cnpg/inventory-cluster.yaml`) |
| catalog — CNPG `catalog` | SKUs, descriptions | 1 h | 2 h | — |
| courier-geo — zalando `larder-courier-geo` | courier location history | 24 h | 8 h | operator logical backup (`dr/zalando`) |
| media library — EFS claim `media-library` | merchant-uploaded originals | 1 h | 4 h | Velero file-system backup (`dr/velero/schedule-media.yaml`) |
| search curation — claim `search-curation` | merchandising rules, synonyms | 24 h | 4 h | Velero (`dr/velero/schedule-search.yaml`) |
| warehouse — EC2 Postgres `warehouse-pg-1` | finance warehouse | 15 min | 4 h | pgBackRest (`dr/pgbackrest`) |
