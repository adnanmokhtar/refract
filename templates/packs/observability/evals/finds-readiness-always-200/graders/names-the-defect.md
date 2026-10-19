---
type: regex
pattern: '^(?=[\s\S]*health\.py)(?=[\s\S]*(?:readiness|readyz|always|200|constant|pool|database))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of OD-MT-07b in benchmarks/fixtures/obs-defects/DEFECTS.md, the rule benchmarks/score.py credits.
