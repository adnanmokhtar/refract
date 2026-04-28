---
artifact: capabilities
purpose: Seven cross-cutting capabilities (versioning + migration, health + telemetry, schema validation, failure catalog, fixtures + factories, multi-language UX, conversational wizard). These are FEATURE blocks that thread through multiple phases.
imported-by: commands/setup-project.md (orchestrator) — referenced; sections within touch Phases 0/3/4/5/6.
note: M3 will split each capability into its own file under templates/capabilities/.
---

## 🚀 Advanced capabilities (v3.0+)

These seven capabilities sit on top of the base 5-phase pipeline. They're independent — a project can use one without the others — but together they graduate `/setup-project` from a one-shot scaffolder into a self-measuring, self-versioning, self-validating engineering platform.

| # | Capability | Flag | Writes |
|---|---|---|---|
| 1 | Setup versioning + migration | `--diff`, auto on every run | `_version` stamps in pack sources, `setup_version` block in `.claude/codebase-profile.md` |
| 2 | Health score + telemetry | `--health`, auto on every run | `.claude/_telemetry.jsonl`, `_session-digest.md` health line |
| 3 | Schema validation harness | `--validate-schemas`, auto in Phase 5 | `.claude/_schema-report.json` (transient) |
| 4 | Failure catalog | none (always-on) | `ai/failures/_index.md` + `ai/failures/<NNNN>-<slug>.md` |
| 5 | Test fixtures + factories | none (auto when business-domain detected) | `test/factories/<entity>.factory.ts` + `test/fixtures/<entity>.fixture.json` per domain |
| 6 | Multi-language UX | `--lang=ar\|en\|auto` | bilingual headers in CLAUDE.md / AGENTS.md / `ai/README.md` |
| 7 | Conversational wizard | `--wizard` | none (interactive — feeds Phase 2.y answers) |

---

### 🧮 1. Setup versioning + migration (B2)

**Problem solved**: packs evolve in `~/.claude/templates/`; old projects don't know they're stale; manual `--refresh` is the only signal. Result: silent rot across projects.

**Design**:

#### 1.1 Version every artifact source

Every pack / business-domain / technical-signal directory gets a `_version.json`:

```
~/.claude/templates/packs/backend/_version.json
{
  "version": "2.4.0",
  "released": "2026-04-15",
  "min_setup_command": "3.0.0",
  "deprecated": false,
  "summary": "Adds saga-orchestrator agent + distributed-tx pattern."
}

~/.claude/templates/business-domains/ecommerce/_version.json
~/.claude/templates/domains/multi-tenant/_version.json
~/.claude/templates/tool-adapters/cursor/_version.json
```

The setup command itself versions in its frontmatter:

```yaml
---
description: <as before>
setup_command_version: 3.0.0
released: 2026-04-25
---
```

#### 1.2 Stamp into project on apply

Phase 4.1 (after baseline scaffold) appends a `## Setup version` block to `.claude/codebase-profile.md`:

```yaml
## Setup version
setup_command: 3.0.0
applied_at: 2026-04-25T14:30:00Z
mode: REFRESH
flags: [--refresh, --lang=ar]
packs:
  backend: 2.4.0
  database: 1.5.2
  security: 1.0.0
  testing: 1.3.0
  code-quality: 1.0.0
  documentation: 1.0.0
  learning: 1.0.0
business_domain: ecommerce@1.2.0
technical_signals:
  multi-tenant: 1.4.0
  payment: 1.1.0
tool_adapters:
  claude-code: 3.0.0
  cursor: 1.2.0
  opencode: 1.1.0
```

#### 1.3 Drift detection at session start

`session-start.sh` reads recorded versions from `.claude/codebase-profile.md` and compares against `_version.json` of each currently-installed template. Output (only if drift detected):

```
⚠ Setup updates available (run /setup-project --diff for details, --refresh to apply):
   backend         2.4.0 → 2.5.1  (3 patches, 1 minor — additive)
   security        1.0.0 → 1.1.0  ★ BREAKING (agent rename)
   ecommerce       1.2.0 → 1.3.0  (new flow templates)

Last refresh: 6 weeks ago.
```

Suppression: user can add `setup_drift_check: false` to their `.claude/settings.json` to silence the nag (NOT recommended).

#### 1.4 `--diff` flag (read-only preview)

