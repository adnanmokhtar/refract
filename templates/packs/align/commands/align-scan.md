---
description: Deep codebase quality scan. Reads source against the gold-standard inventory (_extracted-idioms.md), runs the 11 universal detectors (structural + functional: SOLID, clean code, performance, security) plus stack-specific detectors, builds ai/align/findings.md + ai/align/ledger.md. Run before /align-plan. Stack-agnostic — frontend / backend / data / mobile. Frontend stacks dispatch UI/UX detectors (a11y, design tokens, i18n, motion) automatically. Security findings are always ≥ standard tier; critical security always heavy.
kind: command
pack: align
---

# /align-scan

## The Premise (read this first)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — SOLID / clean-code / detector vocabulary (single source of truth; do not restate glossaries here).

**Read before flagging. Cite real `<path:line>` evidence, never invented.** The scan reads the actual codebase against the actual gold-standard inventory — preferring `_extracted-idioms.md` when present, falling back to `codebase-profile.md` when idioms is absent (the latter is normal for Composition-API / functional projects where Phase 2.5 of refine has no class-inheritance hierarchy to extract from). Plus `ai/conventions.md` + `ai/architecture.md`. Writes a finding row per real fingerprint hit. No paraphrasing, no "this module probably has dead code," no inferred entries from memory or vibe-check. Every finding row's `evidence` is a real `<path:line>` containing the cited fingerprint at the pinned commit. If a detector tool is unavailable (binary missing, config invalid), halt and surface — do NOT silently drop a class.

The deep-comparison entry point. Run this FIRST before `/align-plan` or `/align-fast`.

**Trust nothing.** This command does NOT take any prior "fixed" status as truth — every finding from a previous run is freshly re-verified against current source. The ledger that comes out reflects current reality, not history.

**Stack-conditional dispatch.** The detector set is PROJECT_KIND-conditional. Every project gets the 11 universal detectors:
- **6 structural**: dead-code, duplicates, reinvented-wrapper, silent-catch, over-abstraction, drift.
- **5 functional**: SOLID violations, clean-code violations, performance, security, dependencies (sub-class of security).

Frontend stacks (`frontend-*`) additionally run UI/UX detectors (a11y, design tokens, i18n, motion, lifecycle, permission gates, default-true wrapper props) — UI/UX is mandatory for frontend, not optional. Backend stacks add tenant-gate / N+1 / transaction-boundary detectors. Mobile stacks add native-bridge detectors.

## When to use

- First-time alignment of a project that's accumulated drift.
- Resuming a stalled alignment (status drift in the ledger).
- After a major architecture change — re-comparing what's still in convention.
- Before declaring a milestone done.
- Periodic cadence (monthly / quarterly) on active projects.

## When NOT to use

- Mid-feature work — the diff dominates findings; finish the feature, then run.
- Mechanical CI red (lint / typecheck / build / tests failing) — fix mechanical first via `/check-health`.
- Empty oracle — neither `_extracted-idioms.md` nor `codebase-profile.md` exists or both are empty. Run `/setup-project --refine` first. (NOTE: for projects without class-inheritance hierarchies — composition-style / functional-component stacks — Phase 2.5 of refine explicitly skips `_extracted-idioms.md` and writes only `codebase-profile.md`. The scan accepts either file as the oracle.)

## First-run guidance — what to expect

**A real codebase that has never been aligned will return 200–800+ findings on the first scan.** Phases capped at 12 findings each → 17–67+ phases. Don't try to fix all of them in one cadence.

The right approach for the first sweep:

```
/align-scan --first-run                  # excludes heavy tier + clean-code; caps at 20/class
```

Typical first-run output on a mature codebase:

```
Total findings:       95   (capped from ~400 raw fingerprints)
  Trivial:            70
  Standard:           25
  Heavy:               0   (excluded)

Class breakdown:
  dead-code:          18  (typical: 5–30 per first sweep)
  silent-catch:        8
  reinvented-wrapper: 22
  duplicated-logic:   12  (capped at 20; 8 deferred to next sweep)
  drift:              13
  security:            6  (no critical; if any, scan would surface them despite --first-run)
  performance:        12  (hot-path only)
  stack (frontend):   16  (a11y: 7, design-token: 5, i18n: 4)

Deferred to follow-up sweeps (--first-run):
  clean-code:         ~140 findings (excluded)
  heavy-tier:           4 findings (excluded; consider after team builds workflow confidence)

Recommended phases:    8 (cap: 12 findings/phase)
Estimated wall-clock:  4–8 days (fast flow) OR 8–14 days (manual flow)
```

