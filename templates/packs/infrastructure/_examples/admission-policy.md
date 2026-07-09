---
name: admission-policy
kind: example
pack: infrastructure
---

# Skill: admission-policy

Signing an image means nothing until the cluster refuses unsigned/CVE-failing workloads. Generates the admission policy (fails closed) that verifies what devops release-security signs — closing the sign→verify loop. Detect the engine (Kyverno / Sigstore policy-controller / OPA Gatekeeper / native ValidatingAdmissionPolicy) and generate for it.

## Generates

1. **Image-signature verification** — Kyverno `verifyImages` keyless (cosign OIDC): only images signed by the CI identity (issuer + subject bound to your repo workflow) admit; optionally require SBOM/SLSA attestation.
2. **Pod Security Standards (restricted)** — enforce non-root, no privileged/hostNetwork, drop caps, RO-rootfs, seccomp RuntimeDefault (PSA label + backstop).
3. **Supply-chain gate** — reject mutable :tag, require @sha256 digest; optionally require passing CVE-scan attestation.
4. **Egress default-deny** — reference k8s-generate's NetworkPolicy blocking pod→metadata.

## Gotchas

Roll out Audit → then Enforce (an Enforce policy can block kube-system/ingress — scope exclusions first). Keyless subject/issuer must bind to your real CI identity (over-broad = verifies nothing). Signature verify needs registry + Rekor reachability. PSA ≠ signature verification — use both.

## Halt conditions

No policy left in Audit when enforcement is intended; no placeholder/over-broad signature subject; no "images verified" without a policy that rejects an unsigned image (dry-run proof).

## Related

devops/release-security (producer — signs; this verifies), k8s-generate (defaults) / k8s-audit (drift), security-auditor A03/A02 (dispatch here), security/ssrf-scan (egress code-level).
