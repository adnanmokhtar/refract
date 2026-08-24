#!/usr/bin/env bash
# test-anchor-citations.sh — fixture suite for the ONE line apply-anchors.sh writes into every
# artifact it touches: `> Cite-able sources: <manifests>, top-level: <dirs>.`
#
# WHY THIS SUITE EXISTS. That line is the only project-specific fact most artifacts carry, and
# it is written unconditionally over whatever was there before. On a live Vue 3 SPA the picker
# cited `.husky/`, `.husky/_/`, `.playwright-mcp/` and `new-architecture-standalone/` — between
# them 1 git-tracked file and 0 source files — into 118 of 118 artifacts, replacing
# `src/assets src/components src/composables`, and the run logged the overwrite as "Stale
# citations repaired: 94". The identical code path on a NestJS monorepo picked `apps/`,
# `apps/master/`, `apps/tenant/` and looked correct, which is why the defect survived every
# copy-based test: it is LAYOUT-dependent. Alphabetical order agreed with source density in one
# repo and disagreed in the other.
#
# Two independent failures had to line up, so this suite pins both:
#   § 1  the picker took the first four survivors in ALPHABETICAL order and broke at the cap,
#        so a dot-directory that sorts early beat the source tree that sorts late.
#   § 2  the staleness test split the existing citation on commas only, so the older
#        space-separated form read as one unresolvable token — every artifact carrying it was
#        declared stale and overwritten with the bad value from § 1.
#   § 3  the monorepo layout that looked fine must STILL look fine (no-regression).
#   § 4  a citation that genuinely does not resolve must still be repaired — the fix must not
#        buy safety by turning the repair off.
#
# Everything runs under mktemp -d. Nothing is written outside it.
#
# Usage: test-anchor-citations.sh [--quiet]
# Exit:  0 all fixtures pass / 1 a fixture failed
set -uo pipefail
export LC_ALL=C

# Symlink-resolved: ~/.claude/scripts/<name> links into this repo (see CONTRIBUTING
# § "Scripts run from two places"). Gate: lint-setup-contracts.sh Rule 10.
_ss="${BASH_SOURCE[0]}"
while [ -L "$_ss" ]; do _sd="$(cd -P "$(dirname "$_ss")" && pwd)"; _ss="$(readlink "$_ss")"; case "$_ss" in /*) ;; *) _ss="$_sd/$_ss" ;; esac; done
REPO_ROOT="$(cd -P "$(dirname "$_ss")/.." && pwd)"; unset _ss _sd
ANCHORS="${ANCHORS_OVERRIDE:-$REPO_ROOT/scripts/apply-anchors.sh}"
ANCHOR_AUDIT="${ANCHOR_AUDIT_OVERRIDE:-$REPO_ROOT/scripts/audit-anchoring.sh}"
PACK_SCAN="${PACK_SCAN_OVERRIDE:-$REPO_ROOT/scripts/pack-coverage-scan.sh}"
QUIET=0
for a in "$@"; do [ "$a" = "--quiet" ] && QUIET=1; done
say() { [ $QUIET -eq 1 ] || printf '%s\n' "$*"; }

pass=0; fail=0
ok()  { pass=$((pass+1)); say "  ok   $1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

[ -f "$ANCHORS" ] || { echo "ERR: $ANCHORS not found" >&2; exit 1; }

TD=$(mktemp -d "${TMPDIR:-/tmp}/test-anchor-citations.XXXXXX")
trap 'rm -rf "$TD"' EXIT

# ---- helpers ---------------------------------------------------------------------------
# Write the two Phase-0/Phase-2 inputs apply-anchors.sh requires. $2.. = the § 2 dir list.
seed_setup() {
  local root="$1"; shift
  mkdir -p "$root/.claude/commands"
  {
    printf '# Codebase scan\n\n## 1. Size\n\n## 2. Top-level directories (depth 2)\n\n```\n'
    printf '%s\n' "$@"
    printf '```\n\n## 3. Manifests + framework markers\n\n```\npackage.json  package.json\n```\n'
  } > "$root/.claude/_codebase-scan.md"
  cat > "$root/.claude/codebase-profile.md" <<'PROF'
# Codebase profile

## Architecture
Feature-module architecture.

## Naming
PascalCase components.

## Testing
Vitest.

## Data access
One shared client.

## Error handling
Interceptor maps 401.
PROF
}

seed_artifact() {  # $1=root $2=name  (a bare pack-shaped command, no anchor yet)
  cat > "$1/.claude/commands/$2.md" <<ART
---
name: $2
description: Fixture artifact.
---

# $2

Do the thing.
ART
}

cite_of() {  # $1=file → the value after `top-level:`, minus the trailing period
  local v
  v=$(grep -m1 -E '^>[[:space:]]*Cite-able sources:' "$1" 2>/dev/null || true)
  v="${v#*top-level:}"
  printf '%s' "${v%.}" | sed 's/^[[:space:]]*//'
}

