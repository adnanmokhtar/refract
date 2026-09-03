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
#   Rule 3b no BSD-first `stat -f` / `date -r`. Rule 3's more dangerous half: `grep -P` FAILS
#           on macOS and is loud, while `stat -f %m` SUCCEEDS on GNU meaning --file-system, so
#           the `||` fallback never runs. Measured: it printed `File: ...` into an arithmetic
#           test and `set -u` killed audit-setup.sh mid-run at C2f on every Linux machine.
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
#   Rule 19 every snippet/governance file a pack artifact LINKS TO must be deployed into a
#           target by templates/repo-baseline/. Measured: templates/snippets/ shipped 11 files
#           and the baseline deployed 4, so the deploy-time rewrite
#           (../../../snippets/ → ../templates/snippets/) pointed 41 of 95 links under
#           .claude/ at files that were never installed — and C2t, the check that exists for
#           exactly this, greps for the OLD path shape only and reported "no broken links".
#
#   Rule 18 every non-zero exit an ORCHESTRATED script can return must be named in the
#           exit-code contract table (templates/phases/phase-4.0-preflight.md § Exit-code
#           contract). Measured: apply-study-decisions.sh exited 3 on a live run because the
#           merge engine's safety net refused one row — 154 files had already landed — and no
#           phase file said what exit 3 meant. `grep -n 'exit 3' templates/phases/*.md` was
#           EMPTY. A `set -euo pipefail` runner aborts Phase 4 there, before rule imports and
#           anchors, and leaves the repo half-configured.
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

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
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

# ---- Rule 3b — no BSD-first fallback that SUCCEEDS on GNU with a different meaning -------------
# Rule 3's family, and the more dangerous half. `grep -P` FAILS on macOS, so the breakage is
# loud. `stat -f %m` does not: on macOS `-f` is the output format and this is the mtime, while
# on GNU `-f` is `--file-system`, so the call exits 0 and prints filesystem info beginning
# `File: `. A `X || Y` fallback never reaches Y when X succeeds.
#
# MEASURED on the first CI run this repo ever completed: that string reached
# `[[ $m -gt $pack_newest ]]`, `[[ ]]` evaluated it arithmetically, bash read `File` as a
# variable name, and `set -u` killed audit-setup.sh mid-run at C2f —
#     audit-setup.sh: line 1088: File: unbound variable
# — before C2u and every check after it. Every Linux user had an audit that stopped a third
# of the way through, and the only symptom was output that simply ended.
#
# `date -r` is the same shape: BSD takes an epoch, GNU takes a FILE.
#
# The rule is about ORDER, not about the tools: put the form that FAILS CLEANLY on the other
# platform first. GNU `stat -c` and `date -d` are rejected outright by BSD, so GNU-first is
# the honest direction, and the result should be forced numeric before any arithmetic sees it.
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  f="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"
  add "R3b-bsd-first" "$f:$ln" "BSD-first \`stat -f\`/\`date -r\` — on GNU it SUCCEEDS with another meaning, so the || fallback never runs; put the GNU form (stat -c / date -d) first"
done < <(grep -rnE '(stat[[:space:]]+-f[[:space:]]|date[[:space:]]+-r[[:space:]])' scripts/ templates/ commands/ 2>/dev/null \
         | grep -v '_setup-contracts-baseline' | grep -v 'lint-setup-contracts.sh' \
         | grep -vE ':[[:space:]]*#' \
         | grep -vE '`(stat|date) -[a-z]' \
         | grep -vE 'stat -c[^|]*\|\|.*stat -f|date -d[^|]*\|\|.*date -r' || true)

