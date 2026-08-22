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

## 1.11.0 — 2026-08-23

**The headline safety claim was falsified two paragraphs later in its own file.** 1.10.0's rule said
"Nothing enforceable — no halt, no threshold, no vocabulary — is defined only in `references/`", and
then § Realism guards sent four supporting mechanisms with their own thresholds — baseline-capture
fallback, the reviewer-approval flow, mid-sweep tier promotion, idiom-drift propagation — to
`.claude/references/align-discipline-procedures.md`, a file the same entry documents as never
installed. § Anti-bloat rules sent the merge-gate definitions and the closed 21-verb vocabulary to
the catalogue; § Enforcement sent gate behaviour and the SLA clocks there; three of the four audit
agents cited it in their Related sections.

**All of it moved to `ai-patterns/align-guardrails.md`**, which installs unconditionally. That file
now carries the eight guards, **six** supporting mechanisms (the two it already had plus the four
above, each with its threshold and its required output line), § Anti-bloat merge gates, and
§ Enforcement — gate behaviour, SLA clocks, anti-pattern → check. `rules/align-discipline.md` now
contains **zero** `.claude/references/` citations, and `@align-{gate,ledger,idiom}-auditor`,
`/align-phase` and `find-and-align` were repointed with it. `references/align-discipline-*.md` fell
66,354 → 50,735 chars; both `_essentials.md` and the `_topics.md` reference-pair entry now state that
they are pack-side and install nowhere.

**A stale section was deleted rather than moved.** `references/… § Validator script (v1.5+)` claimed
"7 high-impact checks" plus "remaining 7" = 14, contradicting the rule's 11-of-14 split and the 15
`check_` functions `scripts/validate-align-artifacts.sh` actually defines. It was removed, not
relocated.

**The rule-only-tool classification was wrong for three of five tools** — same correction as the
migration pack, same registry citations (`_registry.md:23,53,54,76`). Only Aider is rule-only.

**The intra-pack overlap figures in § 1.10.0 were not reproducible.** "6%, 11%, 5%" named no metric,
and only two of three reproduced under either candidate metric. Both metrics are now stated and both
figures given per pair. The verdict is unchanged; the evidence behind it is now retrievable.

**Two user-facing docs still described the pre-1.10.0 taxonomy.** `docs/COMMANDS.md:796` said
`/align-scan` "runs 12 universal detectors (6 structural + 5 functional + stack-conditional)" — its
own arithmetic disagrees, and 1.10.0 standardised the pack on 11 universal with `stack-specific` as a
twelfth *class value*. `docs/REFERENCE.md:568` repeated it. Both corrected, along with
`docs/COMMANDS.md:814`, which described `/align-park` without the critical-security refusal or the
`prior_status` / `prior_phase` / `parked_sla_from` fields 1.10.0 added. `scripts/verify-doc-sync.sh`
sees none of this — see the integrator note in the batch report.

**Accounting.** Rule: 32,736 → 25,299 chars (~8,184 → ~6,324 tokens, **−23%**), and the delegated
depth now arrives. Pack total 425,415 → 479,744 chars, **+54,329** — that growth is
`ai-patterns/align-guardrails.md` (26.8K, the guards and gates that previously existed only as names
in a rule or as prose in an undelivered file) plus this changelog; `references/` gave back 15.6K of
it. Commands: 13 before, 13 after.

## 1.10.0 — 2026-08-22

**The rule was a manual in the always-loaded slot, and the depth it delegated went to files no
project receives.** Two findings, one cause.

The rule's largest section — 8,114 chars of two four-column tables under § Finding categories — had
exactly one column that was rule: the class names. The *Detector signal* column restates
`skills/detect-drift/SKILL.md` Detectors 1–11 in weaker prose; the *Default closure verb* column
restates what each detector already suggests; the *Tier promoter?* column restates the tier table
120 lines above it. The class list itself appeared three times in one file (§ Scope's 7-item
enumeration, the two tables, and again as "Forbidden classes" restating § Scope's routing list
verbatim 40 lines later). Deleting the duplication and keeping a compact class table plus the three
boundaries that are genuinely decided here — `silent-catch` vs `unhandled-io`, `drift` requires a
*written* convention, severity not class sets the security heavy floor — took the rule from
**32,736 to 24,175 chars (~8,184 → ~6,043 tokens, −26%)**. Nothing enforceable left the file: the
tier table, the 21 verbs, the 11 halts and the must/must-not all stayed.

