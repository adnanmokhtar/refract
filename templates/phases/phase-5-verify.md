---
phase: 5
name: verify
applies-to-modes: [all]
inputs: [phase-4-outputs, hard-rules, schemas]
outputs: [verification-report, halt-or-pass, retry-loop-state]
exit-criteria: every must/must-not rule passes; coverage check + retry loop exhausted; setup-quality score emitted (REFINE only)
sub-phases:
  - 5.0 — coverage check + retry loop                  @templates/phases/phase-5.0-retry.md
  - 5.1 — required-baseline + inventory diff           @templates/phases/phase-5.1-baseline.md
  - 5.2 — self-consistency checks                      (inline below)
  - 5.3 — Phase 4.6 adaptation audit                   (inline below)
  - 5.3.5 — cross-project leak scan                    (inline below)
  - 5.4 — schema validation harness                    (inline below)
  - 5.4b — health score + telemetry emit (every mode)  (inline below; distinct from 5.5)
  - 5.5 — setup-quality score (REFINE only)            @templates/phases/phase-5.5-quality.md
  - 5.6 — version drift report (every mode)            (inline below)
  - 5.7 — REFRESH-mode cleanup                         (inline below)
  - 5.8 — surface uncertainty                          @templates/phases/phase-5.1-baseline.md (inline)
checklist: templates/phases/phase-5-checklist.md
hard-rule: HALT + RETRY, not "report and continue"
---

### Phase 5 — Verify + report

**5.1 File presence verification**:
- List full tree of created/modified files.
- Confirm hooks are executable.
- Confirm each `ai/status.md` has `Updated:` + `## Recent Changes`.
- Confirm no `<TODO>` / `<placeholder>` / `_UNKNOWN_` leaked into shipped content (placeholders OK in `ai/project-goals.md` for genuinely-undecided facets — but flagged in report).
- Confirm `PROJECTS.md` lists every sibling (workspace mode).
- Confirm `AGENTS.md` written at root (universal anchor — always present).
- Confirm `ai/references/models.md` + `ai/references/tool-parity.md` written.
- Confirm `ai/business-domain.md` + `ai/core/glossary.md` + `ai/project-goals.md` + `ai/users-and-personas.md` written when intent + domain detected.
- For each selected tool adapter, confirm the four-artifact translation (rules + commands + agents + skills) + git-hook fallback for hooks.
- Confirm each adapter's idempotency marker is present.
- **Agent `model: opus` cost-watch warning** — count agents in `.claude/agents/*.md` whose frontmatter declares `model: opus`. If `count > 5`, emit a non-fatal warning to the report:
  ```
  ⚠ Cost watch: <N> agents declare `model: opus`. Each opus invocation is ~5× sonnet. Audit list:
    - .claude/agents/<file>.md  (model: opus)
    ...
  Default policy (see claude-code adapter): opus for architect/auditor/reviewer-of-reviewers; sonnet for reviewers; haiku for linters.
  ```
  This is a warning only — does NOT halt the run.

**5.2 Self-consistency audit + retry loop** — the brain checks its own output:

- **Cross-reference resolution**: every `@file <path>`, every "see `ai/X.md`" link, every Cursor `@file` directive resolves to an existing file. Broken refs = halt apply (regenerate or fix).
- **Naming consistency**: scan generated files for the same concept named differently. E.g., if `tenantId` appears in TS code, also ensure `.claude/rules/multi-tenancy.md` and `ai/core/glossary.md` use the same casing. Flag mismatches with file:line evidence.
- **Contradiction check**: pair every rule from `.claude/rules/*.md` with relevant patterns in `ai/patterns/*.md` and business-domain `anti-patterns.md`. Flag any rule that says "always X" while a pattern shows "do Y" (where X ≠ Y).
- **Idempotency check**: re-run the apply pipeline mentally against the just-written state. Any file that would change is a non-idempotent generator — flag the bug.
- **No-ghost-file check**: every file we WROTE is tracked in the report. Every file in the report exists. No silent extras.
- **Knowledge preservation check (REFRESH only)** — for each item in `.claude/_refresh-knowledge-extract.md`, verify it survived into the regenerated output OR appears in the "Stale extract items" log with explanation:
  - Section 1 (ADRs) → every ADR file MUST exist in `ai/decisions/` with the same ID + title. Append-only: zero ADRs may be missing.
  - Section 2 (domain glossary) → every term MUST appear in `ai/business-domain.md` or `ai/core/glossary.md`.
  - Section 3 (project intent) → every facet MUST appear in `ai/project-goals.md` / `ai/users-and-personas.md`.
  - Section 4 (custom conventions) → every project-specific rule MUST appear in `ai/conventions.md` OR a relevant `.claude/rules/*.md`.
  - Section 5 (custom rules) → every custom rule body MUST appear somewhere in `.claude/rules/`.
  - Section 6 (custom agents/skills/commands) → every custom artifact MUST exist by name in the relevant `.claude/` subdir.
  - Section 7 (validated corrections) → every correction MUST appear in `ai/dynamic/corrections.md` (or be wired into a relevant rule).
  - Section 8 (custom patterns/runbooks) → every project-idiom file MUST exist by path.

  Each missing item triggers HALT + retry of the relevant Phase 4 sub-step. If still missing after retry, halt with error: "Knowledge preservation check failed: <list of dropped items>. Backup is at <path>; restore with `<path>/restore.sh`."
- **Stale extract reconciliation (REFRESH only)** — every item in `.claude/codebase-profile.md` § "Stale extract items" must have either: (a) been dropped from the extract by Phase 2 (logged); or (b) been re-confirmed by user via Phase 2 question. Unresolved stale items = halt.
- **Backup integrity check (REFRESH only)** — re-verify backup directory still exists at the path announced in Phase 0 plan, with the same file count. If anyone (including a hook) deleted it during apply, halt and surface error before tearing down `_refresh-knowledge-extract.md`.

**5.3 Phase 4.6 adaptation audit (per Critical Execution Rule 7 — MANDATORY in every mode)**:

#### 5.3.0 Decision-file format (the audit's input)

Phase 4.6 MUST persist its STUDY → DECIDE → ACT decisions to `.claude/_phase-4-6-decisions.md` so this audit (and any subsequent re-run) can reproduce them deterministically. The file is a YAML-frontmatter index — one block per pack-added file:

```yaml
---
generated_by: setup-project Phase 4.6
generated_at: 2026-04-25T14:35:00Z
mode: REFRESH
---
# Phase 4.6 decisions

- file: .claude/rules/database-principles.md
  decision: CHANGE-anchor                   # CHANGE-anchor | CHANGE-anchor-with-warn | LEAVE-with-redirect | LEAVE-delete
  category: path-citing                     # path-citing | workflow | governance
  cited_identifiers:
    - PrismaService
    - libs/db/repositories/base.repository.ts
  rationale: "Project ships a Prisma-based BaseRepository with multi-tenant scoping; generic Active-Record advice would mislead."

- file: .claude/rules/git-workflow.md
  decision: CHANGE-anchor
  category: workflow
  cited_identifiers: []
  rationale: "Project uses trunk-based; pack default is git-flow."

- file: .claude/rules/concurrency-discipline.md
  decision: CHANGE-anchor
  category: path-citing
  cited_identifiers:
    - "libs/concurrency/run-with-limit.ts"     # the project's bounded-parallel helper, if any
    - "p-limit"                                 # OR the dependency the project standardised on
    - "pool.max=20"                             # observed DB pool ceiling — caps the per-request concurrency
  rationale: "Project standardises on p-limit + a runWithLimit wrapper; generic Promise.all advice would miss bounding + cancellation. Caps must be ≤ pool.max − safety_margin."

- file: ai/patterns/parallel-io.md
  decision: CHANGE-anchor
  category: path-citing
  cited_identifiers:
    - "libs/concurrency/run-with-limit.ts:12"   # helper signature
    - "apps/api/src/orders/order.service.ts:88" # 1-3 grep'd examples of correct project-flavoured parallel I/O
    - "AbortController"                         # cancellation primitive in use
  rationale: "Pattern body must show the project's actual primitive + cap defaults + tracing wrapper, not generic Promise.all prose. Without anchor, agents reach for ad-hoc Promise.all and miss the project's helper."
```

