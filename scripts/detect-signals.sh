#!/usr/bin/env bash
# detect-signals.sh — compute every `*_detected` trigger the pack vocabulary declares, from the
# repository on disk, and write the answers where a machine can read them.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# `templates/packs/_trigger-vocabulary.md` is the authoritative list of signals a pack's
# `_topics.md` may branch on, and its own hard rule is: "A trigger no extractor produces is dead
# code." MEASURED on 2026-08-23, against the live vocabulary: **29 of its 32 `*_detected`
# triggers had no producer anywhere in the repo** — not in scripts/, not in the extraction
# skill, not in the appendices. Every topic gated on one of them could never fire, on any
# project. And the ratchet that was supposed to catch that (`lint-setup-contracts.sh` Rule 4)
# had all 29 recorded in its baseline, so no gate ever turned red over it.
#
# The two that HAD been fixed (`i18n_lib_detected`, `rtl_locale_detected`) were fixed in
# `templates/appendices.md` — a Tier-3 COLD documentation file that NO SCRIPT EXECUTES. They
# produced correct answers when a human pasted the snippet into a shell and nothing else. A
# producer that only runs when an agent chooses to read a cold appendix is not a producer; it
# is a suggestion. So the extractors live HERE, in a script the preflight runs.
#
# CONTRACT
#   * Read-only against the target's source. Writes exactly one file, `<target>/.claude/_detected-signals.md`
#     (or stdout under --stdout), never anything else.
#   * Every signal is emitted, including the negative ones. "not detected" is an answer; a
#     missing line is a bug, and a consumer cannot tell those apart unless both are written.
#   * The machine block is `name=yes` / `name=no`, one per line, inside a fenced block — the
#     same shape `detect-tracks.sh` output is consumed in.
#   * No `grep -P` (lint-setup-contracts.sh Rule 3), and every `find` over a possibly-symlinked
#     path passes -L (Rule 1).
#
# Usage: detect-signals.sh <target-repo> [--stdout] [--quiet]
# Exit:  0 always when the target exists (a signal that is absent is data, not an error)
#        1 target missing / unusable
#        2 usage
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd

[ $# -ge 1 ] || { echo "Usage: $0 <target-repo> [--stdout] [--quiet]" >&2; exit 2; }
TARGET="$1"; shift
SINK_STDOUT=0; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stdout|--no-write) SINK_STDOUT=1 ;;
    --quiet)             QUIET=1 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done
[ -d "$TARGET" ] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd -P)"
VOCAB="$REPO_ROOT/templates/packs/_trigger-vocabulary.md"

cd "$TARGET" || exit 1

# ---- helpers ---------------------------------------------------------------------------
PRUNE='-name node_modules -o -name .git -o -name dist -o -name build -o -name vendor -o -name .venv -o -name __pycache__ -o -name .claude'
# yn <cmd...> → "yes" when the command succeeds, "no" otherwise. Never leaks a non-zero status.
yn() { if "$@" >/dev/null 2>&1; then printf 'yes'; else printf 'no'; fi; }
# manifest grep, extended-regex, across every manifest shape we know
MANIFESTS='package.json pyproject.toml requirements.txt Gemfile composer.json go.mod Cargo.toml pom.xml build.gradle build.gradle.kts mix.exs pubspec.yaml'
# Full-line comments are stripped before matching. A manifest is a DECLARATION file, but
# YAML and TOML carry prose, and prose contains framework names. Measured: a Flutter app was
# detected as Next.js because pubspec.yaml had a comment reading "...costs the next auditor
# the whole..." — `first_of` is word-bounded and matched it, so ssr_capable_framework_detected
# said `next` on a repo with no package.json at all.
# Only whole-line `#` comments are dropped, never mid-line: `#` inside a JSON string (a colour,
# a URL fragment) is data, and cutting at it would trade a false positive for a false negative.
# Existing files are collected FIRST. `grep` on a missing path exits 2, and this script runs
# under `set -o pipefail`, so piping straight from `grep $MANIFESTS` made the whole pipeline
# non-zero whenever ANY manifest was absent — which is almost always. Every manifest-based
# signal silently went to `no`, including the frontend framework on a Nuxt app. Caught by a
# real repo flipping, not by a fixture.
mg() {
  local f; local -a present=()
  for f in $MANIFESTS; do [ -f "$f" ] && present+=("$f"); done
  [ "${#present[@]}" -eq 0 ] && return 1
  grep -hv '^[[:space:]]*#' "${present[@]}" 2>/dev/null | grep -qE "$1"
}
# find with pruning; prints the first hit or nothing
ff() { find -L . -maxdepth "${2:-6}" \( $PRUNE \) -prune -o -name "$1" -print 2>/dev/null | head -1; }
ffp() { find -L . -maxdepth "${2:-6}" \( $PRUNE \) -prune -o -path "$1" -print 2>/dev/null | head -1; }
# source-tree grep across the usual source roots
SRC_ROOTS="src app apps lib libs packages server client web components pages"
sg() {
  local pat="$1" d
  for d in $SRC_ROOTS; do
    [ -d "$d" ] || continue
    grep -rqE --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build \
      -- "$pat" "$d" 2>/dev/null && return 0
  done
  return 1
}
# first captured value from a set of alternatives, or "" — used for the `value:` column
first_of() { local v; for v in "$@"; do mg "\"$v\"|'$v'|(^|[^A-Za-z0-9_-])$v([^A-Za-z0-9_-]|$)" && { printf '%s' "$v"; return; }; done; }

