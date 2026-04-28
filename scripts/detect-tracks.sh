#!/usr/bin/env bash
# detect-tracks.sh — signal-driven pack scoping for /setup-project.
#
# Reads <target>/package.json, manifest files, top-level dirs, sibling
# V1/V2 layout, and emits ONLY the packs that apply to this project.
#
# Replaces the "scan all 17 packs when no tracks declared" fallback that
# pollutes frontend projects with backend/database/devops/mobile content.
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

trace() { [[ $QUIET -eq 0 ]] && echo "  • $*" >&2; }
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
if [[ -f "$PKG" ]]; then
  # All declared deps + devDeps as a single space-joined string for grep
  PKG_DEPS=$(awk '
    /"(dependencies|devDependencies|peerDependencies)"[[:space:]]*:/ { in_block=1; next }
    in_block && /^[[:space:]]*}/ { in_block=0; next }
    in_block && /"[^"]+"[[:space:]]*:/ {
      gsub(/^[[:space:]]*"/, "")
      sub(/"[[:space:]]*:.*$/, "")
      print
    }
  ' "$PKG" 2>/dev/null | tr '\n' ' ')
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
if [[ -f "$TARGET/manage.py" ]] || [[ -f "$TARGET/requirements.txt" ]] && grep -qE '^(django|fastapi|flask|tornado|starlette)' "$TARGET/requirements.txt" 2>/dev/null; then
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
if has_dep '@lhci/cli' || has_dep lighthouse \
   || [[ -f "$TARGET/.lighthouserc.json" || -f "$TARGET/.lighthouserc.js" ]] \
   || [[ -d "$TARGET/benchmark" || -d "$TARGET/benchmarks" ]] \
   || has_dep clinic || has_dep autocannon; then
  trace "perf tooling → performance"
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
if has_dep kafkajs || has_dep amqplib || has_dep nats || has_dep ioredis \
   || has_dep '@temporalio/client' || has_dep bullmq || has_dep 'aws-sdk' \
   || [[ -d "$TARGET/services" && -d "$TARGET/events" ]]; then
  trace "messaging / event-driven → distributed-systems"
  add distributed-systems
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
    # Replace existing managed block (use perl for portability — sed -i differs on macOS/GNU).
    perl -i -pe '
      BEGIN { local $/; }
      s|<!-- detect-tracks:start -->.*?<!-- detect-tracks:end -->|'"$(printf '%s' "$managed_block" | perl -pe 's/[\\\@\$]/\\$&/g; s/\n/\\n/g')"'|s
    ' "$PROFILE" 2>/dev/null || {
      # Perl substitution can be touchy with shell quoting; fall back to awk in-place.
      tmp=$(mktemp)
      awk -v start="$block_start" -v end="$block_end" -v body="$managed_block" '
        $0 ~ start { print body; in_block=1; next }
        in_block && $0 ~ end { in_block=0; next }
        !in_block { print }
      ' "$PROFILE" > "$tmp" && mv "$tmp" "$PROFILE"
    }
    [[ $QUIET -eq 0 ]] && echo "  ✓ updated managed tracks block in $PROFILE" >&2
  else
    printf '\n%s\n' "$managed_block" >> "$PROFILE"
    [[ $QUIET -eq 0 ]] && echo "  ✓ appended managed tracks block to $PROFILE" >&2
  fi
fi

exit 0
