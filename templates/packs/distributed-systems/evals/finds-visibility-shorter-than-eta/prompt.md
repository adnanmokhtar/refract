---
description: 'distributed-systems pack, outcome: the seeded DS-MQ-06b in dunning.py, from the ds-defects fixture'
expected_outcome: 'names dunning.py:9 (messaging/visibility-shorter-than-eta) and leaves the look-alike alone'
tags: [refract, distributed-systems, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review the billing worker's background-job scheduling for delivery problems. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
