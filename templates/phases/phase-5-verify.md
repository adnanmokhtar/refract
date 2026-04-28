---
phase: 5
name: verify
applies-to-modes: [all]
inputs: [phase-4-outputs, hard-rules, schemas]
outputs: [verification-report, halt-or-pass, retry-loop-state]
exit-criteria: every must/must-not rule passes; coverage check + retry loop exhausted; setup-quality score emitted (REFINE only)
sub-phases:
  - 5.0: coverage check + retry loop
  - 5.1: required-baseline check
  - 5.2: inventory diff
  - 5.4: schema validation (frontmatter + dry-invoke smoke)
  - 5.5: setup-quality score (REFINE only)
hard-rule: HALT + RETRY, not "report and continue". See templates/governance/hard-rules.md.
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
             grep -qF "$ident" .claude/_extracted-codebase.md .claude/_extracted-idioms.md 2>/dev/null \
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

1. **Cross-reference every concrete class name + import path in generated `.claude/rules/*.md`, `.claude/agents/*.md`, `ai/patterns/*.md`, `ai/conventions.md`, `CLAUDE.md`, `AGENTS.md` against `.claude/_extracted-codebase.md` + `.claude/_extracted-idioms.md`**. If a generated file cites `<ClassX>` at `<libs/foo/bar.ts>` but extraction has no record of that class or path → flag as leak. Any concrete identifier in a project-specific block must trace to extraction.

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

**5.5 Health score + telemetry emit (Advanced Capabilities § 2 — runs at end of every Phase 5)**:

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

### Coverage check + retry loop (the false-idempotent-bug prevention)

Compare actual file counts against the **minimum-artifacts table** (from Phase 4.0) + the **pre-flight inventory** (from Phase 4.2.a):

```bash
# For each selected track, verify minimums
for track in <selected-tracks>; do
  expected_agents=<from minimums table>
  actual_agents=$(ls .claude/agents/*.md 2>/dev/null | wc -l)
  if [ "$actual_agents" -lt "$expected_agents" ]; then
    echo "SHORTFALL: track $track expected ≥$expected_agents agents, got $actual_agents"
    SHORTFALL=1
  fi
  # ... repeat for commands, skills, rules, ai-patterns
done

if [ "$SHORTFALL" = "1" ]; then
  echo "Coverage check failed. Auto-retrying Phase 4.2 deterministic copy..."
  # RE-RUN the deterministic cp commands from Phase 4.2.b
  # Then re-verify
fi

if [ "$SHORTFALL" = "1" ]; then  # still failing after retry
  echo "HALT: coverage check failed after retry. Manual investigation required."
  exit 1
fi
```

The retry is critical: it handles transient LLM context-pressure skips. Most shortfalls resolve on the second attempt (the retry is mechanical `cp`). Only persistent failure halts.

### Required-baseline check

Beyond per-track minimums, verify the baseline list defined in Phase 4.0 ("Required baseline files"). Same retry-then-halt pattern: if missing, retry the baseline copy, then halt if still failing.

### Inventory diff

Diff Phase 4.2.a pre-flight inventory (expected file list) against actual file system state:
- **Missing files**: in pre-flight, not on disk. Trigger retry.
- **Extra files**: on disk, not in pre-flight. Investigate (intentional generation? silent extra?).
- **Match**: report total file count + GO.

**5.8 Surface uncertainty**:
- Every `[INFERRED]`, `[UNKNOWN]`, `[CONFLICT]` from Phase 2 + 3 surfaces in the final report under "Open questions / decisions blocked".
- Every `_UNKNOWN_` placeholder in `ai/project-goals.md` etc. surfaces here too.
- These are not bugs — they're explicit deferrals the user must resolve.

**Report**:
```
✅ <project-name> — <mode>
📍 <cwd>
🏗  <shape>

Detected stack: <...>
Detected signals: <...>

Applied:
  Tracks: <list with file counts>
  References: <list>
  Domain tooling: <list>
  Tool adapters: <list — e.g. "claude-code, cursor, aider">

Generated (new agents saved to packs for reuse):
  <list>

Skipped (filter + merge):
  <summary with counts>

Knowledge base:
  <created / updated / left-alone counts>

Tool configs written (per adapter, full artifact translation):
  claude-code: .claude/ (rules: N, commands: X, agents: A, skills: S, hooks: H), CLAUDE.md
  <tool-N>:    <rules: <n> · commands: <x> · agents: <a> · skills: <s> · hooks fallback: git+docs>

Parity disclosure: ai/references/tool-parity.md (what's native vs translated vs not-possible per tool)

Next steps:
  1. <concrete — "cd api && pnpm install" or similar>
  2. Review ai/runbooks/phase-1-mvp-plan.md Day 1
  3. git init + initial commit
  4. (Optional) Customize CLAUDE.md section X

Outstanding questions / flags:
  <anything the user needs to decide>
```

