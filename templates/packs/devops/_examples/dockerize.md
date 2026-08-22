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

- Confirm runtime port + health endpoint. Record them as `$PORT` and `$HEALTH_PATH` (default `$HEALTH_PATH=/health`) — Phase 6's smoke test uses these, not hardcoded values.
- Consolidated question if env-var inventory not in `.env.example`.
- Success: image builds reproducibly, runs as non-root, smoke test against `$HEALTH_PATH` on `$PORT` returns 200, `.dockerignore` excludes secrets and lock-rebuilt artifacts.

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

Dispatch `@devops-architect` for choice of base image + runtime user.

### The base-image tag is a decision, not a constant

Never copy a runtime version out of a document — the LTS moves twice a year. Resolve it: pin to the
runtime's current Active LTS (or the exact version the project declares in `ai/stack.md` / `.nvmrc` /
`.python-version` / `go.mod`), never a floating major and never `:latest`. The check is "is this
version still receiving security patches on the vendor's published schedule" — for Node that is
`nodejs.org/en/about/previous-releases`. A maintenance-phase major is a finding; an EOL major is a blocker.

### Native and generated dependencies

A multi-stage image that builds cleanly and dies at startup almost always has one cause: something
installed is not portable source. Answer three questions before writing the stages:

1. **Generated at install time from a project file?** ORM query clients (Prisma's `prisma generate`
   reading `schema.prisma`), protobuf/gRPC stubs, GraphQL or OpenAPI codegen. If yes, that input
   file must be copied *before* the install/generate step, and the generate step run explicitly
   rather than left to a postinstall hook.
2. **Does the builder's libc match the runtime's?** Alpine is musl; `slim`/`bookworm` are glibc.
   Native addons, compiled wheels, CGO binaries and generated query engines are built for one and
   will not load on the other. Share a base, or generate for the runtime's target explicitly —
   read the generator's own docs for the target token, do not guess it.
3. **What would `--prod` pruning delete?** Generated output often lives inside a dependency
   directory. `COPY` it across explicitly and verify it exists in the final image.

If all three are "no", say so in one line and move on.

`Dockerfile`:
- **Stage 1 builder** — base pinned per the decision above, manifests + generator input copied first, deps installed with a cache mount, generate step run explicitly, artifacts built.
- **Stage 2 runtime** — minimal base with the same libc as the builder unless artifacts are provably portable, copy only needed artifacts, non-root user, `EXPOSE`, `HEALTHCHECK`, `ENTRYPOINT` + `CMD`.

`.dockerignore` covering: `.git`, `node_modules`, `.env*`, `dist/`, `build/`, `*.log`, IDE folders, test fixtures.

If repo has DB / Redis dep AND no compose → generate `docker-compose.yml` for local dev only.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/docker.md` — create or append (build commands, image size baseline, base-image upgrade procedure).

## Phase 6 — Validate

Dispatch `dockerfile-lint` on the generated Dockerfile first. A BLOCK finding (`:latest`, final
`USER root`, baked secret) halts before the smoke test. After the image builds in release/CI,
dispatch `release-security` on the built image (CVE scan + SBOM + digest signing + provenance).

Then smoke-test against `$PORT` / `$HEALTH_PATH` — the container must be **named** (nothing to read
logs from otherwise) and readiness must be **polled**, not slept at:

```bash
docker build -t app:test .
docker run -d --name app-smoke -p "$PORT:$PORT" app:test

ok=0
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "http://localhost:$PORT$HEALTH_PATH"; then ok=1; break; fi
  sleep 1
done

if [ "$ok" -ne 1 ]; then
  docker logs --tail 50 app-smoke
  docker rm -f app-smoke
  exit 1
fi
```

- Exercise the image's `HEALTHCHECK` **inside the running container**: `docker exec app-smoke <healthcheck-cmd>`. Never `docker run <image> <healthcheck-cmd>` — arguments to `docker run` override `CMD`, so the server never starts and the probe fails for an unrelated reason.
- Confirm non-root: `docker exec app-smoke id`.
- Image size from `docker image inspect --format '{{.Size}}'`; layer breakdown from `docker history` (`docker image inspect` has no per-layer sizes) or `dive`.
- Tear down `docker rm -f app-smoke`. Halt on healthcheck failure or root-user run.

## Phase 7 — Improve

- Image size is judged against a baseline, not an absolute — a static Go binary is tens of MB, a
  scientific Python image is gigabytes. Record this build's size in `ai/runbooks/docker.md`. What
  warrants investigation is a regression against it, or a `docker history` showing builder layers
  surviving into the runtime stage (always a bug, at any size).
- If a base-image swap (alpine → distroless, or a libc change forced by question 2) emerged as a decision, queue ADR.

## Output

```
Files:
  Dockerfile       (multi-stage, distroless runtime, non-root, healthcheck)
  .dockerignore    new
  docker-compose.yml   new (postgres + redis for local dev)

dockerfile-lint: PASS  (hadolint clean; non-root, multi-stage, pinned base, HEALTHCHECK)
Smoke test: PASS  (200 from $HEALTH_PATH on $PORT in 4.2s)

Image:  app:test  142MB  (builder discarded; 6 runtime layers)
```

## Failure modes

- `:latest` on the base image — non-reproducible; pin to digest or specific tag.
- An EOL base image — the quiet version of `:latest`; it passes every pin check while receiving no security patches.
- Running as root — #1 container CVE amplifier; use `USER nonroot` or `USER node`.
- `COPY . .` before `npm install` — invalidates dep cache on every source change.
- Install-before-schema — the install (and its generate hook) runs before the generator's input file is copied. Builds green, starts red.
- libc mismatch across stages — builder on Debian, runtime on Alpine, with a native addon between them.
- Pruning away generated output — `--prod` pruning after a generate step that wrote inside a dependency directory.
- Healthcheck endpoint missing — `HEALTHCHECK` against missing route = always-unhealthy container.
- Secrets via `ARG` — baked into image layer history; use BuildKit secrets (`--mount=type=secret`) or runtime env.
- Compose for prod — wrong tool; prod uses k8s / ECS / fly.
