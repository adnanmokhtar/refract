---
description: 'devops pack, hard outcome: 6 seeded defects and 7 look-alikes in 23 files sliced from the ci-defects fixture'
expected_outcome: 'names CD-CP-04a, CD-DS-06a, CD-DS-06c, CD-CB-06b, CD-DS-01b, CD-CP-02b with file and line, and cites none of the decoys CD-DECOY-22, CD-DECOY-11, CD-DECOY-21, CD-DECOY-25, CD-DECOY-26, CD-DECOY-16, CD-DECOY-12'
tags: [refract, devops, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

We're about to move more traffic onto the shop stack we run on our two Compose hosts. Audit how it is built and shipped first: the images, the compose files and the deploy script. The code is in the read-only `resources/` directory. For each real problem give `path:line`, what goes wrong and when. Leave out code that only looks risky: do not list it at all, not even as cleared.
