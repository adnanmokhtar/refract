#!/usr/bin/env bash
# apply-adapter-sync.sh — multi-tool deterministic adapter synchronizer.
#
# `.claude/` is the source-of-truth artifact tree. This script keeps every
# enabled adapter's NATIVE folder (.opencode/, .cursor/, .github/, …) in
# sync with `.claude/` — the same drop-in-replacement guarantee that lets a
# user close Claude Code, open OpenCode (or Cursor / Copilot), and get the
# SAME feature surface.
#
# This is the missing 4th leg of the deterministic-propagation tripod:
#
#   apply-study-decisions.sh — packs/<track>/<kind>/<name>.md → .claude/<kind>/<name>.md         (Phase 4.2)
#   apply-baseline-sync.sh   — repo-baseline/{ai,/.claude}/   → target ai/ + .claude/             (Phase 4.1)
#   apply-anchors.sh         — `## Project-specific` blocks IN pack-derived artifacts             (Phase 4.6)
#   apply-adapter-sync.sh    — .claude/<kind>/<name>.md → adapter native paths (per adapter.md)   (Phase 4.8)  ← THIS
#
# Why this exists: the agent often translates 1-2 adapters and silently skips
# the rest, leaving users with claude-only setup masquerading as multi-tool.
# This script removes LLM judgment from the deterministic part of adapter
# translation: 1:1 markdown copies + filename-suffix changes. Format
# conversions that need LLM authoring (e.g., adding YAML frontmatter to
# .cursor/rules/*.mdc) are reported as MISSING — `/setup-project-adapters`
# (LLM-driven) finishes those.
#
# Modes:
#   - .claude/<file> exists, adapter native target missing → ADD (cp + suffix)
#   - .claude/<file> exists, adapter native target present + identical → NO-OP
#   - .claude/<file> exists, adapter native present + different → REFRESH (overwrite)
#   - Format-conversion target missing (e.g., .cursor/rules/NN-X.mdc) → MISSING-AUTHOR (report; not handled here)
#
# Adapter detection: an adapter is "enabled" when its native folder OR config
# file exists in target. Selecting adapters explicitly is /setup-project's job.
#
# Usage:
#   apply-adapter-sync.sh <target-repo> [--apply] [--strict] [--adapters=<list>]
#
# Flags:
#   --apply            write changes (without it: dry-run)
#   --strict           exit 1 if any MISSING-AUTHOR row found
#   --adapters=<list>  comma-separated list to force-process (default: auto-detect)
#
# Exit codes:
#   0 — clean (or successful --apply)
#   1 — target missing OR --strict tripped
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--apply] [--strict] [--adapters=<list>]" >&2
  exit 2
fi

TARGET="$1"; shift
APPLY=0
STRICT=0
ADAPTERS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)       APPLY=1; shift ;;
    --strict)      STRICT=1; shift ;;
    --adapters=*)  ADAPTERS="${1#--adapters=}"; shift ;;
    *)             echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }
[[ -d "$TARGET/.claude" ]] || { echo "ERR: $TARGET/.claude/ missing — run /setup-project first" >&2; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
backup_dir="$TARGET/.claude/backups/adapter-sync-$ts"

# ── Adapter detection ──────────────────────────────────────────────────────
# Detect which adapters are enabled in the target.
# Each tool's signature: a folder OR config file unique to that tool.
detect_adapters() {
  local detected=""
  [[ -d "$TARGET/.opencode" ]]                   && detected+=" opencode"
  [[ -d "$TARGET/.cursor"   ]] || [[ -f "$TARGET/.cursorrules" ]]  && detected+=" cursor"
  [[ -d "$TARGET/.github/agents" ]] || [[ -d "$TARGET/.github/prompts" ]] || [[ -f "$TARGET/.github/copilot-instructions.md" ]] && detected+=" copilot"
  [[ -d "$TARGET/.clinerules" ]]                 && detected+=" cline"
  [[ -d "$TARGET/.windsurf"   ]]                 && detected+=" windsurf"
  [[ -d "$TARGET/.continue"   ]]                 && detected+=" continue"
  [[ -f "$TARGET/.aider.conf.yml" ]] || [[ -f "$TARGET/.aiderignore" ]] && detected+=" aider"
  { [[ -d "$TARGET/.agents/skills" ]] || [[ -f "$TARGET/AGENTS.override.md" ]]; } && detected+=" codex"
  [[ -f "$TARGET/GEMINI.md" ]]                   && detected+=" gemini"
  [[ -d "$TARGET/.kimi" ]]                       && detected+=" kimi"
  [[ -d "$TARGET/.qwen" ]]                       && detected+=" qwen"
  echo "$detected" | tr -s ' ' | sed 's/^ //'
}

# Resolve which adapters to process.
if [[ -n "$ADAPTERS" ]]; then
  SELECTED_ADAPTERS=$(echo "$ADAPTERS" | tr ',' ' ')
else
  SELECTED_ADAPTERS=$(detect_adapters)
fi

if [[ -z "$SELECTED_ADAPTERS" ]]; then
  echo "No adapters enabled in $TARGET (and none specified via --adapters=)."
  echo "Nothing to sync. Run /setup-project-adapters to enable adapters."
  exit 0
fi

# ── Counters ───────────────────────────────────────────────────────────────
total_added=0
total_refreshed=0
total_nooped=0
total_missing_author=0

# ── Helpers ────────────────────────────────────────────────────────────────

# Extract a real project-specific block (lines between markers, anchored).
# Matches only when markers appear on their own line — never matches prose
# mentions inside backticks like "the `<!-- project-specific:start -->` block".
# Returns block content (including markers) on stdout; empty if no real block.
extract_project_specific_block() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { in_block=1 }
    in_block { print }
    /^<!-- project-specific:end -->[[:space:]]*$/ && in_block { exit }
  ' "$f"
}

