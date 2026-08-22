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

**REFRESH-mode preamble (only when mode = REFRESH)**: load `.claude/_refresh-extract.md` (scaffolded by `refresh-extract-checklist.sh`, filled by Phase 0.2) into working memory before any sub-step. **Section numbers below are that file's own numbering** — the numbering `audit-setup.sh` C2b1 reads. (They previously pointed at a 13-section schema belonging to a `_refresh-knowledge-extract.md` that nothing wrote, so "section 7 = validated corrections" resolved against the real file to *Architecture decisions*, and "section 9 = uncategorized files" resolved to the *migration mapping*.) The extract is consumed by:

- **4.1 baseline**: § 5 (custom rules + conventions) → wired into post-baseline overrides; § 3 (validated user corrections) → injected into `.claude/settings.json` deny-list comments; § 10 (custom hook deltas) → re-applied on top of baseline hook shims.
- **4.2 packs**: § 6 (custom agents/skills/commands) → preserved alongside pack copies (deduped by name; user-edited pack files keep user edits over verbatim pack source per Appendix C).
- **4.4 + 4.4b**: § 2 (ADRs + audits + failures) + § 4 (project intent + domain glossary) + § 7 (architecture / runtime / patterns / runbooks) → fed into business-domain content generation so regen produces project-specific output, not generic templates.
- **4.5 generate-missing**: § 5 (custom rules + conventions) → drives generated content's "Project-specific" blocks at the TOP of every rule/pattern.
- **4.7 knowledge base**: §§ 2, 3, 4, 5, 7 → BECOME the regenerated `ai/decisions/`, `ai/business-domain.md`, `ai/project-goals.md`, `ai/conventions.md`, `ai/dynamic/corrections.md`, `ai/patterns/`, `ai/architecture.md`, `ai/runtime/*.md`, `ai/audits/*.md`, `ai/failures/*.md`. ADRs + audits + failures are append-only — copy verbatim, never rewrite. § 11 (uncategorized user-touched files) is restored byte-for-byte unless the file's destination has been deleted by an explicit deprecation in this spec.
- **4.8 tool adapters**: § 6 (custom skills/commands) → translated to each adapter same as pack content.

The brain MUST consume the extract; if a regen sub-step does NOT reference the extract for its category, that's a bug — Phase 5 audit catches it via the "knowledge preservation check" (see Phase 5). § 11 (catch-all) MUST be exhaustively re-applied: every file in it must end up either restored at its original path or recorded in § 12 and listed in the Phase 5 report under "Intentional drops".

### 4.0 Pack-load preflight (mandatory — runs BEFORE 4.1 / 4.2 / 4.8)

This is the gate that everything downstream assumes has run. It validates that every track + adapter + business-domain + technical-domain selected in Phases 2 + 3 is loadable from `~/.claude/templates/` with all the metadata `setup-project` will rely on. If preflight fails, **halt before any file write** — do NOT scaffold a half-known baseline and then bail mid-Phase 4.2.

#### 4.0.0 Pack-source directory parity scan (Critical Rule 1.4)

**Mandatory on every invocation, including re-runs.** Before any other preflight check, scan the actual filesystem of every selected pack source. The directory listing — NOT `_essentials.md`, NOT `_topics.md`, NOT prior `_apply-pack-report.md` — is the source of truth for "what's in this pack."

**M15 enforcement:** if Phase 0.0 has not yet been run (CREATE / ENHANCE modes which skip Phase 0), Phase 4.0 itself runs `scripts/pack-coverage-scan.sh` and `scripts/study-existing.sh` and reads the resulting reports. The reports drive the per-file decisions for Phase 4.2.

```bash
# If Phase 0.0 didn't run, Phase 4.0 runs the scans now (they are idempotent):
[ -f "$TARGET_REPO/.claude/_pack-coverage-report.md" ] || \
  ~/.claude/scripts/pack-coverage-scan.sh "$TARGET_REPO" $SELECTED_PACKS

[ -f "$TARGET_REPO/.claude/_study-existing-report.md" ] || \
  ~/.claude/scripts/study-existing.sh "$TARGET_REPO" $SELECTED_PACKS
```

