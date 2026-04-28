#!/usr/bin/env bash
# apply-pack.sh — apply a track to a target repo, deterministically.
#
# This is the M5 verification harness: the deterministic subset of Phase 4
# (4.0 preflight + 4.2.b copy + managed-marker wrapping). No model invocation;
# pure shell. Same input → same output. Re-running on the same target with
# the same source produces an empty diff.
#
# Usage:
#   apply-pack.sh <track-name> <target-repo> [--apply]
#
# Default mode is dry-run (prints plan; writes nothing).
# --apply actually writes.
#
# What it does
# ------------
# 1. Phase 4.0 preflight: verify track has detect.md + pack.md + meta.yaml;
#    verify pack.md frontmatter has at least one `emits:` entry.
# 2. For each unconditional emit in pack.md:
#    a. Resolve `from:` (relative to track dir).
#    b. Resolve `path:` (relative to target).
#    c. If source file missing → record as gap (not fail).
#    d. If merge mode is `managed-block` → wrap source in markers, write to target.
#    e. If merge mode is `managed-section` → not yet supported (M6+); skipped.
# 3. Write a per-track verification report to TARGET/.claude/_apply-pack-report.md.
#
# What it does NOT do (yet)
# -------------------------
# - Conditional emits (when:dep.has(...) etc.) are evaluated as "always include".
#   M6+ should evaluate against the target's actual deps.
# - `managed-section` merge mode (in-place section replacement). M6+.
# - Phase 4.6 anchoring (project-specific block injection — needs LLM).
# - Multi-track ordering / conflicts.
#
# Exit codes:
#   0 — applied (or dry-run completed) with no errors.
#   1 — preflight failed; nothing applied.
#   2 — usage error.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRACKS_ROOT="$REPO_ROOT/templates/tracks"

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <track-name> <target-repo> [--apply]"
  exit 2
fi

TRACK="$1"
TARGET="$2"
APPLY=0
[[ "${3:-}" == "--apply" ]] && APPLY=1

TRACK_DIR="$TRACKS_ROOT/$TRACK"
PACK_FILE="$TRACK_DIR/pack.md"
META_FILE="$TRACK_DIR/meta.yaml"

