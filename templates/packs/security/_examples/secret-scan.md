---
name: secret-scan
description: Scan the repo (including git history) for leaked secrets — API keys, tokens, private keys, credentials. This skill is the detection primitive; `/secret-scan` is the remediation session.
---

# secret-scan

Detect committed secrets in working tree, staged changes, and recent git history.

## Premise

Find real leaks, no hand-waves. Every finding cites the commit SHA + `<path:line>`, the matched rule (gitleaks rule id / trufflehog detector name), and a redacted excerpt of the match. The provider is identified by prefix when possible (`sk_live_`, `AKIA`, `ghp_`, `-----BEGIN ... PRIVATE KEY-----`). High-entropy hits are flagged separately from prefix-matched hits — entropy alone is suspicion, prefix is confirmation. Allow-listed test fixtures are documented in `.gitleaksignore`, not silently dropped. "Looks like a secret" without rule + redacted match is not a finding.

## Halt conditions

- Halt on any finding without `<commit>:<path:line>` + rule id + redacted excerpt.
- Halt on rotation/purge instructions that skip the rotate-first step (deleting the commit does not invalidate the credential).
- Halt on entropy-only findings that don't separate "high entropy near `token`/`secret`/`password` identifier" from "long config string".
- **Halt on a report written un-redacted** — a findings file holding the live secret is a second copy of the leak, and CI keeps artifacts.

## Prerequisites

- `gitleaks` (preferred), `trufflehog`, or `detect-secrets`. Optional committed `.gitleaksignore`.

## Procedure

`detect` and `protect` were **deprecated in gitleaks v8.19.0** (still functional, hidden from `--help`). Current verbs: `git`, `dir`, `stdin`.

```bash
# working tree
gitleaks dir . --redact -v --report-format json --report-path /tmp/leaks-tree.json
# staged (pre-commit gate)
gitleaks git --staged --redact -v --report-format json --report-path /tmp/leaks-staged.json
# history — the scan that matters; drop --log-opts for the first full audit
gitleaks git . --log-opts="--since=90.days.ago" --redact -v \
  --report-format json --report-path /tmp/leaks-history.json
# second engine on suspect files
trufflehog filesystem --directory=. --only-verified --json | jq '.'
```

Then per finding: identify the provider from the prefix, find the introducing commit (`git log --all --source -- <file>`), and treat the credential as live until the provider says otherwise.

## Reading the output

**The exit code is not the answer.** `0` = no leaks, `1` = **leaks *or* errors**, `126` = unknown flag. Gate CI on the report's contents; an empty report with a non-zero exit is a failed run, not a clean one.

Findings carry `RuleID`, `Description`, `File`, `StartLine`, `Commit`, `Author`, `Email`, `Date`, `Match`, `Secret`, `Entropy`, `Tags`. Read in this order:

1. **`RuleID`** — a provider rule is a *format match* (confirmation); a generic/entropy rule is suspicion only. Never escalate an entropy hit without classifying it.
2. **`Commit`** — empty means working tree only (not shipped yet). Populated means it is in every clone, fork, and the platform's event API. Reachability from HEAD is irrelevant; it is still a leak.
3. **`Author` / `Date`** — the inputs to the provider-side log review for the exposure window.
4. **`Match` / `Secret`** — read redacted only; without `--redact` the report *is* the secret.

**What to do, per class:**

| Finding class | First action | Then |
|---|---|---|
| Provider-prefix match, live credential | **Rotate at the provider.** Nothing else first. | Verify rejection, review the access log for the window, then scrub |
| Provider-prefix match, already rotated | Confirm rejection with a real call | Scrub or accept-with-note; record why it is inert |
| Entropy-only near a `token`/`secret`/`password` identifier | Classify with the author | Rotate if real; `.gitleaksignore` with a reason if not |
| Entropy-only, long config value / hash / fixture | Nothing | `.gitleaksignore` entry **with a reason** |
| Private key block | Rotate the pair; remove the public half everywhere | Scrub, then re-issue |

**Rotation precedes removal, always** — scrubbing first leaves a clean-looking repo and a working credential.

## What to look for

Anthropic/OpenAI/Gemini `sk-ant-`, `sk-`, `AIza` · Stripe `sk_live_`, `pk_live_`, `whsec_` · AWS `AKIA[0-9A-Z]{16}` · GitHub `ghp_`, `github_pat_`, `gho_`/`ghs_`/`ghu_` · Slack `xox[baprs]-` · HuggingFace `hf_` · SendGrid `SG.` · Twilio `AC[0-9a-f]{32}` · npm `npm_` · GCP service-account JSON (`"type":"service_account"`) · `-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----` · DB URLs with passwords · JWT signing secrets and high-entropy strings near `token`/`secret`/`password`.

## Output

```
Secret scan — last 90 days

BLOCKERS (2):
  commit abc1234   src/config/stripe.ts:8
    rule:stripe-live-secret  match:sk_live_redacted   author:<who>  date:<when>
    Action: rotate at the provider FIRST, then review their API log, then purge.

  commit def5678   .env.staging:12
    rule:postgres-url-with-password  match:postgres://app:redacted@host
    Action: rotate the DB user credential, redeploy, then purge.

WARNINGS (1):
  src/seed.ts:42  (working tree only — no commit)
    rule:high-entropy-string  match:9f3a7b...redacted (40 chars)
    Unclassified — confirm with the author before escalating or allow-listing.

Next: hand BLOCKERS to `/secret-scan` for the rotation playbook + history scrub.
```

## False positives / gotchas

- Fixtures use fake-looking keys — allow-list them **with a reason**; an unexplained entry is how a real leak gets muted.
- Test JWTs and long config values (URLs, integrity hashes) trip entropy detection.
- `git filter-repo` rewrites history — collaborators must re-clone or hard-reset.
- Deleting the commit does not unleak: reflog, event API, forks and clones keep it until rotation.
- A secret that reached a published build artifact (image layer, source map, bundle) needs its own recall — scrubbing the repo does not fix it.

## Related

`/secret-scan` (rotation playbook, scrub procedure, persisted report — this skill finds and classifies, that command closes) · `@security-auditor` (names this skill as its secrets sweep) · `security-principles.md`.
