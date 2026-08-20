---
description: Audit a spec, ticket, or set of acceptance criteria for the defects that survive into code — unfalsifiable criteria, ambiguity with two readings, solution smuggled into the problem, missing edge/error/empty/reversal states, absent non-functional bounds, and requirements with no traceable evidence.
kind: command
pack: product
---

# /audit-requirements [<spec | ticket | path>]

Review prose with the severity a code reviewer applies to a diff. A defect here is multiplied by every hour spent implementing it, and it is almost always cheaper to find than the bug it becomes.

## When to use / NOT to use

- USE: before a spec is estimated or built; when "done" was disputed after delivery; when a ticket keeps bouncing back; when acceptance criteria contain "fast", "intuitive", or "properly"; when inheriting a backlog.
- NOT: to write the spec — that is `/analyze-task` and `@business-analyst` in the business pack.
- NOT: to audit a SHIPPED feature's business completeness — that is `/audit-business`.
- NOT: to decide whether the thing is worth building — that is `/frame-problem`.
- NOT: to review UX flow and content — that is `@ux-reviewer` in the ui-ux pack.

## Phases applied

1-3 + 6 (audit shape — no Generate, no Update; the output is findings plus separately-marked proposals).

## The Premise (read this first, internalize, do not deviate)

**Every finding quotes the exact sentence.** A finding that paraphrases cannot be acted on, because the author will not recognise the sentence they wrote.

**Falsifiability is mechanical.** For each criterion, name the observation that would prove it FAILED. If no observation could refute it, it is not a criterion. This is a test, not a judgment, and it produces the same answer for every reviewer.

**Ambiguity requires two readings.** Flag a sentence only when you can write two plausible readings that lead to different implementations. A reviewer who flags everything is ignored, and being ignored is the failure mode that matters here.

**Do not rewrite in place.** Report the defect; propose the replacement in a separate, clearly marked section. Silently improving prose hides how bad the original was from the person who writes the next one.

## Mechanical halt — hand-wave grep

