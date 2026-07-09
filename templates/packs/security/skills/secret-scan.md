---
name: secret-scan
description: Scan the repo (including git history) for leaked secrets — API keys, tokens, private keys, credentials. Catches commits that shouldn't exist.
---

# secret-scan

Detect committed secrets in working tree, staged changes, and recent git history.

## Premise

Find real leaks, no hand-waves. Every finding cites the commit SHA + `<path:line>`, the matched rule (gitleaks rule id / trufflehog detector name), and a redacted excerpt of the match. The provider is identified by prefix when possible (`sk_live_`, `AKIA`, `ghp_`, `-----BEGIN ... PRIVATE KEY-----`). High-entropy hits are flagged separately from prefix-matched hits — entropy alone is suspicion, prefix is confirmation. Allow-listed test fixtures are documented in `.gitleaksignore`, not silently dropped. "Looks like a secret" without rule + redacted match is not a finding.

## Halt conditions

- Halt on any finding without `<commit>:<path:line>` + rule id + redacted excerpt.
- Halt on rotation/purge instructions that skip the rotate-first step (deleting the commit does not invalidate the credential).
- Halt on entropy-only findings that don't separate "high entropy near `token`/`secret`/`password` identifier" from "long config string".

## When to run

- Before any first push to a public remote.
- After a "whoops, committed `.env`" event — even if force-pushed, pull request cloners may still have it.
- In CI on every PR.
- Quarterly full-history sweep.

## Prerequisites

- One of: `gitleaks` (preferred), `trufflehog`, `detect-secrets`. Install:
  ```bash
  brew install gitleaks
  # or
  pip install detect-secrets
  ```
- Optional: a committed `.gitleaksignore` allow-list for known false positives.

## Procedure

1. Scan the working tree first (fastest):
   ```bash
   gitleaks detect --source . --no-git --redact -v
   ```
2. Scan staged changes (use as a pre-commit gate):
   ```bash
   gitleaks protect --staged --redact -v
   ```
3. Scan recent history (last 90 days; full sweep is slow):
   ```bash
   gitleaks detect --source . --log-opts="--since=90.days.ago" --redact -v
   ```
4. Cross-check with `trufflehog` for entropy detection on suspect files:
   ```bash
   trufflehog filesystem --directory=. --only-verified --json | jq '.'
   ```
5. For each finding:
   - Identify provider from prefix (`sk-ant-`, `sk_live_`, `AKIA`, `AIza`, `ghp_`, etc.).
   - Check `git log --all --source -- <file>` to find the introducing commit.
   - Determine if the secret is still active (test via the provider's API or assume yes).

## What to look for

- Anthropic / OpenAI / Gemini: `sk-ant-`, `sk-`, `AIza`
- Stripe: `sk_live_`, `pk_live_`, `whsec_`
- AWS: `AKIA[0-9A-Z]{16}`, `aws_secret_access_key`
- GitHub: `ghp_` (classic PAT), `github_pat_` (fine-grained PAT), `gho_` / `ghs_` / `ghu_` (OAuth/app tokens)
- Slack: `xox[baprs]-` (bot / app / refresh / user / legacy tokens)
- HuggingFace: `hf_`
- SendGrid: `SG.`
- Twilio: `AC[0-9a-f]{32}` (account SID), `SK…` (API key SID)
- npm: `npm_` (automation / publish token)
- GCP service-account JSON (`"type":"service_account"`)
- Private keys: `-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----`
- DB URLs with passwords: `postgres://user:pass@host`, `mysql://...`, `mongodb+srv://...`
- JWT signing secrets, generic high-entropy strings near identifiers like `token`, `secret`, `password`

## Output

```
Secret scan — last 90 days

BLOCKERS (2):
  commit abc1234   src/config/stripe.ts:8
    rule:stripe-live-secret  match:sk_live_redacted
    Action: rotate at Stripe dashboard, then purge.

  commit def5678   .env.staging:12
    rule:postgres-url-with-password  match:postgres://app:redacted@host
    Action: rotate DB user creds, then purge.

WARNINGS (1):
  src/seed.ts:42
    rule:high-entropy-string  match:9f3a7b...redacted (40 chars)
    Possibly a real secret — confirm with author.

Next steps:
  1. Rotate every flagged credential at the provider FIRST.
  2. Purge from history:
       git filter-repo --invert-paths --path .env.staging --force
     OR (older repos): use BFG. Re-test with `gitleaks` after.
  3. Force-push (one of the rare authorized cases — coordinate with team).
  4. Notify everyone with a clone — they must re-clone.
```

## False positives / gotchas

- Test fixtures intentionally use fake-looking keys (`sk_test_...`, `dummy-token-1234`) — allow-list them in `.gitleaksignore`.
- Generated JWTs in tests look like real tokens; the body is base64 — entropy scanners may flag.
- Long config values (e.g., a 200-char URL) trip high-entropy detection — review context, don't auto-flag.
- `git filter-repo` rewrites history — every collaborator must re-clone or `git fetch && git reset --hard` to the new history.
- "Just deleting the commit" does NOT remove the secret — it stays in reflog, GitHub event API, and others' clones until rotated. Rotation is non-negotiable.
