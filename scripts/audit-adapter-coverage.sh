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
#   — stdout under --stdout, <path> under --report=<path>
# Stderr summary.
#
# Coverage thresholds:
#   ≥95%   ok
#   ≥80%   warn (some artifacts didn't translate)
#   <80%   err  (significant drift — adapter is stale)
#
# Usage:
#   audit-adapter-coverage.sh <target> [--strict] [--stdout | --report=<path>]
#
# Flags:
#   --strict        exit 1 if any adapter is under threshold.
#   --stdout        READ-ONLY mode (alias: --no-write). Report goes to stdout and NOTHING
#                   is created under <target> — not the report, not `.claude/`. The only
#                   way to audit a repo you are not permitted to modify.
#   --report=<path> Write the report to <path> instead. Must use `=`.
#
# Exit codes:
#   0 — clean (or warn-only)
#   1 — --strict + at least one adapter under threshold
#   2 — usage error

set -euo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPT_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
# frontmatter_parse_error / frontmatter_check_engine — the same validator the producer
# (apply-adapter-sync.sh) runs, so grader and producer cannot disagree about what parses.
# shellcheck source=scripts/_adapter-emit.sh
. "$SCRIPT_ROOT/scripts/_adapter-emit.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--strict] [--stdout|--report=<path>]" >&2
  echo "       --stdout = read-only: report on stdout, nothing written under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift
STRICT=0
SINK_STDOUT=0
REPORT_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    --stdout|--no-write) SINK_STDOUT=1; shift ;;
    --report=*) REPORT_OVERRIDE="${1#*=}"; shift ;;
    # The catch-all below SWALLOWS unknown args. Left alone, `--report /tmp/x` would be
    # silently dropped and the report would land in the target anyway — the exact
    # silent-write this flag exists to prevent. Refuse the space form explicitly.
    --report) echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *) shift ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 2; }