**Then read both reports** before issuing any ADD-CANDIDATE / MERGE-CANDIDATE decision. The reports list ALL files; Phase 4.2 visits each row.

#### 4.0.1 Apply study-existing decisions (M23 — deterministic enforcer)

**Mandatory after the parity scan**, before manual Phase 4.2 work begins:

```bash
# Apply REPLACE-OR-ENHANCE + ADD rows from the study-existing report deterministically.
# The agent CANNOT skip these by claiming "narrow scope" — the script reads the
# report and copies pack source over thin stubs (with backup).
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --apply --include=replace,add
```

**What this does:**
- Reads `<target>/.claude/_study-existing-report.md`.
- For every ADD row → copies pack file to target.
- For every REPLACE-OR-ENHANCE row → backs up target, replaces with pack version.
- For MERGE / KEEP-OURS-PLUS-INJECT rows → lists for human review (manual merge needed; deterministic auto-merge unsafe).
- For KEEP-OURS-DEEP / IDENTICAL-NO-OP → no action.
- For *-BY-LEDGER rows → no action (reconciled by `.claude/_refresh-decisions.md`).

**M36 — a shorter file is not a worse file.** `REPLACE-OR-ENHANCE` is a *size* verdict: target ≤ 50% of the pack. Size cannot see that the target's 54 lines are the only written record of this repo's tenant-resolution chain. On 2026-08-22 an ENHANCE run against an 8,151-file repo replaced three such files from the pack — `ai/patterns/multi-tenancy.md` (project identifiers 9 → 0, the real 6-step `DomainMiddleware` chain swapped for generic guidance that contradicts the shipped system), `ai/patterns/error-handling.md` (18 → 0), `.claude/skills/endpoint-test/SKILL.md` (2 → 0).

`study-existing.sh` now tests project knowledge **before** the ratio ladder and withholds `REPLACE-OR-ENHANCE` from any file that carries it — the `<!-- project-specific:start -->` anchor, a real project file path absent from the pack, or ≥3 code identifiers absent from the pack. Those rows arrive as:

```
- `multi-tenancy.md` — target 54 / pack 124 lines → **MERGE** (project-knowledge protected: carries the
  project-specific anchor, 1 project path(s) absent from pack, 12 project identifier(s) absent from pack —
  merge pack depth INTO this file; replacing it destroys knowledge no pack can regenerate)
```

**A protected MERGE row is still actionable** — Phase 4 must bring the pack's depth in — but it may only be closed by merging into the file, by a ledger `--keep-ours` / `--resolve`, or by a hand-written deepening that keeps every project identifier. Closing it by copying the pack over the file is the exact failure this verb exists to prevent, and Phase 5 C2n will catch it: the anchor test alone would not have saved `endpoint-test/SKILL.md`, which carried no anchor at all and was pure project knowledge (`apps/master/src/` on port 4000, `apps/tenant/src/` on 4001, `bun run start:dev-tenant`).

**Curation (M35):** when a row should NOT be applied (pack version is wrong for this project, or yours is better), record the decision instead of skipping it:

```bash
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --reject='pack/kind/file.md:rationale'     # permanent
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --keep-ours='pack/kind/file.md:rationale'  # re-opens when pack changes
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --resolve='pack/kind/file.md:note'         # after a manual MERGE/INJECT
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --keep='kind/file.md:rationale'            # orphan keeper
```

Phase 5 `audit-setup.sh` C2k regenerates the study report and REFUSES success while any actionable row is neither applied nor recorded. Recorded rows are never re-proposed on future refreshes.

**Why mandatory:**
The historic bug (M11 → M22 series): agent ran preflight, generated reports, then ignored the actionable rows under various interpretations of scope. This script removes LLM judgment from the application step. The reports are deterministic; the application is now also deterministic.

