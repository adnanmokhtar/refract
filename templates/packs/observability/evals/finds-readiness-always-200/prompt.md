---
description: 'observability pack, outcome: the seeded OD-MT-07b in health.py, from the obs-defects fixture'
expected_outcome: 'names health.py:10 (health/readiness-always-200) and leaves the look-alike alone'
tags: [refract, observability, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this service's health endpoints: will Kubernetes and the on-call engineer get a true signal? The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
