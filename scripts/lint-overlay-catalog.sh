#!/usr/bin/env bash
# lint-overlay-catalog.sh — the regulatory-overlay catalog must not promise a file that
# does not exist, and must not hide a file that does.
#
# The bug this gate was written to prevent recurring: HIPAA was detected by the technical-signal
# registry and named in the Phase 2 detection appendix, but `templates/regulatory-overlays/hipaa.md`
# was never authored — a healthcare project tripped the detection and received nothing but a
# research stub. Same class as `verify-doc-sync.sh` (command ↔ doc) and `lint-validator-parity.sh`
# (doc-promised gate ↔ defined check), applied to the overlay axis.
#
# Checks:
#   [1] TABLE SHAPE   — every catalog row in the Phase 4.4b.1 overlay table carries an explicit
#                       [SHIPPED] / [PLANNED] status cell. A row with the status column missing
#                       reads as shipped to a human and as nothing to a script.
#   [2] SHIPPED⇒DISK  — every [SHIPPED] row names a file that exists.
#   [3] DISK⇒SHIPPED  — every overlay file on disk has a [SHIPPED] row (no orphan overlays that
#                       Phase 4.4b.1 will never select).
#   [4] CROSS-REFS    — an overlay that cites a sibling `<regime>.md` either has it on disk or
#                       qualifies the citation ("planned — not yet shipped"). Same honesty
#                       contract lint-validator-parity.sh applies to check_* citations.
#
# Usage:  lint-overlay-catalog.sh [--repo-root=<dir>]
# Exit:   1 on any FAIL; 0 otherwise.
# Notes:  bash 3.2 (macOS) compatible — no associative arrays, mapfile, or ${var,,}.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root=*) REPO_ROOT="${1#*=}"; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
cd "$REPO_ROOT" || exit 1

OVERLAY_DIR="templates/regulatory-overlays"
CATALOG="templates/phases/phase-4.2-apply.md"
QUALIFIER='planned|PLANNED|not yet shipped|not yet authored'

fails=0

echo "=== lint-overlay-catalog ==="
echo "Repo: $REPO_ROOT"
echo ""

[ -f "$CATALOG" ] || { echo "FAIL  catalog file missing: $CATALOG"; exit 1; }
[ -d "$OVERLAY_DIR" ] || { echo "FAIL  overlay dir missing: $OVERLAY_DIR"; exit 1; }

# Catalog rows: `| <regime> | \`regulatory-overlays/<file>.md\` | <status> | <affinity> |`
ROWS=$(grep -nE '^\|[^|]*\|[[:space:]]*`regulatory-overlays/[a-z0-9./-]+\.md`' "$CATALOG" || true)

echo "[1] catalog rows carry an explicit status cell"
shape_ok=1
while IFS= read -r row; do
  [ -n "$row" ] || continue
  ln="${row%%:*}"
  body="${row#*:}"
  status=$(printf '%s\n' "$body" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$4); print $4}')
  case "$status" in
    '[SHIPPED]'|'[PLANNED]') ;;
    *)
      echo "  FAIL  $CATALOG:$ln — status cell is '$status' (want [SHIPPED] or [PLANNED]): ${body:0:90}"
      fails=$((fails + 1)); shape_ok=0 ;;
  esac
done <<EOF
$ROWS
EOF
[ "$shape_ok" -eq 1 ] && echo "  ok — every catalog row states [SHIPPED] or [PLANNED]"

echo "[2] every [SHIPPED] row exists on disk"
shipped_files=""
ship_ok=1
while IFS= read -r row; do
  [ -n "$row" ] || continue
  ln="${row%%:*}"
  body="${row#*:}"
  printf '%s\n' "$body" | grep -q '\[SHIPPED\]' || continue
  rel=$(printf '%s\n' "$body" | grep -oE 'regulatory-overlays/[a-z0-9./-]+\.md' | head -1)
  shipped_files="$shipped_files $(basename "$rel")"
  if [ ! -f "templates/$rel" ]; then
    echo "  FAIL  $CATALOG:$ln — [SHIPPED] but templates/$rel does not exist"
    fails=$((fails + 1)); ship_ok=0
  fi
done <<EOF
$ROWS
EOF
[ "$ship_ok" -eq 1 ] && echo "  ok — every [SHIPPED] overlay is on disk"

echo "[3] every overlay on disk is a [SHIPPED] row"
disk_ok=1
for f in "$OVERLAY_DIR"/*.md; do
  [ -f "$f" ] || continue
  b=$(basename "$f")
  case "$b" in _*) continue ;; esac
  case " $shipped_files " in
    *" $b "*) ;;
    *)
      echo "  FAIL  $f — on disk but no [SHIPPED] row in $CATALOG (Phase 4.4b.1 will never select it)"
      fails=$((fails + 1)); disk_ok=0 ;;
  esac
done
[ "$disk_ok" -eq 1 ] && echo "  ok — no orphan overlay files"

echo "[4] overlay cross-references resolve or disclose"
xref_ok=1
for f in "$OVERLAY_DIR"/*.md; do
  [ -f "$f" ] || continue
  self=$(basename "$f")
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    ln="${hit%%:*}"
    body="${hit#*:}"
    for ref in $(printf '%s\n' "$body" | grep -oE '`[a-z0-9-]+\.md`' | tr -d '`' | sort -u); do
      [ "$ref" = "$self" ] && continue
      [ -f "$OVERLAY_DIR/$ref" ] && continue
      if printf '%s\n' "$body" | grep -qE "$QUALIFIER"; then continue; fi
      echo "  FAIL  $f:$ln — cites \`$ref\` which is not on disk and carries no (planned — not yet shipped) qualifier"
      fails=$((fails + 1)); xref_ok=0
    done
  done < <(grep -nE '`[a-z0-9-]+\.md`' "$f" || true)
done
[ "$xref_ok" -eq 1 ] && echo "  ok — every sibling-overlay citation resolves or discloses"

echo ""
echo "overlay-catalog: FAIL=$fails"
[ "$fails" -eq 0 ] || exit 1
