---
description: 'mobile pack, command lane: audit-mobile-defects-slice through /refract-mobile:mobile-audit, same slice and graders'
expected_outcome: 'names MD-NB-02b, MD-NB-03b, MD-ST-02a, MD-OS-01b, MD-OS-03b, MD-ML-02b, MD-ML-06b with file and line, and cites none of the decoys MD-DECOY-16, MD-DECOY-14, MD-DECOY-13, MD-DECOY-20, MD-DECOY-06, MD-DECOY-17'
tags: [refract, mobile, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-mobile:mobile-audit --whole-repo Audit our Flutter driver app before the next store release, iOS and Android both: what would break on real devices or in store review. The code is in the read-only `resources/` directory. For each real problem give `path:line`, what goes wrong and when. Leave out code that only looks risky: do not list it at all, not even as cleared.
