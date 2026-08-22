#!/usr/bin/env bash
# refresh-extract-checklist.sh — deterministic shell-side check of REFRESH-mode extraction depth.
#
# Solves the M15 second bug: REFRESH was shallow. The agent backed up + version-stamped + a few
# derived files and called it done, skipping the deep "read existing setup, extract knowledge,
# merge with re-detection" work that REFRESH's contract requires.
#
# This script INVENTORIES what's in the target's existing setup BEFORE Phase 4 regenerates,
# writes a structured report at <target>/.claude/_refresh-extract.md with sections that MUST
# be filled by Phase 0.2. Phase 5 audit fails the run if any required section is empty.
#
# `_refresh-extract.md` is THE refresh knowledge extract — there is no second file. It was once
# also spelled `_refresh-knowledge-extract.md` in the Phase 0.2/2/4.0/5 prose (inherited from the
# M1 monolith); that name had no writer, so an agent following the prose produced a file no gate
# read while leaving this one at <TBD>. One artifact, one name, one section numbering.
#
# It is NOT a temp file: audit-setup.sh C2b errors when it is absent, and /setup-project-health
# re-audits it after the run. Do not delete it at end of Phase 5.
#
# Usage:
#   refresh-extract-checklist.sh <target-repo> [--force] [--stdout | --report=<path>]
#
# Output: <target>/.claude/_refresh-extract.md
#   --stdout        READ-ONLY mode (alias: --no-write). Report goes to stdout and NOTHING
#                   is created OR modified under <target-repo> — not the report, not
#                   `.claude/`, and not the header re-stamp on the preserve path.
#   --report=<path> Write the report to <path> instead. Must use `=`.

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--force] [--stdout|--report=<path>]" >&2
  echo "       --stdout = read-only: report on stdout, nothing written under <target-repo>." >&2
  exit 2
fi

TARGET="$1"; shift || true
FORCE=0
SINK_STDOUT=0
REPORT_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --stdout|--no-write) SINK_STDOUT=1; shift ;;
    --report=*) REPORT_OVERRIDE="${1#*=}"; shift ;;
    --report) echo "ERR: use --report=<path> (with '='), not --report <path>" >&2; exit 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$TARGET" ]] || { echo "ERR: target not found: $TARGET" >&2; exit 1; }

# ── Report sink ────────────────────────────────────────────────────────────────
# Two variables, deliberately: REPORT_EXISTING is the file the idempotency guard below
# asks about (always the one in the target — that is the artifact being preserved), and
# REPORT is where THIS run's output goes. They were the same variable, which meant a
# redirected sink would have made the guard test the empty sink and regenerate over a
# filled report. The default sink being inside the target is what made merely SCANNING
# a repo write to it, and the mkdir created `.claude/` in a target that had none.
REPORT_EXISTING="$TARGET/.claude/_refresh-extract.md"
REPORT="$REPORT_EXISTING"
REPORT_TMP=""
if [[ $SINK_STDOUT -eq 1 ]]; then
  REPORT_TMP=$(mktemp "${TMPDIR:-/tmp}/refresh-extract.XXXXXX")
  trap '[ -n "${REPORT_TMP:-}" ] && rm -f "$REPORT_TMP"; :' EXIT
  REPORT="$REPORT_TMP"
  REPORT_LABEL="(stdout — nothing written under $TARGET)"
else
  [[ -n "$REPORT_OVERRIDE" ]] && REPORT="$REPORT_OVERRIDE"
  mkdir -p "$(dirname "$REPORT")"
  REPORT_LABEL="$REPORT"
fi

# ---------- Machine-independent header ----------
# The `Target:` line used to carry the absolute path of whoever generated the
# report. This file is PRESERVED across runs (see the idempotency guard below),
# and the preserve path never rewrote the header — so a real project shipped
# `Target: /Users/mac/Workspace/…` through six sessions on a machine where
# `/Users/mac` does not exist, and the agent reading it had no way to tell the
# report apart from one describing a different checkout.
#
# Fix, both halves:
#   1. the emitted header is repo-RELATIVE — it names the repo directory and
#      says how to resolve it, so it cannot go stale when the repo moves host,
#      user or clone path;
#   2. `restamp_header` rewrites that line on the PRESERVED path too, so an
#      existing report carrying an absolute path is corrected on the next run
#      without touching the LLM-filled body.
REPO_NAME="$(basename "$(cd "$TARGET" && pwd -P)")"
TARGET_LINE="Target: \`${REPO_NAME}/\` — repo root, i.e. the directory containing the \`.claude/\` that holds this file. Deliberately relative: this report is preserved across runs and machines."

