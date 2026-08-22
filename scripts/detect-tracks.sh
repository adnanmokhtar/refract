#!/usr/bin/env bash
# detect-tracks.sh — signal-driven pack scoping for /setup-project.
#
# Reads <target>/package.json, manifest files, top-level dirs, sibling
# V1/V2 layout, and emits ONLY the packs that apply to this project.
#
# Replaces the "scan all 17 packs when no tracks declared" fallback that
# pollutes frontend projects with backend/database/devops/mobile content.
#
# TWO sources, unioned:
#   1. DEPENDENCY + LAYOUT SIGNALS — matched by package FAMILY, never by one
#      exact name. Package names move (`bull` -> `bullmq`, `ioredis` -> `keyv`,
#      `aws-sdk` -> `@aws-sdk/client-*`) and an exact-name test silently stops
#      firing the day they do.
#   2. ALREADY-INSTALLED PACK ARTIFACTS — a pack whose own files are on disk is
#      in scope whether or not its dependency signal still matches. Without this
#      an installed pack goes unrecorded and its files rot unreconciled. See the
#      "Already-installed packs (seed from disk)" block near the end.
#
# Usage:
#   detect-tracks.sh <target-repo> [--write] [--quiet]
#
# Flags:
#   --write   — write detected tracks into <target>/.claude/codebase-profile.md
#               under a managed `## Tracks (auto-detected)` block. Idempotent.
#   --quiet   — suppress signal trace; only emit final track list.
#
# Output:
#   stdout — one track per line (alphabetical)
#   stderr — signal trace ("found vue → frontend", etc.) unless --quiet
#
# Exit codes:
#   0 — clean
#   1 — target missing
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--write] [--quiet]" >&2
  exit 2
fi

TARGET="$1"; shift
WRITE=0
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --write) WRITE=1; shift ;;
    --quiet) QUIET=1; shift ;;
    *)       echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# NOTE: returns 0 even when quiet — a bare `[[…]] && echo` would yield exit 1
# under `set -e` when QUIET=1 and abort the whole run on the first trace call.
trace() { [[ $QUIET -eq 0 ]] && echo "  • $*" >&2; return 0; }
add()   { TRACKS+=("$1"); }

declare -a TRACKS

# ---------- Universal tracks (always applicable) ----------
trace "universal: code-quality, business, learning, documentation, testing"
add code-quality
add business
add learning
add documentation
add testing

# ---------- Read package.json once if it exists ----------
PKG="$TARGET/package.json"
PKG_DEPS=""
# All declared deps + devDeps + peerDeps as a single space-joined string for grep.
# jq-first: the awk parser below silently returns ZERO keys on minified/compact
# JSON (no per-line braces to anchor on). Fall back to awk only when jq is
# missing OR jq yields nothing (e.g. malformed JSON jq couldn't parse).
parse_pkg_deps() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '[(.dependencies//{}|keys[]),(.devDependencies//{}|keys[]),(.peerDependencies//{}|keys[])] | .[]' "$1" 2>/dev/null
  fi
}
parse_pkg_deps_awk() {
  awk '
    /"(dependencies|devDependencies|peerDependencies)"[[:space:]]*:/ { in_block=1; next }
    in_block && /^[[:space:]]*}/ { in_block=0; next }
    in_block && /"[^"]+"[[:space:]]*:/ {
      gsub(/^[[:space:]]*"/, "")
      sub(/"[[:space:]]*:.*$/, "")
      print
    }
  ' "$1" 2>/dev/null
}
if [[ -f "$PKG" ]]; then
  PKG_DEPS=$(parse_pkg_deps "$PKG" | tr '\n' ' ')
  if [[ -z "${PKG_DEPS// /}" ]]; then
    PKG_DEPS=$(parse_pkg_deps_awk "$PKG" | tr '\n' ' ')
  fi
fi

has_dep() {
  [[ " $PKG_DEPS " == *" $1 "* ]]
}

