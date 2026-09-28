# Engineering baseline — audit (2026-09-28)

**The question.** A project set up with Refract ran a V1 → V2 port. Afterwards V2 accepted a second
user with an email that already existed. The project had rules, reviewers and a parity auditor. Why
did nothing stop it, and which other standards can fail the same way?

**The answer in one line.** Refract *writes down* almost every standard a senior engineer would ask
for, and almost nothing *requires proof* that a given task applied them. A standard reaches the
model as prose, the command that is running decides whether to look at it, and the default path
through every build command skips the looking.

Three layers, asked of each standard:

| Layer | Question | State today |
|---|---|---|
| In context | Is the rule in front of the model while it writes? | Usually — if its pack was selected |
| In the workflow | Does the running command make the model show it was applied? | Only at heavy tier, which is never the default |
| Enforced | Does a machine fail the change when it is not applied? | Secrets, protected paths, destructive commands, declared module boundaries, lint, tests. Nothing else |

---

## 1. What exists

Coverage in prose is broad. Of the ~70 standards audited (backend/API, architecture, web, mobile,
testing), all but four are documented somewhere; a handful live only in on-demand patterns
(Clean Architecture, DDD aggregates and bounded contexts, the centralized design system, offline
sync). The rule-level homes:

- Backend: `backend-principles.md` (validation, idempotency API-7, rate limiting RES-1, error
  contract, layering, stateless PERF-6), `concurrency-discipline.md`, `database-principles.md`
  (natural-key uniqueness :24, FK, indexes, pooling, row locking), `distributed-principles.md`
  (timeouts, retries, health checks), `observability-principles.md`, `performance-principles.md`
  (cache TTL, stampede), `security-principles.md`.
- Architecture: `code-quality/rules/engineering-principles.md` (module boundaries, layering,
  extend-over-duplicate), `quality-principles.md`.
- Web: `frontend-principles.md`, `ui-ux/rules/ui-principles.md` (a11y, states), the forms domain
  (shared validation schema).
- Mobile: `mobile-principles.md` (secure storage, timeouts, permissions, budgets).
- Testing: `testing-principles.md`, `devops-principles.md` (lint + typecheck CI gate).

**Missing outright:** separating workers from the app process · Anti-Corruption Layer ·
ubiquitous language · SAST at rule level.

## 2. What is actually enforced

The hooks installed by `templates/repo-baseline/.claude/settings.json`:

| Hook | Blocks |
|---|---|
| `pre-edit-guard` | edits to `.env`, keys, lockfiles, generated output, `.claude/hooks` |
| `secret-scan` | a write that introduces a credential |
| `module-boundaries` | an import across a boundary declared in `ai/modules.md` (silent until declared) |
| `guard-destructive` | force-push, `rm -rf`, `DROP`/`TRUNCATE`, `DELETE` without `WHERE`, `curl \| sh` |
| `post-edit-check` | eslint / ruff / golangci-lint failure on the edited file (no typecheck) |
| `verify-gate` (Stop) | a failing test run when source files are uncommitted |