### Phase 5.5 — Setup-quality score (REFINE mode only)

**Trigger**: REFINE mode (`--refine`). Standard modes use the lighter `--health` flag; REFINE produces a richer per-artifact score.

**Why this exists**: REFINE rewrites only artifacts whose round-one anchor was shallow. To decide which is "shallow," we need a deterministic score, not a vibe check. The score is also what tells the user "round two added X points; running `--refine` again would add ≤ 2 — plateau reached, stop here."

**Mechanism**: invoke the `compute-anchor-density` skill (lives in `~/.claude/templates/packs/learning/skills/compute-anchor-density.md`) for every Phase-4-generated artifact (`.claude/agents/*.md`, `.claude/skills/*.md`, `.claude/rules/*.md`, `.claude/commands/*.md`, `ai/*.md`). The skill scores each file on four axes (each 0–25, total 0–100):

1. **Name density** (0–25): how many concrete project identifiers (class names, function names, table names, endpoint paths, package names) appear in the `## Project-specific` block. ≥ 6 = full marks; 0 = zero.
2. **Path density** (0–25): how many concrete `file:line` or `file/path/` citations appear in the block, AND whether each citation is verified to exist in `.claude/_extracted-codebase.md` or `.claude/_refine-extract.md`. ≥ 5 verified = full marks.
3. **Signal density** (0–25): how many of the deep-extraction inputs (entities, flows, hot paths, emergent conventions, failure themes) the block actually consumes — only counts when the block exists AND the upstream extraction yielded STRONG results. ≥ 4 distinct signals consumed = full marks.
4. **Specificity** (0–25): the inverse of generic-prose ratio. Counts placeholder-y phrases (`<TODO>`, `<base>`, `the project's <X>`, "use parameterized queries", "follow framework conventions" — no specific framework named) and deducts 5 per phrase up to 25.

Total per artifact = sum of the four. Reported in `.claude/_setup-quality.md`.

**Plateau is two-class** — never a single binary. The user reading the report MUST know whether the plateau means "we're done because everything is deep" (good) or "we're stuck because extraction was weak" (the user has work to do upstream before another `--refine` will help). The plateau classifier:

| Class | Condition | Message | What the user should do |
|---|---|---|---|
| **PLATEAU-DEEP** | `plateau_delta ≤ ΔMax` AND `plateau_consumed ≥ Cmin` AND `avg_score ≥ Smin` | `## Plateau reached (DEEP) — setup is anchored; further --refine adds nothing meaningful.` | Stop running `--refine` until significant new code lands. |
| **PLATEAU-WEAK** | `plateau_delta ≤ ΔMax` AND `plateau_consumed < Cmin` (i.e. less than `Cmin` of available signal was consumable because the upstream extraction phases hit their `[REFINE-WEAK: <axis>]` quality gates) | `## Plateau reached (WEAK) — setup is NOT yet anchored deeply, but no further refinement is possible from current extraction. <N> phases produced WEAK output: <list>.` | Grow upstream signal: more commits (failure-history), more code/tests (entities/flows), opt into `--include-incidents=<path>` if postmortems exist, etc. THEN re-run `--refine`. |
| **NOT-PLATEAU** | `plateau_delta > ΔMax` OR (first run with no prior baseline) | (no plateau message) | Re-running `--refine` would still climb. Run again if score < 70 average. |

**Default thresholds (tunable via flags):**
- `ΔMax = 2`   — override with `--plateau-delta=<N>`
- `Cmin = 0.85` — override with `--plateau-consumed=<F>`
- `Smin = 80`   — override with `--plateau-score=<N>`

**Why thresholds are tunable**: the defaults above are theoretical — calibrated against synthetic fixtures, not against a real-world corpus of `--refine` runs. As REFINE telemetry accumulates in `.claude/_setup-quality.md` history across many projects, maintainers should re-evaluate whether `2 / 0.85 / 80` actually predicts "stop running --refine" for the median project, OR whether the classifier should be more aggressive (lower `ΔMax`, higher `Smin`) to push users toward growing upstream signal. For now: defaults are conservative — they prefer "keep climbing" over "declare plateau," because the cost of an extra REFINE run (a few minutes, no user-content damage thanks to marker safety) is much less than the cost of stopping at score 65 thinking the setup is done.

