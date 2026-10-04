#!/usr/bin/env bash
# scope-rules.sh — inject a `paths:` glob into rule frontmatter so a rule loads
# only when Claude touches a matching file (native Claude Code path-scoped rules).
#
# Used by Phase 4.2 apply to scope TRACK/DOMAIN rules to their detected source root,
# preventing cross-track context pollution in full-stack / monorepo projects.
# Core baseline rules (read-before-write, code-quality, …) are universal — do NOT scope them.
#
# Usage:   scope-rules.sh <rule-file-or-dir> <glob>[,<glob>...]
# Example: scope-rules.sh .claude/rules/frontend-principles.md "apps/web/**,packages/ui/**"
#          scope-rules.sh .claude/rules/backend-principles.md "src/server/**"
#
# Idempotent: a rule that already declares `paths:` is left unchanged — with ONE exception, the
# pack's own source default (below), which this replaces.
#
# 🔴 A SOURCE DEFAULT IS REPLACEABLE; A `paths:` SOMEBODY WROTE IS NOT.
#
# Pack and domain rules ship a conservative `paths:` at source (the stack's source + config file
# shapes), so a rule nobody scoped no longer loads in every session. That default is marked by the
# line `paths-origin: pack-default-<sha8>`, where <sha8> = first 8 hex of sha1 over the globs, one
# per line, each newline-terminated. This script REPLACES (narrows) the block only while both hold:
# the marker is present AND its hash still matches the globs. An owner who edits the globs without
# deleting the marker therefore keeps the edit (the hash no longer matches), and an owner-written
# block — no marker — is never touched. Before this exception existed, a source `paths:` would have
# made every project-specific scoping pass skip the rule as "already scoped", and Phase 4.2's
# track-root scoping would have stopped working on every multi-track install.
# Fixture: scripts/test-rule-loading.sh § 5.

set -uo pipefail

target="${1:?usage: scope-rules.sh <file|dir> <glob[,glob...]>}"
globs="${2:?usage: scope-rules.sh <file|dir> <glob[,glob...]>}"

# 🔴 BLOCK LIST, NOT FLOW SEQUENCE. THE HOOK CAN ONLY READ ONE OF THEM.
#
# This wrote `paths: ["a/**", "b/**"]`. The consumer — inject-path-rules.sh `rule_globs()` —
# walks the frontmatter for `^paths:` and then reads the `- item` lines beneath it. Given a
# flow sequence it finds the key, finds no `- ` lines, and returns NOTHING.
#
# 📏 A rule scoped by this script therefore loaded NEVER. wire-rule-imports.sh sees the
# `paths:` key and correctly drops it from the CLAUDE.md always-loaded imports; the hook then
# cannot match it, so it is never injected either. Both tiers disown it and the file sits on
# disk looking configured. Measured on a fixture: `scope-rules.sh … "**/payment*/**"` then
# rule_globs → 0 globs.
#
# What makes it worse than a normal bug is WHOSE advice it is. wire-rule-imports.sh prints
# this exact command as the remedy when a rule will not fit the budget, and audit-setup.sh
# repeats it. Anyone who followed the framework's own instruction silently deleted the rule
# they were trying to keep — and the audit's own note about the path-scoped tier being "dead"
# was written about the hook not being registered. It was registered. This was the other half.
#
# The nine scoped rules on the live projects are all block form, written by project
# generation rather than by this script, which is why the breakage never surfaced there.
yaml_block() {
  local g
  IFS=',' read -ra parts <<< "$1"
  for g in "${parts[@]}"; do
    g="$(echo "$g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$g" ] && continue
    printf '  - "%s"\n' "$g"
  done
}

# The `- item` globs of the frontmatter `paths:` block list, quotes stripped, one per line.
fm_path_globs() {
  awk '
    NR==1 && $0 !~ /^---[[:space:]]*$/ { exit }
    /^---[[:space:]]*$/ { d++; if (d==2) exit; next }
    d==1 && /^paths:/ { inp=1; next }
    d==1 && inp && /^[[:space:]]*-[[:space:]]*/ {
      l=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",l); sub(/[[:space:]]+$/,"",l)
      gsub(/^["'\'']|["'\'']$/,"",l); print l; next }
    d==1 && inp && /^[^[:space:]-]/ { inp=0 }
  ' "$1"
}

