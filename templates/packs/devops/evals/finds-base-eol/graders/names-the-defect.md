---
type: regex
pattern: '^(?=[\s\S]*Dockerfile\.web)(?=[\s\S]*(?:18|EOL|end.?of.?life|unsupported))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of CD-CB-07a in benchmarks/fixtures/ci-defects/DEFECTS.md, the rule benchmarks/score.py credits.
