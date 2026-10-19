# ADR-0009 — Run the dev environment on DigitalOcean

Status: accepted · 2026-09-15 · deciders: platform lead

## Context

The dev namespace in the prod EKS cluster competed with production for nodes, and a second EKS
cluster for dev alone costs more than the dev workload justifies.

## Options priced

| Option | Shape | List price |
|---|---|---|
| EKS dev cluster | control plane + 2 × t3.large | $0.10/hour + 2 × $0.0832/hour (AWS pricing pages, eu-central-1, read 2026-09-14) |
| DOKS dev cluster | 2 × s-4vcpu-8gb, free control plane | $48/mo per node (DigitalOcean pricing page, read 2026-09-14) |

## Decision

DOKS in fra1 (`infra/terraform/envs/do`), databases created from `ai/runbooks/platform-do.md`.

## Consequences

Dev runs on a second provider: separate credentials, and no AWS budget or anomaly monitor covers it.
