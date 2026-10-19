---
description: 'learning pack, outcome: the seeded SK-KN08-a in _decision-index.md, from the stale-knowledge fixture'
expected_outcome: 'names _decision-index.md:4 (KN-08) and leaves the look-alike alone'
tags: [refract, learning, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Our AI knowledge files are supposed to match the repository. Check the decision index against the ADRs it indexes. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
