---
description: Audit dependencies for known CVEs + abandoned maintainers + license-incompatible licenses + suspicious version histories. Reports per-dep with severity + recommended action.
---

# /dependency-vuln-check

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every finding cites `<file:line>` and CVE ID.** A vuln without a manifest line + CVE identifier + fix-version is gossip. "lodash might be vulnerable" is not an audit; "`package.json:34` lodash@4.17.20 → CVE-2021-23337 (HIGH, prototype pollution) → upgrade ≥ 4.17.21" is an audit. License findings cite the SPDX expression and the file in `node_modules/<pkg>/LICENSE` (or equivalent). Maintainer findings cite the last-commit SHA / date from the upstream repo. Provenance is non-negotiable.

**The agent's job is exactly this:**
1. Run the ecosystem auditor (`npm audit --json`, `pip-audit`, `cargo audit`, `govulncheck`, etc.) and parse output structurally.
2. For each finding, cite: manifest `<file:line>`, package@version, CVE ID, severity from the source advisory, fix path.
3. Cross-reference with OSV / GHSA so the finding has at least two sources where possible.
4. Categorize: CVE / license / abandoned / supply-chain / drift. **No bucket without evidence.**

**The agent does NOT:**
- Report "lodash is old" without a CVE + version + fix.
- Use vague severity ("could be bad"); copy the CVSS / severity from the source DB exactly.
- Skip transitive deps because they're "indirect" — exploitable transitives are the supply-chain whole point.
- Whitelist a finding without an attached comment + revisit-by date.

**Closure verbs (mandatory per finding):**
- `block-merge` — CRITICAL / HIGH CVE on production dep; merge gate fails until fixed or threat-modeled.
- `fix-now` — patch available, low-risk upgrade; ship the bump.
- `fix-scheduled` — patch requires a major bump or refactor; ticketed with revisit-by date.
- `accept-with-justification` — no patch, exposure documented in `ai/audits/`, threat-model attached, revisit-by date set.
- `dismiss-false-positive` — confirmed false positive (e.g., test-only dep, vuln path unreachable); whitelist entry with reason.

**Mechanical halt (no hand-wave grep):**

Before writing the report, the agent MUST verify each finding by re-fetching its source advisory and matching:

```
finding.package == advisory.package
finding.version_range satisfies installed_version
finding.cve_id == advisory.id (or alias)
```

If any axis fails to verify, HALT and either re-source or drop the finding. **Phrases like "probably affected" or "may be vulnerable" are forbidden** — either the version range matches the advisory or the finding is false. No CVE-less rows in the CRITICAL / HIGH tables.

**Lightweight default:** for INFO / LOW findings without an exploitable path, close with `dismiss-false-positive` (with one-line justification) or batch into a single "below-threshold" line in the report — don't expand each into a row. The report is the action plan, not a vuln-DB dump.

Modern apps have hundreds to thousands of transitive dependencies. Each is a potential supply-chain attack surface. This command audits them systematically.

## Phases applied

1, 2, 3, 4, 6 (skips Update/Improve — read-only audit).

## When to use / NOT to use

- USE: weekly / pre-release / pre-deploy.
- USE: when dependabot / renovate flags multiple updates.
- USE: post-CVE-disclosure on a known package.
- USE: pre-acquisition due diligence.
- NOT: as a substitute for `npm audit` / `pip-audit` / `cargo audit` in CI — those run automatically; this command is the deeper periodic.

## Phase 1 — Understand

Confirm scope:
- Production deps only / dev deps only / both.
- Direct only / direct + transitive.
- Specific severity threshold (default: HIGH+).

## Phase 2 — Organize

Five concerns audited in parallel:

1. **Known CVEs** — `npm audit` / `pip-audit` / `cargo audit` / `bundler-audit` / `govulncheck` / Snyk / OSV. Triage by exploitability, not CVSS alone: cross-reference **EPSS** (probability of exploitation in the next 30 days) and the **CISA KEV** catalog (known-exploited-in-the-wild). A CVSS-7 that is on KEV or has high EPSS outranks a CVSS-9 with near-zero EPSS and no known exploit — escalate KEV/high-EPSS findings, de-prioritize the theoretical.
2. **License compatibility** — every dep's license vs project's chosen license. Surprising introductions of GPL / AGPL.
3. **Maintainer health** — last commit, open issue ratio, # of maintainers (bus factor).
4. **Version drift** — major versions behind; consequences of deferred updates.
5. **Supply-chain markers** — sudden ownership changes, recent typo-squatting reports, suspicious post-install scripts.

## Phase 3 — Retrieve

Tools:
- **OSV-Scanner** — the cross-ecosystem default (npm, PyPI, Go, Cargo, Maven, … from one lockfile-aware pass over OSV.dev); reach for it first, then fall back to the ecosystem-native auditor for richer fix paths.
- `npm audit --json` / `pnpm audit` / `yarn audit` — note: npm **7+** emits findings under `.vulnerabilities` (keyed by package), NOT the legacy `.advisories` map; parse the version-appropriate shape.
- `pip-audit` / `safety` (Python)
- `cargo audit` (Rust)
- `bundler-audit` (Ruby)
- `govulncheck` (Go)
- `composer audit` (PHP)
- `Snyk` / `OSS Index` / `OSV.dev`
- EPSS API (first.org) + CISA KEV catalog for exploitability-weighted triage.
- `npm-license-checker` / `pip-licenses` / `cargo-license`
- `socket.dev` for supply-chain anomaly markers
- GitHub Advisory Database

