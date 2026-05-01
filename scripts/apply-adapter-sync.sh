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
# Copy src → dst with backup of overwritten file.
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
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$backup_dir/$(dirname "${dst#$TARGET/}")"
      cp "$dst" "$backup_dir/${dst#$TARGET/}"
      cp "$src" "$dst"
    fi
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

sync_opencode() {
  echo "  [opencode]"
  # 1:1 markdown copies — agents, commands, skills (folder-form).
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    sync_file "$f" "$TARGET/.opencode/agents/$(basename "$f")"
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