# ---- Rule 4 — every declared trigger has a producer -------------------------------------------
VOCAB="templates/packs/_trigger-vocabulary.md"
if [ -f "$VOCAB" ]; then
  while IFS= read -r trig; do
    [ -z "$trig" ] && continue
    # A producer is anything OUTSIDE the vocabulary and outside a pack's _topics/_essentials
    # (those are consumers). Appendix A and the extraction skill are the two legal emitters.
    up="$(printf '%s' "$trig" | tr 'a-z' 'A-Z')"
    # A PRODUCER IS AN ASSIGNMENT, NOT A MENTION.
    #
    # This used to accept any occurrence of the trigger name anywhere in the three producer
    # paths — so a sentence in a comment satisfied it, and the rule certified that a signal
    # had an extractor when all it had was a name-check. Measured: `rtl_locale_detected` and
    # `i18n_lib_detected` passed this rule while nothing computed them, and both stayed dead
    # on an Arabic-first codebase that needed them. The value must actually be PRODUCED:
    #   shell   RTL_LOCALE_DETECTED=...   |   printf '...rtl_locale_detected=%s...'
    #   report  rtl_locale_detected: yes  |  `rtl_locale_detected=yes`
    # A bare word in prose no longer counts.
    # THE BASELINE FILE IS NOT A PRODUCER. `scripts/_setup-contracts-baseline.txt` lives under
    # scripts/, and every recorded R4 violation quotes the trigger name — so the act of
    # RECORDING a dead trigger made this rule's own search find it and stop reporting it. A
    # suppression that also disables the detector is not a suppression, it is a blind spot:
    # 29 triggers sat recorded-and-undetectable. Exclude the baseline from the search.
    if grep -rqE "($trig|$up)[[:space:]]*=" templates/appendices.md \
         templates/packs/learning/skills/ scripts/ 2>/dev/null \
         --exclude='_setup-contracts-baseline.txt' --exclude='lint-setup-contracts.sh'; then
      continue
    fi
    if grep -rqE "($trig|$up)[[:space:]]*:[[:space:]]*[A-Za-z0-9\$]" templates/appendices.md \
         templates/packs/learning/skills/ scripts/ 2>/dev/null \
         --exclude='_setup-contracts-baseline.txt' --exclude='lint-setup-contracts.sh'; then
      continue
    fi
    add "R4-dead-trigger" "$VOCAB" "trigger '$trig' is declared and consumed but nothing ASSIGNS it — a prose mention of the name is not an extractor (grep for '$trig=' or '$trig:' in templates/appendices.md, templates/packs/learning/skills/ or scripts/)"
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
# un-protected two real files (the sibling repo art-direct.md, the reference monorepo env-diff/SKILL.md), both
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

# ---- Rule 19 — every linked snippet/governance file is actually DEPLOYED ---------------------
# A pack command links `](../../../snippets/plan-flag.md)`; apply-study-decisions.sh rewrites
# that to `](../templates/snippets/plan-flag.md)` on deploy. The rewrite is correct and the link
# is still dead unless `templates/repo-baseline/.claude/templates/snippets/plan-flag.md` exists
# to be copied in. MEASURED on the reference monorepo after a complete run: 41 of 95 relative links under
# .claude/ unresolved (43%), up from 20 of 61 at HEAD — the run more than DOUBLED them — with
# `../templates/snippets/review-action-plan.md` x16 and `../templates/snippets/plan-flag.md` x8
# at the top, while audit-setup.sh C2t printed "ok no broken snippet/governance links".
BASE_SNIP="templates/repo-baseline/.claude/templates"
if [ -d templates/packs ] && [ -d "$BASE_SNIP" ]; then
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    kind="${ref%%/*}"          # snippets | governance
    file="${ref##*/}"
    [ -f "$BASE_SNIP/$kind/$file" ] && continue
    add "R19-undeployed-snippet" "$BASE_SNIP/$kind/$file" "pack artifacts link to '$kind/$file' and the repo-baseline does not ship it — the deploy-time rewrite points every one of those links at a file that is never installed"
  done < <(grep -rhoE '\]\(\.\./\.\./\.\./(snippets|governance)/[A-Za-z0-9_-]+\.md\)' templates/packs 2>/dev/null \
           | sed -E 's#^\]\(\.\./\.\./\.\./##; s#\)$##' | sort -u || true)
fi