**Phase 4.6 still runs after** to anchor project-specific blocks into the replaced files.

**Hard contract (M37) — Deterministic propagation tripod (now a quadruped — covers ALL selected tools):**

```bash
~/.claude/scripts/apply-baseline-sync.sh "$TARGET_REPO" --apply        # Phase 4.1 — repo-baseline → target
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --apply      # Phase 4.2 — pack files → .claude/
~/.claude/scripts/apply-anchors.sh "$TARGET_REPO" --apply              # Phase 4.6 — anchor blocks
~/.claude/scripts/apply-adapter-sync.sh "$TARGET_REPO" --apply         # Phase 4.8 — .claude/ → every enabled adapter
```

These four scripts are the deterministic-propagation contract. Each closes a specific false-idempotent loophole — together they guarantee that EVERY selected tool stays in sync with `.claude/` (the source of truth).

| Script | Source → Target | Phase | Closes the bug |
|---|---|---|---|
| `apply-study-decisions.sh` | `templates/packs/<track>/` → `.claude/{agents,skills,commands,rules}/` + `ai/patterns/` | 4.2 | Agent skips pack copy |
| `apply-baseline-sync.sh` | `templates/repo-baseline/{ai,/.claude}/` → `target/{ai,.claude}/` | 4.1 | Agent skips knowledge-layer + foundational-rules copy |
| `apply-anchors.sh` | extraction → `## Project-specific` blocks IN pack-derived artifacts | 4.6 | Agent skips anchor injection (templates ship generic) |

| `apply-adapter-sync.sh` | `.claude/{agents,skills,commands,rules}/` → `.opencode/`, `.cursor/`, `.github/`, `.clinerules/`, `.windsurf/`, `.continue/`, … | 4.8 | Agent translates 1-2 adapters and skips rest |

**`apply-anchors.sh` exit 3 — injected, but empty.** The script builds every anchor block from five
headings in `.claude/codebase-profile.md` (`phase-2-profile.md § Profile content` § Heading contract).
If ZERO of the five resolve, the blocks it wrote are five `<not declared in codebase-profile.md>` lines
with five identical `codebase-profile.md:1` citations — structurally present, semantically empty, and
passing every presence check downstream. That is now exit **3**, distinct from exit 1 (nothing was
written) precisely because the files WERE written: do not roll back, do not halt the run. Fix
`codebase-profile.md` in Phase 2 and re-run `apply-anchors.sh --apply`; the marker check makes it
idempotent. A partial shortfall (1-4 of 5 resolved) prints a counted WARN and exits 0. Phase 5's
anchor audit re-checks the same condition (`phase-5-verify.md § 5.3` check 2b) so a swallowed exit 3
is still caught at the gate.

**Why all four are mandatory** — the standalone-tool guarantee (`commands/setup-project.md § Drop-in replacement principle`):

> If the user closes Claude Code and opens Cursor (or OpenCode, or Aider, or any selected tool), they get the SAME feature surface — same commands available, same agent personas usable, same knowledge accessible, same conventions enforced.

Without `apply-adapter-sync.sh` specifically, a user who selects `--tools=claude-code,opencode` gets a fully-populated `.claude/` and an empty `.opencode/` — Claude works, OpenCode doesn't, the guarantee is broken. The shell script removes that gap from LLM judgment: 1:1 markdown copies (~80% of adapter translation) happen deterministically; the remaining 20% (format conversions like `.cursor/rules/*.mdc` with YAML frontmatter) are reported as MISSING-AUTHOR rows that `/setup-project-adapters` finishes.

**What `apply-baseline-sync.sh` does**:
- For every file under `~/.claude/templates/repo-baseline/`:
  - Target missing → **ADD** (`cp` from baseline)
  - Target identical to baseline → **NO-OP**
  - Target has `<!-- setup-project:managed -->` markers → **SYNC** managed regions only (preserves user content outside markers)
  - Target has user content + no markers → **KEEP-OURS** (never overwrites)
