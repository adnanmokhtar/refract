---
name: gitops-audit
description: Audit GitOps discipline — git as the single source of truth for cluster state, reconciled by a controller (Argo CD / Flux). Finds drift (cluster ≠ git), out-of-band manual kubectl/helm, plaintext secrets in git, auto-sync+prune with no safeguard, and missing sync-wave ordering. Not general CI/CD — the git→cluster reconciliation loop only.
---

# gitops-audit

The deployed cluster state matches a git-declared desired state, reconciled by a controller. This skill audits that the reconciliation discipline actually holds.

## Premise

Imperative out-of-band changes and un-reconciled drift are forbidden — every change lands via a reviewed commit, and the controller reconciles git→cluster. Every finding cites the real artifact: the `kubectl apply` in a CI job or runbook that bypasses git, the Argo `Application` showing `OutOfSync` / `status: Unknown`, the committed manifest with a base64 `data:` secret that is not sealed/SOPS-encrypted, the `syncPolicy.automated.prune: true` with no safeguard, the dependent resources with no `sync-wave` annotation. A "there's drift" claim without the controller's sync-status output is not a finding.

**Boundary (read first — this is not a CI/CD skill):**
- `@ci-reviewer` and `add-ci` own the **CI pipeline** — build, test, scan, artifact publish, the workflow YAML. They do not audit whether the cluster matches git.
- `@deployment-engineer` owns the **deploy strategy** (rolling/canary/rollback command). It mentions GitOps as one option; it does not audit the reconciliation loop's health.
- **infra/cluster provisioning** (Terraform, cluster creation) is out of scope — this is not "how the cluster was built."
- **THIS** owns the git→cluster **reconciliation discipline**: the controller loop, drift detection/auto-heal, no-manual-kubectl, sync waves, secrets-in-git safety, auto-sync+prune safeguards, app-of-apps structure.

## When to use

- Adopting Argo CD / Flux — confirm git is actually the source of truth, not a mirror nobody reconciles against.
- After an incident where prod changed but no one knows which commit — hunt the out-of-band mutation path.
- Reviewing a GitOps repo before it manages prod — verify drift detection, secret handling, and prune safety.
- Quarterly — confirm no `OutOfSync` apps have been sitting un-reconciled and no manual `kubectl apply` crept into runbooks.

## Adapt to the GitOps controller

- **Argo CD:** `Application`/`ApplicationSet` CRs, `syncPolicy.automated` (`selfHeal`, `prune`), `argocd app diff`, `argocd app list -o wide` (SYNC/HEALTH status), app-of-apps root Application, `argocd-image-updater`.
- **Flux:** `GitRepository` + `Kustomization`/`HelmRelease`, `flux get kustomizations`, `spec.prune`, `dependsOn` for ordering, `flux diff`.
- **Rancher Fleet:** `GitRepo` CR + `fleet.yaml`, bundle status. **Jenkins X:** promote-via-PR + environments repo.
- Resolve which controller runs AND its source repo — you audit both the controller's sync status and the repo's contents.

## Scans for

