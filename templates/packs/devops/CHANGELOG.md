# devops pack — changelog

Release history for `templates/packs/devops/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.5.0 — 2026-07-10

- deploy-stage Safe-Delivery Gate: five evidence-bearing dims (S1 rollback resolved+exercised · S2
  health/readiness · S3 resource limits · S4 no plaintext secrets · S5 reproducible), unmet →
  INCOMPLETE.
- deployment-engineer: matching S1-S5 verdict with copy-pasteable grep detectors.

## 1.4.0 — 2026-07-10

- skills +2: progressive-delivery (feature-flag lifecycle + automated canary-analysis gate) and
  gitops-audit (git->cluster reconciliation discipline, drift, no out-of-band kubectl, no plaintext
  secrets).

## 1.3.0 — 2026-07-09

- NEW skills/release-security.md (kind:skill, dockerfile_detected) — image CVE scan (trivy image
  --severity HIGH,CRITICAL --ignore-unfixed) + SBOM (syft CycloneDX) + digest signing (cosign,
  keyless via CI OIDC) + SLSA provenance + verify-at-admission; EPSS/KEV triage; full runner spine
  (Premise/Prerequisites/Procedure/Output/gotchas/When-to-run/Halt). Explicitly disjoint from
  deps-audit (manifest layer) and dockerfile-lint (Dockerfile). Registered in _topics + _essentials;
  abridged _examples/release-security.md.
- Wired release-security into commands/dockerize.md (post-build release dispatch) +
  commands/add-ci.md (docker-build release-security step: trivy scan + syft SBOM + cosign keyless
  sign + provenance). Closes the enforcement-theater the security-auditor A03 check opened — the
  audit now dispatches to a real producer.

## 1.2.0 — 2026-06-22

- Sync-chain repair: _topics.md now declares deploy-stage and rollback-deploy as commands
  (kind:command, deploy_target_detected trigger). Both shipped under commands/ but were absent from
  the topic list, so /setup-project AUTHOR-mode generation silently dropped them. No _examples/
  stubs exist, so the fallbacks point at the live sources (commands/deploy-stage.md,
  commands/rollback-deploy.md).
- Version record now reflects the long-tail audit fixes already landed in pack content (add-ci
  security + coverage job, app-code stub scan) that had not been version-stamped.
