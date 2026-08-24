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

# Resolve through the global-install symlink so SCRIPT_ROOT is the CHECKOUT, never ~/.claude.
# ~/.claude/scripts/<name> is a symlink INTO this repo, so an unresolved BASH_SOURCE makes
# dirname() report ~/.claude/scripts and every sibling asset reached for below resolves only
# if it, too, happens to have been linked. That is exactly how the merge engine went missing:
# scripts/merge-decide.py existed at HEAD, sync-to-global.sh had not been re-run since it
# landed, and $SCRIPT_ROOT/scripts/merge-decide.py pointed at a link that was never created — so
# 238 MERGE rows across two live repos degraded to "listed, not decided" and the run still
# exited 0. See CONTRIBUTING § "Scripts run from two places". Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
SCRIPT_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
# Shared emitters — the SAME file scripts/sync-to-global.sh sources. Supplies
# emit_exec_body / yaml_scalar / cmd_description / opencode_classify_command_agent /
# frontmatter_parse_error / emit_<tool>_*. Two lanes, one definition per artifact
# shape: the global lane and this one used to generate the same shapes separately and
# drift (opposite OpenCode `agent:` modes for /refine-prompt; working Codex and Gemini
# generators here that this lane punted to an LLM instead of calling).
# shellcheck source=scripts/_adapter-emit.sh
. "$SCRIPT_ROOT/scripts/_adapter-emit.sh"
# Artifacts written by THIS lane trace to the project's own .claude/, not to Refract.
ADAPTER_EMIT_MARK_PREFIX="source: .claude/commands/"

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
  { [[ -d "$TARGET/.clinerules" ]] || [[ -d "$TARGET/.cline" ]]; } && detected+=" cline"
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

# strip_for_compare <file> [strip_agent] — emit a file's body with the THREE intentional,
# sync-preserved adapter additions discounted, so the drift comparison reflects only REAL
# body changes (one awk pass per side keeps the per-file fork count low on 480-file sweeps):
#   (1) the injected EXECUTE NOW preamble — kimi/codex/aider command-skills carry it, the
#       .claude source does not. TWO forms exist in the ecosystem and BOTH are discounted:
#       the `<!-- EXECUTE NOW preamble ... -->` HTML-comment block (migrate-kimi / apply-
#       adapter-sync form) AND the bare `> # EXECUTE NOW` blockquote (sync-to-global /
#       LLM-authored form). Matching only the first is what made Kimi command-skills churn.
#   (2) the anchored `<!-- project-specific:start --> ... :end -->` block — sync_file
#       PRESERVES it across overwrites (extract + re-inject below), so a block in the dst
#       but not the source is an intentional per-tool addition, NOT drift.
#   (3) (only when strip_agent=1, i.e. OpenCode command targets) the load-bearing
#       frontmatter `agent:` line the .claude source never carries, AND — the reverse —
#       the Claude-only orchestrator fields (`kind:`, `pack:`, `allowed-tools:`) the
#       .claude source DOES carry but that are meaningless to OpenCode and are stripped
#       from the translated file on --apply. Both sides of the compare pass strip_agent=1
#       for OpenCode commands so a clean dst matches a source that still has those fields.
# Each is also re-injected on --apply, so without discounting them every faithfully-synced
# artifact false-flags as REFRESH forever (the C2h/C2m churn) even though --apply is
# idempotent. Anchored project-specific markers only (mirrors extract_project_specific_block)
# so a backtick mention of the marker in prose is not treated as a real block. Blank-line
# count differences vs the source are tolerated by `diff -B` at the call site.
strip_for_compare() {
  awk -v sa="${2:-0}" '
    /<!-- EXECUTE NOW preamble/                           { inpre=1; next }
    inpre && /<!-- \/EXECUTE NOW preamble -->/            { inpre=0; next }
    inpre                                                 { next }
    /^>[[:space:]]*#[[:space:]]*EXECUTE NOW[[:space:]]*$/ { inbq=1; next }
    inbq && /^>/                                          { next }
    inbq                                                  { inbq=0 }
    /^<!-- project-specific:start -->[[:space:]]*$/       { inps=1; next }
    inps && /^<!-- project-specific:end -->[[:space:]]*$/ { inps=0; next }
    inps                                                  { next }
    NR==1 && /^---[[:space:]]*$/                          { fm=1; print; next }
    fm && /^---[[:space:]]*$/                             { fm=0; print; next }
    sa==1 && fm && /^agent:[[:space:]]/                   { next }
    sa==1 && fm && /^(kind|pack|allowed-tools):[[:space:]]/ { next }
    { print }
  ' "$1"
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

# Strip Claude-only command frontmatter fields (`kind:`, `pack:`, `allowed-tools:`) from a
# translated command file (.opencode/commands/ and .qwen/commands/ — both document
# `description:`-shaped frontmatter and both read these as leaked Claude-isms). OpenCode command frontmatter is `description:` +
# `agent:` (+ optional model/subtask); the orchestrator's `kind:`/`pack:` metadata and
# Claude's `allowed-tools:` are meaningless there and read as leaked Claude-isms. Stripping
# them on --apply keeps native files clean and stops the drift-compare from false-flagging a
# hand-cleaned file forever. Frontmatter block only — the markdown body is never touched.
strip_claude_command_fields() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local tmp; tmp=$(mktemp)
  awk '
    NR==1 && /^---[[:space:]]*$/ { fm=1; print; next }
    fm && /^---[[:space:]]*$/    { fm=0; print; next }
    fm && /^(kind|pack|allowed-tools):[[:space:]]/ { next }
    { print }
  ' "$f" > "$tmp"
  mv "$tmp" "$f"
}

