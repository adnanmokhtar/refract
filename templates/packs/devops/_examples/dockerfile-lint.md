---
name: dockerfile-lint
description: Lint Dockerfile for safety, size, and correctness. Uses hadolint + project rules (non-root, multi-stage, pinned base, healthcheck).
---
<!-- generated-from: templates/packs/devops/skills/dockerfile-lint/SKILL.md
     Literal-copy fallback: this file carries its source verbatim because the source has no
     droppable section left once the safety block is kept. Declaring it makes check 8b compare
     the two bodies line-for-line (COPY-DRIFT). REGENERATE whenever the source changes —
     do not hand-edit; edit the source and re-copy. -->

# dockerfile-lint

Catch unsafe + bloated Dockerfiles before they hit a registry.

## Premise

Find real issues, cite the Dockerfile line and the rule that fires. Hadolint findings are reported with their rule code (DL3008, DL3007, etc.). Project-rule failures (HEALTHCHECK missing, USER root, no `.dockerignore`) cite the actual line absent or the value detected. Image size, layer count, and "secret in history" come from `docker inspect` / `docker history` output captured during a real build — not from reading the source alone.

## Halt conditions

- Refuse to report "no HEALTHCHECK" without grepping the file.
- Refuse to flag "secret in image" without showing the `docker history` line that contains it.
- Halt if `docker build` failed — fix the build first, then lint.
- Don't dismiss a hadolint warning without naming why it's acceptable.
- `:latest` tag = block. `USER root` as final = block. Secrets baked in = critical (rotate the leaked credential).

## When to use

- Before merging a new Dockerfile or any change to one.
- After a base-image bump to confirm the pin is still tight.
- After a CVE alert against a base image — verify replacement.
- Quarterly to enforce non-root + healthcheck across all services.

## Prerequisites

- `hadolint` installed (`brew install hadolint` or `docker run --rm -i hadolint/hadolint`).
- `dive` for layer audit (optional but recommended).
- Local `docker` daemon for image build + size measurement.

## Procedure

1. Run hadolint against every Dockerfile:
   ```bash
   find . -name 'Dockerfile*' -not -path '*/node_modules/*' \
     | xargs -I{} hadolint --no-color {}
   ```
2. Verify multi-stage + final-stage USER:
   ```bash
   awk '/^FROM/ {n++} /^USER/ {u=$2} END {print "stages="n" user="u}' Dockerfile
   ```
   Expect `stages>=2` and `user!=root` (and not numeric `0`).
3. Verify HEALTHCHECK declared:
   ```bash
   grep -q '^HEALTHCHECK' Dockerfile || echo "MISSING HEALTHCHECK"
   ```
4. Verify base image is pinned to a digest or specific tag (no `:latest`, no floating major):
   ```bash
   grep -E '^FROM' Dockerfile | grep -E ':(latest|[0-9]+)\s|@sha256' || echo "FROM line not strictly pinned"
   ```
5. Verify `.dockerignore` excludes the usual offenders:
   ```bash
   for p in node_modules .env .env.* .git dist build .next .nuxt coverage; do
     grep -q "^$p" .dockerignore || echo "missing: $p"
   done
   ```
6. Build + measure layers + scan history for secrets:
   ```bash
   docker build -t scan/img:lint .
   docker history --no-trunc scan/img:lint | grep -iE '(secret|token|password|api[_-]?key)' && echo "POSSIBLE SECRET IN LAYER"
   docker image inspect scan/img:lint --format '{{.Size}}' | awk '{print $1/1024/1024" MB"}'
   dive scan/img:lint --ci    # exits non-zero if efficiency < threshold
   ```

## Output

```
Dockerfile audit

Hadolint:
  PASS  DL3008  pin apt versions
  PASS  DL3009  apt-get clean
  WARN  DL3007  latest tag used in FROM — pin to node:20.10-alpine

Project rules:
  PASS  Multi-stage: 2 stages (build, runtime)
  PASS  Non-root user (USER node)
  FAIL  HEALTHCHECK missing
  PASS  .dockerignore present (covers node_modules, .env, .git, dist)

Image:
  Size:       247 MB
  Layers:     12
  Secrets:    none detected in `docker history`

Blockers:
  1. HEALTHCHECK missing — kube/ECS liveness probes degrade to TCP-only.

Suggested fix:
  HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health',r=>process.exit(r.statusCode===200?0:1))"
```

## False positives / gotchas

- `apt-get install -y package` without version pin is hadolint DL3008 — but pinning every system package is high churn; document the trade-off.
- `USER 1001` is non-root but unreadable — prefer named user with `useradd`.
- Multi-stage with `FROM scratch` final stage CAN'T have HEALTHCHECK shell commands — use exec form with a static binary.
- `docker history` shows secrets only if they were `RUN echo $SECRET` style; build-arg secrets aren't exposed there but ARE in the image config — `docker inspect` is the deeper check.
- `:latest` tag = block. `USER root` as final = block. Secrets baked in = critical (rotate the leaked credential).
