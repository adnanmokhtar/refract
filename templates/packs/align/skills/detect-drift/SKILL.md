---
name: detect-drift
description: Stack-conditional drift detector for codebase alignment. Runs the 11 universal detectors (6 structural + 5 functional — SOLID, clean code, performance, security, unhandled-io) plus per-stack detectors against the gold-standard inventory. Emits a finding row per fingerprint hit with evidence cited to <path:line>. Used by /align-scan and /align-fast.
kind: skill
pack: align
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: detect-drift

## Purpose

Detect deviations between the codebase's current state and its intended state (the gold-standard inventory in `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md`). Emit one finding per detected fingerprint, with `<path:line>` evidence. The finding is then routed by `/align-plan` into a phase and fixed by the per-finding loop.

This skill is the **detector** half of alignment. The fix half is `find-and-align`.

## When to use

- Dispatched by `/align-scan` for the initial sweep.
- Dispatched by `/align-phase` at DETECT step (re-verify a finding's fingerprint is still present before fixing).
- Dispatched by `/align-final --re-scan` to surface new drift since the last scan.
- Dispatched by `/align-fast` for both initial scan + per-row re-detect.

## Inputs (precise contract)

| Input | Source | Required |
|---|---|---|
| Codebase root | Orchestrator | YES |
| `PROJECT_KIND` | `_extracted-codebase.md § Gold standards` | YES |
| `_extracted-idioms.md` summary (≤ 5K tokens) | Built by orchestrator; passed by reference | YES |
| `ai/conventions.md` | Project | NO (drift class skipped if missing) |
| `ai/architecture.md` | Project | NO (drift class skipped if missing) |
| Per-class detector tool name | `_extracted-codebase.md § Gold standards` | YES (per class) |
| Class filter (optional) | Caller flag | NO (default: all 11 universal + stack-conditional) |
| Scope filter (optional) | Caller flag | NO (default: full repo) |
| Max-findings-per-class cap (optional) | Caller flag | NO (default: unlimited) |

## Outputs (precise contract)

A finding-draft array — ONE row per detected fingerprint. Each row:

```yaml
class: <one of: dead-code | duplicated-logic | reinvented-wrapper | silent-catch |
                over-abstraction | drift | solid-violation | clean-code |
                performance | security | unhandled-io | stack-specific>
subclass: <optional sub-classification, e.g.:
           "SRP" | "OCP" | "LSP" | "ISP" | "DIP" for solid-violation
           "long-function" | "deep-nesting" | "magic-number" | "bad-naming" for clean-code
           "n-plus-one" | "sequential-await" | "missing-cache" | "missing-index" |
              "select-star" | "in-app-filter" | "sync-http-hotpath" for performance
           "missing-auth-gate" | "sql-injection" | "xss" | "secret-in-code" |
              "unsafe-deserialize" | "missing-validator" | "vuln-dep" |
              "tenant-isolation-gap" | "csrf" | "rate-limit" for security
           "a11y-violation" | "design-token-drift" | "i18n-key-drift" |
              "raw-library-component" | "missing-ui-state" | "motion-drift" |
              "responsive-drift" | "lifecycle-hook-wrong" | "default-true-prop" |
              "permission-gate-drop" for stack-specific frontend>
severity: <required for security only: low | medium | high | critical>
evidence: [<path:line>, ...]                # at least 1; each MUST resolve to real file at HEAD
scope: [<path>, ...]                        # files the fix would touch
closure_verb: <one of 21 verbs in the closed vocabulary>
shared_equivalent: <required for replace-with-shared: <path> in _extracted-idioms.md>
idiom_cited: <required for functional verbs that add lines: <path:line> in _extracted-idioms.md>
tier_suggestion: <trivial | standard | heavy>
tier_reason: "<1-line justification per tier promoter rules in align-discipline.md>"
detected_at: <iso-timestamp>
detector: <name of the detector tool that surfaced this finding>
```

Side effect: writes a deferred-fingerprints file (`ai/align/_deferred.md`) listing fingerprints exceeded by `--max-findings-per-class` cap. These are picked up by the next scan run.

The orchestrator (`/align-scan`) merges these into the canonical ledger, assigning stable ids (A001, A002, ...).

## Procedure

### Step 0: Pre-flight

1. Confirm `_extracted-idioms.md` is non-empty. If empty, halt and route to `/setup-project --refine`.
2. Confirm PROJECT_KIND is recognised. If unknown, fall back to universal-only.
3. Build the 5K shared context blob (idioms summary + conventions summary + architecture summary). Pass by reference to all detector subagents.

### Step 1: Structural detectors (parallel)

#### Detector 1: dead-code

**Tool**: dispatch `dead-code-finder` agent (full repo) OR run the project's tree-shake / unused-export tool (`ts-unused-exports`, `pyflakes`, `unimport`, `staticcheck` etc.).

**Procedure**:
1. List all exported symbols across the codebase.
2. For each symbol, grep for inbound imports. If 0 inbound imports, the symbol is dead.
3. List all conditionals where the condition is statically false (`if (false)`, `if (process.env.NEVER_SET)`, etc.).
4. List all unreachable returns / branches after a guaranteed-throw / guaranteed-return.

**Closure verb suggestion**: `remove`.

**Tier**: trivial (unless the dead symbol is an exported public API → standard).

**Output**: `<path:line>` per dead symbol / branch.

#### Detector 2: duplicated-logic

**Tool**: project's duplicate detector (`jscpd` / `pylint --enable=duplicate-code` / `dupl` etc.) with min-token threshold = 50.

**Procedure**:
1. Run the duplicate detector. Output: cluster of duplicate ranges across files.
2. For each cluster, identify the canonical copy (the one in `_extracted-idioms.md` OR closest to the project's shared root).
3. If no canonical exists in idioms, halt this row → "missing idiom" (route to `/setup-project --refine` to add).

**Closure verb suggestion**: `dedupe` (replace non-canonical copies with the canonical).

**Tier**: trivial (unless dedupe touches > 3 files → standard).

**Output**: `<file-A:line>` ↔ `<file-B:line>` ↔ ... for each cluster.

#### Detector 3: reinvented-wrapper

**Tool**: grep against fingerprints derived from `_extracted-idioms.md`.

**Procedure**:
1. For each named wrapper in `_extracted-idioms.md` (e.g., the project's button wrapper wraps a raw button from the project's UI library), derive the fingerprint of the underlying raw component (the import path / module reference / tag name that pulls the raw component — concrete shape varies by stack).
2. Grep the codebase for the fingerprint at non-shared call sites (i.e., outside the wrapper file itself).
3. Each hit is a finding.

**Closure verb suggestion**: `replace-with-shared`.

**Tier**: standard (typically — replace-with-shared touches all call sites).

**Output**: `<path:line>` for each hit + the named shared equivalent.

#### Detector 4: silent-catch

**Tool**: grep.

**Procedure**:
1. Grep for the project's empty-catch idioms:
   - JS/TS: `catch\s*\(?[^)]*\)?\s*{\s*}`, `catch\s*{\s*//.*\bsilent\b`
   - Python: `except\s*[A-Z]\w*\s*:\s*pass`
   - Go: `if err != nil { _ = err }`
   - Other: per project's idioms in `_extracted-idioms.md`.
2. Each hit is a finding.

**Closure verb suggestion**: `replace-with-shared` (route through the project's error handler) OR `remove` (let it throw).

**Tier**: trivial.

**Output**: `<path:line>` per match.

#### Detector 5: over-abstraction

**Tool**: dispatch `refactorer` agent in detect-only mode OR grep.

**Procedure**:
1. List all wrapper classes / factories / strategies in the codebase.
2. For each, grep for inbound consumers. If 1 consumer, the wrapper is over-abstracted.
3. List all functions with `options: { foo?: bool }` parameters where every caller passes the same value.
4. List all comments-as-rename: `// gets the user` immediately above `function getUser()`.

**Closure verb suggestion**: `inline` (fold wrapper into single call site) OR `rename-comment-out` (delete redundant comment).

**Tier**: trivial (single inline) or standard (collapses public abstraction).

**Output**: `<wrapper-path:line>` ↔ `<single-call-site-path:line>` per pair.

#### Detector 6: drift-from-gold-standard

**Tool**: cross-reference `ai/conventions.md` + `ai/architecture.md`.

**Procedure**:
1. For each documented convention (e.g., "data access goes through the repository pattern"), derive the anti-fingerprint (e.g., raw ORM calls in service-layer files).
2. Grep the codebase for the anti-fingerprint.
3. Each hit is a finding.

**Closure verb suggestion**: `replace-with-shared` (use the convention) OR `remove`-and-relocate (move to the right layer).

**Tier**: standard (typically — drift findings span multiple files).

**Output**: `<deviating-path:line>` + the convention being violated.

### Step 2: Functional detectors (parallel)

#### Detector 7: SOLID violation

**Tool**: dispatch `refactorer` agent with `--focus=solid` mode OR project's complexity / responsibility metrics tool.

**Procedure**:
1. **SRP**: list all classes/modules with > 1 named responsibility. Use:
   - File length > project's threshold (per `ai/conventions.md`).
   - Class with > N public methods covering > 1 noun-domain (e.g., `UserService` with `processPayment` is multi-responsibility).
2. **OCP**: list modifications to closed modules (modules whose `_extracted-idioms.md` declares them "closed" / "extension-only"). Each modification of a closed module is an OCP violation.
3. **LSP**: compare interface signatures to overrides. Flag overrides that:
   - Strengthen pre-conditions (require more than the interface).
   - Weaken post-conditions (return less than the interface promises).
   - Throw exceptions the interface doesn't declare.
4. **ISP**: list interfaces with > N members where M consumers use only K < N. The interface is too fat.
5. **DIP**: list high-level modules that import concrete (not abstract) low-level dependencies, where the abstraction exists in `_extracted-idioms.md`.

**Closure verb suggestion**: `split-extract` (SRP) / `inline` (collapse useless interface; ISP) / `replace-with-shared` (depend on abstraction; DIP).

**Tier**: standard if shared module; heavy if widely-consumed; trivial if private internal.

**Output**: `<path:line>` per violation + the SOLID-letter sub-classification.

#### Detector 8: clean-code

**Tool**: project's complexity tool (`eslint-plugin-complexity` / `radon` / `gocyclo` / `flake8 --max-complexity` / `rubocop`) with thresholds from `ai/conventions.md`.

**Procedure**:
1. Run the complexity tool. Output: function-level complexity / nesting / length scores.
2. For each function exceeding threshold, emit a finding.
3. Grep for magic numbers (numeric literals > 1 outside test files; non-zero non-trivial strings used in domain logic).
4. Grep for identifier names violating the project's naming convention (camelCase vs snake_case mismatches, ambiguous names like `data`, `temp`).
5. Grep for comment-as-rename patterns.

**Closure verb suggestion**: `extract-to-shared` (long function, body moves to existing service) / `inline-magic-to-named-const` (magic) / `rename` (naming) / `rename-comment-out` (redundant comment).

**Tier**: trivial (most cases) / standard if the rename touches public API.

**Output**: `<path:line>` per violation + the threshold violated.

#### Detector 9: performance

**Tool**: dispatch `performance-optimizer` agent (named in `performance/agents/` — NOT `code-quality/agents/`; it has never lived there). If the performance pack is not loaded, fall back to the project's profiler / query log; the row still requires a baseline in `notes`. For each candidate:

**Procedure**:
1. **N+1**: detect request handlers that call the same DAO method per loop iteration (`for (id of ids) { await getUser(id) }`).
2. **Sequential await**: detect `for await ... of ...` or `for { await }` loops where ops are independent (no shared mutable state).
3. **Sync HTTP in hot path**: detect `axios.get` / `fetch` / `requests.get` calls in route handlers / per-request paths.
4. **Missing cache**: detect idempotent reads called > 3× per request without a cache layer (cross-ref `_extracted-idioms.md` for the project's cache primitive).
5. **Missing index**: cross-ref query shapes against existing index migrations. Detect queries with `WHERE` / `ORDER BY` not covered by an index.
6. **`SELECT *` consumed by < 5 fields**: parse query → consumer; detect under-projection.
7. **In-app filter**: detect `.filter()` immediately after a query result that could push the filter to the database.

**Closure verb suggestion**: `parallelize` / `batch` / `cache-with-explicit-ttl` / `add-index` / `project-columns` / `inline-filter-to-query`.

**Tier**: standard for hot-path; trivial for cold-path; heavy if ships an index migration.

**Output**: `<path:line>` per perf finding + V1-cost (queries × latency) + V2-estimate.

#### Detector 10: security

**Tool**: dispatch `security-auditor` agent + `deps-audit` skill (named in `security/agents/` + `security/skills/`).

**Procedure**:
1. **Missing auth gate**: cross-ref protected route definitions against the project's auth gate from `_extracted-idioms.md`. Detect routes without the gate.
2. **SQL injection**: grep for string concat / template literal interpolation in raw SQL.
3. **XSS**: grep for unescaped user input rendered to HTML (`innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `safe` filter explicitly applied to user input).
4. **Secret in code**: entropy analysis on string literals (`> 4.0 entropy + length > 16` flags) + known patterns (API keys, AWS access keys, OAuth tokens, database URIs with creds).
5. **Unsafe deserialization**: grep for `pickle.loads(user_input)`, `eval(user_input)`, `Function(user_input)`, `yaml.load(user_input)` (without `Loader=SafeLoader`).
6. **Missing validator**: cross-ref API boundaries (route handlers) against the project's validator helper from `_extracted-idioms.md`. Detect handlers without validation.
7. **Vulnerable dependency**: run `deps-audit` skill (`npm audit` / `pip-audit` / etc.). Each CVE-flagged package is a finding.
8. **Tenant isolation gap** (multi-tenant projects): grep for queries without tenant filter (the project's tenant primitive named in `_extracted-idioms.md`).
9. **CSRF gap**: cross-ref state-mutating endpoints against the project's CSRF middleware.
10. **Rate-limit gap**: cross-ref auth endpoints against the project's rate-limiter from `_extracted-idioms.md`.

**Closure verb suggestion**: `add-gate` / `parameterize` / `escape` / `move-to-secrets` / `add-validator` / `replace-with-shared` (for unsafe deserialize) / `bump-dep`.

**Severity classification**:
- **Critical**: SQL injection on production endpoint, secret-in-committed-code, RCE vector, auth bypass.
- **High**: missing auth gate on user-data endpoint, XSS on user-facing page, missing validator on PII boundary.
- **Medium**: missing rate-limit, CSRF gap on non-critical endpoint, tenant-isolation gap on read-path.
- **Low**: vulnerability advisory in transitive dependency with no exploitable path.

**Tier**: standard floor for security; critical → heavy; high → standard or heavy depending on exposure.

**Output**: `<path:line>` per security finding + severity + the gate/escape/validator/secret that should wrap the site.

#### Detector 11: unhandled-io (happy-path-only I/O)

**Tool**: grep + caller-chain trace against the project's I/O primitives from `_extracted-idioms.md`.

**Procedure**:
1. **Enumerate I/O call sites**: grep for the project's HTTP client, DB primitive, queue producer/consumer, file I/O, external-process spawn (concrete primitive names from `_extracted-idioms.md` — never generic `fetch(`-style greps when the project has a named client).
2. **Classify each site**: routed through the project's wrapped I/O primitive / error boundary? → not a finding. Raw call?
3. **Trace the failure path for raw calls**: is the error surfaced — handler call, error-return checked, rejection awaited-and-handled, UI error state wired? Does the medium need a timeout and is one set?
4. **Cross-check the caller chain before flagging**: a raw call whose CALLER handles the rejection is NOT a finding (cite the handling site in `notes`); a raw call whose only "handler" is a top-level crash logger IS one.
5. **Skip frontend fetch-in-component sites** — those belong to the `missing UI state` sub-class (frontend stack-conditional detector). This universal detector covers the non-UI layers: services, jobs, queue handlers, CLI paths, scripts.

**Closure verb suggestion**: `replace-with-shared` (route through the project's wrapped I/O primitive — the wrapper provides the error path / timeout / failure surfacing). If no wrapped primitive exists for that I/O medium: halt → `/setup-project --refine`; do NOT hand-roll per-site try/catch.

**Tier**: standard floor for hot-path or user-facing call sites; write-path I/O (DB mutation / queue publish / payment) ALWAYS ≥ standard; trivial only for dev-tooling / one-time-script paths.

**Output**: `<path:line>` per unguarded call site + the wrapped primitive it should route through.

### Step 3: Stack-conditional detectors (parallel)

For `PROJECT_KIND in {frontend-*}`:
- Dispatch `accessibility-auditor` (a11y).
- Dispatch `i18n-auditor` (i18n key drift).
- Dispatch `data-flow-auditor` (UI state coverage).
- Dispatch `design-token-audit` skill (token drift).
- Dispatch `motion-audit` skill (motion drift).
- Apply `frontend/rules/migration-frontend.md` fingerprint set (lifecycle hooks, default-true wrapper props, permission-gate drop, raw library components).

For `PROJECT_KIND in {backend-*}`:
- Dispatch backend-specific detectors per `backend/rules/migration-backend.md` (tenant-gate-missing, transaction-boundary, query-without-tenant-filter).

For `PROJECT_KIND in {data-*}`:
- Dispatch data-pipeline detectors (column-projection-mismatch, idempotency-key-missing, sync-http-in-batch).

For `PROJECT_KIND in {mobile-*}`:
- Dispatch `mobile/skills/native-bridge-audit/SKILL.md`.

### Step 4: Merge findings

The orchestrator collects all detector outputs and merges them into a single findings-draft array. Sequential to avoid row-id collisions.

For each finding:
- Assign a stable id (A001, A002, ...).
- Validate evidence resolves.
- Validate `idiom_cited` resolves (for functional verbs).
- Set initial `tier` per the discipline rule's tier promoter rules.
- Set `status: detected`.

## Halts

- **Empty oracle** (`_extracted-idioms.md` missing/empty) → halt; route to `/setup-project --refine`.
- **PROJECT_KIND unknown** → halt; surface; offer universal-only fallback.
- **Detector tool missing** (e.g., `jscpd` not installed) → halt; surface install command.
- **A row's evidence doesn't resolve** at validation time → drop the row; log as detector error.
- **Hand-wave token in any field** → halt; the detector is mis-configured.

## Reductions — what to report when a detector cannot run

A halt stops everything. A **reduction** runs fewer detectors and must say so, because a detector that did not run and a detector that found nothing produce the identical output — zero rows — and only one of them is good news.

| Condition | Effect | Line this skill MUST emit |
|---|---|---|
| `ai/conventions.md` and `ai/architecture.md` both absent | Detector 6 (`drift`) cannot run — drift is deviation from a **documented** convention, and there is no document | `SKIP — drift NOT RUN (no ai/conventions.md / ai/architecture.md)` |
| A per-class tool absent where the caller passed `--continue-on-missing-tool` | that one detector does not run | `SKIP — <class> NOT RUN (<tool> absent: <install command>)` |
| `--class-filter` or `--scope` narrowed the run | fewer detectors, or less source | `SCOPED — <N> of 11 universal detectors, scope <path>` |
| A file exceeds the large-file sampling threshold | partial read | `PARTIAL-READ — <path>: <N> lines, read <ranges>` |

**The final line of every run is `RAN <N> of 11 universal detectors`**, and any `<N>` below 11 is immediately followed by its reasons. A caller that receives zero `drift` rows is entitled to know whether that means "no drift" or "drift was never looked for". See `ai/patterns/align-guardrails.md § The eight realism guards` for the guard names to cite.

### Detector 6 special case — the bimodal convention

The most common reason a team runs this skill is "half our modules do X and half do Y". That is **not** drift: drift needs the oracle to name a winner, and here it names neither. Detector 6 emits a **non-finding report** — no ledger rows, because there is no closure verb for a convention that does not exist yet:

```
BIMODAL CONVENTIONS (0 rows — no oracle entry to align to)
  <concern>   shape A: <N> sites (<representative path:line>)
              shape B: <M> sites (<representative path:line>)
              oracle names: neither
  Route: /setup-project --refine  (adopt one, then re-scan — the N+M sites become drift rows)
         /polish                  (if neither shape is right)
```

Emitting these as `drift` rows would make align pick a convention by majority vote. Choosing a convention is introducing one, which is `/polish`'s job and not this skill's — the boundary `@align-idiom-auditor` exists to hold.

## Hard rules

- **A finding is a fingerprint you found, not a pattern you expect.** Every emitted row carries `<path:line>` evidence that resolves at the pinned commit and contains the fingerprint the row claims. A row derived from "this codebase probably has…" is fabrication, and it is worse than a miss because it consumes a fix loop.
- **One fingerprint, one row.** Never `~8 dead exports` or `several silent catches`. If a cap forces you to stop, emit the rows you found and write the remainder to `ai/align/_deferred.md` with a count — a cap is a reduction, not a summary.
- **Class before verb.** Choose the class from the fingerprint, then take the verb from the class. Choosing a verb first is how a `security` row acquires a structural verb and inherits a `net-lines ≤ 0` rule its fix cannot satisfy.
- **Never invent an idiom to cite.** `shared_equivalent` and `idiom_cited` name entries that exist in `_extracted-idioms.md`. If the fix would need a primitive the oracle does not have, that is a missing-idiom halt for that row — not a row that cites a plausible-sounding path.
- **Read-only, always.** This skill writes exactly one file (`_deferred.md`) and never touches source, ledger or oracle. A detector that edits what it measures has no findings, only consequences.
- **Report the denominator.** Every run ends with `RAN <N> of 11`. Silence about what was skipped is the Trusted Summary with a mechanical cause.

## Failure modes

- **Detector returns zero rows for a class that clearly has instances** — usually the fingerprint was derived from a generic pattern (`fetch(`) rather than the project's named primitive from `_extracted-idioms.md`. Re-derive from the oracle; a generic grep on a project with a named client finds nothing and reports clean.
- **Detector returns hundreds of rows for one class** — clean-code and duplicated-logic dominate first sweeps. This is the scope cap firing, not a bug; emit up to the cap, defer the rest, and say so. Reporting 400 rows is as useless as reporting none.
- **Evidence resolves at scan time but not at fix time** — another PR landed. This is expected on an active repo, which is why `/align-phase` re-detects before fixing. Do not treat a stale row as a detector error; it is an aged-out finding.
- **The same site is flagged by two detectors** (a silent catch inside a duplicated block; an unvalidated input that is also an unhandled I/O call). Emit both rows with distinct classes and let `/align-plan` phase them; merging them into one row hides one of the two fixes, and closing one does not close the other.
- **`_extracted-idioms.md` exists but is a stub** — present and near-empty passes the emptiness check while providing no oracle. Every `replace-with-shared` and `dedupe` row then halts on missing-idiom. Three or more such halts in one run is `The Idiom Inventory Gap`; say so once, at the top, rather than as N identical row-level halts.
- **PROJECT_KIND misidentified** — a frontend project detected as backend silently drops five stack-conditional detectors. The `RAN <N> of 11` line will look correct because the universal set did run; the stack line is the one to check.

## Notes

- This skill is **read-only**. It writes nothing to disk. The orchestrator persists the findings.
- Detectors run in parallel waves (structural / functional / stack-conditional). Within a wave, dispatch up to `--max-subagents` (default 5).
- Each detector reads ≤ 5K tokens of shared context, NOT the project's full source. Per-detector source reads are scoped to the file the detector is currently inspecting.
- Re-running this skill is idempotent — running twice on the same codebase produces the same findings.

## Related

- `/align-scan` — primary dispatcher.
- `/align-fast` — also dispatches.
- `/align-phase` — dispatches at DETECT step.
- `find-and-align` skill — the per-finding fix loop (sibling).
- `align-discipline.md` — the rule this skill enforces.
