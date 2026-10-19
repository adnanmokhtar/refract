---
description: 'documentation pack, command lane: audit-doc-drift-slice through /refract-documentation:doc-refresh, same slice and graders'
expected_outcome: 'names DOC-DK3-a, DOC-DK2-b, DOC-DK2-a, DOC-DK1-b, DOC-DL2-b, DOC-DE2-a, DOC-DE3-a with file and line, and cites none of the decoys DOC-DECOY-17, DOC-DECOY-19, DOC-DECOY-04, DOC-DECOY-07, DOC-DECOY-08'
tags: [refract, documentation, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-documentation:doc-refresh --audit --whole-repo A new engineer joins the on-call rotation next week. Check our runbooks, alert rules and configuration reference against the repository: would they actually work for someone following them at 3am? The code is in the `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
