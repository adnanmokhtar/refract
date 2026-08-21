---
name: release-security
description: Container-image supply-chain gate — trivy/grype CVE scan of the image's OS and baked libraries, syft SBOM, cosign digest signing plus provenance attestation. Run in CI after the image is built and pushed, before deploy promotes it. Not the Dockerfile linter (`dockerfile-lint`) and not the lockfile audit (`deps-audit`) — this scans the built image, and `admission-policy` is what verifies the signature at deploy.
kind: example
pack: devops
---

# Skill: release-security

A built image is a supply-chain artifact. The build→registry gate: scan CVEs, generate SBOM, sign the digest, attest provenance, verify at deploy. The executor the security pack's OWASP A03 check dispatches to. Every finding cites the image + CVE id (or missing gate) + fix. Covers the image OS/baked-lib layer (what deps-audit's manifest scan misses) and the signature/SBOM (what dockerfile-lint's Dockerfile check misses).

## Premise

A built container image is a **supply-chain artifact**, not just a deploy blob. The build→registry gate has four jobs the pack references everywhere but executes nowhere: **scan** the image for OS/library CVEs, **generate an SBOM**, **sign** the digest, and **attest provenance** — then **verify** at deploy. This skill is the executor that closes that loop (the security pack's `@security-auditor` A03 check *dispatches here*; `dockerfile-lint` stops at hadolint; `deps-audit` scans the manifest, not the image's OS layer).

**Every finding cites the image + the CVE id (or the missing gate) + the fix.** "Image looks insecure" without the cited CVE/digest is not a finding. This is a runner — it executes the tools and gates the pipeline on the result.

## Prerequisites

- `trivy` (or `grype`) for image CVE scan; `syft` for SBOM; `cosign` for signing/attestation.
- A registry the image is pushed to (sign the digest there).
- **Keyless signing via OIDC** (Fulcio/Rekor) preferred over a long-lived cosign key — no key to leak; identity = the CI workload.

## Procedure

1. `trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <image>@<digest>` (or grype) — triage by CVSS + EPSS + KEV.
2. `syft <image>@<digest> -o cyclonedx-json > sbom.cdx.json` + `cosign attach sbom`.
3. `cosign sign --yes <image>@<digest>` — sign the DIGEST, keyless via CI OIDC (not a stored key).
4. `cosign attest --type slsaprovenance` (or actions/attest-build-provenance).
5. Verify at deploy: `cosign verify` + a K8s admission policy (Kyverno/Sigstore — infra pack) so unsigned/CVE-failing images can't admit.

## Output

```
release-security — <image>@<digest>   (scanner: trivy | grype)

CVE scan:   FAIL — 2 HIGH, 1 CRITICAL (fixed available)
  - CVE-2025-XXXX (CRITICAL, EPSS 0.72, KEV=yes) openssl 3.0.x → 3.0.y  [BLOCKER]
  - CVE-2025-YYYY (HIGH) libxml2 → update base image
SBOM:       OK (cyclonedx, 214 components, attached)
Signature:  MISSING — image not signed (cosign sign the digest, keyless OIDC)  [BLOCKER]
Provenance: MISSING — no SLSA attestation

Verdict: BLOCK — fix the CRITICAL + sign before release.
```

## Gotchas

Sign the digest not the mutable tag; keyless > stored keys; unfixed base CVEs → slimmer base, not suppress; signing without verify-at-admission is theater; don't re-report app-lockfile CVEs (that's deps-audit).

## Halt conditions

No CVE finding without the cited id + fix; never sign an image that failed the CVE gate; no PASS on an unfixed CRITICAL without explicit EPSS/KEV-informed risk-acceptance; "signed/verified" only if cosign verify actually ran.

## Related

dockerize / add-ci (wire the gate), dockerfile-lint (Dockerfile half), @ci-reviewer, security-auditor A03 (dispatches here), deps-audit (manifest counterpart), infrastructure pack (admission policy).
