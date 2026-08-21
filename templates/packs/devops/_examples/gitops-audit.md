---
name: gitops-audit
description: Audit GitOps discipline — git as the single source of truth for cluster state, reconciled by a controller (Argo CD / Flux). Finds drift (cluster ≠ git), out-of-band manual kubectl/helm, plaintext secrets in git, auto-sync+prune with no safeguard, and missing sync-wave ordering. Not general CI/CD — the git→cluster reconciliation loop only.
---

# gitops-audit

The deployed cluster state matches a git-declared desired state, reconciled by a controller. This skill audits that the reconciliation discipline actually holds.

## Premise

Imperative out-of-band changes and un-reconciled drift are forbidden — every change lands via a reviewed commit, and the controller reconciles git→cluster. Every finding cites the real artifact: the `kubectl apply` in a CI job/runbook that bypasses git, the Argo `Application` showing `OutOfSync`, the committed manifest with a base64 `data:` secret not sealed/SOPS-encrypted, the `prune: true` with no safeguard, the dependent resources with no `sync-wave`. "There's drift" without the controller's sync-status output is not a finding.

**Boundary (this is not a CI/CD skill):**
- `@ci-reviewer` / `add-ci` own the **CI pipeline** (build/test/scan/publish). They do not audit whether the cluster matches git.
- `@deployment-engineer` owns the **deploy strategy**; it names GitOps as an option, not the loop's health.
- **THIS** owns the git→cluster **reconciliation discipline**: controller loop, drift/auto-heal, no-manual-kubectl, sync waves, secrets-in-git safety, prune safeguards, app-of-apps.

## When to use

- Adopting Argo CD / Flux — confirm git is actually the source of truth.
- After an incident where prod changed but no commit explains it — hunt the out-of-band path.
- Quarterly — confirm no `OutOfSync` apps sitting un-reconciled, no manual `kubectl apply` in runbooks.

## Scans for

1. **Out-of-band mutation** — `kubectl apply/edit/scale` / `helm install/upgrade` in CI/Makefile/runbook targeting a managed namespace. 2. **No drift detection / self-heal** — `selfHeal: false` + no `OutOfSync` alert. 3. **Un-reconciled drift** — an `Application` sitting `OutOfSync` (cite status). 4. **Plaintext secret in git** — raw/base64 `Secret data:` not sealed/SOPS/external. 5. **Auto-sync + prune with no safeguard** — `prune: true` with no protected-ns/ignoreDifferences guard. 6. **No sync-wave ordering** — CRD-before-CR, DB-before-app with no `sync-wave`/`dependsOn`. 7. **No app-of-apps** — flat sprawl of hand-registered Applications.

## Detect

```bash
argocd app list -o wide | awk 'NR==1 || $0 !~ /Synced/'    # anything not Synced
grep -rInE 'kubectl (apply|edit|scale|patch)|helm (install|upgrade)' scripts/ .github/ Makefile
grep -rlE '^kind: Secret' manifests/ | while read f; do
  grep -q 'sops:\|SealedSecret\|ExternalSecret' "$f" || echo "PLAINTEXT: $f"; done
```
Flux equivalent: `flux get kustomizations -A ; flux diff kustomization <name>`.

## Output

```
gitops-audit — <cluster/repo> (controller: Argo CD)
Reconciliation:
  ✗ DRIFT     app/payments   OutOfSync 6d — live=5 git=3
  ✗ NO-HEAL   app/web        selfHeal=false, no OutOfSync alert
Out-of-band mutations:
  ✗ BYPASS    scripts/hotfix.sh  `kubectl apply -n payments` — source of the drift
Secrets:
  ✗ PLAINTEXT manifests/db-secret.yaml  base64 Secret, not SOPS/sealed — rotate
```

## Gotchas

- **Controller-managed drift is legitimate** — HPA replicas, cert-manager-rotated secrets — exclude via `ignoreDifferences`; don't flag HPA replica drift.
- **`kubectl apply` in a bootstrap/install-controller script is fine** — only flag imperative changes to *application* resources.
- **`ExternalSecret` CRs reference but don't contain a secret** — that's the correct pattern, not a leak.
- **Don't enable `selfHeal`/`prune` on an app currently OutOfSync** — reconcile first, or it enforces the wrong state.
- Plaintext secret in git = block (rotate — it's in history). Auto-prune on prod with no safeguard = block.

## Halt conditions

- Refuse to report drift without the controller's own sync-status output (`argocd app diff` / `flux diff`) — "probably drifted" is not a finding.
- Refuse to call a committed secret a leak without showing the manifest has a raw/base64 `data:` block and is not an `ExternalSecret`/`SealedSecret`/SOPS-encrypted file.
- Halt if the controller is unreachable (no `argocd`/`flux` access) — audit the repo contents statically and mark reconciliation-status findings as unverified; don't fabricate sync state.
- Plaintext secret in git = block (rotate the credential, it's in history). Auto-prune on prod with no safeguard = block.
- Don't recommend enabling `selfHeal`/`prune` on an app that is *currently* OutOfSync — reconcile the drift first, or self-heal will enforce the wrong state.

## Related

- `@ci-reviewer` — owns the CI pipeline (build/test/scan/publish); this owns the git→cluster reconciliation after publish.
- `@deployment-engineer` — owns deploy strategy + rollback; this audits whether the loop is disciplined.
- infrastructure pack `admission-policy` skill — the cluster-side guardrail (OPA/Kyverno) that rejects what GitOps would sync.