has_dep_prefix() {
  [[ " $PKG_DEPS " == *" $1"* ]]
}

# ---------- Frontend ----------
FRONTEND=0
if has_dep vue || has_dep_prefix '@vue/' || has_dep react || has_dep_prefix '@types/react' \
   || has_dep '@angular/core' || has_dep svelte || has_dep solid-js || has_dep qwik \
   || has_dep next || has_dep nuxt || has_dep remix || has_dep preact \
   || has_dep '@nuxtjs/' || [[ -f "$TARGET/vite.config.ts" || -f "$TARGET/vite.config.js" ]] \
   || [[ -f "$TARGET/next.config.js" || -f "$TARGET/next.config.mjs" ]] \
   || [[ -f "$TARGET/svelte.config.js" || -f "$TARGET/angular.json" ]] \
   || [[ -d "$TARGET/src/components" || -d "$TARGET/src/pages" || -d "$TARGET/src/views" ]]; then
  FRONTEND=1
  trace "frontend signals → frontend"
  add frontend
fi

# ---------- UI/UX (only if frontend) ----------
if [[ $FRONTEND -eq 1 ]]; then
  if has_dep tailwindcss || has_dep '@emotion/react' || has_dep styled-components \
     || has_dep '@radix-ui/react-slot' || has_dep '@headlessui/react' \
     || has_dep '@mui/material' || has_dep '@chakra-ui/react' || has_dep mantine \
     || has_dep_prefix '@mantine/' || has_dep bootstrap || has_dep bulma \
     || has_dep primevue || has_dep_prefix 'primevue' \
     || has_dep '@storybook/vue3' || has_dep '@storybook/react' \
     || [[ -d "$TARGET/.storybook" ]]; then
    trace "ui library / design system → ui-ux"
    add ui-ux
  else
    trace "frontend without explicit UI library — adding ui-ux anyway (every UI project benefits)"
    add ui-ux
  fi
fi

# ---------- Backend ----------
BACKEND=0
if has_dep express || has_dep fastify || has_dep koa || has_dep '@nestjs/core' \
   || has_dep hapi || has_dep restify || has_dep '@hapi/hapi'; then
  BACKEND=1
  trace "node backend framework → backend"
  add backend
fi
# Python backend
# Precedence: `A || B && C` binds as `A || (B && C)` — the old form let the
# grep gate the requirements.txt branch only. Group the requirement-file checks
# explicitly. grep is case-insensitive (-i) and NOT line-anchored, so pinned/
# extras specs like "Django==4.2" or "fastapi[all]" still match. Cover
# requirements.txt, pyproject.toml, and Pipfile as dependency sources.
PY_BACKEND_RE='(django|fastapi|flask|tornado|starlette)'
if [[ -f "$TARGET/manage.py" ]] \
   || { [[ -f "$TARGET/requirements.txt" ]] && grep -qiE "$PY_BACKEND_RE" "$TARGET/requirements.txt" 2>/dev/null; } \
   || { [[ -f "$TARGET/pyproject.toml" ]] && grep -qiE "$PY_BACKEND_RE" "$TARGET/pyproject.toml" 2>/dev/null; } \
   || { [[ -f "$TARGET/Pipfile" ]] && grep -qiE "$PY_BACKEND_RE" "$TARGET/Pipfile" 2>/dev/null; }; then
  BACKEND=1
  trace "python backend → backend"
  add backend
fi
# Go backend
if [[ -f "$TARGET/go.mod" ]] && grep -qE '(gin|echo|fiber|chi|net/http)' "$TARGET/go.mod" 2>/dev/null; then
  BACKEND=1
  trace "go backend → backend"
  add backend
fi
# Ruby backend
if [[ -f "$TARGET/Gemfile" ]] && grep -qE "rails|sinatra|grape" "$TARGET/Gemfile" 2>/dev/null; then
  BACKEND=1
  trace "ruby backend → backend"
  add backend
