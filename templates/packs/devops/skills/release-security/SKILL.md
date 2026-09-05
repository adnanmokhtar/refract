---
name: release-security
description: Container-image supply-chain gate — trivy/grype CVE scan of the image's OS and baked libraries, syft SBOM, cosign digest signing plus provenance attestation. Run in CI after the image is built and pushed, before deploy promotes it. Not the Dockerfile linter (`dockerfile-lint`) and not the lockfile audit (`deps-audit`) — this scans the built image, and `admission-policy` is what verifies the signature at deploy.
kind: skill
pack: devops
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: release-security

## Premise

A built container image is a **supply-chain artifact**, not just a deploy blob. The build→registry gate has four jobs the pack references everywhere but executes nowhere: **scan** the image for OS/library CVEs, **generate an SBOM**, **sign** the digest, and **attest provenance** — then **verify** at deploy. This skill is the executor that closes that loop (the security pack's `@security-auditor` A03 check *dispatches here*; `dockerfile-lint` stops at hadolint; `deps-audit` scans the manifest, not the image's OS layer).

**Every finding cites the image + the CVE id (or the missing gate) + the fix.** "Image looks insecure" without the cited CVE/digest is not a finding. This is a runner — it executes the tools and gates the pipeline on the result.

## What this covers vs siblings

- `deps-audit` (security pack) — **application dependencies** from the lockfile. This skill — **the image OS packages + baked libraries** trivy/grype see that `deps-audit` cannot.
- `dockerfile-lint` (devops) — the **Dockerfile** (non-root, multi-stage, pinned base). This skill — the **built image** and its **signature/SBOM/provenance**.

## Prerequisites

- `trivy` (or `grype`) for image CVE scan; `syft` for SBOM; `cosign` for signing/attestation.
- A registry the image is pushed to (sign the digest there).
- **Keyless signing via OIDC** (Fulcio/Rekor) preferred over a long-lived cosign key — no key to leak; identity = the CI workload.

## Procedure

1. **Image CVE scan — gate on High/Critical:**
   ```bash
   trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <image>@<digest>
   # or: grype <image> --fail-on high
   ```
   Scans OS packages (apk/apt/rpm) + language libs baked into the image. `--ignore-unfixed` avoids blocking on CVEs with no upstream fix (track those separately). Triage remaining by CVSS **+ EPSS + CISA KEV**, not CVSS alone.
2. **SBOM — generate + attest.** Attach it as a signed *attestation*, not as a bare attached blob:
   ```bash
   syft <image>@<digest> -o cyclonedx-json > sbom.cdx.json    # or spdx-json
   cosign attest --yes --type cyclonedx --predicate sbom.cdx.json <image>@<digest>
   ```
   `cosign attach sbom` still exists but is deprecated — cosign's own CLI declares that `attach`
   "will be removed in v4.0.0", pointing at `oras` for attaching arbitrary artifacts. It is also the
   weaker option on its merits: an *attached* SBOM is an unsigned blob sitting next to the image,
   while an *attestation* is signed by the same identity that signed the digest, so `cosign verify-attestation`
   can prove the SBOM belongs to this build. If you are still on `attach`, migrating is a one-line change.
3. **Sign the DIGEST (never the mutable tag):**
   ```bash
   cosign sign --yes <image>@<digest>          # keyless: uses the CI OIDC identity → Fulcio cert, Rekor log
   ```
4. **Provenance — SLSA attestation:**
   ```bash
   cosign attest --yes --type slsaprovenance --predicate provenance.json <image>@<digest>
   ```
   (GitHub Actions can emit provenance via `actions/attest-build-provenance`.)
5. **Verify at deploy / admission** (the gate that makes signing meaningful):
   ```bash
   cosign verify --certificate-identity-regexp <ci-identity> --certificate-oidc-issuer <issuer> <image>@<digest>
   ```
   In K8s, enforce with a policy controller (Kyverno/Sigstore policy-controller / Connaisseur) so an unsigned or CVE-failing image cannot admit — dispatch the `infrastructure` pack for the admission policy.

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

## False positives / gotchas

- **Unfixed base-image CVEs** — a CVE with no upstream patch shouldn't block forever; `--ignore-unfixed` + switch to a slimmer base (distroless/chainguard) rather than suppress-and-forget. Note the accepted risk.
- **Sign the digest, not the tag** — a tag is mutable; signing `image:latest` signs whatever it points at today. Always `@sha256:…`.
- **Keyless > keys** — a stored cosign private key is a leak surface; prefer OIDC keyless. If a key is used, it lives in the secrets manager, never the repo/image.
- **Scanning ≠ verifying** — signing means nothing without `cosign verify` enforced at admission. A signed-but-unverified pipeline is theater.
- **Attaching ≠ attesting** — an attached SBOM is an unsigned blob in the registry that anyone who can push can replace. An attestation is signed by the build identity. Verify with `cosign verify-attestation`, not by confirming a file is present.
- **`--ignore-unfixed` changes what the gate means.** It is the right default (it stops an unpatchable base CVE from blocking every release forever) but it also means a PASS is "no *fixable* HIGH/CRITICAL", not "no HIGH/CRITICAL". Say which you ran; a report that reads as the stronger claim while the flag was set is the quiet version of a false PASS.
- **`deps-audit` overlap** — don't re-report the app-lockfile CVEs here; this owns the image OS/baked-lib layer.

## When to run

- Every release / tag build, in CI **after the image is built and pushed**, **before** deploy promotes it.
- Wired by `dockerize` (release step) and `add-ci` (the docker-build/release job).
- On a base-image bump or a new CVE advisory against a running image.

## Halt conditions

- Halt on any CVE finding without the cited `<CVE-id>` + severity + fix path.
- Do NOT sign an image that failed the CVE gate (you'd be attesting to a known-vulnerable artifact).
- Do NOT report PASS with an unfixed CRITICAL and no explicit risk-acceptance (EPSS/KEV-informed).
- Do NOT claim "signed/verified" unless `cosign verify` actually ran — signing without admission verification is not a control.

## Related

- `dockerize` / `add-ci` — wire this as the release/CI gate; `dockerfile-lint` — the Dockerfile half.
- `@ci-reviewer` — reviews that the pipeline HAS this gate (OIDC, pinned actions).
- `security/agents/security-auditor.md` — its OWASP **A03 Software Supply Chain** check dispatches HERE (this is the producer that closes its dispatch-and-verify loop).
- `security/skills/deps-audit/SKILL.md` — the application-dependency counterpart (manifest, not image).
- `infrastructure` pack — the K8s admission policy (Kyverno/Sigstore) that enforces verify-at-deploy.
