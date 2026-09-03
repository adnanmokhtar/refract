#!/usr/bin/env bash
# PreToolUse hook for Bash — blocks destructive shell commands.
# Exit 2 = block (Claude sees the stderr reason). Exit 0 = allow.
#
# Detects patterns even inside chained commands (&&, ;, |). Prefers jq for
# robust command extraction, falls back to sed so the hook still works on a
# machine without jq installed.
#
# Configurable via env:
#   CLAUDE_PROTECTED_BRANCHES  comma list (default: main,master + git default)
# Opt out per project: create .claude/.no-guard-destructive

set -uo pipefail

[ -f ".claude/.no-guard-destructive" ] && exit 0

payload=$(cat)
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
else
  cmd=$(printf '%s' "$payload" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi
[ -z "$cmd" ] && exit 0

block() {
  echo "Blocked by guard-destructive: $1" >&2
  echo "If you really need this, run it yourself in your own terminal." >&2
  exit 2
}

has()  { printf '%s' "$cmd" | grep -qE  "$1"; }
hasi() { printf '%s' "$cmd" | grep -qiE "$1"; }

# ── Protected branch list ────────────────────────────────────────────────
DEFAULT_BRANCHES="main,master"
if GIT_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null) && [ -n "$GIT_DEFAULT" ]; then
  DEFAULT_BRANCHES="$DEFAULT_BRANCHES,$GIT_DEFAULT"
fi
PROTECTED_BRANCHES="${CLAUDE_PROTECTED_BRANCHES:-$DEFAULT_BRANCHES}"
BR_REGEX=$(printf '%s' "$PROTECTED_BRANCHES" | tr ',' '\n' | awk 'NF{printf "%s%s",sep,$0; sep="|"}')

# ── Git push protections ────────────────────────────────────────────────
if has '(^|[;&|()]+[[:space:]]*)git[[:space:]]+push'; then
  # Explicit push to a protected branch (origin main, HEAD:main, :main, …)
  if has "git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]*:)?($BR_REGEX)(\$|[[:space:]])" \
     || has "git[[:space:]]+push.*:($BR_REGEX)(\$|[[:space:]])"; then
    block "push to a protected branch ($PROTECTED_BRANCHES) — use a feature branch + PR"
  fi
  # Bare `git push` while checked out on a protected branch
  if has 'git[[:space:]]+push[[:space:]]*($|[;&|])'; then
    CURRENT=$(git branch --show-current 2>/dev/null || true)
    if [ -n "$CURRENT" ] && printf '%s' ",$PROTECTED_BRANCHES," | grep -q ",$CURRENT,"; then
      block "you are on protected branch '$CURRENT' — switch to a feature branch"
    fi
  fi
  # Force push — but ALLOW --force-with-lease (the safe form).
  if has 'git[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]=]|$)' \
     && ! has '\-\-force-with-lease'; then
    block "force push — use --force-with-lease if you must overwrite remote"
  fi
fi

# ── Destructive filesystem operations ───────────────────────────────────
# Normalise quotes so "$HOME/x", '/', etc. are all inspected.
cmd_nq=$(printf '%s' "$cmd" | tr -d "'\"")
# Recursive AND force, in any order, in one token or spread across several. The previous pattern
# required `r` before `f` inside a single flag group, so `rm -fr /`, `rm -f -r /` and `rm -r -f /`
# all walked straight through the guard. Collect every flag token first, then ask the two
# questions separately.
# Walk the tokens instead of pattern-matching the whole invocation. The first attempt used a sed
# expression with \b — a GNU extension BSD sed does not support, so on macOS it matched nothing
# and every rm walked through, which is worse than the bug it replaced. Field-splitting behaves
# identically on both awks.
rm_target=$(printf '%s\n' "$cmd_nq" | awk '{
  for (i = 1; i <= NF; i++) {
    if ($i == "rm") {
      flags = ""; j = i + 1
      while (j <= NF && substr($j, 1, 1) == "-") { flags = flags substr($j, 2); j++ }
      if (j <= NF && flags ~ /r/ && flags ~ /f/) { print $j; exit }
    }
  }
}')
if [ -n "$rm_target" ] \
   && printf '%s' "$rm_target" | grep -qE '^(/(\*)?$|~|\$HOME|\$[A-Za-z_][A-Za-z0-9_]*|\.\./\.\.)'; then
  block "recursive force-delete on /, ~, \$HOME, an unresolved \$VAR, or ../.. — specify a concrete safe path"
