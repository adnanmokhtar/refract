---
description: 'business pack, outcome: the seeded BR-PR2-a in refund-calculator.ts, from the business-rules fixture'
expected_outcome: 'names refund-calculator.ts:5 (BIZ-PR-2) and leaves the look-alike alone'
tags: [refract, business, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Before the finance audit, review the refunds module's money rules. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
