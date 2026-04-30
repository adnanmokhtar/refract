---
description: After an API contract change, find frontend consumers and propose synced edits.
---

# /sync-contract

## The Premise (read this first)

**Source contract wins. Refuse drift; surface every divergence with cite.** The API DTO / endpoint signature is the source of truth. Frontend consumers must align — not the other way around. Every proposed edit cites both sides: `<api-repo>/<contract-file:line>` (truth) and `<frontend-repo>/<consumer-file:line>` (drift).

**Mechanical halt** — refuse to propose:
- A frontend edit without naming the exact consumer file:line that's drifting.
- A paraphrased version of the contract change ("rename this field" — name the OLD and NEW field exactly).
- A consumer "looks fine" verdict without citing the line that consumes the changed field.

If the frontend change requires an API change first, halt — don't patch the frontend around a missing API change.

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
