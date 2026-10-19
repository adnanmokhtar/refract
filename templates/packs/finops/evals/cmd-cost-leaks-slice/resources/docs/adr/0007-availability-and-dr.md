# ADR-0007 — Availability and disaster recovery

Status: accepted · 2026-03-02 · deciders: platform lead, CTO

## Objectives

| Service | Availability SLO | RTO | RPO |
|---|---|---|---|
| Tracking API and page | 99.9 % monthly | 4 h | 15 min |
| Label purchase | 99.5 % monthly | 4 h | 15 min |

## Decision

- The API runs at least two replicas spread over two zones (`k8s/overlays/prod/hpa.yaml`).
- The orders database has a warm-standby read replica in eu-west-1 (`orders_dr_replica`), promoted
  by the platform on-call's failover procedure when eu-central-1 is lost. Its cost is part of the RTO, not waste.
- Backups: RDS automated backups for 14 days in-region; Velero for cluster state.

## Consequences

The replica doubles the database line of the bill; we accept that for the 4 h RTO.
