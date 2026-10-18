#!/usr/bin/env bash
# validate-align-artifacts.sh — universal align-discipline validator.
#
# Tool-agnostic. Runs from any AI tool's hook system, CI pipeline, or pre-commit.
# Validates the artifact set required by `align-discipline.md` for every finding
# in a phase (or for one finding with --finding=, or all with --all).
#
# Checks (per align-discipline.md § "Per-finding audit — 11 hard halts" + /align-gate's matrix):
#   1.  Evidence resolves        — every row's <path:line> resolves to a real file
#   2.  No hand-waves            — no "etc." / "..." / "several" / "multiple" / "N+"
#   3.  Closure verb in vocab    — verb in 21-verb closed vocabulary
#   4.  No new symbols           — git diff shows no new exports OR all named in idioms
#   5.  Net-lines non-positive   — structural rows: lines-removed ≥ lines-added
#   6.  Scope boundary           — EVERY commit of the row: touched files ⊂ row.scope (file level;
#                                  line level is align-sweep-gate.py scope)
#   7.  Oracle cited             — the row's `oracle:` quote is found in the cited file, or its
#                                  `<tool>:<rule-id>` is declared in a lint config (AL-01)
#   8.  Proof class              — a closed row carries proof_class EQ | VC | FN
#   9.  VC approval              — a VC row carries `approval: <name>@<iso>`, not written in the fix commit
#   10. Owner routed             — a security / perf / data / code-quality class row is `routed`, not
#                                  closed in align (the measured-baseline perf carve-out excepted)
#   11. Idiom citation           — functional rows that ADD code cite idiom_cited (git-confirmed)
#   12. Oracle unmodified        — the phase diff must not touch the oracle files
#   + legacy checks kept for old ledgers: security tier, security assertion, perf baseline.
#
# Classes: `al_class: AL-01 … AL-34` (the align-detect class ledger). Rows that carry only a legacy
# `class:` are mapped (reinvented-wrapper → AL-11, drift → AL-16, design-token-drift → AL-05, …); an
# al_class outside AL-01…AL-34 is a FAIL.
#
# A check that cannot run (no --phase-base, no git, no commit for the row) prints `NOT RUN — <why>`,
# counted in the summary; under --strict a NOT RUN is a failure. It is never a pass.
#
# Run-level checks (not per-finding):
#   - scan-report evidence — the scan report (ai/align/scan-report.md, or --scan-report=<path>) has a
#     status line for EVERY class AL-01 … AL-34 (checked / N/A / blocked / NOT RUN / Live / routed),
#     and the oracle line. A legacy report needs a `Detector: <class>` line or a NOT RUN line for each
#     of the 12 legacy detectors. A ledger that CLAIMS findings closed with no report → FAIL.
#   - progress/ledger reconciliation — progress.md must not mark a module `done` while the ledger
#     holds non-terminal rows in its scope (false-complete guard).
#
# Genuinely agent-side: the computed-style / visual diff, the mechanical run and boot, coverage.
# align-sweep-gate.py (find-and-align) carries line-level scope, re-detect, one-way-per-pattern,
# emitted names, round-trip, ratchet, test lock and non-vacuous.
#
# Usage:
#   validate-align-artifacts.sh --phase=<N>             # validate every row in phase N
#   validate-align-artifacts.sh --finding=<id>          # validate one finding
#   validate-align-artifacts.sh --all                   # validate every row in ledger
#   validate-align-artifacts.sh --strict                # treat warnings as errors
#   validate-align-artifacts.sh --quiet                 # only print failures
#   validate-align-artifacts.sh --check=<name>          # run only the named check
#   validate-align-artifacts.sh --check=scan-evidence   # run-level scan-report check only (no rows needed)
#   validate-align-artifacts.sh --scan-report=<path>    # e.g. ai/audits/<date>-align.md
#   validate-align-artifacts.sh --self-test             # fixtures under $TMPDIR, never the repo
#
# Exit codes:
#   0  — all checks pass
#   1  — at least one check failed
#   2  — usage error / unable to read ledger
#   3  — environment error (paths missing, tools missing)
#   4  — data-integrity error (duplicate IDs, malformed ledger)

set -euo pipefail
export LC_ALL=C

# ── Defaults (overridable via ai/align/_anchors.md) ─────────────────────────
LEDGER_PATH="ai/align/ledger.md"
PLAN_PATH="ai/align/plan.md"
HALTS_DIR="ai/align/halts"
IMPACT_DIR="ai/align/impact"
ANCHORS_FILE="ai/align/_anchors.md"
ORACLE_FILES=("_extracted-idioms.md" "ai/conventions.md" "ai/architecture.md")
SCAN_REPORT=""

PROJECT_KIND="frontend-vue"        # set per project via _anchors.md
EXTENSIONS_DEFAULT="ts tsx js jsx vue py go rb php java kt swift"

PHASE=""
FINDING=""
SCAN_ALL=0
STRICT=0
QUIET=0
CHECK_FILTER=""
PHASE_BASE=""

