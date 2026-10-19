---
description: 'testing pack, command lane: audit-brittle-suite-slice through /refract-testing:test-audit, same slice and graders'
expected_outcome: 'names BS-SE-12, BS-SE-16, BS-SE-04, BS-SE-03, BS-CG-03, BS-TD-01, BS-AS-08 with file and line, and cites none of the decoys BS-DECOY-21, BS-DECOY-04, BS-DECOY-08, BS-DECOY-16, BS-DECOY-18'
tags: [refract, testing, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-testing:test-audit --whole-repo Please audit our API's test suite before we lean on it for the refunds rewrite: I need to know where it would let a broken refund ship. CI config is included. The code is in the read-only `resources/` directory. For each real problem give `path:line`, what goes wrong and when. Leave out code that only looks risky: do not list it at all, not even as cleared.
