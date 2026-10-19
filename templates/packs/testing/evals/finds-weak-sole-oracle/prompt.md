---
description: 'testing pack, outcome: the seeded BS-AS-03 in invoice-total.spec.ts, from the brittle-suite fixture'
expected_outcome: 'names invoice-total.spec.ts:9 (assertion/weak-sole-oracle) and leaves the look-alike alone'
tags: [refract, testing, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Would this test suite catch a wrong invoice total? Review the spec. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
