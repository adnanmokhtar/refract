---
phase: 4
sub-phase: "4.0"
name: pack-load-preflight
applies-to-modes: [all]
inputs: [selected-tracks, codebase-profile]
outputs: [pack-load-preflight-report, refused-packs, accepted-packs, minimum-artifacts-table]
exit-criteria: every accepted pack has _version.json + CHANGELOG.md (A27); minimum artifacts present per LOAD-BEARING track
runs-before: [4.1, 4.2, 4.8]
imported-by: templates/phases/phase-4-apply.md
---

### Phase 4 — Apply

**REFRESH-mode preamble (only when mode = REFRESH)**: load `.claude/_refresh-knowledge-extract.md` (Phase 0.2 output) into working memory before any sub-step. The extract is consumed by:

- **4.1 baseline**: extract section 5 (custom rules) → wired into post-baseline overrides; extract section 7 (validated corrections) → injected into `.claude/settings.json` deny-list comments; extract section 11 (custom hook deltas) → re-applied on top of baseline hook shims.
- **4.2 packs**: extract section 6 (custom agents/skills/commands) → preserved alongside pack copies (deduped by name; user-edited pack files keep user edits over verbatim pack source per Appendix C).
- **4.4 + 4.4b**: extract sections 1-3 + 10 (ADRs, domain knowledge, project intent, architecture/runtime/audits/failures) → fed into business-domain content generation so regen produces project-specific output, not generic templates.
- **4.5 generate-missing**: extract section 4 (custom conventions) → drives generated content's "Project-specific" blocks at the TOP of every rule/pattern.
- **4.7 knowledge base**: extract sections 1, 2, 3, 4, 7, 8, 9, 10 → BECOME the regenerated `ai/decisions/`, `ai/business-domain.md`, `ai/project-goals.md`, `ai/conventions.md`, `ai/dynamic/corrections.md`, `ai/patterns/`, `ai/architecture.md`, `ai/runtime/*.md`, `ai/audits/*.md`, `ai/failures/*.md`. ADRs + audits + failures are append-only — copy verbatim, never rewrite. Section 9 (uncategorized user-touched files) is restored byte-for-byte unless the file's destination has been deleted by an explicit deprecation in this spec.
- **4.8 tool adapters**: extract section 6 (custom skills/commands) → translated to each adapter same as pack content.

The brain MUST consume the extract; if a regen sub-step does NOT reference the extract for its category, that's a bug — Phase 5 audit catches it via the "knowledge preservation check" (see Phase 5). Section 9 (catch-all) MUST be exhaustively re-applied: every file in it must end up either restored at its original path or listed in the Phase 5 report under "Intentional drops".

### 4.0 Pack-load preflight (mandatory — runs BEFORE 4.1 / 4.2 / 4.8)

This is the gate that everything downstream assumes has run. It validates that every track + adapter + business-domain + technical-domain selected in Phases 2 + 3 is loadable from `~/.claude/templates/` with all the metadata `setup-project` will rely on. If preflight fails, **halt before any file write** — do NOT scaffold a half-known baseline and then bail mid-Phase 4.2.

#### 4.0.0 Pack-source directory parity scan (Critical Rule 1.4)

**Mandatory on every invocation, including re-runs.** Before any other preflight check, scan the actual filesystem of every selected pack source. The directory listing — NOT `_essentials.md`, NOT `_topics.md`, NOT prior `_apply-pack-report.md` — is the source of truth for "what's in this pack."

```bash
for PACK in $SELECTED_PACKS; do
  PACK_SRC="$HOME/.claude/templates/packs/$PACK"
  for KIND in commands agents skills rules ai-patterns; do
    [ -d "$PACK_SRC/$KIND" ] || continue
    while IFS= read -r src_file; do
      base="$(basename "$src_file")"
      target="$TARGET_REPO/.claude/$KIND/$base"   # adjust per emit contract
      if [ ! -f "$target" ]; then
        echo "ADD-CANDIDATE $PACK/$KIND/$base"
      else
        echo "MERGE-CANDIDATE $PACK/$KIND/$base"   # subject to Appendix C
      fi
    done < <(find "$PACK_SRC/$KIND" -maxdepth 1 -name '*.md' -not -name '_*')
  done
done
```