# ---- Rule 18 — every non-zero exit of an orchestrated script is documented -------------------
# THE MEASURED FAILURE. apply-study-decisions.sh exited 3 mid-run because merge-decide.py's
# pre-write invariant check refused ONE row — the safety net working exactly as designed, with
# 154 files already written and verified. Nothing in templates/phases/ or commands/ said what
# exit 3 meant, so the orchestrator had to guess; a scripted runner under `set -e` would have
# aborted Phase 4 before Phase 4.1 wired the rule imports and Phase 4.6 injected the anchors,
# leaving the target half-configured and reporting a crash.
#
# An exit code is a contract with the caller. This rule fails the build when a script the
# orchestrator sequences grows a non-zero literal exit that the contract table does not name.
# NOTE the deliberate limit: only LITERAL `exit N` is detected. `exit "$rc"` cannot be resolved
# statically, so those paths are documented by hand in the same table and are not machine-checked
# here — stated so the next reader knows the boundary rather than trusting a false completeness.
EXIT_CONTRACT="templates/phases/phase-4.0-preflight.md"
if [ -f "$EXIT_CONTRACT" ]; then
  contract_body="$(awk '/^## Exit-code contract/{f=1} f{print}' "$EXIT_CONTRACT" 2>/dev/null || true)"
  for esc in run-preflight.sh apply-baseline-sync.sh apply-study-decisions.sh apply-anchors.sh \
             apply-adapter-sync.sh audit-setup.sh wire-rule-imports.sh; do
    [ -f "scripts/$esc" ] || continue
    while IFS= read -r code; do
      [ -z "$code" ] && continue
      [ "$code" = "0" ] && continue
      printf '%s' "$contract_body" | grep -qE "^\| \`$esc\` \| *$code \|" && continue
      add "R18-undocumented-exit" "scripts/$esc" "can \`exit $code\` but $EXIT_CONTRACT § Exit-code contract has no row for it — the orchestrator cannot know whether to halt or continue"
    done < <(grep -oE '(^|[^A-Za-z_])exit [0-9]+' "scripts/$esc" 2>/dev/null \
             | grep -oE '[0-9]+$' | sort -un || true)
  done
fi

# ---- Rule 10 — a script's repo root must survive the global-install symlink ------------------
# ~/.claude/scripts/<name> is a SYMLINK into this checkout. A script that computes its root as
# `cd "$(dirname "${BASH_SOURCE[0]}")/.."` therefore resolves to ~/.claude when invoked the way
# /setup-project actually invokes it — and every sibling asset it reaches for resolves only if
# that asset, too, happens to have been linked.
#
# MEASURED, on the delivery run this rule was written for: scripts/merge-decide.py existed at
# HEAD, sync-to-global.sh had not been re-run since it landed, so $REPO_ROOT/scripts/merge-decide.py
# pointed at a link that was never created. 238 MERGE rows across two live product repos — the
# entire payload of a seven-batch programme — degraded to "listed, not decided", and the script
# exited 0. Seven repo files were missing from the global install; nothing detected the drift.
#
# The fix is not "remember to re-sync". It is that a script must find its OWN checkout. Resolve
# the symlink chain first, then take the dirname. Then a stale global install can only mean a
# stale ENTRY POINT, never a stale library.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  grep -qE '\$\{BASH_SOURCE\[0\]\}' "$f" 2>/dev/null || continue
  # It must assign SOME root from BASH_SOURCE to be in scope at all.
  grep -qE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*="\$\(cd -?P? ?"\$\(dirname' "$f" 2>/dev/null \
    || grep -qE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*="\$\(cd "\$\(dirname' "$f" 2>/dev/null \
    || continue
  # The unresolved form, verbatim. Its presence IS the violation.
  if grep -qE '="\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)/\.\." && pwd\)"' "$f" 2>/dev/null; then
    add "R10-unresolved-script-root" "$f" "derives its repo root from BASH_SOURCE without resolving the global-install symlink; through ~/.claude/scripts/ this root is ~/.claude, not the checkout"
    continue
  fi
  # And having resolved it, it must actually walk the chain.
  if ! grep -qE 'while \[ -L "\$_ss" \]' "$f" 2>/dev/null && ! grep -qE 'readlink' "$f" 2>/dev/null; then
    add "R10-unresolved-script-root" "$f" "assigns a root from BASH_SOURCE but never resolves a symlink chain (no readlink loop)"
    continue
  fi
  # SECONDARY derivations count too. apply-baseline-sync.sh resolved its REPO_ROOT correctly and
  # then computed a SECOND root, `SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"`,
  # to find its sibling scripts. `pwd -P` resolves the DIRECTORY, never the symlinked FILE, so
  # SELF_DIR was ~/.claude/scripts — and the script printed "WARN wire-rule-imports.sh not found
  # beside this script" on every run while wire-rule-imports.sh sat in the checkout. Every rule
  # in both target repos stayed unimported, and therefore never loaded, because of that one
  # line. One resolved root per file is not enough; ALL of them must be resolved.
  #
  # `printf`-quoted occurrences are exempt: run-preflight.sh emits a restore.sh whose OWN
  # BASH_SOURCE is about the generated file, which is not a symlink into anything.
  #
  # This file is skipped for the SECONDARY scan only: the rule's own grep pattern is a literal
  # match for what it looks for. Its primary root is checked above like every other script's,
  # and Rules 3 and 6 skip themselves for the same reason.
  case "$f" in *lint-setup-contracts.sh) continue ;; esac
  while IFS= read -r sec; do
    [ -z "$sec" ] && continue
    ln="${sec%%:*}"
    add "R10-unresolved-script-root" "$f:$ln" "a SECOND root is derived from BASH_SOURCE without resolving the symlink (pwd -P resolves the directory, not the symlinked file)"
  done < <(grep -nE '="\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)"' "$f" 2>/dev/null | grep -v 'printf' || true)
