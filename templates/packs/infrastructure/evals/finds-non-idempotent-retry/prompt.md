---
description: 'infrastructure pack, outcome: the seeded IO-ED-03b in api.caddy, from the infra-ops fixture'
expected_outcome: 'names api.caddy:20 (edge/non-idempotent-retry) and leaves the look-alike alone'
tags: [refract, infrastructure, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review the API's Caddy edge config for reliability problems under failure. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
