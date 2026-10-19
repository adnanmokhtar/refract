---
type: regex
pattern: '^(?=[\s\S]*_decision-index\.md)(?=[\s\S]*(?:0006))(?=[\s\S]*(?:0008|8 (files|ADRs)|range|count|stale|wrong|outdated))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of SK-KN08-a in benchmarks/fixtures/stale-knowledge/DEFECTS.md, the rule benchmarks/score.py credits.
