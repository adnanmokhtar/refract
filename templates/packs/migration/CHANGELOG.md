# migration pack — changelog

Release history for `templates/packs/migration/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.11.0 — 2026-08-23

**The 1.10.0 shrink delegated ten enforceable rules to a file no project has ever received.**
`rules/migration-discipline.md` fell 37,854 → 26,349 chars by routing depth outward, and ten of the
surviving pointers routed *enforceable* depth — halts 12–13's full spec, the dead-V1 6-axis check,
the tier artifact specs, the anti-bloat gate definitions, the `v1_status` halt-skipping modes, the
enforcement matrix, the 20-name anti-pattern catalogue — into
`.claude/references/migration-discipline-{procedures,catalogue}.md`.

That path does not exist. `templates/phases/phase-4.2-apply.md:210-213` is the only install route for
`references/`, and it reads `for fw in <detected-frameworks>; do cp -R
~/.claude/templates/packs/<track>/references/${fw}.md .claude/references/ 2>/dev/null || true; done`
— the filename must equal a **detected framework name**, and `2>/dev/null || true` swallows the miss.
No framework is called `migration-discipline-procedures`. No adapter ships them either:
`phase-4.8-deep.md:35` enumerates the translation surface as `.claude/{rules,commands,agents}/<x>.md`
plus `.claude/skills/<x>/SKILL.md`, and `grep -rl '\.claude/references' templates/tool-adapters/`
returns zero files. 1.10.0's own align entry diagnosed exactly this and applied the fix to align
only; migration restated the bug as fact ("Every adapter bundle ships all three; do not break the
bundle"). Net effect: the rule reported a 30% token win while the installed project got *less*
enforcement than before.

**Fix: the depth moved to a destination that installs.** New `ai-patterns/migration-guardrails.md`
(38.7K) carries § Tier artifact specs · § What counts as dead V1 code (the 6-axis check) · § Halts
12-13 — full elaborations · § v1_status modes · § Anti-bloat merge gates · § Supporting mechanisms
(reviewer approval, mid-port tier promotion, idiom-drift propagation) · § Review checklist (per port
PR) · § Named anti-patterns (all 20, each with fingerprint and catching check) · § Enforcement —
where each halt is actually caught. `ai-patterns/*.md` copies unconditionally into `ai/patterns/`
(`phase-4.2-apply.md:207`) — the destination `scripts/check-rule-budget.sh:105` names in its own
failure message ("trim it or move depth to ai-patterns/"). Every pointer in the rule, in
`/find-and-fix`, `/migration-phase`, `parity-test-generate` and `_failure-surface.md` was repointed;
`rules/migration-discipline.md` now contains **zero** `.claude/references/` citations.

**Two duplicates were deleted rather than moved.** The references' § Contract — 9 required sections
restated the `extract-v1-contract` skill's own § 9 template verbatim, and § Tool-agnostic procedure
restated the three skills; skills install unconditionally, so both were removed and the rule now
cites the skills. With the enforceable depth gone, the 3.4K remainder of
`references/migration-discipline-procedures.md` (§ Tier rationale, § Should — full guidance) did not
justify a second never-installed file: **it was merged into `migration-discipline-catalogue.md` and
deleted.** The pack's `references/` fell 55,781 → 12,253 chars, and both `_essentials.md` and the
`_topics.md` reference-pair entry now state plainly that it is pack-side and installs nowhere.

**Four `_examples/` fallbacks deleted; those four topics now use source-as-fallback.**
- `_examples/migration-discipline.md` was edited on four lines during 1.10.0 while its source was
  rewritten by −11,505 chars. Heading-for-heading it still shipped six sections the source had
  retracted (`## What counts as dead V1 code (the 6-axis check)`, `## Examples per concern` and its
  four sub-sections, `## Review checklist`, `## Enforcement`) and was missing three the source had
  gained. At 25,898 vs 26,349 chars — 98% — no size heuristic could see it, and check 8b's own header
  names this blind spot. On greenfield that stale document *was* the project's always-loaded rule.
- `_examples/feature-port.md` was never re-cut at all, while 1.10.0 moved the 18-row axis-lookup
  table *into* `ai-patterns/feature-port.md`. The rule's structure-vs-behaviour tiebreaker therefore
  pointed a greenfield project at a section of a file it had been given that did not contain it.
- `_examples/{parity-testing,migration-ledger}.md` had the same structural defect latent: for a
  `kind: pattern` topic whose source is `ai-patterns/<name>.md`, the deterministic pack copy already
  puts the source at `ai/patterns/<name>.md`, so the `_examples/` twin can only ever overwrite a
  fresh source with a staler abridgement.

All four topics now name their live source in `fallback:` — the shape align already uses and
`phase-4.2-apply.md:26` explicitly implements. The class of bug is closed, not patched: a
source-as-fallback cannot drift from its source. `templates/packs/_fallback-baseline.md` lost its
`migration/migration-discipline UNSOURCED-MAGNITUDE` line (backlog 2 → 1), and the fallback-pair
corpus fell 295 → 291 with 0 new defects.

**The rule-only-tool classification was wrong for three of five tools.** Both rules said "rule-only
tools (Aider, Codex, Gemini; partial: Cline, Windsurf)", and that misclassification is what motivated
routing depth to `references/` for their benefit. `templates/tool-adapters/_registry.md:76` records
"Gemini has no executable primitive" as a **doc-verified FALSE** claim; Gemini has TOML custom
commands (`.gemini/commands/`), Codex has Agent Skills (`.agents/skills/`), Cline discovers Skills
from `.cline/skills/` and `.claude/skills/` (`_registry.md:53`), and Windsurf executes
`.windsurf/workflows/<name>.md` (`_registry.md:54`). Only Aider is genuinely rule-only
(`_registry.md:23`: closed slash set, no user-extensible primitive at any layer). Both rules now say
so and cite the registry.

**Accounting.** Rule: 37,854 → 27,648 chars (~9,463 → ~6,912 tokens, **−27%**) — 2,551 tokens banked
off the always-loaded budget, and now every token of delegated depth actually arrives. Pack total:
865,402 → 848,851 chars, **−16,551**. Files deleted: **5**
(`references/migration-discipline-procedures.md` + the four `_examples/` fallbacks). Commands: 20
before, 20 after — see § 1.10.0 for the per-pair overlap measurement that keeps them separate.

## 1.10.0 — 2026-08-23

**The always-loaded rule was a manual.** `rules/migration-discipline.md` was 37,854 chars
(~9,463 tokens) — more than the entire repo's 6,000-token baseline budget for *all* foundational
rules combined, charged on every turn of every project that installs this pack. It is now
**26,349 chars (~6,587 tokens), −30%**, and nothing enforceable left the file: the 13 halts, the
tier floor, the 9 contract sections, the must / must-not and the 20 named anti-patterns all stayed
in place, with the validator check name still attached to each halt.

What left was restatement, not rule. Seven top-level sections went: `What counts as dead V1 code
(the 6-axis check)` (halt 11 already names all six axes, so the section restated the halt),
`Examples per concern` and its four sub-sections (worked code samples, which belong in the
catalogue and were already there), `Review checklist`, `Enforcement` and `References`. `Per-stack
extensions` and `Tool-agnostic procedure` merged into one section, since both answer "what does a
tool without skill dispatch do". A new `## Load on demand` closes the file by naming, in one place,
every companion the rule delegates to.

**Where the depth went — deliberately not to `references/`.** The reflex move is to lift depth into
`references/`. For a Claude Code project that move loses the content: `templates/phases/phase-4.2-apply.md:211-214`
and `:347-350` are the only install paths for references and both read
`for fw in <detected-frameworks>; do cp .../references/${fw}.md .claude/references/ 2>/dev/null || true`,
so a file only installs when its **filename matches a detected framework name**. Nothing is called
`migration-discipline-procedures`, and `|| true` swallows the miss. So the depth that a project
must be able to reach went into `ai-patterns/feature-port.md` (14,483 → 17,042 chars), which
`phase-4.2-apply.md:208` copies unconditionally and `:342` copies again in MINIMAL mode. What stayed
in the two reference files was believed to be material only rule-only tools need, on the strength of
`templates/tool-adapters/_migration-pack-coverage.md:240` ("Every adapter translation MUST ship all
three files together"). **That belief was wrong, and 1.11.0 below corrects it** — no adapter's
translation table implements that sentence.

**`/migration-rollback` claimed a power it does not have.** Its "When to use" listed *"Production
traffic on V2 is failing for features in phase N"*, and the command restores a file snapshot. A
snapshot does not drain a canary, flip a cutover flag, reverse a backfill, or notify a consumer in
another repo — so following that line on a live incident reverts the code while traffic keeps
arriving at a V2 that no longer exists in the tree. That row is now a **When NOT to use** entry
pointing at the deployment runbook that halt #8 already forces every standard/heavy port to author,
and a new **irreversibility triage** runs before every other check. It REFUSES rather than warns, on
six signals, each naming the artifact that clears it: a row at `V2-canary` / `V2-only` /
`V1-deleted`; a backfill checkpoint past its start (a cross-store port is unwound by reconciliation,
never by file restore — restoring the code leaves the data moved and the two stores diverge
silently and permanently); an open `cross-repo-tasks.md` row; a missing or unreadable runbook
(unknown is not off); and a later-phase row citing a phase-N feature in `depends_on`. The command
also now states plainly that there is **no per-feature revert** — `/migration-phase <N>
--feature=<id>` re-ports forward from the contract, which is a different operation with a different
risk profile, and must never be described to a user as "undo".

**The pack advertised a scheduler that does not exist.** `/migration-status` said it ran "via weekly
cron" and that `.claude/git-hooks/post-merge-learn.sh` "may invoke this". Neither is true: the shim
at `templates/repo-baseline/.claude/git-hooks/post-merge` execs
`.claude/hooks/post-merge-learn.sh`, which appends review hints to `ai/dynamic/.review-queue` and
invokes no command at all. The baseline ships no cron. Corrected in `/migration-status`,
`agents/parity-auditor.md` and `ai-patterns/migration-ledger.md` (plus the matching fallbacks) —
a recurring report is a cadence the user wires up, and each place now says so.

**`api-other` is a trap in the anchors schema.** `validate_project_kind_strict()` at
`scripts/validate-migration-artifacts.sh:3170` accepts `api-other`, so it looks like the right
declaration for an API-only migration. But `extract_inventory_primitives()` branches on family at
`:1224-1230` — `frontend-*|mixed`, `backend-*`, `data-*`, `mobile-*` — and `api-other` matches none
of them, falling to the `*)` default which sets `family="frontend"`. An API migration declared
`api-other` is inventoried against two-way form bindings, component tags and click handlers, and the
tier promoter that fires when a V2 primitive count drops under 70% of V1's fires on that noise.
`_v2-anchors-schema.md` now says to declare `backend-other` instead, records that `project_kind` is
a **family prefix and not a closed list** (any `<family>-<flavour>` is legal; the suffix is
documentation for humans, so a new stack needs no schema change), and adds the `data-*` and
`mobile-*` values that the validator has always accepted but the schema never listed.

**Nine fallbacks had drifted below their sources.** `_examples/` is copied verbatim when extraction
finds no signal, which for a greenfield project is the only path — so a thin fallback is a thin
install. Restored: `parity-auditor.md` +211 lines (the entire two-layer navigation scan and the
Section 0 evidence block were missing), `port-feature.md` +74 (tier gating, Phase-4 ledger schema),
`extract-v1-contract.md` +42 (tier-aware scope, citation discipline), `data-cutover-orchestrate.md`
+32 (the 7 cite-or-halt detectors), `migration-ledger.md` +20 (5 extended states),
`migration-status.md` +19, `parity-test-generate.md` +15, `perf-uplift-survey.md` +14,
`migration-architect.md` +13.

`_examples/migration-discipline.md` was the exception: its source lost seven top-level sections
this release while the twin moved +33 chars, so a greenfield project would have installed the
pre-release rule shape. Check 8b cannot see that — `templates/phases/phase-4.2-apply.md:32` says it
"does not read either file". Rather than delete the twin, 1.10.0 documented the divergence in the
file itself and pinned the rule that follows from it: a citation must resolve in **both** shapes, so
cite halts, never delegated sections. **1.11.0 below retires the twin entirely instead**, which is
the better fix.

**Six section anchors broke when the rule was restructured, and no gate saw it.**
`scripts/lint-handoffs.sh` only opens a citation that carries a resolvable *path*; a citation written as a bare
basename plus a section name is ~89% of the corpus and is never opened. Repaired:
`commands/migration-plan.md:201`, `commands/migration-scan.md:96` and `agents/parity-auditor.md:308`
cited the deleted `§ What counts as dead V1 code` and now cite `§ Per-feature audit — 13 hard halts`
halt 11 — chosen because halt 11 is always-loaded and exists in the fallback shape too, so the
citation resolves everywhere. `_failure-surface.md:246` now names the catalogue section that holds
the example. `commands/migration-phase.md:154` and `:352` addressed "rule-only tools" and cited a
`§ Tool-agnostic procedure` that had been renamed.

**Also:** `_topics.md`'s `sections:` list for the rule still declared `examples_per_concern` and
`review_checklist`, two sections the rule no longer has, which would have had extraction re-author
them on every refresh; it is now an annotated 10-entry list matching the rule's real shape.
`references/migration-discipline-procedures.md` had duplicate `## Should` and `## Anti-bloat rules`
headings left over from the 2026-06-07 split, making those anchors ambiguous — removed.
`commands/find-and-fix.md:190` cited `§ Trivial-tier artifact spec`; the heading is
`§ Trivial-tier artifact spec (audit + code only)`. `commands/migration-gate.md` gained the
`## Phases applied` block it was missing.

**Not done, deliberately.** No commands merged, deleted or renamed; the pack still ships 20. Two
merge questions were asked and both were measured rather than asserted.

*Intra-pack*, on substantive lines (non-blank, ≥25 chars, deduped) — the eight pairs a reader would
nominate on their names alone: `migrate` vs `migration-scan` **0.0%** · `migration-recheck` vs
`find-and-fix` **0.0%** · `compare-v1` vs `migration-scan` **0.7%** · `migration-final` vs
`migration-status` **1.0%** · `find-and-fix` vs `port-feature` **1.2%** · `migration-fast` vs
`migration-phase` **4.6%** · `migration-replan` vs `migration-plan` **8.3%** · `migration-unpark` vs
`migration-park` **14.8%**. The highest is the park/unpark inverse pair, and that number *is* the
contract between them — unpark reads the fields park writes — not duplication to remove. Nothing
here supports a merge.

*Cross-pack.* The question — whether the 13 identically-suffixed `{migration,align}-*` pairs are one state
machine implemented twice — was measured rather than assumed, and the full table is in
`templates/packs/align/CHANGELOG.md` § 1.10.0. Summary: after neutralising pack vocabulary so that
structure is compared rather than nouns, median overlap is **14.6%** and the maximum is **35.4%**
(`recheck`). The residue that does overlap is not pack duplication — the 48 identical lines in
`recheck` are overwhelmingly the repo-wide 7-phase command harness that **90 of the 133 pack
commands** carry, which merging would not remove. The two packs share a vocabulary because they are
the same *shape* of process; they do not share an implementation, because migration reconciles two
codebases against a parity oracle and align reconciles one codebase against its own documented
idioms. **Verdict: KEEP-SEPARATE, on evidence.**

## 1.9.1 — 2026-08-22

**Three anchors, including a self-citation.** `scripts/lint-handoffs.sh` opened the targets:

- `agents/parity-auditor.md` (density rule for axes) pointed a `§ Forms-bearing fingerprints`
  anchor at `frontend/rules/migration-frontend.md` for the concrete per-stack form-input tags. No such section; the tags are the `input_html` / `v_model` rows of
  **§ Stack-aware primitive set**, which the citation now names.
- `references/migration-discipline-procedures.md` Halt 12 cited the same file's
  `§ Leaf-component extensions` for the leaf-component / view-template extension list. No such
  section; the `.vue` / `.tsx` / `.svelte` / `.jsx` list is in **§ Frontend audit axes**, inside the
  Section 0 completion checklist.
- Halt 13 pointed a `§ Navigation Inventory two-layer scan` anchor at **its own file** for the full
  two-layer spec and the Section 0 checklist. That is not a
  heading anywhere in it. Both live verbatim in
  `frontend/rules/migration-frontend.md § Frontend audit axes`, which the pointer now names, so the
  reader is sent to the file that has the spec instead of back to the paragraph they are reading.

## 1.9.0 — 2026-07-09

- skills +1: data-cutover-orchestrate — cross-store V1->V2 data port: resumable checkpointed
  backfill + field-mapping + reconciliation + read-cutover gated on backfill-complete. The unowned
  seam between parity-test-generate (compares) and database/migrations (single-store
  expand-contract). Backing MUST/SHOULD in migration-discipline.

## 1.8.0 — 2026-06-26

- /migrate relocated from core commands/migrate.md into this pack
  (templates/packs/migration/commands/migrate.md). Rationale: /migrate is bound to a V1/V2 source
  pair + ai/migration/ledger.md and pre-flight-fails in a normal project (project-scoped, not a
  universal method) — it belongs with the migration suite it fronts, not on the always-loaded global
  command surface. It is the simple-surface one-command alias for the /migration-scan →
  /migration-plan → /migration-fast cycle, now installed per-project by /setup-project when the
  migration pack is selected (like every other migration command).
- Declared as a command in _essentials.md (commands array, first entry) + _topics.md (kind: command,
  fallback: commands/migrate.md) so AUTHOR-mode generation and pack-consistency see it.
- Cross-repo doc sync: the global 'simple-surface commands' set drops from 8 to 7 (/roadmap /align
  /optimize /refactor /polish /audit /unify-surfaces) across README, docs/COMMANDS.md,
  docs/REFERENCE.md, tool-adapters/_registry.md and _orchestration-sync.md; commands/migrate.md's
  internal core-discipline link repointed to ~/.claude/templates/governance/core-discipline.md to
  resolve from the new depth.
- Also de-globalised /learn-from-task (its global commands/ copy dropped; the always-applied
  learning pack already carries it per-project) in the same sweep. Global core command surface: 16 →
  14.

## 1.7.1 — 2026-06-22

- migration-ledger.md § Per-feature record shape: rewritten to the canonical single fenced-YAML
  list. Each feature is now a two-space-indented `- id: F<NNN>` list item with fields indented one
  level beneath it (id is the row key; feature: carries the human slug), replacing the prior
  per-feature markdown `## <feature-name>` heading + separate yaml block. This aligns the documented
  shape with the actual parsers (discover_features, migrate-parallel.sh, migration-doctor.sh), which
  anchor on the indented `- id: FNNN` row marker and read each field as an indented `key: value` —
  the old `##`-heading shape would extract zero rows.

## 1.7.0 — 2026-06-16

- cross-repo-task: NEW reopen <task-id> --reason subcommand — reverses a premature close/abandon
  (landed→open) and re-blocks the feature in the ledger; previously a premature closure left the
  feature in a false-done limbo with no recovery path.
- cross-repo-task: register now captures expected_contract (--contract, or derived-and-confirmed)
  and generates a paste-ready upstream-request artifact at
  ai/migration/cross-repo-requests/<task-id>.md (the exact contract + which downstream features are
  blocked + acceptance criteria) — turns 'notify the owner' into a concrete handoff.
- cross-repo-task: drain now contract-checks each landed task before retrying the port; a feature
  reaches done only via a clean drain, never via close alone. Mismatch ⇒ suggest reopen. Added list
  --stale (open > 30d).
- migration-final: now reads cross-repo-tasks.md — any open/in-flight task forces INCOMPLETE and
  blocks the V1 retirement plan (new pre-req + Phase 2 check + deterministic-verdict condition +
  hard rule). A feature waiting on an upstream change isn't truly ported.

## 1.6.0 — 2026-06-07

- Split migration-discipline.md (was 79.5k — roughly half silently truncated every session by Claude
  Code's 40k always-on limit) into an always-on core (<40k) + two on-demand companions under
  references/ (content relocated VERBATIM, zero rewording): migration-discipline-procedures.md (tier
  specs, contract template, full halt elaborations, tool-agnostic procedures, operational protocols,
  enforcement matrix) + migration-discipline-catalogue.md (worked examples, anti-pattern catalogue,
  per-tool dispatch tables).
- The 'procedures are inlined here' contract is replaced by the rule-bundle contract: core + 2
  references = ONE discipline. Every adapter bundle MUST ship all three files together
  (_migration-pack-coverage.md § Rule-bundle requirement).
- Manifests declare the pair: rule_references: [migration-discipline-procedures,
  migration-discipline-catalogue] in _essentials.md; reference-pair topic in _topics.md.
- Follow-up trims (07c22ec): core reduced to ~36.2k to leave headroom for a project-specific
  apply-anchors block so an anchored project copy stays under 40k; companion pointers repointed to
  the project-consumption path (.claude/references/migration-discipline-procedures.md /
  -catalogue.md) so every tool resolves them from the repo root (c92a955).

## 1.5.2 — 2026-05-07

- /migration-recheck: NEW --phase=<N> mode. Reads ledger / plan, expands to phase N's full feature
  set (done rows included), runs fresh audit + in-place fix per row WITHOUT rolling back the phase
  or downgrading clean done rows. Status only flips when fresh audit surfaces drift. The
  non-rollback alternative to /migration-rollback <N> + /migration-fast <N>.
- Mutually exclusive with description / path inputs in the same invocation. Combinable with
  --re-detect-only for phase-wide drift report without edits.
- Doc updates: COMMANDS.md row, REFERENCE.md plan-independent section, _topics.md sections list.

## 1.5.1 — 2026-05-03

- Sync-chain repair: _topics.md now declares migration-promote-tier, draft-phase-adrs, and
  find-and-fix as commands (previously shipped under commands/ but absent from the topic list,
  breaking /setup-project AUTHOR-mode generation for these surfaces).

## 1.5.0 — 2026-05-02

- Reviewer-approval mechanism: heavy-tier rows now have a real protocol. Ledger field
  `reviewer_approval: <name>@<iso>`. Status `pending-review` between fix-applied and
  reviewer-signoff. Halt file at `ai/migration/halts/<id>-pending-review.md`. CODEOWNERS-based
  default reviewer; --reviewer override; 7-day default timeout; no auto-fail.
- Mid-port tier promotion: `/migration-promote-tier <id> <new-tier>` mini-command. Promotion
  backfills required artifacts; demotion requires --reason and is forbidden for
  P0/cross-repo/contract-break/write-path rows.
- Idiom-drift propagation: `/migration-scan` compares oracle file hashes against prior scan;
  surfaces 'Oracle drift detected' section. `/migration-replan --include-drifted` re-phases affected
  rows.
- Cross-repo task workflow: NEW `/cross-repo-task` command. Subcommands: register / list / update /
  close / drain. Tracks blockers in `ai/migration/cross-repo-tasks.md`. Drain re-runs
  `/find-and-fix` on rows whose blockers landed.
- Validator additions (PLANNED): check_oracle_drift, check_reviewer_approval — agent-side until
  script ships.

## 1.4.0 — 2026-05-02

- Make /migration-recheck plan-independent. NO ledger required. NO plan required. NO phase concept.
  NO required prior scan.
- New flow: SCAN-FRESH directly against V1 + V2 source for the resolved area (description or path).
  AUDIT-FRESH (no cache lookup, no prior-audit reuse). FIX. VERIFY. RECORD-LEDGER (best-effort:
  update if exists, leave alone if not).
- New flags: --register-ledger (create new ledger row from recheck findings), --ledger-only (legacy:
  restrict to existing rows), --v1-commit=<sha> (pin V1 commit, default: HEAD).
- Removed flags: --match-on, --include-done, --include-deprecated (no ledger to match against by
  default), --ports-only.
- Use case: spot-check an area without setting up the full migration ceremony. Works whether or not
  the area is in the migration plan.

## 1.3.2 — 2026-05-02

- Replace tokenize-keyword-search resolution in /migration-recheck with semantic understanding. Like
  /add-feature, the agent reads codebase-profile.md + ledger + architecture/conventions + idioms,
  then maps the description to features by intent — not keyword matching.
- No more stopword-stripping or keyword-scoring; the agent uses its full read-context capability.
  Compound descriptions ('the auth flow including login and signup') are handled as one semantic
  intent.
- Confirmation flow refined: confident → silent (with preamble); uncertain → halt with
  disambiguation options; nothing-found → halt with concrete suggestions.

## 1.3.1 — 2026-05-02

- /migration-recheck now accepts natural-language descriptions (e.g., 'the sidebar', 'the orders
  module', 'the page builder', 'customer tabs in the dashboard') in addition to paths.
- Resolution procedure: tokenize → ledger keyword search → codebase grep → codebase-profile lookup →
  confirm-or-run.
- New flags: --no-confirm, --always-confirm, --max-matches=<N> for resolution behaviour control.
- Single high-confidence match runs immediately; ambiguous matches halt for user confirmation; zero
  matches halt with suggestions.
- Mixed input supported: descriptions + paths in the same command.

## 1.3.0 — 2026-05-02

- Add /migration-recheck <path> [<path>...] command. Path-scoped re-audit + re-fix; not tied to
  phases. Use case: 're-check the orders module', 're-check the sidebar', 're-check
  src/modules/{store,products}'. Mirrors /find-and-fix's per-feature loop but multi-feature +
  path-scoped. Same discipline (DETECT → DECIDE → FIX → VERIFY → RECORD; one commit per feature;
  halts aggregated).

## 1.2.0 — 2026-05-02

- **No-dead-V1-port rule**: refuse to port V1 features with zero callers. Added halt #11 to
  per-feature audit (the rule now has 11 hard halts, not 10).
- 6-axis reachability check inlined in `migration-discipline.md § What counts as dead V1 code` — app
  source / tests / cron / route registration / infra / production telemetry. A feature is dead iff
  all 6 axes (or axes 1–5 if observability is N/A) return zero callers.
- Dead V1 features are marked `status: deprecated` with `deprecation_reason: dead-v1-no-callers` at
  scan time. They are excluded from /migration-plan's phasing, skipped by /migration-fast, and
  deleted from V1 directly during retirement (never touch V2).
- Override flags on /migration-scan: --include-dead (force-port a flagged-dead row; requires
  caller_evidence), --external-consumer (bypass axis 1 for library exports / public APIs),
  --in-development (for unwired features about to ship).
- New 'The Zombie Port' anti-pattern in the rule: porting code with zero callers migrates V1 rot
  into V2. Real cost: ~50–500 lines per zombie × ~15% of inventory = ~10K lines of waste in a
  200-feature migration.
- Updated /migration-scan: dead-code reachability is the 4th parallel scan in Phase 2.
  Scan-report.md gets a 'Dead V1 features (excluded from port queue)' section with the 6-axis
  breakdown per row. Ledger schema gains a `reachability:` field.
- Updated /migration-plan: dead rows are listed in a 'Dead — excluded from port queue' section, NOT
  in any phase.
- Validator addition (PLANNED): check_no_dead_v1_ported re-runs the 6-axis check at PR time and
  refuses the gate if a dead feature was ported.

## 1.1.0 — 2026-04-29

- Make migration-discipline.md self-sufficient: inline the 9 contract sections, 10 hard halts,
  frontend audit axes, frontend anti-pattern catalogue, and tool-agnostic procedures so rule-only
  tools (Aider, Codex, Gemini) get the full discipline floor.
- Make /migration-phase a thin dispatcher of /port-feature per row; mandate parity-auditor (or its
  10-halt checklist inlined); add Phase 4a pre-flight via migration-detect-existing.sh.
- Make /migration-gate enforce 12 checks (file presence + content quality + citation resolution +
  corpus size + tolerance coverage + perf measurements + audit hand-wave detection).
- Add scripts/validate-migration-artifacts.sh: language-agnostic Bash validator runnable from any
  tool's hook system.
- Add frontend recipes to parity-test-generate.md: page-level mount + composable golden master +
  component snapshot + E2E parity + visual regression + a11y diff + multi-locale.
- Document auto-import test-config requirement and KeepAlive-aware mount for Vue (failure modes #8
  and #10 in audit-failure-modes.md).
- Add _examples/audit-failure-modes.md: 10 named anti-patterns observed in real audits including
  F039 (Trusted Summary), Hand-waved Query Param, Optimistic Form Field Match, Permission-gate Drop,
  Skipped Contract, Thin Corpus, Stale Plan Reference, Auto-import Trip, defineExpose-Less Page,
  KeepAlive-onMounted Mismatch.
- Add _examples/audit-template.md: copy-paste audit file structure with required sections + per-axis
  enumeration discipline + frontend axes section.
- Add tool-adapters/_migration-pack-coverage.md: per-tool translation expectations for migration
  discipline across Claude Code, OpenCode, Cursor, Copilot, Continue, Cline, Windsurf, Aider, Codex,
  Gemini.
- Update _essentials.md with phased-vs-per-feature flow diagram and decision tree.
- Root-cause: F039 (geography-mappings) shipped audit with missing add-button + divergent query
  params because /migration-phase was a permissive shell over the strict toolchain. This release
  closes the discipline floor.

## 1.0.0 — 2026-04-27

- Initial migration pack release.
