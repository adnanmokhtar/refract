---
artifact: appendices
purpose: Reference implementations + Appendix A (detection commands), B (relevance filter), C (merge decision matrix), D (codebase profile shape), E (learnings encoded), F (glossary).
imported-by: commands/setup-project.md (orchestrator) — listed but not always loaded; tier-3 cold-load.
---

## Reference implementations

When in doubt, match the shape of mature reference projects with these characteristics:
- A mature multi-tenant backend API (NestJS / Express / Django-class shapes illustrated in references; ~14 agents, ~19 commands, ~10 ai/ files, idiom-rich) — references for backend track + multi-tenant signal + AI signal.
- A Nuxt SSR multi-theme storefront — references for frontend track + SSR pattern + multi-theme variant.
- A Vue / React Composition-style SPA + `<TBD: store>` (~15 agents, ai/core, ai/references) — references for frontend-vue-composition variant + dynamic-tracking extension.
- A workspace orchestration root with dispatcher agent + sibling registry (PROJECTS.md) — references for ext:workspace-cascade + cross-repo commands.

Tool adapter specs (one per driver):
- `~/.claude/templates/tool-adapters/README.md` — overview + capability matrix.
- `~/.claude/templates/tool-adapters/_registry.md` — capability legend + selection logic.
- `~/.claude/templates/tool-adapters/<key>/adapter.md` — per-tool translation spec (target files, format, recipe, idempotency, gotchas, sample output). Keys: `claude-code`, `opencode`, `cursor`, `aider`, `continue`, `cline`, `windsurf`, `copilot`, `codex`, `gemini`.

---

## Appendix A — Detection commands

Run these at start of Phase 2. Each has a grep / file-check proof.

