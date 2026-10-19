---
description: 'business pack, should-NOT-trigger: a near-miss ask no business skill or command owns'
expected_outcome: 'answers directly; no business skill or command runs'
tags: [refract, business, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What does the CSS property `contain: layout` do? Two sentences.
