# Business flows (Tier 2)

Primary user and operational flows. **Auto-filled** at `/setup-project` from `~/.claude/templates/business-domains/<detected>/core-flows.md` when a business domain is detected.

Last updated: <YYYY-MM-DD>

## Flow catalog

### <Flow name> (P0 | P1 | P2)

- **Actor**: <role>
- **Trigger**: <event>
- **Happy path**: <3–5 bullets>
- **Invariants**: <what must always hold>
- **Failure modes**: <what can go wrong>

### <Flow name>

- **Actor**: <...>
- **Trigger**: <...>
- **Happy path**: <...>

## Cross-cutting concerns

- **AuthN / AuthZ**: <how flows enforce identity and permission>
- **Multi-tenant** (if applicable): <tenant boundary in each flow>

## See also

- `ai/business-domain.md` — entities and vocabulary
- `ai/runbooks/` — step-by-step operational guides per phase
- `templates/business-domains/<domain>/feature-checklist.md` — product checklist source
