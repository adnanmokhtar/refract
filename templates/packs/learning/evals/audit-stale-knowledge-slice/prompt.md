---
description: 'learning pack, hard outcome: 4 seeded defects and 5 look-alikes in 20 files sliced from the stale-knowledge fixture'
expected_outcome: 'names SK-KN11-a, SK-KN07-b, SK-KN07-a, SK-KN27-a with file and line, and cites none of the decoys SK-DECOY-20, SK-DECOY-06, SK-DECOY-21, SK-DECOY-26, SK-DECOY-16'
tags: [refract, learning, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Our coding agents keep getting basics wrong in this repo. Audit the AI knowledge layer - agent instructions, rules, skills, hooks and the ai/ notes - against the actual code and config: what is wrong or will mislead an agent? The code is in the `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