restamp_header() {
  local file="$1" stamp tmp
  [[ -f "$file" ]] || return 0
  grep -q '^Target: ' "$file" 2>/dev/null || return 0
  # Already canonical -> no write at all, so a preserved report stays byte-stable
  # run to run. The stamp below records when the header was CORRECTED, not when
  # it was last read.
  grep -qxF "$TARGET_LINE" "$file" 2>/dev/null && return 0
  # Read-only mode: this is the script's SECOND write path into the target (it edits an
  # already-preserved report in place). Report what it would do; change nothing.
  if [[ ${SINK_STDOUT:-0} -eq 1 || -n "${REPORT_OVERRIDE:-}" ]]; then
    printf ' | header WOULD be re-stamped (read-only: not written)'
    return 0
  fi
  stamp="Header re-stamped: $(date -u +%Y-%m-%dT%H:%M:%SZ) by \`scripts/refresh-extract-checklist.sh\` — body below is preserved verbatim."
  tmp="$(mktemp)" || return 0
  awk -v tgt="$TARGET_LINE" -v stamp="$stamp" '
    seen == 0 && /^Target: / { print tgt; print stamp; seen = 1; next }
    seen == 1 { if ($0 ~ /^(Header re-stamped|Last verified): /) { seen = 2; next } seen = 2 }
    { print }
  ' "$file" > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
  # Never replace a good file with an empty one if awk was interrupted.
  if [[ -s "$tmp" ]] && ! cmp -s "$tmp" "$file"; then
    cat "$tmp" > "$file"
    # Emitted as a SUFFIX, not a new line: run-preflight.sh pipes this script
    # through `tail -2`, so a third line would push the "preserved" line off the
    # agent's only view of what happened.
    printf ' | header re-stamped: Target line is now repo-relative'
  fi
  rm -f "$tmp"
  return 0
}

# The header is ours to rewrite; the BODY is the agent's knowledge and is never
# touched. But a preserved body can cite an absolute home directory that no
# longer exists either (observed: `_refresh-extract.md` § 9 citing
# `/Users/mac/Workspace/...` for its V1 and V2 roots). Report it so the staleness
# is visible instead of silently authoritative — detect only, never rewrite.
warn_stale_abs_paths() {
  local file="$1" root missing=""
  [[ -f "$file" ]] || return 0
  while IFS= read -r root; do
    [[ -z "$root" ]] && continue
    [[ -d "$root" ]] && continue
    missing="$missing $root"
  done < <( { grep -oE '/(Users|home)/[A-Za-z0-9._-]+' "$file" 2>/dev/null || true; } | sort -u )
  [[ -n "$missing" ]] && printf ' | WARN preserved body cites home dir(s) absent on this machine:%s — re-verify the sections quoting them' "$missing"
  return 0
}

# Idempotency: if report exists with any LLM-filled section (i.e., contains
# non-trivial content under any "Phase 0.2 must fill" heading), skip overwrite
# unless --force is passed. Re-running this script wiping LLM-filled sections
# was the bug that caused the agent to re-fill the same content every preflight.
if [[ -f "$REPORT_EXISTING" && "$FORCE" -eq 0 ]]; then
  # Count <TBD> markers in LLM sections (sections 2-9). If <8, the report has
  # been at least partially filled — preserve it. Note: grep -c exits 1 when 0
  # matches, so we must not pipe through `|| echo 0` (that would concatenate
  # grep's "0" stdout with the fallback "0", producing "0\n0" — invalid integer).
  tbd_count=$(grep -c '^<TBD>$' "$REPORT_EXISTING" 2>/dev/null) || tbd_count=0
  if [[ "$tbd_count" -lt 8 ]]; then
    # Preserve the BODY, never the machine-specific header — see restamp_header above.
    hdr_note="$(restamp_header "$REPORT_EXISTING")"
    stale_note="$(warn_stale_abs_paths "$REPORT_EXISTING")"
    # Under --stdout the caller asked for the report ON stdout; on this branch the
    # report is the PRESERVED file, so emit that and keep the notes on stderr.
    if [[ $SINK_STDOUT -eq 1 ]]; then
      echo "Extract checklist preserved (already filled): $REPORT_EXISTING" >&2
      echo "  ($tbd_count of 8 LLM-fill sections still <TBD>; pass --force to regenerate fresh template)${hdr_note}${stale_note}" >&2
      cat "$REPORT_EXISTING"
      exit 0
    fi
    echo "Extract checklist preserved (already filled): $REPORT_EXISTING"
    echo "  ($tbd_count of 8 LLM-fill sections still <TBD>; pass --force to regenerate fresh template)${hdr_note}${stale_note}"
    exit 0
  fi
fi

