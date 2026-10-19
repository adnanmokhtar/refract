---
id: entities-ids
guards: [.claude/rules/entities.md]
kind: knowledge
created: 2026-09-01
threshold: strict
---

# Eval: new entity primary key

## Scenario

Add a `Shipment` entity to the shipping module.

## Answer key

### MUST include
- [ ] the primary key is generated in the constructor through `newId()`

### MUST NOT
- [ ] a database sequence or an auto-increment key
