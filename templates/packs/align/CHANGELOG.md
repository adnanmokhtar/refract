# align pack — changelog

Release history for `templates/packs/align/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

Some versions also carry a **Release narrative**. This pack kept a second, independent telling of
each release inside the `_version.json` `summary` string, and every release appended to it, all on
one JSON line. Each telling is preserved below under the version it describes, verbatim and
unabridged.

## Pack description

Carried in the `_version.json` `summary` field through v1.8.2:

Codebase quality gate — comprehensive sweep against the gold-standard inventory. Detects + fixes
drift, dead code, duplicates, reinvented wrappers, silent catches, over-abstraction, SOLID
violations, clean-code violations, performance issues, security weaknesses, and unhandled I/O
(happy-path-only call sites). Stack-agnostic; frontend stacks dispatch UI/UX detectors (a11y, design
tokens, i18n, motion) automatically. Phased + parallel dispatch like /migration-fast.

## 1.9.1 — 2026-08-22

**Three citations that resolved as text but not as contract.** The Frontend-stack rows of
`references/align-discipline-catalogue.md` each carried an "(inherited)" note plus an anchor into
`frontend/rules/migration-frontend.md`. `scripts/lint-handoffs.sh` opened that file: its headings are
Stack-aware primitive set / Frontend audit axes / Frontend anti-pattern catalogue / Frontend
Transposition Trap fingerprints / Phase 3 / Locale parity / Cross-references. None of
`§ lifecycle-hooks`, `§ default-true-wrapper-props` or `§ permission-gate` exists there.

- **lifecycle / data-fetch hook on wrong element** → `migration-frontend.md § Reactive lifecycle`,
  the audit axis that actually states the mount-only-vs-reactivate rule.
- **permission-gate drop** → `migration-frontend.md § Per-button permission gates`, which carries
  the per-button gate table and its density requirement.
- **default-true wrapper prop** → this one was not inherited from `migration-frontend.md` in any
  sense: the string does not appear in that file. The discipline lives in the frontend pack's
  sibling-shape halt, so the row now cites
  `frontend/commands/add-crud-page.md § Sibling-shape mechanical halt` and says where the
  inheritance actually comes from.

## 1.9.0 — 2026-08-20

- **align now ships agents.** Until this release align was the only pack in the repo with commands
  (13) and zero agents. Every audit the discipline demands — evidence resolution, the invention
  boundary, the 14-check phase verdict, ledger reconciliation — was performed inline by the command
  that needed it, which meant no artifact owned any of them, no two commands were guaranteed to run
  the same check the same way, and the halts had no addressable dispatch target. That is the
  enforcement-theatre shape the ui-ux pack's 1.16/1.17 entries name: a mechanism that is described
  but that nothing actually executes. Four agents, split by WHEN in a finding's life the audit
  happens rather than by finding class:

  - `agents/align-evidence-auditor.md` (sonnet) — **pre-fix.** Audits a fresh scan's `detected`
    rows before they can enter `/align-plan`: every `<path:line>` resolves at the pinned commit AND
    contains the fingerprint the row claims; enumerations are explicit; class matches signal;
    closure verb is in the 21 and is reachable without invention; security rows clear the tier
    floor. Audit halts #1–#4 and #11. Carries an out-of-domain routing table so a real defect that
    is not align's leaves with a destination (`/polish`, `/optimize`, `/audit`, `/refactor`,
    `/fix-bug`, `/migration-*`) rather than being silently dropped.
  - `agents/align-idiom-auditor.md` (opus) — **per-fix.** The pack's boundary guard, and the only
    artifact in the repo whose whole job is deciding whether one diff ENFORCED a convention the
    project already has (align) or INTRODUCED a new one (`/polish`), DISCOVERED one (`/optimize`),
    or CHANGED a contract (`/refactor`). Four checks: no new public symbol unnamed in the oracle
    (#9); every added functional block cites an idiom that resolves AND that the block actually
    calls (#6 — the paper-citation case is a HALT); the closure verb used ITS idiom rather than a
    substitute (#10), with a per-verb table of the specific invention each verb invites; the oracle
    is unmodified inside the fix commit. Operationalises
    `templates/tool-adapters/_orchestration-sync.md § Command boundary table` per-diff, which is
    the only place that split is actually decidable.
  - `agents/align-gate-auditor.md` (opus) — **post-phase.** Runs the 14-check matrix and composes
    the PASS/REFUSE verdict with per-check evidence and per-row remediation. States honestly which
    checks are script-enforced and which are not: `validate-align-artifacts.sh` defines 11 of the
    14; checks 1 (ledger completeness), 7 (coverage tolerance) and 8 (frontend regressions) have
    no script implementation and are labelled `(agent-side)` in its report.
  - `agents/align-ledger-auditor.md` (sonnet) — **cross-phase.** Reconciles ledger ↔ git ↔ halt
    files ↔ impact files ↔ plan ↔ gate-history in BOTH directions (a row marked `fixed` with no
    commit, and a commit carrying a row id the ledger has no row for), plus state-machine legality,
    phase drift, and the SLA thresholds `/align-status` reports. Its highest-value output is the
    systemic line: three or more rows halted for the same missing idiom is `The Idiom Inventory
    Gap`, and the fix is one `/setup-project --refine`, not N more halts.

- **Dangling dispatch repointed.** Four align files dispatched `performance-optimizer` at
  `code-quality/agents/performance-optimizer.md`. That file does not exist and never has — the
  agent lives at `performance/agents/performance-optimizer.md`. Repointed in `_essentials.md`,
  `skills/detect-drift/SKILL.md`, `references/align-discipline-procedures.md`, and
  `references/align-discipline-catalogue.md`, with the no-performance-pack fallback stated
  (project profiler / query log; the row still requires a baseline in `notes`). Every other
  cross-pack agent path in the pack was checked and resolves.

- **Deliberately NOT added: a detector agent.** Align dispatches `dead-code-finder`, `refactorer`,
  `code-reviewer`, `security-auditor`, `performance-optimizer`, `accessibility-auditor`,
  `i18n-auditor`, and `data-flow-auditor` from the packs that own those disciplines. Authoring an
  align-local detector would duplicate them and immediately begin to drift. The gap was never
  detection; it was that nothing owned the VERDICT.

- Wiring: `_essentials.md` `agents: []` → the four (all four ship under `--minimal`, with the
  reason stated); `_topics.md` gains an AGENTS section plus a § "Agent dispatch — the four audit
  windows" table, and `dispatches:` on the eight commands and one skill that hand off to them;
  `align-scan` / `align-phase` / `align-fast` / `align-gate` / `align-status` / `align-final` /
  `align-recheck` / `align-replan` / `align-promote-tier` and `skills/find-and-align` name their
  agent at the step that dispatches it.

## 1.8.2 — 2026-06-27

- align-fast.md: restored the **Discipline pointer:** link to
  templates/governance/core-discipline.md that its sibling align-phase.md carries. The 1.8.1
  DECIDE-step edit added the 'SOLID / clean-code' closure vocabulary to align-fast.md (line 68) but
  omitted the pointer, so audit-command-dry.sh ('SOLID/clean-code keywords without
  core-discipline.md link') was RED on main. Gate now green. Surfaced while running the full CI gate
  suite during the OpenCode adapter-frontmatter pipeline fix; pre-existing on main, unrelated to
  that fix.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

align-fast.md restored the **Discipline pointer:** link to core-discipline.md that the 1.8.1 DECIDE
edit omitted while adding the 'SOLID / clean-code' closure vocabulary — audit-command-dry.sh was RED
on main as a result; now green.

## 1.8.1 — 2026-06-26

- _essentials.md: added align-unpark to the commands list (12 → 13). It shipped under commands/, was
  declared in _topics.md (triggers always:true), and its sibling align-park was already in
  essentials, but align-unpark itself was omitted — AUTHOR-mode setup would silently drop it.
  Surfaced by a foundation-layer best-practice audit.
- find-and-align.md hard rules: corrected 'Closure verbs are the closed vocabulary of 16' to 21 (5
  structural + 16 functional). The file already stated 21 at lines 40 + 106 and
  validate-align-artifacts.sh hardcodes the 21-verb set; line 232 was a stale count from before the
  functional-verb expansion.
- align-phase.md + align-fast.md DECIDE steps corrected: they validated only the 5 structural verbs
  (and explicitly excluded 'perf'), but the rule (align-discipline.md — 'covers correctness,
  security, performance…not just structural drift'; 6 structural + 6 functional taxonomy classes),
  align-scan.md (assigns both groups), align-discipline-catalogue.md, and
  validate-align-artifacts.sh ALL consistently define + use all 21 verbs (5 structural + 16
  functional). The DECIDE steps were stale from before the functional-verb expansion. Both now
  reference the full 21-verb vocabulary with the per-group net-lines rule (structural:
  behaviour-preserving, ≤ 0; functional: small + line-budget, added lines cite an
  _extracted-idioms.md idiom + ship the required assertion). Resolved by evidence trace, not guess.
- Boundary-table reconciliation (tool-adapters/_orchestration-sync.md): the command-boundary +
  shared-ownership rows described /align as 'mechanical drift only, net-lines ≤ 0' and asserted
  security was 'exclusive to /audit, never claimed by align' + 'neither /align … may claim perf
  wins' — capturing only align's STRUCTURAL half and contradicting the pack rule's functional
  (security/perf) classes. Reconciled using the table's own 'kind of work' principle: /align applies
  an EXISTING idiom to a drifted site (add-gate / parameterize / escape / add-validator /
  parallelize / add-index / cache-with-explicit-ttl, shipping the gating test or perf assertion);
  /optimize owns DISCOVERED + MEASURED perf; /audit owns RANKING at scale + the deep security pass.
  /align still never claims a measured/discovered win. The /align row, Perf/scale row, and Security
  row were updated accordingly.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

sync-chain + doc-consistency repair surfaced by a best-practice audit — _essentials.md now lists
align-unpark (its sibling align-park was listed, the file + _topics entry existed, but it was absent
from the essentials command set); find-and-align.md hard rule corrected from 'closed vocabulary of
16' to 21 (5 structural + 16 functional), matching the rest of the skill +
validate-align-artifacts.sh.

## 1.8.0 — 2026-06-22

- Sync-chain repair: _topics.md now declares align-promote-tier as a command (kind:command,
  always-trigger, mirror_existing). It shipped under commands/ since 1.5.0 but was absent from the
  topic list, so /setup-project AUTHOR-mode generation silently dropped it. align ships NO
  _examples/ dir, so its fallback points at the live source (commands/align-promote-tier.md) rather
  than a non-existent _examples/ stub.
- align-gate check-count alignment + audit action-plan rollout in the review / feedback commands
  (carries the 1562aa6 audit follow-through into the version record).
- Companion-reference pointers in align-discipline.md core + commands now use the
  project-consumption path (.claude/references/<rule>-procedures.md / -catalogue.md) so every tool
  resolves them from the repo root (07c22ec / c92a955).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

sync-chain repair — _topics.md now declares align-promote-tier as a command (was shipped under
commands/ but absent from the topic list, so AUTHOR-mode setup silently dropped it; align ships no
_examples/ dir so the fallback points at the live source); plus audit follow-through (action-plan
rollout in review/feedback commands, align-gate check-count alignment, project-explicit
.claude/references/ companion paths).

## 1.7.0 — 2026-06-07

- Split align-discipline.md (was 94.4k — roughly half silently truncated every session by Claude
  Code's 40k always-on limit) into an always-on core (<40k) + two on-demand companions under
  references/ (content relocated VERBATIM, zero rewording): align-discipline-procedures.md (tier
  specs, contract template, full halt elaborations, tool-agnostic procedures, enforcement matrix) +
  align-discipline-catalogue.md (worked examples, anti-pattern catalogue, per-tool dispatch tables).
- The 'procedures are inlined here' contract is replaced by the rule-bundle contract: core + 2
  references = ONE discipline. Every adapter bundle MUST ship all three files together
  (_align-pack-coverage.md § Rule-bundle requirement).
- Manifests declare the pair: rule_references: [align-discipline-procedures,
  align-discipline-catalogue] in _essentials.md; reference-pair topic in _topics.md.
- Follow-up trims (07c22ec): cores reduced to ~31.6k to leave headroom for a project-specific
  apply-anchors block (2-6k) so an anchored project copy stays under 40k; Anti-bloat gate detail,
  Per-stack extensions, Relationship-to-migration, and Should guidance moved to the companions
  verbatim.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

split align-discipline.md into always-on core (<40k chars, respects Claude Code's 40k-char always-on
limit — prior size was truncating ~half the rule in every session) + two on-demand reference files
under references/ (procedures + catalogue), content relocated verbatim. Adapter bundles MUST ship
all three files together.

## 1.6.0 — 2026-06-06

- NEW functional class: unhandled-io (happy-path-only I/O). Detects I/O call sites (network / DB /
  queue / file / external process) with NO error path at all — no catch, no error-return check, no
  timeout, no failure surfacing. The absent-error-path sibling of silent-catch (which is
  catch-exists-but-swallows). Canonical fingerprint: AI-generated fetch-and-render / fetch-and-write
  code that works first run and crashes/hangs on the first failure.
- Detector 11 added to detect-drift skill: enumerate I/O call sites from _extracted-idioms.md
  primitives → trace failure path → cross-check caller chain before flagging (caller-handled
  rejections are NOT findings). Frontend fetch-in-component sites stay with the missing-UI-state
  sub-class; this detector covers services / jobs / queue handlers / CLI paths.
- Closure: replace-with-shared (route through the project's wrapped I/O primitive). No wrapped
  primitive for the medium → halt to /setup-project --refine; hand-rolled per-site try/catch is
  forbidden (no-new-abstractions rule).
- Tier: standard floor for hot-path / user-facing sites; write-path I/O (DB mutation / queue publish
  / payment) ALWAYS >= standard; trivial only for dev-tooling paths.
- Count consistency: 11 universal named classes (6 structural + 5 functional) in
  align-discipline.md; 12 universal detectors (incl. dependencies sub-class / stack-specific per
  file convention) across align-scan, detect-drift, recheck, validator, _essentials, docs, adapter
  coverage. validate-align-artifacts.sh check_scan_report_evidence regex extended with unhandled-io;
  is_structural_class unchanged (unhandled-io is functional — idiom-citation budget applies,
  net-lines<=0 does not).

## 1.5.2 — 2026-05-30

- Adds /align-unpark (reverses /align-park; restores prior status+phase) — the
  previously-referenced-but-missing revival command (audit #42). Plus validator-parity fixes: 4 new
  check_* functions implemented (perf-baseline, security-assertion, idiom-citation,
  oracle-unmodified), 2 name-drifts renamed, 3 tagged agent-side; check_no_new_symbols fail-closed +
  scope code-smell grep.

## 1.5.1 — 2026-05-03

- Sync-chain repair: ai-patterns/align-ledger.md authored as the canonical pattern doc (state
  machine + per-row record format). _essentials.md previously declared the pattern but the file was
  missing.
- _topics.md fallback paths repointed from non-existent _examples/ stubs to the canonical commands/
  skills/ rules/ ai-patterns/ files. Eliminates 14 broken fallback references.

## 1.5.0 — 2026-05-02

- validate-align-artifacts.sh shipped (589 lines, 7 mechanical checks): evidence-resolves,
  no-handwaves, closure-verb-vocab, no-new-symbols (idiom-named exemption),
  structural-net-lines-non-positive, scope-boundary, security-tier-minimum.
- Reviewer-approval mechanism: heavy-tier rows have ledger field `reviewer_approval: <name>@<iso>`.
  Status `pending-review` between fix and signoff. Default reviewer from CODEOWNERS or _anchors.md;
  7-day timeout; no auto-fail.
- Mid-port tier promotion: `/align-promote-tier <id> <new-tier>` mini-command. Promotion backfills
  artifacts; security demotion forbidden.
- Idiom-drift propagation: `/align-scan` compares oracle hashes against prior scan; surfaces 'Idiom
  drift detected' section listing changed idioms + affected ledger rows. `/align-replan
  --include-drifted` re-phases affected rows.
- Remaining 7 gate checks (test-coverage, frontend-regression, idiom-citation, security-assertion,
  perf-baseline, oracle-unmodified, ledger-completeness) stay agent-side until v2.

## 1.4.0 — 2026-05-02

- Make /align-recheck plan-independent. NO ledger required. NO plan required. NO phase concept. NO
  required prior scan.
- New flow: SCAN-FRESH dispatches the 11 universal detectors (+ stack-conditional UI/UX detectors
  for frontend-*) directly against current source for the resolved area. FIX. VERIFY (lint +
  typecheck + scoped tests + re-detect + a11y + bundle-size). RECORD-LEDGER (best-effort).
- New flags: --register-ledger (create new ledger entries from recheck findings), --ledger-only
  (legacy: restrict to existing rows).
- Removed flags: --include-verified, --include-archived, --rescan-fresh (no longer relevant —
  recheck IS a fresh scan now).
- Use case: spot-check an area without setting up the full alignment ceremony. Works whether or not
  the alignment workflow has been initialized.

## 1.3.2 — 2026-05-02

- Replace tokenize-keyword-search resolution in /align-recheck with semantic understanding. The
  agent reads codebase-profile.md + ledger + architecture/conventions + idioms, then maps the
  description to findings by intent — not keyword matching. Mirrors the /add-feature interpretation
  model.

## 1.3.1 — 2026-05-02

- /align-recheck now accepts natural-language descriptions ('the sidebar', 'the orders module', 'the
  page builder') in addition to paths. Resolution: tokenize → ledger keyword search → codebase grep
  → codebase-profile lookup → confirm-or-run.
- New flags: --no-confirm, --always-confirm, --max-matches=<N>.
- Mirrors /migration-recheck's description-input feature.

## 1.3.0 — 2026-05-02

- Add /align-recheck <path> [<path>...] command. Path-scoped re-detect + re-fix; not tied to phases.
  Use case: ad-hoc focused re-checks of specific modules / pages / components. Mirrors
  /migration-recheck. Optional --rescan-fresh flag to also pick up NEW findings that surfaced since
  the last scan. Same discipline as /align-phase (DETECT → DECIDE → FIX → VERIFY → RECORD; one
  commit per finding; closure verbs from 21-verb vocabulary; net-lines ≤ 0 structural / cite-idiom
  functional).

## 1.2.0 — 2026-05-01

- Add --re-audit flag to /align-fast and /align-final. Mirrors /migration-fast --re-audit and
  /migration-final --re-audit.
- Default cache reuse: rows at status: verified are skipped from re-detection (their last verdict is
  trusted). Pass --re-audit to force re-dispatch on every row including verified ones.
- Re-detected rows whose fingerprint reappears flip to status: halted with reason
  'false-verified-or-drift'. Fast re-fixes them in the same run using the standard per-finding loop.
- Re-detected rows whose fingerprint stays absent stay verified (no code change).
- Use case: catch false-verified rows, drift since gate, detector improvements that surface
  previously-missed gaps. Without --re-audit, verified rows are trusted (saves time on re-runs).

## 1.1.0 — 2026-05-01

- Refinement pass — add realism guards + first-run UX + symmetry with migration pack.
- /align-fast: stripped to single-phase mode (matches /migration-fast exactly). Removed `all` and
  `scan-only` modes. Added --scope flag for incremental phase runs.
- /align-scan: added --first-run flag with sane defaults (exclude-tier=heavy,
  exclude-class=clean-code, max-findings-per-class=20). Added concrete first-run output example.
  Added --max-findings-per-class cap with deferred-fingerprints registry at ai/align/_deferred.md.
- /align-replan: NEW command for symmetry with /migration-replan. Regenerates plan from current
  ledger; preserves verified rows; re-phases the rest.
- align-discipline.md: added Realism guards section — coverage tolerance (±0.5% for sample
  fluctuation); parallel race serialization (per-file lock mechanism); baseline capture fallback for
  projects without observability dashboards; validator script status (marked [PLANNED — v1.1]) with
  agent-side enforcement fallback.
- Verb taxonomy refinements — add-index ALWAYS ≥ standard tier (never trivial); bump-dep clarified
  for major-version handling (halt + route to dependency-migration ticket if tests break or
  non-patch bump).
- align-plan.md: phasing templates now explicitly described as typical examples, not rules. Real
  projects adapt based on priorities.
- Skills (detect-drift, find-and-align): explicit Inputs/Outputs precise contracts at the top,
  replacing buried IO descriptions.
- Cross-pack symmetry: align command suite now mirrors migration command suite 1:1 — scan, plan,
  phase, gate, fast, final, rollback, park, replan, status.
- Count consistency: every doc now references 10 universal classes (6 structural + 4 functional), 14
  phase-exit checks, 11 per-finding halts, 21-verb closure vocabulary (5 structural + 16
  functional).

## 1.0.0 — 2026-05-01

- Initial align pack release.
- rules/align-discipline.md: 11 finding classes (6 structural + 4 functional + stack-specific
  UI/UX); 21-verb closure vocabulary (5 structural + 16 functional); tier rules (security ALWAYS ≥
  standard; critical security ALWAYS heavy); 11 per-finding audit halts; 14-check phase-exit gate;
  anti-pattern catalogue.
- commands/: align-scan, align-plan, align-phase, align-gate, align-fast, align-status, align-final,
  align-rollback, align-park.
- skills/: detect-drift (universal 11 detectors + stack-conditional dispatch); find-and-align
  (per-finding 5-step loop).
- _essentials.md + _topics.md: pack metadata + AUTHOR-mode topic specs.
- Stack-agnostic via PROJECT_KIND: frontend-* dispatches UI/UX detectors automatically (a11y, design
  tokens, i18n, motion, lifecycle, default-true wrapper props, permission gates). Backend-* adds
  tenant-gate / N+1 / transaction-boundary. Data-* adds column-projection / idempotency /
  sync-http-batch. Mobile-* adds native-bridge.
- /align-fast <N> = per-phase one-shot (scan + plan are pre-requisites, like /migration-fast). Runs
  find-and-align per row in parallel waves + auto-gate. Same discipline; no human-watch pauses.
- Functional fixes (security gates, validators, cache primitives) MUST cite an idiom from
  _extracted-idioms.md — no inventing new abstractions inline. Validator:
  check_added_lines_cite_idioms.
- Net-lines rule split by class group: structural ≤ 0 hard; functional small + budget with idiom
  citation.