fi
# PHP backend
if [[ -f "$TARGET/composer.json" ]] && grep -qE '"laravel/|"symfony/|"slim/' "$TARGET/composer.json" 2>/dev/null; then
  BACKEND=1
  trace "php backend → backend"
  add backend
fi

# ---------- Database ----------
if [[ -d "$TARGET/migrations" || -d "$TARGET/db/migrate" || -d "$TARGET/prisma" \
      || -d "$TARGET/alembic" ]] \
   || [[ -f "$TARGET/knexfile.js" || -f "$TARGET/knexfile.ts" \
         || -f "$TARGET/prisma/schema.prisma" || -f "$TARGET/alembic.ini" \
         || -f "$TARGET/schema.sql" ]] \
   || has_dep prisma || has_dep '@prisma/client' || has_dep sequelize || has_dep typeorm \
   || has_dep drizzle-orm || has_dep mikro-orm || has_dep mongoose || has_dep knex; then
  trace "DB tooling → database"
  add database
fi

# ---------- DevOps ----------
DEVOPS=0
if [[ -f "$TARGET/Dockerfile" || -f "$TARGET/docker-compose.yml" || -f "$TARGET/docker-compose.yaml" \
      || -f "$TARGET/Makefile" ]] \
   || [[ -d "$TARGET/.github/workflows" ]] \
   || [[ -f "$TARGET/.gitlab-ci.yml" || -f "$TARGET/.circleci/config.yml" ]]; then
  DEVOPS=1
  trace "CI / container → devops"
  add devops
fi

# ---------- Infrastructure ----------
if compgen -G "$TARGET/*.tf" >/dev/null 2>&1 \
   || [[ -d "$TARGET/terraform" || -d "$TARGET/pulumi" || -d "$TARGET/infra" \
         || -d "$TARGET/k8s" || -d "$TARGET/kubernetes" \
         || -f "$TARGET/cdk.json" || -f "$TARGET/Pulumi.yaml" \
         || -f "$TARGET/kustomization.yaml" || -f "$TARGET/skaffold.yaml" ]]; then
  trace "IaC manifest → infrastructure"
  add infrastructure
fi

# ---------- Mobile ----------
if [[ -d "$TARGET/ios" && -d "$TARGET/android" ]] \
   || [[ -f "$TARGET/pubspec.yaml" ]] \
   || [[ -f "$TARGET/app.json" && -f "$TARGET/expo-env.d.ts" ]] \
   || has_dep react-native || has_dep '@capacitor/core' || has_dep '@ionic/core' \
   || has_dep expo; then
  trace "mobile signals → mobile"
  add mobile
fi

# ---------- Observability ----------
if has_dep_prefix '@sentry/' || has_dep_prefix '@opentelemetry/' \
   || has_dep datadog-metrics || has_dep dd-trace \
   || has_dep pino || has_dep winston || has_dep bunyan \
   || has_dep prom-client; then
  trace "telemetry / logging libs → observability"
  add observability
fi

# ---------- Performance ----------
# TWO signal classes, not one. The shipped test looked only for FRONTEND perf
# tooling (Lighthouse / LHCI) plus a bare `benchmark/` dir, so a server whose
# whole architecture is a latency decision — a Redis cache in front of the DB, a
# throttler on the edge, a queue moving work off the request path — scored zero
# and the pack stayed undetected while its rules sat installed on disk.
PERF=0
# 1. Explicit perf / benchmark / load-test tooling, any tier.
if has_dep '@lhci/cli' || has_dep lighthouse || has_dep lighthouse-ci \
   || has_dep clinic || has_dep_prefix '@clinic/' || has_dep 0x \
   || has_dep autocannon || has_dep k6 || has_dep_prefix '@k6io/' \
   || has_dep artillery || has_dep_prefix 'artillery-' || has_dep loadtest \
   || has_dep benchmark || has_dep tinybench || has_dep mitata \
   || has_dep why-is-node-running \
   || [[ -f "$TARGET/.lighthouserc.json" || -f "$TARGET/.lighthouserc.js" \
         || -f "$TARGET/.lighthouserc.yml" || -f "$TARGET/lighthouserc.js" ]] \
   || [[ -d "$TARGET/benchmark" || -d "$TARGET/benchmarks" \
         || -d "$TARGET/load-tests" || -d "$TARGET/loadtest" ]]; then
  PERF=1
  trace "perf / benchmark / load-test tooling → performance"
