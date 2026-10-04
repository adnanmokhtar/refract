#!/usr/bin/env bash
# test-report-honesty.sh — an artifact must not read as finished when it is not, and a check
# must not report "clean" when it never looked.
#
# Three defects, one shape. Each was measured on a live delivery run, and each passed every
# gate that existed at the time:
#
#   § 1  `.claude/_codebase-scan.md` shipped with its whole semantic half as the literal string
#        `<TBD>` — 8 sections — and reads as a finished report to anyone who does not run the
#        Phase 5 audit. the reference monorepo's equivalent is 303 lines of real content, so this is a
#        per-run gap, not a design limit; the file simply never said so about itself.
#
#   § 2  19 installed artifacts on the reference monorepo — including the tenant-isolation reviewer, the
#        highest-severity check that repo owns — run `rg ... src/` on a repo with no `src/`.
#        A probe over a missing directory returns zero hits, and zero hits reads as CLEAN.
#
#   § 3  C2t greps for the OLD `../../../snippets/` path shape only. A link rewritten exactly as
#        the fix instructs, pointing at a snippet the baseline never deployed, passed as clean:
#        41 of 95 relative links under .claude/ unresolved (43%), and the check printed
#        "ok no broken snippet/governance links in deployed artifacts".
#
# Everything runs under mktemp -d. Nothing is written outside it.
# Usage: test-report-honesty.sh [--quiet]   Exit: 0 pass / 1 fail
set -uo pipefail
export LC_ALL=C

_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
SCAN="${SCAN_OVERRIDE:-$REPO_ROOT/scripts/deep-codebase-scan.sh}"
AUDIT="${AUDIT_OVERRIDE:-$REPO_ROOT/scripts/audit-setup.sh}"
QUIET=0; for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }
pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; return 0; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-report-honesty.XXXXXX")
trap 'rm -rf "$TD"' EXIT

# ── § 1  an unfilled codebase scan says so, on its own face ──────────────────────────────
say "§ 1  _codebase-scan.md discloses its own unfilled sections"
if [ ! -f "$SCAN" ]; then
  say "SKIP: deep-codebase-scan.sh not found"
else
  S1="$TD/scan"; mkdir -p "$S1/src"
  printf 'export const a = 1\n' > "$S1/src/a.ts"
  printf '{"name":"scan"}\n'    > "$S1/package.json"
  bash "$SCAN" "$S1" >/dev/null 2>&1
  R1="$S1/.claude/_codebase-scan.md"
  if [ -f "$R1" ] && grep -q 'THIS REPORT IS INCOMPLETE' "$R1"; then
    ok "§1 the unfilled report carries an INCOMPLETE banner"
  else
    bad "§1 the unfilled report carries an INCOMPLETE banner" \
        "8 sections are the literal <TBD> and the file reads as finished"
  fi
  if [ -f "$R1" ] && grep -q 'deep-codebase-scan:incomplete start' "$R1" \
     && head -12 "$R1" | grep -q 'INCOMPLETE'; then
    ok "§1 the banner is at the TOP, inside managed markers"
  else
    bad "§1 the banner is at the top, inside managed markers" "a disclosure nobody scrolls to is not one"
  fi
  # it must remove ITSELF once the sections are written — a permanent banner is noise
  python3 - "$R1" <<'PY1'
import sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read().replace("<TBD>", "Real content the model wrote.")
open(p, "w", encoding="utf-8").write(t)
PY1
  bash "$SCAN" "$S1" >/dev/null 2>&1
  if grep -q 'deep-codebase-scan:incomplete' "$R1"; then
    bad "§1 the banner removes itself when the sections are filled" "a stale banner makes a real report look unfinished"
  else
    ok "§1 the banner removes itself when the sections are filled"
  fi
  # and re-running while still unfilled must not stack banners
  S1B="$TD/scan-b"; mkdir -p "$S1B/src"
  printf 'export const b = 1\n' > "$S1B/src/b.ts"; printf '{"name":"b"}\n' > "$S1B/package.json"
  bash "$SCAN" "$S1B" >/dev/null 2>&1
  # fill ONE section so the preserve path is taken on the second run
  python3 - "$S1B/.claude/_codebase-scan.md" <<'PY2'
