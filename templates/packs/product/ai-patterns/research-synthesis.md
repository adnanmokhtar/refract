---
name: research-synthesis
description: 'Pattern: Research Synthesis (inventory before themes, observed vs said vs interpreted, denominators, saturation, disconfirming material)'
kind: ai-pattern
pack: product
---

# Pattern: Research Synthesis

> **Hard rule:** Nothing is invented — not a quote, a participant, a percentage, or a persona. Every quote is verbatim with a locator. Every count has a denominator. Every finding labels its class (observed / said / interpreted) and states what it does NOT support. Disconfirming material is reported, or its absence is stated explicitly. Evidence classes are never upgraded.

**When to apply**
- Raw material exists — interview notes, support tickets, session recordings, sales notes, reviews, survey free-text — and nobody has extracted findings.
- A claim about users needs its provenance checked.
- Several sources are being cited for a conclusion none of them supports.
- Before a problem brief, so it cites findings rather than raw notes.

**When NOT to apply**
- There is no raw material. Synthesis without input is fabrication; name what would need to be gathered instead.
- Heuristic evaluation of an interface — that is a usability review, not research, and the two must not be cited interchangeably.

**Halt conditions / mandatory cites**
- Material is somebody's summary with no underlying record — report their claim as a claim, never as evidence.
- Participant provenance unknown (who, how selected, current / prospective / churned) — selection determines what the material can support.
- Consent or privacy status unclear for material containing personal data — report themes without identifiers.
- The conclusion was specified before the synthesis — that is not synthesis; say so.
- Any percentage on an unknown or single-digit denominator is a hand-wave — reject it.

## Inventory before themes

Count and characterise the material *first*, so the strength of the eventual findings is bounded before any narrative forms. Reading for themes first produces a corpus characterised to fit the story.

| Material | Count | Date range | Selection | Class |
|---|---|---|---|---|
| interviews | | | inbound / recruited / referred | direct research |
| support tickets | | | all / filtered by tag | observed + reported problem |
| session recordings | | | sampled how | observed behaviour |
| sales-call notes | | | won / lost / all | stated preference, selection-biased |
| reviews | | | platform | stated preference, extreme-biased |
| survey free-text | | | respondent selection | stated preference |

Selection bias is not a caveat added at the end; it determines what each finding can claim, so it is recorded first.

## Observed vs said vs interpreted

Three confidence levels, routinely collapsed into one sentence:

- **Observed** — "opened a spreadsheet, copied four values, pasted them into the form" (from a recording or contextual observation).
- **Said** — "said they usually do this weekly" (self-reported, subject to recall).
- **Interpreted** — "appears to distrust the automatic calculation" (your inference, and it is yours).

Every finding labels which it is. An interpretation presented as an observation is the defect this separation exists to prevent, and it is invisible three weeks later.

## Counts with denominators

"Most participants" is not a count. Write "5 of 8 participants", "31 of 214 tickets in the period". Where the denominator is genuinely unknowable (open-ended reviews), state the count and declare the denominator unknown — do not convert it to a percentage.

A percentage on three participants is the most reliable sign that a synthesis is not to be trusted.

## Saturation

State how many independent sources support each finding, and whether new sources stopped producing new themes. A theme from one source is a hypothesis; saying so is what keeps it from being promoted by repetition.

If saturation was not reached, say so — it means more material would change the picture, which is actionable.

## Disconfirming material

For each candidate finding, search the material for observations that contradict it, and report them inside the finding. Where none exists, write "no disconfirming observations found in <n> sources" — silence reads as absence, and a corpus of any real size with no contradictions has been filtered, consciously or not.

## Limits, stated per finding

One sentence at the end of every finding prevents most downstream misuse:

> *"Supports: the manual reconciliation step is a recurring blocker for finance-role users. Does not support: prevalence across other roles, willingness to change tools, or any estimate of how many accounts are affected."*

## Evidence classes are never upgraded

Stated preference stays stated preference. A survey about interest does not become evidence that people will pay; the honest move is to relabel it and name the cheapest behavioural test — a concierge offer, a pre-commitment, an interest-to-action measurement — with its cost.

## Detectors

- A finding whose supporting quotes all come from one participant or one account.
- A percentage on a small denominator.
- A persona assembled from convenient traits rather than clustered observations.
- Quotes trimmed until the qualifying clause disappears.
- A theme present in the summary and absent from the raw notes.
- Only positive or only negative material from a channel that produces both.
- Findings written in the product's vocabulary rather than the participant's — interpretation ran ahead of the material.
- Material predating a significant product change, cited as current.
- No contradictions reported across a corpus of any size.

## Related

- `ai/patterns/problem-framing.md` — consumes these findings as its evidence, at their stated class.
- `ai/patterns/opportunity-sizing.md` — consumes the prevalence figures, with their denominators.
- `@user-research-synthesizer` — the agent that enforces this pattern.
- `evidence-trace` — links requirements back to these findings and catches mislinks.
- `/synthesize-research` — the command.
