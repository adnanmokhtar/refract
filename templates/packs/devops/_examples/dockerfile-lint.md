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

Find real issues, cite the Dockerfile line and the rule that fires. Hadolint findings are reported with their rule code (DL3008, DL3007, etc.). Project-rule failures (HEALTHCHECK missing, final-stage USER root, no `.dockerignore`) cite the actual line absent or the value detected. Image size, layer count, and "secret in history" come from `docker inspect` / `docker history` output captured during a real build — not from reading the source alone.

**Every check below reads the FINAL stage.** A multi-stage Dockerfile has one stage that ships and N that do not, and almost every false pass in this skill's history came from a check that answered about the builder. `USER node` in the build stage does not make the runtime non-root.

## Halt conditions

- Refuse to report "no HEALTHCHECK" without grepping the file.
- Refuse to flag "secret in image" without showing the `docker history` line that contains it.
- Halt if `docker build` failed — fix the build first, then lint.
- Don't dismiss a hadolint warning without naming why it's acceptable.
- `:latest` tag = block. Untagged `FROM` = block (it resolves to `:latest`). Final-stage `USER root` (or no `USER` at all in the final stage) = block. Secrets baked in = critical (rotate the leaked credential).

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
2. Verify multi-stage + the **final stage's** user. Resetting the accumulator at each `FROM` is the
   whole point — reading the last `USER` anywhere in the file reports the builder's user and passes
   a Dockerfile that runs as root:
   ```bash
   awk '/^[Ff][Rr][Oo][Mm][[:space:]]/ { n++; u="" }
        /^[Uu][Ss][Ee][Rr][[:space:]]/  { u=$2 }
        END { print "stages=" n "  final_stage_user=" (u=="" ? "<none> -> ROOT" : u) }' Dockerfile
   ```
   Expect `stages>=2` and a final user that is neither empty, `root`, nor `0`.
3. Verify HEALTHCHECK declared (and see § False positives for when its absence is a blocker vs a nit):
   ```bash
   grep -q '^HEALTHCHECK' Dockerfile || echo "MISSING HEALTHCHECK"
   ```
4. Classify every base image. **One grep cannot do this, and the failure is not theoretical** — the
   check this step replaced was `grep -E '^FROM' Dockerfile | grep -E ':(latest|[0-9]+)\s|@sha256'`,
   and its `\s` makes the tag branch match only when whitespace *follows* the tag. Measured against
   real lines: `FROM node:latest AS build` **passes** (the `AS` supplies the whitespace — and
   multi-stage is exactly what this skill requires, so the blocker slips through in the normal case),
   `FROM node:22 AS build` passes (a floating major, the weakest tag), while `FROM node:22-alpine`
   and `FROM node:22.1-alpine` are both reported "not strictly pinned". It accepts what it should
   block and rejects what it should accept. Classify instead, skipping `FROM <earlier-stage>` lines,
   which carry no registry reference:
   ```bash
   awk '
     toupper($1)=="FROM" {
       for (i=2; i<=NF; i++) if (toupper($i)=="AS") stage[$(i+1)]=1
       ref=""
       for (i=2; i<=NF; i++) { if ($i ~ /^--/) continue; ref=$i; break }
       if (ref in stage) next                       # FROM builder AS runtime
       if      (ref ~ /\$/)                    v="WARN   ARG-driven base - resolve the value"
       else if (ref ~ /@sha256:/)              v="OK     digest-pinned (strongest)"
       else if (ref ~ /:latest$/)              v="BLOCK  :latest"
       else if (ref !~ /:/)                    v="BLOCK  untagged - resolves to :latest"
       else if (ref ~ /:[^:]*[0-9]+\.[0-9]+/)  v="OK     version tag - digest is stronger"
       else                                    v="WARN   floating tag - no minor/patch"
       printf "  %-42s %s\n", ref, v
     }' Dockerfile
   ```
   Then apply the judgement the classifier cannot: **is the pinned version still supported?** A
   correctly pinned EOL base passes every check above and receives no security patches. Compare the
   tag against the runtime's published release schedule (Node: `nodejs.org/en/about/previous-releases`;
   every runtime has one). Maintenance-phase = finding, EOL = blocker.
