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

- Confirm runtime port + health endpoint. Record them as `$PORT` and `$HEALTH_PATH` (default `$HEALTH_PATH=/health`) — Phase 6's smoke test uses these, not hardcoded values. If the app serves health on a non-default path or a separate admin port, capture both.
- Consolidated question if env-var inventory not in `.env.example`.
- Success: image builds reproducibly, runs as non-root, smoke test against `$HEALTH_PATH` on `$PORT` returns 200, `dockerfile-lint` passes, `.dockerignore` excludes secrets and lock-rebuilt artifacts.

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

Never copy a runtime version out of this file or any other document — the LTS moves twice a year and
a document that names one is wrong within months. Resolve it: **pin to the runtime's current Active
LTS (or the exact version in `ai/stack.md` / `.nvmrc` / `.python-version` / `go.mod` if the project
declares one), never to a floating major and never to `:latest`.** A base whose upstream has entered
maintenance — let alone passed EOL — stops receiving security patches, so the check is "is this
version still receiving patches on the vendor's published schedule", not "is this the version we
used last time". For Node that schedule is `nodejs.org/en/about/previous-releases`; every other
runtime publishes an equivalent. A maintenance-phase major is a finding; an EOL major is a blocker.

### Native and generated dependencies — the decision this command exists to get right

A multi-stage Dockerfile that builds cleanly and dies at startup is the normal failure here, and it
has one cause: something in `node_modules` / `site-packages` / `vendor` is **not portable source**.
It was either generated at install time from a file, or compiled against the builder's C library.
Before writing the stages, answer three questions:

1. **Is any dependency generated at install time from a project file?** ORM query clients (Prisma's
   `prisma generate` reading `schema.prisma`), protobuf/gRPC stubs from `.proto`, GraphQL codegen
   from a schema, OpenAPI client generation. If yes, the generator needs its **input file
   on disk**, so a `COPY` of that schema/proto/spec must precede the install-or-generate step —
   putting the whole `COPY . .` after the install is what breaks it. Run the generate step
   explicitly rather than trusting a postinstall hook to fire.
2. **Does the builder's libc match the runtime's?** Alpine is musl; Debian-based (`slim`, `bookworm`)
   is glibc. Anything with a compiled artifact — native addons, image/crypto libraries, Python
   wheels, CGO binaries, and generated ORM query engines — is built for one and will not load on the
   other. Either both stages share a base, or the generated/compiled artifact is produced for the
   runtime's target explicitly (most generators take a target list; read *its* docs for the token —
   do not guess the identifier, it is versioned).
3. **What must survive the stage boundary that a `--prod` prune would delete?** `pnpm prune --prod` /
   `npm prune --omit=dev` remove dev dependencies, and generated output frequently lives *inside*
   a dependency's directory. If step 1 produced anything, `COPY` it across explicitly and verify it
   is present in the final image — do not assume the pruned `node_modules` carried it.

If all three answers are "no native, no generated, no prune", say so in one line and move on. The
cost of asking is a sentence; the cost of not asking is a green build and a red container.

`Dockerfile`:
- **Stage 1 builder** — base pinned per the decision above, dependency manifests + any generator
  input copied first, deps installed with a cache mount, generate step run explicitly, build artifacts produced.
- **Stage 2 runtime** — minimal base **with the same libc as the builder** unless the artifacts are
  provably portable, copy only needed artifacts from builder (including anything from step 1),
  non-root user, `EXPOSE` declared port, `HEALTHCHECK`, `ENTRYPOINT` + `CMD`.

`.dockerignore` covering: `.git`, `node_modules`, `.env*`, `dist/`, `build/`, `*.log`, IDE folders, test fixtures.

If repo has DB / Redis dep AND no compose → generate `docker-compose.yml` for local dev only.

## Phase 5 — Update

- `ai/status.md` — Recent Changes entry.
- `ai/dynamic/changelog.md` — one-line summary.
- `ai/runbooks/docker.md` — create or append (build commands, image size baseline, base-image upgrade procedure).

## Phase 6 — Validate

Dispatch the `dockerfile-lint` skill on the generated Dockerfile first — it ships hadolint + the project-rule checks (non-root, multi-stage, pinned base, HEALTHCHECK, `.dockerignore`, secret-in-history). A BLOCK finding (`:latest`, final `USER root`, baked secret) halts before the smoke test.

