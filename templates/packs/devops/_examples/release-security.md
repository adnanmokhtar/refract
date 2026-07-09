---
name: release-security
kind: example
pack: devops
---

# Skill: release-security

A built image is a supply-chain artifact. The build→registry gate: scan CVEs, generate SBOM, sign the digest, attest provenance, verify at deploy. The executor the security pack's OWASP A03 check dispatches to. Every finding cites the image + CVE id (or missing gate) + fix. Covers the image OS/baked-lib layer (what deps-audit's manifest scan misses) and the signature/SBOM (what dockerfile-lint's Dockerfile check misses).

## Procedure

1. `trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <image>@<digest>` (or grype) — triage by CVSS + EPSS + KEV.
2. `syft <image>@<digest> -o cyclonedx-json > sbom.cdx.json` + `cosign attach sbom`.
3. `cosign sign --yes <image>@<digest>` — sign the DIGEST, keyless via CI OIDC (not a stored key).
4. `cosign attest --type slsaprovenance` (or actions/attest-build-provenance).
5. Verify at deploy: `cosign verify` + a K8s admission policy (Kyverno/Sigstore — infra pack) so unsigned/CVE-failing images can't admit.

## Gotchas

Sign the digest not the mutable tag; keyless > stored keys; unfixed base CVEs → slimmer base, not suppress; signing without verify-at-admission is theater; don't re-report app-lockfile CVEs (that's deps-audit).

## Halt conditions

No CVE finding without the cited id + fix; never sign an image that failed the CVE gate; no PASS on an unfixed CRITICAL without explicit EPSS/KEV-informed risk-acceptance; "signed/verified" only if cosign verify actually ran.

## Related

dockerize / add-ci (wire the gate), dockerfile-lint (Dockerfile half), @ci-reviewer, security-auditor A03 (dispatches here), deps-audit (manifest counterpart), infrastructure pack (admission policy).