- Backups every changed file to `.claude/backups/baseline-sync-<ts>/`.

**What `apply-adapter-sync.sh` does**:
- Auto-detects enabled adapters by folder/config presence (`.opencode/`, `.cursor/`, `.github/agents/`, `.clinerules/`, `.windsurf/`, `.continue/`, `.aider.conf.yml`, `AGENTS.override.md`, `GEMINI.md`).
- Or processes explicit list via `--adapters=opencode,cursor,copilot,...`.
- For each enabled adapter, applies the per-tool path-translation recipe from `templates/tool-adapters/<tool>/adapter.md`:
  - 1:1 markdown copy (OpenCode commands/agents, Cursor commands/skills, Cline workflows, Windsurf workflows, Continue prompts) → shell `cp`.
  - Filename suffix (Copilot `*.agent.md` / `*.prompt.md`) → shell `cp` + rename.
  - Format conversion (Cursor `.mdc` with YAML frontmatter, JSON configs, AGENTS.md composites) → reported as MISSING-AUTHOR; LLM-authored by `/setup-project-adapters`.
- Backups every overwritten file to `.claude/backups/adapter-sync-<ts>/`.

**Phase 5 audit gates**:
- **C2g** — refuses success when `apply-baseline-sync.sh` reports ADD rows in REFRESH/REFINE/ENHANCE modes (baseline files missing).
- **C2h** — refuses success when `apply-adapter-sync.sh` reports ADD/REFRESH rows in those modes (adapter drift). MISSING-AUTHOR rows trigger a WARN (the agent must run `/setup-project-adapters` to author them, which is allowed in the same flow but tracked separately).
- **C2f** — refuses success on STALE_KNOWLEDGE (pack source newer than `ai/_session-digest.md` etc.).

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

#### 4.0.2 Inputs (shared by 4.0.3 onwards)

- Selected packs (Phase 2 detection + `--include`/`--exclude`).
- Selected business-domains (Phase 2.x business-domain detection + wizard answers).
- Selected technical signals → domain overlays (Phase 2 + Appendix B Relevance Filter).
- Selected tool adapters (Phase 3.2 detection + `--tools`).
- Mode (CREATE / ENHANCE / REFRESH).

#### 4.0.3 Per-source preflight (run on each selected source)

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

# 6. Pack-specific: per-kind no-thin-stub floor.
#    The floor differs by artifact KIND because real-world content has
#    different natural lengths: agents are architectural personas (~100+
#    lines), commands are 7-phase procedures (~80+ lines), rules are
#    focused do/don't lists (~50+ lines), skills are recipe procedures
#    (~50+ lines including SKILL.md scaffolding). A single 100-line floor
#    historically failed real focused content; per-kind floors keep the
#    stub protection without false positives.
if [ "$SRC_KIND" = "pack" ]; then
  # agents: ≥100 (architectural personas)
  while IFS= read -r f; do
    lines=$(wc -l < "$f")
    [ "$lines" -lt 100 ] && ERRORS+=("THIN_PACK_FILE $f ($lines lines, floor=100 for agents)")
  done < <(find "$SRC" -type f -path '*/agents/*.md' -not -name '_*')
  # commands: ≥80 (procedure files — 7-phase canonical structure)
  while IFS= read -r f; do
    lines=$(wc -l < "$f")
    [ "$lines" -lt 80 ] && ERRORS+=("THIN_PACK_FILE $f ($lines lines, floor=80 for commands)")
  done < <(find "$SRC" -type f -path '*/commands/*.md' -not -name '_*')
  # rules: ≥50 (focused rules, concise by design)
  while IFS= read -r f; do
    lines=$(wc -l < "$f")
    [ "$lines" -lt 50 ] && ERRORS+=("THIN_PACK_FILE $f ($lines lines, floor=50 for rules)")
  done < <(find "$SRC" -type f -path '*/rules/*.md' -not -name '_*')
  # skills: ≥50 (skill recipes; skill folders use SKILL.md, flat skills use *.md)
  while IFS= read -r f; do
    lines=$(wc -l < "$f")
    [ "$lines" -lt 50 ] && ERRORS+=("THIN_PACK_FILE $f ($lines lines, floor=50 for skills)")
  done < <(find "$SRC" -type f \( -path '*/skills/*/SKILL.md' -o -path '*/skills/*.md' \) -not -name '_*')