**Where the depth went, and why not to `references/`.** The house move is to lift depth into
`references/`. That move is broken for this pack. `templates/phases/phase-4.2-apply.md:213` and
`:349` are the only install paths for references and both read
`for fw in <detected-frameworks>; do cp .../references/${fw}.md ...`. No framework is named
`align-discipline-procedures`, so neither companion file has ever reached an installed project, and
`2>/dev/null || true` swallows the miss. Lifting more depth there would shrink the token number
while making the installed project strictly less capable.

So the depth went into a **new pattern, `ai-patterns/align-guardrails.md`**, which installs
unconditionally in both COPY and MINIMAL mode. It carries two things:

- **The eight realism guards, defined for the first time.** The rule named "scope caps, batch
  ceilings, skip-list honoring, mechanical-red short-circuits, oracle-absence fallbacks, dirty-tree
  behaviour, flaky-test quarantine, large-file sampling" and pointed at
  `references/…-procedures.md § Realism guards` for "full definitions + thresholds". That section
  defines eight *different* things (Coverage tolerance, Parallel race serialization, Baseline
  capture fallback, Validator script, Reviewer-approval, Mid-port tier promotion, Idiom-drift
  propagation, Standard/heavy artifacts). All eight named guards appeared in exactly one file in the
  repo — the rule asserting they were defined elsewhere. The matching count 8-vs-8 is presumably how
  it survived review. Each now has a trigger, a default threshold, and the output line it must emit;
  the procedures file keeps its eight as *supporting mechanisms*, which is what they are.
- **The two supporting mechanisms that commands cite by name came across too.** The first pass left
  `Coverage tolerance` and `Parallel race serialization` in `references/…-procedures.md` and then
  re-pointed nothing, so `/align-gate:62`, `/align-phase:126`, `/align-phase:234` and `/align-fast:143`
  each cited `align-discipline.md § Realism guards § <name>` — a sub-heading the rewritten rule does
  not have, resolving into a file the project does not receive. That is the same defect this entry
  opens by describing, left in place by the fix for it. Both now live under
  `align-guardrails.md § Supporting mechanisms` with their thresholds (0.5% coverage tolerance; the
  per-file lock, heavy rows serialising phase-wide), both are marked **agent-side, not
  script-enforced** so nobody mistakes them for gated, and all four commands point there. They are
  kept apart from the eight guards on a real distinction: a guard bounds what a sweep *examines*, a
  supporting mechanism decides whether an examined result *counts*.
- **The named anti-pattern catalogue.** `@align-ledger-auditor`, `@align-gate-auditor`,
  `@align-idiom-auditor` and several commands cite `The Stale Ledger`, `The Reinvented Idiom`,
  `The Eternal Phase`, `The Idiom Inventory Gap` and six more by name. The definitions lived only in
  the catalogue, i.e. nowhere reachable. One copy now, in the file that installs; the catalogue
  points at it.

**The park/unpark pair was broken by construction, and it laundered security findings.**
`/align-park` step 4 enumerated everything it writes — `status`, `parked_at`, `parked_reason`,
`parked_blocker`, `parked_unpark_after`. `/align-unpark` requires "a parked-context record with
non-empty `prior_status` + `prior_phase`" and halts without them. Those two field names appeared in
exactly one file in the pack: the consumer. Park *read* the prior status at step 2 to validate the
transition, then discarded it. Every park produced a row unpark refuses to restore, whose only
remaining exit is `parked → fixed` — a transition the ledger auditor's own reconciliation 2 lists as
illegal.

Worse, parking was a laundering path. Park flips `halted → parked` and moves the halt file to
`halts/parked/`; the ledger auditor's SLA table had four rows and none keyed on `parked`, while the
security escalation keyed on "`class: security` row **halted** > 24 hours". So parking a critical
row stopped the 24-hour clock, removed the file from the systemic-reason detector, unblocked the
gate, and surfaced only as an undifferentiated `PARTIAL` in `/align-final` — identical to a parked
dead import. The pack's own worked example demonstrated exactly this: A047, `security/sql-injection`,
`severity: critical`, parked because the parameterized-query primitive did not exist.

