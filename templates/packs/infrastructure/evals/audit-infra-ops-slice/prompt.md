---
description: 'infrastructure pack, hard outcome: 7 seeded defects and 5 look-alikes in 12 files sliced from the infra-ops fixture'
expected_outcome: 'names IO-K8-SPa, IO-K8-RBa, IO-K8-RBb, IO-K8-PDBa, IO-K8-SGb, IO-K8-NRa, IO-K8-NPa with file and line, and cites none of the decoys IO-DECOY-01, IO-DECOY-09b, IO-DECOY-04, IO-DECOY-11, IO-DECOY-26'
tags: [refract, infrastructure, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Audit our base Kubernetes manifests, and the dispatch worker one of them runs, before the next production release. The code is in the `resources` directory (read-only). For each real problem give `path:line` and what goes wrong and when; leave out code that only looks risky.