# Strip the adapter-injected EXECUTE NOW preamble (kimi/codex/aider command-skills carry
# it; the .claude source does not). Used so drift comparison reflects REAL body changes,
# not the intentional preamble. Without this, every preamble-carrying file false-flags as
# drifted AND a subsequent --apply cp's the raw source over it, STRIPPING the preamble —
# regressing the exact behaviour the preamble enforces ("execute on load, don't describe").
strip_injected_preamble() {
  # The preamble is bounded by `<!-- EXECUTE NOW preamble ... -->` (open) and
  # `<!-- /EXECUTE NOW preamble -->` (close). Drop everything between them inclusive.
  # Residual blank-line count differences vs the source are tolerated by `diff -B`.
  awk '
    /<!-- EXECUTE NOW preamble/        { inpre=1; next }
    inpre && /<!-- \/EXECUTE NOW preamble -->/ { inpre=0; next }
    inpre                              { next }
    { print }
  ' "$1"
}

# Strip a leading-frontmatter `agent:` line. OpenCode command files carry it as a
# load-bearing field (without it OpenCode describes instead of executes), but the
# `.claude/commands/*.md` source never does — so it must be discounted in drift
# comparison, exactly like the EXECUTE NOW preamble. Reads stdin (chains after
# strip_injected_preamble). Without this, every command with the (correct, contract-
# required) `agent:` field false-flags as drift AND a subsequent --apply cp's the raw
# source over it, STRIPPING the field — regressing the exact execution it enforces.
strip_frontmatter_agent_line() {
  awk '
    NR==1 && /^---[[:space:]]*$/ { fm=1; print; next }
    fm && /^---[[:space:]]*$/    { fm=0; print; next }
    fm && /^agent:[[:space:]]/   { next }
    { print }
  '
}

# Extract the frontmatter `agent:` line (whole line) from a file, if present.
extract_frontmatter_agent_line() {
  awk '
    NR==1 && /^---[[:space:]]*$/ { fm=1; next }
    fm && /^---[[:space:]]*$/    { exit }
    fm && /^agent:[[:space:]]/   { print; exit }
  ' "$1"
}

