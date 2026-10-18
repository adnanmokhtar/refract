---
name: align-discipline
description: Align Rule — enforce the project's DECLARED conventions (oracle-cited rows, EQ/VC/FN proof, owner routing, scope creep, trusted-summary failure)
kind: rule
pack: align
severity: must
applies-to: align-track, every-alignment-sweep
---

# Align Rule: declared-convention enforcement

> **Project-specific values** (codebase root, gold-standard inventory, test runner, PROJECT_KIND, architecture / conventions / findings-ledger paths) are auto-injected into the `project-specific` block at the bottom of this file by `scripts/apply-anchors.sh`, sourced from `.claude/_extracted-codebase.md § Gold standards` + `_extracted-idioms.md`. Edit the extraction sources and re-run `/setup-project --refresh` — never edit the injected values here.

This rule governs every alignment sweep. It exists because codebases drift three ways, and audits cite these names: **drift from the declared convention** (the lint config, the conventions doc, an ADR, the token set and the named wrappers say one thing, and live sites do another) · **scope creep during a sweep** (a "small cleanup" reorders imports, re-records a snapshot or resolves one pattern two ways in one unreviewable PR) · **trusted summary** (an executor asks "is this drift?", a search agent says "looks fine", and the report echoes it unverified).

This rule is the universal contract — enforceable by any AI tool. Full-capability tools compose it by dispatch (`/align-scan` → `/align-plan` → `/align-phase` → `/align-gate` → `/align-final`, with `/align-fast` as the one-shot phase runner and `/align --from-audit` as the simple surface); rule-only tools follow this file directly. Of the adapters this repo ships, **only Aider is rule-only** (`tool-adapters/_registry.md:23`); Codex, Gemini, Cline and Windsurf each have an executable command primitive and take the dispatch path. **Enforcement floor**: this rule plus the two patterns that install with the pack — `ai/patterns/align-ledger.md` (row schema, fourteen-state machine) and `ai/patterns/align-guardrails.md` (the eight guards, six supporting mechanisms, merge gates, enforcement matrix, named anti-patterns). **`references/` is not a delivery path**: `phase-4.2-apply.md` § 4.3 copies `references/<name>.md` only for a detected framework name, so nothing enforceable is stored there.

## Scope

**Align enforces conventions the project already declares.** A declaration is the **oracle**: a rule at `error` in the resolved lint config of a package CI lints (T1), a line a human wrote in `ai/conventions.md`, an ADR, CONTRIBUTING, the design-system docs or `ai/glossary.md` (T2), the token set, a named wrapper or helper. Every row cites it — `oracle:` with the quote or rule id, and `oracle_tier:` — and a row whose quote cannot be found is AL-01 and is dropped.

Two things look like oracles and are not:
- **A majority.** Most files sharing a shape that nothing declares is a split (AL-02): a proposal for a human to ratify, never a finding, whatever the share.
- **A generated line** (T2g): text `/setup-project` wrote inside `refine-enriched` markers, or a `codebase-profile.md` / `_extracted-*` fact. Its sites wait at `pending-ratification` behind one confirmation per rule. A contested category (`[CONTESTED: …]`, `## Unsettled conventions`) is AL-02 even when a generated line names a side.

**What align owns** (the 34 classes AL-01…AL-34, one owner each, are tabled once in the `align-detect` skill): oracle-level checks (AL-01–04), wrappers and imports (AL-11, 13, 14, 15, 22), names and layout (AL-16–19), suppressions and ratchets (AL-29–32), and the sweep itself (AL-33 one pattern resolved two ways, AL-34 an out-of-scope edit).

**What align closes for another owner — EQ rows only.** Tokens (AL-05–10, 12) are ui-ux's, layers (AL-20/21) code-quality's, i18n and a11y (AL-26–28) frontend's. Align closes an owner's row only when its oracle is T1/T2 and the swap is exact (EQ, § Proof classes).

**What align routes and never closes** — the row moves to `routed (<command>)`:
- Security → `/security-fix` (always installed). Performance and data → `/perf-fix`, `/db-fix` when installed; without them, align may apply an idiom the oracle already names only with a baseline **measured** by a failing-first test.
- Error handling, dead code, a diverged copy, SOLID, complexity → `/quality-fix`.
- New copy, catalog defects → `/frontend-fix`. An envelope or error shape against a **declared** API contract → `/backend-fix`; API uniformity with no declared contract → `/polish`.
- A token, state or wrapper that does not exist yet → `/polish`; a wrapper gap (the raw call does something the wrapper does not expose) → `/unify-surfaces`; layer rework → `/optimize`; a rename of a wire, DB, env or generated name → `/refactor` + ADR; a V1→V2 port → `/migration-*`; a behaviour bug → `/fix-bug`.

