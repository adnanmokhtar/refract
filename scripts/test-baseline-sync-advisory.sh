#!/usr/bin/env bash
# test-baseline-sync-advisory.sh — apply-baseline-sync must SAY what it is withholding.
#
# WHY THIS EXISTS. KEEP-OURS is the correct decision for a file a human edited: overwriting it
# would destroy their work. But the decision was reported and then dropped, so a project whose
# guard had been edited stopped receiving every later fix to that guard and the run still printed
# a clean summary and exited 0.
#
# MEASURED on three real installed projects before the advisory existed: 4 / 1 / 0 executable
# guards sat in exactly that state. One was a security guard.
#
# What is asserted here is the DIFFERENCE between "kept, and you were told" and "kept, silently".
# Overwriting is NOT asserted — keeping the user's file is the behaviour we want to preserve.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE="$REPO_ROOT/templates/repo-baseline"

pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---- case A: a guard the user edited -> KEEP-OURS *and named in the advisory* -------------------
A="$TMP/edited"; mkdir -p "$A/.claude/hooks"
printf '#!/usr/bin/env bash\n# my own version\nexit 0\n' > "$A/.claude/hooks/session-start.sh"
out="$(bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$A" 2>&1)" || true

echo "$out" | grep -q "KEEP-OURS .claude/hooks/session-start.sh" \
  && ok "user-edited guard is kept, not overwritten" \
  || bad "user-edited guard was not reported KEEP-OURS"

echo "$out" | grep -q "withheld from" \
  && ok "the run announces that something is being withheld" \
  || bad "SILENT KEEP-OURS: no advisory printed for an edited guard"

echo "$out" | sed -n '/withheld from/,$p' | grep -q "session-start.sh" \
  && ok "the advisory names the specific guard" \
  || bad "advisory printed but does not name the guard"

grep -q "my own version" "$A/.claude/hooks/session-start.sh" \
  && ok "the user's content is still on disk (dry run wrote nothing)" \
  || bad "the user's file was modified"

# ---- case B: no edited guards -> no advisory, and no empty-array crash under set -u -------------
B="$TMP/clean"; mkdir -p "$B/.claude/hooks"
cp "$BASELINE/.claude/hooks/session-start.sh" "$B/.claude/hooks/session-start.sh"
rc=0; out2="$(bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$B" 2>&1)" || rc=$?

[ "$rc" -eq 0 ] && ok "clean target exits 0" || bad "clean target exited $rc"
echo "$out2" | grep -qiE "unbound variable|bad substitution" \
  && bad "empty-array path errored (bash 3.2 set -u trap)" \
  || ok "empty advisory list does not trip set -u"
echo "$out2" | grep -q "withheld from" \
  && bad "advisory printed when nothing was withheld" \
  || ok "no advisory when nothing is withheld"

# ---- case C: a hook DELIVERED but not registered -> reported as inert ---------------------------
# A hook that no settings file names never runs. settings.json is nearly always KEEP-OURS, so a
# hook this script ADDs lands on disk and stays dead while the ADD row reads like a success.
# MEASURED: 7 and 11 such hooks on two installed projects, including secret-scan and pre-edit-guard.
C="$TMP/unwired"; mkdir -p "$C/.claude/hooks"
cp "$BASELINE/.claude/hooks/secret-scan.sh" "$C/.claude/hooks/secret-scan.sh"
printf '{"permissions":{}}\n' > "$C/.claude/settings.json"
out3="$(bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$C" 2>&1)" || true

echo "$out3" | grep -q "NOT WIRED" \
  && ok "a delivered-but-unregistered hook is reported" \
  || bad "SILENT: hook on disk, absent from settings.json, not reported"

echo "$out3" | sed -n '/NOT WIRED/,$p' | grep -q "secret-scan.sh" \
  && ok "the unwired report names the hook" \
  || bad "unwired report does not name the hook"

# ---- case D: wired in settings.local.json -> NOT reported (precision) ---------------------------
# A user may register hooks in local settings. Reading only settings.json would call a live hook
# dead — a false alarm on a healthy project, which is worse than saying nothing.
D="$TMP/localwired"; mkdir -p "$D/.claude/hooks"
cp "$BASELINE/.claude/hooks/secret-scan.sh" "$D/.claude/hooks/secret-scan.sh"
printf '{"permissions":{}}\n' > "$D/.claude/settings.json"
printf '{"hooks":{"PreToolUse":[{"hooks":[{"command":".claude/hooks/secret-scan.sh"}]}]}}\n' > "$D/.claude/settings.local.json"
out4="$(bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$D" 2>&1)" || true

