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
declared="$(grep -oE '^- `[a-z0-9_]+`' "$VOCAB" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u)"

# Declared triggers detect-signals.sh does NOT produce, each named with why. This list is
# printed on every run so it stays a backlog and not a silence.
#
# Until this check enumerated `_detected` names ONLY, none of these was visible: the same
# blind spot sat in all three guards for it (this file, lint-setup-contracts.sh Rule 4 and
# detect-signals.sh's own coverage report), so a trigger whose name lacked that suffix was
# unguarded by construction. `native_bridge_present` was one of them — declared, gating a real
# mobile topic, produced by nothing, so that topic could never fire on any project. It now has
# an extractor; these ten do not yet.
#
#   refine_mode, refinement_eligible   run context (the --refine flag), not a codebase fact —
#                                      this script inspects a repo and cannot know the flag
#   backend_track                      track selection, decided during pack choice
#   codebase_has_base_classes          defined as "≥1 class with ≥3 extenders found in Step 5"
#                                      — cross-file inheritance analysis, which is the
#                                      extraction step's job. A grep for `extends X` would be
#                                      language-specific and wrong on Python, Go and Dart.
#
# Six that WERE on this list now have extractors: git_log_accessible, codebase_age_above_2y,
# container_target_likely, module_per_feature_layout, ssr_enabled, migration_ledger_present.
# Each was verified to DISCRIMINATE, not merely to run — across five production repos plus a
# synthetic positive where the real set had no yes case.
UNPRODUCED='backend_track codebase_has_base_classes refine_mode refinement_eligible'
declared="$(comm -23 <(printf '%s\n' "$declared" | sort -u) <(printf '%s\n' $UNPRODUCED | sort -u))"
say "     backlog — $(printf '%s\n' $UNPRODUCED | grep -c .) declared trigger(s) with no producer: $UNPRODUCED"
miss="$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$emitted") | tr '\n' ' ')"
extra="$(comm -13 <(printf '%s\n' "$declared") <(printf '%s\n' "$emitted") | tr '\n' ' ')"
[ -z "${miss// /}" ]  && ok "§1 every declared trigger has a producer (backlog excluded)" \
                      || bad "§1 every declared trigger has a producer (backlog excluded)" "no producer for:$miss"
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

# ── § 2c  a pnpm/turbo MONOREPO — the root manifest declares nothing ─────────────────────
# The defect this pins: every signal was resolved from root manifests only. In a workspace repo
# the root package.json is the WORKSPACE file, so a React web app and a MikroORM API one level
# down both reported `no`. MEASURED on a real repo before it was a fixture. `no` here is not a
# cosmetic wrong row — it deselects the ui-ux and frontend packs, so the project's design tokens
# are never extracted and every command that needs them halts on a repo that has them.
say "§ 2c  pnpm + turbo monorepo: deps live in apps/*, never at the root"
M="$TD/mono"
mkdir -p "$M/apps/api/src/modules/orders" "$M/apps/web/src/features" "$M/packages/ui/src"
cat > "$M/package.json" <<'J'
{ "name":"mono","private":true,"workspaces":["apps/*","packages/*"],
  "devDependencies":{"turbo":"^2","typescript":"^5"} }
J
printf 'packages:\n  - "apps/*"\n  - "packages/*"\n' > "$M/pnpm-workspace.yaml"
printf 'pnpm-lock stub\n' > "$M/pnpm-lock.yaml"
cat > "$M/apps/api/package.json" <<'J'
{ "name":"@mono/api","dependencies":{"fastify":"^5","@mikro-orm/core":"^6","@mikro-orm/postgresql":"^6"} }
J
cat > "$M/apps/web/package.json" <<'J'
{ "name":"@mono/web","dependencies":{"react":"^19","react-dom":"^19"},
  "devDependencies":{"vite":"^8","tailwindcss":"^4"} }
J
printf 'export class OrdersController {}\n' > "$M/apps/api/src/modules/orders/orders.controller.ts"
printf 'export const App = () => null\n'     > "$M/apps/web/src/features/App.tsx"
MBM="$(mb "$M")"
# the whole point: BOTH halves are seen, from one repo, with an empty root manifest
assert "§2c" "$MBM" primary_frontend_framework_detected  yes
assert "§2c" "$MBM" primary_framework_detected           yes
assert "§2c" "$MBM" orm_detected                         yes
assert "§2c" "$MBM" build_tool_detected                  yes
assert "§2c" "$MBM" package_manager_detected             yes
assert "§2c" "$MBM" controller_pattern_detected          yes
# and a workspace member must not invent what no member declares
assert "§2c" "$MBM" mobile_framework_detected            no
assert "§2c" "$MBM" terraform_detected                   no