fi

# 7. Business-domain pack-specific: factories.md required ONLY when the run
#    explicitly asks for B17 fixtures (`--with-factories` flag OR a detected
#    test-factory framework like Faker/factory_boy/FactoryBot in deps).
#    Without the gate, every business-domain pack would HALT preflight on a
#    template detail that does not block normal packs.
if [ "$SRC_KIND" = "business-domain" ]; then
  if [ "$ARG_WITH_FACTORIES" = "1" ] || [ "$FACTORY_FRAMEWORK_DETECTED" = "1" ]; then
    [ -f "$SRC/factories.md" ] || ERRORS+=("MISSING_FACTORIES $SRC (factories.md is required when --with-factories or a factory framework is detected — see capabilities/5-fixtures-factories.md)")
  else
    [ -f "$SRC/factories.md" ] || WARNINGS+=("FACTORIES_OPTIONAL $SRC (factories.md not shipped; no B17 generation. To enable: pass --with-factories or add Faker/factory_boy/FactoryBot to deps)")
  fi
fi

# 8. Adapter-specific: schema present in templates/schemas/ if --validate-schemas was passed
if [ "$SRC_KIND" = "adapter" ] && [ "$ARG_VALIDATE_SCHEMAS" = "1" ]; then
  adapter_name="$(basename "$SRC")"
  schema_count=$(ls "$HOME/.claude/templates/schemas/$adapter_name/"*.schema.json 2>/dev/null | wc -l)
  [ "$schema_count" -eq 0 ] && WARNINGS+=("SCHEMA_MISSING $adapter_name (continuing; --validate-schemas was opt-in)")
fi
```

#### 4.0.4 Halt vs. warn

- **ERRORS → halt before Phase 4.1.** Print every error in the report. Do not write anything to the project.
- **WARNINGS → log + continue.** Surface them in the Phase 5 report under "Pack-load preflight warnings". They are advisory.

#### 4.0.5 Pack-load preflight report (always emitted)

```
== Pack-load preflight ==
Sources scanned: N (P packs, A adapters, B business-domains, D domains, O overlays)
✓ Loadable:        K
⚠ Warnings:        W (deprecation, missing CHANGELOG, schema missing)
✗ Errors:          E (halts the run if E > 0)

Errors:
  - THIN_PACK_FILE ~/.claude/templates/packs/backend/agents/foo.md (43 lines, floor=100 for agents)
  - MISSING_VERSION ~/.claude/templates/business-domains/scheduling
Warnings:
  - DEPRECATED ~/.claude/templates/packs/legacy-track see CHANGELOG.md
