---
description: 'ai-engineering pack, hard outcome: 9 seeded defects and 3 look-alikes in 22 files sliced from the llm-assist fixture'
expected_outcome: 'names LA-RG8-a, LA-EV4-b, LA-EV5-b, LA-EV2-b, LA-CO4-b, LA-RG6-a, LA-RG10-a, LA-EV3-b, LA-CO2-b with file and line, and cites none of the decoys LA-DECOY-20, LA-DECOY-23, LA-DECOY-21'
tags: [refract, ai-engineering, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Do a full audit of the AI/LLM side of our Python RAG service before we scale it up. The code is in the `resources` directory (read-only). For each real problem give `path:line` and what goes wrong and when; leave out code that only looks risky.
