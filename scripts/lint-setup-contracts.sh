#!/usr/bin/env bash
# lint-setup-contracts.sh — the RATCHET for the defect class a live end-to-end run exposed and
# nine passes of reading did not: a producer and its consumer that disagree, where neither side
# is wrong on its own and nothing compares them.
#
# Every rule here was written AFTER a measured failure, and every rule is mechanical. The house
# pattern applies: known violations are recorded in scripts/_setup-contracts-baseline.txt, a new
# violation is a hard FAIL, and --record re-baselines deliberately.
#
#   Rule 1  find over a possibly-symlinked templates path must pass -L.
#           Measured: ~/.claude/templates/packs IS a symlink and ~/.claude/scripts is a real dir
#           of per-file symlinks, so `pwd -P` put PACKS_DIR on the symlink; `[[ -d ]]` passed
#           (test follows symlinks) and `find` returned 0 of 887 files. detect-tracks.sh's
#           installed-pack seed was DEAD through the only documented invocation path, dropping
#           the `backend` track from a repo carrying 5 backend artifacts.
#
#   Rule 2  a gate's extractor must be able to see every field its own generator emits.
#           Measured: apply-anchors.sh writes the `top-level:` value UNBACKTICKED, and
#           audit-anchoring.sh's leak extractor read backticked tokens only — 225 artifacts
#           cited a `src/` that does not exist and the audit reported "0 leaks", exit 0.
#
#   Rule 3  no GNU-only `grep -P` anywhere. Measured: exactly one occurrence in the whole
#           framework, and it was the line deciding which technical domains get installed.
#           /usr/bin/grep on macOS answers "invalid option -- P", so on a stock shell Phase 4.4
#           would silently install ZERO domains. It only ever worked because the session shell
#           happened to shim grep to ugrep.
#
#   Rule 4  a trigger name declared in templates/packs/_trigger-vocabulary.md must have a
#           producer. The vocabulary's own hard rule says so: "A trigger no extractor produces
#           is dead code." Measured: rtl_locale_detected and i18n_lib_detected had ZERO
#           producers, so the ui-ux rtl topic and four frontend i18n topics could never fire on
#           any project — including a genuinely Arabic-first, dir="rtl" codebase.
#
#   Rule 5  an unmistakably browser-only pack artifact must declare `project_kind:`.
#           Measured: 49,450 bytes (17.6% of one run's installs) of Core Web Vitals / bundle /
#           INP content landed on a NestJS service with zero .vue and zero .tsx files.
#
#   Rule 6  a machine contract must be read BY KEY, not by section number. Measured: a phase
#           file instructed "read verbatim from codebase-profile.md § 17" and halt if absent;
#           the producer wrote the block under § 19 and § 17 was "Project intent", so the
#           consumer read the wrong section AND the halt never fired.
#
# Usage:  lint-setup-contracts.sh [--repo-root=<dir>] [--record] [--quiet]
# Exit:   0 clean (or every violation is baselined) / 1 a NEW violation
set -uo pipefail
export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECORD=0; QUIET=0
for a in "$@"; do
  case "$a" in
    --repo-root=*) REPO_ROOT="${a#--repo-root=}" ;;
    --record)      RECORD=1 ;;
    --quiet)       QUIET=1 ;;
  esac
done
REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
BASELINE="$REPO_ROOT/scripts/_setup-contracts-baseline.txt"

findings=""     # one "rule|file|detail" per line
add() { findings="${findings}$1|$2|$3"$'\n'; }
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

cd "$REPO_ROOT" || exit 1

# ---- Rule 1 — find without -L over a templates path -----------------------------------------
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  f="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"
  add "R1-find-no-L" "$f:$ln" "find over a templates/packs path without -L"
done < <(grep -rnE 'find[[:space:]]+"?\$(PACKS_DIR|TEMPLATES_DIR|PACKS_ROOT)"?' scripts/ 2>/dev/null \
         | grep -v -- 'find -L' || true)

# ---- Rule 2 — anchor emitter fields the auditor can read -------------------------------------
# Every `<label>:` field apply-anchors.sh writes on its Cite-able-sources line must appear in
# audit-anchoring.sh's extractor set. Today that is the `top-level:` field.
if [ -f scripts/apply-anchors.sh ] && [ -f scripts/audit-anchoring.sh ]; then
  # Compare against the EXTRACTOR BODY, not the whole auditor file. A label that survives only
  # in a comment proves nothing: deleting the extractor while leaving its `# HISTORY` note
  # behind is precisely the regression this rule has to catch, and a whole-file grep passes it.
  extractor_body="$(awk '/^anchor_citation_tokens\(\) \{/{f=1} f{print} f && /^\}/{exit}' \
                     scripts/audit-anchoring.sh 2>/dev/null | grep -v '^[[:space:]]*#' || true)"
  while IFS= read -r field; do
    [ -z "$field" ] && continue
    printf '%s' "$extractor_body" | grep -qF "$field" \
      || add "R2-unreadable-field" "scripts/audit-anchoring.sh" "apply-anchors.sh emits '$field' on the Cite-able line; anchor_citation_tokens() has no extractor for it"
  done < <(grep -oE ', [a-z-]+: \$\{[A-Z_]+\}' scripts/apply-anchors.sh 2>/dev/null \
           | sed -E 's/^, //; s/ \$\{[A-Z_]+\}//' | sort -u || true)
