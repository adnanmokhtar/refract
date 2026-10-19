---
type: regex
pattern: '^(?=[\s\S]*invoice-total\.spec\.ts)(?=[\s\S]*(?:toBeDefined|weak (sole )?oracle|existence|only (checks|asserts) (that )?(it|a|the)|any (value|object)|return(s)? (0|zero|\{)|wrong (value|total|amount)))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of BS-AS-03 in benchmarks/fixtures/brittle-suite/DEFECTS.md, the rule benchmarks/score.py credits.
