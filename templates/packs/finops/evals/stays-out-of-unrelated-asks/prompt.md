---
description: 'finops pack, should-NOT-trigger: a near-miss ask no finops skill or command owns'
expected_outcome: 'answers directly; no finops skill or command runs'
tags: [refract, finops, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What is the difference between a mutex and a semaphore? Two sentences.
