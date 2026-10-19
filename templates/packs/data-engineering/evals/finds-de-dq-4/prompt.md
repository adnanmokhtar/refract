---
description: 'data-engineering pack, outcome: the seeded DE-DQ4-b in _sources.yml, from the data-pipelines fixture'
expected_outcome: 'names _sources.yml:65 (DE-DQ-4) and leaves the look-alike alone'
tags: [refract, data-engineering, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Check our dbt staging sources config for data-quality gaps that would let bad or late data reach the dashboards. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
