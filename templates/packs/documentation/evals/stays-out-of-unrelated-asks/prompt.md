---
description: 'documentation pack, should-NOT-trigger: a near-miss ask no documentation skill or command owns'
expected_outcome: 'answers directly; no documentation skill or command runs'
tags: [refract, documentation, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What is the time complexity of inserting into a binary heap? One sentence.
