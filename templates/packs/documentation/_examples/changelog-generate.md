---
name: changelog-generate
description: Generate a categorized changelog / release notes from commit + PR history (conventional-commits · semver). Groups feat/fix/breaking, surfaces breaking changes with migration notes, and derives the semver bump — never hand-written from memory or a raw git-log dump.
---

# changelog-generate

A changelog is *generated from categorized history* — conventional-commit types or PR labels grouped for humans — breaking changes at the top, the version bump *derived* from the change set. Not hand-written from memory, not a raw `git log` dump. The reader wants three answers in order: what breaks me, what's new, what's fixed.

## Premise

Cite-or-halt. Every line traces to a commit SHA or PR number; every breaking entry cites the commit/PR + the marker that classified it (`BREAKING CHANGE:` footer, `feat!:`, a `breaking`/`major` label). Every semver claim cites the type tally. An unclassifiable commit is a reportable convention gap, not something to silently drop.

## When to run

- At release-cut time — notes for the range since the last tag.
- In CI on the release branch to keep the `Unreleased` section current.
- After a run of unconventional commits — surface the classification gap before release day.

## Procedure (abridged)

1. Range: previous tag → HEAD; record it in the header so notes are reproducible.
2. Parse each commit / PR into a typed change (type, scope, `!`, `BREAKING CHANGE:` footer, or PR label).
3. Flag `UNCLASSIFIED` — don't silently omit a real change.
4. Group breaking-first: ⚠ Breaking → Features → Fixes → Performance → other; drop pure chore/ci noise.
5. Derive the bump: any breaking → major; else any feat → minor; else patch. Flag `BUMP-MISMATCH`.
6. Emit Keep a Changelog format; diff a hand-maintained CHANGELOG.md (MISSING / PHANTOM).

## Output (abridged)

```
changelog-generate — v2.3.1..HEAD · 27 commits, 9 PRs · convention: conventional-commits
Derived bump: MINOR → v2.4.0  (1 feat, 4 fix, 0 breaking; highest = feat ⇒ minor)
  ⚠ BUMP-MISMATCH: release.yml proposes v2.3.2 (patch) but a feat shipped → should be v2.4.0.

### Features    - Bulk order export as CSV (#412)
### Fixes       - Refund rounding on partial refunds (#418)
### Performance - Order-list query 340ms → 45ms via covering index (#419)

CONVENTION GAP — 3 UNCLASSIFIED: a1b2c3d "wip"; d4e5f6a "fix stuff"; 9f8e7d6 mixed feat+chore.
```

## Halt conditions

- Refuse notes that silently omit UNCLASSIFIED commits — list them + their SHAs.
- Refuse a semver bump not justified by the type tally; on BUMP-MISMATCH, surface it and stop short of tagging.
- A breaking change renders at the top with a before → after migration note; never author entries from memory.

## Related

- `add-adr.md` (command) — the ADR records *why a decision was made*; the changelog records *what shipped*. A breaking change here points at the ADR that decided it.
- `doc-refresh.md` (command) — reconciles `ai/status.md` `Updated:` + `## Recent Changes` after a release; `@doc-writer` sharpens the entry prose.
