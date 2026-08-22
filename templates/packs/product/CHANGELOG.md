# product pack — changelog

Release history for `templates/packs/product/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record.

## 1.1.0 — 2026-08-23

**The best-written pack in the batch, and four fifths of it never reached a project.**

- **FALLBACK — 10 of 17 topics resolved to nothing.** `_topics.md` declared `fallback:
  stub-from-sections` on all four commands, all four skills, and two patterns; per
  `templates/phases/phase-4.2-apply.md:26` that sentinel builds a stub from the topic's `sections:`
  list, and the four skill topics carried **no `sections:` key**. Measured content survival to disk
  was **20%** — the lowest of the nine packs audited this cycle, against `algorithms` at 91%. What
  did not arrive: `launch-readiness`'s "run the query now" and its counter-metric-independence check,
  `acceptance-criteria-check`'s four tests, `evidence-trace`'s evidence classes and MISLINKED
  distinction, `assumption-ledger`'s nine categories and cheapest-test ladder, and every command's
  closure gate. All ten now declare their own source as the fallback, as `algorithms`, `mobile`,
  `align` and `learning` already do; survival is 100% and abridgement drift becomes structurally
  impossible. The same defect was repaired by hand in `security` and `infrastructure`; no gate
  catches it.
- **The two reviewers halted on a question the repository answers.** `@requirements-reviewer` and
  `acceptance-criteria-check` both listed *"existing behaviour undocumented for a change to an
  existing surface"* as a halt — refusing to issue a verdict — while running inside a coding CLI with
  the codebase open. The effect was a reviewer sitting beside the answer and returning "existing
  behaviour unstated", which the author then pastes back. Both now **establish the current behaviour
  from the code at `<file:line>` before the first criterion is assessed**, and five of the seven
  review dimensions stop being guesswork: a delta-phrased criterion ("faster than today") acquires a
  bound the moment today's value is measurable; the coverage grid's **migration**, **permission** and
  **error** cells become enumerable from the code that already handles them, so the finding is "the
  spec omits the 409 this endpoint already returns" rather than "errors seem underspecified";
  non-functional volumes come from the schema and the pagination defaults; and a mechanism named in a
  requirement may simply be describing what exists, which only the code distinguishes from smuggling.
  The coverage grid gained a *Today's behaviour (file:line)* column so an unspecified cell the code
  already handles ranks below one nothing handles. Two limits are stated explicitly: the code
  establishes what **is**, never what should be — a requirement is not wrong for disagreeing with it —
  and the spec's silence stays a REQUEST rather than being silently repaired, because the next reader
  will not have done this reading either. The halt now fires only when the surface cannot be
  **located**, i.e. when the requirement has no referent at all. Mirrored into
  `_examples/requirements-reviewer.md`, which is what greenfield receives.
- **DISPATCH — `launch-readiness` was reachable only from a `## Related` bullet.** The pack's
  strongest artifact, and the one gate the neighbouring `business` pack has no equivalent for, had no
  command that initiated it. `/define-success` gained **Phase 7**: dispatch it before the change is
  enabled for real users (not at definition time — it verifies events are *arriving*, which they may
  not be yet), record the scheduled run beside the review date so it is a calendar entry rather than
  an intention, and treat any `blocks launch: yes` instrumentation gap and this dispatch as the same
  piece of work. A gate nobody schedules runs after launch, where `NOT READY` is unactionable.
- **RULE — 1,700 → 1,520 tok (6,803 → 6,083 chars, −11%).** Deleted `## Review checklist` entirely.
  Measured, not assumed: a scripted map of all eleven checkboxes onto the Must / Must-not / Should set
  found a counterpart for every one, and unlike the finops rule none carried an obligation the body
  lacked, so nothing needed folding. `## Enforcement` is untouched — it is the most honest section in
  any rule here (*"these gates are agent-enforced — no external validator checks requirement prose,
  and none is planned"*) and honesty is not compressible. `## Should` is untouched: the smallest
  distinguishable change and the reuse-an-existing-metric-definition lines are load-bearing and appear
  nowhere else. The fallback lost the same section, so the pair stays consistent.
- **`applies-to` corrected.** The frontmatter claimed `product-track,
  every-code-writing-task-in-product`. This rule governs briefs, requirement prose and success
  definitions — not code. Now `product-track,
  every-brief-requirement-or-success-definition-written`, a deliberate deviation with precedent
  (`algorithms` uses `every-algorithm-design-or-analysis-task`, `align` uses
  `every-alignment-sweep`). A rule that mis-declares its own trigger surface invites both
  over-application and dismissal.
- **All four agent fallbacks regained a sibling boundary** (0 of 4 → 4 of 4). Greenfield previously
  installed four product agents with routing intact (check 8b gates the frontmatter `Do NOT trigger`
  clause) and no statement of who owns what between them — four overlapping reviewers with no
  arbitration. Each now opens `## Related` with a compressed `**Boundary:**` line: the strategist
  decides *whether*, the reviewer decides whether what was written is buildable, the arbiter decides
  what fits using the metric the strategist declares, and the synthesizer produces findings at the
  strength the material supports and stops there.

## 1.0.0 — 2026-08-20

- NEW pack. The business pack already covers the spec-to-shipped-feature span: `@business-analyst`
  writes specs, `/analyze-task` and `/expand-task` turn ideas into them, `@business-auditor` and
  `@workflow-integrity` audit what shipped, and `/suggest-features` proposes capabilities from a
  domain checklist. This pack deliberately does NOT duplicate any of that. It owns the span
  UPSTREAM of the spec — problem framing, evidence, requirement quality, scope classification, and
  whether a launch can be judged — plus the one downstream gate the business pack has no equivalent
  for (`launch-readiness`).
- agents (4): `requirements-reviewer` (opus — reviews prose with the severity a code reviewer
  applies to a diff: falsifiability, two-reading ambiguity, solution-in-problem, the eight-cell
  coverage grid, non-functional bounds, traceability, metric linkage), `product-strategist` (opus —
  the mechanism-free problem statement, labelled evidence, the do-nothing baseline, the metric pair,
  kill criteria with an owner), `user-research-synthesizer` (opus — fidelity over narrative: verbatim
  quotes with locators, counts with denominators, observed/said/interpreted labels, disconfirming
  material, and a refusal to upgrade an evidence class), `scope-arbiter` (sonnet — mechanical
  must/should/could/won't classification, one row per item, `must` requiring a stated consequence of
  omission).
- commands (4): `/frame-problem`, `/audit-requirements`, `/synthesize-research`, `/define-success`.
- skills (4): `acceptance-criteria-check`, `evidence-trace`, `assumption-ledger`, `launch-readiness`.
- rules (1): `product-principles`.
- ai-patterns (4): `problem-framing`, `acceptance-criteria`, `research-synthesis`,
  `opportunity-sizing`.
- The pack's central discipline is the label rule, mirroring the finops pack's three-label rule for
  cost: every claim about users is cited, or labelled an assumption, and nothing is ever invented —
  no fabricated quotes, personas, participants, or numbers. "No direct evidence; assumption ranked 1"
  is treated as a better brief than a confident one, because it names what to go and find out.
- Boundaries stated in every artifact: `business` owns the spec and the shipped-feature audit;
  `ui-ux` `@ux-reviewer` owns flow and content review, which is heuristic evaluation and not
  research; `/roadmap` (orchestration) maps intended-but-unbuilt capability from code while this
  pack decides what *should* be intended; `observability` `/add-telemetry` implements the
  instrumentation `/define-success` specifies; `devops` owns deploy mechanics while
  `launch-readiness` owns only whether the launch can be learned from.
