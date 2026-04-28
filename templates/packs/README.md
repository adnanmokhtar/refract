# Packs — role-based artifact tracks

Each pack ships a curated bundle of agents / commands / skills / rules / patterns / runbooks for one role or concern (e.g. `backend`, `frontend`, `security`, `database`). `/setup-project` selects packs based on detected stack, business domain, and user `--include` flags.

## Pack folder shape

```
templates/packs/<pack-name>/
├── _version.json          # REQUIRED — version stamp (kind: "pack", version, released, summary)
├── _essentials.md         # REQUIRED — load-bearing files in this pack (the minimum-viable subset)
├── _topics.md             # REQUIRED — what topics this pack covers (one section per topic)
├── _examples/             # OPTIONAL — fully-realized example artifacts (cookbook style)
├── agents/*.md            # specialized personas
├── commands/*.md          # slash commands
├── skills/<name>/SKILL.md # scripted procedures
├── rules/*.md             # prose rules / guardrails
├── ai-patterns/*.md       # worked-example patterns (loaded into ai/patterns/ at apply)
├── references/*.md        # reference material (loaded into ai/references/ at apply)
└── runbooks/*.md          # step-by-step ops/dev runbooks
```

### `_essentials.md` vs `_examples/`

`_essentials.md` lists the **always-loaded** subset of the pack (kept tight to control context burn). Everything else in the pack is opt-in via `--include` or auto-included when relevant.

`_examples/` is **optional**. When `/setup-project` Phase 4.2-AUTHOR needs a concrete-shape example to seed an artifact for the project, it falls back in this order:

1. If `_examples/<artifact-name>` exists → use it as the structural template (still rewritten with project specifics).
2. Else if `_topics.md` describes the topic in enough detail → generate a stub from the topic description.
3. Else → copy the closest literal template file from this pack and inject project specifics.

**Pack authors don't need to fill `_examples/` for every artifact.** If you skip it, fallbacks 2 and 3 still produce a viable artifact. Half-filling `_examples/` (some artifacts have examples, others don't) is acceptable — the fallback chain handles it cleanly.

### `_version.json`

Every pack MUST have a `_version.json`. Bump the version when:
- A new artifact is added → minor bump.
- An artifact is renamed or removed → major bump (writes a `deprecated.md` mapping note).
- An artifact's body changes substantively (not just typo fixes) → patch bump.

`/setup-project` Phase 1.1 reads `_version.json` files for drift detection at session-start. Without a version stamp, drift detection silently skips that pack.

## When pack content changes

Phase 4.6 (STUDY → DECIDE → ACT) is what reconciles new pack content against project-authored files in existing repos. As a pack author, your job is to ship clean templates; Phase 4.6 handles the merge into existing projects.

## Adding a new pack

1. Create `templates/packs/<new-pack>/` with the required files (`_version.json`, `_essentials.md`, `_topics.md`).
2. Add at least one of: `agents/`, `commands/`, `skills/`, `rules/`, `ai-patterns/`, `runbooks/`.
3. Update `templates/packs/_trigger-vocabulary.md` with detection signals for this pack.
4. If the pack should be added by default for a profile, update `setup-project.md` Phase 4.0 minimums table.
5. Run `scripts/seed-versions.sh` to confirm the version file is well-formed.

## See also

- `_trigger-vocabulary.md` — auto-detection signals → pack mapping.
- `templates/repo-baseline/` — what every project gets regardless of pack selection.
- `templates/tool-adapters/_registry.md` — capability matrix for tool adapters (orthogonal to packs).
- `commands/setup-project.md` — the orchestrator that consumes everything here.