1. **Out-of-band mutation** — `kubectl apply`/`kubectl edit`/`kubectl scale`/`helm install`/`helm upgrade` in a CI job, Makefile, runbook, or deploy script that targets a GitOps-managed namespace (bypasses git → guaranteed drift source).
2. **No drift detection / self-heal** — controller present but `selfHeal: false` and no alert on `OutOfSync`, so cluster silently diverges from git with nobody notified.
3. **Un-reconciled drift** — an `Application`/`Kustomization` sitting `OutOfSync`/`degraded` (cite the controller's status output), meaning git no longer describes reality.
4. **Plaintext secret in git** — a committed manifest with a raw or base64-only `Secret` `data:` block, not encrypted via sealed-secrets / SOPS / external-secrets (git history now leaks the credential).
5. **Auto-sync + prune with no safeguard** — `syncPolicy.automated.prune: true` is the switch that
   lets a bad render delete live resources. Know which controls are actually guards, because the
   plausible-sounding ones are not:
   - **`automated.allowEmpty`** — the real one. It defaults to `false`, and that default *is* the
     protection: an Application whose manifests render to zero resources is refused rather than
     pruning everything it owns. Argo's own wording is that automated sync with prune "have a
     protection from any automation/human errors when there are no target resources". So the
     finding is not "allowEmpty is missing" — it is **`allowEmpty: true` set explicitly** on a prod
     Application, which switches the protection off. Grep for its presence, not its absence.
   - **`PruneLast=true`** (sync option) — prunes as a final implicit wave, after the other resources
     are deployed and healthy, so a partially-applied sync cannot delete first.
   - **`PrunePropagationPolicy`** (`foreground` default / `background` / `orphan`) — `orphan` leaves
     dependents behind; know which one is set before judging blast radius.
   - **Not guards, despite looking like them:** `ignoreDifferences` governs diff noise, and
     `FailOnSharedResource` fails a sync when another Application already owns a resource. Neither
     constrains pruning. Do not accept either as evidence of prune safety.
6. **No sync-wave ordering** — dependent resources (CRD before CR, DB before app, namespace before workload) with no `argocd.argoproj.io/sync-wave` / Flux `dependsOn`, so first sync races and fails.
7. **No app-of-apps / flat sprawl** — many hand-registered Applications with no root/ApplicationSet parent, so onboarding a new app is a manual out-of-git step (drift vector).

## How to detect

```bash
# Un-reconciled drift + self-heal state (Argo CD): SYNC / HEALTH per app.
argocd app list -o wide | awk 'NR==1 || $0 !~ /Synced/'      # anything not Synced
argocd app get <app> -o json | jq '.spec.syncPolicy.automated'  # selfHeal / prune flags
argocd app diff <app>                                         # the exact cluster≠git delta
#   Flux equivalent: flux get kustomizations -A ; flux diff kustomization <name>

# Out-of-band mutations: imperative applies to GitOps-managed namespaces in scripts/CI.
grep -rInE 'kubectl (apply|edit|scale|set|patch)|helm (install|upgrade)' \
  scripts/ .github/ Makefile 2>/dev/null   # exclude the controller-bootstrap script

# Plaintext secrets committed (not sealed/SOPS/external).
grep -rlE '^kind: Secret' manifests/ | while read -r f; do
  grep -q 'sops:\|kind: SealedSecret\|kind: ExternalSecret' "$f" || echo "PLAINTEXT: $f"
done

# Prune safety. Note the polarity: allowEmpty's SAFE state is absent-or-false, so this
# looks for the explicit opt-OUT, and separately for prune with neither sync-option guard.
grep -rn 'allowEmpty:[[:space:]]*true' apps/ 2>/dev/null    # each hit disables the empty-render guard
grep -rl 'prune:[[:space:]]*true' apps/ 2>/dev/null \
  | xargs -r grep -L 'PruneLast=true\|PrunePropagationPolicy='   # -r: don't hang on an empty list

# Dependent resources with no ordering. Guard the substitution the same way.
crds=$(grep -rl 'kind: CustomResourceDefinition' k8s/ 2>/dev/null)
[ -n "$crds" ] && grep -rL 'sync-wave\|dependsOn' $crds
```

Two shell notes that are not pedantry — both of these have silently produced empty audits:
`xargs` with no `-r` runs the command once with no arguments when its input is empty, so
`grep -L <pattern>` reads **stdin** and hangs; and `$(...)` expanding to nothing turns
`grep -rL pat $files` into a recursive grep of the working directory.

## Output

```
gitops-audit — <cluster/repo> (controller: Argo CD)

Reconciliation:
  ✗ DRIFT       app/payments        OutOfSync 6d — live replicas=5, git=3 (argocd app diff below)
  ✗ NO-HEAL     app/web             selfHeal=false, no OutOfSync alert — silent divergence possible
  ✓ OK          app/notifications   Synced / Healthy, selfHeal=true

Out-of-band mutations:
  ✗ BYPASS      scripts/hotfix.sh   `kubectl apply -f patch.yaml -n payments` — bypasses git, source of the payments drift

Secrets:
  ✗ PLAINTEXT   manifests/db-secret.yaml  base64 Secret committed, not SOPS/sealed — DB password in git history (rotate)

Sync safety:
  ✗ PRUNE       app/batch           automated.prune=true AND allowEmpty=true (apps/batch.yaml:22) —
                                    a render that produces zero manifests will delete every prod job
  ⚠ PRUNE       app/web             prune=true, no PruneLast — a partially-applied sync prunes first
  ⚠ ORDER       app/analytics       CRD + CR in one wave, no sync-wave — first sync races

Blockers:
  1. db-secret.yaml — rotate the leaked password, re-commit via sealed-secrets/SOPS.
  2. scripts/hotfix.sh kubectl apply — remove; land the patch as a git commit so Argo reconciles it.
  3. app/payments drift — reconcile to git (or update git to match), then enable selfHeal.

Recommendations:
  - Enable selfHeal + OutOfSync alerting on all prod Applications.
  - Add sync-wave annotations for CRD→CR and DB→app ordering.
  - Remove `allowEmpty: true` from app/batch and add `PruneLast=true` before trusting auto-prune in prod.
```

## False positives / gotchas

- **Some drift is legitimately controller-managed** — HPA-scaled replicas, VPA-adjusted resources, cert-manager-rotated secrets. Exclude these via `ignoreDifferences`; don't flag HPA replica drift as an out-of-band mutation.
- **A `kubectl apply` in a bootstrap/install-controller script is fine** — that's how Argo/Flux itself gets installed. Only flag imperative changes to *application* resources the controller should own.
- **External-secrets `ExternalSecret` CRs look like they reference a secret but don't contain one** — the value lives in Vault/SSM. That's the correct pattern, not a plaintext-secret finding.
- **`prune: false` is safe-by-default but leaks orphans** — note orphaned resources, but don't demand `prune: true` without the safeguards in the same breath; recommending prune without a guard is the exact BLOCKER this skill warns about.
- **`allowEmpty` absent is the SAFE state, not a missing control.** Its default is `false`. A checklist that reports "allowEmpty not configured" as a finding inverts the polarity and generates a wall of false positives across every correctly-configured Application. The finding is the explicit `true`.
- **Sealed-secrets are cluster-key-specific** — a sealed secret in git is safe, but it can't be decrypted by a different cluster; that's a portability caveat, not a leak.
- **Flux `dependsOn` and Argo `sync-wave` don't compose across controllers** — if a repo mixes both, ordering guarantees don't cross the boundary; call that out.

## Halt conditions

- Refuse to report drift without the controller's own sync-status output (`argocd app diff` / `flux diff`) — "probably drifted" is not a finding.
- Refuse to call a committed secret a leak without showing the manifest has a raw/base64 `data:` block and is not an `ExternalSecret`/`SealedSecret`/SOPS-encrypted file.
- Halt if the controller is unreachable (no `argocd`/`flux` access) — audit the repo contents statically and mark reconciliation-status findings as unverified; don't fabricate sync state.
- Plaintext secret in git = block (rotate the credential, it's in history). Auto-prune on prod with no safeguard = block.
- Don't recommend enabling `selfHeal`/`prune` on an app that is *currently* OutOfSync — reconcile the drift first, or self-heal will enforce the wrong state.

## Related

- `@ci-reviewer` — owns the CI pipeline (build/test/scan/publish); this owns the git→cluster reconciliation that runs after publish.
- `@deployment-engineer` — owns deploy strategy + rollback; names GitOps as an option, this audits whether the loop is actually disciplined.
- infrastructure pack `admission-policy` skill — the cluster-side guardrail (OPA/Kyverno) that rejects what GitOps would otherwise sync.