Canonical procedure: [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Below adds the requirement-specific tokens, applied to the SPEC UNDER REVIEW rather than to the findings.

Scan the spec for: `fast`, `quickly`, `performant`, `responsive`, `intuitive`, `easy`, `user-friendly`, `seamless`, `robust`, `gracefully`, `properly`, `correctly`, `appropriately`, `as expected`, `should be able to`, `etc.`, `and so on`, `where applicable`, `if needed`, `reasonable`, `sensible`. Each match is a candidate finding, not an automatic one — check whether the surrounding text bounds it. An unbounded match is a falsifiability finding and goes in the criteria ledger with its refuting observation named as MISSING.

Also scan the findings themselves for hand-waves before emitting: an ambiguity finding without both readings, or a falsifiability finding without the missing observation named, is HALTed and re-written or dropped.

## Phase 1 — Understand

Confirm:
- **Scope** — which spec, ticket, or criteria set, and which surrounding documents count as "stated elsewhere".
- **The brief** — the success metric and counter-metric this spec serves. Without them, the traceability and metric-linkage dimensions cannot be assessed; say so rather than skipping them silently.
- **Existing behaviour** for any change to an existing surface. A requirement that says "change X" without stating X's current behaviour cannot be reviewed for completeness or migration impact.
- **Stage** — is this pre-estimate, pre-build, or post-dispute? Post-dispute audits should identify which defect caused the dispute, by name.

## Phase 2 — Organize

Seven dimensions, applied to every requirement:

1. **Falsifiability** — per criterion, the refuting observation.
2. **Ambiguity** — per flagged sentence, both readings.
3. **Solution-in-problem** — mechanisms named where an outcome belongs.
4. **Coverage grid** — empty, partial, error, boundary, concurrent, permission, migration, reversal. Each cell is specified, explicitly out of scope, or a finding.
5. **Non-functional bounds** — expected volume, maximum volume, latency with a percentile and a measurement point, behaviour above the maximum.
6. **Traceability** — evidence-backed, labelled assumption, or UNSOURCED.
7. **Metric linkage** — the success metric this moves and the counter-metric that would reveal damage.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/acceptance-criteria.md`, `ai/patterns/problem-framing.md`.
- `.claude/rules/product-principles.md`.
- `ai/business-domain.md` — a requirement inventing a term the domain does not use is a finding.
- `ai/product/briefs/<slug>.md` — the brief this spec descends from.
- `ai/product/research/` — the findings requirements should trace to.
- The spec for the surrounding feature, so "unstated" can be distinguished from "stated elsewhere".

## Phase 6 — Validate

Dispatch, in order:

- **`acceptance-criteria-check`** — the mechanical per-criterion pass. Its output is the criteria ledger; no other source is accepted for the falsifiability column.
- **`evidence-trace`** — populates the traceability column and names the UNSOURCED set.
- **`@requirements-reviewer`** — issues the verdict across all seven dimensions.
- **`assumption-ledger`** — converts the UNSOURCED set into ranked, testable assumptions, so the output is actionable rather than accusatory.

### Criteria ledger — REQUIRED OUTPUT ARTIFACT (every criterion appears; no sampling)

```
#    | Criterion (quoted verbatim)                  | Falsifiable | Refuting observation        | Verdict
AC-1 | "the export completes for large accounts"    | no          | MISSING — no bound on       | BLOCKER
                                                                    "large" or on completion time
AC-2 | "a revoked share removes access within 60s"  | yes         | access still granted at 61s | PASS
```

## Output format

```
## /audit-requirements — <spec> — <date>

Brief: <path>   Success metric: <named | ABSENT>   Counter-metric: <named | ABSENT>

Criteria ledger: <the table above, verbatim>
Criteria: <n> total · falsifiable <n> · unfalsifiable <n>

Coverage grid:
| State | Specified | Out of scope (stated) | Finding |
| empty · partial · error · boundary · concurrent · permission · migration · reversal |

Non-functional bounds: volume <y/n> · max volume <y/n> · latency + percentile + point <y/n> ·
                       above-max behaviour <y/n>

Traceability: evidence-backed <n> · labelled assumption <n> · UNSOURCED <n> (each named)

Findings:
BLOCKERS (N) — unfalsifiable primary criteria · destructive action with no reversal and no
               stated exclusion · missing counter-metric · unstated actor
REQUESTS (N) — ambiguity (both readings given) · solution-in-problem · missing coverage cells ·
               absent bounds · unsourced requirements
NITS (N)     — vocabulary drift, minor unlabelled assumptions

Each finding quotes the sentence at <path:line or field> and, for ambiguity, gives both readings.

Proposed replacements (SEPARATE SECTION — proposals, not edits):
| # | Original (quoted) | Proposed | Why |

Spec hand-wave grep: <n> matches, <n> became findings
Findings hand-wave grep: ✓ | halts=<N>

Verdict: APPROVE | REQUEST_CHANGES | BLOCK
```

Write the report to `ai/audits/requirements-<slug>-<date>.md`.

## Hard rules

- **Every criterion appears in the ledger.** An omitted criterion has been silently approved.
- **Every ambiguity finding gives both readings.** Without them it is an opinion.
- **Every falsifiability finding names the missing refuting observation.**
- **Never rewrite in place.** Proposals go in their own section.
- **A destructive or irreversible action with no reversal criterion and no stated exclusion is a BLOCKER.**
- **A change to a behavioural surface with no counter-metric is a BLOCKER.**
- **UNSOURCED is a finding, not an accusation** — it becomes a ranked assumption with a test.

## Failure modes

- Auditing the acceptance criteria and not the problem statement above them, so a well-specified wrong thing passes.
- Flagging every soft adjective, including the bounded ones, and being tuned out.
- Rewriting the spec during the audit, so the author never sees the defect rate.
- Missing the reversal row because the forward path was thorough.
- Treating "stated elsewhere" as unstated because the surrounding documents were not read.
- Auditing after estimation, when the numbers have already anchored the scope.

## Related

- `@requirements-reviewer` — the agent this command dispatches.
- `acceptance-criteria-check`, `evidence-trace`, `assumption-ledger` — the executors.
- `/frame-problem` — supplies the brief and the metric pair this audit checks against.
- `/define-success` — closes a missing-counter-metric BLOCKER.
- `/analyze-task`, `/expand-task` (business pack) — write the spec this audits.
- `ai/patterns/acceptance-criteria.md`.
