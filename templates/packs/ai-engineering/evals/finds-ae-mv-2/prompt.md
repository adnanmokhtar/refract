---
description: 'ai-engineering pack, outcome: the seeded LA-MV2-b in lc_models.py, from the llm-assist fixture'
expected_outcome: 'names lc_models.py:4 (AE-MV-2) and leaves the look-alike alone'
tags: [refract, ai-engineering, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Our RAG service calls an LLM through LangChain. Review how it configures and calls the model for production risks. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
