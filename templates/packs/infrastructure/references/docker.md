# Docker reference

> **Tool**: Docker Engine with BuildKit (the default builder since Engine 23.0) • Compose v2 (`docker compose`, NOT `docker-compose`). Confirm the local engine with `docker version` rather than assuming a floor.
> **Official docs**: https://docs.docker.com/ • Dockerfile reference: https://docs.docker.com/reference/dockerfile/
> **Version-specific gotchas**: BuildKit (default since 23.0) enables cache mounts + secret mounts + bind mounts via `--mount`; `docker compose` v2 (Go binary) replaces Python `docker-compose`; `compose-spec` is the canonical schema; `--platform` flag for cross-arch builds; SBOM + provenance attestations via `--sbom=true --provenance=true`.
> **Substitution markers**: Replace the base image / port `3000` with the project's actual values.
> **Base-image currency**: a runtime major goes end-of-life on a published schedule — Node's is https://nodejs.org/en/about/previous-releases (v18 ended 2025-04-30, v20 ended 2026-04-30, v22 runs to 2027-04-30, v24 to 2028-04-30). **Read the schedule; do not copy a version out of this file.** A base image on an EOL major stops receiving security patches while still building green, which is the failure mode nothing in CI catches.

## Dockerfile — the canonical shape

```dockerfile
# syntax=docker/dockerfile:1.7

# ---- Build stage
#   Pin to a SUPPORTED major (check the EOL schedule), then pin the digest in prod.
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
# Anything code-generated from source (ORM clients, protobuf stubs) must run AFTER
# the source is copied — see "Generated + native dependencies" below.
RUN pnpm build && pnpm prune --prod

# ---- Runtime stage
#   Same base as the build stage: a native module built against one libc will not
#   load on the other. alpine is musl; the default images are glibc.
FROM node:22-alpine AS runtime
RUN addgroup -g 1001 app && adduser -D -u 1001 -G app app
WORKDIR /app
COPY --from=build --chown=app:app /app/node_modules ./node_modules
COPY --from=build --chown=app:app /app/dist ./dist
COPY --from=build --chown=app:app /app/package.json ./
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1))"
CMD ["node", "dist/main.js"]
```

## Generated + native dependencies — the decision this file exists to teach

A multi-stage Dockerfile is easy. The part that breaks in production is what crosses the stage boundary. Before writing one, answer three questions:

1. **Is any dependency BUILT or GENERATED at install time?** ORM clients generated from a schema, protobuf/gRPC stubs, native addons compiled by `node-gyp`, image/crypto libraries with prebuilt binaries, Python wheels with C extensions. If yes, the generate step must run **after** the files it reads are in the image — an install that runs before `COPY . .` cannot see a schema that has not been copied yet.
2. **Does the builder's libc match the runtime's?** alpine is musl; the standard images are glibc. A native module or a generated engine compiled for one will not load on the other. Either use the same base for both stages, or make the generator emit a binary for the runtime's target.
3. **What would `prune --prod` (or a naive `COPY --from`) delete?** Generated artifacts often live inside `node_modules` (or the language's equivalent) and are not listed in any manifest, so a dependency prune or a selective copy silently removes them. Copy them explicitly, or generate in the runtime stage.

The failure shape is identical across ecosystems: **the image builds successfully and the container crashes on first request.** A build that goes green proves nothing about this class; only starting the container and exercising one real code path does.

## Rules

- Multi-stage: build dependencies don't ship.
- Pinned base image on a supported major (never `:latest`); digest-pinned in prod.
- Non-root user (USER app after COPY).
- HEALTHCHECK with start period for slow-boot apps.
- `.dockerignore` aggressive:

```
node_modules
.git
.github
.env
.env.*
*.log
dist
build
coverage
.claude
ai
README.md
CLAUDE.md
```

## BuildKit features

- Cache mounts: `RUN --mount=type=cache,target=/root/.pnpm-store pnpm install`
- Secret mounts: `RUN --mount=type=secret,id=npmrc,target=/root/.npmrc pnpm install`
- Bind mounts for read-only source.
- Faster builds, smaller images.

## Image size targets

- Node / Python apps: < 200 MB.
- Go / Rust binaries: < 50 MB (distroless / scratch base).
- Frontend builds: < 100 MB (just nginx + static files).

## Security

- Scan in CI: `docker scout cves IMAGE` or `trivy image IMAGE`.
- Sign images (cosign) for supply-chain integrity.
- Pin base image digest in prod: `FROM node@sha256:...` (vs tag).
- Re-check the base major against its EOL schedule on every dependency sweep. A digest pin freezes the image; it does not stop the major behind it from going out of support.

## Compose (for dev / small prod)

```yaml
services:
  api:
    build: ./api
    environment:
      - DATABASE_URL=postgres://db/app
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 10s
    volumes:
      - db-data:/var/lib/postgresql/data
volumes:
  db-data:
```

## Forbidden

- `USER root` as final USER.
- `:latest` tags in prod.
- Secrets copied into layers (visible via `docker history`).
- Apt-get / apk without version pins + no-cache cleanup.
- Missing `HEALTHCHECK`. (Note the scope: a container runtime and ECS task definitions read the image `HEALTHCHECK`; **Kubernetes does not** — kubelet probes come from `spec.containers[].livenessProbe` / `readinessProbe` in the pod spec. Declare both; neither substitutes for the other.)
- Single-stage Dockerfile for a compiled app.
- A base image on an end-of-life major. It builds; it is simply no longer patched.