import sys, re
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(t.replace("<TBD>", "Filled.", 1))
PY2
  bash "$SCAN" "$S1B" >/dev/null 2>&1
  bash "$SCAN" "$S1B" >/dev/null 2>&1
  n1=$( { grep -c 'deep-codebase-scan:incomplete start' "$S1B/.claude/_codebase-scan.md" 2>/dev/null || echo 0; } | tail -1 )
  [ "${n1:-0}" -eq 1 ] && ok "§1 re-running does not stack banners (exactly 1)" \
                       || bad "§1 re-running does not stack banners" "found ${n1:-0}"
fi

# ── § 2  a probe over a directory that does not exist is a FALSE NEGATIVE, not a pass ────
say "§ 2  a shell probe naming an absent directory fails the audit"
if [ ! -f "$AUDIT" ]; then
  say "SKIP: audit-setup.sh not found"
else
  P2="$TD/probe"; mkdir -p "$P2/.claude/agents" "$P2/apps/tenant"
  printf '# CLAUDE\n' > "$P2/CLAUDE.md"
  printf 'export class T {}\n' > "$P2/apps/tenant/t.ts"
  cat > "$P2/.claude/agents/tenant-isolation-reviewer.md" <<'A2'
---
name: tenant-isolation-reviewer
---
# Tenant isolation reviewer

## Automatic scans — every hit is a BLOCKER candidate

```bash
rg "skipTenantPrefix" src/
rg "createQueryBuilder" apps/tenant/
```
A2
  o2=$(bash "$AUDIT" "$P2" --read-only 2>&1 | sed -n '/^C2y:/,/^$/p')
  if printf '%s' "$o2" | grep -q 'ERR .*shell probe'; then
    ok "§2 the dead probe is reported"
  else
    bad "§2 the dead probe is reported" "$(printf '%s' "$o2" | head -3 | tr '\n' ' ')"
  fi
  if printf '%s' "$o2" | grep -q 'apps/tenant/'; then
    bad "§2 a probe over a directory that EXISTS is not reported" "apps/tenant/ was flagged"
  else
    ok "§2 a probe over a directory that EXISTS is not reported"
  fi
  # the mirror: a clean target must produce the ok, or the check is just noise
  P2B="$TD/probe-clean"; mkdir -p "$P2B/.claude/agents" "$P2B/apps/tenant"
  printf '# CLAUDE\n' > "$P2B/CLAUDE.md"
  printf 'export class T {}\n' > "$P2B/apps/tenant/t.ts"
  sed 's|rg "skipTenantPrefix" src/|rg "skipTenantPrefix" apps/|' \
    "$P2/.claude/agents/tenant-isolation-reviewer.md" > "$P2B/.claude/agents/tenant-isolation-reviewer.md"
  o2b=$(bash "$AUDIT" "$P2B" --read-only 2>&1 | sed -n '/^C2y:/,/^$/p')
  if printf '%s' "$o2b" | grep -q 'ok .*every shell probe'; then
    ok "§2 a target whose probes all resolve passes"
  else
    bad "§2 a target whose probes all resolve passes" "$(printf '%s' "$o2b" | head -3 | tr '\n' ' ')"
  fi
fi

# ── § 3  C2t must RESOLVE a link, not pattern-match one spelling of failure ──────────────
say "§ 3  a rewritten link whose destination was never deployed is still dead"
if [ ! -f "$AUDIT" ]; then
  say "SKIP: audit-setup.sh not found"
