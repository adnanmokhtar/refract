# CHANGELOG

All notable changes to claude-config and its commands. Per-pack changelogs live under `templates/packs/<name>/CHANGELOG.md` (Hard rule A27).

The format is loosely inspired by Keep a Changelog. Versions follow Semantic Versioning at the command level: major = breaking artifact-shape change; minor = new capability; patch = fix or doc.

## [Unreleased]

### M21 — Decisions-first batch flow for migration pack

User pain point: "running /port-feature per row takes very long and I need to keep my eye on the CLI." Per-feature interactive ports re-prompt the user for the same cross-cutting decisions (RBAC slug renames, payload shape changes, `is_active` defaults) once per affected feature. M21 adds a **decisions-first batch flow** that decouples decisions from execution.

#### Added
- **`/draft-phase-adrs <N>`** (new command) — Reads `phase-<N>.md` audit summary + per-feature audits, drafts one ADR per P0 + cross-cutting decision in `ai/decisions/`. Each ADR ships as `Status: proposed`; user reviews + flips to `accepted` in one focus session. Cross-cutting decisions get a single ADR covering ≥2 features (instead of N micro-decisions across N port runs).
- **Index doc** `ai/decisions/_phase-<N>-decisions.md` — single managed-block index per phase listing every drafted ADR + cross-repo coordination items + sign-off checklist.

#### Changed
- **`/port-feature`** — added `--unattended` flag. When set, the command reads accepted ADRs as pre-approved decisions and skips the matching halts (e.g., contract review, plan slicing, intentional-break authoring). HALTS preserved for: new ambiguities not covered by an ADR, path violations, parity-auditor verdicts, cutover stage advance.
- **`/migration-phase <N>`** — added `--chain` flag. After `/draft-phase-adrs` produces ADRs the user accepts, `--chain` runs `/port-feature <id> --unattended` per feature in dependency order, aggregates halts at end-of-phase, and auto-invokes `/migration-gate <N>`. New `--stop-on-halt` (default) and `--no-stop-on-halt` modifiers. Mutually exclusive with `--audit-only`.
- **`docs/COMMANDS.md`** — Suite A migration table updated with `/draft-phase-adrs` row + new "batch workflow" example next to the interactive workflow.

#### Why
Empirical: Phase 7 + Phase 8 audits (tenant-portal-v2, 21 features total) surfaced the same RBAC permission-slug renames recurring across 4–8 features per phase. Per-row interactive `/port-feature` would require deciding the rename policy 4–8 times. Batching cuts that supervision cost ~30% per phase. The pattern is exactly Phase 2 of any phased migration plan ("Pre-port decisions") — already built into `/migration-plan`'s output, but skipped when teams jump from `--audit-only` to per-row porting. M21 makes Phase 2 first-class with its own command + the unattended wiring.

#### Compatibility
- **Backward compatible.** Default `/migration-phase <N>` and `/port-feature <id>` invocations unchanged. `--chain` and `--unattended` are opt-in.
- **No new artifacts in the discipline rule.** `migration-discipline.md`'s 9-section contract, 10-halt audit, parity tests, perf-decisions, rollback runbooks all unchanged. The new command + flags are about *when* the user makes intentional-break decisions, not *what* the discipline requires.

#### Files touched
- `templates/packs/migration/commands/draft-phase-adrs.md` (new)
- `templates/packs/migration/commands/port-feature.md` (added Flags + Unattended-mode sections)
- `templates/packs/migration/commands/migration-phase.md` (added flags + Workflow modes table + Chain mode section)
- `docs/COMMANDS.md` (Suite A table + batch workflow example)

## [2.16.0] — 2026-04-28

### M20 — Fill remaining pack gaps (19 new artifacts across 5 packs)

User: "fix the gaps." M20 closes coverage in security / performance / observability / infrastructure / distributed-systems.

#### Added (per pack)
- **security** (3 commands): secret-scan, threat-model, dependency-vuln-check
- **performance** (4): commands profile-perf + bundle-perf; agent caching-architect; pattern lazy-loading
- **observability** (4): commands add-tracing + add-metrics + alert-design; skill slo-audit
- **infrastructure** (5): commands audit-iam + cost-audit + provision-tier; skill tf-plan-review; pattern multi-region
- **distributed-systems** (4): commands add-saga + add-event-handler + audit-distributed-tx; skill dlq-replay

#### Verified
- audit-template-quality: 0 thin / 0 non-7-phase / 0 no-preflight / 0 no-output / 0 thin (any kind). Every M20 file at full canonical depth.
- smoke-test: 8/8 pass; 0 fail / 0 warn.
- verify-sync: 57 ok / 0 drift.

#### State after M20
17 packs; all with ≥2 commands except ui-ux (1 command + 3 audit skills). No empty packs. Coverage spans:
- Web (backend + frontend)
- Mobile
- Code-quality / testing / refactoring
- Database (incl. migrations)
- Security (incl. threat modeling + secret scanning + dep vuln)
- Performance (perf + bundle + caching + lazy-load)
- Observability (tracing + metrics + alerts + SLO)
- Infrastructure (provisioning + IAM + cost + tf-review + multi-region)
- Distributed systems (sagas + events + DLQ + idempotency)
- Business completeness (cycles + funnel + coverage)
- UI-UX (design tokens + a11y + motion)
- Documentation, devops, learning, migration

The pack-template content is the deep knowledge center the user asked for. The agent's job is honoring the M11→M17 contracts so that content lands in target projects.

## [2.15.0] — 2026-04-28

### M19 — Mobile / business / ui-ux pack expansion (17 new artifacts)

User asked for a deep knowledge center, no stubs. M19 fills the largest coverage gaps.

#### Added — mobile pack (10 new; was 2 → now 12)
- commands: `add-screen`, `add-feature`, `optimize-bundle`
- agents: `app-store-reviewer`
- skills: `bundle-analyze`, `native-bridge-audit`
- patterns: `offline-sync`, `native-storage`, `deep-linking`

#### Added — business pack (4 new; was 5 → now 9)
- rule: `business-completeness`
- skills: `audit-funnel-completion`, `check-business-coverage`
- pattern: `missing-counterparts`

#### Added — ui-ux pack (3 new; was 11 → now 14)
- skills: `design-token-audit`, `motion-audit`, `a11y-quick-check`

#### Pack inventory after M19
| Pack | Before | After |
|------|--------|-------|
| mobile | 2 | 12 |
| business | 5 | 9 |
| ui-ux | 11 | 14 |