After the image builds (release/CI, not local dev), dispatch the **`release-security`** skill on the built image — CVE scan (`trivy image`, gate on HIGH/CRITICAL) + SBOM (`syft`) + digest signing (`cosign`, keyless OIDC) + SLSA provenance. `dockerfile-lint` checks the *Dockerfile*; `release-security` checks the *built image + its signature/SBOM*. This is the producer the security pack's A03 Supply-Chain audit dispatches to.

Then smoke-test against the Phase 1 `$PORT` / `$HEALTH_PATH` (never hardcoded `8080` / `/health`).
The container must be **named** (there is nothing to read logs from otherwise) and the readiness
must be **polled**, not slept at — a fixed `sleep` either fails a slow-starting app or wastes the
window on a fast one:

```bash
docker build -t app:test .
docker run -d --name app-smoke -p "$PORT:$PORT" app:test

ok=0
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null "http://localhost:$PORT$HEALTH_PATH"; then ok=1; break; fi
  sleep 1
done

if [ "$ok" -ne 1 ]; then
  docker logs --tail 50 app-smoke      # the reason lives here, not in curl's exit code
  docker rm -f app-smoke
  exit 1
fi
```

- Confirm the image's own `HEALTHCHECK` passes **inside the running container** —
  `docker exec app-smoke <healthcheck-cmd>`. Do NOT use `docker run <image> <healthcheck-cmd>`:
  arguments passed to `docker run` override `CMD`, so the server never starts and the healthcheck
  is being asked to probe a process that was never launched. It will fail for a reason that has
  nothing to do with the image. If the exec exits non-zero, halt and surface `docker logs`.
- Confirm non-root user: `docker exec app-smoke id` (the runtime user of the *running* container,
  which is what actually matters — see `dockerfile-lint`'s final-stage check).
- Print image size (`docker image inspect --format '{{.Size}}'`) **and** the layer breakdown from
  `docker history` — `docker image inspect` returns the config and a digest list with no per-layer
  sizes, so it cannot produce a breakdown. `dive` gives the same view interactively.
- Tear down: `docker rm -f app-smoke`. Halt on healthcheck failure or root-user run.

## Phase 7 — Improve

- **Image size is judged against a baseline, not an absolute.** A static Go binary in `scratch` is
  tens of MB; a Python image with a scientific stack is gigabytes, and neither number is a defect on
  its own. Record this build's size in `ai/runbooks/docker.md` as the baseline. What warrants
  investigation is a **regression** against it (roughly: a jump with no dependency change) or a
  `docker history` breakdown showing the *builder's* layers surviving into the runtime stage —
  that one is always a bug, at any size. Queue either to `ai/dynamic/learned-patterns.md`.
- If a base-image swap (alpine → distroless, or musl → glibc forced by Phase 4 question 2) emerged
  as a decision, queue ADR — the libc choice constrains every future native dependency.

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
- **An EOL base image.** `:latest` is the loud version of this; a pinned-but-unsupported major is the
  quiet one, and it passes every pin check in the pack while receiving no security patches.
- Running as root — #1 container CVE amplifier; use `USER nonroot` or `USER node`.
- `COPY . .` before `npm install` — invalidates dep cache on every source change.
- **Install-before-schema.** The mirror-image mistake: the dependency install (and its generate hook)
  runs before the file the generator reads has been copied, so the client is silently absent or
  empty. Builds green, starts red. Copy the generator's input with the manifests.
- **libc mismatch across stages.** Builder on Debian, runtime on Alpine (or the reverse), with a
  native addon or a generated engine between them — the loader error names a `.so`, not the stage.
- **Pruning away generated output.** `--prod` pruning after a generate step that wrote inside a
  dependency directory. The fix is an explicit `COPY` of the generated artifact, plus verifying it
  exists in the final image rather than assuming.
- Healthcheck endpoint missing — `HEALTHCHECK` against missing route = always-unhealthy container.
- Secrets via `ARG` — baked into image layer history; use BuildKit secrets (`--mount=type=secret`) or runtime env.
- Compose for prod — wrong tool; prod uses k8s / ECS / fly.

## Related

### Sibling commands in devops pack
- `/add-ci` — sibling command in devops pack

### Skills
- `dockerfile-lint` — dispatched in Phase 6 to lint the generated Dockerfile before the smoke test.

### Patterns
- `ai/patterns/cicd-pipeline.md`
- `ai/patterns/deployment.md`

### Rules
- `.claude/rules/devops-principles.md`
