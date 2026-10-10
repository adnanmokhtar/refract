# ADR 0012 — Hand the search cluster to the search team's state

Date: 2026-09-28 · Status: accepted

## Decision

`aws_opensearch_domain.search` leaves the prod root through a `removed { lifecycle { destroy = false } }` block
(`iac/envs/prod/refactor.tf`) and is imported into `iac/tofu/search-index` in the same change window.

## Consequences

- The domain keeps running; only its owner state changes. The import was applied on 2026-09-30 and
  `tofu plan` in `iac/tofu/search-index` reported no changes afterwards.
- The `removed` block stays until every engineer's checkout has applied the prod root once (two weeks).
