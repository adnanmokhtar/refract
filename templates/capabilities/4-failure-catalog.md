---
artifact: capability-4-failure-catalog
purpose: Failure catalog (B10). Architectural agents inject ai/failures/_index.md; entries append-only; supersede via ADR.
imported-by: templates/capabilities.md (index), commands/setup-project.md (orchestrator)
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