declare -a NAMES=() VALS=() NOTES=()
# THE CALL SHAPE IS `sig name=value "evidence"`, NOT `sig name value`, and that is deliberate.
# scripts/lint-setup-contracts.sh Rule 4 defines a producer as an ASSIGNMENT to the trigger
# name — precisely because a bare mention in prose used to satisfy it and certified 29 dead
# triggers as alive. Writing the assignment literally at every call site is what makes THIS
# file a producer the ratchet can actually see, instead of a 33rd thing that claims to be one.
sig() { local nv="$1"; NAMES+=("${nv%%=*}"); VALS+=("${nv#*=}"); NOTES+=("${2:-}"); }

# ===== Stack / framework =================================================================
BE_FW="$(first_of '@nestjs/core' 'express' 'fastify' 'koa' 'django' 'Django' 'flask' 'Flask' 'fastapi' 'rails' 'laravel' 'spring-boot' 'gin-gonic' 'echo' 'phoenix' 'aspnetcore')"
sig "primary_framework_detected=$( [ -n "$BE_FW" ] && echo yes || echo no )" "$BE_FW"
FE_FW="$(first_of 'nuxt' 'next' '@angular/core' 'svelte' 'solid-js' 'vue' 'react')"
sig "primary_frontend_framework_detected=$( [ -n "$FE_FW" ] && echo yes || echo no )" "$FE_FW"
MOB_FW=""
mg 'react-native|"expo"'      && MOB_FW="react-native"
[ -f pubspec.yaml ]           && MOB_FW="${MOB_FW:-flutter}"
[ -n "$(ff '*.xcodeproj' 3)" ] && MOB_FW="${MOB_FW:-ios-native}"
[ -n "$(ffp '*/android/build.gradle' 4)" ] && MOB_FW="${MOB_FW:-android-native}"
sig "mobile_framework_detected=$( [ -n "$MOB_FW" ] && echo yes || echo no )" "$MOB_FW"

