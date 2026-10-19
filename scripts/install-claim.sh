#!/usr/bin/env bash
# install-claim.sh — copy one pack's (or domain's) files of one kind into a project, first claim
# wins, and HALT on a same-name / different-content collision inside one install run.
#
# WHY. The pack copy loops in phase-4.2-apply.md were first-claim-wins with a log line, and the
# domain copy was a bare `cp -Rn`. Two templates shipping one name with different bytes was
# therefore resolved by install ORDER, in silence: measured 2026-10-19, `domains/auth`'s
# auth-reviewer and `domains/multi-tenant`'s tenant-isolation-reviewer vanished on every install
# that also had the security pack, and `testing`'s test-engineer on every install at all (delivery
# applies first). Two files with one `name:` is an undefined registration; which one a project
# gets must never depend on the order its packs happened to be applied in.
#
# THE RULE (PLAN.md §6). Each copied file is recorded as `kind<TAB>name<TAB>source<TAB>sha256`
# in <target>/.claude/_install-claims.tsv for THIS run (`--reset` truncates it at run start).
# Before copying <kind>/<name>:
#   (a) not on disk                                    → copy it and claim it
#   (b) on disk, claimed in THIS run by another source,
#       with different content                         → COLLISION: exit 4, NOTHING of this
#                                                        source is copied (pre-pass, no partial copy)
#   (c) on disk, not claimed in this run (the owner's
#       file, or an earlier run's)                     → keep it, report `<kind>-skip` (unchanged
#                                                        merge-matrix behaviour: an owner edit is
#                                                        not a collision)
#   (d) identical content                              → no-op
# Commands are NOT handled here: a second pack's command of the same name is a deliberate
# `<name>.<track>.md` variant (docs/CHEATSHEET.md), installed by phase-4.2-apply.md's own loop.
#
# Usage:  install-claim.sh <target-repo> --reset
#         install-claim.sh <target-repo> <kind> <source-label> <src-dir> [<dest-dir>]
#           kind          agents | lenses | rules | ai-patterns (flat *.md files)
#           source-label  the pack or domain name (`security`, `domain:auth`)
#           dest-dir      default <target>/.claude/<kind> (ai-patterns → <target>/ai/patterns)
# Exit:   0 done (copies, skips and no-ops reported) · 4 collision (nothing copied) · 2 usage
set -uo pipefail
export LC_ALL=C

T="${1:-}"; [ -n "$T" ] && [ -d "$T" ] || { echo "usage: install-claim.sh <target-repo> --reset | <kind> <source> <src-dir> [dest-dir]" >&2; exit 2; }
CLAIMS="$T/.claude/_install-claims.tsv"
mkdir -p "$T/.claude"
if [ "${2:-}" = "--reset" ]; then : > "$CLAIMS"; exit 0; fi
KIND="${2:-}"; SRCLABEL="${3:-}"; SRC="${4:-}"; DEST="${5:-}"
[ -n "$KIND" ] && [ -n "$SRCLABEL" ] && [ -n "$SRC" ] || { echo "usage: install-claim.sh <target-repo> <kind> <source> <src-dir> [dest-dir]" >&2; exit 2; }
case "$KIND" in agents|lenses|rules|ai-patterns) ;; *) echo "install-claim: kind '$KIND' not handled here (commands use the variant rule)" >&2; exit 2 ;; esac
if [ -z "$DEST" ]; then
  if [ "$KIND" = ai-patterns ]; then DEST="$T/ai/patterns"; else DEST="$T/.claude/$KIND"; fi
fi
[ -d "$SRC" ] || exit 0            # a pack without this kind: nothing to do
[ -f "$CLAIMS" ] || : > "$CLAIMS"

sha() { if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1; else sha256sum "$1" | cut -d' ' -f1; fi; }
claimed_by() {   # $1 = name → "<source>\t<sha>" of the first claim of kind/name in this run, or ""
  awk -F'\t' -v k="$KIND" -v n="$1" '$1==k && $2==n { print $3 "\t" $4; exit }' "$CLAIMS"
}

# ---- pre-pass: decide every file before copying any, so a collision leaves no partial copy ----
plan="$(mktemp "${TMPDIR:-/tmp}/install-claim.XXXXXX")"; trap 'rm -f "$plan"' EXIT
collisions=0
for f in "$SRC"/*.md; do
  [ -f "$f" ] || continue
  n="$(basename "$f")"; name="${n%.md}"
  case "$name" in _*) continue ;; esac            # _topics.md, _essentials.md: pack metadata, not artifacts
  s="$(sha "$f")"; d="$DEST/$n"
  if [ ! -e "$d" ]; then printf 'copy\t%s\t%s\t%s\n' "$f" "$name" "$s" >> "$plan"; continue; fi
  if [ "$(sha "$d")" = "$s" ]; then printf 'same\t%s\t%s\t%s\n' "$f" "$name" "$s" >> "$plan"; continue; fi
  c="$(claimed_by "$name")"; cowner="$(printf '%s' "$c" | cut -f1)"
  if [ -n "$c" ] && [ "$cowner" != "$SRCLABEL" ]; then
    echo "COLLISION ${KIND%s} '$name': $cowner and $SRCLABEL ship different content — fix the templates (rename or merge); see scripts/_agent-merge-map.json" >&2
    collisions=$((collisions + 1)); continue
  fi
  printf 'skip\t%s\t%s\t%s\n' "$f" "$name" "$s" >> "$plan"
done
if [ "$collisions" -gt 0 ]; then
  echo "HALT: $collisions same-name collision(s) — nothing from $SRCLABEL/$KIND was copied" >&2
  exit 4
fi

# ---- apply ----
mkdir -p "$DEST"
while IFS="$(printf '\t')" read -r act f name s; do
  case "$act" in
    copy) cp "$f" "$DEST/$name.md"; printf '%s\t%s\t%s\t%s\n' "$KIND" "$name" "$SRCLABEL" "$s" >> "$CLAIMS" ;;
    same) [ -n "$(claimed_by "$name")" ] || printf '%s\t%s\t%s\t%s\n' "$KIND" "$name" "$SRCLABEL" "$s" >> "$CLAIMS" ;;
    skip) echo "  ${KIND%s}-skip: '$name' already in the project (not installed by this run) — $SRCLABEL's copy NOT installed; the project's file is kept"
          printf '%s\n' "- ${KIND%s} \`$name\` — $SRCLABEL's copy skipped; the project already carries a different file of that name (owner edit or an earlier run)." \
            >> "$T/.claude/_command-variants.md" ;;
  esac
done < "$plan"
exit 0