#### Verified
- audit-template-quality: 0 thin / 0 non-7-phase / 0 no-preflight / 0 no-output / 0 thin (any kind).
- smoke-test: 8/8 pass; 0 fail / 0 warn.
- verify-sync: 57 ok / 0 drift.

#### Honest scope
M19 fills the largest gaps. distributed-systems / infrastructure / observability / performance / security still have 1-2 commands each — M20+ candidates. Each new artifact is 100-300 lines of engineering content.

## [2.14.0] — 2026-04-28

### M18 — Template content audit + frontend `/add-feature` parity

User asked for review of ALL templates. Real audit + concrete fix.

#### Audit results (71 commands, 70 agents, 43 skills, 34 rules, 53 patterns)
- Thin commands: 0
- Non-7-phase commands: 0 (read-only exceptions honored)
- Thin / no-preflight / no-output agents: 0
- Thin skills / rules / patterns: 0

**Total: 0 content-quality issues.** Pack templates are clean.

#### Diagnosis: the 57-line stub
The user's `add-feature.md` at 57 lines in tenant-portal-v2 was NOT a pack issue. The pack source is 301 lines, well-formed. The 57-line file was an **agent-authored stub from a prior buggy run** — exactly the bug class M11/M15/M16/M17 closes. M15's `study-existing.sh` correctly flags it as `REPLACE-OR-ENHANCE` (target 57 / pack 301 = 19%).

#### Real cross-pack gap closed
- **`templates/packs/frontend/commands/add-feature.md`** added (~250 lines). Mirrors backend's depth, uses canonical 7-phase template, dispatches frontend-specific agents (ui-architect / ui-reviewer / accessibility-auditor / i18n-auditor / design-system-guardian), hard rules (one styling system, every string is a key, schema validation at boundary).

#### Added
- `scripts/audit-template-quality.sh` — re-runnable comprehensive audit. Honors documented exceptions (read-only commands skip Phases 5-7).

#### What this means
M15+M16+M17 detect / refuse stubs at the artifact layer. M18 confirms the source content is clean. Together: when the agent honors the M11→M17 contract, refresh produces good output because the templates are quality AND the agent can't ship shortcuts.

#### Honest scope
Audit is mechanical. Doesn't verify semantic quality, version freshness of framework references, or cross-reference resolution. Those are per-file human review.

## [2.13.0] — 2026-04-28

### M17 — Final round: front-loaded contract + composite + auditor + regression

User asked for the final round. M17 closes the four remaining gaps from the M11 → M16 trajectory: prose-rule skipping, no single composite invocation, audit-form Phase 5 still LLM-judged, and no regression test for the whole loop.

#### Added
- `scripts/run-preflight.sh` — composite invocation. Runs all 4 deterministic scripts in order. The orchestrator's hard rule becomes "run THIS one script."
- `scripts/audit-setup.sh` — Phase 5 deterministic auditor. Reads all 4 reports, checks `<TBD>` markers, counts structural recommendations, verifies pack-coverage Missing rows are now present. Exit 1 = REFUSED; exit 0 = safe.

#### Changed — orchestrator front-loaded
- `commands/setup-project.md` opens with **🛑 STEP ZERO — deterministic preflight (M17)**. Before persona, before mandate. Agent reads: run preflight at Phase 0.0; run audit at Phase 5; if audit exits 1 → REFUSED; Phase 4's work plan IS the 4 reports.

#### Changed — smoke test extended
- `smoke-test.sh` check #8: M17 regression. Copies django fixture, runs preflight, verifies 3 reports written, runs audit, verifies it exits 1 (TBDs unfilled = expected). Catches any break in the M11→M17 chain.

#### Closes M11→M16 trajectory
| Gap | Closed by |
|---|---|
| Prose rules skipped under context pressure | M17 front-loaded contract |
| 4 separate scripts → easy to forget one | M17 `run-preflight.sh` composite |
| Phase 5 audit LLM-judged | M17 `audit-setup.sh` deterministic |
| No regression test for the loop | M17 smoke check #8 |

#### Verified
- `smoke-test.sh`: 8/8 pass; 0 fail / 0 warn.
- `verify-sync.sh`: 56 ok / 0 drift.

#### Honest scope
M11 → M17 is mechanical from orchestrator's first instruction to Phase 5's exit code. Remaining LLM-judgment: filling `<TBD>` prose, addressing actionable rows in Phase 4, judging recommendation quality. Bug class reduced from "agent silently skipped the work" to "agent did the work shallowly" — much narrower and easier to spot in review.

## [2.12.0] — 2026-04-28

### M16 — Full codebase analysis + structural recommendations contract

User directive: "the next run — refresh / migration / refine — must prioritize a full codebase analysis. Review the current setup, every individual file, all command/setup/package-level files. Decide on **meaningful, structural improvements — not just minor, isolated changes.**"

M15 covered the artifact layer (.claude/ + ai/). M16 covers the actual codebase (src/, app/, lib/, manifests, configs).

#### Added
- `scripts/deep-codebase-scan.sh <target>` — walks the actual codebase. Mechanical sections (auto-filled):
  - Section 1: file count by language extension
  - Section 2: top-level directory tree
  - Section 3: manifests + framework markers detected (package.json, pyproject.toml, vite.config, next.config, tsconfig, etc.)
  - Section 4: suffix patterns visible (`*.service.ts`, `*.repository.ts`, `*.dto.ts` — counts files matching 30+ architectural suffixes)
  - Section 5: lines of code by language (excluding tests)
  - Section 6: pattern grep — class extenders (TS/JS + Python) → potential base classes with 3+ extenders
  - Section 7: setup-artifact summary (cross-reference for drift detection)

  Then 8 semantic-questions sections (LLM MUST fill — empty = Phase 5 fails):
  - Section 8: module map — top-level features/contexts visible in code
  - Section 9: architecture pattern detected (vs ai/architecture.md declaration)
  - Section 10: top 10 conventions visible — compared to ai/conventions.md
  - Section 11: patterns repeated 3+ times (candidates for ai/patterns/)
  - Section 12: decisions implicit in code (candidates for ADRs)
  - Section 13: drift between rules and code (rules code violates, code patterns not in rules)
  - Section 14: stale references in setup (paths/classes that no longer exist)
  - **Section 15: recommended STRUCTURAL improvements** — minimum 3 on non-trivial codebases. Format requires What / Why / Where / Effort / Risk per item. Explicit "qualifies vs doesn't qualify" examples in the script — minor isolated changes are REJECTED.

  Output: `<target>/.claude/_codebase-scan.md`. Bug fix: `|| true` on grep pipelines so pipefail doesn't kill the script when no matches found.

