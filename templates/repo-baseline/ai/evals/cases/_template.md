---
id: <kebab-slug>                 # unique; matches the filename
guards: []                        # what promoted knowledge this case protects — REQUIRED for coverage.
                                  # e.g. [.claude/rules/refund-auth.md, ai/conventions.md#tenancy, ai/patterns/idempotency.md]
kind: knowledge                   # knowledge | behavior | regression
created: <YYYY-MM-DD>
source: <what motivated this case> # e.g. ai/dynamic/feedback-learned.md 2026-06-10, or failures/_index #0001
threshold: strict                 # strict = 100% MUST-include AND 0 MUST-NOT (default). Override only with a reason.
---

# Eval: <one-line title>

## Scenario
<!-- The exact prompt handed to the AI under test. MUST be self-contained — no "as we discussed".
     This is what a real session would ask. Keep it to one concrete task or question. -->

<the task / question>

## Setup
<!-- What the graded AI is allowed to see. Default is the real project knowledge base
     (ai/, .claude/rules/) — i.e. how a normal session actually runs. List fixture files only
     if the case needs them. NEVER put the answer key in here — that leaks the answer. -->

Clean repo — standard project knowledge (ai/, .claude/rules/) available.

## Answer key
<!-- Checkable assertions ONLY. Vague keys ("does it well") make the case TOOTHLESS and it
     counts as no coverage. Assert invariants, not exact wording, so the case isn't flaky. -->

### MUST include
- [ ] <observable thing the correct output must contain or do>
- [ ] <another checkable assertion>

### MUST NOT
- [ ] <the specific mistake this case guards against — a violation is an automatic FAIL>

## Notes
<!-- Optional: why this case exists, what regression it caught, links to the incident. -->
