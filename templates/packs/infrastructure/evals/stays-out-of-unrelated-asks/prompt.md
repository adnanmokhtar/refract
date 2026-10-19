---
description: 'infrastructure pack, should-NOT-trigger: a near-miss ask no infrastructure skill or command owns'
expected_outcome: 'answers directly; no infrastructure skill or command runs'
tags: [refract, infrastructure, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Write a short commit message for: renamed getUser to fetchUser in three call sites.
