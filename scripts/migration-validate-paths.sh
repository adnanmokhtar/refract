#!/usr/bin/env bash
# migration-validate-paths.sh — gate proposed file paths through V2 conventions.
#
# Before /port-feature writes any file, run this to confirm:
#   - Path matches V2's module shape (src/modules/<feature>/{pages,components,...})
#   - Filename matches V2's naming convention (PascalCase + suffix for Vue,
#     camelCase + suffix for TS, etc. — derived from `.claude/codebase-profile.md`)
#   - File extension is one V2 actually uses (no surprise .jsx in a Vue project)
#   - Path doesn't accidentally write outside src/ + tests/ + public/
#
# What we do NOT validate (kept for content-aware tools):
#   - Imports / dependency direction (use a linter; outside our scope)
#   - Type coverage / strict-mode compliance (that's tsc / lint)
#
# Usage:
#   migration-validate-paths.sh <target> <feature-slug> <path1> [path2 ...]
#   echo -e "path1\npath2" | migration-validate-paths.sh <target> <feature> -
#
# Output:
#   stdout — one line per path: `<verdict>\t<path>\t<reason>`
#            verdict ∈ { ok, fail }
#   exit 0 — all paths pass
#   exit 1 — at least one fail
#   exit 2 — usage / target missing

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <target> <feature-slug> <path1> [path2 ...]" >&2
  echo "  or:  echo paths | $0 <target> <feature-slug> -" >&2
  exit 2
fi

TARGET="$1"; shift
FEATURE="$1"; shift

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 2; }

