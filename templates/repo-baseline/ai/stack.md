# Stack

The technology inventory for this project. Auto-populated at `/setup-project` from manifest detection (`package.json`, `pyproject.toml`, `Cargo.toml`, `composer.json`, `go.mod`, `Gemfile`, …) — every value below traces to a real manifest file.

> **No guessing.** If a row says "<e.g., …>" with no actual value, the manifest didn't have the signal. Don't fill it in from memory of similar projects.

Last updated: <YYYY-MM-DD>

---

## Runtime / Language

- **Language**: <e.g., TypeScript 5.4 / Python 3.12 / Go 1.22 / Rust 1.78>
- **Runtime**: <Node 20 / Bun 1.x / Deno / CPython / PyPy / GraalVM / native>
- **Type system**: <strict / loose / dynamic — from `tsconfig.json` / `mypy.ini` / equivalent>

## Framework(s)

- **Primary**: <NestJS 11 / Django 5 / Rails 7 / Spring Boot 3 / FastAPI / Nuxt 3 / Next 14 / …>
- **Auxiliary**: <BullMQ for queues / OpenTelemetry for tracing / etc.>

## Package manager

- **Tool**: <bun / pnpm / npm / yarn / uv / pip+poetry / cargo / go / composer / bundler>
- **Lockfile**: `<bun.lockb / pnpm-lock.yaml / package-lock.json / yarn.lock / Cargo.lock / poetry.lock>`
- **Workspaces**: <single / monorepo (workspace tool: pnpm-workspaces / nx / turborepo / lerna / cargo-workspaces / go workspaces)>

## Database(s)

- **Primary**: <PostgreSQL 16 / MySQL 8 / SQLite / MongoDB / Redis-as-DB / DynamoDB / …>
- **Migration tool**: <Prisma migrate / TypeORM migrations / Alembic / Rails migrations / Liquibase / Flyway>
- **ORM / data access**: <Prisma / TypeORM / Sequelize / SQLAlchemy / ActiveRecord / GORM / Eloquent / raw SQL>
- **Read replicas / sharding**: <none / configured at <ADR>>

## Cache / queue / search

- **Cache**: <Redis / Memcached / in-process LRU / none>
- **Queue**: <BullMQ / RabbitMQ / Kafka / SQS / Celery+Redis / sidekiq / none>
- **Search**: <Elasticsearch / Meilisearch / Algolia / Postgres FTS / none>

## Key libraries (load-bearing only)

Libraries the codebase RELIES ON for cross-cutting behavior — not every dep, just the ones a new contributor needs to know about.

| Library | Version | Purpose | Cross-cuts |
|---|---|---|---|
| <name> | <semver> | <one line> | <auth / logging / multi-tenant / i18n / …> |

## Scripts (the canonical command set)

The scripts every developer runs. Auto-detected from `package.json` `scripts:` / `Makefile` / `pyproject.toml` `[tool.poetry.scripts]` / etc.

| Script | What it does | When run |
|---|---|---|
| `<pm> run dev` | Start dev server (auto-reload) | local development |
| `<pm> run test` | Run unit + integration tests | local + CI |
| `<pm> run test:e2e` | E2E suite (when present) | CI / pre-release |
| `<pm> run lint` | Lint (formatter + linter) | pre-commit + CI |
| `<pm> run typecheck` | Type check (TS / mypy / etc.) | pre-commit + CI |
| `<pm> run build` | Build for production | CI / pre-deploy |

`<pm>` substitutes for the detected package manager (`bun` / `pnpm` / `npm` / `make` / etc.). The actual scripts are written into `.claude/settings.json § permissions.allow` so the agent doesn't see permission prompts on day-one usage.

## Env files

- `.env` — local development (gitignored)
- `.env.example` — committed template; every variable documented
- `.env.test` — test runner overrides (gitignored)
- `.env.production` — NEVER committed; lives in deploy secret store

Each `.env*` file's variables are documented in `ai/runtime/dependencies-with-traps.md` (which env vars are required vs optional, default values, what breaks when missing).

## Build / deploy artifacts

- **Container**: <Dockerfile / Buildpack / serverless / native binary>
- **Deploy target**: <K8s / ECS / Cloud Run / Vercel / Netlify / Render / bare-metal>
- **Pipeline**: <GitHub Actions / CircleCI / GitLab CI / Jenkins>
- **Pipeline file**: `<.github/workflows/main.yml / .gitlab-ci.yml / Jenkinsfile>`

## Detection signals (what `/setup-project` saw)

This section is auto-written by Phase 2 detection. The agent uses it to decide which packs/tracks apply.

- **Frontend signal**: <yes — Vue/React/Angular/… | no>
- **Backend signal**: <yes — NestJS/Django/Rails/… | no>
- **Multi-tenant signal**: <yes — tenant-context middleware | yes — row-level | no>
- **Webhook signal**: <yes — `/webhooks/*` routes + signature verifier | no>
- **Payment signal**: <yes — `stripe` / `square` / `adyen` in deps | no>
- **AI signal**: <yes — `openai` / `anthropic` / `langchain` in deps | no>
- **Multi-region signal**: <yes — region-aware DB / CDN / queues | no>
- **Workspace shape**: <single | monorepo | workspace>

## Update cadence

| Trigger | Update which sections |
|---|---|
| Major version bump (e.g., Node 20 → 22) | Runtime / Language |
| New framework adopted | Framework(s) |
| New DB / cache / queue / search added | Database(s) / Cache-queue-search |
| Adding a load-bearing library | Key libraries |
| Adding a new script | Scripts |
| Adding a new env var | Env files + `ai/runtime/dependencies-with-traps.md` |
| Pipeline migration | Build / deploy |

`/setup-project --refresh` re-runs detection and overwrites the auto-detected sections. Hand-edited rows in **Key libraries** are preserved across refresh (managed-section markers).

## See also

- `ai/architecture.md` — how these pieces fit together at runtime
- `ai/runtime/dependencies-with-traps.md` — env vars, version traps, undocumented requirements
- `ai/runtime/environment-quirks.md` — quirks of dev/staging/prod environments
- `.claude/codebase-profile.md` — the deeper extraction this file projects from
- `package.json` / `pyproject.toml` / etc. — the source manifests every value above derives from
