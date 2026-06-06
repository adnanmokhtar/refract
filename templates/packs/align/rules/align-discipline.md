# Align Rule: codebase alignment discipline

> **Project-specific values** — codebase root, gold-standard inventory, test runner, PROJECT_KIND, plus the architecture / conventions / findings-ledger paths — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Sourced from `.claude/_extracted-codebase.md § Gold standards` + `_extracted-idioms.md`. Do **not** edit those values here; edit the extraction sources and re-run `apply-anchors.sh` (or `/setup-project --refresh`) to propagate.

This rule governs every codebase-alignment sweep. It exists because the most common codebase-rot failure is **drift from the gold standard** — a project starts with clean conventions, then accretes one-off helpers, custom wrappers, silent catches, dead branches, and copy-pasted logic until "the codebase" and "the conventions" describe two different repos. Routine work surfaces N+1 papercuts that nobody fixes alone, but every refactor that *would* fix them gets pulled into a feature PR and cut for scope. The second most common failure is **scope creep during refactor** — a "small cleanup" becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed. The third most common is **trusted summary** — an executor delegates "is this code duplicated / dead / drift?" to a search agent, the agent says "looks fine" in confident summary language, and the executor echoes that into the alignment report without verifying the claim against source.

This rule is the universal contract — it must be enforceable by any AI tool. Tools with full capability (commands + agents + skills + hooks) compose the discipline by dispatching `/align-scan` → `/align-plan` → `/align-phase` → `/align-gate` → `/align-final` (with `/align-fast` as the one-shot equivalent). Tools with rules only (Aider, Codex, Gemini, partial: Cline, Windsurf) enforce the discipline by reading and following this file directly. Therefore: the complete discipline = THIS file + its two companion reference files (`references/align-discipline-procedures.md` + `references/align-discipline-catalogue.md`), which hold the verbatim procedural detail (split 2026-06-07 to respect the 40k-char always-on context limit). Every adapter bundle ships all three together; rule-only tools read all three as one discipline.

## Scope — what align covers (the comprehensive sweep)

Align is the codebase's quality gate. It covers every class of finding that affects the codebase's correctness, security, performance, structure, or maintainability — not just structural drift. The universal taxonomy spans:

