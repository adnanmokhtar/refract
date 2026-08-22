---
name: align-discipline
description: Align Rule — codebase alignment discipline (drift from gold standard, refactor scope creep, trusted-summary failure)
kind: rule
pack: align
severity: must
applies-to: align-track, every-alignment-sweep
---

# Align Rule: codebase alignment discipline

> **Project-specific values** (codebase root, gold-standard inventory, test runner, PROJECT_KIND, architecture / conventions / findings-ledger paths) are auto-injected into the `project-specific` block at the bottom of this file by `scripts/apply-anchors.sh`, sourced from `.claude/_extracted-codebase.md § Gold standards` + `_extracted-idioms.md`. Edit the extraction sources and re-run `/setup-project --refresh` — never edit the injected values here.

This rule governs every codebase-alignment sweep. It exists because codebases rot three ways, and audits cite these names: **drift from the gold standard** (clean conventions accrete one-off helpers, custom wrappers, silent catches and copy-pasted logic until "the codebase" and "the conventions" describe two different repos) · **scope creep during refactor** (a "small cleanup" becomes a redesign + perf project + refactor in one unreviewable PR) · **trusted summary** (an executor delegates "is this duplicated / dead / drift?" to a search agent, the agent says "looks fine", and the executor echoes that into the report unverified).

This rule is the universal contract — enforceable by any AI tool. Full-capability tools compose it by dispatch (`/align-scan` → `/align-plan` → `/align-phase` → `/align-gate` → `/align-final`, with `/align-fast` as the one-shot equivalent); rule-only tools follow this file directly. Of the adapters this repo ships, **only Aider is rule-only** (`tool-adapters/_registry.md:23` — closed slash set, no user-extensible primitive at any layer); Codex (`.agents/skills/`), Gemini (`.gemini/commands/*.toml`), Cline (`.cline/skills/`) and Windsurf (`.windsurf/workflows/`) each have an executable command primitive and take the dispatch path — `_registry.md § Command translation` verifies all four against vendor docs and lists "Gemini has no executable primitive" among its doc-verified FALSE claims. **Enforcement floor**: this rule plus the two patterns that install with the pack — `ai/patterns/align-ledger.md` (row schema + ten-state machine) and `ai/patterns/align-guardrails.md` (the eight guards, six supporting mechanisms and their thresholds, the anti-bloat merge gates, the enforcement matrix, the named anti-patterns). **`references/` is not a delivery path**: `templates/phases/phase-4.2-apply.md:210-213` copies `references/<name>.md` only when `<name>` equals a **detected framework name**, so no installed project has ever received `align-discipline-{procedures,catalogue}.md`. Nothing enforceable — no halt, no threshold, no vocabulary — is stored there.

## Scope

Align is the codebase's quality gate. It covers every finding class that affects correctness, security, performance, structure or maintainability — not just structural drift. The classes themselves are enumerated once, in § Finding categories below; do not restate them here.

**What align does NOT cover** — route elsewhere:
- A behaviour-changing bug (incorrect output, crash, wrong state) → `fix-bug` / dedicated tests.
- A new feature → feature-flow.
- A V1→V2 port across parallel codebases → `/migration-*`.
- A reorganisation that changes module boundaries, or adopting a new framework → `/refactor` + ADR.
- A perf change that requires breaking the contract (changing pagination behaviour, adding a required parameter, removing a field) → `/refactor` + ADR + caller-migration plan.
- A security finding that requires changing an interface contract (adding a required auth header where none was required) → `/refactor` + ADR. Align handles the closure *inside* the existing contract.
- Introducing finish the project does not have yet — a token, a state, a wrapper that does not exist → `/polish`. Align snaps to what exists; creating it is new finish.
- Release / deployment / infra → out of scope.

A finding's class drives four things: which **detector** surfaces it · which **closure verb** fixes it · which **net-lines rule** applies (structural ≤ 0 hard; functional small-+ budget that must cite idioms) · which **tier promoter** triggers (security ALWAYS ≥ standard; critical-security ALWAYS heavy).

## Relationship to migration discipline

Align is the migration discipline turned inward — same tiering, same audit rigor, same closure-verb model, but the oracle is the project's OWN gold-standard inventory (`_extracted-idioms.md`) instead of V1. There is no second codebase, so align has no parity test, no shadow/canary and no cutover; it substitutes the net-lines rule.

## Required artifacts per finding — tiered floor

Every finding-fix produces an artifact set scaled to its actual risk. Tier is set on the ledger row at scan time and propagates through the fix.