A row's class drives four things: which **detector** found it · which **closure verb** fixes it · which **proof class** proves it · which **tier promoter** applies.

## Relationship to migration discipline

Align is the migration discipline turned inward — same tiering, same audit rigor, same closure-verb model, but the oracle is the project's own declared conventions instead of V1. There is no second codebase, so align has no parity test, no shadow/canary and no cutover; it substitutes the proof classes and the sweep gates.

## Required artifacts per finding — tiered floor

Tier is set on the ledger row at scan time and propagates through the fix.

### Tier classification

| Tier | Triggers (any one promotes) | Required artifacts |
|---|---|---|
| **trivial** (DEFAULT) | No promoter triggers | Ledger row + code edit + the proof its class needs |
| **standard** | 3–10 files touched OR cross-module symbol rename OR an exported or public name OR a T1 rule newly enforced across a package | + 1-paragraph rationale in the row's `notes` |
| **heavy** | Any of: cross-package boundary change OR public API surface change OR removes a symbol used outside the module OR touches >10 files OR touches an auth / permission / tenant wrapper (AL-15 gates) OR a VC row on a shared component | + impact analysis (file+line of every consumer) + reviewer-approved before merge |

Rules: tier is **set by scan** (`tier:` + `tier_reason:`, one sentence citing the trigger); heavy needs a scan-flagged trigger or `/align-phase <N> --heavy`; users may **upgrade** anytime, a **downgrade needs a 1-line justification** in `notes`; `/align-gate <N>` validates the artifact set for the row's tier.

## Proof classes — EQ, VC, FN

Every row carries one `proof_class`, set at DECIDE (`find-and-align` Step 3) and re-derived by the sweep gate:

- **EQ — exact equivalence.** The literal's value equals the token's in every shipped theme, within one property family, with exactly one semantic candidate; or the wrapper's defaults reproduce the raw call's props; or the literal equals an existing catalog value whose key resolves in every locale; or a rename touches no wire name. Proven by a **zero** computed-style or compiled-CSS diff (V394 / V396). Without a harness: `[report-with-fix] (static EQ)` with the runtime probe written out.
- **VC — visible change.** A snap to the nearest token, a value matching another property family, a wrapper with different defaults. Proven only by a visual diff at `maxDiffPixels: 0` **and** `approval: <name>@<iso>` written by a human (V407). Never auto-accepted, never under `--safe-only`, never with an allowance; an agent never fills `approval:`.
- **FN — functional.** A verb that adds an idiom the oracle declares (`add-gate` with the declared `<Can>`). Proven by a behaviour test as the role that must not see it (V401), failing first.

## Anti-bloat rules

Merge gates: code edits are the deliverable · per-axis enumeration wherever a gap exists · hand-wave grep HALTs (`etc.` / `...` / `N+ items`) · single dispatch + shared context blob default · audit verdict = convention-parity, not plan-execution. Full gate definitions, the closed 21-verb closure vocabulary and the net-lines rule: `ai/patterns/align-guardrails.md § Anti-bloat merge gates`.

## Realism guards

Eight execution-time guards keep the discipline survivable on real codebases — **scope cap · batch ceiling · skip-list honoring · mechanical-red short-circuit · oracle-absence fallback · dirty-tree behaviour · flaky-test quarantine · large-file sampling**. Definitions, thresholds and the output line each one must emit: **`ai/patterns/align-guardrails.md § The eight realism guards`**. Commands apply them silently; audits cite a guard **by name** when one fires.

A guard reduces what was *examined* and says so — it never converts an examined failure into a pass (mechanical-red and dirty-tree halt outright, `/align-fast` included); and **a guard that fires without a line in the output makes a reduced sweep indistinguishable from a clean codebase**. Six supporting mechanisms decide whether an examined result *counts*: **coverage tolerance** (±0.5% default), **parallel race serialization** (disjoint scopes per wave, one committer), **baseline-capture fallback**, **reviewer approval**, **mid-sweep tier promotion**, **idiom-drift propagation** — thresholds in `ai/patterns/align-guardrails.md § Supporting mechanisms`.