# Extract just the injected EXECUTE NOW preamble so a real refresh can re-inject it
# after the body is overwritten. Handles BOTH forms (mirrors strip_for_compare): the
# `<!-- EXECUTE NOW preamble ... -->` HTML-comment block AND the bare `> # EXECUTE NOW`
# blockquote (LLM-authored kimi/cursor/opencode command-skills). Capturing only the HTML
# form silently dropped blockquote preambles on --apply REFRESH → MISSING-AUTHOR churn.
extract_injected_preamble() {
  awk '
    /<!-- EXECUTE NOW preamble/                           { inpre=1; print; next }
    inpre && /<!-- \/EXECUTE NOW preamble -->/            { print; exit }
    inpre                                                 { print; next }
    /^>[[:space:]]*#[[:space:]]*EXECUTE NOW[[:space:]]*$/ { inbq=1; print; next }
    inbq && /^>/                                          { print; next }
    inbq                                                  { exit }
  ' "$1"
}

# Re-inject a captured EXECUTE NOW preamble after the frontmatter, before the body.
# No-op if the file already carries one (src may already include it) or block is empty.
reinject_injected_preamble() {
  local f="$1" pre_file="$2"
  [[ -s "$pre_file" ]] || return 0
  [[ -f "$f" ]] || return 0
  grep -q "<!-- EXECUTE NOW preamble" "$f" 2>/dev/null && return 0
  grep -qE '^>[[:space:]]*#[[:space:]]*EXECUTE NOW' "$f" 2>/dev/null && return 0
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
  # Qwen command frontmatter is `description:` only (qwen/adapter.md § .qwen/commands/<name>.md),
  # so the Claude-only orchestrator fields get the SAME strip OpenCode's do — and the same
  # discount in the drift compare, or every cleaned file false-flags REFRESH forever.
  local strip_claude=$oc_cmd
  [[ "$dst" == *"/.qwen/commands/"* ]] && strip_claude=1
  # OpenCode AGENTS need contract frontmatter that diverges from `.claude`:
  # opencode_normalize_agent_frontmatter rewrites string-form `tools:` into a record,
  # injects `mode: subagent`, and maps `model:` shorthand to provider form on the dst
  # at --apply (sync_opencode). That transform is ONE-WAY, so comparing a synced dst
  # against the raw src re-flags every faithfully-synced agent as drift forever. Compare
  # against a copy of src run through the SAME normalization so a correctly-synced agent
  # reads as NO-OP.
  local oc_agent=0 cmp_src="$src" cmp_tmp=""
  [[ "$dst" == *"/.opencode/agents/"* ]] && oc_agent=1
  if [[ $oc_agent -eq 1 ]]; then
    cmp_tmp=$(mktemp); cp "$src" "$cmp_tmp"; opencode_normalize_agent_frontmatter "$cmp_tmp"; cmp_src="$cmp_tmp"
  fi
  if [[ ! -f "$dst" ]]; then
    if [[ $APPLY -eq 1 ]]; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      [[ $strip_claude -eq 1 ]] && strip_claude_command_fields "$dst"
    fi
    echo "    ADD       $(rel_to_target "$dst")"
    total_added=$((total_added + 1))
  elif diff -q -B <(strip_for_compare "$dst" "$strip_claude") <(strip_for_compare "$cmp_src" "$strip_claude") >/dev/null 2>&1; then
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
      # Strip Claude-only orchestrator fields so the translated OpenCode command stays clean.
      [[ $strip_claude -eq 1 ]] && strip_claude_command_fields "$dst"
      # Re-inject extracted block + preamble + agent field (each a no-op if src already carries one OR empty).
      reinject_project_specific_block "$dst" "$block_tmp"
      reinject_injected_preamble "$dst" "$pre_tmp"
      [[ $oc_cmd -eq 1 ]] && reinject_frontmatter_agent_line "$dst" "$agent_line"
    fi
    rm -f "$block_tmp" "$pre_tmp"
    echo "    REFRESH   $(rel_to_target "$dst")"
    total_refreshed=$((total_refreshed + 1))
  fi
  # Use an `if` (not `&&`) so an empty cmp_tmp can't return non-zero and trip `set -e`.
  if [[ -n "$cmp_tmp" ]]; then rm -f "$cmp_tmp"; fi
}

