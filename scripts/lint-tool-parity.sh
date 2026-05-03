#!/usr/bin/env bash
# Lint cross-doc consistency for the tool-adapter matrix.
#
# Catches drift between:
#   - templates/tool-adapters/_registry.md           (capability matrix, source of truth for keys + caps)
#   - templates/tool-adapters/README.md              (10-adapter list)
#   - templates/repo-baseline/ai/references/tool-parity.md (consumer-facing parity matrix)
#   - templates/tool-adapters/<key>/adapter.md       (each adapter exists + has _version.json)
#
# Exit code: 0 = clean, 1 = drift detected.
#
# Requires bash 4+ (associative arrays). macOS ships bash 3.2 — install via `brew install bash`.

set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTERS_DIR="$ROOT/templates/tool-adapters"
REGISTRY="$ADAPTERS_DIR/_registry.md"
README="$ADAPTERS_DIR/README.md"
PARITY="$ROOT/templates/repo-baseline/ai/references/tool-parity.md"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }

ERRORS=0
fail() { red "✗ $*"; ERRORS=$((ERRORS+1)); }
pass() { green "✓ $*"; }

# 1. Collect adapter folder names (each must have adapter.md + _version.json).
declare -a ADAPTERS=()
for d in "$ADAPTERS_DIR"/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  ADAPTERS+=("$name")
  [ -f "$d/adapter.md"     ] || fail "$name: missing adapter.md"
  [ -f "$d/_version.json"  ] || fail "$name: missing _version.json"
done

ADAPTER_COUNT=${#ADAPTERS[@]}
echo "Found $ADAPTER_COUNT adapter folders: ${ADAPTERS[*]}"

# 2. _registry.md must mention every adapter key.
for a in "${ADAPTERS[@]}"; do
  if ! grep -q "\`$a\`" "$REGISTRY"; then
    fail "_registry.md: adapter \`$a\` not listed in the matrix"
  fi
done

# 3. README.md must mention every adapter key.
for a in "${ADAPTERS[@]}"; do
  if ! grep -q "\`$a/\`" "$README"; then
    fail "README.md: adapter \`$a/\` not listed"
  fi
done

# 4. tool-parity.md must have a column header per adapter (case-insensitive label match).
parity_label_for() {
  case "$1" in
    aider)        echo "Aider" ;;
    claude-code)  echo "Claude Code" ;;
    cline)        echo "Cline" ;;
    codex)        echo "Codex" ;;
    continue)     echo "Continue" ;;
    copilot)      echo "Copilot" ;;
    cursor)       echo "Cursor" ;;
    gemini)       echo "Gemini" ;;
    kimi)         echo "Kimi" ;;
    opencode)     echo "OpenCode" ;;
    qwen)         echo "Qwen" ;;
    windsurf)     echo "Windsurf" ;;
    *)            echo "" ;;
  esac
}
for a in "${ADAPTERS[@]}"; do
  label="$(parity_label_for "$a")"
  if [ -z "$label" ]; then
    yellow "  (no parity-label mapping for adapter \`$a\` — add to lint-tool-parity.sh)"
    continue
  fi
  if ! grep -qi "$label" "$PARITY"; then
    fail "tool-parity.md: column for \`$a\` ($label) not found"
  fi
done

# 5. Cross-doc count consistency: README.md says "10 adapters" — make it match the actual count.
DOCUMENTED_COUNT=$(grep -oE 'The [0-9]+ adapters' "$README" | grep -oE '[0-9]+' | head -1)
if [ -n "$DOCUMENTED_COUNT" ] && [ "$DOCUMENTED_COUNT" != "$ADAPTER_COUNT" ]; then
  fail "README.md says '$DOCUMENTED_COUNT adapters' but $ADAPTER_COUNT folders exist"
fi

# 6. Phase 4.8.0 contract presence (sanity).
# Table lives in setup-project-adapters.md (M2 split — see commands/setup-project-adapters.md § Phase B).
SETUP_CMD="$ROOT/commands/setup-project-adapters.md"
for a in "${ADAPTERS[@]}"; do
  if ! grep -q "^| \`$a\`" "$SETUP_CMD"; then
    fail "setup-project-adapters.md Phase 4.8.0: no contract row for \`$a\`"
  fi