log()  { printf '%s\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
note() { printf '  note  %s\n' "$*"; }
err()  { printf '  ERR   %s\n' "$*" >&2; }

# ---------- Phase 4.0 preflight ----------
log "=== preflight: $TRACK ==="

if [[ ! -d "$TRACK_DIR" ]]; then
  err "track not found: $TRACK_DIR"
  exit 1
fi
ok "track dir exists"

for f in detect.md pack.md conventions.md meta.yaml; do
  if [[ -f "$TRACK_DIR/$f" ]]; then ok "$f present"; else err "$f missing"; exit 1; fi
done

# Get track version from meta.yaml
TRACK_VERSION=$(grep -E '^version:[[:space:]]+' "$META_FILE" | head -1 | sed -E 's/^version:[[:space:]]+(.*)$/\1/' | tr -d '"' | tr -d "'" | xargs)
[[ -z "$TRACK_VERSION" ]] && TRACK_VERSION="0.0.0"
ok "track version: $TRACK_VERSION"

if [[ ! -d "$TARGET" ]]; then
  err "target repo not found: $TARGET"
  exit 1
fi
ok "target exists: $TARGET"

# ---------- Parse pack.md emits ----------
# We need to parse a YAML-ish list under `emits:` and `emits-conditional:`.
# This is intentionally a small parser — only what apply-pack supports.

PACK_FM=$(awk '/^---[[:space:]]*$/ { c++; next } c==1' "$PACK_FILE")

# We use Python for YAML-ish parsing because pure bash is too brittle for nested
# inline records.
EMITS_JSON=$(python3 - "$PACK_FM" <<'PY'
import sys, re, json

fm = sys.argv[1]

# Walk lines under "emits:" until next top-level key.
emits = []
current = None
mode = None
for raw in fm.splitlines():
    line = raw.rstrip()
    stripped = line.lstrip()
    indent = len(line) - len(stripped)

    if not stripped or stripped.startswith("#"):
        continue

    if indent == 0 and stripped.endswith(":"):
        # top-level key
        key = stripped[:-1].strip()
        if key == "emits":
            mode = "unconditional"
        elif key == "emits-conditional":
            mode = "conditional"
        else:
            mode = None
        continue

    if mode is None:
        continue

    # New entry begins with "- " at indent 2
    if indent == 2 and stripped.startswith("- "):
        if current:
            emits.append(current)
        current = {"_kind": mode}
        rest = stripped[2:].strip()
        # The "- " line might already carry "key: value"
        if rest:
            m = re.match(r"^([a-z_-]+):\s*(.*)$", rest)
            if m:
                current[m.group(1)] = m.group(2).strip()
        continue

    if indent == 4 and current is not None:
        m = re.match(r"^([a-z_-]+):\s*(.*)$", stripped)
        if m:
            current[m.group(1)] = m.group(2).strip()

if current:
    emits.append(current)

print(json.dumps(emits))
PY
)

count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$EMITS_JSON")
log "emits parsed: $count"
[[ "$count" -eq 0 ]] && { err "pack.md has no emits"; exit 1; }

# ---------- Apply each emit ----------
log ""
log "=== apply: $TRACK -> $TARGET ==="
[[ "$APPLY" -eq 0 ]] && log "(dry run — pass --apply to write)"

REPORT="$TARGET/.claude/_apply-pack-report.md"
declare -a APPLIED
declare -a GAPS
declare -a UNSUPPORTED

# Helper to write managed-block file
write_managed_block() {
  local artifact_id="$1"
  local source_path="$2"
  local target_path="$3"

  if [[ "$APPLY" -eq 0 ]]; then
    log "  would-write $target_path (id=$artifact_id, source=$source_path)"
    return
  fi

  mkdir -p "$(dirname "$target_path")"
  {
    printf '<!-- setup-project:managed start id=%s v=%s track=%s -->\n' "$artifact_id" "$TRACK_VERSION" "$TRACK"
    cat "$source_path"
    printf '<!-- setup-project:managed end -->\n'
  } > "$target_path"
  log "  wrote $target_path"
}

i=0
while [[ "$i" -lt "$count" ]]; do
  entry=$(python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1])[$i]))" "$EMITS_JSON")
  i=$((i + 1))

  kind=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('_kind',''))" "$entry")
  path=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('path',''))" "$entry")
  src=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('from',''))" "$entry")
  merge=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('merge',''))" "$entry")
  section_id=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('section-id',''))" "$entry")

  log "[$i/$count] $kind: $path  (from=$src, merge=$merge)"

  if [[ -z "$path" || -z "$src" ]]; then
    note "skipped — missing path/from"
    continue
  fi

  source_path="$TRACK_DIR/$src"
  target_path="$TARGET/$path"

  if [[ ! -f "$source_path" ]]; then
    note "source missing — gap recorded"
    GAPS+=("$src -> $path")
    continue
  fi

  case "$merge" in
    managed-block)
      artifact_id="${TRACK}.$(echo "$path" | sed 's|^\.||; s|^/||' | tr '/' '.' | sed 's/\.md$//')"
      write_managed_block "$artifact_id" "$source_path" "$target_path"
      APPLIED+=("$path")
      ;;
    managed-section)
      note "managed-section not yet supported — skipped"
      UNSUPPORTED+=("$path (managed-section, id=$section_id)")
      ;;
    *)
      note "unknown merge mode '$merge' — skipped"
      UNSUPPORTED+=("$path (merge=$merge)")
      ;;
  esac
done

# ---------- Verification report ----------
if [[ "$APPLY" -eq 1 ]]; then
  mkdir -p "$(dirname "$REPORT")"
  {
    printf '# apply-pack report\n\n'
    printf 'track: %s\n' "$TRACK"
    printf 'version: %s\n' "$TRACK_VERSION"
    printf 'applied-at: %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '## Applied (%d)\n\n' "${#APPLIED[@]}"
    for a in "${APPLIED[@]:-}"; do [[ -n "$a" ]] && printf '%s\n' "- $a"; done
    printf '\n## Gaps (%d)\n\n' "${#GAPS[@]}"
    for g in "${GAPS[@]:-}"; do [[ -n "$g" ]] && printf '%s\n' "- $g"; done
    printf '\n## Unsupported (%d)\n\n' "${#UNSUPPORTED[@]}"
    for u in "${UNSUPPORTED[@]:-}"; do [[ -n "$u" ]] && printf '%s\n' "- $u"; done
  } > "$REPORT"
  log ""
  log "report: $REPORT"
fi

log ""
log "summary: ${#APPLIED[@]} applied / ${#GAPS[@]} gaps / ${#UNSUPPORTED[@]} unsupported"

[[ "$APPLY" -eq 0 ]] && log "dry run — re-run with --apply to write"

exit 0