**The agent MUST run this scan literally** (or its semantic equivalent) for every `--include=<pack>` flag set, AND for every pack previously selected and recorded in `.claude/codebase-profile.md § Setup version`.

**Bug class this prevents:** prior runs may have decided "SKIP-with-redirect" for `commands/<old-name>.md`. A subsequent release adds `commands/<new-name>.md` to the pack. The directory scan sees the new file → emits ADD-CANDIDATE → it lands in the target. The old SKIP decision is irrelevant to the new file.

**Forbidden short-circuits:**
- ❌ "Already-applied — no work to do" without running the directory scan.
- ❌ Reading `_essentials.md` and stopping (manifest may lag behind directory).
- ❌ Trusting `_apply-pack-report.md` from a prior run as authoritative for what "should be there."

If preflight finds ANY ADD-CANDIDATE → the run is NOT idempotent → proceed to Phase 4.2 deterministic copy.

#### 4.0.1 Inputs

- Selected packs (Phase 2 detection + `--include`/`--exclude`).
- Selected business-domains (Phase 2.4 + wizard answers).
- Selected technical signals → domain overlays (Phase 2 + Appendix B Relevance Filter).
- Selected tool adapters (Phase 3.2 detection + `--tools`).
- Mode (CREATE / ENHANCE / REFRESH).

#### 4.0.2 Per-source preflight (run on each selected source)

For every selected pack / adapter / domain / business-domain / regulatory-overlay:

```bash
SRC="$1"   # e.g. ~/.claude/templates/packs/backend
SRC_KIND="$2"  # one of: pack, adapter, business-domain, domain, overlay
ERRORS=()

# 1. Existence
[ -d "$SRC" ] || ERRORS+=("MISSING_SOURCE $SRC")

# 2. _version.json present + parseable + has required fields
if [ ! -f "$SRC/_version.json" ]; then
  ERRORS+=("MISSING_VERSION $SRC")
else
  jq -e '.version and .kind and .name and .min_setup_command' "$SRC/_version.json" >/dev/null 2>&1 \
    || ERRORS+=("BAD_VERSION_JSON $SRC")
fi

# 3. CHANGELOG.md present (informational on first major; required from v2+)
[ -f "$SRC/CHANGELOG.md" ] || ERRORS+=("MISSING_CHANGELOG $SRC")  # warning, not halt

# 4. min_setup_command compatibility check
required="$(jq -r '.min_setup_command // "0.0.0"' "$SRC/_version.json")"
semver_ge "$SETUP_COMMAND_VERSION" "$required" \
  || ERRORS+=("INCOMPATIBLE $SRC requires setup-project >= $required, have $SETUP_COMMAND_VERSION")

# 5. deprecated flag → warn (do not halt)
deprecated="$(jq -r '.deprecated // false' "$SRC/_version.json")"
[ "$deprecated" = "true" ] && WARNINGS+=("DEPRECATED $SRC see CHANGELOG.md")

# 6. Pack-specific: every artifact file ≥100 lines (the no-thin-stub gate)
if [ "$SRC_KIND" = "pack" ]; then
  while IFS= read -r f; do
    lines=$(wc -l < "$f")
    [ "$lines" -lt 100 ] && ERRORS+=("THIN_PACK_FILE $f ($lines lines, floor=100)")
  done < <(find "$SRC" -type f \( -path '*/agents/*.md' -o -path '*/skills/*/SKILL.md' -o -path '*/commands/*.md' -o -path '*/rules/*.md' \))
fi

# 7. Business-domain pack-specific: factories.md present (B17)
if [ "$SRC_KIND" = "business-domain" ]; then
  [ -f "$SRC/factories.md" ] || ERRORS+=("MISSING_FACTORIES $SRC (every business-domain pack must ship factories.md)")
fi

# 8. Adapter-specific: schema present in templates/schemas/ if --validate-schemas was passed
if [ "$SRC_KIND" = "adapter" ] && [ "$ARG_VALIDATE_SCHEMAS" = "1" ]; then
  adapter_name="$(basename "$SRC")"
  schema_count=$(ls "$HOME/.claude/templates/schemas/$adapter_name/"*.schema.json 2>/dev/null | wc -l)
  [ "$schema_count" -eq 0 ] && WARNINGS+=("SCHEMA_MISSING $adapter_name (continuing; --validate-schemas was opt-in)")
fi
```