### Tier classification (set by scan; trivial-by-default for structural; ≥ standard for security)

| Tier | Triggers (any one promotes) | Required artifacts |
|---|---|---|
| **trivial** (DEFAULT for structural classes) | No promoter triggers AND class is NOT security | Ledger row + code edit |
| **standard** | 3–10 files touched OR cross-module symbol rename OR newly-introduced shared helper consumed by 3+ sites OR class is security (any severity) OR class is performance on a hot path OR class is SOLID violation in a shared module | + 1-paragraph rationale in the row's `notes` |
| **heavy** | Any of: cross-package boundary change OR public API surface change OR removes a symbol used outside the module being aligned OR touches >10 files OR touches an auth / data / billing / migration path OR class is critical-security (auth bypass / SQL injection on production endpoint / secret-in-committed-code / RCE vector) OR perf change ships an index migration | + impact analysis (file+line of every consumer) + reviewer-approved before merge |

**Rules**:
- **Default tier is trivial for structural classes** (dead-code, dups, reinvented-wrapper, silent-catch, over-abstraction, drift), unless a standard / heavy promoter above fires.
- **Security findings are NEVER trivial** — always ≥ standard; critical security ALWAYS heavy; downgrading a security row is forbidden. This floor is absolute and is repeated nowhere else in this rule.
- **Performance** starts at standard for hot-path code (entry endpoints / request handlers / loop-bound), trivial for cold paths (test setup / one-time scripts / debug builds). **SOLID** starts at standard in shared modules, trivial in private internals. **Clean-code** is typically trivial unless the rename touches a public API name.
- Tier is **set by scan**, written to the row's `tier:` + `tier_reason:`; the scan MUST state the tier in 1 sentence per row citing trigger absence/presence.
- Heavy requires a scan-flagged trigger OR explicit user opt-in via `/align-phase <N> --heavy`. Users may **upgrade** anytime; **downgrade needs a 1-line justification** in `notes`.
- `/align-gate <N>` validates the artifact set **for the row's tier**, not the heavy floor universally. Over-production is allowed but never rewarded.

## Anti-bloat rules

Merge gates: code edits are the deliverable · per-axis enumeration wherever a gap exists · hand-wave grep HALTs (`etc.` / `...` / `N+ items`) · single dispatch + shared context blob default · audit verdict = convention-parity, not plan-execution. Full gate definitions, the closed 21-verb closure vocabulary and the net-lines rule: `ai/patterns/align-guardrails.md § Anti-bloat merge gates`.

## Realism guards

Eight execution-time guards keep the discipline survivable on real codebases — **scope cap · batch ceiling · skip-list honoring · mechanical-red short-circuit · oracle-absence fallback · dirty-tree behaviour · flaky-test quarantine · large-file sampling**. Definitions, thresholds and the output line each one must emit: **`ai/patterns/align-guardrails.md § The eight realism guards`**. Commands apply them silently; audits cite a guard **by name** when one fires.

Two properties make them safe: a guard reduces what was *examined* and says so — it never converts an examined failure into a pass (mechanical-red and dirty-tree halt outright); and **a guard that fires without a line in the output makes a reduced sweep indistinguishable from a clean codebase**, which is the Trusted Summary with a mechanical cause instead of a lazy one. Six supporting mechanisms decide whether an examined result *counts*, who signs it off, and what happens when the oracle moves — rather than bounding what is examined. Commands and agents cite them by name: **coverage tolerance** (±0.5% default; a drop beyond it is a halt), **parallel race serialization**, **baseline-capture fallback**, **reviewer approval**, **mid-sweep tier promotion**, **idiom-drift propagation** — all six with thresholds in `ai/patterns/align-guardrails.md § Supporting mechanisms`, which installs unconditionally.

## Finding categories — universal taxonomy

Eleven universal classes: **6 structural** (entropy-reducing; `net-lines ≤ 0` is a hard rule) and **5 functional** (correctness-improving; added lines allowed on a small budget and must cite an idiom). A twelfth class value, `stack-specific`, carries the per-stack findings the stack packs define. Per-stack packs extend the taxonomy; these are the universal floor every project gets.

| Group | Classes |
|---|---|
| **Structural** (net-lines ≤ 0 hard) | `dead-code` · `duplicated-logic` · `reinvented-wrapper` · `silent-catch` · `over-abstraction` · `drift` |
| **Functional** (small + budget, cite an idiom) | `solid-violation` · `clean-code` · `performance` · `security` · `unhandled-io` |
| **Stack-conditional** | `stack-specific` — frontend (a11y, design tokens, i18n, motion, lifecycle, default-true wrapper props, permission-gate drop) · backend (tenant gate, transaction boundary) · data (column projection, idempotency) · mobile (native bridge) |