# native_bridge_present — CUSTOM bridge code, not the scaffolding every mobile app ships.
#
# Declared in templates/packs/_trigger-vocabulary.md and consumed by the mobile pack's
# native-bridge topic; nothing produced it, so that topic could never fire on any project.
# It went unnoticed because BOTH guards for exactly this (lint-setup-contracts.sh Rule 4 and
# test-detect-signals.sh § 1) enumerated `^- `<name>_detected`` only, and this name does not
# carry that suffix.
#
# The naive test — "a .swift under ios/" — would report yes for every Flutter and React
# Native project on earth, because ios/Runner/AppDelegate.swift is generated scaffolding.
# A signal that is always yes is not a signal. What distinguishes a real bridge is the
# bridge SURFACE: a platform channel, a React Native module registration, or a package that
# exists to hold native modules. Verified against a real Flutter app that has the
# scaffolding and no channels — it reports `no`, which is the correct answer there.
NB=""
_nb_roots=""
for _d in lib src app ios android; do [ -d "$_d" ] && _nb_roots="$_nb_roots $_d"; done
if [ -n "$_nb_roots" ]; then
  # shellcheck disable=SC2086
  grep -rqE 'MethodChannel\(|EventChannel\(|BasicMessageChannel\(' $_nb_roots \
    --exclude-dir=node_modules --exclude-dir=build --exclude-dir=.dart_tool 2>/dev/null \
    && NB="flutter-platform-channel"
  # shellcheck disable=SC2086
  grep -rqE 'RCTBridgeModule|ReactContextBaseJavaModule|@ReactMethod|TurboModule' $_nb_roots \
    --exclude-dir=node_modules --exclude-dir=build 2>/dev/null \
    && NB="${NB:-react-native-module}"
fi
[ -n "$(ffp '*-native-modules*' 3)" ] && NB="${NB:-native-modules-package}"
sig "native_bridge_present=$( [ -n "$NB" ] && echo yes || echo no )" "$NB"
unset _nb_roots _d

PKG_MGR=""
[ -f bun.lockb ] || [ -f bun.lock ]  && PKG_MGR="bun"
[ -f pnpm-lock.yaml ]                && PKG_MGR="${PKG_MGR:-pnpm}"
[ -f yarn.lock ]                     && PKG_MGR="${PKG_MGR:-yarn}"
[ -f package-lock.json ]             && PKG_MGR="${PKG_MGR:-npm}"
[ -f poetry.lock ]                   && PKG_MGR="${PKG_MGR:-poetry}"
[ -f Pipfile.lock ]                  && PKG_MGR="${PKG_MGR:-pipenv}"
[ -f uv.lock ]                       && PKG_MGR="${PKG_MGR:-uv}"
[ -f requirements.txt ]              && PKG_MGR="${PKG_MGR:-pip}"
[ -f Cargo.lock ]                    && PKG_MGR="${PKG_MGR:-cargo}"
[ -f go.sum ]                        && PKG_MGR="${PKG_MGR:-go}"
[ -f composer.lock ]                 && PKG_MGR="${PKG_MGR:-composer}"
[ -f Gemfile.lock ]                  && PKG_MGR="${PKG_MGR:-bundler}"
[ -f package.json ]                  && PKG_MGR="${PKG_MGR:-npm}"
sig "package_manager_detected=$( [ -n "$PKG_MGR" ] && echo yes || echo no )" "$PKG_MGR"
BUILD_TOOL="$(first_of 'vite' 'webpack' 'esbuild' 'rollup' 'turbo' 'nx' 'parcel' 'rspack' 'tsup')"
sig "build_tool_detected=$( [ -n "$BUILD_TOOL" ] && echo yes || echo no )" "$BUILD_TOOL"

# ===== Data layer ========================================================================
ORM="$(first_of 'typeorm' '@prisma/client' 'prisma' 'sequelize' 'drizzle-orm' 'mongoose' 'SQLAlchemy' 'sqlalchemy' 'peewee' 'django' 'activerecord' 'eloquent' 'gorm' 'diesel' 'hibernate' 'ecto')"
sig "orm_detected=$( [ -n "$ORM" ] && echo yes || echo no )" "$ORM"
MIG_TOOL=""
mg 'typeorm'         && MIG_TOOL="typeorm"
mg 'prisma'          && MIG_TOOL="${MIG_TOOL:-prisma}"
mg 'alembic'         && MIG_TOOL="${MIG_TOOL:-alembic}"
mg 'phinx'           && MIG_TOOL="${MIG_TOOL:-phinx}"
mg 'flyway|liquibase' && MIG_TOOL="${MIG_TOOL:-flyway/liquibase}"
mg 'knex'            && MIG_TOOL="${MIG_TOOL:-knex}"
mg 'rails|activerecord' && MIG_TOOL="${MIG_TOOL:-rails}"
mg 'ecto'            && MIG_TOOL="${MIG_TOOL:-ecto}"
sig "migration_tool_detected=$( [ -n "$MIG_TOOL" ] && echo yes || echo no )" "$MIG_TOOL"
MIG_DIR=""
for d in prisma/migrations database/migrations db/migrate migrations src/migrations alembic/versions; do
  [ -d "$d" ] && { MIG_DIR="$d"; break; }