#### 5.3.1 Helper definitions (concrete, not pseudocode)

The audit relies on three helpers — they are deterministic shell functions over the decision file + extraction, NOT free-form LLM lookups:

```bash
DECISIONS_FILE=".claude/_phase-4-6-decisions.md"
EXTRACTION_FILE=".claude/_extracted-codebase.md"
IDIOMS_FILE=".claude/_extracted-idioms.md"

# Returns the decision token for a given file path (CHANGE-anchor, LEAVE-with-redirect, etc.).
# Empty string = "no record" → audit treats it as MISSING_DECISION (halt).
lookup_phase_4_6_decision() {
  local file="$1"
  awk -v target="$file" '
    /^- file:/ { current = $3; gsub(/"/, "", current) }
    /^  decision:/ && current == target { print $2; exit }
  ' "$DECISIONS_FILE"
}

# Returns the file's category as recorded in the decision file (path-citing | workflow | governance).
# Falls back to a topic-based heuristic if no record exists (still surfaces MISSING_DECISION elsewhere).
classify_pack_file() {
  local file="$1"
  local recorded
  recorded=$(awk -v target="$file" '
    /^- file:/ { current = $3; gsub(/"/, "", current) }
    /^  category:/ && current == target { print $2; exit }
  ' "$DECISIONS_FILE")
  if [ -n "$recorded" ]; then
    echo "$recorded"
    return
  fi
  case "$file" in
    *git-workflow*|*branching*|*code-review-flow*|*documentation-principles*) echo workflow ;;
    *engineering-principles*|*quality-principles*)                            echo governance ;;
    *)                                                                        echo path-citing ;;
  esac
}

# Returns the cited_identifiers list for a file (one identifier per line). Empty if none.
extract_anchor_identifiers() {
  local file="$1"
  awk -v target="$file" '
    /^- file:/ { current = $3; gsub(/"/, "", current); in_block = (current == target); in_list = 0 }
    in_block && /^  cited_identifiers:/ { in_list = 1; next }
    in_list && /^    - / { sub(/^    - /, ""); gsub(/"/, ""); print; next }
    in_list && /^  [a-z]/ { in_list = 0 }
  ' "$DECISIONS_FILE"
}
```

These helpers MUST be available in shell scope before the audit runs. Phase 5.1 verifies `.claude/_phase-4-6-decisions.md` exists; if it's missing, the audit halts with `MISSING_PHASE_4_6_DECISIONS_FILE` and instructs the user to re-run Phase 4.6.

#### 5.3.0 Foundational `ai/` populate gate (EVERY mode — CREATE / ENHANCE / REFRESH)

This is the safety net for the failure mode where ENHANCE/REFRESH scaffolds the foundational `ai/` files from baseline and then never populates them (the old "leave user-authored files untouched" rule could not tell a 2-second-old stub from real user content, so the stub survived). The 5.3.2 audit below only covers **pack-added** files (Phase 4.2/4.4/4.4b) — the baseline-scaffolded foundational files are added by Phase 4.1 and fall entirely outside it. 5.3.0 closes that gap and runs in **every** mode (the prior `ai/`-validator mode-split wrongly exempted ENHANCE/REFRESH).

