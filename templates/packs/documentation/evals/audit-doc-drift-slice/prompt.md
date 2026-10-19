---
description: 'documentation pack, hard outcome: 7 seeded defects and 5 look-alikes in 18 files sliced from the doc-drift fixture'
expected_outcome: 'names DOC-DK3-a, DOC-DK2-b, DOC-DK2-a, DOC-DK1-b, DOC-DL2-b, DOC-DE2-a, DOC-DE3-a with file and line, and cites none of the decoys DOC-DECOY-17, DOC-DECOY-19, DOC-DECOY-04, DOC-DECOY-07, DOC-DECOY-08'
tags: [refract, documentation, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

A new engineer joins the on-call rotation next week. Check our runbooks, alert rules and configuration reference against the repository: would they actually work for someone following them at 3am? The code is in the `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
