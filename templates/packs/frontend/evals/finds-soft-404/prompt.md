---
description: 'frontend pack, outcome: the seeded FC-RT-04a in page.tsx, from the frontend-correctness fixture'
expected_outcome: 'names page.tsx:9 (routing/soft-404) and leaves the look-alike alone'
tags: [refract, frontend, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review this Next.js category page for correctness problems users or crawlers would hit. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