done < <(find scripts -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort || true)

# ---- Rule 11 — every installable artifact must have parseable YAML frontmatter ---------------
# MEASURED: 11 artifacts in one live repo and 3 in another carried frontmatter that no YAML
# parser accepts, and the defect was in the PACK SOURCE, not the install — two of them were
# newly installed by the delivery run. The cause is always the same shape: an unquoted plain
# scalar whose value contains a colon-space, e.g.
#     description: Add an event handler. ... Output: handler + tests + DLQ.
# YAML reads the second `: ` as a nested mapping key and errors with "mapping values are not
# allowed in this context". Every adapter that projects these files into another tool's surface
# has to parse that frontmatter; apply-adapter-sync.sh counted 11 MALFORMED FRONTMATTER and
# shipped them anyway. Quote the value and the file parses.
#
# SCOPE covers `_examples/` too. An `_examples/` file is not documentation:
# validate-pack-consistency.sh check 8b holds it to the artifact it abridges and apply-pack.sh
# installs it as the fallback when the full artifact is trimmed. It reaches a real project, so
# it is held to the same parser.
#
# ONE parser process for the whole corpus — a fork per file put this gate over two minutes.
# No parser -> skipped, loudly, because a gate that silently passes when its tool is absent is
# the always-pass bug this repo keeps fixing.
_R11_LIST=$(mktemp "${TMPDIR:-/tmp}/r11-list.XXXXXX")
find -L commands templates -type f -name '*.md' 2>/dev/null \
  | grep -vE '/CHANGELOG\.md$|/README\.md$|/STACK\.md$' | sort > "$_R11_LIST" || true
_R11_OUT=$(mktemp "${TMPDIR:-/tmp}/r11-out.XXXXXX")
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 - "$_R11_LIST" > "$_R11_OUT" <<'PYEOF' || true
import sys, yaml
for path in open(sys.argv[1]).read().split("\n"):
    if not path: continue
    try: lines = open(path, errors="replace").read().split("\n")
    except Exception: continue
    if not lines or lines[0].rstrip() != "---": continue
    end = next((i for i in range(1, len(lines)) if lines[i].rstrip() == "---"), None)
    if end is None: continue
    try: yaml.safe_load("\n".join(lines[1:end]))
    except Exception as e:
        print("%s\t%s" % (path, str(e).replace("\n", " ")[:160]))
PYEOF
elif [ -x /usr/bin/ruby ] && /usr/bin/ruby -ryaml -e 'exit 0' >/dev/null 2>&1; then
  # Encoding is NOT incidental here. This gate exports LC_ALL=C, and under LC_ALL=C ruby reads
  # every file as US-ASCII — at which point YAML.safe_load stops raising on the very
  # `mapping values are not allowed` error this rule exists to catch. The first version of this
  # rule found 69 real violations when run by hand and ZERO when run as the gate: an always-pass
  # that only its own locale created. Read UTF-8 explicitly.
  /usr/bin/ruby -ryaml -e '
    Encoding.default_external = Encoding::UTF_8
    Encoding.default_internal = Encoding::UTF_8
    File.read(ARGV[0], encoding: "UTF-8").split("\n").each do |path|
      next if path.empty?
      begin; lines = File.read(path, encoding: "UTF-8").split("\n", -1); rescue; next; end
      next if lines.empty? || lines[0].rstrip != "---"
      fin = nil
      (1...lines.length).each { |i| if lines[i].rstrip == "---" then fin = i; break end }
      next if fin.nil?
      begin
        YAML.safe_load(lines[1...fin].join("\n"))
      rescue => e
        puts "#{path}\t#{e.message.gsub("\n", " ")[0,160]}"
      end
    end' "$_R11_LIST" > "$_R11_OUT" 2>/dev/null || true
