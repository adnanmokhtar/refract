---
phase: 1
name: detect-mode
applies-to-modes: [all]
inputs: [target-repo, user-flags]
outputs: [mode (CREATE | ENHANCE | REFRESH | REFINE), repo-shape (single | monorepo | workspace)]
exit-criteria: mode + shape decided and recorded
---

### Phase 1 — Detect mode

**Lightweight mode**: Commands invoked with `--lightweight` skip Phase 2.7-2.12 (deep extraction) + Phase 4.6/4.7 (re-anchoring) and jump from Phase 4.2-apply directly to Phase 5-verify. Trade-off: no anchor-density refinement, ~80% faster. Use for trivial pack additions, status checks, lightweight commands. Default is full ceremony unless `--lightweight` is passed OR the command's frontmatter declares `mode: lightweight`.

Inspect cwd in parallel:
- `git status` (repo y/n)
- Manifests: `package.json`, `pyproject.toml`, `composer.json`, `go.mod`, `Gemfile`, `Cargo.toml`, `mix.exs`, `build.gradle`, `pom.xml`
- `CLAUDE.md` / `.claude/` / `ai/` presence + contents
- Source file count
- **Workspace manifests** (member-declaring): `pnpm-workspace.yaml`, `package.json` → `workspaces`, `lerna.json` → `packages`, `nx.json`, `go.work`, `Cargo.toml` → `[workspace] members`, `turbo.json`, and `PROJECTS.md`
- **Sub-manifest inventory** — for every immediate subdirectory, and every subdirectory of `apps/`, `packages/`, `services/`, `libs/`, `modules/`, `src/`: does it carry its OWN manifest from the list above? Skip `node_modules`, `dist`, `build`, `out`, `target`, `vendor`, `.git`, `.venv`, `__pycache__`, `.next`, `coverage`. Record each hit as `<dir> → <manifest>`, plus whether `<dir>/.git` exists.

Decide mode:

| Signal | Mode |
|---|---|
| `--upgrade` flag set AND existing `.claude/` present | **UPGRADE** — first run `~/.claude/scripts/migrate-setup.sh "$TARGET_REPO"` to migrate the setup artifacts from their recorded version to the current schema (idempotent; backs up first), THEN continue as **REFRESH** (Phase 0 → prior-knowledge-aware Phase 2/4). `--upgrade` without existing `.claude/` is a user error — suggest plain `/setup-project` (CREATE). |
| `--refine` flag set AND existing `.claude/` artifacts present (≥1 generated agent/skill/rule/command) | **REFINE** (skip Phase 0 backup unless `--refresh` also set; jump to Phase 2 + Phase 2.7–2.12 deep extraction; then Phase 4.6-DEEP re-anchor; then Phase 4.7-DEEP ai/ refresh; then Phase 4.8-DEEP adapter sync; then Phase 5 verify; then Phase 5.5 quality score) |
| `--refine` flag set AND nothing to refine (no `.claude/` artifacts) | User error — refuse. Suggest plain `/setup-project` (CREATE) first. |
| `--refresh` flag set AND existing `.claude/` or `ai/` present | **REFRESH** (run Phase 0 first; then continue with prior-knowledge-aware variants of Phase 2/4) |
| `--refresh` flag set AND nothing to back up | User error — refuse. Suggest plain `/setup-project` (CREATE) instead. |
| No source, no `.claude/`, no `CLAUDE.md`, no `ai/` | **CREATE** |
| Source exists but `.claude/` or `ai/` missing | **ENHANCE-retrofit** |
| `.claude/` + `ai/` + `CLAUDE.md` all present | **ENHANCE-extend** |
| Ambiguous | Ask ONE consolidated question |

Decide shape — **mandatory, not optional; it is the second declared output of this phase.**

`repo-shape` is what Phase 2 § 17 splits the profile on, what Phase 4.0 gates sub-project recursion on, and what Phase 4.2 derives `is-multi-track` from. Leaving it unset does not make the run neutral — it silently routes a multi-deployable repo down the single-package path, which averages two packages' conventions into one blended value that is wrong for both. **Decide it from the signals above; never skip to Phase 2 without it.**

| Signal (first match wins) | Shape |
|---|---|
| A workspace manifest declares members (`pnpm-workspace.yaml`, `package.json` `workspaces`, `lerna.json` `packages`, `nx.json`, `go.work`, `Cargo.toml` `[workspace] members`; `turbo.json` only alongside one of those) | **workspace** — members = the declared list, expanded per Phase 4.0 § Sub-project enumeration |
| `PROJECTS.md` at the root with a registered-repos table | **workspace** — members = the table rows |
| ≥2 sub-manifest dirs AND (cwd is not a git repo, OR each member dir has its own `<dir>/.git`) | **workspace** — the *sibling-directory* shape: independent repos parked under one parent with no workspace tool. Members = the dirs holding those manifests |
| ≥2 sub-manifest dirs, all inside ONE git repo, with no member-declaring manifest | **monorepo** — one repo, several deployables. Members = the dirs holding those manifests |
| Root manifest + exactly one sub-manifest dir | **single** — a lone nested package (a tooling helper, a docs site, an example app) is not a second deployable |
| Everything else | **single** — members = `[.]` |

Two things that table is deliberate about:

- **The last three rows are the ones that were missing.** Detection by workspace manifest alone covers only rows 1–2. A repo with a server directory and a client directory and no workspace tool — and a parent folder holding two checked-out repos — are both extremely common and both matched *nothing* before. They now land on `monorepo` and `workspace` respectively.
- **`monorepo` ≠ `workspace`, and the difference is the git boundary.** One git repo means one `.claude/`, one `ai/`, one commit — so a `monorepo` is NOT recursed like a workspace. What it gets instead is a per-member *profile*: Phase 2 § 17 records one entry per member and every code-shaped profile field is answered once per member, Phase 4.2 path-scopes each track's rules to its member's root, and `ai/conventions.md` carries one row per member. A `workspace` gets the full recursion (Phase 4.0 § Workspace mode) because each member is separately committable and separately shippable.

Record in the Phase 1 output: the shape, the deciding signal (which row fired), and the member list with each member's path. If the signals conflict — a workspace manifest declaring one member while three sub-manifest dirs exist, or member dirs listed in `PROJECTS.md` that aren't on disk — flag `[SHAPE-WEAK: <what conflicts>]` and ask ONE question naming the candidate members. Do not average past the ambiguity.

Announce mode **and shape** in one line. Respect `--create` / `--enhance` / `--refresh` / `--refine` / `--upgrade` flag overrides per the precedence table in Quick Start. (`--upgrade` runs `migrate-setup.sh` then proceeds as REFRESH — it is NOT a silent fall-through to ENHANCE.)

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

