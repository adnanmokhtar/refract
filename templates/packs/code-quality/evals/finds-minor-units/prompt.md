---
description: 'code-quality pack, outcome: the seeded QM-CS-12 in minor-units.ts, from the quality-mix fixture'
expected_outcome: 'names minor-units.ts:12 (logic/minor-units) and leaves the look-alike alone'
tags: [refract, code-quality, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review the payouts helper for code that will behave wrongly in production. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
