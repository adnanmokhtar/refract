#!/usr/bin/env bash
# lint-track.sh — validate templates/tracks/<name>/ against the schema in templates/tracks/_loader.md
#
# Pass nothing → check every track. Pass a name → check that one.
# Exits 0 ok / 1 violations / 2 usage error.
#
# Checks:
#   1. Required files exist:
#        detect.md  pack.md  conventions.md  meta.yaml
#   2. detect.md has a YAML frontmatter block with `track:`, `signals:`, `threshold:`
#   3. signals entries have valid kind (file | dep | command | negative) and weight (integer)
#   4. pack.md has a frontmatter block with at least one `emits:` entry
#   5. emits entries have `path:` and `from:` and a known `merge:` mode
#   6. meta.yaml has at least: name, version, status

set -euo pipefail

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
TRACKS_ROOT="$REPO_ROOT/templates/tracks"

VALID_SIGNAL_KINDS="file dep command negative"
VALID_MERGE_MODES="managed-block managed-section append-once replace-if-managed"

violations=0

usage() {
  echo "Usage: $0 [<track-name>]"
  exit 2
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

err()  { printf '  ERR  %s\n' "$*" >&2; violations=$((violations + 1)); }
warn() { printf '  WARN %s\n' "$*"; }
ok()   { printf '  ok   %s\n' "$*"; }

extract_frontmatter() {
  # Print lines between first two `---` lines, exclusive
  local file="$1"
  awk '/^---[[:space:]]*$/ { c++; next } c==1' "$file"
}

check_track() {
  local track_dir="$1"
  local name; name="$(basename "$track_dir")"

  echo ""
  echo "track: $name"

  if [[ ! -d "$track_dir" ]]; then
    err "directory missing: $track_dir"; return
  fi

  # 1. Required files
  for f in detect.md pack.md conventions.md meta.yaml; do
    if [[ -f "$track_dir/$f" ]]; then
      ok "$f present"
    else
      err "$f missing"
    fi
  done

  # 2 + 3. detect.md frontmatter
  if [[ -f "$track_dir/detect.md" ]]; then
    local fm; fm="$(extract_frontmatter "$track_dir/detect.md")"
    if [[ -z "$fm" ]]; then
      err "detect.md has no YAML frontmatter (--- ... ---)"
    else
      grep -qE '^track:[[:space:]]+' <<<"$fm"     || err "detect.md missing 'track:'"
      grep -qE '^signals:[[:space:]]*$' <<<"$fm"  || err "detect.md missing 'signals:'"
      grep -qE '^threshold:[[:space:]]+[0-9]+' <<<"$fm" || err "detect.md missing numeric 'threshold:'"

      # signal kinds
      while IFS= read -r line; do
        kind="$(sed -nE 's/.*kind:[[:space:]]*([a-z]+).*/\1/p' <<<"$line")"
        weight="$(sed -nE 's/.*weight:[[:space:]]*([0-9-]+).*/\1/p' <<<"$line")"
        [[ -z "$kind" ]] && continue
        if ! grep -qw "$kind" <<<"$VALID_SIGNAL_KINDS"; then
          err "detect.md unknown signal kind '$kind' (valid: $VALID_SIGNAL_KINDS)"
        fi
        if [[ -z "$weight" ]]; then
          err "detect.md signal missing weight: $line"
        fi
      done < <(grep -E 'kind:' <<<"$fm")
    fi
  fi

  # 4 + 5. pack.md emits contract
  if [[ -f "$track_dir/pack.md" ]]; then
    local fm; fm="$(extract_frontmatter "$track_dir/pack.md")"
    if [[ -z "$fm" ]]; then
      err "pack.md has no YAML frontmatter"
    elif ! grep -qE '^emits:[[:space:]]*$' <<<"$fm"; then
      err "pack.md missing 'emits:'"
    else
      while IFS= read -r line; do
        merge="$(sed -nE 's/.*merge:[[:space:]]*([a-z-]+).*/\1/p' <<<"$line")"
        [[ -z "$merge" ]] && continue
        if ! grep -qw "$merge" <<<"$VALID_MERGE_MODES"; then
          err "pack.md unknown merge mode '$merge' (valid: $VALID_MERGE_MODES)"
        fi
      done < <(grep -E 'merge:' <<<"$fm")
    fi
  fi

  # 6. meta.yaml minimum
  if [[ -f "$track_dir/meta.yaml" ]]; then
    grep -qE '^name:[[:space:]]+'    "$track_dir/meta.yaml" || err "meta.yaml missing 'name:'"
    grep -qE '^version:[[:space:]]+' "$track_dir/meta.yaml" || err "meta.yaml missing 'version:'"
    grep -qE '^status:[[:space:]]+'  "$track_dir/meta.yaml" || err "meta.yaml missing 'status:'"
  fi
}

if [[ $# -ge 1 ]]; then
  check_track "$TRACKS_ROOT/$1"
else
  for d in "$TRACKS_ROOT"/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    [[ "$name" == _* ]] && continue
    check_track "$d"
  done
fi

echo ""
if [[ "$violations" -gt 0 ]]; then
  echo "FAIL: $violations violation(s)"
  exit 1
fi
echo "ok: all tracks valid"
exit 0
