---
description: 'business pack, hard outcome: 6 seeded defects and 7 look-alikes in 24 files sliced from the business-rules fixture'
expected_outcome: 'names BR-LC5-a, BR-LC3-a, BR-LC1-a, BR-MP1-a, BR-LG3-a, BR-CY1-a with file and line, and cites none of the decoys BR-DECOY-21, BR-DECOY-02, BR-DECOY-25, BR-DECOY-08, BR-DECOY-10, BR-DECOY-12, BR-DECOY-13'
tags: [refract, business, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Finance audits us next month. Run a business audit of the orders, payments, ledger, payouts and team-invite code: what will actually go wrong for customers, merchants or the books? The code is in the `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