```

#### 4.0.6 Minimum-artifacts table (referenced by Phase 4.2.c + Phase 5.1)

**Single source of truth**: see § "Minimum artifacts per LOAD-BEARING track" later in this file. Track keys there are drawn from the registry at `templates/packs/_registry.md`, which carries one row per pack folder under `templates/packs/`. **Parity is hand-maintained and unenforced** — no script cross-checks the floor table against the registry or the folder list, so a new pack can ship with a registry row and no floor row (Phase 2.6.b then has nothing to check it against). `align` and `algorithms` are opt-in-only tracks: they carry floors below, but are never auto-selected.

**Minimal mode (`--minimal`)**: floors are replaced by the track's `_essentials.md` manifest counts. Anything outside the focused subset is `n/a`.

**Migration track**: load-bearing only when `migration_layout_detected` is true (parallel V1+V2 directories, version-suffixed sibling modules, dual-app workspaces with `-v2`/`-next`/`-new` suffixes, README mentions of V1→V2 / legacy migration) OR when explicitly opted in via `--include=migration`. Floors match `_essentials.md`: 2 agents (`migration-architect`, `parity-auditor`), 2 commands (`port-feature`, `migration-status`), 3 skills (`extract-v1-contract`, `parity-test-generate`, `perf-uplift-survey`), 1 rule (`migration-discipline`), 3 patterns (`feature-port`, `parity-testing`, `migration-ledger`).

#### 4.0.7 Required baseline files (referenced by Phase 5.1 + Phase 5.4)

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
           # >>> refract: learning loop (managed) >>>
           "$(git rev-parse --show-toplevel)/.claude/hooks/<hook>-learn.sh" || true
           # <<< refract: learning loop (managed) <<<
           ```
           Idempotent on re-run: skip if the marker block is already present. **Both marker
           spellings count as present** — the project was called `claude-config` before it was
           renamed to Refract, so a repo wired by an older run carries
           `# >>> claude-config: learning loop (managed) >>>`. Treat that as already wired: do
           NOT append a second block, and do NOT rewrite the old marker (it invokes the same
           hook, and rewriting it would dirty a file the user may have edited around).
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
- **Gitignore the learning-hook + scheduler outputs + setup snapshots** (CRITICAL — prevents a dirty-tree commit loop AND keeps transient snapshots out of VCS/search). The hooks just wired (`post-commit-learn.sh`, `post-merge-learn.sh`, `update-session-log.sh`) and the scheduler APPEND to files on every commit / merge / session-stop; Phase 0 also writes `.claude/backups/` snapshots and `.claude/plans/` working artifacts. If any are tracked, the working tree is dirty the instant a commit finishes (commit → post-commit hook rewrites the file → dirty → …), and the backup snapshots bloat every `TBD`/`TODO` search with copies of the anti-placeholder tooling. This bit real projects (observed 2026-06 across multiple consuming projects — backups never gitignored). **This MUST be a deterministic write, not a prose note** — the `.claude/backups/` + `.claude/plans/` entries previously lived only in Phase 0 prose ("Phase 4.1 enforces this") and so were silently skipped. Ensure `.gitignore` contains the full block below (idempotent append; create `.gitignore` if missing; skip any entry already present). For each tracked file, also `git rm --cached --quiet <file>` so the loop/clutter stops immediately:
  ```gitignore
  # Auto-generated by .claude learning/scheduler hooks — per-engineer local state, never commit.
  .claude/scheduled_tasks.lock
  ai/dynamic/.review-queue
  ai/dynamic/changelog.md
  ai/dynamic/session-log.md
  # Derived retrieval cache — rebuilt from ai/ on a size+mtime fingerprint mismatch.
  .claude/_memory-index.json
  # Transient setup-project snapshots + per-engineer working artifacts — never commit.
  .claude/backups/
  .claude/plans/*.md
  !.claude/plans/README.md
  .claude/plans/_archive/
  .claude/_telemetry.jsonl
  ```
  Rationale: these are local learning/session state + transient snapshots, not shared history. `.claude/_memory-index.json` is the `/recall` index — a *derived cache* over the `ai/` tree, not a store: committing it would add a drift surface with nothing to gain, since it rebuilds from the source files it points at (same argument `docs/RETRIEVAL.md` already makes for not committing the pack catalog). A team that deliberately wants a committed changelog must instead move the post-commit append to a pre-commit/staged step (a post-commit write to a tracked file is always a dirty-tree loop); a team that wants plans tracked flips the `.claude/plans/*.md` line — record either decision in the ledger.
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
- **Monorepo mode** (`repo_shape: monorepo` — several deployables inside ONE git repo, no member-declaring workspace manifest):
  - **Do NOT recurse.** One git repo means one `.claude/`, one `ai/`, one `CLAUDE.md`, one commit. Scaffolding a `.claude/` per member here fragments a single team's config and produces N conflicting sources of truth for one repo.
  - **Do NOT collapse to single either.** The members are real and their conventions differ. Everything member-shaped is split *inside* the shared artifacts: `.claude/codebase-profile.md § 17` carries one entry per member (Phase 2 fills fields 1–10 + 15 once per member), `ai/conventions.md` carries one row per member in its per-package matrix, `ai/stack.md` carries one Primary per member, and Phase 4.2 path-scopes each track's rules to that track's `track_roots` glob so one member's rules do not load while editing another's.
  - Track selection is the **union** across members (a repo with a server member and a client member installs both track sets), but each track's rules are scoped to its own member root — that is what keeps the union from becoming pollution.
  - The member list comes from the SAME enumeration table below. It is not workspace-only.

