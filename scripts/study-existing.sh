#!/usr/bin/env bash
# study-existing.sh — per-file deep comparison of target's existing setup vs pack equivalents.
#
# Solves the third bug: the agent runs REFRESH/REFINE/ENHANCE and only ADDS missing files.
# It does NOT compare existing files against pack equivalents to decide what should be
# ENHANCED (deepen/improve), ALIGNED (re-anchor to project), or DELETED (deprecated).
#
# This script does the comparison in shell, applies Appendix C merge matrix
# deterministically, and writes a proposal report. Phase 4 must consume the proposals.
#
# Usage:
#   study-existing.sh <target-repo> [pack1 pack2 ...]
#
# Output: <target>/.claude/_study-existing-report.md
# Properties: deterministic; idempotent; read-only on the target's actual artifacts.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [pack1 pack2 ...]" >&2
  exit 2
fi

TARGET="$1"; shift
[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

REPORT="$TARGET/.claude/_study-existing-report.md"
mkdir -p "$(dirname "$REPORT")"

# M35 — durable decisions ledger. Rows recorded here are reconciled instead of
# re-proposed on every run (the "95 rows again every refresh" failure mode).
# Refresh's aim: keep what must be kept, change what must change, add the new —
# WITHOUT re-litigating every kept row each run. Verbs encode exactly that:
#   - `pack/kind/file.md` → REJECTED (YYYY-MM-DD) — rationale            (permanent: artifact class is wrong for this project)
#   - `pack/kind/file.md` → KEEP-OURS (YYYY-MM-DD, pack@sha8) — why ours wins   (re-opens when pack source changes)
#   - `pack/kind/file.md` → RESOLVED (YYYY-MM-DD, pack@sha8) — how merged       (re-opens when pack source changes)
#   - `kind/file.md` → KEEP (YYYY-MM-DD) — rationale                     (project-only orphan keeper)
LEDGER="$TARGET/.claude/_refresh-decisions.md"

# ledger_lookup <key> → prints "VERB|date|sha8|rationale" (sha8 empty unless stamped). Empty if no entry.
ledger_lookup() {
  local key="$1" line verb ldate sha why
  [[ -f "$LEDGER" ]] || return 0
  line=$(grep -F "\`$key\`" "$LEDGER" 2>/dev/null | grep -E '→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(' | tail -1 || true)
  [[ -z "$line" ]] && return 0
  verb=$(echo "$line" | sed -E 's/^.*→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(.*/\1/')
  ldate=$(echo "$line" | sed -E 's/^.*\(([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
  sha=$(echo "$line" | sed -nE 's/^.*pack@([0-9a-f]{8}).*/\1/p')
  why="${line#*— }"   # text after the first " — " separator (byte-safe vs sed multibyte classes)
  printf '%s|%s|%s|%s' "$verb" "$ldate" "$sha" "$why"
}

pack_sha8() { shasum "$1" 2>/dev/null | cut -c1-8; }

# apply-study-decisions.sh rewrites snippet/governance links on deploy
# (../../../snippets/ → ../templates/snippets/). Compare against the DEPLOYED
# shape, or every applied command re-flags as MERGE forever (false drift).
NORM_TMP=""
normalized_src() {
  local src="$1" kind="$2"
  if [[ "$kind" != "commands" && "$kind" != "agents" ]] || ! command -v perl >/dev/null 2>&1; then
    printf '%s' "$src"; return
  fi
  [[ -z "$NORM_TMP" ]] && NORM_TMP=$(mktemp -d "${TMPDIR:-/tmp}/study-norm.XXXXXX")
  local out="$NORM_TMP/$(basename "$src")"
  perl -pe 's{\]\(\.\./\.\./\.\./snippets/}{](../templates/snippets/}g; s{\]\(\.\./\.\./\.\./governance/}{](../templates/governance/}g' "$src" > "$out" 2>/dev/null || { printf '%s' "$src"; return; }
  printf '%s' "$out"
}

# Phase 4.6 (apply-anchors.sh) injects the canonical
# `<!-- project-specific:start --> ... :end -->` block (+ one trailing blank
# line) into every deployed artifact. That block does NOT exist in the pack
# source, so comparing the raw target against the pack counts the anchor as
# ~15 lines of "difference" — a file that is EXACTLY pack-content + anchor then
# re-flags as MERGE on every refresh forever (phantom drift; observed 2026-07-09).
# Strip the anchor block (and the single blank line the injection appends) so the
# comparison sees only the pack-derived content.
STRIP_TMP=""
stripped_target() {
  local tgt="$1"
  if ! grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$tgt" 2>/dev/null; then
    printf '%s' "$tgt"; return
  fi
  [[ -z "$STRIP_TMP" ]] && STRIP_TMP=$(mktemp -d "${TMPDIR:-/tmp}/study-strip.XXXXXX")
  local out="$STRIP_TMP/$(basename "$tgt")"
  awk '
    /^<!-- project-specific:start -->[[:space:]]*$/ { skip=1; next }
    skip { if (/^<!-- project-specific:end -->[[:space:]]*$/) { skip=0; drop_blank=1 } next }
    drop_blank && /^[[:space:]]*$/ { drop_blank=0; next }
    { drop_blank=0; print }
  ' "$tgt" > "$out" 2>/dev/null || { printf '%s' "$tgt"; return; }
  printf '%s' "$out"
}

PACKS=("$@")
if [[ ${#PACKS[@]} -eq 0 ]]; then
  # Auto-detect installed packs from target's codebase-profile.md if present.
  # Fall back to scanning ALL packs (so the report is never empty for projects
  # that don't have a tracks_selected line — the historic bug).
  if [[ -f "$TARGET/.claude/codebase-profile.md" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] && PACKS+=("$p")
    done < <(grep -E '^[[:space:]]*-?[[:space:]]*track:' "$TARGET/.claude/codebase-profile.md" 2>/dev/null \
             | sed -E 's/.*track:[[:space:]]+([a-z0-9-]+).*/\1/' | sort -u)
  fi
  if [[ ${#PACKS[@]} -eq 0 ]]; then
    # No tracks declared — scan ALL packs. The user's project may have
    # commands/agents from packs that aren't recorded in the profile.
    # Try find first; some sandboxes restrict find traversal even when ls
    # works, so fall back to a bash glob if find returns nothing.
    while IFS= read -r d; do
      name="$(basename "$d")"
      [[ "$name" == _* ]] && continue
      PACKS+=("$name")
    done < <(find -L "$PACKS_ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    if [[ ${#PACKS[@]} -eq 0 ]]; then
      for d in "$PACKS_ROOT"/*/; do
        [[ -d "$d" ]] || continue
        name="$(basename "$d")"
        [[ "$name" == _* ]] && continue
        [[ "$name" == "*" ]] && continue
        PACKS+=("$name")
      done
    fi
  fi
fi
# bash 3.2 (macOS default) treats `${arr[*]}` on an empty array as unbound under
# set -u — guard the trace line so it never crashes the preflight.
if [[ ${#PACKS[@]} -gt 0 ]]; then
  echo "Scanning packs: ${PACKS[*]}" >&2
else
  echo "Scanning packs: (none — neither codebase-profile track: lines nor $PACKS_ROOT scan yielded packs)" >&2
  echo "ERR: cannot proceed with zero packs. Pass packs as args, or check $PACKS_ROOT exists and is readable." >&2
  exit 1
fi

target_dir_for_kind() {
  case "$1" in
    commands)    echo "$TARGET/.claude/commands" ;;
    agents)      echo "$TARGET/.claude/agents" ;;
    skills)      echo "$TARGET/.claude/skills" ;;
    rules)       echo "$TARGET/.claude/rules" ;;
    ai-patterns) echo "$TARGET/ai/patterns" ;;
    *)           echo "$TARGET/.claude/$1" ;;
  esac
}

# Enumerate one artifact-kind dir, one line per artifact, in BOTH on-disk forms:
#   flat      <dir>/<name>.md
#   dir-form  <dir>/<name>/SKILL.md   (Agent Skills convention; pack skills use this)
# Emits FULL paths so callers can derive the pack-relative suffix (`${p#"$dir"/}`) —
# that suffix is the artifact identity for both forms, and is what keeps source rows,
# union keys and target paths 1:1. `_*`-prefixed artifacts are filtered by the caller's
# existing prefix guard, which sees `_name.md` or `_name/SKILL.md` alike.
enumerate_kind_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$dir/_*" 2>/dev/null
  } | sort
}

# Canonical, form-independent artifact identity:
#   foo.md        -> foo.md
#   foo/SKILL.md  -> foo.md
# Lets the two on-disk forms of the SAME artifact compare equal. Without it, a target
# still on flat form would be misreported as a project-only orphan the moment the pack
# moved to dir-form (and a dir-form target likewise, against an older flat pack).
artifact_identity() {
  case "$1" in
    */SKILL.md) local d="${1%/SKILL.md}"; echo "${d##*/}.md" ;;
    *)          echo "${1##*/}" ;;
  esac
}

# Appendix C decision based on size ratio (target/pack) + byte-identity check.
# Codifies "Same name overlap" rules in shell so the agent can't override.
decide() {
  local target_path="$1" pack_path="$2" has_anchor="${3:-0}"
  local target_size pack_size
  target_size=$(wc -l < "$target_path" | tr -d ' ')
  pack_size=$(wc -l < "$pack_path" | tr -d ' ')

  if [[ "$pack_size" -eq 0 ]]; then echo "ERROR_DIVZERO"; return; fi

  # Byte-identical = no work needed (Phase 4.6 will still anchor project-specific block separately).
  # `diff -q` alone would report the trailing blank the anchor strip may leave; -w -B
  # makes an adopted-then-anchored file compare equal to its pack source (no phantom MERGE).
  if cmp -s "$target_path" "$pack_path" || diff -q -w -B "$target_path" "$pack_path" >/dev/null 2>&1; then
    echo "IDENTICAL-NO-OP"
    return
  fi

  local ratio=$(( target_size * 100 / pack_size ))

  if [[ $ratio -ge 200 ]]; then
    echo "KEEP-OURS-DEEP"
  elif [[ $ratio -ge 130 ]]; then
    # "target deeper but MISSING project-specific anchor → inject" is the whole
    # point of KEEP-OURS-PLUS-INJECT. When the anchor is ALREADY present the
    # inject is a no-op, so this is a non-actionable keeper — flagging it
    # actionable is a false positive (deeper+anchored files re-flagged every run
    # until a ledger row lands; observed 2026-07-14).
    if [[ "$has_anchor" == "1" ]]; then echo "KEEP-OURS-ANCHORED"; else echo "KEEP-OURS-PLUS-INJECT"; fi
  elif [[ $ratio -ge 70 ]]; then
    echo "MERGE"
  elif [[ $ratio -ge 50 ]]; then
    echo "KEEP-OURS-ADD-SIDE-DOC"
  else
    echo "REPLACE-OR-ENHANCE"
  fi
}

# ---------- Build report ----------
{
  printf '# Study-existing report — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Generated by: scripts/study-existing.sh\n\n'
  printf '> **MANDATORY for REFRESH / REFINE / ENHANCE.** Per-file decisions derived from Appendix C merge matrix. Phase 4 MUST address every row marked REPLACE-OR-ENHANCE / KEEP-OURS-PLUS-INJECT / MERGE before declaring success. Phase 5 audit FAILS the run if any actionable row was silently ignored.\n\n'
  printf -- '---\n\n'

  total_act=0
  total_keep=0
  total_missing=0
  total_orphan=0
  total_ledger=0
  total_reopened=0

  # Union of pack basenames per kind — used after the loop to report each
  # project-only orphan ONCE (previously each orphan re-appeared under every
  # scanned pack: ~80 orphans × ~20 packs = ~1600 noise rows).
  UNION_TMP=$(mktemp -d "${TMPDIR:-/tmp}/study-union.XXXXXX")
  trap 'rm -rf "$UNION_TMP" ${NORM_TMP:+"$NORM_TMP"}' EXIT

  for pack in "${PACKS[@]}"; do
    pack_dir="$PACKS_ROOT/$pack"
    [[ -d "$pack_dir" ]] || continue

    pack_section=""
    pack_actionable=0

    for kind in commands agents skills rules ai-patterns; do
      kind_dir="$pack_dir/$kind"
      [[ -d "$kind_dir" ]] || continue

      tgt_dir="$(target_dir_for_kind "$kind")"
      [[ -d "$tgt_dir" ]] || continue

      kind_rows=""
      while IFS= read -r src; do
        # Agent Skills dir-form (`<name>/SKILL.md`) keeps its pack-relative suffix, so the
        # report row, the union key and the target path stay 1:1 with the source. Flat
        # `<name>.md` artifacts are unaffected — the suffix IS the basename for them.
        base="${src#"$kind_dir"/}"
        [[ "$base" == _* ]] && continue
        artifact_identity "$base" >> "$UNION_TMP/$kind"
        tgt="$tgt_dir/$base"

        # M35: a ledger entry reconciles this row unless the pack source changed
        # since the decision was stamped (content hash, not mtime).
        ledger_entry="$(ledger_lookup "$pack/$kind/$base")"
        if [[ -n "$ledger_entry" ]]; then
          IFS='|' read -r lverb ldate lsha lwhy <<<"$ledger_entry"
          cur_sha="$(pack_sha8 "$src")"
          if [[ "$lverb" == "REJECTED" ]]; then
            kind_rows+=$'\n'"  - \`$base\` — → **REJECTED-BY-LEDGER** — $lwhy ($ldate)"
            total_ledger=$(( total_ledger + 1 ))
            continue
          elif [[ "$lverb" == "KEEP-OURS" || "$lverb" == "RESOLVED" ]]; then
            if [[ -n "$lsha" && "$lsha" == "$cur_sha" ]]; then
              kind_rows+=$'\n'"  - \`$base\` — → **${lverb}-BY-LEDGER** — $lwhy ($ldate, pack@$lsha)"
              total_ledger=$(( total_ledger + 1 ))
              continue
            fi
            # Pack source changed since the decision → re-open for re-audit.
            kind_rows+=$'\n'"  - \`$base\` — ledger $lverb ($ldate) is STALE: pack changed pack@${lsha:-?}→pack@$cur_sha — re-opened below"
            total_reopened=$(( total_reopened + 1 ))
          fi
        fi

        if [[ -f "$tgt" ]]; then
          cmp_src="$(normalized_src "$src" "$kind")"
          # Compare against the anchor-stripped target so the Phase 4.6
          # project-specific block never inflates the diff into phantom MERGE.
          cmp_tgt="$(stripped_target "$tgt")"
          src_lines=$(wc -l < "$cmp_src" | tr -d ' ')
          tgt_lines=$(wc -l < "$cmp_tgt" | tr -d ' ')
          # Anchor presence gates the KEEP-OURS-PLUS-INJECT ("inject the anchor")
          # verdict — a deeper file that already carries the marker needs no inject.
          has_anchor=0
          grep -qE '^<!-- project-specific:start -->[[:space:]]*$' "$tgt" 2>/dev/null && has_anchor=1
          decision=$(decide "$cmp_tgt" "$cmp_src" "$has_anchor")
          kind_rows+=$'\n'"  - \`$base\` — target $tgt_lines / pack $src_lines lines → **$decision**"

          case "$decision" in
            REPLACE-OR-ENHANCE|KEEP-OURS-PLUS-INJECT|MERGE)
              pack_actionable=$(( pack_actionable + 1 ))
              total_act=$(( total_act + 1 ))
              ;;
            *)
              total_keep=$(( total_keep + 1 ))
              ;;
          esac
        else
          kind_rows+=$'\n'"  - \`$base\` — target MISSING / pack $(wc -l < "$src" | tr -d ' ') lines → **ADD**"
          pack_actionable=$(( pack_actionable + 1 ))
          total_missing=$(( total_missing + 1 ))
        fi
      done < <(enumerate_kind_dir "$kind_dir")

      [[ -n "$kind_rows" ]] && pack_section+=$'\n\n### '"$kind"$''$kind_rows
    done

    if [[ -n "$pack_section" ]]; then
      printf '## %s' "$pack"
      printf '%b' "$pack_section"
      printf '\n\nactionable in this pack: **%d**\n\n---\n\n' "$pack_actionable"
    fi
  done

  # Project-only orphans — reported ONCE per file across all scanned packs.
  printf '## Project-only files (target has them; no scanned pack does)\n'
  for kind in commands agents skills rules ai-patterns; do
    tgt_dir="$(target_dir_for_kind "$kind")"
    [[ -d "$tgt_dir" ]] || continue
    orphan_rows=""
    while IFS= read -r tgtf; do
      base="${tgtf#"$tgt_dir"/}"
      [[ "$base" == _* ]] && continue
      if [[ ! -f "$UNION_TMP/$kind" ]] || ! grep -qxF "$(artifact_identity "$base")" "$UNION_TMP/$kind"; then
        ledger_entry="$(ledger_lookup "$kind/$base")"
        if [[ -n "$ledger_entry" ]]; then
          IFS='|' read -r lverb ldate lsha lwhy <<<"$ledger_entry"
          orphan_rows+=$'\n'"  - \`$base\` — → **KEEP-BY-LEDGER** — $lwhy ($ldate)"
          total_ledger=$(( total_ledger + 1 ))
        else
          orphan_rows+=$'\n'"  - \`$base\` — target-only (not in pack) → **REVIEW: project-specific keeper OR deprecated upstream**"
          total_orphan=$(( total_orphan + 1 ))
        fi
      fi
    done < <(enumerate_kind_dir "$tgt_dir")
    [[ -n "$orphan_rows" ]] && { printf '\n### %s' "$kind"; printf '%b\n' "$orphan_rows"; }
  done
  printf '\n---\n\n'

  printf '## Decision legend\n\n'
  cat <<'LEGEND'
* ADD — file in pack but not target. Phase 4.2 must copy.
* IDENTICAL-NO-OP — target byte-identical to pack. No structural action; Phase 4.6 still anchors project-specific block.
* REPLACE-OR-ENHANCE — target ≤ 50% of pack size. Stub or shallow; replace with pack OR rewrite to pack depth.
* KEEP-OURS-PLUS-INJECT — target deeper but missing project-specific anchor. Phase 4.6 must inject anchor section into target.
* KEEP-OURS-ANCHORED — target deeper AND already carries the project-specific anchor block. Keeper; no action (the inject KEEP-OURS-PLUS-INJECT would ask for is already done).
* MERGE — sizes comparable; real per-section merge required.
* KEEP-OURS-ADD-SIDE-DOC — target slightly shallower; keep target, add pack as side-doc with different name.
* KEEP-OURS-DEEP — target ≥ 2× pack size; pack adds nothing. No action.
* REVIEW — file in target but NOT in pack. Could be project-specific (keep) or deprecated upstream (consider deleting). Human judgment required.
* REJECTED-BY-LEDGER / KEEP-OURS-BY-LEDGER / RESOLVED-BY-LEDGER / KEEP-BY-LEDGER — reconciled by `.claude/_refresh-decisions.md`. Not actionable. KEEP-OURS / RESOLVED entries re-open automatically when the pack source changes (pack@sha8 mismatch).

Recording decisions (M35 — the ONLY sanctioned way to skip an actionable row):

    apply-study-decisions.sh <target> --reject='pack/kind/file.md:rationale'     # permanent: wrong for this project
    apply-study-decisions.sh <target> --keep-ours='pack/kind/file.md:rationale'  # ours is better than current pack version
    apply-study-decisions.sh <target> --resolve='pack/kind/file.md:note'         # merge/inject performed by hand
    apply-study-decisions.sh <target> --keep='kind/file.md:rationale'            # project-only orphan keeper
LEGEND

  printf '\n## Summary\n\n'
  printf 'Files with action needed: **%d**\n' "$(( total_act + total_missing ))"
  printf '  ADD (missing): %d\n' "$total_missing"
  printf '  ENHANCE / MERGE / INJECT: %d\n' "$total_act"
  printf 'Files to keep as-is: %d\n' "$total_keep"
  printf 'Ledger-reconciled (not re-proposed): %d\n' "$total_ledger"
  printf 'Ledger entries re-opened (pack changed since decision): %d\n' "$total_reopened"
  printf 'Files to review (orphans, deduped): %d\n\n' "$total_orphan"

  if [[ $(( total_act + total_missing )) -eq 0 && "$total_orphan" -eq 0 ]]; then
    printf 'No actionable items. Setup is converged.\n'
  else
    printf '⚠ Phase 4 MUST end every actionable row in one of two states: APPLIED (copy / merge / enhance) or RECORDED in `.claude/_refresh-decisions.md` with rationale. Phase 5 audit (C2k) regenerates this report and refuses success otherwise.\n'
  fi
} > "$REPORT"

echo "Study report written: $REPORT"
echo "Actionable: $(( total_act + total_missing )) | Keep: $total_keep | Ledger: $total_ledger (re-opened: $total_reopened) | Orphans: $total_orphan"
exit 0