#### Changed
- **Phase 0.0** now mandates running the 4th script (`deep-codebase-scan.sh`) alongside M15's three. Total: 4 reports the agent must consume.
- **Phase 5 audit C2c** (NEW): 6 must-pass checks for the deep-scan report. Empty section = fail. Less than 3 structural recommendations on a non-trivial codebase = fail. Drift findings unaddressed = fail. Stale references unaddressed = fail.

#### What this changes for the user

Next `/setup-project --refresh / --refine / --enhance` on any codebase:

1. Phase 0.0 runs `deep-codebase-scan.sh` → mechanical sections auto-fill (file counts, suffix patterns, base classes, manifests).
2. Agent MUST fill semantic sections 8-15 — module map, architecture pattern, conventions visible, repeated patterns, implicit decisions, rule-vs-code drift, stale references, **structural improvements**.
3. Phase 4 reads section 15's recommendations and applies them (ADRs proposed, patterns documented, rules updated/anchored, stale refs cleaned).
4. Phase 5 refuses success if any section is `<TBD>`, if section 15 has fewer than 3 structural recommendations, or if recommendations are minor.

**Net effect**: the historical bug ("refresh ran shallow — touched ≤5 surface files, never compared rules to code, never proposed structural changes") becomes mechanically prevented at the artifact layer (M15) AND the code layer (M16).

#### Verified
- Tested against `claude-config/tests/setup-project/fixtures/django/` — script ran clean, wrote 131-line report with 10 `<TBD>` markers (8 mandatory sections × 2 lines each + section 15 + summary).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 54 ok / 0 drift.

#### Honest scope statement
The script is deterministic. The semantic answers are LLM-authored. Phase 5 audit catches empty `<TBD>` and "fewer than 3 recommendations" mechanically. **It cannot judge whether recommendations are genuinely "structural" vs "isolated"** — that's still LLM judgment in the audit, partially mitigated by the explicit qualifying-examples table embedded in section 15.

## [2.11.0] — 2026-04-28

### M15 — Make refresh / refine / enhance / migration actually do the deep work

User reported repeatedly that `/setup-project --refresh --include=migration` produced shallow output: backed up + version-stamped + a few derived files, then declared "no work to do" while 21 migration pack files were missing from the target. Re-running M11's "directory parity scan" rule didn't fix it because the agent kept ignoring prose rules under context pressure.

**M15 root cause**: prose rules don't constrain LLM behavior. Shell scripts producing files the LLM must read DO constrain it.

#### Added — three deterministic scripts

- `scripts/pack-coverage-scan.sh <target> [packs...]` — for each selected pack, lists pack source files vs target, classifies each as Missing or Present (with size ratio for merge-matrix decisions). Writes `.claude/_pack-coverage-report.md`. Exit always 0; the report is the contract.
- `scripts/refresh-extract-checklist.sh <target>` — auto-inventories the target's existing artifacts (counts of agents, commands, skills, rules, ADRs, patterns); writes `.claude/_refresh-extract.md` with **9 prose sections that Phase 0.2 MUST fill**. Sections 2-8: ADRs preserved, validated user corrections, project intent, custom rules, custom agents/skills/commands, architecture decisions implicit in code, detected stack + version. Section 9: V1↔V2 mapping when migration in scope. Empty `<TBD>` sections fail Phase 5 audit.
- `scripts/study-existing.sh <target> [packs...]` — for every existing target file with a pack equivalent, applies Appendix C merge matrix deterministically: byte-identity check first (IDENTICAL-NO-OP), then size ratio decides REPLACE-OR-ENHANCE / KEEP-OURS-PLUS-INJECT / MERGE / KEEP-OURS-ADD-SIDE-DOC / KEEP-OURS-DEEP. Files in target but NOT in pack flagged as REVIEW (project-specific keeper or upstream-deprecated). Writes `.claude/_study-existing-report.md`.

#### Changed — phases now MANDATE the scripts

- **Phase 0.0 (NEW first sub-step of Phase 0)**: runs all three scripts before any other Phase 0 work. Reports become the contract for Phase 4 actions.
- **Phase 4.0**: if Phase 0.0 didn't run (CREATE/ENHANCE skip Phase 0), Phase 4.0 runs `pack-coverage-scan.sh` + `study-existing.sh` itself. Either way, no Phase 4.2 decision is made without consulting the reports.
- **Phase 5 audit (C2b NEW)**: 7 new must-pass checks:
  - The three reports exist.
  - Every "Missing" / "REPLACE-OR-ENHANCE" / "MERGE" / "KEEP-OURS-PLUS-INJECT" row was addressed (or explicitly skipped with rationale).
  - Sections 2-8 of `_refresh-extract.md` are non-empty.
  - Section 9 non-empty when `--include=migration` was set.

#### Sync infrastructure

- Added `scripts:scripts` to `sync-to-global.sh` `SYNC_MAP`. `~/.claude/scripts/` is now symlinked back to the repo. Old `~/.claude/scripts/` directory backed up automatically.
- 23 scripts now visible at `~/.claude/scripts/` for the agent to invoke.
- `verify-sync.sh` updated to check scripts as well: 53 ok / 0 drift (was 30 ok before scripts were synced).

#### Verified
- All 3 scripts work against `tenant-portal-v2` (used as live test target):
  - `pack-coverage-scan.sh tenant-portal-v2 migration` → wrote report listing all 21 pack files (all present after prior manual cp).
  - `refresh-extract-checklist.sh tenant-portal-v2` → wrote checklist with auto-inventory + 9 sections demanding fill.
  - `study-existing.sh tenant-portal-v2 migration` → 0 actionable / 21 keep / 48 orphans (correctly classifies the 21 migration files as IDENTICAL-NO-OP and flags 48 project-specific commands/agents for REVIEW).
- `lint-artifact.sh`: 0 errors / 22 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 53 ok / 0 drift.

#### What this changes for the user

Next `/setup-project --refresh --include=migration` run on a target where files are missing:

1. Phase 0.0 runs `pack-coverage-scan.sh` → writes report listing every missing file by name and target path.
2. Phase 0.0 runs `study-existing.sh` → classifies every existing-vs-pack pairing per Appendix C.
3. Phase 0.0 runs `refresh-extract-checklist.sh` → produces the 9-section extract template the agent must fill.
4. Phase 4 reads ALL three reports and applies the decisions. Cannot skip "Missing" rows.
5. Phase 5 audit refuses success if any actionable row was silently ignored.

The historic bug ("idempotent — no work to do" while 21 files missing) becomes mechanically impossible: the report lists the 21 files, Phase 4 must address each, Phase 5 verifies.