**Sub-project / member enumeration** — the member list for BOTH multi-member shapes:
- `repo_shape: workspace` → members are sub-projects; each is recursed through Phases 2 → 4 (steps 1–6 below).
- `repo_shape: monorepo` → members are packages inside one repo; only steps 1–3 below run (detect + select), and their output lands in the shared `codebase-profile.md § 17` instead of a per-member `.claude/`.

Phase 1 has already decided the shape and produced a candidate member list from its sub-manifest inventory; this table is how that list is expanded and confirmed. Detect members from manifest(s) in this order:
| Source | Extract |
|---|---|
| `pnpm-workspace.yaml` | `packages:` glob list (e.g. `packages/*`, `apps/*`, `api`, `dashboard`). |
| `package.json` → `workspaces` | Array or object form; expand globs. |
| `lerna.json` → `packages` | Glob list. |
| `turbo.json` (Turborepo) | Infer from `package.json` workspaces or pipeline filters. |
| `nx.json` + `workspace.json` / `project.json` | Nx workspace — enumerate via `nx show projects`. |
| `go.work` (Go) | `use` directives. |
| `Cargo.toml` `[workspace]` `members` | Rust. |
| **No member-declaring manifest at all** — any dir with its OWN manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `composer.json`, `Gemfile`, `build.gradle`, `pom.xml`, `mix.exs`) | Use these. **This is the row that catches the most common real shape** — a server directory and a client directory side by side, or two checked-out repos under one parent folder, with no workspace tool anywhere. Search immediate subdirs plus one level under `apps/`, `packages/`, `services/`, `libs/`, `modules/`, `src/`. |
| `PROJECTS.md` in workspace root lists siblings | Use table rows. |

**These last two rows are not a long shot — they are the default for repos that never adopted a workspace tool.** They fire on the Phase 1 sub-manifest inventory, which runs on every setup, not only when a workspace manifest was found. A member list that is empty because no `pnpm-workspace.yaml` existed is a detection failure, not a `single`-shape repo.

For each member P in the enumeration:
1. Filter out non-project dirs: `node_modules`, `dist`, `build`, `out`, `.git`, `.pnpm-store`, `target`, `vendor`, `.venv`, `coverage`.
2. Detect P's stack (same as Phase 2 detection, but scoped to P's directory).
3. Select tracks + domain tooling for P's stack — a server-framework member and a client-framework member get DIFFERENT track sets, and that difference is the whole point of enumerating.

Steps 4–6 are **`repo_shape: workspace` only** (a `monorepo` stops after step 3 and records the result in the shared `codebase-profile.md § 17`):

4. Scaffold P's own `.claude/` + `ai/` (repo-baseline copy).
5. Apply tracks + domains + tool adapters in P's directory.
6. P gets its own `CLAUDE.md` + `AGENTS.md` + `opencode.json` + `.cursor/rules/` etc. — not shared with siblings.

**Never scaffold per-project content only at workspace root** when sub-projects exist. That's the bug this rule exists to prevent. Its `monorepo` twin: **never answer a member-shaped question with one repo-wide value** when several members exist — one blended convention set is wrong for every member and reads as measured.

