---
name: deps-audit
description: Run the ecosystem's dependency audit (npm / pip / cargo / composer / go) and triage the findings, separating blockers from noise. Run before every release, after a fresh install, when a new advisory lands, and weekly in CI. Scans the manifest and lockfile — `release-security` is what scans the built container image's OS layer.
---

# deps-audit

Run the package-manager audit and convert raw CVE noise into prioritized actions.

## Premise

Find real issues, no hand-waves. Every finding cites the advisory id (CVE / GHSA), the affected package + version range, the fixed version, and the consumer site (`<path:line>` for runtime deps; "transitive via `<parent>`" for indirect). Severity is the advisory's severity AND the surface analysis ("runtime path reachable from user input" vs "dev-only build script"); "high CVE" alone is not a verdict. Triage that says "upgrade everything" without surface analysis is noise.

## Halt conditions

- Halt on findings missing CVE/GHSA id or fixed-version field.
- Halt on severity escalation ("CRITICAL — fix today") without naming the reachable consumer path.
- Halt on `audit fix --force` recommendations that cross majors without a regression-test plan.
- **Halt on any advisory id you did not re-read** — package, class and fixed version come from the record, never from recall.

## Prerequisites

- The project's package-manager CLI; `jq`; internet access (audit DBs are remote).

## Procedure

1. Run the right tool for the stack:
   ```bash
   osv-scanner --format json --lockfile=<path> > /tmp/audit.json   # cross-ecosystem default
   npm audit --json --omit=dev > /tmp/audit.json   # npm 7+ → `.vulnerabilities` (NOT `.advisories`)
   pnpm audit --json > /tmp/audit.json             # pnpm → legacy `.advisories`
   pip-audit --format json --output /tmp/audit.json
   cargo audit --json > /tmp/audit.json
   composer audit --format=json > /tmp/audit.json
   govulncheck -json ./... > /tmp/audit.json
   bundler-audit check --update --format json > /tmp/audit.json
   ```
2. Parse the shape your tool emits:
   ```bash
   jq '.vulnerabilities | to_entries[] | {name:.key, sev:.value.severity, range:.value.range, fix:.value.fixAvailable}' /tmp/audit.json
   jq '.advisories | to_entries[] | {name:.value.module_name, sev:.value.severity, cve:.value.cves, fix:.value.patched_versions}' /tmp/audit.json
   ```
3. **Read it — see § Reading the output.** Skipping this produces a re-formatted dump, not an audit.
4. Classify: Critical/High + reachable runtime path → blocker; Medium runtime → this sprint; dev-only → backlog **except** build-time deps, which execute on CI with CI secrets; vulnerable function never called → risk-accepted, naming the import that would change that.
5. Confirm the path, then bump minimally: `pnpm why <pkg>` · `npm outdated <pkg>` · `pnpm up <pkg>@<fixed> && pnpm test`.

## Reading the output

The scanner answers "does an advisory match a version in my lockfile", not "am I exploitable".

- **Reachability is yours, with one exception.** npm/pip/composer/bundler audits match the manifest. **`govulncheck` does call-graph analysis** — "prioritizing vulnerabilities in functions that your code is actually calling" (<https://go.dev/blog/govulncheck>). Everywhere else, "reachable" is a claim you make with a `<path:line>`.
- **The class is part of the finding, and recall gets it wrong.** Copy package/class/fixed version from the record. **CVE-2021-23337** is lodash *command injection via `template`* (fixed 4.17.21), not prototype pollution. **CVE-2024-28849** is *follow-redirects* leaking `proxy-authorization` across a cross-domain redirect (fixed 1.15.6), not axios, not SSRF.
- **"Fix available" is not always a patch** — it may be a major bump, or only reachable through a transitive override (`pnpm.overrides` / `resolutions`).
- **Severity is the advisory's blast radius, not yours.** CVSS + **EPSS** + **CISA KEV**: a KEV-listed Medium outranks a theoretical Critical. Then adjust for reachability, and record which factor moved the row.

CI wiring: `npm audit`'s exit code is governed by `--audit-level` (<https://docs.npmjs.com/cli/v11/commands/npm-audit>). A job that never fails is usually a threshold, not a clean tree.

## Output

```
Dependency audit — 3 findings

CRITICAL:
  follow-redirects@1.15.5   CVE-2024-28849   proxy-authorization retained on cross-domain redirect
    Fixed:  1.15.6
    Used:   transitive via <http client dep> → runtime, reachable
    Surface: proxy configured + user-influenced target host — the credential leaves to a
             host we do not control.
    Action: pin the fixed version (transitive override if the parent lags); re-test outbound.

MEDIUM:
  lodash@4.17.20   CVE-2021-23337   command injection via the `template` function
    Fixed:  4.17.21
    Used:   transitive via <lint plugin>
    Surface: dev-only — `template` is not called on any runtime path.
    Action: upgrade with the next dep refresh.

LOW:
  semver@5.7.1   CVE-2022-25883   ReDoS in `new Range` on untrusted range strings
    Fixed:  5.7.2 / 6.3.1 / 7.5.2
    Used:   transitive (deep), build-time only
    Surface: no untrusted string reaches a range parse.
    Action: bundle with the next routine refresh.
```

A row missing its surface sentence is a scanner line, not a finding.

## False positives / gotchas

- Vulnerable but unreachable is real risk only if the import surface changes — flag with the import that would change it.
- `npm audit fix --force` crosses majors — read the changelog, run tests.
- Dedupe duplicate advisories by CVE id; keep the record you actually read.
- `--omit=dev` narrows the scan's scope, not the risk — build-time deps run on CI with CI credentials.
- Transitive overrides fix vulns without waiting on the parent — the only lever when the parent is abandoned.

## Related

`/dependency-vuln-check` (the periodic session that wraps this skill: licenses, maintainer health, supply-chain markers, persisted report) · `@security-auditor` (names this skill as its vulnerable-components executor) · `security-principles.md`.
