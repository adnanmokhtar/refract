---
description: 'frontend pack, should-NOT-trigger: a near-miss ask no frontend skill or command owns'
expected_outcome: 'answers directly; no frontend skill or command runs'
tags: [refract, frontend, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What does the SQL `COALESCE` function do? One sentence and one example.