echo "$out4" | sed -n '/NOT WIRED/,$p' | grep -q "secret-scan.sh" \
  && bad "false alarm: hook wired in settings.local.json reported as inert" \
  || ok "a hook wired in local settings is not called dead"

# ---- case E: --wire-hooks registers what is missing, and touches nothing else -------------------
# The file being edited holds the user's permissions and their own hook entries. Adding to it must
# not reformat their entries, duplicate a hook they wired their own way, or drop a key.
E="$TMP/wire"; mkdir -p "$E/.claude/hooks"
cp "$BASELINE"/.claude/hooks/*.sh "$E/.claude/hooks/" 2>/dev/null || true
cat > "$E/.claude/settings.json" <<'JSON'
{
  "permissions": { "allow": ["Bash(ls:*)"] },
  "hooks": {
    "PostToolUse": [
      { "matcher": "Edit", "hooks": [ { "type": "command", "command": "bash .claude/hooks/post-edit-check.sh" } ] }
    ]
  }
}
JSON
before="$(cat "$E/.claude/settings.json")"
bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$E" >/dev/null 2>&1 || true
[ "$before" = "$(cat "$E/.claude/settings.json")" ] \
  && ok "without --wire-hooks, settings.json is not touched" \
  || bad "settings.json changed without --wire-hooks"

bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$E" --apply --wire-hooks >/dev/null 2>&1 || true
python3 - "$E/.claude/settings.json" <<'PYCHK'
import json, re, sys
d = json.load(open(sys.argv[1]))
names = []
for ev, gs in (d.get("hooks") or {}).items():
    for g in gs:
        for e in g.get("hooks") or []:
            names += re.findall(r"hooks/([a-z0-9-]+\.sh)", e.get("command", ""))
checks = {
    "permissions survived": d.get("permissions", {}).get("allow") == ["Bash(ls:*)"],
    "no duplicate hook": len(names) == len(set(names)),
    "user's own command form kept": any(
        e.get("command") == "bash .claude/hooks/post-edit-check.sh"
        for gs in d["hooks"].values() for g in gs for e in (g.get("hooks") or [])),
    "missing hooks added": "secret-scan.sh" in names,
}
for k, v in checks.items():
    print(("ok   " if v else "FAIL ") + k)
sys.exit(0 if all(checks.values()) else 1)
PYCHK
if [ $? -eq 0 ]; then pass=$((pass+4)); else fail=$((fail+1)); fi

# ---- case F: an advisory rules-import code is not a failed run ----------------------------------
# wire-rule-imports.sh exit 3 is documented as advisory: foundational rules wired, pack rules left
# out because importing them would cost ~45k tokens every turn. Treating it as a failure marked a
# healthy sync INCOMPLETE and returned 1. MEASURED on a real monorepo with 20 rules on disk.
F="$TMP/advisory"; mkdir -p "$F/.claude/rules"
cp "$BASELINE"/.claude/rules/*.md "$F/.claude/rules/" 2>/dev/null || true
# The baseline ships ~6k tokens of rules — under the 12k budget, so copying it alone never reaches
# the over-budget branch and this case silently asserted nothing. Pad past the budget on purpose.
i=0
while [ $i -lt 8 ]; do
  {
    printf '# Padding rule %s\n\n' "$i"
    j=0; while [ $j -lt 200 ]; do
      printf 'This line exists to push the always-tier rule set past the import budget.\n'
      j=$((j+1))
    done
  } > "$F/.claude/rules/zz-padding-$i.md"
  i=$((i+1))
done
printf '# Project\n' > "$F/CLAUDE.md"
rcF=0; outF="$(bash "$REPO_ROOT/scripts/apply-baseline-sync.sh" "$F" 2>&1)" || rcF=$?
[ "$rcF" -eq 0 ] && ok "an over-budget rule set is not a failed run" \
                 || bad "advisory rules-import code escalated to exit $rcF"
echo "$outF" | grep -q "INCOMPLETE" \
  && bad "healthy sync reported INCOMPLETE over an advisory code" \
  || ok "no INCOMPLETE banner on an advisory code"

# ---- case G: the reported exit code is the REAL one ---------------------------------------------
# `$?` inside `if ! cmd; then` is the result of the negated test — always 0 — so the WARN line
# printed "exit 0" for every refusal and every crash alike: a diagnostic that says the run
# succeeded inside the sentence explaining that it failed.
grep -q 'wire_rc=\$?' "$REPO_ROOT/scripts/apply-baseline-sync.sh" \
  && ok "wire-rule-imports status is captured before it is tested" \
  || bad "exit status read after the test — it can only ever report 0"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