# Read paths
declare -a PATHS
if [[ "${1:-}" == "-" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] && PATHS+=("$p")
  done
else
  PATHS=("$@")
fi
[[ ${#PATHS[@]} -eq 0 ]] && exit 0

PROFILE="$TARGET/.claude/codebase-profile.md"
[[ -f "$PROFILE" ]] || { echo "ERR: $PROFILE not found — Phase 2 has not run; cannot validate paths against project conventions" >&2; exit 2; }

# ---------- Detect project conventions from codebase-profile.md ----------
#
# Module shape: capture pattern under "## 1. Architecture" or look for
# "src/modules/<m>/" / "src/features/<m>/" mentions.
MODULE_BASE=""
for candidate in "src/modules/" "src/features/" "src/app/" "app/(features)/"; do
  if grep -qF "$candidate" "$PROFILE" 2>/dev/null; then
    MODULE_BASE="$candidate"
    break
  fi
done
[[ -z "$MODULE_BASE" ]] && MODULE_BASE="src/modules/"

# Vue / React / Svelte / Angular detection from package.json + profile
STACK="unknown"
if grep -qE '\bvue\b' "$PROFILE" 2>/dev/null || [[ -f "$TARGET/vite.config.ts" && $(grep -c 'vue' "$TARGET/package.json" 2>/dev/null) -gt 0 ]]; then
  STACK="vue"
elif grep -qE '\breact\b|\bnext\b' "$PROFILE" 2>/dev/null; then
  STACK="react"
elif grep -qE '\bsvelte\b' "$PROFILE" 2>/dev/null; then
  STACK="svelte"
elif grep -qE '\bangular\b' "$PROFILE" 2>/dev/null; then
  STACK="angular"
fi

# Allowed kind subdirs under a module (read from existing modules — best signal)
KIND_DIRS=""
if [[ -d "$TARGET/${MODULE_BASE%/}" ]]; then
  # Sample: list immediate subdirs of an arbitrary module
  sample_module=$(find "$TARGET/${MODULE_BASE%/}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
  if [[ -n "$sample_module" ]]; then
    KIND_DIRS=$(find "$sample_module" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null \
                | grep -vE '^_|^\.' | sort -u | tr '\n' ' ')
  fi
fi
[[ -z "$KIND_DIRS" ]] && KIND_DIRS="pages components composables services types locales"

# Allowed top-level write zones (anything outside refused)
ALLOWED_TOP_DIRS="src tests test __tests__ public docs ai .claude"

# ---------- Helpers ----------
to_pascal() { echo "$1" | awk -F'[-_]' '{for(i=1;i<=NF;i++) printf "%s", toupper(substr($i,1,1)) substr($i,2); print ""}'; }
to_camel()  { local p; p=$(to_pascal "$1"); echo "$(echo "${p:0:1}" | tr 'A-Z' 'a-z')${p:1}"; }

PASCAL=$(to_pascal "$FEATURE")
CAMEL=$(to_camel "$FEATURE")
KEBAB="$FEATURE"

ok_count=0
fail_count=0

emit() {
  local verdict="$1" path="$2" reason="$3"
  printf '%s\t%s\t%s\n' "$verdict" "$path" "$reason"
  if [[ "$verdict" == "ok" ]]; then
    ok_count=$((ok_count + 1))
  else
    fail_count=$((fail_count + 1))
  fi
}

# ---------- Per-path validation ----------
for p in "${PATHS[@]}"; do
  rel="${p#./}"
  rel="${rel#$TARGET/}"

  # 1. Top-level dir whitelist
  top="${rel%%/*}"
  if [[ ! " $ALLOWED_TOP_DIRS " == *" $top "* ]]; then
    emit "fail" "$p" "writes outside allowed roots ($ALLOWED_TOP_DIRS); rejected"
    continue
  fi

  # 2. Module-shape conformance (only enforced for src/ paths matching MODULE_BASE)
  if [[ "$rel" == ${MODULE_BASE%/}/* ]]; then
    # Strip MODULE_BASE prefix → expect <feature>/<kind>/<file>
    rest="${rel#${MODULE_BASE}}"
    feat_dir="${rest%%/*}"
    rest_after="${rest#*/}"

    # Feature dir must match the slug (kebab/camel/pascal — accept any of project's idiom)
    if [[ "$feat_dir" != "$KEBAB" && "$feat_dir" != "$CAMEL" && "$feat_dir" != "$PASCAL" ]]; then
      emit "fail" "$p" "module dir '$feat_dir' doesn't match feature '$FEATURE'"
      continue
    fi

    # If the path has a kind subdir, validate against detected KIND_DIRS
    if [[ "$rest_after" == */* ]]; then
      kind="${rest_after%%/*}"
      if [[ ! " $KIND_DIRS " == *" $kind "* ]]; then
        emit "fail" "$p" "kind subdir '$kind' not in module shape ($KIND_DIRS)"
        continue
      fi
    fi
  fi

  # 3. Filename + extension validation by stack
  base="$(basename "$rel")"
  ext="${base##*.}"
  stem="${base%.$ext}"

  case "$ext" in
    vue)
      if [[ "$STACK" != "vue" ]]; then
        emit "fail" "$p" ".vue file in non-Vue project (detected stack: $STACK)"
        continue
      fi
      # Vue files: PascalCase + suffix
      if [[ ! "$stem" =~ ^[A-Z][a-zA-Z0-9]+(Page|DetailsPage|EditPage|Form|List|Card|Modal|Dialog|Tabs|Layout|View|Item)$ ]] \
         && [[ ! "$stem" =~ ^[A-Z][a-zA-Z0-9]+$ ]]; then
        emit "fail" "$p" "Vue filename '$stem' should be PascalCase + recognized suffix"
        continue
      fi
      ;;
    tsx|jsx)
      if [[ "$STACK" != "react" && "$STACK" != "next" ]]; then
        emit "fail" "$p" ".$ext in non-React project (detected stack: $STACK)"
        continue
      fi
      ;;
    ts|js|mjs|cjs)
      # TS/JS: camelCase or PascalCase. Composables use{Feature}, services {feature}Service, etc.
      if [[ ! "$stem" =~ ^(use[A-Z]|[a-z][a-zA-Z0-9]+|[A-Z][a-zA-Z0-9]+|index|routes|api|tabs|locales)$ ]]; then
        emit "fail" "$p" "TS/JS filename '$stem' doesn't match camelCase / PascalCase / known stem"
        continue
      fi
      ;;
    svelte)
      if [[ "$STACK" != "svelte" ]]; then
        emit "fail" "$p" ".svelte in non-Svelte project (detected stack: $STACK)"
        continue
      fi
      ;;
    md|json|yaml|yml|html|css|scss|sql|env|sh)
      # Pass-through; no naming rule
      ;;
    *)
      emit "fail" "$p" "unknown / unsupported extension .$ext"
      continue
      ;;
  esac

  # 4. Doesn't try to write into .git, .claude/backups, node_modules, dist, etc.
  case "$rel" in
    .git/*|node_modules/*|.next/*|dist/*|build/*|coverage/*|.claude/backups/*)
      emit "fail" "$p" "writes into a tooling / build / backup dir"
      continue
      ;;
  esac

  emit "ok" "$p" "passes module shape, naming, extension, and zone checks"
done

if [[ $fail_count -gt 0 ]]; then
  echo "" >&2
  echo "$fail_count of ${#PATHS[@]} path(s) violate V2 conventions; aborting write." >&2
  echo "Fix the paths or pass --override-paths (logged) to /port-feature." >&2
  exit 1
fi
echo "" >&2
echo "$ok_count path(s) pass all conformance checks." >&2
exit 0
