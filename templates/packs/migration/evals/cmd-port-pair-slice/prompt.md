---
description: 'migration pack, command lane: audit-port-pair-slice through /refract-migration:compare-v1, same slice and graders'
expected_outcome: 'names PX-RT1a, PX-ER1a, PX-DM10a, PX-SE1a, PX-NULL1b, PX-MN1b with file and line, and cites none of the decoys PX-DECOY-31, PX-DECOY-30, PX-DECOY-20, PX-DECOY-23'
tags: [refract, migration, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-migration:compare-v1 --whole-repo --v1=resources/v1 --v2=resources/v2 --live-v1 We are porting the order desk from the Laravel V1 (`v1/`) to the NestJS V2 (`v2/`). Before we move order traffic to V2, compare the orders module between the two and list every behaviour V2 lost or changed. The code is in the `resources` directory (read-only). For each real problem give `path:line` and what goes wrong and when; leave out code that only looks risky.
