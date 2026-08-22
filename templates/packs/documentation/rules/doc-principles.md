---
name: doc-principles
description: Documentation Principles
kind: rule
pack: documentation
severity: must
applies-to: documentation-track, every-code-writing-task-in-documentation
---

# Documentation Principles

> **Hard rule.** Docs MUST describe what IS in the codebase right now. When code changes, docs change in the SAME PR — no follow-up tickets. Architectural decisions live in `ai/decisions/<NNNN>-*.md` ADRs, status timestamps stay current, and aspirational claims (features that don't exist yet) are forbidden in any non-ADR doc.

Prevents the failure mode that's worse than missing docs: stale docs that actively mislead.

## Must

- Docs describe what IS in the codebase right now. If reality changes, docs change in the SAME PR. Reviewer rejects mismatched diffs.
- Architectural decisions go in `ai/decisions/<NNNN>-<slug>.md` as ADRs (Context / Decision / Consequences) — not in `README.md`, not in inline comments.
- Every README opens with: 1) what this is, 2) how to run it, 3) how to test it. Anything below those three is bonus.
- Non-obvious claims cite code: file path + line range, migration ID, or commit SHA. "The service caches users" with a link beats the assertion alone.
- `ai/status.md` carries an `Updated:` line in `YYYY-MM-DD` and a `## Recent Changes` section. SessionStart hooks parse these — don't break the format.
- A new module ships with a one-line entry in `ai/modules.md` (path + purpose) in the same PR.
- API endpoints are documented in machine-readable form (OpenAPI / GraphQL SDL / JSDoc-typed RPC), never only in prose.
- Every public class, interface, enum, and exported function carries a one-sentence docstring stating its CONTRACT — what it guarantees, assumes, raises — not a restated signature.
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

- Prefer one screen of bullets over three paragraphs of prose. If readers must scroll, split into sub-pages.
- Diagrams (Mermaid / PlantUML in markdown) for sequence flows, lifecycles, and data flow with > 3 actors.
- Add a table of contents to any file > 100 lines.
- Link to source over copy-pasting it. Source rot is detectable; copy-paste rot is silent.
- Write ADRs at decision time, never retroactively — the lost context is the whole point.
- Use present tense, active voice. "The service caches results" beats "Results will be cached by the service."

### Four docs that must be PROVEN, not written

Each is a doc whose truth is checkable by running something. Reading it is not the check.

| Doc surface | Proven by | Run (skill, when installed) |
|---|---|---|
| Setup / getting-started | executing every step in a CLEAN env — a warm-machine pass certifies broken docs | `quickstart-verify` (reports time-to-first-green) |
| Architecture diagram | diffing it against the real module/import graph — a box naming a deleted module misleads with the authority of a picture | `diagram-sync` |
| Public-API docstrings | measuring coverage on the PUBLIC surface against the project's OWN linter convention; a re-spelt signature is a zero-information gap that green-lights the count | `docstring-coverage` |
| Release notes | deriving them from categorized commit/PR history, breaking-first with before → after, semver bump COMPUTED from the change types | `changelog-generate` (an unclassifiable commit is a reportable gap, not a silent drop) |

## The two formats this rule owns

The ADR and runbook skeletons are NOT duplicated here: `ai/patterns/adr-template.md` owns the ADR format (with a worked example), `/add-runbook` owns the runbook template. Two homes for one skeleton is how they drift apart. These two are machine-parsed contracts, so they live here:

- **`ai/modules.md`** — `| Module | Path | Purpose |`, one row per module, added in the same PR as the module. Use the layout Phase 2 detected in THIS codebase; don't invent one.
- **`ai/status.md`** — first line `Updated: YYYY-MM-DD`, and a `## Recent Changes` heading with newest first. SessionStart hooks parse exactly those two; other sections are free-form.

## In review — reject on sight

- A doc claim the diff contradicts (renamed path, deleted symbol, dropped env var) → fix in THIS PR, not a follow-up.
- Doc says "we use X" but the dependency manifest shows Y → one of them is wrong; fix it here.
- Inline comment paraphrasing the next line → delete it and rename the variable instead.
- External / wiki link with no permalink (resolves to "latest") → pin a revision or SHA.
- `TBD` with no owner and no date; a new module with no `ai/modules.md` row; an architectural change with no ADR.

## Enforcement

- `markdownlint` in pre-commit: heading levels, trailing whitespace, link syntax.
- `lychee` / `markdown-link-check` in CI for broken links.
- CI grep for `TBD` / `TODO(no-owner)` patterns in `ai/` fails the build.
- CI parses `ai/status.md` `Updated:` and warns when older than 30 days on changed branches (the same threshold `doc-writer`, `/doc-refresh` and `doc-drift-scan` use — one number, one meaning).
- Code review checklist enforces "feature PR → docs PR" coupling.

## When rules conflict with a task

- Shipping a feature and docs are wrong → fix docs in the SAME PR. Don't file a follow-up.
- Doc is fully stale and no one will re-validate → delete it in the PR; reference deletion in the commit.
- Draft / aspirational doc in `README.md` → move to `ai/decisions/` as a Proposed ADR.
- Two docs disagree → code is the source of truth; rewrite the loser in the same PR.

## References

- Michael Nygard, "Documenting Architecture Decisions" — cognitect.com/blog/2011/11/15/documenting-architecture-decisions (the original ADR essay).
- Diátaxis — diataxis.fr (tutorial / how-to / reference / explanation: the four modes, and why mixing two in one page is the defect).
- Keep a Changelog — keepachangelog.com (the release-notes format `changelog-generate` emits).
