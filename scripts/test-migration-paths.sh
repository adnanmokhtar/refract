#!/usr/bin/env bash
# Migration regression test for legacy → native adapter shapes.
#
# WHY THIS EXISTS:
#   When an upstream tool ships a new native primitive (e.g. Cursor 2.3 added
#   .cursor/{skills,commands,hooks}/), pre-existing setups will have files at the legacy
#   path (.cursor/rules/{skill,command,agent}-*.mdc). Phase 4.8 / 4.8-DEEP must:
#     1. Document each legacy path as a "harmless fallback" (not an error).
#     2. Document the native path as the primary target.
#     3. Provide a migration path on --refresh.
#
#   Without these three guarantees, users who run --refine on a project with legacy outputs
#   silently get DUAL outputs (both legacy AND native files), and the lint table looks fine
#   while the user's tool sees confused duplicates.
#
# WHAT THIS SCRIPT CHECKS:
#   For each documented legacy → native migration, asserts the adapter doc:
#     A. Mentions the legacy path with framing like "legacy / pre-Apr-2026 / harmless fallback".
#     B. Mentions the native path as the documented target.
#     C. Documents the migration trigger (typically: "Phase 4.8 / 4.8-DEEP migrate ... on next refresh").
#
#   AND asserts setup-project.md Critical Execution Rule 4 mentions the anti-patterns
#   (cramming into rules/ instead of using native folders).
#
# Usage:  scripts/test-migration-paths.sh
# Exit:   0 = clean, 1 = drift detected

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTERS_DIR="$ROOT/templates/tool-adapters"
SETUP_CMD="$ROOT/commands/setup-project.md"
ERRORS=0
WARNINGS=0
fail()  { printf '\033[31m✗ %s\033[0m\n' "$*"; ERRORS=$((ERRORS+1)); }
pass()  { printf '\033[32m✓ %s\033[0m\n' "$*"; }
# Visible, but not a build break. Used where the original code's own comment said "flag it and let
# the maintainer add a note" and then called `pass`, so nothing was ever flagged.
warn()  { printf '\033[33m! %s\033[0m\n' "$*"; WARNINGS=$((WARNINGS+1)); }
info()  { printf '\033[36m• %s\033[0m\n' "$*"; }
group() { printf '\033[1m\n%s\033[0m\n' "$*"; }

echo "════════════════════════════════════════════════════════════════"
echo "  Migration paths regression — legacy → native shape"
echo "════════════════════════════════════════════════════════════════"

# Format: <adapter>|<legacy-pattern>|<native-path>|<change-rationale>
# legacy-pattern is matched as a literal substring in the adapter doc (use the fragment that
# the adapter author would actually put in prose, e.g. `command-<name>.mdc` rather than the
# fully assembled `.cursor/rules/command-` path).
MIGRATIONS=(
  "cursor|command-<name>.mdc|.cursor/commands/|Cursor 2.3 added native commands folder"
  "cursor|agent-<name>.mdc|.cursor/commands/agent-|Cursor 2.3 — agents translated as commands"
  "cursor|skill-<name>.mdc|.cursor/skills/|Cursor 2.3 added native skills folder"
  "cline|80-commands.md|.clinerules/workflows/|Cline added native workflows folder"
  "windsurf|80-commands.md|.windsurf/workflows/|Windsurf added native workflows folder"
  "continue|prompts:|.continue/prompts/|Continue added native prompts as files"
  "opencode|opencode.json|.opencode/agents/|OpenCode added .opencode/ native agent folder"
  "opencode|opencode.json|.opencode/commands/|OpenCode added .opencode/ native command folder"
  "opencode|~/.claude/skills/|.opencode/skills/|OpenCode added repo-local skills folder"
  "copilot|.github/prompts/*.prompt.md|.github/agents/|Copilot Apr-2026 GA added native agents folder"
  "copilot|.github/prompts/*.prompt.md|.github/skills/|Copilot Apr-2026 GA added native skills folder"
)

