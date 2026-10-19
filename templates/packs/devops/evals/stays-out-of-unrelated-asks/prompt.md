---
description: 'devops pack, should-NOT-trigger: a near-miss ask no devops skill or command owns'
expected_outcome: 'answers directly; no devops skill or command runs'
tags: [refract, devops, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Explain the difference between `useMemo` and `useCallback` in React, in three sentences.