fi
if printf '%s' "$cmd_nq" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-?[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+/(usr|etc|var|bin|sbin|lib|opt|root|boot)([[:space:]/]|$)'; then
  block "recursive delete targeting a system directory"
fi

# ── Dangerous database operations ───────────────────────────────────────
if hasi 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)[[:space:]]+'; then
  block "DROP TABLE/DATABASE/SCHEMA — run manually if intended"
fi
# DELETE FROM without a WHERE on the SAME statement (split on ';').
# `BEGIN{IGNORECASE=1}` is a GAWK extension. macOS ships BWK awk, which ignores it silently — so
# on the platform this repo targets first, `DELETE FROM users where id=1` was BLOCKED (the lower-
# case `where` never matched) while `delete from users` was ALLOWED. Wrong in both directions at
# once. Fold the case in the shell, where the behaviour is the same everywhere.
if printf '%s\n' "$cmd" | tr 'a-z' 'A-Z' | awk 'BEGIN{RS=";"} /DELETE[[:space:]]+FROM[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*/{if($0!~/WHERE/){print "BAD";exit}}' | grep -q BAD; then
  block "DELETE FROM without a WHERE clause — add a WHERE or run manually"
fi
hasi 'TRUNCATE[[:space:]]+TABLE' && block "TRUNCATE TABLE — run manually if intended"

# ── Dangerous system commands ───────────────────────────────────────────
if has 'chmod([[:space:]]+-[a-zA-Z]+)*[[:space:]]+0?777([[:space:]]|$)' \
   || has 'chmod([[:space:]]+-[a-zA-Z]+)*[[:space:]]+a\+rwx([[:space:]]|$)'; then
  block "chmod 777 / a+rwx grants everyone full access — use restrictive perms"
fi
has '(curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|ksh|fish|dash|csh)([[:space:]]|$)' \
  && block "piping downloaded content straight to a shell is dangerous"
# Redirect into a raw device (but 2>/dev/null and /dev/null etc. are fine).
# The safe-list used to be grepped against the WHOLE command, so any harmless `2>/dev/null`
# anywhere in the line vouched for a `> /dev/disk2` elsewhere in it. Ask the question per
# redirect: is there a data-carrying redirect whose target is NOT one of the safe devices?
if printf '%s' "$cmd" | grep -oE '(^|[^0-9&])>[[:space:]]*/dev/[a-zA-Z][a-zA-Z0-9]*' \
   | grep -qvE '/dev/(null|stdout|stderr|tty|zero|random|urandom)$'; then
  block "redirection into a raw device file can destroy data"
fi
if has '(^|[;&|[:space:]])(mkfs|mkfs\.[a-z0-9]+)([[:space:]]|$)' \
   || has '(^|[;&|[:space:]])dd[[:space:]]+[^|]*(if|of)=/dev/[a-zA-Z]'; then
  block "mkfs/dd against a device node — irreversible data loss"
fi

# ── Destructive git ─────────────────────────────────────────────────────
has 'git[[:space:]]+reset[[:space:]]+--hard'  && block "git reset --hard discards uncommitted changes permanently"
has 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f' && block "git clean -f permanently deletes untracked files"
has 'git[[:space:]]+branch[[:space:]]+-D'     && block "force branch delete — run manually if intended"

# ── Fork bomb ───────────────────────────────────────────────────────────
printf '%s' "$cmd" | grep -qF ':(){ :|:& };:' && block "fork bomb"

# ── Accidental package publishing (allow --dry-run) ─────────────────────
for pat in '(npm|yarn|pnpm|bun)[[:space:]]+publish' 'cargo[[:space:]]+publish' 'gem[[:space:]]+push' 'twine[[:space:]]+upload'; do
  if has "$pat" && ! has '(^|[[:space:]])(--dry-run|-n)([[:space:]=]|$)'; then
    block "publishing packages should run in CI or manually, not via the agent"
  fi
done

exit 0
