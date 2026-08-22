---
name: deps-audit
description: Run the ecosystem's dependency audit (npm / pip / cargo / composer / go) and triage the findings, separating blockers from noise. Run before every release, after a fresh install, when a new advisory lands, and weekly in CI. Scans the manifest and lockfile — `release-security` is what scans the built container image's OS layer.
---

# deps-audit

Run the package-manager audit and convert raw CVE noise into prioritized actions.

## Premise

Find real issues, no hand-waves. Every finding cites the advisory id (CVE / GHSA), the affected package + version range, the fixed version, and the consumer site (`<path:line>` for runtime deps; "transitive via `<parent>`" for indirect). Severity is the advisory's severity AND the surface analysis ("runtime path reachable from user input" vs "dev-only build script"); "high CVE" alone is not a verdict. Risk-accepted findings name the unreachable code path and what would change that. Triage that says "upgrade everything" without surface analysis is noise.

## Halt conditions

- Halt on findings missing CVE/GHSA id or fixed-version field.
- Halt on severity escalation ("CRITICAL — fix today") without naming the reachable consumer path (`<path:line>` or "transitive via X, unreachable").
- Halt on `audit fix --force` recommendations that cross majors without a regression-test plan.
- **Halt on any advisory id you did not re-read.** Package, class and fixed version all come from the advisory record, never from recall — see § Reading the output, "the class is part of the finding".

## Prerequisites

- Project's package-manager CLI (`pnpm`, `npm`, `yarn`, `pip`, `cargo`, `composer`, `go`, `bundle`).
- `jq` for JSON parsing.
- Internet access — audit DBs are remote.

## Procedure

1. Run the right tool for the stack:
   ```bash
   # Cross-ecosystem default (preferred — one scanner, all lockfiles, OSV DB):
   osv-scanner --format json --lockfile=<path> > /tmp/audit.json   # or: osv-scanner -r .
   # Node — NOTE the schema differs by tool/version:
   npm audit --json --omit=dev > /tmp/audit.json     # npm 7+ → top-level `.vulnerabilities` (NOT `.advisories`)
   pnpm audit --json > /tmp/audit.json               # pnpm → legacy `.advisories`
   # Python
   pip-audit --format json --output /tmp/audit.json
   # Rust
   cargo audit --json > /tmp/audit.json
   # PHP
   composer audit --format=json > /tmp/audit.json
   # Go
   govulncheck -json ./... > /tmp/audit.json
   # Ruby
   bundler-audit check --update --format json > /tmp/audit.json
   ```
2. Parse (schema-aware — pick the shape your tool emits):
   ```bash
   # npm 7+  (top-level .vulnerabilities, keyed by package):
   jq '.vulnerabilities | to_entries[] | {name:.key, sev:.value.severity, via:.value.via, range:.value.range, fix:.value.fixAvailable}' /tmp/audit.json
   # pnpm / npm 6  (.advisories):
   jq '.advisories | to_entries[] | {name:.value.module_name, sev:.value.severity, cve:.value.cves, vuln:.value.vulnerable_versions, fix:.value.patched_versions}' /tmp/audit.json
   # osv-scanner  (.results[].packages[].vulnerabilities[]):
   jq '.results[].packages[] | {name:.package.name, vulns:[.vulnerabilities[].id]}' /tmp/audit.json
   ```
3. **Read it — see § Reading the output.** This is the step that turns a scanner dump into an audit; skipping it produces a re-formatted dump.
4. Classify each finding:
   - **Critical/High on a runtime dep with a reachable path** → blocker, fix today.
   - **Medium on runtime dep** → fix this sprint.
   - **Any severity on dev-only dep** → backlog. Exception: a build-time dep executes on your CI runner with your CI secrets — a post-install-script or build-tool RCE is *not* dev-only risk.
   - **Transitive dep where the vulnerable function is never called from your code** → risk-accepted, and name the import that would change that.
5. Confirm the upgrade path won't break, then apply the minimal bump:
   ```bash
   pnpm why <package>          # transitive ancestry — who forces the old version
   npm outdated <package>      # current vs wanted vs latest
   pnpm up <package>@<fixed-version> && pnpm test
   ```

## Reading the output

The scanner answers "does a published advisory match a version in my lockfile". It does not answer "am I exploitable". Four things it will not tell you, in the order they cause wrong verdicts:

- **Reachability is yours, with one exception.** `npm audit`, `pip-audit`, `composer audit` and `bundler-audit` match the manifest — they flag a package, not a call. **`govulncheck` is the exception**: it does call-graph analysis, "prioritizing vulnerabilities in functions that your code is actually calling" (<https://go.dev/blog/govulncheck>). So on Go a clean report means more than it does anywhere else, and everywhere else "reachable" is a claim you make with a `<path:line>`, not one the tool made for you.
- **The class is part of the finding, and recall gets it wrong.** Open the advisory record and copy the package, the class and the fixed version from it. Two ids that live next to each other in every triage list: **CVE-2021-23337** is lodash *command injection via the `template` function* (fixed 4.17.21) — not prototype pollution, which is a different pair of ids; **CVE-2024-28849** is *follow-redirects* leaking the `proxy-authorization` header across a cross-domain redirect (fixed 1.15.6) — not axios, not SSRF. A report that mislabels the class sends the reader to audit the wrong code path, which is worse than no report.
- **"Fix available" is not always a patch.** The fix field may point at a major bump. Check whether the fixed version satisfies your declared range before you promise a one-line upgrade, and whether the version is reachable at all — a transitive pin (`pnpm.overrides` / `resolutions`) may be the only path when the parent has not released.
- **Severity is the advisory's blast radius, not yours.** Prioritize by CVSS **+ EPSS** (probability of exploitation in the next 30 days) **+ CISA KEV** (known-exploited-in-the-wild): a KEV-listed or high-EPSS Medium outranks a theoretical Critical. Then adjust down for an unreachable path — and record which of the two moved the row.

CI wiring: `npm audit`'s exit code is governed by `--audit-level` ("the minimum level of vulnerability for `npm audit` to exit with a non-zero exit code" — <https://docs.npmjs.com/cli/v11/commands/npm-audit>). A job that never fails is usually a threshold, not a clean tree.

## Output

```
Dependency audit — 3 findings

CRITICAL:
  follow-redirects@1.15.5   CVE-2024-28849   proxy-authorization header retained on cross-domain redirect (credential leak)
    Fixed:  1.15.6
    Used:   transitive via <http client dep> → runtime, reachable
    Surface: outbound requests configured with a proxy + user-influenced target host — the
             credential leaves to a host we do not control.
    Action: pin the fixed version (transitive override if the parent lags); re-run outbound tests.

MEDIUM:
  lodash@4.17.20   CVE-2021-23337   command injection via the `template` function
    Fixed:  4.17.21
    Used:   transitive via <lint plugin>
    Surface: dev-only — `template` is not called on any runtime path (no import found).
    Action: upgrade with the next dep refresh; re-check if `template` ever enters runtime code.

LOW:
  semver@5.7.1   CVE-2022-25883   ReDoS in `new Range` on untrusted range strings
    Fixed:  5.7.2 / 6.3.1 / 7.5.2
    Used:   transitive (deep), build-time only
    Surface: no untrusted string reaches a range parse.
    Action: bundle with the next routine dep refresh.
```

Every row is (advisory id → class copied from the record → fixed version → consumer path → surface sentence → action). A row missing the surface sentence is a scanner line, not a finding.

## False positives / gotchas

- Vulnerable but unreachable: a CVE in a sub-feature you don't import is real risk only if the import surface changes — flag with the import that would change it, don't panic.
- `npm audit fix --force` upgrades across majors — read the changelog, run tests, never apply blindly.
- Some advisories are duplicates from different sources (GHSA + npm + Snyk) — dedupe by CVE id, and keep the record you actually read.
- `--omit=dev` narrows the *scope of the scan*, not the risk: it hides build-time deps that run on CI with CI credentials.
- Pinned transitive overrides (`pnpm.overrides`, `resolutions`) can fix vulns without waiting on the parent dep — preferred when a parent is slow to release, and the only lever when it is abandoned.

## Related

- `/dependency-vuln-check` — the periodic session that wraps this skill: license compatibility, maintainer health, supply-chain markers, and the persisted report. This skill is its CVE dimension; run the skill for a scan, the command for an audit of record.
- `@security-auditor` — names this skill as its vulnerable-components executor; an A0x supply-chain finding without a resolved advisory id from here is not shippable.
- `rules/security-principles.md` — the vulnerable-components MUSTs this skill enforces.