```
$ /setup-project --diff

PACK DRIFT REPORT (.claude/codebase-profile.md vs ~/.claude/templates/)

  backend          2.4.0 → 2.5.1
    +1 minor: pattern/saga-orchestrator.md (NEW)
    +3 patches: rule wording fixes
    Migration: none required (additive)

  security         1.0.0 → 1.1.0  ★ BREAKING
    !1 major: agent api-architect → backend-architect (renamed)
    Migration script: ~/.claude/templates/packs/security/migrations/v1.0-to-v1.1.sh
    Auto-applied by /setup-project --refresh.

  ecommerce        1.2.0 → 1.3.0
    +1 minor: core-flows: subscription-billing flow added
    Migration: none required (additive)

To apply: /setup-project --refresh    (REFRESH preserves your ADRs + custom rules)
```

#### 1.5 Changelog format

Each pack maintains a `CHANGELOG.md`:

```markdown
# backend pack changelog

## [2.5.1] - 2026-04-30
### Fixed
- typo in rule/services.md

## [2.5.0] - 2026-04-25
### Added
- pattern/saga-orchestrator.md
- agent/distributed-tx-architect.md
### Migration
- additive only; /setup-project --refresh handles automatically

## [2.4.0] - 2026-04-15
### Added
- pattern/distributed-transactions.md
```

#### 1.6 Migration scripts

For breaking changes (major version bump), add a migration script:

```
~/.claude/templates/packs/security/migrations/v1.0-to-v1.1.sh

#!/usr/bin/env bash
# Renames api-architect → backend-architect across all setup files.
set -euo pipefail
PROJECT_ROOT="${1:-.}"

[ -f "$PROJECT_ROOT/.claude/agents/api-architect.md" ] && \
  mv "$PROJECT_ROOT/.claude/agents/api-architect.md" \
     "$PROJECT_ROOT/.claude/agents/backend-architect.md"

# Update references
for f in "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/AGENTS.md" "$PROJECT_ROOT/.claude/GUIDE.md"; do
  [ -f "$f" ] && sed -i.bak 's/api-architect/backend-architect/g' "$f" && rm "$f.bak"
done
```

REFRESH mode auto-runs migration scripts in version order before regen. Plan output shows which scripts will run + lets user approve.

#### 1.7 Hard rule

- **Every pack source MUST have `_version.json`.** Phase 4.0 pack-load preflight refuses to apply a pack without it.
- **Breaking changes (major bump) MUST have a migration script.** CI on `~/.claude/templates/` enforces this.
- **`setup_command_version` and pack versions MUST be recorded** in every project's `.claude/codebase-profile.md`. Without these, drift detection is impossible.

---

### 📊 2. Setup health score + telemetry (B3)

**Problem solved**: command writes 50+ files. Are they helping? Which agents/skills/commands actually get invoked? Has the setup decayed since apply? No way to know without measurement.

**Design**:

#### 2.1 Health score formula

Score is `0–100`, computed by `--health` flag and at end of every Phase 5:

```
health_score = (
  0.25 × baseline_completeness +    # full `templates/repo-baseline/ai/` seeded tree present in project `ai/`
  0.20 × pack_coverage +            # per-track minimums met (Phase 4.0)
  0.15 × adapter_completeness +     # per-adapter contracts (Phase 4.8.0)
  0.15 × cross_ref_integrity +      # broken refs / ghost files
  0.10 × convention_match +         # codebase conventions match `ai/conventions.md`
  0.10 × version_currency +         # how far behind latest packs
  0.05 × usage_signal               # invocation telemetry presence
)
```

Each sub-score 0–100. Composite tagged:
- `90–100`: Excellent
- `70–89`: Good
- `50–69`: Drift detected
- `< 50`: Setup needs refresh

#### 2.2 `--health` output

```
$ /setup-project --health

SETUP HEALTH SCORE: 87/100  (Good)

  ✓ Baseline completeness:    100/100  (13/13 baseline files)
  ✓ Pack coverage:             95/100  (backend 5/5 ★, security 2/2 ★, testing 3/3 ★)
  ⚠ Adapter completeness:      75/100  (cursor: 8/10 commands translated; opencode: complete)
  ✓ Cross-ref integrity:       100/100 (0 broken refs)
  ⚠ Convention match:          80/100  (3 generic rules detected; Phase 4.6 may need re-run)
  ⚠ Version currency:          70/100  (backend 1 minor behind, security 1 major BREAKING behind)
  ⚠ Usage signal:              60/100  (3 of 12 agents never invoked in last 30 days)

Top 3 actions:
  1. Run /setup-project --refresh   → close version-currency gap (+10)
  2. Re-run Phase 4.6 conventions  → close convention-match gap (+5)
  3. Translate 2 missing cursor commands → close adapter-completeness gap (+5)

Last computed: 2026-04-25T14:35:00Z
```

