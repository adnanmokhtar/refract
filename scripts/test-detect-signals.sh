#!/usr/bin/env bash
# test-detect-signals.sh — fixtures for scripts/detect-signals.sh.
#
# WHY. `templates/packs/_trigger-vocabulary.md` declares the signals every pack `_topics.md`
# branches on, and its own hard rule is "a trigger no extractor produces is dead code".
# MEASURED 2026-08-23: 29 of its 32 `*_detected` triggers had NO producer anywhere, so every
# topic gated on one could not fire on any project — and the ratchet meant to catch that had
# all 29 recorded in its baseline, so no gate turned red. The two that HAD been fixed lived in
# `templates/appendices.md`, a COLD doc no script runs.
#
# Two things are pinned here, and the second is the one that rots:
#   § 1  COVERAGE — every `*_detected` name in the vocabulary is emitted by the script, and
#        every name the script emits is in the vocabulary. A signal invented in one place and
#        not the other is the same drift class in a new direction.
#   § 2  CORRECTNESS — over two synthetic repos of opposite shape (a Vue SPA and a NestJS
#        service), the answers are checked BOTH ways: what must fire, and what must NOT. An
#        extractor that answers `yes` to everything passes a one-sided test.
#
# Everything runs under mktemp -d. Nothing is written outside it.
# Usage: test-detect-signals.sh [--quiet]   Exit: 0 pass / 1 fail
set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
DETECT="${DETECT_OVERRIDE:-$REPO_ROOT/scripts/detect-signals.sh}"
VOCAB="$REPO_ROOT/templates/packs/_trigger-vocabulary.md"
QUIET=0; for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }
pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; return 0; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
[ -f "$DETECT" ] || { echo "ERR: $DETECT not found" >&2; exit 1; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-detect-signals.XXXXXX")
trap 'rm -rf "$TD"' EXIT
mb() { bash "$DETECT" "$1" --stdout --quiet 2>/dev/null | awk '/^```$/{f=!f;next} f&&/=/{print}'; }
val() { printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -1; }
assert() {  # $1=label $2=machine-block $3=signal $4=expected
  local got; got="$(val "$3" "$2")"
  if [ "$got" = "$4" ]; then ok "$1 $3=$4"; else bad "$1 $3=$4" "got '${got:-<absent>}'"; fi
}

# ── § 1  the script and the vocabulary agree on the signal set ───────────────────────────
say "§ 1  vocabulary coverage is exact in both directions"
mkdir -p "$TD/empty"; printf '{}\n' > "$TD/empty/package.json"
MB0="$(mb "$TD/empty")"
emitted="$(printf '%s\n' "$MB0" | sed 's/=.*//' | sort -u)"
declared="$(grep -oE '^- `[a-z0-9_]+_detected`' "$VOCAB" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u)"
miss="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$emitted") | tr '\n' ' ')"
extra="$(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$emitted") | tr '\n' ' ')"
[ -z "${miss// /}" ]  && ok "§1 every declared *_detected trigger has a producer" \
                      || bad "§1 every declared *_detected trigger has a producer" "no producer for:$miss"
[ -z "${extra// /}" ] && ok "§1 the script emits nothing the vocabulary does not declare" \
                      || bad "§1 the script emits nothing the vocabulary does not declare" "undeclared:$extra"
n0=$(printf '%s\n' "$MB0" | grep -c . || true)
[ "${n0:-0}" -ge 30 ] && ok "§1 negatives are emitted too ($n0 rows on a near-empty repo)" \
                      || bad "§1 negatives are emitted too" "only $n0 rows — an absent line is indistinguishable from 'no'"

# ── § 2a  a Vue 3 SPA, Arabic-first ──────────────────────────────────────────────────────
say "§ 2a  Vue 3 SPA with vite, pinia, vue-i18n and an Arabic locale"
V="$TD/spa"
mkdir -p "$V/src/components" "$V/src/locales" "$V/src/services" "$V/.github/workflows"
cat > "$V/package.json" <<'J'
{ "name":"portal","dependencies":{"vue":"^3.4.0","vue-router":"^4","pinia":"^2","vue-i18n":"^9.9.0","axios":"^1.6","primevue":"^3"},
  "devDependencies":{"vite":"^5","vitest":"^1","@playwright/test":"^1"} }
