#!/usr/bin/env bash
# pack-coverage-scan.sh — deterministic shell-side scan of pack content vs target.
#
# Solves the M11 bug: the agent (LLM running /setup-project) was reading prose
# rules about scanning pack directories and skipping the actual scan. This
# script does the scan in shell (no LLM judgment), writes a structured report,
# and Phase 4.0 / Phase 5 require the agent to consume it.
#
# Usage:
#   pack-coverage-scan.sh <target-repo> [pack1 pack2 ...] [--stdout | --report=<path>]
#
#   --stdout        READ-ONLY mode (alias: --no-write). Report goes to stdout and NOTHING
#                   is created under <target-repo> — not the report, not `.claude/`.
#                   CONTRIBUTING.md tells contributors to run this against "a real target
#                   tree"; without this flag that instruction silently writes to it.
#   --report=<path> Write the report to <path> instead. Must use `=` (the space form is
#                   refused, since a bare word here is parsed as a PACK NAME).
#
# If no packs listed, scans every selected pack from <target>/.claude/codebase-profile.md
# (line "tracks_selected: ..."). Falls back to scanning all packs if profile missing.
#
# Output: <target>/.claude/_pack-coverage-report.md (structured markdown).
#
# THE REPORT CALLS ITSELF THE SOURCE OF TRUTH, so it must not contradict the
# other two artifacts that grade the same tree. It reads
# `<target>/.claude/_refresh-decisions.md` (the M35 decisions ledger) and lists a
# deliberately-declined pack file under "Declined by ledger" instead of "Missing".
# Without that, a file recorded `→ REJECTED` was reconciled by study-existing.sh,
# reported ok by audit-setup.sh C2b2, and STILL printed here under Missing with
# the "MUST address every Missing file" close — so the next agent obeying the
# self-declared source of truth re-created every file a human had declined.
# Exit codes: 0 = report written; 1 = target missing; 2 = usage error.
#   Exit is ALWAYS 0 on a written report — the report is the contract, and
#   run-preflight.sh pipes this script under `set -euo pipefail`. A shape
#   conflict is signalled by the LAST stdout line (survives `| tail -3`) and by
#   a CONFLICT section in the report, never by a non-zero exit.
#
# ---------------------------------------------------------------------------
# SKILL SHAPE — the framework's ONE position (M40)
# ---------------------------------------------------------------------------
# A skill has TWO legal on-disk shapes and exactly ONE identity:
#   CANONICAL  <dir>/<name>/SKILL.md   — Agent Skills folder form. Every pack
#                                        ships this; every new install gets it.
#   LEGACY     <dir>/<name>.md         — flat form. Pre-Apr-2026 installs carry
#                                        it; it is NOT re-created, only migrated.
# The identity is <name>, NEVER the path. A scan that knows only the canonical
# shape reports every legacy-form skill as "Missing", and whatever acts on that
# report installs a SECOND copy of a skill that is already there — two files,
# one `name:` in frontmatter, both registered. Observed 2026-08-22 against an
# 8,151-file target: 56 of 59 flat skills reported Missing, 56 duplicates created.
# So: resolution is by identity, and a target carrying BOTH shapes of one name is
# a CONFLICT this script reports loudly rather than a state it silently tolerates.
# Migration path for a legacy-form project:
#   scripts/apply-study-decisions.sh <target> --migrate-skill-shape [--apply]
#
# Properties:
# - Deterministic. Same input → same output.
# - Idempotent. Re-running overwrites the report (it's derived).
# - Read-only on the target's actual artifacts. Only writes the report.

set -euo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKS_ROOT="$REPO_ROOT/templates/packs"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [pack1 pack2 ...] [--stdout|--report=<path>]" >&2
  echo "       --stdout = read-only: report on stdout, nothing written under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift
[[ -d "$TARGET" ]] || { echo "ERR: target repo not found: $TARGET" >&2; exit 1; }