done

# 6b. Native-folder mentions in Phase 4.8.0 contract — guards against drift back to legacy shapes.
# Each entry: <adapter-key>:<native-path-fragment-that-MUST-appear-in-the-contract-row>
declare -a NATIVE_PATHS=(
  "cursor:.cursor/commands/"
  "cursor:.cursor/skills/"
  "cursor:.cursor/hooks.json"
  "opencode:.opencode/agents/"
  "opencode:.opencode/commands/"
  "opencode:.opencode/skills/"
  "copilot:.github/prompts/"
  "copilot:.github/agents/"
  "copilot:.github/skills/"
  "cline:.clinerules/workflows/"
  "windsurf:.windsurf/workflows/"
  "continue:.continue/prompts/"
)
for entry in "${NATIVE_PATHS[@]}"; do
  adapter="${entry%%:*}"
  path="${entry#*:}"
  # Scan ALL `| \`<adapter>\` |` rows in setup-project-adapters.md (several tables share the key column).
  if ! grep "^| \`$adapter\` |" "$SETUP_CMD" | grep -qF "$path"; then
    fail "setup-project-adapters.md Phase 4.8.0 contract for \`$adapter\` is missing native path \`$path\` — drift back to legacy shape?"
  fi
done

# 6c. Adapter docs must mention their native folders too.
declare -a NATIVE_PATHS_IN_ADAPTERS=(
  "cursor:.cursor/commands/"
  "cursor:.cursor/skills/"
  "cursor:.cursor/hooks.json"
  "opencode:.opencode/agents/"
  "opencode:.opencode/commands/"
  "opencode:.opencode/skills/"
  "copilot:.github/agents/"
  "copilot:.github/skills/"
  "cline:.clinerules/workflows/"
  "windsurf:.windsurf/workflows/"
  "continue:.continue/prompts/"
)
for entry in "${NATIVE_PATHS_IN_ADAPTERS[@]}"; do
  adapter="${entry%%:*}"
  path="${entry#*:}"
  doc="$ADAPTERS_DIR/$adapter/adapter.md"
  [ -f "$doc" ] || continue
  if ! grep -qF "$path" "$doc"; then
    fail "$adapter/adapter.md is missing native path \`$path\` — adapter doc drifted from Phase 4.8.0 contract"
  fi
done

# 7. Track-count drift across docs.
PACKS_DIR="$ROOT/templates/packs"
TRACK_COUNT=0
while IFS= read -r d; do
  base="$(basename "$d")"
  case "$base" in
    _*|README.md) continue ;;
  esac
  TRACK_COUNT=$((TRACK_COUNT+1))
done < <(find "$PACKS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

# Files that should mention the track count consistently.
README="$ROOT/README.md"
CHEAT="$ROOT/docs/setup-project-cheatsheet.md"

# Look for any "<digit><digit> tracks" mention in the canonical docs and check it matches.
for f in "$README" "$CHEAT"; do
  [ -f "$f" ] || continue
  WRONG=$(grep -oE '\b[0-9]+ tracks?\b' "$f" | grep -vE "^${TRACK_COUNT} tracks?\$" || true)
  if [ -n "$WRONG" ]; then
    rel="$(echo "$f" | sed "s|$ROOT/||")"
    fail "$rel: track-count drift — found '$(echo "$WRONG" | tr '\n' ',' | sed 's/,$//')'; actual count is $TRACK_COUNT"
  fi
done

echo
if [ "$ERRORS" -eq 0 ]; then
  green "Tool-parity lint: PASS ($ADAPTER_COUNT adapters + $TRACK_COUNT tracks consistent across registry, README, parity matrix, and 4.8.0 contract)"
  exit 0
else
  red "Tool-parity lint: FAIL ($ERRORS issue(s))"
  exit 1
fi
