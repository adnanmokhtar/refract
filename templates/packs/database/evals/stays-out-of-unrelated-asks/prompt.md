---
description: 'database pack, should-NOT-trigger: a near-miss ask no database skill or command owns'
expected_outcome: 'answers directly; no database skill or command runs'
tags: [refract, database, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

What is the difference between `git merge` and `git rebase`? Three sentences.
