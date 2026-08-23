---
phase: 1
name: detect-mode
applies-to-modes: [all]
inputs: [target-repo, user-flags]
outputs: [mode (CREATE | ENHANCE-retrofit | ENHANCE-extend | REFRESH | REFINE | UPGRADE), repo-shape (single | monorepo | workspace)]
exit-criteria: mode + shape decided and recorded
---

### Phase 1 — Detect mode

> **This section is the SINGLE authority on WHICH mode fires.** The "Decide mode" table below is the only place a repo's signals are turned into a mode name, and its labels — `CREATE`, `ENHANCE-retrofit`, `ENHANCE-extend`, `REFRESH`, `REFINE`, `UPGRADE` — are the canonical spellings. The shell agrees with this table, not with any prose restatement: `scripts/run-preflight.sh:63-64` and `scripts/audit-setup.sh:57-58` normalize exactly these six strings — `ENHANCE-*` folds to `enhance`, `REFRESH-*`/`REFINE-*` to themselves, and `UPGRADE` to `refresh`, because UPGRADE's ceremony *is* the REFRESH ceremony (see the table row). Both scripts keep the announced label in `MODE_LABEL`. This claim was false when it was first written: `UPGRADE` lowercased to `upgrade`, matched no guard in either script, and the mode advertised as the most ceremonious silently received no Phase-0 backup, no C2a and no C2n.
>
> `commands/setup-project.md` § "Mode → ceremony" is authoritative for the *opposite* half — what a mode, once detected, then executes. Its "Detected as" column is a non-authoritative echo of this table. **If the two disagree, this file wins and that table is the bug** — the two must be edited together, never reconciled at runtime. (They did disagree: that table used to say ENHANCE means "no `.claude/` yet", so a repo with a complete prior setup and no flags — row 8 below, the most common real invocation — matched no ceremony row at all.)
>
> **Phase 1 runs FIRST**, ahead of the deterministic preflight in `commands/setup-project.md` § STEP ZERO. That preflight is invoked with `--mode=$MODE`, and `$MODE` is this phase's output; `run-preflight.sh:31` silently defaults to `refresh` when it is absent, which would take a REFRESH-shaped backup on a CREATE target. Phase 1 is read-only and writes nothing, which is what makes it safe to precede the preflight.

**Lightweight mode**: Commands invoked with `--lightweight` skip Phase 2.7-2.12 (deep extraction) + Phase 4.6/4.7 (re-anchoring) and jump from Phase 4.2-apply directly to Phase 5-verify. Trade-off: no anchor-density refinement, ~80% faster. Use for trivial pack additions, status checks, lightweight commands. Default is full ceremony unless `--lightweight` is passed OR the command's frontmatter declares `mode: lightweight`.

Inspect cwd in parallel:
- `git status` (repo y/n)
- Manifests: `package.json`, `pyproject.toml`, `composer.json`, `go.mod`, `Gemfile`, `Cargo.toml`, `mix.exs`, `build.gradle`, `pom.xml`
- `CLAUDE.md` / `.claude/` / `ai/` presence + contents
- Source file count
- **Workspace manifests** (member-declaring): `pnpm-workspace.yaml`, `package.json` → `workspaces`, `lerna.json` → `packages`, `nx.json`, `go.work`, `Cargo.toml` → `[workspace] members`, `turbo.json`, and `PROJECTS.md`
- **Sub-manifest inventory** — for every immediate subdirectory, and every subdirectory of `apps/`, `packages/`, `services/`, `libs/`, `modules/`, `src/`: does it carry its OWN manifest from the list above? Skip `node_modules`, `dist`, `build`, `out`, `target`, `vendor`, `.git`, `.venv`, `__pycache__`, `.next`, `coverage`. Record each hit as `<dir> → <manifest>`, plus whether `<dir>/.git` exists.

**Decide mode:**

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

Every row above has a matching ceremony row in `commands/setup-project.md` § "Mode → ceremony". `ENHANCE-retrofit` and `ENHANCE-extend` are two distinct modes with two distinct ceremonies; they are normalized to the single string `enhance` only at the shell boundary (`run-preflight.sh:64`, `audit-setup.sh:58`), never in the prose. **Announce the full label**, so Phase 5's mode-drift self-audit (halt condition 5) has something specific to check the executed ceremony against.

Decide shape — **mandatory, not optional; it is the second declared output of this phase.**

`repo-shape` is what Phase 2 § 17 splits the profile on, what Phase 4.0 gates sub-project recursion on, and what Phase 4.2 derives `is-multi-track` from. Leaving it unset does not make the run neutral — it silently routes a multi-deployable repo down the single-package path, which averages two packages' conventions into one blended value that is wrong for both. **Decide it from the signals above; never skip to Phase 2 without it.**