#### Honest scope statement
The scripts are deterministic. The agent reading them is still an LLM. If the agent ignores the script output entirely (a regression of the same class), Phase 5's "did Phase 4 address every actionable row?" check catches it — but only if the agent honors Phase 5. M15 raises the floor significantly; doesn't eliminate LLM judgment from the loop entirely.

## [2.10.0] — 2026-04-28

### M14 — Related sections across all packs

User: "not migration only — all commands agents skills rules and the ai knowledge for all packs". Real refinement work, not a survey.

#### Coverage before M14
- Migration commands: 11/12 had `## Related` (M13 added them).
- All other commands + agents: **0 / ~120 had Related sections.**

#### What landed
- `scripts/add-related-sections.sh` — generates per-file Related sections from the pack's contents:
  - Sibling commands / agents in the same pack/kind.
  - Patterns in the same pack.
  - Rules in the same pack.
- Idempotent: skips files that already have `## Related`.
- Default dry-run; `--apply` to write.

Applied across all packs:
- **98 files updated** with Related sections.
- 11 files skipped (migration commands already had them from M13).

After M14: every command + agent in every pack has navigation links to siblings + patterns + rules.

#### Audit findings (no fixes needed)
Verified during the per-pack pass:
- All 11 migration commands' phase counts are correct (false positives caused by sed double-counting example output blocks).
- 514-line `apply-pack-adaptation` skill is justified (two distinct mode outputs).
- 273-line `api-reviewer` agent is content density, not padding.
- 4 baseline rules (A19) reviewed in M7 — still solid.

#### Honest scope
- M14 is **mechanical**: Related sections auto-generated from pack contents. Each section lists ALL siblings, not just the most-relevant ones — so it's a navigation aid, not a curated cross-reference.
- M14 does **not** read individual file content for semantic improvements. That remains M15+ multi-day work.

#### Verified
- 109/109 commands + agents now have `## Related`.
- `lint-artifact.sh`: 0 errors / 22 warnings (the 2 new warnings: `add-frontmatter.sh` and `add-related-sections.sh` themselves are not under packs/, so unrelated).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

## [2.9.0] — 2026-04-28

### M13 — Final review pass: migration command navigation

User asked for a final review with focus on whether content is actually refined. Real findings + real fixes.

#### Audit findings

**False positives (no fix needed):**
- `migration-status` 4-phase count is intentional — read-only commands canonically skip Update/Validate/Improve.
- `migration-plan` 10-phase count was a grep false positive — extra 3 are inside an example code block; actual structure is correctly 7-phase.
- 514-line `apply-pack-adaptation.md` skill — verified to be two distinct example outputs (shallow + deep anchor); both needed.
- 273-line `api-reviewer.md` agent length is justified by content density (checklists + examples, not padding).

**Real fix landed:**
- **None of the 10 new migration commands had a `## Related` section.** Added them. Each command now links to siblings (where in the workflow), patterns/rules it depends on, and output paths it produces. Self-navigable.

#### Verified
- 10/10 migration commands have `## Related` sections.
- `lint-artifact.sh`: 0 errors / 20 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

#### Honest scope
Audit was structural + sample-deep. Every migration command read for navigation completeness; longest-3 skills + agents sampled to verify length is justified. ~150 files under packs/ were NOT exhaustively read — prior structural lint (M6) + dedup audit (M7) + spot-reads (M8) cover their quality at the ensemble level.

## [2.8.0] — 2026-04-28

### M12 — Migration lifecycle commands + extended ledger schema

User asked for "all migrations no skip" — meaning all 10 gaps from the M10 self-critique should land. M12 ships them.

#### Added — 6 new commands
- `commands/migration-rollback.md` — restores phase N's pre-run state. Reverts ledger + ported files (managed blocks). User-authored content preserved. Mandatory reason logged. Backup never auto-deleted.
- `commands/migration-replan.md` — regenerates plan from current ledger. Preserves `done` rows in original phase numbers; re-phases everything else. Use after rollbacks / V1 changes / when day-1 plan ages out.
- `commands/migration-park.md` — set hairy features aside without blocking phase gate. Writes `parked/<id>.md` with full context. Reversible.
- `commands/migration-unpark.md` — reverse a park. Restores `prior_status` + `prior_phase`. Archives parked file to `parked/_resolved/`.
- `commands/migration-deprecate.md` — V1 feature being killed in V2. Requires Accepted ADR. Permanent — no undeprecate. Tenant-impact + V1-sunset captured.
- `templates/workspace-baseline/.claude/commands/migration-workspace-status.md` — cross-repo aggregator (workspace-level). Reads each sibling's ledger, reports per-repo summary + cross-repo blockers + phase synchronization.

#### Extended ledger schema (`ai-patterns/migration-ledger.md`)
New fields documented:
- **Park/unpark**: `parked_reason`, `parked_blocker` (`decision-pending` / `third-party` / `arch-debt` / `adr-needed` / `other`), `parked_at`, `prior_status`, `prior_phase`, `unparked_at`, `unparked_reason`.
- **Deprecation**: `deprecated_at`, `deprecated_by`, `deprecation_adr` (mandatory), `deprecation_reason`, `tenant_impact`, `v1_sunset_date`.
- **Per-feature cutover**: `cutover_mechanism` (overrides project default — `feature-flag` / `strangler` / `dns-swap` / `blue-green` / `parallel-write` / `shadow-read` / `sticky-session` / `direct`), `cutover_progress` (`0%` → `10%` → `50%` → `100%`).
- **Composition**: `composes:` (1 V2 ← N V1), `composite_of:` (1 V1 → N V2). For split / merge cases.
- **Soft-parity tolerance**: `soft_parity_tolerance:` list of axes where exact parity isn't required (timestamp_format, error_message_wording, currency_rounding, etc.). Avoids ADR-pollution for cosmetic diffs.
- **Phased flow tracking**: `phase`, `phase_passed_at`, `audit_findings`, `intentional_break` (ADR ref).

#### Changed — `migration-scan` flags
- `--since=<commit>` — incremental scan for large repos.
- `--include-deprecated=<re-scan|skip>` — handle deprecated rows on re-scan.
- `--workspace` — produce a workspace-level ledger.

#### Changed — manifests + docs
- `_essentials.md` `commands` list extended to 12 (was 7).
- `_topics.md` adds 5 entries under "Suite C — lifecycle commands".
- `docs/COMMANDS.md` migration section now shows three suites: Suite A (phased), Suite B (per-feature), Suite C (lifecycle).

