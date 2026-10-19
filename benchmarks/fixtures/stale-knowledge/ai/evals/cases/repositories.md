---
id: repositories
guards: [ai/patterns/repository-per-aggregate.md]
kind: knowledge
created: 2026-09-01
threshold: strict
---

# Eval: repository shape

## Scenario

Add persistence for the inventory module.

## Answer key

### MUST include
- [ ] a repository that extends `BaseRepository`

### MUST NOT
- [ ] a repository returning another aggregate