# Re-inject an `agent:` line into the frontmatter (immediately after the opening ---).
# No-op if the file already carries one (src already had it) or the line is empty.
reinject_frontmatter_agent_line() {
  local f="$1" line="$2"
  [[ -n "$line" ]] || return 0
  [[ -f "$f" ]] || return 0
  grep -q '^agent:' "$f" 2>/dev/null && return 0
  local tmp; tmp=$(mktemp)
  awk -v al="$line" 'NR==1 && /^---[[:space:]]*$/ { print; print al; next } { print }' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# Extract just the injected EXECUTE NOW preamble block (marker comment + contiguous
# blockquote) so a real refresh can re-inject it after the body is overwritten.
extract_injected_preamble() {
  awk '
    /<!-- EXECUTE NOW preamble/        { inpre=1; print; next }
    inpre                              { print }
    inpre && /<!-- \/EXECUTE NOW preamble -->/ { exit }
  ' "$1"
}

# Re-inject a captured EXECUTE NOW preamble after the frontmatter, before the body.
# No-op if the file already carries one (src may already include it) or block is empty.
reinject_injected_preamble() {
  local f="$1" pre_file="$2"
  [[ -s "$pre_file" ]] || return 0
  [[ -f "$f" ]] || return 0
  grep -q "<!-- EXECUTE NOW preamble" "$f" 2>/dev/null && return 0
  local tmp; tmp=$(mktemp)
  awk -v pf="$pre_file" '
    function emit(   line) { print ""; while ((getline line < pf) > 0) print line; close(pf) }
    BEGIN { state="start"; done=0 }
    NR==1 && /^---[[:space:]]*$/        { state="fm"; print; next }
    state=="fm" && /^---[[:space:]]*$/  { state="body"; print; emit(); done=1; next }
    state=="fm"                          { print; next }
    state=="start"                       { emit(); done=1; state="body"; print; next }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# Re-inject a project-specific block into a file at the canonical insertion
# point: after frontmatter (if any), after first H1, before first H2.
# If the file already has a real block (e.g. caller used a fresh src that
# already carries one), this is a no-op to avoid double-injection.
# Block is passed via temp file (awk -v cannot accept newlines in values).
reinject_project_specific_block() {
  local f="$1" block_file="$2"
  [[ -f "$block_file" ]] || return 0
  [[ -s "$block_file" ]] || return 0
  [[ -f "$f" ]] || return 0
  # Skip if the destination already carries a real (anchored) block.
  if grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$f" 2>/dev/null; then
    return 0
  fi
  local tmp; tmp=$(mktemp)
  awk -v bf="$block_file" '
    function emit_block(   line) {
      print ""
      while ((getline line < bf) > 0) print line
      close(bf)
      print ""
    }
    BEGIN { state="start"; injected=0 }
    NR == 1 && /^---[[:space:]]*$/ { state="fm"; print; next }
    state == "fm" && /^---[[:space:]]*$/ { state="body"; print; next }
    state == "body" && /^# / && !h1 { h1=1; print; next }
    state == "body" && /^## / && !injected { emit_block(); injected=1 }
    state == "start" && /^# / && !h1 { h1=1; state="body"; print; next }
    state == "start" && /^## / && !injected { emit_block(); injected=1 }
    { print }
    END { if (!injected) emit_block() }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# Copy src → dst with backup of overwritten file.
# **Preserves project-specific blocks** in dst (added 2026-05): if dst has a
# real `<!-- project-specific:start --> ... <!-- project-specific:end -->`
# block (anchored on its own line), the block is extracted before overwrite
# and re-injected into the freshly-copied src content. Single chokepoint
# that protects per-tool blocks across ALL adapters (.cursor/, .opencode/,
# .qwen/, .kimi/, .github/, .clinerules/, .windsurf/, .continue/, etc.).
sync_file() {
  local src="$1" dst="$2"
  # OpenCode command targets carry an intentional, contract-required `agent:`
  # frontmatter field that the .claude source lacks — discount + preserve it
  # (same treatment as the EXECUTE NOW preamble) so it is neither false-flagged
  # as drift nor stripped on --apply.
  local oc_cmd=0
  [[ "$dst" == *"/.opencode/commands/"* ]] && oc_cmd=1
  if [[ ! -f "$dst" ]]; then
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
    echo "    ADD       $(rel_to_target "$dst")"
    total_added=$((total_added + 1))
  elif diff -q -B <(if [[ $oc_cmd -eq 1 ]]; then strip_injected_preamble "$dst" | strip_frontmatter_agent_line; else strip_injected_preamble "$dst"; fi) "$src" >/dev/null 2>&1; then
    # Bodies match once the injected EXECUTE NOW preamble (and, for OpenCode commands,
    # the load-bearing `agent:` field) plus blank-line noise is discounted — the dst
    # differs ONLY by intentional, contract-required additions. Not real drift.
    total_nooped=$((total_nooped + 1))
  else
    # Real body drift. Extract the project-specific block, any injected preamble, AND
    # (for OpenCode commands) the agent: field from dst BEFORE overwrite, then re-inject
    # after copying the fresh source — so a legitimate refresh never strips them.
    local block_tmp pre_tmp agent_line=""
    block_tmp=$(mktemp); pre_tmp=$(mktemp)
    extract_project_specific_block "$dst" > "$block_tmp"
    extract_injected_preamble "$dst" > "$pre_tmp"
    [[ $oc_cmd -eq 1 ]] && agent_line=$(extract_frontmatter_agent_line "$dst")
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$backup_dir/$(dirname "${dst#$TARGET/}")"
      cp "$dst" "$backup_dir/${dst#$TARGET/}"
      cp "$src" "$dst"
      # Re-inject extracted block + preamble + agent field (each a no-op if src already carries one OR empty).
      reinject_project_specific_block "$dst" "$block_tmp"
      reinject_injected_preamble "$dst" "$pre_tmp"
      [[ $oc_cmd -eq 1 ]] && reinject_frontmatter_agent_line "$dst" "$agent_line"
    fi
    rm -f "$block_tmp" "$pre_tmp"
    echo "    REFRESH   $(rel_to_target "$dst")"
    total_refreshed=$((total_refreshed + 1))
  fi
}

rel_to_target() { echo "${1#$TARGET/}"; }

# Report a target as needing format-conversion (LLM authoring required).
report_missing_author() {
  local kind="$1" expected_path="$2" reason="$3"
  echo "    MISSING-AUTHOR $expected_path  ($reason)"
  total_missing_author=$((total_missing_author + 1))
}

# ── Per-adapter sync recipes ───────────────────────────────────────────────

# OpenCode agent frontmatter requires `tools:` as a YAML record
# (`tools:\n  bash: true\n  read: true`), but Claude Code accepts the
# comma-separated string form (`tools: Bash, Read, Grep, Glob`). When a
# project's `.claude/agents/<name>.md` was customized with the Claude form,
# a 1:1 copy into `.opencode/agents/` fails OpenCode's schema with
# "expected record, received string tools" and refuses to load.
#
# This helper rewrites the frontmatter of a destination .opencode agent file
# in-place, converting only string-form `tools:` lines to record form.
# Record-form `tools:` lines (followed by indented children) are left intact.
# Operates on the body BEFORE the second `---` only — never touches markdown.
opencode_normalize_agent_tools() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  # Detect string-form: `tools: Foo, Bar` on a single line. Skip if not present.
  awk 'BEGIN{fm=0} /^---[[:space:]]*$/{fm++; next} fm==1 && /^tools:[[:space:]]*[A-Za-z]/{found=1; exit} fm>=2{exit} END{exit !found}' "$f" || return 0
  local tmp; tmp=$(mktemp)
  awk '
    BEGIN { fm=0 }
    /^---[[:space:]]*$/ { fm++; print; next }
    fm==1 && /^tools:[[:space:]]*[A-Za-z]/ {
      val=$0; sub(/^tools:[[:space:]]*/, "", val)
      n=split(val, parts, /[[:space:]]*,[[:space:]]*/)
      print "tools:"
      for (i=1; i<=n; i++) {
        t=parts[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        if (t=="") continue
        # lowercase
        lc=""; for (j=1; j<=length(t); j++) { c=substr(t,j,1); lc=lc tolower(c) }
        print "  " lc ": true"
      }
      next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

sync_opencode() {
  echo "  [opencode]"
  # 1:1 markdown copies — agents, commands, skills (folder-form).
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    local dst="$TARGET/.opencode/agents/$(basename "$f")"
    sync_file "$f" "$dst"
    [[ $APPLY -eq 1 ]] && opencode_normalize_agent_tools "$dst"
  done
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    local cdst="$TARGET/.opencode/commands/$(basename "$f")"
    sync_file "$f" "$cdst"
    # `agent:` frontmatter is load-bearing — without it OpenCode describes instead of executes.
    if [[ -f "$cdst" ]] && ! grep -q "^agent:" "$cdst"; then
      report_missing_author "opencode-agent-field" ".opencode/commands/$(basename "$f")" "add 'agent: build' (or 'agent: plan' for audit/plan commands) frontmatter — run /setup-project-adapters"
    fi
  done
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      sync_file "$skill_dir/SKILL.md" "$TARGET/.opencode/skills/$skill_name/SKILL.md"
    fi
  done
  # Flat-skills variant (some packs ship skills/<name>.md)
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    skill_name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.opencode/skills/$skill_name/SKILL.md"
  done
  # opencode.json + AGENTS.md require composition (LLM-authored).
  [[ -f "$TARGET/opencode.json" ]] || report_missing_author "config" "opencode.json" "schema-valid JSON config; run /setup-project-adapters"
  [[ -f "$TARGET/AGENTS.md"      ]] || report_missing_author "agents-md" "AGENTS.md" "cross-tool composite; run /setup-project-adapters"
}

sync_cursor() {
  echo "  [cursor]"
  # Commands are skills-first: PRIMARY = .cursor/skills/<name>/SKILL.md (LLM-authored — needs a
  # `name:` field the source command lacks); fallback = .cursor/commands/<name>.md (1:1 mirror,
  # still works, on Cursor's slash-command→Skills deprecation path).
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.cursor/commands/$name.md"
    [[ -f "$TARGET/.cursor/skills/$name/SKILL.md" ]] || report_missing_author "cursor-command-skill" ".cursor/skills/$name/SKILL.md" "command→native Skill (PRIMARY) with name/description frontmatter — run /setup-project-adapters"
  done
  # Agents → cursor commands (Cursor has no agent dispatch; agent-<name>.md prefix).
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.cursor/commands/agent-$(basename "$f")"
  done
  # Skills (folder-form).
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      sync_file "$skill_dir/SKILL.md" "$TARGET/.cursor/skills/$skill_name/SKILL.md"
    fi
  done
  # Flat skills.
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    skill_name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.cursor/skills/$skill_name/SKILL.md"
  done
  # Rules → .mdc with YAML frontmatter (format conversion — LLM required).
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    rule_name=$(basename "$f" .md)
    expected=".cursor/rules/30-$rule_name.mdc"
    # Accept the bare `<name>.mdc` form too — Cursor loads any `*.mdc` regardless of an
    # `NN-` ordering prefix, and the generator emits bare names. (audit-adapter-coverage.sh
    # already accepts bare; this aligns apply-adapter-sync.sh with it so a correctly-generated
    # rule isn't false-flagged MISSING-AUTHOR.)
    [[ -f "$TARGET/.cursor/rules/$rule_name.mdc" ]] || [[ -f "$TARGET/$expected" ]] || \
      [[ -f "$TARGET/.cursor/rules/00-$rule_name.mdc" ]] || [[ -f "$TARGET/.cursor/rules/10-$rule_name.mdc" ]] || \
      [[ -f "$TARGET/.cursor/rules/20-$rule_name.mdc" ]] || \
      report_missing_author "rule.mdc" "$expected" ".mdc with YAML frontmatter (globs/applyTo) — needs author"
  done
  # hooks.json (format conversion).
  [[ -f "$TARGET/.cursor/hooks.json" ]] || report_missing_author "hooks.json" ".cursor/hooks.json" "JSON shape; run /setup-project-adapters"
}

sync_copilot() {
  echo "  [copilot]"
  # 1:1 with filename-suffix change.
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.github/agents/$name.agent.md"
  done
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.github/prompts/$name.prompt.md"
  done
  # Skills folder-form.
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      sync_file "$skill_dir/SKILL.md" "$TARGET/.github/skills/$skill_name/SKILL.md"
    fi
  done
  # Flat skills.
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    skill_name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.github/skills/$skill_name/SKILL.md"
  done
  # Repo-wide instructions composite.
  [[ -f "$TARGET/.github/copilot-instructions.md" ]] || report_missing_author "instructions" ".github/copilot-instructions.md" "composite from CLAUDE.md + rules; run /setup-project-adapters"
  # Path-scoped instructions.
  [[ -d "$TARGET/.github/instructions" ]] || report_missing_author "instructions-dir" ".github/instructions/" "per-domain instructions w/ applyTo glob; run /setup-project-adapters"
}

sync_cline() {
  echo "  [cline]"
  # Cline workflows = commands. 1:1 markdown copy (no frontmatter conversion needed).
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.clinerules/workflows/$(basename "$f")"
  done
  # Rules → .clinerules/<NN>-<domain>.md — numeric load-order prefix ({10..79}); LLM assigns the
  # domain number, so flag (don't raw-copy to a non-prefixed name that fails the coverage glob).
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    rule_name=$(basename "$f" .md)
    find "$TARGET/.clinerules" -maxdepth 1 -name "[1-7][0-9]-$rule_name.md" 2>/dev/null | grep -q . || \
      report_missing_author "cline-rule" ".clinerules/<NN>-$rule_name.md" "rule needs numeric <NN>- load-order prefix ({10..79}) — run /setup-project-adapters"
  done
  # Composite + index files (LLM-authored).
  [[ -f "$TARGET/.clinerules/00-project.md" ]] || report_missing_author "cline-project" ".clinerules/00-project.md" "always-loaded project rules + driver-gap disclosure — run /setup-project-adapters"
  [[ -f "$TARGET/.clinerules/81-agents.md" ]]  || report_missing_author "cline-agents-index" ".clinerules/81-agents.md" "agent persona index (every agent) — run /setup-project-adapters"
  [[ -f "$TARGET/.clinerules/82-skills.md" ]]  || report_missing_author "cline-skills-index" ".clinerules/82-skills.md" "skill procedure index (every skill) — run /setup-project-adapters"
}

sync_windsurf() {
  echo "  [windsurf]"
  # Windsurf workflows = commands. 1:1 markdown copy.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.windsurf/workflows/$(basename "$f")"
  done
  # Rules → .windsurf/rules/<NN>-<domain>.md WITH activation-mode frontmatter (format conversion —
  # LLM required; raw copy would lack activation_mode and the <NN>- prefix the coverage glob needs).
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    rule_name=$(basename "$f" .md)
    find "$TARGET/.windsurf/rules" -maxdepth 1 -name "[1-7][0-9]-$rule_name.md" 2>/dev/null | grep -q . || \
      report_missing_author "windsurf-rule" ".windsurf/rules/<NN>-$rule_name.md" "rule needs <NN>- prefix + activation_mode frontmatter (always/glob/trigger_words) — run /setup-project-adapters"
  done
  # Composite + index files (LLM-authored).
  [[ -f "$TARGET/.windsurf/rules/00-project.md" ]] || report_missing_author "windsurf-project" ".windsurf/rules/00-project.md" "activation_mode: always project rules — run /setup-project-adapters"
  [[ -f "$TARGET/.windsurf/rules/81-agents.md" ]]  || report_missing_author "windsurf-agents-index" ".windsurf/rules/81-agents.md" "agent index (trigger_words activation) — run /setup-project-adapters"
  [[ -f "$TARGET/.windsurf/rules/82-skills.md" ]]  || report_missing_author "windsurf-skills-index" ".windsurf/rules/82-skills.md" "skill index — run /setup-project-adapters"
}

sync_continue() {
  echo "  [continue]"
  # Command prompts → .continue/prompts/<name>.md WITH `invokable: true` + name/description
  # frontmatter (format conversion — raw copy lacks the frontmatter Continue needs to invoke it).
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    local ctgt=""
    [[ -f "$TARGET/.continue/prompts/$name.md" ]] && ctgt="$TARGET/.continue/prompts/$name.md"
    [[ -z "$ctgt" && -f "$TARGET/.continue/prompts/$name.prompt.md" ]] && ctgt="$TARGET/.continue/prompts/$name.prompt.md"
    if [[ -n "$ctgt" ]]; then
      grep -q "invokable:" "$ctgt" || report_missing_author "continue-prompt-frontmatter" ".continue/prompts/$name.md" "add 'invokable: true' + name/description frontmatter — run /setup-project-adapters"
    else
      report_missing_author "continue-prompt" ".continue/prompts/$name.md" "command→prompt with 'invokable: true' frontmatter — run /setup-project-adapters"
    fi
  done
  # Agents → agent-<name>.md prompts (LLM-authored).
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    [[ -f "$TARGET/.continue/prompts/agent-$name.md" ]] || report_missing_author "continue-agent-prompt" ".continue/prompts/agent-$name.md" "agent→prompt — run /setup-project-adapters"
  done
  # Skills → skill-<name>.md prompts (LLM-authored).
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "$skill_dir")
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    [[ -f "$TARGET/.continue/prompts/skill-$name.md" ]] || report_missing_author "continue-skill-prompt" ".continue/prompts/skill-$name.md" "skill→prompt — run /setup-project-adapters"
  done
  # Rules → .continue/rules/<name>.md WITH required `name:` frontmatter (silently ignored without it).
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    rule_name=$(basename "$f" .md)
    if [[ -f "$TARGET/.continue/rules/$rule_name.md" ]]; then
      grep -q "^name:" "$TARGET/.continue/rules/$rule_name.md" || report_missing_author "continue-rule-frontmatter" ".continue/rules/$rule_name.md" "rule needs 'name:' frontmatter (silently ignored without it) — run /setup-project-adapters"
    else
      report_missing_author "continue-rule" ".continue/rules/$rule_name.md" "rule→.continue/rules with 'name:' frontmatter — run /setup-project-adapters"
    fi
  done
  # config.yaml + .continueignore composites (LLM-authored).
  [[ -f "$TARGET/.continue/config.yaml" ]] || report_missing_author "config" ".continue/config.yaml" "YAML schema (models/rules/docs); run /setup-project-adapters"
  [[ -f "$TARGET/.continueignore" ]]       || report_missing_author "continueignore" ".continueignore" "sensitive-file fallback (.env*, *.lock, migrations dirs) — run /setup-project-adapters"
}

sync_aider() {
  echo "  [aider]"
  # Aider has no native skills/commands/agents — single config + CONVENTIONS.md.
  [[ -f "$TARGET/.aider.conf.yml" ]] || report_missing_author "config" ".aider.conf.yml" "YAML schema; run /setup-project-adapters"
  [[ -f "$TARGET/CONVENTIONS.md" ]]   || report_missing_author "conventions" "CONVENTIONS.md" "compact rules digest; run /setup-project-adapters"
  # Command sections fold into CONVENTIONS.md under `## User-invoked procedures`, EACH with an
  # EXECUTE NOW imperative preamble — without it "run optimize" gets described, not executed.
  if [[ -f "$TARGET/CONVENTIONS.md" ]] && ls "$TARGET"/.claude/commands/*.md >/dev/null 2>&1; then
    grep -q "## User-invoked procedures" "$TARGET/CONVENTIONS.md" || report_missing_author "aider-procedures" "CONVENTIONS.md" "add '## User-invoked procedures' section — run /setup-project-adapters"
    grep -q "EXECUTE NOW" "$TARGET/CONVENTIONS.md" || report_missing_author "aider-preamble" "CONVENTIONS.md" "command sections need EXECUTE NOW imperative preamble — run /setup-project-adapters"
  fi
}

sync_codex() {
  echo "  [codex]"
  # Codex consumes AGENTS.md + AGENTS.override.md; both are composites.
  [[ -f "$TARGET/AGENTS.md" ]]          || report_missing_author "agents-md" "AGENTS.md" "cross-tool composite; run /setup-project-adapters"
  [[ -f "$TARGET/AGENTS.override.md" ]] || echo "    (info: AGENTS.override.md is optional; only present if codex-specific rules diverge from AGENTS.md)"
  # Commands + skills translate to NATIVE Agent Skills (primary surface); AGENTS.md prose is fallback.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    [[ -f "$TARGET/.agents/skills/$name/SKILL.md" ]] || report_missing_author "codex-agent-skill" ".agents/skills/$name/SKILL.md" "command→native Agent Skill with EXECUTE NOW body — run /setup-project-adapters"
  done
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "$skill_dir")
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    [[ -f "$TARGET/.agents/skills/$name/SKILL.md" ]] || report_missing_author "codex-agent-skill" ".agents/skills/$name/SKILL.md" "skill→native Agent Skill — run /setup-project-adapters"
  done
}

sync_gemini() {
  echo "  [gemini]"
  [[ -f "$TARGET/GEMINI.md" ]] || report_missing_author "gemini-md" "GEMINI.md" "single-file composite; run /setup-project-adapters"
  # Commands translate to NATIVE TOML custom commands (primary surface); GEMINI.md prose is fallback.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    [[ -f "$TARGET/.gemini/commands/$name.toml" ]] || report_missing_author "gemini-toml-command" ".gemini/commands/$name.toml" "command→native TOML (prompt=\"\"\"# EXECUTE NOW ... {{args}}\"\"\") — run /setup-project-adapters"
  done
}

sync_kimi() {
  echo "  [kimi]"
  # Commands are DUAL-SURFACE: each command → BOTH a skill (so /skill:<name> works) AND a
  # subagent (so description-dispatch works), EACH carrying the EXECUTE NOW preamble so the
  # body EXECUTES instead of loading as reference. See templates/tool-adapters/kimi/adapter.md.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    # Name collision: a skill of the same name owns the .kimi/skills/<name>/ surface (the skill
    # loops below write it from the skill source). The command is still covered by its subagent.
    # Writing the skill here too would double-write the same path and perpetually false-flag drift
    # (the on-disk file can only match ONE of the two sources). Skip the skill write; keep the
    # subagent obligation.
    if [[ -f "$TARGET/.claude/skills/$name.md" || -f "$TARGET/.claude/skills/$name/SKILL.md" ]]; then
      [[ -f "$TARGET/.kimi/subagents/$name.yaml" ]] || report_missing_author "subagent.yaml" ".kimi/subagents/$name.yaml" "command→subagent (dual-surface, name collides with a skill) — run /setup-project-adapters"
      continue
    fi
    sync_file "$f" "$TARGET/.kimi/skills/$name/SKILL.md"
    # Command-skill must carry the EXECUTE NOW preamble (loaded text must be imperative).
    if [[ -f "$TARGET/.kimi/skills/$name/SKILL.md" ]] && ! grep -q "EXECUTE NOW" "$TARGET/.kimi/skills/$name/SKILL.md"; then
      report_missing_author "kimi-skill-preamble" ".kimi/skills/$name/SKILL.md" "inject EXECUTE NOW preamble at top of command-skill — run /setup-project-adapters"
    fi
    # Command also gets a subagent (description-dispatch surface) — LLM-authored YAML + preamble + tools whitelist.
    [[ -f "$TARGET/.kimi/subagents/$name.yaml" ]] || report_missing_author "subagent.yaml" ".kimi/subagents/$name.yaml" "command→subagent (dual-surface) with EXECUTE NOW preamble + tools whitelist by command type — run /setup-project-adapters"
  done
  # Skills (folder-form).
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      sync_file "$skill_dir/SKILL.md" "$TARGET/.kimi/skills/$skill_name/SKILL.md"
    fi
  done
  # Flat skills.
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    skill_name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.kimi/skills/$skill_name/SKILL.md"
  done
  # Agents → subagents (format conversion .md → .yaml — LLM-authored).
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    [[ -f "$TARGET/.kimi/subagents/$name.yaml" ]] || report_missing_author "subagent.yaml" ".kimi/subagents/$name.yaml" "YAML frontmatter conversion from .claude/agents/ — run /setup-project-adapters"
  done
  # Rules → AGENTS.md (composite — LLM-authored).
  [[ -f "$TARGET/AGENTS.md" ]] || report_missing_author "agents-md" "AGENTS.md" "cross-tool composite; run /setup-project-adapters"
}

sync_qwen() {
  echo "  [qwen]"
  # 1:1 markdown copies — commands, agents, skills (folder-form).
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.qwen/commands/$(basename "$f")"
  done
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.qwen/agents/$(basename "$f")"
  done
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      sync_file "$skill_dir/SKILL.md" "$TARGET/.qwen/skills/$skill_name/SKILL.md"
    fi
  done
  # Flat skills.
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    skill_name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.qwen/skills/$skill_name/SKILL.md"
  done
  # Rules → QWEN.md (composite — LLM-authored).
  [[ -f "$TARGET/QWEN.md" ]] || report_missing_author "qwen-md" "QWEN.md" "cross-tool composite; run /setup-project-adapters"
  # Hooks → settings.json (format conversion — LLM-authored).
  [[ -f "$TARGET/.qwen/settings.json" ]] || report_missing_author "settings.json" ".qwen/settings.json" "JSON shape; run /setup-project-adapters"
}

# ── Main loop ──────────────────────────────────────────────────────────────

echo "=== apply-adapter-sync ==="
echo "Target:           $TARGET"
echo "Mode:             $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Selected adapters: $SELECTED_ADAPTERS"
echo ""

for adapter in $SELECTED_ADAPTERS; do
  case "$adapter" in
    opencode) sync_opencode ;;
    cursor)   sync_cursor   ;;
    copilot)  sync_copilot  ;;
    cline)    sync_cline    ;;
    windsurf) sync_windsurf ;;
    continue) sync_continue ;;
    aider)    sync_aider    ;;
    codex)    sync_codex    ;;
    gemini)   sync_gemini   ;;
    kimi)     sync_kimi     ;;
    qwen)     sync_qwen     ;;
    claude-code) ;; # Source of truth; no sync needed
    *) echo "  [unknown adapter: $adapter — skipping]" ;;
  esac
done

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "=== summary ==="
echo "ADD:                  $total_added"
echo "REFRESH (overwrite):  $total_refreshed"
echo "NO-OP:                $total_nooped"
echo "MISSING-AUTHOR:       $total_missing_author  (need /setup-project-adapters for format conversions)"

if [[ $APPLY -eq 1 && ($total_added -gt 0 || $total_refreshed -gt 0) ]]; then
  echo ""
  echo "Backups: $backup_dir/"
fi

if [[ $APPLY -eq 0 ]]; then
  echo ""
  echo "Dry run — pass --apply to execute."
fi

if [[ $STRICT -eq 1 && $total_missing_author -gt 0 ]]; then
  echo ""
  echo "REFUSED — --strict + $total_missing_author MISSING-AUTHOR row(s)." >&2
  exit 1
fi

exit 0