rel_to_target() { echo "${1#$TARGET/}"; }

# Report a target as needing format-conversion (LLM authoring required).
report_missing_author() {
  local kind="$1" expected_path="$2" reason="$3"
  echo "    MISSING-AUTHOR $expected_path  ($reason)"
  total_missing_author=$((total_missing_author + 1))
}

# True when the target project ships real hooks worth translating to a native adapter
# hook config (any `.claude/hooks/*.sh`). No hooks → nothing to translate, so the
# native-hook reporting below is skipped entirely (a hookless project never false-flags).
project_has_hooks() {
  compgen -G "$TARGET/.claude/hooks/*.sh" > /dev/null 2>&1
}

# Report a full-native-hook tool's hook surface as needing LLM authoring — ONLY when the
# project ships `.claude/hooks/*.sh` AND that native surface is absent (or, for a shared
# settings file, carries no `"hooks"` block yet). Translating `.claude/hooks/*.sh` needs
# per-tool schema knowledge + a payload shim (see each adapter's § Hooks), so the CONTENT
# stays LLM-authored via /setup-project-adapters — this helper just makes the sync DRIVE
# hook coverage for EVERY native-hook tool instead of only Cursor.
#   path ending in `/`            → directory target: present when it holds ≥1 file.
#   path ending in `settings.json`→ shared config: present when it exists AND has "hooks".
#   otherwise                     → dedicated file: present when it exists.
report_hooks_missing() {
  local kind="$1" path="$2" reason="$3"
  project_has_hooks || return 0
  local full="$TARGET/$path"
  if [[ "$path" == */ ]]; then
    compgen -G "$full"'*' > /dev/null 2>&1 && return 0
  elif [[ "$path" == *settings.json ]]; then
    [[ -f "$full" ]] && grep -q '"hooks"' "$full" 2>/dev/null && return 0
  else
    [[ -f "$full" ]] && return 0
  fi
  report_missing_author "$kind" "$path" "$reason"
}

# ── Per-adapter sync recipes ───────────────────────────────────────────────

