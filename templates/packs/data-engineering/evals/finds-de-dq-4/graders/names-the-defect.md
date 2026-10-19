---
type: regex
pattern: '^(?=[\s\S]*_sources\.yml)(?=[\s\S]*(?:impressions|ads|freshness))(?=[\s\S]*(?:no freshness|missing|stale|freshness))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of DE-DQ4-b in benchmarks/fixtures/data-pipelines/DEFECTS.md, the rule benchmarks/score.py credits.
