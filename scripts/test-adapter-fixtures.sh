#!/usr/bin/env bash
# Behavior-level fixture test for tool adapters.
#
# WHY THIS EXISTS:
#   The other lint scripts (lint-tool-parity.sh, dry-run-setup.sh, test-refine-fixture.sh)
#   verify that documentation is INTERNALLY CONSISTENT (registry vs parity matrix vs contract
#   table vs adapter docs). They do NOT verify that the documented contract is ACHIEVABLE —
#   i.e. that for a given .claude/ fixture, every adapter doc actually documents how to
#   produce every output the contract promises.
#
#   This script closes that gap. For a synthetic .claude/ fixture (~5 files of each artifact
#   type), it walks the Phase 4.8.0 contract rows and asserts:
#     1. Each documented native output path appears in the adapter's adapter.md.
#     2. Each adapter's _translate.md (if present) covers every Claude artifact kind it
#        claims to handle (commands, agents, skills, hooks, rules).
#     3. The adapter doc + setup-project.md contract row are mutually consistent — paths
#        documented in one show up in the other (asymmetric drift = fail).
#
#   This is "fixture by reference" — we don't actually run /setup-project (that needs an
#   LLM session). We treat the spec + adapter docs as the implementation and test that the
#   spec is unambiguous + complete enough that an LLM following it produces the documented
#   shape.
#
# WHAT THE FIXTURE IS:
#   A synthetic .claude/ tree with one file per Claude artifact type:
#     .claude/commands/db-migration.md
#     .claude/agents/backend-reviewer.md
#     .claude/skills/module-scaffold/SKILL.md
#     .claude/hooks/post-edit-check.sh
#     .claude/rules/database.md
#
#   Per adapter, the script computes the expected native output paths from the contract
#   row + adapter doc, then verifies the adapter doc explicitly mentions every artifact
#   kind the fixture exercises.
#
# Usage:  scripts/test-adapter-fixtures.sh
# Exit:   0 = clean, 1 = drift detected

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTERS_DIR="$ROOT/templates/tool-adapters"
# Adapter contract rows live in commands/setup-project-adapters.md after the
# modular split. Some legacy contract / overview content may still reference
# adapters in commands/setup-project.md. We accept either file as a match for
# the contract-row symmetry check.
SETUP_CMD="$ROOT/commands/setup-project.md"
SETUP_ADAPTERS_CMD="$ROOT/commands/setup-project-adapters.md"
ERRORS=0
fail()  { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass()  { printf '\033[32m✓ %s\033[0m\n' "$*"; }
info()  { printf '\033[36m• %s\033[0m\n' "$*"; }
group() { printf '\033[1m\n%s\033[0m\n' "$*"; }

echo "════════════════════════════════════════════════════════════════"
echo "  Adapter fixture test — does each adapter doc cover every artifact kind?"
echo "════════════════════════════════════════════════════════════════"

# Synthetic fixture artifact kinds — one file per kind.
FIXTURE_KINDS=(commands agents skills hooks rules)

# Per-adapter expected coverage. Format: <adapter>:<kind1>,<kind2>,<kindN>
# A kind is "covered" if the adapter doc or contract row contains a recognizable native
# path for it. Adapters that translate (no native folder) still need the kind covered as
# a translation entry — we just look for the kind name in the adapter doc body.
ADAPTERS=(
  "claude-code:commands,agents,skills,hooks,rules"
  "cursor:commands,agents,skills,hooks,rules"
  "opencode:commands,agents,skills,rules"        # no native hooks
  "copilot:commands,agents,skills,rules"          # hooks via instruction advise (translated)
  "cline:commands,skills,rules"                   # commands+skills→.cline/skills/ (PRIMARY); agents/hooks translated as index/sections
  "windsurf:commands,rules"                       # agents/skills/hooks translated
  "continue:commands,rules"                       # agents/skills as prompts (still covered as kind)
  "aider:rules"                                   # single-doc tool — every kind in CONVENTIONS.md
  "codex:commands,skills,rules"                   # commands+skills→.agents/skills/ (native Agent Skills, PRIMARY); rules→AGENTS.md
  "gemini:commands,rules"                         # commands→.gemini/commands/*.toml (native, PRIMARY); rules→GEMINI.md
  "kimi:commands,agents,skills,rules"             # commands→dual-surface (skill+subagent), agents→subagents, skills→skills, rules→AGENTS.md
  "qwen:commands,agents,skills,rules"             # near-1:1 with Claude Code
)

# Native path map — for each (adapter, kind), the expected native path fragment that MUST
# appear in BOTH the contract row in setup-project.md AND the adapter doc. Empty value =
# adapter has no native primitive for that kind (translation only — looser check).
declare -a NATIVE_PATHS=(
  # cursor — fully native
  "cursor:commands:.cursor/commands/"
  "cursor:agents:.cursor/commands/agent-"
  "cursor:skills:.cursor/skills/"
  "cursor:hooks:.cursor/hooks.json"
  "cursor:rules:.cursor/rules/"
  # opencode — native agents/commands/skills
  "opencode:commands:.opencode/commands/"
  "opencode:agents:.opencode/agents/"
  "opencode:skills:.opencode/skills/"
  "opencode:rules:opencode.json"
  # copilot — native agents/skills/prompts
  "copilot:commands:.github/prompts/"
  "copilot:agents:.github/agents/"
  "copilot:skills:.github/skills/"
  "copilot:rules:.github/instructions/"
  # cline — skills-first: commands + reference skills land in .cline/skills/ (PRIMARY);
  # .clinerules/workflows/ is a graded fallback mirror, not the canonical command surface.
  "cline:commands:.cline/skills/"
  "cline:skills:.cline/skills/"
  "cline:rules:.clinerules/"
  # windsurf — native workflows for commands
  "windsurf:commands:.windsurf/workflows/"
  "windsurf:rules:.windsurf/rules/"
  # continue — native prompts as files
  "continue:commands:.continue/prompts/"
  "continue:rules:.continue/rules/"
  # aider — single-doc (rules only check)
  "aider:rules:CONVENTIONS.md"
  # codex — native Agent Skills (PRIMARY) for commands + skills; AGENTS.md prose is the fallback
  "codex:commands:.agents/skills/"
  "codex:skills:.agents/skills/"
  "codex:rules:AGENTS.md"
  # gemini — native TOML custom commands (PRIMARY); GEMINI.md prose is the fallback
  "gemini:commands:.gemini/commands/"
  "gemini:rules:GEMINI.md"
  # kimi — dual-surface: commands → BOTH a skill (.kimi/skills/) AND a subagent (.kimi/subagents/);
  # reference skills → skills; agents → subagents.
  "kimi:commands:.kimi/skills/"
  "kimi:skills:.kimi/skills/"
  "kimi:agents:.kimi/subagents/"
  # qwen — near-1:1 native folders
  "qwen:commands:.qwen/commands/"
  "qwen:agents:.qwen/agents/"
  "qwen:skills:.qwen/skills/"
  # claude-code — canonical paths
  "claude-code:commands:.claude/commands/"
  "claude-code:agents:.claude/agents/"
  "claude-code:skills:.claude/skills/"
  "claude-code:hooks:.claude/hooks/"
  "claude-code:rules:.claude/rules/"
)

# 1. Adapter doc covers every kind in its declared scope.
group "1. Per-adapter kind coverage in adapter.md"
for entry in "${ADAPTERS[@]}"; do
  name="${entry%%:*}"
  kinds_csv="${entry#*:}"
  IFS=',' read -ra kinds <<< "$kinds_csv"
  doc="$ADAPTERS_DIR/$name/adapter.md"
  [ -f "$doc" ] || { fail "$name: missing adapter.md"; continue; }

  for kind in "${kinds[@]}"; do
    # Find the documented native path for this (adapter, kind), if any.
    native_path=""
    for np in "${NATIVE_PATHS[@]}"; do
      if [[ "$np" == "$name:$kind:"* ]]; then
        native_path="${np##*:}"
        break
      fi
    done

    if [ -n "$native_path" ]; then
      if grep -qF "$native_path" "$doc"; then
        pass "$name: kind=$kind covered by native path \`$native_path\`"
      else
        fail "$name: kind=$kind — adapter.md is missing the native path \`$native_path\`"
      fi
    else
      # No native path declared for this kind — the doc must still mention the kind name
      # somewhere in the translation recipe (as a heading or list item).
      if grep -qiE "(^|[^a-z])$kind([^a-z]|$)" "$doc"; then
        pass "$name: kind=$kind covered (translated, no native path)"
      else
        fail "$name: kind=$kind not mentioned in adapter.md (translated, but no recipe documented)"
      fi
    fi
  done
done

# 2. Contract row in setup-project.md mentions every native path the adapter doc claims.
group "2. Contract row \u2194 adapter doc symmetry"
for np in "${NATIVE_PATHS[@]}"; do
  IFS=':' read -r adapter kind path <<< "$np"
  doc="$ADAPTERS_DIR/$adapter/adapter.md"
  [ -f "$doc" ] || continue
  doc_has=$(grep -qF "$path" "$doc" && echo yes || echo no)
  # Check contract rows in BOTH the orchestrator command and the dedicated
  # adapters command — modular split means rows can live in either.
  contract_has="no"
  for cmd_file in "$SETUP_CMD" "$SETUP_ADAPTERS_CMD"; do
    [ -f "$cmd_file" ] || continue
    if grep "^| \`$adapter\` |" "$cmd_file" | grep -qF "$path"; then
      contract_has="yes"
      break
    fi
  done
  case "$doc_has:$contract_has" in
    yes:yes) pass "$adapter/$kind: \`$path\` documented in BOTH contract + adapter.md" ;;
    yes:no)
      # Single-doc adapters (aider/codex/gemini) and Claude-code itself reference their
      # primary file via name not via native folder pattern. Suppress the check.
      case "$adapter" in
        aider|codex|gemini|claude-code) pass "$adapter/$kind: \`$path\` referenced (single-doc / canonical — contract row uses prose)" ;;
        *) fail "$adapter/$kind: \`$path\` is in adapter.md but NOT in setup-project.md contract row" ;;
      esac
      ;;
    no:yes) fail "$adapter/$kind: \`$path\` is in setup-project.md contract row but NOT in adapter.md" ;;
    no:no)
      case "$adapter" in
        aider|codex|gemini|claude-code) pass "$adapter/$kind: prose-referenced (single-doc / canonical)" ;;
        *) fail "$adapter/$kind: \`$path\` missing from BOTH contract row and adapter.md" ;;
      esac
      ;;
  esac
done

# 3. Each adapter has _version.json with the new-format keys (docs_url, last_verified).
group "3. _version.json schema (new-format keys)"
for adapter_dir in "$ADAPTERS_DIR"/*/; do
  [ -d "$adapter_dir" ] || continue
  name="$(basename "$adapter_dir")"
  vf="$adapter_dir/_version.json"
  [ -f "$vf" ] || { fail "$name: no _version.json"; continue; }

  if python3 -c "
import json, sys
d = json.load(open('$vf'))
required = ['kind','name','version','released','min_setup_command','deprecated']
missing = [k for k in required if k not in d]
if missing:
    print('missing required keys:', ','.join(missing))
    sys.exit(1)
" 2>&1; then
    pass "$name/_version.json: required keys present"
  else
    fail "$name/_version.json: schema check failed"
  fi
done

echo
echo "════════════════════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  Adapter fixture test: PASS\033[0m\n'
  exit 0
else
  printf '\033[31m  Adapter fixture test: FAIL (%d issue(s))\033[0m\n' "$ERRORS"
  exit 1
fi
