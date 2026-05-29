#!/usr/bin/env bash
# audit-setup.sh — Phase 5 deterministic audit. Read the 4 reports + verify completeness.
#
# Solves the "agent forgot to run Phase 5 audit" risk: this is a single script the
# orchestrator MUST invoke at the end of every refresh/refine/enhance/migration run.
# Returns 0 if all checks pass; non-zero with a numbered report otherwise.
#
# Usage:
#   audit-setup.sh <target-repo> [--mode=refresh|refine|enhance|create]
#
# Exits:
#   0 — all checks pass; safe to report success
#   1 — at least one mandatory check failed; agent must NOT report success
#   2 — usage error

set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-repo> [--mode=...]" >&2
  exit 2
fi

TARGET="$1"; shift
MODE="refresh"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#--mode=}"; shift ;;
    *)        shift ;;
  esac
done

CL="$TARGET/.claude"
fail=0
warn=0

err() { echo "  ERR  $*"; fail=$((fail + 1)); }
warn_msg() { echo "  WARN $*"; warn=$((warn + 1)); }
ok() { echo "  ok   $*"; }

echo "=== Phase 5 audit — target=$TARGET mode=$MODE ==="
echo ""

# C2b — required reports exist
echo "C2b: deterministic-coverage reports present"
for rpt in _pack-coverage-report.md _study-existing-report.md _codebase-scan.md; do
  if [[ -f "$CL/$rpt" ]]; then
    ok "$rpt"
  else
    err "$rpt missing — Phase 0.0 / Phase 4.0 didn't run"
  fi
done
if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
  if [[ -f "$CL/_refresh-extract.md" ]]; then
    ok "_refresh-extract.md (REFRESH/REFINE mode requires this)"
  else
    err "_refresh-extract.md missing — REFRESH/REFINE didn't run extract checklist"
  fi
fi

# Project-aware substrate check: in non-CREATE modes, Phase 2.5 should produce
# _extracted-idioms.md whenever the codebase has ≥1 base class with ≥3 extenders.
# Without it, AUTHOR-mode silently falls back to COPY-mode (generic templates with
# only the 5-facet anchor), and the system ships pack content that does not reflect
# this project's actual architecture. We can't deterministically tell whether the
# project HAS such base classes, so emit a WARN (not ERR) to surface the risk.
if [[ "$MODE" != "create" ]]; then
  if [[ -f "$CL/_extracted-idioms.md" ]]; then
    # Empty file or file with no `# <BaseName>` H1 sections = Phase 2.5 ran but
    # found no extenders — that's a valid outcome for true-greenfield code, but
    # the agent should have logged WHY. Just confirm the file exists.
    idioms_h1=$(grep -cE '^# ' "$CL/_extracted-idioms.md" 2>/dev/null || echo 0)
    if [[ "${idioms_h1:-0}" -gt 0 ]]; then
      ok "_extracted-idioms.md (${idioms_h1} base class section(s) — AUTHOR-mode substrate present)"
    else
      warn_msg "_extracted-idioms.md exists but has 0 base-class sections — AUTHOR-mode will fall back to COPY (generic templates). Confirm Phase 2.5's '<3-extenders' rationale is logged in plan."
    fi
  else
    warn_msg "_extracted-idioms.md missing — Phase 2.5 (deep idiom extraction) was skipped. AUTHOR-mode tracks will fall back to COPY-mode (generic templates), so the generated setup will be less project-specific. If the codebase has any base class with ≥3 extenders, re-run with Phase 2.5 enabled."
  fi
fi
echo ""

