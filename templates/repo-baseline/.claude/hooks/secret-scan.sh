#!/usr/bin/env bash
# PreToolUse hook (Edit|Write|MultiEdit) — blocks writes that introduce secrets.
# Stack-agnostic: scans the tool payload for high-confidence credential formats.
# Exit 2 = block (the write is prevented and Claude is told why).
# Deliberately conservative: only well-known key SHAPES, to keep false positives near zero.
#
# Opt out per project: create .claude/.no-secret-scan

set -uo pipefail

[ -f ".claude/.no-secret-scan" ] && exit 0

# The raw payload contains the new file content (new_string / content field),
# so grepping the payload string catches secrets regardless of JSON nesting.
payload=$(cat)

# ...but it ALSO contains `old_string`, which is the text being REMOVED. Scanning that blocked the
# one edit this hook should welcome: replacing a hardcoded `AKIA…` with `process.env.AWS_KEY`
# carries the key in old_string, so the remediation was refused while the file that already
# contained it sat there untouched. Scan only what is being WRITTEN.
scan=$(printf '%s' "$payload" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null || true)
if [ -z "$scan" ]; then
  # No jq, or a payload shape jq did not match. Strip the old_string spans textually rather than
  # falling back to the whole payload — failing closed on a removal is the bug, not the guard.
  # sed -E: `\|` alternation is a GNU extension BSD sed ignores, which would leave old_string in
  # the scanned text on macOS — the very false block this fallback exists to prevent.
  scan=$(printf '%s' "$payload" | sed -E 's/"old_string"[[:space:]]*:[[:space:]]*"(\\.|[^"\\])*"/"old_string":""/g')
fi
# NOTE: `payload` is deliberately left intact — the skip-list below extracts `file_path` from it,
# and overwriting it here made every path-based exemption (*.md, *.example, tests/) invisible.
# Only the credential greps switch to `$scan`.

# Skip if the edit targets a file we expect to hold example/placeholder values.
file_path=$(echo "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
case "$file_path" in
  *.example|*.sample|*.dist|*.md|*.lock|*/test/*|*/tests/*|*/__tests__/*|*.test.*|*.spec.*) exit 0 ;;
esac

block() {
  echo "Blocked by secret-scan: detected $1." >&2
  echo "Move the secret to an environment variable / secrets manager and reference it indirectly." >&2
  echo "If this is a placeholder or false positive, name the file *.example or create .claude/.no-secret-scan." >&2
  exit 2
}

# High-confidence credential shapes (each is specific enough to rarely false-positive).
echo "$scan" | grep -Eq 'sk-ant-[A-Za-z0-9_-]{20,}'                  && block "an Anthropic API key (sk-ant-…)"
echo "$scan" | grep -Eq '\bsk-[A-Za-z0-9]{32,}\b'                     && block "an OpenAI-style API key (sk-…)"
echo "$scan" | grep -Eq '\bAKIA[0-9A-Z]{16}\b'                        && block "an AWS access key id (AKIA…)"
echo "$scan" | grep -Eq '\bASIA[0-9A-Z]{16}\b'                        && block "an AWS temporary access key (ASIA…)"
echo "$scan" | grep -Eq '\bAIza[0-9A-Za-z_-]{35}\b'                   && block "a Google API key (AIza…)"
echo "$scan" | grep -Eq '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b' && block "a GitHub token (gh*_…)"
echo "$scan" | grep -Eq '\bgithub_pat_[A-Za-z0-9_]{60,}\b'           && block "a GitHub fine-grained PAT"
echo "$scan" | grep -Eq '\bxox[baprs]-[A-Za-z0-9-]{10,}\b'           && block "a Slack token (xox*-…)"
echo "$scan" | grep -Eq 'AC[0-9a-fA-F]{32}'                          && block "a Twilio account SID"
echo "$scan" | grep -Eq -- '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----'  && block "a private key block"
echo "$scan" | grep -Eq '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' && block "a JWT (eyJ…)"
echo "$scan" | grep -Eq '(mongodb|postgres|postgresql|mysql|redis|amqp|smtp)(\+[a-z]+)?://[^:@[:space:]/]+:[^@[:space:]/]+@' && block "a connection string with embedded credentials (user:pass@host)"

exit 0