```bash
# ===== Backend frameworks =====
HAS_NESTJS=$(grep -q '"@nestjs/core"' package.json 2>/dev/null && echo yes)
HAS_EXPRESS=$(grep -q '"express"' package.json 2>/dev/null && echo yes)
HAS_FASTIFY=$(grep -q '"fastify"\|@fastify/' package.json 2>/dev/null && echo yes)
HAS_FASTAPI=$(grep -q 'fastapi' pyproject.toml requirements.txt 2>/dev/null && echo yes)
HAS_DJANGO=$(grep -q '^Django\|"django"' requirements.txt pyproject.toml 2>/dev/null && echo yes)
HAS_FLASK=$(grep -q '^Flask\|"flask"' requirements.txt pyproject.toml 2>/dev/null && echo yes)
HAS_LARAVEL=$([ -f composer.json ] && grep -q 'laravel/framework' composer.json 2>/dev/null && echo yes)
HAS_RAILS=$([ -f Gemfile ] && grep -q "'rails'" Gemfile 2>/dev/null && echo yes)
HAS_SPRING=$(grep -q 'spring-boot' pom.xml build.gradle build.gradle.kts 2>/dev/null && echo yes)
HAS_DOTNET=$(find . -maxdepth 3 -name '*.csproj' | head -1 | grep -q . && echo yes)
HAS_PHOENIX=$([ -f mix.exs ] && grep -q 'phoenix' mix.exs 2>/dev/null && echo yes)
HAS_GO_BACKEND=$([ -f go.mod ] && grep -q 'gin-gonic\|chi-router\|gofiber\|labstack/echo' go.mod 2>/dev/null && echo yes)

# ===== Frontend frameworks =====
HAS_REACT=$(grep -q '"react"' package.json 2>/dev/null && echo yes)
HAS_VUE=$(grep -q '"vue"\|@vue/' package.json 2>/dev/null && echo yes)
HAS_ANGULAR=$(grep -q '@angular/core' package.json 2>/dev/null && echo yes)
HAS_NUXT=$(grep -q '"nuxt"' package.json 2>/dev/null && echo yes)
HAS_NEXTJS=$(grep -q '"next"' package.json 2>/dev/null && echo yes)
HAS_SVELTE=$(grep -q '"svelte"\|@sveltejs/' package.json 2>/dev/null && echo yes)
HAS_SOLID=$(grep -q '"solid-js"' package.json 2>/dev/null && echo yes)
HAS_ASTRO=$(grep -q '"astro"' package.json 2>/dev/null && echo yes)
HAS_REMIX=$(grep -q '@remix-run/' package.json 2>/dev/null && echo yes)

# ----- Frontend TOOLCHAIN, not just the framework -----
# HISTORY: this block did not exist. Running Appendix A verbatim against a live Vue 3 SPA
# returned only the framework name and NOTHING else usable — no build tool, no store, no router,
# no i18n, no UI kit, no MAJOR version. It is the same blind spot for React (redux / zustand /
# MUI / shadcn / react-router) and for Angular (NgRx / Angular Material). The correct stack reached that
# project's profile only because a human had typed it there previously. `build_tool_detected`
# was a declared trigger in templates/packs/_trigger-vocabulary.md with no emitter anywhere,
# which that file's own hard rules call dead code.
VUE_MAJOR=$(sed -nE 's/.*"vue"[[:space:]]*:[[:space:]]*"[^0-9]*([0-9]+).*/\1/p' package.json 2>/dev/null | head -1)
REACT_MAJOR=$(sed -nE 's/.*"react"[[:space:]]*:[[:space:]]*"[^0-9]*([0-9]+).*/\1/p' package.json 2>/dev/null | head -1)
HAS_VITE=$(grep -q '"vite"' package.json 2>/dev/null && echo yes)
HAS_WEBPACK=$(grep -q '"webpack"' package.json 2>/dev/null && echo yes)
HAS_ESBUILD=$(grep -q '"esbuild"' package.json 2>/dev/null && echo yes)
HAS_ROLLUP=$(grep -q '"rollup"' package.json 2>/dev/null && echo yes)
HAS_TURBOPACK=$(grep -q '"turbo"\|turbopack' package.json 2>/dev/null && echo yes)
# build_tool_detected — the trigger name _trigger-vocabulary.md:21 declares.
BUILD_TOOL_DETECTED=$([ -n "$HAS_VITE$HAS_WEBPACK$HAS_ESBUILD$HAS_ROLLUP$HAS_TURBOPACK" ] && echo yes)

# State: Pinia/Vuex (Vue) alongside redux/zustand (React) — one family per line reads as a
# single-stack block to scripts/audit-stack-leakage.sh, so keep the families adjacent.
HAS_PINIA=$(grep -q '"pinia"' package.json 2>/dev/null && echo yes)          # Vue — cf. redux
HAS_VUEX=$(grep -q '"vuex"' package.json 2>/dev/null && echo yes)            # Vue — cf. zustand
HAS_REDUX=$(grep -q '@reduxjs/toolkit\|"redux"' package.json 2>/dev/null && echo yes)   # React — cf. Pinia
HAS_ZUSTAND=$(grep -q '"zustand"' package.json 2>/dev/null && echo yes)      # React — cf. Vuex
HAS_TANSTACK_QUERY=$(grep -q '@tanstack/.*query' package.json 2>/dev/null && echo yes)  # React/Vue — cf. Pinia
STATE_LIB_DETECTED=$([ -n "$HAS_PINIA$HAS_VUEX$HAS_REDUX$HAS_ZUSTAND$HAS_TANSTACK_QUERY" ] && echo yes)

HAS_VUE_ROUTER=$(grep -q '"vue-router"' package.json 2>/dev/null && echo yes)
HAS_REACT_ROUTER=$(grep -q 'react-router' package.json 2>/dev/null && echo yes)
ROUTER_DETECTED=$([ -n "$HAS_VUE_ROUTER$HAS_REACT_ROUTER" ] && echo yes)

HAS_TAILWIND=$(grep -q 'tailwindcss' package.json 2>/dev/null && echo yes)
HAS_BOOTSTRAP=$(grep -q '"bootstrap"' package.json 2>/dev/null && echo yes)
HAS_PRIMEVUE=$(grep -q '"primevue"\|"primereact"\|"primeng"' package.json 2>/dev/null && echo yes)
HAS_MUI=$(grep -q '@mui/' package.json 2>/dev/null && echo yes)
HAS_VUETIFY=$(grep -q '"vuetify"' package.json 2>/dev/null && echo yes)
HAS_CHAKRA=$(grep -q '@chakra-ui/' package.json 2>/dev/null && echo yes)     # React — cf. Vuetify
HAS_SHADCN=$([ -f components.json ] && grep -q 'shadcn\|"ui":' components.json 2>/dev/null && echo yes)  # React — cf. PrimeVue
CSS_FRAMEWORK_DETECTED=$([ -n "$HAS_TAILWIND$HAS_BOOTSTRAP$HAS_PRIMEVUE$HAS_MUI$HAS_VUETIFY$HAS_CHAKRA$HAS_SHADCN" ] && echo yes)

# ----- i18n / RTL -----
# HISTORY: `i18n_lib_detected` and `rtl_locale_detected` are declared in
# templates/packs/_trigger-vocabulary.md:76-77 and consumed by templates/packs/ui-ux/_topics.md
# and templates/packs/frontend/_topics.md, and NOTHING anywhere produced them. The vocabulary's
# own hard rules say "a trigger no extractor produces is dead code", and three other signals had
# already been given emitters here for exactly that reason. On a genuinely Arabic-first codebase
# (vue-i18n ^9.9.0, src/locales/ar.json at 273 KB, `dir="rtl"` set at runtime, fallback locale
# `ar`) neither signal fired, so the ui-ux `rtl` topic and four frontend i18n topics could not
# be reached on ANY project.
I18N_LIB_DETECTED=$(grep -qE '"vue-i18n"|"react-i18next"|"i18next"|"next-intl"|"nestjs-i18n"|"@nestjs/i18n"|"svelte-i18n"|"@angular/localize"|"formatjs"|"@lingui/"|Babel|django\.utils\.translation|"gettext"|"rails-i18n"' \
  package.json pyproject.toml requirements.txt Gemfile composer.json 2>/dev/null && echo yes)
# RTL: an RTL-script locale FILE (ar/he/fa/ur/yi), an explicit dir="rtl", or a documented mention.
RTL_LOCALE_DETECTED=$( { find . -maxdepth 6 \( -path '*/locales/*' -o -path '*/i18n/*' -o -path '*/lang/*' -o -path '*/translations/*' \) \
      \( -name 'ar*' -o -name 'he*' -o -name 'fa*' -o -name 'ur*' -o -name 'yi*' \) \
      -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -1 | grep -q . \
   || grep -rqE 'dir=("|.)rtl|direction:[[:space:]]*rtl|\brtlCss\b|rtl-detect|stylis-plugin-rtl' \
      src/ app/ apps/ lib/ libs/ 2>/dev/null \
   || grep -qiE '\bRTL\b|right-to-left' README.md 2>/dev/null ; } && echo yes)

# ===== Mobile =====
HAS_RN=$(grep -q 'react-native\|expo' package.json 2>/dev/null && echo yes)
HAS_FLUTTER=$([ -f pubspec.yaml ] && echo yes)
HAS_NATIVE_IOS=$(find . -maxdepth 3 -name '*.xcodeproj' 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_NATIVE_ANDROID=$(find . -maxdepth 3 -name 'build.gradle' -path '*/android/*' 2>/dev/null | head -1 | grep -q . && echo yes)

# ===== Databases =====
HAS_POSTGRES=$(grep -q '"pg"\|psycopg\|"postgresql"\|postgres://' package.json pyproject.toml requirements.txt composer.json Gemfile 2>/dev/null && echo yes)
HAS_MYSQL=$(grep -q 'mysql2\|mariadb\|PyMySQL\|mysqlclient' package.json pyproject.toml requirements.txt 2>/dev/null && echo yes)
HAS_MONGO=$(grep -q 'mongoose\|"mongodb"\|pymongo\|mongoid' package.json pyproject.toml requirements.txt Gemfile 2>/dev/null && echo yes)
HAS_SQLITE=$(grep -q 'better-sqlite3\|"sqlite3"' package.json 2>/dev/null && echo yes)
HAS_REDIS=$(grep -q 'ioredis\|"redis"\|python-redis\|predis' package.json pyproject.toml requirements.txt composer.json 2>/dev/null && echo yes)
HAS_ELASTIC=$(grep -q '@elastic/\|elasticsearch\|opensearch' package.json pyproject.toml requirements.txt 2>/dev/null && echo yes)

# ===== ORMs =====
HAS_TYPEORM=$(grep -q '"typeorm"' package.json 2>/dev/null && echo yes)
HAS_PRISMA=$(grep -q '"prisma"\|@prisma/client' package.json 2>/dev/null && echo yes)
HAS_SQLALCHEMY=$(grep -q 'sqlalchemy' requirements.txt pyproject.toml 2>/dev/null && echo yes)
HAS_ACTIVERECORD=$([ -f Gemfile ] && grep -q 'activerecord\|rails' Gemfile 2>/dev/null && echo yes)
HAS_ELOQUENT=$([ -f composer.json ] && grep -q 'illuminate/database' composer.json 2>/dev/null && echo yes)
HAS_DRIZZLE=$(grep -q 'drizzle-orm' package.json 2>/dev/null && echo yes)

# ===== Infrastructure =====
HAS_DOCKER=$([ -f Dockerfile ] || [ -f docker-compose.yml ] || [ -f docker-compose.yaml ] && echo yes)
HAS_K8S=$(find . -maxdepth 4 -type f \( -name '*.yaml' -o -name '*.yml' \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null \
  | xargs grep -l '^apiVersion:.*\(apps\|batch\|core\|networking\)' 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_HELM=$(find . -maxdepth 4 -name 'Chart.yaml' 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_SWARM=$(grep -q 'deploy:' docker-compose*.yml 2>/dev/null && echo yes)
HAS_TERRAFORM=$(find . -maxdepth 3 -name '*.tf' -not -path '*/node_modules/*' 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_PULUMI=$(find . -maxdepth 2 -name 'Pulumi.yaml' 2>/dev/null | head -1 | grep -q . && echo yes)

# ===== CI =====
HAS_GITHUB_CI=$([ -d .github/workflows ] && echo yes)
HAS_GITLAB_CI=$([ -f .gitlab-ci.yml ] && echo yes)
HAS_CIRCLECI=$([ -f .circleci/config.yml ] && echo yes)

# ===== Domain signals =====
HAS_CLAUDE=$(grep -q '@anthropic-ai/sdk' package.json pyproject.toml requirements.txt 2>/dev/null && echo yes)
HAS_OPENAI=$(grep -q '"openai"\|^openai$' package.json requirements.txt pyproject.toml 2>/dev/null && echo yes)
HAS_GEMINI=$(grep -q '@google/generative-ai\|google-generativeai' package.json requirements.txt 2>/dev/null && echo yes)

HAS_STRIPE=$(grep -q '"stripe"' package.json pyproject.toml requirements.txt 2>/dev/null && echo yes)
HAS_PAYPAL=$(grep -q '@paypal/\|paypalrestsdk' package.json pyproject.toml 2>/dev/null && echo yes)
HAS_PADDLE=$(grep -q '"paddle-sdk"\|paddlesdk' package.json 2>/dev/null && echo yes)

HAS_WEBHOOK=$(grep -rnE '(X-Hub-Signature|Stripe-Signature|X-Webhook-Signature|computeHmac|createHmac.*sha256)' src/ app/ apps/ lib/ libs/ 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_MULTI_TENANT=$(grep -rnE '(tenant_id|tenantId|AsyncLocalStorage.*tenant)' src/ app/ apps/ lib/ libs/ migrations/ prisma/ 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_WS=$(grep -q 'socket.io\|"ws"\|@fastify/websocket\|ws-module' package.json 2>/dev/null && echo yes)
HAS_EVENT_SOURCED=$(grep -rnE '(AggregateRoot|EventStore|DomainEvent.*apply|event-sourced)' src/ app/ 2>/dev/null | head -1 | grep -q . && echo yes)
HAS_FILE_UPLOAD=$(grep -q 'multer\|@fastify/multipart\|busboy\|multipart/form-data' package.json 2>/dev/null && echo yes)
# NOT `HAS_SEARCH=[[ … ]] && echo yes`. That form is not an assignment at all: bash assigns the
# literal `[[` to HAS_SEARCH for the duration of ONE command and then tries to EXECUTE
# `"$HAS_ELASTIC"` and `-n "…"`, so every run of this appendix printed two `command not found`
# errors and the `search` signal could never be `yes`. It shipped that way because gate-19
# Rule 3 screens only for `grep -P`. Fixture: scripts/test-anchor-citations.sh is not the gate
# here — lint-setup-contracts.sh Rule 15 runs `bash -n` over this block.
HAS_SEARCH=$( { [ "$HAS_ELASTIC" = "yes" ] || grep -q 'meilisearch\|typesense\|pinecone\|qdrant\|weaviate' package.json 2>/dev/null; } && echo yes )
HAS_FEATURE_FLAGS=$(grep -q 'launchdarkly\|"growthbook"\|"unleash"\|"flipt"\|ldclient' package.json 2>/dev/null && echo yes)
HAS_NOTIFICATIONS=$(grep -q 'sendgrid\|nodemailer\|firebase\|twilio\|vonage\|mailgun' package.json pyproject.toml 2>/dev/null && echo yes)
HAS_JOBS=$(grep -q 'bullmq\|"bull"\|celery\|sidekiq\|"rq"\|@nestjs/bull' package.json pyproject.toml Gemfile 2>/dev/null && echo yes)
HAS_COMPLIANCE=$(grep -rnE '(GDPR|HIPAA|SOC2|PCI-DSS|data.retention)' ai/ .claude/ 2>/dev/null | head -1 | grep -q . && echo yes)

# Analytics / warehouse signals — emit the `data-pipeline`, `analytics`, and `reporting`
# signal names listed in templates/packs/_trigger-vocabulary.md. Without these three lines
# those names are triggers no extractor produces (dead code, per that file's hard rules).
HAS_DATA_PIPELINE=$([ -f dbt_project.yml ] || [ -d dags ] || [ -d models/staging ] \
  || grep -qE 'apache-airflow|"?dagster"?|dbt-core|prefect|"?luigi"?|pyspark|apache-beam|sqlmesh|"?meltano"?' \
     package.json pyproject.toml requirements.txt 2>/dev/null && echo yes)
HAS_ANALYTICS=$(grep -qE '@segment/|"?analytics-node"?|amplitude|mixpanel|posthog|@snowplow/|react-ga|gtag' \
  package.json pyproject.toml requirements.txt 2>/dev/null && echo yes)
HAS_REPORTING=$(grep -rnE '(exceljs|"xlsx"|papaparse|csv-writer|openpyxl|pandas\.to_csv|StreamingHttpResponse)' \
  src/ app/ apps/ lib/ libs/ 2>/dev/null | head -1 | grep -q . && echo yes)
```

Print results in the plan as:

```
== STACK DETECTION ==
  backend:       NestJS ✓  Fastify ✓
  frontend:      (none)
  mobile:        (none)
  database:      MySQL ✓  Redis ✓  Postgres ✗  Mongo ✗
  orm:           TypeORM ✓  Prisma ✓
  infra:         Docker ✓  K8s ✓
  ci:            GitHub Actions ✓

== DOMAIN SIGNALS ==
  ai: ✓ (OpenAI)  multi-tenant: ✓  webhook: ✓  real-time: ✓
  file-upload: ✓  search: ✓  notifications: ✓  background-jobs: ✓
  payment: ✗  event-sourced: ✗  feature-flags: ✗  compliance: ✗

== FRONTEND TOOLCHAIN ==
  framework:     Vue 3 ✓
  build tool:    Vite ✓                    (build_tool_detected)
  state:         Pinia ✓  (redux/zustand on a React app)   (state_lib_detected)
  router:        vue-router ✓              (router_detected)
  ui / css:      PrimeVue ✓  Bootstrap ✓  (MUI/shadcn on React)  (css_framework_detected)
  i18n:          vue-i18n ✓                (i18n_lib_detected)
  rtl:           ✓ ar locale + dir="rtl"   (rtl_locale_detected)
```

**Every `*_detected` name printed above is a trigger some `_topics.md` consumes.** Print the
line even when the answer is ✗ — a silently absent signal is indistinguishable from a signal
whose extractor is dead, and that is exactly how `i18n_lib_detected` and `rtl_locale_detected`
shipped for as long as they did. `scripts/lint-setup-contracts.sh § rule 4` fails the build if
a name declared in `templates/packs/_trigger-vocabulary.md` has no emitter here.

---

## Appendix B — Relevance filter

Tracks / references / patterns / domains apply ONLY when their trigger matches.

**Relationship to Phase 2.6:** The "Always" column below is the **catalog upper bound** — which tracks *can* apply when relevant. Phase 2.6 still **profile-filters** tracks: a track marked NOT-APPLICABLE in the profile (e.g. `frontend` for an API-only repo) is skipped entirely and does not count as a coverage gap. "Always" does not override NOT-APPLICABLE.

### Track relevance

| Track | Apply when |
|---|---|
| `code-quality`, `documentation`, `testing`, `security`, `business` | Always *(when the track is not profile-filtered to n/a — see note above)* |
| `performance` | Rules always; agents on demand |
| `observability` | Always for any service |
| `backend` | Backend code detected |
| `frontend`, `ui-ux` | Frontend code detected |
| `database` | ORM / migrations / schema detected |
| `distributed-systems` | ≥2 services, events, queues, SaaS at scale, or declared in architecture |
| `infrastructure` | Dockerfile / k8s / Terraform / Helm detected OR deployment declared |
| `devops` | CI config detected OR deploy mentioned |
| `mobile` | Mobile stack detected |

**If a track is NOT relevant, NONE of its files apply** — not agents, not commands, not rules, not patterns, not references.

### Reference relevance

Per-framework reference applies ONLY if that specific framework is detected:
- `nestjs.md` iff `@nestjs/core` in `package.json`.
- `postgres.md` iff `pg` / `psycopg` / typeorm-postgres / prisma-postgres detected.
- `kubernetes.md` iff K8s manifests OR Helm chart detected.
- Same rule for every framework. Otherwise SKIPPED.

### Pattern relevance

Patterns inherit their track's relevance. Frontend patterns (design-systems, theming, rtl, motion, rendering-strategy, ssr-safety, i18n-frontend, forms) apply ONLY if `frontend` track applies.

### Domain relevance

Domain tooling applies ONLY if its signal is detected:
- `ai` — Anthropic / OpenAI / Gemini SDK OR LLM usage in code.
- `webhook` — signature verification / HMAC handling detected.
- `multi-tenant` — tenant_id columns / AsyncLocalStorage tenant context.
- `payment` — Stripe / PayPal / Paddle SDK detected.
- `real-time` — WebSocket / SSE / socket.io detected.
- `event-sourced` — AggregateRoot / EventStore / event-sourced patterns in code.
- `file-upload` — multer / multipart handlers detected.
- `search` — Elastic / Meilisearch / Typesense / vector search SDK.
- `feature-flags` — LaunchDarkly / GrowthBook / Unleash / Flipt.
- `notifications` — SendGrid / Nodemailer / Firebase / Twilio / Mailgun.
- `background-jobs` — BullMQ / Celery / Sidekiq / RQ.
- `compliance` — GDPR / HIPAA / SOC2 / PCI-DSS declared in ADRs / docs.

Undetected signal → domain files NOT applied (even if useful). User can override with `--include=<signal>`.

### Report filtered-out

In the plan, include the "Filtered out" section so the user can confirm decisions:

```
FILTERED OUT (not relevant to this codebase):
  - frontend, ui-ux, mobile tracks (no frontend / mobile code)
  - infrastructure track (no Dockerfile / k8s / terraform)
  - References: angular, react, vue, nuxt, next, svelte, postgres, mongodb,
    django, laravel, rails, spring-boot, dotnet, phoenix, express, fastapi, go
    docker-swarm, terraform (no detection evidence)
  - Domain: payment, event-sourced, feature-flags (no detection evidence)
```

---

## Appendix C — Merge decision matrix

Applied per-file in Phase 4. Line-count + content depth determine the decision.

### Exact name overlap (same file in both)

| Ratio (ours/theirs) | Decision |
|---|---|
| ≥ 2.0× | **REPLACE** with ours |
| 1.3× – 2.0× | **REPLACE** + inject their project-specific "Reference paths" section |
| 0.7× – 1.3× | **MERGE** — real content merge required |
| 0.5× – 0.7× | **KEEP THEIRS** + add ours as side-doc with different filename |
| < 0.5× | **KEEP THEIRS** — ours adds nothing |

### Purpose overlap (different name, same job)

Specialized agent with framework name in description wins:

| Our generic | Skip if exists |
|---|---|
| `api-architect`, `api-reviewer` | `nestjs-architect`, `api-designer`, `<stack>-architect` |
| `schema-architect`, `schema-reviewer`, `query-optimizer` | `database-reviewer`, `migration-reviewer`, `<engine>-specialist` |
| `ui-reviewer` | `<framework>-reviewer` / `vue-reviewer` / `angular-reviewer` |
| `infra-architect` | `k8s-architect` / `aws-architect` / `gcp-architect` |

Detection: scan existing agents' `description:` field. If it names a specific framework/tool + same responsibility → specialized.

### Rules

Project-idiom rules (naming specific base class paths or custom names) are NEVER overwritten. Apply our generic principles as NEW files with distinct names.

Example: their `base-classes.md` (V1 backend-framework-specific) stays; ours `backend-principles.md` adds alongside.

### Orchestration commands

| Ratio (ours/theirs) | Decision |
|---|---|
| ≥ 2.0× | **REPLACE** — orchestration benefits from depth |
| Other | **MERGE** — preserve their dispatch targets, take our phase structure |

### Pattern files

- 200+ lines of project-specific content → **KEEP THEIRS**; add ours with different name.
- Overlap < 100 lines on both sides → **MERGE**.

### Skills format

```bash
# Detect existing format
ls -d .claude/skills/*/ 2>/dev/null | head -1 && FORMAT=folder
ls .claude/skills/*.md 2>/dev/null | head -1 && FORMAT=file
```

- Folder-style + same-name file-style = clash → **SKIP ours**.
- All non-clashing skills apply normally.

### Reference-path injection (post-apply)

For every generic agent that got applied in ENHANCE mode, prepend a Reference-paths block. **Values come from the current codebase's extraction at `.claude/_extracted-codebase.md` — never copied from another project.** Shape:

```markdown
## Reference paths (from codebase profile)
- <DetectedBaseClass>: <detected/path/to/file>  (<n> extenders)
- <DetectedBaseClass>: <detected/path>  (<n> extenders)
- ... (one line per real base from this codebase's extraction; OMIT if no inheritance bases were found)
```

So generic agents cite this codebase's real paths, not hypothetical class names. If a project doesn't use inheritance bases (functional / module-style), this block is empty or omitted — don't manufacture entries.

---

## Appendix D — Codebase profile shape

Written to `.claude/codebase-profile.md` in Phase 2. **All values are placeholders — every field is filled from this codebase's extraction (`.claude/_extracted-codebase.md`). The shape is universal; the values are project-specific.**

Format:

```markdown
# Codebase Profile
Generated: YYYY-MM-DD
Source: scan of <path> (<N> files, <LOC>)

## Architecture
Layering: <detected style — e.g., Clean / Hexagonal / MVC / flat / package-by-feature / package-by-layer>
Layer folders: <detected names — actual folder names used in this codebase>
Dependency direction: <verified from import-graph sample>

## Base classes (with paths + extender count — list ONLY base classes with ≥3 extenders found by Phase 2.5; OMIT this section if the project doesn't use inheritance bases)
| Base | Path | Extenders |
| <DetectedBase> | <detected/path> | <n> |
| <DetectedBase> | <detected/path> | <n> |
| ...

## Naming
Files: <detected case>  |  Classes: <detected case>  |  Methods: <detected case>  |  DB: <detected case or n/a>
Suffixes: <detected from extraction — list ONLY suffixes the codebase actually uses>

## Aliases
<detected from tsconfig / pyproject / module manifest — list real aliases or omit if none>

## Testing
Framework: <detected — Jest / Vitest / Pytest / Go test / RSpec / JUnit / etc.>
File pattern: <detected suffix + colocation>
Mock style: <detected — fixture / spy / fake / contract / mocking lib name>

## Data access
Base / pattern: <detected — base class name / functional pattern / repository style>
Automatic behaviors: <detected — e.g., tenant filter, soft-delete filter, audit fields, or "none">
Migrations: <detected tool + path, or "n/a">

## Error handling
Root: <detected error base / sentinel / panic style>
Mapper: <detected — exception filter / error middleware / etc.>

## Observability
Logger: <detected lib + structured fields, or "ad-hoc — no central logger">
Metrics: <detected lib, or "none">
Tracing: <detected, or "(none — flagged gap)">

## Auth
Scheme: <detected — JWT / session / OAuth / API key / none>
Guards / middleware: <detected names + paths>
Permission model: <RBAC / ABAC / scope-based / none>

## i18n
Library: <detected, or "none">
Locales: <detected>

## Domain glossary
Entities: <top list from extraction>
Signals detected: <list — multi-tenant / payment / ai / webhook / search / queue / realtime / mobile / etc., based on Phase 2 detection>

## Anti-patterns present (acknowledge, don't fix)
<noisy-debug primitive — e.g., console.log / print / fmt.Println>: <count>
<broad type — e.g., any / interface{} / dict>: <count>
swallowed errors: <count>

## Phase
Declared: <from ai/status.md>
Evidence: <modules suggesting phase>
Consistency: ✓ / flagged
```

---

## Appendix E — Learnings encoded (where each rule comes from)

Traceable so a future maintainer knows WHY each rule exists.

### From mature backend V1 reference projects (NestJS · Django · Rails · Laravel · …)
- Reference-path specificity → injection rule in Appendix C.
- Specialized > generic for framework agents → matrix in Appendix C.
- V1-idiom rules preserved → merge rules in Appendix C.
- Pattern files >200 lines preserved → merge rules in Appendix C.

### From sibling-repo workspaces (v2 rewrite, portals, storefront)
- `ai/core/` + `ai/references/` + `ai/dynamic/` + `ai/runtime/` + `ai/audits/` subfolders → baseline `ai/` shape.
- Session-log Stop hook → baseline hook.
- Variant packs: `frontend-vue-options`, `frontend-vue-composition`, `nuxt-store`, `hexagonal-nestjs`, `multi-theme`, `ssr`.
- Specialized frontend agents: theme-specialist, data-flow-auditor, api-contract-sentry.
- Workspace orchestration: project-dispatcher, contract-diff, PROJECTS.md.

### From external agent libraries (awesome-claude-code-subagents, agents-main)
- Model assignment (`opus` / `sonnet` / `haiku` / `inherit`) in agent frontmatter.
- Novel agents: tdd-orchestrator, workflow-orchestrator, event-sourcing-architect, database-optimizer, api-documenter, websocket-engineer, monorepo-architect, kubernetes-architect, legacy-modernizer, sre-engineer, deployment-engineer, incident-responder, error-detective, dependency-auditor, theme-specialist, data-flow-auditor, api-contract-sentry.
- Plugin-style pack structure (`.claude-plugin/plugin.json`) — documented for future migration.
- Cataloged agents for generate-on-signal: mlops-engineer, ml-pipeline-architect, model-serving-specialist, gitops-architect, progressive-delivery-engineer, electron-pro, tauri-specialist, mcp-developer, and 12+ more.


---

## Appendix F — Glossary

Single canonical definition per term. When this command (or generated content) uses any of these words, this is what they mean.

### Architectural concepts

- **Track** — a discipline-shaped pack catalog (backend, frontend, security, etc.). The authoritative track list lives in `~/.claude/templates/packs/_registry.md`; that file is the single source of truth used by Phase 2 detection + the Phase 4.0 preflight + Appendix B Relevance Filter. Each track contains agents, commands, skills, rules, ai-patterns, optional framework `references/`, and `_version.json`.
- **Pack** — physical layout of a track on disk. `~/.claude/templates/packs/<track>/{agents,commands,skills,rules,ai-patterns,references}/`.
- **Variant pack** — stack-specialized fork of a track (e.g., `frontend-vue-options` vs `frontend-vue-composition`). Applied when a specific stack is detected.
- **Technical signal** (NOT just "signal") — a cross-cutting tech concern detected from code (multi-tenant, payment, AI, webhook). The authoritative list lives in `~/.claude/templates/domains/_registry.md`. Lives at `~/.claude/templates/domains/<signal>/`. Triggers Phase 4.4 tooling generation.
- **Business domain** (NOT just "domain") — what KIND of product the project is (ecommerce, lms, fintech). The authoritative list lives in `~/.claude/templates/business-domains/_registry.md`. Lives at `~/.claude/templates/business-domains/<domain>/`. Drives Phase 4.4b content (entities, flows, compliance).
- **Tool adapter** — per-AI-tool config generator. The authoritative list of supported adapters + their capability matrix lives in `~/.claude/templates/tool-adapters/_registry.md`. Phase 3.2 auto-detection + `--tools` resolution both consult that file. Each adapter folder lives at `~/.claude/templates/tool-adapters/<key>/` with `adapter.md`, `_version.json`, and an optional `samples/` directory.
- **Driver** — synonym for an active tool adapter — the AI tool currently consuming the project's knowledge base. A project can have multiple drivers configured simultaneously.

### Process concepts

- **Profile** (noun) — `.claude/codebase-profile.md` — the fact-sheet output of Phase 2 detection. Lists detected stack, base classes, naming, signals, business-domain, intent, etc.
- **Profile** (verb) — Phase 2 itself: the act of running detection commands + walking modules to produce the profile.
- **Pre-flight** — the auto-injected reading list at the top of every agent's prompt (`codebase-profile`, `conventions`, `business-domain`, `project-goals`, `feedback-learned`, mirror existing module).
- **Verification** — the auto-injected `## Verification` section at the bottom of every agent's prompt (lint + typecheck + test commands the agent must run before reporting done).
- **Persistence pyramid** — the layered model in Phase 6: formal `ai/decisions/` at top → raw `ai/dynamic/` at bottom; evidence flows UPWARD as it accumulates.
- **Promotion** — graduating an entry from a `dynamic/` file (raw observation) to a formal file (ADR, pattern, rule, conventions update). Driven by `knowledge-curator` agent + slash commands.
- **Drift** — divergence between documented expectations (rules, conventions, ADRs) and actual code state. Tracked in `ai/dynamic/drift-log.md`.

### Mode + scope

- **CREATE mode** — greenfield project, no existing source/`.claude/`/`ai/`. Generates from prompt + sensible defaults.
- **ENHANCE-retrofit** — source exists but `.claude/` or `ai/` missing. Generates from codebase profile.
- **ENHANCE-extend** — source + `.claude/` + `ai/` all exist. Generates additively (never overwrites user content).
- **Workspace mode** — repo contains multiple sub-projects (`pnpm-workspace.yaml`, etc.). Each sub-project gets its own full setup; workspace root gets thin orchestration only.

### Knowledge layer concepts

- **Convention** — a project-specific style + naming + structural rule, auto-detected from real code into `ai/conventions.md`. Distinct from generic pack rules.
- **ADR (Architecture Decision Record)** — formal, append-only decision record in `ai/decisions/<NNNN>-<slug>.md`. Promoted from `ai/dynamic/decisions-pending.md` after 2 weeks + ≥2 real code changes (see Phase 6 promotion table).
- **Pattern** — worked example of HOW to do something in this codebase. Lives in `ai/patterns/`. Promoted from `ai/dynamic/learned-patterns.md` after 3+ occurrences.
- **Runbook** — operational step-by-step guide (deployment, incident-response, dependency-upgrade). Lives in `ai/runbooks/`.
- **Rule** — coding convention or constraint enforced at PR/edit time. Lives in `.claude/rules/<concern>.md`.
- **Skill** — scripted procedure with optional shell steps. Lives in `.claude/skills/<name>/SKILL.md`. Auto-loadable via path/keyword match. (As of Apr 2026, Anthropic positions skills as the primary form for new project artifacts; commands remain for backward compatibility.)
- **Command** — slash-command prompt template. Lives in `.claude/commands/<name>.md`. User invokes via `/<name>`.
- **Agent** — specialized persona with its own system prompt + tool constraints + model. Lives in `.claude/agents/<name>.md`. Claude Code auto-dispatches; other tools require manual invocation.
- **Hook** — lifecycle shell script (PreToolUse, PostToolUse, SessionStart, Stop, plus git-hook variants for Phase 6 learning loop). Lives in `.claude/hooks/`.

### Persistence files (`ai/`)

| File | Purpose |
|---|---|
| `ai/status.md` | current state, in-flight work, recent changes |
| `ai/business-domain.md` | what kind of product (top-level) |
| `ai/project-goals.md` | mission, KPIs, anti-goals, personas summary |
| `ai/conventions.md` | auto-detected style + naming (refresh via `/refresh-knowledge`) |
| `ai/architecture.md` | layer + component overview |
| `ai/core/` | glossary, entities, invariants, stakeholders |
| `ai/patterns/` | worked examples (promoted from learned-patterns.md) |
| `ai/decisions/` | formal ADRs (promoted from decisions-pending.md) |
| `ai/runbooks/` | operational guides |
| `ai/runtime/` | gotchas, env quirks, dep traps |
| `ai/references/` | external pointers (models, tool-parity, siblings) |
| `ai/audits/` | dated audit artifacts (reactive) |
| `ai/dynamic/` | high-churn working state (source of promotions) |

### Confidence + uncertainty markers

Used in plan output + reports:

- `[CONFIDENT]` — 3+ converging signals; no ambiguity.
- `[INFERRED]` — 1-2 signals or single-source classification.
- `[UNKNOWN — assumed default]` — no signal; default applied; surface in plan to ASK.
- `[CONFLICT]` — signals disagree; surface in plan to ASK.
- `_TBD — populate as code is written_` — placeholder for CREATE-mode greenfield where a fact isn't yet knowable.

### When in doubt

If a term used in this command isn't in this glossary, that's a documentation bug — file it.
