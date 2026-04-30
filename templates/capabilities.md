---
artifact: capabilities-index
purpose: Index of cross-cutting capabilities. Each capability lives in its own file under templates/capabilities/. This file holds only the composition map.
imported-by: commands/setup-project.md (orchestrator)
---

# Cross-cutting capabilities (index)

| #  | Capability                              | File                                                          | Threads through phases   |
|----|-----------------------------------------|---------------------------------------------------------------|--------------------------|
| 1  | Setup versioning + migration            | `templates/capabilities/1-versioning-migration.md`            | 0, 4, 5, 6               |
| 2  | Setup health score + telemetry          | `templates/capabilities/2-health-telemetry.md`                | 4, 5, 6                  |
| 3  | Schema validation harness               | `templates/capabilities/3-schema-validation.md`               | 5 (5.4)                  |
| 4  | Failure catalog                         | `templates/capabilities/4-failure-catalog.md`                 | 4 (4.6), 6               |
| 5  | Test fixtures + factories               | `templates/capabilities/5-fixtures-factories.md`              | 4 (4.4b)                 |
| 6  | Multi-language UX                       | `templates/capabilities/6-multi-language.md`                  | 1, 3, 4                  |
| 7  | Conversational wizard mode              | `templates/capabilities/7-conversational-wizard.md`           | 3 (wizard mode)          |

Each capability file is self-contained and includes its own contract, hard rules, and integration points.

**MANDATORY**: Pack code MUST NOT pre-load all 7 capability files. Each command's frontmatter declares which capabilities apply (key: `capabilities: [versioning, telemetry, ...]`); only those load. Pre-loading violates token budget — agents reject pack code that imports the capability index in bulk.

## 🔗 How the 7 capabilities compose

These features compose multiplicatively, not additively:

- **Versioning + Telemetry** = trend analysis ("setup was 95/100 in March, 87/100 today — what regressed?").
- **Schema validation + Wizard** = wizard refuses to apply if previewed config fails schema.
- **Failure catalog + Decision engine** = architectural agents propose new patterns aware of past failures.
- **Factories + Multi-language** = generated factory classes have Arabic JSDoc when `--lang=ar`.
- **Health score + Failure catalog** = health degrades if failures-not-cited grows (proxy for "team learning isn't applied").

The full pipeline with all 7 active:

```
/setup-project --refresh --wizard --lang=ar --validate-schemas
   ↓
   Phase 0:  backup + extract (REFRESH)
   Phase 1:  detect mode + version drift check
   Phase 2.6: profile-informed coverage gap + failure-catalog cross-check
   Phase 2:  profile codebase + load failure index + load extract
   Phase 2.y: WIZARD prompts in Arabic, 12 steps, mock previews
   Phase 3:  plan with version-stamps + schema preview
   Phase 4:  apply (regen + factory generation per domain)
   Phase 4.7: bilingual headers in CLAUDE.md / AGENTS.md
   Phase 5:  presence + self-consistency + SCHEMA validation + dry-invoke
   Phase 5+: health score computed + telemetry entry written
   Phase 6:  learning loop active forever
```

---

Treat this as the command's vocabulary. Everything referenced in the flow is catalogued here.

> **Terminology lock** (see Appendix F Glossary for full definitions):
> - **Track** — a discipline-shaped pack (backend / frontend / security / etc.). 15 total.
> - **Technical signal** — a cross-cutting tech concern detected in code (multi-tenant, payment, AI). Triggers tooling generation.
> - **Business domain** — what KIND of product the project is (ecommerce / lms / fintech). Drives entities, flows, compliance.
> - **Pack** — `~/.claude/templates/packs/<track>/` directory with `agents/`, `commands/`, `skills/`, `rules/`, `ai-patterns/`, `references/`.
> - **Tool adapter** — per-AI-tool config generator (claude-code / cursor / aider / opencode / ...). 10 total.
>
> The word "domain" is OVERLOADED — always qualify it: "technical signal" or "business domain". Never bare "domain".

---

**TODO (deferred)**: a future `scripts/validate-capabilities.sh` will mechanically reject packs whose code pre-loads >1 capability without declaring it. Until then, manual review enforces this rule.