#### 4.0.3 Halt vs. warn

- **ERRORS → halt before Phase 4.1.** Print every error in the report. Do not write anything to the project.
- **WARNINGS → log + continue.** Surface them in the Phase 5 report under "Pack-load preflight warnings". They are advisory.

#### 4.0.4 Pack-load preflight report (always emitted)

```
== Pack-load preflight ==
Sources scanned: N (P packs, A adapters, B business-domains, D domains, O overlays)
✓ Loadable:        K
⚠ Warnings:        W (deprecation, missing CHANGELOG, schema missing)
✗ Errors:          E (halts the run if E > 0)

Errors:
  - THIN_PACK_FILE ~/.claude/templates/packs/backend/agents/foo.md (43 lines, floor=100)
  - MISSING_VERSION ~/.claude/templates/business-domains/scheduling
Warnings:
  - DEPRECATED ~/.claude/templates/packs/legacy-track see CHANGELOG.md
```

#### 4.0.5 Minimum-artifacts table (referenced by Phase 4.2.c + Phase 5.1)

The table that Phase 4.2.c verifies against and Phase 5.1 retries against. **Per-track floors** (load-bearing only — tracks not load-bearing get `n/a`, not a gap):

| Track             | agents | commands | skills | rules | ai-patterns |
|-------------------|--------|----------|--------|-------|-------------|
| backend           | 2      | 2        | 2      | 2     | 3           |
| frontend          | 2      | 2        | 1      | 2     | 2           |
| testing           | 1      | 1        | 1      | 1     | 1           |
| security          | 1      | 1        | 1      | 2     | 1           |
| code-quality      | 1      | 1        | 1      | 2     | 1           |
| documentation     | 1      | 1        | 1      | 1     | 0           |
| learning          | 1      | 1        | 1      | 1     | 0           |
| db                | 1      | 1        | 1      | 1     | 1           |
| devops            | 1      | 1        | 1      | 1     | 1           |
| performance       | 1      | 1        | 1      | 1     | 1           |
| api               | 1      | 1        | 1      | 1     | 1           |
| compliance        | 1      | 1        | 1      | 2     | 0           |
| product           | 0      | 1        | 1      | 1     | 0           |
| design            | 0      | 1        | 1      | 1     | 1           |
| pm                | 0      | 1        | 1      | 1     | 0           |
| support           | 0      | 1        | 1      | 1     | 0           |
| migration         | 2      | 2        | 3      | 1     | 3           |

**Minimal mode (`--minimal`)**: floors are replaced by the track's `_essentials.md` manifest counts. Anything outside the focused subset is `n/a`.

**Migration track**: load-bearing only when `migration_layout_detected` is true (parallel V1+V2 directories, version-suffixed sibling modules, dual-app workspaces with `-v2`/`-next`/`-new` suffixes, README mentions of V1→V2 / legacy migration) OR when explicitly opted in via `--include=migration`. Floors above match `_essentials.md`: 2 agents (`migration-architect`, `parity-auditor`), 2 commands (`port-feature`, `migration-status`), 3 skills (`extract-v1-contract`, `parity-test-generate`, `perf-uplift-survey`), 1 rule (`migration-discipline`), 3 patterns (`feature-port`, `parity-testing`, `migration-ledger`).

#### 4.0.6 Required baseline files (referenced by Phase 5.1 + Phase 5.4)

The flat list below MUST exist on disk after Phase 4.1. Phase 5.1 retries this list (then halts). It is the answer to "what does Phase 4.0's baseline contract look like":

