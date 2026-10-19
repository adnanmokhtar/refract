---
description: 'testing pack, should-NOT-trigger: a near-miss ask no testing skill or command owns'
expected_outcome: 'answers directly; no testing skill or command runs'
tags: [refract, testing, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Explain what a CDN edge cache does, in two sentences.