# ── § 1  SPA layout: tooling dot-dirs sort first, the source tree sorts last ──────────────
say "§ 1  single-root SPA — the picker must not cite tooling directories"
P1="$TD/spa"
mkdir -p "$P1"/{.husky/_,.playwright-mcp,new-architecture-standalone} \
         "$P1"/src/{assets,components,composables,views}
printf '#!/bin/sh\n' > "$P1/.husky/pre-commit"
printf 'x\n'         > "$P1/.husky/_/husky.sh"
printf '{}\n'        > "$P1/.playwright-mcp/trace.json"
printf 'readme\n'    > "$P1/new-architecture-standalone/README.md"
printf 'svg\n'       > "$P1/src/assets/logo.svg"
for i in 1 2 3 4 5 6 7 8 9 10; do printf 'export const x%s = %s\n' "$i" "$i" > "$P1/src/components/C$i.ts"; done
for i in 1 2 3; do printf '<template><div/></template>\n' > "$P1/src/views/V$i.vue"; done
printf 'export const useX = () => {}\n' > "$P1/src/composables/useX.ts"
printf '{"name":"spa"}\n' > "$P1/package.json"
seed_setup "$P1" .claude .claude/commands .husky .husky/_ .playwright-mcp \
                 new-architecture-standalone src src/assets src/components src/composables src/views
seed_artifact "$P1" add-page
bash "$ANCHORS" "$P1" --apply >/dev/null 2>&1
C1=$(cite_of "$P1/.claude/commands/add-page.md")
if [ -z "$C1" ]; then
  bad "§1 a citation line was written" "no Cite-able-sources line in the artifact"
else
  ok "§1 a citation line was written"
fi
# The defect, stated as an assertion: no directory that holds zero source files may be cited.
for junk in '.husky' '.playwright-mcp' 'new-architecture-standalone'; do
  case "$C1" in
    *"\`$junk/\`"*) bad "§1 does not cite $junk/" "citation is: $C1" ;;
    *)              ok  "§1 does not cite $junk/" ;;
  esac
done
case "$C1" in
  *'`src/'*) ok  "§1 cites the source tree" ;;
  *)         bad "§1 cites the source tree" "citation is: $C1" ;;
esac

# ── § 2  the older space-separated citation must not read as stale ───────────────────────
say "§ 2  a resolvable space-separated citation is NOT stale"
P2="$TD/spa-legacy"
mkdir -p "$P2"/src/{assets,components,composables} "$P2/.husky"
printf '#!/bin/sh\n' > "$P2/.husky/pre-commit"
printf 'svg\n' > "$P2/src/assets/logo.svg"
for i in 1 2 3; do printf 'export const y%s = %s\n' "$i" "$i" > "$P2/src/components/D$i.ts"; done
printf 'export const useY = () => {}\n' > "$P2/src/composables/useY.ts"
printf '{"name":"legacy"}\n' > "$P2/package.json"
seed_setup "$P2" .claude .claude/commands .husky src src/assets src/components src/composables
cat > "$P2/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
> Cite-able sources: `package.json`, top-level: src/assets src/components src/composables.
<!-- project-specific:end -->

