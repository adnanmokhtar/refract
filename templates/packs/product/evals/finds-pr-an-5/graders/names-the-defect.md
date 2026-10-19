---
type: regex
pattern: '^(?=[\s\S]*UpgradePage\.tsx)(?=[\s\S]*(?:Plan Purchased|purchase))(?=[\s\S]*(?:before (the )?(payment|outcome|confirm)|checkout (session|URL)|not (yet )?paid|intent|premature|early|webhook|redirect))'
flags: i
target: last_message
---

The reply names the file and describes the seeded defect: every `match:` pattern of LG-AN5-a in benchmarks/fixtures/launch-gaps/DEFECTS.md, the rule benchmarks/score.py credits.