else
  P3="$TD/links"; mkdir -p "$P3/.claude/commands" "$P3/.claude/templates/snippets"
  printf '# CLAUDE\n' > "$P3/CLAUDE.md"
  printf 'snippet body\n' > "$P3/.claude/templates/snippets/plan-flag.md"
  printf -- '---\nname: x\n---\n# X\n\nSee [plan](../templates/snippets/plan-flag.md) and [gone](../templates/snippets/review-action-plan.md).\n' \
    > "$P3/.claude/commands/x.md"
  a3=$(bash "$AUDIT" "$P3" --read-only 2>&1 || true)
  o3=$(printf '%s\n' "$a3" | sed -n '/^C2t:/,/^$/p')
  # SAY WHICH SECTIONS RAN, NOT JUST THAT ONE IS MISSING.
  #
  # Same lesson as test-rule-loading.sh § 2: when the captured section is EMPTY, every
  # assertion about its contents fails with an empty detail line — which renders as no
  # detail at all — and the emptiness IS the finding. On CI this reported three failures
  # and printed nothing that distinguished "C2t ran and disagreed" from "C2t never ran".
  # Listing the section headers the audit actually emitted answers that in one line.
  if [ -z "$o3" ]; then
    bad "§3 the audit never emitted a C2t: section" \
        "sections seen: $(printf '%s\n' "$a3" | grep -oE '^C2[a-z]:' | tr '\n' ' ')| ended: $(printf '%s\n' "$a3" | grep -vE '^[[:space:]]*$' | tail -2 | tr '\n' ' ' | cut -c1-150)"
  fi
  if printf '%s' "$o3" | grep -q 'do NOT resolve on disk'; then
    ok "§3 an unresolved rewritten link is reported"
  else
    bad "§3 an unresolved rewritten link is reported" "$(printf '%s' "$o3" | head -3 | tr '\n' ' ')"
  fi
  if printf '%s' "$o3" | grep -q 'review-action-plan.md'; then
    ok "§3 it names the link that is dead"
  else
    bad "§3 it names the link that is dead" "$(printf '%s' "$o3" | head -4 | tr '\n' ' ')"
  fi
  printf 'snippet body\n' > "$P3/.claude/templates/snippets/review-action-plan.md"
  o3b=$(bash "$AUDIT" "$P3" --read-only 2>&1 | sed -n '/^C2t:/,/^$/p' || true)
  if printf '%s' "$o3b" | grep -q 'ok .*every relative .md link'; then
    ok "§3 deploying the missing snippet clears it"
  else
    bad "§3 deploying the missing snippet clears it" "$(printf '%s' "$o3b" | head -3 | tr '\n' ' ')"
  fi
  # ── § 3b  a SKILL's link is one `../` deeper, and the shape check must still see it ──────
  # A pack skill links `](../../../../snippets/…)` from skills/<name>/SKILL.md. C2t's shape grep
  # matched exactly three `../`, so a skill installed without the rewrite passed as clean. And a
  # link into a snippet SUBDIRECTORY (`precedents/data.md`) must resolve like any other.
  mkdir -p "$P3/.claude/skills/sk"
  printf -- '---\nname: sk\n---\n# SK\n\nSee [r](../../../../snippets/plan-flag.md).\n' > "$P3/.claude/skills/sk/SKILL.md"
  o3c=$(bash "$AUDIT" "$P3" --read-only 2>&1 | sed -n '/^C2t:/,/^$/p' || true)
  if printf '%s' "$o3c" | grep -q 'un-rewritten pack links' && printf '%s' "$o3c" | grep -q 'skills/sk/SKILL.md'; then
    ok "§3b a skill still carrying the four-level pack link is reported by the shape check"
  else
    bad "§3b a skill still carrying the four-level pack link is reported by the shape check" "$(printf '%s' "$o3c" | head -4 | tr '\n' ' ')"
  fi
  printf -- '---\nname: sk\n---\n# SK\n\nSee [r](../../templates/snippets/plan-flag.md) and [p](../../templates/snippets/precedents/data.md).\n' > "$P3/.claude/skills/sk/SKILL.md"
  o3d=$(bash "$AUDIT" "$P3" --read-only 2>&1 | sed -n '/^C2t:/,/^$/p' || true)
  if printf '%s' "$o3d" | grep -q 'do NOT resolve on disk' && printf '%s' "$o3d" | grep -q 'precedents/data.md'; then
    ok "§3b a rewritten skill link into an undeployed snippet SUBDIRECTORY is reported"
  else
    bad "§3b a rewritten skill link into an undeployed snippet SUBDIRECTORY is reported" "$(printf '%s' "$o3d" | head -4 | tr '\n' ' ')"
  fi
  if printf '%s' "$o3d" | grep -q 'un-rewritten pack links'; then
    bad "§3b a correctly rewritten skill is not called un-rewritten" "$(printf '%s' "$o3d" | head -3 | tr '\n' ' ')"
  else
    ok "§3b a correctly rewritten skill is not called un-rewritten"
  fi
  mkdir -p "$P3/.claude/templates/snippets/precedents"
  printf 'precedents\n' > "$P3/.claude/templates/snippets/precedents/data.md"
  o3e=$(bash "$AUDIT" "$P3" --read-only 2>&1 | sed -n '/^C2t:/,/^$/p' || true)
  if printf '%s' "$o3e" | grep -q 'ok .*every relative .md link'; then
    ok "§3b deploying the subdirectory snippet clears it"
  else
    bad "§3b deploying the subdirectory snippet clears it" "$(printf '%s' "$o3e" | head -3 | tr '\n' ' ')"
  fi

  # ── § 3c  the ROOT CAUSE: the baseline must ship every snippet the packs link to ─────────
  # One matcher, used three ways: on a fixture that MUST fire, on the same fixture once fixed,
  # and on the real tree. It used to match three-level links to TOP-LEVEL snippets only, so a
  # skill's four-level link and any `precedents/<domain>.md` were never even looked up — the
  # test passed on the cases it could not see. lint-setup-contracts.sh Rule 19 is the same
  # matcher and is driven against the same fixture below.
  undeployed_snippet_refs() {   # $1 = packs dir, $2 = repo-baseline templates dir
    local ref out=""
    while IFS= read -r ref; do
      [ -z "$ref" ] && continue
      [ -f "$2/$ref" ] || out="$out $ref"
    done < <(grep -rhoE '\]\((\.\./){3,4}(snippets|governance)/([A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.md(#[A-Za-z0-9_-]+)?\)' "$1" 2>/dev/null \
             | sed -E 's#^\]\((\.\./)+##; s#\)$##; s/#.*$//' | sort -u || true)
    printf '%s' "$out"
  }
  FX="$TD/fx-repo"; FXB="$FX/templates/repo-baseline/.claude/templates"
  mkdir -p "$FX/templates/packs/fx/skills/sk" "$FX/templates/packs/fx/commands" "$FXB/snippets" "$FXB/governance"
  printf -- '---\nname: sk\ndescription: "fixture"\n---\n# SK\n\n[a](../../../../snippets/skill-only.md) [b](../../../../snippets/precedents/skill-sub.md) [c](../../../../governance/gov-only.md)\n' \
    > "$FX/templates/packs/fx/skills/sk/SKILL.md"
  printf -- '---\nname: c\ndescription: "fixture"\n---\n# C\n\n[d](../../../snippets/precedents/cmd-sub.md#anchor) [e](../../../snippets/shipped.md)\n' \
    > "$FX/templates/packs/fx/commands/c.md"
  printf 'shipped\n' > "$FXB/snippets/shipped.md"
  m3=$(undeployed_snippet_refs "$FX/templates/packs" "$FXB")
  m3_miss=""
  for want in snippets/skill-only.md snippets/precedents/skill-sub.md governance/gov-only.md snippets/precedents/cmd-sub.md; do
    case " $m3 " in *" $want "*) ;; *) m3_miss="$m3_miss $want" ;; esac
  done
  [ -z "$m3_miss" ] && ok "§3c the matcher sees four-level skill links and snippet subdirectories" \
                    || bad "§3c the matcher sees four-level skill links and snippet subdirectories" "missed:$m3_miss (found:$m3)"
  case " $m3 " in *" snippets/shipped.md "*) bad "§3c a deployed snippet is not reported" "$m3" ;;
                  *) ok "§3c a deployed snippet is not reported" ;; esac
  LINT="$REPO_ROOT/scripts/lint-setup-contracts.sh"
  if [ -f "$LINT" ]; then
    l3=$(bash "$LINT" --repo-root="$FX" 2>&1 | grep 'R19-undeployed-snippet' || true)
    l3_miss=""
    for want in snippets/skill-only.md snippets/precedents/skill-sub.md governance/gov-only.md snippets/precedents/cmd-sub.md; do
      printf '%s' "$l3" | grep -qF "templates/$want" || l3_miss="$l3_miss $want"
    done
    [ -z "$l3_miss" ] && ok "§3c lint-setup-contracts Rule 19 fires on a skill's link and on a snippet subdirectory" \
                      || bad "§3c lint-setup-contracts Rule 19 fires on a skill's link and on a snippet subdirectory" "missed:$l3_miss | $(printf '%s' "$l3" | head -3 | tr '\n' ' ')"
  fi
  mkdir -p "$FXB/snippets/precedents"
  for f in snippets/skill-only.md snippets/precedents/skill-sub.md governance/gov-only.md snippets/precedents/cmd-sub.md; do
    printf 'x\n' > "$FXB/$f"
  done
  m3b=$(undeployed_snippet_refs "$FX/templates/packs" "$FXB")
  [ -z "${m3b// /}" ] && ok "§3c shipping them clears the matcher" || bad "§3c shipping them clears the matcher" "$m3b"
  if [ -f "$LINT" ]; then
    l3b=$(bash "$LINT" --repo-root="$FX" 2>&1 | grep 'R19-undeployed-snippet' || true)
    [ -z "$l3b" ] && ok "§3c shipping them clears Rule 19" || bad "§3c shipping them clears Rule 19" "$(printf '%s' "$l3b" | head -2 | tr '\n' ' ')"
  fi
  missing3=$(undeployed_snippet_refs "$REPO_ROOT/templates/packs" "$REPO_ROOT/templates/repo-baseline/.claude/templates")
  [ -z "${missing3// /}" ] && ok "§3c the repo-baseline ships every snippet the packs link to" \
                           || bad "§3c the repo-baseline ships every snippet the packs link to" "not deployed:$missing3"
