# Architecture

System shape, boundaries, and integration points. **Expanded** at `/setup-project` from codebase profile + prompt. One-page reference; deep layering lives in `.claude/codebase-profile.md`. The one-line shape is mirrored into `ai/_session-digest.md`.

Last updated: <YYYY-MM-DD>

## One-line shape

<Monolith | Modular monolith | N-tier API + workers | Microservices | ...> — <primary frameworks>

## Context diagram (text)

- **Inbound**: <web, mobile, webhooks, CLI, ...>
- **Core**: <services / modules>
- **Data**: <DBs, caches, queues>
- **Outbound**: <3rd-party APIs, email, ...>

## Module boundaries

| Module / bounded context | Responsibility | Key interfaces |
|--------------------------|----------------|----------------|
| <name> | <one line> | <APIs / events> |

## Non-functional targets

- **Scale / SLO**: <targets or TBD>
- **Security**: <auth model, sensitive data handling>

## See also

- `ai/_session-digest.md` — Tier-1 one-line shape (mirrored from this file)
- `.claude/codebase-profile.md` — machine-oriented deep layering
- `ai/stack.md` — versions and scripts
- `ai/decisions/` — ADRs that constrain architecture
