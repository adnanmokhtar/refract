---
description: 'product pack, outcome: the seeded LG-AN5-a in UpgradePage.tsx, from the launch-gaps fixture'
expected_outcome: 'names UpgradePage.tsx:21 (PR-AN-5) and leaves the look-alike alone'
tags: [refract, product, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Before launch, check that the billing upgrade page's analytics events tell us the truth about purchases. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
