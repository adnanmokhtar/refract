---
description: 'frontend pack, command lane: audit-frontend-correctness-slice through /refract-frontend:frontend-audit, same slice and graders'
expected_outcome: 'names FC-BND-03, FC-RT-07a, FC-RT-07b, FC-SSR-03b, FC-I18N-02a with file and line, and cites none of the decoys FC-DECOY-01, FC-DECOY-02, FC-DECOY-05'
tags: [refract, frontend, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-frontend:frontend-audit --whole-repo Please audit this part of our Next.js grocery storefront before it goes to production: the root layout, product, checkout, account, catalogue and search pages, the server helpers, layout components and the translations. Find the correctness problems real shoppers would hit. The code is in the `resources/` directory (read-only). For each real problem give `path:line`, what goes wrong and when it happens. Leave out code that only looks risky.
