---
description: 'performance pack, hard outcome: 5 seeded defects and 5 look-alikes in 23 files sliced from the slow-marketplace fixture'
expected_outcome: 'names SM-CM-01, SM-CM-05, SM-SC-01, SM-CM-02, SM-SC-02 with file and line, and cites none of the decoys SM-DECOY-19, SM-DECOY-20, SM-DECOY-21, SM-DECOY-22, SM-DECOY-23'
tags: [refract, performance, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Please run a performance audit of this part of the backend before our seasonal sale: the deployment, auth, payouts, catalogue, checkout, dashboard, realtime and home-feed code, the search indexer and the outbound clients. Find what will be slow or fall over under real load. The code is in the `resources/` directory (read-only). For each real problem give `path:line`, what goes wrong and when it happens. Leave out code that only looks risky.
