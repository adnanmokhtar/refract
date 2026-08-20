# code-quality pack — changelog

Release history for `templates/packs/code-quality/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.7.0 — 2026-07-10

- refactorer: two non-negotiable invariants — measurable-improvement / no churn-for-churn, and
  behavior-preservation PROVEN on the touched surface (green characterization/tests).
- simplify: mechanical halt deepened into a production-grade gate carrying both arms in the
  four-verb vocabulary.

## 1.6.1 — 2026-07-10

- engineering-principles: dropped the dangling scripts/audit-shared-utils.sh TODO (the script never
  existed); shared/utils-growth-needs-ADR is now honestly enforced by the reviewer-rejection gate,
  stated as review-not-script.

## 1.6.0 — 2026-07-10

- skills +1: debt-ledger (persisted ranked tech-debt ledger — dated TODOs, unjustified suppressions,
  deprecated-API use, version-lag — diffed run-over-run; the longitudinal tracker check-health
  cites).

## 1.5.1 — 2026-06-26

- refactorer agent: added a reciprocal boundary route — an algorithmic change (swapping the
  algorithm/data structure for a different complexity class) is not
  behavior-AND-complexity-preserving, so it routes to the new algorithms pack (`/analyze-complexity`
  / `/design-algorithm`), alongside the existing `/optimize` route. Makes the algorithms pack's
  claimed hand-off real (rendered-not-asserted).

## 1.5.0 — 2026-06-16

- review-changes: NEW dependency-manifest category + reviewer — a diff that ADDS a package
  (package.json / lockfiles / go.mod / requirements.txt / Cargo / pom / gradle / Podfile) triggers a
  dependency review (maintenance / license / size / CVE / already-present-primitive); version bumps
  ignored. Closes the suite-wide dependency gate at the final PR gate.
- review-changes: NEW universal secret-scan — runs on EVERY changed file, not just auth-category
  (security-auditor previously only fired on auth files); a committed credential is a BLOCK
  regardless of file category. Inline fallback (entropy + known key prefixes) when the skill isn't
  installed.
- review-changes: NEW universal coverage-gap check — added business logic with no covering test is
  flagged even when no test file was touched (test-reviewer otherwise never dispatches); blocker on
  security / data-integrity / write-path changes.
- review-changes: NEW missing-agent inline fallback (parity with add-feature / fix-bug) — an
  uninstalled reviewer is performed inline against its checklist (inline:<reviewer-name>), never
  silently skipped. Added matching invariants + rules.
- _examples/review-changes.md synced on the four new dimensions (pre-existing drift — missing '##
  The Premise' section + change-brief universal reviewer — left as-is; flagged for a separate
  regeneration).

## 1.4.2 — 2026-06-14

- architectural-diagnosis + refactoring-sweep skills: added the `name:` frontmatter field (was
  missing; the 3 migration skills already had it) — makes Cursor/Codex SKILL.md translation
  mechanical instead of LLM-authored.
- architectural-diagnosis: fixed dangling reference to a non-existent 'step 4.7' in the
  migration-discipline cross-ref — now points at the detector pass (Procedure step 4).

## 1.4.1 — 2026-06-13

- refactorer agent: removed 3 verbs from the 'Safe refactors' table that fell outside
  refactoring-sweep's closed 10 AND tripped the agent's own new-symbol auto-halt — value-object
  introduction, conditional→polymorphism, reduce-fan-out; these now route to /optimize.
- refactoring-sweep skill: now names /refactor as its core apply-engine consumer (the 10 verbs ARE
  /refactor's closed vocabulary) — fixes the one-directional wiring where /refactor dispatched the
  skill but the skill never named it.

## 1.4.0 — 2026-06-06

- Adds change-brief skill — the comprehension gate. 'If you can't explain the code, it isn't yours'
  was advisory in engineering-principles § AI-assisted development; now mechanical: every
  non-trivial change carries a 5-field brief (What / Why this shape / Edge cases / Blast radius /
  Verified by) in the commit/PR body, generated (mode A) + validated (mode B: presence, hand-wave
  grep, citation check, echo check, verification check) by the skill.
- Wired into /pre-commit (new 'Comprehension gate' step in Phase 6 — missing/failing brief is a
  blocker) and /review-changes (universal dispatch alongside code-reviewer).
- Trigger tiers scale the gate with risk (>20-line diff, new dependency/public symbol/abstraction,
  I/O-auth-payments touch, error-path/default/permission-gate change); typo fixes, mechanical
  renames, formatting, lockfile-only changes are exempt — no manufactured ceremony.
- engineering-principles.md § AI-assisted development gains the operationalizing bullet;
  _essentials.md + _topics.md updated in the same change.

## 1.3.0 — 2026-05-30

- Adds test-shield (pre-sweep coverage gate) + smoke-verify (post-sweep stack-agnostic boot-check)
  skills, wired into /optimize (Phase 0.5 + final) and /audit (steps 5 + 7). Closes audit #9/#11:
  'tests stay green' only proves preservation when a test covers the touched branch, and a green
  suite doesn't prove the app boots.

## 1.2.0 — 2026-05-03

- Sync-chain repair: _essentials.md now lists engineering-principles alongside quality-principles.
  The rule was orphaned in _essentials despite being shipped as a peer governance rule.

## 1.1.0 — 2026-05-03

- Adds architectural-diagnosis + refactoring-sweep skills (back the new /optimize Phase 0 +
  refactoring class).

## 1.0.0 — 2026-04-26

- Initial code-quality pack release.