After the first sweep completes (`/align-final`), schedule the follow-up:

```
/schedule align-scan +4w                 # next sweep includes clean-code + heavy
```

The follow-up scan picks up the deferred findings + any new drift accumulated over 4 weeks. By the second or third sweep, the codebase has reached "steady state" — fewer total findings, faster sweeps.

**Why exclude clean-code on first run**: clean-code findings (long functions, magic numbers, naming) are the highest-volume class on most codebases (often 60%+ of total findings). They're also the lowest-risk and most subjective. Including them in the first sweep dilutes attention from higher-risk classes (security, drift, reinvented wrappers).

**Why exclude heavy on first run**: heavy-tier rows require reviewer approval + impact analysis. The first sweep is for the team to build muscle memory with the workflow. Heavy rows slow it down and conflate "learning the discipline" with "shipping high-blast-radius changes".

For incremental validation on a subset before committing to a full sweep:

```
/align-scan --scope=src/auth/ --first-run    # scan one module first; verify the workflow
/align-plan
/align-fast 1
... (validate the flow on this module before scaling)
```

## Project-specific anchors (Phase 4.6 fills these)

> - **Codebase root**: `<this repo's root>`
> - **PROJECT_KIND**: `<extracted from .claude/_extracted-codebase.md>` (e.g., `frontend-vue`, `frontend-react`, `backend-node`, `backend-python`, `data-pipeline`, `mobile-rn`)
> - **Gold standards**: `<extracted from _extracted-idioms.md>` (named shared wrappers / utils / hooks / types / patterns)
> - **Test runner**: `<extracted>` (`vitest` / `jest` / `pytest` / `playwright` / `rspec` / `go test`)
> - **Lint command**: `<extracted>` (e.g., `pnpm lint`)
> - **Typecheck command**: `<extracted>` (e.g., `pnpm typecheck`)
> - **Dead-code tool**: `<extracted>` (e.g., `ts-unused-exports` / `pyflakes` / `unimport` / `staticcheck`)
> - **Duplicate detector**: `<extracted>` (e.g., `jscpd` / `pylint duplicate-code` / `dupl`)
> - **Complexity tool**: `<extracted>` (e.g., `eslint-plugin-complexity` / `radon` / `gocyclo` / `flake8 --max-complexity` / `rubocop`) — for clean-code class
> - **SOLID detector**: `<extracted>` (the project's responsibility / SOLID metric tool, OR the `refactorer` agent in `--focus=solid` mode)
> - **Performance profiler / detector**: `<extracted>` (e.g., the `performance-optimizer` agent + the project's APM if linked)
> - **Security scanner**: `<extracted>` (the `security-auditor` agent + the project's SAST tool — `semgrep` / `bandit` / `gosec` / `brakeman`)
> - **Dependency vuln scanner**: `<extracted>` (e.g., `npm audit` / `pip-audit` / `cargo audit` / `bundler-audit` / `snyk` — used by `deps-audit` skill)
> - **a11y tool** (if frontend): `<extracted>` (e.g., `axe-core` / `pa11y` / `Playwright accessibility`)
> - **Visual regression** (if frontend): `<extracted>` (e.g., `Chromatic` / `Percy` / `Playwright snapshots`)
> - **Bundle-size tool** (if frontend): `<extracted>` (e.g., `size-limit` / `bundlesize`)
> - **Observability link** (for performance baseline): `<extracted>` (e.g., Grafana board URL, Datadog dashboard ID — used to capture latency / query / HTTP baselines for perf findings)
> - **Existing alignment commands** (skip-with-redirect map): `<populated from prior /setup-project --include=align run>`

## Phase 1 — Understand (the ask)

Inputs (no user input needed for the standard path):
- Codebase root from project anchors.
- `_extracted-idioms.md` — the oracle. Names every shared wrapper / util / hook / type / pattern.
- `_extracted-codebase.md § Gold standards` — defines PROJECT_KIND + names the gold-standard files.
- `ai/conventions.md` — the project's naming + structure rules (drift detector consumes this).
- `ai/architecture.md` — the declared module boundaries (drift detector consumes this).
- Existing `ai/align/ledger.md` (read-only — used to identify rows to keep, but every status will be reset to `detected` unless `--since=<commit>` is used).

Optional flags:
- `--first-run` — sane defaults for an UNTOUCHED codebase (typically yields a manageable phase 1 + sets expectations for follow-up sweeps). Equivalent to: `--exclude-tier=heavy --exclude-class=clean-code --max-findings-per-class=20`. The first sweep ships the trivial / standard wins; clean-code + heavy follow in a subsequent run after the team has built confidence in the workflow. Recommended for any codebase that has never been aligned.
- `--scope=<path>` — limit scan to a subdirectory (e.g., `--scope=src/auth/`). Default: full repo. Useful for incremental sweeps on large monorepos OR for first-run validation on a single module before committing to a full sweep.
- `--class=<list>` — limit detector classes (e.g., `--class=dead-code,silent-catch`). Default: all classes for PROJECT_KIND.
- `--exclude-class=<list>` — skip detector classes (e.g., `--exclude-class=clean-code,solid-violation` for first-run).
- `--exclude-tier=<list>` — skip tiers (e.g., `--exclude-tier=heavy` for first-run).
- `--max-findings-per-class=<N>` — cap findings per detector (default: unlimited; first-run sets to 20). When the cap is hit, the scan reports "<class>: capped at <N> findings; <K> additional findings deferred to next sweep" and writes the deferred fingerprints to `ai/align/_deferred.md` for follow-up.
- `--include-archived` — also re-scan findings marked `archived-pre-existing` in a prior run.
- `--since=<commit>` — incremental scan. Only re-evaluate files changed since the given commit. Existing ledger rows for unchanged files keep their current status. Use on large repos (10k+ files) where re-detecting everything is expensive.
- `--no-stack` — disable PROJECT_KIND-specific detectors (universal 10 only). Use when stack pack is not loaded.
- `--max-subagents=<N>` — cap parallel detector dispatch (default: 5).

## Phase 2 — Organize (decompose the work)

The detector dispatch is parallel where independent. Orchestration:

```
                            /align-scan
                                  |
        +-------------------------+-------------------------+
        |                         |                         |
   universal-11             stack-conditional         ledger build
   (parallel waves)         (parallel waves)         (sequential after)
        |                         |
   STRUCTURAL (6):                 frontend-*:
   1. dead-code                      a11y, i18n, design-tokens, motion, data-flow,
   2. duplicates                     lifecycle, default-true-prop, permission-gate
   3. reinvented-wrapper           backend-*:
   4. silent-catch                   tenant-gate, transaction-boundary, query-without-tenant
   5. over-abstraction             data-*:
   6. drift                          column-projection, idempotency, sync-http-batch
                                  mobile-*:
   FUNCTIONAL (5):                   native-bridge
   7. SOLID-violation
   8. clean-code
   9. performance
   10. security
   11. (deps-audit, sub-class of security)
```

Wave 1 (parallel): structural detectors (6) — they read source independently.
Wave 2 (parallel): functional detectors (5) — same.
Wave 3 (parallel): stack-conditional detectors per PROJECT_KIND.
Wave 4 (sequential): merge outputs into findings draft + ledger draft (avoids row-id collisions).

Concurrency cap: `--max-subagents` (default 5). Within each wave, detectors run in parallel up to the cap.

## Phase 3 — Retrieve (read the right context)

For each detector dispatch, the agent reads:
- `_extracted-idioms.md` — the named shared equivalents (passed as a 5K-token context blob, NOT the full file, to prevent re-reading the same content per agent). For functional detectors: includes the named gate / validator / cache / escape / safe-deserializer primitives.
- `ai/conventions.md` — what counts as "drift" here (project may codify it).
- `ai/architecture.md` — declared module boundaries (drift detector cross-references).
- `.claude/rules/align-discipline.md` — closure verb vocabulary + tier triggers (so the detector emits rows with the correct tier classification).
- For functional detectors:
  - `code-quality/rules/quality-principles.md` — clean-code thresholds.
  - `code-quality/rules/engineering-principles.md` — SOLID definitions + responsibility-naming convention.
  - The project's threat model (if `ai/security/threat-model.md` exists) — security detector references.
  - The project's lockfile (`package-lock.json` / `yarn.lock` / `Pipfile.lock` / etc.) — deps-audit reads this.
  - The project's APM / observability link (if extracted) — perf detector reads dashboards for baselines.
- For frontend: the project's design-token file (`tokens.json` / `theme.ts` / Tailwind config — named in `_extracted-idioms.md`), the locale tree root (`locales/` / `i18n/` / `messages/`), and the visual-regression baseline path.

The shared 5K context blob is BUILT ONCE in Phase 2 by the orchestrator, then passed by reference to each detector subagent. Each detector reads ≤ 5K tokens of context, NOT 50K of full source — same anti-bloat rule the migration pack uses.

## Phase 4 — Generate (produce the output)

### Output 1: `ai/align/scan-report.md` (human-readable)

```markdown
# Align scan report — <YYYY-MM-DD>

Codebase: <root>
PROJECT_KIND: <kind>
Pinned commit: <sha>
Detectors run: <list>

## Codebase structure (detected)
- Framework: <name + version>
- Module layout: <description>
- Conventions source: ai/conventions.md (rev <commit>)
- Gold-standard inventory: _extracted-idioms.md (rev <commit>)

## Findings summary
| Class | Count | Trivial | Standard | Heavy |
|---|---|---|---|---|
| **STRUCTURAL** | | | | |
| dead-code | <N> | <T> | <S> | <H> |
| duplicated-logic | <N> | <T> | <S> | <H> |
| reinvented-wrapper | <N> | <T> | <S> | <H> |
| silent-catch | <N> | <T> | <S> | <H> |
| over-abstraction | <N> | <T> | <S> | <H> |
| drift | <N> | <T> | <S> | <H> |
| **FUNCTIONAL** | | | | |
| solid-violation (SRP) | <N> | <T> | <S> | <H> |
| solid-violation (OCP) | <N> | <T> | <S> | <H> |
| solid-violation (LSP) | <N> | <T> | <S> | <H> |
| solid-violation (ISP) | <N> | <T> | <S> | <H> |
| solid-violation (DIP) | <N> | <T> | <S> | <H> |
| clean-code (long-function) | <N> | <T> | <S> | <H> |
| clean-code (deep-nesting) | <N> | <T> | <S> | <H> |
| clean-code (magic-number) | <N> | <T> | <S> | <H> |
| clean-code (bad-naming) | <N> | <T> | <S> | <H> |
| performance (n-plus-one) | <N> | <T> | <S> | <H> |
| performance (sequential-await) | <N> | <T> | <S> | <H> |
| performance (sync-http-hotpath) | <N> | <T> | <S> | <H> |
| performance (missing-cache) | <N> | <T> | <S> | <H> |
| performance (missing-index) | <N> | <T> | <S> | <H> |
| performance (select-star) | <N> | <T> | <S> | <H> |
| performance (in-app-filter) | <N> | <T> | <S> | <H> |
| security (missing-auth-gate) | <N> | 0 | <S> | <H> |
| security (sql-injection) | <N> | 0 | 0 | <H> (always heavy) |
| security (xss) | <N> | 0 | <S> | <H> |
| security (secret-in-code) | <N> | 0 | 0 | <H> (always heavy) |
| security (unsafe-deserialize) | <N> | 0 | 0 | <H> (always heavy) |
| security (missing-validator) | <N> | 0 | <S> | <H> |
| security (vuln-dep) | <N> | 0 | <S> | <H> |
| security (tenant-isolation-gap) | <N> | 0 | <S> | <H> |
| security (csrf / rate-limit) | <N> | 0 | <S> | <H> |
| **FRONTEND (when PROJECT_KIND=frontend-*)** | | | | |
| a11y-violation | <N> | <T> | <S> | <H> |
| design-token-drift | <N> | <T> | <S> | <H> |
| i18n-key-drift | <N> | <T> | <S> | <H> |
| raw-library-component | <N> | <T> | <S> | <H> |
| missing-ui-state | <N> | <T> | <S> | <H> |
| motion-drift | <N> | <T> | <S> | <H> |
| responsive-drift | <N> | <T> | <S> | <H> |
| lifecycle-hook-wrong | <N> | <T> | <S> | <H> |
| default-true-prop | <N> | <T> | <S> | <H> |
| permission-gate-drop | <N> | <T> | <S> | <H> |
| **BACKEND (when PROJECT_KIND=backend-*)** | | | | |
| tenant-gate-missing | <N> | 0 | <S> | <H> |
| transaction-boundary | <N> | <T> | <S> | <H> |
| query-without-tenant-filter | <N> | 0 | <S> | <H> |

Total: <N> findings, <T> trivial, <S> standard, <H> heavy
Critical security: <C> (subset of heavy; auto-priority for phase 2)

## Top 10 findings by impact
| ID | Class | Tier | Files | Closure verb | Evidence |
|---|---|---|---|---|---|
| A001 | reinvented-wrapper | standard | 18 | replace-with-shared | src/.../<leaf-component>:42 (+17 more) |
| A002 | dead-code | trivial | 1 | remove | src/utils/old.<ext>:1 |
| ... | | | | | |

## Recommended phasing (input to /align-plan)
- Phase 1 (mechanical): dead code (12 findings, all `remove`)
- Phase 2 (security critical): SQL injection + secret-in-code + unsafe-deserialize (4 findings, all heavy, all `parameterize` / `move-to-secrets` / `replace-with-shared`) — front-loaded due to risk
- Phase 3 (security standard): missing auth gates + missing validators (10 findings, all standard)
- Phase 4 (mechanical): silent catches → error handler (8 findings)
- Phase 5 (auth domain UI/UX): a11y + design tokens + i18n on auth pages (15 findings)
- Phase 6 (perf hot-path): N+1 + sequential-await + missing cache in checkout flow (8 findings, mostly standard)
- Phase 7 (orders domain): reinvented wrappers swap to shared (10 findings)
- Phase 8 (clean-code): magic numbers + long functions in shared utils (12 findings)
- Phase 9 (SOLID): SRP splits in shared services (4 findings, standard + heavy)
- Phase 10 (deps): vuln-dep bumps (5 findings, standard)
- Phase 11 (orders): over-abstraction inlines (6 findings)
- ... (justification per phase)

Total findings: <N> across <K> phases (cap: 12 findings/phase)
Critical security ALWAYS in phase 2 (or first phase after mechanical pre-flight clear).
```

### Output 2: `ai/align/ledger.md` (canonical state machine)

Flat YAML-ish ledger, one row per finding. Schema from `ai/patterns/align-ledger.md`:

```yaml
# Structural example (extension and shared-wrapper names abstracted —
# substitute your stack's extension and shared-wrapper inventory; pattern is identical across stacks)
- id: A001
  class: reinvented-wrapper
  scope: [<components-root>/auth/LoginForm.<ext>, <components-root>/auth/SignupForm.<ext>, <components-root>/auth/PasswordReset.<ext>]
  evidence:
    - <components-root>/auth/LoginForm.<ext>:42     # raw <Button> from a UI lib; project has its shared <AppButton>
    - <components-root>/auth/SignupForm.<ext>:67
    - <components-root>/auth/PasswordReset.<ext>:31
  closure_verb: replace-with-shared
  shared_equivalent: <components-root>/AppButton.<ext> (per _extracted-idioms.md § Buttons)
  tier: standard
  tier_reason: "3 files; cross-component swap; mechanical (API-equivalent)"
  status: detected
  phase: <unassigned>
  detected_at: 2026-05-01T19:46:00Z
  notes: ""

# Structural — dead code
- id: A002
  class: dead-code
  scope: [<utils-root>/old-formatter.<ext>]
  evidence:
    - <utils-root>/old-formatter.<ext>:1         # exported, no inbound import
  closure_verb: remove
  tier: trivial
  status: detected
  ...

# Security — critical (always heavy)
- id: A047
  class: security
  subclass: sql-injection
  severity: critical
  scope: [<source-root>/reports/orders.<ext>]
  evidence:
    - <source-root>/reports/orders.<ext>:88      # `WHERE status = '<interpolated-user-input>'` — string interpolation
  closure_verb: parameterize
  idiom_cited: <source-root>/db/query.<ext>:14 (parameterized query primitive per _extracted-idioms.md § DB)
  tier: heavy
  tier_reason: "critical security — SQL injection on production endpoint; auto-promoted"
  status: detected
  phase: <unassigned>
  detected_at: 2026-05-01T19:46:00Z
  notes: ""

# Security — standard
- id: A048
  class: security
  subclass: missing-auth-gate
  severity: high
  scope: [<source-root>/routes/admin/export.<ext>]
  evidence:
    - <source-root>/routes/admin/export.<ext>:12 # GET /admin/export — no auth middleware
  closure_verb: add-gate
  idiom_cited: <source-root>/auth/gates.<ext>:7 (requireAdmin gate per _extracted-idioms.md § Auth)
  tier: standard
  tier_reason: "security finding — never trivial; auto-promoted to standard"
  status: detected
  ...

# Performance — N+1
- id: A082
  class: performance
  subclass: n-plus-one
  scope: [<services-root>/listOrders.<ext>]
  evidence:
    - <services-root>/listOrders.<ext>:42        # parallel iteration over orders, each calls getCustomer(id)
  closure_verb: batch
  idiom_cited: <source-root>/repos/customers.<ext>:88 (getByIds batch primitive)
  tier: standard
  tier_reason: "hot-path perf finding; standard floor"
  status: detected
  notes: "Baseline: 51 queries / 200ms p95 for 50-order list (observability dashboard ID xyz)"
  ...

# SOLID — SRP
- id: A105
  class: solid-violation
  subclass: SRP
  scope: [<services-root>/checkoutService.<ext>]
  evidence:
    - <services-root>/checkoutService.<ext>:1    # 540-line class; tax + shipping + payment + notification
  closure_verb: split-extract
  idiom_cited: _extracted-idioms.md § Service responsibilities (TaxCalculator, ShippingCalculator, PaymentProcessor, NotificationService — all already exist)
  tier: heavy
  tier_reason: "shared service module touched; > 10 consumers downstream"
  status: detected
  ...

# Clean code — long function
- id: A130
  class: clean-code
  subclass: long-function
  scope: [<source-root>/checkout/processOrder.<ext>]
  evidence:
    - <source-root>/checkout/processOrder.<ext>:42  # 143 lines; project max is 50 (per ai/conventions.md § complexity)
  closure_verb: extract-to-shared
  idiom_cited: _extracted-idioms.md § Service responsibilities (existing services)
  tier: trivial
  status: detected
  ...
```

### Output 3: `ai/align/findings.md` (drill-down per finding)

One section per finding with the full detector context (excerpts from source, the fingerprint pattern matched, the shared equivalent, link to convention/idiom doc). Used by `/align-phase` at DETECT time to confirm the fingerprint is still present.

```markdown
# Findings — <YYYY-MM-DD>

## A001 — reinvented-wrapper

### Evidence

<components-root>/auth/LoginForm.<ext>:42
```text
# pseudocode — concrete syntax varies by stack
RawButton(variant="primary", onClick=handleLogin) { "Login" }
```

<components-root>/auth/SignupForm.<ext>:67
```text
RawButton(variant="outlined", onClick=handleSignup) { "Sign up" }
```

(... 1 more cited in ledger ...)

### Shared equivalent (per _extracted-idioms.md § Buttons)

<components-root>/AppButton.<ext>
```text
# the project's button wrapper — wraps the raw UI-library button with project tokens
AppButton(kind, ...props)
```

### Closure verb: replace-with-shared

For each evidence line, replace the raw button with the project's wrapper (`AppButton kind="primary"` etc.). Preserve all other props. (Concrete syntax varies by stack.)

### Tier: standard
Reason: 3 files touched; API-equivalent swap; mechanical.

---

## A002 — dead-code

(... )
```

### Output 4: `ai/align/halts/` (empty dir)

Created at scan time. Populated by `/align-phase` when a row halts. Used by `/align-gate` to enumerate blockers.

### Output 5: Update `ai/align/_session-digest.md`

One-line summary: scan complete, N findings, K phases recommended.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/align/scan-report.md` — managed-block markers; re-runnable.
- `ai/align/ledger.md` — managed-block; existing user-added notes preserved by `id`.
- `ai/align/findings.md` — managed-block per finding section.
- `ai/align/halts/` — created if missing.
- `ai/index.md` — append-once entry pointing to the new ledger + scan report.

## Phase 6 — Validate (verify correctness)

- Every finding has ≥ 1 `evidence` citation.
- Every `evidence` `<path:line>` resolves to a real file at HEAD; the cited line contains the fingerprint the row claims (re-verified by re-running the detector at scope-of-one).
- No hand-wave tokens (`etc.`, `...`, `several`, `multiple`) in any field.
- Every row has a `closure_verb` in the universal vocabulary.
- Every row has a `tier` ∈ `{trivial, standard, heavy}` matching the promoter rules in `align-discipline.md`.
- All 11 universal detectors ran (none silently skipped). For frontend stacks: + a11y / i18n / design-token / data-flow / motion. For backend stacks: + tenant-gate / N+1 / transaction-boundary.
- Every security finding has `severity ∈ {low, medium, high, critical}`.
- Every security finding has `tier ≥ standard` (no security-trivial rows).
- Every functional finding (SOLID / clean-code / perf / security) has `idiom_cited` resolving to an entry in `_extracted-idioms.md`.
- Every perf finding has a baseline note in `notes` (queries / latency / HTTP count) OR the row is parked-pending-baseline.

If any check fails → halt + report. Surface the failure with a remediation note.

## Phase 7 — Improve (feed the learning loop)

- If a detector class returned 0 findings, note "0 findings" explicitly in the report (not omitted) — silence is itself a signal worth verifying.
- If a finding class returned > 50 findings, surface "high-volume class — recommend dedicated phase or `/setup-project --refine` to update gold standards" — high counts often indicate the oracle is incomplete, not that the codebase is uniquely broken.
- If a finding's `shared_equivalent` cannot be resolved (named in `_extracted-idioms.md` but file doesn't exist) → that's an oracle-drift signal; halt and route to `/setup-project --refine`.
- If the same fingerprint appeared in a prior scan, was marked `fixed`, and is now detected again → that's a regression; flag in the report and queue an ADR for the convention's enforcement (a hook? a lint rule?).
- **Idiom-drift detection** — at the end of every scan, compare the git hash of `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` against the hashes recorded in the prior scan's `ai/align/_session-digest.md`. If any oracle file's hash changed:
  1. Surface a "Idiom drift detected" section in `scan-report.md`:
     ```
     ## Idiom drift detected since last scan (2026-04-01)

     Changed oracles:
     - _extracted-idioms.md (hash abc → def): 3 idioms added (BaseDataTable, AppDropdown, useToast), 1 modified (useCrud — return shape changed), 0 removed.

     Affected ledger rows (rows whose `idiom_cited` references a changed idiom):
     - A042 (reinvented-wrapper): cited useCrud at <path:line> — return shape changed; recommend re-detect via /align-recheck.
     - A058 (silent-catch): cited handleApiError at <path:line> — unchanged; no action needed.
     - ... (12 more)

     Recommended actions:
     - /align-recheck the orders module     # if drift affects a specific area
     - /align-replan --include-drifted      # to re-phase affected rows globally
     ```
  2. Update `ai/align/_session-digest.md` with the new oracle hashes for future drift detection.
  3. Do NOT auto-flip status of any row — surface the drift, let user decide via replan or recheck.

## Output to user

```
Align scan complete:
  PROJECT_KIND:               <kind>
  Total findings:             <N>
    Trivial:                  <T>
    Standard:                 <S>
    Heavy:                    <H>

  Class breakdown:
    Structural:               <N> (dead-code, dups, reinvented, silent-catch, over-abstraction, drift)
    SOLID:                    <N>
    Clean-code:               <N>
    Performance:              <N>
    Security:                 <N> (critical: <C>, high: <Hi>, medium: <M>, low: <L>)
    Stack-specific:           <N>

  Detectors run:              <count> (universal: 11, stack-specific: <K>)
  Recommended phases:         <P> (cap: 12 findings/phase)
  Critical security front-loaded to phase 2.
  Pinned commit:              <sha>

Reports:
  ai/align/scan-report.md     (deep analysis)
  ai/align/ledger.md          (flat status table)
  ai/align/findings.md        (per-finding drill-down)

Next: /align-plan          (consumes scan + ledger; produces phased plan)
```

## Mechanical halt — refuse to fabricate findings

Every finding row MUST trace to readable source at the pinned commit. Forbidden: writing a row with `evidence` that doesn't resolve; writing a row inferred from architecture docs or prior conversations without re-running the detector; using `...`, `etc.`, `and similar`, `multiple sites`, `~N occurrences` in any field; writing a row whose `class` doesn't match the detector signal (e.g., `dead-code` row whose evidence shows an active import). If a detector tool is unavailable → halt and report; do NOT skip the class silently and do NOT invent rows by hand.

Every row in the output must be re-derivable by another reader given the same commit + the same detector tool.

## Hard rules

- **Trust nothing** — every status reset to `detected` (unless `--since=<commit>` is used).
- **No silent fixes** — this command DOES NOT write any code. It only inventories. Fixing happens in `/align-phase` or `/align-fast`.
- **No drops** — every detector hit must appear in the ledger. If a fingerprint is detected but classified as "false positive", the row exists with `status: archived-pre-existing` and `notes: <why>`.
- **No oracle modification** — `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md` are READ-ONLY in this command. If the oracle is wrong, halt and route to `/setup-project --refine`.
- **PROJECT_KIND drives stack dispatch** — for `frontend-*`, UI/UX detectors are mandatory; refusing to run them (even via `--no-stack`) requires a 1-line justification in the scan report.

## Failure modes

- **Empty oracle** — neither `_extracted-idioms.md` NOR `codebase-profile.md` exists / populated. Halt; route to `/setup-project --refine`. The scan accepts EITHER file as the oracle (preferring idioms when present, falling back to profile when idioms is absent — which is the normal case for composition-style / functional-component projects where Phase 2.5 of refine skips idioms because there's no class-inheritance hierarchy to extract).
- **Mechanical red** — lint / typecheck / build / tests failing. Halt; the existing red drowns alignment findings.
- **Detector tool missing** — e.g., `jscpd` not installed. Halt; surface the install command from the project's `package.json` / `Makefile`.
- **Stack pack missing** — `PROJECT_KIND=frontend-vue` but no `frontend/` pack loaded. Halt; surface the missing pack and offer `--no-stack` as a workaround (with the explicit downgrade noted in the report).
- **Visual regression baseline missing** (frontend) — UI/UX phases need a snapshot baseline to validate fixes; halt; route to "run the project's snapshot baseline command first".

## Related

### Sibling commands in align pack
- `/align-plan` — next command; consumes scan output, produces phased plan.
- `/align-phase <N>` — executes a single phase from the plan.
- `/align-gate <N>` — phase exit verifier.
- `/align-fast` — one-shot: scan + plan + all phases + gate.
- `/align-status` — read-only ledger reader.

### Skills
- `.claude/skills/detect-drift.md` — the detector procedure dispatched by this command.

### Cross-pack references
- `code-quality/commands/check-health.md` — pre-flight mechanical check; run before this command.
- `code-quality/agents/dead-code-finder.md` — dispatched for the dead-code class.
- `code-quality/agents/refactorer.md` — dispatched in detect-only mode for over-abstraction.
- `frontend/agents/accessibility-auditor.md` — dispatched for `frontend-*`.
- `frontend/agents/i18n-auditor.md` — dispatched for `frontend-*`.
- `frontend/agents/data-flow-auditor.md` — dispatched for `frontend-*`.
- `ui-ux/skills/design-token-audit.md` — dispatched for `frontend-*`.
- `ui-ux/skills/motion-audit.md` — dispatched for `frontend-*`.
- `frontend/rules/migration-frontend.md` — frontend fingerprint set for stack-anti-pattern detector.
- `backend/rules/migration-backend.md` — backend fingerprint set for stack-anti-pattern detector.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.

### Patterns
- `ai/patterns/align-ledger.md` — schema for the ledger this command writes.
