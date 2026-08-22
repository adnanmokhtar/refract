# code-quality pack — changelog

Release history for `templates/packs/code-quality/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.8.0 — 2026-08-22

- **Audit corrections (same release).** Four boundary sections asserted repo-wide uniqueness without
  checking the repo — the batch's own "asserts a measurement it never took" failure, transposed onto
  routing claims. `/simplify` claimed its `net-lines ≤ 0` + no-new-symbol gate pair was unique;
  `/align-gate` runs both as checks 3 and 4 of its 14-check matrix, so the claim is replaced with a
  table separating the two by *what the gate is attached to*. `/review-changes` claimed "nothing else
  in the repo" returns a merge verdict on a diff — its own sibling `/pre-commit` and `database`'s
  `/migration-review` both do; it now routes by input. `/check-health` claimed to be the pack's only
  diff-free command; `/find-module` is diff-free too. Separately, `/refactor` told developers to
  extract a shared helper at **≥2** call sites while the agent it dispatches refuses that number
  outright ("Not 2 — premature abstraction is worse than duplication", `refactorer.md`); all three
  occurrences now read ≥3 and cite the agent. `docs/CHEATSHEET.md` was stale in five rows that never
  matched their sources — regenerated with `scripts/gen-cheatsheet.py`.

- **ai-patterns/ +2 (the pack had none).** `module-boundaries` and `ai-assisted-change` carry the
  placement judgement, layer detail, enforcement wiring and AI-change reasoning that
  `engineering-principles.md` was holding in every session's context. Always-loaded rule cost
  4441 → ~3628 tokens; the rules keep the invariants, the patterns carry the depth. The four
  pointers into them were written pack-relative (`ai-patterns/<x>.md`) and are now written in the
  form the installer actually produces (`ai/patterns/<x>.md`) — `phase-4.2-apply.md` copies
  `ai-patterns/` into `ai/patterns/` while rules land in `.claude/rules/`, so the pack-relative
  form resolved to `.claude/rules/ai-patterns/`, which no install has. The pointer IS the shrink
  strategy here, so a dangling one costs the whole lift.
- **All 7 agents: `## Related` replaced by a real boundary.** Each states the axis it reads (diff /
  one symbol / tree reachability / manifest / telemetry / shape gap / workspace graph) and hands
  the rest over by name. Previously every agent listed its six siblings with the text "sibling
  agent in code-quality pack", which told a reader nothing about what was NOT its job. Present in
  the `_examples/` fallbacks too — all 7 dropped the section entirely before this.
- **dependency-auditor: fabricated data removed, evidence contract added.** Deleted a CVE
  attributed to the wrong package with the wrong weakness class, a gzip size understated ~3x, and
  a worked example that listed one package as unused, as bundle-resident and as an upgrade target
  at once. Replaced with a per-dimension evidence contract, three self-consistency checks, and a
  placeholder-only output template. Scope narrowed: it consumes `deps-audit` / `@security-auditor`
  / `debt-ledger` rather than re-deriving them, and owns the cross-dimension synthesis alone.
- **code-reviewer: diagnosis before checklist.** New `## Diagnose the change` step (what does it do,
  which file carries it, is it the right shape, blast radius), design-first review order, the
  every-line obligation and cited what-was-done-well — all sourced to Google eng-practices. New
  three-state Verification block: a verdict may no longer be conditional on "tests green" unless a
  run in that session produced it; `UNVERIFIED` is the honest default for a diff-only review.
- **refactorer: the new-symbol boundary resolved.** "Auto-halt on new symbols" contradicted three
  of the ten closure verbs, which create symbols by construction. Restated as extraction (can you
  point at the lines it is made of → proceed) vs introduction (a concept the codebase lacks →
  halt), and `flatten-conditional` vs replace-with-polymorphism split explicitly. Its fallback
  regained the whole two-arm done-gate, which it had been shipping without.
- **legacy-modernizer: dead recipe deleted.** The Python 2 → 3 section recommended `2to3` and
  `futurize`; both were removed from the standard library in Python 3.13. Per-framework recipes
  replaced by the three shapes that generalise (side-by-side router / migrate-on-touch /
  dual-implementation). Trigger moved off `codebase_age_above_2y` — in 2026 that fires on almost
  every repo. "Coverage > 70% before migrating" replaced by per-branch pinning.
- **error-detective: no telemetry, no report.** Mechanical halt when no log sink or tracker can be
  queried, instead of inferring an incident from `catch` blocks. "Pareto: top 3 → 80%" and the
  fixed 50-occurrence floor replaced by cuts computed from the window under review.