done
[ -z "$MIG_DIR" ] && MIG_DIR="$(ffp '*/migrations' 5 | sed 's|^\./||')"
sig "migration_dir_detected=$( [ -n "$MIG_DIR" ] && echo yes || echo no )" "$MIG_DIR"
# migration_ledger_present — one exact path, named in the vocabulary. /port-feature and
# /migration-status gate on it, so a fuzzy match here would be worse than none.
sig "migration_ledger_present=$( [ -f ai/migration/ledger.md ] && echo yes || echo no )" "$( [ -f ai/migration/ledger.md ] && echo 'ai/migration/ledger.md' )"

# ===== API surface =======================================================================
API_HITS=$(find -L . -maxdepth 8 \( $PRUNE \) -prune -o -type f \
             \( -name '*controller*' -o -name '*Controller*' -o -name '*router*' -o -name '*Router*' \
                -o -name 'routes.*' -o -name 'urls.py' -o -name 'views.py' \) -print 2>/dev/null | grep -c . || true)
sig "api_surface_detected=$( [ "${API_HITS:-0}" -ge 1 ] && echo yes || echo no )" "${API_HITS:-0} route/controller file(s)"
sig "controller_pattern_detected=$( [ "${API_HITS:-0}" -ge 1 ] && echo yes || echo no )" "${API_HITS:-0} file(s) matching *controller*/*router*/routes.*/urls.py/views.py"
# module_per_feature_layout — feature-sliced (`<feature>/{controller,service,repo}`) rather
# than flat MVC (`controllers/`, `services/`, `repositories/` as siblings at the top). The
# test is CO-LOCATION: one directory holding all three roles. Two such directories are
# required, because a single one is as likely to be a coincidence as a layout. Flat MVC has
# the same file names and never co-locates them, which is exactly what separates the two.
MPF=""
_mpf_hits=0
while IFS= read -r _d; do
  [ -d "$_d" ] || continue
  # find, not `ls | grep`: filenames can carry anything, and the shellcheck ratchet is right
  # to refuse the pipeline. Names only — the role is in the filename, not the path.
  _names="$(find "$_d" -maxdepth 1 -type f -print 2>/dev/null | sed 's|.*/||')"
  _c="$(printf '%s\n' "$_names" | grep -icE 'controller|handler|router' || true)"
  _s="$(printf '%s\n' "$_names" | grep -icE 'service|usecase|use-case' || true)"
  _r="$(printf '%s\n' "$_names" | grep -icE 'repositor|repo\.|dao' || true)"
  if [ "${_c:-0}" -ge 1 ] && [ "${_s:-0}" -ge 1 ] && [ "${_r:-0}" -ge 1 ]; then
    _mpf_hits=$(( _mpf_hits + 1 ))
    [ -z "$MPF" ] && MPF="${_d#./}"
  fi
done <<EOF
$(find -L . -maxdepth 5 \( $PRUNE \) -prune -o -type d -print 2>/dev/null | head -400)
EOF
[ "$_mpf_hits" -ge 2 ] && MPF="$_mpf_hits feature dirs, e.g. $MPF" || MPF=""
sig "module_per_feature_layout=$( [ -n "$MPF" ] && echo yes || echo no )" "$MPF"
unset _d _c _s _r _names _mpf_hits
API_CLIENT=""
sg 'from ["'"'"']axios["'"'"']|require\(["'"'"']axios["'"'"']\)|createAxios|apiClient|api_urls|\$fetch\(|useFetch\(|openapi-fetch|generated/api' && API_CLIENT="module found in source"
[ -z "$API_CLIENT" ] && mg 'axios|ky|got|openapi-typescript|@hey-api/openapi-ts|swagger-typescript-api' && API_CLIENT="client library in manifest"
sig "api_client_detected=$( [ -n "$API_CLIENT" ] && echo yes || echo no )" "$API_CLIENT"
DTO=""
mg 'class-validator|pydantic|marshmallow|"zod"|"yup"|"joi"|@sinclair/typebox|valibot|dry-validation|FluentValidation' && DTO="declarative validation library"
[ -z "$DTO" ] && sg '@IsString\(|@IsInt\(|BaseModel\)|z\.object\(|yup\.object\(|Joi\.object\(' && DTO="validation decorators/schemas in source"
sig "dto_pattern_detected=$( [ -n "$DTO" ] && echo yes || echo no )" "$DTO"