#### 2.3 Telemetry log

Every command/agent/skill invocation appends one line to `.claude/_telemetry.jsonl`:

```jsonl
{"ts":"2026-04-25T14:30:00Z","kind":"command","name":"/add-module","tool":"claude-code","duration_ms":45000,"success":true}
{"ts":"2026-04-25T14:32:10Z","kind":"agent","name":"nestjs-architect","invoked_by":"/add-module","duration_ms":12000,"success":true}
{"ts":"2026-04-25T14:33:00Z","kind":"skill","name":"endpoint-test","invoked_by":"manual","duration_ms":3000,"success":true}
```

Format: append-only JSONL. Pruned to last 90 days at session start. NEVER sent off-machine — entirely local telemetry.

Wired via:
- Each generated command's Phase 7 (Improve) appends a telemetry entry.
- Each agent's pre-flight emits a `kind:"agent"` entry.
- Each skill's `SKILL.md` includes a telemetry-emit step.

#### 2.4 Drift score (sub-component)

Computed by comparing `.claude/codebase-profile.md` § "Detected stack/conventions" against current state of code. Mismatches = drift.

```
DRIFT REPORT
  Profile says: base class BaseService (47 extenders)
  Current code: BaseService (52 extenders) ✓
  Profile says: file naming kebab-case + suffix matrix
  Current code: kebab-case + suffix matrix ✓
  Profile says: tenantId column on every entity
  Current code: 3 NEW entities WITHOUT tenant_id  ⚠
    apps/master/src/billing-experiments/.../experiment.entity.ts
    libs/common-modules/src/notifications/.../template.entity.ts
    apps/tenant/src/v3/products/.../variant.entity.ts
```

Drift findings auto-feed Phase 6 learning loop (the `convention-drift-detector` agent picks them up).

#### 2.5 Phase 6 effectiveness metrics

Once telemetry has 30+ days of history, Phase 6 reports include:
- **Correction rate**: corrections per session (target: declining over time).
- **Pattern reuse**: ratio of new modules using existing patterns vs inventing new ones.
- **Agent utility**: invocation count per agent (low-utility agents flagged for removal).
- **Skill cache-hit**: how often `getOrSet` hits in skill flows (target: rising).

Output in `ai/_session-digest.md` § "Setup health" line.

#### 2.6 Hard rules

- **Telemetry is local-only.** NEVER make a network call from the telemetry path. NEVER include user/PII data in telemetry entries.
- **Health score MUST appear in `_session-digest.md`.** Tier 1 visibility — silent decay isn't allowed.
- **`.claude/_telemetry.jsonl` MUST be `.gitignore`d.** Phase 4.1 enforces.

---

### 🔬 3. Schema validation harness (B4)

**Problem solved**: Phase 5 verifies file PRESENCE, not file VALIDITY. Generated `settings.json` could have a typo. Generated `opencode.json` could miss required keys. `.cursor/rules/*.mdc` frontmatter could be malformed. No automated catch.

**Design**:

#### 3.1 Schema directory

```
~/.claude/templates/schemas/
  claude-code/
    settings.schema.json      # Claude Code settings.json schema
    mcp.schema.json           # .mcp.json schema
    skills.schema.json        # SKILL.md frontmatter schema
    agents.schema.json        # agent frontmatter schema
    commands.schema.json      # command frontmatter schema
  cursor/
    rules.schema.json         # .cursor/rules/*.mdc frontmatter schema
    cursorrules.schema.json
  opencode/
    config.schema.json        # opencode.json schema
  aider/
    config.schema.json
  generic/
    agents-md.schema.json     # AGENTS.md (universal anchor) shape
    codebase-profile.schema.json
    session-digest.schema.json
```

Each schema is JSON Schema Draft 2020-12. Updated alongside the corresponding tool adapter version.

#### 3.2 Phase 5.4 — Schema validation step (NEW)

After Phase 5 file-presence + self-consistency audit:

