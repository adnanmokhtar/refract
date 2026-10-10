#!/usr/bin/env bash
# render.sh — k8s-render-scan § 0: render every Kubernetes deploy root of a repo, per environment, offline.
#
# One output per environment, never one blob: a dev overlay's `replicas: 1` is a decoy and the prod
# overlay's is not, so every document keeps the root it came from.
#   render-<env>.yaml   the render exactly as it would apply, documents joined by an explicit `---`
#                       (a kustomize render does not start with one; `cat a b` glues two objects)
#   render-<env>.json   the same objects as one JSON array; each carries `__src`
#                       {env, origin, root, file, line, values} for <file:line> citations (Kustomize:
#                       line = the source document's first key, or the generator entry; null = no match)
#   render.err          every renderer's stderr, prefixed `[env]` (kustomize deprecations land here)
#   render-ledger.tsv   env · origin · objects · exit · stderr lines · root
#   inventory-platform.tsv  `helm install|upgrade|template` and `kubectl apply|create -f|-k` lines in
#                       runbooks, scripts, Makefiles and CI: file:line, release, chart, version,
#                       UNPINNED (no --version) or UNREAD(<var>) (a variable pin not resolved in the
#                       file), values files, namespace, notable flags (Helm 4 renames among them)
#   cd-targets.tsv      Argo CD Application/ApplicationSet and Flux Kustomization/HelmRelease objects, with the
#                       env each one deploys (or `-` when its source is not this repo)
#   embedded/src/       edge configs inside YAML (a Caddyfile or nginx.conf in a ConfigMap, a snippet
#                       annotation), line-preserving: embedded/src/a__b.yaml.conf:88 is a/b.yaml:88
#   embedded/<env>/     the same configs as each environment renders them (an overlay may patch them)
#   canary.yaml         two canaries every tool run reads beside the render: a removed-API PDB and a
#                       YAML-1.1 ConfigMap named `n`. A tool that reports neither did not read them.
#
# Offline by construction. KUBECONFIG points at an empty scratch file and Helm's homes at scratch
# dirs, so nothing here can reach the caller's kube context or helm repos. Nothing is written inside
# the repo: no `helm dependency update`, no `kustomize edit`. A kustomization with a remote resource
# is not fetched; its row is `blocked (remote base)` unless --allow-remote is given.
#
# Usage:  render.sh <repo-root> [--out=DIR] [--kube-version=1.36.0] [--api-versions=g/v,g/v]
#                   [--allow-remote] [--quiet]
#         render.sh --self-test
# Needs:  kustomize, or kubectl (its embedded kustomize); helm for charts; yq (mikefarah v4) + jq for
#         the JSON, the inventory of Argo/Flux objects and the embedded-config pass. A missing tool is
#         a NOT-INSTALLED ledger row, never a silent skip.
# Exit:   0 every render exited 0 · 3 at least one render failed or was blocked (all outputs still
#         written) · 2 usage · 4 no renderer at all.
# Shells: bash 3.2 and zsh (no arrays indexed, no mapfile, no `path`/`status` variables).

set -u
export LC_ALL=C

ROOT=""; OUT="${SCAN:-}"; KV="${TARGET_MINOR:-}"; APIV=""; REMOTE=0; QUIET=0; SELFTEST=0
for a in "$@"; do
  case "$a" in
    --out=*) OUT="${a#*=}" ;;
    --kube-version=*) KV="${a#*=}" ;;
    --api-versions=*) APIV="${a#*=}" ;;
    --allow-remote) REMOTE=1 ;;
    --quiet) QUIET=1 ;;
    --self-test) SELFTEST=1 ;;
    -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *) ROOT="$a" ;;
  esac
done
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- self-test ----------------------
if [ "$SELFTEST" -eq 1 ]; then
  ME="$0"; SH=bash; [ -n "${ZSH_VERSION:-}" ] && SH=zsh
  T="$(mktemp -d "${TMPDIR:-/tmp}/render-selftest.XXXXXX")"; F="$T/repo"; O="$T/out"
  trap 'rm -rf "$T"' EXIT
  mkdir -p "$F/k/base" "$F/k/overlays/prod" "$F/k/overlays/dev" "$F/k/remote" "$F/manifests" \
           "$F/chart/app/templates" "$F/apps" "$F/ops" "$F/node_modules/x"
  cat > "$F/k/base/kustomization.yaml" <<'EOF'
resources: [deploy.yaml, svc.yaml]
configMapGenerator:
  - name: edge
    files: [Caddyfile]
EOF
  cat > "$F/k/base/deploy.yaml" <<'EOF'
# the api Deployment (a head comment: the object starts on line 2)
apiVersion: apps/v1
kind: Deployment
metadata: {name: api}
spec:
  replicas: 2
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec: {containers: [{name: api, image: "r/api@sha256:00"}]}
EOF
  printf 'apiVersion: v1\nkind: Service\nmetadata: {name: api}\nspec: {selector: {app: api}, ports: [{port: 80}]}\n' > "$F/k/base/svc.yaml"
  printf ':80 {\n  reverse_proxy api:80\n}\n' > "$F/k/base/Caddyfile"
  printf 'resources: [../../base]\npatches:\n  - path: replicas.patch.yaml\n' > "$F/k/overlays/prod/kustomization.yaml"
  printf 'apiVersion: apps/v1\nkind: Deployment\nmetadata: {name: api}\nspec: {replicas: 4}\n' > "$F/k/overlays/prod/replicas.patch.yaml"
  printf 'apiVersion: networking.k8s.io/v1\nkind: NetworkPolicy\nmetadata: {name: deny}\nspec: {podSelector: {}, policyTypes: [Egress]}\n' > "$F/k/overlays/prod/np.yaml"
  printf 'resources: [../../base]\nreplicas: [{name: api, count: 1}]\n' > "$F/k/overlays/dev/kustomization.yaml"
  printf 'resources: ["https://github.com/example/none//base?ref=v1"]\n' > "$F/k/remote/kustomization.yaml"
  cat > "$F/manifests/edge.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata: {name: edge-conf}
data:
  nginx.conf: |
    server {
      listen 80;
    }
---
apiVersion: v1
kind: Namespace
metadata: {name: web}
EOF
  printf 'apiVersion: v1\nkind: ConfigMap\nmetadata: {name: ignored}\n' > "$F/node_modules/x/cm.yaml"
  printf 'apiVersion: v2\nname: app\nversion: 0.1.0\n' > "$F/chart/app/Chart.yaml"
  printf 'replicas: 1\n' > "$F/chart/app/values.yaml"
  printf 'replicas: 3\n' > "$F/chart/app/values-prod.yaml"
  cat > "$F/chart/app/templates/deploy.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: {{ .Release.Name }}-web}
spec:
  replicas: {{ .Values.replicas }}
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec: {containers: [{name: web, image: "r/web@sha256:00"}]}
EOF
  cat > "$F/apps/app.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: web, namespace: argocd}