fi
# 2. Server-side latency machinery. A cache, a rate limiter or a throttler is
# installed BECAUSE throughput and tail latency are being managed. Matched by
# FAMILY, not exact name: `keyv` / `@keyv/redis` / `cache-manager` /
# `@nestjs/cache-manager` are the indirections that keep `ioredis` — the only
# cache name the old test knew — out of package.json entirely.
if has_dep ioredis || has_dep redis || has_dep_prefix '@redis/' \
   || has_dep keyv || has_dep_prefix '@keyv/' \
   || has_dep cache-manager || has_dep_prefix 'cache-manager-' \
   || has_dep_prefix '@nestjs/cache-manager' \
   || has_dep memcached || has_dep memjs \
   || has_dep_prefix '@nestjs/throttler' || has_dep express-rate-limit \
   || has_dep rate-limiter-flexible || has_dep_prefix '@fastify/rate-limit' \
   || has_dep koa-ratelimit || has_dep_prefix '@upstash/ratelimit'; then
  PERF=1
  trace "cache / rate-limit / throttle layer → performance"
fi
# 3. Non-node perf tooling — same widening, other manifests.
if { [[ -f "$TARGET/requirements.txt" ]] && grep -qiE '(locust|pytest-benchmark|py-spy|scalene|memray)' "$TARGET/requirements.txt" 2>/dev/null; } \
   || { [[ -f "$TARGET/pyproject.toml" ]] && grep -qiE '(locust|pytest-benchmark|py-spy|scalene|memray)' "$TARGET/pyproject.toml" 2>/dev/null; } \
   || { [[ -f "$TARGET/go.mod" ]] && grep -qiE '(pprof|vegeta|k6)' "$TARGET/go.mod" 2>/dev/null; }; then
  PERF=1
  trace "python / go perf tooling → performance"
fi
if [[ $PERF -eq 1 ]]; then
  add performance
elif [[ $FRONTEND -eq 1 ]]; then
  # Every shipped UI benefits from a perf budget (Core Web Vitals / bundle size),
  # exactly like ui-ux above — don't gate the pack behind Lighthouse already being
  # wired (chicken-and-egg: you need the pack to know you should add Lighthouse).
  trace "frontend without explicit perf tooling — adding performance anyway (every UI ships with a perf budget)"
  add performance
fi

# ---------- Security ----------
SEC=0
if has_dep_prefix '@auth/' || has_dep next-auth || has_dep passport \
   || has_dep '@passport/local' || has_dep jsonwebtoken || has_dep jose \
   || has_dep helmet || has_dep '@nestjs/jwt' || has_dep argon2 || has_dep bcrypt; then
  SEC=1
  trace "auth / crypto libs → security"
  add security
fi

# ---------- Distributed systems ----------
# Matched by PACKAGE FAMILY, not by exact name. The shipped test named exactly
# three things — `bullmq`, `ioredis`, `aws-sdk` — and a live NestJS API missed
# all three by one rename each: it ships `bull@4` (the v3/v4 line bullmq
# succeeded), `keyv` + `@keyv/redis` (the indirection over ioredis) and
# `@aws-sdk/client-s3` (the v3 split of the `aws-sdk` v2 monolith). Result:
# distributed-systems undetected on a repo that already had the pack installed.
# Each group below is the current name PLUS its predecessors and the
# platform-equivalent clients that carry the same concern.
DIST=0
# Brokers + streaming.
if has_dep kafkajs || has_dep_prefix '@confluentinc/kafka' || has_dep node-rdkafka \
   || has_dep amqplib || has_dep amqp-connection-manager || has_dep rhea \
   || has_dep_prefix '@golevelup/nestjs-rabbitmq' \
   || has_dep nats || has_dep_prefix '@nats-io/' \
   || has_dep mqtt || has_dep_prefix 'pulsar-client' || has_dep zeromq; then
  DIST=1
  trace "message broker client → distributed-systems"
