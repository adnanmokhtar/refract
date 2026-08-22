# documentation pack — changelog

Release history for `templates/packs/documentation/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.6.0 — 2026-08-23

FIXED
- **`ai-patterns/slo.md` silently CLOBBERED `observability`'s file of the same name.**
  `phase-4.2-apply.md:208` installs ai-patterns with a plain `cp -R ... ai/patterns/` (no `-n`,
  unlike the domains loop 220 lines later), so whichever track applied second destroyed the other.
  `documentation` is always-applied and `observability` detects on OTel/Datadog/Sentry/Prometheus,
  so this fired on most production services, and the two files are complementary — 1 shared heading
  out of 17 vs 8. Renamed to `slo-doc-template` (this pack owns the SLO DOCUMENT; observability owns
  the error-budget arithmetic and burn-rate alerting), with a reciprocal boundary block at the top
  of both source and fallback. Neither file had mentioned the other.
- **The last entry in `templates/packs/_fallback-baseline.md` is retired, not re-suppressed.**
  `documentation/slo SECTION-ORDER` was a true false positive: the prose `### SLI — what you
  measure` collided with the `## SLI` heading inside the file's own fenced doc-template. Renaming
  that template heading to `## SLI definition` — which is also what it holds — removed the collision.
  Backlog is now empty; fallback integrity reports 0 baselined.
- **`Authors: @adnan, @sara` shipped in the ADR template of every project the framework touches**
  (documentation is always-applied). Replaced with placeholders, in source and fallback.
- **doc-principles contradicted its own pack on the staleness threshold** — the always-loaded rule
  said 90 days where `doc-writer:93`, `doc-refresh:66` and `doc-refresh:203` all use 30. Fixed to 30
  in the rule and its fallback, and `doc-drift-scan` now states the number so there is one home.
- Dangling reference deleted: `.claude/rules/jsdoc.md` — measured 0 occurrences repo-wide outside
  the two lines citing it.
- `system-design` told the author to hand-draw an "ASCII diagram, box per service" while the same
  pack's `diagram-sync` calls a hand-drawn diagram "worse than none... it teaches a wrong mental
  model with the authority of a picture". Two shipped artifacts in direct contradiction; the pattern
  now points at diagram-sync and labels an intended-shape sketch as unverified.
- `api-documenter` cited `ai/patterns/api-contract.md`, `api-versioning.md` and the `api-snapshot`
  skill unguarded — all three ship with the BACKEND pack, and documentation installs standalone.
  Now guarded, with `Contract source: derived from code` as the honest fallback.
- Node-manifest assumptions genericised in `/doc-refresh` and `doc-drift-scan` prose (the inline
  bash stays, labelled as one worked instance) — an always-applied pack must not assume
  `package.json` exists.
- **The gate-4 upgrade below did not reach greenfield: `_examples/doc-refresh.md` still said
  "three gates".** `_examples/` is copied verbatim and IS the artifact on a greenfield /
  `--lightweight` / `[EXTRACTION-WEAK]` install, so a greenfield `/doc-refresh` could award
  PRODUCTION-GRADE without ever running the diagram or docstring axis — the exact gate this release
  adds — and its worked example printed the superseded three-field production-bar line. Fallback
  re-cut: four gates, gate 4 dispatching `diagram-sync` + `docstring-coverage`, the
  PRODUCTION-GRADE condition now requiring the non-prose gate `PASS`/`N/A`, and the mandated
  drift-log line plus its worked example carrying `· diagram <…> · docstrings <…> · verdict <…>`.
  The source was self-inconsistent in the same place and is corrected too: `:59` mandated the
  six-field line while `:228` still printed the four-field one and `:223` still said "three axes".
  check-8b reads neither file, so the pair stayed green throughout.

IMPROVED
- **doc-principles rule: 2131 -> 1725 tok (-19%), and better.** The four mega-Shoulds were 99-161
  token prose summaries of four skills that ship in full and end by naming them; they are now a
  four-row table of what each doc surface is PROVEN by. The ADR skeleton (strict subset of
  `adr-template.md`, which ships unconditionally and is in `_essentials`) and the runbook skeleton
  (subset of `/add-runbook` Phase 4) DELETED — two homes for one skeleton is how they drift.
  `## Anti-patterns` and `## Review checklist` merged into one `## In review — reject on sight`.
  References gained real URLs; the pack previously made zero external citations across 7,796 lines.
- **`doc-drift-scan` used TWO buckets for THREE conditions.** `BROKEN` held both "the doc names a
  dead thing" and "the doc is WRONG about a live symbol" — different fixes — while "code exists,
  doc missing" was filed under STALE next to a 67-day timestamp. Now three axes: **DEAD** (delete or
  repoint) / **WRONG** (correct the claim) / **UNDOCUMENTED** (write the entry), with UNDOCUMENTED
  counted separately because an absence is not a lie.