spec:
  source: {repoURL: "https://git.example/repo", path: chart/app, targetRevision: HEAD, helm: {valueFiles: [values-prod.yaml]}}
  destination: {namespace: web}
  syncPolicy: {automated: {selfHeal: true, prune: true}}
EOF
  cat > "$F/ops/platform.md" <<'EOF'
```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace \
  --set controller.replicaCount=1 --atomic
helm upgrade --install metrics-server metrics-server/metrics-server --version 3.14.0 -n kube-system
kubectl apply -f k/overlays/prod/np.yaml
KEDA_VERSION=2.18.0
helm upgrade --install keda kedacore/keda --version "${KEDA_VERSION}" -n keda
CM_ARGS=(--version v1.18.2
  --set crds.enabled=true)
helm upgrade --install cert-manager jetstack/cert-manager "${CM_ARGS[@]}" -n cert-manager
helm upgrade --install reloader stakater/reloader --version "$RELOADER_VERSION" -n reloader
```
EOF
  # shellcheck disable=SC2034  # read inside the ok() eval strings below
  before="$(cd "$F" && find . -type f -exec cksum {} + | sort)"
  "$SH" "$ME" "$F" --out="$O" --kube-version=1.36.0 --quiet; rc=$?
  # shellcheck disable=SC2034
  after="$(cd "$F" && find . -type f -exec cksum {} + | sort)"
  fails=0; checks=0
  ok() { checks=$((checks + 1)); if eval "$2"; then printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); fi; }
  skip() { printf 'SKIP  %s\n' "$*"; }
  led() { awk -F'\t' -v e="$1" -v c="$2" '$1 == e { print $c }' "$O/render-ledger.tsv"; }
  ok "the repo tree is unchanged (nothing written in-tree)" '[ "$before" = "$after" ]'
  ok "exit 3: the remote base is blocked, not fetched" '[ "$rc" -eq 3 ]'
  ok "remote kustomization row reads blocked" '[ "$(led k__remote 4)" = "blocked" ]'
  if have kustomize || have kubectl; then
    ok "base renders 3 objects (Deployment, Service, generated ConfigMap)" '[ "$(led k__base 3)" = 3 ]'
    ok "base is tagged base, prod and dev overlay" '[ "$(led k__base 2)" = base ] && [ "$(led k__overlays__prod 2)" = overlay ] && [ "$(led k__overlays__dev 2)" = overlay ]'
    ok "every render file starts with an explicit ---" '[ "$(sed -n 2p "$O/render-k__overlays__prod.yaml")" = "---" ]'
    ok "an unreferenced manifest in a kustomize dir is its own raw env" '[ "$(led raw__k__overlays__prod 3)" = 1 ]'
    ok "node_modules is never rendered" '! find "$O" -name "render-*.yaml" -exec grep -l ignored {} + | grep -q .'
    if have yq && have jq; then
      ok "prod overlay JSON: Deployment replicas 4 from the patch" '[ "$(jq -r ".[] | select(.kind==\"Deployment\") | .spec.replicas" "$O/render-k__overlays__prod.json")" = 4 ]'
      ok "dev overlay JSON: replicas 1 from the transformer" '[ "$(jq -r ".[] | select(.kind==\"Deployment\") | .spec.replicas" "$O/render-k__overlays__dev.json")" = 1 ]'
      ok "__src.file of the prod Deployment is the base file" '[ "$(jq -r ".[] | select(.kind==\"Deployment\") | .__src.file" "$O/render-k__overlays__prod.json")" = k/base/deploy.yaml ]'
      ok "__src.line of the prod Deployment is its first key in the base file (line 2, after the comment)" '[ "$(jq -r ".[] | select(.kind==\"Deployment\") | .__src.line" "$O/render-k__overlays__prod.json")" = 2 ]'
      ok "__src.line of the generated ConfigMap is its generator entry (kustomization.yaml:3)" '[ "$(jq -r ".[] | select(.kind==\"ConfigMap\") | \"\(.__src.file):\(.__src.line)\"" "$O/render-k__overlays__prod.json")" = k/base/kustomization.yaml:3 ]'
      ok "the origin annotation is moved out of the object" '! grep -q "config.kubernetes.io/origin" "$O/render-k__overlays__prod.json"'
      ok "raw docs carry file and line" '[ "$(jq -r ".[] | select(.kind==\"Namespace\") | \"\(.__src.file):\(.__src.line)\"" "$O/render-raw__manifests.json")" = manifests/edge.yaml:10 ]'
      ok "embedded config extracted from the rendered ConfigMap (generator)" 'ls "$O/embedded/k__overlays__prod/" | grep -q Caddyfile'
      ok "Argo Application listed as a CD target with selfHeal" 'grep -q "selfHeal=true" "$O/cd-targets.tsv"'
      have helm && ok "the CD target row names the env it deploys (argo__web)" '[ "$(awk -F"\t" "NR == 2 { print \$NF }" "$O/cd-targets.tsv")" = argo__web ]'
    else skip "JSON checks: yq or jq not installed"; fi
  else skip "kustomize checks: neither kustomize nor kubectl installed"; fi
  if have helm; then
    ok "chart renders once per values file (default + values-prod)" '[ "$(led chart__chart__app__default 3)" = 1 ] && [ "$(led chart__chart__app__values-prod 3)" = 1 ]'
    if have yq && have jq; then
      ok "the values-prod render carries replicas 3 and its template path" '[ "$(jq -r ".[0] | \"\(.spec.replicas) \(.__src.file)\"" "$O/render-chart__chart__app__values-prod.json")" = "3 chart/app/templates/deploy.yaml" ]'
      ok "the Argo valueFiles render exists" '[ "$(led argo__web 3)" = 1 ]'
    fi
  else skip "helm checks: helm not installed"; fi
  ok "embedded source extraction keeps line numbers (nginx.conf body at line 6)" '[ "$(sed -n 6p "$O/embedded/src/manifests__edge.yaml.conf" | tr -d " ")" = "server{" ]'
  ok "inventory: ingress-nginx UNPINNED with the Helm-4-removed --atomic flag" 'grep "ingress-nginx/ingress-nginx" "$O/inventory-platform.tsv" | grep -q "UNPINNED" && grep "ingress-nginx/ingress-nginx" "$O/inventory-platform.tsv" | grep -q -- "--atomic"'
  ok "inventory: the continuation line is joined (the --set on the next line is read)" 'grep "ingress-nginx/ingress-nginx" "$O/inventory-platform.tsv" | grep -q "set=1"'
  ok "inventory: metrics-server pinned 3.14.0" 'grep "metrics-server/metrics-server" "$O/inventory-platform.tsv" | grep -q "3.14.0"'
  ok "inventory: --version from a variable resolves (keda 2.18.0, version-via)" 'grep "kedacore/keda" "$O/inventory-platform.tsv" | grep "2.18.0" | grep -q "version-via=\$KEDA_VERSION"'
  ok "inventory: --version inside a multi-line array resolves (cert-manager v1.18.2, args-from)" 'grep "jetstack/cert-manager" "$O/inventory-platform.tsv" | grep "v1.18.2" | grep -q "args-from=CM_ARGS"'
  ok "inventory: an unassigned version variable is UNREAD, not UNPINNED" 'grep "stakater/reloader" "$O/inventory-platform.tsv" | grep -q "UNREAD(\$RELOADER_VERSION)"'
  ok "inventory: the kubectl apply -f line is listed" 'grep -q "kubectl	apply" "$O/inventory-platform.tsv"'
  ok "canary.yaml holds the two canaries" '[ "$(grep -c "^kind:" "$O/canary.yaml")" = 2 ]'
  ok "KUBECONFIG was a scratch file, never the caller's" 'grep -q "kubeconfig=scratch" "$O/render-meta.txt"'
  printf '%s\n' "self-test ($SH): $((checks - fails))/$checks passed"
  [ "$fails" -eq 0 ]; exit $?