| Signal (first match wins) | Shape |
|---|---|
| A workspace manifest declares members (`pnpm-workspace.yaml`, `package.json` `workspaces`, `lerna.json` `packages`, `nx.json`, `go.work`, `Cargo.toml` `[workspace] members`; `turbo.json` only alongside one of those) | **workspace** — members = the declared list, expanded per Phase 4.0 § Sub-project enumeration |
| `PROJECTS.md` at the root with a registered-repos table | **workspace** — members = the table rows |
| ≥2 sub-manifest dirs AND (cwd is not a git repo, OR each member dir has its own `<dir>/.git`) | **workspace** — the *sibling-directory* shape: independent repos parked under one parent with no workspace tool. Members = the dirs holding those manifests |
| ≥2 sub-manifest dirs, all inside ONE git repo, with no member-declaring manifest | **monorepo** — one repo, several deployables. Members = the dirs holding those manifests |
| A **build-tool** manifest declares ≥2 members inside ONE git repo, even though no member carries a package-manager manifest of its own. Equally common in NestJS (`nest-cli.json` with `"monorepo": true`; members = the `projects` map's `sourceRoot` dirs), Angular (`angular.json` `projects`), Spring Boot / Maven (`pom.xml` `<modules>`), Gradle (`settings.gradle[.kts]` `include(...)`), ASP.NET (`*.sln` project rows) and Flutter (`pubspec.yaml` `workspace:`) | **monorepo** — members = the declared member dirs |
| Root manifest + exactly one sub-manifest dir | **single** — a lone nested package (a tooling helper, a docs site, an example app) is not a second deployable |
| Everything else | **single** — members = `[.]` |

Three things that table is deliberate about:

- **The build-tool row exists because a package-manager manifest is not the only way to declare a member.** HISTORY: the member-declaring list was package-manager manifests only, and the fallback row required each member to carry its OWN `package.json` / `pyproject.toml` / `Cargo.toml`. NestJS libraries and apps never do — a NestJS monorepo declares its members in `nest-cli.json` and shares one root `package.json`. So a live repo declaring **24 projects** fell through every row to `Everything else → single, members = [.]`, silently: nothing refused, nothing warned. Every per-member contract downstream then collapsed to one bucket — the per-package census, per-member conventions, per-member `track_roots`. The measured consequence was a profile with 1 census bucket where the same repo, read correctly, has 25. Maven, Gradle, Angular, .NET solutions and Dart workspaces share the shape and are listed with it. Detect it like this, and treat a declared-member count ≥2 as the deciding signal:

  ```bash
  # One question per build tool — NestJS, Angular, Spring Boot, Gradle, ASP.NET, Flutter alike:
  # does a build-tool manifest declare >= 2 members? NestJS keeps that in nest-cli.json.
  if [ -f nest-cli.json ]; then
    python3 - <<'PY'
import json, sys
try:
    d = json.load(open("nest-cli.json"))
except Exception:
    sys.exit(0)
projs = d.get("projects") or {}
if d.get("monorepo") and len(projs) >= 2:
    roots = sorted({(v or {}).get("sourceRoot", "") for v in projs.values()} - {""})
    print("SHAPE=monorepo members=%d roots=%s" % (len(projs), ",".join(roots)))
PY
  fi
  # Spring Boot / Gradle / Angular / ASP.NET / Flutter — same question, one line each
  grep -c '<module>' pom.xml 2>/dev/null
  grep -cE "^[[:space:]]*include\\(" settings.gradle settings.gradle.kts 2>/dev/null
  python3 -c 'import json;d=json.load(open("angular.json"));print(len(d.get("projects",{})))' 2>/dev/null
  grep -c '^Project(' ./*.sln 2>/dev/null
  ```

- **The three sub-manifest rows are the ones that were missing before that.** Detection by workspace manifest alone covers only rows 1–2. A repo with a server directory and a client directory and no workspace tool — and a parent folder holding two checked-out repos — are both extremely common and both matched *nothing* before. They now land on `monorepo` and `workspace` respectively.
- **`monorepo` ≠ `workspace`, and the difference is the git boundary.** One git repo means one `.claude/`, one `ai/`, one commit — so a `monorepo` is NOT recursed like a workspace. What it gets instead is a per-member *profile*: Phase 2 § 17 records one entry per member and every code-shaped profile field is answered once per member, Phase 4.2 path-scopes each track's rules to its member's root, and `ai/conventions.md` carries one row per member. A `workspace` gets the full recursion (Phase 4.0 § Workspace mode) because each member is separately committable and separately shippable.

Record in the Phase 1 output: the shape, the deciding signal (which row fired), and the member list **in the shape Phase 2 forwards it in** — one entry per member carrying `name`, `root` and `manifest`. `(none)` is a legal `manifest` value: a member directory with no manifest of its own is still a member (the `PROJECTS.md` row and the sibling-directory cases both produce them). Record all three fields, not just the path: `phase-2-profile.md § 2.0.a` forwards this list to `extract-codebase-overview` **verbatim**, and that skill's `## Inputs` requires `manifest` per entry with source *"the input, verbatim"* (`extract-codebase-overview/SKILL.md § Inputs`, Step 2's per-entry table). A field this phase never writes is a field the extraction has to re-derive — which is the re-detection this handoff exists to remove. If the signals conflict — a workspace manifest declaring one member while three sub-manifest dirs exist, or member dirs listed in `PROJECTS.md` that aren't on disk — flag `[SHAPE-WEAK: <what conflicts>]` and ask ONE question naming the candidate members. Do not average past the ambiguity.

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
  Extracted: 23 durable items across 11 sections (see .claude/_refresh-extract.md)
  Proceeding to Phase 2 (deep profile + extract merge), then Phase 2.5 (idioms),
  then Phase 2.6 (profile-informed coverage gap check), then Phase 3 (delta + plan).
```

