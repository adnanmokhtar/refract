---
description: 'mobile pack, should-NOT-trigger: a near-miss ask no mobile skill or command owns'
expected_outcome: 'answers directly; no mobile skill or command runs'
tags: [refract, mobile, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Explain what `EXPLAIN ANALYZE` shows in Postgres, in two sentences.