# ── § 2d  container_target_likely reads every compose shape, and nothing else ─────────────
# The defect this pins: only root `docker-compose.y*ml` and `compose.yml` counted, so the Compose
# Specification's canonical `compose.yaml`, an override or per-environment file and a compose file
# nested under deploy/ all reported `no` — and the devops and infrastructure topics gated on it never fired.
say "§ 2d  container_target_likely: compose.yaml, override files, nested compose"
for shape in compose.yaml compose.override.yaml docker-compose.prod.yml deploy/compose.yaml infra/docker/docker-compose.yml; do
  C="$TD/compose-$(printf '%s' "$shape" | tr '/.' '__')"; mkdir -p "$C/$(dirname "$shape")"; printf '{}\n' > "$C/package.json"
  printf 'services:\n  api:\n    image: api\n' > "$C/$shape"
  assert "§2d $shape" "$(mb "$C")" container_target_likely yes
done
# and an empty repo, or one whose only YAML merely mentions compose, stays dark
assert "§2d empty" "$MB0" container_target_likely no
C="$TD/compose-none"; mkdir -p "$C"; printf '{}\n' > "$C/package.json"; printf 'composer: true\n' > "$C/composer.yaml"
assert "§2d composer.yaml" "$(mb "$C")" container_target_likely no

# ── § 2e  llm_usage_detected: SDK, raw-HTTP gateway, nested Python service — and the decoys ─
# The defect this pins: nothing produced llm_usage_detected, so the ai-engineering pack and
# @llm-security-reviewer never fired. MEASURED on a real monorepo that calls an OpenAI-compatible
# gateway over raw HTTP: no provider SDK anywhere, so only the wire lane sees it. The decoys are
# the shapes that made the old substring greps lie: an SMS API on /v1/messages, Twilio's
# messages.create, `cohere` inside "coherence", a role type union, a token bucket's max_tokens,
# and an OpenAI call that lives only in a test.
say "§ 2e  llm_usage_detected: SDK, raw-HTTP gateway, nested Python service; SMS / Twilio / coherence decoys"
L="$TD/llm-sdk"; mkdir -p "$L/src"
printf '{ "name":"sdk","dependencies":{"openai":"^5.0.0","express":"^5"} }\n' > "$L/package.json"
printf "import OpenAI from 'openai';\nexport const client = new OpenAI();\n" > "$L/src/llm.ts"
assert "§2e sdk" "$(mb "$L")" llm_usage_detected yes
L="$TD/llm-wire"; mkdir -p "$L/apps/api/src/llm"
printf '{ "name":"gw","private":true,"workspaces":["apps/*"] }\n' > "$L/package.json"
printf '{ "name":"@gw/api","dependencies":{"@nestjs/core":"^11"} }\n' > "$L/apps/api/package.json"
cat > "$L/apps/api/src/llm/gateway.port.ts" <<'J'
export async function complete(base: string, model: string, text: string) {
  const res = await fetch(`${base}/v1/chat`, { method: 'POST', body: JSON.stringify({
    model, max_tokens: 1024, messages: [{ role: 'system', content: 'Extract the order' }, { role: 'user', content: text }],
  }) });
  return res.json();
}
J
assert "§2e raw-http gateway" "$(mb "$L")" llm_usage_detected yes
L="$TD/llm-py"; mkdir -p "$L/services/rag/app"
printf '[project]\nname = "rag"\ndependencies = [\n  "fastapi>=0.115",\n  "anthropic>=0.40",\n]\n' > "$L/services/rag/pyproject.toml"
printf 'def answer(q):\n    return q\n' > "$L/services/rag/app/answer.py"
assert "§2e nested python service" "$(mb "$L")" llm_usage_detected yes
L="$TD/llm-decoys"; mkdir -p "$L/src/notify" "$L/src/core" "$L/src/users" "$L/src/limits" "$L/src/__tests__"
printf '{ "name":"decoys","dependencies":{"twilio":"^5","express":"^5"} }\n' > "$L/package.json"
printf "export const send = (to: string, from: string, text: string) =>\n  fetch('https://sms.example.com/v1/messages', { method: 'POST', body: JSON.stringify({ to, from, text }) });\n" > "$L/src/notify/sms.ts"
printf "import twilio from 'twilio';\nconst client = twilio();\nexport const sms = (to: string, body: string) => client.messages.create({ body, to, from: '+15550000' });\n" > "$L/src/notify/twilio.ts"
printf '// cohere: the coherence score of a cluster, not a provider\nexport const coherenceScore = (x: number) => x * 2;\n' > "$L/src/core/coherence.ts"
printf "export type Role = 'system' | 'user' | 'assistant';\nexport const SYSTEM_ROLE = { role: 'system' as Role, label: 'System user' };\n" > "$L/src/users/roles.ts"
printf 'export class TokenBucket { max_tokens = 10; refill() { return this.max_tokens; } }\n' > "$L/src/limits/bucket.ts"
printf "import OpenAI from 'openai';\nnew OpenAI().chat.completions.create({ model: 'gpt-4o', messages: [] });\n" > "$L/src/__tests__/gateway.spec.ts"
assert "§2e decoys only" "$(mb "$L")" llm_usage_detected no
assert "§2a vue spa"      "$MBV" llm_usage_detected no
assert "§2b nestjs api"   "$MBN" llm_usage_detected no