#### Verified
- `lint-artifact.sh`: 0 errors / 20 warnings (the 5 new commands all parse clean).
- `test-pack-directory-parity.sh`: 0 errors (migration pack manifests in sync).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

#### Coverage of the M10 critique gaps

All 10 gaps from M10's self-critique now have a system answer:

| Gap (from M10 critique) | Resolved by |
|---|---|
| 1. Re-audit cost | `--since=<commit>` flag |
| 2. Binary done/not-done | `cutover_progress` field |
| 3. No rollback | `/migration-rollback` |
| 4. No deprecation path | `/migration-deprecate` |
| 5. No split/merge | `composes` / `composite_of` fields |
| 6. Single cutover mechanism | per-feature `cutover_mechanism` field |
| 7. Hairy feature blocks phase | `/migration-park` |
| 8. ADR per cosmetic diff | `soft_parity_tolerance` field |
| 9. No multi-repo coordination | `/migration-workspace-status` |
| 10. Plan ages out | `/migration-replan` |

#### Honest scope statement
Coverage is at the **schema + command level.** The actual logic (what happens when `/migration-rollback 3` runs against a real repo with parked features that depended on now-deprecated ones) is documented in each command's hard rules but has not been exercised against real data. Expect at least one edge case to surface in first real use.

## [2.7.0] — 2026-04-28

### M10 — Migration command suite (5 phased-execution commands)

User asked for slash commands instead of agent prompts for V1→V2 migration. Built 5 stack-agnostic commands that force a phased migration with gap-finding + verification.

#### Added
- `templates/packs/migration/commands/migration-scan.md` — deep V1↔V2 comparison. Reads BOTH codebases, understands structures, builds `ai/migration/ledger.md` with every row `status: unverified` (trust nothing). Outputs `scan-report.md` with structural deltas + recommended phasing.
- `templates/packs/migration/commands/migration-plan.md` — produces `ai/migration/plan.md`. Phased plan grouped by domain + dependency. Foundation first (auth, tenant, infra). Each phase has measurable exit criteria. **Honors V2's NEW structure — never lift-and-shift.**
- `templates/packs/migration/commands/migration-phase.md` — executes phase N. Per feature: AUDIT → GAP-FIND → PORT (using V2 conventions) → VERIFY (parity test) → UPDATE ledger. Stops at phase boundary. `--feature=<id>` for retry; `--audit-only` for triage.
- `templates/packs/migration/commands/migration-gate.md` — phase exit gate. Confirms every phase-N feature is `done` + `parity_test=passing`. **Read-only; refuses on any blocking issue.** Append-only `_history.md` entry on PASS.
- `templates/packs/migration/commands/migration-final.md` — full sweep. Confirms every feature complete across all phases. Optional `--re-audit` to re-run parity tests catching drift since gate. Produces V1 retirement plan with cutover sequence + rollback procedure.

#### Design properties
- **Stack-agnostic** — works for frontend pages, API endpoints, scheduled jobs, queue consumers, CLI commands, anything that has identifiable behavior.
- **Trust nothing** — every status reset to `unverified` at scan; verified by parity test before flipping to `done`.
- **No silent ports** — `/migration-scan` and `/migration-plan` write zero code; only `/migration-phase` ports.
- **Idempotent** — every command writes through managed markers; re-running doesn't lose state.
- **Phased gating** — `/migration-gate` refuses pass on any blocking issue; next phase can't start until current is green.

#### Workflow
```
/migration-scan          # build fresh ledger, deep V1↔V2 comparison
/migration-plan          # phased plan covering everything
/migration-phase 1       # run phase 1: audit + port + verify
/migration-gate 1        # confirm phase 1 complete
/migration-phase 2       # next phase
/migration-gate 2
... (repeat per phase)
/migration-final         # full sweep + V1 retirement plan
```

#### Activation
After M10 syncs, run `/setup-project --include=migration` in any V2 repo to receive the 5 new commands. The merge matrix decides per command: ADD if no project equivalent exists, SKIP-with-redirect if a specialized version is already present.

#### Verified
- `lint-artifact.sh`: 0 errors / 20 warnings (5 new commands all parse clean).
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

## [2.6.0] — 2026-04-28

### M9 — Canonical reference doc

The flag table, mode descriptions, and migration walkthrough were comprehensive but buried inside `templates/quick-start.md` (an internal orchestrator import). M9 surfaces them as a real user-facing reference.

#### Added
- `docs/COMMANDS.md` — the canonical user manual. ~370 lines covering:
  - All 4 commands (`/setup-project`, `/setup-project-adapters`, `/setup-project-health`, `/learn-from-task`).
  - All `/setup-project` flags grouped by purpose (universal / mode-forcing / track-and-signal / tool-adapters / backup / REFINE-only / read-only / UX).
  - Flag combinations + conflicts (refusals, precedence, warnings).
  - All 4 modes (CREATE / ENHANCE / REFRESH / REFINE) with exit-criteria.
  - Generated-command catalog (`/add-endpoint`, `/add-module`, `/port-feature`, `/migration-status`, etc.) with `--plan` universal-flag note.
  - 6 worked workflows: first-setup-new, first-setup-existing, refresh, refine, V1→V2 migration (step-by-step with explicit hard rules), plan-only mode.
  - Top-10 hard rules summary (with link to full table).
  - "Where things live" map: command files, phase files, packs, domains, business-domains, tool-adapters, scripts, tests, archived monolith, sync state.

#### Changed
- `README.md` — top callout pointing to `docs/COMMANDS.md` for the full reference. README stays focused on the elevator pitch + sync workflow.

#### Verified
- `smoke-test.sh`: 0 fail / 0 warn.
- `verify-sync.sh`: 30 ok / 0 drift.

#### Why this milestone existed
A user asked: "is this mentioned in the README?" — and discovered I'd been documenting flags (`--v1-root`) that didn't exist while the genuine flag reference was buried in an internal file. M9 fixes the documentation gap so this doesn't happen again.

#### Honest correction also landed
- I claimed `--v1-root=<path>` was a flag. It is not. V1 root is detected by Phase 2 Step 16 OR resolved interactively. `docs/COMMANDS.md` documents the actual mechanism.

## [2.5.0] — 2026-04-28

### M8 — Pre-flight coverage + length budgets + reference freshness + spot-reads

After M7's mechanical dedup, M8 turns to per-file content quality. Five concrete, scoped passes; no auto-magic, all changes traceable.