Fixed end to end: park captures and persists `prior_status` + `prior_phase` (it already read both),
verifies them in its own Phase 6, and refuses a `severity: critical` security row without an
explicit `--override-critical="<reason>"` that is written into `parked_reason` and logged as
`CRITICAL-PARK` — `--no-confirm` does not satisfy it. Security parks carry `parked_sla_from` so the
clock ages from when the problem was found, not from when it was parked. The ledger auditor gained
four `parked` SLA rows (security escalation, overdue `unpark_after`, >90d abandoned, and
unrevivable-missing-`prior_*`), and counts `halts/parked/` in its systemic total. `/align-final`
breaks `PARTIAL` down by class, worst-first, and flags unrevivable rows. The worked example now
shows the refusal and its three legitimate routes.

**`ai-patterns/align-ledger.md` was the pack's declared schema authority and contradicted reality on
eight axes.** `/align-scan` says "Schema from `ai/patterns/align-ledger.md`" and then emits something
else: `- id: A001` list items vs the pattern's `## ALIGN-0042` headings, `scope:` vs `source:`,
`evidence` as a `<path:line>` list vs a prose string, `detected_at` vs `ported_at` (a migration-ism —
align ports nothing), and no `subclass` / `severity` / `tier_reason` / `idiom_cited` /
`shared_equivalent` at all. Two were fatal rather than cosmetic. The canonical row's
`closure_verb: surface-error` is in neither `STRUCTURAL_VERBS` nor `FUNCTIONAL_VERBS` in
`scripts/validate-align-artifacts.sh:195-197` — the reference row fails the pack's own vocabulary
check, audit halt #4 and evidence-auditor check 4. And `discover_findings()` at
`validate-align-artifacts.sh:159` matches `/^- id: A[0-9]+[a-z]?$/`, which the pattern's heading form
never matches — so a ledger written to the documented schema yields **zero discovered rows and a
clean exit**. Because this file is its own `fallback:`, it is copied verbatim into
`ai/patterns/align-ledger.md` and becomes the project's schema of record. Rewritten against the
validator, the command and the four agents, with the ten-state machine and per-state required fields.

**Smaller repairs.**
- `/align-scan`'s Phase 2 dispatch diagram listed `11. (deps-audit, sub-class of security)` and
  dropped `unhandled-io` — the class the rule calls the canonical AI-generated-code defect — while
  the same file's frontmatter and § Stack-conditional dispatch both promised it. `detect-drift`
  defines 11 detectors with #11 = `unhandled-io` and no deps-audit detector (vuln-dep is step 7
  inside Detector 10). Diagram restored; the numbering is now stated as the contract with the skill.
- The 11-vs-12 detector count was unreconciled across six files, with `_essentials.md` claiming 12
  and then enumerating 11. Standardised on **11 universal (6 structural + 5 functional)**, with
  `stack-specific` named as the 12th *class value*, matching the skill, the rule and the catalogue.
- `/align-deprecate` was referenced from three places and does not exist. Removed; `archived-deprecated`
  is now defined as a terminal state reached by hand with an `adr:`, which is what a won't-fix is.
- The state set had six incompatible definitions (7 / 9 / 10 names, plus `archived-deprecated`
  written by three commands and legal in none). Ten states, defined once in the ledger pattern.
- `/align-phase`'s Premise — under "read this first, internalize, do not deviate" — taught the five
  structural verbs as the whole vocabulary and called alignment "an entropy reducer, not a designer",
  contradicting the pack's functional half. This is the exact framing `1.7.x` hunted out of
  `_orchestration-sync.md`; it survived here, in the command that applies fixes. Both halves now.
- `/align-promote-tier` mutates `tier`, the field every security floor keys on, and had no halt block
  and no failure modes. Both added, including deriving the security floor from the row's own class
  and severity rather than accepting it as an argument.