## Finding classes

The AL ids are the vocabulary; `align-detect` holds the class ledger (class, detector, owner, closer) and the **legacy map** that reads old ledgers: `reinvented-wrapper` / `raw-library-component` → AL-11, `drift` → the AL id of the rule it cites, `design-token-drift` → AL-05, `i18n-key-drift` → AL-26, `permission-gate-drop` / `default-true-prop` → AL-15, `a11y-violation` → AL-28. The legacy classes `silent-catch`, `unhandled-io`, `dead-code`, `duplicated-logic`, `over-abstraction`, `solid-violation`, `clean-code`, `performance` and `security` are owner classes: routed, never closed here. Two boundaries are decided here, because each is decided wrongly often enough to have produced findings:

- **Drift requires a declared convention.** Half the modules doing X and half doing Y, with no oracle naming either, is AL-02: the BIMODAL report, `proposed canonical — ratify?` or `undetermined — ask`, and **0 ledger rows**. Picking a winner by majority vote is introducing a convention, not enforcing one.
- **A stale document loses to a consistent, current codebase** (AL-04). When nearly every site and the newest files follow the other shape, the row is "doc stale", routed to a doc update; the code is not rewritten.

## Per-finding audit — 11 hard halts

The audit HALTS (refuses to advance the row) on any of these:

1. **No evidence** — `evidence` empty, a `<path:line>` that doesn't resolve, or a line without the fingerprint. Validator: `check_evidence_resolves`.
2. **Hand-waved enumeration** — `etc.`, `...`, `and so on`, `several places`, `N+ duplicates`, `multiple call sites` in any field. Each instance gets an explicit `<path:line>`. Validator: `check_no_handwaves`.
3. **No oracle, or an oracle that does not resolve** — the row's `oracle:` is absent, its quote is not in the cited file, or its rule id is not declared (AL-01). Drop the row. Validator: `check_oracle_cited`.
4. **Closure verb outside vocabulary** — the verb is not in the closed set of 21. **Structural (5):** `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`. **Functional (16):** `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`. The security, perf and validation verbs serve only the owner carve-out (§ Scope). Validator: `check_closure_verb_in_vocab`.
5. **Net-positive line count on a structural row** — halt; revert; redo. Validator: `check_net_lines_structural`.
6. **Functional fix doesn't cite idiom** — the added lines call no idiom the oracle names. Route to `/setup-project --refine` or stop inventing. Validator: `check_added_lines_cite_idioms`.
7. **Tests touched or behaviour changed** — an align commit edits a test, spec, snapshot, fixture, the class's lint config or a baseline file; or tests fail, test or assertion count drops, coverage drops beyond tolerance. Tests are **read-only** in an align commit, with no exception: a change that "needs" a snapshot update was not EQ. Sweep gate: `lock-paths`, `lock-count` (V408).
8. **Scope creep** — a file outside the row's `scope`, or inside it a removed line that is neither an evidence line nor the verb's footprint (AL-34). Validator `check_scope_boundary` (every row commit); sweep gate `scope` (line level, V392).
9. **New abstraction introduced** — a symbol (function / class / type / file) the oracle does not name. Validator: `check_no_new_symbols`.
10. **Reinvented wrapper without justification** — a `replace-with-shared` fix introduces a NEW shared helper rather than the named one, or a raw call needs a capability the wrapper lacks (that is `/unify-surfaces`).
11. **Unproven or wrongly closed** — a fixed row with no `proof_class`; a VC row without a human `approval:`; an EQ row with a non-zero diff; one before-value resolved to two after-values in the run (AL-33); an owner-class row (security, performance, database, code-quality) closed here instead of routed. Validator `check_proof_class`, `check_vc_approval`, `check_owner_routed`; sweep gate `consistency` (V393).

**Output of any halt**: a structured remediation note — the row and the action — written to `ai/align/halts/<row-id>.md`. NO advance until each halt is cleared.

## Per-stack extensions and tool-agnostic procedure

Stack lanes (each language's linter, style checker, file-name checker and import-boundary tool, with their version gates) live in the detector skills; this rule stays stack-agnostic. The canonical loop is dispatched as skills `align-detect` (the class ledger and dispatcher over `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan` and the owners' detectors) and `find-and-align` (the proof ladder L0–L13, with `align-sweep-gate.py`); rule-only tools read the same loop from those `SKILL.md` files, which install with the pack.

## Must

