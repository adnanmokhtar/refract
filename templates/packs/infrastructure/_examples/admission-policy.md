---
name: admission-policy
description: Generates fail-closed Kubernetes admission policy for the cluster's engine (Kyverno / Sigstore policy-controller / Gatekeeper / native ValidatingAdmissionPolicy) — cosign image-signature verification, restricted Pod Security Standards, a provenance gate, and default-deny egress. Run when standing up a cluster's security baseline, or once `release-security` starts signing so the signatures are actually verified. Not a posture report — `k8s-audit` reports drift and `k8s-generate` sets defaults; this enforces at admission so neither can be bypassed.
kind: example
pack: infrastructure
---

# Skill: admission-policy

Signing an image means nothing until the cluster refuses unsigned or CVE-failing workloads. This skill generates the admission policy — fail-closed — that verifies what devops `release-security` signs, closing the sign→verify loop.

## Premise

Signing an image (devops `release-security`) means nothing until the cluster **refuses to run anything unsigned or CVE-failing**. Admission control is the enforcement point — a policy that runs at `kubectl apply` time and *rejects* a workload that violates it. `k8s-generate` sets secure defaults when it generates a manifest, but nothing stops a hand-written or third-party manifest that skips them. This skill makes the posture non-bypassable.

**Every generated policy cites what it enforces + the failure message a rejected workload gets.** A policy in `Audit`/`warn` mode that never blocks is theater — default to `Enforce`.

## Adapt to the codebase

| Engine | Best for | Image-signature verification |
|---|---|---|
| **Kyverno** | most teams — YAML policies, good UX | `verifyImages` rule with `keyless` (cosign OIDC) |
| **Sigstore policy-controller** | signature-first shops | `ClusterImagePolicy` (native cosign/Fulcio/Rekor) |
| **OPA Gatekeeper** | Rego-standardized orgs | constraint templates (+ a verifier such as `ratify`) |
| **Native ValidatingAdmissionPolicy** | no extra controller wanted | CEL expressions — pod-security shape only; **image signatures still need a controller**, VAP cannot reach a registry |

Mirror the cluster's existing engine; introduce one only if none exists (recommend Kyverno). Native `ValidatingAdmissionPolicy` reached GA in Kubernetes 1.30, so it is on every currently-supported minor (https://kubernetes.io/releases/) — confirm with `kubectl api-resources --api-group=admissionregistration.k8s.io` rather than assuming.

**Resolve the engine's own API shape before generating.** Policy-engine CRDs deprecate fields on their own schedule, independent of Kubernetes. `kubectl explain <kind>.<field>` prints the DEPRECATED marker when there is one; a policy that sets a deprecated field applies today and stops applying at the next engine upgrade.

## Generates

### 1. Image-signature verification (the release-security counterpart)

Only images signed by the CI's OIDC identity admit — keyless, no key to distribute:

```yaml
# Kyverno
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: verify-image-signatures }
spec:
  rules:
    - name: check-cosign-signature
      match: { any: [{ resources: { kinds: [Pod] } }] }
      verifyImages:
        - imageReferences: ["<registry>/*"]
          attestors:
            - entries:
                - keyless:
                    issuer: "https://token.actions.githubusercontent.com"   # your CI OIDC issuer
                    subject: "https://github.com/<org>/<repo>/.github/workflows/*"
```

**Enforce vs Audit is a PER-RULE field.** Kyverno's own API type marks the spec-level one deprecated — *"Deprecated, use validationFailureAction under the validate rule instead"* (https://raw.githubusercontent.com/kyverno/kyverno/main/api/kyverno/v1/spec_types.go) — so `spec.validationFailureAction` and `spec.validationFailureActionOverrides` are on the removal path. Set it on the rule:

```yaml
  rules:
    - name: require-digest
      match: { any: [{ resources: { kinds: [Pod] } }] }
      validate:
        failureAction: Enforce         # per-rule; the spec-level field is deprecated
        message: "images must be referenced by digest, not a mutable tag"
        pattern: { spec: { containers: [{ image: "*@sha256:*" }] }}
```

### 2. Pod Security Standards (restricted) — enforced, not just defaulted

Reject `privileged`, `hostNetwork`/`hostPID`/`hostIPC`, `allowPrivilegeEscalation: true`, missing `runAsNonRoot`, un-dropped capabilities, writable root FS, and missing `seccompProfile: RuntimeDefault`. Prefer the built-in Pod Security Admission label (`pod-security.kubernetes.io/enforce: restricted`) on the namespace plus a Kyverno/VAP backstop for the specifics.

### 3. Supply-chain + provenance gate

Reject images by mutable tag; require the digest form so the signature binds. Optionally require the CVE-scan attestation to be present and passing.

### 4. Egress / network default-deny reference

Point at `k8s-generate`'s default-deny `NetworkPolicy` (blocks pod→metadata `169.254.169.254`) — the runtime belt to the code-level SSRF suspenders.

## Output

```
admission-policy — <cluster/namespace>   (engine: Kyverno)

Generated:
  policies/verify-image-signatures.yaml   Enforce — keyless cosign, issuer=<ci>, subject=<repo>
  policies/pod-security-restricted.yaml    Enforce — non-root, no-priv, drop-caps, RO-rootfs, seccomp
  policies/require-digest.yaml             Enforce — reject mutable :tag, require @sha256

Field shapes resolved against the installed engine (kubectl explain), not from memory.

Verify:  kubectl apply --dry-run=server of an unsigned image → REJECTED with the policy message.
```

## False positives / gotchas

- **Roll out in `Audit` first, then flip to `Enforce`** — an Enforce policy on an existing cluster can block system workloads (kube-system, the edge controller). Scope exclusions explicitly, then enforce.
- **Keyless subject/issuer must match your CI exactly** — a wrong `subject` regex fails every deploy; an over-broad one verifies nothing.
- **Signature verify needs registry reachability + Rekor** — air-gapped clusters need a mirrored transparency log.
- **Pod Security Admission ≠ signature verification** — PSA covers the securityContext; images still need a controller. Use both.

## Halt conditions

- Halt on a generated policy left in `Audit`/`warn` when the intent is enforcement.
- Halt on any policy field written from memory — confirm it against the installed engine; a deprecated field applies today and stops applying at the next engine upgrade, the worst failure shape for a control that fails closed.
- No placeholder or over-broad signature subject — it must bind to the project's real CI identity or it verifies nothing.
- No "images verified" claim without a policy that actually rejects an unsigned image (dry-run proof in the output).

## Related

- `devops/skills/release-security/SKILL.md` — the producer (signs + attests); this is the verifier. Together they close the sign→verify loop.
- `k8s-generate` — sets secure defaults; `k8s-audit` — reports posture drift; this **enforces** at admission so nothing bypasses.
- `security/agents/security-auditor.md` — A03 Supply-Chain + A02 Misconfiguration dispatch here.
- `security/skills/ssrf-scan/SKILL.md` — the code-level SSRF detector this pack's egress NetworkPolicy backstops.
