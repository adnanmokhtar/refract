---
description: 'security pack, should-NOT-trigger: a near-miss ask no security skill or command owns'
expected_outcome: 'answers directly; no security skill or command runs'
tags: [refract, security, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What is the difference between a left join and an inner join? Two sentences.
