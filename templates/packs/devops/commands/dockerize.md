---
description: Generate a production-ready Dockerfile, .dockerignore, and optional compose for local dev.
---

# /dockerize

Multi-stage, non-root, healthchecked image for the detected stack.

## Phases applied

All 7. Phase 6 includes a smoke test against the built image.

## When to use / NOT to use
- USE: new repo with no Dockerfile; existing Dockerfile is single-stage / runs as root / pins `:latest`.
- NOT: deploy target is serverless and image isn't needed (Lambda zip, Cloudflare Workers).

## Phase 1 — Understand

- Confirm runtime port + health endpoint.
- Consolidated question if env-var inventory not in `.env.example`.
- Success: image builds reproducibly, runs as non-root, smoke test against `/health` returns 200, `.dockerignore` excludes secrets and lock-rebuilt artifacts.

## Phase 2 — Organize

- Detect stack (Phase 3).
- Plan: pinned base image, two-stage build, runtime user, healthcheck, dockerignore, optional compose.
- Decide base image flavor (distroless / alpine / slim) — pause for confirmation if non-obvious.

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` — runtime + scripts.
- `.env.example` — env-var inventory.
- `ai/stack.md` — language version, package manager.

Detect stack:
- `package.json` + `bun.lockb` → Bun.
- `package.json` + `pnpm-lock.yaml` → Node + pnpm.
- `package.json` + `package-lock.json` → Node + npm.
- `pyproject.toml` → Python (uv / poetry by lockfile presence).
- `go.mod` → Go.
- `Cargo.toml` → Rust.

## Phase 4 — Generate

Dispatch `devops-architect` for choice of base image + runtime user.

`Dockerfile`:
- **Stage 1 builder** — pinned base (`node:20.11-alpine` not `node:alpine`), install deps with cache mount, build artifacts.
- **Stage 2 runtime** — minimal base, copy only needed artifacts from builder, non-root user, `EXPOSE` declared port, `HEALTHCHECK`, `ENTRYPOINT` + `CMD`.

`.dockerignore` covering: `.git`, `node_modules`, `.env*`, `dist/`, `build/`, `*.log`, IDE folders, test fixtures.

If repo has DB / Redis dep AND no compose → generate `docker-compose.yml` for local dev only.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/docker.md` — create or append (build commands, image size baseline, base-image upgrade procedure).

## Phase 6 — Validate

```bash
docker build -t app:test .
docker run --rm -p 8080:8080 app:test &
sleep 5 && curl -f http://localhost:8080/health
```

- Print image size + layer breakdown (`docker image inspect`).
- Confirm non-root user (`docker run --rm app:test id`).
- HALT on healthcheck failure or root-user run.

## Phase 7 — Improve

- If image > 200MB, queue investigation to `ai/dynamic/learned-patterns.md` (multi-stage may need tighter copy patterns).
- If a base-image swap (alpine → distroless) emerged as decision, queue ADR.

## Output

```
Files:
  Dockerfile       (multi-stage, distroless runtime, non-root, healthcheck)
  .dockerignore    new
  docker-compose.yml   new (postgres + redis for local dev)

Smoke test: PASS  (200 from /health in 4.2s)

Image:  app:test  142MB  (builder discarded; 6 runtime layers)
```

## Failure modes

- `:latest` on the base image — non-reproducible; pin to digest or specific tag.
- Running as root — #1 container CVE amplifier; use `USER nonroot` or `USER node`.
- `COPY . .` before `npm install` — invalidates dep cache on every source change.
- Healthcheck endpoint missing — `HEALTHCHECK` against missing route = always-unhealthy container.
- Secrets via `ARG` — baked into image layer history; use BuildKit secrets or runtime env.
- Compose for prod — wrong tool; prod uses k8s / ECS / fly.

## Related

### Sibling commands in devops pack
- `/add-ci` — sibling command in devops pack

### Patterns
- `ai/patterns/cicd-pipeline.md`
- `ai/patterns/deployment.md`

### Rules
- `.claude/rules/devops-principles.md`