# ===== Auth ==============================================================================
AUTH=""
mg 'passport|@nestjs/jwt|jsonwebtoken|next-auth|@auth/core|express-session|django.contrib.auth|devise|omniauth|spring-security|authlib|python-jose' && AUTH="auth library in manifest"
[ -z "$AUTH" ] && sg 'AuthGuard|JwtStrategy|Bearer |x-api-key|X-API-Key|@UseGuards\(|requireAuth|IsAuthenticated' && AUTH="auth middleware/guard in source"
sig "auth_scheme_detected=$( [ -n "$AUTH" ] && echo yes || echo no )" "$AUTH"

# ===== Observability =====================================================================
LOGGER="$(first_of 'pino' 'winston' 'bunyan' 'loguru' 'structlog' 'log4j' 'logback' 'zap' 'zerolog' 'monolog' 'serilog')"
sig "logger_lib_detected=$( [ -n "$LOGGER" ] && echo yes || echo no )" "$LOGGER"
METRICS="$(first_of 'prom-client' 'prometheus_client' 'statsd' 'hot-shots' 'datadog' 'dd-trace' 'micrometer' 'appsignal')"
sig "metrics_lib_detected=$( [ -n "$METRICS" ] && echo yes || echo no )" "$METRICS"
TRACER="$(first_of '@opentelemetry/api' 'opentelemetry' 'jaeger-client' 'zipkin' 'elastic-apm-node' 'newrelic')"
sig "tracer_lib_detected=$( [ -n "$TRACER" ] && echo yes || echo no )" "$TRACER"

# ===== Testing ===========================================================================
TEST_FW="$(first_of 'vitest' 'jest' '@playwright/test' 'cypress' 'mocha' 'jasmine' 'pytest' 'unittest2' 'rspec' 'minitest' 'phpunit' 'testify' 'junit' 'xunit' 'nunit' 'exunit')"
[ -z "$TEST_FW" ] && [ -n "$(ff '*_test.go' 6)" ] && TEST_FW="go test"
sig "test_framework_detected=$( [ -n "$TEST_FW" ] && echo yes || echo no )" "$TEST_FW"

# ===== i18n / RTL ========================================================================
# Ported from templates/appendices.md § Appendix A, where they were correct and unreachable.
I18N="$(first_of 'vue-i18n' 'react-i18next' 'i18next' 'next-intl' 'nestjs-i18n' '@nestjs/i18n' 'svelte-i18n' '@angular/localize' 'formatjs' '@lingui/core' 'rails-i18n' 'gettext')"
sig "i18n_lib_detected=$( [ -n "$I18N" ] && echo yes || echo no )" "$I18N"
RTL_EV=""
RTL_FILE=$(find -L . -maxdepth 6 \( $PRUNE \) -prune -o \
             \( -path '*/locales/*' -o -path '*/i18n/*' -o -path '*/lang/*' -o -path '*/translations/*' \) \
             \( -name 'ar*' -o -name 'he*' -o -name 'fa*' -o -name 'ur*' -o -name 'yi*' \) -print 2>/dev/null | head -1)
[ -n "$RTL_FILE" ] && RTL_EV="RTL-script locale file ${RTL_FILE#./}"
[ -z "$RTL_EV" ] && sg 'dir=.?rtl|direction:[[:space:]]*rtl|rtlCss|rtl-detect|stylis-plugin-rtl' && RTL_EV="explicit rtl direction in source"
[ -z "$RTL_EV" ] && grep -qiE '\bRTL\b|right-to-left' README.md 2>/dev/null && RTL_EV="README documents RTL"
sig "rtl_locale_detected=$( [ -n "$RTL_EV" ] && echo yes || echo no )" "$RTL_EV"