# ── Report sink ────────────────────────────────────────────────────────────
# The default sink is a file INSIDE the target, which made merely RUNNING this audit a
# write to the audited repo. Observed 2026-08-22: this script regenerated its report
# inside a declared read-only target purely because someone ran it to verify a fix — the
# verification WAS the write, and the regenerated verdict table even flipped an adapter
# from `ok 4/4` to `err 140/205`. --stdout / --report= remove every write under $TARGET,
# `.claude/` included — the mkdir below creates it in a repo that has none.
REPORT="$TARGET/.claude/_adapter-coverage-audit.md"
REPORT_TMP=""
if [[ $SINK_STDOUT -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/adapter-coverage-audit.XXXXXX")
  trap '[ -n "${REPORT_TMP:-}" ] && rm -f "$REPORT_TMP"; :' EXIT
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(stdout — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# List artifact NAMES (no extension, no form) per kind. Dual-form: a flat `<name>.md` and
# an Agent Skills `<name>/SKILL.md` both reduce to `<name>`, which is exactly the token every
# adapter target path is built from. Missing the dir-form branch is a silent FALSE-GREEN:
# SRC_SKILLS collapses to 0, skills drop out of `expected`, and every adapter grades ~100%
# while zero skills were actually translated.
list_basenames_kind() {
  local kind="$1"
  [[ -d "$TARGET/.claude/$kind" ]] || return 0
  { find "$TARGET/.claude/$kind" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null \
      | xargs -I {} basename {} .md 2>/dev/null
    find "$TARGET/.claude/$kind" -mindepth 2 -maxdepth 2 -name 'SKILL.md' \
      -exec sh -c 'for p; do n=$(basename "$(dirname "$p")"); case $n in _*) ;; *) echo "$n" ;; esac; done' _ {} + 2>/dev/null
  } | sort -u
}

# Count source artifacts in .claude/. Defined in terms of list_basenames_kind so `expected`
# can never drift from the number of items actually graded below (one loop iteration each).
# Guard the missing-dir case: under `set -euo pipefail`, `find <missing> | …` exits non-zero
# and aborts the command substitution before the report is ever written. A project may
# legitimately ship without one kind (e.g. no rules/), so treat a missing dir as 0, not fatal.
count_source_kind() {
  list_basenames_kind "$1" | wc -l | tr -d ' '
}
SRC_COMMANDS=$(count_source_kind commands)
SRC_AGENTS=$(count_source_kind agents)
SRC_SKILLS=$(count_source_kind skills)
SRC_RULES=$(count_source_kind rules)

# Per-adapter coverage check
declare -a SUMMARY_ROWS  # one line per adapter: "verdict|adapter|details"

# ---------- cursor ----------
audit_cursor() {
  [[ -d "$TARGET/.cursor" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS + SRC_RULES))
  while IFS= read -r b; do
    # Skills-first (Cursor ≥ 2.3): grade the PRIMARY surface only. The legacy .cursor/commands/<name>.md
    # mirror is ALWAYS written by apply, so OR-counting it would let a missing primary skill grade ok
    # while the command never surfaces in Cursor's native picker (#6).
    [[ -f "$TARGET/.cursor/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.cursor/commands/agent-$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  while IFS= read -r b; do
    [[ -f "$TARGET/.cursor/skills/$b/SKILL.md" || -f "$TARGET/.cursor/skills/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  while IFS= read -r b; do
    # Cursor rules use the documented numeric-prefix ordering convention
    # (.cursor/rules/<NN>-<name>.mdc — see tool-adapters/cursor/adapter.md § Rules);
    # accept both the prefixed and bare forms so the audit doesn't false-flag a correct sync.
    { [[ -f "$TARGET/.cursor/rules/$b.mdc" ]] || compgen -G "$TARGET/.cursor/rules/[0-9]*-$b.mdc" >/dev/null; } && hits=$((hits + 1))
  done < <(list_basenames_kind rules)
  echo "$hits|$expected"
}

# An .opencode/agents/<name>.md counts toward coverage ONLY if its frontmatter satisfies
# OpenCode's schema + the adapter contract (tool-adapters/opencode/adapter.md § Agents):
#   - `tools:` in record form, NEVER Claude's comma-string (OpenCode rejects that outright);
#   - `mode:` declared (so OpenCode routes it as a dispatchable persona);
#   - `model:`, when present, provider-qualified (`anthropic/claude-...`), not a bare tier
#     alias that won't resolve.
# A file that merely EXISTS but is off-contract loaded BROKEN in the field, so it must not
# score as covered — that silent pass is exactly how a botched sync shipped undetected.
# This mirrors apply-adapter-sync.sh's opencode_normalize_agent_frontmatter (the producer).
# set -e safe: pure if/then, no `&&`/`||` that could abort under `set -euo pipefail`.
opencode_agent_frontmatter_ok() {
  local f="$1" fmt
  [[ -f "$f" ]] || return 1
  fmt=$(awk 'BEGIN{fm=0} /^---[[:space:]]*$/{fm++; next} fm>=2{exit} fm==1{print}' "$f")
  # string-form tools -> reject (hard OpenCode schema error)
  if printf '%s\n' "$fmt" | grep -qE '^tools:[[:space:]]*[A-Za-z]'; then return 1; fi
  # mode must be declared
  if ! printf '%s\n' "$fmt" | grep -qE '^mode:[[:space:]]*[A-Za-z]'; then return 1; fi
  # model, if present, must be provider-qualified (provider/model), not a bare alias
  if printf '%s\n' "$fmt" | grep -qE '^model:[[:space:]]'; then
    if ! printf '%s\n' "$fmt" | grep -qE '^model:[[:space:]]*[^[:space:]]+/[^[:space:]]'; then return 1; fi
  fi
  return 0
}

# ---------- opencode ----------
audit_opencode() {
  [[ -d "$TARGET/.opencode" || -f "$TARGET/opencode.json" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS))
  while IFS= read -r b; do
    # The `agent:` frontmatter is load-bearing — without it OpenCode routes the command to a no-tool
    # mode and it DESCRIBES instead of EXECUTES. A command file that lacks it is not a real hit, so
    # require BOTH presence AND an `agent:` line (any value, mirroring apply-adapter-sync.sh tolerance).
    [[ -f "$TARGET/.opencode/commands/$b.md" ]] && grep -q "^agent:" "$TARGET/.opencode/commands/$b.md" 2>/dev/null && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    # Presence is necessary but NOT sufficient — the frontmatter must be contract-valid
    # (object tools + mode + provider-form model), else the agent loads broken in OpenCode.
    [[ -f "$TARGET/.opencode/agents/$b.md" ]] && opencode_agent_frontmatter_ok "$TARGET/.opencode/agents/$b.md" && hits=$((hits + 1))
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
  [[ -d "$TARGET/.clinerules" || -d "$TARGET/.cline" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_RULES + SRC_SKILLS))
  while IFS= read -r b; do
    # Skills-first (Cline merged workflows into Skills): grade the PRIMARY surface only. The legacy
    # .clinerules/workflows/<name>.md mirror is ALWAYS written by apply, so OR-counting it would let a
    # missing primary skill grade ok while the command never surfaces in Cline's native Skills picker.
    [[ -f "$TARGET/.cline/skills/$b/SKILL.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -f "$TARGET/.cline/skills/$b/SKILL.md" || -f "$TARGET/.cline/skills/$b.md" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
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
# The old grader scored 4 points for four `grep` patterns, and TWO of them were the
# same alternation: `^##.*[Cc]ommand|^##.*[Pp]rocedure` and `^##.*[Ss]kill|##.*[Pp]rocedure`
# BOTH match a single `## Named procedures` heading. So `## Named procedures` +
# `## Named personas` + 100 lines scored 4/4 = "ok 100%" with zero of the project's
# commands actually written down and zero skills documented — a false green by
# construction, on the weakest tool in the set. Worse, sync_aider REQUIRES an EXECUTE NOW
# preamble on the command sections and the grader never looked for one.
#
# Aider is a single-doc tool, so "translated" means "named in CONVENTIONS.md". That is
# per-artifact checkable exactly like every other adapter: one point per command, agent
# and skill actually mentioned, plus the structural anchors the 4.8.0 contract names.
# Each anchor below is a DISTINCT pattern — no heading can score two points.
audit_aider() {
  local file="$TARGET/CONVENTIONS.md"
  [[ -f "$file" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS + 4))
  # Per-artifact: is each source artifact actually named in the single doc?
  while IFS= read -r b; do
    [[ -n "$b" ]] && grep -qF -- "$b" "$file" && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  while IFS= read -r b; do
    [[ -n "$b" ]] && grep -qF -- "$b" "$file" && hits=$((hits + 1))
  done < <(list_basenames_kind agents)
  while IFS= read -r b; do
    [[ -n "$b" ]] && grep -qF -- "$b" "$file" && hits=$((hits + 1))
  done < <(list_basenames_kind skills)
  # Structural anchors from the Phase 4.8.0 aider row + sync_aider's own requirements.
  # Disjoint patterns: procedures, personas, the safety disclosure, the preamble.
  grep -qE '^##.*([Pp]rocedure|[Cc]ommand)' "$file" && hits=$((hits + 1))
  grep -qE '^##.*([Pp]ersona|[Aa]gent)'     "$file" && hits=$((hits + 1))
  grep -qE '^##.*[Dd]river-dependent'       "$file" && hits=$((hits + 1))
  # sync_aider (apply-adapter-sync.sh) reports MISSING-AUTHOR without this; grading it
  # closes the gap where the producer required something the grader never checked.
  grep -qF 'EXECUTE NOW' "$file" && hits=$((hits + 1))
  echo "$hits|$expected"
}

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
  # GEMINI.md is always written (cross-tool anchor / thin pointer), even when gemini is NOT a
  # selected tool. Only grade the full native TOML command surface when gemini was actually
  # selected — i.e. its .gemini/commands/ dir exists. Otherwise grade the anchor at 1/1, so an
  # unselected gemini isn't scored ~3% and false-REFUSED under --strict (#5; mirrors audit_codex).
  if [[ ! -d "$TARGET/.gemini/commands" ]]; then
    echo "1|1"
    return
  fi
  local hits=0 expected=$((SRC_COMMANDS + 1))
  hits=$((hits + 1))  # GEMINI.md present (checked above)
  while IFS= read -r b; do
    [[ -f "$TARGET/.gemini/commands/$b.toml" ]] && hits=$((hits + 1))
  done < <(list_basenames_kind commands)
  echo "$hits|$expected"
}

# Resolve the parent agent file(s) that may declare Kimi subagents. Subagents at
# .kimi/subagents/<name>.yaml are INERT until declared in a parent agent YAML's
# `subagents:` section. Accept the documented default (.kimi/agent.yaml) OR a
# configured one ($KIMI_AGENT_CONFIG env, resolved relative to TARGET if not absolute),
# OR any project-side .kimi/*.yaml (not under subagents/) that carries a `subagents:` block.
kimi_parent_agent_files() {
  local found=""
  if [[ -n "${KIMI_AGENT_CONFIG:-}" ]]; then
    if [[ "$KIMI_AGENT_CONFIG" = /* ]]; then
      [[ -f "$KIMI_AGENT_CONFIG" ]] && found+=" $KIMI_AGENT_CONFIG"
    else
      [[ -f "$TARGET/$KIMI_AGENT_CONFIG" ]] && found+=" $TARGET/$KIMI_AGENT_CONFIG"
    fi
  fi
  [[ -f "$TARGET/.kimi/agent.yaml" ]] && found+=" $TARGET/.kimi/agent.yaml"
  local f
  for f in "$TARGET"/.kimi/*.yaml; do
    [[ -f "$f" ]] || continue
    grep -qE '^[[:space:]]*subagents:[[:space:]]*$' "$f" 2>/dev/null && found+=" $f"
  done
  echo "$found" | tr -s ' ' | sed 's/^ //'
}

# check_kimi_subagent_registration — named guard. FAILS (exit 1) when subagent YAMLs
# exist under .kimi/subagents/ but at least one is NOT declared in any parent agent
# file. Orphan subagents cannot be dispatched by Kimi, so a 100%-file-coverage audit
# that ignores registration would grade green while dispatch is silently broken.
# Exit 0 = clean (no subagents, or every subagent registered). Emits diagnostics to stderr.
check_kimi_subagent_registration() {
  local any=0 b
  for f in "$TARGET"/.kimi/subagents/*.yaml; do
    [[ -f "$f" ]] || continue
    any=1
  done
  [[ $any -eq 1 ]] || return 0   # no subagents → nothing to register
  local parents
  parents=$(kimi_parent_agent_files)
  if [[ -z "$parents" ]]; then
    echo "kimi: subagents present but NO parent agent file (.kimi/agent.yaml or configured) declares any — all orphaned" >&2
    return 1
  fi
  local broken=0
  for f in "$TARGET"/.kimi/subagents/*.yaml; do
    [[ -f "$f" ]] || continue
    b=$(basename "$f" .yaml)
    # Registered if some parent file references the subagent by name (key) or by its path/basename.
    if ! grep -hqE "(^[[:space:]]+$b:[[:space:]]*$)|($b\.yaml)|(subagents/$b)" $parents 2>/dev/null; then
      echo "kimi: subagent '$b' is not declared in any parent agent file — orphan, cannot dispatch" >&2
      broken=$((broken + 1))
    fi
  done
  [[ $broken -eq 0 ]]
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
  # Subagent registration guard: orphan subagents (not declared in a parent agent YAML) cannot
  # dispatch. Force an err verdict when registration is broken — file coverage alone is a lie.
  if ! check_kimi_subagent_registration; then
    echo "0|$expected"
    return
  fi
  echo "$hits|$expected"
}

# A .qwen/commands/<name>.md counts toward coverage ONLY if it satisfies the contract in
# tool-adapters/qwen/adapter.md § `.qwen/commands/<name>.md`: frontmatter is `description:`
# (the Claude-only orchestrator fields `kind:`/`pack:`/`allowed-tools:` read as leaked
# Claude-isms exactly as they do in OpenCode, and apply-adapter-sync.sh strips them), and
# the frontmatter must actually PARSE — a description with an unquoted colon-space makes
# Qwen read the rest of the value as a nested mapping and the whole block fails.
#
# Presence-only was the gap: a verbatim copy carrying `compatibility:`, `kind:` and `pack:`
# with no args token scored 100%. Only OpenCode had a content check; the pattern existed
# and was applied to exactly one of eleven adapters.
qwen_command_ok() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local fmt
  fmt=$(awk 'BEGIN{fm=0} /^---[[:space:]]*$/{fm++; next} fm>=2{exit} fm==1{print}' "$f")
  printf '%s\n' "$fmt" | grep -qE '^(kind|pack|allowed-tools):[[:space:]]' && return 1
  [[ -n "$(frontmatter_parse_error "$f")" ]] && return 1
  return 0
}

# ---------- qwen: native 1:1 commands + agents + skills ----------
audit_qwen() {
  [[ -d "$TARGET/.qwen" ]] || return 1
  local hits=0 expected=$((SRC_COMMANDS + SRC_AGENTS + SRC_SKILLS))
  while IFS= read -r b; do
    qwen_command_ok "$TARGET/.qwen/commands/$b.md" && hits=$((hits + 1))
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

# --stdout: the report was buffered off-target; emit it now and leave $TARGET untouched.
if [[ -n "$REPORT_TMP" ]]; then
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi

# stderr summary
echo "Adapter coverage audit: $(echo "${SUMMARY_ROWS[*]:-(no adapters)}")" >&2
echo "Report: $REPORT_LABEL" >&2

if [[ $STRICT -eq 1 && $fails -gt 0 ]]; then
  echo "REFUSED — $fails adapter(s) below 80% coverage (--strict)." >&2
  exit 1
fi
exit 0