**Critical**: a plain `## Plateau reached` message is forbidden. The classifier MUST tag DEEP vs WEAK. A user seeing "plateau reached" with score 58 should immediately understand "we plateaued because there's nothing more to consume, not because we got everything." The two-class messaging is the contract.

The full report:

```markdown
# Setup quality — anchor-density score
> Generated by /setup-project --refine on <YYYY-MM-DD HH:MM>.
> Threshold for "anchored": 70/100. Threshold for "deep": 85/100.

## Summary
- Total artifacts: 18
- Anchored (≥ 70): 14 (was 4 in round one — +10)
- Deep (≥ 85): 6 (was 0 in round one — +6)
- Shallow (< 70): 4 — see § "Refinement opportunities"
- Average score: 81/100 (was 47/100 in round one — +34)
- Plateau check: deep-extraction signals consumed = 92% — re-running `--refine` would add ≤ 2 points.

## Plateau verdict
**PLATEAU-DEEP** — setup is anchored at avg 81/100; signals_consumed = 92% means there's almost nothing left to deepen. Further `--refine` runs will not move scores meaningfully. Stop running `--refine` until significant new code lands.

## Per-artifact scores

| Artifact | Round 1 | Round 2 | Δ | Notes |
|---|---|---|---|---|
| `.claude/rules/database.md` | 42 | 88 | +46 | DEEP — cites 7 entities + 4 hot paths |
| `.claude/rules/code-quality.md` | 65 | 65 | 0 | LEAVE-DEEP — no entity / flow signal applies; round-one anchor is optimal |
| `.claude/agents/backend-architect.md` | 38 | 79 | +41 | ANCHORED — cites 3 lifecycles + 5 boundaries |
| `.claude/skills/parallelize-independent-ops.md` | 51 | 84 | +33 | DEEP — cites 4 hot paths with N+1 |
| ... | | | | |

## Refinement opportunities (artifacts < 70)
- `.claude/rules/security.md` — score 62. Could improve if `.claude/_refine-extract.md` `## Failure history` had STRONG result (currently WEAK). Re-run after committing a `docs/postmortems/` directory.
- ... (3 more)

## Extraction quality (per-axis)
- Phase 2.7 (entities):     STRONG (7 entities, 12 invariants)
- Phase 2.8 (architecture): STRONG (4 boundaries, 5 lifecycles)
- Phase 2.9 (flows):        STRONG (5 flows, all with file:line citations)
- Phase 2.10 (conventions): STRONG (8 emergent patterns)
- Phase 2.11 (hot paths):   STRONG (10 hot paths, 6 with N+1 risk)
- Phase 2.12 (failures):    WEAK (only 18 commits in git log; threshold is 30) — failure-themes section empty
```

Contrast — a WEAK plateau (different project, smaller codebase):

```markdown
## Plateau verdict
**PLATEAU-WEAK** — setup is NOT yet anchored deeply (avg 58/100), but the extraction substrate is exhausted: 4 of 6 deep-extraction phases produced WEAK output (entities, flows, hot paths, failures). Running `--refine` again will not improve scores until you grow upstream signal:
- `entities`: WEAK (only 2 model classes detected) — add more domain models, then re-run.
- `flows`: WEAK (only 1 endpoint traced; threshold is 5) — add more endpoints, then re-run.
- `hot paths`: WEAK (no monitoring config / no Datadog dashboard / no high-churn endpoints) — add more usage signal, then re-run.
- `failures`: WEAK (12 commits; threshold is 30) — accumulate more git history, then re-run.
**Do NOT keep running `--refine` against an unchanged codebase — there's nothing left to consume.** Grow signal first.
```

**Exit codes**:
- `0` if `PLATEAU-DEEP` OR `avg_score ≥ 70` (the setup is good enough or has plateaued in a healthy state).
- `2` if `PLATEAU-WEAK` (the setup is NOT good enough, but rerunning won't help — exit code 2 is "user action required upstream"). Honoring this exit code in CI lets a maintainer surface "REFINE didn't help — go grow signal" without conflating it with hard errors.
- `1` if hard error (rollback occurred, missing required input, schema validation failed).

**Idempotency check**: REFINE compares the new score to the prior `.claude/_setup-quality.md` (if present). If 2nd / 3rd `--refine` run produces Δ ≤ 2 points, REFINE writes the report and emits the appropriate plateau verdict per the classifier above. The plain "## Plateau reached — no further refinement needed" wording is NEVER emitted alone — it is always one of the two classes.

---