```bash
for config in $(find . -name "settings.json" -path "*/.claude/*" -o \
                       -name "opencode.json" -o \
                       -name ".mcp.json"); do
  schema="$(basename "$config")".schema.json
  ajv validate -s ~/.claude/templates/schemas/claude-code/$schema -d "$config" \
    || HALT_VALIDATION="$HALT_VALIDATION\n  $config FAILED schema $schema"
done

# Frontmatter validation (markdown files with YAML frontmatter)
for skill in .claude/skills/*/SKILL.md; do
  extract_frontmatter "$skill" | yamllint --schema ~/.claude/templates/schemas/claude-code/skills.schema.json
done
```

If any failure → halt + retry the offending generator. If retry also fails → halt with report.

#### 3.3 Dry-invoke smoke test

For each generated command: parse the frontmatter, simulate invocation with a minimal test prompt, verify output matches expected shape:

```bash
for cmd in .claude/commands/*.md; do
  desc=$(yq '.description' "$cmd")
  # Generate a minimal test prompt that should trigger the command
  # Pipe into a dry-evaluator (does NOT actually invoke the LLM — just parses + validates structure)
  validate_command_invocation "$cmd" || FAIL=1
done
```

The validator checks:
- All `Read` directives in the command point to existing files.
- All `Bash` snippets are syntactically valid (parse with `bash -n`).
- All referenced agents exist in `.claude/agents/`.
- All referenced skills exist in `.claude/skills/`.
- Phase numbers are sequential (1→7) per the canonical 7-phase structure.

#### 3.4 `--validate-schemas` flag

Standalone read-only run:

```
$ /setup-project --validate-schemas

VALIDATING 47 generated files against schemas...

  .claude/settings.json                    ✓
  .mcp.json                                ✓
  .claude/skills/*/SKILL.md (7 files)     ✓
  .claude/agents/*.md (14 files)          ✓
  .claude/commands/*.md (20 files)        ⚠
    /add-module: Phase 5 missing (canonical 7-phase structure violated)
    /fix-bug: references nonexistent agent `db-architect`

  opencode.json                            ✓
  .cursor/rules/*.mdc (6 files)           ✓

DRY-INVOKE smoke test (20 commands):
  /add-module        ✓ structure OK
  /fix-bug           ✗ broken cross-ref to .claude/agents/db-architect.md (does not exist)
  ...

RESULT: 2 issues found.
Run /setup-project --refresh to regenerate (auto-fixes structural violations).
```

#### 3.5 Rules (graceful degradation)

- **Schema validation is opt-in.** When `--validate-schemas` is passed (or the user runs `--refresh` and schemas are present), Phase 4.8 validates every generated config against its schema. If a schema is missing for a selected adapter, Phase 4.8 emits a `SCHEMA_MISSING <adapter>` warning in the report and continues. It does NOT halt.
- **Recommended seed schemas** (ship in `~/.claude/templates/schemas/` over time): `claude-code/settings.schema.json`, `claude-code/agents.schema.json`, `claude-code/commands.schema.json`, `claude-code/skills.schema.json`, `cursor/rules.schema.json`, `opencode/config.schema.json`, `aider/config.schema.json`, `generic/agents-md.schema.json`. Anything beyond these is a future enhancement, not a hard requirement.
- **Schema version pinning** (when schemas exist): schemas declare `$id` with version (e.g. `https://<your-org>.com/schemas/claude-code/settings/v1.json`). Adapter version bump = schema version bump.
- **`--refresh` SHOULD run schema validation** as part of Phase 5 when schemas are present. Failures degrade to warnings unless `--strict` is also passed.

---

### 📕 4. Failure catalog (B10)

**Problem solved**: ADRs say "we decided X." Patterns say "do this." Nothing says **"we tried Y and it FAILED because Z — don't retry."** Future LLMs and humans re-burn on solved problems.

**Design**:

#### 4.1 New baseline directory

`ai/failures/` is now part of the baseline (Phase 4.1 scaffolds it). Structure:

```
ai/failures/
  _index.md                              # one-line per failure for fast scan
  README.md                              # how to add new failures
  0001-orm-injectrepository-typeorm.md   # the @InjectRepository / TypeOrmModule.forFeature attempt
  0002-cache-without-tenant-prefix.md    # generic key tried; leaked across tenants
  0003-elasticsearch-as-primary-store.md # used ES as source-of-truth; data loss
  ...
```

#### 4.2 Failure file format

