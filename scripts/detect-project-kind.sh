#!/usr/bin/env bash
# detect-project-kind.sh — which PROJECT KINDS does this target actually have?
#
# Prints a space-separated set drawn from: browser server mobile cli
# Prints `any` when nothing resolves — an undetectable repo must not be silently stripped of
# half its artifacts. See templates/packs/_project-kind.md for the contract and the measured
# defect that motivated it (49,450 bytes of browser-only content installed on a headless API).
#
# Usage: detect-project-kind.sh <target-repo>
set -uo pipefail
export LC_ALL=C

TARGET="${1:-.}"
[ -d "$TARGET" ] || { echo "any"; exit 0; }
TARGET="$(cd "$TARGET" && pwd -P)"
PKG="$TARGET/package.json"
KINDS=""

has_dep() { [ -f "$PKG" ] && grep -qE "\"($1)\"[[:space:]]*:" "$PKG" 2>/dev/null; }
src_hit() {
  find "$TARGET" -maxdepth 6 -type f \( -name "$1" \) \
    -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
    -not -path '*/build/*' -not -path '*/.claude/*' 2>/dev/null | head -1 | grep -q .
}

# ---- browser ----
if has_dep 'react|vue|@angular/core|svelte|solid-js|astro|nuxt|next|@remix-run/react' \
   || src_hit '*.vue' || src_hit '*.tsx' || src_hit '*.jsx' || src_hit '*.svelte' \
   || src_hit 'index.html'; then
  KINDS="$KINDS browser"
fi

# ---- server ----
if has_dep '@nestjs/core|express|fastify|koa|@hapi/hapi' \
   || grep -qE '^(fastapi|django|Django|flask|Flask)' "$TARGET/requirements.txt" "$TARGET/pyproject.toml" 2>/dev/null \
   || { [ -f "$TARGET/Gemfile" ] && grep -q "'rails'" "$TARGET/Gemfile" 2>/dev/null; } \
   || { [ -f "$TARGET/composer.json" ] && grep -q 'laravel/framework' "$TARGET/composer.json" 2>/dev/null; } \
   || grep -q 'spring-boot' "$TARGET/pom.xml" "$TARGET/build.gradle" "$TARGET/build.gradle.kts" 2>/dev/null \
   || { [ -f "$TARGET/go.mod" ] && grep -qE 'gin-gonic|labstack/echo|gofiber|chi-router' "$TARGET/go.mod" 2>/dev/null; } \
   || { [ -f "$TARGET/mix.exs" ] && grep -q 'phoenix' "$TARGET/mix.exs" 2>/dev/null; } \
   || { [ -f "$TARGET/Dockerfile" ] && grep -qE '^[[:space:]]*EXPOSE[[:space:]]+[0-9]' "$TARGET/Dockerfile" 2>/dev/null; } \
   || [ -f "$TARGET/manage.py" ] || [ -f "$TARGET/artisan" ]; then
  KINDS="$KINDS server"
fi

# ---- mobile ----
if has_dep 'react-native|expo' || [ -f "$TARGET/pubspec.yaml" ] \
   || src_hit '*.xcodeproj' || [ -f "$TARGET/android/build.gradle" ]; then
  KINDS="$KINDS mobile"
fi

# ---- cli ----
if { [ -f "$PKG" ] && grep -q '"bin"[[:space:]]*:' "$PKG" 2>/dev/null; } \
   || grep -q 'console_scripts\|\[project.scripts\]' "$TARGET/setup.py" "$TARGET/pyproject.toml" 2>/dev/null \
   || { [ -f "$TARGET/go.mod" ] && [ -d "$TARGET/cmd" ]; }; then
  KINDS="$KINDS cli"
fi

KINDS="$(printf '%s' "$KINDS" | sed 's/^[[:space:]]*//')"
[ -z "$KINDS" ] && KINDS="any"
printf '%s\n' "$KINDS"
