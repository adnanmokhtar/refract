---
type: regex
pattern: '^(?=[\s\S]*refund-calculator\.ts)(?=[\s\S]*(?:product\.price|catalog|price|return))(?=[\s\S]*(?:snapshot|live|current|catalog|unit_?price|today|historical|changed))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of BR-PR2-a in benchmarks/fixtures/business-rules/DEFECTS.md, the rule benchmarks/score.py credits.