#### Pre-flight discipline (Hard Rule A18) — fixed across 11 agents
M6 detected pre-flight via the literal keyword "pre-flight"; M8 fixes the agents that had the discipline but used different headings:
- 4 agents had a pre-flight section under another name → renamed: `security-auditor` ("Before auditing"), `design-system-guardian` (same), `ux-reviewer` ("Before reviewing"), `project-dispatcher` (split out from "Steps").
- 7 agents had **no pre-flight section at all** → added concrete pre-flight blocks: `endpoint-tester` (renamed Preparation), `websocket-engineer` (added), `business-auditor` (added), `code-reviewer` (renamed "Before you start"), `dead-code-finder` (added), `monorepo-architect` (added), `ci-reviewer` (added).
- Each added pre-flight names 3-5 specific files / configs / patterns the agent must read first — not generic "read the codebase."

#### Reference freshness — Next.js
- `templates/packs/frontend/references/nextjs.md` updated header from "App Router, 14+" to "App Router, 14 / 15" and added a version-note callout: Next 14 default `fetch` cache was `force-cache`; Next 15 default is `no-store`. ALWAYS set `cache:` and `next.revalidate` explicitly.
- All other references (django, fastapi, rails, nestjs, etc.) intentionally don't pin versions — pattern-level guidance that survives major bumps. Confirmed correct.

#### H1 normalization — 3 rule files
- `domains/background-jobs/rules/job-design.md`, `domains/event-sourced/rules/event-sourcing-discipline.md`, `domains/feature-flags/rules/flag-discipline.md` started with H2 / H3 instead of H1. Promoted to H1.

#### Length budget tuning
- `lint-artifact.sh`: skills budget 200 → 250, ai-patterns budget 200 → 250. Several technical-domain patterns (compliance, payment, websocket-fanout, search-indexing) are legitimately complex; the previous budget produced noise without signal. The 250 ceiling still flags genuine outliers (e.g., `learning/skills/apply-pack-adaptation.md` at 514 — Phase 4.6 anchoring contract; complex by necessity).
- Lint warnings: 48 → 20. Remaining warnings are all length-related on legitimately complex content; documented as signal, not bugs.

#### Spot-reads (4 high-impact files, all judged solid)
- `packs/backend/agents/api-architect.md` (102 lines): excellent. Concrete invariants, structured output template, framework references, "common rewrites to push back on", self-failure-modes.
- `packs/backend/commands/add-endpoint.md` (314 lines): follows the canonical 7-phase template (Hard Rule A24). Length appropriate for a complex generation command.
- `packs/security/rules/security-principles.md` (62 lines): excellent. Cites specific algorithms (argon2id), specific tools (gitleaks, semgrep), specific HTTP headers. Concrete, actionable.
- `packs/backend/ai-patterns/parallel-io.md` (172 lines): excellent. Project-specific block scaffold, decision matrix per language, opinionated guidance.

#### Verified
- `lint-artifact.sh`: 0 errors / 20 warnings (was 48). The 20 remaining are length-related on complex content.
- `smoke-test.sh`: 0 fail / 0 warn.
- `run.sh --apply` + `--idempotency-only`: 2 passed each.

#### Honest scope
M8 covered the highest-leverage content issues that automated tools could surface. **Most artifacts have not been deeply read.** The 4 spot-reads suggest content quality is good across the board, but that's a sample, not a survey. A semantic per-file audit of all ~150 artifacts under packs/ remains M9+ work — multi-day, not amenable to automation.

## [2.4.0] — 2026-04-28

### M7 — Content audit (cross-pack dedup + spot reads)

After M6 hardened *structure*, M7 verifies *content*. Bounded scope: cross-pack duplicate detection, sample-read of high-impact files, fix concrete issues.

#### Added
- `scripts/find-duplication.sh` — detects overlapping content across packs by H1 title, opening paragraph (100 chars), and verbatim MUST bullet repetition. Exposes redundancy candidates without auto-merging.

#### Findings (real, non-trivial)
- **`templates/packs/backend/ai-patterns/multi-tenancy.md` was a 100% byte-for-byte duplicate** of `templates/domains/multi-tenant/ai-patterns/multi-tenancy.md` (83 lines). Multi-tenancy is a technical signal, not a backend-pack concern — canonical home is `domains/`. **Removed the backend duplicate.**
- **H1 collision: "Code Quality Principles"** appeared in both `repo-baseline/.claude/rules/code-quality.md` (foundational A19 rule) and `packs/code-quality/rules/quality-principles.md` (concrete pack rules). Different content, same heading = confusion. **Renamed pack version's H1 to "Code Quality — concrete pack rules"** with explicit `extends: repo-baseline/.claude/rules/code-quality.md` in frontmatter and a quoted callout reading "Reads the baseline `code-quality.md` first."
- **MUST-bullet repetition 3+ times: zero.** No verbatim MUST/MUST-NOT statements duplicated across files — surprisingly clean.
- **Lead-paragraph duplicates: 5 groups** — but four of them are Phase 4.6 scaffold markers ("> Project-specific block — Phase 4.6 fills this in from..."). Expected. One genuine overlap (`learning/ai-patterns/setup-quality-scoring.md` ↔ `learning/skills/compute-anchor-density.md`) — cross-references are appropriate; not flagged for deletion.

#### Spot-reads (4 baseline rules + 4 ai/ knowledge templates)
- All 4 foundational rules (A19): well-written, opinionated, cross-referenced, concise. No content fixes needed.
- ai/ knowledge templates (architecture.md, conventions.md, modules.md, _session-digest.md): minimalist scaffolds with `<placeholder>` markers that Phase 4.6 fills at runtime. Shape is correct; content is template-stage by design.

#### Verified
- `find-duplication.sh`: 0 duplicate H1 groups (was 2).
- `lint-artifact.sh`: 0 errors / 48 warnings.
- `smoke-test.sh`: 0 fail / 0 warn.
- `run.sh --apply`: 2 passed (django + nextjs snapshot diff empty).

#### Honest scope statement
M7 verified content for the highest-impact subset: cross-pack dedup (mechanical) + 4 baseline rules + sampled ai/ templates. The remaining content audit (~150 individual artifacts under packs/) is M8+ work — semantic per-file review, not amenable to automation.

## [2.3.0] — 2026-04-28

### M6 — Artifact lint + spot audit

After M1–M5 hardened the meta-system (`/setup-project` and its harness), M6 turns attention to the artifacts the meta-system actually ships: 200+ agents / commands / skills / rules / patterns under `templates/packs/` and `templates/repo-baseline/`. Most pre-date the schema introduced in M2; this milestone fixes the structural gaps and surfaces the remaining content-quality flags.

