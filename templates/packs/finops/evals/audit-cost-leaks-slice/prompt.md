---
description: 'finops pack, hard outcome: 5 seeded defects and 6 look-alikes in 25 files sliced from the cost-leaks fixture'
expected_outcome: 'names CL-BG1-b, CL-BG5-a, CL-BG5-b, CL-BG6-b, CL-TG2-b with file and line, and cites none of the decoys CL-DECOY-01, CL-DECOY-04, CL-DECOY-05, CL-DECOY-14, CL-DECOY-16, CL-DECOY-18'
tags: [refract, finops, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Please do a cloud cost review of this infrastructure before finance's quarterly review: Terraform, CloudFormation, Kubernetes overlays, monitoring, the CI workflow, runbooks and decisions. Would we notice a runaway bill before the invoice, and what are we paying for that nobody needs? The code is in the `resources/` directory (read-only). For each real problem give `path:line`, what goes wrong and when it happens. Leave out code that only looks risky.
