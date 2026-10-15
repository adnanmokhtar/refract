# Secrets runbook — production EKS cluster

The workload Secrets Argo CD does not own are created by hand, once per cluster build, from the same laptop session
as `platform.md`. External Secrets is planned (it replaces this file).

## 1. Payment provider keys

From the provider's dashboard (Developers → API keys), copy the live key and the webhook signing secret:

```bash
kubectl -n larder create secret generic payments-provider \
  --from-literal=PAYMENTS_API_KEY='<live secret key from the dashboard>' \
  --from-literal=PAYMENTS_WEBHOOK_SECRET='<signing secret from the same page>'
```

## 2. Sessions Valkey (`larder-sessions`, `iac/envs/prod/cache.tf`)

The api keeps sessions and checkout idempotency keys there; Traefik's distributed rate limit counts requests in the
same replication group.

```bash
SESSIONS_HOST=master.larder-sessions.abc123.euc1.cache.amazonaws.com
SESSIONS_TOKEN="$(aws secretsmanager get-secret-value --secret-id larder/prod/valkey-sessions --query SecretString --output text)"
kubectl -n larder create secret generic api-sessions \
  --from-literal=SESSIONS_URL="rediss://default:${SESSIONS_TOKEN}@${SESSIONS_HOST}:6379"
kubectl -n traefik create secret generic traefik-ratelimit \
  --from-literal=REDIS_PASSWORD="${SESSIONS_TOKEN}"
```

## 3. Queue Valkey users

Each consumer of the queue store has its own ACL user (`ACL SETUSER notifier …`, `ACL SETUSER dispatch …`, run once
by the store's admin), so each Secret holds a different password.

```bash
QUEUES_HOST=master.larder-queues.abc123.euc1.cache.amazonaws.com
NOTIFIER_QUEUE_PASSWORD="$(aws secretsmanager get-secret-value --secret-id larder/prod/queues-notifier --query SecretString --output text)"
DISPATCH_QUEUE_PASSWORD="$(aws secretsmanager get-secret-value --secret-id larder/prod/queues-dispatch --query SecretString --output text)"
kubectl -n larder create secret generic notifier-queue \
  --from-literal=QUEUE_URL="rediss://notifier:${NOTIFIER_QUEUE_PASSWORD}@${QUEUES_HOST}:6379"
kubectl -n larder create secret generic dispatch-queue \
  --from-literal=QUEUE_URL="rediss://dispatch:${DISPATCH_QUEUE_PASSWORD}@${QUEUES_HOST}:6379"
```

## 4. Ledger signing key

Run from the `ops-toolbox` pod, which mounts the key from AWS Secrets Manager through the Secrets Store CSI driver; the
key never touches the laptop or the shell history.

```bash
kubectl -n larder exec -it deploy/ops-toolbox -- \
  kubectl -n larder create secret generic ledger-signing \
  --from-file=signing.key=/mnt/secrets-store/ledger-signing-key
```
