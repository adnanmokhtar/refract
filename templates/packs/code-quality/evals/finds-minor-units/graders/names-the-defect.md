---
type: regex
pattern: '^(?=[\s\S]*minor-units\.ts)(?=[\s\S]*(?:100|minor unit|exponent|JPY|KWD|currenc|decimal))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of QM-CS-12 in benchmarks/fixtures/quality-mix/DEFECTS.md, the rule benchmarks/score.py credits.
