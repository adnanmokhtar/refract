---
description: 'delivery pack, outcome: the seeded FR-TRAP-01 in orders.js, from the feature-refund fixture'
expected_outcome: 'names orders.js:34 (trap/float-money) and leaves the look-alike alone'
tags: [refract, delivery, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Plan (do not implement) adding a 'Refund order' button to the order details page of this app: the steps, the files, and the tests you would write first. The app is in the read-only `resources` directory.
