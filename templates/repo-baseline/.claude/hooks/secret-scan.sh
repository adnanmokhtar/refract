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
echo "$payload" | grep -Eq 'sk-ant-[A-Za-z0-9_-]{20,}'                  && block "an Anthropic API key (sk-ant-…)"
echo "$payload" | grep -Eq '\bsk-[A-Za-z0-9]{32,}\b'                     && block "an OpenAI-style API key (sk-…)"
echo "$payload" | grep -Eq '\bAKIA[0-9A-Z]{16}\b'                        && block "an AWS access key id (AKIA…)"
echo "$payload" | grep -Eq '\bASIA[0-9A-Z]{16}\b'                        && block "an AWS temporary access key (ASIA…)"
echo "$payload" | grep -Eq '\bAIza[0-9A-Za-z_-]{35}\b'                   && block "a Google API key (AIza…)"
echo "$payload" | grep -Eq '\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b' && block "a GitHub token (gh*_…)"
echo "$payload" | grep -Eq '\bgithub_pat_[A-Za-z0-9_]{60,}\b'           && block "a GitHub fine-grained PAT"
echo "$payload" | grep -Eq '\bxox[baprs]-[A-Za-z0-9-]{10,}\b'           && block "a Slack token (xox*-…)"
echo "$payload" | grep -Eq 'AC[0-9a-fA-F]{32}'                          && block "a Twilio account SID"
echo "$payload" | grep -Eq -- '-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----'  && block "a private key block"
echo "$payload" | grep -Eq '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' && block "a JWT (eyJ…)"

exit 0
