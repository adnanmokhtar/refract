---
name: deps-audit
description: Run the ecosystem's dep audit (npm / pip / cargo / composer / go) and triage findings. Flag blockers vs noise.
---

# deps-audit

Run the package-manager audit and convert raw CVE noise into prioritized actions.

## When to use

- Before every release.
- After a fresh `npm install` / `pip install` / equivalent.
- When a new advisory hits a dep you use (GitHub Dependabot, Snyk alert).
- Weekly in CI to track drift.

## Prerequisites

- Project's package-manager CLI (`pnpm`, `npm`, `yarn`, `pip`, `cargo`, `composer`, `go`, `bundle`).
- `jq` for JSON parsing.
- Internet access — audit DBs are remote.

## Procedure

1. Run the right tool for the stack:
   ```bash
   # Node
   pnpm audit --json > /tmp/audit.json
   npm audit --json --omit=dev > /tmp/audit.json   # prod-only
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
2. Parse + triage:
   ```bash
   jq '.advisories | to_entries[] | {name:.value.module_name, sev:.value.severity, cve:.value.cves, vuln:.value.vulnerable_versions, fix:.value.patched_versions}' /tmp/audit.json
   ```
3. For each finding, classify:
   - **Critical/High on runtime dep** → blocker, fix today.
   - **Medium on runtime dep** → fix this sprint.
   - **Any severity on dev-only dep** → backlog, lower priority.
   - **Transitive dep where the vulnerable code path is unreachable from your code** → note as risk-accepted.
4. Confirm the upgrade path won't break:
   ```bash
   pnpm why <package>          # transitive ancestry
   npm outdated <package>      # current vs wanted vs latest
   ```
5. Apply minimal upgrade (avoid `audit fix --force` blindly — it bumps majors):
   ```bash
   pnpm up axios@^1.7.4
   pnpm test
   ```

## Output

```
Dependency audit — 3 findings

CRITICAL:
  axios@0.21.4   CVE-2024-28849   SSRF
    Fixed:  1.7.4
    Used:   src/modules/http/client.ts (runtime)
    Surface: outbound HTTP with user-supplied URLs — exploitable.
    Action: upgrade today, regression-test outbound paths.

MEDIUM:
  lodash@4.17.20   CVE-2021-23337   prototype pollution
    Fixed:  4.17.21
    Used:   transitive via eslint-plugin-import
    Surface: dev-only.
    Action: upgrade when convenient (pnpm dedupe + bump).

LOW:
  semver@5.7.1   CVE-2022-25883   ReDoS
    Fixed:  5.7.2 / 6.3.1 / 7.5.2
    Used:   transitive (deep)
    Surface: build-time only.
    Action: bundle this with the next routine dep refresh.
```

## False positives / gotchas

- Vulnerable but unreachable: a CVE in a sub-feature you don't import is real risk only if the import surface changes — flag, don't panic.
- `npm audit fix --force` upgrades across majors — read the changelog, run tests, never apply blindly.
- Yarn's audit DB lags npm's by days — prefer `npm audit` against the same lockfile.
- Some advisories are duplicates from different sources (GHSA + npm + Snyk) — dedupe by CVE ID.
- Pinned transitive overrides (`pnpm.overrides`, `resolutions`) can fix vulns without waiting on the parent dep — preferred when a parent is slow to release.
