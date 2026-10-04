---
artifact: precedence
purpose: Which rule wins when two Refract rules disagree, and the log of every conflict found and how it was settled. The 8-line core is carried by the always-on rule `.claude/rules/engineering-baseline.md`; this file is the full version.
imported-by: templates/repo-baseline/.claude/rules/engineering-baseline.md (core), scripts/lint-rule-conflicts.sh (the conflict log below is its fixture list)
---

# Precedence — one truth per fact

## The order

1. **Hooks and settings** — mechanical — outrank all prose. A rule that contradicts what a hook enforces is wrong; fix the rule.
2. **Engineering-baseline row = floor** (`governance/engineering-baseline/`). It may be tightened, never loosened. It outranks the sibling you mirror and the V1 you port: a missing guarantee is fixed in this change or reported `UNMET`, never copied. Mirroring governs only what the baseline is silent on — naming, layout, error type, DI.
3. **Regulatory overlay** (`templates/regulatory-overlays/`): the stricter of the overlay and the rule wins.
4. **Domain rule**, inside its domain (by path or by the signal that installed it).
5. **Stack pack rule** (backend, frontend, mobile, database, …).
6. **Generic pack rule** (code-quality, testing, documentation, …).
7. **Project conventions and siblings** — shape only, never a guarantee.
8. **Template docs and examples** (`_examples/`, `ai-patterns/` worked samples).

**Ties** go to the stricter rule on security and data integrity, and to the more specific rule otherwise. **Numbers** live in `governance/thresholds.json`; a rule cites the id (`THR-RES-RETRY`) instead of restating the value, so two rules cannot drift apart on it. A project overrides a value in `.claude/thresholds.local.json` — tighten-only where the entry says `"floor": true`.

**An unresolved conflict is reported, never picked silently.** Name both rules (`file:line` each), the reading you chose, and why; the owner settles it and the settlement is added to the log below.

## Conflict log

Each row: the conflict, the winner, the registry id it now cites, and the files that carry the resolution. `scripts/lint-rule-conflicts.sh` reads this table: a `resolved` row fails the build when the losing wording reappears in a named file; an `open` row is counted, and the count may not grow.

| ID | Conflict | Winner | Cites | Resolved in | Status |
|---|---|---|---|---|---|
| A1 | Boy Scout "clean what's adjacent" vs surgical "every changed line traces to the request" | surgical; Boy Scout only on lines the change already touches | — | `repo-baseline/.claude/rules/think-simplify-surgical.md` § 3 (dangling `commands/setup-project.md` pointer removed), `governance/hard-rules.md` A17 | resolved (baseline side); `packs/code-quality/rules/quality-principles.md` Boy Scout bullet open |
| A2 | `TODO` needs a ticket vs owner + delete-by date | owner + delete-by date; a ticket is optional, never a substitute | `THR-TODO` | `repo-baseline/.claude/rules/code-quality.md` | resolved (baseline side); `packs/testing/rules/testing-principles.md` open |
| A4 | docstrings on every export vs "no comments" | contract docstrings on the exported surface only; internal code keeps the no-comment default | — | `repo-baseline/.claude/rules/code-quality.md` § Should, `packs/documentation/rules/doc-principles.md` | resolved |
| A5 | 30-line function cap vs "no portable threshold" | the project's configured linter value | `THR-FN-LEN` | `governance/thresholds.json` | open — the 30-line literal lives in `packs/code-quality/rules/quality-principles.md` |
| A7 | 429 never retried (RES-4 "never on a 4xx") vs retryable (integrations, jobs, notifications) | retry 408/429 no sooner than `Retry-After`, jitter required | `THR-RES-RETRY` | `governance/engineering-baseline/backend-api.md` RES-4, `packs/backend/rules/backend-principles.md` | resolved |
| A9 | recovered catch logged at `debug` (migration) vs `warn` (observability) | `warn` | `THR-LOG-LEVEL` | `packs/migration/rules/migration-discipline.md`, `packs/migration/ai-patterns/migration-guardrails.md`, `packs/observability/rules/observability-principles.md` | resolved |
| A12 | RLS as the isolation (DATA-11) vs app-layer tenant filter (multi-tenancy) | app layer primary; RLS a backstop, never the only filter | — | `governance/engineering-baseline/data.md` DATA-11 | resolved |
| A13 | tenant FK `ON DELETE CASCADE` vs immutable ledger / audit rows | `RESTRICT` on append-only ledger / audit / event tables, erased by crypto-shred | — | `domains/multi-tenant/rules/multi-tenancy.md`, `domains/multi-tenant/ai-patterns/tenant-isolation.md` | resolved |
| A14 | `DECIMAL(19,4)` vs integer minor units | DATA-9 is the floor (exact decimal or minor units, never float); inside payments and ledgers minor units win | `THR-MONEY` | `governance/engineering-baseline/data.md` DATA-9, `packs/database/rules/database-principles.md` | resolved |
| A27 | baseline outranks the sibling vs "don't silently fix a pattern" | baseline wins for guarantees; shape still mirrors the sibling | — | `repo-baseline/.claude/rules/engineering-baseline.md` (core), `read-before-write.md`, `think-simplify-surgical.md` § 3 | resolved |
| A28 | DRY at 2 vs at 3 | reuse an existing implementation at 2; extract a new one at 3 | `THR-DRY` | `repo-baseline/.claude/rules/think-simplify-surgical.md` § 2 | resolved (baseline side); `packs/code-quality/rules/*` open |
| A30 | re-validate at service boundaries vs "inside the system, types are the contract" | security wins at every trust boundary; inside one trust domain types are the contract | — | `repo-baseline/.claude/rules/code-quality.md`, `governance/engineering-baseline/backend-api.md` SEC-01 | resolved (baseline side); `packs/code-quality/rules/quality-principles.md` "don't re-validate" open |

The original evaluation listed 34 conflicts (A1–A34); the twelve above are the ones the architecture proposal ranked first. The rest are not lost — they are re-derived and added here as they are settled.

## Waivers are not precedence

A project that deliberately departs from a baseline row records an ADR and a `WAIVED(owner, expiry, reason, ticket)` entry (`THR-WAIVER`). Precedence decides between two rules; a waiver suspends one rule for one project, for a bounded time, by a human.