fi
# Background job queues — `bull` and `bullmq` are the SAME concern, and a Nest
# repo declares the wrapper (`@nestjs/bull` / `@nestjs/bullmq`), not the core.
if has_dep bull || has_dep bullmq || has_dep bee-queue || has_dep kue \
   || has_dep agenda || has_dep agenda-rest || has_dep bree || has_dep graphile-worker \
   || has_dep_prefix '@nestjs/bull' || has_dep_prefix '@taskforcesh/'; then
  DIST=1
  trace "background job queue → distributed-systems"
fi
# Shared cache / coordination store. `ioredis` was already an accepted signal;
# these are the same signal wearing its current names.
if has_dep ioredis || has_dep redis || has_dep_prefix '@redis/' \
   || has_dep keyv || has_dep_prefix '@keyv/' \
   || has_dep cache-manager || has_dep_prefix 'cache-manager-' \
   || has_dep_prefix '@nestjs/cache-manager' \
   || has_dep memcached || has_dep memjs || has_dep etcd3 || has_dep node-zookeeper-client; then
  DIST=1
  trace "shared cache / coordination store → distributed-systems"
fi
# Workflow engines + microservice transports — explicit cross-process boundaries.
if has_dep_prefix '@temporalio/' || has_dep_prefix '@camunda' || has_dep conductor-client \
   || has_dep_prefix '@nestjs/microservices' || has_dep_prefix '@grpc/' \
   || has_dep grpc || has_dep moleculer || has_dep seneca || has_dep_prefix 'dapr-client'; then
  DIST=1
  trace "workflow engine / microservice transport → distributed-systems"
fi
# Managed-cloud SDKs. `aws-sdk` (v2) was already accepted and bundled every
# service in one package, so the v3 `@aws-sdk/client-*` split is matched at the
# same breadth — plus the GCP / Azure equivalents that were never covered.
if has_dep 'aws-sdk' || has_dep_prefix '@aws-sdk/' || has_dep_prefix '@aws-lite/' \
   || has_dep_prefix '@google-cloud/' || has_dep_prefix '@azure/'; then
  DIST=1
  trace "managed-cloud service SDK → distributed-systems"
fi
# Non-node equivalents — same widening, other manifests.
if { [[ -f "$TARGET/requirements.txt" ]] && grep -qiE '(celery|kombu|dramatiq|arq|rq-scheduler|pika|aiokafka|confluent-kafka|temporalio|nats-py)' "$TARGET/requirements.txt" 2>/dev/null; } \
   || { [[ -f "$TARGET/pyproject.toml" ]] && grep -qiE '(celery|kombu|dramatiq|arq|rq-scheduler|pika|aiokafka|confluent-kafka|temporalio|nats-py)' "$TARGET/pyproject.toml" 2>/dev/null; } \
   || { [[ -f "$TARGET/go.mod" ]] && grep -qiE '(segmentio/kafka-go|confluentinc/confluent-kafka-go|nats-io|streadway/amqp|rabbitmq/amqp091|go-redis|temporal)' "$TARGET/go.mod" 2>/dev/null; } \
   || { [[ -f "$TARGET/Gemfile" ]] && grep -qiE '(sidekiq|resque|shoryuken|karafka|bunny)' "$TARGET/Gemfile" 2>/dev/null; }; then
  DIST=1
  trace "python / go / ruby messaging or queue library → distributed-systems"