Read project's:
- Dep manifest + lock file.
- License file (the project's own license).
- `.snyk` / `.npmrc` exclusions if any.

## Phase 4 — Generate

```
## Dependency vuln audit — <date>

### Scope
Direct deps:    <N>
Transitive:     <M>
Total:          <N+M>

### CVE findings

**CRITICAL — fix immediately:**
| Package | Version | CVE | Severity | Fix | Used by |
|---|---|---|---|---|---|
| lodash | 4.17.20 | CVE-2021-23337 | High (RCE) | upgrade ≥ 4.17.21 | direct + 12 transitive |
| node-forge | 1.0.0 | CVE-2022-24771 | High (signature bypass) | upgrade ≥ 1.3.0 | indirect via @nestjs/jwt |

**HIGH:**
| Package | Version | CVE | Fix |
|---|---|---|---|
| ... | | | |

**MEDIUM (queue for next maintenance):**
| ... |

**INFO (no fix available):**
- 2 deps with disputed CVEs (likely false positives — verify with security@vendor).

### License findings

**INCOMPATIBLE:**
- `some-package@2.0.0` licensed AGPL-3.0; project is MIT. Strict copyleft incompatible.
  Fix: replace with permissively-licensed alternative; or change project license; or seek commercial license.

**ATTENTION:**
- `another-package@1.4.0` licensed BUSL-1.1 (Business Source License). Permitted today; converts to Apache 2.0 in 4 years; verify use case is acceptable.

### Maintainer health

**ABANDONED (last commit > 18 months):**
- `dead-package@1.0.0` — last commit 2023-03; 47 open issues; single maintainer hasn't responded since 2024.
  Risk: no security patches if a CVE drops. Replace with maintained alternative.

**LOW BUS FACTOR (single maintainer + actively used):**
- `important-package@2.5.0` — 1 maintainer; 4M weekly downloads. Critical CVE = no one to patch quickly.
  Mitigation: monitor; consider sponsorship or fork-readiness plan.

### Version drift

**MAJORS BEHIND:**
| Package | Current | Latest | Majors behind | Risk |
|---|---|---|---|---|
| react | 17.0.2 | 19.x | 2 | Migration cost rising; security patches eventually stop |
| express | 4.18.2 | 5.x | 1 | Express 5 has breaking changes; deferred is fine until Q3 |

### Supply-chain markers

**SUSPICIOUS:**
- `random-utility@4.2.0` — Released 3 days ago. Maintainer changed last week. New email domain. Pinned in lock file; was previously `@4.1.5`.
  Action: investigate why it was upgraded; review changes; consider downgrading until trusted.

- `legit-looking-name@1.0.1` — Typo-squat candidate; the legit package is `legit-looking-named` (note `-d`). Verify intent.

### Aggregate metrics
- Total deps:                <N>
- With known CVEs:          <count> (<%>)
- Behind by ≥ 1 major:      <count> (<%>)
- Maintainer-abandoned:     <count>
- License-incompatible:     <count>

### Action plan

| Priority | Action | Effort |
|---|---|---|
| P0 | Upgrade lodash + node-forge (CRITICAL CVEs) | 30 min |
| P0 | Replace AGPL package | 4-8 hours |
| P1 | Replace abandoned `dead-package` | 1-2 days |
| P2 | Schedule React 17 → 19 migration sprint | sprint-sized |
| P2 | Investigate suspicious `random-utility` upgrade | 1 hour |

### Blockers documented (no fix today)

- 2 deps with unresolvable CVEs (no patch available); file-paths isolated by feature flag; threat-modeled in `ai/audits/threat-model-X.md`.
```

## Phase 6 — Validate

After remediation:
- Re-run audit; CVE count drops.
- Re-run unit + integration + e2e tests; no regressions from version bumps.
- Lock file updates committed.
- CI dependency-audit step now passes (or whitelist updated for accepted-risk items with justification).

## Output format

```
## /dependency-vuln-check complete

Scope: <direct/transitive/both> | <prod/dev/both>
CVEs found: <C critical / H high / M med>
License issues: <count>
Abandoned deps: <count>
Major-version drift: <count>

Report: ai/audits/dep-vuln-<date>.md
Action plan: <P0 count / P1 count / P2 count>
```

## Hard rules

- **A critical CVE blocks merge.** No exceptions. If the fix is impossible today, threat-model the exposure and document acceptance.
- **License compatibility audited at first import.** Policy: only OSI-approved permissive (MIT, BSD, Apache 2.0). Anything else needs ADR.
- **Lock file always committed.** No floating versions.
- **Whitelisting requires justification.** Every entry in `.snyk` / `npm audit --audit-level` exclusions has a comment with reason + revisit-by date.

## Failure modes

- Upgraded transitive but didn't update lock file → next install reverts to vulnerable version.
- Whitelisted CVE without revisit date → forgotten.
- Replaced abandoned dep with another abandoned dep — verify maintainer health before swap.
- License audit at first import works; license CHANGE on existing dep (publisher relicenses) is missed unless re-audited.
- Updated dep introduced a behavior change masquerading as security fix — re-test.

## Related

- `@security-auditor` — runs broader audit; this is one dimension.
- `@dependency-auditor` (code-quality pack) — overlap on freshness; this is security-focused.
- `secret-scan` — different concern; pair them in security workflows.
- `.claude/rules/security-principles.md` — the vulnerable-components + dependency-audit rules this command enforces.
