---
description: 'observability pack, hard outcome: 5 seeded defects and 4 look-alikes in 11 files sliced from the obs-defects fixture'
expected_outcome: 'names OD-AL-04b, OD-AL-04a, OD-SLO-05a, OD-SLO-02a, OD-SY-02a with file and line, and cites none of the decoys OD-DECOY-11, OD-DECOY-22, OD-DECOY-13, OD-DECOY-06'
tags: [refract, observability, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Audit the API's monitoring: the Prometheus scrape config, the alert and SLO rules, and the metrics the code exports. Will these alerts fire when something is wrong, and only then? The code is in the `resources` directory (read-only). For each real problem give `path:line` and what goes wrong and when; leave out code that only looks risky.