# Helpers — count files, get sizes.
# `enum` is the single dual-form enumerator: flat `<name>.md` (depth 1) plus Agent Skills
# dir-form `<name>/SKILL.md` (depth 2). Every helper below routes through it so an inventory
# of a skills/ dir on the Agent Skills convention cannot silently report 0 files.
enum() {
  [[ -d "$1" ]] || return 0
  { find "$1" -maxdepth 1 -name '*.md' -not -name '_*' 2>/dev/null
    find "$1" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -not -path "$1/_*" 2>/dev/null
  } | sort
}
count() { enum "$1" | wc -l | tr -d ' '; }
total_lines() {
  local t=0 f
  while IFS= read -r f; do t=$(( t + $(wc -l < "$f" | tr -d ' ') )); done < <(enum "$1")
  echo "$t"
}
list_files() {
  enum "$1" | while IFS= read -r f; do
    echo "  - ${f#"$1"/} ($(wc -l < "$f" | tr -d ' ') lines)"
  done
}

{
  printf '# REFRESH extract checklist — %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\n\n' "$TARGET_LINE"
  printf 'Generated by: scripts/refresh-extract-checklist.sh\n\n'
  printf '> **MANDATORY for REFRESH/REFINE.** Phase 0.2 fills the prose sections below; `audit-setup.sh` C2b1 FAILS the run when any of sections 2-8 is left `<TBD>` (and section 9 when migration is in scope). Sections 10-12 are recorded for Phase 4 to consume but are not shell-gated. This file is the contract preventing surface-level "REFRESH = backup + version stamp + go" failures — keep it after the run; it is audited again by `/setup-project-health`, not deleted.\n\n'
  printf -- '---\n\n'

  # ---------- Section 1: Existing artifact inventory (auto-filled by this script) ----------
  printf '## 1. Existing artifact inventory (auto-filled by this script)\n\n'
  printf 'These counts are mechanically derived. The agent reads them; does not edit.\n\n'

  printf '### .claude/\n\n'
  for kind in agents commands skills rules hooks; do
    dir="$TARGET/.claude/$kind"
    if [[ -d "$dir" ]]; then
      n=$(count "$dir")
      printf -- '- **%s/**: %d files\n' "$kind" "$n"
      list_files "$dir"
    else
      printf -- '- **%s/**: not present\n' "$kind"
    fi
  done

  printf '\n### ai/\n\n'
  for f in CLAUDE.md AGENTS.md; do
    if [[ -f "$TARGET/$f" ]]; then
      printf -- '- **%s**: %d lines\n' "$f" "$(wc -l < "$TARGET/$f" | tr -d ' ')"
    else
      printf -- '- **%s**: not present\n' "$f"
    fi
  done
  for f in conventions.md architecture.md status.md modules.md business-domain.md project-goals.md; do
    if [[ -f "$TARGET/ai/$f" ]]; then
      printf -- '- **ai/%s**: %d lines\n' "$f" "$(wc -l < "$TARGET/ai/$f" | tr -d ' ')"
    fi
  done
  if [[ -d "$TARGET/ai/decisions" ]]; then
    n=$(find "$TARGET/ai/decisions" -name '*.md' -not -name '_*' -not -name 'README*' 2>/dev/null | wc -l | tr -d ' ')
    printf -- '- **ai/decisions/**: %d ADRs\n' "$n"
    find "$TARGET/ai/decisions" -name '*.md' -not -name '_*' -not -name 'README*' 2>/dev/null | sort | head -20 | while IFS= read -r adr; do
      printf '    - `%s`\n' "$(basename "$adr")"
    done
  fi
  for kind in patterns runbooks runtime audits dynamic; do
    dir="$TARGET/ai/$kind"
    if [[ -d "$dir" ]]; then
      n=$(find "$dir" -name '*.md' -not -name '_*' -not -name 'README*' 2>/dev/null | wc -l | tr -d ' ')
      printf -- '- **ai/%s/**: %d files\n' "$kind" "$n"
    fi
  done
  if [[ -d "$TARGET/ai/failures" ]]; then
    n=$(find "$TARGET/ai/failures" -name '*.md' -not -name '_*' 2>/dev/null | wc -l | tr -d ' ')
    printf -- '- **ai/failures/**: %d failure entries\n' "$n"
  fi

  printf '\n---\n\n'

  # ---------- Section 2-9: Required prose sections (Phase 0.2 fills) ----------
  cat <<'PROSE'
## 2. ADRs preserved (Phase 0.2 must fill)

> List every ADR by ID + title + one-line summary, then every append-only history file under `ai/audits/` and `ai/failures/` (path + one-line summary). All three are append-only; they will NOT be regenerated. Empty list when there are none.

<TBD>

## 3. Validated user corrections (Phase 0.2 must fill)

> User-given truth that is NOT in the codebase but must be preserved. Example: "Tenant scope auto-applied via AsyncLocalStorage — never accept tenant_id in request body." Source: existing rules, comments, ADRs, dynamic/feedback-learned.md.

<TBD>

## 4. Project intent (Phase 0.2 must fill)

> Facts the codebase doesn't encode but the team relies on. Goals, target users, business priorities, constraints (compliance, deadline, scale). Extracted from `ai/project-goals.md`, `ai/business-domain.md`, `ai/users-and-personas.md`, `ai/competitive-context.md`.

<TBD>

## 5. Custom rules (Phase 0.2 must fill)

> Rules AND conventions the project authored that are NOT in the universal pack — `.claude/rules/*.md` deltas plus the project-specific bullets of `ai/conventions.md` / `ai/_convention-cheatsheet.md`. Each: file path + 1-line purpose. Phase 4 wires these BACK into post-baseline overrides.

<TBD>

## 6. Custom agents/skills/commands (Phase 0.2 must fill)

> Agents/skills/commands the project authored that the pack doesn't have OR that the project specialized beyond pack equivalent. Per item: name + role + replaces/specializes which generic. Used by Phase 4.2 merge matrix to SKIP-with-redirect generic pack equivalents.

<TBD>

## 7. Architecture decisions implicit in code (Phase 0.2 must fill)

> Patterns visible in code but NOT documented in ADRs. Layering, framework choice, data-access style, error handling pattern. Also the project-idiom content of `ai/architecture.md`, `ai/patterns/*.md`, `ai/runbooks/*.md`, `ai/runtime/*.md` — preserved verbatim. Phase 4.6 anchors generated content to these.

<TBD>

## 8. Detected stack + version (Phase 0.2 must fill)

> Languages, frameworks, ORMs, test runners, build tools — with versions. From manifests, lock files, config files. Used by Phase 4.6 to cite the right APIs.

<TBD>

## 9. Migration / V1↔V2 mapping (only if migration in scope)

> If `--include=migration` was set OR Phase 2 detected V1+V2 layout: V1 root path, V2 root path, cutover mechanism, current ledger state. Phase 4.6 anchors migration artifacts to these.

<TBD>

## 10. Custom hooks — delta from baseline (Phase 0.2 fills; recorded, not shell-gated)

> Diff `.claude/hooks/*.sh` + `.claude/git-hooks/post-*` against `~/.claude/templates/repo-baseline/.claude/{hooks,git-hooks}/`; record additions/edits only. Phase 4.1 re-applies these on top of the regenerated baseline shims. Leave empty when every hook is baseline-verbatim.

## 11. Uncategorized user-touched files — catch-all sweep (Phase 0.2 fills; recorded, not shell-gated)

> After sections 2-10 are consumed, sweep every remaining file under `ai/` and `.claude/` that is mtime-newer than its baseline copy OR not byte-identical to its pack source. Record path + full content verbatim. This is the safety net against silent knowledge loss when new file categories outrun the sections above. Phase 4 MUST restore every entry at its original path or list it in section 12.

## 12. Drop list — intentionally NOT preserved (Phase 0.2 fills; recorded, not shell-gated)

> Existing files that are pack-equivalent and will be regenerated rather than extracted, plus any section-11 entry deliberately not restored. Path + one-line rationale each. Phase 5 reports these as "Intentional drops".
PROSE

  printf '\n---\n\n'
  printf '## Phase 5 audit gates this report\n\n'
  printf 'Phase 5 (verify) FAILS the run if:\n\n'
  printf -- '- Any of sections 2-8 is left as `<TBD>` (REFRESH default mode).\n'
  printf -- '- Section 9 is `<TBD>` AND `--include=migration` was set OR migration_layout_detected.\n'
  printf -- '- Section 1 (auto-filled) shows ≥10 files preserved AND sections 5/6 are empty (impossible — files exist but no extraction performed).\n\n'
  printf 'Sections 10-12 are **recorded, not shell-gated**: `audit-setup.sh` does not read them. They exist so Phase 4.1 (hook deltas), Phase 4 catch-all restore, and the Phase 5 "Intentional drops" report each address a numbered section of THIS file instead of an unwritten one. Phase 5 § "knowledge preservation check" enforces them in prose.\n\n'
  printf 'These gates exist because the historic REFRESH bug was exactly this: the agent ran "backup + version-stamp + a few derived files" and reported success, leaving the extract step at zero-effort.\n'
} > "$REPORT"

# --stdout: the report was buffered off-target; emit it now and leave $TARGET untouched.
# The summary lines move to stderr so the report file stays clean; the DEFAULT path,
# which run-preflight.sh reads from stdout, is unchanged.
if [[ -n "$REPORT_TMP" ]]; then
  cat "$REPORT_TMP"
  rm -f "$REPORT_TMP"
  REPORT_TMP=""
fi
say() { if [[ $SINK_STDOUT -eq 1 ]]; then echo "$@" >&2; else echo "$@"; fi; }
say "Extract checklist written: $REPORT_LABEL"
say "Phase 0.2 must now fill sections 2-8 (and 9 if migration in scope); 10-12 are recorded, not gated."
exit 0
