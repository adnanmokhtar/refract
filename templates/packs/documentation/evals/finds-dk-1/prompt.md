---
description: 'documentation pack, outcome: the seeded DOC-DK1-a in restore-db.md, from the doc-drift fixture'
expected_outcome: 'names restore-db.md:15 (DK-1) and leaves the look-alike alone'
tags: [refract, documentation, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Check the database restore runbook against the repository: would an on-call engineer following it at 3am succeed? The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
