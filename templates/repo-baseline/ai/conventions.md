# Conventions

The full convention reference for this project. **Tier 3** — load on demand when `ai/_convention-cheatsheet.md` (Tier 2) isn't enough. Auto-populated at `/setup-project` from `.claude/_extracted-codebase.md § Conventions`; hand-edited as the team makes new decisions.

> **All `<...>` placeholders below are filled at setup time from THIS codebase's actual extraction.** Do NOT copy concrete identifiers (class names, library names, suffixes) from another project's `conventions.md` into this one — every value below must trace to `.claude/_extracted-codebase.md` for THIS project. The leak-marker scan (Phase 5.3.5) refuses runs where a generated file cites identifiers not in extraction.

Last updated: <YYYY-MM-DD>

---

## Tier guidance (when to read what)

| Reading need | Load |
|---|---|
| Fast bootstrap (every session) | `ai/_session-digest.md` |
| Code-edit task — match local style | `ai/_convention-cheatsheet.md` (top 20 rules) |
| Convention not in the cheatsheet OR cheatsheet ambiguous | this file |
| Reasoning about why a rule exists | the cited ADR in `ai/decisions/` |

## Scope — how many answers does each section have?

Read `.claude/codebase-profile.md § 17` (`repo_shape` + `members`) before filling anything below.

| `repo_shape` | How the sections below are filled |
|---|---|
| `single` (one member) | One value per row. Delete the per-package matrix section that follows. |
| `monorepo` / `workspace` (N members) | **One row per member** in the matrix below. Every section that describes *code* — file naming, identifiers, folders, imports, errors, logging, validation, tests, concurrency — is answered once per member. |

> **Never average two packages into one convention.** A repo whose server package names files one way and whose client package names them another has TWO conventions, not one blended winner. A blended value is wrong for *both* packages while carrying the confidence of a measured one — and because this file feeds `ai/_convention-cheatsheet.md` and the `## Project-specific` block of every adapted rule, the wrong value propagates into every artifact and every agent then "corrects" conforming code toward a convention that exists nowhere in the repo. If the members disagree, that disagreement IS the content. Record one value only after checking every member and finding they genuinely agree.

## Per-package conventions

Fill when `repo_shape` is `monorepo` or `workspace`; **delete this whole section when `repo_shape: single`.** One row per member from `.claude/codebase-profile.md § 17 members`. Where a column is genuinely identical across every member, collapse it to one `all packages` row — but only after checking each member, never by assumption.

| Package | Root | Stack | Source file naming | Test file naming | Classes | Functions | Constants | Alias root | Error base | Test framework |
|---|---|---|---|---|---|---|---|---|---|---|
| `<member-a>` | `<path>` | <lang + framework> | <naming> | <naming> | <case> | <case> | <case> | `<alias>` | `<Base>` | <framework> |
| `<member-b>` | `<path>` | <lang + framework> | <naming> | <naming> | <case> | <case> | <case> | `<alias>` | `<Base>` | <framework> |

**This matrix outranks the sections below.** Where a section states one value and a member's row disagrees, the row wins and the section reads `see per-package matrix` rather than a blended value. Sections that genuinely hold repo-wide — one formatter config governing the whole tree, one multi-tenancy boundary, the ADR links — stay single-valued and say so.

**Which member am I in?** Every rule below applies to the package containing the file being edited, resolved by longest-path match against the `Root` column. A file outside every member root (repo-level config, CI, scripts) follows the repo-wide sections only.

## File naming

- **Source files**: <e.g., kebab-case.ts / snake_case.py / PascalCase.cs — derived from extraction>
- **Test files**: <e.g., `*.spec.ts` colocated / `tests/test_*.py` mirrored — from extraction>
- **Migrations**: <e.g., `<NNNN>-<slug>.ts` / `<YYYYMMDDHHMMSS>_<slug>.py` — from extraction; OMIT if no DB>
- **Generated files**: <e.g., `*.generated.ts`, never hand-edited; from extraction>

## Identifier naming

- **Classes**: <PascalCase | snake_case (in Python) | …>
- **Functions / methods**: <camelCase | snake_case | …>
- **Constants**: <SCREAMING_SNAKE_CASE | const camelCase | …>
- **DB columns**: <snake_case | camelCase | …>  (OMIT if no DB)
- **DI tokens**: <Symbol-based | string-constant | framework-native — `@Injectable` / `@Bean` / `@Component` / …>
- **Test helpers**: <`make<Entity>` factories | `<Entity>Factory.build()` | …>