**Write the registry.** For `repo_shape: workspace`, if the root has no `PROJECTS.md`, emit one from `~/.claude/templates/workspace-baseline/PROJECTS.md.tpl` using the confirmed member list — one table row per member with its path, detected stack, and role. That file is the durable record of the enumeration: without it the member list exists only for the length of this run, and the next session re-derives it (or fails to). If a `PROJECTS.md` already exists, reconcile rather than overwrite — add missing members, and flag rows pointing at directories that are no longer on disk rather than deleting them silently.

For the workspace-root `AGENTS.md` + `opencode.json` thin-anchor shapes, see Phase 4.8 § "Workspace root anchor shapes".

**4.0 Pack-load preflight** (runs ONCE before 4.1 — prevents thin-content propagation; per-kind floors per § 4.0.3 step 6):

```bash
# Per-kind floors (matches § 4.0.3 step 6 above): agents=100, commands=80, rules=50, skills=50.
declare -A FLOOR=( [agents]=100 [commands]=80 [rules]=50 [skills]=50 )
for track in <selected-tracks>; do
  for type in agents commands rules skills; do
    floor=${FLOOR[$type]}
    for f in ~/.claude/templates/packs/$track/$type/*.md; do
      [ ! -f "$f" ] && continue
      lines=$(wc -l < "$f")
      if [ "$lines" -lt "$floor" ]; then
        echo "HALT: pack source $f is thin ($lines lines, floor=$floor for $type). Deepen at the pack level before applying."
        exit 1
      fi
    done
  done
done
```

If any pack file is below its kind's floor, HALT. Don't propagate shallow content into the project. The fix is in `~/.claude/templates/packs/`, not in this run.

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
| ui-ux | 4 | 1 | 3 | 1 | 5 |
| learning | 3 | 4 | 1 | 0 | 0 |
| migration | 2 | 2 | 3 | 1 | 3 |
| data-engineering | 3 | 2 | 2 | 1 | 3 |
| finops | 2 | 2 | 1 | 1 | 2 |
| product | 3 | 2 | 1 | 1 | 2 |
| ai-engineering | 2 | 2 | 3 | 1 | 5 |
| algorithms | 1 | 2 | 1 | 1 | 1 |
| align | 3 | 10 | 2 | 1 | 1 |

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

**`[SAMPLED]` does NOT affect this gate.** Only `[EXTRACTION-WEAK]` (no signal) routes a track to COPY. `[SAMPLED]` (partial signal — `extract-codebase-overview § Step 2.5`) is **reported here and consumed as confidence downstream**, never as a mode switch. Forcing COPY on a large repo because its conventions came from a sample would make coverage-reporting a punishment for having a big codebase, and a metric that punishes you is a metric someone switches off. Report, don't punish. The behaviour that *does* change is one layer down: claims from a sampled section arrive carrying `[inferred: …; sampled s/p]` (`phase-2-profile.md § Provenance discipline`), and Phase 4 generators may not anchor to `[inferred:]` without re-verifying against source. The mode stays AUTHOR; the anchor gets honest.

Report the per-track mode in the plan, with coverage on the same line — the reader deciding whether to trust a generated rule needs both facts at once:

```
Track modes:
  backend         AUTHOR  (3 base classes extracted: BaseService [238 ext], DataAccess [273 ext], BaseController [89 ext])
                          coverage 214/1,204 source files cited (18%) — conventions sampled 10/412, carried as [inferred:]
  database        AUTHOR  (1 base class: BaseEntitySubscriber [12 ext])
                          coverage 88/88 entity files (100%) — no [SAMPLED] sections
  code-quality    COPY    (no project-specific base classes; pack content is sufficient)
  documentation   COPY    (same)
  testing         COPY    (no _topics.md in pack yet — falls back to literal copy)
  security        COPY    (same)
  learning        COPY    (always — meta-pack)
```

Read the coverage line off `_extracted-codebase.md`'s `## Coverage` section and header `Coverage:` key. When extraction was skipped entirely, print `coverage n/a (extraction skipped)` — absent is not the same as 100%, and the two must never render identically.

