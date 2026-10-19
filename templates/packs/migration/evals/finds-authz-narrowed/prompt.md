---
description: 'migration pack, outcome: the seeded PX-AZ2b in tickets.controller.ts, from the port-pair fixture'
expected_outcome: 'names tickets.controller.ts:40 (surface/authz-narrowed) and leaves the look-alike alone'
tags: [refract, migration, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

We are porting the helpdesk from the Laravel V1 to the NestJS V2. Compare the tickets API surface between the two and list what V2 lost or changed. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
