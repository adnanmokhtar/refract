# Configuration

The API validates its environment at boot against `apps/api/src/config/env.schema.ts` and
refuses to start when a required variable is missing. Locally the values come from
`apps/api/.env`; in the cluster from the `tallyhook-config` ConfigMap and the `tallyhook-api`
Secret.

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | - | Postgres connection string. Required. |
| `REDIS_URL` | `redis://localhost:6379` | Queues and the shared rate limiter. |
| `JWT_SECRET` | - | Signs merchant session tokens. Required. |
| `WEBHOOK_SECRET` | - | Signs outbound webhook deliveries. Required. |
| `RETRY_LIMIT` | `5` | Delivery attempts per webhook before the delivery is parked. |
| `LOG_FORMAT` | `json` | `json` or `text`. |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warn` or `error`. |
| `INVOICE_BUCKET` | `tallyhook-invoices` | Bucket that holds the invoice PDFs. |
| `REPORTS_TIMEZONE` | `UTC` | Time zone of the nightly reports cut-off. |
| `SEARCH_INDEX_URL` | - | Full-text search over orders and invoices. |

## Changing a value

Locally, edit `apps/api/.env` and restart the API. In the cluster, change the ConfigMap in
`deploy/k8s/api.yaml` through a pull request; the rollout restarts the pods. Secrets are rotated
by the platform team and never committed.

## Precedence

The schema's default applies only when the variable is absent. An empty value is not absent: it
fails validation for every variable that has a minimum length.

## Platform variables

`NODE_ENV` and `PORT` are set by the container runtime in every environment; do not put them in
`.env`.

On a workstation the invoice store's AWS SDK reads `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the environment;
in the cluster it uses the pod's role.
