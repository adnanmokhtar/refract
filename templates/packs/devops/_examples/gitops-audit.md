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

1. **Out-of-band mutation** — `kubectl apply/edit/scale` / `helm install/upgrade` in CI/Makefile/runbook targeting a managed namespace. 2. **No drift detection / self-heal** — `selfHeal: false` + no `OutOfSync` alert. 3. **Un-reconciled drift** — an `Application` sitting `OutOfSync` (cite status). 4. **Plaintext secret in git** — raw/base64 `Secret data:` not sealed/SOPS/external. 5. **Auto-sync + prune with no safeguard** — see below; the guards are not the ones people name. 6. **No sync-wave ordering** — CRD-before-CR, DB-before-app with no `sync-wave`/`dependsOn`. 7. **No app-of-apps** — flat sprawl of hand-registered Applications.

### Prune safety — know which controls are actually guards

- **`automated.allowEmpty`** is the real one, and its polarity is the opposite of a checklist item.
  It defaults to `false`, and that default *is* the protection: an Application rendering to zero
  resources is refused rather than pruning everything it owns. So the finding is **`allowEmpty: true`
  set explicitly** on a prod app, not "allowEmpty is missing". Grep for its presence.
- **`PruneLast=true`** (sync option) prunes as a final wave, after the rest is deployed and healthy.
- **`PrunePropagationPolicy`** (`foreground` default / `background` / `orphan`) — `orphan` leaves dependents behind.
- **Not guards, despite looking like them:** `ignoreDifferences` governs diff noise;
  `FailOnSharedResource` fails a sync when another Application already owns a resource. Neither
  constrains pruning — do not accept either as prune-safety evidence.

## Detect

```bash
argocd app list -o wide | awk 'NR==1 || $0 !~ /Synced/'    # anything not Synced
grep -rInE 'kubectl (apply|edit|scale|patch)|helm (install|upgrade)' scripts/ .github/ Makefile
grep -rlE '^kind: Secret' manifests/ | while read -r f; do
  grep -q 'sops:\|SealedSecret\|ExternalSecret' "$f" || echo "PLAINTEXT: $f"; done

grep -rn 'allowEmpty:[[:space:]]*true' apps/ 2>/dev/null    # each hit disables the empty-render guard
grep -rl 'prune:[[:space:]]*true' apps/ 2>/dev/null \
  | xargs -r grep -L 'PruneLast=true\|PrunePropagationPolicy='   # -r: empty input must not run grep on stdin
```
Flux equivalent: `flux get kustomizations -A ; flux diff kustomization <name>`.

Shell note, not pedantry: `xargs` without `-r` runs once with no arguments on empty input, so
`grep -L` reads stdin and hangs; and `$(...)` expanding to nothing turns `grep -rL pat $files`
into a recursive grep of the working directory. Both produce a silently empty audit.

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
Sync safety:
  ✗ PRUNE     app/batch      prune=true AND allowEmpty=true (apps/batch.yaml:22) — a zero-manifest
                             render will delete every prod job
```

## Gotchas

- **Controller-managed drift is legitimate** — HPA replicas, cert-manager-rotated secrets — exclude via `ignoreDifferences`; don't flag HPA replica drift.
- **`allowEmpty` absent is the SAFE state, not a missing control** — its default is `false`. Reporting "allowEmpty not configured" inverts the polarity and produces a false positive on every correctly-configured Application.
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