# ── Args ────────────────────────────────────────────────────────────────────
# ── --self-test ───────────────────────────────────────────────────────────────
# GOOD fixtures that must pass and BAD ones that must fail, all under a mktemp -d in $TMPDIR.
# (The first version wrote into <repo>/tmp/, i.e. into the tree being validated.)
#
# Writing the first self-test found the bare-`return` bug in check_no_new_symbols: on the warn-only
# path the function returned 1 and `set -e` killed the run mid-check, so a fixture whose every check
# passed exited 1 with no summary.
run_align_self_test() {
  local td rc me fails=0 n=0
  # Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
  # § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
  _ss="${BASH_SOURCE[0]}"
  while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
  me="$(cd -P "$(dirname "$_ss")" && pwd)/$(basename "$_ss")"; unset _ss _sd
  td=$(mktemp -d "${TMPDIR:-/tmp}/align-selftest.XXXXXX")
  trap 'rm -rf "$td"' EXIT

  mk_good() {   # a fresh GOOD tree in $td/case
    rm -rf "$td/case"; mkdir -p "$td/case/ai/align" "$td/case/src"
    printf 'const a = 1\nconst b = 2\n' > "$td/case/src/a.ts"
    printf '# Conventions\n\n- Data access goes through `src/lib/api-client.ts`; never import `ky` directly.\n' > "$td/case/ai/conventions.md"
    cat > "$td/case/ai/align/ledger.md" <<'FIX'
# Align ledger

```yaml
- id: A001
  al_class: AL-11
  class: reinvented-wrapper
  oracle: 'ai/conventions.md:3 "never import `ky` directly."'
  oracle_tier: T2
  owner: align
  scope: [src/a.ts]
  evidence:
    - src/a.ts:1
  closure_verb: remove
  proof_class: EQ
  tier: trivial
  tier_reason: "single-line swap, no behaviour change"
  status: verified
  phase: 1
  detected_at: 2026-10-18T09:00:00Z
  gaps_in: 1
  gaps_closed: 1

- id: A002
  class: security
  scope: [src/a.ts]
  evidence:
    - src/a.ts:2
  routed: "/security-fix ai/audits/2026-10-18-align.md#S1"
  tier: standard
  tier_reason: "owner row"
  status: routed
  phase: 1
```
FIX
    { echo "# Align scan report"; echo; echo "oracle: T1 0 · T1-warn 0 · T1-noci 0 · T2 1 · T2g 0 (unratified) · contested 0"; echo
      for i in $(seq 1 32); do printf '  AL-%02d  checked (1 hits → 0 findings)   owner: align\n' "$i"; done
      echo "  AL-33 / AL-34  N/A (audit — checked on the fix)   owner: align"; } > "$td/case/ai/align/scan-report.md"
  }
  expect() {    # $1=want(0|nonzero) $2=label, rest = args
    local want="$1" label="$2"; shift 2; n=$((n + 1)); rc=0
    ( cd "$td/case" && bash "$me" "$@" >/dev/null 2>&1 ) || rc=$?
    if { [[ "$want" == 0 && $rc -ne 0 ]] || [[ "$want" != 0 && $rc -eq 0 ]]; }; then
      echo "self-test FAIL: $label (exit $rc)" >&2; fails=$((fails + 1)); fi
  }
  edit() { sed "$1" "$td/case/$2" > "$td/case/$2.tmp" && mv "$td/case/$2.tmp" "$td/case/$2"; }

  mk_good; expect 0 "the GOOD fixture passes" --all
  mk_good; expect 0 "--check=scan-evidence passes on a full AL report" --check=scan-evidence
  mk_good; expect 1 "a NOT RUN check fails under --strict (no git, no --phase-base)" --all --strict
  # `parallelise` — the British spelling of a verb that IS in the vocabulary. A closed set is only
  # closed if a near-miss is refused; a substring or fuzzy match would let this by.
  mk_good; edit 's/closure_verb: remove/closure_verb: parallelise/' ai/align/ledger.md; expect 1 "verb outside the closed 21" --all
  mk_good; edit '/  AL-17 /d' ai/align/scan-report.md; expect 1 "scan report missing AL-17" --check=scan-evidence
  # AD-8: the old check passed on ONE `Detector:` block out of twelve.
  mk_good; printf '# Align scan report\n\nOracle consulted: `.claude/_extracted-idioms.md`.\n\nDetector: dead-code | Modules scanned: 1 | Fingerprint matches: 1\n' > "$td/case/ai/align/scan-report.md"
  expect 1 "legacy report with 1 of 12 detectors" --check=scan-evidence
  mk_good; edit 's/oracle: T1 0 .*//' ai/align/scan-report.md; expect 1 "scan report with no oracle line" --check=scan-evidence
  mk_good; edit 's/never import `ky` directly/always import ky/' ai/align/ledger.md; expect 1 "oracle quote not in the cited file (AL-01)" --all
  mk_good; edit 's/  oracle: .*/  oracle: eslint:no-restricted-imports/' ai/align/ledger.md; expect 1 "oracle rule declared in no lint config" --all
  mk_good; edit 's/proof_class: EQ/proof_class: VC/' ai/align/ledger.md; expect 1 "VC row closed without approval (V407)" --all
  mk_good; edit 's/proof_class: EQ/proof_class: VC/' ai/align/ledger.md
  python3 -I - "$td/case/ai/align/ledger.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read(); s=s.replace('proof_class: VC\n','proof_class: VC\n  approval: ana@2026-10-18T10:00Z\n',1); open(p,'w').write(s)
PY
  expect 0 "VC row with a human approval passes" --all
  mk_good; edit '/  proof_class: EQ/d' ai/align/ledger.md; expect 1 "closed AL row without proof_class" --all
  mk_good; edit 's/al_class: AL-11/al_class: AL-99/' ai/align/ledger.md; expect 1 "al_class outside AL-01 … AL-34" --all
  mk_good; edit 's/status: routed/status: fixed/' ai/align/ledger.md; expect 1 "security row closed in align instead of routed" --all
  mk_good; edit 's/  routed: .*/  routed: ""/' ai/align/ledger.md; expect 1 "routed row with no destination" --all

  rm -rf "$td"; trap - EXIT
  if [[ $fails -gt 0 ]]; then echo "validate-align-artifacts.sh --self-test: $fails of $n FAILED" >&2; exit 1; fi
  echo "validate-align-artifacts.sh --self-test OK ($n/$n)"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase=*)       PHASE="${1#--phase=}"; shift ;;
    --finding=*)     FINDING="${1#--finding=}"; shift ;;
    --all)           SCAN_ALL=1; shift ;;
    --strict)        STRICT=1; shift ;;
    --quiet)         QUIET=1; shift ;;
    --self-test)    run_align_self_test ;;
    --check=*)       CHECK_FILTER="${1#--check=}"; shift ;;
    --phase-base=*)  PHASE_BASE="${1#--phase-base=}"; shift ;;
    --scan-report=*) SCAN_REPORT="${1#--scan-report=}"; shift ;;
    -h|--help)
      grep -E '^#' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--phase=N | --finding=ID | --all] [--strict] [--quiet] [--check=NAME]" >&2
      exit 2
      ;;
  esac
done

[[ "$CHECK_FILTER" == "scan-evidence" ]] && SCAN_ALL=1
if [[ -z "$PHASE" && -z "$FINDING" && "$SCAN_ALL" -eq 0 ]]; then
  echo "Usage: $0 [--phase=N | --finding=ID | --all]" >&2
  exit 2
fi

if [[ ! -f "$LEDGER_PATH" && "$CHECK_FILTER" != "scan-evidence" ]]; then
  echo "FATAL: ledger not found at $LEDGER_PATH" >&2
  echo "Run /align-scan first, OR you're in the wrong directory." >&2
  exit 3
fi

# ── Output helpers ──────────────────────────────────────────────────────────
TOTAL_CHECKED=0
TOTAL_PASS=0
TOTAL_FAIL=0
declare -a FAILURES=()
log_pass() {
  TOTAL_PASS=$((TOTAL_PASS + 1))
  if [[ $QUIET -eq 0 ]]; then
    echo "  ✓ $1"
  fi
}

log_fail() {
  TOTAL_FAIL=$((TOTAL_FAIL + 1))
  FAILURES+=("$1")
  echo "  ✗ $1" >&2
}

log_warn() {
  if [[ $STRICT -eq 1 ]]; then
    log_fail "[strict] $1"
  elif [[ $QUIET -eq 0 ]]; then
    echo "  ⚠ $1"
  fi
}

TOTAL_NOTRUN=0
log_notrun() {
  TOTAL_NOTRUN=$((TOTAL_NOTRUN + 1))
  if [[ $STRICT -eq 1 ]]; then
    log_fail "[strict] NOT RUN — $1"
  elif [[ $QUIET -eq 0 ]]; then
    echo "  ⊘ NOT RUN — $1"
  fi
  return 0
}

log_section() {
  if [[ $QUIET -eq 0 ]]; then
    echo
    echo "── $1 ──"
  fi
}

# ── Project anchors ─────────────────────────────────────────────────────────
load_project_anchors() {
  if [[ ! -f "$ANCHORS_FILE" ]]; then
    return 0
  fi
  local fm
  fm=$(awk '/^---$/{c++; next} c==1' "$ANCHORS_FILE")
  local pk
  pk=$(echo "$fm" | grep -m1 '^project_kind:' | sed 's/^project_kind:[[:space:]]*//' | tr -d '"' | tr -d "'")
  [[ -n "$pk" ]] && PROJECT_KIND="$pk"
}

