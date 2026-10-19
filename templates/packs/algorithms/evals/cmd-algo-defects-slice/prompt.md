---
description: 'algorithms pack, command lane: audit-algo-defects-slice through /refract-algorithms:analyze-complexity, same slice and graders'
expected_outcome: 'names AL-GE1-b, AL-GE2-a, AL-GE3-a, AL-RC4-a, AL-RC2-b, AL-OC1-a, AL-OC4-a with file and line, and cites none of the decoys AL-DECOY-06, AL-DECOY-04, AL-DECOY-02, AL-DECOY-01, AL-DECOY-08'
tags: [refract, algorithms, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-algorithms:analyze-complexity resources Audit the algorithms in our API's stores, delivery, pricing, catalog and sync code: anything that gives a wrong answer on real inputs or will not hold up as the data grows. The code is in the read-only `resources/` directory. For each real problem give `path:line`, what goes wrong and when. Leave out code that only looks risky: do not list it at all, not even as cleared.
