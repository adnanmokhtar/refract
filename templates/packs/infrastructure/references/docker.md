# Docker reference

## Dockerfile — the canonical shape

```dockerfile
# syntax=docker/dockerfile:1.7

# ---- Build stage
FROM node:20.11-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY . .
RUN pnpm build && pnpm prune --prod

# ---- Runtime stage
FROM node:20.11-alpine AS runtime
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

## Rules

- Multi-stage: build dependencies don't ship.
- Pinned base image (`node:20.11-alpine`, not `node:latest`).
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
- Missing `HEALTHCHECK`.
- Single-stage Dockerfile for a compiled app.
