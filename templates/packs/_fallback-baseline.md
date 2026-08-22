# `_examples/` fallback-integrity baseline

`templates/packs/<pack>/_examples/<name>.md` is not documentation. It is the **AUTHOR-mode
fallback**: `templates/phases/phase-4.2-apply.md § 4.2-AUTHOR step 2` ("If extraction has NO
signal … copy it as fallback") copies it **verbatim** into a project's `.claude/` whenever
extraction has no signal for that topic — the default for greenfield, for `--lightweight`, and
for every `[EXTRACTION-WEAK]` track that `phase-4.0-preflight.md § Minimum artifacts per
LOAD-BEARING track` routes to COPY. The **No-thinning rule** in `phase-4.2-apply.md § Rules`
("pack files are copied verbatim") means whatever is in the fallback IS the artifact the project
receives.

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
**The backlog is 1 line.** If a comment anywhere in the repo advertises a bigger one, that comment
is stale — this file is the authority, and it is short on purpose.

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
  `FRONTMATTER-LOSS` · `NOT-AN-ARTIFACT` · `SECTION-LOSS` · `SECTION-ORDER` · `SIGNAL-LOSS`
  (see the check-8b header comment in `scripts/validate-pack-consistency.sh` for what each one
  means and what it measured).

## Backlog

```
documentation/slo                        SECTION-ORDER         # NOT drift: the fallback's heading order is identical to the source's. The rule compares source H2s against fallback H2s+H3s, so the fallback's `### SLI - what you measure` collides with the source's `## SLI` (inside its documentation template) while the source's own identical H3 is not counted. Diffing the SOURCE against ITSELF reproduces this finding verbatim - verified 2026-08-21. Correct as-is.
```

## Promoted OUT of this list

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
  baselined defect sits at parity (`documentation/slo` 101%; `migration/migration-discipline` was the
  other, at 112%, and was retired 2026-08-23 when that topic switched to source-as-fallback).
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
