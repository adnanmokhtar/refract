---
description: 'mobile pack, outcome: the seeded MD-ML-05a in router.dart, from the mobile-defects fixture'
expected_outcome: 'names router.dart:23 (lifecycle/deep-link-payload-crash) and leaves the look-alike alone'
tags: [refract, mobile, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review the driver app's router for problems a real device would hit. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