```markdown
---
id: 0001
title: TypeORM @InjectRepository / TypeOrmModule.forFeature in V1
date_failed: 2025-09-15
attempted_by: <author>
status: validated_failure  # or: superseded_by_<adr-id>
related_adrs: [001, 003]
related_patterns: [data-access]
tags: [typeorm, dependency-injection, repositories]
severity: high  # how badly this hurt; informs how loudly to warn
---

# Failure 0001: TypeORM @InjectRepository / TypeOrmModule.forFeature in V1

## What we tried
Replace V1's custom `DataAccess` + `DataSource` repository pattern with NestJS-idiomatic
`@InjectRepository(Entity)` + `TypeOrmModule.forFeature([Entity])` registration.

## Why it failed
1. Lost automatic tenant filtering (DataAccess applies it; @InjectRepository doesn't).
2. Soft-delete subscribers stopped firing on entities not registered through DataAccess.
3. 47 modules required updating; 12 introduced cross-tenant query bugs in QA.
4. Custom criteria system incompatible with TypeOrmModule registration.

## Root cause
V1 baked tenant + soft-delete into the data-access base class. Bypassing it = bypassing
those guarantees.

## What we do instead
See ADR-001 (BaseService pattern) + pattern/data-access.md.

## Don't retry unless
The cross-cutting filters (tenant + soft-delete + audit) move to a different layer
(e.g., TypeORM subscribers) AND all 47 modules migrate atomically.
```

#### 4.3 `_index.md` format (one-line per failure)

```markdown
# Failures index

| ID | Title | Date | Severity | Status | Don't retry unless |
|---|---|---|---|---|---|
| 0001 | TypeORM @InjectRepository | 2025-09 | high | validated | filters move to subscribers + atomic migration |
| 0002 | Cache without tenant prefix | 2025-11 | critical | validated | global key explicitly + audit confirms no PII |
| 0003 | Elasticsearch as source-of-truth | 2025-12 | critical | validated | dual-write + reconciliation harness |
```

#### 4.4 Decision engine integration

The Decision engine gains a 6th input:

| Input | What it answers | Source |
|---|---|---|
| **Prior failures** | "What have we already tried that failed?" | `ai/failures/_index.md` |

Tie-breaking: **Failure history wins on architecture decisions.** If a proposed approach matches an entry in `ai/failures/_index.md`, the brain MUST surface the failure in the plan and require explicit override before proceeding.

#### 4.5 Decision-engine prompt insertion

Tier 2 context loading adds `ai/failures/_index.md` for "architecture decision" task types. Every architectural agent (nestjs-architect, backend-architect, db-architect, etc.) reads the index in pre-flight:

```markdown
## Pre-flight (auto-injected)
- @file ai/failures/_index.md  ← "have we tried this before?"
- @file ai/decisions/_decision-index.md
- @file ai/conventions.md
```

#### 4.6 Phase 6 promotion path

The persistence pyramid gains a "validated failure" tier:

```
RAW observation → CORRECTION (user said no) → VALIDATED failure (user said
"we tried this and it broke; don't try again") → FAILURE catalog entry (formal)
```

`/learn-from-task` gains `--as-failure` flag: when a task ends with the user explicitly saying "this didn't work, never again," promote to `ai/failures/`.

#### 4.7 Hard rules

- **Failure catalog MUST be loaded in pre-flight** for all architectural agents. Without it, agents propose ideas that already failed.
- **NEVER delete a failure entry.** Mark `status: superseded_by_<adr>` if conditions change. History is permanent.
- **A failure entry MUST cite the original incident** (PR / commit / Slack thread / dated note). "We tried this and it failed" without evidence is not a failure entry; it's hearsay.

---

### 🏭 5. Test fixtures + factories generation (B17)

**Problem solved**: business-domain detection knows "this is ecommerce" but doesn't generate `ProductFactory`, `OrderFactory`, `CartFactory`. New modules ship without test fixtures. `add-module` has nothing to compose with.

**Design**:

#### 5.1 New pack file per business domain

```
~/.claude/templates/business-domains/ecommerce/factories.md
```

Format:

