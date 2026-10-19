---
description: 'code-quality pack, should-NOT-trigger: a near-miss ask no code-quality skill or command owns'
expected_outcome: 'answers directly; no code-quality skill or command runs'
tags: [refract, code-quality, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Summarise what a Kubernetes PodDisruptionBudget is for, in two sentences.