# ── Parse ledger to discover findings ──────────────────────────────────────
# Ledger format (per align-ledger.md): yaml-fenced or yaml-block format.
# Each row has: id, class, scope (list), evidence (list), closure_verb, tier,
# status, phase (optional), idiom_cited (optional), severity (security only).
#
# Output: "<id>|<class>|<phase>|<status>|<tier>|<closure_verb>|<severity>|<al_class>"
discover_findings() {
  awk '
    /^- id: A[0-9]+[a-z]?$/ {
      if (id != "") print id "|" class "|" phase "|" status "|" tier "|" verb "|" severity "|" al
      id = $3; class=""; phase=""; status=""; tier=""; verb=""; severity=""; al=""
      in_block = 1
      next
    }
    /^[[:space:]]*$/ && in_block == 1 {
      # Blank line ends a yaml block in this format
      if (id != "") print id "|" class "|" phase "|" status "|" tier "|" verb "|" severity "|" al
      id=""; class=""; phase=""; status=""; tier=""; verb=""; severity=""; al=""
      in_block = 0
      next
    }
    in_block && /^[[:space:]]+al_class:/     { al=$2; gsub(/["\047]/,"",al); next }
    in_block && /^[[:space:]]+class:/        { class=$2; next }
    in_block && /^[[:space:]]+phase:/        { phase=$2; next }
    in_block && /^[[:space:]]+status:/       { status=$2; next }
    in_block && /^[[:space:]]+tier:/         { tier=$2; next }
    in_block && /^[[:space:]]+closure_verb:/ { verb=$2; next }
    in_block && /^[[:space:]]+severity:/     { severity=$2; next }
    END {
      if (id != "") print id "|" class "|" phase "|" status "|" tier "|" verb "|" severity "|" al
    }
  ' "$LEDGER_PATH"
}

# ── AL class enum + the legacy map (align-detect § The legacy class map) ─────
# Prints the AL id for a row: its al_class when present, else the legacy class mapped. An owner
# class (closed by another pack) prints `owner:<pack>`; an unknown legacy name prints `unmapped`.
resolve_al() {
  local al="$1" cls="$2"
  if [[ -n "$al" ]]; then echo "$al"; return; fi
  case "$cls" in
    reinvented-wrapper|raw-library-component) echo "AL-11" ;;
    drift) echo "AL-16" ;;
    stack-specific|design-token-drift) echo "AL-05" ;;
    i18n-key-drift) echo "AL-26" ;;
    permission-gate-drop|default-true-prop) echo "AL-15" ;;
    a11y-violation) echo "AL-28" ;;
    security) echo "owner:security" ;;
    performance) echo "owner:performance" ;;
    silent-catch|unhandled-io|dead-code|duplicated-logic|over-abstraction|solid-violation|clean-code) echo "owner:code-quality" ;;
    "") echo "unmapped" ;;
    *) echo "unmapped" ;;
  esac
}

is_al_id() { [[ "$1" =~ ^AL-(0[1-9]|[12][0-9]|3[0-4])$ ]]; }

# ── Row field helper (scalar on one line) ───────────────────────────────────
row_field() {   # $1=id $2=field → the value, quotes stripped
  awk -v id="$1" -v f="$2" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block && /^[[:space:]]*$/ { exit }
    in_block && $0 ~ "^[[:space:]]+" f ":" { sub("^[[:space:]]+" f ":[[:space:]]*", ""); sub(/[[:space:]]+#.*$/, "")
      if ($0 == "\"\"" || $0 == "\047\047") $0 = ""; print; exit }
  ' "$LEDGER_PATH"
}

filter_findings() {
  if [[ -n "$FINDING" ]]; then
    grep "^${FINDING}|" || true
  elif [[ -n "$PHASE" ]]; then
    awk -F'|' -v p="$PHASE" '$3 == p' || true
  else
    cat
  fi
}

# ── Closure-verb vocabulary (21 verbs) ──────────────────────────────────────
STRUCTURAL_VERBS="remove inline dedupe rename-comment-out replace-with-shared"
FUNCTIONAL_VERBS="add-gate parameterize escape move-to-secrets add-validator parallelize batch project-columns add-index cache-with-explicit-ttl extract-to-shared split-extract inline-magic-to-named-const inline-filter-to-query bump-dep rename"
ALL_VERBS="$STRUCTURAL_VERBS $FUNCTIONAL_VERBS"

is_structural_class() {
  local cls="$1"
  case "$cls" in
    # silent-catch is functional (align-discipline § Finding categories): removing a swallow
    # changes observable behaviour, so the net-lines ≤ 0 rule does not apply to it.
    dead-code|duplicated-logic|reinvented-wrapper|over-abstraction|drift)
      return 0 ;;
    # AL classes closed by a structural verb (swap, rename, move, remove). AL-15 / AL-28 add a
    # declared prop or gate (functional); AL-30 / AL-31 edit config; AL-01–04 are never edited.
    AL-0[5-9]|AL-1[0-46-9]|AL-2[0-26]|AL-29|AL-32)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── CHECK 1: evidence resolves ───────────────────────────────────────────────
# Read all `evidence:` <path:line> entries for the row from the ledger;
# verify each path exists and the line number is within bounds.
check_evidence_resolves() {
  local id="$1"
  local row_block
  row_block=$(awk -v id="$id" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block { print }
    /^[[:space:]]*$/ && in_block { exit }
  ' "$LEDGER_PATH")

  local in_evidence=0
  local missing=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]+evidence: ]]; then
      in_evidence=1
      # Inline list?  evidence: [path:line, path:line]
      local inline
      inline=$(echo "$line" | sed 's/^[[:space:]]*evidence:[[:space:]]*//; s/^\[//; s/\]$//')
      if [[ -n "$inline" && "$inline" != "[]" ]]; then
        IFS=',' read -ra entries <<< "$inline"
        for entry in "${entries[@]}"; do
          entry=$(echo "$entry" | xargs)  # trim
          [[ -z "$entry" ]] && continue
          if ! evidence_resolves "$entry"; then
            log_fail "$id: evidence does not resolve: $entry"
            missing=$((missing + 1))
          fi
        done
        in_evidence=0
        continue
      fi
      continue
    fi

    if [[ $in_evidence -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]+- ]]; then
        local entry
        entry=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/[[:space:]]*#.*$//' | tr -d '"' | tr -d "'")
        [[ -z "$entry" ]] && continue
        if ! evidence_resolves "$entry"; then
          log_fail "$id: evidence does not resolve: $entry"
          missing=$((missing + 1))
        fi
      else
        in_evidence=0
      fi
    fi
  done <<< "$row_block"

  if [[ $missing -eq 0 ]]; then
    log_pass "$id: evidence resolves"
  fi
}

evidence_resolves() {
  local entry="$1"
  if [[ ! "$entry" =~ ^([^:]+):([0-9]+)$ ]]; then
    return 1
  fi
  local path="${BASH_REMATCH[1]}"
  local lineno="${BASH_REMATCH[2]}"
  [[ ! -f "$path" ]] && return 1
  local file_lines
  file_lines=$(wc -l < "$path")
  (( lineno <= file_lines + 1 )) || return 1
  return 0
}

