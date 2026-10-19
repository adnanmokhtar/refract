---
description: 'align pack, outcome: the seeded CD-AL13-b in format-date.ts, from the convention-drift fixture'
expected_outcome: 'names format-date.ts:1 (AL-13) and leaves the look-alike alone'
tags: [refract, align, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Our monorepo ships shared packages every app is meant to use. Check the admin app's utilities for drift from what the shared packages already provide. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
