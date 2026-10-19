---
description: 'ui-ux pack, should-NOT-trigger: a near-miss ask no ui-ux skill or command owns'
expected_outcome: 'answers directly; no ui-ux skill or command runs'
tags: [refract, ui-ux, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

How do I read a file line by line in Python? One short example.