# OpenCode agent frontmatter must satisfy OpenCode's schema + the adapter contract
# (templates/tool-adapters/opencode/adapter.md § Agents), which diverges from Claude's
# `.claude/agents/<name>.md` frontmatter in THREE ways. A faithful 1:1 copy therefore
# loads broken or off-contract, so this helper rewrites a destination .opencode agent
# file IN-PLACE to the OpenCode shape:
#   1. tools:  string form (`tools: Bash, Read, Grep`) -> YAML record (`tools:\n  bash: true`).
#              Claude accepts the string; OpenCode rejects it ("expected record, received string").
#   2. mode:   inject `mode: subagent` when the block declares none — OpenCode needs it to
#              route the file as a dispatchable persona rather than a primary agent.
#   3. model:  Claude tier shorthand (sonnet|opus|haiku) -> `anthropic/claude-...` provider id;
#              a bare alias does not resolve in OpenCode's model catalogue.
# Already-correct fields (record tools / present mode / provider-form model) are left
# untouched, so the transform is IDEMPOTENT — safe to re-run on an already-synced file.
# Operates on the frontmatter (before the 2nd `---`) ONLY — never touches the markdown body.
# The model map tracks the latest Claude tier ids; adjust here if OpenCode's catalogue
# uses different slugs. Mirrored by audit-adapter-coverage.sh's opencode_agent_frontmatter_ok,
# which FAILS coverage for any agent that does not satisfy this same contract.
opencode_normalize_agent_frontmatter() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local tmp; tmp=$(mktemp)
  awk '
    BEGIN { fm=0; has_mode=0 }
    /^---[[:space:]]*$/ {
      # Closing frontmatter fence: inject mode if the block never declared one.
      if (fm==1 && !has_mode) print "mode: subagent"
      fm++; print; next
    }
    fm==1 && /^mode:[[:space:]]/ { has_mode=1; print; next }
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
    fm==1 && /^model:[[:space:]]/ {
      val=$0; sub(/^model:[[:space:]]*/, "", val); gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
      if      (val=="sonnet") print "model: anthropic/claude-sonnet-4-6"
      else if (val=="opus")   print "model: anthropic/claude-opus-4-8"
      else if (val=="haiku")  print "model: anthropic/claude-haiku-4-5"
      else print $0
      next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

# opencode_classify_command_agent lives in scripts/_adapter-emit.sh — sourced above and
# shared with the GLOBAL lane. It used to be defined here AND, differently, in
# sync-to-global.sh: this lane classified /refine-prompt `build` (it writes
# ai/prompts/<YYYYMMDD>-<slug>.md) while the global lane's hard-coded list pinned it
# `plan`, the one mode that blocks its write. One definition, so the same command cannot
# be classified two ways again.

# Write a generated artifact through sync_file, so a derived file still gets the backup,
# drift-compare and project-specific-block preservation a 1:1 copy gets. $1 = generator
# command line (evaluated), $2 = destination.
sync_generated() {  # $1 = emitter function, $2 = destination, $3.. = emitter args
  local gen="$1" dst="$2"; shift 2
  local tmp; tmp=$(mktemp)
  "$gen" "$@" > "$tmp"
  sync_file "$tmp" "$dst"
  rm -f "$tmp"
}

# True when a command name also names a skill in .claude/skills/. Both would write the
# SAME <adapter>/skills/<name>/SKILL.md, so the on-disk file can match only ONE source
# and the other false-flags drift forever. The skill owns the path (it is the reference
# procedure); the command keeps whatever secondary surface that adapter has.
command_name_collides_with_skill() {
  local name="$1"
  [[ -f "$TARGET/.claude/skills/$name.md" || -f "$TARGET/.claude/skills/$name/SKILL.md" ]]
}

sync_opencode() {
  echo "  [opencode]"
  # 1:1 markdown copies — agents, commands, skills (folder-form).
  for f in "$TARGET"/.claude/agents/*.md; do
    [[ -f "$f" ]] || continue
    local dst="$TARGET/.opencode/agents/$(basename "$f")"
    sync_file "$f" "$dst"
    [[ $APPLY -eq 1 ]] && opencode_normalize_agent_frontmatter "$dst"
  done
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    local cdst="$TARGET/.opencode/commands/$(basename "$f")"
    sync_file "$f" "$cdst"
    # `agent:` frontmatter is load-bearing — without it OpenCode describes instead of executes.
    # Deterministically classify + inject it from the source (build|plan) so no LLM authoring
    # step is required. A hand-authored agent: already in the dst is preserved by sync_file's
    # extract+reinject path, so this only fills a genuinely missing field.
    if [[ $APPLY -eq 1 && -f "$cdst" ]] && ! grep -q "^agent:" "$cdst"; then
      reinject_frontmatter_agent_line "$cdst" "agent: $(opencode_classify_command_agent "$f")"
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
  # Hooks → partial: OpenCode has no shell-in-config hooks; guardrails live in a TS plugin (`tool.execute.before/.after` that shells out to .claude/hooks/*.sh). LLM-authored.
  report_hooks_missing "opencode-hooks" ".opencode/plugins/" "translate .claude/hooks/*.sh → an OpenCode TS plugin (.opencode/plugins/guardrails.ts; tool.execute.before to block) — run /setup-project-adapters"
}

sync_cursor() {
  echo "  [cursor]"
  # Commands are skills-first: PRIMARY = .cursor/skills/<name>/SKILL.md (LLM-authored — needs a
  # `name:` field the source command lacks); fallback = .cursor/commands/<name>.md (1:1 mirror,
  # still works, on Cursor's slash-command→Skills deprecation path).
  # The PRIMARY surface is generated, not punted. This lane used to write the DEPRECATED
  # .cursor/commands/ mirror deterministically and MISSING-AUTHOR the .cursor/skills/
  # surface that cursor/adapter.md marks PRIMARY — backwards. The `name:` field the source
  # command lacks is exactly what emit_command_skill supplies.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.cursor/commands/$name.md"
    if command_name_collides_with_skill "$name"; then continue; fi
    sync_generated emit_command_skill "$TARGET/.cursor/skills/$name/SKILL.md" "$f" "$name" ""
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
  # Hooks → native .cursor/hooks.json (events preToolUse/beforeShellExecution/afterFileEdit/…; timeouts in SECONDS). Format conversion.
  report_hooks_missing "cursor-hooks" ".cursor/hooks.json" "translate .claude/hooks/*.sh → Cursor hooks.json (real events + per-tool payload shim) — run /setup-project-adapters"
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
  # Hooks → native .github/hooks/*.json (events preToolUse/postToolUse/sessionStart/…; read by CLI + Cloud Agent). Format conversion.
  report_hooks_missing "copilot-hooks" ".github/hooks/" "translate .claude/hooks/*.sh → Copilot .github/hooks/*.json (per-tool payload shim) — run /setup-project-adapters"
}

sync_cline() {
  echo "  [cline]"
  # Commands are skills-first: PRIMARY = .cline/skills/<name>/SKILL.md (LLM-authored — needs a
  # `name:` field the source command lacks); fallback = .clinerules/workflows/<name>.md (1:1 mirror,
  # still works, on Cline's workflows→Skills deprecation path — the workflows docs page now 404s).
  # PRIMARY surface generated (see the cursor note above — same inversion, same fix).
  # .clinerules/workflows/ stays as the graded fallback mirror; its docs page now 404s.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.clinerules/workflows/$name.md"
    if command_name_collides_with_skill "$name"; then continue; fi
    sync_generated emit_command_skill "$TARGET/.cline/skills/$name/SKILL.md" "$f" "$name" ""
  done
  # Reference skills → .cline/skills/<name>/SKILL.md (NATIVE folder copy).
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    if [[ -f "$skill_dir/SKILL.md" ]]; then
      sync_file "$skill_dir/SKILL.md" "$TARGET/.cline/skills/$skill_name/SKILL.md"
    fi
  done
  # Flat skills.
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    skill_name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.cline/skills/$skill_name/SKILL.md"
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
  [[ -f "$TARGET/.clinerules/82-skills.md" ]]  || report_missing_author "cline-skills-index" ".clinerules/82-skills.md" "skill procedure catalog/index (PRIMARY surface is .cline/skills/) — run /setup-project-adapters"
  # Hooks → native .clinerules/hooks/<EventName> executable scripts (v3.36; PreToolUse/PostToolUse/UserPromptSubmit/TaskStart/…). Format conversion.
  report_hooks_missing "cline-hooks" ".clinerules/hooks/" "translate .claude/hooks/*.sh → Cline .clinerules/hooks/<EventName> (filename = event, per-tool payload shim) — run /setup-project-adapters"
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
  # Hooks → native .windsurf/hooks.json (events pre_/post_ write_code/run_command/…; pre-hooks block via exit 2). Format conversion.
  report_hooks_missing "windsurf-hooks" ".windsurf/hooks.json" "translate .claude/hooks/*.sh → Windsurf hooks.json (per-tool payload shim) — run /setup-project-adapters"
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
  # Commands + skills translate to NATIVE Agent Skills (primary surface); AGENTS.md prose
  # is fallback. These were MISSING-AUTHOR rows — an LLM round-trip on every /setup-project
  # for a shape scripts/sync-to-global.sh already generated correctly one directory over.
  # Same generator now, so the global surface and every project get identical bytes.
  # (codex/adapter.md § Agent Skills: `name` required [a-z0-9-]{1,64}, `description`
  # required 1-1024 chars, body is the workflow prose.)
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    if command_name_collides_with_skill "$name"; then continue; fi
    sync_generated emit_codex_skill "$TARGET/.agents/skills/$name/SKILL.md" "$f" "$name" ""
  done
  # Reference skills are NOT command-derived: they are supposed to load as documentation,
  # so they get a 1:1 copy with NO preamble. Copy deterministically, then flag only the
  # real gap — a source SKILL.md with no `name:` is not a valid Agent Skill.
  for skill_dir in "$TARGET"/.claude/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "$skill_dir")
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    sync_file "$skill_dir/SKILL.md" "$TARGET/.agents/skills/$name/SKILL.md"
    grep -q '^name:' "$skill_dir/SKILL.md" || report_missing_author "codex-skill-name" ".agents/skills/$name/SKILL.md" "source SKILL.md has no 'name:' — required by the Agent Skills schema; add it to .claude/skills/$name/SKILL.md"
  done
  for f in "$TARGET"/.claude/skills/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_file "$f" "$TARGET/.agents/skills/$name/SKILL.md"
    grep -q '^name:' "$f" || report_missing_author "codex-skill-name" ".agents/skills/$name/SKILL.md" "source skill has no 'name:' — required by the Agent Skills schema; add it to .claude/skills/$name.md"
  done
  # Hooks → native .codex/hooks.json (or [hooks] in .codex/config.toml; events PreToolUse/PostToolUse/…; /hooks trust model). Format conversion.
  report_hooks_missing "codex-hooks" ".codex/hooks.json" "translate .claude/hooks/*.sh → Codex .codex/hooks.json (per-tool payload shim; user must trust via /hooks) — run /setup-project-adapters"
}

sync_gemini() {
  echo "  [gemini]"
  [[ -f "$TARGET/GEMINI.md" ]] || report_missing_author "gemini-md" "GEMINI.md" "single-file composite; run /setup-project-adapters"
  # Commands translate to NATIVE TOML custom commands (primary surface); GEMINI.md prose
  # is fallback. Deterministic — the global lane's TOML generator, shared, not re-punted
  # to an LLM. `description` + `prompt` are the two documented keys (gemini/adapter.md
  # § Commands); the body carries the EXECUTE NOW preamble and {{args}}.
  for f in "$TARGET"/.claude/commands/*.md; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .md)
    sync_generated emit_gemini_toml "$TARGET/.gemini/commands/$name.toml" "$f" "$name" ""
  done
  # Hooks → native .gemini/settings.json "hooks" block (events BeforeTool/AfterTool/…; timeouts in MS). Format conversion.
  report_hooks_missing "gemini-hooks" ".gemini/settings.json" "translate .claude/hooks/*.sh → Gemini .gemini/settings.json hooks block (ms timeouts, per-tool payload shim) — run /setup-project-adapters"
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
  # Hooks → native .qwen/settings.json "hooks" block (16 events incl. hookSpecificOutput.additionalContext; richest schema). Format conversion.
  report_hooks_missing "qwen-hooks" ".qwen/settings.json" "translate .claude/hooks/*.sh → Qwen .qwen/settings.json hooks block (16 events, additionalContext supported, per-tool payload shim) — run /setup-project-adapters"
}

# ── Main loop ──────────────────────────────────────────────────────────────

echo "=== apply-adapter-sync ==="
echo "Target:           $TARGET"
echo "Mode:             $([[ $APPLY -eq 1 ]] && echo APPLY || echo dry-run)"
echo "Selected adapters: $SELECTED_ADAPTERS"
echo ""

# ── Dual-form skill collision guard ────────────────────────────────────────
# A skill present as BOTH a flat `.claude/skills/<name>.md` AND a folder
# `.claude/skills/<name>/SKILL.md` is a latent bug: every adapter's skills sync
# writes BOTH into the SAME `<adapter>/skills/<name>/SKILL.md` (folder loop then
# flat loop), so the flat copy silently wins on --apply and the other form's
# content is lost. Warn loudly — this is exactly the failure that let a stale
# visual-check body keep clobbering the correct one. Non-fatal; reconcile to ONE form.
total_dual_form=0
if [[ -d "$TARGET/.claude/skills" ]]; then
  for sd in "$TARGET"/.claude/skills/*/; do
    [[ -d "$sd" ]] || continue
    sn=$(basename "$sd")
    if [[ -f "$sd/SKILL.md" && -f "$TARGET/.claude/skills/$sn.md" ]]; then
      echo "  WARN  skill '$sn' exists in BOTH forms (.claude/skills/$sn.md + $sn/SKILL.md) — they collide on one adapter target (flat wins on --apply); reconcile to ONE form"
      total_dual_form=$((total_dual_form + 1))
    fi
  done
  if [[ $total_dual_form -gt 0 ]]; then echo ""; fi
fi

# ── Malformed-frontmatter guard ─────────────────────────────────────────────
# Frontmatter that does not PARSE is malformed, and "parses" is not the same as
# "has two fences". The old guard counted `---` fences only. It could not see the
# defect that actually shipped: a description containing an unquoted colon-space
# (`Anti-triggers (do NOT fire): a plain "implement X"`) makes YAML read the rest of
# the value as a nested mapping, so the whole block fails in every target tool while
# both fences sit there looking correct. This now runs a real parser where one exists
# and a narrower structural check where none does, and it says which ran.
#
# Two failure modes, both non-fatal (warn so the SOURCE is repaired):
#   - unterminated fence — reinject_injected_preamble loops in the frontmatter state
#     and SILENTLY DROPS the EXECUTE NOW preamble on --apply (root cause of an observed
#     kimi command-skill corruption; a historical pipeline left 24 such commands in a
#     real target);
#   - unparseable YAML — name/description are unreadable in every translated copy.
total_bad_fm=0
fm_engine="$(frontmatter_check_engine)"
FM_SHOW_MAX=10
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  fm_err="$(frontmatter_parse_error "$f")"
  if [[ -n "$fm_err" ]]; then
    total_bad_fm=$((total_bad_fm + 1))
    # Two DIFFERENT defects reach this branch and they need different fixes. Count them apart
    # so the summary can say which — see the summary line below for what happened when it
    # could not.
    case "$fm_err" in
      *'never closed'*) bad_fm_unclosed=$(( ${bad_fm_unclosed:-0} + 1 )) ;;
      *)                bad_fm_parse=$(( ${bad_fm_parse:-0} + 1 )) ;;
    esac
    if [[ $total_bad_fm -le $FM_SHOW_MAX ]]; then
      echo "  WARN  frontmatter does not parse: ${f#$TARGET/} — $fm_err"
    fi
  fi
