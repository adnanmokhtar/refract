---
description: 'security pack, outcome: the seeded VFS-FILE-01 in downloads.controller.ts, from the vuln-fullstack fixture'
expected_outcome: 'names downloads.controller.ts:39 (file-access/path-traversal) and leaves the look-alike alone'
tags: [refract, security, outcome]
plugins: ["../.."]
runs: 3
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Before we open this marketplace API to the public, check the downloads controller for anything an attacker could abuse. The code is in the read-only `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
