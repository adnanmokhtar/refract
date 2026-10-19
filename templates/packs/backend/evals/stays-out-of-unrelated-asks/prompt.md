---
description: 'backend pack, should-NOT-trigger: a near-miss ask no backend skill or command owns'
expected_outcome: 'answers directly; no backend skill or command runs'
tags: [refract, backend, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Write a haiku about a quiet deploy on a Friday.