Do the thing.
ART
BEFORE2=$(cite_of "$P2/.claude/commands/add-page.md")
out2=$(bash "$ANCHORS" "$P2" --apply 2>&1)
AFTER2=$(cite_of "$P2/.claude/commands/add-page.md")
if [ "$BEFORE2" = "$AFTER2" ]; then
  ok "§2 the existing citation survived untouched"
else
  bad "§2 the existing citation survived untouched" "was [$BEFORE2] now [$AFTER2]"
fi
rep2=$(printf '%s' "$out2" | sed -n 's/^Stale citations repaired:[[:space:]]*//p')
if [ "${rep2:-0}" = "0" ]; then
  ok "§2 the run reported 0 repairs"
else
  bad "§2 the run reported 0 repairs" "reported $rep2"
fi

# ── § 3  monorepo layout — the shape that already worked must keep working ───────────────
say "§ 3  monorepo — no regression on the layout that was already correct"
# Shaped like the real monorepo this was measured on: TWO source roots plus a third small one,
# and enough qualifying candidates (6) that the 4-slot cap actually bites. With depth-first
# spending, `apps/`, `apps/tenant/`, `apps/master/` and `chrome-extension/` take every slot and
# `libs/` — where half the code lives — is cut.
P3="$TD/mono"
mkdir -p "$P3"/apps/{master,tenant}/src "$P3"/libs/database/src "$P3/chrome-extension" "$P3/caddy"
for i in 1 2 3 4 5; do printf 'export class M%s {}\n' "$i" > "$P3/apps/master/src/m$i.ts"; done
for i in 1 2 3 4 5 6 7 8; do printf 'export class T%s {}\n' "$i" > "$P3/apps/tenant/src/t$i.ts"; done
for i in 1 2 3; do printf 'export class L%s {}\n' "$i" > "$P3/libs/database/src/l$i.ts"; done
for i in 1 2 3 4; do printf 'console.log(%s)\n' "$i" > "$P3/chrome-extension/bg$i.js"; done
printf 'reverse proxy\n' > "$P3/caddy/Caddyfile"
printf '{"name":"mono"}\n' > "$P3/package.json"
seed_setup "$P3" .claude .claude/commands apps apps/master apps/tenant caddy chrome-extension libs libs/database
seed_artifact "$P3" add-endpoint
bash "$ANCHORS" "$P3" --apply >/dev/null 2>&1
C3=$(cite_of "$P3/.claude/commands/add-endpoint.md")
case "$C3" in
  *'`apps/`'*) ok  "§3 cites apps/" ;;
  *)           bad "§3 cites apps/" "citation is: $C3" ;;
esac
case "$C3" in
  *'`caddy/`'*) bad "§3 does not cite caddy/ (config, no source)" "citation is: $C3" ;;
  *)            ok  "§3 does not cite caddy/ (config, no source)" ;;
esac
# BREADTH BEFORE DEPTH. The cap is 4 and the candidate list contains nested dirs, so the
# ranking used to spend three slots inside ONE tree (`apps/`, `apps/tenant/`, `apps/master/`)
# and cut `libs/` — the shared-library root half the codebase lives in, and the one the anchor
# block cites `DataAccess<…> at libs/database/src/…` from three lines above. Every path it did
# print resolved, so no gate saw it. Each distinct top-level root gets a slot first.
case "$C3" in
  *'`libs/`'*|*'`libs/database/`'*) ok  "§3 cites the second source root (libs/) — breadth before depth" ;;
  *)                                bad "§3 cites the second source root (libs/)" "citation is: $C3 — one tree ate the cap" ;;
esac

# ── § 4  a citation that really is dead must still be repaired ───────────────────────────
say "§ 4  a citation naming a directory that does not exist IS repaired"
P4="$TD/stale"
mkdir -p "$P4/src/components"
for i in 1 2 3; do printf 'export const z%s = %s\n' "$i" "$i" > "$P4/src/components/E$i.ts"; done
printf '{"name":"stale"}\n' > "$P4/package.json"
seed_setup "$P4" .claude .claude/commands src src/components
cat > "$P4/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
> Cite-able sources: `package.json`, top-level: `lib/`, `pkg/`.
<!-- project-specific:end -->

