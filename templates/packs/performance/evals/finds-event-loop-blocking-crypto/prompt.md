---
description: 'performance pack, outcome: the seeded SM-RT-02 in password.service.ts, from the slow-marketplace fixture'
expected_outcome: 'names password.service.ts:36 (perf/event-loop-blocking-crypto) and leaves the look-alike alone'
tags: [refract, performance, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

The login endpoint gets slow under load. Review the auth password service for the cause. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