## Folder structure

```
<src/>
├── <layer-1>/         # <responsibility — derived from extraction>
├── <layer-2>/         # <responsibility>
├── <layer-3>/         # <responsibility>
└── <shared/>          # <only what's used by ≥2 callers>
```

Boundaries: which folders MUST NOT import from which? (Cross-link to `ai/modules.md § Module boundaries`.)

## Imports

- **Alias scheme**: <e.g., `@/` → `src/`, `@core/` → `src/core/` — derived from `tsconfig.json` / `pyproject.toml` / equivalent>
- **Order**: <node_modules → aliases → relative — from extraction or formatter config>
- **Forbidden**: <wildcard imports, deep imports through internals, cross-module imports without facade>

## Errors

- **Base class hierarchy**: `<DetectedBase>` at `<path>` — extends to <DomainError, InfraError, ValidationError, …>
- **HTTP mapping** (if applicable): <`status_code` per error type — from extraction>
- **Never throw**: <generic `Error` / `Exception` — must use project hierarchy>
- **Catch policy**: every `catch` must (a) route through `<project-error-handler>` OR (b) include a comment explaining recovery + log at debug level. **No silent catches.** (See `templates/packs/migration/rules/migration-discipline.md § The Silent Catch`.)

## Logging

- **Logger**: <name@version — `pino` / `winston` / `loguru` / `slf4j` / `zap`>
- **Levels in use**: <trace / debug / info / warn / error / fatal — actual subset>
- **Structured fields convention**: <camelCase keys / specific field names like `requestId`, `tenantId`, `userId`>
- **NEVER log**: <secrets, full PII, tokens, full request bodies on error paths>
- **NEVER use**: <`console.log` / `print` / `System.out.println` — debug primitives banned>

## Validation

- **Library**: <class-validator / Zod / Pydantic / Joi / Marshmallow — from extraction>
- **Where**: <controller boundary / service boundary / both — from extraction>
- **DTO convention**: <`Create<Entity>Dto` / `<Entity>Schema` / `<Entity>Request` — from extraction>

## Tests

- **Framework**: <vitest / jest / pytest / rspec / junit — from manifest>
- **Location**: <colocated `*.spec.ts` next to source / mirrored `tests/` tree / `__tests__/` per module>
- **Naming**: <pattern from extraction>
- **What's required**: <unit for every service method? E2E for every endpoint? — from extraction or team agreement>
- **Coverage threshold**: <%age — from CI config OR "advisory only">
- **Factories**: <FactoryBot / factory_boy / fishery / hand-rolled — from `test/factories/` if shipped>

## Base classes / inheritance patterns

(Only fill this section if the project uses inheritance bases. OMIT entirely for functional / module-style codebases.)

| Base | Path | Extenders | Purpose | Pattern doc |
|---|---|---|---|---|
| `<BaseName>` | `<path>` | <count> | <one line> | `ai/patterns/<name>.md` |

## Concurrency / async

(Only fill if the runtime is async-by-default — Node, Python-async, Go, Java, .NET. Omit for sync-by-language stacks.)

- **Primitive**: <`Promise.all` / `asyncio.gather` / goroutines + channels / virtual threads>
- **Bounding**: <`pLimit(N)` / `asyncio.Semaphore(N)` / WaitGroups>
- **Default for independent I/O**: <bounded parallel — never sequential `await`>
- **Forbidden**: sequential `await` of independent operations (see `templates/packs/backend/rules/concurrency-discipline.md`)

## API contract conventions

(Only fill if the project exposes an API surface.)

- **Style**: <REST / GraphQL / RPC / hybrid>
- **Versioning**: <prefix `/v1/` / header `Accept-Version` / never — from extraction>
- **Response envelope**: <`{ data, error }` / raw / `Result<T, E>` — from extraction>
- **Pagination**: <cursor / offset / page+size — from extraction>
- **Auth**: <JWT / session / OAuth / API key — see `ai/decisions/<NNNN>-auth.md`>

### Cross-stack contract verification

Fill when this repo contains BOTH a producer and a consumer of the same API — a server package and a client package in one tree, or an API this repo publishes and also calls. **A fullstack repo has the same producer/consumer seam a multi-repo workspace has, minus the repo boundary that makes it visible** — which makes it easier to break, not safer.