No CI workflow is installed (`templates/repo-baseline/CLAUDE.md`: "there is no CI gate that ships
with this baseline"). `/add-ci` is manual and needs the devops pack. `/pre-commit`,
`/review-changes`, `/check-health` are never invoked by anything.

No deterministic check exists for: natural-key uniqueness, idempotency, outbound timeouts,
retry/backoff, rate limiting, health checks, graceful shutdown, N+1, missing indexes, token drift,
a11y, bundle size, coverage threshold.

In ENHANCE mode an existing `settings.json` is kept and setup does not pass `--wire-hooks`
(`commands/setup-project.md:178`), so the hooks above can be on disk and not registered.

## 3. Documentation only

Everything in § 1 that is not in § 2 — which is nearly all of it. Whether it is applied depends on
the model remembering it, and on the running command asking.

## 4. Missing, or present only in a pack a stack may not get

The only MUST for each of these lives in one pack or domain:

| Standard | Only MUST in | That pack is selected when |
|---|---|---|
| Natural-key uniqueness, row locking, pooling | `database` | root `migrations/`, `prisma/`, `alembic/`, `db/migrate`, or an npm ORM dep (`scripts/detect-tracks.sh:207-217`) |
| Outbound timeouts, retries, circuit breaker | `distributed-systems` | a broker / queue / gRPC / cloud-SDK dep |
| Health checks | `distributed-systems` / `infrastructure` / `devops` | as above / infra files |
| Alerting, SLOs | `observability` | an npm telemetry dep |
| Queue job design | `background-jobs` domain | domain detected |
| Shared FE/BE validation schema | `forms` domain | domain detected |
| Backoff **with jitter** as a MUST | `integrations` domain | domain detected |
| Full SOLID | `align` | opt-in |

`backend-principles.md` has timeouts and retries as **Should**, no health check, and uses unique
constraints only for idempotency dedupe (:32). The database detector reads `package.json` only, so
a Laravel (`database/migrations/`), Django (app-level `migrations/`), Spring/Flyway, Go or raw-driver
backend gets **no database pack and no uniqueness rule**.

## 5. What needs refactoring — the causes

**5a. Conformance-first premise.** The build commands state that the existing code is the truth:
"Existing siblings are the truth" (`packs/backend/commands/add-feature.md:14`; same premise in
add-endpoint:62, add-module:14, add-page:19, add-crud-page:20, add-component:15, mobile
add-feature:19, add-screen:25). The migration pack states that V1 is: "V1 is the validated truth"
(`packs/migration/agents/parity-auditor.md:14`, migration-discipline:31/43). A sibling or a V1 that
lacks a unique constraint is therefore a shape to copy, not a defect to fix. Only three places say a
standard outranks the sibling: add-crud-page:175, add-screen:56-60, add-module:69.

**5b. The default tier checks shape, not standards.** Every build command defaults to trivial, and
the model picks the tier. Backend add-feature at trivial: "this halt is the only gate. No
reviewers" (:96). The sibling-shape halt compares imports, paths, names and primitives — not
uniqueness, idempotency or timeouts. The all-tier floor (:110-121) covers observability and a
security pre-flight, not data integrity. Several commands also contradict themselves on whether
review runs at trivial tier (mobile add-feature:44 vs :232-239, add-endpoint:31 vs :324-346,
add-module:103 vs :222-234, backend fix-bug:44 vs :291-293).

**5c. Migration never records invariants below heavy tier.** Migration tier defaults to trivial
(`migration-discipline.md:61-68`). Invariants live only in contract § 5, and the contract is
heavy-only (`extract-v1-contract/SKILL.md:30-32`); standard tier's 3-section contract skips them
(`migration-guardrails.md:51`).

**5d. The parity counter cannot see a lost constraint.** `extract_inventory_primitives`
(`scripts/validate-migration-artifacts.sh:1270`) counts eight backend classes — none of them a
unique constraint or a uniqueness check. `constraint` / `index_def` exist only for `data-*`
projects, and that regex misses the common declarations (`@unique`, `unique: true`,
`unique=True`, `->unique()`). And a drop of ≤ 5 on a trivial-tier PARITY row is warn-only
(:1897) — a V2 that lost its one uniqueness check, or one auth guard, passes.

**5e. Rule delivery is documented wrong.** `templates/repo-baseline/.claude/rules/README.md:11`
says Claude Code does not auto-load `.claude/rules/`. Claude Code's memory docs say rules without
`paths:` load at launch, recursively (https://code.claude.com/docs/en/memory.md § "Organize rules
with `.claude/rules/`": "Rules without `paths` frontmatter are loaded at launch with the same
priority as `.claude/CLAUDE.md`" · "All `.md` files are discovered recursively"). The same page:
rules are "context, not enforced configuration. To block an action regardless of what Claude
decides, use a PreToolUse hook."

The wrong premise is not only in that README. `scripts/wire-rule-imports.sh:8` and `:314` write it
into every target's `CLAUDE.md`; `scripts/audit-setup.sh:1673` errors "NO rule is loaded" on a
project with no `@`-imports; the 12k import budget limits nothing, since every rule loads anyway;
and `_unloaded.md` lists rules as "NOT LOADED" while they load — as do `_unloaded.md` and the
rules `README.md` themselves, every session. Worse, `scope-domain-rules.sh` pass 2 "rescued"
unimported principle rules by path-scoping them — taking backend-principles and
security-principles OUT of always-on context.

**Measured, then decided (option A — accept native loading).** A canary run on Claude Code 2.1.236
(empty CLAUDE.md, three rules) loaded the unconditional and the nested rule and not the
`paths:`-scoped one. So: `wire-rule-imports.sh` no longer writes `_unloaded.md` and removes a stale
one; its CLAUDE.md block and overflow message state the truth and the real cost; `audit-setup.sh`
C2u no longer ERRs on healthy installs and reports cost instead; `scope-domain-rules.sh` pass 2 is
retired; the docs that repeated the premise are corrected; `scripts/test-rule-loading.sh` § 2 pins
the new behaviour.

In the incident, if the database pack was installed, the uniqueness rule was in context — and was
still not applied. Prose in context is not enough; the workflow has to ask for evidence.

**Conflicts between rule files** (resolve while cataloguing):

1. CPU on the event loop: `backend-principles:48` says 50 ms; `performance-principles:36` says a
   server has no such constant.
2. Rate-limit headers: `domains/rate-limiting` mandates `RateLimit-Limit/-Remaining/-Reset`;
   `backend/ai-patterns/rate-limiting.md:87,129` calls those legacy.
3. TODO format: baseline `code-quality.md:24` wants a ticket ref; `quality-principles.md:37-38`
   forbids ticket refs and wants owner + delete-by.
4. Circuit breaker: Hard-rule MUST at `distributed-principles:12`, Should at :43.
5. Tenant filter: `security-principles:30` says auto-applied, never opt-in; `database-principles:27`
   and `backend-principles:34` allow it per query.
6. Re-validation: `quality-principles:27` vs `security-principles:20`.
7. Severity mismatches: timeouts (Should in backend, Must in distributed/mobile), rate limiting
   (Should in security, Must in backend), backoff without jitter in `job-design.md:27`.

## 6. What can become an automated gate

| Standard | Mechanism |
|---|---|
| Natural-key column without a unique constraint | static schema scan across Prisma / TypeORM / Sequelize / Mongoose / Django / Laravel / Rails / SQL |
| Lost constraint or uniqueness check in a port | `extract_inventory_primitives` + no trivial softening for invariant classes |
| Outbound HTTP call with no timeout | static scan per client library |
| `.only` / `.skip` without owner | static scan |
| `console.log`, `fetch` in a component body, hardcoded colour/spacing | static scan (frontend rule already names them) |
| Lint, typecheck, tests, coverage floor, dependency audit, secret scan, migration lint, e2e | CI proposed at setup via `/add-ci` |

---

## Other drift found on the way

- `packs/backend/rules/migration-backend.md` cites `extract_inventory_primitives` at `:1211` and its
  call at `:1799-1800`; they are at `:1270` and `:1864-1865`.
- `packs/backend/commands/add-feature.md:253` says `.claude/rules/` is auto-loaded while the
  baseline README says it is not.
- `scripts/detect-tracks.sh:80-86` installs six universal packs; `_registry.md` and
  `phase-2-profile.md:55` say four, and list testing as signal-based.
- No build command ends at `/ship` or `/deploy-stage`; `/task` stops at a PR.

## What changes

Tracked in the approved plan: a per-stack engineering-baseline catalog with IDs, a standards gate
in every build command at every tier where the baseline outranks the sibling and V1, the migration
fixes in § 5c–5d, a deterministic `standards-check` starting with natural-key uniqueness, CI proposed
at setup, and the pipeline closed through `/ship`.
