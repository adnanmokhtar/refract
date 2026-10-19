---
description: 'migration pack, should-NOT-trigger: a near-miss ask no migration skill or command owns'
expected_outcome: 'answers directly; no migration skill or command runs'
tags: [refract, migration, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What is a closure in JavaScript? Two sentences.