- `detect-drift` had no Hard rules and no Failure modes, and a missing `ai/conventions.md` silently
  skipped the `drift` class — it was not in the skill's Halts list, so a scan on a project without
  that file reported zero drift and said nothing. Added a Reductions table (`SKIP — drift NOT RUN`),
  a mandatory `RAN <N> of 11` denominator, and a **bimodal-convention** non-finding output for the
  most common reason teams reach for align ("half our modules do X and half do Y") — which is not
  `drift`, because drift needs the oracle to name a winner and here it names neither.
- `find-and-align`, the loop every fix runs through, had 36 halt references and no Failure modes.
- `@align-gate-auditor` accounted for 11 script checks + 3 agent-side = 14; the validator defines
  **15**. The four unaccounted (`check_scan_report_evidence`, `check_progress_ledger_reconciliation`,
  `check_scope_code_smells`, `check_actionable_next_steps`) are now reported under a
  `SUPPLEMENTARY (script-only)` heading, with the note that `check_progress_ledger_reconciliation`
  polices a `progress.md` no command in this pack writes and must be reported `SKIP`, not pass.
- `/align-unpark` was the pack's thinnest artifact at 50 lines with no Hard rules, Failure modes or
  Related, and shipped `templates/packs/migration/commands/migration-unpark.md` — a repo-internal
  path — to installed projects. Rebuilt; the pointer is now `/migration-unpark`, qualified.
- Split residue from 2026-06-07 removed: duplicate `## Anti-bloat rules`, `## Should` and
  `## Relationship to migration discipline` headings that made the rule's section anchors ambiguous.

**Not done, deliberately — and here is the measurement.** No commands merged. Two questions were
asked; the earlier draft of this entry answered only the first and then appealed to a cross-pack
"9% median" that had never been written down anywhere. That appeal is withdrawn and replaced by the
real numbers below.

*Intra-pack*, same corpus rule as the cross-pack table below (non-blank lines of ≥ 25 chars,
deduped to a set), reported two ways because the pairs differ in size — Jaccard `|A∩B| / |A∪B|`
first, then the min-denominator variant `|A∩B| / min(|A|,|B|)` which flatters the smaller file:
`align-fast` vs `align-phase` **4.9% / 9.5%**, `align-replan` vs `align-plan` **4.9% / 11.3%**,
`align-unpark` vs `align-park` **1.3% / 5.6%**. (Corrected 2026-08-23: this line previously read
"6%, 11%, 5%" with no metric named, and only two of the three reproduced under either metric.)

*Cross-pack* — the 13 identically-suffixed `{migration,align}-{fast,final,gate,park,phase,plan,
promote-tier,recheck,replan,rollback,scan,status,unpark}` pairs, the batch's headline question. Each
pair was compared on substantive lines twice: verbatim, and again after neutralising pack vocabulary
(`migration|align`→PACK, `feature|finding`→ITEM, `port|fix`→ACT, `row`→ROW) so that structure was
compared rather than nouns. Neutralised overlap, low to high: `phase` 2.6% · `status` 5.6% ·
`fast` 8.5% · `unpark` 8.9% · `gate` 11.4% · `park` 14.4% · `final` 14.6% · `rollback` 15.1% ·
`scan` 18.0% · `promote-tier` 18.3% · `replan` 24.3% · `plan` 28.4% · `recheck` 35.4%.
**Median 14.6%; maximum 35.4%.**

**Verdict: KEEP-SEPARATE, on evidence.** One state machine implemented twice would sit far higher
than 35%. And the residue that does overlap is not pack duplication: the 48 identical lines in the
highest pair (`recheck`) are overwhelmingly the repo-wide 7-phase command harness — `## Phase 3 —
Retrieve`, `## Phase 5 — Update`, `## Phase 7 — Improve` — which **90 of the 133 pack commands in
this repo carry**. Merging any pair would remove none of it. The two packs share a *vocabulary*
(scan → plan → phase → gate → final, with park/unpark/rollback/promote-tier as the same four escape
hatches) because they are the same *shape* of process; they do not share an implementation, because
migration reconciles two codebases against a parity oracle and align reconciles one codebase against
its own documented idioms. There is no parity test in align and no second codebase to have one.

`/align-unpark`'s problem was that it was underbuilt and broken against its producer, not that it
duplicated anything; it was built up and repaired instead.

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
