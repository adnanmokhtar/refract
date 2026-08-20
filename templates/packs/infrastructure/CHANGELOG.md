# infrastructure pack — changelog

Release history for `templates/packs/infrastructure/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 1.4.0 — 2026-07-10

- k8s-generate mechanical halt #9: least-privilege in-cluster IAM (no default SA · no wildcard
  RBAC/cluster-admin · automount off · no privileged/hostPath).
- k8s-reviewer: invariants for least-privilege in-cluster IAM (the k8s analog of iam:*) + no
  privilege-escalation surface + bounded worst-case blast radius.

## 1.3.1 — 2026-07-10

- k8s-audit: every check group is now bound to its named tool's parsed output with a cite-or-halt
  (failed kube-bench control id, kubectl cost idle line, securityContext field, kubent line) + a
  no-finding-without-tool-output-citation halt — mirrors tf-plan-review/dr-audit.

## 1.3.0 — 2026-07-10

- skill +1: network-exposure-audit (audits running/declared ingress exposure — 0.0.0.0/0 on
  non-public ports, public DB/cache, missing default-deny NetworkPolicy).

## 1.2.0 — 2026-07-09

- skills +1: dr-audit — audits an EXISTING footprint for backup coverage + PITR + drilled-restore +
  RPO/RTO (the audit-of-state counterpart to provision-tier's creation-time enforcement and
  multi-region's design). Backing MUST in infra-principles.

## 1.1.0 — 2026-07-09

- NEW skills/admission-policy.md (kind:skill) — admission-policy generator. Generates:
  image-signature verification (Kyverno verifyImages keyless / Sigstore ClusterImagePolicy,
  issuer+subject bound to the CI OIDC identity, optional SBOM/SLSA attestation require), Pod
  Security Standards restricted enforcement (non-root/no-priv/drop-caps/RO-rootfs/seccomp),
  supply-chain digest-not-tag gate, egress default-deny reference. Per-engine Adapt table;
  Audit->Enforce rollout guidance; fail-closed default. Verifier counterpart to devops
  release-security (closes sign->verify); enforcement layer between k8s-generate (defaults) and
  k8s-audit (drift). Registered in _topics/_essentials; abridged _examples/admission-policy.md.
