# `_examples/` fallback-integrity baseline

`templates/packs/<pack>/_examples/<name>.md` is not documentation. It is the **AUTHOR-mode
fallback**: `templates/phases/phase-4.2-apply.md § 4.2-AUTHOR step 2` ("If extraction has NO
signal … copy it as fallback") copies it **verbatim** into a project's `.claude/` whenever
extraction has no signal for that topic — the default for greenfield, for `--lightweight`, and
for every `[EXTRACTION-WEAK]` track that `phase-4.0-preflight.md § Minimum artifacts per
LOAD-BEARING track` routes to COPY. The **No-thinning rule** in `phase-4.2-apply.md § Rules`
("pack files are copied verbatim") means whatever is in the fallback IS the artifact the project
receives.

> **Every `of 293` / `of 297` figure below is a dated corpus measurement, not a live count.** They
> were all taken in one pass at `6dcb778`, when the corpus was **293 pairs / 297 `_examples/` files**.
> The gate checks **282 pairs** today: 2 pairs retired across batches 1-5, and 9 more on 2026-08-23
> (the whole `learning/_examples/` directory — 8 topics repointed to source-as-fallback — plus
> `ai-engineering/_examples/ai-engineering-principles.md`, whose topic already declared
> `fallback: rules/…`). The ratios these figures support (which classes discriminate, which are
> conventions) were not re-derived against the smaller corpus, so the numbers are left as recorded
> rather than restated — a renumbered figure would assert a measurement pass that never ran. Re-run
> the pass before quoting any of them as current.

Check 8b of `scripts/validate-pack-consistency.sh` compares every fallback against the source it
abridges. Fallbacks are **deliberately abridged** — 29 of 293 are under 40% of their source's
length and 135 of 297 are under 100 lines — so the gate never diffs prose and never looks at
length, with one exception that is not a judgement call (byte-equality). It flags three shapes:

1. something the fallback **asserts that its source does not** (a framed magnitude, a dispatch
   target, a `model:` value, a body that contradicts a self-declared literal copy),
2. something the source carries that the corpus itself keeps **≥85% of the time**, or a **safety
   signal** at any retention (the load-bearing section set, the section order, a `> **Hard rule:`
   line, a halt block, a `## Premise`, an agent TRIGGER clause), and
3. a fallback whose body **is** its source with nothing declaring it (`UNDECLARED-COPY`) — the one
   state neither an abridgement rule nor a copy rule can see.

**What it does not do.** Every rule compares text against text; none understands either file. A
source that deletes a Hard-rules bullet, or flips a `MUST` to a `MUST NOT`, leaves no trace in the
fallback and produces **zero findings** — the fallback goes on asserting the retracted rule and the
gate stays green. A fabricated magnitude is caught only when the line frames it as a target/limit
or its unit is inherently a claim; `200000 concurrent sockets per process` is not caught. Treat a
green run as a floor, not as a certificate that the fallback still says what its source says. The
full list is under "WHAT THIS CHECK DOES NOT CATCH" in the check-8b header comment.

Every line below is a violation someone has read and decided is correct as-is. Baselined lines are
suppressed (counted in one summary WARN, listed by `--fallback-report`); anything **not** listed
is a hard FAIL. That is the ratchet: the backlog is visible and finite, and new drift is red.
**The backlog is 0 lines.** If a comment anywhere in the repo advertises a bigger one, that
comment is stale — this file is the authority, and it is short on purpose. That sentence is no
longer on trust: check 8b parses it and **FAILs when it disagrees with the entries below**, the
same self-check `scripts/lint-handoffs.sh:661-670` runs on its own ledger. It was added because
this exact sentence, and the check's own header comment, both went stale the day the backlog
reached zero — a comment advertising a worklist that is not there sends readers looking for it.

## Working with this file

- **Repairing a file** → fix the fallback, then delete its line here. The gate WARNs on a line
  that no longer reproduces ("is fixed — drop its line"), so a stale entry cannot linger.
- **Adding a line** → only for a violation you have looked at and decided is correct as-is.
  Say why in the trailing comment — **the reason is mandatory and mechanically enforced**: a line
  with no `# reason` suppresses nothing, the finding stays red, and the gate WARNs that the line is
  inert. A line added to silence a finding you did not read is the failure mode this whole gate
  exists to prevent.
- Format: `<pack>/<example-name>  <RULE>  # note`. Rules:
  `COPY-DRIFT` · `UNDECLARED-COPY` · `UNSOURCED-MAGNITUDE` · `DANGLING-DISPATCH` ·
  `FRONTMATTER-LOSS` · `NOT-AN-ARTIFACT` · `SECTION-LOSS` · `SECTION-ORDER` · `SIGNAL-LOSS` ·
  `BOUNDARY-LOSS` · `CLOSING-SIGNAL-LOSS` · `VERDICT-DEGRADED`
  (see the check-8b header comment in `scripts/validate-pack-consistency.sh` for what each one
  means and what it measured).
- **Strategy, not content, is a different ledger.** Whether a topic's `fallback:` can deliver
  anything at all is check **3b** and `_topics-strategy-baseline.md`; this file only ever judges a
  fallback that IS a file against the source it abridges.

## Backlog

```
(empty)
```

The last entry, `documentation/slo SECTION-ORDER`, was **retired 2026-08-23** — not suppressed
harder, but made not to fire. It was a true false positive: the rule compares source H2s against
fallback H2s+H3s, so the prose section `### SLI - what you measure` collided with the `## SLI`
heading inside the file's own fenced documentation-template. Renaming that template heading to
`## SLI definition` (which is also what it holds) removed the collision, and the finding no longer
reproduces. The topic was renamed `slo` -> `slo-doc-template` in the same pass, to end a silent
`ai/patterns/slo.md` destination clobber against `observability`'s pattern of the same name.

## Promoted OUT of this list

- **Sibling-boundary loss** (`BOUNDARY-LOSS`, agents only) and **closing-verdict loss**
  (`CLOSING-SIGNAL-LOSS`, `VERDICT-DEGRADED`) were armed in the same pass, at **0 baseline lines
  between them**. Boundary cost 3 repairs (`frontend/api-contract-sentry`, `frontend/i18n-auditor`,
  `security/data-privacy-reviewer`), the closing verdict cost 1 (`backend/add-endpoint`, which
  stamped `Status: COMPLETE` where its source gates on a 7-row production floor). The closing-gate
  class earned its place from a measured incident: `ai-engineering/_examples/add-ai-feature.md`
  never gained the `## Ship gate` its source added at 7dde562, kept a `Status: COMPLETE` the source
  forbids at `commands/add-ai-feature.md:155` and `:215`, and survived 13 commits / 44 days / all of
  pack v1.3.0 — including the commit that armed this very check, which exited 0 over it and never
  named the file. It sat on the pack's only `_essentials.md` command.

  **Both were widened and re-measured on 2026-08-23, and what the widening cost is on the record.**
  `BOUNDARY-LOSS` used to require a heading or a **bold** run, so `- **Boundary:** …` matched while
  the identical `- Boundary: …` did not — a FAIL on the very compression the rule blesses, naming no
  formatting requirement. It now also accepts the keyword when it opens the line: agent findings
  stayed at 0 and no repair was needed. The closing family used to test typography, not semantics:
  ``### Verdict: `DURABLE` / `FRAGILE` / `ORPHAN-RISK` `` failed where the identical unbackticked
  line passed, and a bare `## Ship gate` with no criteria *satisfied* the rule — the cheapest-looking
  repair to the founding incident. Emphasis is now stripped before counting outcomes, and a gate
  heading needs ≥100 characters of criteria under it (the smallest real gate block in the corpus is
  139). Widening the vocabulary took qualifying sources from 66 to **80 of 282** and found one live
  instance the narrow form missed — `code-quality/_examples/simplify.md`, repaired here, not
  baselined. `VERDICT-DEGRADED` lost its source-side guard: four `_essentials`-listed greenfield
  artifacts (`backend/add-feature`, `backend/fix-bug`, `frontend/add-component`,
  `frontend/add-crud-page`) closed on a bare `Status: COMPLETE` and were silent *only* because their
  sources printed the same line. All four were repaired on both sides.

- **Boundary loss outside the agents class is COUNTED, not baselined.** The hard FAIL is scoped to
  agents because 77 of 77 agent sources carry the block. Outside it the convention is real but not
  universal (commands 36 of 44, ai-patterns 33 of 81, skills 30 of 64, rules 1 of 16), so a hard
  FAIL would legislate a convention — but "scoped" was being read as "invisible": arming the rule
  fixed 3 agent fallbacks and left **51 across 12 packs** unreported. `--fallback-report` lists
  every one, and [`_greenfield-budget.md`](_greenfield-budget.md) budgets them per pack so the
  class can only shrink. A 51-line reasoned ledger was rejected: reasons nobody reads are the
  enforcement theatre this file exists to avoid.

- **Safety-signal loss** (`> **Hard rule:` / a halt block / `## Premise` / an agent `TRIGGER`
  clause present in the source, absent from the fallback) shipped as a counted WARN because it
  stood at **227 of 292 pairs (78%)**, on the stated grounds that at 78% it "cannot separate
  abridgement from drift". The repair pass then closed all 227. That result refutes the grounds:
  the class was 100% repairable drift, so it discriminated perfectly all along. It is **now gated**
  as `SIGNAL-LOSS`, at 0 of 293. Arming it cost nothing and closes the regression path. A fallback
  that genuinely must drop a signal takes a baseline line with a reason, like anything else.

## Not in the ratchet, deliberately

- **Length ratio** — ratios span 22% (`database/full-text-search`, 33 vs 153 lines) to 137%
  (`distributed-systems/outbox`, 100 vs 73) and the correlation with drift is inverted:
  `frontend/seo-audit` is textbook-legitimate at 25% (47 vs 190), while the file still carrying a
  baselined defect sat at parity (`documentation/slo` 101%, retired 2026-08-23 when the heading
  collision that produced it was removed; `migration/migration-discipline` was the other, at 112%,
  retired the same day when that topic switched to source-as-fallback).
  Measured across all 293 pairs: no threshold discriminates. Not implemented at any severity.
  The one length-shaped rule that IS implemented is byte-equality (`UNDECLARED-COPY`), which is a
  fact rather than a threshold.
- **`kind:` value equality** (133 of 293 differ) and missing `severity:` on rule fallbacks
  (20 of 20 — the whole class) — uniform conventions, not drift. `kind:` is worth a design decision
  (4.2 copies it verbatim, so a project receives `kind: example` in `.claude/rules/`), but a
  100%-of-class property is a convention and gating it would flag the convention, not a defect.
- **Orphaned examples** (`migration/_examples/{audit-failure-modes,audit-template}.md`) — already
  WARNed by check 8a, and both have live inbound citations, so they are misfiled references rather
  than dead files. Left where they are rather than muted.
- **Blanket protection.** The closing gate / verdict rules evaluate the **80 of 282 pairs (28%)**
  whose SOURCE carries a done-condition. The other 202 sources do not close on one, so there is
  nothing for their fallbacks to drop. Read the closing family as protecting the pairs that have
  something to protect, never as a certificate over the whole directory.

## Source-as-fallback is a trade, not a pure win

A topic whose `fallback:` names the pack's own `commands/…` / `skills/…/SKILL.md` instead of an
`_examples/` file delivers the finished artifact in full — and leaves check 8b entirely, because 8b
walks `_examples/` only (`templates/phases/phase-4.2-apply.md:32`). The file is no longer compared
against anything, because it *is* the thing. That is strictly better than the empty file or the
heading skeleton it replaces, and it is the pattern this repo already uses — the pair count fell
293 → 282 for exactly this reason (9 `learning` topics, then `observability`'s four and now
`testing/tdd`) — but it should be read as moving a file out of the gate's reach, not as a repair
the gate verified.