Do the thing.
ART
bash "$ANCHORS" "$P4" --apply >/dev/null 2>&1
C4=$(cite_of "$P4/.claude/commands/add-page.md")
case "$C4" in
  *'`lib/`'*|*'`pkg/`'*) bad "§4 the dead citation was replaced" "citation is still: $C4" ;;
  *'`src/'*)             ok  "§4 the dead citation was replaced" ;;
  *)                     bad "§4 the dead citation was replaced" "citation is: $C4" ;;
esac

# ── § 6  an anchor with NO citation line at all must gain one ────────────────────────────
say "§ 6  an anchored artifact carrying no Cite-able line is repaired, not skipped"
P6="$TD/no-cite"
mkdir -p "$P6/src/components"
for i in 1 2 3; do printf 'export const w%s = %s\n' "$i" "$i" > "$P6/src/components/F$i.ts"; done
printf '{"name":"nocite"}\n' > "$P6/package.json"
seed_setup "$P6" .claude .claude/commands src src/components
cat > "$P6/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
> Architecture: feature modules.
<!-- project-specific:end -->

Do the thing.
ART
bash "$ANCHORS" "$P6" --apply >/dev/null 2>&1
C6=$(cite_of "$P6/.claude/commands/add-page.md")
if [ -n "$C6" ]; then
  ok "§6 the missing citation line was written ($C6)"
else
  bad "§6 the missing citation line was written" "still no Cite-able-sources line — an anchored file with no citation is a permanent skip"
fi
# and the pre-existing anchor body must survive
if grep -q 'Architecture: feature modules' "$P6/.claude/commands/add-page.md"; then
  ok "§6 the existing anchor body survived"
else
  bad "§6 the existing anchor body survived" "the repair overwrote anchor content"
fi

# ── § 7  THE AUDITOR must read the same citation the WRITER just approved ────────────────
# The writer half of the space-separated-citation bug was fixed (§ 2). The auditor half was
# not, and nothing here exercised it: audit-anchoring.sh split the `top-level:` tail on commas
# alone, so `src/assets src/components src/composables` became ONE 43-character token that
# resolves as nothing. MEASURED on tenant-portal: 94 "cross-project leaks", every one that same
# string, all three directories present on disk — and audit-setup.sh C2d promotes each to ERR,
# so a correctly-anchored run could not pass its own audit and the remedy it printed (re-run
# apply-anchors.sh) provably could not help, because apply-anchors.sh agrees the citation is
# fine. Writer and auditor must split on the SAME separator set or they disagree about what
# the same line says.
say "§ 7  the auditor reads the space-separated citation the writer approves"
P7="$TD/audit-legacy"
mkdir -p "$P7"/src/{assets,components,composables} "$P7/.claude/commands"
printf 'svg\n' > "$P7/src/assets/logo.svg"
for i in 1 2 3; do printf 'export const q%s = %s\n' "$i" "$i" > "$P7/src/components/G$i.ts"; done
printf 'export const useQ = () => {}\n' > "$P7/src/composables/useQ.ts"
printf '{"name":"audit-legacy"}\n' > "$P7/package.json"
seed_setup "$P7" .claude .claude/commands src src/assets src/components src/composables
cat > "$P7/.claude/commands/add-page.md" <<'ART'
---
name: add-page
description: Fixture artifact.
---

# add-page

<!-- project-specific:start -->
## Project-specific (auto-generated)

> - **Architecture** (`.claude/codebase-profile.md:3`): feature modules.
> Cite-able sources: `package.json`, top-level: src/assets src/components src/composables.

<!-- project-specific:end -->

Do the thing.
ART
A7=$(bash "$ANCHOR_AUDIT" "$P7" --quiet --stdout 2>/dev/null || true)
leaks7=$(printf '%s\n' "$A7" | sed -n 's/^Cross-project leaks:[[:space:]]*//p' | head -1)
if [ "${leaks7:-x}" = "0" ]; then
  ok "§7 the auditor reports 0 leaks for a citation whose parts all resolve"
