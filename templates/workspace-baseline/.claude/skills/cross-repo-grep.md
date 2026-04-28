---
name: cross-repo-grep
description: Parallel grep across every registered sibling repo in the workspace. Use when you're looking for where a concept lives across the system.
---

# cross-repo-grep

## Usage

```
/cross-repo-grep "<pattern>"            # full-text grep
/cross-repo-grep "<pattern>" --type ts  # scoped to a file type
/cross-repo-grep "<pattern>" --in api   # scoped to one repo
```

## Flow

1. Read `PROJECTS.md` to know every sibling path.
2. Grep in parallel (`rg` preferred, `grep -r` fallback).
3. Group results by repo.
4. For each hit, show: repo / file:line / snippet.

## Output

```
Pattern: "whatsapp_phone_number_id"

api/ (2 hits)
  src/modules/tenants/infrastructure/persistence/tenant.orm-entity.ts:24
  src/modules/whatsapp/adapters/webhooks/whatsapp-webhook.controller.ts:47

dashboard/ (0 hits)
```

## Rules

- Parallel — don't serialize greps, run them concurrently.
- Respect `.gitignore` per repo.
- Exclude `node_modules`, `dist`, `build`, `.next`, `.nuxt`, `target`.
- Flag when a concept lives in only one repo but the PROJECTS.md suggests it should be shared.
