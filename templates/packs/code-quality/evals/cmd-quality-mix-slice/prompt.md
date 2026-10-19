---
description: 'code-quality pack, command lane: audit-quality-mix-slice through /refract-code-quality:quality-audit, same slice and graders'
expected_outcome: 'names QM-AR-03, QM-DC-01, QM-DC-02, QM-DC-03, QM-SUP-03, QM-CS-20, QM-CS-19, QM-CS-07, QM-CS-14, QM-CS-02 with file and line, and cites none of the decoys QM-DECOY-06, QM-DECOY-05, QM-DECOY-18, QM-DECOY-23, QM-DECOY-24'
tags: [refract, code-quality, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-code-quality:quality-audit --whole-repo Please run a code-quality audit of our billing API before we hand it over to another team next sprint. I want everything in it that is wrong today, not style nits. The code is in the read-only `resources/` directory. For each real problem give `path:line`, what goes wrong and when. Leave out code that only looks risky: do not list it at all, not even as cleared.
