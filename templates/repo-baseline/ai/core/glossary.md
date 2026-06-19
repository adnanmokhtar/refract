# Glossary

Domain entities + key concepts in this project. Auto-populated from `business-domains/<domain>/glossary.md` when `/setup-project` detects a business domain. Otherwise: filled in as the codebase grows.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `<EntityName>` | <what it represents> | `id, ...` | <state machine> |

(Replace this row when the first domain entity is identified. Add rows as new entities are introduced.)

## Vocabulary distinctions (don't conflate)

When two terms LOOK like synonyms but mean different things in this codebase, document the distinction here.

- **<TermA>** vs **<TermB>** — <distinction>

## Status state machines

For entities with non-trivial lifecycles, draw the state diagram here in ASCII or text:

```
<state> → <state> → <state>
   ↓
<terminal-state>
```

## Multi-tenancy variant (if multi-tenant)

- Boundary: <single-tenant | per-tenant | per-region | none>
- Scope of every entity: <does each entity belong to a tenant?>

## How to keep this current

- Add an entry every time a new aggregate root is introduced.
- Update vocabulary distinctions when team conversations reveal confusion.
- Cross-link to `ai/business-domain.md` if the project has a declared business domain.

## See also

- `ai/business-domain.md` — overarching domain identity.
- `ai/core/invariants.md` — system-wide rules entities must obey.
- `ai/dynamic/glossary-evolution.md` (optional) — entries being watched before they enter here.
