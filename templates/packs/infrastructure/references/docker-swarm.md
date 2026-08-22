# Docker Swarm reference

> **Tool**: Docker Engine 24+ in Swarm mode • Compose v3.9 (Swarm-mode supported subset)
> **Official docs**: https://docs.docker.com/engine/swarm/
> **Version-specific gotchas**: Swarm mode is in maintenance (no major new features since ~2020) — Docker Inc. focuses on Kubernetes; compose-spec still works but Swarm-only fields (`deploy:`) are ignored by `docker compose up`; secrets file-mount path is `/run/secrets/<name>`; `docker stack deploy` uses Compose v3.9 schema (NOT the latest compose-spec).
> **Substitution markers**: Replace registry / image / port with the project's actuals.

**Read the maintenance status before the syntax.** Swarm mode is in maintenance: it still works and is still shipped, but it has had no major feature work in years, its ecosystem is a fraction of Kubernetes', and it has no NetworkPolicy equivalent and no built-in autoscaling. That makes it a **defensible place to STAY, and a poor place to GO.**

This reference exists because projects already running Swarm need their conventions written down, not to recommend adopting it.

## Is Swarm still the right answer here?

| Situation | Answer |
|---|---|
| Already on Swarm, it meets the requirements, nobody is fighting it | **Stay.** A migration you do not need is pure risk. Confirm the requirements below still hold. |
| Already on Swarm and hitting a stated limit (below) | Move — and `@infra-architect` decides the target, which is often a managed container runtime rather than Kubernetes |
| Greenfield, no orchestrator yet | Do not start here. A managed container runtime gives you the same "Compose, but multi-host" ergonomics with an active roadmap |

The requirements Swarm still satisfies, and the ones it does not:

- **Satisfied**: fixed replica counts, rolling updates with automatic rollback, file-mounted secrets, overlay networking, self-healing, a Docker-native workflow on a handful of nodes.
- **Not satisfied**: horizontal autoscaling (there is none — you run `docker service scale`), per-service network policy (overlay separation is the only boundary), a policy/admission layer, and any of the ecosystem tooling this pack's other references assume.

If a requirement in the second list has become real, that is the signal to move — not a general sense that Swarm is unfashionable.

## Compose file (Swarm mode)

```yaml
version: '3.9'
services:
  api:
    image: registry.example.com/api:sha-abc123
    ports:
      - "80:3000"
    environment:
      - NODE_ENV=production
    secrets:
      - database_url
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
        failure_action: rollback
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
      resources:
        reservations: { cpus: '0.25', memory: 256M }
        limits:       { cpus: '1.0',  memory: 512M }
      placement:
        constraints: [node.role == worker]
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1))"]
      interval: 30s
      timeout: 5s
      retries: 3
    networks:
      - appnet

secrets:
  database_url:
    external: true

networks:
  appnet:
    driver: overlay
```

Deploy:
```bash
docker stack deploy -c docker-compose.prod.yml app
```

## Features

- **Services** with desired replicas + rolling updates.
- **Secrets** mounted as `/run/secrets/<name>` files (not env).
- **Overlay networks** for multi-host service discovery.
- **Built-in load balancer** (routing mesh) — any node routes to any task.
- **Self-healing** — failed containers restart per `restart_policy`.

## Rolling updates

- `parallelism: N` — how many containers update at once.
- `order: start-first` — new container up before old down (zero-downtime).
- `failure_action: rollback` — auto-revert on failure.

## Secrets

- `docker secret create database_url ./db_url.txt`
- Mounted at `/run/secrets/database_url` — read as a file, not env var.
- NEVER commit secrets. Bootstrap via CI / manual admin.

## Node roles

- **Manager** — maintains cluster state (raft consensus). 3 or 5 for HA.
- **Worker** — runs tasks.
- Constrain stateful services: `node.labels.role == db` on specific nodes with storage.

## Storage

- Local volumes: tied to a node. OK for dev.
- External: NFS / object store / managed DB. Don't use local for stateful prod services.

## Limits vs K8s

- No horizontal autoscaling built-in (fixed replicas; scale with `docker service scale`).
- Smaller ecosystem (Helm charts, operators, etc. are K8s-specific).
- No NetworkPolicy equivalent (you rely on overlay network separation).
- Being de-emphasized by Docker — no major new features in years.

## Forbidden

- Local volumes for stateful prod services.
- Secrets as env vars (file-mounted only).
- `:latest` tags.
- Manager on a public network (only exposed via an HA VIP + bastion).