# ── CHECK 2: no hand-waves in any field ─────────────────────────────────────
check_scan_report_evidence() {
  # Without a status line per class, the scan is a Trusted Summary: "no findings" and "did not look"
  # print the same way. The report is ai/align/scan-report.md (what /align-scan writes for the pack's
  # readers), or --scan-report=<path> (e.g. ai/audits/<date>-align.md).
  local scan_report="${SCAN_REPORT:-${ALIGN_DIR:-ai/align}/scan-report.md}"
  if [[ ! -f "$scan_report" ]]; then
    # Absent report is acceptable only when the run makes NO findings-closed claim.
    local terminal_rows=0
    [[ -f "$LEDGER_PATH" ]] && terminal_rows=$(grep -cE '^[[:space:]]+status:[[:space:]]*(fixed|verified|archived-pre-existing)\b' "$LEDGER_PATH" 2>/dev/null || true)
    terminal_rows=${terminal_rows:-0}
    if [[ "$terminal_rows" -gt 0 ]]; then
      log_fail "scan report absent at $scan_report but the ledger holds $terminal_rows terminal (findings-closed) row(s). A run that claims findings closed MUST have a scan report with a status line per class — a skipped scan must not look like a clean codebase (Trusted-Summary)."
      return 1
    fi
    if [[ "$CHECK_FILTER" == "scan-evidence" ]]; then
      log_fail "scan report absent at $scan_report (--check=scan-evidence needs one)"
      return 1
    fi
    [[ $QUIET -eq 0 ]] && echo "  ▸ scan report not present at $scan_report and no findings-closed claim in ledger (nothing to check)"
    return 0
  fi

  # A status token: checked (…) · N/A (…) · blocked (…) · NOT RUN (…) / not run (…) · Live, unreviewed / ratcheted · routed (…)
  local status_rx='(checked[[:space:]]*\(|N/A[[:space:]]*\(|blocked[[:space:]]*\(|NOT RUN|not run[[:space:]]*\(|Live, (unreviewed|ratcheted)|routed[[:space:]]*\()'
  local missing=() n i al
  if grep -qE '\bAL-(0[1-9]|[12][0-9]|3[0-4])\b' "$scan_report"; then
    for i in $(seq 1 34); do
      al=$(printf 'AL-%02d' "$i")
      # The class's status may share a line with its neighbours (`AL-33 / AL-34  N/A (…)`).
      if ! grep -E "\b${al}\b" "$scan_report" | grep -qE "$status_rx"; then missing+=("$al"); fi
    done
    n=$((34 - ${#missing[@]}))
    if [[ ${#missing[@]} -gt 0 ]]; then
      log_fail "scan report covers $n of 34 AL classes; no status line for: ${missing[*]}. Every class prints checked / N/A / blocked / NOT RUN / Live / routed — a class with no line reads as 'looked, nothing found'."
      return 1
    fi
  else
    # Legacy report (before the AL ids): every one of the 12 legacy detectors ran or says why not.
    local legacy="dead-code duplicated-logic reinvented-wrapper silent-catch over-abstraction drift solid-violation clean-code performance security unhandled-io stack-specific" d
    for d in $legacy; do
      grep -qE "Detector:[[:space:]]+${d}\b|\b${d}\b.*NOT RUN|NOT RUN.*\b${d}\b" "$scan_report" || missing+=("$d")
    done
    n=$((12 - ${#missing[@]}))
    if [[ ${#missing[@]} -gt 0 ]]; then
      log_fail "legacy scan report covers $n of 12 detectors; no 'Detector: <class>' or NOT RUN line for: ${missing[*]}. Re-run /align-scan, which prints the AL-01 … AL-34 ledger."
      return 1
    fi
  fi

  # The oracle line: the oracle-map tier line, or a cited oracle file.
  if ! grep -qE '(^|[^a-z])oracle:[[:space:]]*T1|Oracle:|_extracted-idioms\.md|codebase-profile\.md|ai/conventions\.md|ai/architecture\.md' "$scan_report"; then
    log_fail "scan report cites no oracle (the oracle-map tier line 'oracle: T1 n · T2 n · …' or the oracle files it read)."
    return 1
  fi

  log_pass "scan-report evidence: $n classes with a status line; oracle cited ($scan_report)"
  return 0
}

# ── CHECK: progress.md ↔ ledger.md reconciliation (single source of truth) ──
# ai/align/ledger.md is the validated source of truth; ai/align/progress.md is a derived
# module roll-up. They can silently disagree → false-complete (progress says a module is
# `done` while the ledger still holds non-terminal rows for it). When BOTH files exist, every
# module marked `done` / `[done]` in progress.md MUST have zero non-terminal ledger rows whose
# scope falls under that module. Absent progress.md = nothing to reconcile (ledger is canonical).
PROGRESS_CHECKED=0
check_progress_ledger_reconciliation() {
  [[ "${PROGRESS_CHECKED:-0}" == "1" ]] && return 0
  PROGRESS_CHECKED=1
  local progress="${ALIGN_DIR:-ai/align}/progress.md"
  if [[ ! -f "$progress" ]]; then
    [[ $QUIET -eq 0 ]] && echo "  ▸ progress.md not present (ledger is the sole source of truth; nothing to reconcile)"
    return 0
  fi

  # Module names marked done in progress.md.
  # Shapes accepted: "### <module> [done]"  OR  "- <module>: done".
  local done_modules
  done_modules=$(grep -iE '^###[[:space:]]+\S+[[:space:]]+\[done\]|^-[[:space:]]+\S+:[[:space:]]*done\b' "$progress" 2>/dev/null \
    | sed -E 's/^###[[:space:]]+([^[:space:]]+).*/\1/; s/^-[[:space:]]+([^:]+):.*/\1/' \
    | sed 's/[[:space:]]*$//' | sort -u || true)
  if [[ -z "$done_modules" ]]; then
    log_pass "progress.md ↔ ledger: no modules marked done; nothing to reconcile"
    return 0
  fi

  # Non-terminal ledger rows: status ∈ {detected, planned, in-progress, halted}. Buffer each row's full
  # block first (scope: and status: can appear in either order), then emit "<id>|<status>|<scope>"
  # lines only for rows whose status is non-terminal.
  local nonterminal
  nonterminal=$(awk '
    function flush() {
      if (id != "" && (status=="detected" || status=="planned" || status=="in-progress" || status=="halted")) {
        for (i=1; i<=ns; i++) print id "|" status "|" scopes[i]
      }
      id=""; status=""; ns=0
    }
    /^- id: / { flush(); id=$3; next }
    id != "" && /^[[:space:]]+status:/ { status=$2; next }
    id != "" && /^[[:space:]]+scope:/ {
      line=$0; sub(/^[[:space:]]+scope:[[:space:]]*/,"",line)
      gsub(/[][]/,"",line)
      n=split(line, parts, ",")
      for (i=1;i<=n;i++) { gsub(/^[[:space:]]+|[[:space:]]+$/,"",parts[i]); if (parts[i]!="") scopes[++ns]=parts[i] }
      inscope=1; next
    }
    id != "" && inscope && /^[[:space:]]+-[[:space:]]/ {
      line=$0; sub(/^[[:space:]]+-[[:space:]]*/,"",line); if (line!="") scopes[++ns]=line; next
    }
    id != "" && /^[[:space:]]+[a-z_]+:/ { inscope=0 }
    END { flush() }
  ' "$LEDGER_PATH" 2>/dev/null || true)

  local violations=0 mod
  while IFS= read -r mod; do
    [[ -z "$mod" ]] && continue
    local hit
    hit=$(printf '%s\n' "$nonterminal" | grep -F "$mod" | head -3 || true)
    if [[ -n "$hit" ]]; then
      log_fail "progress.md marks module '$mod' done, but the ledger holds non-terminal row(s) in its scope (false-complete). ledger.md is the source of truth — re-project progress.md after these rows reach a terminal state:"
      while IFS='|' read -r vid vstatus vscope; do
        [[ -z "$vid" ]] && continue
        echo "        $vid (status=$vstatus): $vscope" >&2
      done <<< "$hit"
      violations=$((violations + 1))
    fi
  done <<< "$done_modules"

  if [[ $violations -eq 0 ]]; then
    log_pass "progress.md ↔ ledger reconciled: every done module has only terminal ledger rows"
    return 0
  fi
  return 1
}

check_no_handwaves() {
  local id="$1"
  local row_block
  row_block=$(awk -v id="$id" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block { print }
    /^[[:space:]]*$/ && in_block { exit }
  ' "$LEDGER_PATH")

  local hits
  hits=$(echo "$row_block" | grep -iE '\betc\.|\.\.\.|\bseveral\b|\bmultiple (call sites|endpoints|places)\b|\bN\+ (duplicates|items)\b|\band so on\b|\band similar\b' || true)
  if [[ -n "$hits" ]]; then
    log_fail "$id: hand-wave token detected — refactor row to enumerate instances explicitly"
    if [[ $QUIET -eq 0 ]]; then
      echo "$hits" | head -3 | sed 's/^/        /'
    fi
  else
    log_pass "$id: no hand-waves"
  fi
}

# ── CHECK 3: closure verb in vocabulary ─────────────────────────────────────
check_closure_verb_in_vocab() {
  local id="$1" verb="$2"
  if [[ -z "$verb" ]]; then
    log_fail "$id: closure_verb missing"
    return
  fi
  if [[ " $ALL_VERBS " == *" $verb "* ]]; then
    log_pass "$id: closure_verb '$verb' is in vocabulary"
  else
    log_fail "$id: closure_verb '$verb' NOT in 21-verb vocabulary — re-classify or route to /refactor"
  fi
}

# ── CHECK 4: no new symbols (with idioms-named exemption) ───────────────────
# Diff <phase-base>..HEAD for added exports. Each new export must be named in
# _extracted-idioms.md, otherwise it's a Reinvented Wrapper.
check_no_new_symbols() {
  local id="$1"
  # Fail-closed (#30): when we CAN'T verify, surface it — under --strict it's a halt, not a
  # silent pass, so a missing phase-base / git doesn't let a Reinvented Wrapper slip through.
  if [[ -z "$PHASE_BASE" ]]; then
    log_notrun "$id: no-new-symbols (no --phase-base)"
    # `return 0`, NOT a bare `return`. The line above is `[[ $STRICT -eq 1 ]] && { … }`, and
    # when strict is OFF that test is false, so the compound command exits 1 — which a bare
    # `return` then hands back as the function's status. Under this file's `set -e` the caller
    # aborts, so the validator DIED HERE mid-run and exited 1 on a warn-only path: no summary,
    # no remaining checks, and an exit code indistinguishable from a real finding.
    #
    # Reproduced on a fixture whose every check passed — 4 ✓, one ⚠, then nothing. Found by
    # writing this script's first --self-test.
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_notrun "$id: no-new-symbols (git not on PATH)"
    return 0
  fi

  # #18 — scan ALL added lines, not just added FILES. The Reinvented-Wrapper anti-pattern most
  # often adds a new `export function fooWrapper()` INTO an existing module; --diff-filter=A
  # (added files only) never saw it. The `^\+(export …)` grep already restricts to added lines.
  local diff_added
  diff_added=$(git diff "$PHASE_BASE..HEAD" 2>/dev/null \
    | grep -E '^\+(export\s+(default\s+)?(function|class|const|let|interface|type)|export\s+\{)' \
    | grep -v '^+++' \
    | head -40 || true)

  if [[ -z "$diff_added" ]]; then
    log_pass "$id: no new exports"
    return
  fi

  # New exports exist but no idioms inventory to check them against = un-verifiable → FAIL
  # (fail-closed, #30): we cannot claim these are exempt reuses without the inventory.
  if [[ ! -f "_extracted-idioms.md" ]]; then
    log_fail "$id: new exports added but _extracted-idioms.md not found — cannot verify they reuse existing idioms (Reinvented Wrapper un-verifiable; add the idioms inventory or justify)."
    return 1
  fi

  local violations=0
  while IFS= read -r exline; do
    [[ -z "$exline" ]] && continue
    local symbol
    symbol=$(echo "$exline" | grep -oE '(function|class|const|let|interface|type)\s+[A-Za-z_][A-Za-z0-9_]*' | awk '{print $2}' | head -1)
    [[ -z "$symbol" ]] && continue
    if ! grep -q "$symbol" "_extracted-idioms.md" 2>/dev/null; then
      log_fail "$id: new export '$symbol' not named in _extracted-idioms.md (Reinvented Wrapper anti-pattern)"
      violations=$((violations + 1))
    fi
  done <<< "$diff_added"

  if [[ $violations -eq 0 ]]; then
    log_pass "$id: new exports all named in idioms inventory"
  fi
}

# ── CHECK 5: net-lines non-positive on structural rows ──────────────────────
check_net_lines_structural() {
  local id="$1" cls="$2"
  if ! is_structural_class "$cls"; then
    log_pass "$id: functional class '$cls' — net-lines rule N/A (idiom citation applies instead)"
    return
  fi
  if [[ -z "$PHASE_BASE" ]]; then
    log_notrun "$id: net-lines (no --phase-base)"
    return
  fi
  if ! command -v git >/dev/null 2>&1; then
    log_notrun "$id: net-lines (git not on PATH)"
    return
  fi

  # Find commit(s) for this row by message convention: align/<phase>/<id>:
  local row_commits
  row_commits=$(git log --grep="${id}:" --format='%H' "$PHASE_BASE..HEAD" 2>/dev/null || true)
  if [[ -z "$row_commits" ]]; then
    log_notrun "$id: net-lines (no commit carries '$id:' in its subject)"
    return
  fi

  local added=0 removed=0
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    local stat
    stat=$(git show --shortstat "$sha" 2>/dev/null | tail -1 || true)
    local a r
    a=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    r=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
    added=$((added + ${a:-0}))
    removed=$((removed + ${r:-0}))
  done <<< "$row_commits"

  local net=$((added - removed))
  if (( net <= 0 )); then
    log_pass "$id: structural net-lines = $net (added=$added, removed=$removed)"
  else
    log_fail "$id: structural net-lines = $net > 0 (added=$added, removed=$removed) — closure verb applied wrong"
  fi
}

# ── CHECK 6: scope boundary ─────────────────────────────────────────────────
check_scope_boundary() {
  local id="$1"
  if ! command -v git >/dev/null 2>&1; then
    log_notrun "$id: scope-boundary (git not on PATH)"
    return
  fi

  # EVERY commit that carries the row id, not the first one: a second "fixup" commit is where scope
  # creep hides. Bounded by --phase-base when given.
  local row_commits
  if [[ -n "$PHASE_BASE" ]]; then
    row_commits=$(git log --grep="${id}:" --format='%H' "$PHASE_BASE..HEAD" 2>/dev/null || true)
  else
    row_commits=$(git log --grep="${id}:" --format='%H' 2>/dev/null || true)
  fi
  if [[ -z "$row_commits" ]]; then
    log_notrun "$id: scope-boundary (no commit carries '$id:' in its subject)"
    return
  fi

  local scope_files
  scope_files=$(awk -v id="$id" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block && /^[[:space:]]+scope:/ {
      in_scope = 1
      sub(/^[[:space:]]+scope:[[:space:]]*/, "")
      sub(/^\[/, ""); sub(/\]$/, "")
      gsub(/, /, "\n")
      gsub(/,/, "\n")
      print
      next
    }
    in_scope && /^[[:space:]]+- / { sub(/^[[:space:]]+-[[:space:]]*/, ""); print; next }
    in_scope && !/^[[:space:]]+/ { in_scope = 0 }
    /^[[:space:]]*$/ && in_block { exit }
  ' "$LEDGER_PATH" | tr -d '"' | tr -d "'" | sort -u)

  if [[ -z "$scope_files" ]]; then
    log_fail "$id: scope field empty — a row with no scope cannot be scope-checked (or run in parallel)"
    return
  fi

  local touched="" sha
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    touched+=$(git show --name-only --format='' "$sha" 2>/dev/null)$'\n'
  done <<< "$row_commits"
  # The ledger and the row's own halt note travel with the fix commit (align-ledger.md hard rule).
  touched=$(printf '%s' "$touched" | grep -v '^$' | grep -vxF "$LEDGER_PATH" | grep -vx "ai/align/halts/${id}\.md" | sort -u || true)

  local violations=()
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    local in_scope=0
    while IFS= read -r scope_path; do
      [[ -z "$scope_path" ]] && continue
      # Match: file is exactly scope_path OR file is inside scope_path/
      if [[ "$file" == "$scope_path" || "$file" == "$scope_path"/* ]]; then
        in_scope=1
        break
      fi
    done <<< "$scope_files"
    if [[ $in_scope -eq 0 ]]; then
      violations+=("$file")
    fi
  done <<< "$touched"

  if [[ ${#violations[@]} -eq 0 ]]; then
    log_pass "$id: all touched files within scope"
  else
    log_fail "$id: scope creep — touched files outside scope:"
    for v in "${violations[@]:0:5}"; do
      echo "        $v" >&2
    done
  fi
}

# ── CHECK 7: security tier minimum ───────────────────────────────────────────
check_security_tier_minimum() {
  local id="$1" cls="$2" tier="$3" severity="$4"
  if [[ "$cls" != "security" ]]; then
    return  # not applicable
  fi
  case "$tier" in
    trivial)
      log_fail "$id: security finding at trivial tier — security must be ≥ standard"
      return
      ;;
    standard)
      case "$severity" in
        critical)
          log_fail "$id: critical-severity security at standard tier — must be heavy"
          return
          ;;
      esac
      ;;
    heavy)
      ;;
    *)
      log_warn "$id: tier '$tier' not recognized for security row"
      return
      ;;
  esac
  log_pass "$id: security tier '$tier' valid for severity '$severity'"
}

# Extract the YAML block for a ledger row id (shared helper).
align_row_block() {
  awk -v id="$1" '
    /^- id: / { in_block = ($3 == id) ? 1 : 0; next }
    in_block && /^[[:space:]]*$/ { exit }
    in_block { print }
  ' "$LEDGER_PATH"
}

# ── CHECK: perf row carries a baseline measurement ("The Hopeful Perf Fix") ──
check_perf_baseline_present() {
  local id="$1" cls="$2"
  [[ "$cls" == "performance" ]] || return 0
  local blk; blk=$(align_row_block "$id")
  if printf '%s' "$blk" | grep -qiE 'baseline|before/after|[0-9.]+[[:space:]]*ms\b|\bp(50|95|99)\b'; then
    log_pass "$id: perf baseline present"
  else
    log_fail "$id: perf-class row has no baseline (need a before/after or pNN / ms figure in notes) — The Hopeful Perf Fix."
  fi
}

# ── CHECK: security row references a test/assertion ("The Bare Security Fix") ─
check_security_assertion_present() {
  local id="$1" cls="$2"
  [[ "$cls" == "security" ]] || return 0
  local blk; blk=$(align_row_block "$id")
  if printf '%s' "$blk" | grep -qiE 'tests?/|\.spec\.|\.test\.|test_|assert|test:|covered by'; then
    log_pass "$id: security assertion/test referenced"
  else
    log_fail "$id: security-class row has no test/assertion reference — a security fix must add a test asserting the gate (The Bare Security Fix)."
  fi
}

# ── CHECK: functional row that ADDS code cites the reused idiom ("Reinvented Idiom") ─
# Only fires when git confirms net-positive added lines for the row (mirrors net-lines);
# pure-deletion / rename functional rows are exempt. Warn-skips when git/phase-base absent.
check_added_lines_cite_idioms() {
  local id="$1" cls="$2"
  is_structural_class "$cls" && return 0   # structural rows use the net-lines rule instead
  command -v git >/dev/null 2>&1 || { log_notrun "$id: idiom-citation (git not on PATH)"; return 0; }
  [[ -z "$PHASE_BASE" ]] && { log_notrun "$id: idiom-citation (no --phase-base)"; return 0; }
  local row_commits added=0
  row_commits=$(git log --grep="${id}:" --format='%H' "$PHASE_BASE..HEAD" 2>/dev/null || true)
  [[ -z "$row_commits" ]] && { log_notrun "$id: idiom-citation (no commit for the row)"; return 0; }
  while IFS= read -r sha; do
    [[ -z "$sha" ]] && continue
    local a; a=$(git show --shortstat "$sha" 2>/dev/null | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    added=$((added + ${a:-0}))
  done <<< "$row_commits"
  if (( added <= 0 )); then
    log_pass "$id: functional row added no lines — idiom citation N/A"
    return 0
  fi
  local blk; blk=$(align_row_block "$id")
  if printf '%s' "$blk" | grep -qiE '^[[:space:]]*idiom_cited:[[:space:]]*\S'; then
    log_pass "$id: functional row adds code + cites an idiom"
  else
    log_fail "$id: functional row adds $added line(s) without an 'idiom_cited:' reference — The Reinvented Idiom (cite the shared util/wrapper reused)."
  fi
}

# ── CHECK: alignment PR must not modify the convention oracles ("Oracle Drift") ─
ORACLE_CHECKED=0
check_oracle_unmodified() {
  [[ "${ORACLE_CHECKED:-0}" == "1" ]] && return 0
  ORACLE_CHECKED=1
  command -v git >/dev/null 2>&1 || { log_notrun "oracle-unmodified (git not on PATH)"; return 0; }
  [[ -z "$PHASE_BASE" ]] && { log_notrun "oracle-unmodified (no --phase-base)"; return 0; }
  local touched
  touched=$(git diff --name-only "$PHASE_BASE..HEAD" 2>/dev/null | grep -E '(_extracted-idioms\.md|ai/conventions\.md)$' || true)
  if [[ -n "$touched" ]]; then
    log_fail "alignment PR modifies the convention oracle(s): $(echo "$touched" | tr '\n' ' ')— The Oracle Drift (fix the code, don't edit _extracted-idioms.md / ai/conventions.md to legitimize drift)."
  else
    log_pass "convention oracles unmodified by this alignment"
  fi
}

# ── CHECK: code-level smells in the row's ACTUAL scope files (#30) ──────────
# The align/optimize/polish validators historically checked only the report/ledger, so a "fix"
# that ADDED a silent catch or a debug print shipped green (only migration greps real source).
# This greps each existing scope file for unambiguous swallows: a truly-EMPTY catch `{}` or python
# `except: pass` (FAIL), and debug prints console.log / bare print( (WARN). Empty-body match keeps
# false positives near-zero (a catch with a comment/handler body does not match).
check_scope_code_smells() {
  local id="$1"
  local blk; blk=$(align_row_block "$id")
  # scope files: inline `[a, b]` OR a `- file` list under `scope:`.
  local scope_files
  scope_files=$(printf '%s\n' "$blk" | awk '
    /^[[:space:]]*scope:/ {
      s=1; line=$0; sub(/^[[:space:]]*scope:[[:space:]]*/,"",line)
      if (line ~ /\[/) { gsub(/[][]/,"",line); gsub(/,/,"\n",line); print line; s=0 }
      next
    }
    s && /^[[:space:]]*-[[:space:]]*/ { l=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",l); print l; next }
    s && /^[[:space:]]*[a-z_]+:/ { s=0 }
  ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/["'\'']//g' | grep -v '^$')
  [[ -z "$scope_files" ]] && { log_pass "$id: no scope files to code-scan"; return 0; }
  local smells=0 f
  while IFS= read -r f; do
    [[ -z "$f" || ! -f "$f" ]] && continue
    if grep -qE 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}|except[^:]*:[[:space:]]*pass[[:space:]]*$' "$f" 2>/dev/null; then
      log_fail "$id: silent catch (empty catch{} / except: pass) in $f — route failures through the project error handler (No Silent Catch)"
      smells=$((smells + 1))
    fi
    if grep -qE '\bconsole\.(log|debug)\(|^[[:space:]]*print\(' "$f" 2>/dev/null; then
      log_warn "$id: debug print (console.log / print) in $f — use the project logger"
    fi
  done <<< "$scope_files"
  [[ $smells -eq 0 ]] && log_pass "$id: scope files free of silent-catch smells"
  [[ $smells -gt 0 ]] && return 1
  return 0
}

# ── CHECK: AL class valid ───────────────────────────────────────────────────
check_al_class() {
  local id="$1" al="$2" cls="$3"
  local r; r=$(resolve_al "$al" "$cls")
  if [[ -n "$al" ]] && ! is_al_id "$al"; then
    log_fail "$id: al_class '$al' is not one of AL-01 … AL-34 (align-detect § The class ledger)"
  elif [[ "$r" == "unmapped" ]]; then
    log_fail "$id: class '${cls:-<none>}' maps to no AL class and the row has no al_class — re-read it against align-detect § The legacy class map"
  else
    log_pass "$id: class resolves to $r"
  fi
}

# ── CHECK: oracle cited and resolving (AL-01, V389) ─────────────────────────
# `oracle: <path>:<line> "<quote>"` → the quote (whitespace-normalised) is in <path>;
# `oracle: <tool>:<rule-id>` → the rule id appears in a lint config at the root.
LINT_CONFIGS=(eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts .eslintrc .eslintrc.json .eslintrc.js
  .eslintrc.cjs .eslintrc.yml pyproject.toml ruff.toml .ruff.toml .ls-lint.yml stylelint.config.js stylelint.config.mjs
  .stylelintrc .stylelintrc.json .dependency-cruiser.js .dependency-cruiser.cjs .importlinter .spectral.yaml .editorconfig
  .golangci.yml .golangci.yaml)
check_oracle_cited() {
  local id="$1" al="$2"
  local o; o=$(row_field "$id" oracle)
  if [[ -z "$o" ]]; then
    if [[ -z "$al" ]]; then
      log_notrun "$id: oracle-cited (legacy row with no al_class and no oracle field)"
    else
      log_fail "$id: no \`oracle:\` — a row must cite the line or rule that declares its convention (AL-01, halt #3)"
    fi
    return 0
  fi
  o="${o#\'}"; o="${o%\'}"
  if [[ "$o" =~ ^([^[:space:]:\"]+):([0-9]+)[[:space:]]+\"(.*)\"$ ]]; then
    local f="${BASH_REMATCH[1]}" q="${BASH_REMATCH[3]}"
    if [[ ! -f "$f" ]]; then
      log_fail "$id: oracle file '$f' does not exist (AL-01)"
    elif python3 -I -c 'import re,sys
n=lambda t: re.sub(r"\s+"," ",t).strip()
sys.exit(0 if n(sys.argv[2]) in n(open(sys.argv[1],encoding="utf-8",errors="replace").read()) else 1)' "$f" "$q" 2>/dev/null; then
      log_pass "$id: oracle quote found in $f"
    else
      log_fail "$id: oracle quote not found in $f — \"${q:0:60}\" (AL-01: the convention is not declared there)"
    fi
  elif [[ "$o" =~ ^([A-Za-z0-9_.-]+):([^[:space:]]+)$ ]]; then
    local rule="${BASH_REMATCH[2]}" cfg hit=""
    for cfg in "${LINT_CONFIGS[@]}"; do
      [[ -f "$cfg" ]] && grep -qF -- "$rule" "$cfg" && { hit="$cfg"; break; }
    done
    if [[ -n "$hit" ]]; then log_pass "$id: oracle rule '$rule' declared in $hit"
    else log_fail "$id: oracle rule '$rule' is declared in no lint config at the root (AL-01)"; fi
  else
    log_fail "$id: oracle '${o:0:60}' is neither <path>:<line> \"<quote>\" nor <tool>:<rule-id>"
  fi
  return 0
}

# ── CHECK: proof class on a closed row ──────────────────────────────────────
check_proof_class() {
  local id="$1" status="$2" al="$3"
  case "$status" in fixed|verified|pending-review) ;; *) return 0 ;; esac
  local pc; pc=$(row_field "$id" proof_class | tr -d '"'"'"' ')
  case "$pc" in
    EQ|VC|FN) log_pass "$id: proof_class $pc" ;;
    "") if [[ -z "$al" ]]; then log_notrun "$id: proof-class (legacy row with no al_class)"
        else log_fail "$id: closed row with no proof_class (EQ | VC | FN) — halt #11"; fi ;;
    *)  log_fail "$id: proof_class '$pc' is not EQ, VC or FN" ;;
  esac
  return 0
}

# ── CHECK: a VC row carries a human approval, not one written in the fix commit (V407) ──
check_vc_approval() {
  local id="$1" status="$2"
  local pc; pc=$(row_field "$id" proof_class | tr -d '"'"'"' ')
  [[ "$pc" == "VC" ]] || return 0
  case "$status" in fixed|verified|pending-review) ;; *) return 0 ;; esac
  local ap; ap=$(row_field "$id" approval | tr -d '"'"'"'')
  if [[ ! "$ap" =~ ^[^@[:space:]]+@[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    log_fail "$id: VC row closed without \`approval: <name>@<iso>\` — a visible change is never auto-accepted (V407)"
    return 0
  fi
  if command -v git >/dev/null 2>&1; then
    local sha
    for sha in $(git log --grep="${id}:" --format='%H' ${PHASE_BASE:+"$PHASE_BASE..HEAD"} 2>/dev/null); do
      if git show "$sha" -- "$LEDGER_PATH" 2>/dev/null | grep -qE '^\+[[:space:]]+approval:[[:space:]]*\S'; then
        log_fail "$id: approval was written in the fix commit ${sha:0:8} — the approver signs after the diff exists, never inside it"
        return 0
      fi
    done
  fi
  log_pass "$id: VC approval $ap"
  return 0
}

# ── CHECK: owner classes are routed, never closed in align ──────────────────
check_owner_routed() {
  local id="$1" status="$2" al="$3" cls="$4"
  local r; r=$(resolve_al "$al" "$cls")
  [[ "$r" == owner:* ]] || return 0
  case "$status" in
    fixed|verified|pending-review|in-progress)
      if [[ "$r" == "owner:performance" ]] && row_field "$id" carve_out | grep -q 'measured' \
         && align_row_block "$id" | grep -qiE 'tests?/|\.spec\.|\.test\.|test_'; then
        log_pass "$id: performance carve-out (owner pack absent) with a measured, test-backed baseline"
      else
        log_fail "$id: ${r#owner:} class '$cls' closed in align — route it (status: routed, routed: <its fix command> <audit id>)"
      fi ;;
    *) log_pass "$id: owner class ${r#owner:} not closed here ($status)" ;;
  esac
  return 0
}

# ── CHECK: a routed / refuted row carries what its state requires ───────────
check_side_state() {
  local id="$1" status="$2"
  local c; c=$(row_field "$id" commit)
  case "$status" in
    routed)
      [[ -n "$(row_field "$id" routed)" ]] || { log_fail "$id: status routed with an empty \`routed:\` (name the fix command and the audit id)"; return 0; }
      [[ -z "$c" ]] || { log_fail "$id: a routed row carries commit $c — it was closed in the wrong command"; return 0; } ;;
    refuted)
      [[ -n "$(row_field "$id" refuted_gate)" ]] || { log_fail "$id: refuted row without \`refuted_gate:\`"; return 0; }
      [[ -z "$c" ]] || { log_fail "$id: a refuted row carries commit $c"; return 0; } ;;
    archived-pre-existing)
      [[ -z "$c" ]] || { log_fail "$id: archived-pre-existing (aged out) carries commit $c — a fixed row is 'fixed', a false positive is 'refuted'"; return 0; } ;;
  esac
  log_pass "$id: $status row consistent"
  return 0
}

# ── Per-finding orchestrator ────────────────────────────────────────────────
validate_finding() {
  local id="$1" cls="$2" phase="$3" status="$4" tier="$5" verb="$6" severity="$7" al="${8:-}"
  TOTAL_CHECKED=$((TOTAL_CHECKED + 1))
  log_section "$id (${al:-$cls} / phase=$phase / status=$status / tier=$tier)"

  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "al-class" ]]; then
    check_al_class "$id" "$al" "$cls"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "oracle-cited" ]]; then
    case "$status" in refuted|archived-deprecated) ;; *) check_oracle_cited "$id" "$al" ;; esac
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "owner-routed" ]]; then
    check_owner_routed "$id" "$status" "$al" "$cls"
  fi

  case "$status" in
    detected|planned|in-progress|pending-ratification)
      [[ $QUIET -eq 0 ]] && echo "  ▸ $id: status=$status — not closed yet; closure checks apply once it is fixed"
      return
      ;;
    routed|refuted|archived-pre-existing)
      if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "side-state" ]]; then check_side_state "$id" "$status"; fi
      return
      ;;
    archived-deprecated|parked|pending-approval)
      log_pass "$id: status=$status — no closure claimed"
      return
      ;;
  esac
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "proof-class" ]]; then
    check_proof_class "$id" "$status" "$al"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "vc-approval" ]]; then
    check_vc_approval "$id" "$status"
  fi

  # Run the 7 checks, optionally filtered by --check
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "evidence" ]]; then
    check_evidence_resolves "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "handwaves" ]]; then
    check_no_handwaves "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "verb" ]]; then
    check_closure_verb_in_vocab "$id" "$verb"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "no-new-symbols" ]]; then
    check_no_new_symbols "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "net-lines" ]]; then
    check_net_lines_structural "$id" "${al:-$cls}"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "scope" ]]; then
    check_scope_boundary "$id"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "security-tier" ]]; then
    check_security_tier_minimum "$id" "$cls" "$tier" "$severity"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "perf-baseline" ]]; then
    check_perf_baseline_present "$id" "$cls"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "security-assertion" ]]; then
    check_security_assertion_present "$id" "$cls"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "idiom-citation" ]]; then
    check_added_lines_cite_idioms "$id" "${al:-$cls}"
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "oracle" ]]; then
    check_oracle_unmodified
  fi
  if [[ -z "$CHECK_FILTER" || "$CHECK_FILTER" == "code-smells" ]]; then
    check_scope_code_smells "$id"
  fi
}

