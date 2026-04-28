---
description: After an API contract change, find frontend consumers and propose synced edits.
---

# /sync-contract

Run after an API DTO / endpoint signature has changed. Finds every frontend consumer and proposes the updates.

## Flow

1. Ask for: endpoint path (or DTO name) + brief description of what changed.
2. Read the old vs new DTO/contract in the API repo.
3. For each registered frontend sibling:
   - Grep for the endpoint URL and the type name.
   - Read the consumer files.
   - Propose concrete edits (which file, which line, what to change).
4. Identify i18n keys that must be added per frontend.
5. Print a per-repo punch list.

## Rules

- Don't apply edits automatically — report them. Let the user run `/cross-repo-task` to execute.
- Flag consumers that will break silently (e.g., optional field becoming required).
