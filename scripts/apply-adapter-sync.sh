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
  [[ -f "$TARGET/AGENTS.override.md" ]]          && detected+=" codex"
  [[ -f "$TARGET/GEMINI.md" ]]                   && detected+=" gemini"
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
  if [[ ! -f "$dst" ]]; then
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    fi
    echo "    ADD       $(rel_to_target "$dst")"
    total_added=$((total_added + 1))
  elif ! cmp -s "$src" "$dst"; then
    # Extract project-specific block from dst BEFORE overwrite (via temp file).
    local block_tmp=""
    block_tmp=$(mktemp)
    extract_project_specific_block "$dst" > "$block_tmp"
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$backup_dir/$(dirname "${dst#$TARGET/}")"
      cp "$dst" "$backup_dir/${dst#$TARGET/}"
      cp "$src" "$dst"
      # Re-inject extracted block (no-op if src already carries one OR block empty).
      reinject_project_specific_block "$dst" "$block_tmp"
    fi
    rm -f "$block_tmp"
    echo "    REFRESH   $(rel_to_target "$dst")"
    total_refreshed=$((total_refreshed + 1))
  else
    total_nooped=$((total_nooped + 1))
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
    sync_file "$f" "$TARGET/.opencode/commands/$(basename "$f")"
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
  # 1:1 markdown copies — commands + skills.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.cursor/commands/$(basename "$f")"
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
    [[ -f "$TARGET/$expected" ]] || [[ -f "$TARGET/.cursor/rules/00-$rule_name.mdc" ]] || \
      [[ -f "$TARGET/.cursor/rules/10-$rule_name.mdc" ]] || [[ -f "$TARGET/.cursor/rules/20-$rule_name.mdc" ]] || \
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
  # Cline workflows = commands. 1:1 markdown copy.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.clinerules/workflows/$(basename "$f")"
  done
  # Rules: cline reads `.clinerules/*.md` flat (no frontmatter required).
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.clinerules/$(basename "$f")"
  done
}

sync_windsurf() {
  echo "  [windsurf]"
  # Windsurf workflows = commands. 1:1.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.windsurf/workflows/$(basename "$f")"
  done
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.windsurf/rules/$(basename "$f")"
  done
}

sync_continue() {
  echo "  [continue]"
  # Continue.dev prompts = commands. 1:1.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.continue/prompts/$(basename "$f")"
  done
  for f in "$TARGET"/.claude/rules/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.continue/rules/$(basename "$f")"
  done
  # config.yaml composite (format conversion).
  [[ -f "$TARGET/.continue/config.yaml" ]] || report_missing_author "config" ".continue/config.yaml" "YAML schema; run /setup-project-adapters"
}

sync_aider() {
  echo "  [aider]"
  # Aider has no native skills/commands/agents — single config + CONVENTIONS.md.
  [[ -f "$TARGET/.aider.conf.yml" ]] || report_missing_author "config" ".aider.conf.yml" "YAML schema; run /setup-project-adapters"
  [[ -f "$TARGET/CONVENTIONS.md" ]]   || report_missing_author "conventions" "CONVENTIONS.md" "compact rules digest; run /setup-project-adapters"
}

sync_codex() {
  echo "  [codex]"
  # Codex consumes AGENTS.md + AGENTS.override.md; both are composites.
  [[ -f "$TARGET/AGENTS.md" ]]          || report_missing_author "agents-md" "AGENTS.md" "cross-tool composite; run /setup-project-adapters"
  [[ -f "$TARGET/AGENTS.override.md" ]] || echo "    (info: AGENTS.override.md is optional; only present if codex-specific rules diverge from AGENTS.md)"
}

sync_gemini() {
  echo "  [gemini]"
  [[ -f "$TARGET/GEMINI.md" ]] || report_missing_author "gemini-md" "GEMINI.md" "single-file composite; run /setup-project-adapters"
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