else
  bad "§7 the auditor reports 0 leaks for a citation whose parts all resolve" \
      "reported ${leaks7:-<no summary>} leak(s): $(printf '%s\n' "$A7" | grep -m2 'add-page' | tr '\n' ' ')"
fi
# and the mirror: a citation naming a directory that does NOT exist must STILL be a leak,
# so the fix cannot buy silence by turning the extractor off.
P7B="$TD/audit-dead"
mkdir -p "$P7B/src/components" "$P7B/.claude/commands"
for i in 1 2 3; do printf 'export const r%s = %s\n' "$i" "$i" > "$P7B/src/components/H$i.ts"; done
printf '{"name":"audit-dead"}\n' > "$P7B/package.json"
seed_setup "$P7B" .claude .claude/commands src src/components
sed 's|top-level: src/assets src/components src/composables\.|top-level: nope-one nope-two.|' \
  "$P7/.claude/commands/add-page.md" > "$P7B/.claude/commands/add-page.md"
A7B=$(bash "$ANCHOR_AUDIT" "$P7B" --quiet --stdout 2>/dev/null || true)
leaks7b=$(printf '%s\n' "$A7B" | sed -n 's/^Cross-project leaks:[[:space:]]*//p' | head -1)
if [ "${leaks7b:-0}" -ge 2 ] 2>/dev/null; then
  ok "§7 a space-separated citation naming absent directories IS still reported ($leaks7b leak(s))"
else
  bad "§7 a space-separated citation naming absent directories IS still reported" \
      "reported ${leaks7b:-<no summary>} — the extractor went blind instead of getting smarter"
fi

# ── § 8  an anchored artifact must strip back to its pack source EXACTLY ─────────────────
# THE METRIC-KILLER. Every consumer that asks "is this artifact current?" strips the anchor and
# compares what is left with the pack source — study-existing.sh stripped_target(),
# merge-decide.py split_anchors(). Both drop the blank line that FOLLOWS the `:end -->` marker.
# inject_block() used to write that blank BEFORE the `:start -->` marker and none after, so the
# strip left one extra blank line in EVERY anchored artifact and no deployed file could ever
# compare equal to its source. MEASURED across two live repos: byte-for-byte pack currency
# 0 → 0 over 207 pack commands+agents, after 154 of them had been rewritten from current pack
# source. `.claude/agents/websocket-engineer.md` stripped was 190 lines against a 189-line pack
# and the complete unified diff was `@@ -9,0 +10 @@` / `+`. The work landed; the ruler could
# not see it, and the owner read "nothing arrived".
#
# Runs against REAL pack sources — the round trip is only meaningful over the file shapes the
# packs actually ship (frontmatter or not, H2 or not, long or short).
say "§ 8  strip(anchor(pack)) == the pack source, byte for byte"
P8="$TD/roundtrip"
mkdir -p "$P8/.claude/commands" "$P8/.claude/agents" "$P8/src/components"
for i in 1 2 3; do printf 'export const v%s = %s\n' "$i" "$i" > "$P8/src/components/K$i.ts"; done
printf '{"name":"roundtrip"}\n' > "$P8/package.json"
seed_setup "$P8" .claude .claude/commands .claude/agents src src/components
mkdir -p "$P8/orig"
n8=0
while IFS= read -r src; do
  [ -f "$src" ] || continue
  kind="$(basename "$(dirname "$src")")"
  case "$kind" in commands|agents) ;; *) continue ;; esac
  bn="$(basename "$src")"
  [ -f "$P8/.claude/$kind/$bn" ] && continue
  cp "$src" "$P8/.claude/$kind/$bn"
  cp "$src" "$P8/orig/$kind-$bn"
  n8=$((n8+1))
  [ "$n8" -ge 6 ] && break
done < <(find -L "$REPO_ROOT/templates/packs" -maxdepth 3 \( -path '*/commands/*.md' -o -path '*/agents/*.md' \) -type f 2>/dev/null | sort)
if [ "$n8" -eq 0 ]; then
  bad "§8 pack sources were found to test against" "no templates/packs/*/{commands,agents}/*.md"
