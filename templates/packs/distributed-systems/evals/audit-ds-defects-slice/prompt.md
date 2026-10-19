---
description: 'distributed-systems pack, hard outcome: 5 seeded defects and 5 look-alikes in 21 files sliced from the ds-defects fixture'
expected_outcome: 'names DS-RT-04a, DS-MQ-02a, DS-DW-04a, DS-DW-04b, DS-CO-09a with file and line, and cites none of the decoys DS-DECOY-02, DS-DECOY-03, DS-DECOY-15, DS-DECOY-21, DS-DECOY-05'
tags: [refract, distributed-systems, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Audit the worker service (its Kafka consumers, BullMQ jobs and outbound clients) for what will go wrong under redelivery, retries and crashes. The code is in the `resources` directory (read-only). For each real problem give `path:line` and what goes wrong and when; leave out code that only looks risky.