```
.claude/settings.json
.claude/codebase-profile.md
.claude/hooks/                  (≥7 settings.json-wired hook scripts: post-edit-check, pre-edit-guard, guard-destructive, session-start, update-session-log, post-commit-learn, post-merge-learn)
.claude/git-hooks/post-commit   (thin shim that execs .claude/hooks/post-commit-learn.sh; wired via core.hooksPath OR Husky per Phase 4.1)
.claude/git-hooks/post-merge    (thin shim that execs .claude/hooks/post-merge-learn.sh; wired via core.hooksPath OR Husky per Phase 4.1)
.claude/rules/read-before-write.md          (foundational rule — repo-baseline ships verbatim)
.claude/rules/read-codebase-deeply.md       (foundational rule — repo-baseline ships verbatim)
.claude/rules/code-quality.md               (foundational rule — repo-baseline ships verbatim)
.claude/rules/think-simplify-surgical.md    (foundational rule — repo-baseline ships verbatim; Karpathy-inspired task discipline layer)
CLAUDE.md
AGENTS.md                       (codex adapter writes; always-written even if codex not selected)
ai/README.md
ai/status.md
ai/stack.md
ai/architecture.md
ai/business-domain.md
ai/conventions.md
ai/_essentials.md               (when --minimal was passed)
ai/_convention-cheatsheet.md
ai/project-goals.md
ai/users-and-personas.md
ai/core/glossary.md
ai/decisions/README.md
ai/decisions/_template.md
ai/dynamic/corrections.md
ai/dynamic/decisions-pending.md
ai/dynamic/README.md
ai/failures/_index.md
ai/failures/README.md
ai/patterns/README.md
ai/runbooks/README.md
ai/references/tool-parity.md
```

> Anything in this list missing after Phase 4.1 → Phase 5.1 retries the baseline copy → halts if still missing.

**4.1 Scaffold baseline** (skip if already present; never overwrite — REFRESH treats this as overwrite-with-extract-merge for files in `ai/decisions/` and `ai/dynamic/corrections.md` ONLY; everything else uses standard append/skip rules):

**Baseline contents extended in v3.0+** (see Advanced Capabilities section above):