# Sink flags are filtered out of "$@" here; what remains is pack names (read at
# `PACKS=("$@")` below), so the two argument families cannot collide.
SINK_STDOUT=0
REPORT_OVERRIDE=""
_pc_args=()
for _a in ${@+"$@"}; do
  case "$_a" in
    --stdout|--no-write) SINK_STDOUT=1 ;;
    --report=*)          REPORT_OVERRIDE="${_a#*=}" ;;
    --report)            echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *)                   _pc_args+=("$_a") ;;
  esac
done
set -- ${_pc_args[@]+"${_pc_args[@]}"}

# ── Report sink ────────────────────────────────────────────────────────────────
# The default sink is a file INSIDE the target, so merely SCANNING a repo wrote to it —
# and the mkdir created `.claude/` in a target that had none. Same class of defect that
# put three regenerated reports into a declared read-only project on 2026-08-22.
REPORT="$TARGET/.claude/_pack-coverage-report.md"
REPORT_TMP=""
if [[ $SINK_STDOUT -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/pack-coverage-report.XXXXXX")
  trap '[ -n "${REPORT_TMP:-}" ] && rm -f "$REPORT_TMP"; :' EXIT
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(stdout — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# Determine packs to scan
PACKS=("$@")
if [[ ${#PACKS[@]} -eq 0 ]]; then
  if [[ -f "$TARGET/.claude/codebase-profile.md" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] && PACKS+=("$p")
    done < <(grep -E '^[[:space:]]*-?[[:space:]]*track:' "$TARGET/.claude/codebase-profile.md" 2>/dev/null \
             | sed -E 's/.*track:[[:space:]]+([a-z0-9-]+).*/\1/' | sort -u)
  fi
fi
if [[ ${#PACKS[@]} -eq 0 ]]; then
  # Try find first; some sandboxes restrict find traversal even when ls works,
  # so fall back to a bash glob if find returns nothing.
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
# bash 3.2 (macOS default) treats `${arr[*]}` on an empty array as unbound under
# set -u — guard the trace line so it never crashes the preflight.
if [[ ${#PACKS[@]} -gt 0 ]]; then
  echo "Scanning packs: ${PACKS[*]}" >&2
else
  echo "Scanning packs: (none — neither codebase-profile track: lines nor $PACKS_ROOT scan yielded packs)" >&2
  echo "ERR: cannot proceed with zero packs. Pass packs as args, or check $PACKS_ROOT exists and is readable." >&2
  exit 1
fi

# Per-kind target dir resolution (per pack.md emit conventions)
target_dir_for_kind() {
  local kind="$1"
  case "$kind" in
    commands)    echo "$TARGET/.claude/commands" ;;
    agents)      echo "$TARGET/.claude/agents" ;;
    skills)      echo "$TARGET/.claude/skills" ;;
    rules)       echo "$TARGET/.claude/rules" ;;
    ai-patterns) echo "$TARGET/ai/patterns" ;;
    *)           echo "$TARGET/.claude/$kind" ;;
  esac
}

# Enumerate one artifact-kind dir, one line per artifact, in BOTH on-disk forms:
#   flat      <dir>/<name>.md
#   dir-form  <dir>/<name>/SKILL.md   (Agent Skills convention; pack skills use this)
# Emits FULL paths so callers can derive the pack-relative suffix (`${p#"$dir"/}`), which
# is the artifact identity for both forms. `_*` artifacts are dropped by the caller's guard.
enumerate_kind_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  { find "$dir" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$dir" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$dir/_*" 2>/dev/null
  } | sort
}

# ---------- Shape-aware target resolution (M40) ----------
# The pack side already enumerates both shapes (above). The TARGET side used to be
# tested one-shape-only (`[[ -f "$tgt_dir/$base" ]]`), which is the whole 56-duplicate
# bug: a pack `skills/<n>/SKILL.md` never looked for the project's `skills/<n>.md`.

# Artifact identity — the NAME, stripped of whichever shape carries it.
#   skills/<name>/SKILL.md → <name>        <name>.md → <name>
artifact_identity() {
  local base="$1"
  if [[ "$base" == */SKILL.md ]]; then printf '%s' "${base%/SKILL.md}"; else printf '%s' "${base%.md}"; fi
}

# Resolve one pack artifact against the target, accepting BOTH shapes for `skills`.
# Sets three globals (no command substitution — a `return 1` inside `$(…)` is
# swallowed by the assignment and this runs under `set -e`):
#   RESOLVED_PATH  full path of the installed artifact, "" when genuinely absent
#   RESOLVED_FORM  canonical | legacy-flat | ""      (which shape carries it)
#   TWIN_PATH      non-empty ONLY when BOTH shapes exist — a duplicate-`name:` twin
resolve_target_artifact() {
  local kind="$1" tgt_dir="$2" base="$3"
  RESOLVED_PATH=""; RESOLVED_FORM=""; TWIN_PATH=""

  # Non-skill kinds have exactly one legal shape — resolve as before, no dual-shape guess.
  if [[ "$kind" != "skills" ]]; then
    [[ -f "$tgt_dir/$base" ]] && { RESOLVED_PATH="$tgt_dir/$base"; RESOLVED_FORM="canonical"; }
    return 0
  fi

  local name folder flat
  name="$(artifact_identity "$base")"
  folder="$tgt_dir/$name/SKILL.md"
  flat="$tgt_dir/$name.md"

  if [[ -f "$folder" && -f "$flat" ]]; then
    # Both shapes of one name on disk. Two registrations, one `name:` — the exact
    # damage this script exists to stop. Canonical wins for merge-matrix purposes;
    # the twin is reported as a CONFLICT the run must resolve.
    RESOLVED_PATH="$folder"; RESOLVED_FORM="canonical"; TWIN_PATH="$flat"
  elif [[ -f "$folder" ]]; then
    RESOLVED_PATH="$folder"; RESOLVED_FORM="canonical"
  elif [[ -f "$flat" ]]; then
    RESOLVED_PATH="$flat";   RESOLVED_FORM="legacy-flat"
  fi
  return 0
}

# ---------- Decisions ledger (M35) ----------
# cap-6 §3.2: without this, the report that calls itself the SOURCE OF TRUTH is
# the one that is wrong. A pack file the human deliberately declined
# (`apply-study-decisions.sh <target> --reject='pack/kind/file.md:why'`) is
# recorded in `.claude/_refresh-decisions.md`; `study-existing.sh` reconciles it
# (REJECTED-BY-LEDGER) and `audit-setup.sh` C2b2 reports ok on it — but this scan
# kept printing it under **Missing** and kept closing with the INCOMPLETE MUST, so
# two framework artifacts gave opposite verdicts on the same tree and the next
# agent obeying this one re-created every declined file.
#
# Keyed exactly as study-existing.sh and C2b2 key it: `<pack>/<kind>/<base>` — the
# PACK-relative path, never the deployed target path.
LEDGER="$TARGET/.claude/_refresh-decisions.md"
pack_sha8() { shasum "$1" 2>/dev/null | cut -c1-8; }

# ledger_lookup <key> → "VERB|date|sha8|rationale" (sha8 empty unless stamped);
# empty when there is no entry. Same parse as study-existing.sh:45.
ledger_lookup() {
  local key="$1" line verb ldate sha why
  [[ -f "$LEDGER" ]] || return 0
  line=$(grep -F "\`$key\`" "$LEDGER" 2>/dev/null | grep -E '→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(' | tail -1 || true)
  [[ -z "$line" ]] && return 0
  verb=$(echo "$line" | sed -E 's/^.*→ (REJECTED|KEEP-OURS|RESOLVED|KEEP) \(.*/\1/')
  ldate=$(echo "$line" | sed -E 's/^.*\(([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
  sha=$(echo "$line" | sed -nE 's/^.*pack@([0-9a-f]{8}).*/\1/p')
  why="${line#*— }"
  printf '%s|%s|%s|%s' "$verb" "$ldate" "$sha" "$why"
}

# ---------- Build report ----------
{
  printf '# Pack coverage scan — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Target: `%s`\n\n' "$TARGET"
  printf 'Generated by: scripts/pack-coverage-scan.sh\n\n'
  printf '> **THIS REPORT IS THE SOURCE OF TRUTH** for "what should be in the target." The agent MUST read it before declaring `idempotent — no work to do`. Phase 5 audit FAILS the run if any pack shows missing files that were not addressed.\n'
  printf '>\n'
  printf '> It is the source of truth **because it reads `.claude/_refresh-decisions.md`**, the same ledger `study-existing.sh` and `audit-setup.sh` C2b2 read. A pack file a human declined there is listed under "Declined by ledger" below, is NOT a `Missing` row, and does NOT fail coverage. Reinstate one by deleting its line from the ledger — never by copying the pack file over the decision.\n\n'
  printf -- '---\n\n'

  total_missing=0
  total_legacy=0
  total_conflict=0
  total_declined=0
  legacy_rows=()
  conflict_rows=()
  declined_rows=()
  for pack in "${PACKS[@]}"; do
    pack_dir="$PACKS_ROOT/$pack"
    [[ -d "$pack_dir" ]] || { printf '## %s\n\n  ERR — pack source not found at %s\n\n' "$pack" "$pack_dir"; continue; }

    printf '## %s\n\n' "$pack"
    pack_missing=0
    pack_declined=0

    for kind in commands agents skills rules ai-patterns; do
      kind_dir="$pack_dir/$kind"
      [[ -d "$kind_dir" ]] || continue

      tgt_dir="$(target_dir_for_kind "$kind")"
      missing=()
      present=()   # rows: "<pack-base>|<resolved-target-path>|<form>"

      while IFS= read -r f; do
        base="${f#"$kind_dir"/}"
        [[ "$base" == _* ]] && continue
        resolve_target_artifact "$kind" "$tgt_dir" "$base"
        if [[ -n "$TWIN_PATH" ]]; then
          conflict_rows+=("$pack|$kind|$base|${RESOLVED_PATH#$TARGET/}|${TWIN_PATH#$TARGET/}")
          total_conflict=$(( total_conflict + 1 ))
        fi
        if [[ -n "$RESOLVED_PATH" ]]; then
          present+=("$base|$RESOLVED_PATH|$RESOLVED_FORM")
          if [[ "$RESOLVED_FORM" == "legacy-flat" ]]; then
            legacy_rows+=("$pack|$kind|$base|${RESOLVED_PATH#$TARGET/}")
            total_legacy=$(( total_legacy + 1 ))
          fi
        else
          # Absent on disk — but "absent" and "missing" are not the same thing.
          # A ledger REJECTED is permanent; a KEEP/KEEP-OURS/RESOLVED re-opens
          # when the pack source changed since the decision was stamped (same
          # staleness rule as study-existing.sh, content hash not mtime).
          led="$(ledger_lookup "$pack/$kind/$base")"
          if [[ -n "$led" ]]; then
            IFS='|' read -r l_verb l_date l_sha l_why <<<"$led"
            l_stale=0
            if [[ "$l_verb" != "REJECTED" && -n "$l_sha" && "$l_sha" != "$(pack_sha8 "$f")" ]]; then
              l_stale=1
            fi
            if [[ "$l_stale" -eq 0 ]]; then
              declined_rows+=("$pack|$kind|$base|$l_verb|$l_date|$l_why")
              total_declined=$(( total_declined + 1 ))
              pack_declined=$(( pack_declined + 1 ))
              continue
            fi
            missing+=("$base")
            continue
          fi
          missing+=("$base")
        fi
      done < <(enumerate_kind_dir "$kind_dir")

      total=$(( ${#missing[@]} + ${#present[@]} ))
      [[ $total -eq 0 ]] && continue

      printf '### %s (%d total)\n\n' "$kind" "$total"

      if [[ ${#missing[@]} -gt 0 ]]; then
        printf '**Missing — Phase 4.2 must copy or apply merge matrix to:**\n\n'
        for m in "${missing[@]}"; do
          printf -- '- `%s/%s` ← from `%s/%s/%s`\n' "${tgt_dir#$TARGET/}" "$m" "templates/packs/$pack" "$kind" "$m"
        done
        printf '\n'
        pack_missing=$(( pack_missing + ${#missing[@]} ))
      fi

      if [[ ${#present[@]} -gt 0 ]]; then
        printf '**Present — re-evaluate via Appendix C merge matrix (size ratio: ours / theirs):**\n\n'
        for row in "${present[@]}"; do
          IFS='|' read -r p_base p_path p_form <<<"$row"
          src_size=$(wc -l < "$kind_dir/$p_base" | tr -d ' ')
          tgt_size=$(wc -l < "$p_path" | tr -d ' ')
          shape_note=""
          [[ "$p_form" == "legacy-flat" ]] && shape_note=" — **legacy flat shape** of pack \`$p_base\`; same skill, not missing"
          printf -- '- `%s` (target: %d lines, pack: %d lines)%s\n' "${p_path#$TARGET/}" "$tgt_size" "$src_size" "$shape_note"
        done
        printf '\n'
      fi
    done

    if [[ "$pack_missing" -eq 0 ]]; then
      if [[ "$pack_declined" -gt 0 ]]; then
        printf 'pack coverage: COMPLETE (every file is either present in target — re-evaluate via merge matrix — or declined in the ledger: %d)\n\n' "$pack_declined"
      else
        printf 'pack coverage: COMPLETE (all files present in target — re-evaluate via merge matrix only)\n\n'
      fi
    else
      printf 'pack coverage: **%d files missing** — Phase 4.2 must address.\n\n' "$pack_missing"
      total_missing=$(( total_missing + pack_missing ))
    fi
    printf -- '---\n\n'
  done

  # ---------- Skill-shape sections (M40) ----------
  # These are NOT "Missing" rows and must never be written as such: audit-setup.sh
  # C2b2 parses `- `<path>` ← from …` and demands the path exist afterwards. A legacy
  # skill already exists — under its other legal name. Emitting it as Missing is what
  # produced 56 duplicate skills, so it is emitted as a MIGRATION row instead.
  if [[ "$total_conflict" -gt 0 ]]; then
    printf '## ⚠ SHAPE CONFLICTS — %d skill(s) installed TWICE\n\n' "$total_conflict"
    printf 'Both legal shapes of the SAME skill name are on disk. Two files, one `name:` in frontmatter — the tool registers a duplicate and which one wins is undefined. **This must be resolved before any Phase-4.2 write.** Keep the canonical folder form, delete the flat twin (or vice versa if the flat one holds the project edits — then migrate it).\n\n'
    for row in "${conflict_rows[@]}"; do
      IFS='|' read -r c_pack c_kind c_base c_canon c_flat <<<"$row"
      printf -- '- `%s` **and** `%s` — same skill `%s` (pack `%s/%s/%s`)\n' \
        "$c_canon" "$c_flat" "$(artifact_identity "$c_base")" "templates/packs/$c_pack" "$c_kind" "$c_base"
    done
    printf '\n'
    printf -- '---\n\n'
  fi

  if [[ "$total_legacy" -gt 0 ]]; then
    printf '## Skill shape — %d skill(s) on the LEGACY flat form\n\n' "$total_legacy"
    printf 'The framework ships **one** canonical shape: `.claude/skills/<name>/SKILL.md` (Agent Skills folder form). These skills are **PRESENT, not missing** — they are the same artifact under the pre-Apr-2026 flat name `.claude/skills/<name>.md`. Do NOT copy the pack file next to them; that creates a same-`name:` twin.\n\n'
    printf 'Migration (moves each flat file into its folder — backed up, never duplicated):\n\n'
    printf '```bash\n'
    printf '~/.claude/scripts/apply-study-decisions.sh "%s" --migrate-skill-shape          # dry run\n' "$TARGET"
    printf '~/.claude/scripts/apply-study-decisions.sh "%s" --migrate-skill-shape --apply  # execute\n' "$TARGET"
    printf '```\n\n'
    printf 'Staying on the flat shape is a legitimate choice — this section is informational, not a Missing row, and it does not fail coverage. It re-appears every scan until migrated.\n\n'
    for row in "${legacy_rows[@]}"; do
      IFS='|' read -r l_pack l_kind l_base l_path <<<"$row"
      printf -- '- `%s` → canonical `.claude/skills/%s/SKILL.md` (pack `%s/%s/%s`)\n' \
        "$l_path" "$(artifact_identity "$l_base")" "templates/packs/$l_pack" "$l_kind" "$l_base"
    done
    printf '\n'
    printf -- '---\n\n'
  fi

  if [[ "$total_declined" -gt 0 ]]; then
    printf '## Declined by ledger — %d file(s) NOT missing\n\n' "$total_declined"
    printf 'Each row is absent from the target **on purpose**: a human recorded the decision in `.claude/_refresh-decisions.md`. These are not `Missing` rows, they do not count toward coverage, and they must not be copied in. To reinstate one, delete its line from the ledger and re-scan.\n\n'
    for row in "${declined_rows[@]}"; do
      IFS='|' read -r d_pack d_kind d_base d_verb d_date d_why <<<"$row"
      printf -- '- `templates/packs/%s/%s/%s` → **%s** (%s) — %s\n' \
        "$d_pack" "$d_kind" "$d_base" "$d_verb" "$d_date" "$d_why"
    done
    printf '\n'
    printf -- '---\n\n'
  fi

  printf '## Summary\n\n'
  printf 'Packs scanned: %d\n' "${#PACKS[@]}"
  printf 'Total missing files across all packs: **%d**\n' "$total_missing"
  printf 'Declined by ledger (absent on purpose, not missing): **%d**\n' "$total_declined"
  printf 'Skills on the legacy flat shape (present, not missing): **%d**\n' "$total_legacy"
  printf 'Skill shape conflicts (same name installed twice): **%d**\n\n' "$total_conflict"

  if [[ "$total_conflict" -gt 0 ]]; then
    printf '⚠ Coverage: CONFLICT. Resolve every SHAPE CONFLICT above BEFORE any Phase-4.2 write — a duplicate `name:` is a broken registration, not a cosmetic issue.\n\n'
  fi

  if [[ "$total_missing" -eq 0 ]]; then
    printf 'Coverage: COMPLETE. The agent MAY conclude `no Phase-4.2 copy work` IF AND ONLY IF other gates also pass (drift, prompt delta, schema validation).\n'
  else
    printf '⚠ Coverage: INCOMPLETE. The agent MUST address every "Missing" file above before declaring "no work to do." Re-running `/setup-project --include=<pack>` is REQUIRED to apply. "Every Missing file" means exactly the rows in the **Missing** blocks — the "Declined by ledger" rows are already addressed and MUST NOT be copied in.\n'
  fi
} > "$REPORT"

# --stdout: the report was buffered off-target; emit it now and leave $TARGET untouched.
if [[ -n "$REPORT_TMP" ]]; then
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi

# Under --stdout the REPORT owns stdout, so these summary lines move to stderr —
# `pack-coverage-scan.sh <t> --stdout > report.md` must yield a clean report file.
# Default mode keeps them on stdout: run-preflight.sh reads them with `| tail -3`.
say() { if [[ $SINK_STDOUT -eq 1 ]]; then echo "$@" >&2; else echo "$@"; fi; }
say "Report written: $REPORT_LABEL"
if [[ "$total_declined" -gt 0 ]]; then
  say "Total missing files: $total_missing (+$total_declined declined by ledger — absent on purpose, not missing)"
else
  say "Total missing files: $total_missing"
fi
# Shape lines come LAST so they survive run-preflight.sh's `| tail -3`.
[[ "$total_legacy" -gt 0 ]] && say "Legacy flat-shape skills (present, not missing): $total_legacy — migrate: apply-study-decisions.sh \"$TARGET\" --migrate-skill-shape"
if [[ "$total_conflict" -gt 0 ]]; then
  echo "ERR: $total_conflict skill(s) installed in BOTH shapes (duplicate \`name:\`) — see '⚠ SHAPE CONFLICTS' in $REPORT_LABEL" >&2
  say "⚠ SHAPE CONFLICT: $total_conflict skill(s) installed twice — resolve before Phase 4.2 (see $REPORT_LABEL)"
fi
exit 0
