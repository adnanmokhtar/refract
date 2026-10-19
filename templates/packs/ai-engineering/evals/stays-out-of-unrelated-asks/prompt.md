---
description: 'ai-engineering pack, should-NOT-trigger: a near-miss ask no ai-engineering skill or command owns'
expected_outcome: 'answers directly; no ai-engineering skill or command runs'
tags: [refract, ai-engineering, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

In two sentences, what is the difference between a Postgres B-tree index and a hash index?