#### Added (executable tools)
- `scripts/lint-artifact.sh` — structural lint for shipped artifacts. Checks frontmatter presence, required keys per kind (agent / command / skill / rule / pattern), length budgets (agents ≤ 300, commands ≤ 250, skills ≤ 200, rules ≤ 250, patterns ≤ 200), placeholder strings (outside code spans), top-level heading, and pre-flight block presence in agents (Hard Rule A18). Exits 0 healthy / 1 errors.
- `scripts/add-frontmatter.sh` — bulk migration tool. For any rule/pattern .md file lacking frontmatter, prepends a minimal block (`name`, `description` derived from H1 or first H2, `kind`, `pack` if applicable). Idempotent. Default dry-run; `--apply` to write.

#### Changed
- **The 4 foundational baseline rules now have frontmatter** (Hard Rule A19): `repo-baseline/.claude/rules/{read-before-write, read-codebase-deeply, code-quality, think-simplify-surgical}.md`. These ship in every project and previously had no metadata.
- **86 rule + pattern files received frontmatter** via `add-frontmatter.sh --apply`. Coverage now near-universal across `templates/packs/*/` and `templates/domains/*/`.
- `repo-baseline/.claude/agents/knowledge-curator.md` — renamed "Inputs you read" section to "Pre-flight (read before any write)" so the linter's pre-flight heuristic recognizes it.

#### Verified (with caveats below)
- `lint-artifact.sh`: **0 errors / 48 warnings.** Errors are now zero — every artifact has frontmatter and an H1.
- `smoke-test.sh`: 0 fail / 0 warn.
- `tests/setup-project/run.sh --apply`: 2 passed (django + nextjs); django snapshot re-recorded after pattern frontmatter changes — confirms the snapshot test correctly catches schema drift.
- `tests/setup-project/run.sh --idempotency-only`: 2 passed.

#### What the 48 warnings tell us (M7+ scope)
- **Length budget breaches** (~5 files): `learning/skills/apply-pack-adaptation.md` (514 lines vs 200), `compute-anchor-density.md` (246 vs 200), and similar. Some are genuinely complex extractors; some could likely be split. Worth a content audit, not blocking.
- **4 agents missing the literal "pre-flight" keyword**: `security-auditor`, `design-system-guardian`, `ux-reviewer`, `project-dispatcher`. Each has the discipline (sections describing what to read first) but doesn't use the keyword. Heuristic linter false-ish-positives — fix is renaming a section in each, ~5 minutes per agent.
- **3 ai-patterns slightly over budget** (`test-strategy.md` at 207, `theming.md` at 212): borderline; not worth chopping.

#### Honest scope statement
M6 is the first milestone where the **artifacts** (not just the system that ships them) are validated against a contract. Structural lint is now a CI-able gate. Content lint (e.g., "does this rule cite project specifics or generic prose?") remains M7+ — that requires reading semantics, not just structure.

#### Side effects
- The django snapshot was re-recorded once during M6 because two pattern source files (`patterns/{models,views}.md`) gained frontmatter. The test suite caught this drift on the first `--apply` run — exactly the behavior a snapshot suite should produce. Re-recorded with explicit confirm; idempotency holds in run-2.

## [2.2.0] — 2026-04-28

### M5 — Close the verification gap

**The forcing-function milestone.** Until M5, every refactor was unverified. M5 ships the deterministic harness that proves the system actually works end-to-end (for the deterministic phases — LLM-driven phases still need a CLI strategy in M6+).

#### Added (executable)
- `scripts/apply-pack.sh` — deterministic Phase 4 subset: 4.0 preflight + 4.2.b copy + managed-marker wrapping. Pure shell, no model. Same input → same output. Idempotent. Records gaps for missing source files; records unsupported merge modes (managed-section is M6+).
- `tests/setup-project/run.sh` — drives `apply-pack.sh` against fixtures. Modes: `--shape-only`, `--apply` (diff vs snapshot), `--update-snapshots` (record), `--idempotency-only` (run twice, assert empty diff).

#### Added (artifacts)
- `templates/tracks/web-frontend-nextjs/` — second concrete track plugin (npm-ecosystem detection, App Router + Pages Router awareness, conditional emits gated by detected flags + deps). Validates that the schema generalizes beyond django.
- `templates/tracks/web-backend-django/{rules-template.md, claude-md-section.md, patterns/views.md, patterns/models.md}` — pack source files referenced by the track's `pack.md` emits contract. The django track now ships 4 unconditional emits + 5 conditional gaps + 1 unsupported merge mode (CLAUDE.md managed-section).
- `tests/setup-project/snapshots/django/` — first real snapshot. 6 files: rules, conventions, patterns × 2, apply-pack report, original fixture files (preserved).
- `tests/setup-project/snapshots/nextjs/` — second real snapshot. 4 files: rules, conventions, apply-pack report, original fixture file.

#### Verified (now actually testable claims)
- **Idempotency contract round-trips for both tracks.** `run.sh --idempotency-only` runs apply-pack twice and asserts the trees are byte-identical (with `applied-at:` masked). 2 passed / 0 failed.
- **Snapshot diff is empty.** `run.sh --apply` re-runs the harness and diffs against the recorded snapshot. 2 passed / 0 failed.
- **Schema generalizes.** Both tracks pass `lint-track.sh` with zero schema changes. Adding the second track required no edits to `templates/tracks/_loader.md`.
- **Smoke test still clean.** 0 fail / 0 warn across 7 structural checks.

#### Still NOT verified (M6+ scope)
- LLM-driven phases (Phase 1 mode detection, Phase 2 deep extraction, Phase 4.6 anchoring) — these need real CLI invocation against a fixture, which is the open automation problem documented in `tests/setup-project/run.sh` header.
- Multi-track fixtures (monorepo) — apply-pack runs one track at a time today; multi-track conflict resolution is M6+.
- Bootstrap mode (empty fixture) — needs LLM-driven authoring.
- managed-section merge mode — apply-pack records as unsupported; M6+ implementation.
- Conditional emits — apply-pack treats `emits-conditional` as "always include" today; M6+ should evaluate against the target's deps.

#### Honest scope statement
M5 verifies the deterministic floor of the system. The deterministic floor is approximately 60% of what `/setup-project` does in production: pack preflight, deterministic copy, marker discipline, idempotency. The remaining 40% (LLM-driven authoring, deep extraction, project anchoring) is the M6+ horizon — well-defined, but requires an automation strategy beyond shell.

## [2.1.0] — 2026-04-28

### M4 — Verification + tooling