**Detector fingerprint, default closure verb, tier suggestion and severity rubric per class are defined once — in `detect-drift`, Detectors 1–11.** That skill is the executable form and ships with the pack; this rule does not restate it. Three boundaries are decided here, because each is decided wrongly often enough to have produced findings:

- **`silent-catch` vs `unhandled-io`** — in `silent-catch` an error path exists and swallows it; in `unhandled-io` there is no error path at all (no catch, no error-return check, no timeout where the medium needs one, no failure surfaced). `unhandled-io` is the canonical AI-generated-code defect: fetch-and-render / fetch-and-write that works on the first run and hangs or crashes on the first failure. It is **functional, not structural** — its fix routes the call through the project's wrapped I/O primitive and legitimately adds lines. If no wrapped primitive exists for that medium, halt → `/setup-project --refine`; never hand-roll try/catch per site.
- **`drift` requires a written convention.** A deviation is `drift` only when the convention is documented in `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md`. A codebase where half the modules do X and half do Y, with the oracle naming neither, has **no `drift` row available** — that is a bimodal convention, and the route is `/setup-project --refine` (adopt one into the oracle) or `/polish` (introduce one). Picking a winner by majority vote is introducing a convention, not enforcing one.
- **`security` sub-classes carry a `severity`**, and severity — not class — sets the heavy floor. `sql-injection`, `secret-in-code`, `unsafe-deserialize` and anything `severity: critical` are heavy; the rest are standard.

## Per-finding audit — 11 hard halts

The DETECT step runs against a finding row + its evidence. The audit HALTS (refuses to advance the row) on any of these 11 conditions:

