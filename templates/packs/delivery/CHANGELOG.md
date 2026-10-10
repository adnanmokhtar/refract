# delivery pack — changelog

Release history for `templates/packs/delivery/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 1.2.0 — 2026-10-10

**P3 has a writer, and the state matrix has a gate.**

- `/add-feature` P3: with the ui-ux pack installed, `@ux-designer` writes `ux.md` (flows, the
  `## State matrix` over `THR-UI-STATES`, interface contracts, a11y and i18n notes) and lints it with
  `state-matrix-lint.py --phase=design`; without ui-ux the architect's UI slice carries the matrix and
  P3 is recorded as covered by it. P4 lints it again before `@ux-reviewer` reviews it; P12 reads gate
  `G12 state-matrix` (shadow).
- `lane-frontend`: the Phase 2 slice carries a `## State matrix` example; WCAG and UI states are
  judged by `@ux-reviewer` at T2/T3 with `@accessibility-auditor` as the fallback when ui-ux is
  absent; the a11y check is the `a11y-scan` baseline diff (`THR-A11Y.axe_gate`, G9), not a Lighthouse
  score; audits route to `/frontend-audit` (`/a11y-audit`, `/i18n-audit` presets) and `/frontend-fix`.
- `lane-mobile`: native a11y is `@ux-reviewer` over `mobile-a11y-scan` §1–§8 — the web
  `@accessibility-auditor` row is gone, and without ui-ux the axis is `UNREVIEWED(a11y)`; Phase 6 adds
  G12 and `device-harness` § 7 process-death checks; Related names `/mobile-audit` and `/mobile-fix`.

## 1.1.0 — 2026-10-05

**P5 records the behaviour before anyone changes it** (architecture proposal §7 rule 1, Phase 5).

- `/add-feature` P5 step 3: after the acceptance tests are red and before `plan.md`, the testing
  pack's `characterize` pins every pre-existing entry point `design.md` names plus its importers, and
  `baseline-capture.sh capture --run=<id>` writes `.claude/baselines/<base-sha>/` — together with every
  registered engine entry (api-snapshot, schema-diff, visual-check, …) whose scope the design meets.
- A criterion that deliberately changes recorded behaviour declares it in `acceptance.json`
  (`changes_baseline`) before the lock; G14 fails an undeclared difference and `test-integrity.py` an
  undeclared re-recording. H2 shows the capture; P12 and the Output block read G14; G4 runs in CI.
- Building before the baseline is captured is not allowed (Hard rules).

## 1.0.0 — 2026-10-05

**A feature no longer starts with code.** Architecture proposal Phase 4 ("The Run").

- **NEW `/add-feature` — the one cross-stack orchestrator.** Before this pack the bare
  `/add-feature` went to whichever of backend, frontend or mobile was installed first, defaulted to
  the trivial tier (no requirements, no design, the builder grading its own work) and promoted the
  tier only after code existed. The orchestrator runs P0–P12 of the proposal per risk tier: the tier
  is classified by `.claude/scripts/risk-tier.py` from the ask before code and re-classified from the
  design and the diff (promote-only); every phase writes a typed artifact under `ai/runs/<run-id>/`
  (`templates/snippets/run-ledger.md`); acceptance is written, red and locked before code; one
  writer builds; read-only lenses review in one parallel fan-out; the verifier's `verdict.json` is
  the only path to COMPLETE. The tier matrix is one file: `templates/governance/tiers.json`.
- **NEW agents** `product-analyst` (merges product-strategist + user-research-synthesizer +
  business-analyst), `requirements-reviewer` (product's reviewer + business-auditor's completeness
  lens), `architect` (system-architect's method + the stack architects as optional slices),
  `architecture-reviewer` (domain-model-auditor's invariant register + design conformance),
  `test-engineer` (testing's test-engineer + tdd-orchestrator's red-first order), `plan-critic`
  (scope-arbiter, standing in for H2 at T1), `implementer` (one plan task at a time, SPEC_CONFLICT
  instead of bending a locked test). The originals stay in their packs until Phase 6 measures parity;
  delivery is applied first, so its same-name agents are the installed ones.
- **NEW lane skills** `lane-backend`, `lane-frontend`, `lane-mobile` — the stack procedure CUT from
  the three former `add-feature` bodies (premise, prior-art, sibling-shape and new-dependency gates,
  signal → binding-constraint tables, design slices, generate rules, lens tables, spec conformance),
  without their tier tables, acceptance sections and output blocks, which now live once in the
  orchestrator. The stack packs' `add-feature.md` files become thin lane presets.
