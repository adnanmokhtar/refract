---
description: Run golden prompt evaluations — send a fixed set of customer messages through the real PromptBuilder + Claude, grade the replies.
---

# /prompt-eval

Purpose: detect prompt regressions before they land in prod. Every prompt change must pass this gate.

## Premise

Real prompts in real conditions. Don't synthesize edge cases on the fly — pull from `test/prompt-eval/golden-cases.json` (production-like fixtures), call the real Claude API, grade the real reply. No mocked Claude responses. No invented "what-if" cases. If the rubric isn't in the golden file, it doesn't get evaluated this run — add it to the file first, commit, then re-run.

## Mechanical halt

Cite-or-halt: every reported pass/fail must reference the case `id` from the JSON and the actual API response token counts. No cases without a recorded reply. If `ANTHROPIC_API_KEY` is missing, halt — refuse to fake a run with stub replies.

## What it does

1. Loads `test/prompt-eval/golden-cases.json` — 10+ hand-curated Egyptian-Arabic customer scenarios with expected-behavior rubrics (not exact-match strings).
2. For each case:
   - Spins up the fixture tenant + products in an in-memory fake DB.
   - Invokes `PromptBuilder.build()` exactly as production does.
   - Calls the **real** Claude API (uses `ANTHROPIC_API_KEY` — this command costs real money).
   - Records the reply + token counts.
3. Grades each reply against the rubric (length, dialect, on-topic, mentions correct product, doesn't invent prices).
4. Prints a table: case id | pass/fail | reply preview | tokens | cost.

## When to invoke

- Before merging any change to `application/services/prompt-builder/` or its fragments.
- After tweaking `CLAUDE_MODEL` or `max_tokens`.
- Day 6 of Phase 1 (initial Arabic tuning).
- Weekly sanity check once live.

## How

```bash
pnpm run prompt-eval            # all cases
pnpm run prompt-eval -- --case=price-ask-out-of-stock   # single case
```

Implementation lives at `test/prompt-eval/run.ts`. Golden cases at `test/prompt-eval/golden-cases.json`. Add new cases whenever you find a real-world failure — the regression set only grows.

## Rubric dimensions (each case defines which apply)

- **dialect**: reply is Egyptian Arabic (not MSA, not English). Automated check: regex + small classifier.
- **length**: 1-3 sentences.
- **factuality**: if case mentions a product, the reply uses the correct price/stock from the fixture catalog.
- **on_topic**: reply advances toward a sale (recommends, clarifies, or asks for the order).
- **safety**: no invented products, no discounts not in fixture, no PII leak.

## Output

- Prints pass/fail.
- Fails the command if any required case fails (non-zero exit).
- Writes `test/prompt-eval/runs/<timestamp>.json` for historical comparison.

## Cost note

One full eval run = ~15 Claude calls ≈ $0.10. Cheap. Run it liberally.