- **Build the oracle before scanning** (`convention-oracle` § 0). The inventory falls back `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`; a missing file is a reduction with a printed line, never a halt. With no declaration at all, every align class prints `N/A (no declared convention)`.
- **Read source before flagging.** A row you did not open is a row you cannot pass; if the count is large, say how many you read and mark the rest `Live, unreviewed` — never `checked`.
- **Refute before reporting.** Every candidate passes `refute-before-report.md` § 10 (conventions column) in a verifier that did not raise it; gate 6 is the oracle line quoted + the site.
- **One finding per atomic commit**, subject `align/<phase-N>/<id>: …`; one committer when rows run in parallel.
- **Prove by class** — EQ by a zero diff, VC by a named approval, FN by a behaviour test (§ Proof classes). Deterministic gates run before any reviewer; a judge can move PASS to `pending-review`, never FAIL to PASS.
- **One way per pattern** — one before-value maps to one after-value across the whole run, unless the token map splits it by role.
- **Update the ledger on every state transition**, per `ai/patterns/align-ledger.md`.
- **Heavy-tier rows require reviewer approval before merge** (`reviewer_approval: <name>@<iso>`).
- **Gap-count parity** (`gaps_in == gaps_closed`); a row that closes 7 of 8 is `halted`.
- **Say what you did not run.** A tool absent, a rule that matched 0 files (V399), an `rg` exit 2 — each is `blocked` or `NOT RUN` with its reason, never zero.

## Must not

- **Enforce a majority or a generated line.** Both are proposals until a human writes them down (§ Scope).
- **Bundle findings in a commit**, or let two sub-agents commit concurrently on one index.
- **Skip the ledger.** `/align-gate` halts on ledger drift.
- **Edit a test, snapshot or baseline to make a swap pass** (halt #7).
- **Hand-wave enumeration** (halt #2).
- **Modify the oracle in the alignment PR.** `_extracted-idioms.md` / `ai/conventions.md` / `ai/architecture.md` / lint configs change via `/setup-project --refine` or an ADR. Validator: `check_oracle_unmodified`.
- **Close another pack's class.** Security, perf, data and quality rows are routed with their audit id.
- **Promote or demote tier silently.**
- **Carry V1 patterns into align findings** during a migration — V2's declared conventions win.
- **Park a finding as a way of closing it.** Park captures `prior_status` + `prior_phase` (`ai/patterns/align-guardrails.md § Named anti-patterns → The Silent Park`).

## Should

Lowest-risk class first · batch by class not by file · rule first where expressible (a lint or structural-search rule with BAD/GOOD tests, run from a scratch folder) · ratchet what is not fixed (a shrink-only baseline) · cite occurrence counts in every finding. Each is a default; deviate with a one-line reason in `notes`.

## Enforcement

`/align-gate <N>` runs a 17-check matrix. `scripts/validate-align-artifacts.sh` carries the ledger and commit checks (evidence, hand-waves, verbs, net lines, new symbols, file-level scope on every row commit, oracle cited and unmodified, proof class, VC approval, owner routing, idiom citation) and the run-level scan evidence (all 34 AL rows). `find-and-align`'s `align-sweep-gate.py` carries the run checks (line-level scope, re-detect zero, one way per pattern, test lock, emitted names, value round-trip, ratchet, non-vacuous). Ledger completeness, the mechanical run and boot, and the zero-diff evidence are **agent-side** and labelled `(agent-side)`. Anti-pattern → check, gate behaviour, SLA clocks: `ai/patterns/align-guardrails.md § Enforcement`.

## Anti-patterns (named)

The names are load-bearing vocabulary — audits cite them, `/align-status` groups by them, `/align-final` counts them. The catalogue: **`ai/patterns/align-guardrails.md § Named anti-patterns`**.

## Load on demand

**Align's own agents** — `.claude/agents/align-{evidence,idiom,gate,ledger}-auditor.md`. Four audit windows over a finding's life: scan output, one diff, one phase, all state.

**Installed with the pack, always reachable** — `ai/patterns/align-ledger.md` · `ai/patterns/align-guardrails.md` · skills `align-detect`, `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`, `find-and-align` · snippets `precedents/align.md` and `proof-oracles.md § Align` (V389–V408).

**Companion reference files — pack-side only, NOT installed.** `references/align-discipline-procedures.md` and `references/align-discipline-catalogue.md` live in the pack for authors and adapter bundles; nothing above depends on them.
