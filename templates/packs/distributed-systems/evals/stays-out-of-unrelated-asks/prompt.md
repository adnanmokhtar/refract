---
description: 'distributed-systems pack, should-NOT-trigger: a near-miss ask no distributed-systems skill or command owns'
expected_outcome: 'answers directly; no distributed-systems skill or command runs'
tags: [refract, distributed-systems, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Give me a regex that matches an ISO 8601 date (YYYY-MM-DD) and nothing else.