fi
if [[ -d "$TARGET/services" && -d "$TARGET/events" ]]; then
  DIST=1
  trace "services/ + events/ layout → distributed-systems"
fi
if [[ $DIST -eq 1 ]]; then
  add distributed-systems
fi

# ---------- Data engineering ----------
# Warehouse / analytics-engineering discipline: dimensional modelling, transformation
# layering, data contracts, quality assertions, backfill safety. Distinct from `database`
# (OLTP schema/queries) and from the `data-pipeline` technical signal (movement correctness).
if [[ -f "$TARGET/dbt_project.yml" ]] \
   || [[ -d "$TARGET/dags" || -d "$TARGET/models/staging" || -d "$TARGET/warehouse" ]] \
   || [[ -f "$TARGET/sqlmesh.yaml" || -f "$TARGET/meltano.yml" ]] \
   || has_dep '@dbt-labs/dbt-core' || has_dep '@dagster-io/dagit' \
   || { [[ -f "$TARGET/requirements.txt" ]] && grep -qiE '(dbt-core|apache-airflow|dagster|prefect|pyspark|apache-beam|sqlmesh|meltano)' "$TARGET/requirements.txt" 2>/dev/null; } \
   || { [[ -f "$TARGET/pyproject.toml" ]] && grep -qiE '(dbt-core|apache-airflow|dagster|prefect|pyspark|apache-beam|sqlmesh|meltano)' "$TARGET/pyproject.toml" 2>/dev/null; }; then
  trace "warehouse / transformation / orchestration tooling → data-engineering"
  add data-engineering
fi

# ---------- FinOps ----------
# Cost as a reviewed engineering dimension. Gated on infrastructure-as-code, because
# without provisioned resources there is no meaningful spend to attribute, and without
# IaC there is nowhere for tag enforcement or a pre-merge cost estimate to attach.
if compgen -G "$TARGET/*.tf" >/dev/null 2>&1 \
   || [[ -d "$TARGET/terraform" || -d "$TARGET/pulumi" || -d "$TARGET/infra" ]] \
   || [[ -f "$TARGET/cdk.json" || -f "$TARGET/Pulumi.yaml" ]] \
   || [[ -f "$TARGET/infracost.yml" || -f "$TARGET/.infracost.yml" ]]; then
  trace "infrastructure-as-code → finops (spend is provisioned here)"
  add finops
fi

# ---------- Product ----------
# Problem framing, requirement quality, research synthesis, launch judgement. Signalled by
# product artifacts the team maintains OUTSIDE the framework, plus this pack's own output
# directory — not by stack, which says nothing about whether requirements are written down
# or written well.
#
# Deliberately NOT signals — `ai/project-goals.md`, `ai/users-and-personas.md` and
# `ai/roadmap.md` are written by /setup-project Phase 4.7b, and `ai/roadmap/plan.md` by
# /roadmap. Keying on them would fire `product` on every repo that has run either command
# once, which is always-on for the installed base wearing a detector's clothes. Content-
# gating does not rescue them either: 4.7b populates those files from extraction, so a
# non-stub copy is ordinary framework output, not evidence of a product practice.
if [[ -d "$TARGET/ai/product" || -d "$TARGET/docs/prd" || -d "$TARGET/docs/product" ]] \
   || [[ -f "$TARGET/PRD.md" || -f "$TARGET/ROADMAP.md" ]]; then
  trace "product artifacts (briefs / PRDs / research) → product"
  add product
fi

# ---------- Migration ----------
parent_dir=$(dirname "$TARGET")
target_name=$(basename "$TARGET")
v1_candidate=""
case "$target_name" in
  *-v2|*-V2|*-new|*-rewrite|*-next)
    v1_candidate="${target_name%-*}"
    ;;