done < <( { ls "$TARGET"/.claude/commands/*.md 2>/dev/null; find "$TARGET"/.claude/skills -name '*.md' 2>/dev/null; find "$TARGET"/.claude/agents -name '*.md' 2>/dev/null; find "$TARGET"/.claude/rules -name '*.md' 2>/dev/null; } )
if [[ $total_bad_fm -gt 0 ]]; then
  [[ $total_bad_fm -gt $FM_SHOW_MAX ]] && echo "  WARN  ... and $((total_bad_fm - FM_SHOW_MAX)) more (list capped at $FM_SHOW_MAX)"
  echo "        Every one of these is copied 1:1 into tools that parse YAML strictly (qwen commands,"
  echo "        cursor commands, copilot prompts, windsurf/cline workflows) — name/description are"
  echo "        unreadable there, and an unterminated fence also drops the EXECUTE NOW preamble on"
  echo "        --apply. Repair the SOURCE: single-quote the value. Generated artifacts are already"
  echo "        safe (the emitters quote), so this is about the 1:1 copy paths only."
  echo "        (checked with: $fm_engine)"
  [[ "$fm_engine" == "structural-fallback" ]] && echo "        NOTE: no YAML parser on this box — the structural check is NARROWER than a parse and can miss classes it does not model."
  echo ""
fi

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
if [[ $total_dual_form -gt 0 ]]; then echo "DUAL-FORM SKILLS:     $total_dual_form  (same-named flat + folder skill collide on one adapter target — reconcile to one form)"; fi
# THE SUMMARY MUST NOT NAME A CAUSE IT DID NOT MEASURE.
# MEASURED: this line read "(opening --- never closed — add the closing --- to the source)" for
# every failure, and on a live run all 11 files it counted had a perfectly closed fence — two
# `^---$` lines, at 1 and 3. The real defect was a YAML mapping-value error at line 1 column 91
# (an unquoted description containing a colon-space). Eleven readers were sent to fix something
# that was not wrong. frontmatter_parse_error() distinguishes the two cases; the summary now
# reports what it actually counted instead of hard-coding one of the two branches.
if [[ ${total_bad_fm:-0} -gt 0 ]]; then
  _fm_unclosed=${bad_fm_unclosed:-0}
  _fm_parse=${bad_fm_parse:-0}
  _fm_detail=""
  [[ $_fm_unclosed -gt 0 ]] && _fm_detail="$_fm_unclosed with an unterminated opening \`---\` (add the closing \`---\`)"
  if [[ $_fm_parse -gt 0 ]]; then
    [[ -n "$_fm_detail" ]] && _fm_detail="$_fm_detail; "
    _fm_detail="$_fm_detail$_fm_parse whose YAML does not parse — the usual cause is an unquoted value containing a colon-space (\`description: … Output: …\`); quote the value. The exact parser message is on each WARN above."
  fi
  echo "MALFORMED FRONTMATTER: $total_bad_fm  ($_fm_detail)"
  # AND IT MUST MOVE THE EXIT CODE. This block counted, named and explained the defect and then
  # returned 0, so every caller read the run as clean: a live run reported "MALFORMED
  # FRONTMATTER: 5" followed by EXIT=0, and Phase 5 C2e downgraded the related condition to a
  # WARN ("adapter coverage: 1 adapter(s) below 80%"). Five adapter artifacts were silently
  # degraded — an artifact whose YAML does not parse does not register in the tool it was
  # translated for — and no gate anywhere caught it. Exit 3, which is the framework's
  # "files DID land, and something needs a human" code (see
  # templates/phases/phase-4.0-preflight.md § Exit-code contract): the projection is on disk
  # and correct except for these N, so the orchestrator continues and reports them.
  ADAPTER_FM_RC=3
fi

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

if [[ "${ADAPTER_FM_RC:-0}" -eq 3 ]]; then
  echo ""
  echo "EXIT 3 — the projection landed, but $total_bad_fm artifact(s) above carry frontmatter that does"
  echo "         not parse. Those are silently degraded in the tool they were translated for."
  echo "         ORCHESTRATOR: this is NOT a stop — the files are on disk and the rest of the sync is"
  echo "         correct. Fix the named files (usually one unquoted colon-space value) and re-run."
  exit 3
fi

exit 0
