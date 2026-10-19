---
description: 'devops pack, outcome: the seeded CD-CB-07a in Dockerfile.web, from the ci-defects fixture'
expected_outcome: 'names Dockerfile.web:2 (container/base-eol) and leaves the look-alike alone'
tags: [refract, devops, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review the web app's container build for problems we would ship to production. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