check_actionable_next_steps() {
  # Per templates/snippets/actionable-next-steps.md: if a final-report.md exists,
  # it MUST end with an `## Actionable next steps` section containing paste-ready
  # commands for every deferred / out-of-scope finding.
  local report="${1:-ai/align/final-report.md}"
  [[ ! -f "$report" ]] && return 0

  if ! grep -qE '^##[[:space:]]+Actionable next steps' "$report"; then
    log_fail "final-report missing '## Actionable next steps' section at $report — every deferred finding MUST be a paste-ready command (see templates/snippets/actionable-next-steps.md)"
    return 1
  fi

  local extracted bad=0
  extracted=$(awk '
    /^##[[:space:]]+Actionable next steps/ { in_sec=1; next }
    in_sec && /^##[[:space:]]/ { in_sec=0 }
    in_sec { print }
  ' "$report")

  if ! echo "$extracted" | grep -qE '^[[:space:]]*```'; then
    log_fail "actionable next steps section has no bash fence at $report — commands must be inside \`\`\`bash\`\`\` so they are paste-ready"
    return 1
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*/[a-z-]+ ]] || continue
    local clean args arg_count
    clean=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    args=$(echo "$clean" | cut -s -d' ' -f2-)
    arg_count=$(echo "$args" | wc -w | tr -d ' ')
    [[ "$arg_count" == "0" ]] && continue
    [[ "$arg_count" == "1" ]] && continue
    if echo "$args" | grep -qE '/|=|--|\.[a-zA-Z]+'; then
      continue
    fi
    log_fail "actionable next-step line looks like prose, not a paste-ready command (no path / flag / extension marker): $line"
    bad=$((bad + 1))
  done <<< "$extracted"

  [[ $bad -gt 0 ]] && return 1
  log_pass "final report ends with paste-ready actionable next steps"
  return 0
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
  load_project_anchors
  if [[ $QUIET -eq 0 ]]; then
    echo "validate-align-artifacts.sh"
    echo "  ledger:  $LEDGER_PATH"
    echo "  project: $PROJECT_KIND"
    [[ -n "$PHASE" ]] && echo "  scope:   phase $PHASE"
    [[ -n "$FINDING" ]] && echo "  scope:   finding $FINDING"
    [[ $SCAN_ALL -eq 1 ]] && echo "  scope:   all findings"
    [[ -n "$CHECK_FILTER" ]] && echo "  check:   $CHECK_FILTER"
  fi

  if [[ "$CHECK_FILTER" == "scan-evidence" ]]; then
    log_section "Run-level evidence check (scan report)"
    check_scan_report_evidence || true
    echo
    echo "── Summary ──"
    echo "  checks passed:    $TOTAL_PASS"
    echo "  checks failed:    $TOTAL_FAIL"
    [[ $TOTAL_FAIL -gt 0 ]] && exit 1
    exit 0
  fi

  # Pre-check: duplicate IDs
  local dupes
  dupes=$(grep -oE '^- id: A[0-9]+[a-z]?$' "$LEDGER_PATH" 2>/dev/null | sort | uniq -d)
  if [[ -n "$dupes" ]]; then
    echo "FATAL: duplicate ledger IDs:" >&2
    echo "$dupes" | sed 's/^/  /' >&2
    exit 4
  fi

  # Run the run-level evidence check ONCE before per-finding validation
  # This catches Trusted-Summary scans that produce findings without per-detector evidence
  # NOTE: run-level checks are called with `|| true` so a single FAIL (which `return`s non-zero)
  # does not trip `set -e` and abort before later checks run. Failures are recorded in FAILURES /
  # TOTAL_FAIL by log_fail; the real gate is the TOTAL_FAIL count at the end of main().
  log_section "Run-level evidence check (scan report)"
  check_scan_report_evidence || true

  # Single-source-of-truth reconciliation: progress.md (derived roll-up) must not claim a
  # module done while the ledger (canonical) still holds non-terminal rows for it.
  log_section "Progress/ledger reconciliation"
  check_progress_ledger_reconciliation || true

  local findings
  findings=$(discover_findings | filter_findings)
  if [[ -z "$findings" ]]; then
    echo "No findings matched the scope. Check ledger contents." >&2
    exit 2
  fi

  while IFS='|' read -r id cls phase status tier verb severity al; do
    [[ -n "$id" ]] || continue
    validate_finding "$id" "$cls" "$phase" "$status" "$tier" "$verb" "$severity" "$al"
  done <<< "$findings"

  check_actionable_next_steps "ai/align/final-report.md" || true

  echo
  echo "── Summary ──"
  echo "  findings checked: $TOTAL_CHECKED"
  echo "  checks passed:    $TOTAL_PASS"
  echo "  checks failed:    $TOTAL_FAIL"
  echo "  checks not run:   $TOTAL_NOTRUN   (never a pass; --strict makes each a failure)"

  if [[ $TOTAL_FAIL -gt 0 ]]; then
    echo
    echo "Failures:"
    for f in "${FAILURES[@]}"; do
      echo "  - $f"
    done
    exit 1
  fi

  if [[ $QUIET -eq 0 ]]; then
    echo
    echo "Note: agent-side, not in this script — the computed-style / visual diff, the mechanical run and"
    echo "      boot, coverage. align-sweep-gate.py (find-and-align) carries line-level scope, re-detect,"
    echo "      one way per pattern, emitted names, round-trip, ratchet, test lock and non-vacuous."
  fi
  exit 0
}

main "$@"
