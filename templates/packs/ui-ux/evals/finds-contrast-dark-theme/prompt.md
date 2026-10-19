---
description: 'ui-ux pack, outcome: the seeded AS-A11Y-09a in globals.css, from the a11y-states fixture'
expected_outcome: 'names globals.css:26 (a11y/contrast-dark-theme) and leaves the look-alike alone'
tags: [refract, ui-ux, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Review the shop's global styles for accessibility problems, light and dark theme. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