# C2b — extract sections non-empty
if [[ -f "$CL/_refresh-extract.md" ]]; then
  echo "C2b: refresh-extract sections filled"
  for section in "ADRs preserved" "Validated user corrections" "Project intent" "Custom rules" "Custom agents" "Architecture decisions" "Detected stack"; do
    # Find section header, then check next non-empty non-blockquote line for <TBD>
    section_first_line=$(awk -v sec="$section" '
      $0 ~ "^## .*"sec"" { in_sec=1; next }
      in_sec && /^## / { exit }
      in_sec && /^>/ { next }
      in_sec && /^[[:space:]]*$/ { next }
      in_sec { print; exit }
    ' "$CL/_refresh-extract.md" 2>/dev/null || true)
    if echo "$section_first_line" | grep -q '<TBD>'; then
      err "_refresh-extract.md § \"$section\" is still <TBD>"
    else
      ok "_refresh-extract.md § \"$section\" filled"
    fi
  done
  # Section 9 only required when migration in scope
  if grep -q "include=migration\|migration_layout_detected" "$TARGET"/.claude/codebase-profile.md 2>/dev/null; then
    if awk '/^## 9\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec && /^>/ { next } in_sec && /^[[:space:]]*$/ { next } in_sec { print; exit }' "$CL/_refresh-extract.md" | grep -q '<TBD>'; then
      err "_refresh-extract.md § 9 (migration mapping) is <TBD> but migration is in scope"
    fi
  fi
  echo ""
fi

# C2c — codebase-scan sections filled
if [[ -f "$CL/_codebase-scan.md" ]]; then
  echo "C2c: codebase-scan semantic sections filled"
  for section in "Module map" "Architecture pattern" "Conventions visible" "Patterns repeated" "Decisions implicit" "Drift between rules" "Stale references" "Recommended structural"; do
    section_first_line=$(awk -v sec="$section" '
      $0 ~ "^## .*"sec"" { in_sec=1; next }
      in_sec && /^## / { exit }
      in_sec && /^>/ { next }
      in_sec && /^[[:space:]]*$/ { next }
      in_sec { print; exit }
    ' "$CL/_codebase-scan.md" 2>/dev/null || true)
    if echo "$section_first_line" | grep -q '<TBD>'; then
      err "_codebase-scan.md § \"$section\" is <TBD>"
    else
      ok "_codebase-scan.md § \"$section\" filled"
    fi
  done

  # Section 15 must contain ≥3 structural recommendations
  recs=$(awk '
    /^## 15\./ { in_sec=1; next }
    in_sec && /^## / { exit }
    in_sec && /^- \*\*What\*\*:/ { count++ }
    END { print count + 0 }
  ' "$CL/_codebase-scan.md" 2>/dev/null || echo 0)
  recs="${recs:-0}"

  # Compute LOC from section 5 to gate "non-trivial" check
  loc_total=0
  if grep -q '^## 5\.' "$CL/_codebase-scan.md" 2>/dev/null; then
    loc_total=$({ awk '/^## 5\./ { in_sec=1; next } in_sec && /^## / { exit } in_sec' "$CL/_codebase-scan.md" 2>/dev/null || true; } \
      | { grep -oE '[0-9]+ lines' 2>/dev/null || true; } | { grep -oE '^[0-9]+' 2>/dev/null || true; } | awk '{s+=$1} END {print s+0}')
    loc_total="${loc_total:-0}"
  fi

  if [[ "$loc_total" -ge 1000 && "$recs" -lt 3 ]]; then
    err "_codebase-scan.md § 15 has $recs structural recommendations; minimum 3 required (LOC=$loc_total)"
  elif [[ "$loc_total" -lt 1000 ]]; then
    ok "_codebase-scan.md § 15 has $recs recommendations (small codebase, threshold relaxed)"
  else
    ok "_codebase-scan.md § 15 has $recs structural recommendations"
  fi
  echo ""
fi

# Pack coverage — every "Missing" row should be addressed (now present in target)
if [[ -f "$CL/_pack-coverage-report.md" ]]; then
  echo "C2b: pack coverage — Missing rows addressed"
  # Extract every "Missing" target path; check that each file now exists
  missing_unaddressed=0
  while IFS= read -r line; do
    # Lines look like: "- `<target-rel-path>` ← from `<src>`"
    target_rel=$(echo "$line" | sed -nE 's/^- `([^`]+)` ← from .*/\1/p')
    [[ -z "$target_rel" ]] && continue
    if [[ ! -f "$TARGET/$target_rel" ]]; then
      err "pack-coverage said missing → $target_rel still missing in target"
      missing_unaddressed=$((missing_unaddressed + 1))
    fi
  done < <(grep -E '^- `' "$CL/_pack-coverage-report.md" | grep '← from')
  [[ "$missing_unaddressed" -eq 0 ]] && ok "all 'Missing' rows addressed (or no missing rows)"
  echo ""
fi

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# C2h — Adapter sync coverage: when ≥1 adapter is enabled in target, every
# .claude/ source artifact must have its native counterpart in the adapter's
# folder (.opencode/, .cursor/, .github/, etc.). Reports ADD rows from
# apply-adapter-sync.sh. REFRESH/REFINE/ENHANCE require this.
if [[ -x "$SCRIPTS_DIR/apply-adapter-sync.sh" ]]; then
  echo "C2h: adapter-sync coverage (.claude/ → enabled adapters)"
  adapter_out=$("$SCRIPTS_DIR/apply-adapter-sync.sh" "$TARGET" 2>&1 || true)
  if echo "$adapter_out" | grep -q "No adapters enabled"; then
    ok "no adapters enabled — adapter-sync skipped"
  else
    add_count=$(echo "$adapter_out" | grep -cE '^    ADD ' || echo 0)
    add_count=${add_count:-0}
    refresh_count=$(echo "$adapter_out" | grep -cE '^    REFRESH ' || echo 0)
    refresh_count=${refresh_count:-0}
    missing_author=$(echo "$adapter_out" | grep -cE '^    MISSING-AUTHOR ' || echo 0)
    missing_author=${missing_author:-0}
    if [[ "$add_count" -gt 0 || "$refresh_count" -gt 0 ]]; then
      if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ]]; then
        err "$add_count adapter file(s) missing + $refresh_count drifted — run: ~/.claude/scripts/apply-adapter-sync.sh \"$TARGET\" --apply"
      else
        warn_msg "$add_count adapter file(s) missing (CREATE mode — first scaffold)"
      fi
    else
      ok "all 1:1 adapter-sync rows resolved"
    fi
    if [[ "$missing_author" -gt 0 ]]; then
      warn_msg "$missing_author adapter file(s) need LLM-authored format conversion — run: /setup-project-adapters"
    fi
  fi
  echo ""
fi

# C2g — Baseline coverage check: every file in repo-baseline/ must be present
# in target (ADD-rows from apply-baseline-sync.sh). REFRESH/REFINE/ENHANCE
# all require this; CREATE creates the baseline so the check is informational.
if [[ -x "$SCRIPTS_DIR/apply-baseline-sync.sh" ]]; then
  echo "C2g: repo-baseline coverage (ai/ + .claude/ scaffolds present)"
  baseline_out=$("$SCRIPTS_DIR/apply-baseline-sync.sh" "$TARGET" 2>&1 || true)
  add_count=$(echo "$baseline_out" | grep -cE '^  ADD ' || echo 0)
  add_count=${add_count:-0}
  if [[ "$add_count" -gt 0 ]]; then
    if [[ "$MODE" == "refresh" || "$MODE" == "refine" || "$MODE" == "enhance" ]]; then
      err "$add_count baseline file(s) missing in target — run: ~/.claude/scripts/apply-baseline-sync.sh \"$TARGET\" --apply"
    else
      warn_msg "$add_count baseline file(s) missing in target (CREATE mode — first scaffold)"
    fi
    # Show first 5 missing files for context
    echo "$baseline_out" | grep -E '^  ADD ' | head -5 | sed 's/^/    /'
  else
    ok "all repo-baseline files present"
  fi
  echo ""
fi

# C2f — STALE_KNOWLEDGE check (REFRESH / REFINE / ENHANCE only).
# After Phase 4.4 / 4.4b / 4.7 / 4.7b regen the ai/ knowledge layer, the derived
# files (_session-digest, _convention-cheatsheet, _decision-index, business-domain,
# users-and-personas, architecture, conventions) MUST be at least as recent as
# the most recent pack-source change. If pack source mtime > ai/<derived>.md mtime,
# the agent silently skipped knowledge regeneration — this is the failure mode
# observed when a REFRESH only updates 5 ai/patterns/ files instead of the full
# knowledge layer. CREATE mode is exempt (greenfield: nothing to compare against).
if [[ "$MODE" != "create" ]]; then
  echo "C2f: ai/ knowledge layer freshness vs pack source"

  # Most recent mtime across pack sources we depend on (claude-config repo).
  # Resolve the templates dir via the symlink at ~/.claude/templates (or use
  # CLAUDE_CONFIG_ROOT if exported).
  PACKS_ROOT="${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/packs"
  pack_newest=0
  if [[ -d "$PACKS_ROOT" ]]; then
    # find the newest .md file across pack sources (resolves symlinks via -L)
    while IFS= read -r f; do
      m=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
      [[ $m -gt $pack_newest ]] && pack_newest=$m
    done < <(find -L "$PACKS_ROOT" -type f -name '*.md' -not -name '_*' 2>/dev/null | head -2000)
  fi

  if [[ $pack_newest -eq 0 ]]; then
    warn_msg "pack source root not found at $PACKS_ROOT — skipping knowledge-freshness check"
  else
    # Files that REFRESH/REFINE must regenerate (relative to target)
    KNOWLEDGE_FILES=(
      "ai/_session-digest.md"
      "ai/_convention-cheatsheet.md"
      "ai/_decision-index.md"
      "ai/conventions.md"
      "ai/architecture.md"
      "ai/business-domain.md"
    )
    stale_count=0
    for rel in "${KNOWLEDGE_FILES[@]}"; do
      f="$TARGET/$rel"
      if [[ ! -f "$f" ]]; then
        if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
          err "knowledge file missing: $rel — Phase 4.4/4.7 should have written it"
          stale_count=$((stale_count + 1))
        fi
        continue
      fi
      file_mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
      if [[ $file_mtime -lt $pack_newest ]]; then
        # Format both timestamps for the message
        pack_iso=$(date -r "$pack_newest" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "@$pack_newest" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "?")
        file_iso=$(date -r "$file_mtime" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d "@$file_mtime" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "?")
        if [[ "$MODE" == "refresh" || "$MODE" == "refine" ]]; then
          err "STALE_KNOWLEDGE: $rel ($file_iso) older than newest pack source ($pack_iso) — Phase 4.4/4.4b/4.7/4.7b silently skipped"
        else
          warn_msg "STALE_KNOWLEDGE: $rel ($file_iso) older than newest pack source ($pack_iso) — consider /setup-project --refresh"
        fi
        stale_count=$((stale_count + 1))
      fi
    done
    [[ $stale_count -eq 0 ]] && ok "ai/ knowledge layer up-to-date vs pack source"
  fi
  echo ""
fi

# C2i — Foundational ai/ populate gate (EVERY mode). The baseline scaffold copies
# stub templates into ai/; ENHANCE/REFRESH historically left them untouched (could
# not tell a freshly-copied stub from real user content), shipping placeholder
# conventions.md / stack.md / modules.md green. C2g (presence) + C2f (mtime
# freshness) BOTH pass on a fresh stub, so neither caught it. This check fails when
# a foundational file is byte-identical to its repo-baseline source OR still carries
# baseline placeholder tokens. Spec: templates/phases/phase-5-verify.md §5.3.0.
echo "C2i: foundational ai/ files populated (not baseline stubs)"
BASELINE_AI="${CLAUDE_CONFIG_ROOT:-$HOME/.claude}/templates/repo-baseline/ai"
FOUNDATIONAL=( architecture stack modules status conventions business-domain _convention-cheatsheet )
STUB_TOKENS='<name>|<src/path|<e\.g\.,|<YYYY-MM-DD>|<detected|<EntityA>|<DetectedBase>|<NNNN>|<term>|<one-line'
stub_count=0
for fname in "${FOUNDATIONAL[@]}"; do
  tgt="$TARGET/ai/$fname.md"
  if [[ ! -f "$tgt" ]]; then
    err "foundational ai/ file missing: ai/$fname.md"
    stub_count=$((stub_count + 1)); continue
  fi
  base="$BASELINE_AI/$fname.md"
  if [[ -f "$base" ]] && diff -q "$base" "$tgt" >/dev/null 2>&1; then
    err "UNPOPULATED_STUB: ai/$fname.md is byte-identical to repo-baseline stub — Phase 4.7 never populated it (run /setup-project --refresh)"
    stub_count=$((stub_count + 1)); continue
  fi
  if grep -qE "$STUB_TOKENS" "$tgt" 2>/dev/null; then
    err "UNPOPULATED_STUB: ai/$fname.md still carries baseline placeholder tokens — population incomplete"
    stub_count=$((stub_count + 1))
  fi
done
[[ $stub_count -eq 0 ]] && ok "all foundational ai/ files populated"
echo ""

# Anchoring audit (M25.4): per-artifact coverage of the canonical
# `<!-- project-specific:start --> ... :end -->` block + `path:line` citations.
# REFUSE when anchors are missing in REFRESH / REFINE / ENHANCE modes (Phase 4.6
# was supposed to inject them via apply-anchors.sh). CREATE mode warns only —
# the agent may still be mid-flow when this runs and the profile may not exist.
# (SCRIPTS_DIR set earlier at C2g block)
if [[ -x "$SCRIPTS_DIR/audit-anchoring.sh" ]]; then
  echo "C2d: artifact anchoring"
  "$SCRIPTS_DIR/audit-anchoring.sh" "$TARGET" --quiet >/dev/null 2>&1 || true
  if [[ -f "$CL/_anchoring-audit.md" ]]; then
    pct=$(grep -E '^Coverage: \*\*' "$CL/_anchoring-audit.md" 2>/dev/null \
          | grep -oE '[0-9]+' | head -1 || true)
    unanchored=$(grep -E '^Unanchored:' "$CL/_anchoring-audit.md" 2>/dev/null \
                 | grep -oE '[0-9]+$' | head -1 || true)
    # When audit-anchoring.sh detects 0 pack-derived files, no `Coverage:` line is
    # emitted (audit-anchoring.sh:180-183 only writes it when total_eligible > 0).
    # Treat that case as a pass: every eligible artifact is anchored when there
    # are zero eligible artifacts.
    if [[ -z "$pct" ]] && grep -qE '^Pack-derived artifacts:[[:space:]]+\*\*0\*\*' "$CL/_anchoring-audit.md" 2>/dev/null; then
      ok "anchoring coverage n/a — 0 pack-derived artifacts (all are project-specific orphans)"
    fi
    if [[ -n "$pct" ]]; then
      if [[ "$unanchored" == "0" ]]; then
        ok "anchoring coverage ${pct}% — every pack-derived artifact carries an anchor block"
      elif [[ "$MODE" == "create" ]]; then
        warn_msg "anchoring coverage ${pct}% — ${unanchored} unanchored (CREATE mode; Phase 4.6 may not have run yet — re-run apply-anchors.sh)"
      else
        err "anchoring coverage ${pct}% — ${unanchored} pack-derived artifact(s) lack project anchors. Phase 4.6 must run: ~/.claude/scripts/apply-anchors.sh \"$TARGET\" --apply"
      fi
    fi
  fi
  echo ""
fi

# Adapter coverage audit (M34b): warn-only — verifies that adapter native files
# are in sync with .claude/ source artifacts. If no adapters were translated yet
# (zero native folders), this is informational; a passing C2d (anchoring) plus
# zero adapter native files = "user hasn't run /setup-project-adapters yet."
if [[ -x "$SCRIPTS_DIR/audit-adapter-coverage.sh" ]]; then
  echo "C2e: adapter translation coverage (M34b warn-only)"
  "$SCRIPTS_DIR/audit-adapter-coverage.sh" "$TARGET" >/dev/null 2>&1 || true
  if [[ -f "$CL/_adapter-coverage-audit.md" ]]; then
    # Extract pass/warn/fail counts from the table
    # Use awk — always exits 0 and prints a number, no grep -c "1 on no match" trap.
    err_n=$(awk '/^\| ❌/  {n++} END {print n+0}' "$CL/_adapter-coverage-audit.md" 2>/dev/null || echo 0)
    warn_n=$(awk '/^\| ⚠/ {n++} END {print n+0}' "$CL/_adapter-coverage-audit.md" 2>/dev/null || echo 0)
    ok_n=$(awk  '/^\| ✅/ {n++} END {print n+0}' "$CL/_adapter-coverage-audit.md" 2>/dev/null || echo 0)
    err_n="${err_n:-0}"; warn_n="${warn_n:-0}"; ok_n="${ok_n:-0}"
    if [[ "$ok_n" == "0" && "$warn_n" == "0" && "$err_n" == "0" ]]; then
      warn_msg "no adapter native files detected — run /setup-project-adapters to translate .claude/ to Cursor/OpenCode/etc native shapes"
    elif [[ "$err_n" -gt 0 ]]; then
      warn_msg "adapter coverage: $err_n adapter(s) below 80%; $warn_n warn; $ok_n ok — re-run /setup-project-adapters to refresh"
    elif [[ "$warn_n" -gt 0 ]]; then
      warn_msg "adapter coverage: $warn_n adapter(s) at 80-94%; $ok_n ok — minor drift, /setup-project-adapters to fully sync"
    else
      ok "adapter coverage: $ok_n adapter(s) at ≥95% — all in sync with .claude/"
    fi
  fi
  echo ""
fi

# Stack-agnostic template lint — scans this repo's `commands/` + `templates/**` (not TARGET).
# Ensures universal docs never pin a single stack without multi-stack diversity / `<TBD:...>`.
PACK_TEMPLATE_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
if [[ -x "$SCRIPTS_DIR/audit-stack-leakage.sh" ]]; then
  echo "C2f: stack-agnostic language (template pack source)"
  if leakage_out=$("$SCRIPTS_DIR/audit-stack-leakage.sh" --repo-root="$PACK_TEMPLATE_ROOT" 2>&1); then
    ok "stack leakage audit clean ($PACK_TEMPLATE_ROOT)"
  else
    echo "$leakage_out" >&2
    err "audit-stack-leakage.sh failed — fix universal docs or placeholders in claude-config"
  fi
  echo ""
fi

# Command DRY — SOLID/clean-code pointers + Phase 3 snippet links (template pack source).
if [[ -x "$SCRIPTS_DIR/audit-command-dry.sh" ]]; then
  echo "C2g: command DRY (SOLID/clean-code + Phase 3 snippets)"
  if dry_out=$("$SCRIPTS_DIR/audit-command-dry.sh" 2>&1); then
    echo "$dry_out"
    ok "audit-command-dry.sh clean"
  else
    echo "$dry_out" >&2
    err "audit-command-dry.sh failed — link core-discipline.md / phase-3-always-reads.md or remove duplicated prose"
  fi
  echo ""
fi

# Refactor artifact validator — smoke test (template pack source scripts/)
if [[ -x "$SCRIPTS_DIR/validate-refactor-artifacts.sh" ]]; then
  echo "C2i: validate-refactor-artifacts.sh --self-test"
  if refactor_self=$("$SCRIPTS_DIR/validate-refactor-artifacts.sh" --self-test 2>&1); then
    echo "$refactor_self"
    ok "validate-refactor-artifacts.sh --self-test passed"
  else
    echo "$refactor_self" >&2
    err "validate-refactor-artifacts.sh --self-test failed"
  fi
  echo ""
fi

# Summary
echo "=== summary ==="
echo "fail: $fail"
echo "warn: $warn"

if [[ "$fail" -gt 0 ]]; then
  echo ""
  echo "REFUSED — $fail mandatory check(s) failed."
  echo "The agent MUST NOT declare 'no work to do' / 'idempotent' / 'success' until these are addressed."
  exit 1
fi

echo ""
echo "PASS — Phase 5 audit clean. Safe to report success."
exit 0
