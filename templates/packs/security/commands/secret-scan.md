---
description: Scan repo + commit history for leaked secrets. Reports findings + remediation steps + the rotation playbook for each leak class.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /secret-scan

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every finding cites `<file:line>` and secret-type.** A leak report without a path + line + pattern-class + first-introduced commit is unactionable. "There may be a key somewhere in config/" is not a finding; "`src/config/aws.config.ts:12` AWS access key (matches `AKIA[0-9A-Z]{16}`), introduced commit `a3f4d21` 2025-09-14, action: rotate IAM key + filter-repo + audit CloudTrail" is a finding. **Every CRITICAL row carries a rotation playbook; no rotation playbook = not a CRITICAL row.**

**The agent's job is exactly this:**
1. Run scanners (`gitleaks`, `trufflehog`, `detect-secrets`) over the chosen scope (working tree / HEAD / full history / paths).
2. For each hit, cite: `<file:line>`, secret-type (AWS / Stripe / GitHub / JWT / RSA / DB / OAuth / SSH), first-introduced commit + author + date, current reachability (in HEAD? scrubbed? rebased away?).
3. Distinguish real secrets from fixtures by inspecting the surrounding context (test paths, deliberate-fake markers, `.example` extensions).
4. Emit the rotation playbook entry matching the secret-type — pick from the table, do not improvise.

**The agent does NOT:**
- Report a high-entropy string without classifying it (entropy alone is not a secret type).
- Whitelist a hit without a one-line justification in `.gitleaksignore`.
- Skip git-history scan on first audit. Working-tree-only scans miss the leak that already shipped.
- Recommend "remove from repo" without "rotate the credential" — removal does not unleak.

**Closure verbs (mandatory per finding):**
- `rotate-now` — confirmed real secret in working tree or recent history; rotation playbook attached + history-scrub plan if reachable in past commits.
- `rotate-and-scrub` — secret reachable via git history beyond HEAD; rotation + filter-repo + team-coordination steps.
- `whitelist-with-reason` — confirmed fixture / dummy / public test-key; entry in `.gitleaksignore` with comment.
- `flag-ambiguous` — high-entropy hit, type unclear; surfaced for human review with surrounding context excerpted, no auto-rotation.

**Mechanical halt (no hand-wave grep):**

Before writing the report, the agent MUST verify each finding has all four axes filled:

```
finding.path        != null
finding.line        != null
finding.secret_type IN  {AWS, Stripe, GitHub, JWT, RSA, DB, OAuth, SSH, encryption-key, generic-high-entropy}
finding.rotation    IN  rotation-playbook-table  (or 'flag-ambiguous')
```

If any axis is unfilled, HALT and re-classify. **A hit without a secret-type is not a CRITICAL** — demote to `flag-ambiguous` and surface the context for review. No "looks suspicious" rows in the CRITICAL table.

**Lightweight default:** for whitelisted hits and confirmed fixtures, batch into a single "Whitelisted" line — don't expand each fixture-key into its own row. The report's job is to enumerate **secrets to rotate**, not to re-list every test artifact.

Find leaked secrets BEFORE they're discovered by attackers. Run periodically AND on every PR. A secret in git history is a secret leaked even if reverted — it must be rotated, not just removed.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit).

## When to use / NOT to use

- USE: pre-merge gate on PRs touching code or config.
- USE: periodic full-history scan (monthly).
- USE: post-incident when a secret leak is suspected.
- NOT: routine code review — that's the code-reviewer agent's job.

## Phase 1 — Understand

Decide scope:
- **Working tree only** — current state of files. Fast (~seconds).
- **HEAD commit only** — what's about to be merged. Pre-commit / pre-merge hook.
- **Full history** — every commit ever. Slow (minutes for large repos) but mandatory at first audit.
- **Specific paths** — focused on `.env*` / `config/` / `terraform/` etc.

## Phase 2 — Organize

Three scanners run in parallel:

1. **Pattern-based** — known secret formats (AWS keys, Stripe tokens, GitHub tokens, JWT bearers, RSA private keys, etc.).
2. **Entropy-based** — high-entropy strings that look like random secrets even if format unknown.
3. **Filename-based** — files that shouldn't exist in repo (`.env`, `*.pem`, `*.p12`, `id_rsa`, etc.).

## Phase 3 — Retrieve

**Run the `secret-scan` skill for detection.** It owns the scanner invocations (including the post-v8.19.0 `gitleaks git` / `dir` / `stdin` verbs that replaced the deprecated `detect`/`protect`), the provider-prefix table, and § Reading the output — the exit-code trap, the finding fields, and the confirmation-vs-suspicion split. This command does not restate any of it. It starts from the skill's classified findings and adds what the skill cannot: rotation, scrub, coordination, and the report of record.

Engines the skill drives: **gitleaks** (pattern + entropy, configurable), **trufflehog** (deeper entropy heuristics, verified-only mode), **detect-secrets** (baseline file for whitelisting), plus **GitHub Advanced Security** where the repo has it.

