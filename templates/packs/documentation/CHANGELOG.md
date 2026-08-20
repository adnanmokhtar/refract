# documentation pack — changelog

Release history for `templates/packs/documentation/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.5.0 — 2026-07-10

- doc-refresh production bar — regenerate→diff→cite: three wired gates (drift via doc-drift
  detector, examples run, links resolve); divergence from code = STALE.
- add-runbook: command-resolution gate re-derives every step's script/target/path from the repo;
  unresolved = BROKEN.

## 1.4.1 — 2026-07-10

- api-documenter: SDK-generation gains a regenerate->diff->cite gate + the quality checklist gains
  cite-or-halt (every box cites the spec/code proof) — was 1 of 4 sub-jobs verified. add-runbook:
  linked-ADR/feature path-existence check (halt on dangling link) + an undrilled runbook is honestly
  marked 'not-yet-run' instead of silently accepted.

## 1.4.0 — 2026-07-10

- skills +3: diagram-sync (C4/mermaid generated from the real dep graph + drift check),
  docstring-coverage (public-API docstring gap + gate), changelog-generate (categorized changelog
  from conventional-commit/PR history).

## 1.3.0 — 2026-07-09

- skills +1: quickstart-verify — executes the README/getting-started setup in a clean env to PROVE
  onboarding works (the smoke-verify leap for docs), distinct from doc-writer's prose authoring.
  Backing SHOULD in doc-principles.