fi

# ---------------------------------------------------------------- setup --------------------------
[ -n "$ROOT" ] || { printf 'usage: render.sh <repo-root> [--out=DIR] [--kube-version=X.Y.Z]\n' >&2; exit 2; }
[ -d "$ROOT" ] || { printf 'not a directory: %s\n' "$ROOT" >&2; exit 2; }
ROOT="$(cd -P "$ROOT" && pwd)"
[ -n "$OUT" ] || OUT="$(mktemp -d "${TMPDIR:-/tmp}/k8s-render.XXXXXX")"
mkdir -p "$OUT" || exit 2
OUT="$(cd -P "$OUT" && pwd)"
case "$OUT/" in "$ROOT"/*) printf 'refusing --out inside the repo: %s\n' "$OUT" >&2; exit 2 ;; esac
mkdir -p "$OUT/embedded/src" "$OUT/.wrap" "$OUT/.helm/cache" "$OUT/.helm/config" "$OUT/.helm/data"
: > "$OUT/no-cluster.kubeconfig"
export KUBECONFIG="$OUT/no-cluster.kubeconfig"
export HELM_CACHE_HOME="$OUT/.helm/cache" HELM_CONFIG_HOME="$OUT/.helm/config" HELM_DATA_HOME="$OUT/.helm/data"
unset HELM_KUBECONTEXT HELM_NAMESPACE 2>/dev/null
: > "$OUT/render.err"
printf 'env\torigin\tobjects\texit\tstderr\troot\n' > "$OUT/render-ledger.tsv"
JSON=0; { have yq && have jq; } && JSON=1
KZ=""; if have kustomize; then KZ=kustomize; elif have kubectl; then KZ=kubectl; fi
{ printf 'root=%s\nkubeconfig=scratch (%s)\n' "$ROOT" "$KUBECONFIG"
  printf 'kustomize=%s\n' "$( [ "$KZ" = kustomize ] && kustomize version 2>/dev/null; [ "$KZ" = kubectl ] && printf 'kubectl-embedded '; [ -z "$KZ" ] && printf 'NOT-INSTALLED' )"
  printf 'helm=%s\n' "$(have helm && helm version --short 2>/dev/null || printf 'NOT-INSTALLED')"
  printf 'yq=%s\njq=%s\nkube-version=%s\n' "$(have yq && yq --version 2>/dev/null | awk '{print $NF}' || printf 'NOT-INSTALLED')" \
    "$(have jq && jq --version 2>/dev/null || printf 'NOT-INSTALLED')" "${KV:-unset (helm default)}"
} > "$OUT/render-meta.txt"

envname() { e="$(printf '%s' "${1#./}" | sed 's#/#__#g; s#[^A-Za-z0-9_.-]#-#g')"; [ -n "$e" ] && [ "$e" != "." ] && printf '%s' "$e" || printf 'root'; }
relpath() { r="${1#"$ROOT"/}"; [ "$r" = "$ROOT" ] && r="."; printf '%s' "$r"; }
ledger() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$OUT/render-ledger.tsv"; }
count_objs() {  # objects in a YAML stream (JSON when available, else top-level kind: lines)
  if [ "$JSON" -eq 1 ] && [ -s "$2" ]; then jq 'length' "$2"; else c="$(grep -c '^kind:' "$1" 2>/dev/null)"; printf '%s' "${c:-0}"; fi; }
errlines() { c="$(grep -c . "$1" 2>/dev/null)"; printf '%s' "${c:-0}"; }

# File discovery: never vendored, generated or dependency trees. Env-like dirs (dev, local, preview,
# ci-ephemeral) are NOT excluded; they are rendered and tagged, and the read step decides.
walk() {  # walk <name tests…>: files under ROOT, pruned dirs never entered (argv literal: no word splitting needed)
  find "$ROOT" \( -name node_modules -o -name .git -o -name vendor -o -name .terraform -o -name cdk.out -o -name .venv -o -name dist \
    -o -name build -o -name target -o -name __tests__ -o -name testdata -o -name fixtures -o -name __fixtures__ -o -name .claude -o -name .opencode \
    -o -name .cursor -o -name .codex -o -name .windsurf -o -name .gemini -o -name .kiro \) -prune -o -type f \( "$@" \) -print 2>/dev/null | sort; }
walk -name '*.yaml' -o -name '*.yml' -o -name Kustomization > "$OUT/.yaml-files"
grep -E '/(kustomization\.ya?ml|Kustomization)$' "$OUT/.yaml-files" > "$OUT/.kz-files" || :
grep -E '/Chart\.yaml$' "$OUT/.yaml-files" | grep -v '/charts/[^/]*/Chart\.yaml$' > "$OUT/.charts" || :

