---
description: 'security pack, hard outcome: 5 seeded defects and 5 look-alikes in 25 files sliced from the vuln-fullstack fixture'
expected_outcome: 'names VFS-AUTH-01, VFS-XSS-04, VFS-IAC-06, VFS-DATA-09, VFS-DATA-02 with file and line, and cites none of the decoys VFS-DECOY-04, VFS-DECOY-07, VFS-DECOY-08, VFS-DECOY-09, VFS-DECOY-10'
tags: [refract, security, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Please run a security audit of this part of our marketplace before we launch it: the API (settings, webhooks, inventory, auth, themes), the web build config, the image and the proxy and Kubernetes config. The code is in the `resources/` directory (read-only). For each real problem give `path:line`, what goes wrong and when it happens. Leave out code that only looks risky.