5. Verify `.dockerignore` excludes the usual offenders:
   ```bash
   for p in node_modules .env .env.* .git dist build .next .nuxt coverage; do
     grep -q "^$p" .dockerignore || echo "missing: $p"
   done
   ```
6. BuildKit hygiene. BuildKit is the default builder for Docker Desktop and Docker Engine, so these
   are not exotic features — a Dockerfile that ignores them is paying for cold dependency installs
   and, in the secret case, leaking:
   ```bash
   head -1 Dockerfile | grep -q '^# syntax=' \
     || echo "NOTE  no '# syntax=docker/dockerfile:1' directive - build uses the bundled frontend"
   grep -qE 'RUN --mount=type=cache' Dockerfile \
     || echo "NOTE  no cache mount - every build re-downloads the dependency tree"
   grep -nE '^ARG .*(SECRET|TOKEN|PASSWORD|_KEY)' Dockerfile \
     && echo "BLOCK build-arg secret - use RUN --mount=type=secret; ARG values persist in image config"
   ```
7. Build + measure layers + scan history for secrets:
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
  WARN  DL3007  latest tag used in FROM

Base images:
  node:22-alpine AS build                    WARN   floating tag - no minor/patch
  gcr.io/distroless/nodejs22-debian12        WARN   floating tag - no minor/patch
  (support check: both on a currently-supported major per the runtime's release schedule)

Project rules:
  PASS  Multi-stage: 2 stages (build, runtime)
  FAIL  Final-stage user: <none> -> ROOT   (USER node is set in the BUILD stage only, line 9)
  FAIL  HEALTHCHECK missing
  PASS  .dockerignore present (covers node_modules, .env, .git, dist)
  NOTE  No '# syntax=' directive; no RUN --mount=type=cache

Image:
  Size:       247 MB
  Layers:     12
  Secrets:    none detected in `docker history`

Blockers:
  1. Final stage runs as root — the `USER node` on line 9 belongs to the build stage, which is
     discarded. Add `USER node` after the last FROM.
  2. HEALTHCHECK missing — severity depends on the runtime; see below.

Suggested fix:
  HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://localhost:'+process.env.PORT+process.env.HEALTH_PATH,r=>process.exit(r.statusCode===200?0:1))"
```

## False positives / gotchas

- **`HEALTHCHECK`'s severity depends on where the image runs, and the common claim about Kubernetes
  is wrong.** Docker Engine, Compose (`depends_on: condition: service_healthy`) and Swarm read the
  image's `HEALTHCHECK`; without it the container is `running` with no notion of healthy, and
  nothing can gate on it. **Kubernetes does not read it at all** — kubelet's probes come from
  `livenessProbe`/`readinessProbe` in the pod spec, and a missing HEALTHCHECK has no effect there.
  So: blocker for compose/Swarm/ECS-without-an-overriding-task-definition; a nit for a k8s-only
  image, where the equivalent gap is a missing probe in the manifest — that is `@k8s-reviewer`'s and
  `/deploy-stage` S2's territory, not this skill's. Report which runtime you judged against.
- `apt-get install -y package` without version pin is hadolint DL3008 — but pinning every system package is high churn; document the trade-off.
- `USER 1001` is non-root but unreadable — prefer a named user created with `adduser`/`useradd`.
- Multi-stage with `FROM scratch` final stage CAN'T have HEALTHCHECK shell commands — use exec form with a static binary. Same for distroless: there is no shell, so the healthcheck must be the runtime's own binary.
- A **floating tag is a WARN, not a pass.** `node:22-alpine` is reproducible today and a different image next week. It is the right default for a team that patches; it is a finding for anything claiming reproducible builds.
- `docker history` shows secrets only if they were `RUN echo $SECRET` style; **build-arg secrets aren't exposed there but ARE in the image config** — `docker inspect` is the deeper check, and `RUN --mount=type=secret` is the fix (the value never enters a layer).
- `:latest` tag = block. Untagged `FROM` = block. Final-stage `USER root` = block. Secrets baked in = critical (rotate the leaked credential).