```markdown
# Ecommerce factory templates

Auto-generated when business-domain = ecommerce. Each factory is a starting point
adapted to the project's detected base test framework + ORM in Phase 4.6.

## Entities to factory

- ProductFactory      — required: name, price, sku; faker.commerce.*
- VariantFactory      — required: productId, attributes; uses ProductFactory.create()
- CartFactory         — required: customerId, items[]; uses ProductFactory + VariantFactory
- OrderFactory        — required: customerId, items[], total, status; uses CartFactory
- CustomerFactory     — required: email, phone; faker.internet.email + faker.phone
- AddressFactory      — required: country, city; respects detected i18n locales
- PaymentMethodFactory — required: type (card/cod/wallet); maps to detected payment provider
- DiscountFactory     — required: code, type, value
- TaxRuleFactory      — required: country, rate; respects multi-currency signal

## Fixtures to generate (golden values)

- fixtures/products-100.json          — 100 realistic SKUs across categories
- fixtures/orders-various-states.json — 1 order per status (pending, paid, shipped, etc.)
- fixtures/customers-multi-tenant.json — customers across 3 tenants for isolation tests
- fixtures/checkout-edge-cases.json   — coupon-plus-tax, partial-refund, COD, etc.
```

Each business domain has its own `factories.md`. Healthcare gets `PatientFactory` / `EncounterFactory`; LMS gets `CourseFactory` / `EnrollmentFactory`; etc.

#### 5.2 Phase 4.4b (business-domain content) — extended

After copying `glossary.md` / `core-flows.md` / etc., Phase 4.4b ALSO:

1. Reads `factories.md` from the matched business-domain pack.
2. For each entity listed: detects whether the codebase already has the entity (via Phase 2 codebase-profile entities scan).
3. For entities that EXIST: generate factory + fixture using the project's test framework conventions.
4. For entities NOT YET in code: add to `ai/business-domain.md` § "Domain entities (not yet implemented)" — when those entities get added later, factories materialize on next `--refresh`.

Generated paths:

```
test/factories/product.factory.ts
test/factories/order.factory.ts
test/fixtures/products-100.json
test/fixtures/orders-various-states.json
```

#### 5.3 Framework adaptation

Phase 4.6 (convention adaptation) detects:

| Detected | Factory style |
|---|---|
| Jest + TypeORM | factory-pattern with `DataSource` injection |
| Jest + Prisma | factory using `prisma.<model>.create()` |
| Vitest + Drizzle | factory using `db.insert(<table>)` |
| Pytest + SQLAlchemy | factory_boy DjangoFactory |
| pytest + Django | factory_boy DjangoModelFactory |
| Go + standard test | builder-pattern function returning `*Entity` |
| Phoenix + Ecto | ExMachina factories |

#### 5.4 Wired into `add-module` skill

`add-module` now declares:

```yaml
---
description: Scaffold new V1 module
inputs:
  - module_name
generates:
  - core/, adapters/, infrastructure/ (existing)
  - test/factories/<module>.factory.ts (NEW — uses business-domain factory pack)
  - test/fixtures/<module>-baseline.json (NEW)
---
```

#### 5.5 Hard rules

- **Every business-domain pack MUST have a `factories.md`.** Phase 4.0 refuses to apply business-domain pack without it.
- **Generated factories MUST be project-style-adapted.** A factory that doesn't match detected naming + base classes is a broken factory.
- **Fixtures NEVER contain real PII** even when sourced from production-like data. `faker` only.

---

### 🌍 6. Multi-language UX (B14)

**Problem solved**: command outputs in English. Many users (esp. those targeting Egyptian/Saudi/Arabic-speaking markets) work primarily in Arabic. Setup questions during interactive flow fail when the user thinks in Arabic.

**Design**:

#### 6.1 Language detection

Resolution order (used by `--lang=auto`):
1. Explicit `--lang=ar|en` flag.
2. `$CLAUDE_CODE_LANG` env var (if user sets globally).
3. `$LANG` / `$LC_ALL` env vars (`ar_*` / `ar_SA.UTF-8` / etc → ar).
4. Detected i18n locale files in repo: if `ar.json` files outweigh `en.json` files in line count, default to ar.
5. Fallback: en.

#### 6.2 Localized prompts (interactive only)

Phase 2.y intent-capture questions get bilingual:

```
🌍 LANG = ar (auto-detected from $LANG=ar_SA.UTF-8)

Question 1 of 8 — Mission
─────────────────────────
🇸🇦 ما هي مهمة هذا المنتج في جملة واحدة؟
🇬🇧 In one sentence, what does this product do?

Inferred from README: "Multi-tenant ecommerce SaaS for Egyptian SMB merchants"
Press [Enter] to accept, type to override:
> _
```

