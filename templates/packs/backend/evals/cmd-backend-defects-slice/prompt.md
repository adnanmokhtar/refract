---
description: 'backend pack, command lane: audit-backend-defects-slice through /refract-backend:backend-audit, same slice and graders'
expected_outcome: 'names BD-EE-6a, BD-HC-1e, BD-HC-7c, BD-JL-2b, BD-JL-5a with file and line, and cites none of the decoys BD-DECOY-19, BD-DECOY-44, BD-DECOY-46, BD-DECOY-50'
tags: [refract, backend, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-backend:backend-audit --whole-repo Please audit our Django billing service's API before partners start calling it next month: settings, models, serializers, views, Celery tasks and schedulers, refunds, disputes, subscriptions, exports and the outbound PSP client. Find what would make partners get wrong answers or wrong amounts, let bad input through, or lose work. The code is in the `resources/` directory (read-only). For each real problem give `path:line`, what goes wrong and when it happens. Leave out code that only looks risky.