- **monorepo-architect: measurements are measured.** Tool-comparison table dropped (stack-specific
  and reproducible on demand); CI-time, cache-hit-rate and speedup figures now print
  `MEASUREMENT UNAVAILABLE` rather than an estimate; `>=3 apps OR >=5 libs` and "remote cache at
  >=3 engineers" replaced by the ratios that actually decide them.
- **dead-code-finder:** the 90-day flag rule and 3-month comment rule replaced by determinants
  (can the other branch still be reached; has the block survived a release boundary untouched).
- **quality-principles:** `## Review checklist` deleted — all seven boxes restated Must/Must-not
  bullets 30 lines above them. Pagination / parameterized-queries / index-on-every-FK dropped to
  their owning packs; this file's flat "index every FK" was wrong on InnoDB, which creates it.
- **STACK.md:** `pre-commit` is a command, not a skill; the stack-conditional hook no longer points
  at `_v2-anchors.md`, a migration-pack artifact absent from a code-quality-only install.
- **find-module: the last invented weight, and the fallback that still shipped all four.** The
  rewrite that replaced the `Score: 100 / 80 / 70 / 30` block with a ranked ORDER — because "a
  fabricated weight is exactly what this command's own `cite-or-halt` verb exists to forbid" —
  stopped one line short and left `- String reference only = 30.` sitting inside the paragraph
  that retracts it. `_examples/find-module.md` was never re-cut at all, so the greenfield install,
  where the fallback IS the command, shipped the complete retracted table. Both fixed; the
  fallback also gained the `### The boundary this command owns` + anti-triggers section the source
  had grown, and its worked output stopped prescribing a NestJS/Prisma tree (`src/modules/…`,
  `prisma/migrations/…`, `.spec.ts`) to every project that installs it.
- **Four command fallbacks carried the pre-routing `description:`.** check-health, pre-commit,
  review-changes and simplify had source ≡ fallback descriptions before this release; the batch
  rewrote the source descriptions to add explicit anti-triggers for `/do` routing, edited the
  fallback bodies, and left the fallback frontmatter alone. Greenfield installs the fallback
  verbatim and routes on its `description:`, so the routing fix reached no greenfield project.
  All four now match their source.
- **simplify shipped two incompatible closed vocabularies.** The frontmatter claimed `dedupe /
  inline / remove-dead / collapse-abstraction`; the body listed `remove / inline / dedupe /
  rename-comment-out` and closed with "That's the entire vocabulary." For a command whose entire
  contract is a CLOSED verb set that is fatal — the router matches one, the executing agent obeys
  the other. The body's set wins: it is also the repo's canonical structural set
  (`align-discipline.md § Closure verb outside vocabulary`), while `remove-dead` and
  `collapse-abstraction` appear in no other file in the repo.
- **`_examples/refactor.md` deleted.** A 20-line usage anecdote with no frontmatter, pinned to a
  TypeScript path, which the `refactor` topic already disowned in favour of the
  `commands/refactor.md` overlay — while that entry's own comment asserted "no `_examples/`
  abridgement ships, deliberately, so there is nothing to drift from it." The file shipped. Any
  glob-based fallback resolution installed the anecdote over the overlay, which is the hazard
  `phase-4.2-apply.md § 4.2-AUTHOR` names by hand. frontend and mobile deleted theirs for the same
  reason; this was the third.
- **quality-principles: two numbers that were never measured, and one contradiction.** The
  Enforcement section says to set the duplication gate "from your own baseline, not a published
  number" — while the Hard rule three sections above imposed a flat 30-line function cap on every
  project regardless of what its linter is already configured to enforce. The cap now reads the
  project's configured max first and falls back to 30 only where nothing is configured, matching
  how `align-discipline.md` has always phrased it ("function > project's max-lines threshold").
  Separately, "Speculative abstractions — wait for the **second** concrete use" sat nine lines
  above "extract on the **third** occurrence, not the second (premature)"; the two bullets are now
  one and defer to the rule of three. `## Should`'s file-ordering bullet is gone — it prescribed an
  order and then said to ignore it if the codebase differs, which is the Consistency rule already.
- **engineering-principles: the fork test is not a percentage.** "Existing code covers ~90% of the
  need → refactor it; ~50% → that's a real fork" put two unmeasurable numbers where a judgement
  belongs — you cannot compute what fraction of a need existing code covers, and the Hard rule
  repeated the 50% as if it were a gate. Replaced by the test that actually decides it: fork only
  when the two cases need *different invariants*, and if you cannot name the invariant you are
  duplicating. Also merged the `shared/`-bucket ADR bullet into the module-placement bullet it
  restated, folded the third `module-boundaries` pointer into the Enforcement bullet, and dropped
  the Phase 4.6 parenthetical that the preamble already states.

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