fi

# ── § 4  a command that SHIPS its helper is not a dead path ──────────────────────────────
# C2w raised a hard ERR on the sibling repo because `.claude/commands/grab-site.md` says to run
# `.claude/scripts/grab-site.py`, which is absent — but that command CARRIES the whole mirror
# script inside itself and says "write verbatim to" that path before running it. The remedy
# C2w printed ("ship the helper") would have duplicated a script the command already holds.
# A genuinely dead path must still fail, or the exemption is just a mute button.
say "§ 4  materialize-on-first-use is exempt; a truly dead path is not"
if [ ! -f "$AUDIT" ]; then
  say "SKIP: audit-setup.sh not found"
else
  P4="$TD/matz"; mkdir -p "$P4/.claude/commands"
  printf '# CLAUDE\n' > "$P4/CLAUDE.md"
  cat > "$P4/.claude/commands/grab-thing.md" <<'M4'
---
name: grab-thing
---
# grab-thing

Materialize the bundled script to `.claude/scripts/grab-thing.py`, then run it:

```bash
python3 .claude/scripts/grab-thing.py <url>
```
M4
  printf -- '---\nname: dead\n---\n# dead\n\nRun `.claude/scripts/nothing.py` first.\n' > "$P4/.claude/commands/dead.md"
  o4=$(bash "$AUDIT" "$P4" --read-only 2>&1 | sed -n '/^C2w:/,/^$/p')
  if printf '%s' "$o4" | grep -q 'grab-thing.py'; then
    bad "§4 a command that ships its own helper is not flagged" "$(printf '%s' "$o4" | grep grab-thing | head -1)"
  else
    ok "§4 a command that ships its own helper is not flagged"
  fi
  if printf '%s' "$o4" | grep -q 'nothing.py'; then
    ok "§4 a genuinely dead path IS still flagged"
  else
    bad "§4 a genuinely dead path IS still flagged" "the exemption became a mute button"
  fi
fi

say ""
say "report-honesty fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
