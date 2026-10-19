---
description: 'delivery pack, should-NOT-trigger: a near-miss ask no delivery skill or command owns'
expected_outcome: 'answers directly; no delivery skill or command runs'
tags: [refract, delivery, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What does `Array.prototype.flatMap` return for an empty array? One sentence.
