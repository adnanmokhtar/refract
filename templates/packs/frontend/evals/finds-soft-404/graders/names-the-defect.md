---
type: regex
pattern: '^(?=[\s\S]*page\.tsx)(?=[\s\S]*(?:404|not.?found|notFound|soft|catch.?all|empty))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of FC-RT-04a in benchmarks/fixtures/frontend-correctness/DEFECTS.md, the rule benchmarks/score.py credits.
