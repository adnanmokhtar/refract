---
description: 'database pack, outcome: the seeded SM-TX-03 in store-settings.service.ts, from the slow-marketplace fixture'
expected_outcome: 'names store-settings.service.ts:19 (tx/lost-update) and leaves the look-alike alone'
tags: [refract, database, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this store-settings service's database usage before launch. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
