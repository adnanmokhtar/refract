# MySQL / MariaDB reference

> **Engine**: MySQL 8.0+ / 8.4 LTS • MariaDB 11.x
> **Official docs**: https://dev.mysql.com/doc/refman/8.0/en/ • https://mariadb.com/kb/en/documentation/
> **Version-specific gotchas**: MySQL 8.0+ added CHECK constraints, JSON functions, descending indexes, window functions; 8.4 LTS made `caching_sha2_password` default (legacy clients break); `EXPLAIN ANALYZE` from 8.0.18; `ALGORITHM=INSTANT` for many ALTERs from 8.0.12 (avoid table rewrite); `gh-ost` / `pt-online-schema-change` for blocking-safe migrations on Aurora / RDS.
> **Substitution markers**: Replace `<table>` / `<column>` with the project's actual schema.

## Engines

- InnoDB always. Never MyISAM.

## Types

- `BIGINT UNSIGNED` PKs (auto-increment) or `BINARY(16)` for UUIDs
- `DATETIME(6)` with explicit timezone handling at app level; MySQL doesn't store tz
- `VARCHAR(N)` — choose N deliberately; `VARCHAR(255)` is a lazy default
- `TEXT` for very long strings (>65K)
- `DECIMAL(P,S)` for money
- `JSON` (native) for semi-structured data
- `ENUM` works but hard to modify later

## Constraints

- FK constraints respected (not always by default in old setups — verify)
- CHECK constraints supported in 8.0+

## Indexes

- Indexes on FKs are NOT automatic on all configurations — add them explicitly
- Covering indexes for hot queries (include `ORDER BY` columns)
- Fulltext indexes for search on small datasets; use Elastic/Meili for big

## Safe migrations on large tables

- Avoid direct `ALTER TABLE` on multi-million row tables during peak — it rewrites the whole table on many operations
- Use `pt-online-schema-change` or `gh-ost` for non-blocking online DDL
- Aurora / RDS have online DDL with limitations — check per-version docs

## Performance

- Slow query log for profiling
- `EXPLAIN` + `EXPLAIN ANALYZE` (8.0+)
- InnoDB buffer pool sizing is the single biggest perf lever (~70% of RAM on dedicated DBs)