else
  bash "$ANCHORS" "$P8" --apply >/dev/null 2>&1
  strip8() {  # the exact strip study-existing.sh stripped_target() / merge-decide split_anchors() do
    awk '
      /^<!-- project-specific:start -->[[:space:]]*$/ { skip=1; next }
      skip { if (/^<!-- project-specific:end -->[[:space:]]*$/) { skip=0; drop_blank=1 } next }
      drop_blank && /^[[:space:]]*$/ { drop_blank=0; next }
      { drop_blank=0; print }
    ' "$1"
  }
  rt_ok=0; rt_bad=0; rt_first=""
  for o in "$P8"/orig/*; do
    [ -f "$o" ] || continue
    ob="$(basename "$o")"; kind="${ob%%-*}"; bn="${ob#*-}"
    live="$P8/.claude/$kind/$bn"
    [ -f "$live" ] || continue
    grep -q '^<!-- project-specific:start -->' "$live" || continue   # not pack-derived here
    strip8 "$live" > "$P8/stripped.tmp"
    if cmp -s "$o" "$P8/stripped.tmp"; then rt_ok=$((rt_ok+1)); else
      rt_bad=$((rt_bad+1))
      [ -z "$rt_first" ] && rt_first="$bn: $(diff "$o" "$P8/stripped.tmp" | head -3 | tr '\n' ' ')"
    fi
  done
  if [ "$rt_ok" -eq 0 ] && [ "$rt_bad" -eq 0 ]; then
    bad "§8 at least one artifact was anchored" "apply-anchors.sh anchored none of the $n8 pack file(s) copied in"
  elif [ "$rt_bad" -eq 0 ]; then
    ok "§8 all $rt_ok anchored artifact(s) strip back to their pack source byte-for-byte"
  else
    bad "§8 all anchored artifacts strip back to their pack source byte-for-byte" \
        "$rt_bad of $((rt_ok+rt_bad)) differ — $rt_first"
  fi

  # THE CONSUMER, end to end. The round trip above is only interesting because a currency
  # metric depends on it. pack-coverage-scan.sh reports CURRENT/STALE from exactly that
  # comparison, and the number a reader acts on is this one — so assert on the number.
  if [ -f "$PACK_SCAN" ]; then
    cur8=$(bash "$PACK_SCAN" "$P8" --stdout 2>&1 >/dev/null | sed -n 's/^Pack currency: \([0-9][0-9]*\) current.*/\1/p' | head -1)
    if [ "${cur8:-0}" -ge 1 ] 2>/dev/null; then
      ok "§8 pack-coverage-scan.sh reports $cur8 CURRENT artifact(s) — the metric can move off zero"
    else
      bad "§8 pack-coverage-scan.sh reports a non-zero CURRENT count" \
          "reported '${cur8:-<none>}' — a fully current install still measures as zero current"
    fi
  fi
fi

# ── § 9  a legacy anchor gains the per-artifact line that makes it artifact-specific ─────
# ANCHORING COVERAGE READ 100% AND MEANT ALMOST NOTHING. Measured: capsolah-api 195 anchored
# artifacts / 20 distinct anchor bodies / largest identical group 110 (56%); tenant-portal
# 88 / 11 / 57 (65%). The target's own report said so — "a global constant wearing a citation
# costume" — while audit-setup.sh C2d printed "ok anchoring coverage 100%" in the same run.
# The cause was a MISSING MIGRATION: artifact_relevance_line already makes each INJECTED block
# specific, but a file anchored by an earlier release is "already anchored" and was skipped
# forever, keeping the old identical body. Same shape as the src/. citation defect, same fix.
say "§ 9  a legacy anchor with no per-artifact line is upgraded in place"
P9="$TD/legacy-anchor"
mkdir -p "$P9/.claude/agents" "$P9/src/components"
for i in 1 2 3; do printf 'export class Widget%s {}\n' "$i" > "$P9/src/components/W$i.ts"; done
printf '{"name":"legacy-anchor"}\n' > "$P9/package.json"
seed_setup "$P9" .claude .claude/agents src src/components
n9=0
while IFS= read -r src; do
  [ -f "$src" ] || continue
  bn="$(basename "$src")"
  [ -f "$P9/.claude/agents/$bn" ] && continue
  python3 - "$src" "$P9/.claude/agents/$bn" <<'PY9'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read().split("\n")
