---
phase: 1
name: detect-mode
applies-to-modes: [all]
inputs: [target-repo, user-flags]
outputs: [mode (CREATE | ENHANCE | REFRESH | REFINE), repo-shape (single | monorepo | workspace)]
exit-criteria: mode + shape decided and recorded
---

### Phase 1 — Detect mode

Inspect cwd in parallel:
- `git status` (repo y/n)
- Manifests: `package.json`, `pyproject.toml`, `composer.json`, `go.mod`, `Gemfile`, `Cargo.toml`, `mix.exs`, `build.gradle`, `pom.xml`
- `CLAUDE.md` / `.claude/` / `ai/` presence + contents
- Source file count

Decide mode:

| Signal | Mode |
|---|---|
| `--refine` flag set AND existing `.claude/` artifacts present (≥1 generated agent/skill/rule/command) | **REFINE** (skip Phase 0 backup unless `--refresh` also set; jump to Phase 2 + Phase 2.7–2.12 deep extraction; then Phase 4.6-DEEP re-anchor; then Phase 4.7-DEEP ai/ refresh; then Phase 4.8-DEEP adapter sync; then Phase 5 verify; then Phase 5.5 quality score) |
| `--refine` flag set AND nothing to refine (no `.claude/` artifacts) | User error — refuse. Suggest plain `/setup-project` (CREATE) first. |
| `--refresh` flag set AND existing `.claude/` or `ai/` present | **REFRESH** (run Phase 0 first; then continue with prior-knowledge-aware variants of Phase 2/4) |
| `--refresh` flag set AND nothing to back up | User error — refuse. Suggest plain `/setup-project` (CREATE) instead. |
| No source, no `.claude/`, no `CLAUDE.md`, no `ai/` | **CREATE** |
| Source exists but `.claude/` or `ai/` missing | **ENHANCE-retrofit** |
| `.claude/` + `ai/` + `CLAUDE.md` all present | **ENHANCE-extend** |
| Ambiguous | Ask ONE consolidated question |

Announce mode in one line. Respect `--create` / `--enhance` / `--refresh` / `--refine` flag overrides per the precedence table in Quick Start.

**REFINE-specific**: announce includes the per-artifact anchor-density baseline + the deep-extraction items count:
```
Mode: REFINE (--refine)
  Existing setup: 18 artifacts (4 agents, 6 skills, 5 rules, 3 commands)
  Baseline anchor-density: 47/100 (4 artifacts ≥ 70 "anchored", 14 < 70 "shallow")
  Deep-extraction queued: domain entities, architecture, flows, conventions, hot paths, failure history
  Will rewrite: only `## Project-specific` blocks of shallow artifacts
  User-authored sections: preserved verbatim
  Target: ≥ 70/100 anchor-density per shallow artifact (or "plateau reached")
  Tool adapters selected: cursor, opencode, aider (will re-sync after 4.6-DEEP / 4.7-DEEP)
  Proceeding to Phase 2.7 → 2.12 (deep extraction) → 4.6-DEEP → 4.7-DEEP → 4.8-DEEP (adapter sync) → 5 (verify) → 5.5 (quality score).
```

**REFRESH-specific**: announce includes the backup path AND the extract-item count from Phase 0:
```
Mode: REFRESH (--refresh)
  Backup: .claude/backups/20260425-1430/ (47 files, 312KB)
  Extracted: 23 durable items across 8 categories (see .claude/_refresh-knowledge-extract.md)
  Proceeding to Phase 2 (deep profile + extract merge), then Phase 2.5 (idioms),
  then Phase 2.6 (profile-informed coverage gap check), then Phase 3 (delta + plan).
```

