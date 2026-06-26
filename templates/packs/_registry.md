# Packs registry

Single source of truth for the **tracks** (role-based packs) supported by `/setup-project`. Phase 2 (track detection), Phase 4.0 (pack-load preflight), Phase 4.2 (deterministic copy), Appendix B (Relevance Filter), and the Glossary all consult this file rather than hard-coded lists.

## What a track is

A **track** is a discipline-shaped catalog of artifacts (agents, commands, skills, rules, ai-patterns) for one role or concern. Tracks are not the same as **technical signals** (`templates/domains/`) or **business domains** (`templates/business-domains/`).

Folder shape and per-pack metadata are documented in `templates/packs/README.md`.

## Registry

| Key | Always-applied | Detection signals | Summary |
|---|---|---|---|
| `backend` | — | server frameworks (NestJS, Express, FastAPI, Rails, Spring, Go HTTP, .NET), API code, controllers/services | Server-side application work |
| `business` | — | domain models, billing logic, multi-tenant identity (in addition to a business-domain pack) | Business-logic depth (entities, flows, rules) |
| `code-quality` | always | every project | Linters, formatters, code-review patterns |
| `database` | — | ORMs (Prisma, TypeORM, Sequelize, ActiveRecord, SQLAlchemy, Drizzle), migration directories | Schema, queries, migrations |
| `devops` | — | Dockerfile, k8s manifests, terraform, CI configs | CI/CD, deployment, infra-as-code |
| `distributed-systems` | — | message buses (Kafka, NATS, RabbitMQ), service mesh, multi-service repos | Service boundaries, resilience |
| `documentation` | always | every project | Docs structure, ADR conventions, runbooks |
| `frontend` | — | React, Vue, Angular, Svelte, mobile UI frameworks | Client-side application work |
| `infrastructure` | — | terraform, pulumi, cloudformation, helm | Cloud / on-prem infra patterns |
| `learning` | always | every project | Continuous-learning loop (corrections, decisions-pending, failure catalog) |
| `migration` | — | parallel V1+V2 directories, `legacy/`+`new/` folders, version-suffixed module trees, dual-app workspaces with `-v2`/`-next`/`-new` suffixes, README mentions of V1→V2 / legacy migration | Per-feature V1→V2 port with parity guarantees + migration-time perf uplift |
| `mobile` | — | iOS / Android / React-Native / Flutter / Expo | Mobile-specific patterns + release flow |
| `observability` | — | OpenTelemetry, Datadog, Sentry, Prometheus | Logs, metrics, traces, alerts |
| `performance` | — | bottleneck-shaped tickets, profiling tooling, large datasets | Profiling, optimization patterns |
| `security` | always | every project | OWASP-aligned rules, threat-model patterns |
| `testing` | — | test/ folders, vitest/jest/pytest/rspec/junit, e2e tooling | Unit / integration / e2e patterns + factories |
| `ui-ux` | — | design system code, component libraries, Figma exports | Visual + interaction conventions |

**Always-applied** tracks: `code-quality`, `documentation`, `learning`, `security`. They are added to `selected_tracks` even when no signal is detected — they're the base substrate every project benefits from.

## Reserved non-track namespaces

Not every `pack:` frontmatter value names a track. The top-level core commands in `commands/` (`/optimize`, `/align`, `/polish`, `/audit`, `/refactor`, `/roadmap`, `/do`, `/scaffold-project`, `/refine-prompt`, `/task`, `/setup-project-adapters`, `/setup-project-health`, `/unify-surfaces`) carry `pack: orchestration`. This is a **logical grouping label**, not a track:

- It has **no `templates/packs/orchestration/` folder** — these commands ship repo-symlinked from `commands/`, not installed via `/setup-project` tracks.
- It is therefore **not a table row above** and is **excluded from the folder↔row drift check** below (a row would falsely report "row without folder").
- The adapter layer refers to this set as the "Top-level orchestration commands" (`templates/tool-adapters/_registry.md`, `templates/tool-adapters/_orchestration-sync.md`).

Reserved non-track namespace: `orchestration`.

## Maintenance

- **Adding a track**: create `~/.claude/templates/packs/<key>/` per `templates/packs/README.md` (with `_version.json` + `_essentials.md` + `_topics.md` minimum), then add a row above. Phase 4.0 preflight enforces presence.
- **Renaming**: never rename in place. Add the new key, leave the old with `deprecated: true` + `replaced_by: <new-key>` in `_version.json` so Phase 0.2 extract can still read older installs.
- **Removing**: bump `deprecated: true` instead of deleting, so existing installs keep functioning until they refresh.

## Drift detection

`scripts/lint-tool-parity.sh` (and the planned `scripts/lint-registry-drift.sh`) cross-check this file against the actual `~/.claude/templates/packs/*/` folder list. Any folder without a row, or any row without a folder, is reported as drift. The reserved non-track namespace `orchestration` (see above) is exempt — it intentionally has no folder and no table row.
