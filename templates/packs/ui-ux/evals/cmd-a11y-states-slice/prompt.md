---
description: 'ui-ux pack, command lane: audit-a11y-states-slice through /refract-ui-ux:design-review, same slice and graders'
expected_outcome: 'names AS-A11Y-08a, AS-ST-06a, AS-A11Y-05a, AS-TK-08b, AS-ST-08a with file and line, and cites none of the decoys AS-DECOY-18, AS-DECOY-02, AS-DECOY-17, AS-DECOY-11, AS-DECOY-09, AS-DECOY-08'
tags: [refract, ui-ux, outcome, hard, command]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/refract-ui-ux:design-review resources Before launch, audit the shop's account area and checkout for accessibility and UI-state problems: anything a real shopper would actually hit. The code is in the read-only `resources/` directory. For each real problem give `path:line`, what goes wrong and when. Leave out code that only looks risky: do not list it at all, not even as cleared.