# 1. For each migration, the adapter doc must:
#    A. Mention the legacy path
#    B. Mention the native path
#    C. Frame the legacy as backward-compat / harmless fallback / migration
group "1. Per-migration completeness in adapter docs"
for m in "${MIGRATIONS[@]}"; do
  IFS='|' read -r adapter legacy native rationale <<< "$m"
  doc="$ADAPTERS_DIR/$adapter/adapter.md"
  [ -f "$doc" ] || { fail "$adapter: missing adapter.md"; continue; }

  has_legacy=$(grep -qF "$legacy" "$doc" && echo yes || echo no)
  has_native=$(grep -qF "$native" "$doc" && echo yes || echo no)

  # Migration framing — at least ONE of these phrases must appear NEAR the legacy path.
  # Window: 12 lines after first occurrence of the legacy path.
  has_framing=no
  if [ "$has_legacy" = "yes" ]; then
    snippet=$(grep -A 12 -F "$legacy" "$doc" | head -20)
    if echo "$snippet" | grep -qiE "(legacy|backward[- ]?compat|harmless fallback|pre-Apr-2026|Phase 4\.8|on next refresh|migrate)"; then
      has_framing=yes
    fi
  fi

  case "$has_legacy:$has_native:$has_framing" in
    yes:yes:yes)
      pass "$adapter: legacy=\`$legacy\` migrates to native=\`$native\` ($rationale)"
      ;;
    no:yes:*)
      # The comment said "flag it and let the maintainer add an explicit note", and then called
      # `pass` — so nothing was ever flagged and no note was ever prompted for. A warn is what the
      # comment describes: visible, and not a build break for a genuinely new adapter.
      warn "$adapter: native=\`$native\` documented, but no legacy path (\`$legacy\`) is called out — add an explicit note if this adapter ever had prior users"
      ;;
    yes:no:*)
      fail "$adapter: legacy=\`$legacy\` mentioned but native=\`$native\` is NOT documented"
      ;;
    yes:yes:no)
      fail "$adapter: legacy=\`$legacy\` and native=\`$native\` both mentioned, but no migration framing nearby (legacy/backward-compat/harmless-fallback/migrate)"
      ;;
    no:no:*)
      fail "$adapter: neither legacy=\`$legacy\` nor native=\`$native\` is documented for migration \"$rationale\""
      ;;
  esac
done

# 2. setup-project.md Critical Execution Rule 4 documents the native-shape anti-patterns.
group "2. Critical Execution Rule 4 — anti-pattern enumeration"
# "legacy" and "native" appear in any engineering prose, so asserting their presence asserted
# nothing — there is no realistic input where those two fail. Keep only the phrases that are
# specific to this rule's subject.
for keyword in "anti-pattern" "thin stub"; do
  if grep -qiF "$keyword" "$SETUP_CMD"; then
    pass "setup-project.md mentions: $keyword"
  else
    fail "setup-project.md missing keyword: $keyword (Rule 4 should call this out)"
  fi
done

# Critical Execution Rule 4 must specifically warn about the .cursor/rules/command- pattern.
if grep -qF ".cursor/rules/command-" "$SETUP_CMD"; then
  pass "setup-project.md Rule 4 specifically calls out the .cursor/rules/command- legacy anti-pattern"
else
  fail "setup-project.md Rule 4 missing the canonical legacy anti-pattern warning (\`.cursor/rules/command-\`)"
fi

# 3. The standalone-tool guarantee phrase appears in tool-adapters/_registry.md AND
#    setup-project.md (signals consistency of intent across spec + registry).
group "3. Standalone-tool guarantee — cross-doc presence"
for f in \
  "templates/tool-adapters/_registry.md" \
  "commands/setup-project.md" \
  "templates/tool-adapters/README.md"
do
  if grep -qiE "(standalone[- ]tool|standalone goal|without .claude/)" "$ROOT/$f"; then
    pass "$f mentions standalone-tool guarantee"
  else
    fail "$f missing standalone-tool guarantee phrasing"
  fi
done

echo
echo "════════════════════════════════════════════════════════════════"
if [ "$ERRORS" -eq 0 ]; then
  printf '\033[32m  Migration regression: PASS (%d migrations validated)\033[0m\n' "${#MIGRATIONS[@]}"
  exit 0
else
  printf '\033[31m  Migration regression: FAIL (%d issue(s))\033[0m\n' "$ERRORS"
  exit 1
fi