- `ai/failures/_index.md` + `ai/failures/README.md` — failure catalog (B10). Empty index OK on greenfield; ENHANCE/REFRESH may seed from `ai/dynamic/corrections.md` if `severity: critical` corrections exist.
- `.claude/_telemetry.jsonl` — empty file with header comment + `.gitignore` entry. Telemetry harness (B3).
- Version stamp block in `.claude/codebase-profile.md` § "Setup version" — records `setup_command_version` + per-pack versions + per-adapter versions (B2). MUST be written by Phase 4.1; without it drift detection at session-start can't function.
- `.claude/_wizard-answers.yaml` (only if `--wizard` was used) — persists answers for re-runs (B22).
- `test/factories/` + `test/fixtures/` directories scaffolded when business-domain has factories.md (B17).
- Copy `~/.claude/templates/repo-baseline/.claude/` + `/ai/` into cwd.
- `chmod +x` hooks.
- **Wire git hooks** (Phase 6 learning loop) — **Husky-aware decision tree**:

  `repo-baseline` ships **`.claude/git-hooks/post-commit`** + **`.claude/git-hooks/post-merge`** as thin shims that `exec` **`.claude/hooks/post-commit-learn.sh`** + **`.claude/hooks/post-merge-learn.sh`** (implementations stay in `.claude/hooks/`).

  After `chmod +x` on both shims + all `.claude/hooks/*.sh`, and only if `git rev-parse --is-inside-work-tree` succeeds:

  ```
  Detect Husky:
    HUSKY = exists(.husky/) OR (package.json has "prepare": "husky*") OR core.hooksPath ∈ {.husky, .husky/_}
    EXISTING_HOOKSPATH = git config --get core.hooksPath  (may be empty)

  Decision:
    1. If HUSKY is true → ROUTE THROUGH HUSKY (do NOT touch core.hooksPath):
       - Ensure .husky/ exists (run `npx husky init` if missing and package.json has the prepare hook).
       - For each of {post-commit, post-merge}:
         - If .husky/<hook> does not exist → create it with shebang + `exec "$(git rev-parse --show-toplevel)/.claude/hooks/<hook>-learn.sh"` and `chmod +x`.
         - If .husky/<hook> exists and does NOT already source our learn script → append a marker block:
           ```
           # >>> claude-config: learning loop (managed) >>>
           "$(git rev-parse --show-toplevel)/.claude/hooks/<hook>-learn.sh" || true
           # <<< claude-config: learning loop (managed) <<<
           ```
           Idempotent on re-run: skip if the marker block is already present.
       - Log: `git-hooks: routed via .husky/ (Husky detected)`.

    2. Elif EXISTING_HOOKSPATH is empty OR equals .claude/git-hooks → USE OUR SHIM PATH:
       - Run `git config core.hooksPath .claude/git-hooks`.
       - Log: `git-hooks: core.hooksPath set to .claude/git-hooks`.

    3. Elif EXISTING_HOOKSPATH points to something else (e.g. .githooks, custom path) → DO NOT OVERWRITE:
       - Print a multi-line note: "core.hooksPath is set to <X>. To wire learning hooks, append `exec \"$(git rev-parse --show-toplevel)/.claude/hooks/post-commit-learn.sh\"` to <X>/post-commit and the post-merge analogue."
       - Log: `git-hooks: skipped (foreign core.hooksPath=<X>; manual wiring required)`.

    4. Elif .git/hooks/post-commit or .git/hooks/post-merge exist as real (non-symlink) user-owned files → DO NOT REPLACE:
       - Same note as case 3 but suggest editing .git/hooks/<hook> directly.
       - Log: `git-hooks: skipped (existing .git/hooks/<hook> not managed by us)`.
  ```

  **Idempotency on re-runs**: re-running this phase against an already-wired repo MUST be a no-op (detect markers / detect existing core.hooksPath value matching ours / detect already-appended Husky block). No duplicate appends, no re-toggling of `core.hooksPath`.
- **Pre-fill `.claude/settings.json` permission allowlist** with detected safe project commands so users don't see permission prompts on day one. Detect from `package.json` scripts / `Makefile` / `pyproject.toml` / `Cargo.toml`:
  ```json
  {
    "permissions": {
      "allow": [
        "Bash(<detected lint command>:*)",
        "Bash(<detected test command>:*)",
        "Bash(<detected typecheck command>:*)",
        "Bash(<detected build command>:*)",
        "Bash(git status:*)",
        "Bash(git diff:*)",
        "Bash(git log:*)",
        "Bash(git show:*)",
        "Bash(git branch:*)",
        "Bash(ls:*)", "Bash(find:*)", "Bash(grep:*)", "Bash(rg:*)",
        "Bash(cat:*)", "Bash(head:*)", "Bash(tail:*)", "Bash(wc:*)"
      ],
      "deny": [
        "Bash(rm -rf:*)", "Bash(rm -fr:*)",
        "Bash(git push --force:*)", "Bash(git push -f:*)",
        "Bash(git reset --hard:*)", "Bash(git clean -fd:*)",
        "Bash(git branch -D:*)", "Bash(git commit --amend:*)",
        "Bash(*uninstall*)", "Bash(*:--no-verify:*)"
      ]
    }
  }
  ```
  Auto-detection rules:
  - `package.json`: extract `scripts.lint`, `scripts.test`, `scripts.typecheck`, `scripts.build` → allowlist them as `Bash(<package-manager> run <script>:*)`.
  - `Makefile`: extract common targets (`lint`, `test`, `build`) → allowlist `Bash(make <target>:*)`.
  - `pyproject.toml`: detect `pytest` / `mypy` / `ruff` → allowlist directly.
  - `Cargo.toml`: allowlist `Bash(cargo build:*)`, `Bash(cargo test:*)`, `Bash(cargo clippy:*)`.
- **Workspace mode** (CRITICAL — this was the missed cascade):
  - Root of workspace gets `workspace-baseline/` (orchestration-only: dispatcher agent, PROJECTS.md, cross-repo commands, workspace rules, workspace AGENTS.md as a thin index).
  - Workspace root does NOT get per-stack track agents / per-domain tooling / per-stack rules — those belong in each sub-project.
  - For EACH registered sub-project (see enumeration below), **recursively apply Phases 2 → 4** with cwd = sub-project path. Each sub-project gets its own stack detection, profile, track selection, domain tooling, tool adapters, and `ai/` knowledge base.

**Sub-project enumeration** (happens at start of Phase 4.1 when shape=workspace):

Detect sub-projects from manifest(s) in this order:
| Source | Extract |
|---|---|
| `pnpm-workspace.yaml` | `packages:` glob list (e.g. `packages/*`, `apps/*`, `api`, `dashboard`). |
| `package.json` → `workspaces` | Array or object form; expand globs. |
| `lerna.json` → `packages` | Glob list. |
| `turbo.json` (Turborepo) | Infer from `package.json` workspaces or pipeline filters. |
| `nx.json` + `workspace.json` / `project.json` | Nx workspace — enumerate via `nx show projects`. |
| `go.work` (Go) | `use` directives. |
| `Cargo.toml` `[workspace]` `members` | Rust. |
| Fallback: any dir with its own manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `composer.json`) | Use these. |
| Fallback: `PROJECTS.md` in workspace root lists siblings | Use table rows. |

For each sub-project P in the enumeration:
1. Filter out non-project dirs: `node_modules`, `dist`, `build`, `.git`, `.pnpm-store`, `target`.
2. Detect P's stack (same as Phase 2 detection, but scoped to P's directory).
3. Select tracks + domain tooling for P's stack (NestJS backend vs Angular frontend get DIFFERENT track sets).
4. Scaffold P's own `.claude/` + `ai/` (repo-baseline copy).
5. Apply tracks + domains + tool adapters in P's directory.
6. P gets its own `CLAUDE.md` + `AGENTS.md` + `opencode.json` + `.cursor/rules/` etc. — not shared with siblings.

**Never scaffold per-project content only at workspace root** when sub-projects exist. That's the bug this rule exists to prevent.

For the workspace-root `AGENTS.md` + `opencode.json` thin-anchor shapes, see Phase 4.8 § "Workspace root anchor shapes".

**4.0 Pack-load preflight** (runs ONCE before 4.1 — prevents thin-content propagation):

```bash
# For every pack file in selected tracks, confirm it's ≥100 lines
for track in <selected-tracks>; do
  for type in agents commands skills rules ai-patterns; do
    for f in ~/.claude/templates/packs/$track/$type/*.md; do
      [ ! -f "$f" ] && continue
      lines=$(wc -l < "$f")
      if [ "$lines" -lt 100 ]; then
        echo "HALT: pack source $f is thin ($lines lines). Deepen at the pack level before applying."
        exit 1
      fi
    done
  done
done
```

If any pack file is thin, HALT. Don't propagate shallow content into the project. The fix is in `~/.claude/templates/packs/`, not in this run.

### Minimum artifacts per LOAD-BEARING track (quality floor — NOT a "every project gets every track" contract)

This table is a quality floor for tracks that ARE generated. It is NEVER applied to tracks the codebase profile marked NOT-APPLICABLE.

**Rule of application** (read this before invoking the table):

1. A track only enters this check if Phase 2.6.a marked it LOAD-BEARING (signal in profile) or ALWAYS-ON (security, code-quality, documentation, learning). Tracks marked NOT-APPLICABLE are skipped entirely — no row, no expected count, no shortfall, no retry. The audit reports them under `not-applicable` in the gap report and never under `gaps`.
2. The numbers are aspirational floors derived from "what does a competent project of this discipline include?" — they are not religious. Phase 4.2-AUTHOR derives content from extracted idioms; if the project's idioms genuinely don't need the Nth agent of a track, Phase 4.6's CHANGE/LEAVE decision can drop it (with a comment) — Phase 5 audit will not retry a documented LEAVE-delete.
3. Phase 5 verification uses this table to confirm Phase 4.2 / 4.2-AUTHOR actually produced floor-meeting output **for tracks that were selected**. Shortfalls trigger retry → halt — but only for selected tracks.

| Track | Min agents | Min commands | Min skills | Min rules | Min ai-patterns |
|---|---|---|---|---|---|
| backend | 3 | 8 | 4 | 2 | 6 |
| frontend | 4 | 5 | 3 | 1 | 5 |
| database | 4 | 4 | 2 | 1 | 3 |
| testing | 3 | 2 | 1 | 1 | 2 |
| security | 2 | 1 | 2 | 1 | 2 |
| devops | 2 | 2 | 1 | 1 | 2 |
| performance | 1 | 1 | 2 | 1 | 0 |
| observability | 3 | 1 | 0 | 1 | 3 |
| documentation | 1 | 2 | 1 | 1 | 2 |
| code-quality | 5 | 4 | 1 | 1 | 0 |
| business | 2 | 3 | 0 | 0 | 0 |
| infrastructure | 2 | 1 | 0 | 1 | 1 |
| distributed-systems | 3 | 1 | 1 | 1 | 6 |
| mobile | 1 | 0 | 0 | 1 | 0 |
| ui-ux | 4 | 1 | 0 | 1 | 6 |
| learning | 3 | 4 | 1 | 0 | 0 |
| migration | 2 | 2 | 3 | 1 | 3 |

**What changed (vs. older versions of this file)**: this table used to be applied to ALL listed tracks unconditionally — that's the "force-fit one shape" failure mode the user reported. It is now scoped to load-bearing + always-on only, which is what makes setup adaptive instead of prescriptive.

**Required baseline files (always, regardless of tracks):**
- `.claude/hooks/`: 7 settings.json-wired hook scripts (post-edit-check, pre-edit-guard, guard-destructive, session-start, update-session-log, post-commit-learn, post-merge-learn). These are invoked by Claude Code via `.claude/settings.json` `hooks.*` registrations — they are NOT git hooks.
- `.claude/git-hooks/`: 2 thin shim scripts (post-commit, post-merge) that `exec` the matching `…-learn.sh` from `.claude/hooks/`. Wired into git via `core.hooksPath` or Husky per Phase 4.1's decision tree. These ARE git hooks (Phase 6 learning loop).
- `.claude/settings.json`: 1 file with allowlist + deny.
- `ai/`: 13 always-present files (status, stack, modules, architecture, conventions, README + 7 subfolder READMEs + business-domain + project-goals + users-and-personas + business-model + competitive-context + roadmap + _session-digest + _decision-index + _convention-cheatsheet + references/models + references/tool-parity).
- `CLAUDE.md` + `AGENTS.md` at root.
- `.claude/codebase-profile.md`.

If post-Phase-4 file count is below ANY of these minimums for a SELECTED track or required baseline: Phase 5 retries the copy, then halts if still failing.

**4.2 Apply tracks** — gate first (AUTHOR vs COPY), then execute.

For each selected track, decide one of two modes BEFORE doing any file ops:

- **AUTHOR mode** — Phase 2.5 produced extraction signal AND the track's pack ships `_topics.md` (topic specs, not literal templates). Use Phase 4.2-AUTHOR (below). Output is generated from `.claude/_extracted-idioms.md` + topic spec; pack template bodies are inspiration only.
- **COPY mode** — extraction was skipped/weak OR the track's pack ships only literal templates (no `_topics.md` present yet). Use Phase 4.2.a–c (deterministic shell `cp` — original behavior, kept intact below). This is the safe fallback.

Mode is per-track. A typical run mixes: `backend` + `database` in AUTHOR (rich extraction); `code-quality` + `documentation` in COPY (stable generic content).

Report the per-track mode in the plan:

```
Track modes:
  backend         AUTHOR  (3 base classes extracted: BaseService [238 ext], DataAccess [273 ext], BaseController [89 ext])
  database        AUTHOR  (1 base class: BaseEntitySubscriber [12 ext])
  code-quality    COPY    (no project-specific base classes; pack content is sufficient)
  documentation   COPY    (same)
  testing         COPY    (no _topics.md in pack yet — falls back to literal copy)
  security        COPY    (same)
  learning        COPY    (always — meta-pack)
```

