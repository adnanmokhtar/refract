---
name: admission-policy
description: Generates fail-closed Kubernetes admission policy for the cluster's engine (Kyverno / Sigstore policy-controller / Gatekeeper / native ValidatingAdmissionPolicy) — cosign image-signature verification, restricted Pod Security Standards, a provenance gate, and default-deny egress. Run when standing up a cluster's security baseline, or once `release-security` starts signing so the signatures are actually verified. Not a posture report — `k8s-audit` reports drift and `k8s-generate` sets defaults; this enforces at admission so neither can be bypassed.
kind: example
pack: infrastructure
---

# Skill: admission-policy

Signing an image means nothing until the cluster refuses unsigned/CVE-failing workloads. Generates the admission policy (fails closed) that verifies what devops release-security signs — closing the sign→verify loop. Detect the engine (Kyverno / Sigstore policy-controller / OPA Gatekeeper / native ValidatingAdmissionPolicy) and generate for it.

## Premise

Signing an image (devops `release-security`) means nothing until the cluster **refuses to run anything unsigned or CVE-failing**. Admission control is the enforcement point — a policy that runs at `kubectl apply` time and *rejects* a workload that violates it. The pack sets secure defaults *when it generates* a manifest (`k8s-generate`), but nothing stops a hand-written or third-party manifest that skips them. This skill generates the admission policy that makes the security posture non-bypassable — closing the "admission control is mentioned but never generated" gap and giving `release-security`'s `cosign sign` a verifier.

**Every generated policy cites what it enforces + the failure message a rejected workload gets.** Generate policy that fails closed; a policy in `Audit`/`warn` mode that never blocks is theater — default to `Enforce`.

## Generates

1. **Image-signature verification** — Kyverno `verifyImages` keyless (cosign OIDC): only images signed by the CI identity (issuer + subject bound to your repo workflow) admit; optionally require SBOM/SLSA attestation.
2. **Pod Security Standards (restricted)** — enforce non-root, no privileged/hostNetwork, drop caps, RO-rootfs, seccomp RuntimeDefault (PSA label + backstop).
3. **Supply-chain gate** — reject mutable :tag, require @sha256 digest; optionally require passing CVE-scan attestation.
4. **Egress default-deny** — reference k8s-generate's NetworkPolicy blocking pod→metadata.

## Output

```
admission-policy — <cluster/namespace>   (engine: Kyverno)

Generated:
  policies/verify-image-signatures.yaml   Enforce — keyless cosign, issuer=<ci>, subject=<repo>
  policies/pod-security-restricted.yaml    Enforce — non-root, no-priv, drop-caps, RO-rootfs, seccomp
  policies/require-digest.yaml             Enforce — reject mutable :tag, require @sha256

Verify:  kubectl apply --dry-run=server of an unsigned image → REJECTED with the policy message.
```

## Gotchas

Roll out Audit → then Enforce (an Enforce policy can block kube-system/ingress — scope exclusions first). Keyless subject/issuer must bind to your real CI identity (over-broad = verifies nothing). Signature verify needs registry + Rekor reachability. PSA ≠ signature verification — use both.

## Halt conditions

No policy left in Audit when enforcement is intended; no placeholder/over-broad signature subject; no "images verified" without a policy that rejects an unsigned image (dry-run proof).

## Related

devops/release-security (producer — signs; this verifies), k8s-generate (defaults) / k8s-audit (drift), security-auditor A03/A02 (dispatch here), security/ssrf-scan (egress code-level).