# ===== Frontend extras ===================================================================
SSR_FW="$(first_of 'nuxt' 'next' '@sveltejs/kit' '@remix-run/react' 'astro' '@angular/ssr')"
sig "ssr_capable_framework_detected=$( [ -n "$SSR_FW" ] && echo yes || echo no )" "$SSR_FW"
# ssr_enabled — the framework CAN do SSR *and* this project has not turned it off. Distinct
# from the line above on purpose: a Nuxt app with `ssr: false` is a SPA, and three frontend
# topics gate on the difference. Astro is inverted — it is static by default, so it needs an
# explicit opt-IN rather than the absence of an opt-out.
SSR_ON=""
if [ -n "$SSR_FW" ]; then
  case "$SSR_FW" in
    astro)
      grep -hqE "output:[[:space:]]*['\"](server|hybrid)['\"]" astro.config.* 2>/dev/null \
        && SSR_ON="astro output: server/hybrid" ;;
    *)
      if grep -hqE "ssr:[[:space:]]*false" nuxt.config.* 2>/dev/null; then SSR_ON=""
      elif grep -hqE "output:[[:space:]]*['\"]export['\"]" next.config.* 2>/dev/null; then SSR_ON=""
      elif grep -hq "adapter-static" svelte.config.* 2>/dev/null; then SSR_ON=""
      else SSR_ON="$SSR_FW, no opt-out found"
      fi ;;
  esac
fi
sig "ssr_enabled=$( [ -n "$SSR_ON" ] && echo yes || echo no )" "$SSR_ON"
DARK=""
sg 'dark:[a-z-]|prefers-color-scheme|useColorMode|ThemeProvider|data-theme' && DARK="dark-mode markers in source"
[ -z "$DARK" ] && grep -qE 'darkMode' tailwind.config.* 2>/dev/null && DARK="tailwind darkMode config"
sig "dark_mode_capability_detected=$( [ -n "$DARK" ] && echo yes || echo no )" "$DARK"
THEMES=""
sg 'theme-variant|themeVariant|themes/|setTheme\(|switchTheme|data-theme=' && THEMES="theme-switching markers in source"
[ -z "$THEMES" ] && [ -n "$(ffp '*/themes' 5)" ] && THEMES="themes/ directory"
sig "multi_theme_signal_detected=$( [ -n "$THEMES" ] && echo yes || echo no )" "$THEMES"

# ===== Infra / deploy ====================================================================
DOCKERFILE="$(find -L . -maxdepth 4 \( $PRUNE \) -prune -o \( -name 'Dockerfile' -o -name 'Dockerfile.*' \) -print 2>/dev/null | head -1)"
sig "dockerfile_detected=$( [ -n "$DOCKERFILE" ] && echo yes || echo no )" "${DOCKERFILE#./}"
K8S=""
[ -d charts ] || [ -f Chart.yaml ] && K8S="helm chart"
if [ -z "$K8S" ]; then
  while IFS= read -r y; do
    [ -z "$y" ] && continue
    if grep -qE '^apiVersion:' "$y" 2>/dev/null && grep -qE '^kind:[[:space:]]*(Deployment|Service|StatefulSet|DaemonSet|Ingress|ConfigMap|CronJob)' "$y" 2>/dev/null; then
      K8S="${y#./}"; break
    fi
  done < <(find -L . -maxdepth 5 \( $PRUNE \) -prune -o \( -name '*.yaml' -o -name '*.yml' \) -print 2>/dev/null | head -200)