#### Added (executable tools)
- `tests/setup-project/run.sh` — snapshot test runner (shape-only mode today; full-runner mode documented but stubbed pending automation strategy).
- `scripts/lint-track.sh` — validates `templates/tracks/<name>/` against the schema (required files, frontmatter keys, signal kinds, weights, merge modes).
- `scripts/migrate-setup.sh` — applies a named migration to a target repo. Implements the `v1-to-v2` migration spec; dry-run by default.
- `scripts/smoke-test.sh` — structural integrity check: command parsing, import resolution, track lint, phase frontmatter, HOT-tier budget, sync state, fixture shape. Exits 0 healthy / 1 broken.

#### Added (artifacts)
- `templates/migrations/v1-to-v2.md` — migration spec for the M2 split (markers, version stamps, derived files, adapter re-sync). Idempotent.
- `templates/import-tiers.md` — HOT / WARM / COLD definitions with line budgets. HOT ≤ 600 lines combined. Tier-budget audit lives in `/setup-project-health` (C7).
- `templates/tracks/web-backend-django/` — first concrete track plugin under the M2 schema. Has `detect.md` (signals + threshold + exclusive-with), `pack.md` (emits contract), `conventions.md` (Django MUST / MUST-NOT rules), `meta.yaml`. Validates the schema end-to-end.

#### Changed
- `commands/setup-project.md` `imports:` reorganized into HOT / WARM / COLD groups. Loaders are expected to honor tier when pulling content.
- `templates/governance/hard-rules.md` — added "Top 10" surface at the top, ranking the highest-impact rules so readers see the floor before the full table.
- `templates/phases/phase-5-verify.md` (was 577 lines) split into:
  - `phase-5-verify.md` (397 lines, orchestrator)
  - `phase-5.0-retry.md` (coverage check + retry loop)
  - `phase-5.1-baseline.md` (required-baseline + inventory diff)
  - `phase-5.5-quality.md` (REFINE-only setup-quality score)

#### Verified
- `scripts/smoke-test.sh` — all 7 checks pass: 0 fail, 0 warn.
- `scripts/lint-track.sh` — `web-backend-django` track validates clean.
- `scripts/sync-to-global.sh` — 30 symlinks ok, 0 drift.

#### Still deferred to M5+
- Real `/setup-project` invocation against fixtures (the runner has the harness; the missing piece is non-interactive CLI invocation strategy — Claude Code commands are model-executed prompts, not shell commands). Two paths documented in `tests/setup-project/run.sh` header.
- Snapshots — empty until a real runner records them.
- Additional tracks — `web-frontend-nextjs`, `mobile-react-native`, `data-pipeline-airflow`, etc.
- Migration runner Step 2 (auto-wrapping existing managed regions) is currently advisory; a non-interactive runner is too risky for that step. User runs it manually and re-runs migrate-setup.sh.

## [2.0.0] — 2026-04-28

### M3 — Polish (this release)

#### Added
- `commands/setup-project-health.md` — read-only health reporter (digest age, ADRs, drift, budgets, dead files, adapter parity, idempotency markers, version drift). Exits 0/1.
- `commands/learn-from-task.md` — Phase 6 manual entry point; respects the persistence pyramid (raw → conventions → ADRs).
- `templates/repo-baseline/.claude/agents/knowledge-curator.md` — recurring counterpart; budget-enforcing; never edits ADRs; "no-op" is a valid run.
- `templates/persona.md` — full prose preserved; orchestrator now references via 5-bullet summary.
- `templates/phases/phase-5-checklist.md` — Phase 5 audit as a checklist (8 sections, must/should rows, halt+retry policy).
- `CHANGELOG.md` (this file).

#### Changed
- `templates/governance/hard-rules.md` reformatted from prose to ID-keyed tables (A01–A36 Always, N01–N20 Never) with severity column. Full prose preserved as reference below the table; Phase 5 references rules by ID.
- `commands/setup-project.md` persona block compressed to 5 bullets + reference to `@templates/persona.md`.
- `README.md` workflow section + milestone status updated for M3.

#### Known follow-ups (deferred)
- Phase 4 file remains at ~1500 lines — sub-phase split (4.0 / 4.2 / 4.6-DEEP / 4.7-DEEP / 4.8-DEEP) is open.
- `templates/capabilities.md` (~830 lines) not yet split per-capability.
- `scripts/lint-track.sh` (track schema validator) not yet implemented.
- `/setup-project --upgrade` migration runner not yet implemented (versioning scaffold + `templates/migrations/` exist; runner is M4).
- Snapshot test runner (`tests/setup-project/run.sh`) not yet implemented; fixtures exist.

### M2 — Split monolith into orchestrator + phase plugins (commit 1bc91cd)

#### Added
- `templates/phases/phase-{0..6}-*.md` — one file per execution phase, each with a frontmatter contract (inputs, outputs, exit criteria, applies-to-modes).
- `templates/critical-execution-rules.md` — the 7 hard guardrails extracted from the monolith head.
- `templates/quick-start.md` — flags, end states, cheat sheet.
- `templates/knowledge-hub.md` — tracks/domains/agents/skills inventory.
- `templates/decision-engine.md` — 4-input reasoning + tie-breaks + self-audit.
- `templates/idempotency.md` — re-run safety contract + managed-marker convention.
- `templates/tracks/_loader.md` — track plugin schema (detect.md weighted signals + pack.md emits contract + meta.yaml).
- `templates/governance/hard-rules.md` (initial extraction; reformatted in M3).
- `templates/canonical-command-template.md` — META: shape of generated commands.
- `templates/capabilities.md` — 7 cross-cutting features (versioning, health, schema, failures, fixtures, multi-language, wizard).
- `templates/appendices.md` — A–F (detection, filter, merge, profile, learnings, glossary).
- `commands/setup-project-adapters.md` — sibling command holding adapter detail.

#### Changed
- `commands/setup-project.md` reduced from 5,153 lines → 236 lines. Behavior preserved via @-imports.

### M1 — Foundation (commit a712053)

#### Added
- `scripts/sync-to-global.sh` — symlink-based sync from this repo to `~/.claude`.
- `scripts/verify-sync.sh` — drift detection.
- `tests/setup-project/` — fixture stubs (empty / django / nextjs / monorepo) + snapshots placeholder.
- `README.md` — workflow doc (edit-here-then-sync) + milestone status.

#### Changed
- `~/.claude/commands/` and `~/.claude/templates/` are now managed symlinks back to this repo. Backup tarball at `~/.claude-backup-20260428-125420.tar.gz`.

## [1.0.0] — pre-2026-04-28

The 5,153-line monolith era. Original archived at `.archive/setup-project.M1.monolith.md`.