blk = ["<!-- project-specific:start -->",
       "## Project-specific (auto-generated)",
       "",
       "> - **Architecture** (`.claude/codebase-profile.md:3`): Feature modules.",
       "> Cite-able sources: `package.json`, top-level: `src/`, `src/components/`.",
       "",
       "<!-- project-specific:end -->",
       ""]
# an anchor written by an EARLIER release: no per-artifact line anywhere in it
at = 0
for i, l in enumerate(t):
    if l.startswith("## "):
        at = i
        break
open(dst, "w", encoding="utf-8").write("\n".join(t[:at] + blk + t[at:]))
PY9
  n9=$((n9+1)); [ "$n9" -ge 3 ] && break
done < <(find -L "$REPO_ROOT/templates/packs" -maxdepth 3 -path '*/agents/*.md' -type f 2>/dev/null | sort)
before9=$(for f in "$P9"/.claude/agents/*.md; do awk '/project-specific:start/,/project-specific:end/' "$f" | shasum | cut -c1-12; done | sort -u | grep -c .)
out9=$(bash "$ANCHORS" "$P9" --apply 2>&1)
after9=$(for f in "$P9"/.claude/agents/*.md; do awk '/project-specific:start/,/project-specific:end/' "$f" | shasum | cut -c1-12; done | sort -u | grep -c .)
if [ "$n9" -lt 2 ]; then
  bad "§9 enough pack agents to test with" "found $n9"
elif [ "$after9" -gt "$before9" ]; then
  ok "§9 identical legacy anchors became distinct ($before9 → $after9 distinct bodies over $n9 artifacts)"
else
  bad "§9 identical legacy anchors became distinct" "still $after9 distinct body/bodies over $n9 artifacts"
fi
if printf '%s' "$out9" | grep -qE '^Relevance lines retro-fitted:[[:space:]]*[1-9]'; then
  ok "§9 the run reports the retro-fit rather than counting them as 'already anchored'"
else
  bad "§9 the run reports the retro-fit" "$(printf '%s' "$out9" | grep -E 'Relevance|Already' | tr '\n' ' ')"
fi
# the pre-existing anchor content must survive untouched
if grep -q 'Architecture.*Feature modules' "$P9"/.claude/agents/*.md; then
  ok "§9 the existing anchor body survived the upgrade"
else
  bad "§9 the existing anchor body survived the upgrade" "the retro-fit rewrote the block"
fi
# and it must be idempotent — a second run adds nothing
out9b=$(bash "$ANCHORS" "$P9" --apply 2>&1)
dup9=$(grep -c 'Relevance UNCONFIRMED\|Where this applies here' "$P9"/.claude/agents/*.md | awk -F: '{s+=$2} END{print s+0}')
if printf '%s' "$out9b" | grep -qE '^Relevance lines retro-fitted:[[:space:]]*0' && [ "$dup9" -eq "$n9" ]; then
  ok "§9 re-running adds nothing (one relevance line per artifact)"
else
  bad "§9 re-running adds nothing" "$dup9 relevance line(s) across $n9 artifact(s)"
fi

# ── § 5  every cited directory must resolve on disk, in every fixture above ──────────────
say "§ 5  every emitted citation resolves on disk"
for pair in "$P1" "$P2" "$P3" "$P4" "$P6"; do
  for f in "$pair"/.claude/commands/*.md; do
    [ -f "$f" ] || continue
    v=$(cite_of "$f")
    case "$v" in *'<'*) continue ;; esac
    printf '%s' "$v" | tr ',[:space:]' '\n\n' | tr -d '`' | grep -v '^$' | while IFS= read -r d; do
      [ -d "$pair/${d%/}" ] || { printf '  FAIL §5 %s cites %s which does not exist\n' "${f#$TD/}" "$d"; exit 1; }
    done || bad "§5 $(basename "$pair") citations resolve"
  done
done
ok "§5 all citations resolve on disk"

say ""
say "anchor-citation fixtures: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
exit 0