- **Nothing in the pack checked that a documented CLI flag still exists** — commands and endpoints
  were covered, flags were not, and flags are renamed far more casually than functions.
  `doc-drift-scan` step 8 resolves every documented flag against the argument parser; unpinned
  third-party flags are `UNVERIFIED (external CLI)`, never guessed.
- **`/doc-refresh` dispatched 2 of the pack's 5 skills** and did the other work inline and worse
  ("if the diagram changed at an architectural level — update"). Gate 4 (non-prose) now dispatches
  `diagram-sync` and `docstring-coverage`; `changelog-generate` is stated as deliberately out of
  scope (release-cut, not post-change) rather than silently omitted.
- **`@doc-writer` half-reimplemented `doc-drift-scan`** — six bullets, no output format, no citation
  rule, no verdict. Replaced with a dispatch plus an honest `UNVERIFIED (skill absent)` degraded
  path, and the agent gained the sibling/skill boundary its fallback had entirely lacked.
- **`@api-documenter` printed `APPROVE | REQUEST_CHANGES | BLOCK` directly above four uncomputed
  ratios with no rule connecting any ratio to the verdict.** Added the first-match-wins table, plus
  `UNVERIFIED (<axis>)` so an unmeasured axis can never underwrite an APPROVE.
- **`/add-adr`'s only terminal state was `Status: COMPLETE`** — in the pack whose flagship command
  made computing an honest verdict its entire point. Phase 6 is now six mechanical checks and the
  command can report `INCOMPLETE` on a one-way supersession link or an unwritten decision-index row.
- **`docstring-coverage` shipped `Gate: ≥ 80%`** — an unsourced threshold in a skill that otherwise
  defers to the project's linter config. Now: use the project's declared `fail-under` if it has one,
  else RATCHET from the current measurement and fail only on a decline, and print the provenance.
- **`diagram-sync` was `always: true` while hard-depending on `code-quality`'s `_dep-graph.json`** —
  install documentation without code-quality and its only possible action was to halt. Trigger is
  now gated on a committed diagram or the graph, and without the graph it does the half that needs
  none (resolve each box's path — a stale node is the highest-value finding) and labels the rest
  UNVERIFIED.
- `/add-runbook` Phase 2 renumbered the house 7-phase skeleton into its own `1. UNDERSTAND … 5.
  WRITE` pipeline — the only command in the pack that did. Now maps onto the house phases.

FIXED (integration pass, same release)
- **`_examples/doc-refresh.md` still shipped THREE gates after the source grew a fourth.** This
  release added the non-prose gate — the two doc surfaces that are not text and are therefore
  invisible to gates 1-3, dispatching `diagram-sync` against `ai/optimize/_dep-graph.json` and
  `docstring-coverage` against the exported-symbol surface — plus two required `ai/dynamic/drift-log.md`
  fields (`diagram <…>` and `docstrings <…>`). The fallback's heading still read "**The three
  gates**", and its terminal-verdict clause and required-artifact line omitted both new axes. Since
  `_examples/` is the only path on greenfield, a new project ran `/doc-refresh` with its diagram and
  its public-symbol surface unchecked while reporting `PRODUCTION-GRADE` — the precise pair the
  other three gates cannot reach. Gate 4, the verdict clause, the Phase 6 dispatch steps and the
  worked example's artifact line all re-cut.

## 1.5.0 — 2026-07-10

- doc-refresh production bar — regenerate→diff→cite: three wired gates (drift via doc-drift
  detector, examples run, links resolve); divergence from code = STALE.
- add-runbook: command-resolution gate re-derives every step's script/target/path from the repo;
  unresolved = BROKEN.

## 1.4.1 — 2026-07-10

- api-documenter: SDK-generation gains a regenerate->diff->cite gate + the quality checklist gains
  cite-or-halt (every box cites the spec/code proof) — was 1 of 4 sub-jobs verified. add-runbook:
  linked-ADR/feature path-existence check (halt on dangling link) + an undrilled runbook is honestly
  marked 'not-yet-run' instead of silently accepted.

## 1.4.0 — 2026-07-10

- skills +3: diagram-sync (C4/mermaid generated from the real dep graph + drift check),
  docstring-coverage (public-API docstring gap + gate), changelog-generate (categorized changelog
  from conventional-commit/PR history).

## 1.3.0 — 2026-07-09

- skills +1: quickstart-verify — executes the README/getting-started setup in a clean env to PROVE
  onboarding works (the smoke-verify leap for docs), distinct from doc-writer's prose authoring.
  Backing SHOULD in doc-principles.
