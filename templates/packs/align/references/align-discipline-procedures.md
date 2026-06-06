# Align discipline — procedures & operational reference

> Companion to `rules/align-discipline.md` (the always-loaded core). Loaded on demand by align commands/skills when scanning, fixing, gating, or reviewing — NOT auto-loaded into every session.
> Rule-only tools (Aider / Codex / Gemini): this file ships alongside the core rule in your adapter bundle — read both; together they are the complete discipline.
> Content relocated verbatim from the core rule on 2026-06-07 (40k-char always-on limit); wording unchanged.

## Realism guards (added so the discipline survives real codebases)

A discipline rule that fails on real-world conditions (sample-coverage flake, parallel race conditions, projects without observability dashboards) is an obstacle, not a guard. These rules trade absolute purity for operational realism — the discipline still holds, but it accommodates how production codebases actually behave.

### Coverage tolerance

The "coverage non-decreasing" rule allows a tolerance of **±0.5%** (configurable per project; default 0.5). Sample-based coverage tools (jest-coverage, pytest-cov, go test -cover, etc.) fluctuate ±0.1–0.3% on identical code due to:
- Async test ordering (which branches "happened to be" exercised in the run).
- Coverage instrumentation rounding.
- Test parallelism affecting which fixtures load.

A drop within tolerance is NOT a halt. A drop beyond tolerance IS a halt — the closure removed a load-bearing branch. The validator's `check_test_coverage_nondecreasing` (agent-side — not script-enforced) reads the project's coverage tolerance from `ai/conventions.md § Coverage` (default 0.5%) and applies it.

### Parallel race serialization (per-file lock)

`/align-fast` dispatches rows in parallel waves (default `--max-parallel=5`). Two rows whose `scope` files overlap MUST NOT run concurrently — they would race on edits to the same file.

Serialization mechanism (per-file lock):
1. Before dispatching a row, the orchestrator computes the row's `scope_files = set(scope)`.
2. The orchestrator maintains a **lock set** of `in_progress_files = union(scope_files for active rows)`.
3. A row is dispatched only when `scope_files ∩ in_progress_files == ∅`.
4. When a row completes (fix + verify + record OR halt), its `scope_files` are removed from the lock set.
5. Heavy-tier rows always serialize across the entire phase (lock = all files).

Trivial implementation: process rows in dependency order; for each row, wait until all its scope files are unlocked; acquire locks; run; release.

The validator's `check_parallel_consistency` (agent-side — not script-enforced) (post-hoc) verifies no two phase commits touched the same file at overlapping timestamps. A race condition (two commits modifying the same file in the same wave) = halt.

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
   - **Unhandled I/O failure (happy-path-only)**: enumerate I/O call sites — the project's HTTP client, DB primitive, queue producer/consumer, file I/O, external-process spawn (concrete primitives named in `_extracted-idioms.md`). For each site, trace the failure path: (a) is the call routed through the project's wrapped I/O primitive / error boundary? (b) if raw, is the error surfaced — handler call, error-return checked, rejection awaited-and-handled, UI error state? (c) does the medium need a timeout and is one set? A site with none of these is a finding. Cross-check the caller chain before flagging — a raw call whose CALLER handles the rejection is NOT a finding (cite the handling site in `notes`); a raw call whose only "handler" is a top-level crash logger IS one. Frontend overlap: the `missing UI state` sub-class (frontend pack) covers fetch-in-component; this universal detector covers the non-UI layers — services, jobs, queue handlers, CLI paths, scripts. Output: list of `<path:line>` + the wrapped primitive each site should route through.

   **Stack-specific:**
   - **Stack-specific**: dispatch the per-stack pack's detector. Output per-pack-defined.

4. For each detector output, write a finding row to the ledger draft (the finished ledger is built by `/align-plan`):
   ```yaml
   - id: A001
     class: dead-code | duplicated-logic | reinvented-wrapper | silent-catch | over-abstraction | drift | solid-violation | clean-code | performance | security | unhandled-io | stack-specific
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
2. **DECIDE** — confirm the closure verb is in the combined vocabulary (21 verbs across structural + functional groups). Confirm the fix is appropriate to the row's class:
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
- **Validator script** `scripts/validate-align-artifacts.sh` operationalises the enforcement of the named anti-patterns (11 of 14 checks are script-enforced; the 3 tagged `(agent-side — not script-enforced)` below require runtime tooling and run agent-side):
  - "Hand-waved enumeration" → `check_no_handwaves` greps for hand-wave tokens.
  - "Reinvented Wrapper in fix" → `check_no_new_symbols` runs `git diff --diff-filter=A` against the alignment PR and fails on new public exports NOT named in `_extracted-idioms.md`.
  - "Net-positive line count on structural row" → `check_net_lines_structural` measures diff for structural-class rows and fails if `+>−`.
  - "Functional add without idiom citation" → `check_added_lines_cite_idioms` parses each added hunk and validates that the row's `idiom_cited` resolves AND covers the added lines (the cited idiom file appears in the diff's import lines OR the added block calls the named symbol).
  - "Behaviour change" → `check_test_coverage_nondecreasing` (agent-side — not script-enforced) runs the test suite + coverage, fails if either regresses (with security-row exception: coverage may shift; absolute % must not drop).
  - "Trusted Summary" → `check_evidence_resolves` validates every row's `evidence` is a real `<path:line>` containing the claimed fingerprint.
  - "Scope creep" → `check_scope_boundary` runs `git diff --name-only` and fails if touched files are outside any row's `scope`.
  - "Security row without assertion" → `check_security_assertion_present` for each security row, looks for a co-committed test file change that asserts the gate / validator / escape; fails if absent.
  - "Perf row without baseline" → `check_perf_baseline_present` for each perf row, looks for a `notes` field containing baseline numbers (latency / queries / HTTP) OR a co-committed observability annotation; fails if absent.
  - "Oracle modification" → `check_oracle_unmodified` runs `git diff` against `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md`; fails if non-empty.
  - "Frontend regression" → `check_frontend_regressions` (agent-side — not script-enforced) (when `PROJECT_KIND in {frontend-*}`) runs scoped a11y / visual / bundle-size; fails on regression.

