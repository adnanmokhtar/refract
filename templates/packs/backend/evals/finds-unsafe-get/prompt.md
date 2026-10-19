---
description: 'backend pack, outcome: the seeded BD-HC-4a in order-actions.controller.ts, from the backend-defects fixture'
expected_outcome: 'names order-actions.controller.ts:11 (http/unsafe-get) and leaves the look-alike alone'
tags: [refract, backend, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this order API controller for HTTP contract problems before we publish the API to partners. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