_sha8() { if command -v shasum >/dev/null 2>&1; then shasum; else sha1sum; fi | cut -c1-8; }

# 0 = the `paths:` block is the pack's source default, unedited: the marker line is present and
# its hash equals the hash of the globs as they stand now.
is_pack_default() {
  local f="$1" want got
  want=$(awk '/^---[[:space:]]*$/{d++; if(d==2)exit; next}
              d==1 && /^paths-origin:[[:space:]]*pack-default-[0-9a-f]+[[:space:]]*$/ {
                sub(/^paths-origin:[[:space:]]*pack-default-/,""); sub(/[[:space:]]+$/,""); print; exit }' "$f")
  [ -n "$want" ] || return 1
  got=$(fm_path_globs "$f" | _sha8)
  [ "$got" = "$want" ]
}

# The file with its frontmatter `paths:` block (key + list items) and marker line removed.
strip_scope() {
  awk '
    NR==1 { print; if ($0 ~ /^---[[:space:]]*$/) d=1; next }
    d==1 && /^---[[:space:]]*$/ { d=2; print; next }
    d==1 && /^paths:/ { skip=1; next }
    d==1 && skip && (/^[[:space:]]/ || /^-[[:space:]]/) { next }
    d==1 && /^paths-origin:/ { skip=0; next }
    { skip=0; print }
  ' "$1"
}

inject() {
  local f="$1"
  [ -f "$f" ] || return 0
  # 🔴 NO FRONTMATTER IS NOT A REASON TO REFUSE. CREATE IT.
  #
  # This returned 0 — success — after doing nothing, so every caller believed the rule was
  # scoped. scope-domain-rules.sh reported `SCOPE ai-cost-discipline.md` while the file was
  # untouched, and the next wire-rule-imports.sh run imported it as always-loaded again.
  #
  # 📏 MEASURED on the reference monorepo: 16 of 36 installed rules start with a heading rather than
  # `---`, so they were unscopeable — 30,992 tok of rules that could never leave the
  # always-loaded tier no matter what any tool did. All 63 rule TEMPLATES in this repo carry
  # frontmatter, so the loss happens on install, not at source; refusing here just made a
  # pipeline bug permanent and silent.
  #
  # A rule without frontmatter is still a rule. Give it the block it needs and scope it.
  if ! head -n1 "$f" | grep -q '^---$'; then
    printf -- '---\n---\n' > "$f.fm" && cat "$f" >> "$f.fm" && mv "$f.fm" "$f"
    echo "note: added missing frontmatter block: $f" >&2
  fi
  local blk; blk="$(yaml_block "$globs")"
  [ -z "$blk" ] && { echo "skip (no usable globs): $f" >&2; return 0; }

  # Already scoped? Only the pack's unedited source default may be replaced.
  local replaced=0
  if awk '/^---$/{c++; next} c==1 && /^paths:/{found=1} c==2{exit} END{exit !found}' "$f"; then
    is_pack_default "$f" || { echo "skip (already scoped): $f" >&2; return 0; }
    strip_scope "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    replaced=1
  fi
  # Insert `paths:` plus its block list right after the opening `---`.
  { head -n1 "$f"; printf 'paths:\n'; printf '%s\n' "$blk"; tail -n +2 "$f"; } > "$f.tmp" && mv "$f.tmp" "$f"
  if [ "$replaced" = 1 ]; then
    echo "scoped (replaced pack default): $f -> paths: $(printf '%s' "$globs")" >&2
  else
    echo "scoped: $f -> paths: $(printf '%s' "$globs")" >&2
  fi
}

if [ -d "$target" ]; then
  for f in "$target"/*.md; do inject "$f"; done
else
  inject "$target"
fi