1. **Structural** — drift from the gold-standard inventory (dead code, duplicated logic, reinvented wrappers, silent catches, over-abstraction, drift from `ai/conventions.md`).
2. **SOLID** — single-responsibility violations (god classes, multi-purpose modules), open/closed violations (modification where extension is the convention), Liskov violations (subtype contract breaks), interface-segregation violations (fat interfaces), dependency-inversion violations (high-level depending on low-level).
3. **Clean code** — long functions (> project's complexity threshold), deep nesting, magic numbers, poor naming, comment-as-rename, dead variables.
4. **Performance** — N+1 queries, sequential awaits where parallelism is safe, sync external HTTP in hot paths, missing caching at known-cacheable sites, missing index where the query shape demands one, `SELECT *` consumed by 4-field templates, in-app filtering where the database can filter.
5. **Security** — missing auth/permission gate on protected endpoints, SQL injection vectors (string concat in queries), XSS vectors (unescaped user output), secrets in committed code, unsafe deserialization, missing input validation at boundaries, vulnerable dependencies (CVE-flagged), tenant-isolation gaps in multi-tenant projects.
6. **Unhandled I/O failure (happy-path-only)** — I/O call sites (network / DB / queue / file) with no error path at all: no catch, no error-return check, no timeout, no failure state surfaced. The code works on the happy path and crashes/hangs on the first failure.
7. **Stack-specific** — for frontend, the UI/UX classes (a11y, design tokens, i18n, motion, lifecycle, default-true wrappers, permission gates); for backend, the data-layer classes (tenant-gate, transaction-boundary); for data, the pipeline classes (column projection, idempotency); for mobile, the bridge classes.

**What align does NOT cover** (route elsewhere):
- Behaviour-changing bugs (incorrect output, crash, wrong state) → `fix-bug` / dedicated tests.
- New features → feature-flow.
- V1→V2 ports (parallel codebases) → `/migration-*`.
- Architectural decisions (changing module boundaries, adopting a new framework) → `/refactor` + ADR.
- Release / deployment / infra → out of scope.

A finding's class drives:
- Which **detector** surfaces it (11 universal classes — 6 structural + 5 functional — plus per-stack extensions).
- Which **closure verb** fixes it (mechanical structural verbs OR small-+ functional verbs).
- Which **net-lines rule** applies (structural classes: ≤ 0 hard; functional classes: small + budget that must cite idioms).
- Which **tier promoter** triggers (security ALWAYS ≥ standard; critical-security ALWAYS heavy).

## Relationship to migration discipline

The align discipline is **migration discipline turned inward**. Migration ports V1 features to V2; align ports the codebase's *current shape* to its *intended shape* (the gold standards in `_extracted-idioms.md`). The same anti-patterns apply (Reinvented Wrapper, Silent Catch, Trusted Summary, Hand-waved enumeration), the same tiered floor (trivial / standard / heavy), the same atomic-fix discipline, the same gap-count parity rule (`gaps_in == gaps_closed`).

The differences:
- **No V1/V2 split.** One codebase. The "oracle" is `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md`, not a sibling V1 source.
- **No parity tests.** Existing test suites validate behaviour preservation. A finding-fix MUST NOT change observable behaviour (entropy-reducer, not redesigner — see `/simplify` § The Premise).
- **No cutover mechanism.** A finding is fixed in-place; no shadow / canary / feature-flag stage. Atomicity comes from one-finding-per-commit, not staged rollout.
- **No contract document.** Findings are scoped (one issue, one or few files, one closure verb). The contract is implicit: "after the fix, behaviour is unchanged AND the codebase is closer to the gold standard."

If a finding is large enough to need a parity test, a contract, a cutover plan, or a behaviour-change ADR — it is NOT an alignment finding. It is a migration / refactor / feature task. Mis-categorisation is the #1 way alignment sweeps creep into multi-week rewrites. Halt and route to the right surface.

## Required artifacts per finding — tiered floor

Every finding-fix produces an artifact set scaled to its actual risk. The discipline is **tiered**, not one-size-fits-all: a 1-line dead-import removal and a 25-file shared-component dedupe have different audit needs. Tier is set on the ledger row at scan time and propagates through the fix.

### Tier classification (set by scan; trivial-by-default for structural; ≥ standard for security)

| Tier | Triggers (any one promotes) | Required artifacts |
|---|---|---|
| **trivial** (DEFAULT for structural classes) | No promoter triggers AND class is NOT security | Ledger row + code edit |
| **standard** | 3–10 files touched OR cross-module symbol rename OR newly-introduced shared helper consumed by 3+ sites OR class is security (any severity) OR class is performance on a hot path OR class is SOLID violation in a shared module | Ledger row + code edit + 1-paragraph rationale in the row's `notes` |
| **heavy** | Any of: cross-package boundary change OR public API surface change OR removes a symbol used outside the module being aligned OR touches >10 files OR touches an auth / data / billing / migration path OR class is critical-security (auth bypass / SQL injection on production endpoint / secret-in-committed-code / RCE vector) OR perf change ships an index migration | Ledger row + code edit + rationale + impact analysis (file+line of every consumer) + reviewer-approved before merge |

**Rules**:
- **Default tier is trivial for structural classes** (dead-code, dups, reinvented-wrapper, silent-catch, over-abstraction, drift). Every structural finding starts at trivial UNLESS one of the standard / heavy promoters fires.
- **Security findings are NEVER trivial.** A missing auth gate, an SQL injection vector, an unescaped output — these are user-facing risks; the standard tier's rationale + reviewer attention is the floor. Critical security promotes to heavy automatically.
- **Performance findings start at standard for hot-path code; trivial for cold paths.** Hot-path = entry endpoints / request handlers / loop-bound code; cold-path = test setup / one-time scripts / debug builds.
- **SOLID violations in shared modules start at standard.** SOLID violations in private internals start at trivial.
- **Clean-code violations are typically trivial** unless the rename touches a public API name (then standard).
- Tier is **set by scan**, written to the ledger row's `tier:` field. Without explicit promoter triggers, structural rows stay trivial; security rows stay standard (or heavy for critical).
- Heavy tier requires either (a) a scan-flagged trigger above, OR (b) explicit user opt-in via `/align-phase <N> --heavy`.
- User can **upgrade** a tier (trivial → standard → heavy) anytime but cannot downgrade without a 1-line justification in the row's `notes`. Security row downgrade is forbidden — security never falls below standard.
- Scan MUST state the tier in 1 sentence citing trigger absence/presence per row.
- `/align-gate <N>` validates the artifact set **for the row's tier**, not the heavy floor universally.
- If a fix produces more than the tier requires, that's allowed but not required — the rule does not reward over-production.

## Anti-bloat rules

The migration discipline rule's Phase 7 lesson — "~95% docs / ~5% code on simple ports" — applies double here. Alignment is *by definition* small atomic edits. A doc-heavy alignment run is a category error.

- **Code edits are the deliverable.** A doc that doesn't enable a code change is waste. Rationales / notes exist when they unblock a code decision; they are not deliverables themselves.
- **The closure-verb vocabulary is finite.** Two semantic groups:
  - **Structural verbs** (used by structural classes; net-lines ≤ 0): `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`.
  - **Functional verbs** (used by functional classes; small + budget): `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`.
  A finding whose fix needs a verb outside this combined vocabulary IS NOT an alignment finding. Route to `/refactor` or `/setup-project --refine` instead. **No verb introduces a NEW abstraction not named in `_extracted-idioms.md`.** A `split-extract` that creates a brand-new abstraction (rather than splitting into responsibilities the project's idiom inventory already names) is forbidden.
- **Net-lines rule (split by class group):**
  - **Structural classes** — net-lines must be ≤ 0 per phase. Lines-removed ≥ lines-added across all structural findings, summed. A net-positive structural phase is a halt; the closure verb was applied wrong (likely a `replace-with-shared` that imported but didn't delete the local copy).
  - **Functional classes** — small + budget allowed (typically + 5 to + 30 lines per finding for security gates / validators / cache primitives / index migrations). The added lines MUST cite an idiom — every block of added lines references a `<path:line>` in `_extracted-idioms.md` (or the project's framework primitive) for what it's adding (the gate wrapper, the validator helper, the cache primitive, the safe deserializer). Validator: `check_added_lines_cite_idioms` walks the diff hunks and refuses any added block that doesn't cite an idiom.
  - **Cumulative phase rule** — for phases that mix structural + functional findings, the structural rows must net ≤ 0 AND the functional rows must each cite idioms. The phase's overall diff may net positive when functional findings dominate (a phase that adds 8 auth gates is + 16 lines net; that's allowed).
- **Per-finding enumeration is required at every tier.** Hand-waves (`etc.`, `...`, `and similar`, `N+ duplicates`, `several call sites`, `a few places`, `multiple endpoints`) HALT the gate. The validator's `check_no_handwaves` greps for these tokens. If 8 dead exports exist, the ledger lists 8 rows (or 1 row with 8 explicit `<path:line>` citations in `evidence`). Never `~8 dead exports`. Same applies to security findings: never `several missing auth gates` — each endpoint gets its own row.
- **Single-agent dispatch is the default.** Parallel sub-agents are heavy-tier-only AND require a deduplicated context blob (each sub-agent reading the project's full source independently is forbidden — same wasted-token pattern migration's Phase 7 fixed).
- **Findings cite source.** Every finding row has `evidence: <path:line>` for at least one fingerprint. If you can't cite source, the finding doesn't exist (Trusted-Summary failure mode).
- **Trivial-tier rows do not produce rationales.** The closure verb + the `<path:line>` evidence is the rationale. A trivial row whose `notes` field is filled with prose is over-production; the validator flags `notes_excess_chars > 200` on trivial rows. Note: security findings are NEVER trivial-tier — they always have rationale (≥ standard tier).

## Realism guards

Eight execution-time guards keep the discipline survivable on real codebases — scope caps, batch ceilings, skip-list honoring, mechanical-red short-circuits, oracle-absence fallbacks, dirty-tree behaviour, flaky-test quarantine, large-file sampling. Full guard definitions + thresholds: `references/align-discipline-procedures.md § Realism guards`. Commands apply them silently; audits cite a guard by name when one fires.

## Finding categories — universal taxonomy

Each finding belongs to exactly one of these classes. The class drives the detector skill that surfaces it AND the closure verb that fixes it AND the net-lines rule that applies. Stack-specific anti-patterns extend this taxonomy (delegated to per-stack packs); the categories below are the universal floor every project gets.

The taxonomy splits into two semantic groups: **structural** (entropy-reducing — net-lines must be ≤ 0) and **functional** (correctness-improving — small + line budget allowed when added lines cite idioms).

### Structural classes (net-lines ≤ 0 hard rule)

| Class | Detector signal | Default closure verb | Tier promoter? |
|---|---|---|---|
| **Dead code** | unused export, unreachable branch, `if (false)`, no inbound caller via grep + dead-code-finder | `remove` | No (trivial unless removal cuts a public API symbol) |
| **Duplicated logic** | same 3+-line shape in 2+ files, same function signature in 2+ modules, same regex/SQL/template repeated | `dedupe` (replace local copies with the existing shared helper named in `_extracted-idioms.md`) | Yes if dedupe touches > 3 files |
| **Reinvented wrapper** | custom markup / CSS / util / hook / type / class for a surface that has a shared equivalent in `_extracted-idioms.md` | `replace-with-shared` (delete custom, import shared, adjust call sites) | Yes if shared swap changes a public prop / call signature |
| **Silent catch** | `catch { /* no log, no rethrow */ }` OR `catch(e) {}` OR `try: ... except: pass` (project's idiom for empty catch — see `_extracted-idioms.md`) | `remove`-the-catch (let it throw) OR route through the project's error handler (named in `_extracted-idioms.md`) | No (trivial; routing through the standard handler is mechanical) |
| **Over-abstraction** | wrapper class / factory / strategy with one implementer; `options: {foo?: bool}` where every caller passes the same value; comment-as-rename (`// gets the user` above `function getUser()`) | `inline` (fold the wrapper into its single call site) OR `rename-comment-out` (delete the redundant comment) | Yes if inline collapses a public abstraction |
| **Drift from gold standard** | code deviates from a documented pattern in `ai/conventions.md` / `ai/architecture.md` / `_extracted-idioms.md` (e.g., raw library component used where the project's wrapper is the convention; route handler in the wrong layer; data access bypassing the repository pattern) | `replace-with-shared` OR `remove`-and-relocate | Yes (most drift findings span multiple files; standard tier is the typical floor) |
| **Stack-specific anti-pattern** | per-stack fingerprint detected by per-stack pack (`frontend/`, `backend/`, etc.) — e.g., default-true wrapper props left implicit, lifecycle hook on the wrong child, missing tenant gate (UI side) | Per-stack-pack-defined (typically `replace-with-shared` or `remove`) | Per-stack-pack-defined |

### Functional classes (small + line budget; added lines must cite idioms)

| Class | Detector signal | Default closure verb(s) | Tier promoter? |
|---|---|---|---|
| **SOLID violation** | (SRP) class with > 1 named responsibility; (OCP) modification of a closed module instead of extension; (LSP) subtype contract break (override changes pre/post-condition); (ISP) interface with members no consumer uses; (DIP) high-level module imports concrete low-level dependency | `split-extract` (split god class into named-in-idioms responsibilities) OR `inline` (collapse useless interface) OR `replace-with-shared` (depend on the abstraction named in `_extracted-idioms.md`) | Yes if the violation is in a shared module |
| **Clean-code violation** | function > project's max-lines threshold; nesting > project's max-depth threshold; magic number / string literal where the project has a named constants module; identifier name fails the project's naming convention; redundant comment-as-rename | `extract-to-shared` (move long function body to the shared helper named in `_extracted-idioms.md`) OR `inline-magic-to-named-const` (replace magic with named const from the project's constants module) OR `rename` (apply the convention) OR `rename-comment-out` (delete redundant comment) | No (trivial unless the rename touches a public API name) |
| **Performance** | N+1 query (1 query + per-result follow-ups); sequential `await` loop where ops are independent; sync external HTTP in a hot path; same lookup repeated within a request without caching; missing index where V2's query shape demands one; `SELECT *` consumed by < 5 field templates; in-app `.filter()` where the database can filter | `parallelize` (replace sequential await with `Promise.all` / `gather`); `batch` (replace per-item query with batch); `cache-with-explicit-ttl` (route through the project's caching primitive in `_extracted-idioms.md`); `add-index` (add reversible migration); `project-columns` (replace `SELECT *` with explicit list); `inline-filter-to-query` (push filter to the database) | Yes for hot-path findings; standard floor |
| **Security** | missing auth/permission gate on protected endpoint; SQL string concat / template literal in query; unescaped user input in HTML / template; secret in committed code (API key, password, token); unsafe deserialization (`pickle.loads(user_input)`, `eval`, `Function(...)`); missing input validation at API boundary; vulnerable dependency (CVE-flagged in lockfile); tenant-isolation gap (query without tenant filter in multi-tenant project); CSRF gap; missing rate-limit on auth endpoint | `add-gate` (wrap with the project's auth/permission gate from `_extracted-idioms.md`); `parameterize` (convert string concat to parameterized query); `escape` (wrap output in the project's escape helper); `move-to-secrets` (replace inline secret with config/env reference); `add-validator` (wrap input with the project's validator helper); `replace-with-shared` (e.g., swap unsafe `pickle` for the project's safe deserializer); for vuln deps: `bump-dep` (raise version per security advisory) | ALWAYS ≥ standard; critical security (auth bypass, SQL injection on production endpoint, secret-in-committed-code, RCE vector) ALWAYS heavy |
| **Unhandled I/O failure (happy-path-only)** | I/O call site (network / DB / queue / file / external process) with NO error path at all: no catch / rescue, no error-return check, no timeout where the medium needs one, no failure state surfaced to the caller or UI. The happy path is the only path — first network blip / DB timeout / malformed payload crashes or hangs. Distinct from **Silent catch** (structural): there a catch exists but swallows; here the error path is absent entirely. Canonical fingerprint: AI-generated fetch-and-render / fetch-and-write code that works first run and has zero failure handling | `replace-with-shared` (route the call through the project's wrapped I/O primitive / standard fetch wrapper / error-handler boundary named in `_extracted-idioms.md` — the wrapper provides the error path, timeout, and failure surfacing). If the project has no wrapped primitive for that I/O medium, halt → `/setup-project --refine` to add one; do NOT hand-roll try/catch per site | Yes for hot-path or user-facing call sites (standard floor); write-path I/O (DB mutation / queue publish / payment) ALWAYS ≥ standard; trivial only for dev-tooling / one-time-script paths |

**Forbidden classes** (these are NOT alignment findings — route elsewhere):
- A bug (incorrect output, crash) where the fix changes observable correct behaviour → `fix-bug` / dedicated tests.
- A new feature → feature-flow.
- A V1→V2 port → `/migration-*`.
- A reorganisation that changes module boundaries → `/refactor` + ADR.
- A perf change that requires breaking the contract (changing pagination behaviour, adding a required parameter, removing a field) → `/refactor` + ADR + caller-migration plan.
- A security finding that requires changing an interface contract (adding a required auth header where none was required) → `/refactor` + ADR; align handles the closure inside the existing contract.

## Per-finding audit — 11 hard halts

The DETECT step runs against a finding row + its evidence. The audit HALTS (refuses to advance the row) on any of these 11 conditions:

1. **No evidence** — finding row's `evidence` field empty OR `<path:line>` doesn't resolve OR cited line doesn't actually contain the fingerprint the row claims.
2. **Hand-waved enumeration** — finding row uses `etc.`, `...`, `&...`, `and so on`, `several places`, `a few sites`, `N+ duplicates`, `multiple call sites`, `multiple endpoints` in any field. Each duplicate / instance gets its own row OR one row with explicit `<path:line>` per instance in `evidence`.
3. **Wrong category** — finding class doesn't match the detector signal (e.g., a row classed as `dead-code` whose evidence shows an active import; a row classed as `security` whose evidence shows no risk vector). Re-classify or remove.
4. **Closure verb outside vocabulary** — verb not in the structural set (`remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`) NOR the functional set (`add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`). The fix is a refactor / redesign / new-feature; route elsewhere.
5. **Net-positive line count on structural class** — fix's diff has lines-added > lines-removed AND the row's class is structural (dead-code, dups, reinvented, silent-catch, over-abstraction, drift). Halt; revert; redo. Functional classes are exempt from this halt (see #6 instead).
6. **Functional fix doesn't cite idiom** — fix adds lines AND the row's class is functional (SOLID, clean-code, performance, security, unhandled-io) AND the added lines don't reference an idiom in `_extracted-idioms.md` (gate wrapper, validator helper, cache primitive, safe deserializer, etc.). Halt; either the idiom is missing (route to `/setup-project --refine`) OR the porter is inventing a new abstraction. Validator: `check_added_lines_cite_idioms`.
7. **Behaviour change (where preservation is required)** — touched files have tests; tests fail OR coverage drops OR a snapshot test diff appears that wasn't expected. The fix was not behaviour-preserving in a context where preservation was the contract; halt; revert. **Note**: security fixes MAY change behaviour intentionally (e.g., adding an auth gate denies previously-allowed unauth access). Such changes are documented in the row's `notes` and the test suite is updated in the SAME commit (test fixtures for unauth-access cases must be updated to reflect the new gate). The "behaviour change" halt fires only when the change is unintentional / undocumented.
8. **Scope creep** — diff touches files outside the finding row's `scope` field (the file list named at scan time). Halt; the fix violates one-finding-per-commit.
9. **New abstraction introduced** — diff introduces a new symbol (function / class / type / interface / file) NOT named in `_extracted-idioms.md`. Halt; either the symbol belongs in the idiom inventory (route to `/setup-project --refine`) or the porter is inventing. Validator: `check_no_new_symbols` exempts symbols listed in idioms.
10. **Reinvented wrapper without justification** — a `replace-with-shared` finding's fix introduces a NEW shared helper (rather than using the one named in `_extracted-idioms.md`). Halt; either the gold-standard inventory is incomplete (run `/setup-project --refine`) or the porter mis-identified the shared equivalent.
11. **Security finding without standard-tier rationale** — a security-class row was set to trivial tier OR has empty `notes`. Security findings always have rationale (≥ standard tier); halt and either promote to standard with rationale OR re-classify (if the row was wrongly tagged as security).

**Output of any halt**: a structured remediation note — specific finding row + specific action — written to `ai/align/halts/<row-id>.md`. NO advance until each halt is cleared.

## Per-stack extensions

The universal finding classes are necessary but not sufficient per stack — frontend / backend / mobile / data packs add their own detectors, fingerprints, and closure-verb vocabularies. Stack routing is via `PROJECT_KIND`. Full per-stack detector tables: `references/align-discipline-catalogue.md § Per-stack extensions`.

## Tool-agnostic procedure (for tools without skill dispatch)

The canonical detect → decide → fix → verify → record loop, per-class detection recipes, and closure-verb application steps are inlined verbatim in `references/align-discipline-procedures.md § Tool-agnostic procedure`. Tools with skill dispatch use `detect-drift` / `find-and-align`; rule-only tools follow the reference file (ships alongside this rule in every adapter bundle).

## Must

- **Inventory the gold standard before scanning.** `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` are the oracle. If they're empty, halt and run `/setup-project --refine`. Without an oracle, "alignment" is just opinion.
- **Read source before flagging.** Every finding cites `<path:line>` evidence that resolves. The Trusted-Summary failure mode (agent says "looks fine" without reading) is the #1 way alignment sweeps miss real drift, missing auth gates, and N+1 patterns.
- **Default to trivial tier for structural classes.** Most structural findings are 1-line `remove` or 1-symbol `dedupe`. Promoting to standard / heavy without trigger criteria is over-ceremony. **Security findings are NEVER trivial** — always ≥ standard; critical security ALWAYS heavy.
- **One finding per atomic commit.** Bundling findings in a commit hides which fix caused which downstream effect; rollback is all-or-nothing. The phase PR contains N commits = N findings. Security commits MAY change behaviour intentionally; the test update is part of the same commit.
- **Net-lines rule by class group:**
  - Structural rows: ≤ 0 per row, per phase. Entropy-reducing.
  - Functional rows: small + budget; every added block cites an idiom from `_extracted-idioms.md`.
- **Closure-verb vocabulary is the combined list of 21.** Structural verbs (5) + functional verbs (16). If the fix doesn't fit, it's not alignment; route elsewhere.
- **No new abstractions.** Even functional verbs like `add-validator` / `cache-with-explicit-ttl` use the project's existing helper named in `_extracted-idioms.md` — never invent a new validator / cache helper. `extract-to-shared` and `split-extract` move code to PRE-NAMED idioms; creating new abstractions in those verbs is forbidden.
- **Test before declaring fixed.** Lint + typecheck + scoped tests + re-detect. All four must pass. For security rows: + the security assertion exists. For perf rows: + the perf assertion exists. For frontend UI/UX rows: + a11y / visual / bundle-size all green. Skipping any is a Trusted-Summary failure waiting to surface.
- **Update the ledger on every state transition.** `detected → planned → in-progress → fixed → verified → archived` (with side states `halted`, `parked`, `archived-pre-existing`). The ledger is the source of truth — code grep is not.
- **Heavy-tier rows require reviewer approval before merge.** A symbol used outside the module being aligned has consumers; critical security rows have user-facing risk. A human reads the impact analysis. The reviewer's name + timestamp goes in the ledger row's `notes`.
- **Gap-count parity** (`gaps_in == gaps_closed`) — every evidence line surfaced at DETECT must be closed at VERIFY. A row that closes 7 of 8 evidence lines is `status: halted`, not `status: fixed`.
- **Security and perf changes ship with assertions.** A security gate without a test that asserts it gates; a parallelize without a perf assertion or observability annotation — these are halts. The fix isn't done until the regression-prevention test exists.
- **Idiom citation for functional adds.** Every block of added lines from a functional verb cites a `<path:line>` in `_extracted-idioms.md` (or the project's framework primitive). Validator `check_added_lines_cite_idioms` enforces.

## Must not

- **Introduce a new abstraction** in an alignment fix. Helper, base class, mixin, generic, strategy, factory, decorator, hook, validator schema, cache helper, escape function — all forbidden as a finding closure UNLESS the abstraction is already named in `_extracted-idioms.md`. If the project lacks the abstraction the fix needs, halt and route to `/setup-project --refine` to add it to idioms first; THEN run alignment.
- **Bundle findings in a commit.** "Cleanup: dead imports + dedupe utility + silent catch fixes + auth gate" guarantees an impossible review and an all-or-nothing rollback.
- **Skip the ledger.** A merged PR that closes findings without updating `ai/align/ledger.md` is incomplete. `/align-gate` halts on ledger drift.
- **Treat "no test exists for this" as "no behaviour exists".** A dead-code candidate that has no test might still be a runtime hot path (cron, queue consumer, integration with no unit test). Read git log + grep for callers in adjacent repos before removing.
- **Hand-wave enumeration.** `~8 dead exports` / `several silent catches` / `multiple missing auth gates` / `a few SQL injection vectors` — none of these are findings. They're vibes. Each instance gets a row OR one row with each instance enumerated in `evidence`.
- **Modify the oracle in the alignment PR.** `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md` changes are gold-standard updates — they ship via `/setup-project --refine`, not via a finding fix. Mixing them with alignment fixes lets the PR redefine the oracle to "match" what the fix did, which defeats the audit.
- **Promote tier silently.** A finding's tier is set at scan; promoting it later (e.g., during fix) requires a 1-line justification in `notes`. Silent promotion is how heavy work hides as trivial.
- **Downgrade a security finding's tier.** Security never falls below standard. Demoting a security row to trivial is forbidden.
- **Ship a security fix without a security assertion.** Adding a gate without a test that asserts the gate denies; adding a validator without a test that asserts malformed input is rejected; adding an escape without a test that neutralises a known-XSS payload — these are incomplete. The assertion is part of the fix.
- **Ship a perf fix without a perf assertion or observability annotation.** A `parallelize` without proof it parallelises; a `cache-with-explicit-ttl` without a cache-hit assertion; an `add-index` without an `EXPLAIN ANALYZE` capture — incomplete.
- **Bump a vulnerable dependency without running the test suite.** A `bump-dep` that breaks tests is a feature change in disguise; route to a separate dependency-migration ticket.
- **Carry V1 patterns into align findings.** If your project is also running a V1→V2 migration, alignment fixes never use V1's old shape — they use V2's gold standard. The migration discipline rule's "Structure → V2 wins" applies inside align too.
- **Ship a finding fix that fails any of: lint, typecheck, scoped tests, re-detect.** All four must be green; one red is a halt. For functional rows: + the relevant assertion (security / perf). For frontend rows: + a11y / visual / bundle-size all green. The verbs are mechanical-ish; if mechanical produces red, the row was mis-classified.
- **Combine intentional behaviour change with unrelated alignment in one commit.** Security gates that change behaviour ship in their own commit (security row). Mixing the gate with a refactor or feature in the same commit hides the security change.

## Should

- **Order findings within a phase by dependency.** A row that introduces a shared helper (or repairs one) goes BEFORE rows that swap local copies for it. A row that removes a wrapper goes AFTER rows that remove its callers.
- **Pick the lowest-blast-radius class first.** Dead code (touch-and-go) is the safest first phase; silent-catches → error-handler routing next; reinvented-wrapper swaps with shared equivalents come next; UI/UX domain phases (frontend) next; over-abstraction inlines later (those touch more files); SOLID splits last.
- **Front-load security in the plan.** Security findings have user-facing risk; ship them in early phases (phase 2 or 3 typically — after mechanical cleanup unblocks the test signal). Don't bury critical security at phase 8.
- **Group perf findings by hot-path domain.** A "checkout flow perf" phase (parallelize + batch + cache the cart + project columns on the order list) reads as a coherent perf uplift; mixing perf findings across domains is harder to validate.
- **Run `/align-fast` for routine sweeps** — most alignment work is mechanical, parallelisable, and the manual `/align-phase` flow's human-watch pauses are pure wall-clock waste. Reach for the manual flow when a phase has heavy-tier rows that benefit from per-row supervision.
- **Anchor a phase to a domain when possible.** A phase that aligns "all auth" or "all order processing" reads better in PR review than a phase that aligns "dead code + duplicates + silent catches + auth gates across the repo".
- **Run `/check-health` before `/align-scan`** — if mechanical (lint / typecheck / build / tests) is red, alignment fixes will be drowned by the existing red. Fix mechanical first.
- **Stop at the gold standard.** If a finding closure pushes the codebase *past* `_extracted-idioms.md` (e.g., introduces a "better" wrapper than the documented one), halt; either the gold standard is wrong (update via `/setup-project --refine`) or the fix is over-reach.
- **Cap a phase at 12 findings.** Larger phases hide regressions in PR review and slow the gate. If the scan surfaces 80 findings, that's 7+ phases.
- **Re-scan after every K phases.** Findings age. A phase that closed 12 rows may have surfaced new ones (a `replace-with-shared` row that introduced a new consumer of the shared helper might have surfaced a previously-hidden drift in a sibling file). Re-running `/align-scan` periodically catches drift.
- **For perf findings, capture an observability baseline before the fix.** Latency p95, query count per request, external HTTP per request — record from the project's observability dashboard at HEAD before the fix; the post-fix delta is the perf claim. Without a baseline, "I parallelized it" is unverifiable.
- **For security findings, file a separate ticket for any leaked secret rotation.** A `move-to-secrets` finding fixes the inline reference; the leaked secret itself must be rotated out-of-band. Don't conflate the two.
- **Wire detected anti-patterns into pre-commit hooks / lint rules where feasible.** A class that ships > 50 findings probably indicates the convention isn't enforced — alignment will rot back without a hook. Queue ADRs for hook creation.

## Examples per concern

Worked examples per finding class (reinvented-wrapper, silent-catch, design-token-drift, unhandled-io, dead-code, …): `references/align-discipline-catalogue.md § Examples per concern`.

## Review checklist (per phase PR)

Per-phase-PR checklist: `references/align-discipline-procedures.md § Review checklist`.

## Enforcement

Validator mapping (each named anti-pattern → its `validate-align-artifacts.sh` check function), gate behaviour, and SLA flags: `references/align-discipline-procedures.md § Enforcement matrix`.

## Anti-patterns (named)

The named catalogue with fingerprints and fixes: `references/align-discipline-catalogue.md § Anti-patterns`. The names are load-bearing vocabulary; audits cite them; the catalogue holds definitions.

## References

**Companion reference files (ship with this rule in every adapter bundle):**
- `references/align-discipline-procedures.md` — realism guards, per-stack extensions, tool-agnostic procedure, review checklist, enforcement matrix.
- `references/align-discipline-catalogue.md` — worked examples, anti-pattern catalogue, per-tool dispatch + cross-pack pointers.

**Key dispatch surfaces**: skills `detect-drift` / `find-and-align`; commands `/align` (simple surface) / `align-scan` / `align-fast` / `align-recheck` / `align-gate`. Validator: `scripts/validate-align-artifacts.sh` (21 closure verbs). Oracle: `_extracted-idioms.md`. Rule-only tools: this rule + the two reference files together are the complete discipline.