- **Producer → consumer pairs**: `<producer-member>` serves `<consumer-member>` at `<base path>`. List every pair; a consumer nobody remembered is how a contract change ships broken.
- **Verification mechanism**: <generated types from the spec / consumer-driven contract test / shared type package imported by both / NONE — hand-written client types>
- **Where it runs**: <CI job name / pre-commit hook / manual — from the pipeline config>

Three rules, whatever the mechanism:

1. **Classify every contract change `additive` or `breaking` before editing either side**, and grep the whole tree for consumers first — including packages you are not editing. Removing or renaming a response field, changing its type, adding a required input field, or changing an error code are all breaking, regardless of how small the diff looks.
2. **Verify the consumer against the producer's SHIPPED shape, not the spec on paper** — generated or type-checked types, a real call, or a contract test. *A green consumer build alone does not prove the shapes match*: a hand-written client type compiles perfectly against a field the server stopped sending, and fails at runtime in front of a user.
3. **Producer ships first and backward-compatible.** A change that requires both sides to land at once is forbidden even inside one repo — deploys are not atomic, and a rollback of one side leaves the other broken.

If the mechanism is `NONE`, that is a **known gap, not a passing state**: every contract change is verified by hand and by memory. Record it in `ai/status.md` as a risk rather than leaving this row blank, so the next person reads "unverified" instead of "fine".

## i18n / localization

(Only fill if the project ships in >1 locale.)

- **Library**: <i18next / vue-i18n / Django translations — from extraction>
- **Locale files**: `<path>` — every key must exist in every locale (parity check)
- **Fallback**: <`en` / `<base-locale>` — from extraction>
- **Convention**: <bare keys vs full strings; namespace per module / global namespace>

## Multi-tenancy

(Only fill if the project is multi-tenant.)

- **Boundary**: <row-level / schema-per-tenant / DB-per-tenant — from `ai/decisions/<NNNN>-multi-tenancy.md`>
- **Tenant resolution**: <middleware-extracts from JWT / subdomain / header — from extraction>
- **Auto-filter mechanism**: <repository base auto-applies / explicit per-query — from `ai/patterns/multi-tenancy.md`>
- **Bypass rules**: <when admin queries can cross tenant — must cite the ADR>

## Code style (formatter-driven, never debate)

These come from the formatter config (`.prettierrc`, `pyproject.toml`, `.editorconfig`). Don't argue them — run the formatter:

- **Quotes**: <single / double — from formatter>
- **Indent**: <2 spaces / 4 spaces / tabs — from formatter>
- **Line width**: <80 / 100 / 120 — from formatter>
- **Trailing commas**: <yes / no / multiline-only>
- **Semicolons / line endings**: <as the formatter says>

## How to add a convention

1. Notice an emerging pattern (3+ occurrences) in `ai/dynamic/learned-patterns.md`.
2. Decide whether to formalize: open `ai/dynamic/decisions-pending.md`.
3. If formalized: write the rule here AND update `ai/_convention-cheatsheet.md` (top 20).
4. If contradicting an existing rule: write an ADR at `ai/decisions/<NNNN>-<slug>.md` AND update both files.
5. Run `/audit-knowledge` (or wait for `knowledge-curator`) to regenerate the cheatsheet + session digest from the new rule.

## Anti-leak (the failure mode this scaffold prevents)

A `conventions.md` populated from another project's extraction is a serious leak: it ships generic-sounding-but-wrong rules to your team and to every agent that reads it. The Phase 5.3.5 leak scan refuses runs where a citation here doesn't trace to `.claude/_extracted-codebase.md` for THIS project. If the cheatsheet says `BaseRepository` and your codebase has no such class, the extraction was empty (or another project's extraction leaked in) — STOP and re-run `/setup-project --refresh`.

## See also

- `ai/_convention-cheatsheet.md` — top 20, loaded by code-edit tasks (Tier 2)
- `ai/_session-digest.md` — top 5 conventions in the session bootstrap (Tier 1)
- `.claude/_extracted-codebase.md` — the ground-truth extraction this file projects (Tier 3)
- `.claude/_extracted-idioms.md` — base-class deep extraction (when applicable)
- `ai/decisions/` — ADRs that DECIDED a convention (cited from rule rows above)
- `ai/dynamic/learned-patterns.md` — emerging patterns (3+ occurrences) waiting to formalize
- `ai/dynamic/feedback-learned.md` — corrections that became conventions
