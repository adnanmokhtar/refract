# Quaywise

Parcel and courier software for online merchants: a merchant creates a shipment, Quaywise buys the
label from a carrier, tracks the parcel until it is delivered, and keeps the merchant's customers
informed by SMS and on a public tracking page with an assistant that answers "where is my parcel?".

- `apps/api` — NestJS 11 on Fastify with MikroORM over Postgres and BullMQ on Redis: shipments,
  labels, tracking, exports and imports, proof-of-delivery photos, the tracking assistant (an
  OpenAI-compatible model gateway reached by `LLM_GATEWAY_URL`) and SMS through Twilio.
- `services/worker` — Python 3.12: carrier event consumer (SQS), rate-card sync, address
  re-validation and the daily carrier manifests (boto3, SQLAlchemy).
- `infra/terraform` — AWS roots `envs/prod`, `envs/preview` and `envs/analytics`, and the
  DigitalOcean dev cluster in `envs/do`; `infra/cloudformation` holds the data account's stack and
  `infra/do` the dev bootstrap script.
- `k8s` — kustomize `base`, `overlays/prod` (EKS) and `overlays/dev` (DOKS); `k8s/monitoring` is
  the self-hosted Prometheus and Alertmanager; `k8s/platform` holds the Velero schedule.
- `ai/finops/attribution.md` — who pays for what; `ai/runbooks/` — the dev platform and the paid
  providers; `docs/adr/` — decisions; `docs/compliance/retention.md` — retention floors.
- `billing/` — last quarter's FOCUS export (trimmed) and the commitment inventory finance keeps.
