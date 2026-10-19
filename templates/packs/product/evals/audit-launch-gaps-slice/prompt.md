---
description: 'product pack, hard outcome: 7 seeded defects and 5 look-alikes in 15 files sliced from the launch-gaps fixture'
expected_outcome: 'names LG-AN2-b, LG-AN1-a, LG-AN1-b, LG-AN3-b, LG-AN4-b, LG-AN6-b, LG-AN7-b with file and line, and cites none of the decoys LG-DECOY-02, LG-DECOY-03, LG-DECOY-10, LG-DECOY-14, LG-DECOY-15'
tags: [refract, product, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

We launch the new billing and onboarding flows next week and growth reads the PostHog funnels from day one. Audit our product analytics: will the events and the tracking plan tell us the truth? The code is in the `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