```bash
# Deep-extraction source — first that exists (Fix C resolution order).
EXTRACT=""
for cand in .claude/_extracted-codebase.md .claude/_codebase-scan.md .claude/codebase-profile.md; do
  [ -f "$cand" ] && { EXTRACT="$cand"; break; }
done
[ -z "$EXTRACT" ] && { SHORTFALL="$SHORTFALL\n  no deep-extraction file found (.claude/_extracted-codebase.md | _codebase-scan.md | codebase-profile.md) — Phase 0/2 extraction never ran"; }

FOUNDATIONAL_AI="architecture stack modules status conventions business-domain _convention-cheatsheet"
BASELINE_DIR="$HOME/.claude/templates/repo-baseline/ai"
# Tokens that ONLY appear in un-populated baseline stubs (NOT in real populated content).
# Bare `<name>` is deliberately EXCLUDED — it is a legitimate code/path placeholder in populated
# docs (`get_logger(<name>)`, `app/modules/<name>/`) and would false-positive. The diff-identical
# check + these stub-only tokens (`<src/path`, `<EntityA>`, `<DetectedBase>`, …) still catch real stubs.
STUB_TOKENS='<src/path|<e\.g\.,|<YYYY-MM-DD>|<detected|<EntityA>|<DetectedBase>|<NNNN>|<term>|<one-line'
for f in $FOUNDATIONAL_AI; do
  tgt="ai/$f.md"
  [ -f "$tgt" ] || { SHORTFALL="$SHORTFALL\n  $tgt: MISSING (foundational file must be present + populated)"; continue; }
  # (a) byte-identical to baseline stub → Phase 4.7 never populated it (the ENHANCE-skip bug)
  if [ -f "$BASELINE_DIR/$f.md" ] && diff -q "$BASELINE_DIR/$f.md" "$tgt" >/dev/null 2>&1; then
    SHORTFALL="$SHORTFALL\n  $tgt: IDENTICAL to baseline stub (never populated from $EXTRACT)"
    continue
  fi
  # (b) still carries baseline placeholder tokens → partial / failed population
  grep -qE "$STUB_TOKENS" "$tgt" \
    && SHORTFALL="$SHORTFALL\n  $tgt: contains baseline placeholder tokens (population incomplete)"
done
```

**Scope note**: intent files that legitimately carry undecided facets — `ai/project-goals.md`, `ai/users-and-personas.md`, `ai/roadmap.md`, `ai/business-model.md`, `ai/competitive-context.md` — are NOT in this set (per §5.0: placeholders OK there, flagged-not-halted). The gate covers ONLY the extraction-derived foundational files, which always have a concrete answer in the deep-extraction source.

**On shortfall**: auto-retry Phase 4.7 population for the flagged files (resolve `$EXTRACT` → fill the stub from it, CREATE-style). After `MAX_RETRIES=2`, **HARD HALT** listing each surviving stub. A stub foundational file is NEVER a passing state — same mechanical gate as 5.3.2. This makes the `phase-4-templates.md:150` "MUST-populate non-stub" validator real (it was specced there but never implemented).

#### 5.3.2 Audit body

For each pack-added file (added by Phase 4.2 / 4.4 / 4.4b — i.e. files that exist in current but NOT in the backup snapshot for REFRESH mode, OR all files added by those phases for CREATE/ENHANCE), verify that Phase 4.6's STUDY → DECIDE → ACT step actually fired:

1. **Categorize the file** — based on Phase 4.6 decision recorded:
   - **CHANGE-anchor**: file should have a `## Project-specific (<project-name>)` heading near the top.
   - **CHANGE-anchor-with-warn-conflict**: same anchor, plus a "**Conflicts with generic body**:" sub-block.
   - **LEAVE (project has richer project-authored equivalent)**: file should have a brief redirect note at top citing the project-authored equivalent.
   - **LEAVE (off-topic — should have been deleted)**: file should NOT exist.

