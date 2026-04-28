# Workspace rules

Apply when Claude is rooted at the workspace parent directory.

## Read-before-edit across repo boundaries

- Per-repo `.claude/rules/` do NOT auto-load across boundaries.
- Before editing any file inside a sibling repo, **first `Read` that repo's root `CLAUDE.md`**. It's your only signal for per-repo conventions at this level.

## Scope

- Only edit files in the registered sibling repos (see `PROJECTS.md`).
- Don't touch sibling directories outside the registry without explicit approval.

## Sequencing

- **API first, frontends after.** Contract changes go in the API repo; frontends consume the new contract.
- If a frontend-only change would require an API change, flag and stop — don't patch the frontend around a missing API change.

## i18n (if multiple locales)

- Any user-facing string added to a frontend MUST be added to BOTH locales.
- Across frontends, prefer the SAME key name for the same concept.

## Commits

- Each sibling has its own git remote.
- Don't commit across repos in one step. Edit all affected repos, then commit each separately.
- Leave commit approval to the user.

## Don't

- Commit across repos
- Skip reading per-repo `CLAUDE.md`
- Assume siblings use the same patterns (v1 vs v2, Options vs Composition API, etc.)
- Apply a frontend change that depends on an unshipped API change