# ---------------------------------------------------------------- kustomize ----------------------
# Files and dirs each kustomization references, so a manifest no kustomization loads is rendered as
# its own `raw` env (applied by hand from a runbook, or stale) instead of vanishing.
: > "$OUT/.kz-refs"; : > "$OUT/.kz-dirs-referenced"
while IFS= read -r k; do
  d="$(dirname "$k")"
  if have yq; then
    yq -r '[.resources[]?, .bases[]?, .components[]?, .crds[]?, .patchesStrategicMerge[]?, (.patches[]? | select(type == "!!map") | .path),
            (.patchesJson6902[]? | .path), (.configMapGenerator[]?.files[]?), (.secretGenerator[]?.files[]?),
            (.configMapGenerator[]?.envs[]?), (.secretGenerator[]?.envs[]?), (.replacements[]? | .path)] | .[] | select(. != null)' "$k" 2>/dev/null
  else
    # No yq: block lists (`- a`) and one-line flow lists (`resources: [a, b]`) of resources/bases/components.
    awk '/^[^ #-]/{s=$1} s ~ /^(resources|bases|components):/ && /^ *- /{sub(/^ *- */,""); gsub(/["\047]/,""); print}
         /^(resources|bases|components):[ \t]*\[/ || /^[ \t-]*(files|envs):[ \t]*\[/{l=$0; sub(/^[^[]*\[/,"",l); sub(/\].*/,"",l); n=split(l,a,/,/)
           for(i=1;i<=n;i++){v=a[i]; gsub(/^[ \t"\047]+|[ \t"\047]+$/,"",v); if(v!="") print v}}
         /^[ \t-]*path:[ \t]*[^ \t]/{v=$0; sub(/^[ \t-]*path:[ \t]*/,"",v); sub(/[ \t]+#.*/,"",v); gsub(/["\047]/,"",v); print v}' "$k"
  fi | sed 's#^[^=]*=##' | while IFS= read -r ref; do
    case "$ref" in *://*|github.com/*|git@*) continue ;; esac
    t="$d/$ref"
    if [ -d "$t" ]; then (cd -P "$t" 2>/dev/null && pwd) >> "$OUT/.kz-dirs-referenced"
    elif [ -f "$t" ]; then printf '%s/%s\n' "$(cd -P "$(dirname "$t")" 2>/dev/null && pwd)" "$(basename "$t")" >> "$OUT/.kz-refs"; fi
  done
done < "$OUT/.kz-files"

kz_lines() {  # $1 render JSON: fill __src.line from the cited source file (kind + name; generators by entry)
  # The origin annotation names the file, never the line. Index every document of each cited file (kind, name,
  # first-key line) plus each configMapGenerator/secretGenerator entry, then match: the exact name, else the longest
  # source name the rendered name contains (namePrefix/nameSuffix/hash suffix), else the only document of that kind.
  # No match leaves line null: the citation is file-only, never a guessed line.
  # yq's `line` on a document with a head comment is off by one (measured, yq 4.54.1), so a document's line comes
  # from awk (the first top-level key after its `---`) joined on yq's document index `di`.
  jq -r '[.[] | select(.__src.line == null) | .__src.file // empty] | unique[]' "$1" 2>/dev/null | while IFS= read -r f; do
    [ -f "$ROOT/$f" ] || continue
    awk '/^---/ { if (s) i++; s = 1; next } /^[ \t]*(#|$)/ { next } { s = 1 } /^[A-Za-z_"]/ && !((i + 0) in L) { L[i + 0] = NR; print (i + 0) "\t" NR }' "$ROOT/$f" > "$OUT/.di"
    yq -o=json ea '[. | select(tag == "!!map") | {"k": (.kind // ""), "n": (.metadata.name // ""), "di": di}]
      + [(.configMapGenerator[]? | {"k": "ConfigMap", "n": (.name // ""), "l": line}), (.secretGenerator[]? | {"k": "Secret", "n": (.name // ""), "l": line})]' \
      "$ROOT/$f" 2>/dev/null | jq -c --arg f "$f" --rawfile d "$OUT/.di" '
        ($d | split("\n") | map(select(. != "") | split("\t") | {key: .[0], value: (.[1] | tonumber)}) | from_entries) as $dl
        | map(. + {f: $f} | if has("di") then .l = $dl[(.di | tostring)] else . end)'
  done | jq -s 'add // []' > "$OUT/.lines-idx.json" 2>/dev/null || return 0
  rm -f "$OUT/.di"
  jq --slurpfile ix "$OUT/.lines-idx.json" '($ix[0] // []) as $ix
    | map(if .__src.line == null and .__src.file != null then
        . as $o | [$ix[] | select(.f == $o.__src.file and .k == $o.kind)] as $c
        | (([$c[] | select(.n == $o.metadata.name)][0].l)
           // ([$c[] | select(.n != "") | . as $e | select($o.metadata.name | contains($e.n))] | sort_by(-(.n | length)) | .[0].l)
           // (if ($c | length) == 1 then $c[0].l else null end)) as $l
        | .__src.line = $l
      else . end)' "$1" > "$1.tmp" 2>/dev/null && [ -s "$1.tmp" ] && mv "$1.tmp" "$1"
  rm -f "$1.tmp" "$OUT/.lines-idx.json"; return 0
}

render_kz() {  # $1 dir → plain render (what applies) + origin-annotated render (for __src.file)
  d="$1"; env="$(envname "$(relpath "$d")")"; origin=overlay
  grep -qxF "$d" "$OUT/.kz-dirs-referenced" && origin=base
  kf="$(ls "$d"/kustomization.yaml "$d"/kustomization.yml "$d"/Kustomization 2>/dev/null | head -1)"
  if [ "$REMOTE" -eq 0 ] && sed 's/#.*//' "$kf" | grep -Eq '(https?://|git@|github\.com/|gitlab\.com/)'; then
    printf '[%s] blocked: remote resource in %s (not fetched; --allow-remote to fetch)\n' "$env" "$(relpath "$kf")" >> "$OUT/render.err"
    ledger "$env" "$origin" 0 blocked 1 "$(relpath "$d")"; return 3; fi
  y="$OUT/render-$env.yaml"; e="$OUT/.err-$env"; rm -f "$OUT/render-$env.json"
  { printf '# render-src: env=%s origin=%s root=%s renderer=%s\n' "$env" "$origin" "$(relpath "$d")" "$KZ"; printf -- '---\n'
    if [ "$KZ" = kustomize ]; then kustomize build "$d"; else kubectl kustomize "$d"; fi; } > "$y" 2> "$e"; rc=$?
  sed "s#^#[$env] #" "$e" >> "$OUT/render.err"
  if [ "$JSON" -eq 1 ] && [ "$rc" -eq 0 ]; then
    # A wrapper kustomization in $OUT adds buildMetadata: [originAnnotations]; the path to the root is
    # "../" × depth + the absolute path, so the annotation can be turned back into a repo path.
    w="$OUT/.wrap/$env"; mkdir -p "$w"; depth="$(printf '%s' "$w" | tr -cd '/' | wc -c | tr -d ' ')"
    up="$(i=0; while [ "$i" -lt "$depth" ]; do printf '../'; i=$((i + 1)); done)"
    printf 'resources: ["%s%s"]\nbuildMetadata: [originAnnotations]\n' "$up" "${d#/}" > "$w/kustomization.yaml"
    pre="$up${ROOT#/}/"
    if [ "$KZ" = kustomize ]; then kustomize build --load-restrictor LoadRestrictionsNone "$w"; else kubectl kustomize --load-restrictor LoadRestrictionsNone "$w"; fi 2>/dev/null \
      | yq -o=json ea '[.]' 2>/dev/null | jq --arg env "$env" --arg o "$origin" --arg root "$(relpath "$d")" --arg pre "$pre" '
        map(select(type == "object")
          | ((.metadata.annotations["config.kubernetes.io/origin"] // "") | capture("(?:path|configuredIn): *(?<p>[^\n]+)") | .p | ltrimstr($pre)) as $f
          | .__src = {env: $env, origin: $o, root: $root, file: ($f // null), line: null, values: null}
          | del(.metadata.annotations["config.kubernetes.io/origin"])
          | if (.metadata.annotations // {}) == {} then del(.metadata.annotations) else . end)' > "$OUT/render-$env.json" 2>/dev/null
    if [ -s "$OUT/render-$env.json" ]; then kz_lines "$OUT/render-$env.json"
    else yq -o=json ea '[.]' "$y" 2>/dev/null | jq --arg env "$env" --arg o "$origin" --arg root "$(relpath "$d")" \
      'map(select(type == "object") | .__src = {env: $env, origin: $o, root: $root, file: null, line: null, values: null})' > "$OUT/render-$env.json"; fi
  fi
  ledger "$env" "$origin" "$(count_objs "$y" "$OUT/render-$env.json")" "$rc" "$(errlines "$e")" "$(relpath "$d")"; rm -f "$e"
  return "$rc"
}

# ---------------------------------------------------------------- helm ---------------------------
render_helm() {  # $1 chart dir, $2 env, $3 origin, $4 values files, newline-separated (absolute)
  c="$1"; env="$2"; origin="$3"; vl="${4:-}"; rm -f "$OUT/render-$env.json"
  y="$OUT/render-$env.yaml"; e="$OUT/.err-$env"; rel="$(basename "$c")"
  vals="$(printf '%s\n' "$vl" | while IFS= read -r v; do [ -n "$v" ] && relpath "$v" && printf ','; done | sed 's/,$//')"
  { printf '# render-src: env=%s origin=%s root=%s values=%s renderer=helm\n' "$env" "$origin" "$(relpath "$c")" "${vals:-default}"
    helm_call "$c" "$rel" "$vl"; } > "$y" 2> "$e"; rc=$?
  sed "s#^#[$env] #" "$e" >> "$OUT/render.err"
  if [ "$JSON" -eq 1 ] && [ "$rc" -eq 0 ]; then
    # `# Source: <chart>/templates/x.yaml` precedes each document; pair it with the non-empty docs in order.
    awk '/^---/{ if (has) print src; has = 0; src = ""; next } /^# Source: /{ src = $3; next } /^[^#[:space:]]/{ has = 1 } END { if (has) print src }' "$y" > "$OUT/.src-$env"
    cbase="$(relpath "$(dirname "$c")")"
    yq -o=json ea '[.]' "$y" 2>/dev/null | jq --rawfile s "$OUT/.src-$env" --arg env "$env" --arg o "$origin" --arg root "$(relpath "$c")" --arg vals "$vals" --arg cb "$cbase" '
      ($s | split("\n")) as $src | map(select(type == "object")) | to_entries
      | map(.value + {__src: {env: $env, origin: $o, root: $root, line: null, values: (if $vals == "" then "default" else $vals end),
            file: ($src[.key] // "" | if . == "" then null elif $cb == "." then . else "\($cb)/\(.)" end)}})' > "$OUT/render-$env.json"
    rm -f "$OUT/.src-$env"
  fi
  ledger "$env" "$origin" "$(count_objs "$y" "$OUT/render-$env.json")" "$rc" "$(errlines "$e")" "$(relpath "$c")"; rm -f "$e"
  return "$rc"
}
helm_call() {  # $1 chart $2 release $3 values (newline-separated); argv built with set --, no arrays
  hc="$1"; hr="$2"; vl="$3"; set --
  while IFS= read -r v; do [ -n "$v" ] && set -- "$@" -f "$v"; done <<VALS
$vl
VALS
  [ -n "$KV" ] && set -- "$@" --kube-version "$KV"
  [ -n "$APIV" ] && set -- "$@" --api-versions "$APIV"
  printf -- '---\n'
  helm template "$hr" "$hc" "$@"
}

# ---------------------------------------------------------------- run renders --------------------
fail=0
if [ -s "$OUT/.kz-files" ] && [ -z "$KZ" ]; then
  printf 'NOT-INSTALLED: kustomize and kubectl (brew install kustomize) — every Kustomize root is blocked\n' >> "$OUT/render.err"
  while IFS= read -r k; do ledger "$(envname "$(relpath "$(dirname "$k")")")" kustomize 0 not-installed 0 "$(relpath "$(dirname "$k")")"; done < "$OUT/.kz-files"; fail=4
else
  while IFS= read -r k; do render_kz "$(cd -P "$(dirname "$k")" && pwd)" || fail=3; done < "$OUT/.kz-files"
fi
while IFS= read -r ch; do
  c="$(dirname "$ch")"; cr="$(relpath "$c")"
  if ! have helm; then ledger "$(envname "chart/$cr")" chart 0 not-installed 0 "$cr"; fail=3; continue; fi
  render_helm "$c" "chart__$(envname "$cr")__default" chart "" || fail=3
  find "$c" -maxdepth 1 -type f \( -name 'values-*.y*ml' -o -name 'values.*.y*ml' -o -name 'values_*.y*ml' -o -name '*.values.y*ml' \) 2>/dev/null | sort |
    while IFS= read -r v; do b="$(basename "$v")"; render_helm "$c" "chart__$(envname "$cr")__${b%.y*ml}" chart "$v" || printf 'x\n' > "$OUT/.helm-fail"; done
done < "$OUT/.charts"
[ -f "$OUT/.helm-fail" ] && { fail=3; rm -f "$OUT/.helm-fail"; }

# Raw manifests: Kubernetes-shaped YAML that no kustomization loads and no chart owns.
# Grouped one env per directory. Tool configs that only look like objects are skipped.
cat "$OUT/.charts" | while IFS= read -r ch; do dirname "$ch"; done > "$OUT/.chart-dirs"
: > "$OUT/.raw"
while IFS= read -r f; do
  case "$f" in */kustomization.y*ml|*/Kustomization|*/Chart.yaml|*/values*.y*ml|*-values.y*ml|*/.github/*|*/.gitlab-ci.yml) continue ;; esac
  inchart=0; while IFS= read -r cd; do case "$f" in "$cd"/*) inchart=1 ;; esac; done < "$OUT/.chart-dirs"
  [ "$inchart" -eq 1 ] && continue
  grep -qxF "$f" "$OUT/.kz-refs" && continue
  grep -Eq '^kind:[[:space:]]*[A-Za-z]' "$f" || continue
  grep -Eq '^apiVersion:[[:space:]]*[a-z]' "$f" || continue
  grep -Eq '^apiVersion:[[:space:]]*(kustomize\.config\.k8s\.io|kind\.x-k8s\.io|config\.kubernetes\.io|skaffold/|k3d\.io|ctlptl\.dev|kubeadm\.k8s\.io|kubelet\.config\.k8s\.io|kubeproxy\.config\.k8s\.io|apiserver\.config\.k8s\.io)' "$f" && continue
  printf '%s\n' "$f" >> "$OUT/.raw"
done < "$OUT/.yaml-files"
sed 's#/[^/]*$##' "$OUT/.raw" | sort -u | while IFS= read -r d; do
  env="raw__$(envname "$(relpath "$d")")"; y="$OUT/render-$env.yaml"
  note=""; [ -n "$(ls "$d"/kustomization.yaml "$d"/kustomization.yml "$d"/Kustomization 2>/dev/null)" ] && note=" (in a kustomize dir but not loaded by it: applied by hand, or stale)"
  printf '# render-src: env=%s origin=raw root=%s%s\n' "$env" "$(relpath "$d")" "$note" > "$y"
  grep -F "$d/" "$OUT/.raw" | awk -F/ -v n="$(printf '%s' "$d" | awk -F/ '{print NF}')" 'NF == n + 1' | while IFS= read -r f; do
    printf -- '---\n# render-src: file=%s\n' "$(relpath "$f")"; sed '1{/^---[[:space:]]*$/d;}' "$f"; printf '\n'; done >> "$y"
  if [ "$JSON" -eq 1 ]; then
    grep -F "$d/" "$OUT/.raw" | awk -F/ -v n="$(printf '%s' "$d" | awk -F/ '{print NF}')" 'NF == n + 1' | while IFS= read -r f; do
      yq -o=json ea '[. | select(tag == "!!map") | . as $d | {"d": $d, "l": line}]' "$f" 2>/dev/null |
        jq --arg f "$(relpath "$f")" 'map(.d + {__src: {file: $f, line: .l}})'; done |
      jq -s --arg env "$env" --arg root "$(relpath "$d")" 'add // [] | map(select(.kind != null) | .__src += {env: $env, origin: "raw", root: $root, values: null})' > "$OUT/render-$env.json"
  fi
  ledger "$env" raw "$(count_objs "$y" "$OUT/render-$env.json")" 0 0 "$(relpath "$d")"
done

# ---------------------------------------------------------------- CD targets (Argo / Flux) -------
printf 'kind\tns/name\tsource\tpath_or_chart\trevision\tvalues\tdestination\tsync\tfile\n' > "$OUT/cd-targets.tsv"
if [ "$JSON" -eq 1 ]; then
  find "$OUT" -maxdepth 1 -name 'render-*.json' | sort | while IFS= read -r j; do jq -c '.[]' "$j"; done | jq -rs '
    unique_by([.kind, (.metadata.namespace // ""), .metadata.name, .__src.file])[]
    | select((.apiVersion | startswith("argoproj.io/")) and (.kind == "Application" or .kind == "ApplicationSet")
             or (.apiVersion | test("^(kustomize|helm)\\.toolkit\\.fluxcd\\.io/")) and (.kind == "Kustomization" or .kind == "HelmRelease"))
    | (.spec.source // (.spec.sources // [])[0] // .spec.template.spec.source // {}) as $s
    | [ .kind, "\(.metadata.namespace // "-")/\(.metadata.name)",
        ($s.repoURL // .spec.sourceRef.name // .spec.chart.spec.sourceRef.name // "-"),
        ($s.path // $s.chart // .spec.path // .spec.chart.spec.chart // "-"),
        ($s.targetRevision // .spec.chart.spec.version // "-"),
        ((($s.helm.valueFiles // []) | join(",")) + (if .spec.postBuild.substitute or .spec.postBuild.substituteFrom then " postBuild=substitute" else "" end) | if . == "" then "-" else . end),
        "\(.spec.destination.server // .spec.destination.name // "-")/\(.spec.destination.namespace // .spec.targetNamespace // "-")",
        "selfHeal=\(.spec.syncPolicy.automated.selfHeal // false) prune=\(.spec.syncPolicy.automated.prune // .spec.prune // false) ignoreDiff=\((.spec.ignoreDifferences // []) | length) opts=\((.spec.syncPolicy.syncOptions // []) | join(","))",
        (.__src.file // "-") ] | @tsv' >> "$OUT/cd-targets.tsv"
  # An Argo Application whose path is a chart in this repo renders as its own env, with its valueFiles.
  awk -F'\t' 'NR > 1 && $1 == "Application" && $4 != "-"' "$OUT/cd-targets.tsv" | while IFS="$(printf '\t')" read -r _k nn _src pth _rev vf _rest; do
    [ -f "$ROOT/$pth/Chart.yaml" ] || continue
    if have helm; then
      vlist="$(printf '%s' "${vf%% postBuild*}" | tr ',' '\n' | while IFS= read -r v; do [ -n "$v" ] && [ "$v" != "-" ] && printf '%s\n' "$ROOT/$pth/$v"; done)"
      render_helm "$ROOT/$pth" "argo__$(envname "${nn#*/}")" argo "$vlist" || printf 'x\n' > "$OUT/.helm-fail"
    fi
  done
  [ -f "$OUT/.helm-fail" ] && { fail=3; rm -f "$OUT/.helm-fail"; }
fi
# Last column: the env this target deploys (argo__<app> for a chart rendered above, the Kustomize env whose root is the
# target's path), or `-` when the target is not in this repo. §4's joins key on it.
awk -F'\t' -v OFS='\t' 'NR == FNR { if (FNR > 1) { e[$6] = $1; if ($2 == "argo") a[$1] = 1 } next }
  FNR == 1 { print $0, "env"; next }
  { p = $4; sub(/^\.\//, "", p); sub(/\/$/, "", p); n = $2; sub(/^[^\/]*\//, "", n); gsub(/[^A-Za-z0-9_.-]/, "-", n)
    print $0, (("argo__" n) in a ? "argo__" n : (p in e ? e[p] : "-")) }' "$OUT/render-ledger.tsv" "$OUT/cd-targets.tsv" > "$OUT/.cd" && mv "$OUT/.cd" "$OUT/cd-targets.tsv"

# ---------------------------------------------------------------- platform inventory -------------
# Components installed outside the render are in scope (precedent 45): their chart defaults are their
# config. Continuation lines are joined; tokens are whitespace-split (one level of quotes is stripped).
# A --version (or a chart/release) given as a variable is resolved from the same file: a shell, Make or YAML
# `env:` assignment, a `${V:-default}`, a GitHub `${{ env.V }}`, or an array spliced in with "${ARGS[@]}"
# (one-line or multi-line `ARGS=( … )` / `ARGS+=( … )`). Resolved → the literal plus `version-via=<V>` in
# flags. Unresolved → `UNREAD(<expression>)`: a pin whose value was not read, never UNPINNED
# (precedents/infrastructure.md § 63). A name assigned two different literals in one file stays UNREAD.
printf 'file:line\ttool\tverb\trelease\tchart\tversion\tvalues\tnamespace\tflags\n' > "$OUT/inventory-platform.tsv"
walk -name '*.md' -o -name '*.sh' -o -name '*.bash' -o -name Makefile -o -name '*.mk' -o -name Justfile -o -name justfile \
     -o -name 'Taskfile*.y*ml' -o -name Jenkinsfile -o -name '.gitlab-ci.yml' -o -path '*/.github/workflows/*' \
     -o -path '*/.circleci/*' -o -path '*/.buildkite/*' | while IFS= read -r f; do
  grep -Eq '(helm[[:space:]]+(upgrade|install|template)|kubectl[[:space:]]+(apply|create)[[:space:]])' "$f" || continue
  awk -v F="$(relpath "$f")" -v Q="'" '
    function unq(s,   a, z) { a = substr(s, 1, 1); z = substr(s, length(s), 1)
      if (length(s) >= 2 && (a == "\"" || a == Q) && z == a) return substr(s, 2, length(s) - 2)
      if (a == "\"" || a == Q) return substr(s, 2); if (z == "\"" || z == Q) return substr(s, 1, length(s) - 1); return s }
    function setvar(nm, val) { val = unq(val); if (val == "") return
      if ((nm in vars) && vars[nm] != val) amb[nm] = 1; vars[nm] = val }
    function addarr(nm, s) { gsub(/\\[ \t]*$/, "", s); arr[nm] = arr[nm] " " s }
    function resolve(tok,   k, nm, d, e) {  # literal value, or "" (RN = what was not read)
      tok = unq(tok); RN = ""
      for (k = 0; k < 4; k++) {
        if (substr(tok, 1, 1) != "$") return tok
        d = ""; e = tok
        if (e ~ /^\$\{\{/) { gsub(/^\$\{\{[ \t]*|[ \t]*\}\}$/, "", e); if (RN == "") RN = "${{" e "}}"
          if (e !~ /^env\.[A-Za-z_][A-Za-z0-9_]*$/) return ""; nm = substr(e, 5) }
        else if (e ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*(:?-[^}]*)?\}$/) { nm = substr(e, 3, length(e) - 3)
          if (match(nm, /:?-/)) { d = substr(nm, RSTART + RLENGTH); nm = substr(nm, 1, RSTART - 1) } }
        else if (e ~ /^\$\([A-Za-z_][A-Za-z0-9_]*\)$/ || e ~ /^\$[A-Za-z_][A-Za-z0-9_]*$/) { nm = e; gsub(/^\$\(?|\)$/, "", nm) }
        else { if (RN == "") RN = tok; return "" }
        if (RN == "") RN = "$" nm
        if (nm in amb) return ""
        if (nm in vars) tok = vars[nm]; else if (d != "") { tok = d; RN = RN "(default)" } else return ""
      }
      return "" }
    # Pass 1 over the file: assignments and arrays (shell, Make, YAML env maps).
    NR == FNR {
      l = $0; sub(/^[ \t]*(export|readonly|local|declare([ \t]+-[A-Za-z]+)?)[ \t]+/, "", l); sub(/^[ \t]*/, "", l)
      if (inarr != "") { s = l; if (s ~ /\)/) { sub(/\).*/, "", s); addarr(inarr, s); inarr = "" } else addarr(inarr, s); next }
      if (match(l, /^[A-Za-z_][A-Za-z0-9_]*\+?=\(/)) { nm = substr(l, 1, RLENGTH - 2); sub(/\+$/, "", nm); s = substr(l, RLENGTH + 1)
        if (s ~ /\)/) { sub(/\).*/, "", s); addarr(nm, s) } else { addarr(nm, s); inarr = nm }; next }
      if (match(l, /^[A-Za-z_][A-Za-z0-9_]*=/)) { nm = substr(l, 1, RLENGTH - 1); s = substr(l, RLENGTH + 1)
        if (substr(s, 1, 1) == "\"" || substr(s, 1, 1) == Q) { c = substr(s, 1, 1); s = substr(s, 2); sub(c ".*", "", s) } else sub(/[ \t;#].*/, "", s)
        setvar(nm, s); next }
      if (match(l, /^[A-Za-z_][A-Za-z0-9_]*[ \t]*(\?|:|::)?=[ \t]*/)) { nm = l; sub(/[ \t]*(\?|:|::)?=.*/, "", nm); s = substr(l, RLENGTH + 1); sub(/[ \t]*(#.*)?$/, "", s)
        if (s !~ /[ \t]/) setvar(nm, s); next }
      if (l ~ /^[A-Z][A-Z0-9_]*:[ \t]*[^ \t{}|>]+[ \t]*$/) { nm = l; sub(/:.*/, "", nm); s = l; sub(/^[^:]*:[ \t]*/, "", s); sub(/[ \t]*$/, "", s); setvar(nm, s) }
      next }
    function flush(   n, t, i, j, tool, verb, rel, ch, ver, vtok, vals, ns, fl, pos, v, nsets, ex, an, spl, unk, r) {
      n = split(cmd, t, /[ \t]+/); ex = ""; spl = ""; unk = ""
      for (j = 1; j <= n; j++) { v = unq(t[j])
        if (v ~ /^\$\{[A-Za-z_][A-Za-z0-9_]*\[[@*]\]\}$/) { an = substr(v, 3); sub(/\[.*/, "", an)
          if (an in arr) { ex = ex " " arr[an]; spl = spl (spl ? "," : "") an } else unk = unk (unk ? "," : "") "${" an "[@]}"; continue }
        ex = ex " " t[j] }
      n = split(ex, t, /[ \t]+/); tool = ""; i = 1
      while (i < n && !((t[i] == "helm" && t[i + 1] ~ /^(upgrade|install|template)$/) || (t[i] == "kubectl" && t[i + 1] ~ /^(apply|create)$/))) i++
      if (i >= n) return
      tool = t[i]; verb = t[i + 1]; i += 2; rel = ch = ns = vals = fl = vtok = ""; ver = "UNPINNED"; pos = 0; nsets = 0
      for (; i <= n; i++) {
        v = t[i]; if (v == "" || v ~ /^(#|&&|\|\||;|\||>|2>)/) break
        if (v ~ /^--version=/) { vtok = substr(v, 11); continue }
        if (v == "--version") { vtok = t[++i]
          if (vtok ~ /^"?\$\{\{/) while (vtok !~ /\}\}"?$/ && i < n) vtok = vtok " " t[++i]
          continue }
        if (v == "-f" || v == "--values" || v == "-k" || v == "--filename" || v == "--kustomize") { vals = vals (vals ? "," : "") t[++i]; continue }
        if (v ~ /^(--values|--filename|--kustomize)=/) { sub(/^[^=]*=/, "", v); vals = vals (vals ? "," : "") v; continue }
        if (v == "-n" || v == "--namespace") { ns = t[++i]; continue }
        if (v ~ /^--namespace=/) { ns = substr(v, 13); continue }
        if (v ~ /^--set(-string|-file|-json)?$/) { nsets++; i++; continue }
        if (v ~ /^--(atomic|force|force-replace|rollback-on-failure|wait|wait-for-jobs|server-side|create-namespace|reuse-values|reset-then-reuse-values|cleanup-on-fail|install|dry-run|kube-context|context|kubeconfig|devel)(=.*)?$/) {
          fl = fl (fl ? " " : "") v; if (v ~ /^--(kube-context|context|kubeconfig|timeout)$/) i++; continue }
        if (v ~ /^--(timeout|repo|description|post-renderer|history-max|kube-version|api-versions)$/) { i++; continue }
        if (v ~ /^-/) continue
        pos++; if (pos == 1) rel = v; else if (pos == 2) ch = v
      }
      if (rel != "") { r = resolve(rel); if (r != "") rel = r }
      if (ch != "") { r = resolve(ch); if (r != "") ch = r }
      if (vtok != "") { r = resolve(vtok)
        if (r != "") { ver = r; if (RN != "") fl = fl (fl ? " " : "") "version-via=" RN } else ver = "UNREAD(" RN ")" }
      else if (unk != "") ver = "UNREAD(" unk ")"
      if (spl != "") fl = fl (fl ? " " : "") "args-from=" spl
      if (tool == "helm" && verb == "template" && ch == "") ch = rel
      if (tool == "kubectl") { if (vals == "") return; ver = "-"; ch = "-"; rel = "-" }
      if (nsets) fl = fl (fl ? " " : "") "set=" nsets
      printf "%s:%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", F, start, tool, verb, rel ? rel : "-", ch ? ch : "-", ver, vals ? vals : "-", ns ? ns : "-", fl ? fl : "-"
    }
    {
      line = $0
      if (cont) { sub(/^[ \t]+/, "", line); cmd = cmd " " line } else {
        if (line !~ /(^|[ \t$`(]|run:[ \t]*)(helm[ \t]+(upgrade|install|template)|kubectl[ \t]+(apply|create)[ \t])/) next
        cmd = line; start = FNR }
      if (cmd ~ /\\[ \t]*$/) { sub(/\\[ \t]*$/, "", cmd); cont = 1; next }
      cont = 0; flush()
    }' "$f" "$f" >> "$OUT/inventory-platform.tsv"
done

# ---------------------------------------------------------------- embedded configs ---------------
# Source pass (the iac-scan 1e technique): every line outside a config block prints empty, so the
# extracted copy keeps the source's line numbers.
EK='^ *(- +)?"?(Caddyfile|[A-Za-z0-9_.-]+\.(conf|caddy|caddyfile|cfg)|nginx\.ingress\.kubernetes\.io/(server|configuration|stream)-snippet)"? *: *[|>]'
while IFS= read -r f; do
  grep -Eq "$EK" "$f" || continue
  awk -v re="$EK" 'b { if ($0 ~ /^[ \t]*$/) { print ""; next } match($0, /^ */); if (RLENGTH > k) { print substr($0, k + 1); next } b = 0 }
    $0 ~ re { match($0, /^ */); k = RLENGTH; b = 1 } { print "" }' "$f" > "$OUT/embedded/src/$(relpath "$f" | sed 's#/#__#g').conf"
done < "$OUT/.yaml-files"
# Render pass: the configs as each environment deploys them (generator files and overlay patches included).
if [ "$JSON" -eq 1 ]; then
  find "$OUT" -maxdepth 1 -name 'render-*.json' | sort | while IFS= read -r j; do
    env="$(basename "$j" .json)"; env="${env#render-}"
    jq -r '.[] | select(.kind == "ConfigMap") | . as $c | (.data // {}) | keys[]
           | select(test("^(Caddyfile|.*\\.(conf|caddy|caddyfile|cfg)|haproxy.*|envoy.*\\.ya?ml|traefik.*\\.ya?ml)$"; "i"))
           | "\($c.metadata.namespace // "default")\t\($c.metadata.name)\t\(.)"' "$j" 2>/dev/null |
      while IFS="$(printf '\t')" read -r ns nm key; do
        mkdir -p "$OUT/embedded/$env"
        jq -r --arg ns "$ns" --arg n "$nm" --arg k "$key" '.[] | select(.kind == "ConfigMap" and (.metadata.namespace // "default") == $ns and .metadata.name == $n) | .data[$k]' "$j" \
          > "$OUT/embedded/$env/${ns}__${nm}__${key}"
      done
  done
fi

# ---------------------------------------------------------------- canaries -----------------------
cat > "$OUT/canary.yaml" <<'EOF'
---
# canary 1: policy/v1beta1 was removed in Kubernetes 1.25. A schema tool must report it as an error.
# Reported `skipped` (kubeconform -ignore-missing-schemas) or not at all (kube-linter) = the tool
# drops what it cannot decode, so every removed API in the render was dropped the same way.
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata: {name: refract-canary-removed-api, namespace: refract-canary}
spec: {minAvailable: 1, selector: {matchLabels: {app: refract-canary}}}
---
# canary 2: metadata.name is the string "n". A YAML-1.1 decoder reads it as boolean false and either
# drops the object or names it "false"; such a tool misreads every `on`/`off`/`yes`/`no`/`y`/`n`.
apiVersion: v1
kind: ConfigMap
metadata:
  name: n
  namespace: refract-canary
data:
  enabled: "yes"
EOF

# ---------------------------------------------------------------- ledger -------------------------
rm -rf "$OUT/.wrap" "$OUT/.yaml-files" "$OUT/.kz-files" "$OUT/.kz-refs" "$OUT/.kz-dirs-referenced" "$OUT/.charts" "$OUT/.chart-dirs" "$OUT/.raw"
if [ "$QUIET" -eq 0 ]; then
  say "render.sh — $(tr '\n' ' ' < "$OUT/render-meta.txt")"
  column -t -s "$(printf '\t')" "$OUT/render-ledger.tsv" 2>/dev/null || cat "$OUT/render-ledger.tsv"
  envs="$(awk 'NR > 1' "$OUT/render-ledger.tsv" | wc -l | tr -d ' ')"; objs="$(awk -F'\t' 'NR > 1 { s += $3 } END { print s + 0 }' "$OUT/render-ledger.tsv")"
  h="$(awk -F'\t' 'NR > 1 && $2 == "helm"' "$OUT/inventory-platform.tsv" | wc -l | tr -d ' ')"
  u="$(awk -F'\t' 'NR > 1 && $2 == "helm" && $6 == "UNPINNED"' "$OUT/inventory-platform.tsv" | wc -l | tr -d ' ')"
  ur="$(awk -F'\t' 'NR > 1 && $2 == "helm" && $6 ~ /^UNREAD/' "$OUT/inventory-platform.tsv" | wc -l | tr -d ' ')"
  k="$(awk -F'\t' 'NR > 1 && $2 == "kubectl"' "$OUT/inventory-platform.tsv" | wc -l | tr -d ' ')"
  say "envs: $envs · objects rendered: $objs · stderr lines: $(errlines "$OUT/render.err") (read render.err)"
  say "platform inventory: $h helm lines ($u UNPINNED, $ur UNREAD: a pin whose value was not read) · $k kubectl apply/create lines → inventory-platform.tsv"
  say "cd targets: $(awk 'NR > 1' "$OUT/cd-targets.tsv" | wc -l | tr -d ' ') → cd-targets.tsv · embedded configs: $(ls "$OUT/embedded/src" | wc -l | tr -d ' ') source, $(find "$OUT/embedded" -mindepth 2 -type f ! -path '*/src/*' | wc -l | tr -d ' ') rendered"
  [ "$JSON" -eq 1 ] || say "NOT-INSTALLED: yq and/or jq (brew install yq jq) — no render-*.json; the jq detectors are blocked"
  say "canaries: canary.yaml (2 objects) — pass it to every tool beside the render; outputs in $OUT"
fi
exit "$fail"
