---
name: adr-template
description: Pattern: ADR Template
kind: ai-pattern
pack: documentation
---

# Pattern: ADR Template

> **Hard rule** — Every ADR has a numbered file in `ai/decisions/NNNN-*.md`, names ≥ 2 alternatives with concrete rejection reasons, and lists trade-offs accepted. ADRs without alternatives or written speculatively (before the choice) are forbidden.

**When to apply**
- Decision constrains future architecture (DB choice, auth model, multi-tenancy strategy).
- Reasonable engineers would disagree and the cost of disagreement is real.
- You're reversing or superseding a previous ADR.

**When NOT to apply**
- Style / naming conventions — those go in `ai/conventions.md`.
- Library version bumps with no architectural reach.
- Bug fix or refactor that doesn't change a system property.

**Halt conditions / mandatory cites**
- Cite the previous ADR by `<path>` when superseding; never rewrite the prior body — link forward only.
- Cite the triggering signal (`<path:line>` of incident report, `<path>` of ticket, `<path>` of metric dashboard) in Context; "we need scalability" alone is a halt.
- Cite at least 2 alternatives with one concrete reject reason each tied to the cited Context; single-option ADRs are halted.
- Cite the implementing file or commit (`<path:line>` or commit SHA) when moving Status to `Accepted`; promote-without-impl is a halt.
- Hand-wave grep ban — never claim "no other ADR conflicts" without citing `ai/decisions/` listing or grep artifact.

Architecture Decision Records capture WHY a non-obvious technical choice was made. Six months from now, when someone asks "why did we use Postgres instead of Mongo?", the answer is a 200-word document, not a Slack thread that's been pruned. ADRs encode institutional memory in a format that survives team turnover.

## Context

