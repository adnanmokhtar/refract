---
phase: 4
sub-phase: "4.2"
name: apply-copy-or-author
applies-to-modes: [all]
inputs: [accepted-packs, gate-decision (COPY | AUTHOR), extracted-idioms (AUTHOR only)]
outputs: [written-files, per-track-verification-report]
exit-criteria: every track's minimum artifacts written; post-copy verification clean (4.2.c); managed markers in place
sub-steps:
  - 4.2-AUTHOR  — author from extracted idioms (AUTHOR-mode tracks)
  - 4.2.a       — pre-flight inventory (mandatory)
  - 4.2.b       — deterministic copy (Bash, NOT model-rewritten)
  - 4.2.c       — immediate post-copy verification
governing-rules: [A11, A12, A14, A15, N10, N11]
imported-by: templates/phases/phase-4-apply.md
---

### 4.2-AUTHOR — Author from extracted idioms (when gate selected AUTHOR mode)

For each track in AUTHOR mode:

1. **Read the topic spec** at `~/.claude/templates/packs/<track>/_topics.md`. It lists the patterns/agents/rules every project in this discipline must cover, each as a topic spec (required sections + extraction recipes — NOT as a finished file body).
2. **For each topic** in the spec:
   - Look up the relevant section(s) in `.claude/_extracted-idioms.md` (e.g., topic `data-access` consumes the idiom block for the project's repository base class).
   - If extraction has signal → invoke the authoring flow as follows: **if pack has `_topics.md`, the agent MUST locate the topic-specific authoring section by topic-slug match against the pack's track. If no match, fall back to `extract-base-class-idiom § Step 6`.** Pre-flight: verify the topic slug resolves before Phase 4.2 begins; halt if it doesn't. Output is project-voice content citing real paths, real extenders, real pitfalls.
   - If extraction has NO signal for this topic → **read that topic's `fallback:` field and copy what it names, verbatim.** The value is either a pack-relative path — `_examples/<topic>.md` for most topics, or `agents/` / `rules/` / `commands/` / `skills/<name>/SKILL.md` / `ai-patterns/` where the pack has decided the source IS the fallback — or the literal `stub-from-sections`, which emits a sectioned stub from that topic's `sections:` list. **Do not resolve the fallback by globbing `_examples/<topic>.md`.** **Zero** topics now ship an `_examples/` file their entry disowns — the three that did have all been deleted (`code-quality/refactor` at 600659c, `mobile/refactor` at 21ce271, and `ai-engineering/ai-engineering-principles` at f207ce2), and each was a thin usage anecdote that a glob would have installed over the declared source: for `mobile/refactor`, six lines of prose where the command overlay belongs. The rule stands on the mechanism, not on a current instance — the moment a pack adds an `_examples/` file beside a topic that points its `fallback:` somewhere else, a glob silently prefers the wrong one, and nothing in the project it lands in can tell. Count and list checked against the tree at f207ce2; re-check before restating either. `fallback:` is the field `validate-pack-consistency.sh` resolves through (check 8b pairs each example with the source its topic names; check 3 fails a `fallback:` that does not resolve) and the field CONTRIBUTING §5b holds pack authors to, so the copy must read the same field the gate reads. Only a topic with NO `fallback:` falls through: `_examples/<topic>.md` if it exists, else the closest template in that pack's `agents/`, `rules/`, `commands/`, `skills/` or `ai-patterns/`, else a sectioned stub. Mark with `<!-- TODO: re-author from extraction once base class exists -->` when using fallback so future runs upgrade it.
3. **In ENHANCE/REFRESH mode**, before writing, READ any existing `ai/patterns/<topic>.md` in the project and mirror its section order + voice (Step 5.5 of the skill). Authored content goes inside the existing skeleton; new sections (e.g., "Pitfalls" if missing) appended at the end.
4. **Always cite evidence** — every method, path, line number, extender count, deprecation warning in the output must trace to a real file the extractor read. No invention.

Output: same destination paths as COPY mode (`.claude/agents/`, `.claude/rules/`, `ai/patterns/`, etc.), same Phase 5 verification (file presence + minimums + retry). Difference is purely in how the content was produced.

> **The fallback IS the artifact, and it is only PARTLY gated as one.** Because step 2 copies the file each topic's `fallback:` names — `_examples/<topic>.md` for most topics, the pack's own `agents/` / `rules/` / `commands/` / `skills/` / `ai-patterns/` file where a pack declares the source IS the fallback — verbatim to the real destination, whatever that file says is what the project runs on — for greenfield, for `--lightweight`, and for every `[EXTRACTION-WEAK]` track Phase 4.0 routes here. Pack authors: `validate-pack-consistency.sh` check 8b compares each `_examples/` file against the source it abridges on the axes a text comparison can decide — a framed magnitude, dispatch target, or frontmatter value the source disowns; a dropped load-bearing section or safety signal; a body that is secretly a literal copy — with the known backlog enumerated in `templates/packs/_fallback-baseline.md`. **It does not read either file** — and it walks `_examples/` only, so a topic whose `fallback:` names the pack's own `agents/` / `rules/` / `commands/` / `skills/` file is outside 8b entirely; what covers that file instead is the Phase 4.0 per-kind pack-depth floor, which 8b's own header records as not reaching `_examples/`. A source edit that retracts a non-numeric rule, or flips a `MUST` to a `MUST NOT`, leaves the stale fallback GREEN — verified, not assumed. So re-cutting a fallback after editing its source is the author's obligation, and a green gate is not evidence you have met it. See CONTRIBUTING §5b for the exact list of what is and is not caught.

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

### 4.2.b-shape — Skill shape: ONE identity, two legal shapes (M40)

**The framework's position, stated once so nothing has to guess it:**

| shape | path | status |
|---|---|---|
| **CANONICAL** | `.claude/skills/<name>/SKILL.md` | What every pack ships (`templates/packs/*/skills/<name>/SKILL.md`), what every CREATE install writes, and what `templates/appendices.md` and `templates/tool-adapters/claude-code/adapter.md` both name. Agent Skills folder form. |
| **LEGACY** | `.claude/skills/<name>.md` | Flat form, written by pre-Apr-2026 setups. Still on disk in real projects. **Supported for reading and replacing in place. Never re-created.** |

**A skill's identity is its `<name>`, never its path.** The two shapes are the same artifact. Three consequences, all mechanical:

1. **Presence is resolved by identity — in every report, not just one.** `scripts/pack-coverage-scan.sh` tests both shapes before it writes a `Missing` row, and reports the flat ones under "Skill shape — N skill(s) on the LEGACY flat form" instead. `scripts/study-existing.sh` resolves the same way (`resolve_target_artifact`), so a legacy-flat skill is compared against its pack source and lands on a real merge-matrix verdict — `IDENTICAL-NO-OP` when the bodies agree — instead of an `**ADD**`. A legacy-form skill is **PRESENT**; it is not a Phase-4.2 copy target and it does not fail coverage.

   This is load-bearing, and it was true of the coverage scan alone for one release. `study-existing.sh` still resolved the target by PATH, and **that** report is the one `audit-setup.sh` C2k regenerates and gates Phase 5 on. Its `**ADD**` row was unclosable: `apply-study-decisions.sh --apply` correctly refuses it with `SHAPE-SKIP` (copying would create a same-`name:` twin), the regeneration prints the same row, and C2k's remediation is exactly that no-op apply. Three such rows on the observed real target; up to 59 on a project that never migrated. If you ever add a third report over these artifacts, resolve by identity there too.
2. **No write may put both shapes of one name on disk.** `check_skill_shape_twin()` in `scripts/apply-study-decisions.sh` refuses the write and the run exits 4; `check_skill_name_uniqueness()` in the same script re-checks the whole `.claude/skills/` tree by frontmatter `name:` afterwards, which also catches a duplicate whose two files are not filename twins. Every raw `cp` in this phase carries the same guard inline — see 4.2.b below.
3. **Migration is explicit and one-way, never a side effect.** A project on the legacy shape moves with:

```bash
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --migrate-skill-shape          # dry run — lists every move
~/.claude/scripts/apply-study-decisions.sh "$TARGET_REPO" --migrate-skill-shape --apply  # moves; backs up to .claude/backups/skill-shape-<ts>/
```

It **moves** each file (`.claude/skills/<name>.md` → `.claude/skills/<name>/SKILL.md`); it never copies, because a copy is precisely the duplicate being prevented. Any name already carrying both shapes is reported as a CONFLICT and left untouched for a human to resolve. Re-run `pack-coverage-scan.sh` and the adapter sync afterwards — adapters project skills by name, so the projection is unchanged, but the sources they read moved.

**Staying on the legacy shape is a legitimate choice.** REPLACE-OR-ENHANCE rewrites the flat file in place and the project keeps working. What is NOT a choice is carrying both: two files with one `name:` is a duplicate registration whose winner is undefined.

> **Why this is written down.** Run of 2026-08-22 against an 8,151-file target: 56 of 59 flat-form skills were reported `Missing`, arrived at `apply-study-decisions.sh --apply` as `ADD` rows, and were copied in under their folder-form names. The project ended with 56 skills registered twice — 112 files, 56 identical `name:` values — and the coverage report, which calls itself the source of truth, still instructed the next agent to do it again.

### 4.2.b Deterministic copy (executed via Bash, not model-written)

**Two modes**: STANDARD (default) and MINIMAL (when `--minimal` flag set).

#### Standard mode (default)

For each selected track, run these EXACT commands (substitute `<track>` for the track name):

```bash
# Copy agents (verbatim — no trimming possible at OS level)
mkdir -p .claude/agents
cp -R ~/.claude/templates/packs/<track>/agents/*.md .claude/agents/ 2>/dev/null || true

# Copy commands — COLLISION-AWARE (M41). NOT a bare `cp -R commands/*.md`: several command
# names are deliberately shipped by more than one pack as PACK-SPECIALIZED VARIANTS —
# docs/CHEATSHEET.md says so in as many words. Measured: `add-feature.md` ships in backend,
# frontend and mobile; `refactor.md` in backend, frontend, code-quality and mobile. They are
# DIFFERENT commands (backend add-feature is 523 lines, frontend's is 418), so a blind copy
# into a shared `.claude/commands/` means the last track applied SILENTLY DESTROYS the
# variants applied before it. A fullstack project loses one of each; a fullstack + mobile
# project loses two. Nothing warned, and the loss is invisible after the fact.
#
# A variant is never overwritten and never dropped. The first track to claim a name owns the
# bare `<name>.md`; every later variant lands beside it as `<name>.<track>.md`, and the
# collision is recorded so the choice is auditable rather than accidental.
mkdir -p .claude/commands
for c in ~/.claude/templates/packs/<track>/commands/*.md; do
  [ -f "$c" ] || continue                      # no commands dir / no match → nothing to do
  n=$(basename "$c")
  if [ ! -e ".claude/commands/$n" ]; then
    cp "$c" .claude/commands/"$n"; continue
  fi
  # Same bytes already there (re-run, or two packs shipping an identical file) → nothing to do.
  if cmp -s "$c" ".claude/commands/$n"; then
    echo "  cmd-skip: '$n' already installed, identical"; continue
  fi
  variant=".claude/commands/${n%.md}.<track>.md"
  cp "$c" "$variant"
  echo "  cmd-variant: '$n' already claimed by an earlier track — <track>'s variant installed as $(basename "$variant"), NOT overwritten"
  printf '%s\n' "- \`$n\` — <track> variant installed as \`$(basename "$variant")\`; the bare name belongs to the track applied first." \
    >> .claude/_command-variants.md
done

# Copy skills — SHAPE-AWARE (M40; see 4.2.b-shape above). NOT a bare `cp -R skills/*`:
# a skill has one identity (<name>) and two legal shapes, so a blind recursive copy into a
# project carrying the legacy flat shape installs a SECOND copy of every skill it already
# has. Skip any name already present in EITHER shape — that is also the documented default
# merge behaviour for this phase ("SKIP, don't overwrite"), which the old `cp -R` violated.
mkdir -p .claude/skills
for s in ~/.claude/templates/packs/<track>/skills/*/; do
  [ -d "$s" ] || continue                      # no skills dir / no match → nothing to do
  n=$(basename "$s")
  if [ -f ".claude/skills/$n/SKILL.md" ]; then
    echo "  shape-skip: '$n' already installed (canonical)"; continue
  fi
  if [ -f ".claude/skills/$n.md" ]; then
    echo "  shape-skip: '$n' already installed as .claude/skills/$n.md (legacy flat shape — same skill)"; continue
  fi
  cp -R "$s" .claude/skills/
done

# Copy rules
mkdir -p .claude/rules
cp -R ~/.claude/templates/packs/<track>/rules/*.md .claude/rules/ 2>/dev/null || true

# Path-scope TRACK rules in MULTI-TRACK projects (full-stack / monorepo) so a track's
# rules load only when Claude touches that track's source — prevents cross-track context
# pollution (one track's rules loading during another track's work). SINGLE-track projects
# skip this: they never install a sibling track's rules, so there is nothing to pollute.
#
# BOTH substitutions below are read from `.claude/codebase-profile.md` BY KEY, never by
# section number. HISTORY: this contract used to say "read verbatim from § 17" and instruct a
# halt when § 17 was missing. On a live repo § 17 was `Project intent` and the shape block sat
# under § 19 — the producer's own numbering had drifted from the number written here — so the
# consumer read the wrong section, found no `is_multi_track`, and the halt never fired because
# the section it was told to check DID exist. A section NUMBER is not a contract; a KEY is.
# Grep for the key across the whole file:
#   <is-multi-track>  = the `is_multi_track:` value  (true when ≥2 distinct load-bearing
#                       STACK tracks exist across members; ALWAYS-ON tracks never count).
#   <track-src-root>  = `track_roots[<track>]` — the comma-separated glob list for THIS track.
#                       Already a glob list, so pass it through unchanged; scope-rules.sh
#                       accepts comma-separated globs.
#
#   IS_MULTI_TRACK=$(grep -m1 -E '^[[:space:]]*is_multi_track:' \
#                      "$TARGET_REPO/.claude/codebase-profile.md" \
#                    | sed -E 's/.*is_multi_track:[[:space:]]*//; s/[[:space:]]*(#.*)?$//')
#
# If the KEY `is_multi_track:` is absent anywhere in the file, or its value is neither `true`
# nor `false`, do NOT default to false — that silently ships every track's rules unscoped into
# every file's context. Halt and complete the repo-shape block.
#
# CONSISTENCY HALT — `repo_shape` and `is_multi_track` are independent but not unconstrained.
# A profile asserting `repo_shape: single` together with `is_multi_track: true` is legal (one
# manifest, a server dir and a client dir), but a profile asserting `is_multi_track: true`
# with an EMPTY or absent `track_roots:` is not: the true branch below would then scope every
# rule to nothing. Measured on a live repo: `repo_shape: single` + `is_multi_track: true` was
# recorded and exactly ONE rule in the whole target carried `paths:` frontmatter, so the true
# branch demonstrably never ran. Halt when `is_multi_track: true` and `track_roots:` lists no
# track.
# Core baseline rules in .claude/rules/ (read-before-write, code-quality, think-simplify-surgical,
# read-codebase-deeply) are UNIVERSAL — never scope them.
if [ "<is-multi-track>" = "true" ]; then
  for r in ~/.claude/templates/packs/<track>/rules/*.md; do
    ~/.claude/scripts/scope-rules.sh ".claude/rules/$(basename "$r")" "<track-src-root>" 2>/dev/null || true
  done
fi

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
    # M40 shape guard — identical rule to standard mode: one identity, two legal shapes.
    if [ -f ".claude/skills/$name/SKILL.md" ] || [ -f ".claude/skills/$name.md" ]; then
      echo "  shape-skip: '$name' already installed"; continue
    fi
    # Land in the CANONICAL shape even when the pack ships the flat fallback that
    # validate-pack-consistency.sh check 4 still accepts — new installs never get flat.
    if [ -d ~/.claude/templates/packs/<track>/skills/$name ]; then
      cp -R ~/.claude/templates/packs/<track>/skills/$name .claude/skills/
    elif [ -f ~/.claude/templates/packs/<track>/skills/$name.md ]; then
      mkdir -p .claude/skills/$name
      cp ~/.claude/templates/packs/<track>/skills/$name.md .claude/skills/$name/SKILL.md
    fi
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

**Phase 4.2 mechanical halt**: After all tracks complete, count files written per track. If any track yielded fewer than 1 file per category expected (agents/commands/rules/patterns), HALT. Do NOT advance to Phase 4.3 — Phase 5 retry is for systematic failures, NOT for missing-artifact escapes from this phase.

### Merge handling (when files already exist in target)

If a destination file already exists (`.claude/agents/code-reviewer.md` already there from a prior run):
- Default behavior: SKIP (don't overwrite — `cp -n` semantics).
- `--force-replace-all`: overwrite.
- `--force-keep-all`: same as default (skip).
- Pre-flight inventory must distinguish: "X new files + Y skipped (already exist)".
- **"Already exists" is decided by IDENTITY, not by path** (M40). For skills that means: `<name>` counts as existing if EITHER `.claude/skills/<name>/SKILL.md` OR `.claude/skills/<name>.md` is on disk. `--force-replace-all` overwrites **the shape that is installed** — it never adds the other one. Nothing in this phase, at any flag setting, may leave both shapes of one name on disk; `check_skill_shape_twin()` refuses and the run exits 4.

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

**4.4 Apply technical-domain tooling** — for every TECHNICAL signal in the profile's `technical_signals:` array (§11), copy the matching domain folder. **Deterministic + enforced — same model as 4.2 (`cp` cannot skip); the LLM's only job is to read the key list, the shell does the copy.** A prose instruction here is NOT sufficient: this step previously shipped as one sentence with no shell enforcement and no coverage report, and so a run could silently install ZERO domains while the profile's prose "detected" all of them. It is now mechanical:

```bash
# Apply the UNION of (a) canonical keys Phase 2 §11 detected and (b) keys forced via --include=.
# (a) detected — NOT prose, exact registry keys from §11.
# PORTABILITY — this line MUST NOT use `grep -P`. It was `grep -oP '…\K…'` for one release:
# PCRE is a GNU extension, /usr/bin/grep on macOS rejects `-P` outright ("invalid option -- P"),
# and this is the single line that decides which technical domains get installed. On a stock
# macOS shell DETECTED would have been empty and Phase 4.4 would have silently installed ZERO
# domains — the exact failure this step's own text says it was rewritten in shell to prevent.
# It only ever worked because the session shell happened to shim `grep` to ugrep. POSIX ERE +
# sed below is portable to BSD and GNU alike. `scripts/lint-setup-contracts.sh § rule 3` fails
# the build if `grep -P` reappears anywhere in scripts/, templates/ or commands/.
#
# Read BY KEY, not by section number — see the § repo-shape note above for why.
DETECTED=$(grep -m1 -E 'technical_signals:[[:space:]]*\[' "$TARGET_REPO/.claude/codebase-profile.md" \
           | sed -E 's/.*technical_signals:[[:space:]]*\[//; s/\].*//' \
           | tr ',' '\n' | sed 's/ //g')
# (b) forced — every --include=<key> passed to this run that resolves to a real domain folder.
#     --include ADDS scope, never subtracts (per setup-project.md); a forced key may not be in §11
#     (the user knows a concern the scan couldn't infer). Honor it here so the deterministic copy covers it.
FORCED=$(printf '%s\n' "$INCLUDE_FLAGS" | tr ', ' '\n' | sed 's/ //g')   # INCLUDE_FLAGS = the run's --include= values
# (c) confidence — §11's `technical_signal_confidence:` rows, read BY KEY. A signal the
#     extraction demoted to `partial` still installs its domain, but the ratio is carried
#     into the domain coverage report so the demotion is not purely cosmetic. HISTORY: §11
#     was a bare key array and this branch did not exist; a signal matching 117 of 242 entity
#     files drove byte-identical behaviour to one matching 242 of 242, and the honest
#     demotion the extractor performed was discarded one file later.
conf_for() {   # $1 = signal key -> "confirmed 242/242" | "partial 117/242" | ""
  sed -n '/technical_signal_confidence:/,/^[^[:space:]]/p' \
      "$TARGET_REPO/.claude/codebase-profile.md" 2>/dev/null \
    | sed -nE "s/^[[:space:]]*$1:[[:space:]]*//p" | head -1
}
SIGNALS=$(printf '%s\n%s\n' "$DETECTED" "$FORCED" | grep -v '^$' | sort -u)   # union, de-duplicated

: > "$TARGET_REPO/.claude/_domain-coverage-report.md"
for sig in $SIGNALS; do
  src=~/.claude/templates/domains/"$sig"
  if [ ! -d "$src" ]; then
    echo "- ❌ $sig — NO SUCH DOMAIN under templates/domains/ (alias not normalized in §11 → HALT)" >> "$TARGET_REPO/.claude/_domain-coverage-report.md"
  elif [ -z "$(conf_for "$sig")" ]; then
    # A key in the array with no confidence row is §11 half-written. Refuse rather than
    # install a domain whose evidence strength nobody recorded.
    echo "- ❌ $sig — no \`technical_signal_confidence:\` row in §11 (bare key array → HALT; see phase-2-profile.md §11)" >> "$TARGET_REPO/.claude/_domain-coverage-report.md"
    continue
  fi
  for kind in agents commands rules ai-patterns; do
    [ -d "$src/$kind" ] || continue
    dest="$TARGET_REPO/.claude/$kind"; [ "$kind" = ai-patterns ] && dest="$TARGET_REPO/ai/patterns"
    mkdir -p "$dest"
    # each file still passes through the merge matrix (skip-if-user-edited); shell copies the rest verbatim
    cp -Rn "$src/$kind/." "$dest/"
  done
  echo "- ✅ $sig — applied (agents/commands/rules/ai-patterns)" >> "$TARGET_REPO/.claude/_domain-coverage-report.md"
done
```

- **Apply the union of detected + forced.** The applied set is `technical_signals:` (what Phase 2 detected) **unioned with** every `--include=<key>` passed to the run (`INCLUDE_FLAGS`). `--include` adds scope it can't subtract — a forced key absent from §11 (a concern the scan couldn't infer) is still applied. De-duplicate so a key in both is copied once.
- **Resolve every key (detected or forced) to a real folder.** A key with no `templates/domains/<key>/` folder is an un-normalized alias (e.g. `media-transcoding` instead of `media-processing`) or a bad `--include=` value — HALT and fix it, do not silently skip.
- **`_domain-coverage-report.md` is the source of truth** for "which domains should be present" — the Phase 5 audit (C2c) fails the run if any detected signal is neither applied nor explicitly skipped-with-rationale. This mirrors `_pack-coverage-report.md` for tracks.
- Each file passes through the merge matrix (user-edited regions preserved); the shell copies the rest verbatim — no LLM hand-copying, no skipping under context pressure.

**4.4a Project CODEBASE-overview content into the load-bearing `ai/` files** (round-one — consume `.claude/_extracted-codebase.md` from `extract-codebase-overview`):

`extract-codebase-overview` enumerates the project's modules + stack into `.claude/_extracted-codebase.md`, but nothing previously projected them into the two `ai/` files agents actually read for "where does new code go" + "what is this built with". This step does that projection (round-one; Phase 4.7-DEEP deepens conventions/architecture/flows separately). Source resolution follows the same order as Fix C (`_extracted-codebase.md` → `_codebase-scan.md` → `codebase-profile.md`; first that exists wins).

| Source section in `_extracted-codebase.md` | Destination | What gets projected |
|---|---|---|
| `## Modules` | `ai/modules.md` | One row per enumerated module into the `## Module catalog` table — name, path (real, not `<placeholder>`), Owns (one-line responsibility), Public surface, Cross-cuts. Module boundaries from `## Architecture` (declared layer/context constraints) fill `## Module boundaries`; omit when none detected. This is the file Hard Rule A16 ("every new file maps to a home") depends on. |
| `## Stack` | `ai/stack.md` | Runtime/language, framework(s), database + ORM, build tool, test framework, package manager — every value traced to a real manifest file. Leave `<e.g., …>` rows only where the manifest had no signal. |

Population obeys the stub-vs-authored test from `phase-4-templates.md § 4.7`: a scaffolded stub (absent / byte-identical to baseline / placeholder-only) is populated from extraction; a user-diverged file is left untouched (append a dated line only). Phase 5.3.6 then verifies both files are non-stub.

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
# Helpers used below (`extract_phase_2y_field`, `append_with_section_header`,
# `append_research_stub`) are NOT defined here.
# TODO: extract these helpers to `scripts/_phase-4-helpers.sh` and source at phase entry.
# Currently inlined ad-hoc per agent run — risk of agent improvisation; canonical
# definitions must live in one file before this phase is considered hardened.

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

**Bootstrapped overlays** (initial catalog — extend by saving back via Phase 4.5 generate-missing when an unknown regime is encountered). `[SHIPPED]` files exist on disk; `[PLANNED]` regimes route through the `__REGIME__` research-stub flow in `phase-4-templates.md` until the overlay is authored.

| Regime | File | Status | Domain affinity |
|---|---|---|---|
| GDPR | `regulatory-overlays/gdpr.md` | [SHIPPED] | Universal (any product touching EU users) |
| PCI-DSS | `regulatory-overlays/pci-dss.md` | [SHIPPED] | Payments (universal) |
| SOC2 | `regulatory-overlays/soc2.md` | [SHIPPED] | Universal (any B2B SaaS doing security audits) |
| HIPAA | `regulatory-overlays/hipaa.md` | [SHIPPED] | Healthcare (US) — PHI, Security Rule safeguards, BAAs, de-identification |
| CCPA / CPRA | `regulatory-overlays/ccpa.md` | [PLANNED] | Universal (any product touching California users) |
| ISO-27001 | `regulatory-overlays/iso-27001.md` | [PLANNED] | Universal (any product with formal infosec) |
| NPHIES | `regulatory-overlays/nphies.md` | [PLANNED] | Healthcare (Saudi Arabia) — claims/eligibility integration |
| SCFHS | `regulatory-overlays/scfhs.md` | [PLANNED] | Healthcare (Saudi Arabia) — practitioner registration |
| MOH-SA | `regulatory-overlays/moh-sa.md` | [PLANNED] | Healthcare (Saudi Arabia) — Ministry of Health rules |
| CBAHI | `regulatory-overlays/cbahi.md` | [PLANNED] | Healthcare (Saudi Arabia) — accreditation |
| SAMA | `regulatory-overlays/sama.md` | [PLANNED] | Banking / fintech (Saudi Arabia) |
| CBUAE / SCA | `regulatory-overlays/uae-finance.md` | [PLANNED] | Banking / fintech (UAE) |
| FERPA | `regulatory-overlays/ferpa.md` | [PLANNED] | Education (US) |
| LGPD | `regulatory-overlays/lgpd.md` | [PLANNED] | Universal (any product touching Brazilian users) |
| PDPA | `regulatory-overlays/pdpa.md` | [PLANNED] | Universal (Singapore / Thailand / Malaysia variants) |

**Research stub** (when no prebuilt overlay exists for a declared regime). The literal token `__REGIME__` (double-underscore-bracketed, not angle-brackets) is used so this stub does NOT trigger the Phase 5.3.5 cross-project leak scan, which flags `<…>` style placeholders as "Phase 4.6 produced template-stamp output". `append_research_stub` substitutes the actual regime name on write, leaving zero placeholders behind on disk:

```markdown