Read the project's `.gitleaksignore` / `.trufflehogignore` — and read the *reasons*: an allow-list entry with no justification is an unaudited finding, not a resolved one.

## Phase 4 — Generate (the report)

```
## Secret scan — <date>

### Scope
- Working tree:    scanned
- Last 100 commits: scanned
- Full history:    <yes/no — flag if "no" on first audit>

### Findings

**CRITICAL — rotate immediately:**
- `src/config/aws.config.ts:12` — AWS access key (AKIA...) exposed.
  Pattern: `AKIA[0-9A-Z]{16}`
  First introduced: commit a3f4d21 by alice@team on 2025-09-14
  Action: rotate the key in AWS IAM, then `git filter-repo` to scrub history (force-push required), notify team.

- `infra/terraform.tfvars:8` — Stripe live secret (`sk_live_...`).
  First introduced: commit 7b8e92c on 2025-12-03
  Action: rotate in Stripe dashboard, scrub history, audit logs for unauthorized API calls in window.

**HIGH — investigate:**
- `tests/fixtures/test-config.json:18` — high-entropy string starting with `eyJh...` (likely JWT).
  May be intentional test fixture; verify it's not a real token.

**Whitelisted (in `.gitleaksignore`):**
- `tests/fixtures/dummy-keys.json` — test data, deliberately fake.

### Rotation playbook (per leak class)

| Leak class | Rotation steps |
|---|---|
| AWS key | IAM → delete key → audit CloudTrail for unauthorized calls |
| Stripe secret | Stripe Dashboard → Roll API key → review API logs |
| GitHub token | GitHub Settings → Personal access tokens → revoke; check audit log |
| Database password | Rotate in DB; update app secrets manager; restart pods |
| JWT signing secret | Rotate; **invalidate all existing tokens** (forced re-login); deploy |
| OAuth client secret | Rotate in identity provider; re-deploy with new secret |
| Encryption key | Rotate; re-encrypt at-rest data with new key (often gradual) |
| SSH key | Remove from authorized_keys; deploy new key |

### History scrub procedure

If a secret was in git history (not just current state):

1. `git log --all --full-history --source -- <path-to-file>` — confirm reach.
2. Use `git filter-repo` (preferred) or `git filter-branch` to remove the file/string.
3. Force-push to all branches (coordinate with team — destructive operation).
4. Have all collaborators re-clone (no merge — re-clone).
5. Rotate the secret regardless. The old version is in attackers' Wayback / GitHub Archive caches.

### Recommended prevention (not installed/verified by this command)

- `.gitignore` — confirm `.env*`, `*.pem`, `*.p12`, `*.key`, `secrets/`, `.aws/` are ignored.
- Pre-commit hook running gitleaks (in `.githooks/` or `.husky/`).
- CI step blocking merge on any HIGH+CRITICAL finding (e.g., a gitleaks CI job).
- Secrets manager (AWS Secrets Manager / HashiCorp Vault / Doppler / 1Password CLI) for runtime secrets — NOT in env files committed to repo.

### Verified (observable from the scan itself)
- `.gitignore` covers expected secret paths.
- Allowlist entries in `.gitleaksignore` each carry a justification comment.
```

## Phase 6 — Validate

After remediation:
- Re-run scan to verify no findings.
- Verify rotated secrets are deployed (apps using new values).
- Verify revoked secrets are actually revoked (in IAM / OAuth / etc.).
- Verify audit logs show no anomalous use during the leak window.

## Output format

```
## /secret-scan complete

Scope: <working tree | last N commits | full history>
Findings: <C critical / H high / M medium / W whitelisted>
Critical rotations required: <list with rotation status>

Report: ai/audits/secret-scan-<date>.md
```

## Hard rules

- **A leaked secret must be rotated, even if reverted.** Removed from git ≠ unleaked. The Wayback Machine / GitHub Archive / cached forks have it.
- **No false-positive whitelisting without justification.** Every entry in `.gitleaksignore` must have a comment explaining why it's safe.
- **History scrub requires team coordination.** Don't force-push without notice.
- **Rotated secrets logged in incident-tracker.** Even minor rotations — audit trail.

## Failure modes

- Scanned working tree only → missed leak in older commit. Always scan full history at least once.
- Whitelisted a "false positive" that was actually real — read whitelist entries carefully.
- Rotated secret but old code still references env var with old name → service breaks.
- Force-pushed to scrub history but didn't notify team → merge conflicts.
- Scrubbed git history but forgot the deployment artifacts had been published with the secret embedded.

## Related

- `secret-scan` **skill** — the detection primitive this command orchestrates: scanner invocation, the provider-prefix table, finding-field triage. Deliberate split, near-zero overlap — the skill answers *what leaked and is it real*, this command answers *how it gets closed*. Run the skill for a scan; run this when something has to be rotated.
- `@security-auditor` — runs the broader audit; this command is one dimension of it.
- `@auth-reviewer` — overlap on credential handling (a leaked signing secret is also a session-integrity finding).
- `.claude/rules/security-principles.md` — the secret-management + never-log-secrets rules this command enforces.
