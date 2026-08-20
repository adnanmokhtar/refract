# Packs registry

Single source of truth for the **tracks** (role-based packs) supported by `/setup-project`. Phase 2 (track detection), Phase 4.0 (pack-load preflight), Phase 4.2 (deterministic copy), Appendix B (Relevance Filter), and the Glossary all consult this file rather than hard-coded lists.

## What a track is

A **track** is a discipline-shaped catalog of artifacts (agents, commands, skills, rules, ai-patterns) for one role or concern. Tracks are not the same as **technical signals** (`templates/domains/`) or **business domains** (`templates/business-domains/`).

Folder shape and per-pack metadata are documented in `templates/packs/README.md`.

## Registry

| Key | Always-applied | Detection signals | Summary |
|---|---|---|---|
| `ai-engineering` | — | LLM provider SDKs (Anthropic, OpenAI, Gemini, vLLM/Ollama), embeddings/vector stores (pgvector, Pinecone, Weaviate, Qdrant), prompt/agent/RAG/eval code | Building LLM/AI features well — RAG, evals, prompts, agents, LLM gateway (secured by the security pack's llm-security-reviewer) |
| `algorithms` | — | opt-in via `--include=algorithms`; no detector block and no Phase 2 signal today, so it is never auto-selected — reach for it when hot paths are data-structure-bound (large collections, nested scans, hand-rolled containers) rather than I/O-bound | Algorithm design + complexity analysis — pick the structure for the input scale, derive and prove the bound, catch the asymptotic defects profiling calls "slow" without explaining |
| `align` | — | opt-in via `--include=align`; never auto-included by design — alignment is a deliberate cadence, not a constant. Reach for it once `_extracted-idioms.md` is populated and a routine sweep is wanted | Codebase quality gate — 12 universal detectors against the gold-standard inventory, phased fix loop, 14-check phase-exit gate. Enforces conventions the project ALREADY has; never invents |
| `backend` | — | server frameworks (NestJS, Express, FastAPI, Rails, Spring, Go HTTP, .NET), API code, controllers/services | Server-side application work |
| `business` | — | domain models, billing logic, multi-tenant identity (in addition to a business-domain pack) | Business-logic depth (entities, flows, rules) |
| `code-quality` | always | every project | Linters, formatters, code-review patterns |
| `data-engineering` | — | dbt/SQLMesh/Meltano project files, orchestration DAG directories (`dags/`), warehouse model layouts (`models/staging`, `warehouse/`), Airflow/Dagster/Prefect/Spark/Beam deps | Warehouse + analytics engineering — declared grain, layered transformations, data contracts, trust assertions, safe backfills |
| `database` | — | ORMs (Prisma, TypeORM, Sequelize, ActiveRecord, SQLAlchemy, Drizzle), migration directories | Schema, queries, migrations |
| `devops` | — | Dockerfile, k8s manifests, terraform, CI configs | CI/CD, deployment, infra-as-code |
| `distributed-systems` | — | message buses (Kafka, NATS, RabbitMQ), service mesh, multi-service repos | Service boundaries, resilience |
| `documentation` | always | every project | Docs structure, ADR conventions, runbooks |
| `finops` | — | infrastructure-as-code (`*.tf`, `terraform/`, `pulumi/`, `infra/`, `cdk.json`, `Pulumi.yaml`), infracost config | Cost as a reviewed engineering dimension — unit economics, spend attribution, commitment posture, guardrails, diff-time cost lens |
| `frontend` | — | React, Vue, Angular, Svelte, mobile UI frameworks | Client-side application work |
| `infrastructure` | — | terraform, pulumi, cloudformation, helm | Cloud / on-prem infra patterns |
| `learning` | always | every project | Continuous-learning loop (corrections, decisions-pending, failure catalog) |
| `migration` | — | parallel V1+V2 directories, `legacy/`+`new/` folders, version-suffixed module trees, dual-app workspaces with `-v2`/`-next`/`-new` suffixes, README mentions of V1→V2 / legacy migration | Per-feature V1→V2 port with parity guarantees + migration-time perf uplift |
| `mobile` | — | iOS / Android / React-Native / Flutter / Expo | Mobile-specific patterns + release flow |
| `observability` | — | OpenTelemetry, Datadog, Sentry, Prometheus | Logs, metrics, traces, alerts |
| `performance` | — | bottleneck-shaped tickets, profiling tooling, large datasets | Profiling, optimization patterns |
| `product` | — | product artifacts a team maintains: `ai/product/`, `docs/prd/`, `docs/product/`, `ai/roadmap.md`, `ai/users-and-personas.md`, `ai/project-goals.md`, root `PRD.md`/`ROADMAP.md` | Decide what to build and why — evidence-labelled problem framing, falsifiable requirements, research synthesis, launches that can be judged |
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

**No script cross-checks this table against the folder list today.** `scripts/lint-tool-parity.sh` reads only `templates/tool-adapters/_registry.md` (the adapter matrix); it counts pack *directories* to police the `<N> tracks` strings in `README.md` and `docs/setup-project-cheatsheet.md`, but it never opens this file. `scripts/lint-registry-drift.sh` is planned and not yet implemented.

Until it exists, folder↔row parity is maintained by hand and checked in one line:

```bash
diff <(ls -d templates/packs/*/ | xargs -n1 basename | grep -v '^_') \
     <(grep -oE '^\| `[a-z-]+`' templates/packs/_registry.md | tr -d '| `')
```

Any folder without a row, or any row without a folder, is drift. The reserved non-track namespace `orchestration` (see above) is exempt — it intentionally has no folder and no table row. `scripts/lint-overlay-catalog.sh` enforces exactly this catalog↔disk pattern for the regulatory overlays and is the closest working prior art if anyone picks the planned script up.