fi

# ---- Rule 3 — no GNU-only grep -P -------------------------------------------------------------
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  f="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"
  add "R3-grep-P" "$f:$ln" "grep -P is a GNU extension; /usr/bin/grep on macOS rejects it"
done < <(grep -rnE 'grep[[:space:]]+-[a-zA-Z]*P[a-zA-Z]*[[:space:]]' scripts/ templates/ commands/ 2>/dev/null \
         | grep -v '_setup-contracts-baseline' | grep -v 'lint-setup-contracts.sh' \
         | grep -vE ':[[:space:]]*#' \
         | grep -vE '`grep -[a-zA-Z]*P' || true)

# ---- Rule 4 — every declared trigger has a producer -------------------------------------------
VOCAB="templates/packs/_trigger-vocabulary.md"
if [ -f "$VOCAB" ]; then
  while IFS= read -r trig; do
    [ -z "$trig" ] && continue
    # A producer is anything OUTSIDE the vocabulary and outside a pack's _topics/_essentials
    # (those are consumers). Appendix A and the extraction skill are the two legal emitters.
    up="$(printf '%s' "$trig" | tr 'a-z' 'A-Z')"
    if grep -rqE "(^|[^A-Za-z_])($trig|$up)([^A-Za-z_]|$)" templates/appendices.md \
         templates/packs/learning/skills/ scripts/ 2>/dev/null; then
      continue
    fi
    add "R4-dead-trigger" "$VOCAB" "trigger '$trig' is declared and consumed but no extractor produces it"
  done < <(grep -oE '^- `[a-z0-9_]+_detected`' "$VOCAB" 2>/dev/null | sed 's/^- `//; s/`$//' | sort -u || true)
fi

# ---- Rule 5 — browser-only artifacts declare project_kind -------------------------------------
# Deliberately narrow: TWO distinct markers, so a passing mention of "bundle size" in a
# general performance doc is not mistaken for a browser-only artifact. The point of this rule
# is the artifact that is UNUSABLE off-kind, not the one that mentions the browser.
BROWSER_RE='Core Web Vitals|INP budget|page-load|hydration|LoAF|Largest Contentful Paint|Cumulative Layout Shift|First Input Delay|web-vitals'
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # ui-ux and mobile are single-kind tracks by construction — the track IS the gate there.
  # ui-ux / frontend / mobile are single-kind tracks by construction — the TRACK is the gate
  # there, and tagging every file in them would be noise. CHANGELOG / README / _examples are
  # not installable artifacts.
  case "$f" in
    templates/packs/ui-ux/*|templates/packs/mobile/*|templates/packs/frontend/*) continue ;;
    */_examples/*|*/CHANGELOG.md|*/README.md|*/STACK.md) continue ;;
  esac
  hits=$({ grep -oiE "$BROWSER_RE" "$f" 2>/dev/null || true; } | tr 'A-Z' 'a-z' | sort -u | grep -c . || true)
  [ "${hits:-0}" -ge 2 ] || continue
  awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} /^project_kind:/{f=1} END{exit !f}' "$f" && continue
  add "R5-no-project-kind" "$f" "reads as browser-only but declares no project_kind: (see templates/packs/_project-kind.md)"
done < <(find -L templates/packs -type f -name '*.md' -not -name '_*' 2>/dev/null | sort || true)

# ---- Rule 6 — no machine contract addressed by section NUMBER ---------------------------------
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  f="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"
  add "R6-section-number-contract" "$f:$ln" "reads a machine contract from codebase-profile.md by section NUMBER; read it by KEY"
done < <(grep -rnE 'codebase-profile\.md[[:space:]]*§[[:space:]]*[0-9]+' templates/phases/ scripts/ commands/ 2>/dev/null \
         | grep -v 'lint-setup-contracts.sh' \
         | grep -viE 'by KEY|never by section number|HISTORY|not by section' || true)

# ---- Rule 7 — every writer of pack content applies the SAME deploy rewrites -------------------
# Pack sources link to ../../../snippets/ and ../../../governance/, which resolve under
# templates/packs/*/commands/ and nowhere else. apply-study-decisions.sh has rewritten them on
# deploy since the beginning; merge-decide.py now writes pack content too. A writer that skips
# the rewrite leaves a dangling link AND guarantees the file it just wrote re-flags as MERGE on
# the next run forever — phantom drift that looks exactly like real drift. So both writers must
# carry both rewrites, and this rule fails the build if either loses one.
for rw in 'templates/snippets/' 'templates/governance/'; do
  for w in scripts/apply-study-decisions.sh scripts/merge-decide.py; do
    [ -f "$w" ] || continue
    grep -qF "$rw" "$w" 2>/dev/null && continue
    add "R7-deploy-rewrite-parity" "$w" "writes pack content but has no '$rw' rewrite (see apply-study-decisions.sh § rewrite_deployed_command_links)"
  done
