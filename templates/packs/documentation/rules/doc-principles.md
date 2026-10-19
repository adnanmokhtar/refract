---
name: doc-principles
description: Documentation Principles
kind: rule
pack: documentation
severity: must
applies-to: documentation-track, every-code-writing-task-in-documentation
---

# Documentation Principles

> **Hard rule.** Docs MUST describe what IS in the codebase right now. When code changes, docs change in the SAME PR — no follow-up tickets. Decisions live in ADRs, status timestamps stay current, and aspirational claims (features that don't exist yet) are forbidden outside an ADR.

Prevents the failure mode that's worse than missing docs: stale docs that actively mislead.

## Must

- Docs describe what IS in the codebase now; a code change and its doc change ship in the SAME PR.
- Architectural decisions go in the project's ADR folder (`/add-adr` finds it) as ADRs (Context / Decision / Consequences) — not in `README.md`, not in inline comments.
- Every README opens with: 1) what this is, 2) how to run it, 3) how to test it. Anything below those three is bonus.
- Non-obvious claims cite code: file path + line range, migration ID, or commit SHA. "The service caches users" with a link beats the assertion alone.
- `ai/status.md` carries an `Updated:` line in `YYYY-MM-DD` and a `## Recent Changes` section. SessionStart hooks parse these — don't break the format.
- A new module ships with a one-line entry in `ai/modules.md` (path + purpose) in the same PR.
- API endpoints are documented in machine-readable form (OpenAPI / GraphQL SDL / JSDoc-typed RPC), never only in prose.
- The exported surface only (precedence A4): every public class, interface, enum and exported function has a one-sentence CONTRACT docstring — guarantees, assumes, raises — not a restated signature.
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
| Every other claim (paths, scripts, flags, env, endpoints, links, ADRs, samples) | resolving it against its oracle | `/doc-refresh --audit` |

## The two formats this rule owns

The ADR and runbook skeletons live in `ai/patterns/adr-template.md` and `/add-runbook`, not here: two homes for one skeleton drift apart. These two are machine-parsed contracts, so they live here:

- **`ai/modules.md`** — `| Module | Path | Purpose |`, one row per module, added in the same PR as the module. Use the layout Phase 2 detected in THIS codebase; don't invent one.
- **`ai/status.md`** — first line `Updated: YYYY-MM-DD`, and a `## Recent Changes` heading with newest first. SessionStart hooks parse exactly those two; other sections are free-form.

## In review — reject on sight

- A doc claim the diff contradicts (renamed path, deleted symbol, dropped env var) → fix in THIS PR, not a follow-up.
- Doc says "we use X" but the dependency manifest shows Y → one of them is wrong; fix it here.
- Inline comment paraphrasing the next line → delete it and rename the variable instead.
- External / wiki link with no permalink (resolves to "latest") → pin a revision or SHA.
- `TBD` with no owner and no date; a new module with no `ai/modules.md` row; an architectural change with no ADR.

## Enforcement

A gate counts only after it has failed once on a planted defect (the DL-4 mutation proof):

- `doc-claims.py . --check` (`doc-drift-scan`'s engine) in CI on pull requests: exit 1 on a MISS or WRONG claim.
- The repo's own link, lint, site, sample and breaking-change gates, each in its failing setting: `doc-structure-scan` §4 lists them and flags one that cannot fail.
- `ai/status.md` `Updated:` older than 30 days on a changed branch warns (one threshold everywhere); `/doc-refresh` (default mode) is the pre-PR check.

## When rules conflict with a task

- Shipping a feature and docs are wrong → fix docs in the SAME PR. Don't file a follow-up.
- Doc is fully stale and no one will re-validate → delete it in the PR; reference deletion in the commit.
- Draft / aspirational doc in `README.md` → move it to the ADR folder as a Proposed ADR (`/add-adr`).
- Two docs disagree → code is the source of truth; rewrite the loser in the same PR.

## References

- Michael Nygard, "Documenting Architecture Decisions" — cognitect.com/blog/2011/11/15/documenting-architecture-decisions.
- Diátaxis — diataxis.fr (four modes; mixing two in one page is the defect).
- Keep a Changelog — keepachangelog.com (the release-notes format `changelog-generate` emits).