J
printf 'package-lock stub\n' > "$V/package-lock.json"
printf '{"hello":"مرحبا"}\n' > "$V/src/locales/ar.json"
printf 'export const apiClient = axios.create({})\n' > "$V/src/services/index.ts"
printf '<template><div dir="rtl"/></template>\n' > "$V/src/components/App.vue"
printf 'export const router = createRouter({})\n' > "$V/src/router.ts"
printf 'name: ci\n' > "$V/.github/workflows/ci.yml"
printf 'FROM node:20\n' > "$V/Dockerfile"
MBV="$(mb "$V")"
assert "§2a" "$MBV" primary_frontend_framework_detected yes
assert "§2a" "$MBV" build_tool_detected                 yes
assert "§2a" "$MBV" package_manager_detected            yes
assert "§2a" "$MBV" test_framework_detected             yes
assert "§2a" "$MBV" i18n_lib_detected                   yes
assert "§2a" "$MBV" rtl_locale_detected                 yes
assert "§2a" "$MBV" api_client_detected                 yes
assert "§2a" "$MBV" dockerfile_detected                 yes
assert "§2a" "$MBV" ci_config_detected                  yes
# the other side: a browserless/backend signal must NOT fire here
assert "§2a" "$MBV" orm_detected                        no
assert "§2a" "$MBV" terraform_detected                  no
assert "§2a" "$MBV" k8s_detected                        no
assert "§2a" "$MBV" mobile_framework_detected           no
assert "§2a" "$MBV" ssr_capable_framework_detected      no

# ── § 2b  a NestJS service, no browser anywhere ──────────────────────────────────────────
say "§ 2b  NestJS service with TypeORM, migrations and k8s manifests"
N="$TD/api"
mkdir -p "$N/src/modules/orders" "$N/src/migrations" "$N/deploy"
cat > "$N/package.json" <<'J'
{ "name":"api","dependencies":{"@nestjs/core":"^10","typeorm":"^0.3","class-validator":"^0.14","@nestjs/jwt":"^10","pino":"^8"},
  "devDependencies":{"jest":"^29"} }
J
printf 'pnpm-lock stub\n' > "$N/pnpm-lock.yaml"
printf 'export class OrdersController {}\n' > "$N/src/modules/orders/orders.controller.ts"
printf 'export class Init1700 {}\n' > "$N/src/migrations/1700-init.ts"
printf 'apiVersion: apps/v1\nkind: Deployment\n' > "$N/deploy/app.yaml"
MBN="$(mb "$N")"
assert "§2b" "$MBN" primary_framework_detected           yes
assert "§2b" "$MBN" orm_detected                         yes
assert "§2b" "$MBN" migration_tool_detected              yes
assert "§2b" "$MBN" migration_dir_detected               yes
assert "§2b" "$MBN" controller_pattern_detected          yes
assert "§2b" "$MBN" dto_pattern_detected                 yes
assert "§2b" "$MBN" auth_scheme_detected                 yes
assert "§2b" "$MBN" logger_lib_detected                  yes
assert "§2b" "$MBN" test_framework_detected              yes
assert "§2b" "$MBN" k8s_detected                         yes
assert "§2b" "$MBN" dockerfile_or_k8s_detected           yes
# and the frontend half must stay dark
assert "§2b" "$MBN" primary_frontend_framework_detected  no
assert "§2b" "$MBN" i18n_lib_detected                    no
assert "§2b" "$MBN" rtl_locale_detected                  no
assert "§2b" "$MBN" dockerfile_detected                  no

# ── § 3  --stdout writes NOTHING under the target ────────────────────────────────────────
say "§ 3  --stdout is read-only against the target"
R="$TD/readonly"; mkdir -p "$R"; printf '{}\n' > "$R/package.json"
before=$(find "$R" | sort | shasum | cut -c1-16)
bash "$DETECT" "$R" --stdout --quiet >/dev/null 2>&1
after=$(find "$R" | sort | shasum | cut -c1-16)
[ "$before" = "$after" ] && ok "§3 --stdout created nothing under the target" \
                         || bad "§3 --stdout created nothing under the target" "tree changed"
bash "$DETECT" "$R" --quiet >/dev/null 2>&1
[ -f "$R/.claude/_detected-signals.md" ] && ok "§3 the default mode DOES write the report" \
                                         || bad "§3 the default mode DOES write the report" "no .claude/_detected-signals.md"

say ""
say "detect-signals fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
