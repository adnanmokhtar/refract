---
description: 'product pack, should-NOT-trigger: a near-miss ask no product skill or command owns'
expected_outcome: 'answers directly; no product skill or command runs'
tags: [refract, product, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What does `chmod 640` mean? One sentence.
