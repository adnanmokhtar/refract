---
type: regex
pattern: '^(?=[\s\S]*downloads\.controller\.ts)(?=[\s\S]*(?:path traversal|directory traversal|traversal|\.\./|dot.?dot|\blfi\b|local file (inclusion|read)|arbitrary file (read|download|access)|outside.{0,30}(root|director|base)|path\.join.{0,40}(user|name|query|input)))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of VFS-FILE-01 in benchmarks/fixtures/vuln-fullstack/DEFECTS.md, the rule benchmarks/score.py credits.