2. **Run the check (presence + quality, not just presence)**:
   ```bash
   # File category determines whether anchor must cite identifiers.
   # PATH-CITING categories: rules/agents/patterns referencing data access, controllers,
   #                        error handling, auth, testing, multi-tenancy, observability,
   #                        any rule whose topic involves project-specific code shapes.
   # WORKFLOW categories: git-workflow, documentation-principles, code-review-flow,
   #                     branching-strategy — anchor cites team conventions, not identifiers.

   # Helper — extract ONLY the body of the "## Project-specific (...)" anchor block,
   # bounded by either the next H2 (any text after `## ` that is NOT "Project-specific")
   # or a horizontal rule `---` on its own line. Using `^## ` instead of the loose
   # `^## [^P]` pattern below avoids false-positives like `## Pre-flight` where the
   # second character happens to not be 'P' but the section is still a sibling H2.
   extract_anchor_body() {
     local file="$1"
     awk '
       /^## Project-specific/ { in_anchor = 1; next }
       in_anchor && /^## / && !/^## Project-specific/ { exit }
       in_anchor && /^---[[:space:]]*$/ { exit }
       in_anchor { print }
     ' "$file"
   }

   for f in <pack-added-files>; do
     decision=$(lookup_phase_4_6_decision "$f")
     category=$(classify_pack_file "$f")    # path-citing | workflow | governance
     case $decision in
       CHANGE-anchor*)
         # Check 1 — anchor PRESENCE
         grep -q "^## Project-specific" "$f" || { SHORTFALL="$SHORTFALL\n  $f: missing anchor block"; continue; }

         # Check 2 — anchor QUALITY (≥3 lines of project-specific content beyond the heading)
         anchor_body_lines=$(extract_anchor_body "$f" \
           | grep -vE '^(##|>|\s*$|---)' | wc -l)
         [ "$anchor_body_lines" -lt 3 ] && SHORTFALL="$SHORTFALL\n  $f: anchor too thin ($anchor_body_lines lines; need ≥3 lines of project-specific content)"

         # Check 3 — identifier traceability (path-citing categories ONLY)
         if [ "$category" = "path-citing" ]; then
           # Anchor must cite ≥1 concrete identifier (path or class name) traceable to extraction.
           identifier_count=$(extract_anchor_body "$f" \
             | grep -cE '`[A-Z][A-Za-z0-9]+`|`[a-z]+[/.][a-z/.]+`')
           [ "$identifier_count" -lt 1 ] && SHORTFALL="$SHORTFALL\n  $f: path-citing file has no concrete identifier in anchor (must cite ≥1 class/path from extraction)"

           # Each cited identifier must trace to extraction (cross-check with leak scan §5.3.5).
           for ident in $(extract_anchor_identifiers "$f"); do
             # Trace against whichever deep-extraction files exist (Fix C resolution — names drifted).
             grep -qF "$ident" .claude/_extracted-codebase.md .claude/_codebase-scan.md .claude/codebase-profile.md .claude/_extracted-idioms.md 2>/dev/null \
               || SHORTFALL="$SHORTFALL\n  $f: anchor cites '$ident' which is NOT in extraction (leak — re-run with extraction loaded)"
           done
         fi

         # Check 4 — anchor must NOT contain placeholder syntax
         grep -qE '<TODO>|<placeholder>|<base-class-path>|<RepositoryBase>|<ClassName>|<your-' "$f" \
           && SHORTFALL="$SHORTFALL\n  $f: anchor contains placeholder syntax (Phase 4.6 produced template-stamp output)"
         ;;
       CHANGE-anchor-with-warn)
         # Same checks as CHANGE-anchor PLUS the conflict sub-block must be present.
         grep -q "^## Project-specific" "$f" || { SHORTFALL="$SHORTFALL\n  $f: missing anchor"; continue; }
         grep -q "Conflicts with generic body" "$f" \
           || SHORTFALL="$SHORTFALL\n  $f: CHANGE-anchor-with-warn decision but no 'Conflicts with generic body' sub-block"
         ;;
       LEAVE-with-redirect)
         head -10 "$f" | grep -qE "(supplementary|primary guidance|see ai/)" \
           || SHORTFALL="$SHORTFALL\n  $f: missing redirect note (Phase 4.6 LEAVE decision didn't add the note)"
         ;;
       LEAVE-delete)
         [ ! -f "$f" ] || SHORTFALL="$SHORTFALL\n  $f: should have been deleted (Phase 4.6 LEAVE-delete decision)"
         ;;
     esac
   done
   ```

3. **If shortfall detected**:
   - **Auto-retry Phase 4.6 for the affected files** by re-invoking the `apply-pack-adaptation` skill with the failing files + explicit "only cite identifiers found in `.claude/_extracted-codebase.md`" instruction. This is what Critical Execution Rule 5 (HALT + RETRY) demands.
   - If retry STILL produces no anchor / thin anchor / placeholder anchor / leaked identifier → halt with explicit error citing each unadapted file + the specific quality check that failed. Don't ship "incomplete adaptation" silently.
   - **Retry exhaustion halt**: After 2 auto-retries (`MAX_RETRIES=2`), if any check still flags shortfalls, emit a HARD HALT with the full list of unresolved findings (file paths + check name). Refuse to ship partial fixes. The user must resolve manually before re-running. This is the same `gaps_in == gaps_closed` mechanical gate from `migration-discipline.md`.

4. **Anti-pattern detection** (specific failure modes the quality checks catch):
   - **Anchor missing**: pack file shipped UNCHANGED → "Phase 4.6 SKIPPED for X files. Re-running."
   - **Anchor too thin** (<3 lines of project-specific content): "Phase 4.6 produced lazy anchor (`'this project uses TypeScript and follows MVC'`-class output). Re-running with deeper extraction loaded."
   - **Anchor cites no identifiers in path-citing file**: "Phase 4.6 produced anchor without concrete identifiers — failed to ground in extraction. Re-running."
   - **Anchor cites placeholder syntax** (`<RepositoryBase>`, `<TODO>`, `<base-class-path>`): "Phase 4.6 produced template-stamp anchors, not project-specific. Re-running."
   - **Anchor cites identifiers not in extraction**: "Phase 4.6 LEAKED from another project's context. Re-running with explicit extraction-only constraint."

**File-category classification** (used by Check 3 above):

| Category | Examples | Identifier requirement |
|---|---|---|
| **path-citing** | `database-principles.md`, `auth.md`, `error-handling.md`, `multi-tenancy.md`, `testing.md`, `observability.md`, every agent with "Reference paths" section, every pattern in `ai/patterns/` | ≥1 concrete identifier (class name or path) traceable to extraction |
| **workflow** | `git-workflow.md`, `documentation-principles.md`, `code-review-flow.md`, `branching-strategy.md` | No identifier requirement — anchor cites team conventions (PR template, commit format, SLA) |
| **governance** | `engineering-principles.md`, `quality-principles.md` | Per-section "Applies when" check (see `apply-pack-adaptation` skill § "Special case — engineering-principles.md") |

5. **Report at end of Phase 5**:
   ```
   Phase 4.6 ADAPTATION AUDIT:
     Pack-added files: <N>
     CHANGE-anchor decisions:           <X>  ✓ all anchored
     CHANGE-anchor-with-conflict:       <Y>  ✓ all flagged
     LEAVE-with-redirect:               <Z>  ✓ all redirected
     LEAVE-delete:                      <W>  ✓ all deleted
     Shortfalls auto-retried:           <K>
     Final shortfalls (HALT condition): <0 expected>
   ```

This audit is the safety net that catches the "you just copied templates" failure mode. Without it, Rule 7 has no enforcement.

**5.3.5 Cross-project leak scan (NEW — runs in every mode after Phase 5.3 adaptation audit)**:

This is the safety net for the failure mode the user reported: generated rules / agents / patterns / conventions ship with class names, paths, library names, or business rules from a DIFFERENT project than the one being set up. It happens when the LLM under context pressure pattern-matches "what an adapted rule looks like" against memory of a prior run instead of reading `.claude/_extracted-codebase.md` for THIS run.

The scan does three things:

1. **Cross-reference every concrete class name + import path in generated `.claude/rules/*.md`, `.claude/agents/*.md`, `ai/patterns/*.md`, `ai/conventions.md`, `CLAUDE.md`, `AGENTS.md` against the deep-extraction source (resolve `.claude/_extracted-codebase.md` → `.claude/_codebase-scan.md` → `.claude/codebase-profile.md`, first that exists) + `.claude/_extracted-idioms.md`**. If a generated file cites `<ClassX>` at `<libs/foo/bar.ts>` but extraction has no record of that class or path → flag as leak. Any concrete identifier in a project-specific block must trace to extraction.

2. **Cross-reference every concrete library / framework name in generated content against detected stack** (`.claude/codebase-profile.md` § stack). If generated content says "this project uses <FrameworkX>" but the stack section doesn't include FrameworkX → flag as leak.

3. **Scan for known leak markers** — internal product names from prior runs that may have been carried in by a confused LLM. The leak markers are configured in `~/.claude/templates/leak-markers.txt` (one regex per line, version-controlled). Default markers include any tokens the user has flagged in past sessions. The user can append project-internal codenames to this file so they're never accidentally written into other projects' setup.

```bash
# Pseudocode for the scan
LEAKS=""
for f in $(find .claude/agents .claude/rules .claude/skills .claude/commands ai/patterns ai/conventions.md CLAUDE.md AGENTS.md -type f -name "*.md" 2>/dev/null); do
  # Check 1: concrete identifiers must trace to extraction
  for ident in $(extract_concrete_class_names_and_paths "$f"); do
    if ! grep -qF "$ident" .claude/_extracted-codebase.md .claude/_extracted-idioms.md 2>/dev/null; then
      LEAKS="$LEAKS\n  $f: cites '$ident' which is not in this codebase's extraction"
    fi
  done
  # Check 2: framework names must match detected stack
  for fw in $(extract_concrete_framework_names "$f"); do
    if ! grep -qF "$fw" .claude/codebase-profile.md 2>/dev/null; then
      LEAKS="$LEAKS\n  $f: cites '$fw' which is not in detected stack"
    fi
  done
  # Check 3: known leak markers
  while IFS= read -r marker_re; do
    [ -z "$marker_re" ] && continue
    if grep -E -q "$marker_re" "$f"; then
      LEAKS="$LEAKS\n  $f: matches leak marker /$marker_re/"
    fi
  done < ~/.claude/templates/leak-markers.txt
done

if [ -n "$LEAKS" ]; then
  echo "LEAK SCAN FAILED:$LEAKS"
  # Auto-retry: re-run Phase 4.6 for the affected files with EXPLICIT instruction
  # to read .claude/_extracted-codebase.md FIRST and only cite identifiers found there.
  # If still failing → halt with the leak list as the error.
fi
```

Report at end of Phase 5:
```
CROSS-PROJECT LEAK SCAN:
  Files scanned: <N>
  Concrete identifiers traced to extraction: <X>/<X> ✓
  Framework / library mentions matching detected stack: <Y>/<Y> ✓
  Known leak markers matched: 0 ✓
  Status: CLEAN
```

If the scan fails after retry, the halt message MUST list every leaking file + the offending identifier so the user can decide: was it correct (extraction missed it → re-run with deeper Phase 2) or was it a leak (regenerate that file).

**5.4 Schema validation (Advanced Capabilities § 3 — opt-in; reconciles with Hard Rules § 3.5)**:

Schema validation is **opt-in by default** — see Hard Rules § 3.5 (where this policy was softened from "every adapter MUST have a schema or halt" to "validate when schemas are present + `--validate-schemas` was passed").

```
Trigger matrix:
  --validate-schemas passed             → validate every generated config; missing schemas → SCHEMA_MISSING warning, no halt
  --refresh + schemas present on disk   → SHOULD validate (warn-on-miss, no halt)
  --strict added                        → SCHEMA_MISSING + validation failure both promoted to halts
  Neither flag, no schemas              → skip 5.4 entirely; report line: "Schema validation: skipped (no schemas; opt-in)"
```

For each generated artifact when validation runs:

- **JSON configs** (e.g. `opencode.json`, `.continue/config.yaml`-converted-to-JSON, `.aider.conf.yml`-converted-to-JSON, `.claude/settings.json`): validate against `~/.claude/templates/schemas/<adapter>/<file>.schema.json` if it exists. Missing schema → `SCHEMA_MISSING <adapter>/<file>` warning. Failed validation → retry generator once, then either halt (if `--strict`) or warn-and-continue.
- **YAML frontmatter** (in `.claude/agents/*.md`, `.claude/commands/*.md`, `.claude/skills/<name>/SKILL.md`): extract the frontmatter block, validate against the corresponding schema if present. Same warn/halt policy as JSON.
- **`AGENTS.md` / `CLAUDE.md`**: structural validation only (required sections present per the codex / claude-code adapter contracts in Phase 4.8.0). Missing required section → halt regardless of `--strict` (this is a contract violation, not a schema miss).
- **`--validate-schemas` flag** also enables **dry-invoke smoke test** for every generated command: parse YAML frontmatter, verify referenced agents/skills/commands exist, verify any inline Bash blocks parse via `bash -n`. Smoke-test failures behave like schema failures (warn unless `--strict`).

Final report line under every mode:
```
Schema validation: <run|skipped>
  Schemas present:  <N>/<expected>
  Validated:        <K> (<ok> ok, <warn> warnings, <fail> failures)
  Strict mode:      <on|off>
```

**5.4b Health score + telemetry emit (Advanced Capabilities § 2 — runs at end of every Phase 5; distinct from REFINE-only 5.5 setup-quality score in `phase-5.5-quality.md`)**:

- Compute health score per the formula in § 2.1 (baseline / pack-coverage / adapter-completeness / cross-ref / convention-match / version-currency / usage-signal).
- Append composite score + sub-scores to `ai/_session-digest.md` § "Setup health" line:
  ```
  ## Setup health
  Score: 87/100 (Good) · Last computed: 2026-04-25 · Weakest: version-currency 70
  ```
- Append one entry to `.claude/_telemetry.jsonl`:
  ```jsonl
  {"ts":"2026-04-25T14:35:00Z","kind":"setup-run","mode":"REFRESH","duration_ms":42000,"files_written":47,"score":87}
  ```
- Skip telemetry append if `--no-telemetry` flag set OR `claude_config.telemetry: false` in `.claude/settings.json` (project-scoped) OR `~/.claude/settings.json` (global). The `setup_drift_check` key is a **separate** opt-out for session-start version-drift advisories — it does NOT suppress telemetry.

**5.6 Version drift report (Advanced Capabilities § 1 — runs at end of every Phase 5)**:

- Compare each pack's recorded version (from `.claude/codebase-profile.md` § "Setup version") against current `~/.claude/templates/<scope>/<name>/_version.json`.
- If drift exists in non-REFRESH mode: emit advisory at end of report.
- If drift exists AND mode = REFRESH: confirm versions in profile were updated to current.

**5.7 REFRESH-mode cleanup (only when mode = REFRESH AND audit passed)**:

- Delete `.claude/_refresh-knowledge-extract.md` (the temp working file). It served its purpose — Phase 2 merged it, Phase 4 consumed it, Phase 5 audited against it. Keeping it is noise.
- Append `## Recent Changes` entry to `ai/status.md`:
  ```
  ## Recent Changes (<YYYY-MM-DD>)
  ### Setup refresh (`/setup-project --refresh`)
  - Backup: <BACKUP_DIR> (<N> files preserved; restore via <BACKUP_DIR>/restore.sh)
  - Extracted <K> durable items across 8 categories
  - Regenerated: <list of regen-targeted dirs>
  - Preserved verbatim: <list of preserved categories e.g. "ADRs (12), corrections (8), custom glossary (6)">
  - Stale extract items resolved: <count> (see .claude/codebase-profile.md § "Stale extract items")
  ```
- Print restore instructions one final time at end of report:
  ```
  If something looks wrong, restore the previous setup with:
    bash <BACKUP_DIR>/restore.sh
  ```

