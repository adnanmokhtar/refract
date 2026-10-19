---
description: 'data-engineering pack, hard outcome: 7 seeded defects and 7 look-alikes in 14 files sliced from the data-pipelines fixture'
expected_outcome: 'names DE-OR8-a, DE-OR8-b, DE-OR7-b, DE-OR4-a, DE-DQ3-b, DE-DQ4-a, DE-IN10-a with file and line, and cites none of the decoys DE-DECOY-09, DE-DECOY-10, DE-DECOY-11, DE-DECOY-12, DE-DECOY-13, DE-DECOY-15, DE-DECOY-08'
tags: [refract, data-engineering, outcome, hard]
plugins: ["../.."]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

Finance starts reading the warehouse next month. Audit our data pipelines - the Airflow DAGs, the dbt CI workflow and source definitions, and the CDC connectors - for anything that will silently load wrong, duplicate, late or missing data. The code is in the `resources` directory. For each real problem give `path:line`, what goes wrong and when; leave out code that only looks risky.
