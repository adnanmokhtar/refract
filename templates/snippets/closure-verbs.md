---
purpose: Canonical closure-verb vocabulary for scanner artifacts (skills, ai-patterns, auditor agents). Every emitted finding carries exactly one. Link here instead of redefining them per file.
---

# Closure verbs — the vocabulary every finding closes with

A scanner that emits findings without saying **what the reader is supposed to do with each one** has produced a list, not a report. The verb is the difference between "here is a thing I noticed" and "here is a thing, and here is its disposition."

**Exactly one verb per finding.** Two verbs on one finding means the artifact has not decided; no verb means the reader has to.

| Verb | Emit it when | What it obliges the emitter to carry |
|---|---|---|
| `report-with-fix` | The pattern matched **and** this artifact owns the fix. | `<file:line>` + the matched pattern + the concrete replacement, expressed in the **project's own primitive** — not a generic one. |
| `report-flagged` | The pattern matched and the finding is real, but the fix is a **decision this artifact cannot make alone** — an architectural change, a config flag with blast radius, a product/staleness tolerance, a budget nobody has set. | `<file:line>` + why it is not mechanical + **who decides** (an ADR, a named owner, a named command). A `report-flagged` with no decision-maker is a `report-with-fix` that lost its nerve. |
| `halt-handoff` | The pattern matched but the finding belongs to a **different named owner** — a sibling skill, another pattern, another pack. | The owner **by name** + the evidence transferred to it. Not "this may be a perf issue": the owner, and what it is being handed. |
| `dismiss` | The pattern matched and the **carve-out applies** — the code is deliberately this way and is correct. | The carve-out that applies + why, **recorded so the next scan does not re-open it**. This verb is how an artifact stops re-teaching an author a rule they already followed. |
| `halt-missing-cite` | A claim was drafted that cannot be anchored to a `<file:line>` (or the artifact's declared equivalent). | Nothing — the finding does not ship. This is the refusal verb, and it fires on this artifact's own output, not on the codebase. |

## The three rules that make the vocabulary worth having

1. **A closed vocabulary is closed.** Inventing a verb does not produce a richer finding — it produces a finding no downstream consumer can route. An artifact that needs a verb this list does not have has found a scope problem, not a vocabulary problem.
2. **`dismiss` is the quality signal.** An artifact with no `dismiss` cannot express a legitimate exception, so it fires on every correct-by-design case and its reader learns to skim it. If a scanner's own § False positives section names a carve-out, that carve-out needs `dismiss` or the section is unreachable.
3. **`report-flagged` is not a softer `report-with-fix`.** It is the verb for a finding whose fix costs a decision. Using it to avoid writing the fix is how a report becomes a to-do list for the reader.

## Extending it

An artifact MAY add verbs that name a *specific mechanical move* it owns (`split-route`, `move-to-effect`, `key-async-data`, `single-flight-refresh`) — those are refinements of `report-with-fix` and must be listed in that artifact's own `## Closure verbs` section. They never replace the five above; a consumer that does not know an artifact's private verb still has to be able to route its findings.

Artifacts that emit any of the five SHOULD link here rather than restating the table.