Write an ADR when:
- The decision will outlive the people in the room (architecture, vendor lock-in, multi-year commitments).
- Reasonable engineers would disagree, and the disagreement cost is real.
- The choice constrains future decisions (e.g., picking a DB constrains every query for the system's lifetime).
- You're reversing a previous decision — the old ADR's reasoning has changed.

Don't write an ADR for:
- Conventions and style (those go in `ai/conventions.md`).
- Library version bumps (unless it's a major framework swap).
- Bug fixes, feature adds, refactors that have no architectural reach.

The line: "would a new senior engineer Google this and not find the answer in the codebase?" If yes, ADR.

## Format

```markdown
# ADR NNNN — <Title in imperative form>

Date: YYYY-MM-DD
Status: Proposed | Accepted | Deprecated | Superseded by ADR-NNNN
Authors: <names or handles>
Reviewers: <who signed off>

## Context

What forced the decision? Ground in a real signal — incident, deadline, requirement, cost.
2-3 paragraphs max. The reader should finish this section and feel "yes, a decision is needed".

## Decision

What we will do. Concrete and specific. Imperative present tense.
NOT "We should consider using X." — that's a discussion.
YES "We use X for Y, configured with Z."

## Consequences

What follows from this:
- Easier: <list>
- Harder: <list>
- New commitments: <what we now must maintain>
- Trade-offs accepted: <what we knowingly give up>

## Alternatives considered

- **<Alt A>** — Rejected because <concrete reason tied to Context>.
- **<Alt B>** — Rejected because <concrete reason>.

If no alternatives — this probably isn't a decision worth an ADR. Re-examine.

## Open questions (optional)

- What we still don't know but accept as risk.
- Triggers that would prompt revisiting this ADR.
```

## Worked example

```markdown
# ADR 0007 — Use Postgres as the primary OLTP store

Date: 2026-04-24
Status: Accepted
Authors: @adnan, @sara
Reviewers: @platform-team, @security

## Context

We're scaling from 50 tenants to a projected 5,000 in 18 months. The current SQLite per-tenant
file model holds for the prototype but breaks for: cross-tenant analytics queries (reporting
team), backups (one file per tenant doesn't scale to 5k), and connection pooling (file-per-tenant
forces process-per-tenant).

We need a single OLTP store that handles 5k tenants in shared schema with row-level tenant
filtering, supports JSONB for the variable product attributes, and has operational track record
in our team.

## Decision

We use PostgreSQL 16 as the primary OLTP database. All services connect to a single Postgres
cluster (primary + 2 read replicas). Tenant isolation is enforced at the application layer via
`tenant_id` columns + `TenantScopedRepository` base class; row-level security policies layer on
top as defense-in-depth.

Read-heavy analytics queries route to a replica via a separate connection pool.

## Consequences

Easier:
- Single backup target. PITR via WAL archive.
- Cross-tenant analytics in one query.
- JSONB unblocks variable product attributes without schema-per-tenant.
- Connection pooling via PgBouncer scales to thousands of app connections.

Harder:
- Tenant isolation now an application concern (was filesystem). Shipped via base repo + tested
  per repo. Subject to ADR 0008 (Tenant isolation testing standard).
- Need DBA expertise we don't yet have. Hired for in Q3.
- Migration from SQLite is non-trivial — see runbook `migrate-sqlite-to-pg.md`.

New commitments:
- Postgres operational ownership (backup, replication, version upgrades).
- Schema migration discipline — no breaking changes without expand-contract.

Trade-offs accepted:
- Lose per-tenant blast radius isolation. A bad query in one tenant could affect others if it
  hits a shared resource (DB CPU). Mitigation: per-tenant connection limits + slow-query alerts.

## Alternatives considered

- **MySQL 8** — Rejected because we lack operational experience. Postgres' JSONB + array types
  also fit our product schema better than MySQL's JSON.
- **MongoDB** — Rejected because we need ACID transactions across multiple collections (orders +
  inventory + accounting), which Mongo supports but is awkward and expensive. Our data is
  fundamentally relational.
- **Schema-per-tenant in Postgres** — Rejected because 5k schemas hits Postgres limits (per-conn
  memory grows linearly with schemas in search_path); operational overhead of running migrations
  across 5k schemas is high.

## Open questions

- At what tenant count does row-level isolation strain (slow queries from tenant scan)? Plan to
  re-evaluate at 2k tenants.
- Whether to add Citus for horizontal scaling later. Defer until concrete signal.
```

## When to write — concrete examples

**Write an ADR for:**
- Picking primary database, message broker, or cloud provider.
- Authentication model (JWT vs sessions vs OAuth + variants).
- Multi-tenancy strategy (shared DB vs schema-per-tenant vs DB-per-tenant).
- Synchronous vs asynchronous (in-process call vs queue).
- Architecture style (hexagonal vs layered vs flat) when it spans the codebase.
- Build/deploy strategy (monorepo vs polyrepo, Docker vs serverless).
- Patterns that span more than one module (how we handle errors / events / idempotency / caching).
- Reversing or replacing a previous ADR.

**Don't write an ADR for:**
- "We use camelCase for variables" (conventions, not architecture).
- "We bumped from React 18 to React 19" (unless it forces architecture changes).
- "We added a new service" (unless its existence is the architectural choice).
- "We renamed module X to Y" (refactor, not decision).

## Numbering and naming

```
ai/decisions/0001-use-hexagonal-architecture.md
ai/decisions/0002-mysql-to-postgres.md
ai/decisions/0003-jwt-with-refresh-rotation.md
```

- Sequential 4-digit numbers. Pad to 4 because you'll cross 999 if the project lasts.
- Never reuse a number.
- Title is kebab-case, present tense, the decision itself — not "should we" or "consider".
- Title encodes the choice: `0007-use-postgres-as-primary-oltp.md` not `0007-database-choice.md`.

## Status lifecycle

```
Proposed       ← under review
   ↓
Accepted       ← merged to main, in effect
   ↓
Deprecated     ← still true but no longer how we'd choose; new code may diverge
   ↓
Superseded     ← replaced; link to the replacing ADR
```

When superseding:
1. Write the NEW ADR with a `Supersedes ADR-NNNN` reference in Context.
2. EDIT the old ADR: change Status to `Superseded by ADR-MMMM` and add a one-line link.
3. NEVER rewrite the old ADR's body. Decisions are historical record.

## Common mistakes

- **Speculative ADRs.** "We might switch to Mongo later" — there's no decision yet. ADR comes after the choice, not before.
- **Vague Context.** "We need scalability" — every ADR can claim that. Ground in a number, an incident, a deadline. "Tenant count projected to grow 100× in 18 months" is concrete.
- **No alternatives.** Single-option ADR is just documentation. Reviewers can't tell if the decision is good or just inevitable.
- **Multiple decisions in one ADR.** "ADR 0005 — DB and message broker and auth" — three ADRs muddled. Split.
- **Decisions hidden in code review threads.** Slack/PR comments don't survive. Promote to ADR.
- **ADR rotting after the decision changes.** Codebase moved on; ADR still says "Accepted". Update Status to Deprecated/Superseded.
- **Reading like a defense.** ADR is not justification for what you already shipped — it's reasoning that survives. Tone: "we considered X, Y, Z; chose Y because Z couldn't do A."

## Linking from elsewhere

- `ai/status.md` Recent Changes section: link new ADRs.
- Code: when implementing the decision, add a comment like `// Per ADR 0007: tenant isolation via base repo`.
- Onboarding doc: list the most important ADRs new hires must read.

## Alternatives to ADR format

- **Y-Statements** (Olaf Zimmermann): "In the context of X, facing Y, we decided to Z and accept consequences C". One sentence per decision. Good for tiny decisions.
- **Lightweight Architectural Decision Records** (Tyree & Akerman, IEEE 2005) — heavier template with related decisions, etc. Use when ADRs feed into a formal architecture process.

For most teams, the format above is the right level. Keep it terse — one screen is plenty.

## References

- Michael Nygard's original ADR post (cognitect.com/blog/2011/11/15/documenting-architecture-decisions) — the seed for the modern format.
- adr.github.io — collected templates, tooling, examples.
- "Building Evolutionary Architectures" (Ford, Parsons, Kua) — ADRs as a tool for evolutionary architecture.
- adr-tools (npm: `adr-tools`, or Go: `adr`) — CLI to scaffold + supersede ADRs.