Wizard mode (B22) uses the same bilingual format. CREATE-mode prompt parsing accepts Arabic — extracts the same facets.

#### 6.3 Bilingual generated headers

`CLAUDE.md`, `AGENTS.md`, `ai/README.md` get a small Arabic preamble above the English body when `lang = ar`:

```markdown
# CLAUDE.md — <project-name>

> 🇸🇦 ملاحظة للمساعد: هذا المشروع متعدد المستأجرين (multi-tenant) ومتعدد العملات.
>     يجب احترام عزل المستأجر في كل استعلام. اللغة الأساسية للكود: TypeScript / NestJS.
>     لغة التواصل: عربي أو إنجليزي حسب اختيار المطور.
>
> 🇬🇧 Note for assistant: this is a multi-tenant, multi-currency project. Tenant
>     isolation is mandatory in every query. Code language: TypeScript / NestJS.
>     Communication language: English or Arabic per developer's choice.

## #1 Rule: Read Before You Write
<rest of file in English as before>
```

Generated code comments stay in English (industry norm; non-Arabic-readers contribute too). User prompts during setup, README files, and assistant-facing preambles get Arabic.

#### 6.4 Locale-aware business-domain content

When `lang = ar` AND `business_domain = ecommerce`:
- `ai/business-domain.md` includes Arabic glossary entries:
  ```
  ## Domain glossary
  - Product / منتج — ...
  - Cart / عربة التسوق — ...
  - Checkout / إتمام الشراء — ...
  - Tenant subscriber / المشترك (المتجر) — ...
  ```
- Compliance section auto-includes Saudi PDPL + UAE PDPL references.

#### 6.5 RTL awareness

Generated frontend-pack rules add an RTL note when `lang = ar`:
- "All UI MUST support RTL layout — verify with `dir='rtl'` set on `<html>`."
- "Mirror padding/margin: `ms-*` / `me-*` (Tailwind logical) over `pl-*` / `pr-*`."

#### 6.6 Hard rules

- **Setup question prompts respect `--lang`.** English-only Phase 2.y is a regression in `lang=ar`.
- **Generated code comments + variable names stay English.** Even in `lang=ar`. Industry interop > local convenience.
- **Bilingual preamble appears ONLY in human-facing docs** (CLAUDE.md, README, AGENTS.md, ai/README.md). NEVER in machine-only files (codebase-profile, session-digest, _telemetry).

---

### 🪄 7. Conversational wizard mode (B22)

**Problem solved**: flag-based UX is great for power users but bad for new team members, unfamiliar stacks, or cases where the prompt is sparse and the auto-detected mode is uncertain. Forcing one consolidated mega-question loses nuance.

**Design**:

#### 7.1 Activation

`--wizard` flag explicitly activates. ALSO auto-suggested when:
- CREATE mode + prompt < 50 chars + no README.
- ENHANCE mode + ≥3 `[CONFLICT]` or `[UNKNOWN]` flags after detection.
- User runs `/setup-project` with no prompt + no flag for the first time on a project.

In auto-suggest case: "Your prompt is sparse and the codebase is empty. Run `--wizard` for guided setup? [Y/n]"

#### 7.2 Wizard flow

The 8 Phase-2.y intent facets become 8 wizard steps. Plus 4 setup-meta steps:

| Step | Question | Default offered |
|---|---|---|
| 1 | Mode | Inferred (CREATE / ENHANCE / REFRESH) — confirm or override |
| 2 | Tracks to apply | Auto-detected list, lets user toggle |
| 3 | Business domain | Auto-detected, override if wrong |
| 4 | Mission / one-liner | From README / package.json description |
| 5 | Target users | From README — explicit ask if absent |
| 6 | Business model | From package.json keywords / README |
| 7 | Maturity stage | From README phase / `ai/status.md` |
| 8 | Success KPIs | Always ask |
| 9 | Constraints | Always ask |
| 10 | Anti-goals | Always ask |
| 11 | Tools | Auto-detected adapters, lets user toggle |
| 12 | Confirm + apply | Show full plan, mock outputs, ask Y/N |

Each step:
- Shows what the brain inferred.
- Shows the WHY (why this default makes sense).
- Lets user `[Enter]` to accept, type to override, `[?]` for "what does this affect," `[skip]` to leave as default.
- Shows a mini "this will result in:" preview after each answer.

#### 7.3 Mock output preview before final apply

