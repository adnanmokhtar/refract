# Runbook — dev platform on DigitalOcean

The dev environment (`k8s/overlays/dev`) runs on the DOKS cluster `qw-dev` in `fra1`, created by
`infra/terraform/envs/do`. The managed databases are created by hand from this runbook and from
`infra/do/bootstrap.sh`; the connection strings live in the `quaywise-secrets` Secret of the
`quaywise-dev` namespace.

## Create the dev Postgres

```bash
doctl databases create qw-dev-pg \
  --engine pg \
  --version 17 \
  --size db-s-1vcpu-2gb \
  --region fra1 \
  --num-nodes 1
doctl databases firewalls append "$(doctl databases list --format ID,Name --no-header | awk '$2 == "qw-dev-pg" { print $1 }')" \
  --rule "k8s:$(doctl kubernetes cluster get qw-dev --format ID --no-header)"
```

Load the anonymised snapshot with `pg_restore --no-owner -d "$DEV_DATABASE_URL" dev-snapshot.dump`.

## What the dev account runs each month

| Item | Shape | Monthly |
|---|---|---|
| DOKS node pool | 2 × s-4vcpu-8gb | $96/mo |
| Managed Postgres | db-s-1vcpu-2gb | $30/mo |
| Managed Valkey | db-s-1vcpu-1gb | $15/mo |

## Deploying

`kubectl apply -k k8s/overlays/dev` with the `do-fra1-qw-dev` context. The API and worker images
are the ones CI pushed for the branch; `kubectl rollout status deploy/quaywise-api -n quaywise-dev`.

## Silencing alerts during a node pool upgrade

Create the silence with an end, never an open one:

```json
{
  "matchers": [{ "name": "namespace", "value": "quaywise-dev", "isRegex": false }],
  "startsAt": "2026-10-03T08:00:00Z",
  "endsAt": "2026-10-03T12:00:00Z",
  "createdBy": "platform-oncall",
  "comment": "DOKS node pool upgrade"
}
```

`curl -s -X POST -H 'content-type: application/json' --data @silence.json "$ALERTMANAGER_URL/api/v2/silences"`

## Tearing down

Dev data is disposable: `doctl databases delete qw-dev-pg` and re-create from this runbook.
