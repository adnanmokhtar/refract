---
description: Turn raw research material — interview notes, support tickets, session recordings, sales notes, reviews, survey free-text — into evidence-backed findings with sources, counts, evidence class, disconfirming material, and explicit limits. Never invents a quote, a participant, or a number.
kind: command
pack: product
---

# /synthesize-research [<corpus or path>]

Extract findings from material that already exists, at the strength the material actually supports. Most research is not lost because it was never gathered; it is lost because nobody extracted it, or because it was extracted one confidence level too high.

## When to use / NOT to use

- USE: raw material exists and nobody has produced findings; a claim about users needs its provenance checked; several sources are being cited for a conclusion none of them supports; before `/frame-problem`, so the brief cites findings rather than raw notes.
- NOT: when there is no raw material. Synthesis without input is fabrication — the command refuses and names what would need to be gathered.
- NOT: to decide what to build from the findings — that is `/frame-problem`.
- NOT: to evaluate an interface against usability heuristics — that is `@ux-reviewer` in the ui-ux pack, and it is not research.

## Phases applied

1-3 + 4 + 5.

## The Premise (read this first, internalize, do not deviate)

**Never invent. Not a quote, not a participant, not a percentage, not a persona.** Every quote is verbatim with a locator. Every number is a count of real items with its denominator stated. Thin material produces a thin finding — "2 of 7 participants" is real, and more useful than an inflated version, because the reader can weigh it correctly.

**Never upgrade an evidence class.** Observed behaviour supports *that*; interviews support *why*; surveys support stated interest. Conflating them is the most common research defect and the hardest to detect afterwards.

**Report disconfirming material, or state its absence explicitly.** Silence reads as absence, and a corpus of any real size with no contradictions has been filtered.

**Escalation triggers (halt and ask):**
- No raw material — name what would be needed.
- Material is somebody's summary with no underlying record — their claim can be reported as a claim, never as evidence.
- Participant provenance unknown (who, how selected, current/prospective/churned) — selection determines what the material can support.
- Consent or privacy status unclear for material containing personal data — report themes without identifiers until it is resolved.
- The conclusion was specified before the synthesis — say so.

## Phase 1 — Understand

Confirm:
- **The corpus** — what material, where, over what date range.
- **Selection** — how participants or items were chosen for each source. This is recorded first because it bounds every finding that follows.
- **Privacy handling** — what may be quoted verbatim, what must be de-identified.
- **The question**, if there is one. A synthesis with a guiding question is sharper; a synthesis with a required answer is not synthesis.

## Phase 2 — Organize

1. Inventory and characterise the material before reading for themes, so finding strength is bounded before a narrative forms.
2. Code bottom-up: tag observations at the level they occur, then group tags into themes. Never start from an expected theme list.
3. Separate observed / said / interpreted at every tag.
4. Count with denominators.
5. Hunt disconfirming material per candidate finding, deliberately.
6. State each finding's limits.

## Phase 3 — Retrieve

**ALWAYS** — see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Additionally:
- `ai/patterns/research-synthesis.md`, `ai/patterns/problem-framing.md`.
- `.claude/rules/product-principles.md`.
- `ai/users-and-personas.md` — existing personas are prior claims to be tested against this material, not templates to fill.
- Prior syntheses in `ai/product/research/` — a finding that contradicts an earlier one is itself a finding, and the product may simply have changed.

## Phase 4 — Generate

Dispatch `@user-research-synthesizer`, then assemble:

1. **Material inventory** — type, count, date range, selection, class, per source.
2. **Findings**, ranked by strength (saturation × evidence class), never by how interesting they are. Each carries: the finding, its class (observed / said / interpreted), support as `n of N`, its sources, disconfirming material, what it supports, and what it does NOT support.
3. **Saturation statement** — did new sources stop producing new themes, and at which source? If they did not, say the corpus is not saturated and more material would change the picture.
4. **Contradictions and open questions** — what the material cannot answer and what would answer it.
5. **Verbatim quotes** — each with a locator, none paraphrased, all privacy-handled.

## Phase 5 — Update

- Write `ai/product/research/<slug>.md` — the synthesis above, dated, with the material inventory intact.
- Update `ai/users-and-personas.md` only where this material supports a change, and cite the finding number that supports it. A persona edited without a citation has become fiction again.
- Append the open questions to `ai/product/assumptions.md`, so the next brief inherits them.

## Output format

```
## /synthesize-research — <corpus> — <date>

Material inventory:
| Type | Count | Date range | Selection | Class |
Total sources: <n>   Saturation: <reached at source <n> | NOT REACHED>
Privacy: <what is verbatim, what is de-identified>

Findings (ranked by strength):
| # | Finding | Class | Support (n of N) | Sources | Disconfirming | Supports | Does NOT support |

Contradictions and open questions:
| Question | Why the material cannot answer it | What would answer it | Cost |

Verbatim quotes:
| Quote | Source (locator) | Context |

Fabrication check: quotes located <n>/<n> · counts with denominators <n>/<n> ·
                   findings with a class label <n>/<n> · findings with a "does not support" line <n>/<n>

Status: <see gate below>
```

### Closure gate — COMPLETE only when every finding is traceable and bounded

- **`Status: COMPLETE`** — every quote located in the material, every count carrying a denominator, every finding labelled observed/said/interpreted with an explicit "does not support" line, disconfirming material reported or its absence stated, and saturation stated either way.
- **`Status: INCOMPLETE — unmet: <list>`** — any quote that could not be located, any percentage on an unknown denominator, any finding without a class label or a limits line. Name each.

An unlocatable quote is removed, not softened. This gate is **[self-policed]** on the Status line, and the fabrication-check counters are the evidence.

## Hard rules

- **No invented quotes, participants, numbers, or personas.**
- **Every quote verbatim with a locator.** Unlocatable means removed.
- **Every count has a denominator**, or the denominator is declared unknown and no percentage is given.
- **Every finding labels its class and states what it does not support.**
- **Disconfirming material reported, or its absence stated explicitly.**
- **Never upgrade an evidence class.**
- **Never synthesise toward a pre-specified conclusion.**

## Failure modes

- Reading for themes before inventorying, so the corpus is characterised to fit the narrative.
- A percentage on three participants.
- A persona assembled from convenient traits rather than clustered observations.
- Quotes trimmed until the qualifying clause disappears.
- Only positive or only negative material from a channel that produces both.
- Findings written in the product's vocabulary rather than the participant's — a sign interpretation ran ahead of the material.
- Material from before a significant product change, cited as current.

## Related

- `@user-research-synthesizer` — the agent this command dispatches.
- `evidence-trace` — links later requirements back to these findings.
- `assumption-ledger` — everything the material could not settle becomes a ranked assumption.
- `/frame-problem` — consumes these findings as its evidence.
- `ai/patterns/research-synthesis.md`.
- `@ux-reviewer` (ui-ux pack) — heuristic review, not research; the two must not be cited interchangeably.
