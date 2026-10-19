---
description: 'database pack, command lane: audit-slow-marketplace-slice through /refract-database:db-audit, same slice and graders'
expected_outcome: 'names SM-CONN-03, SM-SCH-01, SM-SCH-03, SM-SCH-06, SM-TX-02 with file and line, and cites none of the decoys SM-DECOY-06, SM-DECOY-10, SM-DECOY-12, SM-DECOY-13, SM-DECOY-15'
tags: [refract, database, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-database:db-audit Please audit how this marketplace uses Postgres before Black Friday, when we expect several times our normal traffic: the deploy and pooler config, the ORM config, entities, migrations and the services that write orders, stores, money and events. The code is in the `resources/` directory (read-only). For each real problem give `path:line`, what goes wrong and when it happens. Leave out code that only looks risky.
