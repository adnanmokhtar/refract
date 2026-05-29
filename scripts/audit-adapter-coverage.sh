#!/usr/bin/env bash
# audit-adapter-coverage.sh — verify per-adapter translation coverage in a target.
#
# After /setup-project --refresh runs and chains into /setup-project-adapters
# (per M34a hard contract), this script audits the result. For each adapter
# the project enabled (detected by folder presence), it counts how many of
# the .claude/<kind>/<name>.md sources have a corresponding native file in
# the adapter's expected layout.
#
# Output:
#   <target>/.claude/_adapter-coverage-audit.md
# Stdout summary.
#
# Coverage thresholds:
#   ≥95%   ok
#   ≥80%   warn (some artifacts didn't translate)
#   <80%   err  (significant drift — adapter is stale)
#
# Usage:
#   audit-adapter-coverage.sh <target> [--strict]
#
# Exit codes:
#   0 — clean (or warn-only)
#   1 — --strict + at least one adapter under threshold
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--strict]" >&2
  exit 2
fi

TARGET="$1"; shift
STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    *) shift ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 2; }

REPORT="$TARGET/.claude/_adapter-coverage-audit.md"
mkdir -p "$(dirname "$REPORT")"

# Count source artifacts in .claude/
count_source_kind() {
  local kind="$1"
  find "$TARGET/.claude/$kind" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null \
    | wc -l | tr -d ' '
}
SRC_COMMANDS=$(count_source_kind commands)
SRC_AGENTS=$(count_source_kind agents)
SRC_SKILLS=$(count_source_kind skills)
SRC_RULES=$(count_source_kind rules)

# List basenames (without .md) per kind
list_basenames_kind() {
  local kind="$1"
  find "$TARGET/.claude/$kind" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null \
    | xargs -I {} basename {} .md 2>/dev/null | sort
}

# Per-adapter coverage check
declare -a SUMMARY_ROWS  # one line per adapter: "verdict|adapter|details"

