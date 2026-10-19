---
description: 'performance pack, should-NOT-trigger: a near-miss ask no performance skill or command owns'
expected_outcome: 'answers directly; no performance skill or command runs'
tags: [refract, performance, negative]
plugins: ["../.."]
runs: 3
max_turns: 5
allowed_tools: [Read, Glob, Grep, Skill]
---

Write a SQL query that counts orders per customer from a table orders(id, customer_id).
