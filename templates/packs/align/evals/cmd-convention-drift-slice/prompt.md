---
description: 'align pack, command lane: audit-convention-drift-slice through /refract-align:align-scan, same slice and graders'
expected_outcome: 'names CD-AL11-a, CD-AL11-b, CD-AL11-d, CD-AL14-a, CD-AL15-b, CD-AL32-a with file and line, and cites none of the decoys CD-DECOY-03, CD-DECOY-12, CD-DECOY-20, CD-DECOY-24, CD-DECOY-18'
tags: [refract, align, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-align:align-scan Audit the web app's orders feature for drift from the conventions and shared packages this monorepo already declares. The code is in the `resources` directory (read-only). For each real problem give `path:line` and what goes wrong and when; leave out code that only looks risky.