# ---------- cursor ----------
audit_cursor() {
  [[ -d "$TARGET/.cursor" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS + SRC_RULES))
  while IFS= read -r b; do
    # Skills-first: command's primary surface is .cursor/skills/<name>/SKILL.md; .cursor/commands/ is the fallback.
    [[ -f "$TARGET/.cursor/skills/$b/SKILL.md" || -f "$TARGET/.cursor/commands/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.cursor/commands/agent-$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  while IFS= read -r b; do
    [[ -f "$TARGET/.cursor/skills/$b/SKILL.md" || -f "$TARGET/.cursor/skills/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  while IFS= read -r b; do
    [[ -f "$TARGET/.cursor/rules/$b.mdc" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind rules)
  echo "$hits|$expected"
}

# ---------- opencode ----------
audit_opencode() {
  [[ -d "$TARGET/.opencode" || -f "$TARGET/opencode.json" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS))
  while IFS= read -r b; do
    [[ -f "$TARGET/.opencode/commands/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.opencode/agents/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  while IFS= read -r b; do
    [[ -f "$TARGET/.opencode/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  echo "$hits|$expected"
}

# ---------- copilot ----------
audit_copilot() {
  [[ -d "$TARGET/.github/prompts" || -d "$TARGET/.github/agents" || -d "$TARGET/.github/instructions" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS + SRC_RULES))
  while IFS= read -r b; do
    [[ -f "$TARGET/.github/prompts/$b.prompt.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.github/agents/$b.agent.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  while IFS= read -r b; do
    [[ -f "$TARGET/.github/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  while IFS= read -r b; do
    [[ -f "$TARGET/.github/instructions/$b.instructions.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind rules)
  echo "$hits|$expected"
}

# ---------- cline ----------
audit_cline() {
  [[ -d "$TARGET/.clinerules" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_RULES))
  while IFS= read -r b; do
    [[ -f "$TARGET/.clinerules/workflows/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    # Cline uses NN-name.md naming; check by suffix match
    if find "$TARGET/.clinerules" -maxdepth 1 -name "*-$b.md" 2>/dev/null | grep -q .; then
      hits=$((hits + 1))
    fi
  done < <(list_basenames_kind rules)
  echo "$hits|$expected"
}

# ---------- windsurf ----------
audit_windsurf() {
  [[ -d "$TARGET/.windsurf" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_RULES))
  while IFS= read -r b; do
    [[ -f "$TARGET/.windsurf/workflows/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    if find "$TARGET/.windsurf/rules" -maxdepth 1 -name "*-$b.md" 2>/dev/null | grep -q .; then
      hits=$((hits + 1))
    fi
  done < <(list_basenames_kind rules)
  echo "$hits|$expected"
}

# ---------- continue ----------
audit_continue() {
  [[ -d "$TARGET/.continue" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_RULES))
  while IFS= read -r b; do
    [[ -f "$TARGET/.continue/prompts/$b.prompt.md" || -f "$TARGET/.continue/prompts/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.continue/rules/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind rules)
  echo "$hits|$expected"
}

# ---------- single-doc adapter: aider (genuinely rule-only) ----------
audit_singledoc() {
  local file="$1" name="$2"
  [[ -f "$TARGET/$file" ]] || return 1
  local lines hits=0 expected=4  # presence of major sections
  lines=$(wc -l < "$TARGET/$file" | tr -d ' ')
  if [[ $lines -ge 100 ]]; then hits=$((hits + 1)); fi
  if grep -qE '^##.*[Cc]ommand|^##.*[Pp]rocedure' "$TARGET/$file"; then hits=$((hits + 1)); fi
  if grep -qE '^##.*[Aa]gent|##.*[Pp]ersona' "$TARGET/$file"; then hits=$((hits + 1)); fi
  if grep -qE '^##.*[Ss]kill|##.*[Pp]rocedure' "$TARGET/$file"; then hits=$((hits + 1)); fi
  echo "$hits|$expected"
}
audit_aider()  { audit_singledoc "CONVENTIONS.md" "aider"; }

# ---------- codex: native Agent Skills (primary) + AGENTS.md (fallback) ----------
audit_codex() {
  [[ -f "$TARGET/AGENTS.md" ]] || return 1
  # AGENTS.md is ALWAYS written (the codex adapter is the canonical AGENTS.md writer and runs
  # even when codex is NOT a selected tool, because 8+ other tools fall back to AGENTS.md).
  # Only grade the full native Agent-Skills surface when codex was actually selected as a full
  # adapter — i.e. its native .agents/skills/ dir exists. Otherwise grade only the AGENTS.md
  # anchor (codex's sole always-on deliverable) so an unselected codex isn't scored ~1%.
  if [[ ! -d "$TARGET/.agents/skills" ]]; then
    echo "1|1"
    return
  fi
  local hits=0 expected=$((SRC_COMMANDS + SRC_SKILLS + 1))
  hits=$((hits + 1))  # AGENTS.md present (checked above)
  while IFS= read -r b; do
    [[ -f "$TARGET/.agents/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.agents/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  echo "$hits|$expected"
}

# ---------- gemini: native TOML commands (primary) + GEMINI.md (fallback) ----------
audit_gemini() {
  [[ -f "$TARGET/GEMINI.md" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + 1))
  hits=$((hits + 1))  # GEMINI.md present (checked above)
  while IFS= read -r b; do
    [[ -f "$TARGET/.gemini/commands/$b.toml" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  echo "$hits|$expected"
}

# ---------- kimi: commands dual-surface (skill + subagent); skills→skill; agents→subagent ----------
audit_kimi() {
  [[ -d "$TARGET/.kimi" ]] || return 1
  local hits=0 expected=$(((SRC_COMMANDS * 2) + SRC_SKILLS + SRC_AGENTS))
  while IFS= read -r b; do
    [[ -f "$TARGET/.kimi/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
    [[ -f "$TARGET/.kimi/subagents/$b.yaml" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.kimi/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  while IFS= read -r b; do
    [[ -f "$TARGET/.kimi/subagents/$b.yaml" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  echo "$hits|$expected"
}

# ---------- qwen: native 1:1 commands + agents + skills ----------
audit_qwen() {
  [[ -d "$TARGET/.qwen" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS))
  while IFS= read -r b; do
    [[ -f "$TARGET/.qwen/commands/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.qwen/agents/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  while IFS= read -r b; do
    [[ -f "$TARGET/.qwen/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  echo "$hits|$expected"
}

# Run all adapters; record verdicts
verdict_for() {
  local hits="$1" expected="$2"
  if [[ $expected -eq 0 ]]; then echo "skip"; return; fi
  local pct=$((hits * 100 / expected))
  if   [[ $pct -ge 95 ]]; then echo "ok|$pct"
  elif [[ $pct -ge 80 ]]; then echo "warn|$pct"
  else echo "err|$pct"
  fi
}

# Tracks fail count for --strict
fails=0
warns=0

run_one() {
  local name="$1" fn="$2"
  local result
  if ! result=$($fn 2>/dev/null); then
    return  # adapter not present
  fi
  local hits expected
  IFS='|' read -r hits expected <<<"$result"
  local v
  v=$(verdict_for "$hits" "$expected")
  local kind pct
  IFS='|' read -r kind pct <<<"$v"
  case "$kind" in
    ok)   SUMMARY_ROWS+=("ok|$name|$hits/$expected ($pct%)") ;;
    warn) SUMMARY_ROWS+=("warn|$name|$hits/$expected ($pct%)"); warns=$((warns + 1)) ;;
    err)  SUMMARY_ROWS+=("err|$name|$hits/$expected ($pct%)"); fails=$((fails + 1)) ;;
    skip) SUMMARY_ROWS+=("skip|$name|no source artifacts") ;;
  esac
}

run_one cursor    audit_cursor
run_one opencode  audit_opencode
run_one copilot   audit_copilot
run_one cline     audit_cline
run_one windsurf  audit_windsurf
run_one continue  audit_continue
run_one aider     audit_aider
run_one codex     audit_codex
run_one gemini    audit_gemini
run_one kimi      audit_kimi
run_one qwen      audit_qwen

# ---------- report ----------
{
  printf '# Adapter coverage audit — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Generated by: scripts/audit-adapter-coverage.sh\n\n'
  printf 'Source artifacts in `.claude/`:\n'
  printf -- '- commands: **%d**\n' "$SRC_COMMANDS"
  printf -- '- agents:   **%d**\n' "$SRC_AGENTS"
  printf -- '- skills:   **%d**\n' "$SRC_SKILLS"
  printf -- '- rules:    **%d**\n\n' "$SRC_RULES"
  printf -- '---\n\n## Per-adapter coverage\n\n'
  if [[ ${#SUMMARY_ROWS[@]} -eq 0 ]]; then
    printf '_No adapter native files detected. Run `/setup-project-adapters` to translate._\n'
  else
    printf '| Verdict | Adapter | Coverage |\n|---|---|---|\n'
    for row in "${SUMMARY_ROWS[@]}"; do
      IFS='|' read -r v name detail <<<"$row"
      case "$v" in
        ok)   printf '| ✅ ok | `%s` | %s |\n' "$name" "$detail" ;;
        warn) printf '| ⚠️  warn | `%s` | %s |\n' "$name" "$detail" ;;
        err)  printf '| ❌ err | `%s` | %s |\n' "$name" "$detail" ;;
        skip) printf '| ➖ skip | `%s` | %s |\n' "$name" "$detail" ;;
      esac
    done
    printf '\n## Thresholds\n\n'
    printf -- '- **≥95%%** = ok\n- **≥80%%** = warn (some artifacts missing)\n- **<80%%** = err (adapter is stale; re-run `/setup-project-adapters`)\n'
  fi
} > "$REPORT"

# stderr summary
echo "Adapter coverage audit: $(echo "${SUMMARY_ROWS[*]:-(no adapters)}")" >&2
echo "Report: $REPORT" >&2

if [[ $STRICT -eq 1 && $fails -gt 0 ]]; then
  echo "REFUSED — $fails adapter(s) below 80% coverage (--strict)." >&2
  exit 1
fi
exit 0