done

# ---- Rule 8 — exactly ONE implementation of the additive merge --------------------------------
# It lived in apply-study-decisions.sh as merge_additive(), appending the `## ` sections the
# pack had and the target lacked. merge-decide.py subsumed it as one of four verbs, and the
# bash copy was DELETED rather than left beside it — two implementations of "merge without
# losing anything" is two chances to lose something, and only one of them has the post-write
# invariant check. --include=merge-additive now routes to the engine's --additive-only.
if grep -qE '^[[:space:]]*merge_additive(_dryrun_count)?\(\)' scripts/apply-study-decisions.sh 2>/dev/null; then
  add "R8-duplicate-additive-merge" "scripts/apply-study-decisions.sh" "a second additive-merge implementation reappeared; route --include=merge-additive to scripts/merge-decide.py --additive-only instead"
fi

# ---- Rule 9 — the merge engine must never reuse the emphasis-stripping normalization ---------
# pack_substantive_sha8() in study-existing.sh strips [*_`] before hashing, which is correct
# for a stability hash and catastrophic anywhere else: it turns E2E_EMAIL into E2EEMAIL and
# eats .env.tenant. MEASURED — copying that normalization into the merge detector silently
# un-protected two real files (tenant-portal art-direct.md, capsolah env-diff/SKILL.md), both
# of which carry exactly those tokens, and classified both as safe to overwrite. The engine may
# use it for the ledger's pack@sha8 stamp and for nothing else.
if [ -f scripts/merge-decide.py ]; then
  # Track the enclosing `def`, and look only at code that actually performs the strip
  # (`re.sub`), so the rule's own explanatory prose does not trip it. Two functions are
  # allowed to do it: pack_substantive_sha8 (the ledger stamp, which must match
  # study-existing.sh byte for byte) and sec_key (heading-text comparison, where emphasis
  # genuinely is noise and no identifier can be destroyed because a heading is not a token).
  hits=$(awk '
    /^[[:space:]]*def [A-Za-z_]+/ { fn=$2; sub(/\(.*/,"",fn) }
    /re\.sub\(r"\[\*_`\]"/ {
      if (fn != "pack_substantive_sha8" && fn != "sec_key") print NR": in "fn"(): "$0
    }' scripts/merge-decide.py 2>/dev/null || true)
  if [ -n "$hits" ]; then
    add "R9-emphasis-strip-outside-hash" "scripts/merge-decide.py" "strips [*_\`] outside pack_substantive_sha8/sec_key ($(printf '%s' "$hits" | head -1)) — that normalization eats E2E_EMAIL and .env.tenant"
  fi
fi

# ---- report / ratchet -------------------------------------------------------------------------
findings="$(printf '%s' "$findings" | grep -c . >/dev/null 2>&1; printf '%s' "$findings")"
sorted_findings="$(printf '%s' "$findings" | grep . | sort || true)"

if [ "$RECORD" = "1" ]; then
  {
    echo "# lint-setup-contracts.sh baseline — known violations, one per line: rule|file|detail"
    echo "# Regenerate: bash scripts/lint-setup-contracts.sh --record"
    echo "# A line here suppresses that ONE violation. Anything new is a hard FAIL."
    printf '%s\n' "$sorted_findings" | grep . || true
  } > "$BASELINE"
  say "recorded $(printf '%s\n' "$sorted_findings" | grep -c . || echo 0) violation(s) -> $BASELINE"
  exit 0
fi

known=""
[ -f "$BASELINE" ] && known="$(grep -v '^#' "$BASELINE" 2>/dev/null | grep . || true)"

new_count=0
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if printf '%s\n' "$known" | grep -qxF "$line"; then
    say "  known  ${line%%|*}  $(printf '%s' "$line" | cut -d'|' -f2)"
  else
    printf '  NEW    %s  %s\n       %s\n' "${line%%|*}" "$(printf '%s' "$line" | cut -d'|' -f2)" "$(printf '%s' "$line" | cut -d'|' -f3-)" >&2
    new_count=$((new_count + 1))
  fi
done < <(printf '%s\n' "$sorted_findings")

total=$(printf '%s\n' "$sorted_findings" | grep -c . || echo 0)
say ""
say "setup-contracts: $total violation(s), $new_count new"
if [ "$new_count" -gt 0 ]; then
  echo "::error::$new_count NEW setup-contract violation(s). Fix them, or record deliberately with: bash scripts/lint-setup-contracts.sh --record" >&2
  exit 1
fi
say "OK — no new setup-contract violations."
exit 0
