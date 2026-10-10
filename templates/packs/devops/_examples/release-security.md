---
name: release-security
description: "Image gate runner: scan the built digest, SBOM, sign and attest, verify by exact identity; cosign ≥ 3.1.3."
kind: example
pack: devops
---

# Skill: release-security

## Premise

A built image is a supply-chain artifact. The gate: scan CVEs, generate an SBOM, sign the digest, attest provenance, verify by the exact workflow and ref. Two modes: **CI mode** (wired by `/dockerize` and `/add-ci`; signs and pushes in the user's pipeline) and **audit mode** (called by `release-integrity-scan` §5 and security's A03 with an existing digest; read-only — never signs, tags or pushes). Every finding cites `<repo>@<digest>` + the CVE id (or the missing gate, or the identity a verify accepts) + the fix. Oracles: `proof-oracles.md` § DevOps V223, V224; precedents § 19, § 21, § 41.

## Prerequisites — floors first (`THR-SCANNER-FLOOR`)

cosign **≥ 3.1.3** (GHSA-fx35-mq7g-6g98, a verification bypass fixed 2026-08-06); trivy pinned by version **and** digest (`aquasec/trivy:0.75.0@sha256:<digest>`; 76 of 77 `trivy-action` tags were force-moved on 2026-03-19); syft and grype pinned the same way; keyless OIDC signing over a stored key. A tool below its floor makes its rows `NOT-RUN`, never PASS.

## Procedure

0. Work on `<repo>@<digest>` (the one build that pushes: `steps.build.outputs.digest`), never a tag.
1. Scan **before** the image is pullable (push by digest to a staging repo, scan, promote that digest) — or scan the pushed digest and gate the deploy on it, said plainly. Never scan a `load: true` image and push a second build (unscanned, and no attestations).
   `trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <repo>@<digest>` — a PASS means "no *fixable* High/Critical" (precedents § 21); triage by CVSS + EPSS + KEV.
2. `syft scan <repo>@<digest> --scope all-layers -o cyclonedx-json=sbom.cdx.json` (the default `squashed` hides packages deleted in a later layer), then **attest** it:
   `cosign attest --yes --type cyclonedx --predicate sbom.cdx.json <repo>@<digest>` (or `actions/attest` v4 with `sbom-path`).
   `cosign attach sbom` is deprecated — cosign declares `attach` "will be removed in v4.0.0" — and weaker: an attached SBOM is an unsigned blob; an attestation is signed by the build identity.
3. `cosign sign --yes --recursive <repo>@<digest>` — the digest, every platform of an index, keyless.
4. Provenance SLSA v1: `actions/attest` v4, or `cosign attest --type slsaprovenance1` (`slsaprovenance` is v0.2). build-push-action's own provenance is v0.2 by default and `mode=max` on public repos records build-arg values: a secret build arg is security's (`iac-scan` 2b); use `--mount=type=secret`.
5. Verify by exact identity and issuer:
   `cosign verify --certificate-identity 'https://github.com/<o>/<r>/.github/workflows/<release>.yml@refs/heads/main' --certificate-oidc-issuer https://token.actions.githubusercontent.com <repo>@<digest>`;
   `gh attestation verify oci://<repo>@<digest> --repo <o>/<r> --signer-workflow <o>/<r>/.github/workflows/<release>.yml --source-ref refs/heads/main --deny-self-hosted-runners`.
   A valid attestation from the wrong workflow is the TanStack shape (2026-05-11). Regexp identities, `--owner` alone, a missing issuer, `--insecure-ignore-tlog`, a tag or `|| true` verify nothing. **Negative test (V224):** a scratch image signed by another workflow or ref, in a sandbox repo and a scratch registry, must be rejected.
6. Digest equality (V223): scanned = signed = pushed = deployed.

Admission enforcement with the same identity → infrastructure `admission-policy`; upgrade the verifier with a cosign v3 signer (bundles, OCI 1.1 referrers).

## Runner contract (`release-integrity-scan` §5)

Input: `<repo>@<digest>`, expected identity + issuer, platforms, `THR-SCANNER-FLOOR`. Output rows, each with its command and exit, or `NOT-RUN (<reason>)`: `FLOOR` · `SCAN` · `SBOM` (attested / attached / none, scope) · `SIGN` (platforms signed) · `VERIFY+` · `VERIFY-` (REJECTED is the pass; ACCEPTED = V224 failure) · `DIGEST` (built = scanned = pushed = deployed). A `NOT-RUN` makes §5 `blocked`.

## Output

```
release-security — <repo>@<digest>   (mode: audit · trivy 0.75.0@sha256 · cosign 3.1.3)

FLOOR:    OK
CVE scan: FAIL — 1 CRITICAL, 2 HIGH (fixes available; --ignore-unfixed)
SBOM:     attached, not attested — replace with cosign attest / actions/attest
Sign:     1 of 2 platform manifests unsigned (no --recursive)
Verify+:  pass (exact identity + issuer) · Verify-: REJECTED (another workflow's signature)
Digest:   built = scanned = pushed; deployed: NOT-RUN (no cluster access)

Verdict: BLOCK — fix the CRITICAL and sign every platform before release.
```

## Gotchas

Sign the digest, not the tag; signing without a pinned-identity verify is theatre; unfixed base CVEs → a slimmer base, not suppression; a manifest list is one digest (precedents § 19) — promote the index, sign `--recursive`; don't re-report app-lockfile CVEs (that's `deps-audit`).

## When to run

CI mode on every release or tag build (scan before the push that makes it pullable, or gate the deploy on the pushed digest's scan). Audit mode when `release-integrity-scan` §5 or security A03 hands it a digest, and on a base-image bump or a new advisory.

## Halt conditions

No CVE finding without the cited id + fix; never sign an image that failed the CVE gate; no PASS on an unfixed CRITICAL without explicit EPSS/KEV-informed risk acceptance; "verified" only if a verify ran with an exact identity and issuer, saying whether the negative test ran; a tool below its floor is `NOT-RUN`; audit mode never signs, tags, pushes or deletes on the user's registry.

## Related

`release-integrity-scan` (the detector that calls this), `/dockerize` / `/add-ci` (wire the gate), `container-build-scan` (the Dockerfile half), `@ci-reviewer` / `@deployment-engineer`, security-auditor A03 (dispatches here), `deps-audit` (manifest counterpart), infrastructure `admission-policy` (enforces verify).