Step 12 shows a preview of what 5 sample generated files will look like:

```
Step 12 — Confirm + apply

Sample generated files (full preview at .claude/_wizard-preview/):

  CLAUDE.md (first 30 lines)
  ───────────────────────────
  # CLAUDE.md — <project-name>
  ...

  .claude/agents/backend-architect.md (first 30 lines)
  ─────────────────────────────────────────────────────
  ...

  ai/conventions.md (first 30 lines)
  ───────────────────────────────────
  ...

Plan:
  - Mode: ENHANCE-extend (refresh existing setup with new tracks)
  - Tracks: backend, security, code-quality, learning, testing
  - Files to write: 47
  - Files to leave alone: 12
  - Files to backup (REFRESH-prep): 0 (not in REFRESH)

Apply now? [y/n/preview-more]
```

#### 7.4 Wizard adapts to language

`--wizard --lang=ar` → all 12 steps prompt in Arabic with English fallback. See B14 § 6.2 for shape.

#### 7.5 Wizard saves answers for re-use

After apply, wizard answers persist to `.claude/_wizard-answers.yaml`:

```yaml
mode: ENHANCE-extend
business_domain: ecommerce
tracks: [backend, security, code-quality, learning, testing]
mission: "Multi-tenant ecommerce SaaS for Egyptian SMB merchants"
target_users: "Egyptian + Saudi small/medium business merchants"
maturity: paying-customers
constraints: [latency-p99-200ms, multi-currency, RTL-required]
anti_goals: [enterprise-on-prem, white-label-only]
applied_at: 2026-04-25T14:30:00Z
```

Re-running wizard reads these as defaults. So second run is fast — only changed answers need attention.

#### 7.6 Hard rules

- **Wizard NEVER auto-applies.** User MUST type `y` at step 12.
- **Wizard preview MUST show real generated content, not placeholders.** A wizard that previews `<TODO>` is broken.
- **Wizard answers MUST roundtrip with `--refresh`.** A second `/setup-project --refresh --wizard` reads `_wizard-answers.yaml` and pre-fills defaults.

---

## 🔗 How the 7 capabilities compose

These features compose multiplicatively, not additively:

- **Versioning + Telemetry** = trend analysis ("setup was 95/100 in March, 87/100 today — what regressed?").
- **Schema validation + Wizard** = wizard refuses to apply if previewed config fails schema.
- **Failure catalog + Decision engine** = architectural agents propose new patterns aware of past failures.
- **Factories + Multi-language** = generated factory classes have Arabic JSDoc when `--lang=ar`.
- **Health score + Failure catalog** = health degrades if failures-not-cited grows (proxy for "team learning isn't applied").

The full pipeline with all 7 active:

```
/setup-project --refresh --wizard --lang=ar --validate-schemas
   ↓
   Phase 0:  backup + extract (REFRESH)
   Phase 1:  detect mode + version drift check
   Phase 2.6: profile-informed coverage gap + failure-catalog cross-check
   Phase 2:  profile codebase + load failure index + load extract
   Phase 2.y: WIZARD prompts in Arabic, 12 steps, mock previews
   Phase 3:  plan with version-stamps + schema preview
   Phase 4:  apply (regen + factory generation per domain)
   Phase 4.7: bilingual headers in CLAUDE.md / AGENTS.md
   Phase 5:  presence + self-consistency + SCHEMA validation + dry-invoke
   Phase 5+: health score computed + telemetry entry written
   Phase 6:  learning loop active forever
```

---

Treat this as the command's vocabulary. Everything referenced in the flow is catalogued here.

> **Terminology lock** (see Appendix F Glossary for full definitions):
> - **Track** — a discipline-shaped pack (backend / frontend / security / etc.). 15 total.
> - **Technical signal** — a cross-cutting tech concern detected in code (multi-tenant, payment, AI). Triggers tooling generation.
> - **Business domain** — what KIND of product the project is (ecommerce / lms / fintech). Drives entities, flows, compliance.
> - **Pack** — `~/.claude/templates/packs/<track>/` directory with `agents/`, `commands/`, `skills/`, `rules/`, `ai-patterns/`, `references/`.
> - **Tool adapter** — per-AI-tool config generator (claude-code / cursor / aider / opencode / ...). 10 total.
>
> The word "domain" is OVERLOADED — always qualify it: "technical signal" or "business domain". Never bare "domain".