1. **No evidence** — finding row's `evidence` field empty OR `<path:line>` doesn't resolve OR cited line doesn't actually contain the fingerprint the row claims. Validator: `check_evidence_resolves`.
2. **Hand-waved enumeration** — the row uses `etc.`, `...`, `&...`, `and so on`, `several places`, `a few sites`, `N+ duplicates`, `multiple call sites`, `multiple endpoints` in any field. Each instance gets its own row OR one row with an explicit `<path:line>` per instance in `evidence`. Validator: `check_no_handwaves`.
3. **Wrong category** — the class doesn't match the detector signal (a row classed `dead-code` whose evidence shows an active import; a row classed `security` whose evidence shows no risk vector). Re-classify or remove.
4. **Closure verb outside vocabulary** — the verb is not in the closed set of 21. **Structural (5):** `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`. **Functional (16):** `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`. Anything else is a refactor / redesign / new feature; route elsewhere. Validator: `check_closure_verb_in_vocab`.
5. **Net-positive line count on structural class** — the diff adds more than it removes AND the class is structural. Halt; revert; redo. Functional classes are exempt (see #6). Validator: `check_net_lines_structural`.
6. **Functional fix doesn't cite idiom** — the fix adds lines, the class is functional, and the added lines reference no idiom in `_extracted-idioms.md` (gate wrapper, validator helper, cache primitive, safe deserializer). Either the idiom is missing (route to `/setup-project --refine`) or the fixer is inventing. Validator: `check_added_lines_cite_idioms`.
7. **Behaviour change (where preservation is required)** — touched files have tests and the tests fail, coverage drops, or an unexpected snapshot diff appears. Halt; revert. **Security fixes MAY change behaviour intentionally** (adding an auth gate denies previously-allowed unauth access); such a change is documented in `notes` and its test fixtures are updated in the SAME commit. This halt fires only on the unintentional or undocumented case.
8. **Scope creep** — the diff touches files outside the row's `scope` field (the list named at scan time). Halt; the fix violates one-finding-per-commit. Validator: `check_scope_boundary`.
9. **New abstraction introduced** — the diff introduces a symbol (function / class / type / interface / file) NOT named in `_extracted-idioms.md`. Either it belongs in the inventory (`/setup-project --refine`) or the fixer is inventing. Validator: `check_no_new_symbols`, which exempts symbols listed in idioms.
10. **Reinvented wrapper without justification** — a `replace-with-shared` fix introduces a NEW shared helper rather than using the one named in `_extracted-idioms.md`. Either the inventory is incomplete or the shared equivalent was mis-identified.
11. **Security finding without standard-tier rationale** — a security-class row set to trivial tier OR with empty `notes`. Promote to standard with rationale, or re-classify if the row was wrongly tagged. Validator: `check_security_tier_minimum`.

**Output of any halt**: a structured remediation note — specific finding row + specific action — written to `ai/align/halts/<row-id>.md`. NO advance until each halt is cleared.

## Per-stack extensions and tool-agnostic procedure

The universal classes are necessary but not sufficient per stack — frontend / backend / mobile / data packs add their own detectors, fingerprints and closure-verb vocabularies, routed by `PROJECT_KIND`. Each stack pack's own rules carry its detector table; this rule stays stack-agnostic and concrete component / hook / library names belong there. The canonical detect → decide → fix → verify → record loop is dispatched as skills `detect-drift` / `find-and-align`; rule-only tools read the same loop verbatim from those two `SKILL.md` files, which install with the pack and which every adapter translates — not from `references/`, which does not install.

## Must

- **Inventory the gold standard before scanning.** `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` are the oracle. If `_extracted-idioms.md` is empty, halt and run `/setup-project --refine`. Without an oracle, "alignment" is just opinion.
- **Read source before flagging.** Every finding cites `<path:line>` evidence that resolves. A row you did not open is a row you cannot pass; if the count is large, say how many you actually read and mark the remainder `UNAUDITED` — never `PASS`. Trusted Summary is the #1 way sweeps miss real drift, missing auth gates and N+1 patterns.
- **Default to trivial tier for structural classes.** Most are a 1-line `remove` or 1-symbol `dedupe`; promoting without a trigger is over-ceremony. The security floor in § Tier classification is the one exception and it is absolute.
- **One finding per atomic commit.** Bundling hides which fix caused which downstream effect and makes rollback all-or-nothing. The phase PR contains N commits = N findings. A security commit MAY change behaviour intentionally; its test update ships in the same commit and nothing else does.
- **Net-lines rule by class group** — structural rows: ≤ 0 per row, per phase (entropy-reducing). Functional rows: small + budget, and every added block cites a `<path:line>` idiom in `_extracted-idioms.md`. Validator: `check_added_lines_cite_idioms`.
- **Closure-verb vocabulary is the combined list of 21** — 5 structural + 16 functional, enumerated in halt #4. If the fix doesn't fit one, it isn't alignment; route elsewhere.
- **No new abstractions.** Even functional verbs like `add-validator` / `cache-with-explicit-ttl` use the project's existing helper named in `_extracted-idioms.md`. `extract-to-shared` and `split-extract` move code to PRE-NAMED idioms. If the project lacks the abstraction the fix needs, halt and route to `/setup-project --refine` to add it to idioms first, THEN align. Enforced by halts #9 and #10.
- **Test before declaring fixed** — lint + typecheck + scoped tests + re-detect, all four green. One red is a halt, and if mechanical produced red the row was mis-classified. For security rows: + the security assertion. For perf rows: + the perf assertion. For frontend UI/UX rows: + a11y / visual / bundle-size. Skipping any is a Trusted-Summary failure waiting to surface.
- **Update the ledger on every state transition**, per `ai/patterns/align-ledger.md`: `detected → planned → in-progress → fixed → verified`, with side states `halted`, `parked`, `pending-review`, `archived-pre-existing`, `archived-deprecated`. The ledger is the source of truth — code grep is not.
- **Heavy-tier rows require reviewer approval before merge.** A symbol used outside the module has consumers; a critical-security row has user-facing risk. A human reads the impact analysis; their name + timestamp goes in the row's `reviewer_approval`.
- **Gap-count parity** (`gaps_in == gaps_closed`) — every evidence line surfaced at DETECT is closed at VERIFY. A row that closes 7 of 8 is `status: halted`, not `status: fixed`.
- **Security and perf changes ship with assertions.** A gate without a test asserting it gates; a `parallelize` without a perf assertion or observability annotation — these are halts. The fix isn't done until the regression-prevention test exists: for a gate, a test that unauth is denied; for a validator, that malformed input is rejected; for an escape, that a known-XSS payload is neutralised; for an `add-index`, an `EXPLAIN ANALYZE` capture; for a cache, a cache-hit assertion.
- **Say what you did not run.** A detector class skipped, a check that could not execute, a file read only in part — each appears as an explicit line naming the guard that caused it. A check that vanished from a report is a refusal, not a pass.

## Must not

- **Bundle findings in a commit.** "Cleanup: dead imports + dedupe utility + silent catch fixes + auth gate" guarantees an impossible review and an all-or-nothing rollback.
- **Skip the ledger.** A merged PR that closes findings without updating `ai/align/ledger.md` is incomplete. `/align-gate` halts on ledger drift.
- **Treat "no test exists for this" as "no behaviour exists".** A dead-code candidate with no test might still be a runtime hot path (cron, queue consumer, integration with no unit test). Read git log and grep for callers in adjacent repos before removing.
- **Hand-wave enumeration.** `~8 dead exports` / `several silent catches` / `multiple missing auth gates` — these are vibes, not findings. Enforced as halt #2.
- **Modify the oracle in the alignment PR.** `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md` changes ship via `/setup-project --refine`, not via a finding fix. Mixing them lets the PR redefine the oracle to "match" what the fix did, which defeats the audit. Validator: `check_oracle_unmodified`.
- **Promote or demote tier silently.** A tier is set at scan; promoting later requires a 1-line justification in `notes`. Silent promotion is how heavy work hides as trivial; demoting a security row below standard is forbidden outright.
- **Bump a vulnerable dependency without running the test suite.** A `bump-dep` that breaks tests is a feature change in disguise; route to a separate dependency-migration ticket.
- **Carry V1 patterns into align findings.** If the project is also running a V1→V2 migration, alignment fixes use V2's gold standard, never V1's old shape. The migration rule's "Structure → V2 wins" applies inside align too.
- **Combine intentional behaviour change with unrelated alignment in one commit.** A security gate that changes behaviour ships in its own commit; mixing it with a refactor or feature hides the security change.
- **Park a finding as a way of closing it.** Park is deferral with a reason, a blocker category, a revisit date, and the prior state to return to — `/align-park` captures `prior_status` + `prior_phase` or the row can never be revived. A parked `class: security` row keeps its escalation clock; see `ai/patterns/align-guardrails.md § Named anti-patterns → The Silent Park`.

## Should

Lowest-risk class first · batch by class not by file · re-run detectors after each phase · prefer extending shared primitives over new ones · cite occurrence counts in every finding. Each is a default, not a halt; deviate with a one-line reason in the row's `notes`.

## Enforcement

`scripts/validate-align-artifacts.sh` script-enforces 11 of the 14 phase-exit checks. Ledger completeness, coverage tolerance and frontend regressions are **agent-side** and are labelled `(agent-side)` in every gate report so nobody reads them as machine-verified. Named anti-pattern → the check that catches it, gate behaviour, and the SLA clocks (`in-progress` > 7d stalled; a halted `class: security` row > 24h escalated): `ai/patterns/align-guardrails.md § Named anti-patterns` and `§ Enforcement — gate behaviour, SLA clocks, anti-pattern → check`.

## Anti-patterns (named)

The names are load-bearing vocabulary — audits cite them, `/align-status` groups by them, `/align-final` counts them. The catalogue, with a fingerprint and the catching check for each: **`ai/patterns/align-guardrails.md § Named anti-patterns`**.

## Load on demand

**Align's own agents** — `.claude/agents/align-{evidence,idiom,gate,ledger}-auditor.md`. Four audit windows over a finding's life: scan output, one diff, one phase, all state. They own the halts this rule defines; detection stays with the packs that own each discipline (`code-quality`, `security`, `performance`, `frontend`, `ui-ux`, `mobile`).

**Installed with the pack, always reachable** — `ai/patterns/align-ledger.md` (row schema, ten-state machine, required fields per state) · `ai/patterns/align-guardrails.md` (the eight guards, the six supporting mechanisms and their thresholds, the anti-bloat merge gates, the enforcement matrix, the named anti-patterns) · skills `detect-drift` (the 11 detectors) and `find-and-align` (the fix loop). Oracle: `_extracted-idioms.md`.

**Companion reference files — pack-side only, NOT installed.** `references/align-discipline-procedures.md` (worked scan / fix-loop / closure-verb / gate procedures, review checklist, relationship to migration discipline) and `references/align-discipline-catalogue.md` (worked examples per finding class, per-stack extensions, Should — full guidance, per-tool dispatch tables) live in the pack for authors and for any adapter bundle that chooses to carry them. Phase 4.2 copies `references/<name>.md` only for a **detected framework name** (`phase-4.2-apply.md:210-213`), so a project does not receive them and nothing above depends on them. Every halt, threshold, vocabulary item and enforcement mapping this rule names lives in this file, in `ai/patterns/align-{ledger,guardrails}.md`, or in the `detect-drift` / `find-and-align` skills — all of which install.