fi
sig "k8s_detected=$( [ -n "$K8S" ] && echo yes || echo no )" "$K8S"
TF="$(find -L . -maxdepth 5 \( $PRUNE \) -prune -o -name '*.tf' -print 2>/dev/null | head -1)"
sig "terraform_detected=$( [ -n "$TF" ] && echo yes || echo no )" "${TF#./}"
sig "dockerfile_or_k8s_detected=$( { [ -n "$DOCKERFILE" ] || [ -n "$K8S" ]; } && echo yes || echo no )" "union of dockerfile_detected, k8s_detected"
sig "dockerfile_or_k8s_or_terraform_detected=$( { [ -n "$DOCKERFILE" ] || [ -n "$K8S" ] || [ -n "$TF" ]; } && echo yes || echo no )" "union of dockerfile/k8s/terraform"
CI=""
[ -n "$(ffp './.github/workflows/*' 3)" ] && CI=".github/workflows"
[ -z "$CI" ] && [ -f .gitlab-ci.yml ]        && CI=".gitlab-ci.yml"
[ -z "$CI" ] && [ -f .circleci/config.yml ]  && CI=".circleci/config.yml"
[ -z "$CI" ] && [ -f bitbucket-pipelines.yml ] && CI="bitbucket-pipelines.yml"
[ -z "$CI" ] && [ -f azure-pipelines.yml ]   && CI="azure-pipelines.yml"
[ -z "$CI" ] && [ -f Jenkinsfile ]           && CI="Jenkinsfile"
sig "ci_config_detected=$( [ -n "$CI" ] && echo yes || echo no )" "$CI"
sig "ci_or_dockerfile_detected=$( { [ -n "$CI" ] || [ -n "$DOCKERFILE" ]; } && echo yes || echo no )" "union of ci_config_detected, dockerfile_detected"
# container_target_likely — the vocabulary also allows "deploy mention in README". That half
# is DELIBERATELY not implemented: grepping prose for "deploy" matches almost every README
# ever written, and a signal that is nearly always yes is not a signal (see
# native_bridge_present). Explicit deploy artifacts only, so a yes means something.
DEPLOY_ART=""
[ -n "$DOCKERFILE" ] && DEPLOY_ART="Dockerfile"
[ -n "$K8S" ]        && DEPLOY_ART="${DEPLOY_ART:-k8s/helm}"
for _f in docker-compose.yml docker-compose.yaml compose.yml Procfile fly.toml render.yaml app.yaml vercel.json; do
  [ -f "$_f" ] && DEPLOY_ART="${DEPLOY_ART:-$_f}" && break
done
unset _f
sig "container_target_likely=$( [ -n "$DEPLOY_ART" ] && echo yes || echo no )" "$DEPLOY_ART"

# ===== VCS ===============================================================================
sig "vcs_detected=$( [ -d .git ] && echo yes || echo no )" "$( [ -d .git ] && echo '.git/' )"
# git_log_accessible — `.git/` alone is not enough: a shallow clone or a permission failure
# leaves the directory present and the history unreadable, which is exactly what
# extract-failures-from-history needs to know before it tries.
GIT_LOG=""
[ -d .git ] && git log -1 --format=%H >/dev/null 2>&1 && GIT_LOG="history readable"
sig "git_log_accessible=$( [ -n "$GIT_LOG" ] && echo yes || echo no )" "$GIT_LOG"

# codebase_age_above_2y — gated on the line above, never on `.git/` alone: a shallow clone
# reports a recent root commit, so an ungated check would call an old codebase young, which
# is the wrong answer in the direction that silently skips the legacy topics.
AGE=""
if [ -n "$GIT_LOG" ]; then
  _root_ts="$(git log --max-parents=0 --format=%ct 2>/dev/null | sort -n | head -1)"
  if [ -n "$_root_ts" ]; then
    _now="$(date +%s)"
    _years=$(( (_now - _root_ts) / 31557600 ))
    [ "$_years" -ge 2 ] && AGE="first commit ~${_years}y ago"
  fi
  unset _root_ts _now _years
fi
sig "codebase_age_above_2y=$( [ -n "$AGE" ] && echo yes || echo no )" "$AGE"

# ===== Migration layout (V1 → V2) ========================================================
MIG_LAYOUT=""
for pair in "v1 v2" "legacy new" "old new"; do
  a="${pair%% *}"; b="${pair##* }"
  if [ -n "$(ffp "*/$a" 5)" ] && [ -n "$(ffp "*/$b" 5)" ]; then MIG_LAYOUT="parallel $a/ + $b/ directories"; break; fi
