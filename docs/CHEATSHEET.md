# Commands cheat sheet

> **Generated file — do not edit by hand.** Regenerate with `python3 scripts/gen-cheatsheet.py`.
> The CI gate `gen-cheatsheet.py --check` turns drift red, so this stays in lock-step with the command files —
> add or change a command and re-run the generator. Full prose lives in [`COMMANDS.md`](COMMANDS.md) + [`REFERENCE.md`](REFERENCE.md).

**194 commands** — core 15 · 23 packs (133) · domains 36 · baseline 10. Every field is derived from the command file (H1 + frontmatter); flags exclude not-supported / script / runner tokens.

Columns: **Command** (with its arg signature shown in the example) · **Summary** (first sentence of the command's description) · **Flags** (`—` = none documented) · **Example**.

## Sections

- [Core commands — global, run anywhere](#core-commands--global-run-anywhere) — 15
- [Pack — ai-engineering](#pack--ai-engineering) — 3
- [Pack — algorithms](#pack--algorithms) — 2
- [Pack — align](#pack--align) — 13
- [Pack — backend](#pack--backend) — 9
- [Pack — business](#pack--business) — 5
- [Pack — code-quality](#pack--code-quality) — 6
- [Pack — data-engineering](#pack--data-engineering) — 4
- [Pack — database](#pack--database) — 4
- [Pack — devops](#pack--devops) — 4
- [Pack — distributed-systems](#pack--distributed-systems) — 4
- [Pack — documentation](#pack--documentation) — 3
- [Pack — finops](#pack--finops) — 4
- [Pack — frontend](#pack--frontend) — 7
- [Pack — infrastructure](#pack--infrastructure) — 4
- [Pack — learning](#pack--learning) — 8
- [Pack — migration](#pack--migration) — 20
- [Pack — mobile](#pack--mobile) — 4
- [Pack — observability](#pack--observability) — 4
- [Pack — performance](#pack--performance) — 3
- [Pack — product](#pack--product) — 4
- [Pack — security](#pack--security) — 4
- [Pack — testing](#pack--testing) — 4
- [Pack — ui-ux](#pack--ui-ux) — 10
- [Domain commands — materialized when the domain is detected](#domain-commands--materialized-when-the-domain-is-detected) — 36
- [Baseline — universal infra (repo + workspace)](#baseline--universal-infra-repo--workspace) — 10

## Core commands — global, run anywhere

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/align` | Enforce conventions the project ALREADY has, project-wide or across several areas. | `--plan`, `--status`, `--resume`, `--reset`, `--refresh`, `--ignore-ledger`, `--re-audit`, `--restart`, `--dry-run`, `--strict`, `--quiet`, `--allow-dirty`, `--max-parallel=<N>`, `--focus=<list>`, `--exclude=<scope>`, `--surface-blockers` | `/align the orders module` |
| `/audit` | Rank what is WRONG with code that already exists, across eight engineering axes at once. | `--target-rps=<N>`, `--target-p95=<ms>`, `--plan-only`, `--assess`, `--target-vitals=<spec>`, `--target-cold-start=<ms>`, `--target-startup=<ms>`, `--target-bundle=<bytes>`, `--focus`, `--status`, `--resume`, `--reset`, `--refresh`, `--re-audit`, `--restart`, `--ignore-ledger`, `--dry-run`, `--strict`, `--quiet`, `--allow-dirty`, `--max-parallel=<N>`, `--exclude=<scope>`, `--surface-blockers`, `--skip-p4` | `/audit --target-rps=50000 --target-p95=120` |
| `/delegate` | Dispatch ONE bounded coding task to a different AI coding CLI, then review its diff and land it. | `--to=<cli>`, `--read-only`, `--gate=<cmd>`, `--model=<id>`, `--session=<id>`, `--plan`, `--files=<globs>`, `--allow-dirty`, `--timeout=<dur>`, `--dry-run`, `--repo` | `/delegate "extract the retry/backoff duplication in src/clients/ into one helper" --to=codex --gate="npm test"` |
| `/do` | Route one natural-language request to the right specialized command, then run it. | — | `/do enhance the sidebar with cleaner padding` |
| `/optimize` | Diagnose architecture first, then sweep code quality and measured performance. | `--plan`, `--status`, `--resume`, `--reset`, `--refresh`, `--ignore-ledger`, `--re-audit`, `--restart`, `--dry-run`, `--strict`, `--quiet`, `--allow-dirty`, `--max-parallel=<N>`, `--focus=<list>`, `--exclude=<scope>`, `--surface-blockers` | `/optimize the orders module` |
| `/polish` | Introduce finish the project does not have yet, on the axis its PROJECT_KIND dictates. | `--plan`, `--direction`, `--status`, `--resume`, `--reset`, `--refresh`, `--ignore-ledger`, `--re-audit`, `--restart`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--focus=<list>`, `--exclude=<scope>`, `--no-iterate`, `--surface-blockers`, `--stack=<override>` | `/polish the orders module` |
| `/refactor` | Apply the closed Fowler verb set to ONE named file, module, or symbol. | `--plan`, `--dry-run`, `--allow-dirty`, `--status`, `--resume`, `--strict`, `--quiet`, `--phase-base=<git-ref>`, `--ledger=<path>` | `/refactor [<scope>]` |
| `/refine-prompt` | Turn a rough idea, one-liner, or ticket into an execution-ready prompt file. | — | `/refine-prompt "<rough idea>"` |
| `/roadmap` | Map what is INTENDED but not yet built, then phase the build order. | `--goal`, `--build`, `--status`, `--refresh`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--exclude=<scope>`, `--no-table-stakes` | `/roadmap the payments domain` |
| `/scaffold-project` | Generate a working codebase from nothing, up to a booting dev server. | `--name=<repo-name>`, `--into=<path>`, `--stack=<key>`, `--no-claude-orchestration`, `--no-prompt`, `--dry-run` | `/scaffold-project "<idea-or-refined-spec-path>"` |
| `/setup-project` | Install or refresh the Claude orchestration layer for a repo. | `--refine`, `--refresh`, `--include`, `--no-adapters`, `--upgrade`, `--health`, `--validate-schemas`, `--diff`, `--max-subagents=<N>` | `/setup-project --upgrade` |
| `/setup-project-adapters` | Re-sync tool adapters so every enabled CLI offers the same surface as Claude Code here. | `--legacy-opencode` | `/setup-project-adapters` |
| `/setup-project-health` | Read-only report on whether this repo's /setup-project artifacts have drifted or gone stale. | — | `/setup-project-health` |
| `/task` | Execute ONE tracker item end to end and write its status back to the source. | `--prompt-only`, `--to=<command>`, `--no-writeback`, `--review-only` | `/task https://trello.com/c/aB12cD34` |
| `/unify-surfaces` | Consolidate every instance of ONE surface type behind ONE canonical shared implementation, app-wide. | `--surfaces=<list>`, `--status`, `--resume`, `--reset`, `--refresh`, `--re-audit`, `--restart`, `--ignore-ledger`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--exclude=<scope>`, `--exclude-consumer=<glob>`, `--surface-blockers`, `--no-iterate`, `--canonical=<category>`, `--keep-ad-hoc=<glob>`, `--validation-library=<name>` | `/unify-surfaces --surfaces=tables,filters` |

## Pack — ai-engineering

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-ai-feature` | Build an LLM feature end-to-end — prompt/gateway wiring + structured output + retrieval (if RAG) +… | — | `/add-ai-feature` |
| `/add-eval-set` | Retrofit a regression-gating eval harness onto an existing LLM feature that has none — pick the… | `--plan` | `/add-eval-set <feature> [--plan]` |
| `/ai-audit` | Read-only audit of an existing LLM/AI surface across six axes — eval coverage, prompt quality… | `--plan-only` | `/ai-audit [<scope>] [--plan-only]` |

## Pack — algorithms

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/analyze-complexity` | Analyze existing code for algorithmic complexity — derive time + space big-O per hot path (worst /… | `--plan`, `--fix`, `--hot=<spec>`, `--include-cold`, `--space` | `/analyze-complexity src/feed/ranker.ts` |
| `/design-algorithm` | Design an algorithm for a problem (or redesign an existing function) — model it, derive the… | `--plan`, `--scale=<spec>`, `--budget=<class>`, `--candidates=<n>`, `--no-tests` | `/design-algorithm "dedup 5M event ids preserving first-seen order"` |

## Pack — align

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/align-fast` | One-shot per-phase alignment runner. | `--max-parallel=<N>`, `--scope=<path>`, `--exclude-tier=<list>`, `--re-audit`, `--dry-run`, `--allow-main`, `--gate-strict` | `/align-fast <N+1>` |
| `/align-final` | Final sweep — confirms every finding in the ledger is fixed and gate-verified across ALL phases. | `--re-audit`, `--re-scan`, `--strict` | `/align-final` |
| `/align-gate` | Phase exit gate. | — | `/align-gate <N>` |
| `/align-park` | Park a hairy alignment finding so it doesn't block the phase gate. | `--blocker=<idiom-missing \| cross-repo \| reviewer \| scope \| cadence \| other>`, `--unpark-after=<date \| event>`, `--no-confirm` | `/align-park <id> [reason]` |
| `/align-phase` | Executes one alignment phase. | `--dry-run`, `--start-from=<row-id>`, `--stop-on-halt`, `--heavy`, `--max-parallel=<N>` | `/align-phase <N>` |
| `/align-plan` | Forces a phased alignment plan from the scan output. | `--phases=<N>`, `--max-findings-per-phase=<N>`, `--strategy=<class\|domain\|mixed>`, `--exclude-class=<list>`, `--exclude-tier=<list>` | `/align-plan` |
| `/align-promote-tier` | Promote (or demote) an align ledger row's tier mid-fix. | `--reason` | `/align-promote-tier <finding-id> <new-tier> [--reason="<text>"]` |
| `/align-recheck` | Independent codebase-quality spot-check + fix. | `--no-confirm`, `--always-confirm`, `--max-matches=<N>`, `--register-ledger`, `--ledger-only`, `--class=<list>`, `--max-parallel=<N>`, `--dry-run`, `--allow-dirty`, `--re-detect-only`, `--rescan-fresh` | `/align-recheck the sidebar` |
| `/align-replan` | Regenerate the phased alignment plan from the current ledger state. | `--re-scan-first`, `--include-drifted`, `--phases=<N>`, `--preserve-verified`, `--include-parked`, `--max-findings-per-phase=<N>`, `--strategy=<class\|domain\|mixed>` | `/align-replan` |
| `/align-rollback` | Roll back an alignment phase. | `--dry-run`, `--cascade`, `--no-confirm` | `/align-rollback <N>` |
| `/align-scan` | Deep codebase quality scan. | `--first-run`, `--scope`, `--class=<list>`, `--exclude-class=<list>`, `--exclude-tier=<list>`, `--max-findings-per-class=<N>`, `--include-archived`, `--since=<commit>`, `--no-stack`, `--max-subagents=<N>` | `/align-scan --first-run` |
| `/align-status` | Read ai/align/ledger.md and report per-finding state, blockers, stalled rows, and aggregate… | `--phase=<N>`, `--class=<list>`, `--stalled`, `--blockers`, `--summary`, `--json` | `/align-status` |
| `/align-unpark` | Reverse /align-park. | — | `/align-unpark <id> [reason]` |

## Pack — backend

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-endpoint` | Add a new endpoint to an EXISTING module. | — | `/add-endpoint` |
| `/add-feature` | Comprehensive orchestration for a new feature. | `--plan` | `/add-feature` |
| `/add-module` | Scaffold a new backend module end-to-end following the project's declared architecture. | `--plan` | `/add-module` |
| `/analyze-module` | Deep module analysis — architecture, performance, security, DB, tests, dead code, in parallel. | — | `/analyze-module <path\|name>` |
| `/endpoint-test` | Hit a dev endpoint with curl and verify status + response shape via the endpoint-tester agent. | — | `/endpoint-test [controller\|method-path]` |
| `/fix-bug` | Comprehensive orchestration for a bug fix. | `--plan` | `/fix-bug` |
| `/log-tail` | Tail structured dev logs filtered by level, correlation id, or module. | — | `/log-tail [filter]` |
| `/refactor` | Backend-targeted refactor — preserves API contracts, error envelopes, DI, and layer boundaries. | — | `/refactor [<scope>]` |
| `/trace-flow` | Trace a request / event / job lifecycle through every layer — controller → service → repo →… | — | `/trace-flow <endpoint>` |

## Pack — business

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/analyze-task` | Turn a rough business idea into structured requirements, user stories, and an implementation spec. | `--resume`, `--decisions` | `/analyze-task "<idea>"` |
| `/audit-business` | Audit a feature from the user perspective — missing cycles, broken flows, gap closures. | — | `/audit-business <feature>` |
| `/expand-task` | Turn a one-line task into a full implementer-ready prompt with context, acceptance criteria, scope… | — | `/expand-task "<brief>"` |
| `/suggest-features` | Analyze the whole product against what a business in its domain should have, and WRITE a file of… | — | `/suggest-features` |
| `/suggest-metrics` | Recommend the business metrics/KPIs a project's dashboard SHOULD show for its domain — detect the… | — | `/suggest-metrics [<scope>]` |

## Pack — code-quality

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/check-health` | Periodic whole-repo health pulse (no diff) — mechanical checks that must go green, then a standing… | — | `/check-health` |
| `/find-module` | Locate a module, feature, or concept across the codebase quickly. | — | `/find-module <name\|concept>` |
| `/pre-commit` | Commit gate on the STAGED index — the project's own lint/typecheck/test on staged scope (halt on… | — | `/pre-commit` |
| `/refactor` | Language-agnostic targeted refactor — behaviour-preserving structure changes using… | — | `/refactor [<scope>]` |
| `/review-changes` | Comprehensive, signal-aware review of a PENDING DIFF, ending in a merge verdict (APPROVE /… | — | `/review-changes` |
| `/simplify` | Reduce entropy in CHANGED code using four closed verbs (remove / inline / dedupe /… | — | `/simplify [path]` |

## Pack — data-engineering

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-data-model` | Author a new warehouse model (staging / intermediate / fact / dimension) in the project's own… | `--layer`, `--grain` | `/add-data-model <model-name> [--layer staging\|intermediate\|mart] [--grain "<one sentence>"]` |
| `/audit-data-model` | Audit the warehouse's analytical model — declared grain, fact/dimension separation, key and SCD… | `--layer` | `/audit-data-model [<scope>] [--layer mart\|intermediate\|staging]` |
| `/audit-data-quality` | Audit and close data-trust gaps — per-model assertion coverage across structural, temporal… | `--write-tests` | `/audit-data-quality [<scope>] [--write-tests]` |
| `/backfill-plan` | Plan a safe backfill or reprocess of a warehouse model — bounded scope, shadow target, cost and… | `--from`, `--to`, `--reason` | `/backfill-plan <model> [--from <date>] [--to <date>] [--reason "<why>"]` |

## Pack — database

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-migration` | Generate a safe, reversible, deploy-compatible DB migration. | — | `/add-migration` |
| `/db-audit` | Full DB audit — indexes, bloat, slow queries, soft-delete and tenant filter leakage. | — | `/db-audit [dev\|staging]` |
| `/migration-review` | Review a migration for safety, lock impact, reversibility, and deploy compatibility. | — | `/migration-review [file\|recent]` |
| `/optimize-query` | Profile and optimize one query (SQL string or endpoint that owns it). | — | `/optimize-query <endpoint\|sql>` |

## Pack — devops

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-ci` | Generate or update a CI workflow for the detected platform and stack. | — | `/add-ci [platform]` |
| `/deploy-stage` | Deploy current branch to staging environment. | `--branch=<name>`, `--commit=<sha>`, `--no-monitor`, `--watch=<duration>`, `--allow-dirty`, `--skip-ci-check` | `/deploy-stage --branch=feature/refund-button` |
| `/dockerize` | Generate a production-ready Dockerfile, .dockerignore, and optional compose for local dev. | — | `/dockerize` |
| `/rollback-deploy` | Roll back the current environment to a previous known-good deploy. | `--to=<version>`, `--env`, `--dry-run` | `/rollback-deploy --env=staging` |

## Pack — distributed-systems

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-event-handler` | Add an event handler. | — | `/add-event-handler` |
| `/add-saga` | Implement a saga (orchestration / choreography) for a multi-step distributed transaction with… | — | `/add-saga` |
| `/audit-distributed-tx` | Audit distributed transactions / sagas / event flows for stuck instances, missing compensations… | — | `/audit-distributed-tx` |
| `/design-system` | Produce a system design — service boundaries, data ownership, consistency, failure modes, ADRs. | — | `/design-system <feature>` |

## Pack — documentation

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-adr` | Write a new ADR in ai/decisions/ with proper numbering and Recent Changes log. | — | `/add-adr [title]` |
| `/add-runbook` | Author an operational runbook (incident response, deploy, rollback, on-call playbook). | `--type=<incident\|deploy\|rollback\|migration\|cutover\|on-call>`, `--related-adr=<NNN>`, `--related-feature=<id>` | `/add-runbook <name> [<description>]` |
| `/doc-refresh` | Comprehensive post-work documentation refresh. | — | `/doc-refresh` |

## Pack — finops

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/audit-cost-attribution` | Audit whether spend can be attributed to an owner — tag and label coverage by resource and by… | `--period` | `/audit-cost-attribution [--period <billing-period>]` |
| `/cost-guardrails` | Install the preventive cost layer — budgets with owners, anomaly detection with a declared… | `--scope` | `/cost-guardrails [--scope <account\|project\|service>]` |
| `/cost-model` | Build or refresh the unit-economics model — the driver tree from a business unit down to billed… | `--refresh` | `/cost-model [<unit>] [--refresh]` |
| `/cost-review` | Review a change for cost regressions before it merges — always-on resources, per-row paid calls… | `--since` | `/cost-review [<scope>] [--since <ref>]` |

## Pack — frontend

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/a11y-audit` | Run accessibility-auditor against current UI changes; ground with axe if installed. | — | `/a11y-audit [path]` |
| `/add-component` | Scaffold a reusable component with typed props, tests, and (optional) Storybook entry. | — | `/add-component <name>` |
| `/add-crud-page` | Scaffold list + create + edit + delete pages for one entity end-to-end. | — | `/add-crud-page <entity>` |
| `/add-feature` | End-to-end frontend feature — pages + components + state + i18n + a11y + tests + docs. | `--plan` | `/add-feature` |
| `/add-page` | Scaffold a page/route with view, store slice, service, types, i18n keys, and tests. | — | `/add-page <route>` |
| `/i18n-audit` | Find hardcoded strings, missing keys, locale parity breaks, and unused keys. | — | `/i18n-audit [locale-dir]` |
| `/refactor` | Frontend-targeted refactor — preserves render output, props contracts, and hydration safety. | — | `/refactor [<scope>]` |

## Pack — infrastructure

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/audit-iam` | Audit IAM (cloud + service) policies for least-privilege violations, dead permissions, overly-broad… | — | `/audit-iam` |
| `/cost-audit` | Cloud cost audit. | — | `/cost-audit` |
| `/k8s-generate` | Generate production-ready k8s manifests (Deployment, Service, Ingress, HPA, PDB, NetworkPolicy). | — | `/k8s-generate <service>` |
| `/provision-tier` | Provision a new environment tier (dev / staging / prod / DR). | — | `/provision-tier` |

## Pack — learning

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/audit-knowledge` | Curator health audit of the ai/ knowledge layer. | `--fix` | `/audit-knowledge --fix` |
| `/detect-drift` | Compares current code against documented conventions in ai/conventions.md + .claude/rules/. | — | `/detect-drift` |
| `/eval` | Score the project's accumulated AI knowledge against saved eval cases — the measurement half of the… | `--seed`, `--case`, `--coverage` | `/eval` |
| `/learn-from-task` | After a task finishes, capture decisions made / patterns followed / patterns introduced / user… | — | `/learn-from-task` |
| `/promote-decision` | Graduate an entry from ai/dynamic/decisions-pending.md into a formal, sequentially-numbered ADR… | — | `/promote-decision <id>` |
| `/promote-pattern` | Graduates an emerging pattern from ai/dynamic/learned-patterns.md to a formal ai/patterns/<name>.md… | — | `/promote-pattern <name>` |
| `/recall` | Search this project's existing ai/ memory — the dynamic sinks, the don't-retry failure catalog… | `--kind`, `--owner`, `--since`, `--limit`, `--format`, `--catalog` | `/recall "cart cache key tenant"` |
| `/refresh-knowledge` | Re-runs Phase 2 codebase profiling, diffs against current ai/conventions.md +… | `--dry-run` | `/refresh-knowledge` |

## Pack — migration

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/compare-v1` | Compare a feature / module / endpoint between V1 and V2. | — | `/compare-v1` |
| `/cross-repo-task` | Track and drive cross-repo blockers in V1↔V2 migration. | `--upstream=<repo>`, `--owner=<name>`, `--contract=<spec>`, `--status=<open\|in-flight\|landed\|abandoned>`, `--stale`, `--evidence=<url>`, `--reason=<text>`, `--severity=<low\|medium\|high\|critical>`, `--upstream-pr=<url>` | `/cross-repo-task drain` |
| `/draft-phase-adrs` | Reads phase-N.md summary + per-feature audits, drafts one ADR per P0 finding + cross-cutting… | `--include-cross-cutting`, `--exclude-features` | `/draft-phase-adrs <N> complete:` |
| `/find-and-fix` | Default V1→V2 port loop. | `--plan`, `--from-plan` | `/find-and-fix <feature>:` |
| `/migrate` | One command V1→V2 port. | `--plan`, `--from-plan`, `--dry-run`, `--allow-dirty`, `--max-parallel=<N>`, `--exclude=<scope>`, `--include-dead`, `--surface-blockers`, `--re-detect-fields`, `--status`, `--refresh`, `--resume`, `--reset`, `--ignore-ledger`, `--re-audit`, `--include-superseded`, `--restart` | `/migrate the orders module` |
| `/migration-deprecate` | Mark a V1 feature as deprecated — it will NOT be ported to V2. | `--adr=<NNNN>`, `--reason=<text>`, `--tenant-impact=<low\|medium\|high>` | `/migration-deprecate <feature-id>` |
| `/migration-fast` | One-shot deep-migration phase runner. | `--feature=<id>`, `--max-features=<N>`, `--max-parallel=<N>`, `--serial`, `--no-gate`, `--strict-clean`, `--re-audit` | `/migration-fast <N> complete:` |
| `/migration-final` | Final sweep — confirms every feature in the ledger is done + parity-passing across ALL phases. | `--re-audit`, `--no-retirement` | `/migration-final` |
| `/migration-gate` | Phase exit gate. | — | `/migration-gate <N>` |
| `/migration-park` | Park a hairy feature so it doesn't block the phase gate. | `--blocker=<type>` | `/migration-park <feature-id>` |
| `/migration-phase` | Executes one migration phase. | `--feature=<id>`, `--audit-only`, `--chain`, `--heavy`, `--stop-on-halt` | `/migration-phase 8 --audit-only` |
| `/migration-plan` | Forces a phased migration plan from the scan output. | `--phases=<N>`, `--max-features-per-phase=<N>` | `/migration-plan` |
| `/migration-promote-tier` | Promote (or demote) a migration ledger row's tier mid-port. | `--reason` | `/migration-promote-tier <feature-id> <new-tier> [--reason="<text>"]` |
| `/migration-recheck` | Independent V1↔V2 spot-check + fix. | `--phase=<N>`, `--no-confirm`, `--always-confirm`, `--max-matches=<N>`, `--ledger-only`, `--max-parallel=<N>`, `--dry-run`, `--allow-dirty`, `--re-detect-only`, `--v1-commit=<sha>`, `--match-on` | `/migration-recheck the sidebar` |
| `/migration-replan` | Regenerate the phased migration plan from the current ledger state. | `--re-scan-first`, `--include-drifted`, `--phases=<N>`, `--preserve-passed` | `/migration-replan` |
| `/migration-rollback` | Roll back a migration phase. | `--keep-audits`, `--dry-run` | `/migration-rollback <N>` |
| `/migration-scan` | Deep V1↔V2 comparison. | `--scope`, `--include-deferred`, `--since=<commit>`, `--include-deprecated=<re-scan\|skip>`, `--include-dead`, `--external-consumer=<feature-list>`, `--in-development=<feature-list>`, `--workspace`, `--caller-evidence=<path:line>` | `/migration-scan` |
| `/migration-status` | Read ai/migration/ledger.md and report per-feature state, blockers, stalled rows, and aggregate… | — | `/migration-status` |
| `/migration-unpark` | Reverse /migration-park. | — | `/migration-unpark <feature-id>` |
| `/port-feature` | Per-feature V1→V2 port orchestrator. | `--heavy`, `--simple`, `--no-prompt`, `--resume`, `--advance`, `--depend-on-v1`, `--overwrite-v2`, `--merge-existing`, `--override-paths`, `--unattended`, `--plan`, `--from-plan` | `/port-feature` |

## Pack — mobile

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-feature` | End-to-end mobile feature — multi-screen flow + state + offline + deep-link + native bridge if… | `--plan` | `/add-feature` |
| `/add-screen` | Add a new screen — full chain — route + screen component + navigation wiring + state + i18n + a11y… | — | `/add-screen` |
| `/optimize-bundle` | Mobile bundle-size + cold-start optimization. | — | `/optimize-bundle` |
| `/refactor` | Mobile-targeted refactor — preserves navigation contracts, platform lifecycle, and bundle budgets. | — | `/refactor [<scope>]` |

## Pack — observability

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-metrics` | Add metrics (counters / gauges / histograms) to a service. | — | `/add-metrics` |
| `/add-telemetry` | Wire structured logs, metrics, and traces into a feature; create alert + runbook stubs. | — | `/add-telemetry <feature>` |
| `/add-tracing` | Add distributed tracing to a service / endpoint / job. | — | `/add-tracing` |
| `/alert-design` | Design alerts for a service. | — | `/alert-design` |

## Pack — performance

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/bundle-perf` | Web bundle + page-load performance audit. | `--plan` | `/bundle-perf` |
| `/perf-audit` | Performance pass — performance-optimizer single dispatch, ranked by impact. | `--plan-only` | `/perf-audit [path\|endpoint]` |
| `/profile-perf` | Profile a slow endpoint / page / flow. | `--plan` | `/profile-perf` |

## Pack — product

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/audit-requirements` | Audit a spec, ticket, or set of acceptance criteria for the defects that survive into code… | — | `/audit-requirements [<spec \| ticket \| path>]` |
| `/define-success` | Define what success and damage look like before a change ships — the success metric with a baseline… | — | `/define-success [<change or feature>]` |
| `/frame-problem` | Produce the problem brief before anyone designs a solution — who has it, what evidence says so… | — | `/frame-problem [<problem or feature request>]` |
| `/synthesize-research` | Turn raw research material — interview notes, support tickets, session recordings, sales notes… | — | `/synthesize-research [<corpus or path>]` |

## Pack — security

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/dependency-vuln-check` | Audit dependencies for known CVEs + abandoned maintainers + license-incompatible licenses +… | — | `/dependency-vuln-check` |
| `/secret-scan` | Scan repo + commit history for leaked secrets. | — | `/secret-scan` |
| `/security-audit` | Security audit — OWASP pass via security-auditor, plus auth + tenant reviews if relevant. | — | `/security-audit [base-branch]` |
| `/threat-model` | Run a structured threat-model session against a feature / system. | — | `/threat-model` |

## Pack — testing

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-test` | Add tests for a target file or feature, mirroring the repo's test framework and style. | `--review` | `/add-test [target]` |
| `/flaky-test-hunt` | Expose flaky tests by re-running the suite N times (N chosen for the flake rate you need to detect… | — | `/flaky-test-hunt [pattern]` |
| `/run-tests` | Run the project's test suite (or a scoped subset) and surface results. | `--feature`, `--since`, `--all`, `--coverage`, `--watch`, `--bail`, `--update-snapshots`, `--shard=<i>` | `/run-tests <modules-root>/orders/` |
| `/tdd` | Drive a feature test-first via the tdd-orchestrator — strict RED→GREEN→REFACTOR, one behavior per… | — | `/tdd [feature]` |

## Pack — ui-ux

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/add-theme-variant` | One command to ADD a new theme variant to a multi-theme app — creates a NEW theme slot only (never… | `--plan`, `--name`, `--reimagine`, `--skin` | `/add-theme-variant dark` |
| `/art-direct` | One command to DESIGN and BUILD a product / surface / flow's visual direction. | `--plan`, `--evolve`, `--reimagine`, `--yes`, `--direction`, `--surfaces=<n>`, `--render` | `/art-direct the dashboard` |
| `/clone-design` | One command to CLONE an external design reference (a live URL or a screenshot) into a… | `--plan`, `--pages=<a,b,c>`, `--sections-only`, `--fidelity=<0-100>`, `--max-refine=<n>`, `--adopt=<tokens \| pages \| project>`, `--all-routes` | `/clone-design https://shop.example.com/` |
| `/design-review` | Review UI changes for UX, design system compliance, and accessibility in parallel. | — | `/design-review [path\|screenshot]` |
| `/enhance-ui` | Orchestrator for UI/UX enhancement. | `--plan`, `--direction`, `--scope`, `--dry-detect`, `--auto-extract`, `--skip-cleanup`, `--skip-iterate`, `--re-detect-only` | `/enhance-ui the sidebar — complete` |
| `/grab-site` | FAITHFULLY MIRROR a live website into a folder of static HTML/CSS that looks like the ORIGINAL… | `--plan`, `--pages`, `--max-assets=<N>` | `/grab-site https://shop.example.com/` |
| `/redesign` | One command full UI/UX redesign of a page / screen / flow — rethinks layout + UX from scratch (NOT… | `--plan`, `--direction`, `--yes`, `--max-refine=<n>` | `/redesign <description-or-path> [<more>...]` |
| `/ui-crawl` | Automated cross-route UI crawler. | `--smoke`, `--filter=<substr>`, `--full-matrix`, `--skip-interactions`, `--refresh-inventory`, `--workers`, `--no-dark` | `/ui-crawl --smoke` |
| `/ui-crawl-fix` | Auto-fixes the mechanical UI findings from /ui-crawl by applying the closure-verb vocabulary from… | `--dry-run`, `--plan`, `--safe-only`, `--verify`, `--no-commit`, `--module=<name>` | `/ui-crawl-fix contrast` |
| `/ui-sweep` | Project-wide UI/UX specialist sweep. | `--plan`, `--first-run`, `--scope=<path>`, `--with-iterate`, `--detector=<list>`, `--breakpoints=<list>`, `--baseline-only`, `--report-only`, `--allow-dirty` | `/ui-sweep --first-run` |

## Domain commands — materialized when the domain is detected

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/audit-access-control` _(auth)_ | Audit every endpoint for broken access control — enumerate endpoint × who-can-call-it × the… | — | `/audit-access-control` |
| `/audit-admin-surface` _(admin)_ | Enumerate every admin / back-office endpoint + action and audit each for authorization granularity… | — | `/audit-admin-surface` |
| `/audit-api-contract` _(public-api)_ | Audit the public / external API surface — versioning, deprecation safety, key… | — | `/audit-api-contract` |
| `/audit-document-pipeline` _(document-generation)_ | Audit a specific document (PDF / DOCX / print) pipeline — where the renderer is invoked, sync vs.… | — | `/audit-document-pipeline` |
| `/audit-experiment` _(ab-testing)_ | Audit a specific experiment — deterministic/stable bucketing, server-vs-client identity, exposure… | — | `/audit-experiment` |
| `/audit-form-handling` _(forms)_ | Audit a specific form / submit handler — server-side validation, CSRF, idempotency… | — | `/audit-form-handling` |
| `/audit-integration` _(integrations)_ | Audit a specific third-party integration — token storage, refresh, per-tenant isolation… | — | `/audit-integration` |
| `/audit-ledger` _(ledger)_ | Audit a specific money-movement path — immutability, the balance invariant, money type… | — | `/audit-ledger` |
| `/audit-media-pipeline` _(media-processing)_ | Audit a specific media pipeline end-to-end — codec invocation site, sync vs async, magic-byte… | — | `/audit-media-pipeline` |
| `/audit-moderation` _(moderation)_ | Audit the content-moderation pipeline — where UGC enters, scan coverage (pre/post-publish + edit… | — | `/audit-moderation` |
| `/audit-pipeline` _(data-pipeline)_ | Audit a specific data pipeline (ETL / batch / backfill / CDC / warehouse load) end-to-end — sink… | — | `/audit-pipeline` |
| `/audit-scheduling` _(scheduling)_ | Audit a calendar / availability / booking / recurrence feature — timezone storage, RRULE vs naive… | — | `/audit-scheduling` |
| `/audit-settings` _(settings)_ | Audit the settings/configuration subsystem — store, precedence resolver, typing/validation, secret… | — | `/audit-settings` |
| `/audit-state-machine` _(workflow)_ | Audit an entity's state machine — locate the status field + transitions, reconstruct the actual… | — | `/audit-state-machine` |
| `/audit-streaming-delivery` _(streaming-delivery)_ | Audit a specific stream end-to-end — manifest generation + cache, byte-range/206 segment serving… | — | `/audit-streaming-delivery` |
| `/audit-tracking-plan` _(analytics)_ | Inventory every tracking call-site, match it against the declared tracking plan, and flag drift… | — | `/audit-tracking-plan` |
| `/audit-trail-verify` _(audit-log)_ | Verify the audit trail end-to-end — recompute the hash chain / sequence integrity against the… | `--from`, `--to`, `--coverage-only`, `--integrity-only`, `--replica` | `/audit-trail-verify --from 1 --to 50000` |
| `/compliance-audit` _(compliance)_ | Scan the codebase for PII fields, verify retention + deletion + export coverage, audit log presence… | `--full` | `/compliance-audit` |
| `/dry-run-import` _(import)_ | Validate a bulk-import file / endpoint WITHOUT committing — detected schema vs. spec, per-row… | — | `/dry-run-import` |
| `/flag-audit` _(feature-flags)_ | Inventory every feature flag in code — site count, age, ownership, rollout state, eval rate. | `--provider` | `/flag-audit` |
| `/inspect-queue` _(background-jobs)_ | Dump queue health — depth, oldest-job-age, failed count, throughput. | `--dlq` | `/inspect-queue` |
| `/probe-cache` _(caching)_ | Probe a specific cache usage — key scope (tenant/permission/version), TTL (bounded? jittered?)… | — | `/probe-cache` |
| `/probe-limits` _(rate-limiting)_ | Fire a controlled burst at a target endpoint (LOCAL / STAGING ONLY) to verify the rate limit… | `--count`, `--reset-wait` | `/probe-limits` |
| `/profile-report-query` _(reporting)_ | Profile a specific report / analytics query — plan, row count, replica targeting, and tenant-scope… | — | `/profile-report-query` |
| `/prompt-eval` _(ai)_ | Run golden prompt evaluations — send a fixed set of customer messages through the real… | `--case` | `/prompt-eval` |
| `/replay-charge` _(payment)_ | Replay a recorded payment provider webhook / charge event against the local dev server to verify… | — | `/replay-charge` |
| `/replay-projection` _(event-sourced)_ | Rebuild a read-model projection from the event store. | `--name`, `--drop`, `--aggregate`, `--dry-run`, `--id` | `/replay-projection order_summary --drop` |
| `/scan-i18n-coverage` _(i18n)_ | Scan a codebase for i18n defects — hardcoded user-facing strings, missing/orphan catalog keys per… | — | `/scan-i18n-coverage` |
| `/search-audit` _(search)_ | Run realistic queries against the search engine; verify tenant scoping, relevance ordering, no… | `--index`, `--query`, `--target`, `--explain`, `--tenant`, `--raw`, `--no-tenant-filter` | `/search-audit` |
| `/simulate-renewal` _(subscriptions)_ | Replay a subscription renewal cycle (and a failed-renewal / dunning cycle) against the local dev… | `--fail`, `--exhaust` | `/simulate-renewal` |
| `/simulate-webhook` _(webhook)_ | Replay a WhatsApp webhook fixture against the local (or staging) API, with valid HMAC. | `--tamper` | `/simulate-webhook` |
| `/tenant-leak-audit` _(multi-tenant)_ | Scan the codebase for tenant-isolation leaks — queries and repo methods missing tenant_id filters. | — | `/tenant-leak-audit` |
| `/test-notification` _(notifications)_ | Send a notification through every wired channel to a test recipient with full headers + delivery… | `--template`, `--channel`, `--to`, `--provider`, `--debug` | `/test-notification` |
| `/test-realtime` _(real-time)_ | Open a WebSocket / SSE connection, send N messages, verify ordering, delivery, auth, reconnect… | `--auth`, `--fanout`, `--burst`, `--reconnect`, `--negative`, `--target` | `/test-realtime` |
| `/token-audit` _(ai)_ | Scan the codebase for prompt bloat, unbounded contexts, and missing cost accounting. | — | `/token-audit` |
| `/upload-test` _(file-upload)_ | End-to-end upload smoke — request presigned URL, PUT to S3, trigger backend completion, verify… | `--file`, `--size`, `--type`, `--bomb`, `--eicar`, `--target` | `/upload-test` |

## Baseline — universal infra (repo + workspace)

| Command | Summary | Flags | Example |
|---|---|---|---|
| `/catchup` _(repo)_ | Rebuild working context fast after /clear or a break. | — | `/catchup handoff` |
| `/cross-repo-task` _(workspace)_ | Orchestrate a feature that spans multiple sibling repos — contract-first, dependency-ordered, with… | — | `/cross-repo-task` |
| `/execute-plan` _(repo)_ | Execute a saved plan file produced by <command> --plan — implements its Steps + Outputs verbatim… | `--latest`, `--plan-id`, `--dry-run`, `--no-verify`, `--allow-dirty` | `/execute-plan .claude/plans/add-feature-prescription-filter-20260427-1430.md` |
| `/fix-bug` _(repo)_ | Universal bug-fix workflow. | `--plan`, `--fast` | `/fix-bug` |
| `/migration-doctor` _(workspace)_ | Find real ledger / artifact issues across the workspace's per-repo migration ledgers. | — | `/migration-doctor` |
| `/migration-workspace-status` _(workspace)_ | Aggregate per-repo migration ledgers into a workspace-level status report. | `--repo=<name>`, `--phase=<N>`, `--show-deprecated` | `/migration-workspace-status` |
| `/project-map` _(workspace)_ | Dump the workspace registry or locate a concept across sibling repos. | — | `/project-map "<concept>"` |
| `/ship` _(repo)_ | Take uncommitted work from working tree → commit → push → PR, with a confirmation gate at every… | `--yes`, `--no-pr`, `--cleanup` | `/ship --yes` |
| `/sync-contract` _(workspace)_ | After an API contract change, find frontend consumers and propose synced edits. | — | `/sync-contract` |
| `/verify-plan` _(repo)_ | Verify that the implementation matches a plan generated by <command> --plan. | `--latest`, `--plan-id` | `/verify-plan .claude/plans/add-feature-prescription-filter-20260427-1430.md` |

---

_Duplicate names (e.g. `/refactor`, `/add-feature`, `/fix-bug`, `/cross-repo-task`, `/learn-from-task`) are pack-specialized variants — each appears under its own section with that pack's flags + summary._