esac
if [[ -n "$v1_candidate" && -d "$parent_dir/$v1_candidate" ]]; then
  trace "sibling V1 layout: $parent_dir/$v1_candidate exists → migration"
  add migration
elif [[ -d "$TARGET/ai/migration" ]] || [[ -d "$TARGET/v1" && -d "$TARGET/v2" ]] \
     || [[ -d "$TARGET/legacy" && -d "$TARGET/new" ]]; then
  trace "in-repo migration layout → migration"
  add migration
fi

# ---------- Already-installed packs (seed from disk) ----------
# A pack whose OWN artifacts are already installed is in scope by definition.
# Nothing in the framework writes `.claude/_pack-manifest.md`, so the only record
# that a pack was ever installed is the files themselves. That makes a purely
# signal-driven detector lossy in one direction: the moment a dependency is
# renamed out from under a signal (see the de-aliasing in the two blocks above),
# the pack silently drops out of scope and its installed files rot — never
# scanned by pack-coverage-scan.sh, never reconciled by study-existing.sh, never
# refreshed. Observed on a real repo: `.claude/rules/distributed-principles.md`
# and `.claude/rules/performance-principles.md` present on disk while every
# subsequent detection returned neither track.
#
# Seeding is deliberately conservative — it recovers packs, it does not invent them:
#   * only a file whose target-relative path belongs to EXACTLY ONE pack counts as
#     a signature (`.claude/rules/code-quality.md` ships in several packs and so
#     proves nothing about which one is installed);
#   * a pack needs >= 2 distinct signature hits, so one stray hand-copied file
#     cannot drag a whole pack into scope.
# Degrades to a no-op when the templates tree is not resolvable (script invoked
# from a copy without its sibling `templates/`).
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACKS_DIR="$SELF_DIR/../templates/packs"

if [[ -d "$PACKS_DIR" ]] && [[ -d "$TARGET/.claude" || -d "$TARGET/ai/patterns" ]]; then
  # path<TAB>pack for every pack-owned artifact, in TARGET-relative form.
  pack_sig_map=$(
    { find "$PACKS_DIR" -type f -name '*.md' -not -path '*/_examples/*' 2>/dev/null || true; } \
    | awk '
        {
          n = split($0, a, "/")
          base = a[n]
        }
        base ~ /^_/ { next }
        base == "README.md" || base == "CHANGELOG.md" || base == "STACK.md" { next }
        {
          idx = 0
          # last "packs" component wins — the repo itself may live under a dir of
          # that name (…/Projects/packs/claude-config/templates/packs/…).
          for (i = 1; i <= n; i++) if (a[i] == "packs") idx = i
          if (idx == 0 || idx + 2 > n) next
          pk = a[idx+1]; kind = a[idx+2]
          if (kind == "rules" || kind == "agents" || kind == "commands") {
            if (n != idx + 3) next
            printf ".claude/%s/%s\t%s\n", kind, base, pk
          } else if (kind == "skills" && base == "SKILL.md" && n == idx + 4) {
            printf ".claude/skills/%s/SKILL.md\t%s\n", a[idx+3], pk
            printf ".claude/skills/%s.md\t%s\n", a[idx+3], pk
          } else if (kind == "ai-patterns") {
            if (n != idx + 3) next
            printf "ai/patterns/%s\t%s\n", base, pk
          }
        }' \
    | sort -u \
    | awk -F'\t' '{ c[$1]++; own[$1] = $2 } END { for (k in c) if (c[k] == 1) printf "%s\t%s\n", k, own[k] }' \
    || true
  )

  seeded_packs=""
  if [[ -n "$pack_sig_map" ]]; then
    seeded_packs=$(
      printf '%s\n' "$pack_sig_map" \
      | while IFS=$'\t' read -r rel pk; do
          [[ -n "$rel" && -n "$pk" && -e "$TARGET/$rel" ]] && printf '%s\n' "$pk"
        done \
      | sort | uniq -c | awk '$1 >= 2 { print $2 }' || true
    )
  fi

  if [[ -n "$seeded_packs" ]]; then
    while IFS= read -r pk; do
      [[ -z "$pk" ]] && continue
      already=0
      for t in "${TRACKS[@]}"; do
        [[ "$t" == "$pk" ]] && { already=1; break; }
      done
      if [[ $already -eq 0 ]]; then
        trace "pack artifacts already installed in target → $pk (seeded from disk, not from a dependency signal)"
        add "$pk"
      fi
    done <<< "$seeded_packs"
  fi
