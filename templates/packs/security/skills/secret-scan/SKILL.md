---
name: secret-scan
description: Scan the repo including git history for leaked secrets — API keys, tokens, private keys, credentials. Run before any first push to a public remote, immediately after a committed-`.env` event, in CI on every PR, and as a quarterly full-history sweep. This skill is the detection primitive; `/secret-scan` is the remediation session that owns rotation playbooks, the history scrub and the persisted report.
allowed-tools: [Read, Grep, Glob, Bash]
---

# secret-scan

Detect committed secrets in working tree, staged changes, and recent git history.

## Premise

Find real leaks, no hand-waves. Every finding cites the commit SHA + `<path:line>`, the matched rule (gitleaks rule id / trufflehog detector name), and a redacted excerpt of the match. The provider is identified by prefix when possible (`sk_live_`, `AKIA`, `ghp_`, `-----BEGIN ... PRIVATE KEY-----`). High-entropy hits are flagged separately from prefix-matched hits — entropy alone is suspicion, prefix is confirmation. Allow-listed test fixtures are documented in `.gitleaksignore`, not silently dropped. "Looks like a secret" without rule + redacted match is not a finding.

## Halt conditions

- Halt on any finding without `<commit>:<path:line>` + rule id + redacted excerpt.
- Halt on rotation/purge instructions that skip the rotate-first step (deleting the commit does not invalidate the credential).
- Halt on entropy-only findings that don't separate "high entropy near `token`/`secret`/`password` identifier" from "long config string".
- **Halt on a report written un-redacted.** A findings file that contains the live secret is a second copy of the leak, and CI keeps artifacts.

## Prerequisites

- One of: `gitleaks` (preferred), `trufflehog`, `detect-secrets` (`brew install gitleaks` / `pip install detect-secrets`).
- Optional: a committed `.gitleaksignore` allow-list for known false positives.

## Procedure

`detect` and `protect` were **deprecated in gitleaks v8.19.0** — still functional, hidden from `--help`. The current verbs are `git`, `dir` and `stdin`; use them, because copied-forward `detect`/`protect` lines are the first thing that breaks on a major bump.

1. Scan the working tree — fastest, catches what is on disk right now:
   ```bash
   gitleaks dir . --redact -v --report-format json --report-path /tmp/leaks-tree.json
   ```
2. Scan staged changes as a pre-commit gate:
   ```bash
   gitleaks git --staged --redact -v --report-format json --report-path /tmp/leaks-staged.json
   ```
3. Scan history — the scan that matters, because a reverted commit is still a leak:
   ```bash
   gitleaks git . --log-opts="--since=90.days.ago" --redact -v \
     --report-format json --report-path /tmp/leaks-history.json
   # first audit on any repo: run it with no --log-opts (whole history, slow)
   ```
4. Cross-check entropy on suspect files with a second engine:
   ```bash
   trufflehog filesystem --directory=. --only-verified --json | jq '.'
   ```
5. For each finding: identify the provider from the prefix (§ What to look for), find the introducing commit (`git log --all --source -- <file>`), and treat the credential as live until the provider says otherwise.

## Reading the output

**The exit code is not the answer.** `gitleaks` exits `0` for no leaks, `1` for **"leaks or errors encountered"**, and `126` for an unknown flag — so a `1` in CI may be a finding or a broken invocation, and only the report file distinguishes them. Wire CI on the report's contents, and treat an empty report plus a non-zero exit as a failed run, not a clean one.

Each JSON finding carries `RuleID`, `Description`, `File`, `StartLine`, `Commit`, `Author`, `Email`, `Date`, `Match`, `Secret`, `Entropy`, `Tags`. Read them in this order, because the first two decide everything downstream:

1. **`RuleID` → confirmation or suspicion.** A provider rule (`stripe-access-token`, `aws-access-key-id`, …) is a *format match*: the string is shaped like a real credential. A generic/entropy rule is *suspicion only*. Never escalate an entropy hit to CRITICAL without classifying it first.
2. **`Commit` → is it only in history?** Empty commit = working tree only, and the secret has not shipped anywhere yet — fix it before it does. A populated commit means it is in every clone, every fork, and the platform's event API. **That is still a leak.** Reachability from HEAD is irrelevant.
3. **`Author` / `Date` → who to tell and what window to audit.** These are the inputs to the provider-side log review ("was this key used between `Date` and now?"), which is the step that turns a leak into an incident or closes it.
4. **`Match` / `Secret` → only ever read redacted.** With `--redact` these are masked; without it, your report *is* the secret. This is why step 1-3 above all pass `--redact`.

**What to do, per class — in this order, always:**

| Finding class | First action | Then |
|---|---|---|
| Provider-prefix match, live credential | **Rotate at the provider.** Nothing else first. | Verify the old value is rejected, review the provider's access log for the leak window, then scrub history |
| Provider-prefix match, already-rotated key | Confirm rejection with a real call | Scrub or accept-with-note; record why it is inert |
| Entropy-only, near a `token`/`secret`/`password` identifier | Classify it — ask the author what it is | Rotate if real; `.gitleaksignore` with a reason if not |
| Entropy-only, a long config value / hash / generated fixture | Nothing | `.gitleaksignore` entry **with a reason comment** |
| Private key block | Rotate the key pair and remove the public half from every `authorized_keys` | Scrub, then re-issue |

**Rotation precedes removal, always.** Scrubbing history without rotating produces a repo that looks clean and a credential that still works — the worst of both states, because the evidence is gone and the exposure is not. `/secret-scan` owns the per-provider rotation playbook and the scrub procedure; hand off there once this skill has classified.

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
    rule:stripe-live-secret  match:sk_live_redacted   author:<who>  date:<when>
    Action: rotate at the provider FIRST, then review their API log for the window, then purge.

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

- Test fixtures intentionally use fake-looking keys (`sk_test_...`, `dummy-token-1234`) — allow-list them in `.gitleaksignore`, **with a reason**; an unexplained allow-list entry is how a real leak gets muted.
- Generated JWTs in tests look like real tokens; the body is base64 — entropy scanners flag them.
- Long config values (a 200-char URL, a lockfile integrity hash) trip entropy detection — review context.
- `git filter-repo` rewrites history — every collaborator must re-clone or hard-reset to the new history.
- "Just deleting the commit" does NOT remove the secret — it stays in the reflog, the platform's event API, forks, and others' clones until rotated. Rotation is non-negotiable.
- A secret that reached a **published build artifact** (image layer, source map, bundled config) is not fixed by scrubbing the repo — the artifact needs its own recall.

## Related

- `/secret-scan` — the remediation session: per-provider rotation playbook, four-axis classification halt, history-scrub procedure, persisted `ai/audits/` report. This skill finds and classifies; that command closes.
- `@security-auditor` — names this skill as its secrets sweep; that agent treats a `GO` emitted without it as a halt.
- `rules/security-principles.md` — the secret-management + never-log-secrets MUSTs.
