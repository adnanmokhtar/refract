---
type: regex
pattern: '^(?=[\s\S]*restore-db\.md)(?=[\s\S]*(?:make restore-db))(?=[\s\S]*(?:target|Makefile|db-restore|not (defined|found)|no such|missing|dead|renamed))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of DOC-DK1-a in benchmarks/fixtures/doc-drift/DEFECTS.md, the rule benchmarks/score.py credits.
