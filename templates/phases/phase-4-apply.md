---
phase: 4
name: apply
applies-to-modes: [all]
inputs: [approved-plan, codebase-profile, selected-tracks]
outputs: [CLAUDE.md, ai/, .claude/, tool adapters when enabled]
exit-criteria: every planned artifact written; deterministic copy verified; idempotency markers in place
sub-phases:
  - 4.0: pack-load preflight (mandatory before 4.1 / 4.2 / 4.8)
  - 4.1: project-specific block authoring
  - 4.2: deterministic copy from packs (Bash-driven, not LLM-driven) + AUTHOR variant for extracted-idiom mode
  - 4.2.a: pre-flight inventory
  - 4.2.b: deterministic copy
  - 4.2.c: immediate post-copy verification
  - 4.6-DEEP: re-anchor Project-specific blocks with deep extraction (REFINE only)
  - 4.7-DEEP: refresh ai/ knowledge base (REFINE only)
  - 4.8-DEEP: re-sync tool adapters (REFINE only)
  - 4.8.0: per-adapter completeness contract (thin-stub-bug prevention)
size-note: "1473 lines — exceeds the 500-line per-file budget. Slated for sub-phase splitting in M3."
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

### 4.2-AUTHOR — Author from extracted idioms (when gate selected AUTHOR mode)

For each track in AUTHOR mode:

1. **Read the topic spec** at `~/.claude/templates/packs/<track>/_topics.md`. It lists the patterns/agents/rules every project in this discipline must cover, each as a topic spec (required sections + extraction recipes — NOT as a finished file body).
2. **For each topic** in the spec:
   - Look up the relevant section(s) in `.claude/_extracted-idioms.md` (e.g., topic `data-access` consumes the idiom block for the project's repository base class).
   - If extraction has signal → invoke `extract-base-class-idiom`'s Step 6 author flow OR a topic-specific authoring flow per `_topics.md`. Output is project-voice content citing real paths, real extenders, real pitfalls.
   - If extraction has NO signal for this topic → if `~/.claude/templates/packs/<track>/_examples/<topic>.md` exists, copy it as fallback; else copy the closest template from that pack's `agents/`, `skills/`, or `ai-patterns/` OR emit a sectioned stub from `_topics.md` for that topic. Mark with `<!-- TODO: re-author from extraction once base class exists -->` when using fallback so future runs upgrade it.
3. **In ENHANCE/REFRESH mode**, before writing, READ any existing `ai/patterns/<topic>.md` in the project and mirror its section order + voice (Step 5.5 of the skill). Authored content goes inside the existing skeleton; new sections (e.g., "Pitfalls" if missing) appended at the end.
4. **Always cite evidence** — every method, path, line number, extender count, deprecation warning in the output must trace to a real file the extractor read. No invention.

Output: same destination paths as COPY mode (`.claude/agents/`, `.claude/rules/`, `ai/patterns/`, etc.), same Phase 5 verification (file presence + minimums + retry). Difference is purely in how the content was produced.

**Pack structure for AUTHOR mode** (the pack-author's contract — how packs SHIP topics for this to work):

```
~/.claude/templates/packs/<track>/
├── _topics.md           # nucleus: list of topics + extraction recipes per topic
├── _examples/           # OPTIONAL: finished templates as fallback (when extraction has no signal); not every pack ships this directory
│   ├── data-access.md
│   └── ...
├── agents/              # legacy literal templates (still copied in COPY mode)
├── rules/               # same
├── ai-patterns/         # same — being deprecated in favor of _topics.md
└── ...
```

`_topics.md` shape (minimal):

```yaml
topics:
  - name: data-access
    triggers: { base_class_pattern: "extends DataAccess|extends Repository|extends BaseRepository" }
    sections: [overview, type_params, configuration, protocol, automatic_behaviors, escape_hatches, pitfalls, examples, related]
    fallback: _examples/data-access.md
  - name: base-service
    triggers: { base_class_pattern: "extends BaseService|extends ApplicationService|extends UseCase" }
    sections: [overview, key_methods, configuration, create_flow, update_flow, delete_flow, override_hooks, pitfalls]
    fallback: _examples/base-service.md
  ...
```

Each pack maintainer authors `_topics.md` once; the same triggers + section list adapt across NestJS / Django / Laravel / Rails projects because the extractor reads whatever base class actually exists.

**Backward compatibility**: packs without `_topics.md` automatically fall through to COPY mode. No flag day. As packs adopt the topic-spec format one by one, the brain shifts that track to AUTHOR mode automatically.

This step is the historical failure mode prevention: the LLM agent under context pressure prioritizes "creative" outputs (ADRs, project-specific rules) and silently skips the bulk pack-copy step. To prevent this, COPY-mode Phase 4.2 uses **shell `cp` commands**, not file-by-file model-driven writes. The agent's job is to ENUMERATE which tracks to copy + EXECUTE the deterministic commands. The shell guarantees the copy.

### 4.2.a Pre-flight inventory (mandatory — write to plan BEFORE applying)

For each selected track, calculate expected file counts and add to the plan:

```
Pre-flight inventory:
  Track: backend
    Source: ~/.claude/templates/packs/backend/
    Files to copy: agents/* (8 files), commands/* (10 files), skills/* (6 files), rules/* (1 file), ai-patterns/* (5 files), references/* (1 file for detected framework)
    Total: 31 files → .claude/{agents,commands,skills,rules}/ + ai/patterns/

  Track: code-quality
    Source: ~/.claude/templates/packs/code-quality/
    Total: 17 files

  ... (every selected track listed)

  GRAND TOTAL: 187 files expected from N tracks
```

User reviews the inventory before approval. This makes the failure mode visible BEFORE Phase 4.2 runs.

### 4.2.b Deterministic copy (executed via Bash, not model-written)

**Two modes**: STANDARD (default) and MINIMAL (when `--minimal` flag set).

#### Standard mode (default)

For each selected track, run these EXACT commands (substitute `<track>` for the track name):

```bash
# Copy agents (verbatim — no trimming possible at OS level)
mkdir -p .claude/agents
cp -R ~/.claude/templates/packs/<track>/agents/*.md .claude/agents/ 2>/dev/null || true

# Copy commands
mkdir -p .claude/commands
cp -R ~/.claude/templates/packs/<track>/commands/*.md .claude/commands/ 2>/dev/null || true

# Copy skills (recursive — skills can be folders with SKILL.md + sibling files)
mkdir -p .claude/skills
cp -R ~/.claude/templates/packs/<track>/skills/* .claude/skills/ 2>/dev/null || true

# Copy rules
mkdir -p .claude/rules
cp -R ~/.claude/templates/packs/<track>/rules/*.md .claude/rules/ 2>/dev/null || true

# Copy ai-patterns INTO ai/patterns (renamed destination)
mkdir -p ai/patterns
cp -R ~/.claude/templates/packs/<track>/ai-patterns/*.md ai/patterns/ 2>/dev/null || true

# Copy framework references (only for detected frameworks)
mkdir -p .claude/references
for fw in <detected-frameworks>; do
  cp -R ~/.claude/templates/packs/<track>/references/${fw}.md .claude/references/ 2>/dev/null || true
done
```

The `|| true` is intentional: missing source dir is OK (e.g., a track without skills); the copy proceeds for what exists.

#### MINIMAL mode (when `--minimal` flag set)

Read the track's `_essentials.md` manifest. Copy ONLY the files listed there.

##### `_essentials.md` format contract (the parser depends on this shape)

Every track's `_essentials.md` MUST follow this exact YAML-frontmatter shape so the deterministic parser below works without ambiguity. Authors: do NOT use multi-line array syntax (`agents:\n  - foo\n  - bar`); do NOT inline comments inside the bracket; do NOT use anchors/aliases. The parser is intentionally restrictive — anything fancier requires `yq` and breaks the no-extra-deps guarantee.

```markdown
---
kind: pack-essentials
track: <track-name>
description: <one-liner explaining what this track's minimal subset covers>
essentials:
  agents:      [agent-a, agent-b]
  commands:    [command-a, command-b, command-c]
  skills:      [skill-a]
  rules:       [rule-a, rule-b]
  ai-patterns: [pattern-a, pattern-b]
---

# <Track> — minimal subset

Optional prose explaining why these specific entries were chosen, what gets dropped at `--minimal`, and the upgrade path. The parser ignores everything below the closing `---`.
```

Hard rules:
1. Each list value is a flat `[a, b, c]` array of basenames (no `.md` suffix). No nesting. No dictionaries.
2. The 5 keys (`agents`, `commands`, `skills`, `rules`, `ai-patterns`) MUST all be present. Empty list `[]` is allowed; missing key is a preflight failure (Phase 4.0 catches it).
3. Every basename listed MUST exist as a real file in the pack — `<basename>.md` for agents/commands/rules/ai-patterns; `<basename>/SKILL.md` for skills. Phase 4.0 preflight verifies this.

##### Parser (preferred path: `yq`; fallback: portable awk)

```bash
ESSENTIALS_FILE=~/.claude/templates/packs/<track>/_essentials.md
if [ ! -f "$ESSENTIALS_FILE" ]; then
  echo "WARN: no _essentials.md for track <track> — falling back to standard copy"
  # ... use standard mode instead
else
  # Extract YAML frontmatter (everything between the first two '---' lines).
  FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print}' "$ESSENTIALS_FILE")

  # Preferred: yq (correct YAML parser; install hint emitted by Phase 4.0 preflight if missing).
  if command -v yq >/dev/null 2>&1; then
    ESSENTIAL_AGENTS=$(printf '%s\n' "$FRONTMATTER" | yq -o=tsv '.essentials.agents      | join(" ")')
    ESSENTIAL_COMMANDS=$(printf '%s\n' "$FRONTMATTER" | yq -o=tsv '.essentials.commands    | join(" ")')
    ESSENTIAL_SKILLS=$(printf '%s\n' "$FRONTMATTER" | yq -o=tsv '.essentials.skills      | join(" ")')
    ESSENTIAL_RULES=$(printf '%s\n' "$FRONTMATTER" | yq -o=tsv '.essentials.rules       | join(" ")')
    ESSENTIAL_PATTERNS=$(printf '%s\n' "$FRONTMATTER" | yq -o=tsv '.essentials["ai-patterns"] | join(" ")')
  else
    # Portable fallback: awk parser locked to the format-contract shape above. Refuses
    # multi-line arrays (which the format contract forbids) instead of silently truncating.
    parse_essentials_list() {
      local key="$1"
      printf '%s\n' "$FRONTMATTER" | awk -v key="$key" '
        $0 ~ "^  " key ":[[:space:]]*\\[" {
          line = $0
          # Refuse to continue if the array spans multiple lines (forbidden by contract).
          if (line !~ /\]/) { print "ERR_MULTILINE_ARRAY"; exit 2 }
          sub(/^  [a-zA-Z_-]+:[[:space:]]*\[/, "", line)
          sub(/\][[:space:]]*$/, "", line)
          gsub(/[[:space:]]/, "", line)
          gsub(/,/, " ", line)
          print line
          exit 0
        }
      '
    }
    ESSENTIAL_AGENTS=$(parse_essentials_list "agents")
    ESSENTIAL_COMMANDS=$(parse_essentials_list "commands")
    ESSENTIAL_SKILLS=$(parse_essentials_list "skills")
    ESSENTIAL_RULES=$(parse_essentials_list "rules")
    ESSENTIAL_PATTERNS=$(parse_essentials_list "ai-patterns")

    # Halt explicitly when the format contract was violated rather than silently
    # propagating a truncated essentials list.
    for v in "$ESSENTIAL_AGENTS" "$ESSENTIAL_COMMANDS" "$ESSENTIAL_SKILLS" "$ESSENTIAL_RULES" "$ESSENTIAL_PATTERNS"; do
      [ "$v" = "ERR_MULTILINE_ARRAY" ] && {
        echo "HALT: $ESSENTIALS_FILE uses multi-line array syntax. The _essentials.md format contract requires flat [a, b, c] arrays. Install yq to handle richer YAML, or fix the manifest."
        exit 2
      }
    done
  fi

  # Copy only the listed files
  mkdir -p .claude/agents
  for name in $ESSENTIAL_AGENTS; do
    [ -z "$name" ] && continue
    cp ~/.claude/templates/packs/<track>/agents/$name.md .claude/agents/ 2>/dev/null || true
  done

  mkdir -p .claude/commands
  for name in $ESSENTIAL_COMMANDS; do
    [ -z "$name" ] && continue
    cp ~/.claude/templates/packs/<track>/commands/$name.md .claude/commands/ 2>/dev/null || true
  done

  mkdir -p .claude/skills
  for name in $ESSENTIAL_SKILLS; do
    [ -z "$name" ] && continue
    cp -R ~/.claude/templates/packs/<track>/skills/$name .claude/skills/ 2>/dev/null \
      || cp ~/.claude/templates/packs/<track>/skills/$name.md .claude/skills/ 2>/dev/null \
      || true
  done

  mkdir -p .claude/rules
  for name in $ESSENTIAL_RULES; do
    [ -z "$name" ] && continue
    cp ~/.claude/templates/packs/<track>/rules/$name.md .claude/rules/ 2>/dev/null || true
  done

  mkdir -p ai/patterns
  for name in $ESSENTIAL_PATTERNS; do
    [ -z "$name" ] && continue
    cp ~/.claude/templates/packs/<track>/ai-patterns/$name.md ai/patterns/ 2>/dev/null || true
  done
fi

# Framework references — same logic, no minimal/standard distinction (always essential when detected)
mkdir -p .claude/references
for fw in <detected-frameworks>; do
  cp -R ~/.claude/templates/packs/<track>/references/${fw}.md .claude/references/ 2>/dev/null || true
done
```

#### Always-included regardless of `--minimal`

These are NEVER reduced by `--minimal` — they're foundational:
- All 7 baseline hooks.
- `learning` track ENTIRE pack (knowledge-curator, drift-detector, pattern-watcher agents + refresh-knowledge, detect-drift, learn-from-task, promote-pattern commands + extract-project-context skill). Phase 6 learning loop requires the full set.
- All `ai/` baseline files (status, stack, modules, conventions, business-domain, project-goals, etc.).
- 3 compact derived files (`_session-digest.md`, `_decision-index.md`, `_convention-cheatsheet.md`).
- Business-domain content for the detected domain (`ai/business-domain.md` + 5 supporting files). The user's domain knowledge isn't optional.
- Tool adapter outputs for selected tools (`opencode.json`, `.cursor/rules/`, etc.).

`--minimal` only reduces TRACK packs (`agents/`, `commands/`, `skills/`, `rules/`, `ai-patterns/`); it does NOT touch baseline, learning, or domain content.

### 4.2.c Immediate post-copy verification (per-track)

After each track's copy, IMMEDIATELY count what landed:

```bash
echo "Track <track> copied:"
echo "  agents:    $(ls .claude/agents/*.md 2>/dev/null | wc -l)"
echo "  commands:  $(ls .claude/commands/*.md 2>/dev/null | wc -l)"
echo "  skills:    $(ls .claude/skills/ 2>/dev/null | wc -l)"
echo "  rules:     $(ls .claude/rules/*.md 2>/dev/null | wc -l)"
echo "  patterns:  $(ls ai/patterns/*.md 2>/dev/null | wc -l)"
```

Compare to pre-flight inventory expected counts. If shortfall: re-run that track's copy commands (Phase 5 retry loop catches systematic failures).

### Merge handling (when files already exist in target)

If a destination file already exists (`.claude/agents/code-reviewer.md` already there from a prior run):
- Default behavior: SKIP (don't overwrite — `cp -n` semantics).
- `--force-replace-all`: overwrite.
- `--force-keep-all`: same as default (skip).
- Pre-flight inventory must distinguish: "X new files + Y skipped (already exist)".

### Rules (preserved from prior version)

- **No-thinning rule**: pack files are copied verbatim. The shell does the copy; the LLM never edits during 4.2.
- **Pack-depth floor**: Phase 4.0 (pack-load preflight) verifies every pack file ≥100 lines BEFORE 4.2 runs. If any pack source is thin, halt + report — do NOT propagate shallow content.
- **Reference-path injection (Phase 4.6)** runs AFTER Phase 4.2 — it adapts content with project paths but never trims.

### Why deterministic, not LLM-driven?

Pack copying is mechanical. There's zero creative work required. The LLM's job in Phase 4.2 is to:
1. Enumerate which tracks to copy (decision work — LLM appropriate).
2. Run the `cp` commands above (mechanical work — shell appropriate).
3. Run the verification counts (mechanical — shell appropriate).
4. Report the actuals (decision work — LLM appropriate).

When the LLM was previously responsible for writing each pack file by hand, it could (and did) skip files under context pressure. Shell `cp` cannot skip.

**4.3 Apply framework references** — only for frameworks detected in profile. Copy from `packs/<track>/references/<name>.md` into repo's `.claude/references/`.

**4.4 Apply technical-domain tooling** — for every TECHNICAL signal detected in profile (multi-tenant, webhook, payment, AI, real-time, etc.), copy from `~/.claude/templates/domains/<signal>/` (agents, commands, rules, ai-patterns). Each file passes through merge matrix.

**4.4b Apply BUSINESS-domain content** (THIS IS THE STEP THAT WAS MISSING — the cause of generic-feeling output):

For every business domain detected in profile (`ecommerce`, `lms`, `fintech`, etc., from §2.x), pull content from `~/.claude/templates/business-domains/<domain>/` into the repo's `ai/`:

| Source pack file | Destination | What it does |
|---|---|---|
| `glossary.md` | `ai/core/glossary.md` | Domain entities + state machines + vocabulary |
| `core-flows.md` | `ai/business-flows.md` | P1/P2/P3 user journeys for this domain |
| `feature-checklist.md` | `ai/business-feature-checklist.md` | What v1s commonly miss in this domain |
| `compliance.md` | `ai/business-compliance.md` | Regulatory landscape (GDPR, PCI, HIPAA, FERPA, etc.) |
| `stakeholders.md` | `ai/core/stakeholders.md` | Roles + their workflows + KPIs |
| `anti-patterns.md` | `ai/runtime/domain-anti-patterns.md` | Domain-specific traps (different from generic SRE anti-patterns) |

Plus a top-level summary: `ai/business-domain.md` — declares which domain(s) this project belongs to, why (which signals matched), and links to the 6 detail files above.

For UNIONS (e.g., ecommerce + affiliate): copy each domain's files; merge glossaries (entities deduplicated); concatenate flows + checklists with section headers per domain.

**4.4b.1 Regulatory overlay** (consume Phase 2.y `Constraints` facet — regulatory regime answer):

The generic `ai/business-compliance.md` (copied from `business-domains/<domain>/compliance.md` above) covers the domain's universal compliance landscape (e.g., healthcare → HIPAA + FERPA; ecommerce → PCI-DSS + GDPR). But the project's actual regulatory regime is project-specific — a Saudi healthcare backend needs NPHIES + SCFHS + MOH-SA + CBAHI rules, NOT US-centric HIPAA defaults; a UAE fintech needs CBUAE + SCA rules, NOT just SOC2. The Phase 2.y `Constraints` answer drives a per-project overlay:

```bash
# After domain-pack copy:
REGULATORY_REGIMES=$(extract_phase_2y_field "regulatory_regime")  # comma-separated list

if [ -n "$REGULATORY_REGIMES" ]; then
  # Append project-specific regulatory section to ai/business-compliance.md
  for regime in $REGULATORY_REGIMES; do
    overlay_file="$HOME/.claude/templates/regulatory-overlays/${regime}.md"
    if [ -f "$overlay_file" ]; then
      # Concrete overlay exists — append it (with section header) to ai/business-compliance.md
      append_with_section_header "$overlay_file" "ai/business-compliance.md" "$regime"
    else
      # No prebuilt overlay — write a research stub flagging the gap
      append_research_stub "ai/business-compliance.md" "$regime"
      # Also queue for Phase 6: knowledge-curator should research + populate this regime
      # the next time the user runs /refresh-knowledge.
    fi
  done

  # Cross-reference into the project's failure catalog
  echo "## Regulatory anti-patterns (per declared regime: $REGULATORY_REGIMES)" \
    >> "ai/failures/_regulatory-checklist.md"
fi
```

**Overlay catalog** (`~/.claude/templates/regulatory-overlays/`): one file per regime. Each overlay covers:
- Regime overview + jurisdiction + scope of applicability
- Specific data-residency / locality rules (MUST a request from country X serve from servers in country X?)
- Specific consent / disclosure requirements (what UI/UX is mandated?)
- Specific reporting / audit cadence (how often must logs be retained, where must they go?)
- Specific incident-response timelines (e.g., 72-hour breach notification under GDPR; 30-day under CCPA)
- Specific anti-patterns (things that PASS the generic domain compliance file but FAIL this regime)
- Required integrations (e.g., NPHIES API for Saudi healthcare claims; SAMA reporting for Saudi banking)

**Bootstrapped overlays** (initial catalog — extend by saving back via Phase 4.5 generate-missing when an unknown regime is encountered):

| Regime | File | Domain affinity |
|---|---|---|
| GDPR | `regulatory-overlays/gdpr.md` | Universal (any product touching EU users) |
| CCPA / CPRA | `regulatory-overlays/ccpa.md` | Universal (any product touching California users) |
| HIPAA | `regulatory-overlays/hipaa.md` | Healthcare (US) |
| PCI-DSS | `regulatory-overlays/pci-dss.md` | Payments (universal) |
| SOC2 | `regulatory-overlays/soc2.md` | Universal (any B2B SaaS doing security audits) |
| ISO-27001 | `regulatory-overlays/iso-27001.md` | Universal (any product with formal infosec) |
| NPHIES | `regulatory-overlays/nphies.md` | Healthcare (Saudi Arabia) — claims/eligibility integration |
| SCFHS | `regulatory-overlays/scfhs.md` | Healthcare (Saudi Arabia) — practitioner registration |
| MOH-SA | `regulatory-overlays/moh-sa.md` | Healthcare (Saudi Arabia) — Ministry of Health rules |
| CBAHI | `regulatory-overlays/cbahi.md` | Healthcare (Saudi Arabia) — accreditation |
| SAMA | `regulatory-overlays/sama.md` | Banking / fintech (Saudi Arabia) |
| CBUAE / SCA | `regulatory-overlays/uae-finance.md` | Banking / fintech (UAE) |
| FERPA | `regulatory-overlays/ferpa.md` | Education (US) |
| LGPD | `regulatory-overlays/lgpd.md` | Universal (any product touching Brazilian users) |
| PDPA | `regulatory-overlays/pdpa.md` | Universal (Singapore / Thailand / Malaysia variants) |

**Research stub** (when no prebuilt overlay exists for a declared regime). The literal token `__REGIME__` (double-underscore-bracketed, not angle-brackets) is used so this stub does NOT trigger the Phase 5.3.5 cross-project leak scan, which flags `<…>` style placeholders as "Phase 4.6 produced template-stamp output". `append_research_stub` substitutes the actual regime name on write, leaving zero placeholders behind on disk:

```markdown
## __REGIME__ — research stub (no prebuilt overlay yet)

> User declared this regulatory regime in Phase 2.y but no overlay file exists at
> `~/.claude/templates/regulatory-overlays/__REGIME__.md`.
>
> **Action items** (queued for Phase 6 `/refresh-knowledge`):
> 1. Research: regime overview, jurisdiction, scope, data-residency rules, consent rules,
>    audit cadence, incident-response timelines, regime-specific anti-patterns, required integrations.
> 2. Author overlay at `~/.claude/templates/regulatory-overlays/__REGIME__.md`.
> 3. Re-run `/setup-project --refresh` to consume the new overlay.
>
> Until then: every PR / agent / change touching __SCOPE__ (PII / payments / clinical data / etc.)
> MUST be reviewed against this regime by a human with regime expertise.
```

`append_research_stub`'s contract: replace every occurrence of `__REGIME__` with the regime name and `__SCOPE__` with the relevant data scope before writing. After substitution the rendered section MUST contain zero `__…__` and zero `<…>` tokens — Phase 5.3.5 leak scan asserts this.

**Phase 5 audit**: confirms `ai/business-compliance.md` has a regime-specific section for each declared regime (concrete overlay or research stub). Missing section = HALT (the user declared a regime that the system silently dropped).

**4.5 Generate missing** — signal detected but no specialized agent exists? Generate from external library (awesome-subagents / agents-main) or best practices. Save to `packs/<track>/agents/<name>.md` for reuse.

**4.6 Adapt output to detected conventions** — this is what makes the setup actually MATCH the project's style instead of overwriting it with generic prose.

**Execution model — runs via the `apply-pack-adaptation` skill**:

Phase 4.6's per-file STUDY → DECIDE → ACT loop runs through the **`apply-pack-adaptation`** skill (lives at `~/.claude/templates/packs/learning/skills/apply-pack-adaptation.md`). The skill consumes:

- `.claude/_extracted-codebase.md` (Phase 2 deep extraction)
- `.claude/_extracted-idioms.md` (Phase 2.5 per-base-class idioms)
- `.claude/_extracted-business.md` (Phase 2 Step 13 business context)
- `.claude/codebase-profile.md` (condensed projection)
- `ai/conventions.md`, `ai/business-domain.md`, `ai/_decision-index.md`, `ai/failures/_index.md` (where they exist)
- The pack-added file list (every file written by Phase 4.2 / 4.4 / 4.4b in this run)
- Mode (CREATE / ENHANCE-retrofit / ENHANCE-extend / REFRESH)

The skill produces:
- The **adapted files** (anchor block prepended, redirect note prepended, or file deleted) — in-place edits to pack-added files.
- **`.claude/_phase-4-6-decisions.md`** — decision log (one row per pack-added file: file, decision, reason, identifiers cited). Phase 5.3 audit consumes this to verify the skill ran for every file and produced quality output (anchor presence + body density + identifier traceability + no placeholder syntax).

**Why a skill, not inline**: setup-project.md is ~4000 lines. Under context pressure, the LLM running it has historically skipped Phase 4.6 — the failure mode Critical Execution Rule 7 exists to prevent. The skill runs in a sub-context with focused inputs and the per-file judgment contract. This mirrors the Phase 2 pattern (extract-codebase-overview skill) — proven architectural separation.

**The contract below describes the skill's outputs and what setup-project depends on**; the canonical implementation (per-file STUDY-DECIDE-ACT loop, anchor template shapes, special cases for engineering-principles.md section filtering, workflow files, extraction-weak handling) lives in the skill file. When this section talks about *what gets adapted*, that's the contract; when it shows an *anchor shape*, that's a snapshot — the skill is the source of truth.

**Auto-injected blocks (every agent — these are setup-project responsibilities, NOT skill-internal)**:

The pre-flight + verification + frontmatter blocks below are injected by setup-project's main loop into every copied/generated agent BEFORE the skill runs. They're cross-cutting (apply to every agent regardless of file category) and orthogonal to per-file adaptation (which the skill handles).

**Pre-flight injection (every agent)** — every copied agent's frontmatter body gets a mandatory tiered pre-flight section prepended:

```markdown
## Pre-flight (auto-injected — tiered context loading)

### Always (Tier 1)
1. `ai/_session-digest.md` — compact bootstrap (project + stack + top conventions + recent decisions + corrections to avoid).

### Load by task type (Tier 2)
- Code-write tasks → `ai/_convention-cheatsheet.md` (top 20 rules)
- Feature work → `ai/business-domain.md` + `ai/business-flows.md`
- Architectural decisions → `ai/_decision-index.md`
- Bug fix → `ai/runtime/context.md`

### Load on demand (Tier 3)
- Full `ai/conventions.md` (when cheatsheet isn't enough)
- Full `ai/patterns/<name>.md` (when applying that pattern)
- Specific `ai/decisions/<NNNN>-*.md` (when relevant to architectural decision)
- Specific `.claude/rules/<name>.md` (deep dive into a rule)

### Before modifying (mandatory discovery — applies to every code change)
- **Identify inputs, outputs, and dependencies** of the function / class / module you're about to change. Inputs = parameters + reads from outer scope (env, config, DB, network). Outputs = return value + writes (DB, files, events, logs, mutations of inputs). Dependencies = direct callees + injected services + imports. If you can't trace these in ~2 minutes (signature read + caller grep + downstream effects scan), STOP — read more, or ask. The "I'll figure it out as I go" pattern is how silent regressions ship.
- **Read the existing file you're modifying** — MIRROR its shape exactly (imports order, error-handling style, logging style, comment density). The file is the local style guide; deviation is a bug.
- **Read 1-2 sibling files** in the same layer to confirm the shape is project-wide, not just local to one file. Two siblings agreeing = pattern; one file alone = could be drift.
- **Locate the home before writing new code.** Every new file / module / feature must map to a defined home in `ai/modules.md`. If nothing fits, plan a new module first (record an ADR if architectural) or ask. Loose files in the repo root or in catch-all `utils/` / `shared/` / `common/` folders is the failure mode this rule prevents.

### Boy Scout Rule (when modifying)
- Leave the file cleaner than you found it: kill dead imports, delete commented-out code, sharpen vague names, cut redundant comments — but ONLY adjacent to your change. Don't balloon the diff into a whole-file rewrite; one obvious cleanup per touched file is the bound. Real refactors get their own PR with a stated reason.

If your task contradicts what you read at any tier, STOP and ask before acting.
```

**Verification injection (every agent)** — Anthropic's #1 leverage point: agents that ship plausible-looking-but-wrong code lose user trust fast. Every generated agent's frontmatter body gets a mandatory `## Verification` section appended:

```markdown
## Verification (how you know your work succeeded)

Before reporting done, run + show:
1. <Stack-detected lint command — e.g., `pnpm lint` / `mvn checkstyle` / `cargo clippy`>
2. <Stack-detected type-check — e.g., `pnpm typecheck` / `mypy` / `tsc --noEmit`>
3. <Stack-detected tests for the touched module — e.g., `pnpm test path/to/module`>
4. For UI changes: screenshot via Playwright + visual diff.
5. For API changes: hit the endpoint via curl + verify response shape against DTO (use `/endpoint-test`).
6. For DB changes: `EXPLAIN ANALYZE` the affected queries; confirm indexes used.

Failed verification = halt + report, don't paper over.
```

The verification commands are STACK-DETECTED at setup time (Phase 4.6 ADAPT step) so each agent's verification list cites the actual commands the project uses, not generic placeholders.

**Frontmatter constraints (every generated agent)** — token + permission discipline:

```yaml
---
name: <agent-name>
description: <one-line; first ≤90 chars are the matching keyword cluster>
tools: [Read, Grep, Glob, Bash]   # explicit allowlist; default to MINIMUM needed
model: sonnet                      # opus for complex reasoning; haiku for cheap exploration; sonnet default
---
```

Model assignment by agent type:
- **Architect / reviewer / decision-maker**: `opus` (worth the cost for hard reasoning).
- **Default agents**: `sonnet`.
- **Cheap explorers** (find-module, grep-heavy lookups, doc-drift-scan): `haiku`.
- **Test runners + lint runners**: `haiku` (deterministic work).

`tools:` constraint — generated agents get the MINIMUM needed:
- Architects + reviewers: `[Read, Grep, Glob]` (no Edit — they design, they don't implement).
- Implementers: `[Read, Grep, Glob, Edit, Write, Bash]`.
- Test runners: `[Read, Bash]`.
- Skip if absent (defaults to all tools — only do this for top-level orchestrator agents).

This injection is non-negotiable: every agent (pack, generated, framework-specific) gets it. Agent frontmatter `description` field stays as-is from the pack; only the body + frontmatter `tools:`/`model:` get adjusted.

**Per-file adaptation (path injection + convention prose injection + per-rule adaptation shape)** — handled by the `apply-pack-adaptation` skill (see "Execution model" at the top of this section). The skill produces:

- A **`## Reference paths`** section in every generic agent, populated with real base-class paths + extender counts from `.claude/_extracted-codebase.md` (never hand-written, never carried from another project's run).
- A **`## Project-specific (<project-name>)`** block at the TOP of every adapted rule, citing this codebase's actual file/class/property/DB-column/DI/test naming + base classes + helpers (data access, DTOs, controllers, error hierarchy) — all sourced from extraction.
- The **STUDY → DECIDE → ACT loop** per file (CHANGE-anchor / CHANGE-anchor-with-warn / LEAVE-with-redirect / LEAVE-delete) — see skill § "Decision matrix."
- The **`[EXTRACTION-WEAK]`** flag on anchors produced when extraction has no signal for the topic — Phase 5 audit reports these.

The skill's anchor templates are the canonical shapes. Phase 5.3 audits anchor quality (presence + body density ≥3 lines + identifier traceability for path-citing categories + no placeholder syntax + leak scan against extraction). Anti-patterns the audit catches: missing anchor (skill skipped), thin anchor ("`'this project uses TypeScript'`"-class lazy output), placeholder anchor (`<RepositoryBase>`, `<TODO>`), leaked anchor (cites identifier not in extraction).

**Tie-breaking**: see Decision engine § "Tie-breaking" — detected convention wins; pack rule body stays below the project-specific block.

**What gets adapted (per detected facet)**:
| Detected facet | Adaptation site |
|---|---|
| Naming patterns | Top of every rule + `ai/conventions.md` |
| Base class paths | "Reference paths" section in agents + rules |
| Test framework + colocation | `.claude/rules/testing.md` adaptation; agent pre-flight |
| Error handling base + mapper | `.claude/rules/error-handling.md`; controller agent |
| Auth scheme + guards | `.claude/rules/auth.md`; security agents |
| i18n key convention | `.claude/rules/i18n.md`; frontend agents |
| Module folder layout | `.claude/rules/module-structure.md`; api-architect's "File list" template uses detected layout |

**4.7 Knowledge base** — adaptive output:
- Always include `ai/references/models.md` from `~/.claude/templates/repo-baseline/ai/references/` (driver → model routing map, Kimi/local recipes).
- CREATE: generate `CLAUDE.md`, `ai/architecture.md`, `ai/stack.md`, `ai/modules.md`, `ai/status.md`, `ai/conventions.md` (see special handling below), `ai/patterns/project-structure.md` + 1-3 project-critical patterns, `ai/runbooks/phase-1-mvp-plan.md` (DOMAIN-FLAVORED — if ecommerce, the MVP plan covers cart→checkout→pay; if lms, course-creation→enrollment→first-lesson), 2-4 ADRs. All concrete content, no placeholders.
- CREATE knowledge base must also reference the business domain in `CLAUDE.md` opener: "This is a `<domain>` product. Read `ai/business-domain.md` for entities + canonical flows."
- ENHANCE: leave user-authored `ai/` files untouched. Only prepend a dated `Recent Changes` entry to `ai/status.md`. Add new files (ADRs, patterns, business-domain content) ONLY if a new concept emerged; never rewrite existing.
- ENHANCE that detects a business domain MUST populate `ai/business-domain.md` + `ai/core/glossary.md` if absent — these are foundational and shouldn't be missing in a profiled project.

**`ai/conventions.md` MUST be auto-populated from the codebase profile** (not generic). Generic conventions ("use camelCase") are useless. The file content is built from Phase 2 detection results — every value below is a placeholder filled at write time from `.claude/_extracted-codebase.md`. The LLM authoring this file MUST NOT carry concrete class names / paths / library names from any other project's run.

```markdown
# Project conventions

Auto-populated from `.claude/codebase-profile.md` on <DATE>. Re-run `/setup-project` to refresh.

## File naming
- Source files: <detected pattern from extraction — kebab / snake / camel / pascal>.<detected ext>
- Test files: <detected pattern>.<detected ext> (location: <colocated | separate test/ dir>)
- Migration files: <detected pattern — e.g. timestamp-prefix or sequence>

## Class + identifier naming
- Classes: <detected case>
- Properties: <detected case>
- DB columns: <detected case — snake / camel / pascal>
- Constants: <detected case>
- Suffix matrix (only fill rows the codebase actually uses; omit rows that don't apply):
  | Concept | Suffix in this codebase | Example file from extraction |
  |---|---|---|
  | <e.g., Service / Handler / UseCase / Resolver — whichever this codebase uses> | <detected suffix> | <real example path from extraction> |
  | <e.g., Controller / Router / View / Endpoint> | <detected suffix> | <real example path> |
  | <e.g., Repository / DAO / Query / Mapper> | <detected suffix> | <real example path> |
  | <e.g., DTO / Schema / Form / Serializer / Pydantic model> | <detected suffix + create/update prefix if any> | <real example path> |
  | <e.g., Entity / Model / Record> | <detected suffix> | <real example path> |
  ... (only rows the project's extraction shows — do NOT add hypothetical rows)

## Layer architecture (from `ai/architecture.md`)
- <detected dependency direction — e.g., core → application → infrastructure, or controllers → services → repositories, or whatever shape Phase 2 found>
- Layer enforcement: <yes via dependency-cruiser / arch-unit / lint plugin, or no — detected at Phase 2>

## Base classes (from codebase profile — list ONLY base classes with ≥3 extenders found in extraction; OMIT this section if the project doesn't use inheritance-based bases)
- `<DetectedBase>` at `<detected/path>` — extended by <N> <subjects>
- `<DetectedBase>` at `<detected/path>` — extended by <N> <subjects>
- ... (one line per real base from extraction; never invent)

## Code style (from manifest + formatter config)
- Language version: <from manifest — TypeScript x / Python x / Go x / Rust edition / Ruby x / etc.>
- Formatter: <detected — Prettier / Black / gofmt / rustfmt / RuboCop / etc.> with <detected settings: quote style, trailing comma, line width, indent>
- Linter: <detected — ESLint / Ruff / golangci-lint / Clippy / etc.> with <detected plugin set>
- Strict typing: <detected — yes/no based on tsconfig strict / mypy strict / Sorbet / etc.>
- Unused-var convention: <detected — _-prefix / underscore_ / inline disable comment>

## Testing (from extraction Step 10)
- Framework: <detected — Jest / Vitest / Pytest / Go test / RSpec / etc.>
- File naming: <detected suffix>
- Location: <detected — colocated with source / separate test/ dir / mirrored tree>
- Mock style: <detected — fixture / spy / fake / contract>
- E2E: <separate dir + suffix, OR not detected>

## Imports + aliases (from tsconfig / pyproject / module manifest)
- <detected alias 1> → <detected target>
- <detected alias 2> → <detected target>
- ... (only real aliases; omit if project doesn't use any)
- Relative-parent depth limit: <detected from grep / lint, or "no rule detected">

## Anti-patterns to flag (from codebase scan — counts only; we don't fix)
- `<noisy-debug primitive — e.g., console.log / print / fmt.Println / dbg!>` count: <N> instances → use <detected logger from extraction>
- `<broad-type — e.g., any / interface{} / dict / Object>` count: <N> instances → never add new ones
- Swallowed errors (`<detected pattern — e.g., catch {} / except: pass / .ignore()>`): <N> instances → never add new ones

## When this file conflicts with `.claude/rules/*.md`
This file (auto-detected from real code) wins. Pack rules adapt above it via the "Project-specific" block at the top of each rule.
```

If a facet wasn't detected (CREATE mode, no code yet), write `_TBD — populate as code is written_` rather than generic defaults. **Never** copy values from a different project's extraction into this template — that's the leak failure mode Phase 5.3.5 (leak scan) catches.

`CLAUDE.md` opener structure (ALWAYS this shape, regardless of stack):

```markdown
# <Project> — Project Rules

## You are the Principal Engineer of this project

When working in this codebase, you act as a Principal Engineer / Tech Lead — not an assistant. That means:

- Decisions, not surveys. Pick the right approach + state the reason. Survey only when explicitly asked.
- Push back on bad ideas. "That'd work but cost X — Y is better because Z." Then proceed if user confirms.
- Cite prior art. Use this codebase's conventions + the established patterns documented below.
- Think in 6-month consequences, not next-commit consequences.
- Audit your own output. If two of your suggestions contradict, fix them before reporting.
- Teach in the artifacts. Comments + commits + ADRs explain WHY, not just WHAT.

## Project at a glance

- **Mission**: <one-sentence from `ai/project-goals.md`>
- **Domain**: <ecommerce | lms | ...> — see `ai/business-domain.md`
- **Stage**: <P1 MVP | P2 monetization | P3 scale | mature> — see `ai/status.md`
- **Primary user**: <persona from `ai/users-and-personas.md`>

## Detected stack + conventions (this is what your code already looks like)

- Stack: <detected list — language, framework, ORM, runtime, build tool>
- File naming: <detected pattern>
- Class / identifier naming + suffix matrix: <detected pattern>
- Base classes / patterns this project uses: <list ONLY real bases from extraction with their paths + extender counts; OMIT this line if the project doesn't use inheritance-based bases>
- Test colocation: <detected — colocated/separate, pattern>
- Auth scheme: <detected — JWT/session/OAuth/none>
- DB column naming: <detected — snake_case / camelCase / etc., or n/a if no DB>
- Logger lib: <detected from extraction — replaces ad-hoc print statements>
- i18n lib + locales: <detected — replaces hardcoded strings, or n/a>

> Every value above comes from `.claude/_extracted-codebase.md`. Do NOT invent or copy from another project.

For full conventions: see `ai/conventions.md`.

## Required reading before ANY code change

In this exact order:
1. This file (`CLAUDE.md`).
2. `ai/conventions.md` — auto-detected style + naming.
3. `ai/business-domain.md` — what kind of product this is + entities.
4. `ai/project-goals.md` — mission + KPIs + anti-goals.
5. `ai/dynamic/feedback-learned.md` — corrections from prior sessions (don't repeat them).
6. The existing module you're editing — MIRROR its shape exactly.

If the task contradicts what you read in 1-6, STOP. Ask the user before acting.

## Read-before-edit rule (#1 invariant)

Before creating or modifying any file, read the same TYPE of file (controller, service, repo, mapper) elsewhere in the codebase and match the existing pattern exactly. Consistency with existing code beats personal preference.

## Decision boundaries

You CAN decide and proceed without asking:
- Code-level implementation matching existing patterns
- Test additions for the change you're making
- Lint / format fixes within the file you're editing
- Naming choices that follow the suffix matrix

You MUST ask before:
- Adding a new dependency (`pnpm install`).
- Introducing a new architectural layer or pattern.
- Touching > 10 files in one PR.
- Migration / schema change.
- Anything that affects > 1 sub-project (in workspace mode).
- Editing `ai/decisions/` (formal ADRs).

## When you find drift

If existing code violates a documented rule:
- Don't silently fix it (that's scope creep).
- Append finding to `ai/dynamic/drift-log.md` for resolution by the user / curator.
- If the violation blocks your current task, raise it explicitly and ask how to proceed.

## When the user is wrong

Push back briefly + concretely:
> "I'd avoid X because <Y consequence>. The standard for this codebase is Z (see `ai/patterns/<file>.md`). Want me to do Z, or proceed with X anyway?"

Don't capitulate without surfacing the trade-off. Don't lecture either — one or two sentences.

## Tiered context loading (token discipline)

This project uses **3 tiers** of knowledge files. DON'T load everything every session.

### Tier 1 — HOT (auto-loaded via @ at session-start)

@ai/_session-digest.md

That's it. The session digest is a compact (≤300 lines) projection of what matters right now. It includes pointers to deeper files for when you need them.

### Tier 2 — WARM (load by task type)

When working on:
- **Code edits** → also read `ai/_convention-cheatsheet.md` (top 20 rules, ≤80 lines)
- **New feature** → also read `ai/business-domain.md` + `ai/business-flows.md`
- **Architectural decisions** → also read `ai/_decision-index.md` (drill into specific ADRs only when relevant)
- **Bug fix** → also read `ai/runtime/context.md` + relevant `ai/patterns/`
- **Audit / review** → read `ai/conventions.md` (full) + `.claude/rules/`

### Tier 3 — COLD (load on demand only)

- Specific `ai/patterns/<name>.md` files when applying that pattern.
- Specific `ai/decisions/<NNNN>-*.md` files when discussing that decision.
- Specific `.claude/rules/<name>.md` files when working in that domain.
- `ai/audits/`, `ai/runbooks/`, `ai/dynamic/` files only when needed.

### Why tiered?

Naive "read everything" pre-flight burns 3000+ lines of context per agent invocation. Tiered loading: <500 lines for Tier 1 covers ~80% of decisions; Tier 2 + 3 load on demand for the rest. **7× token reduction on bootstrap.**
```

The opener is the FIRST thing Claude reads in every session. The Principal-Engineer framing + tiered context loading + decision boundaries + push-back posture mean every subsequent task picks them up automatically — no per-task re-instruction.

**4.7b Project-context files** (consume `.claude/_extracted-business.md` from Phase 2 Step 13):

The `extract-business-context` skill has captured WHY this project exists, FOR WHOM, and AT WHAT MATURITY into `.claude/_extracted-business.md`. Phase 4.7b PROJECTS that into 5 user-facing files. **Generators here ASK NOTHING** — every needed answer is already in `_extracted-business.md` (or marked `_UNKNOWN_` there for genuine gaps). If 4.7b finds itself wanting to ask the user a question, that's an `extract-business-context` skill bug — fix the skill, don't bolt the question on here.

| File | Source section in `_extracted-business.md` | Content |
|---|---|---|
| `ai/project-goals.md` | `## Mission` + `## Success KPIs` + `## Constraints` + `## Anti-goals` | Mission statement; top 3 KPIs with target numbers; explicit non-goals; success criteria |
| `ai/users-and-personas.md` | `## Target users + personas` | 1-3 primary personas (job role, context, top 3 needs, top 3 frustrations, what makes them choose this product) |
| `ai/business-model.md` | `## Business model` | How money flows or value is delivered; pricing model if monetized; cost structure; unit economics one-liner |
| `ai/competitive-context.md` | `## Competitive context` | Closest 1-3 alternatives; why this product instead; what NOT to copy from competitors; differentiation themes |
| `ai/roadmap.md` | `## Maturity stage` + `ai/status.md` phase | Beyond P1 — what's the trajectory? Phase 2/3/4 high-level (1-2 paragraphs each, not detailed runbooks — those live in `ai/runbooks/`) |

**Population rules:**
- CREATE mode: write all 5 with content from Phase 2.y. If user couldn't answer a facet, write `_UNKNOWN — fill in when decided_` placeholder rather than fake content.
- ENHANCE mode + files absent: write them, populate from existing `ai/status.md` + ask user for the gaps.
- ENHANCE mode + files present: leave them. Append a one-line update to whichever facet changed (similar to status.md Recent Changes).
- The brain refuses to use `_UNKNOWN_` content as input to other generated files — surface them in the plan as "decisions blocked on these unknowns".

**Why these files matter:**
- New session opens → reads `CLAUDE.md` → CLAUDE.md links to these → instant project context.
- Agent working on a feature → consults `ai/users-and-personas.md` → makes UX/i18n/error-message decisions in user's vocabulary, not engineer's.
- Audit / business-auditor agent → consults `ai/project-goals.md` → flags features that drift from declared mission.
- Roadmap-agent or PM → consults `ai/roadmap.md` → proposes work that fits trajectory, not random improvements.

CLAUDE.md opener (CREATE) must reference these:
> "This is a `<domain>` product. **Mission**: `<mission from project-goals.md>`. **Primary user**: `<persona from users-and-personas.md>`. **Stage**: `<maturity stage>`. Read `ai/project-goals.md` + `ai/users-and-personas.md` + `ai/business-domain.md` before starting any non-trivial task."

### Phase 4.6-DEEP — Re-anchor Project-specific blocks with deep extraction (REFINE mode only)

**Trigger**: REFINE mode (`--refine`). Skipped in CREATE / ENHANCE / REFRESH (those modes already ran the standard Phase 4.6 — round-one anchors are sufficient there).

**Why this exists**: standard Phase 4.6 anchors with whatever extraction is available at first-pass time — typically file paths + base classes + suffix matrix + stack identifiers. That's enough for the floor. But a backend rule that cites the project's framework + a base class is still **mostly generic prose with a 5-line project-specific header**. Round-two anchors with the deep-extraction substrate from Phases 2.7–2.12 — turning the 5-line header into a 20-30-line concrete block: actual entity names with their invariants, actual flow citations, actual hot paths with their N+1 risk, actual emergent error-shape conventions. The body of the rule still gets to be teaching prose; the project-specific block gets to be exact.

**Mechanism**: invoke the `apply-pack-adaptation` skill (same skill as standard Phase 4.6) with **mode = `REFINE`**, **inputs additionally include `.claude/_refine-extract.md`**, and the **`max_subagents` parameter wired from the `--max-subagents=<N>` flag** (default `8`). The skill fans out one re-anchor subagent per shallow artifact up to the cap; remaining artifacts serialize. The skill follows the same STUDY → DECIDE → ACT contract but with extra ACT options:

| Standard 4.6 ACT | REFINE 4.6-DEEP ACT |
|---|---|
| ANCHOR — write Project-specific block from round-one signals | ANCHOR-DEEP — REWRITE existing Project-specific block using `_refine-extract.md` (entities / flows / hot paths / emergent conventions). Round-one block becomes the 5-line summary at top; deep details fill the rest. |
| LEAVE-with-redirect | LEAVE-DEEP — leave round-one block when the deep extraction adds NO new signal for this artifact's topic (e.g. a `code-quality.md` rule has no new domain entities to cite — round-one anchor is already optimal). Record reason in `_refine-log.md`. |
| CHANGE-anchor-with-warn | (same; rare in REFINE since round-one floor already established) |
| *(no analog)* | NEW-FILE — when deep extraction surfaces a genuine artifact need that round-one didn't catch. Examples: Phase 2.12 found a recurring auth-bypass theme → write `ai/failures/auth-bypass.md`. Phase 2.11 found 6 hot paths with N+1 risk → ENSURE `query-optimizer.md` is present (gap-fill if not, deep-anchor if present). |

**Decision-file**: appends to `.claude/_phase-4-6-decisions.md` with section header `## REFINE — round two (<YYYY-MM-DD HH:MM>)`. Each per-file entry includes the new ACT type + which deep-extraction sections were consumed.

**Idempotency contract**: every REFINE run reads BOTH the prior round-one anchor (from disk) AND the prior REFINE entries in `_phase-4-6-decisions.md`. If the deep-extraction content unchanged AND the artifact's anchor already cites the deep details → ACT becomes `LEAVE-DEEP-IDEMPOTENT` (no rewrite). This is what makes 2nd / 3rd `--refine` runs converge to "plateau reached."

**Coverage target**: every artifact whose anchor-density score (Phase 5.5) was < 70 in round-one MUST be re-anchored OR explicitly marked `LEAVE-DEEP` with reason. Files with score ≥ 70 are skipped by default (not worth the rewrite churn).

**Safety**: REFINE 4.6-DEEP rewrites ONLY the `## Project-specific` block delimited by the markers `<!-- project-specific:start -->` and `<!-- project-specific:end -->` (these markers are auto-injected by every Phase 4.6 anchor; standard 4.6 already uses them). User-authored content outside the markers is BIT-IDENTICAL pre/post run. The skill's pre-write step re-reads the file, computes a hash of the user-authored regions, performs the rewrite, computes the hash again — mismatch = halt with rollback.

### Phase 4.7-DEEP — Refresh ai/ knowledge base from deep extraction (REFINE mode only)

**Trigger**: REFINE mode AND ≥1 deep-extraction phase was STRONG (not all WEAK).

**Mechanism**: enrich (not replace) the auto-generated portions of `ai/` files using the deep-extraction substrate.

| ai/ file | Round-one source | REFINE-DEEP enrichment |
|---|---|---|
| `ai/architecture.md` | Phase 2 import-edge summary, layer pattern detection | + Phase 2.8 layer diagram, bounded-context boundaries, 3-5 representative request lifecycles with `file:line` |
| `ai/business-domain.md` | Phase 2.x business-domain detection | + Phase 2.7 entity list with invariants, lifecycle events, relationships |
| `ai/conventions.md` | Phase 2 detected conventions (file-naming, suffix matrix, base classes) | + Phase 2.10 emergent conventions (error shape, pagination shape, transaction-boundary, async-work naming) |
| `ai/patterns/parallel-io.md` *(if backend track)* | Phase 2 Step 15 concurrency primitives | + Phase 2.11 hot paths that should use parallel I/O — with current sequential-await citations |
| `ai/failures/<theme>.md` *(new files)* | n/a (didn't exist round-one unless user authored) | + Phase 2.12 recurring failure themes — one file per theme, with affected files + commit refs + root-cause family + prevention guidance |
| `ai/runbooks/<flow>.md` *(only when explicitly opted-in via `--refine --include-runbooks`)* | n/a | + Phase 2.9 flow narrations |

**Boundaries**:
- Each `ai/` file gets a `<!-- refine-enriched:start -->` ... `<!-- refine-enriched:end -->` block injected near the relevant section. Outside these markers stays untouched.
- `ai/status.md`, `ai/decisions/*.md` (ADRs), `ai/dynamic/feedback-learned.md` are NEVER touched by REFINE — they're Phase 6 / append-only / user-authored history.
- `ai/runbooks/` enrichment is opt-in only because runbooks are operational docs the team owns; REFINE doesn't presume to write them without explicit consent.

**Safety contract** (parity with Phase 4.6-DEEP): Phase 4.7-DEEP delegates each per-file enrichment to the `apply-pack-adaptation` skill so the same marker-bracketed write + hash-check + rollback applies to `ai/*.md` files:

1. **Markers are the only writable region.** Bytes outside `<!-- refine-enriched:start -->` ... `<!-- refine-enriched:end -->` are bit-identical pre/post run. Headers, user notes between sections, manually-added cross-refs, and any unrelated user prose all survive verbatim.
2. **Hash-check before and after**: `pre_outside_hash = SHA-256(file_bytes_outside_markers)` is captured before the rewrite; `post_outside_hash` is captured after; mismatch → ROLLBACK (restore pre-write bytes from in-memory copy) and record `ROLLBACK-MARKER-DRIFT` in `_phase-4-6-decisions.md` for that file. The REFINE run continues with the next file.
3. **Markers absent in target file** (e.g. user has hand-edited `ai/conventions.md` heavily and removed prior REFINE markers, or the file was authored before markers existed): inject the markers around an empty block at the end of the relevant section, then write the enrichment between them. Record `MARKERS-INJECTED` in the decision log so subsequent runs know the markers are now in place. NEVER overwrite the file body to install markers.
4. **First-run on `ai/failures/<theme>.md` files** is a NEW-FILE write (no markers exist yet) — the hash-check is not applicable; the contract becomes "the file did not exist pre-run; if write fails for any reason, no partial file is left on disk" (atomic write to `<file>.tmp` + rename, OR halt before write).
5. **Idempotency hash recording**: each per-file enrichment row in `_phase-4-6-decisions.md` records the SHA-256 of the `_refine-extract.md` sections actually consumed. The next REFINE run reads these hashes; if all relevant sections still match → the row becomes `LEAVE-DEEP-IDEMPOTENT` and the file is not rewritten.

This contract makes Phase 4.7-DEEP safe to run repeatedly. User-authored content in `ai/*.md` is bit-identical pre/post REFINE — only the markered region is rewritten, only when deep extraction has new signal to add.

### Phase 4.8-DEEP — Re-sync tool adapters with deepened artifacts (REFINE mode only)

**Trigger**: REFINE mode (`--refine`), after Phase 4.7-DEEP completes. Skipped in CREATE / ENHANCE / REFRESH (those modes run regular Phase 4.8 as part of the standard pipeline, which writes every adapter from scratch).

**Why this exists**: Phase 4.6-DEEP rewrites `## Project-specific` blocks of `.claude/{rules,commands,agents,skills}/*.md`; Phase 4.7-DEEP rewrites markered regions of `ai/*.md` and may write new `ai/failures/<theme>.md`. **The `claude-code` adapter is auto-current** — it reads `.claude/` directly. **Every other selected adapter is NOT** — they embed compact translations of those artifacts (`.cursor/rules/<name>.mdc` body inlined from `.claude/rules/<name>.md`; `opencode.json` `commands` block embedding command prompts; `AGENTS.md` § "Named procedures" listing every skill; `CONVENTIONS.md` embedding must/must-not from `ai/_convention-cheatsheet.md`; `.continue/rules/`, `.clinerules/`, `.windsurf/rules/`, `.github/instructions/`, `.github/prompts/`, `GEMINI.md` — all stale after REFINE). Without 4.8-DEEP, REFINE produces the failure mode "Claude got smarter, Cursor still talks generic prose." This phase closes the gap.

**Mechanism**: invoke the `apply-pack-adaptation` skill (already used by 4.6-DEEP and 4.7-DEEP) in `ADAPTER-SYNC` mode against the affected-artifact list:

1. **Collect affected artifacts**: read `.claude/_phase-4-6-decisions.md` REFINE section + `_phase-4-7-decisions.md` REFINE section. Build the list:
   - **Anchor changes**: every artifact with action `ANCHOR-DEEP` in 4.6-DEEP (`.claude/{rules,commands,agents,skills}/*.md` whose `## Project-specific` block was rewritten).
   - **New artifacts**: every artifact with action `NEW-FILE` in 4.6-DEEP (a brand-new `.claude/skills/<name>/SKILL.md` or `.claude/rules/<name>.md` that 4.6-DEEP added because deep extraction surfaced a genuine gap).
   - **`ai/` changes**: every `ai/*.md` whose `<!-- refine-enriched:start/end -->` markers were rewritten in 4.7-DEEP, plus every new `ai/failures/<theme>.md`.
   - **Index-impacting flag**: set `index_refresh = true` if the affected list contains ANY `NEW-FILE` row — adapter "index" outputs (which enumerate every command / agent / skill) MUST regenerate.

2. **Per-adapter affected output map**: for each adapter selected at Phase 3.2 (read `.claude/codebase-profile.md`'s adapter list), the affected artifacts produce a list of adapter-side outputs to re-translate. The mapping reuses Phase 4.8.0's per-adapter contract — the only thing that changes is **which** outputs run, not **how** they're written:

   | Adapter | Per-artifact re-translation | Index-refresh outputs (when `index_refresh = true`) |
   |---|---|---|
   | `claude-code` | NO-OP — REFINE wrote `.claude/` directly. | NO-OP. |
   | `opencode` | For each affected `.claude/commands/<x>.md`: re-render the corresponding `commands.<x>` entry in `opencode.json` (description + prompt). | Regenerate `commands` block fully (every command); regenerate `AGENTS.md` § "Invokable commands", "Named personas", "Named procedures" sections. |
   | `cursor` | For each affected `.claude/{rules,commands,agents}/<x>.md` or `.claude/skills/<x>/SKILL.md`: re-render the corresponding `.cursor/rules/{<domain>,command-<x>,agent-<x>,skill-<x>}.mdc`. | Regenerate `.cursor/rules/00-project.mdc` cross-references section. |
   | `aider` | For each affected `.claude/commands/*.md` or `.claude/agents/*.md` or `.claude/skills/*/SKILL.md`: regenerate the matching named-procedures / personas / runbook entry in `CONVENTIONS.md`. For each affected `.claude/rules/*.md`: refresh the must/must-not list (top 6-10 from `ai/_convention-cheatsheet.md`). | Refresh `.aider.conf.yml` `read:` list if any `ai/*.md` from the affected list is referenceable; regenerate `CONVENTIONS.md` named-procedures / personas / runbook indexes. |
   | `continue` | For each affected `.claude/rules/<x>.md`: re-render `.continue/rules/<x>.md`. For each affected command/agent/skill: re-render the corresponding `prompts:` entry in `.continue/config.yaml`. | Regenerate `.continue/config.yaml` `prompts:` block fully. |
   | `cline` | For each affected `.claude/rules/<x>.md`: re-render `.clinerules/<NN>-<x>.md`. | Regenerate `.clinerules/{80-commands,81-agents,82-skills}.md` indexes. |
   | `windsurf` | For each affected `.claude/rules/<x>.md`: re-render `.windsurf/rules/<NN>-<x>.md`. | Regenerate `.windsurf/rules/{80-commands,81-agents,82-skills}.md` indexes. |
   | `copilot` | For each affected `.claude/rules/<x>.md`: re-render `.github/instructions/<x>.instructions.md`. For each affected command/agent/skill: re-render `.github/prompts/{<command>,agent-<name>,skill-<name>}.prompt.md`. | Regenerate `.github/copilot-instructions.md` (≤2k tokens summary of CLAUDE.md). |
   | `codex` | NO per-artifact files — `codex` puts everything into a single `AGENTS.md`. | Regenerate `AGENTS.md` sections impacted: "Conventions" (if a rule changed), "Invokable commands" / "Named personas" / "Named procedures" (always when `index_refresh = true`, OR when any of those artifacts changed). Other sections (project overview, architecture, code style, deployment) are NOT touched unless the corresponding source file changed. |
   | `gemini` | If `GEMINI.md` is the **thin-pointer** variant (AGENTS.md exists): NO-OP — pointer is already current. If `GEMINI.md` is the **full-copy** variant: same as `codex`. | Same as per-artifact column. |

3. **Concurrency cap**: respects `--max-subagents=<N>` (default 8). Per-adapter generation can fan out across adapters in parallel; within an adapter, per-artifact re-translation can also fan out. Total concurrent subagents at any instant ≤ N, shared with the prior REFINE phases' caps (phase boundaries are sequential — by the time 4.8-DEEP starts, all 4.6-DEEP + 4.7-DEEP subagents have completed).

4. **User-customized adapter files**: Phase 4.8-DEEP does NOT modify adapter files the user has hand-edited beyond the "auto-generated" markers regular Phase 4.8 placed (e.g. user added a custom rule to `.cursor/rules/00-project.mdc` outside the `<!-- generated:start -->` ... `<!-- generated:end -->` block). The same marker-bracketed write contract from 4.6-DEEP / 4.7-DEEP applies: SHA-256 hash-check on bytes outside the generated markers, ROLLBACK + log on mismatch, MARKERS-INJECTED if the file has markerless prior content (record once; subsequent runs use the markers). For adapter files that have NO markers convention yet (most don't — Phase 4.8 typically writes the whole file), the per-adapter contract specifies which files are wholly auto-generated (re-write freely) vs which have user-customizable sections (use markers). See `templates/tool-adapters/<adapter>/_user-customization.md` for each adapter's customization surface.

5. **Affected-list empty → skip**: if the union of 4.6-DEEP + 4.7-DEEP affected lists is empty (e.g. Phase 4.6-DEEP returned all `LEAVE-DEEP-IDEMPOTENT` rows AND Phase 4.7-DEEP returned all `LEAVE-DEEP-IDEMPOTENT` rows), Phase 4.8-DEEP is a no-op. Log `SKIPPED-NO-CHANGES` to `_phase-4-8-decisions.md` and proceed to Phase 5.

6. **Decision log** (`_phase-4-8-decisions.md`): one row per `(adapter, output-file, action)` tuple with columns:

   | Adapter | Output file | Action | Triggered by | Notes |
   |---|---|---|---|---|
   | cursor | `.cursor/rules/database.mdc` | RE-TRANSLATED | `.claude/rules/database.md` ANCHOR-DEEP | anchor density 41 → 76 |
   | opencode | `opencode.json` `commands` block | INDEX-REFRESHED | NEW-FILE: `.claude/commands/db-migration.md` | full block regenerated |
   | aider | `CONVENTIONS.md` | RE-TRANSLATED | 4 rules ANCHOR-DEEP'd | must/must-not list refreshed |
   | claude-code | (n/a) | NO-OP | REFINE writes .claude/ directly | always skipped |
   | gemini | `GEMINI.md` | NO-OP | thin-pointer variant — AGENTS.md is source | always skipped |
   | continue | `.continue/rules/security.md` | ROLLBACK-MARKER-DRIFT | bytes outside generated markers changed | preserved user edits; user MUST re-edit |
   | windsurf | `.windsurf/rules/82-skills.md` | INDEX-REFRESHED | NEW-FILE: `.claude/skills/parallel-fanout/SKILL.md` | + skill listing |

7. **Phase 5 verification still runs**: after 4.8-DEEP, regular Phase 5's per-adapter coverage check (Phase 4.8.0 contract — every command listed, every rule translated, etc.) executes. If REFINE created a new command via NEW-FILE and 4.8-DEEP missed it, Phase 5 catches the shortfall and triggers the standard retry loop.

**Coverage target**: every artifact in the 4.6-DEEP / 4.7-DEEP affected list MUST have a `_phase-4-8-decisions.md` row for every selected adapter (or claude-code's NO-OP / gemini's thin-pointer NO-OP). No silent skips.

**Why this is a phase, not a sub-step of 4.8**: regular Phase 4.8 writes every adapter file from the full artifact set; 4.8-DEEP writes only the affected slice (much faster on a 50-rule project where REFINE only rewrote 8 rules). Splitting them keeps the round-one path cheap and makes round-two cost-bounded.

**4.8 Apply tool adapters** — runs **per scope** in workspace mode:

- **Workspace root**: gets **thin anchor versions** of `AGENTS.md` + `CLAUDE.md` + `opencode.json` — each pointing at sub-projects' own configs. No full-fat rules/commands/agents/skills at workspace root.
- **Each sub-project**: gets **full** tool adapter output matched to its own stack (rules, commands, agents, skills translations per adapter). This is driven by the Phase 4.1 recursive cascade — when 4.1 runs Phases 2→4 for sub-project P, step 4.8 runs inside P and writes P's own `.cursor/`, P's own `opencode.json`, P's own `AGENTS.md`, etc.

Non-workspace mode (single-repo): this distinction doesn't apply — everything goes at repo root.

#### `--plan` flag translation (Phase 3.5 / canonical command structure)

The `--plan` flag is universal in Claude Code (the canonical 7-phase command structure declares it). For each non-Claude adapter, the translation must teach the tool how to honor `--plan` natively, since the source-of-truth flag lives in setup-project's canonical structure but each adapter has its own command syntax.

| Adapter | How `--plan` lands |
|---|---|
| `claude-code` | Native — Phase 3.5 runs as written; plan written to `.claude/plans/`. |
| `opencode` | `opencode.json` `commands` block — each command's `prompt` includes "If the user appends `--plan` to the command invocation, write a plan in the canonical format defined at `.claude/plans/README.md` to `.claude/plans/<command>-<slug>-<timestamp>.md` and exit before implementation. Otherwise implement normally." Implementation entry: `--from-plan <file>` reads a plan and runs Phases 4-6 only. |
| `cursor` | `.cursor/rules/command-<name>.mdc` — append a section: "**Plan mode**: when user prompts `<command> ... --plan`, instead of implementing, write the plan to `.claude/plans/<command>-<slug>-<timestamp>.md` per the format in `.claude/plans/README.md`, then stop. Implementation mode (no `--plan`) runs as written above." |
| `aider` | `.aider.conf.yml` — add `read: .claude/plans/README.md` so the plan format is in context. `CONVENTIONS.md` includes a "Plan mode" section: when user types `/plan <command> "<prompt>"`, write plan to `.claude/plans/`, exit. Implementation mode is the default. |
| `continue` | `.continue/prompts/<command>.prompt.md` — branch on `--plan` arg as in OpenCode; same plan-file output. |
| `cline` / `windsurf` / `copilot` | Each command's translated prompt branches on `--plan` per the same pattern. |
| `codex` | `AGENTS.md` § "Invokable commands" — each command entry notes "supports `--plan` flag for handoff" with the format reference. |
| `gemini` | Same as codex — note in `GEMINI.md` command catalog. |

**Plan file format is tool-agnostic markdown** — every adapter consumes the same format. The only thing that varies is HOW each adapter is taught to write the plan (and how `--from-plan <file>` invokes implementation from a plan, where supported).

**Universal fallback (always works)**: any tool that reads markdown can implement from a plan by pasting the plan-file content into the tool's prompt + "implement per this plan." No native `--from-plan` required for the basic workflow.

**`/verify-plan` is universal** — it ships in `repo-baseline/.claude/commands/verify-plan.md` and is included in EVERY project regardless of which adapters are selected. Each adapter translates it the same way it translates other commands. The canonical implementation reads + audits + reports — there's no tool-specific behavior beyond that.

### 4.8.0 Per-adapter completeness contract (thin-stub-bug prevention for tool adapters)

**The historical bug**: Phase 4.8 was specced richly ("translate rules + commands + agents + skills + hooks fallback per spec") but the agent under context pressure shipped only the minimum — `opencode.json` with just an `instructions` block, nothing translated.

To prevent this, each adapter has a **minimum-output contract**. Phase 5 verifies. Coverage shortfall → retry → halt.

#### Per-adapter minimum output (each MUST produce all listed)

| Adapter | Required outputs |
|---|---|
| `claude-code` | `.claude/{agents,commands,skills,rules,hooks}/` populated per pack copy (Phase 4.2) + `.claude/settings.json` + `CLAUDE.md` at root. Note: `.claude/codebase-profile.md` is a Phase 2 output (not an adapter output); the claude-code adapter relies on it but never writes it. |
| `opencode` | (a) `opencode.json` with: `provider` block (defaults), `instructions` glob array. (b) `.opencode/agents/<name>.md` for every `.claude/agents/<name>.md` (NATIVE folder). (c) `.opencode/commands/<name>.md` for every `.claude/commands/<name>.md` (NATIVE folder). (d) `.opencode/skills/<name>/SKILL.md` (+ supporting scripts) for every `.claude/skills/<name>/` (NATIVE folder copy). (e) `AGENTS.md` with sections: `## Invokable commands`, `## Named personas`, `## Named procedures`. (f) Optional legacy mirror in `opencode.json` `commands` block when `--legacy-opencode` is set. |
| `cursor` | (a) `.cursor/rules/00-project.mdc` (alwaysApply, project-wide) + per-rule MDC files for every `.claude/rules/*.md`. (b) `.cursor/commands/<name>.md` for every `.claude/commands/<name>.md` (NATIVE folder). (c) `.cursor/commands/agent-<name>.md` for every `.claude/agents/<name>.md` (NATIVE folder — Cursor has no agent dispatch, personas are commands). (d) `.cursor/skills/<name>/SKILL.md` (+ scripts) for every `.claude/skills/<name>/` (NATIVE folder copy). (e) `.cursor/hooks.json` translating every `.claude/hooks/*.sh` to its lifecycle event (NATIVE; ≥ Cursor 2.3). |
| `aider` | (a) `.aider.conf.yml` with `read:` listing — in this exact order — `CONVENTIONS.md`, `AGENTS.md`, `ai/README.md`, `ai/status.md`, and `ai/business-domain.md` IF that file exists in the project. (b) `CONVENTIONS.md` containing: project intro + must/must-not (top 6-10 from `ai/_convention-cheatsheet.md`) + named procedures (every command) + named personas (every agent) + skill-style runbook entries (every skill) + `## Driver-dependent safety` disclosure. (c) `.aiderignore` with `.env*`, `*.lock`, `node_modules/`, `dist/`, `build/` plus project-specific migrations directories detected during Phase 2. |
| `continue` | (a) `.continue/config.yaml` with `models:` (commented stub for user keys), `rules:` listing every `.claude/rules/*.md` translated to `.continue/rules/<name>.md`, `docs:` pointing at `ai/`. (b) `.continue/rules/<name>.md` per rule (one-to-one with `.claude/rules/*.md`). (c) `.continue/prompts/<name>.md` (NATIVE prompts folder, `invokable: true`) for every command, plus `.continue/prompts/agent-<name>.md` per agent and `.continue/prompts/skill-<name>.md` per skill. (d) `.continueignore` covering `.env*`, `*.lock`, project migrations dirs (sensitive-file fallback for missing hooks). (e) Optional minimal `prompts:` mirror in `config.yaml` for Continue < 1.0 backward compat. |
| `cline` | (a) `.clinerules/00-project.md` (always loaded — project rules + driver-gap disclosure). (b) `.clinerules/<NN>-<domain>.md` per `.claude/rules/<domain>.md` (one-to-one; `<NN>` ∈ {10..79}). (c) `.clinerules/workflows/<name>.md` for every `.claude/commands/<name>.md` (NATIVE — Cline workflows = slash commands). (d) `.clinerules/81-agents.md` (every agent persona — no native dispatch). (e) `.clinerules/82-skills.md` (every skill procedure — no native skills primitive). (f) Optional `.clinerules/80-commands.md` catalog for Cline < 3.0 backward compat. |
| `windsurf` | (a) `.windsurf/rules/00-project.md` (always activation) + per-rule files. (b) `.windsurf/workflows/<name>.md` for every `.claude/commands/<name>.md` (NATIVE — Cascade workflows = slash commands). (c) `.windsurf/rules/81-agents.md` (trigger_words activation per agent). (d) `.windsurf/rules/82-skills.md`. (e) Optional `.windsurf/rules/80-commands.md` catalog for backward compat. |
| `copilot` | (a) `.github/copilot-instructions.md` (repo-wide, ≤2k tokens, summary of CLAUDE.md). (b) `.github/instructions/<domain>.instructions.md` for every `.claude/rules/*.md` (with `applyTo:` glob). (c) `.github/prompts/<name>.prompt.md` for every command (NATIVE). (d) `.github/agents/<name>.agent.md` for every agent (NATIVE — Apr 2026 GA). (e) `.github/skills/<name>/SKILL.md` (+ scripts) for every skill (NATIVE — Agent Skills GA). (f) Optional `.github/chatmodes/<name>.chatmode.md` for any agent flagged for chat-mode translation. |
| `codex` | `AGENTS.md` at root with these sections: project overview, architecture, conventions (MUST/MUST-NOT), code style, testing, deployment, `## Invokable commands`, `## Named personas`, `## Named procedures`, `## Driver-dependent safety`, `## AI-tool adapters present`. |
| `gemini` | `GEMINI.md` at root either (a) full content like AGENTS.md if no AGENTS.md exists, OR (b) thin pointer file referencing AGENTS.md if AGENTS.md exists. Plus optional Gemini-specific notes. |

#### Coverage check (Phase 5 verifies, retries on shortfall)

For each selected adapter, verify the contracted outputs exist + have content:

```bash
case <adapter> in
  opencode)
    [ ! -f opencode.json ] && SHORTFALL=1
    cmds_native=$(ls .opencode/commands/*.md 2>/dev/null | wc -l)
    cmds_expected=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
    [ "$cmds_native" -lt "$cmds_expected" ] && SHORTFALL=1 && echo "OpenCode .opencode/commands/: $cmds_native/$cmds_expected"
    agents_native=$(ls .opencode/agents/*.md 2>/dev/null | wc -l)
    agents_expected=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
    [ "$agents_native" -lt "$agents_expected" ] && SHORTFALL=1 && echo "OpenCode .opencode/agents/: $agents_native/$agents_expected"
    skills_native=$(ls -d .opencode/skills/*/ 2>/dev/null | wc -l)
    skills_expected=$(ls -d .claude/skills/*/ 2>/dev/null | wc -l)
    [ "$skills_native" -lt "$skills_expected" ] && SHORTFALL=1 && echo "OpenCode .opencode/skills/: $skills_native/$skills_expected"
    grep -q "^## Invokable commands" AGENTS.md || { SHORTFALL=1; echo "AGENTS.md missing 'Invokable commands' section"; }
    grep -q "^## Named personas" AGENTS.md || { SHORTFALL=1; echo "AGENTS.md missing 'Named personas' section"; }
    ;;
  cursor)
    cmd_native=$(ls .cursor/commands/*.md 2>/dev/null | grep -v '^.cursor/commands/agent-' | wc -l)
    cmd_expected=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
    [ "$cmd_native" -lt "$cmd_expected" ] && SHORTFALL=1 && echo "Cursor .cursor/commands/: $cmd_native/$cmd_expected"
    agent_native=$(ls .cursor/commands/agent-*.md 2>/dev/null | wc -l)
    agent_expected=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
    [ "$agent_native" -lt "$agent_expected" ] && SHORTFALL=1 && echo "Cursor agent commands: $agent_native/$agent_expected"
    skill_native=$(ls -d .cursor/skills/*/ 2>/dev/null | wc -l)
    skill_expected=$(ls -d .claude/skills/*/ 2>/dev/null | wc -l)
    [ "$skill_native" -lt "$skill_expected" ] && SHORTFALL=1 && echo "Cursor .cursor/skills/: $skill_native/$skill_expected"
    if ls .claude/hooks/*.sh >/dev/null 2>&1; then
      [ ! -f .cursor/hooks.json ] && SHORTFALL=1 && echo "Cursor: .cursor/hooks.json missing despite .claude/hooks/ being present"
    fi
    ;;
  copilot)
    prompt_native=$(ls .github/prompts/*.prompt.md 2>/dev/null | wc -l)
    cmd_expected=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
    [ "$prompt_native" -lt "$cmd_expected" ] && SHORTFALL=1 && echo "Copilot .github/prompts/: $prompt_native/$cmd_expected"
    agent_native=$(ls .github/agents/*.agent.md 2>/dev/null | wc -l)
    agent_expected=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
    [ "$agent_native" -lt "$agent_expected" ] && SHORTFALL=1 && echo "Copilot .github/agents/: $agent_native/$agent_expected"
    skill_native=$(ls -d .github/skills/*/ 2>/dev/null | wc -l)
    skill_expected=$(ls -d .claude/skills/*/ 2>/dev/null | wc -l)
    [ "$skill_native" -lt "$skill_expected" ] && SHORTFALL=1 && echo "Copilot .github/skills/: $skill_native/$skill_expected"
    ;;
  continue)
    [ ! -f .continue/config.yaml ] && SHORTFALL=1 && echo "Continue: missing config.yaml"
    [ ! -f .continueignore ] && SHORTFALL=1 && echo "Continue: missing .continueignore"
    rule_files=$(ls .continue/rules/*.md 2>/dev/null | wc -l)
    rule_expected=$(ls .claude/rules/*.md 2>/dev/null | wc -l)
    [ "$rule_files" -lt "$rule_expected" ] && SHORTFALL=1 && echo "Continue rules: $rule_files/$rule_expected"
    prompt_native=$(ls .continue/prompts/*.md 2>/dev/null | wc -l)
    prompt_expected=$(($(ls .claude/commands/*.md 2>/dev/null | wc -l) + $(ls .claude/agents/*.md 2>/dev/null | wc -l) + $(ls -d .claude/skills/*/ 2>/dev/null | wc -l)))
    [ "$prompt_native" -lt "$prompt_expected" ] && SHORTFALL=1 && echo "Continue .continue/prompts/: $prompt_native/$prompt_expected"
    ;;
  cline)
    [ ! -f .clinerules/00-project.md ] && SHORTFALL=1
    rule_files=$(ls .clinerules/[1-7][0-9]-*.md 2>/dev/null | wc -l)
    rule_expected=$(ls .claude/rules/*.md 2>/dev/null | wc -l)
    [ "$rule_files" -lt "$rule_expected" ] && SHORTFALL=1 && echo "Cline per-rule files: $rule_files/$rule_expected"
    workflow_native=$(ls .clinerules/workflows/*.md 2>/dev/null | wc -l)
    cmd_expected=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
    [ "$workflow_native" -lt "$cmd_expected" ] && SHORTFALL=1 && echo "Cline .clinerules/workflows/: $workflow_native/$cmd_expected"
    [ ! -f .clinerules/81-agents.md ]  && SHORTFALL=1
    [ ! -f .clinerules/82-skills.md ]  && SHORTFALL=1
    ;;
  aider)
    [ ! -f .aider.conf.yml ] && SHORTFALL=1
    [ ! -f CONVENTIONS.md ]  && SHORTFALL=1
    [ ! -f .aiderignore ]    && SHORTFALL=1
    grep -q "^read:" .aider.conf.yml || SHORTFALL=1
    ;;
  windsurf)
    [ ! -f .windsurf/rules/00-project.md ] && SHORTFALL=1
    rule_files=$(ls .windsurf/rules/[1-7][0-9]-*.md 2>/dev/null | wc -l)
    rule_expected=$(ls .claude/rules/*.md 2>/dev/null | wc -l)
    [ "$rule_files" -lt "$rule_expected" ] && SHORTFALL=1
    workflow_native=$(ls .windsurf/workflows/*.md 2>/dev/null | wc -l)
    cmd_expected=$(ls .claude/commands/*.md 2>/dev/null | wc -l)
    [ "$workflow_native" -lt "$cmd_expected" ] && SHORTFALL=1 && echo "Windsurf .windsurf/workflows/: $workflow_native/$cmd_expected"
    ;;
  codex)
    [ ! -f AGENTS.md ] && SHORTFALL=1
    grep -q "^## Architecture" AGENTS.md || SHORTFALL=1
    grep -q "^## Conventions" AGENTS.md  || SHORTFALL=1
    ;;
  gemini)
    [ ! -f GEMINI.md ] && SHORTFALL=1
    ;;
esac
```

If shortfall detected: re-run that adapter's translation (Phase 5 retry loop). If retry also fails: halt with explicit error.

#### What "translate" actually means (each adapter's translation rule)

The Claude Code `.claude/commands/<name>.md` file has frontmatter `description:` + body. To translate to other tools:

- **OpenCode**: write `.opencode/commands/<name>.md` (NATIVE folder) with body 1:1 from `.claude/commands/<name>.md`.
- **Cursor (≥ 2.3)**: write `.cursor/commands/<name>.md` (NATIVE folder) with frontmatter `{description}` and body 1:1 from source. No prefix; filename = slash-command name.
- **Copilot**: write `.github/prompts/<name>.prompt.md` (NATIVE) with frontmatter `{mode: agent, description}` and body.
- **Continue**: write `.continue/prompts/<name>.md` (NATIVE) with frontmatter `{name, description, invokable: true}` and body. Optional minimal `prompts:` mirror in `config.yaml` for Continue < 1.0.
- **Cline**: write `.clinerules/workflows/<name>.md` (NATIVE — Cline workflows = slash commands).
- **Windsurf**: write `.windsurf/workflows/<name>.md` (NATIVE — Cascade workflows = slash commands).
- **Aider / Codex / Gemini**: append section to `CONVENTIONS.md` / `AGENTS.md` / `GEMINI.md` "Invokable commands" section with `### <name>` header + 5-30 line summary (full body stays in `.claude/commands/<name>.md` — referenced).

Same pattern for agents:
- **OpenCode**: `.opencode/agents/<name>.md` (NATIVE — frontmatter `{name, description, mode, model, tools}`).
- **Copilot**: `.github/agents/<name>.agent.md` (NATIVE — frontmatter `{description, tools, model}`).
- **Cursor**: `.cursor/commands/agent-<name>.md` (translated as a command — Cursor has no agent dispatch).
- **Continue**: `.continue/prompts/agent-<name>.md` (translated as a prompt).
- **Cline / Windsurf**: section in `.clinerules/81-agents.md` / `.windsurf/rules/81-agents.md` (no native dispatch).

And for skills:
- **OpenCode / Cursor / Copilot**: copy `.claude/skills/<name>/` folder verbatim to `.opencode/skills/<name>/` / `.cursor/skills/<name>/` / `.github/skills/<name>/` (NATIVE folder copy — `SKILL.md` + supporting scripts copied 1:1).
- **Continue**: `.continue/prompts/skill-<name>.md` (translated as a prompt).
- **Cline / Windsurf**: section in `.clinerules/82-skills.md` / `.windsurf/rules/82-skills.md`.

This translation is mechanical once you know the source — same as pack copying. Phase 4.8 should generate these files DETERMINISTICALLY (loop over `.claude/commands/`, `.claude/agents/`, `.claude/skills/`; for each, write the per-adapter target file). The agent's job: enumerate sources + execute translation; not free-form decide what to include.

**Parallelism (Hard Rules § Always — "Run setup-project's own independent sub-steps in parallel"):** the per-adapter generation loop is **independent across adapters** — `cursor` writes to `.cursor/rules/` while `opencode` writes to `opencode.json` while `aider` writes to `.aider.conf.yml`; no two adapters share a target path. Fan out one Explore subagent per selected adapter (cap = number of selected adapters, typically 1–4). Each subagent executes its adapter's full contract (Phase 4.8.0) end-to-end. After all subagents complete, Phase 4.8.1 runs sequentially (it audits the union of outputs).

Concrete dependency map (what's parallel-safe, what isn't):

```
SEQUENTIAL (must complete before fan-out):
  Phase 4.1 baseline scaffold     → all adapters need .claude/{commands,agents,skills,rules}/ on disk first
  Phase 4.2 / 4.4 / 4.4b / 4.6    → all adapters translate from these; the translation source must be stable

PARALLEL (fan out one subagent per item):
  Phase 2.5  base-class extraction       (one per base class; cap=6)
  Phase 4.2  per-track pack copy          (one per LOAD-BEARING track)
  Phase 4.4  technical-signal overlays    (one per detected signal)
  Phase 4.4b business-domain overlays     (one per detected domain — usually 1)
  Phase 4.8  per-adapter generation       (one per selected adapter; cap = #adapters)

SEQUENTIAL AGAIN (after fan-out joins):
  Phase 4.8.1 cross-adapter parity audit
  Phase 5     audit / leak scan / schema validation (5.1 → 5.2 → 5.3 → ...)
```

---

**Workspace root anchor shapes** (when shape=workspace):

`<workspace>/AGENTS.md`:
```markdown
# <workspace-name>
<one-paragraph workspace purpose>

## Sub-projects
- `api/` — <purpose> — see `api/AGENTS.md` + `api/CLAUDE.md`
- `dashboard/` — <purpose> — see `dashboard/AGENTS.md` + `dashboard/CLAUDE.md`

## Cross-repo commands (workspace .claude/commands/)
- `/cross-repo-task` — orchestrator for features spanning multiple sub-projects
- `/sync-contract` — API contract change → frontend impact
- `/project-map` — workspace dependency map
- `/workspace-status` — quick health + uncommitted state per sub-project

## Conventions
- Per-sub-project AGENTS.md is authoritative for that sub-project's rules.
- Commits stay per-sub-project; no workspace-level PRs.
```

`<workspace>/opencode.json`:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "_generator": "claude-setup-project",
  "instructions": [
    "AGENTS.md",
    "CLAUDE.md",
    "api/AGENTS.md",
    "dashboard/AGENTS.md"
  ]
}
```

Each sub-project also writes its own `opencode.json` with its OWN instructions globs scoped to that sub-project.

---

**Per-adapter translation (runs per scope)** — for each adapter in the selected set, translate **all 4 artifact types** (not just rules):

1. Read its spec at `~/.claude/templates/tool-adapters/<key>/adapter.md`.
2. Walk the spec's four translation subsections in order:
   - **Rules** — translate `.claude/rules/*.md` into the tool's native rule format.
   - **Commands** — translate `.claude/commands/*.md` into the tool's native prompt/command format (or named sections for tools without commands).
   - **Agents** — translate `.claude/agents/*.md` into the tool's named-prompt format with "Act as <name>" framing (no tool except Claude Code has auto-dispatch).
   - **Skills** — translate `.claude/skills/<name>/SKILL.md` into the tool's procedure/prompt format. OpenCode is the one free win (reads `~/.claude/skills/` globally).
   - **Hooks** — NOT translatable in any tool. Fall back to:
     a. `.husky/` git hooks for commit-time enforcement.
     b. `.gitignore` / `.<tool>ignore` for sensitive-file blocking.
     c. Always-apply rule stating "read `ai/status.md` before starting" as a session-start proxy.
     d. Dedicated "Driver-dependent safety" section disclosing the gap.
3. Use the spec's "Idempotency" rules — generator markers, preserved user sections.
4. Pull source content from the ALREADY-written `.claude/` tree (so Claude Code adapter runs FIRST, others derive).
5. Always write `AGENTS.md` — even if no non-Claude adapter is selected (codex adapter owns this file + the universal anchor).
6. Always write `ai/references/tool-parity.md` + `ai/references/models.md` — so the gap matrix + model routing are documented once and referenced by every adapter's "driver-dependent safety" section.

**Ordering** (strictly enforced — `AGENTS.md` has exactly ONE writer to avoid last-writer-wins ambiguity):
1. `claude-code` adapter FIRST — produces `CLAUDE.md` + `.claude/{agents,commands,skills,rules,hooks}/`. Does NOT write `AGENTS.md`.
2. `codex` adapter SECOND — owns `AGENTS.md`. Reads the just-written `CLAUDE.md` + `.claude/` and compacts them into the universal anchor. ALWAYS runs, even when `codex` is not in `--tools` (because 8+ other tools fall back to `AGENTS.md`).
3. All other selected adapters in parallel — they don't conflict because each writes to a different native path. They MAY append cross-references to `AGENTS.md` (Phase 4.8 finalize step) but MUST NOT rewrite the codex-managed sections.

**Cross-adapter de-dup**:
- `CLAUDE.md` is the superset; `AGENTS.md` is a compacted version + "AI-tool adapters present" + "Invokable commands/personas/procedures" sections.
- Each tool adapter's rule/command/agent/skill files either REFERENCE the canonical `.claude/rules/`, `.claude/commands/`, `.claude/agents/`, `.claude/skills/` files (via `@file` in Cursor, paths in Aider's `read:`, etc.) OR embed a compact summary + pointer to the canonical file.
- NEVER fan-out full verbatim copies of rule/command/agent/skill bodies across every tool's config — that's duplication rot waiting to happen.

**Artifact-count sanity check (emitted in plan)**:
```
Rules translated:    <N> rules × <M> tools = <N*M> target files
Commands translated: <X> commands × <M tools that support> = <Y> target files
Agents translated:   <A> agents × <M tools that support>   = <B> target files
Skills translated:   <S> skills × <M tools that support>   = <C> target files (OpenCode: free; other tools: <D>)
Hooks:               <H> hooks → git hooks + gap disclosure (not translated)
```

**Gap disclosure** — every non-Claude-Code adapter writes a "Driver-dependent safety" section in its primary config listing which Claude Code hooks become soft (documented but not enforced) when the tool is used as the driver. Reference: `ai/references/tool-parity.md`.

