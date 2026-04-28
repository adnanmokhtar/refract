# Documentation Principles

Prevents the failure mode that's worse than missing docs: stale docs that actively mislead.

## Must

- Docs describe what IS in the codebase right now. If reality changes, docs change in the SAME PR. Reviewer rejects mismatched diffs.
- Architectural decisions go in `ai/decisions/<NNNN>-<slug>.md` as ADRs (Context / Decision / Consequences) — not in `README.md`, not in inline comments.
- Every README opens with: 1) what this is, 2) how to run it, 3) how to test it. Anything below those three is bonus.
- Non-obvious claims cite code: file path + line range, migration ID, or commit SHA. "The service caches users" with a link beats the assertion alone.
- `ai/status.md` carries an `Updated:` line in `YYYY-MM-DD` and a `## Recent Changes` section. SessionStart hooks parse these — don't break the format.
- A new module ships with a one-line entry in `ai/modules.md` (path + purpose) in the same PR.
- API endpoints are documented in machine-readable form (OpenAPI / GraphQL SDL / JSDoc-typed RPC), never only in prose.
- Every public class, interface, enum, and exported function has a one-sentence JSDoc / TSDoc / Pydoc explaining purpose. (See `.claude/rules/jsdoc.md` if present.)
- Step-by-step procedures are numbered checklists, not paragraphs. One observable action per step.
- Comparisons are tables. Multi-axis bullet lists hide structure.

## Must not

- Duplicate code in prose: `// returns the user by id` on `getUserById()`. Drift is guaranteed; readers train themselves to skip docstrings.
- Multi-paragraph docstrings on obvious methods. Signal collapses.
- Tutorials that re-walk a working `README.md`. The README IS the tutorial.
- Weasel words: "It is important to note that...", "obviously", "simply". Padding without information; "simply" usually fronts something complicated.
- Reference a PR / ticket / caller in committed prose ("Added for PR-1234"). Prose outlives tickets — use `git blame`.
- Mark a doc "TBD" without owner + date. An undated TBD is permanent rot.
- Claim performance numbers without linking the benchmark or load-test artifact.
- Aspirational architecture written as if it exists ("the system uses event sourcing" when it has one EventEmitter). Use ADRs for plans.

## Should

- One screen of bullets > three paragraphs of prose. If readers must scroll, split into sub-pages.
- Diagrams (Mermaid / PlantUML in markdown) for sequence flows, lifecycles, data flow with > 3 actors.
- Table of contents on any file > 100 lines.
- Link to source over copy-pasting it. Source rot is detectable; copy-paste rot is silent.
- ADRs at decision time, not retroactively — the lost context is the whole point.
- Present tense, active voice. "The service caches results" beats "Results will be cached by the service."

## Skeletons

### Module entry in `ai/modules.md`

```
| Module | Path | Purpose |
|---|---|---|
| country | apps/master/src/country | CRUD + translations for country entities |
```

One row, one line, same PR as the module.

### ADR

```markdown
# 0042: Switch from PostgreSQL to MySQL

Status: Accepted
Date: 2026-04-24
Deciders: @platform-team

## Context
<one paragraph: the problem>

## Decision
<one paragraph: what we're doing>

## Consequences
- Positive: …
- Negative: …
- Follow-up: …
```

### `ai/status.md`

```markdown
Updated: 2026-04-24

## Current state
…

## In-flight work
…

## Tech debt
…

## Recent Changes
- 2026-04-24: …
```

### Runbook

```markdown
# Runbook: Restoring from a corrupted Redis instance

When: error rate > 5% on cache reads, Redis CPU saturated.
On-call: @platform

1. Verify in Grafana that Redis is the bottleneck (link).
2. …
3. Post-incident: file a ticket linking back to this run.
```

## Anti-patterns to flag in review

- Doc says "we use X" but `package.json` / `requirements.txt` shows Y → fix one of them in the PR.
- ADR phrased as a tutorial → three sections only: Context / Decision / Consequences.
- README listing 30 npm scripts → link to `package.json`, document only non-obvious ones.
- Inline comment paraphrasing the next line → delete it; rename the variable instead.
- Wiki / external link without a permalink (defaults to "latest") → link to a specific revision/SHA.
- Long FAQ where the answers belong in source → fix the source.
- "How to set up" no one re-tested in 6 months → automate via `make setup` / `bun run setup` and document the script.

## Review checklist

- [ ] Reality matches the doc as of this PR.
- [ ] New module → `ai/modules.md` entry.
- [ ] Architectural change → ADR.
- [ ] Status touched → `Updated:` line refreshed.
- [ ] No `TBD` without owner + date.
- [ ] No duplicate-of-code prose.

## Enforcement

- `markdownlint` in pre-commit: heading levels, trailing whitespace, link syntax.
- `lychee` / `markdown-link-check` in CI for broken links.
- CI grep for `TBD` / `TODO(no-owner)` patterns in `ai/` fails the build.
- CI parses `ai/status.md` `Updated:` and warns when older than 90 days on changed branches.
- Code review checklist enforces "feature PR → docs PR" coupling.

## When rules conflict with a task

- Shipping a feature and docs are wrong → fix docs in the SAME PR. Don't file a follow-up.
- Doc is fully stale and no one will re-validate → delete it in the PR; reference deletion in the commit.
- Draft / aspirational doc in `README.md` → move to `ai/decisions/` as a Proposed ADR.
- Two docs disagree → code is the source of truth; rewrite the loser in the same PR.

## References

- Michael Nygard, "Documenting Architecture Decisions" (the original ADR essay).
- Diátaxis framework: tutorials / how-tos / reference / explanation — diataxis.fr.