else
  say "  SKIP   R11  no YAML parser available (python3+pyyaml or ruby) — frontmatter unchecked"
  : > "$_R11_OUT"
fi
while IFS="$(printf '\t')" read -r f err; do
  [ -z "${f:-}" ] && continue
  add "R11-unparseable-frontmatter" "$f" "frontmatter is not valid YAML: $err"
done < "$_R11_OUT"
rm -f "$_R11_LIST" "$_R11_OUT"

_R12_TMP=$(mktemp "${TMPDIR:-/tmp}/r12.XXXXXX")
# ---- Rule 12 — the codebase-scan producer and its auditor must require the same sections ----
# MEASURED — a producer/auditor deadlock that refused every run on a live repo for four months.
# deep-codebase-scan.sh decides "is this file filled?" by counting `<TBD>` markers.
# audit-setup.sh C2c decides it by looking for the section HEADINGS. A file whose sections are
# ABSENT rather than unfilled has zero `<TBD>` markers, so the producer scored it 100% filled
# and preserved it, while C2c failed it nine times for the eight headings that were not there.
# Neither side was wrong; nothing compared them. The producer now repairs a structurally
# incomplete file instead of preserving it — and this rule keeps the two lists in step, because
# the next section C2c adds is the next deadlock if the producer never learns to emit it.
# Anchor to C2c's OWN loop. audit-setup.sh has more than one `for section in` and grabbing the
# first one made this rule report four sections C2c never asked for — a false positive is a
# retired gate within two weeks, so the anchor is not optional.
_C2C_SECS=$(awk '/C2c: codebase-scan semantic sections filled/{ c=1 }
                 c && /^  for section in /{ s=$0; sub(/^  for section in /,"",s); sub(/; do$/,"",s); print s; exit }' \
            scripts/audit-setup.sh 2>/dev/null || true)
if [ -n "$_C2C_SECS" ] && [ -f scripts/deep-codebase-scan.sh ]; then
  printf '%s\n' "$_C2C_SECS" | tr '"' '\n' | grep -vE '^ *$' | while IFS= read -r sec; do
    [ -z "$sec" ] && continue
    # The producer must be able to EMIT a heading carrying this phrase — both in the
    # first-write template and in the structural-repair path.
    if ! grep -qF "$sec" scripts/deep-codebase-scan.sh 2>/dev/null; then
      printf 'R12-scan-section-drift|scripts/deep-codebase-scan.sh|audit-setup.sh C2c requires _codebase-scan.md section "%s" but no producer emits that heading — that pair deadlocks: C2c fails the run, the producer preserves the file that fails it\n' "$sec"
    fi
  done > "$_R12_TMP" 2>/dev/null || true
  while IFS='|' read -r r f d; do
    [ -z "${r:-}" ] && continue
    add "$r" "$f" "$d"
  done < "$_R12_TMP"
fi
rm -f "$_R12_TMP"

# ---- Rule 13 — a printed remediation must name a script that exists -------------------------
# MEASURED: audit-setup.sh C2u failed a live run for an inert rules layer and prescribed
#   Fix: ~/.claude/scripts/wire-rule-imports.sh "<target>" --apply
# wire-rule-imports.sh was one of seven files committed at HEAD that had never been linked into
# the global install, so a reader who followed the audit verbatim got "No such file or
# directory". Two separate faults compound there: the literal `~/.claude/scripts/` root (which
# is only correct if the sync happens to be current) and no check that the named script exists
# at all. An audit that prescribes a command the reader cannot run has not reported a defect,
# it has added one.
#
# The rule is in two halves:
#   a) no runtime string may root a remediation at a literal `~/.claude/scripts/` — use the
#      script's own resolved dir, which by Rule 10 IS the checkout;
#   b) every `scripts/<name>` a runtime string prescribes must exist in this repo.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    ln="${hit%%:*}"
    add "R13-dead-remediation" "$f:$ln" "prints a remediation rooted at literal ~/.claude/scripts/ — that path exists only if the global install happens to be current; root it at the script's own resolved dir instead"
  done < <(grep -nF '~/.claude/scripts/' "$f" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' || true)
  # (b) names a sibling script that is not in this repo
  while IFS= read -r nm; do
    [ -z "$nm" ] && continue
    [ -e "scripts/$nm" ] && continue
    add "R13-dead-remediation" "$f" "prescribes scripts/$nm, which does not exist in this repo"
  #  `.claude/scripts/<x>` IS NOT A FRAMEWORK SIBLING. It is a path INSIDE THE TARGET, and
  #  several of them are materialize-on-first-use by design (`/grab-site` writes its own
  #  mirror script there before running it). The extractor matched the trailing
  #  `scripts/grab-site.py` of `.claude/scripts/grab-site.py` and demanded the framework ship
  #  it, which it must not. Neutralise the target-side prefix before extracting.
  done < <(sed 's|\.claude/scripts/|«target-scripts»/|g' "$f" 2>/dev/null \
           | grep -ohE '(\$SCRIPTS_DIR|\$REPO_ROOT/scripts|\$SELF_DIR|scripts)/[a-z0-9_-]+\.(sh|py)' 2>/dev/null \
           | sed 's|.*/||' | sort -u || true)
done < <(find scripts -maxdepth 1 -type f -name '*.sh' 2>/dev/null | grep -v 'lint-setup-contracts.sh' | grep -v 'sync-to-global.sh' | sort || true)

# ---- Rule 14 — a phase's mandatory script must be named in the command that runs the phase ---
# MEASURED: apply-baseline-sync.sh (Phase 4.1) appeared in templates/phases/phase-4.0-preflight.md
# and NOWHERE in commands/setup-project.md. An agent following § STEP ZERO's hard contracts —
# M17 preflight, M23 study-decisions, M25 anchors, M34 adapters, audit — therefore never ran it,
# every run, and landed on two guaranteed audit failures: C2g (the recall-inject.sh hook that
# ships there was missing, while the recall.md command that calls it had just been installed) and
# C2u (the rules layer was inert because wire-rule-imports.sh is invoked from there and nowhere
# else). 55 rules and ~82,475 tokens sat on disk in two live repos, imported by nothing.
#
# The rule is deliberately narrow: only scripts a phase file marks MANDATORY. A phase may
# mention a script as an option without the top-level command having to teach it.
_PHASE_SCRIPTS=$(grep -rhoE '(scripts/|~/\.claude/scripts/)(apply|run|wire|detect|study|deep|migrate|audit)-[a-z0-9-]+\.sh' \
                   templates/phases/ 2>/dev/null | sed 's|.*/||' | sort -u || true)
# The window crosses NEWLINES — a phase file writes `**Hard contract (M37) …**`, a blank line,
# a fenced block, and only then the script name. Two earlier drafts of this window were
# ALWAYS-PASS and both were caught only by introducing a real violation and watching nothing
# happen: a line-oriented `grep -E` cannot span the gap at all, and flattening the whole corpus
# to one 500 KB line made BSD grep's bounded `{0,400}` interval quietly stop matching. So the
# window is counted in LINES, by awk, which has neither problem.
#
# Both halves are narrow on purpose, because a gate with false positives is a gate somebody
# turns off. The MARKER must be a contract header, not any line containing the word "must" —
# `| conventions (MUST/MUST-NOT) |` in a table row about codex conventions was enough to make
# the loose version flag audit-adapter-coverage.sh. And the HIT must be an INVOCATION path
# (`scripts/<name>`), not a prose mention of a filename.
_PHASE_MANDATORY=$(find templates/phases -type f -name '*.md' 2>/dev/null -print0 \
  | xargs -0 awk '
      FNR==1 { last = -999 }
      /\*\*Hard contract|MUST run|MUST be run|is MANDATORY|^\*\*Why mandatory/ { last = FNR }
      (FNR - last) <= 8 {
        line = $0
        while (match(line, /scripts\/[a-z0-9_-]+\.(sh|py)/)) {
          hit = substr(line, RSTART, RLENGTH)
          sub(/^scripts\//, "", hit)
          print hit
          line = substr(line, RSTART + RLENGTH)
        }
      }' 2>/dev/null | sort -u || true)
for _psc in $_PHASE_SCRIPTS; do
  printf '%s\n' "$_PHASE_MANDATORY" | grep -qxF "$_psc" || continue
  grep -qF "$_psc" commands/setup-project.md 2>/dev/null && continue
  add "R14-phase-script-unnamed" "commands/setup-project.md" "templates/phases/ marks $_psc mandatory but commands/setup-project.md never names it — an agent that reads only the command's hard contracts will skip that phase, every run"
done

# ---- Rule 15 — a shipped ```bash block must parse as bash --------------------------------------
# MEASURED: templates/appendices.md carried
#     HAS_SEARCH=[[ "$HAS_ELASTIC" == "yes" || -n "$(…)" ]] && echo yes
# which is not an assignment. bash assigns the literal `[[` for one command and then EXECUTES
# `"$HAS_ELASTIC"` and `-n "…"`. Every run of Appendix A printed two `command not found` errors
# and the `search` domain signal could never be `yes`. Rule 3 screens for `grep -P` and nothing
# screened for "is this even bash", so it shipped.
#
# `bash -n` parses without executing. It is a SYNTAX check, not a semantics one — it would not
# have caught the HAS_SEARCH bug's *meaning*, but it does catch the shape, and the shape is what
# was wrong. Blocks whose first line marks them as illustrative (a `# example` / `# pseudo`
# opener) are skipped, as are blocks carrying `<placeholder>` angle-bracket syntax that is not
# meant to run.
_R15_LIST=$(mktemp "${TMPDIR:-/tmp}/r15.XXXXXX")
find commands templates -type f -name '*.md' 2>/dev/null | sort > "$_R15_LIST" || true
_R15_TMP=$(mktemp -d "${TMPDIR:-/tmp}/r15d.XXXXXX")
while IFS= read -r f; do
  [ -f "$f" ] || continue
  n=0
  while IFS= read -r blk; do
    [ -z "$blk" ] && continue
    n=$((n + 1))
    start="${blk%%:*}"
    awk -v s="$start" 'NR > s { if ($0 ~ /^[[:space:]]*```/) exit; print }' "$f" > "$_R15_TMP/blk.sh" 2>/dev/null || continue
    # THE PRECISE CHECK RUNS ON EVERY BLOCK, before any skip. It is an exact shape with no
    # false-positive surface, and the illustrative-block skips below exist for `bash -n`, whose
    # false-positive surface is large. Ordering matters: the block that shipped this defect
    # contains an ellipsis in a comment, so a skip evaluated first would have hidden it — and
    # did, in the first draft of this rule.
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      add "R15-assignment-of-test-bracket" "$f:$start" "\`${hit#*:}\` — the right-hand side of an assignment is a test bracket, which bash reads as a one-command env prefix and then runs the rest as a command; write \`VAR=\$( [ … ] && echo yes )\`"
    done < <(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\[\[?[[:space:]]' "$_R15_TMP/blk.sh" 2>/dev/null || true)
    # Illustrative blocks: a leading marker comment, or angle-bracket placeholders that are
    # syntax for the READER, not for bash. These skip only the `bash -n` leg.
    head -3 "$_R15_TMP/blk.sh" 2>/dev/null | grep -qiE '^#.*(example|pseudo|illustrat|sketch|shape of|not runnable)' && continue
    grep -qE '<[A-Za-z][A-Za-z0-9_ -]*>' "$_R15_TMP/blk.sh" 2>/dev/null && continue
    grep -qE '(\.\.\.|…)' "$_R15_TMP/blk.sh" 2>/dev/null && continue
    err=$(bash -n "$_R15_TMP/blk.sh" 2>&1) || {
      add "R15-unparseable-bash-block" "$f:$start" "the \`\`\`bash block starting here is not valid bash: $(printf '%s' "$err" | head -1 | sed 's|^[^:]*: ||')"
    }

  done < <(grep -nE '^[[:space:]]*```(bash|sh|shell)[[:space:]]*$' "$f" 2>/dev/null || true)
done < "$_R15_LIST"
rm -rf "$_R15_LIST" "$_R15_TMP"

# ---- Rule 16 — a script may not EMIT an unpaired project-specific anchor marker -------------
# MEASURED: study-existing.sh's decision legend printed a whole `<!-- project-specific:start -->`
# inside a sentence explaining what the marker means. Every generated study report therefore
# carried one start tag with no end tag, and whole-tree anchor balance went from 228/228 to
# 256/255 in one live repo and 96/96 to 120/119 in the other, for the first time. The content is
# harmless — it is documentation of the convention — but it silently defeats any start/end pair
# count, including the integrity check an auditor reaches for first, and "the tooling's own
# report is the thing corrupting the tooling's own census" is a bad half-hour for whoever finds
# it. Write the marker broken (`<!-- project-specific:` … `-->`) in prose.
#
# Scope: what scripts WRITE. A script that MATCHES the marker (grep/awk patterns, and the
# apply-anchors writer that legitimately emits both halves) is the point.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # Balance the emitted halves: count echo/printf/heredoc lines carrying each half.
  _st=$(grep -cE '(echo|printf|puts|^[[:space:]]*\*|^[[:space:]]*\|).*<!-- project-specific:start -->' "$f" 2>/dev/null || true)
  _en=$(grep -cE '(echo|printf|puts|^[[:space:]]*\*|^[[:space:]]*\|).*<!-- project-specific:end -->' "$f" 2>/dev/null || true)
  _st="${_st:-0}"; _en="${_en:-0}"
  [ "$_st" -le "$_en" ] && continue
  add "R16-unpaired-anchor-emitted" "$f" "emits $_st project-specific:start marker(s) against $_en end marker(s) — an unpaired marker in generated output breaks every anchor pair count that reads the file. In prose, write it broken: \`<!-- project-specific:\` … \`-->\`"
done < <(find scripts -maxdepth 1 -type f -name '*.sh' 2>/dev/null | grep -v 'lint-setup-contracts.sh' | sort || true)

# ---- Rule 17 — a pack artifact may not instruct the reader to run a file nothing installs ----
# MEASURED: apply-study-decisions.sh installed learning/commands/recall.md into a live repo. Its
# body tells the reader to run `.claude/hooks/recall-inject.sh`. That hook ships through
# apply-baseline-sync.sh — a script commands/setup-project.md did not name (see Rule 14) — so
# the run installed the command, did not install the hook, and then failed ITSELF for it: C2g
# "1 baseline file(s) missing" and C2w "recall.md instructs the reader to run a script that does
# not exist". A pack artifact that prescribes a helper is making a promise on the framework's
# behalf; the framework has to be able to keep it.
#
# The rule checks INSTALLABILITY, not phase ordering: every `.claude/hooks/<x>` or
# `.claude/scripts/<x>` a pack artifact names must exist in templates/repo-baseline/ (the
# baseline sync copies it) or in scripts/ (the adapter/step chain deploys it). Where neither
# holds, either ship the file or stop telling the reader to run it.
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  base="${ref##*/}"
  case "$ref" in
    .claude/hooks/*)   [ -f "templates/repo-baseline/.claude/hooks/$base" ] && continue ;;
    .claude/scripts/*) [ -f "templates/repo-baseline/.claude/scripts/$base" ] && continue
                       [ -f "scripts/$base" ] && continue ;;
  esac
  # SELF-INSTALLING REFERENCES ARE NOT DEAD ONES. Two pack artifacts carry the file they name:
  # frontend/_examples/golden-flow-hook.sh opens "Drop a copy of this file at
  # <project>/.claude/hooks/golden-flow.sh", and ui-ux/commands/grab-site.md bundles its python
  # verbatim under "write verbatim to .claude/scripts/grab-site.py". The reader who follows
  # those instructions HAS the file. Only a reference nobody ships and nobody materialises is a
  # dead one — the recall.md shape, where the command assumes a hook another phase installs.
  culprits=""
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    # A CHANGELOG or README is a RECORD of what changed, not an instruction to the reader.
    case "$c" in */CHANGELOG.md|*/README.md) continue ;; esac
    grep -qiE '(drop a copy of this file|write (it )?verbatim to|materiali[sz]e (it|this|the script)|save this (file|script) (to|as))' "$c" 2>/dev/null && continue
    culprits="$culprits$c "
  done < <(grep -rlF "$ref" templates/packs 2>/dev/null | head -5 || true)
  [ -z "$culprits" ] && continue
  add "R17-uninstallable-helper" "templates/packs" "pack artifact(s) ${culprits}instruct the reader to run $ref, which neither templates/repo-baseline/ nor scripts/ ships and which no artifact materialises — the reader gets 'No such file or directory'"
done < <(grep -rhoE '\.claude/(hooks|scripts)/[a-z0-9_-]+\.(sh|py)' templates/packs 2>/dev/null | sort -u || true)

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
  say "recorded $(printf '%s\n' "$sorted_findings" | grep -c . | tail -1) violation(s) -> $BASELINE"
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

total=$(printf '%s\n' "$sorted_findings" | grep -c . | tail -1)
say ""
say "setup-contracts: $total violation(s), $new_count new"
if [ "$new_count" -gt 0 ]; then
  echo "::error::$new_count NEW setup-contract violation(s). Fix them, or record deliberately with: bash scripts/lint-setup-contracts.sh --record" >&2
  exit 1
fi
say "OK — no new setup-contract violations."
exit 0