done
[ -z "$MIG_LAYOUT" ] && [ -n "$(ff '*_v2.*' 6)" ] && [ -n "$(ff '*_v1.*' 6)" ] && MIG_LAYOUT="version-suffixed sibling modules"
[ -z "$MIG_LAYOUT" ] && [ -n "$(ffp '*-v2' 4)" ] && MIG_LAYOUT="workspace package with -v2 suffix"
[ -z "$MIG_LAYOUT" ] && grep -qiE 'v1[[:space:]]*(->|→|to)[[:space:]]*v2|migration from v1' README.md 2>/dev/null && MIG_LAYOUT="README documents a V1→V2 migration"
sig "migration_layout_detected=$( [ -n "$MIG_LAYOUT" ] && echo yes || echo no )" "$MIG_LAYOUT"

# ===== Business domain ===================================================================
# The only signal here whose authority is an EARLIER PHASE, not the filesystem: Phase 2.x
# writes confirmed domains into .claude/_extracted-codebase.md. Read it rather than guess —
# and say plainly when it has not run, instead of answering "no" as if it had.
BD="no"; BD_NOTE="Phase 2.x has not run (.claude/_extracted-codebase.md absent) — re-run after extraction"
if [ -f "$TARGET/.claude/_extracted-codebase.md" ]; then
  n=$(grep -ciE '^\|?[[:space:]]*(domain|bounded context)[[:space:]]*[:|]' "$TARGET/.claude/_extracted-codebase.md" 2>/dev/null || true)
  if [ "${n:-0}" -ge 1 ]; then BD="yes"; BD_NOTE="$n confirmed domain row(s) in .claude/_extracted-codebase.md"
  else BD_NOTE="_extracted-codebase.md present, 0 confirmed domain rows"; fi
fi
sig "business_domain_detected=$BD" "$BD_NOTE"

# ---- emit ------------------------------------------------------------------------------
emit() {
  printf '# Detected signals\n\n'
  printf '> Written by `scripts/detect-signals.sh` against `%s`.\n' "$TARGET"
  printf '> Every `*_detected` trigger `templates/packs/_trigger-vocabulary.md` declares is answered here,\n'
  printf '> including the negative answers — a missing line would be indistinguishable from `no`.\n'
  printf '> A pack `_topics.md` may branch on any name below. Regenerate with the same command.\n\n'
  printf '| signal | value | evidence |\n|---|:---:|---|\n'
  local i=0
  while [ "$i" -lt "${#NAMES[@]}" ]; do
    printf '| `%s` | %s | %s |\n' "${NAMES[$i]}" "${VALS[$i]}" "${NOTES[$i]:-—}"
    i=$((i+1))
  done
  printf '\n## Machine block\n\n```\n'
  i=0
  while [ "$i" -lt "${#NAMES[@]}" ]; do
    printf '%s=%s\n' "${NAMES[$i]}" "${VALS[$i]}"
    i=$((i+1))
  done
  printf '```\n'
  # COVERAGE, stated in the report itself. A vocabulary entry with no row here is the exact
  # defect this script was written for, so the file has to be able to say it about itself.
  if [ -f "$VOCAB" ]; then
    local missing=""
    while IFS= read -r t; do
      [ -z "$t" ] && continue
      printf '%s\n' "${NAMES[@]}" | grep -qxF "$t" || missing="$missing $t"
    done < <(grep -oE '^- `[a-z0-9_]+`' "$VOCAB" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
    printf '\n## Vocabulary coverage\n\n'
    if [ -z "$missing" ]; then
      printf 'Every `*_detected` trigger in `templates/packs/_trigger-vocabulary.md` has a producer here.\n'
    else
      printf '⚠ DECLARED BUT NOT PRODUCED (dead by the vocabulary’s own rule):%s\n' "$missing"
    fi
  fi
}

if [ "$SINK_STDOUT" -eq 1 ]; then
  emit
else
  mkdir -p "$TARGET/.claude"
  emit > "$TARGET/.claude/_detected-signals.md"
  [ "$QUIET" -eq 1 ] || echo "Report written: .claude/_detected-signals.md"
fi
yes_n=0; i=0
while [ "$i" -lt "${#NAMES[@]}" ]; do [ "${VALS[$i]}" = "yes" ] && yes_n=$((yes_n+1)); i=$((i+1)); done
[ "$QUIET" -eq 1 ] || echo "Signals: ${#NAMES[@]} computed, $yes_n detected" >&2
exit 0
