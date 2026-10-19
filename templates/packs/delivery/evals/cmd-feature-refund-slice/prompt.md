---
description: 'delivery pack, command lane: spec-feature-refund-slice through /refract-delivery:add-feature, same slice and graders'
expected_outcome: 'predicts T3; acceptance criteria cover integer money, idempotent replay, the other tenant 403, the shared empty state, and refusing unpaid and cancelled orders'
tags: [refract, delivery, outcome, spec, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-delivery:add-feature --plan Support wants a 'Refund order' button on the order details page of this back office. Before anyone writes code, give me the requirements: how risky the change is and how much review it needs, the acceptance criteria as testable statements, and the edge cases the tests must cover. Do not implement anything. The app is in the `resources` directory.