fi

# ---------- De-duplicate + sort ----------
unique_sorted=$(printf '%s\n' "${TRACKS[@]}" | sort -u)

if [[ $QUIET -eq 0 ]]; then
  echo "" >&2
  echo "Detected $(echo "$unique_sorted" | wc -l | tr -d ' ') track(s):" >&2
fi
echo "$unique_sorted"

# ---------- Optionally write into codebase-profile.md ----------
if [[ $WRITE -eq 1 ]]; then
  PROFILE="$TARGET/.claude/codebase-profile.md"
  if [[ ! -f "$PROFILE" ]]; then
    [[ $QUIET -eq 0 ]] && echo "  ! codebase-profile.md not found at $PROFILE — skipping --write" >&2
    exit 0
  fi

  # Managed block. Replace if already present; append otherwise.
  block_start='<!-- detect-tracks:start -->'
  block_end='<!-- detect-tracks:end -->'
  block_body=$(printf '%s\n' "$unique_sorted" | sed 's/^/- track: /')
  managed_block=$(cat <<MGD
$block_start
## Tracks (auto-detected by scripts/detect-tracks.sh)

$block_body
$block_end
MGD
)

  if grep -qF "$block_start" "$PROFILE" 2>/dev/null; then
    # Replace existing managed block. No perl: `perl -i -pe 'BEGIN{local $/}'`
    # does NOT slurp (the -p loop still reads line-by-line, so a multi-line
    # block never refreshes on macOS). Pass the replacement body to awk via a
    # FILE + getline — NOT `-v body=…`, which errors ("newline in string") on
    # BSD awk when the value contains embedded newlines.
    before_md5=$(md5 -q "$PROFILE" 2>/dev/null || md5sum "$PROFILE" 2>/dev/null | awk '{print $1}')
    body_file=$(mktemp)
    printf '%s\n' "$managed_block" > "$body_file"
    tmp=$(mktemp)
    awk -v start="$block_start" -v end="$block_end" -v bodyfile="$body_file" '
      $0 ~ start {
        while ((getline line < bodyfile) > 0) print line
        close(bodyfile)
        in_block=1; next
      }
      in_block && $0 ~ end { in_block=0; next }
      !in_block { print }
    ' "$PROFILE" > "$tmp" && mv "$tmp" "$PROFILE"
    rm -f "$body_file"
    # Post-write assertion: the managed block must actually have changed (or at
    # least be present). A no-op write means the replacement silently failed.
    after_md5=$(md5 -q "$PROFILE" 2>/dev/null || md5sum "$PROFILE" 2>/dev/null | awk '{print $1}')
    if ! grep -qF "$block_start" "$PROFILE" 2>/dev/null; then
      echo "  ✗ ERR: managed tracks block lost after write to $PROFILE" >&2
      exit 1
    fi
    if [[ "$before_md5" == "$after_md5" ]]; then
      [[ $QUIET -eq 0 ]] && echo "  = managed tracks block already up to date in $PROFILE" >&2
    else
      [[ $QUIET -eq 0 ]] && echo "  ✓ updated managed tracks block in $PROFILE" >&2
    fi
  else
    printf '\n%s\n' "$managed_block" >> "$PROFILE"
    [[ $QUIET -eq 0 ]] && echo "  ✓ appended managed tracks block to $PROFILE" >&2
  fi
fi

exit 0