# ── § 2f  paid_api_detected: SDK, base-URL-only gateway — and the decoys ─────────────────
# finops IR-7: the pack was gated on IaC only, so a repo whose spend is an SMS provider or an LLM
# gateway reached by a configured URL never got spend-path-scan. Decoys: a payment SDK (billed per
# transaction), the app's own API_BASE_URL, and a provider host that lives only in a test.
say "§ 2f  paid_api_detected: per-call SDK, billed-category base URL; payment SDK / own-URL / test-only decoys"
P="$TD/paid-sdk"; mkdir -p "$P/src"
printf '{ "name":"notify","dependencies":{"twilio":"^5","express":"^5"} }\n' > "$P/package.json"
printf "export const x = 1;\n" > "$P/src/index.ts"
assert "§2f sms sdk" "$(mb "$P")" paid_api_detected yes
P="$TD/paid-url"; mkdir -p "$P/apps/api/src/geo"
printf '{ "name":"m","private":true,"workspaces":["apps/*"] }\n' > "$P/package.json"
printf '{ "name":"@m/api","dependencies":{"@nestjs/core":"^11"} }\n' > "$P/apps/api/package.json"
printf "export const geocode = (q: string) => fetch(\`\${process.env.GEOCODER_BASE_URL}/search?q=\${q}\`);\n" > "$P/apps/api/src/geo/geocoder.ts"
assert "§2f base-url-only geocoder" "$(mb "$P")" paid_api_detected yes
P="$TD/paid-decoys"; mkdir -p "$P/src/pay" "$P/src/__tests__"
printf '{ "name":"shop","dependencies":{"stripe":"^17","express":"^5"} }\n' > "$P/package.json"
printf "import Stripe from 'stripe';\nexport const api = process.env.API_BASE_URL;\nexport const s = new Stripe('k');\n" > "$P/src/pay/stripe.ts"
printf "const host = 'https://api.openai.com/v1';\n" > "$P/src/__tests__/gateway.spec.ts"
assert "§2f decoys only" "$(mb "$P")" paid_api_detected no
assert "§2a vue spa"      "$MBV" paid_api_detected no
assert "§2e llm sdk (an LLM is billed per token)" "$(mb "$TD/llm-sdk")" paid_api_detected yes

# ── § 2g  numeric_or_geo_lib_detected: anchored libraries — never the word gate ─────────────
# algorithms O-4: a suggestion signal for the opt-in pack. The old word gate over source matched
# about 30 % of a CRUD repo; the decoys are exactly those words (mean, distance, score, matrix,
# sketch) plus a map-rendering library, which is not geodesy.
say "§ 2g  numeric_or_geo_lib_detected: python numeric service, PostGIS migration; word and map-render decoys"
G="$TD/num-py"; mkdir -p "$G/services/analytics"
printf '[project]\nname = "a"\ndependencies = [\n  "numpy>=2.1",\n]\n' > "$G/services/analytics/pyproject.toml"
assert "§2g nested numpy" "$(mb "$G")" numeric_or_geo_lib_detected yes
G="$TD/num-gis"; mkdir -p "$G/db/migrations"; printf '{}\n' > "$G/package.json"
printf 'CREATE EXTENSION IF NOT EXISTS postgis;\nALTER TABLE stores ADD COLUMN loc geometry(Point, 4326);\n' > "$G/db/migrations/0002_geo.sql"
assert "§2g postgis migration" "$(mb "$G")" numeric_or_geo_lib_detected yes
G="$TD/num-decoys"; mkdir -p "$G/src"
printf '{ "name":"crm","dependencies":{"leaflet":"^1.9","react":"^19"} }\n' > "$G/package.json"
printf "export const meanScore = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;\nexport const distance = 3; // sketch of the matrix layout\n" > "$G/src/score.ts"
assert "§2g decoys only" "$(mb "$G")" numeric_or_geo_lib_detected no
assert "§2b nestjs api"   "$MBN" numeric_or_geo_lib_detected no

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
