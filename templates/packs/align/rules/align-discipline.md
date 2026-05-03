# Align Rule: codebase alignment discipline

> **Project-specific block** — Phase 4.6 fills this in from `.claude/_extracted-codebase.md § Gold standards` + `_extracted-idioms.md`. Do **not** delete; if extraction is empty, leave the placeholder + open a TODO.
>
> - **Codebase root**: `<extracted-from-codebase>` (the directory the alignment scans)
> - **Gold-standard inventory**: `<extracted-from _extracted-idioms.md>` (the named shared wrappers / utils / hooks / types / patterns the codebase reuses)
> - **Architecture doc**: `ai/architecture.md` (declared module boundaries)
> - **Conventions doc**: `ai/conventions.md` (V2's naming + structure rules)
> - **Findings ledger**: `ai/align/ledger.md` (per-finding state machine)
> - **Test runner**: `<extracted>` (e.g., `vitest`, `jest`, `pytest`, `playwright`, `rspec`, `go test`)
> - **PROJECT_KIND**: `<extracted>` (e.g., `frontend-vue`, `frontend-react`, `backend-node`, `backend-python`, `data-pipeline`) — switches stack-conditional detector fingerprints

This rule governs every codebase-alignment sweep. It exists because the most common codebase-rot failure is **drift from the gold standard** — a project starts with clean conventions, then accretes one-off helpers, custom wrappers, silent catches, dead branches, and copy-pasted logic until "the codebase" and "the conventions" describe two different repos. Routine work surfaces N+1 papercuts that nobody fixes alone, but every refactor that *would* fix them gets pulled into a feature PR and cut for scope. The second most common failure is **scope creep during refactor** — a "small cleanup" becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed. The third most common is **trusted summary** — an executor delegates "is this code duplicated / dead / drift?" to a search agent, the agent says "looks fine" in confident summary language, and the executor echoes that into the alignment report without verifying the claim against source.

This rule is the universal contract — it must be enforceable by any AI tool. Tools with full capability (commands + agents + skills + hooks) compose the discipline by dispatching `/align-scan` → `/align-plan` → `/align-phase` → `/align-gate` → `/align-final` (with `/align-fast` as the one-shot equivalent). Tools with rules only (Aider, Codex, Gemini, partial: Cline, Windsurf) enforce the discipline by reading and following this file directly. Therefore: the procedural detail is inlined here, not just referenced.

## Scope — what align covers (the comprehensive sweep)

Align is the codebase's quality gate. It covers every class of finding that affects the codebase's correctness, security, performance, structure, or maintainability — not just structural drift. The universal taxonomy spans:

1. **Structural** — drift from the gold-standard inventory (dead code, duplicated logic, reinvented wrappers, silent catches, over-abstraction, drift from `ai/conventions.md`).
2. **SOLID** — single-responsibility violations (god classes, multi-purpose modules), open/closed violations (modification where extension is the convention), Liskov violations (subtype contract breaks), interface-segregation violations (fat interfaces), dependency-inversion violations (high-level depending on low-level).
3. **Clean code** — long functions (> project's complexity threshold), deep nesting, magic numbers, poor naming, comment-as-rename, dead variables.
4. **Performance** — N+1 queries, sequential awaits where parallelism is safe, sync external HTTP in hot paths, missing caching at known-cacheable sites, missing index where the query shape demands one, `SELECT *` consumed by 4-field templates, in-app filtering where the database can filter.
5. **Security** — missing auth/permission gate on protected endpoints, SQL injection vectors (string concat in queries), XSS vectors (unescaped user output), secrets in committed code, unsafe deserialization, missing input validation at boundaries, vulnerable dependencies (CVE-flagged), tenant-isolation gaps in multi-tenant projects.
6. **Stack-specific** — for frontend, the UI/UX classes (a11y, design tokens, i18n, motion, lifecycle, default-true wrappers, permission gates); for backend, the data-layer classes (tenant-gate, transaction-boundary); for data, the pipeline classes (column projection, idempotency); for mobile, the bridge classes.

**What align does NOT cover** (route elsewhere):
- Behaviour-changing bugs (incorrect output, crash, wrong state) → `fix-bug` / dedicated tests.
- New features → feature-flow.
- V1→V2 ports (parallel codebases) → `/migration-*`.
- Architectural decisions (changing module boundaries, adopting a new framework) → `/refactor` + ADR.
- Release / deployment / infra → out of scope.

A finding's class drives:
- Which **detector** surfaces it (10 universal classes — 6 structural + 4 functional — plus per-stack extensions).
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
- **Per-finding enumeration is required at every tier.** Hand-waves (`etc.`, `...`, `and similar`, `N+ duplicates`, `several call sites`, `a few places`, `multiple endpoints`) HALT the gate. The validator's `check_findings_enumeration` greps for these tokens. If 8 dead exports exist, the ledger lists 8 rows (or 1 row with 8 explicit `<path:line>` citations in `evidence`). Never `~8 dead exports`. Same applies to security findings: never `several missing auth gates` — each endpoint gets its own row.
- **Single-agent dispatch is the default.** Parallel sub-agents are heavy-tier-only AND require a deduplicated context blob (each sub-agent reading the project's full source independently is forbidden — same wasted-token pattern migration's Phase 7 fixed).
- **Findings cite source.** Every finding row has `evidence: <path:line>` for at least one fingerprint. If you can't cite source, the finding doesn't exist (Trusted-Summary failure mode).
- **Trivial-tier rows do not produce rationales.** The closure verb + the `<path:line>` evidence is the rationale. A trivial row whose `notes` field is filled with prose is over-production; the validator flags `notes_excess_chars > 200` on trivial rows. Note: security findings are NEVER trivial-tier — they always have rationale (≥ standard tier).

## Realism guards (added so the discipline survives real codebases)

A discipline rule that fails on real-world conditions (sample-coverage flake, parallel race conditions, projects without observability dashboards) is an obstacle, not a guard. These rules trade absolute purity for operational realism — the discipline still holds, but it accommodates how production codebases actually behave.

### Coverage tolerance

The "coverage non-decreasing" rule allows a tolerance of **±0.5%** (configurable per project; default 0.5). Sample-based coverage tools (jest-coverage, pytest-cov, go test -cover, etc.) fluctuate ±0.1–0.3% on identical code due to:
- Async test ordering (which branches "happened to be" exercised in the run).
- Coverage instrumentation rounding.
- Test parallelism affecting which fixtures load.

A drop within tolerance is NOT a halt. A drop beyond tolerance IS a halt — the closure removed a load-bearing branch. The validator's `check_test_coverage_nondecreasing` reads the project's coverage tolerance from `ai/conventions.md § Coverage` (default 0.5%) and applies it.

### Parallel race serialization (per-file lock)

`/align-fast` dispatches rows in parallel waves (default `--max-parallel=5`). Two rows whose `scope` files overlap MUST NOT run concurrently — they would race on edits to the same file.

Serialization mechanism (per-file lock):
1. Before dispatching a row, the orchestrator computes the row's `scope_files = set(scope)`.
2. The orchestrator maintains a **lock set** of `in_progress_files = union(scope_files for active rows)`.
3. A row is dispatched only when `scope_files ∩ in_progress_files == ∅`.
4. When a row completes (fix + verify + record OR halt), its `scope_files` are removed from the lock set.
5. Heavy-tier rows always serialize across the entire phase (lock = all files).

Trivial implementation: process rows in dependency order; for each row, wait until all its scope files are unlocked; acquire locks; run; release.

The validator's `check_parallel_consistency` (post-hoc) verifies no two phase commits touched the same file at overlapping timestamps. A race condition (two commits modifying the same file in the same wave) = halt.

### Baseline capture fallback (no-observability projects)

Performance findings require a baseline (queries / latency / HTTP / wall-clock). Many projects don't have Grafana / Datadog / APM. Fallback hierarchy:

1. **APM dashboard** (preferred) — read latency p95 / query count from the project's observability link captured in `_extracted-codebase.md § Observability`.
2. **Test-suite baseline** — capture in a benchmark test that runs at HEAD pre-fix; assertion threshold = baseline + tolerance. Post-fix re-runs the test with new threshold = baseline_post_fix + tolerance.
3. **Manual measurement** — run the relevant code path against representative input; record wall-clock + query count via the project's logger or a one-off script. Document in `notes` with timestamp + input description.

Path 3 is acceptable for non-critical perf rows but discouraged for hot-path rows (subjective; not reproducible by reviewers). Path 1 or 2 preferred.

A perf row whose `notes` says "baseline: ~30ms (hand-timed)" is suspect; the validator's `check_perf_baseline_present` allows it but flags as `low-confidence`. Reviewers should escalate to path 1 or 2 before merging hot-path rows.

### Validator script (v1.5+)

`scripts/validate-align-artifacts.sh` ships 7 high-impact checks:

1. **Evidence resolves** — every row's `<path:line>` resolves to a real file at the cited line.
2. **No hand-waves** — refuses `etc.` / `...` / `several` / `multiple endpoints` / `N+ items`.
3. **Closure verb in vocabulary** — verb in the 21-verb closed list.
4. **No new symbols** — `git diff --diff-filter=A` shows no new public exports unless named in `_extracted-idioms.md`.
5. **Net-lines non-positive on structural** — git stat for the row's commit; structural rows must net ≤ 0.
6. **Scope boundary** — `git show --name-only` for the row's commit; touched files must be inside the row's `scope`.
7. **Security tier minimum** — security rows ≥ standard; critical-severity → heavy.

Remaining 7 checks (test-coverage, frontend-regression, idiom-citation, security-assertion, perf-baseline, oracle-unmodified, ledger-completeness) are **agent-side enforcement** — run inline by `/align-gate` / `/align-fast` / `/align-phase`. The procedures are inlined in this rule.

Usage:
```
scripts/validate-align-artifacts.sh --phase=<N>           # validate every row in phase N
scripts/validate-align-artifacts.sh --finding=<id>        # validate one finding
scripts/validate-align-artifacts.sh --all                 # validate every row in ledger
scripts/validate-align-artifacts.sh --strict              # treat warnings as errors
scripts/validate-align-artifacts.sh --check=<name>        # run only one check
```

Exit non-zero on any failure. Wire into pre-commit / CI / tool hook (Claude Code `.claude/settings.json` PostToolUse, Cursor `.cursor/hooks.json` `onSave`, GitHub Actions, etc.).

### Reviewer-approval mechanism (heavy-tier rows)

Heavy-tier rows pause for reviewer approval before they can flip to `verified`. This is a real protocol, not a soft suggestion:

**Ledger field**: every heavy-tier row has a `reviewer_approval:` field. Initially empty. Approval lands as `<reviewer-name>@<iso-timestamp>` (e.g., `reviewer_approval: alice@2026-05-02T18:30Z`).

**Halt behaviour**: when `/align-fast` / `/align-phase` reaches a heavy-tier row's RECORD step, it:
1. Applies the fix and runs VERIFY as normal.
2. Writes the row to ledger with `status: pending-review` (NOT `fixed`).
3. Writes `ai/align/halts/<id>-pending-review.md` with: who's the assigned reviewer, what to verify, and how to approve.
4. Continues to the next row (heavy rows do NOT block the rest of the phase).

**Approval flow**:
- Reviewer reads `ai/align/halts/<id>-pending-review.md` + the impact analysis at `ai/align/impact/<id>.md`.
- Reviewer manually adds `reviewer_approval: <name>@<iso>` to the ledger row + commits the ledger update.
- On next `/align-gate <N>` run, rows with non-empty `reviewer_approval` flip from `pending-review` → `verified`.

**Reviewer assignment**:
- Default: project's `CODEOWNERS` for the row's `scope` files OR the `default_reviewer:` field in `_anchors.md`.
- Override: pass `--reviewer=<name>` to `/align-fast` / `/align-phase` to assign explicitly.
- Fallback: if no reviewer is assignable, halt the row with "manual review required" (don't auto-approve).

**Timeout behaviour**:
- Default 7 days. After timeout, the row stays `pending-review` indefinitely; `/align-status --blockers` surfaces it.
- The user can override via `--review-timeout=<duration>` (e.g., `24h`, `30d`, `forever`).
- No auto-fail. No silent advance. The discipline is "wait until human signs off, however long that takes."

**Validator**: `validate-align-artifacts.sh` knows about `pending-review` status and treats it as terminal-non-fix (passes the row's checks; doesn't expect `verified`).

### Mid-port tier promotion

Sometimes mid-port the agent realizes a row's tier is wrong (e.g., scan classified it as standard but the fix actually touches > 10 files; or trivial dead-code turns out to remove a public API symbol). Procedure:

1. **Halt the row** — fix loop pauses at DECIDE; agent surfaces the promotion request.
2. **User decides** via `/align-promote-tier <id> <new-tier> [--reason="<text>"]`:
   - `<new-tier>` ∈ `{trivial, standard, heavy}`.
   - Promotions (trivial → standard → heavy) require no further justification.
   - Demotions (heavy → standard → trivial) require `--reason=` AND, for security rows, are forbidden (security never below standard).
3. **Backfill artifacts** for the new tier:
   - Promote to standard → agent backfills the ≤ 200-char rationale in `notes`.
   - Promote to heavy → agent generates the impact analysis at `ai/align/impact/<id>.md`; reviewer-approval flow kicks in.
4. **Resume**: agent re-enters DECIDE → FIX → VERIFY → RECORD with the new tier's discipline.

The `/align-promote-tier` command writes a one-line entry to `ai/align/_history.md`: `<iso> promote-tier <id> <old-tier>→<new-tier> | reason: <text>`.

Demotion of security rows below standard fails with: `security findings cannot fall below standard tier`.

### Idiom-drift propagation

When `_extracted-idioms.md` is modified between scan and execution, ledger rows that referenced the changed idioms may need re-evaluation. The scan + replan commands surface this:

**`/align-scan` detection**: at the end of every scan, the command compares `_extracted-idioms.md`'s git hash against the hash recorded in the prior scan's metadata (stored in `ai/align/_session-digest.md`). If the hash changed:
1. Scan runs as normal.
2. Output report includes a "Idiom drift detected" section listing:
   - Which idioms were added/removed/modified since last scan.
   - Which ledger rows cite those idioms (read `idiom_cited` field across the prior ledger).
   - Recommended action: re-run `/align-recheck` for affected rows OR `/align-replan --include-drifted`.

**`/align-replan --include-drifted`**: re-phases rows whose `idiom_cited` references a modified idiom. Rows whose status was `verified` flip to `detected` IF the cited idiom changed materially (renamed / signature change / removed); they stay `verified` if the change was cosmetic (rename of a comment, etc. — agent decides per-row).

**Validator**: `check_idiom_citation` (agent-side) compares the row's `idiom_cited` `<path:line>` against the current `_extracted-idioms.md`. A citation that no longer resolves halts the row at the next gate.

### Standard- and heavy-tier artifacts (when the floor lifts)

| Tier | Floor |
|---|---|
| trivial | Ledger row (id, finding-class, evidence `<path:line>`, closure verb, status) + code edit. |
| standard | Trivial floor + 1-paragraph rationale (≤ 200 chars) explaining why this finding closure is safe (e.g., "all 3 call sites pass identical args; inlining is mechanical"). |
| heavy | Standard floor + impact analysis (`ai/align/impact/<finding-id>.md`): every consumer of the touched symbol with `<path:line>`, the behaviour observable before/after the fix (assertion: identical OR documented break), reviewer name + approval timestamp before merge. |

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
6. **Functional fix doesn't cite idiom** — fix adds lines AND the row's class is functional (SOLID, clean-code, performance, security) AND the added lines don't reference an idiom in `_extracted-idioms.md` (gate wrapper, validator helper, cache primitive, safe deserializer, etc.). Halt; either the idiom is missing (route to `/setup-project --refine`) OR the porter is inventing a new abstraction. Validator: `check_added_lines_cite_idioms`.
7. **Behaviour change (where preservation is required)** — touched files have tests; tests fail OR coverage drops OR a snapshot test diff appears that wasn't expected. The fix was not behaviour-preserving in a context where preservation was the contract; halt; revert. **Note**: security fixes MAY change behaviour intentionally (e.g., adding an auth gate denies previously-allowed unauth access). Such changes are documented in the row's `notes` and the test suite is updated in the SAME commit (test fixtures for unauth-access cases must be updated to reflect the new gate). The "behaviour change" halt fires only when the change is unintentional / undocumented.
8. **Scope creep** — diff touches files outside the finding row's `scope` field (the file list named at scan time). Halt; the fix violates one-finding-per-commit.
9. **New abstraction introduced** — diff introduces a new symbol (function / class / type / interface / file) NOT named in `_extracted-idioms.md`. Halt; either the symbol belongs in the idiom inventory (route to `/setup-project --refine`) or the porter is inventing. Validator: `check_no_new_symbols` exempts symbols listed in idioms.
10. **Reinvented wrapper without justification** — a `replace-with-shared` finding's fix introduces a NEW shared helper (rather than using the one named in `_extracted-idioms.md`). Halt; either the gold-standard inventory is incomplete (run `/setup-project --refine`) or the porter mis-identified the shared equivalent.
11. **Security finding without standard-tier rationale** — a security-class row was set to trivial tier OR has empty `notes`. Security findings always have rationale (≥ standard tier); halt and either promote to standard with rationale OR re-classify (if the row was wrongly tagged as security).

**Output of any halt**: a structured remediation note — specific finding row + specific action — written to `ai/align/halts/<row-id>.md`. NO advance until each halt is cleared.

## Per-stack extensions

The 7 universal finding classes are necessary but NOT sufficient for stack-specific alignments. Stack-specific detector fingerprints, anti-pattern catalogues, and idiomatic shared-equivalents live in the per-stack packs:

### Frontend alignments — UI/UX is mandatory, not optional

For any `PROJECT_KIND in {frontend-*}`, the align scan MUST dispatch UI/UX detectors alongside the universal 7. UI/UX drift is the single largest source of user-visible regression in frontend codebases — inconsistent spacing, hardcoded colors, missing focus states, orphaned locale keys, a11y violations, raw library components used in pages where wrappers exist, broken empty/loading/error states, mobile breakpoints applied inconsistently. Treating these as "polish for later" is how design systems decay.

**UI/UX finding sub-classes (stack-specific, all use the universal closure verbs):**

| Sub-class | Detector signal | Default closure verb | Detector source |
|---|---|---|---|
| **a11y violation** | missing `alt`, `aria-label`, `aria-labelledby`, `for`/`id` pair, color contrast < AA, focus state missing on interactive element, heading hierarchy skip (`h1 → h3`), button-as-div, link-as-div | `replace-with-shared` (use the project's a11y-correct wrapper) OR `remove`-and-relocate (move attribute to correct element) | `frontend/agents/accessibility-auditor.md` + `frontend/commands/a11y-audit.md` |
| **design-token drift** | hardcoded color hex / rgb / hsl, hardcoded spacing / font-size / radius, raw Tailwind utility where the project's token alias exists, inline `style="color: #..."` | `replace-with-shared` (swap raw value for the design token named in `_extracted-idioms.md`) | `ui-ux/skills/design-token-audit.md` |
| **i18n key drift** | hardcoded user-visible string in markup (no `t('...')` / `$t('...')` / `useTranslation` call), orphan locale key (defined in JSON but no resolver), missing key (resolver call resolves to literal), namespace casing mismatch | `replace-with-shared` (swap hardcoded string for translation key) OR `remove` (orphan key in locale JSON) | `frontend/agents/i18n-auditor.md` + `frontend/commands/i18n-audit.md` |
| **raw library component used in app code** | a raw component from the project's UI library (e.g., button / modal / input / table) used directly in a page where the project's wrapper equivalent exists (per `_extracted-idioms.md` — concrete library and wrapper names vary by stack) | `replace-with-shared` (swap raw component for project wrapper) | universal `reinvented-wrapper` detector + frontend's gold-standard inventory |
| **missing UI state** | data-fetching component with no loading state OR no empty state OR no error state (hooks/composables that fetch data without surfacing the 3 states the project's standard fetch wrapper provides) | `replace-with-shared` (route through the project's standard fetch wrapper named in `_extracted-idioms.md`) | `frontend/agents/data-flow-auditor.md` |
| **motion / transition drift** | hardcoded `transition: all 0.3s` / inconsistent easing curves / missing `prefers-reduced-motion` guard / animation defined inline where the project has a token system | `replace-with-shared` (swap inline motion for project's motion token) | `ui-ux/skills/motion-audit.md` |
| **responsive breakpoint drift** | hardcoded `min-width: 768px` where the project has named breakpoints (`tablet`, `desktop`); responsive-only-at-page-level where the component should adapt; `display: none` for mobile-hide where the project's responsive utility exists | `replace-with-shared` (swap raw media query for project breakpoint utility) | `ui-ux` pack detector OR custom grep |
| **duplicated surface styles** | same affordance (button / card / badge / input / list-row) carries similar inline or scoped styling across **≥ 2** leaf pages or routes with no shared wrapper extracting it; detected by shape / component usage + style-rule similarity per `_extracted-idioms.md` | `extract-to-shared` (introduce or reuse the wrapper named in idioms; rewire callers) OR fold styles into the shared token / wrapper variant — see `ui-ux/commands/enhance-ui.md` Phase 1.5 | `/enhance-ui` orchestration + `frontend/agents/ui-architect.md` |
| **lifecycle / data-fetch hook on wrong element** | (inherited from migration-frontend.md): hook that fires only on full mount used on a route-cached child; hook that fires on every render used on data fetch | `replace-with-shared` (swap to the mount-AND-reactivate hook pair named in `_extracted-idioms.md`) | `frontend/rules/migration-frontend.md` § lifecycle-hooks |
| **default-true wrapper prop** | (inherited): `<CrudActions>` / `<TableHeader>` rendered without `:show-delete="false"` / `:can-edit="false"` where the page should hide that affordance | `remove`-the-element OR add the explicit `false` prop | `frontend/rules/migration-frontend.md` § default-true-wrapper-props |
| **permission-gate drop** | (inherited): action button rendered without the project's permission-gate wrapper / `v-if="hasPermission"` / `{user.can() && ...}` | `replace-with-shared` (wrap in the project's permission gate) | `frontend/rules/migration-frontend.md` § permission-gate |

**Frontend scan dispatch (mandatory for `PROJECT_KIND in frontend-*`):**

In addition to the universal 7 detectors, `/align-scan` runs:
1. `accessibility-auditor` agent — full repo a11y scan
2. `i18n-auditor` agent — locale-tree drift + orphan keys
3. `data-flow-auditor` agent — UI-state coverage
4. `design-token-audit` skill — token drift
5. `motion-audit` skill — animation drift
6. Per-stack pack's `migration-frontend.md` fingerprint set (if the frontend pack is loaded) — Transposition Trap, default-true props, permission-gate drop, reinvented wrappers

Scan output for frontend-* projects has UI/UX findings co-mingled with universal findings, classified by sub-class. Phasing typically groups UI/UX findings by **page or domain** (e.g., "Phase 1: auth pages a11y + design-token alignment") rather than by sub-class — a single page's a11y, token, and i18n fixes are reviewed together because they touch the same files.

**Visual / behaviour preservation for UI/UX fixes:**

UI/UX fixes have stricter behaviour-preservation requirements because the test suite often doesn't cover visual output. Required:
- **Visual regression** — for any phase that touches UI rendering, run the project's visual regression suite (Chromatic / Percy / Playwright snapshots — named in `_extracted-idioms.md`) against pre-fix and post-fix; diffs must be reviewed and accepted before the gate passes.
- **a11y regression** — for any phase that touches a11y, run the project's a11y test suite (`axe-core`, `pa11y`, `Playwright accessibility`) at HEAD; score must NOT drop.
- **Bundle size** — for any phase that swaps raw library components for wrappers, run the project's bundle-size check (`size-limit`, `bundlesize`); size must NOT increase by > 1% per phase.

If any of these regress, halt the gate; the closure verb was applied wrong.

### Backend alignments

See `backend/rules/migration-backend.md` (if your backend pack defines one). Adds: query-without-tenant-gate (in multi-tenant projects), N+1 detector, sequential-await loops where parallelism is safe, missing transaction boundary on multi-statement writes, raw SQL where the repository pattern is the convention.

### Data / pipeline alignments

See `data/rules/` (if defined). Adds: column-projection-greater-than-consumed (`SELECT *` where 4 columns are read), sync external-HTTP in batch jobs, idempotency-key-missing on write paths.

### Mobile alignments

For `PROJECT_KIND in {mobile-*}`, dispatch `mobile/skills/native-bridge-audit.md` alongside the universal 7.

### Fallback

If your project has no per-stack pack file, the universal 7-class taxonomy above is the floor. Author per-stack fingerprints into a per-stack pack as drift accumulates.

The universal rule below stays stack-agnostic. All concrete component / hook / library / ORM / migration-tool / a11y-tool / token-system names belong in the per-stack packs.

## Tool-agnostic procedure (for tools without skill dispatch)

The skills `detect-drift` and `find-and-align` describe canonical procedures. AI tools that support skills dispatch them directly. AI tools that don't (Aider / Codex / Gemini / Cline / Windsurf reading rules only) MUST follow the inlined procedure below to produce the same artifacts:

### Procedure: scan a codebase

1. Confirm `_extracted-idioms.md` and `_extracted-codebase.md § Gold standards` are populated. If empty, halt and run `/setup-project --refine` first — there's no oracle to align against.
2. Identify PROJECT_KIND from `_extracted-codebase.md`. The detector fingerprint set is conditional on this anchor.
3. Run the universal detectors (one per finding class above) in parallel waves:

   **Structural detectors:**
   - **Dead code**: dispatch `dead-code-finder` agent (full repo) OR run the project's tree-shake / unused-export tool (`ts-unused-exports`, `pyflakes`, `unimport`, `staticcheck` etc. — name in `_extracted-idioms.md`). Output: list of `<path:line>` for unused exports + unreachable branches.
   - **Duplicated logic**: run the project's duplicate detector (`jscpd`, `pylint --disable=all --enable=duplicate-code`, `dupl`, etc.) with min-token threshold = 50. Output: list of `<file-A:line>` ↔ `<file-B:line>` ↔ `<file-C:line>` clusters.
   - **Reinvented wrapper**: for each shared wrapper named in `_extracted-idioms.md`, grep for the *fingerprint* (the underlying library component or raw markup that the wrapper would replace). Each hit at non-shared call sites is a finding. Output: `<path:line>` + the shared equivalent it should swap to.
   - **Silent catch**: grep for the project's empty-catch idioms (e.g., `catch\s*\(?[^)]*\)?\s*{\s*}`, `except\s*[A-Z]\w*\s*:\s*pass`, `catch\s*{\s*//.*\bsilent\b`). Output: list of `<path:line>` per match.
   - **Over-abstraction**: dispatch `refactorer` agent in detect-only mode OR grep for single-implementer patterns (one-class-per-file with one public consumer; `options: {...}` where every caller passes identical values). Output: list of `<wrapper-path:line>` ↔ `<single-call-site-path:line>`.
   - **Drift from gold standard**: cross-reference each documented pattern in `ai/conventions.md` against the codebase. For each pattern, grep for the *anti-fingerprint* (the deviation). Output: list of `<deviating-path:line>` + the convention being violated.

   **Functional detectors:**
   - **SOLID violation**: dispatch `refactorer` agent with `--focus=solid` mode (or run the project's complexity / responsibility metrics tool). Detect:
     - SRP: classes/modules with > project's-named-responsibilities-threshold (typically 1 named responsibility per `_extracted-idioms.md`)
     - OCP: code that modifies a closed module instead of extending (the project may codify this in `ai/conventions.md` as "modules ending in `-Base` are closed")
     - LSP: subtype methods that change pre/post-conditions (compare interface signatures to overrides; flag stricter pre / weaker post)
     - ISP: interfaces with > N members where M consumers use only K < N (cite consumer/non-use)
     - DIP: high-level module imports concrete (not abstract) low-level dependency, where the abstraction exists in `_extracted-idioms.md`
     Output: list of `<path:line>` per violation, with the SOLID-letter sub-classification.
   - **Clean code**: run the project's complexity tool (`eslint-plugin-complexity` / `radon` / `gocyclo` / `flake8 --max-complexity` / `rubocop`) with thresholds from `ai/conventions.md`. Detect: long functions, deep nesting, magic numbers, identifier names violating the project's naming convention. Output: list of `<path:line>` + the threshold violated.
   - **Performance**: dispatch `performance-optimizer` agent (named in `code-quality/agents/`). Detect: N+1 query patterns (request handler that calls the same DAO method per loop iteration), sequential `await` loops where ops are independent, sync external HTTP in hot paths (analysed via observability link if present), missing caching at known-cacheable sites (idempotent reads called > 3× in a request), missing index where the query shape demands one (cross-ref `EXPLAIN ANALYZE` output if available), `SELECT *` consumed by < 5 fields (template/component analysis), in-app `.filter()` where the database can filter. Output: list of `<path:line>` per perf finding, with V1-cost (queries × latency or measured baseline) + V2-estimate (post-fix expectation).
   - **Security**: dispatch `security-auditor` agent + `deps-audit` skill (named in `security/agents/` + `security/skills/`). Detect: missing auth/permission gate on protected endpoints (cross-ref the project's auth gate from `_extracted-idioms.md`), SQL injection vectors (string concat in queries; template literal interpolation in raw SQL), XSS vectors (unescaped user input rendered to HTML), secrets in committed code (entropy analysis + known patterns: API keys, tokens, passwords), unsafe deserialization (`pickle.loads(user_input)`, `eval`, `Function(...)`), missing input validation at API boundaries (cross-ref the project's validator helper from `_extracted-idioms.md`), vulnerable dependencies (CVE-flagged in lockfile), tenant-isolation gaps (multi-tenant projects: query without tenant filter), CSRF / rate-limit gaps. Output: list of `<path:line>` per security finding, with severity (low / medium / high / critical) and the gate/escape/validator that should wrap the site.

   **Stack-specific:**
   - **Stack-specific**: dispatch the per-stack pack's detector. Output per-pack-defined.

4. For each detector output, write a finding row to the ledger draft (the finished ledger is built by `/align-plan`):
   ```yaml
   - id: A001
     class: dead-code | duplicated-logic | reinvented-wrapper | silent-catch | over-abstraction | drift | solid-violation | clean-code | performance | security | stack-specific
     subclass: <optional, e.g. "SRP" for solid-violation, "missing-auth-gate" for security>
     severity: <only for security: low | medium | high | critical>
     scope: [<path-1>, <path-2>, ...]   # the files this fix will touch
     evidence: [<path:line>, <path:line>, ...]   # at least 1
     closure_verb: remove | inline | dedupe | rename-comment-out | replace-with-shared
                 | add-gate | parameterize | escape | move-to-secrets | add-validator
                 | parallelize | batch | project-columns | add-index | cache-with-explicit-ttl
                 | extract-to-shared | split-extract | inline-magic-to-named-const | inline-filter-to-query
                 | bump-dep | rename
     idiom_cited: <required for functional verbs that add lines: <path:line> in _extracted-idioms.md for the gate/validator/cache/etc>
     tier: trivial | standard | heavy
     status: detected
     notes: ""
   ```
5. Validate the draft ledger: every row has ≥ 1 evidence citation that resolves; no hand-waves; tier matches the promoter rules above.
6. Write `ai/align/scan-report.md` (the human-readable summary) + `ai/align/ledger.md` (the canonical state machine).

### Procedure: per-finding fix loop (find-and-align)

For each ledger row in the current phase, in dependency order (rows that consume a shared helper come AFTER rows that introduce / fix that helper):

1. **DETECT** — re-read the row's `evidence` lines. Confirm the fingerprint still matches. (A finding can age out — another PR may have already fixed it.) If the fingerprint is gone, mark `status: archived-pre-existing` and skip. If still present, proceed.
2. **DECIDE** — confirm the closure verb is in the combined vocabulary (16 verbs across structural + functional groups). Confirm the fix is appropriate to the row's class:
   - Structural classes use structural verbs; behaviour MUST be preserved.
   - Functional classes use functional verbs; observable behaviour may change intentionally for security (an added auth gate denies unauth) or perf (a parallelize halves wall-clock) — such changes are documented in `notes` and tests are updated in the same commit.
   - For functional verbs that add lines: the row MUST have `idiom_cited: <path:line>` resolving to a real entry in `_extracted-idioms.md`. If not, halt; route to `/setup-project --refine` to update idioms first.
3. **FIX** — apply the closure-verb edit per the verb-specific procedure (see § "Closure-verb procedures" below). Touch only files in `scope`. Apply the net-lines rule by class group:
   - Structural rows: row diff ≤ 0 (with exception: first `replace-with-shared` site may net + due to import; cumulative ≤ 0).
   - Functional rows: small + budget; every block of added lines cites the `idiom_cited` reference (validator: `check_added_lines_cite_idioms`).
4. **VERIFY** —
   - Lint + typecheck on touched files (project commands from `_extracted-idioms.md` / `ai/stack.md`).
   - Run scoped tests (`<test-runner> <touched-files>`).
   - Re-run the detector that surfaced this row; it must NOT detect the fingerprint anymore at the cited evidence lines.
   - Coverage must NOT move for structural rows. For security rows that add a gate: existing coverage may shift (some unauth-access tests now expected to fail with 403) — the test suite must be updated in the same commit; coverage post-update must be ≥ pre-fix baseline.
   - For functional rows that ship perf changes: a perf assertion (latency p95 / query count / external HTTP count) verifies the improvement. The assertion is added to the test suite in the same commit OR is captured in an observability annotation.
   - For security rows: a security assertion (the gate denies unauth, the validator rejects malformed input, the escape neutralises a known-XSS payload) is added to the test suite in the same commit.
5. **RECORD** — update the ledger row:
   - `status: fixed`
   - `fixed_at: <iso-timestamp>`
   - `commit: <git sha>` (one finding = one commit)
   - `gaps_closed: <N>` (= number of evidence lines the fix actually closed; must equal `len(evidence)`)
   - `notes: ""` (trivial structural) OR `<200-char rationale>` (standard) OR full impact analysis link (heavy)
   - For security rows: the rationale cites the threat addressed + the test added (mandatory).

If any step fails, halt the row; mark `status: halted`; write `ai/align/halts/<id>.md` with the specific failure + remediation steps. Do NOT advance the row.

### Closure-verb procedures

Each verb has a specific procedure. The agent follows it mechanically.

**Structural verbs:**

| Verb | Procedure | Notes |
|---|---|---|
| `remove` | Delete the cited lines. If the row's evidence is a function/class/constant export, delete the export. Re-grep the repo post-delete; any remaining inbound import = halt + revert. | Net: −. |
| `inline` | Read the wrapper's body; read its single call site; substitute the body inline at the call site (with arg substitution); delete the wrapper. Re-grep for the wrapper's symbol post-delete; any remaining import = halt + revert. | Net: − (wrapper deleted, body inlined; saves 1 abstraction). |
| `dedupe` | Identify the canonical copy (the one in `_extracted-idioms.md` OR the one nearest to the project's shared root). For each non-canonical evidence site, delete the local copy and import the canonical. Re-grep each non-canonical site for residual usage of its old local symbol. | Net: − (N copies → 1 + N imports; net negative if each copy was > 1 line). |
| `rename-comment-out` | Delete the cited comment line(s). No code change. | Net: −. |
| `replace-with-shared` | For each evidence site, replace the local fingerprint with the named `shared_equivalent` import + call. Preserve all other props/args. Adjust prop names if the shared has different prop names than the local (mechanical rename). | Net: − cumulative; first site may net + from import. |

**Functional verbs:**

| Verb | Procedure | Class | Lines budget |
|---|---|---|---|
| `add-gate` | Wrap the protected endpoint / action / page with the project's auth/permission gate (named in `_extracted-idioms.md`). The gate is invoked at the entry point (route handler / controller method / page component). For UI: also gate the action button via the project's permission-gate wrapper. Every gate added is paired with a test asserting the gate denies an unauth/unprivileged caller. | security | + 2–5 lines per site |
| `parameterize` | Replace string concat / template literal SQL with parameterized query using the project's DB primitive (named in `_extracted-idioms.md`). Pass user-controlled values as parameters; never interpolate. | security | ≈ 0 (verb-equivalent rewrite) |
| `escape` | Wrap user-facing output with the project's escape helper (named in `_extracted-idioms.md` — typically the framework's auto-escape primitive or a dedicated `escapeHtml` / `safe` helper). Cover every interpolation site of the user-controlled value. | security | + 1–2 lines per site |
| `move-to-secrets` | Delete the inline secret. Replace usage with a config/env reference per the project's secrets convention (named in `_extracted-idioms.md`). Add the secret to `.env.example` if applicable. **Also**: rotate the leaked secret out-of-band (not in this PR — file a separate ticket). | security | ≈ 0 (replace 1 line with 1 line) |
| `add-validator` | Wrap the input handler with the project's validator (named in `_extracted-idioms.md` — Joi / Zod / Pydantic / serializer frameworks per backend stack / etc.). Define the schema; reject malformed input at the boundary. Every validator added is paired with a test asserting malformed input is rejected. | security | + 5–15 lines per site (schema definition) |
| `parallelize` | Replace sequential `await` loop with `Promise.all` / `asyncio.gather` / equivalent. Confirm operations are independent (read-only OR no shared mutable state). Bounded parallelism via the project's rate-limiter (named in `_extracted-idioms.md`) when calling external services. | performance | ≈ 0 or − (loop body compresses) |
| `batch` | Replace per-item query with batch query (`getById(id)` × N → `getByIds([id, id, ...])`). The batch primitive is named in `_extracted-idioms.md`. | performance | − (1 query replaces N) |
| `project-columns` | Replace `SELECT *` with explicit column list matching the consumed fields (cross-ref the consumer to identify columns). | performance | + per query (column list verbose) but − bandwidth at runtime |
| `add-index` | Add a reversible database migration creating the index per the query's `WHERE` / `ORDER BY` shape. Run `EXPLAIN ANALYZE` against prod-sized data before merge; record the cost reduction in `notes`. **ALWAYS ≥ standard tier; promotes to heavy if the index is on a hot table (>1M rows) or requires a backfill.** Index migrations are reversible by definition; rollback drops the index. | performance | + (migration file) |
| `cache-with-explicit-ttl` | Wrap the lookup with the project's caching primitive (named in `_extracted-idioms.md`). Set explicit TTL based on the data's staleness tolerance. Record the invalidation rule in `notes`. | performance | + 3–5 lines per site |
| `extract-to-shared` | Move duplicated block to the shared helper named in `_extracted-idioms.md`. Replace each evidence site with the import + call. **The shared helper must already be named in `_extracted-idioms.md`** — extracting to a new helper is forbidden (route to `/setup-project --refine` first). | clean-code, SOLID | − cumulative; first site may net + |
| `split-extract` | Split a multi-responsibility class/module into named-in-idioms responsibilities (each new module is named in `_extracted-idioms.md`). Update consumers. **The split targets must already be named in `_extracted-idioms.md`** — splitting into new abstractions is forbidden. | SOLID (SRP) | + first time, − as consumers swap |
| `inline-magic-to-named-const` | Replace magic number / string with a named const from the project's constants module (named in `_extracted-idioms.md`). | clean-code | + 1 line per site (the const declaration; one-time) |
| `inline-filter-to-query` | Replace in-app `.filter(x => x.active)` with database query `WHERE active = true`. Push the predicate to the query builder (named in `_extracted-idioms.md`). | performance | ≈ 0 (verb-equivalent) |
| `bump-dep` | Update the dependency to the version specified in the security advisory. Run the project's lockfile-regeneration command. Run the test suite. **If the bump is patch-level and tests pass: trivial-tier ledger row + commit, ship.** **If the bump is minor or major OR tests break: halt the row; route to a separate dependency-migration ticket.** A `bump-dep` row that hides a major-version migration is a Refactor in Disguise. The rule of thumb: `bump-dep` is appropriate when the lockfile-only diff has zero source code changes downstream. | security | + 0 (lockfile only); halt if tests break |
| `rename` | Apply the project's naming convention to the cited identifier. If the identifier is a public symbol, also update every consumer (re-grep). For private / file-local identifiers, the rename is local. | clean-code | ≈ 0 |

### Procedure: phase exit gate

Before declaring a phase complete:
1. Every row in the phase has `status ∈ {fixed, archived-pre-existing, parked}`.
2. Every `fixed` row has `gaps_closed == len(evidence)` (gap-count parity).
3. The phase's cumulative diff has net-lines ≤ 0 for STRUCTURAL findings (the structural subset of the phase's diff). Functional findings are exempt; their added lines must each cite an idiom (validator: `check_added_lines_cite_idioms`).
4. The phase's full test suite passes (`<test-runner>` exit 0).
5. Lint + typecheck pass repo-wide.
6. No `halted` rows remain (parked rows are allowed; halted are not).
7. The phase commit log shows one commit per fixed row (no bundled commits).
8. No row's diff touches files outside its `scope`.
9. No new symbol introduced (function / class / type / interface / file) UNLESS the symbol is named in `_extracted-idioms.md` (idioms-named exemption).
10. Per-tier artifact set complete for each row (trivial: ledger + commit; standard: + rationale; heavy: + impact analysis + reviewer approval).
11. Security findings have a security assertion in the test suite (gate denies unauth, validator rejects malformed, escape neutralises XSS) — co-committed with the fix.
12. Performance findings have a perf assertion or observability annotation (latency / query count / external HTTP count) — co-committed with the fix.
13. For frontend phases: a11y / visual / bundle-size regression checks all green.
14. Oracle files (`_extracted-idioms.md`, `ai/conventions.md`, `ai/architecture.md`) unmodified in the phase.

If any check fails → REFUSE the gate. Surface the specific failure. Validator script `scripts/validate-align-artifacts.sh` operationalises these 14 checks.

## Must

- **Inventory the gold standard before scanning.** `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` are the oracle. If they're empty, halt and run `/setup-project --refine`. Without an oracle, "alignment" is just opinion.
- **Read source before flagging.** Every finding cites `<path:line>` evidence that resolves. The Trusted-Summary failure mode (agent says "looks fine" without reading) is the #1 way alignment sweeps miss real drift, missing auth gates, and N+1 patterns.
- **Default to trivial tier for structural classes.** Most structural findings are 1-line `remove` or 1-symbol `dedupe`. Promoting to standard / heavy without trigger criteria is over-ceremony. **Security findings are NEVER trivial** — always ≥ standard; critical security ALWAYS heavy.
- **One finding per atomic commit.** Bundling findings in a commit hides which fix caused which downstream effect; rollback is all-or-nothing. The phase PR contains N commits = N findings. Security commits MAY change behaviour intentionally; the test update is part of the same commit.
- **Net-lines rule by class group:**
  - Structural rows: ≤ 0 per row, per phase. Entropy-reducing.
  - Functional rows: small + budget; every added block cites an idiom from `_extracted-idioms.md`.
- **Closure-verb vocabulary is the combined list of 16.** Structural verbs (5) + functional verbs (11). If the fix doesn't fit, it's not alignment; route elsewhere.
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

### Behaviour preservation

```text
# ❌ Behavioural change masquerading as alignment
Finding: silent catch in fetchUser()
Closure: remove the catch (let it throw)

→ Caller code that did `try { fetchUser() } catch {}` UPSTREAM was the actual silent-catch.
→ Removing the inner catch surfaces the error to a stack-trace, breaking the upstream silent caller.
→ This is a BEHAVIOUR CHANGE — caller observes a thrown error where they previously got undefined.
→ Halt. Re-classify as a refactor; route to /refactor with caller-migration plan.

# ✅ Mechanical alignment
Finding: silent catch in parseDate()
Closure: route through the project's error handler `errors.handleParseFailure(e)` (named in _extracted-idioms.md)

→ The error handler logs at debug + returns the same `null` the silent catch was returning.
→ Caller observable: identical (still gets null on parse failure).
→ Behaviour preserved; alignment win = downstream observability.
```

### Scope discipline

```text
# ❌ Mission creep
Phase 1 PR title: "Phase 1: dead code + dedupes + silent catches + reinvented wrappers + drift"
→ 5 finding classes in 1 phase. Reviewer can't tell which class caused which delta. Rollback is all-or-nothing.

# ✅ Atomic phases
Phase 1: dead code only (12 findings, all `remove` verb).
Phase 2: silent catches only (8 findings, all `replace-with-shared` to error handler).
Phase 3: reinvented wrappers in the auth domain (10 findings, all `replace-with-shared`).
Phase 4: over-abstraction in the order domain (6 findings, all `inline`).
```

### Reuse-Before-Create

```text
# ❌ Reinvented Wrapper (alignment finding that itself reinvents)
Finding: 4 files have a copy of `formatCurrency(amount, locale)`
Closure: extract to `<utils-root>/format-currency.<ext>`, import in all 4

→ Wait — `_extracted-idioms.md` already names `<source-root>/lib/i18n.formatMoney(amount)` as the project's currency formatter.
→ The "extract" is a reinvention. Halt.

# ✅ Replace with shared
Finding: 4 files have a copy of `formatCurrency(amount, locale)`
Closure: replace 4 local copies with `i18n.formatMoney(amount)` (per _extracted-idioms.md)

→ Net-lines: -4 functions, +4 imports = -3 lines per file.
→ Mapping doc not required at trivial tier; the closure verb cites the shared equivalent inline.
```

### Tier escalation

```text
# Trivial → standard escalation
Finding A001: replace local `cn()` helper with shared `clsx` (per _extracted-idioms.md)
Initial tier: trivial (single shared swap, mechanical)

→ Scan re-checks: this swap touches 18 files.
→ Promoter triggers: "3–10 files" exceeded; "newly-introduced shared helper consumed by 3+ sites" matches.
→ Promote to standard. Add 1-paragraph rationale: "18 components import the local cn(); shared clsx is API-equivalent (drop-in)."

# Standard → heavy escalation
Finding A012: replace `useUserContext()` hook with `useAuth()` (per _extracted-idioms.md)
Initial tier: standard (cross-module symbol rename)

→ Scan re-checks: this hook is exported and used by 2 sibling packages in the monorepo.
→ Promoter trigger: "removes a symbol used outside the module being aligned" matches.
→ Promote to heavy. Add impact analysis listing every consumer + reviewer approval before merge.
```

### Security findings (always ≥ standard)

```text
# ❌ Trivial-tier security row (forbidden)
Finding A047: missing auth gate on GET /admin/export
Tier: trivial
Closure verb: add-gate

→ Halt #11: security finding without standard-tier rationale.
→ Promote to standard. Rationale required: "Endpoint exposed admin export to unauthenticated callers; gate uses requireAdmin() from _extracted-idioms.md."
→ Test added in same commit: assert 401 for unauth caller, 403 for non-admin, 200 for admin.

# ✅ Critical security → heavy
Finding A101: SQL injection in /reports/orders?status=<unsanitized>
Tier: heavy (auto-promoted; class=security, subclass=sql-injection)
Closure verb: parameterize
Severity: critical

→ Heavy tier: impact analysis required. Lists every consumer of the affected query.
→ Reviewer approval required before merge.
→ Test added: a known-injection payload returns 400 (validator rejects) AND the query log shows parameterised execution.
→ Notes: "Threat: arbitrary SQL execution as DB user; observed in red-team report 2026-04-15. Test fixture: tests/security/sql-injection.<test-ext>:42."
```

### Performance findings (idiom citation required for added lines)

```text
# ❌ Perf fix without idiom citation
Finding A082: N+1 in listOrders() — 1 query + N customer lookups
Closure verb: cache-with-explicit-ttl
Diff:
+ const cache = new Map();
+ function getCustomer(id) { if (!cache.has(id)) cache.set(id, query(...)); return cache.get(id); }

→ Halt #6: functional fix doesn't cite idiom.
→ The added cache is a NEW abstraction. The project has `<source-root>/cache/requestScopedCache.<ext>` named in _extracted-idioms.md.
→ Re-do using `replace-with-shared`: route through `requestScopedCache.get('customer:' + id, () => fetchCustomer(id), { ttl: 60_000 })`.

# ✅ Parity-preserving perf with idiom citation
Finding A082: N+1 in listOrders()
Closure verb: batch
Idiom cited: <source-root>/repos/customers.<ext>:88 (getByIds() batch primitive)
Diff (pseudocode):
- customers = parallel_each(orders, o => getCustomer(o.customerId))
+ customers = getByIds(unique(orders.map(o => o.customerId)))

→ Net: −1 line.
→ Perf assertion added: query log shows 2 queries instead of N+1 for a 50-order list.
→ Notes: "V1 cost: 51 queries / 200ms p95. V2: 2 queries / 35ms p95. Measured in tests/perf/list-orders.<test-ext>:18."
```

### Clean code / SOLID (extract to NAMED idioms only)

```text
# ❌ extract-to-shared inventing a new abstraction
Finding A055: long function (143 lines) in <source-root>/checkout/processOrder.<ext>:42
Closure verb: extract-to-shared
Diff (pseudocode):
+ // <source-root>/checkout/helpers/calculateTax.<ext> (NEW FILE)
+ export calculateTax(items, region) { ... }

→ Halt #9: new symbol introduced (not in _extracted-idioms.md).
→ Either route to /setup-project --refine (add calculateTax to idioms first), OR re-classify (the long function is a god function; the right verb may be split-extract into pre-named responsibilities, not a fresh extract).

# ✅ extract-to-shared using a pre-named idiom
Finding A055: long function (143 lines) in <source-root>/checkout/processOrder.<ext>:42
Closure verb: split-extract
Idiom cited: _extracted-idioms.md § Service responsibilities (TaxCalculator, ShippingCalculator already named)
Diff:
- // 60 lines of tax calculation
+ const tax = taxCalculator.calculate(items, region);
- // 50 lines of shipping calculation  
+ const shipping = shippingCalculator.calculate(items, region);

→ Net: −90 lines (consumers now call existing services).
→ TaxCalculator and ShippingCalculator already exist per _extracted-idioms.md; this finding moves the inline logic into them (not creates them).
```

## Review checklist (per phase PR)

- [ ] Every commit in the PR maps to exactly one ledger row by `id`.
- [ ] Every ledger row's `status` is `fixed` or `archived-pre-existing` (no `halted`, no `in-progress`).
- [ ] Every row's `evidence` lines were re-detected at DETECT and confirmed gone at VERIFY.
- [ ] `gaps_in == gaps_closed` for every row (gap-count parity).
- [ ] Cumulative diff has net-lines ≤ 0.
- [ ] Lint + typecheck + full test suite green at HEAD.
- [ ] Coverage ≥ pre-PR baseline (a removed branch was not the only thing exercising a code path).
- [ ] No new symbol introduced (function / class / type / interface / file) — `git diff --diff-filter=A` shows no `+` lines defining new exports.
- [ ] No file outside any row's `scope` is touched.
- [ ] Per-tier artifact set complete:
  - trivial: row + commit
  - standard: + 1-paragraph rationale in row's `notes`
  - heavy: + impact analysis at `ai/align/impact/<id>.md` + reviewer approval timestamp in `notes`
- [ ] Gold-standard files (`_extracted-idioms.md`, `ai/conventions.md`, `ai/architecture.md`) NOT modified in this PR.
- [ ] No hand-wave tokens (`etc.`, `...`, `several`, `N+`, `multiple`) in any ledger field.
- [ ] PR title = `align/phase-<N>: <one-finding-class-or-domain>` (single-class or single-domain phases preferred).

## Enforcement

- **`/align-gate <N>`** halts on: any of the 14 phase-exit checks failing, any row's per-tier artifacts incomplete, any net-positive line count on structural rows, any functional row whose added lines don't cite an idiom, any `halted` row, any security row without an assertion, any perf row without a baseline / assertion.
- **`/align-status`** reports per-finding state and flags rows older than the SLA (default: a row in `in-progress` for >7d is flagged stalled; a security row halted for >24h is flagged escalated).
- **Validator script** `scripts/validate-align-artifacts.sh` operationalises the enforcement of the named anti-patterns:
  - "Hand-waved enumeration" → `check_findings_enumeration` greps for hand-wave tokens.
  - "Reinvented Wrapper in fix" → `check_no_new_symbols` runs `git diff --diff-filter=A` against the alignment PR and fails on new public exports NOT named in `_extracted-idioms.md`.
  - "Net-positive line count on structural row" → `check_net_lines_nonpositive_structural` measures diff for structural-class rows and fails if `+>−`.
  - "Functional add without idiom citation" → `check_added_lines_cite_idioms` parses each added hunk and validates that the row's `idiom_cited` resolves AND covers the added lines (the cited idiom file appears in the diff's import lines OR the added block calls the named symbol).
  - "Behaviour change" → `check_test_coverage_nondecreasing` runs the test suite + coverage, fails if either regresses (with security-row exception: coverage may shift; absolute % must not drop).
  - "Trusted Summary" → `check_evidence_resolves` validates every row's `evidence` is a real `<path:line>` containing the claimed fingerprint.
  - "Scope creep" → `check_scope_boundary` runs `git diff --name-only` and fails if touched files are outside any row's `scope`.
  - "Security row without assertion" → `check_security_assertion_present` for each security row, looks for a co-committed test file change that asserts the gate / validator / escape; fails if absent.
  - "Perf row without baseline" → `check_perf_baseline_present` for each perf row, looks for a `notes` field containing baseline numbers (latency / queries / HTTP) OR a co-committed observability annotation; fails if absent.
  - "Oracle modification" → `check_oracle_unmodified` runs `git diff` against `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md`; fails if non-empty.
  - "Frontend regression" → `check_frontend_regressions` (when `PROJECT_KIND in {frontend-*}`) runs scoped a11y / visual / bundle-size; fails on regression.

## Anti-patterns (named)

- **The Refactor in Disguise** — a finding whose fix introduces a new abstraction (not in `_extracted-idioms.md`), renames a public API, or changes observable behaviour where preservation was the contract. Looks like alignment in the ledger; ships as a redesign in PR review. Caught by: closure-verb vocabulary check + `check_no_new_symbols` (with idioms exemption) + `check_test_coverage_nondecreasing`.
- **The Trusted Summary** (inherited from migration) — agent says "looks duplicated" / "looks dead" / "looks reinvented" / "no security issues" without `<path:line>` evidence; executor echoes into ledger. Caught by: `check_evidence_resolves` + audit halt #1.
- **The Hand-waved Finding** (inherited) — `~8 dead exports`, `several silent catches`, `multiple reinvented wrappers`, `a few missing auth gates`. Caught by: `check_findings_enumeration` + audit halt #2.
- **The Net-Positive Cleanup** (structural) — fix imports a shared helper but doesn't delete the local copy; OR introduces a wrapper "to make the swap easier"; OR adds a comment explaining the new shape. Net lines go up on a structural row. Caught by: `check_net_lines_nonpositive_structural` + audit halt #5.
- **The Bundled Phase** — phase PR mixes 5 finding classes; reviewer can't localise regressions. Caught by: review-checklist row "PR title = single-class-or-domain"; reviewer responsibility.
- **The Stale Ledger** — a phase merges without updating ledger rows to `fixed`. Code grep claims "no more silent catches" but ledger rows are still `in-progress`. Caught by: `/align-gate` halt #1; `/align-status` reports stalled rows.
- **The Oracle Drift** — alignment PR also modifies `_extracted-idioms.md` / `ai/conventions.md` to "explain" the fix. Caught by: review-checklist + `check_oracle_unmodified` (PR diff against `_extracted-idioms.md` must be empty).
- **The Eternal Phase** — phase opens, 30+ findings detected, phase never closes because new findings keep getting added. Caught by: phase-cap rule (≤ 12 findings); excess routes to phase N+1.
- **The Re-Detection Skip** — porter applies the fix and marks `status: fixed` without re-running the detector to confirm the fingerprint is gone. The fingerprint sometimes lingers (the fix targeted the wrong line). Caught by: VERIFY step's mandatory re-detect; `check_evidence_resolves` re-run at gate.
- **The Silent Coverage Drop** — fix removes a branch; tests pass; but the branch was the only path exercising a downstream code path. Coverage drops 0.3%; nobody notices in a 1500-test suite. Caught by: `check_test_coverage_nondecreasing` (any drop is a halt).
- **The Reinvented Idiom in Functional Verb** — porter writes a new validator schema, cache helper, escape function, gate wrapper inside an `add-validator` / `cache-with-explicit-ttl` / `escape` / `add-gate` fix. The functional verbs are supposed to USE the project's existing idiom — inventing a new one is the same anti-pattern as Reinvented Wrapper, just on functional adds. Caught by: `check_added_lines_cite_idioms` + `check_no_new_symbols` (with idioms exemption).
- **The Bare Security Fix** — porter adds a gate / validator / escape but doesn't add a test asserting it works. Six months later, a refactor accidentally removes the gate and no test catches it. Caught by: `check_security_assertion_present`.
- **The Hopeful Perf Fix** — porter parallelises / batches / caches without measuring before or after. The fix may be a perf regression (e.g., `Promise.all` overwhelms a downstream service); nobody knows because there's no baseline. Caught by: `check_perf_baseline_present`.
- **The Lockfile-Only Bump** — `bump-dep` for a vulnerable dependency without running the test suite. The bump may have a breaking change; tests catch it but nobody ran them. Caught by: VERIFY step's mandatory test run.
- **The Tier Demotion** — porter sets a security row to trivial because "it's just one missing gate, easy fix". Caught by: audit halt #11 + `check_security_tier_minimum`.
- **The Behaviour Change Conflation** — security gate that changes behaviour (denies unauth) is bundled with an unrelated alignment fix in the same commit. The security change becomes invisible in the diff. Caught by: review-checklist + one-finding-per-commit rule.
- **The Cross-Class Phase** — phase PR contains a mix of structural + security + perf rows. Net-lines rule is ambiguous; reviewer attention is scattered. Caught by: phasing strategy in `/align-plan` (single-class or single-domain phases preferred).
- **The Frontend Regression Skip** — porter ignores a11y / visual / bundle-size regression "because it's mechanical". Caught by: `check_frontend_regressions` at gate.
- **The Idiom Inventory Gap** — porter halts repeatedly because the idiom they need (a validator, a cache helper, a gate wrapper) doesn't exist in `_extracted-idioms.md`. The right move is to update idioms first via `/setup-project --refine`, then resume alignment — not to invent the idiom inline. Symptom: `halts/` directory full of "missing idiom: X" entries.

## References

These references are **convenience pointers for AI tools that support them**. The rule itself is self-sufficient — every procedure is inlined above. If your tool doesn't expose these as commands/agents/skills, follow the inlined procedures.

### For tools with command + agent + skill dispatch

- `.claude/skills/detect-drift.md` — drift-detection procedure (inlined above).
- `.claude/skills/find-and-align.md` — per-finding fix loop (inlined above).
- `.claude/commands/align-scan.md` — Phase 0 entry point (scan + report).
- `.claude/commands/align-plan.md` — phase grouper (consumes scan output).
- `.claude/commands/align-phase.md` — per-phase orchestrator (executes find-and-align per row).
- `.claude/commands/align-gate.md` — phase exit verifier (validates the artifact set above).
- `.claude/commands/align-fast.md` — one-shot orchestrator (scan + plan + all phases + gate).
- `.claude/commands/align-status.md` — read-only ledger reader.
- `.claude/commands/align-final.md` — final sweep across all phases.
- `.claude/commands/align-rollback.md` — undo a phase.
- `.claude/commands/align-park.md` — park a hairy finding.

### Cross-pack references

- `code-quality/commands/simplify.md` — structural closure-verb vocabulary inherited from this command.
- `code-quality/commands/check-health.md` — pre-flight mechanical check; run before `/align-scan`.
- `code-quality/agents/dead-code-finder.md` — dispatched by `detect-drift` for the dead-code class.
- `code-quality/agents/refactorer.md` — dispatched in detect-only mode for over-abstraction + SOLID classes.
- `code-quality/agents/code-reviewer.md` — dispatched for clean-code class.
- `code-quality/agents/performance-optimizer.md` (or per-pack equivalent) — dispatched for performance class.
- `code-quality/rules/quality-principles.md` — clean-code thresholds referenced by clean-code detector.
- `code-quality/rules/engineering-principles.md` — SOLID principles + engineering rules referenced by SOLID + clean-code detectors.
- `security/agents/security-auditor.md` — dispatched for security class.
- `security/commands/security-audit.md` — sibling command (security-only deep audit, used by /align-scan when security findings exceed scan threshold).
- `security/skills/deps-audit.md` — dispatched for vulnerable-dependency security findings.
- `migration/rules/migration-discipline.md` — sibling discipline; align is migration turned inward.
- `frontend/rules/migration-frontend.md` — frontend-specific anti-pattern catalogue (extends align).
- `frontend/agents/accessibility-auditor.md` — dispatched for `frontend-*` a11y class.
- `frontend/agents/i18n-auditor.md` — dispatched for `frontend-*` i18n class.
- `frontend/agents/data-flow-auditor.md` — dispatched for `frontend-*` UI-state class.
- `ui-ux/skills/design-token-audit.md` — dispatched for `frontend-*` token class.
- `ui-ux/skills/motion-audit.md` — dispatched for `frontend-*` motion class.
- `backend/rules/migration-backend.md` — backend-specific anti-pattern catalogue (extends align).
- `backend/rules/concurrency-discipline.md` — perf class's `parallelize` verb references this for safe parallelism.

### Patterns (read by all tools as ai/ knowledge)

- `ai/patterns/align-ledger.md` — ledger record format + state machine (authored when `/align-scan` first runs).

### Validator script

- `scripts/validate-align-artifacts.sh` — validates evidence resolution, hand-wave-token absence, net-line non-positivity, test-coverage non-decreasing, scope-boundary, no-new-symbols, oracle-unmodified. Runnable from CI / pre-commit / any tool's hook system. Tool-agnostic.

### For rule-only tools (Aider, Codex, Gemini, partial: Cline, Windsurf)

This rule **is** the surface. The 10 universal finding categories (6 structural + 4 functional), the 14 phase-exit checks, the 11 per-finding halts, the closure-verb vocabulary (5 structural + 16 functional), and the three procedures (scan / find-and-align / gate) are all inlined above. No skill / agent / command dispatch is required — follow the rule as a checklist.
