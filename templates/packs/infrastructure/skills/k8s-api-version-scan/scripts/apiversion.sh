#!/usr/bin/env bash
# apiversion.sh — k8s-api-version-scan § 1–§ 4 over k8s-render-scan's render, offline.
#
# Reads $SCAN/render-<env>.{yaml,json}, $SCAN/canary.yaml and $SCAN/inventory-platform.tsv (render.sh wrote them).
#   § 1  removed / deprecated apiVersions at the oldest and newest target minor: a static table (offline
#        corroboration) + pluto --target-versions (the maintained table; never kubent, precedents § 55)
#   § 2  schema + CRDs: kubeconform -strict against LOCAL schemas only. --fetch-schemas fills $SCAN/schemas once
#        (credential-free HTTPS, pinned refs) for exactly the GVKs the render holds; the repo's own CRDs are
#        converted locally. Never -ignore-missing-schemas: it reports an object it never read as `skipped`.
#        YAML-1.1 plain scalars (y/n/yes/no/on/off) the schema tools coerce are listed for the read step.
#   § 3  admission: Pod Security labels vs the namespace's own workloads; the repo's Kyverno / VAP policies
#        through `kyverno apply` offline, on the resources it can map (the rest are NOT-RUN, counted)
#   § 4  support status: the target minor against the supported window (a dated table, re-read at audit
#        time); ingress-nginx in the render or the platform inventory; controller pins to read
# Prints one TSV row per candidate:  §  CLASS  env  origin  Kind/ns/name  detail  source-file[:line]
# Writes $SCAN/apiversion-ledger.tsv: tool · version · status · objects read · objects expected · canaries.
#
# Usage:  apiversion.sh <scan-dir> --target=<oldest>[,<newest>] [--schemas=<dir>] [--fetch-schemas]
#                       [--catalog-ref=<sha>] [--today=YYYY-MM-DD]
#         apiversion.sh --self-test
# Needs:  jq; yq (mikefarah v4) for the YAML-1.1 pass and Kyverno input; pluto, kubeconform, kyverno when
#         present (each absent tool is a NOT-INSTALLED ledger row). KUBECONFIG is forced to an empty scratch
#         file for the whole run: nothing here can reach a cluster. Exit: 0 ran · 2 usage · 4 no render.
# Shells: bash 3.2 and zsh-safe.

set -u
export LC_ALL=C
SCAN=""; TARGET=""; SCHEMAS=""; FETCH=0; SELFTEST=0; TODAY="$(date +%Y-%m-%d)"
CATALOG_REF="63669a570e231d4f1f8396d229a1de512bcf0a34"   # datreeio/CRDs-catalog main, 2026-10-08
CORE_REF="5f1fa4f7908afc9b6641c62d282a4a22437626e1"      # yannh/kubernetes-json-schema master, 2026-10-09
for a in "$@"; do
  case "$a" in
    --target=*) TARGET="${a#*=}" ;;
    --schemas=*) SCHEMAS="${a#*=}" ;;
    --fetch-schemas) FETCH=1 ;;
    --catalog-ref=*) CATALOG_REF="${a#*=}" ;;
    --today=*) TODAY="${a#*=}" ;;
    --self-test) SELFTEST=1 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    -*) printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *) SCAN="$a" ;;
  esac
done
have() { command -v "$1" >/dev/null 2>&1; }

# Removed group-versions (kubernetes.io deprecation guide; research B § 2, 2026-10-10). pluto is the maintained
# table; this one keeps § 1 alive offline and corroborates it. Format: regex on "apiVersion kind" → minor removed.
read -r -d '' REMOVED <<'EOF'
^extensions/v1beta1 Ingress$	22
^extensions/v1beta1 	16
^apps/v1beta[12] 	16
^networking\.k8s\.io/v1beta1 (Ingress|IngressClass)$	22
^(rbac\.authorization|admissionregistration|apiextensions|apiregistration|certificates|coordination|scheduling)\.k8s\.io/v1beta1 	22
^storage\.k8s\.io/v1beta1 (CSIDriver|CSINode|StorageClass|VolumeAttachment)$	22
^(batch/v1beta1 CronJob|discovery\.k8s\.io/v1beta1 EndpointSlice|events\.k8s\.io/v1beta1 Event|autoscaling/v2beta1 HorizontalPodAutoscaler|node\.k8s\.io/v1beta1 RuntimeClass)$	25
^policy/v1beta1 (PodDisruptionBudget|PodSecurityPolicy)$	25
^(autoscaling/v2beta2 HorizontalPodAutoscaler|flowcontrol\.apiserver\.k8s\.io/v1beta1 .*)$	26
^storage\.k8s\.io/v1beta1 CSIStorageCapacity$	27
^flowcontrol\.apiserver\.k8s\.io/v1beta2 	29
^flowcontrol\.apiserver\.k8s\.io/v1beta3 	32
EOF

# Supported minors and their end of life (kubernetes.io/releases, read 2026-10-10; precedents § 62). Re-read at audit time.
SUPPORT_DATE="2026-10-10"
read -r -d '' SUPPORT <<'EOF'
34	2026-10-27
35	2027-02-28
36	2027-06-28
37	2027-10-28
EOF

minor() { printf '%s' "$1" | sed -E 's/^v?1\.([0-9]+).*/\1/'; }

read -r -d '' JQLIB <<'JQEOF'
def ns: (.metadata.namespace // "");
def oid: "\(.kind)/\(if ns == "" then "-" else ns end)/\(.metadata.name)";
def srcref: "\(.__src.file // "?")\(if (.__src.line // null) != null then ":\(.__src.line)" else "" end)";
def row($s; $c; $d): [$s, $c, (.__src.env // "?"), (.__src.origin // "?"), oid, $d, srcref] | @tsv;
def iswl: .kind | IN("Deployment","StatefulSet","DaemonSet","ReplicaSet","Job","CronJob","Rollout","Pod");
def tpl: if .kind == "CronJob" then (.spec.jobTemplate.spec.template // {}) elif .kind == "Pod" then {metadata: .metadata, spec: .spec} else (.spec.template // {}) end;
def ps: (tpl.spec // {});
def everyc: (ps.containers // [])[], (ps.initContainers // [])[];
JQEOF

# ---------------------------------------------------------------- self-test ----------------------
if [ "$SELFTEST" -eq 1 ]; then
  ME="$0"; SH=bash; [ -n "${ZSH_VERSION:-}" ] && SH=zsh
  T="$(mktemp -d "${TMPDIR:-/tmp}/apiversion-selftest.XXXXXX")"; trap 'rm -rf "$T"' EXIT
  cat > "$T/render-prod.yaml" <<'EOF'
# render-src: env=prod origin=raw root=k
---
apiVersion: v1
kind: Namespace
metadata:
  name: pay
  labels: {pod-security.kubernetes.io/enforce: restricted}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: api, namespace: pay}
spec:
  selector: {matchLabels: {app: api}}
  template:
    metadata: {labels: {app: api}}
    spec:
      containers:
        - {name: api, image: "r/api@sha256:0", env: [{name: DEBUG, value: no}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: ok, namespace: pay}
spec:
  selector: {matchLabels: {app: ok}}
  template:
    metadata: {labels: {app: ok}}
    spec:
      securityContext: {runAsNonRoot: true, seccompProfile: {type: RuntimeDefault}}
      containers:
        - name: ok
          image: "r/ok@sha256:0"
          securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}
---
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata: {name: api, namespace: pay}
spec: {scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: api}, minReplicas: 2, maxReplicas: 4}
---
apiVersion: v1
kind: Pod
metadata: {name: old, namespace: tools}
spec:
  containers: [{name: c, image: "r/c@sha256:0"}]
  volumes: [{name: g, gitRepo: {repository: "https://example.com/r.git"}}]
---
apiVersion: apps/v1
kind: DaemonSet
metadata: {name: ingress-nginx-controller, namespace: ingress}
spec:
  selector: {matchLabels: {app: in}}
  template:
    metadata: {labels: {app: in}}
    spec: {containers: [{name: controller, image: "registry.k8s.io/ingress-nginx/controller:v1.15.1"}]}
EOF
  yq -o=json ea '[. | select(tag == "!!map") | . + {"__src": {"env": "prod", "origin": "raw", "file": "k/all.yaml", "line": line}}]' "$T/render-prod.yaml" > "$T/render-prod.json"
  cat > "$T/render-platform.yaml" <<'EOF'
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: {name: need-team}
spec:
  rules:
    - name: team-label
      match: {any: [{resources: {kinds: [Deployment]}}]}
      validate: {failureAction: Enforce, message: "team label required", pattern: {metadata: {labels: {team: "?*"}}}}
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: {name: no-latest}
spec:
  matchConstraints: {resourceRules: [{apiGroups: [apps], apiVersions: [v1], operations: [CREATE, UPDATE], resources: [deployments]}]}
  validations: [{expression: "object.spec.template.spec.containers.all(c, !c.image.endsWith(':latest'))", message: "no latest"}]
EOF
  yq -o=json ea '[. | select(tag == "!!map") | . + {"__src": {"env": "platform", "origin": "raw", "file": "p/pol.yaml", "line": line}}]' "$T/render-platform.yaml" > "$T/render-platform.json"
  printf 'env\torigin\tobjects\texit\tstderr\troot\nprod\traw\t6\t0\t0\tk\nplatform\traw\t2\t0\t0\tp\n' > "$T/render-ledger.tsv"
  cat > "$T/canary.yaml" <<'EOF'
---
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata: {name: refract-canary-removed-api, namespace: refract-canary}
spec: {minAvailable: 1, selector: {matchLabels: {app: refract-canary}}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: n
  namespace: refract-canary
data:
  enabled: "yes"
EOF
  printf 'file:line\ttool\tverb\trelease\tchart\tversion\tvalues\tnamespace\tflags\nops/p.md:3\thelm\tupgrade\tcert-manager\tjetstack/cert-manager\tv1.18.2\t-\tcert-manager\t-\n' > "$T/inventory-platform.tsv"
  # A minimal local schema set (no network): a permissive object schema for the core kinds the render holds.
  S="$T/schemas"; mkdir -p "$S/v1.37.0-standalone-strict"
  for f in namespace-v1 deployment-apps-v1 pod-v1 daemonset-apps-v1 configmap-v1; do
    printf '{"type":"object","properties":{"apiVersion":{"type":"string"},"kind":{"type":"string"},"metadata":{"type":"object","properties":{"name":{"type":"string"}}},"spec":{"type":"object"},"data":{"type":"object"}},"additionalProperties":false}\n' > "$S/v1.37.0-standalone-strict/$f.json"; done
  out="$("$SH" "$ME" "$T" --target=1.34,1.37 --schemas="$S" --today=2026-10-20 2>"$T/err")"; rc=$?
  fails=0; checks=0
  has() { checks=$((checks + 1)); if printf '%s\n' "$out" | awk -F'\t' -v c="$2" -v o="$3" -v d="$4" '$2 == c && $5 == o && index($6, d) { f = 1 } END { exit !f }'; then
      printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); fi; }
  hasnt() { checks=$((checks + 1)); if printf '%s\n' "$out" | awk -F'\t' -v c="$2" -v o="$3" '$2 == c && $5 == o { f = 1 } END { exit !f }'; then
      printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); else printf 'PASS  %s\n' "$1"; fi; }
  led() { checks=$((checks + 1)); if awk -F'\t' -v t="$2" -v s="$3" '$1 == t && index($0, s) { f = 1 } END { exit !f }' "$T/apiversion-ledger.tsv"; then
      printf 'PASS  %s\n' "$1"; else printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); fi; }
  checks=$((checks + 1)); if [ "$rc" -eq 0 ]; then printf 'PASS  exit 0\n'; else printf 'FAIL  exit %s\n' "$rc"; cat "$T/err"; fails=$((fails + 1)); fi
  has   "§1 static table: autoscaling/v2beta2 removed in 1.26"            K-API-REMOVED HorizontalPodAutoscaler/pay/api "removed in 1.26"
  has   "§1 field-level: gitRepo volume (secondary source)"              K-API-FIELD Pod/tools/old "gitRepo"
  hasnt "§1 decoy: apps/v1 Deployment"                                   K-API-REMOVED Deployment/pay/api
  has   "§3 PSA restricted: the namespace's own workload is rejected"    K-PSA-LABELS Deployment/pay/api "enforce restricted"
  hasnt "§3 decoy: a workload that meets restricted"                     K-PSA-LABELS Deployment/pay/ok
  has   "§4 target 1.34 past EOL 2026-10-27 on --today=2026-10-20 (warn window)" K-MINOR-SUPPORT Target/-/1.34 "EOL 2026-10-27"
  has   "§4 ingress-nginx image in the render"                           K-INGRESS-RETIRED DaemonSet/ingress/ingress-nginx-controller "retired"
  has   "§4 controller pin listed for the read step"                     read:CONTROLLER-PIN Inventory/-/cert-manager "v1.18.2"
  if have yq; then
    has "§2 YAML-1.1 plain scalar listed"                                 read:YAML11-SCALAR Deployment/pay/api "value = no"
  fi
  if have kubeconform; then
    led "§2 kubeconform read every object + both canaries"               kubeconform "RAN"
    checks=$((checks + 1)); if awk -F'\t' '$1 == "kubeconform" && $4 == 10 && $5 == 10' "$T/apiversion-ledger.tsv" | grep -q .; then
      printf 'PASS  §2 objects read 10 = rendered 8 + 2 canaries\n'; else printf 'FAIL  §2 objects read = rendered + 2\n'; fails=$((fails + 1)); fi
    led "§2 the removed-API canary came back as an error, never skipped"  kubeconform "canary-removed=statusError"
    has "§2 a removed core API has no schema at the target (corroborates §1)" K-SCHEMA-MISSING HorizontalPodAutoscaler/pay/api "no local schema"
  else printf 'SKIP  kubeconform checks: not installed\n'; fi
  if have pluto; then led "§1 pluto RAN and flagged the canary" pluto "canary=flagged"; else printf 'SKIP  pluto: not installed\n'; fi
  has   "§3 an unbound ValidatingAdmissionPolicy rejects nothing (read row)" read:VAP-UNBOUND ValidatingAdmissionPolicy/-/no-latest "no binding"
  if have kyverno && have yq; then
    has "§3 kyverno offline: an Enforce rule rejects the Deployment"     K-ADMISSION-REJECT Deployment/pay/api "need-team/team-label [Enforce]"
    led "§3 kyverno RAN on the mappable objects, the rest counted"       kyverno "RAN"
  else printf 'SKIP  kyverno: not installed\n'; fi
  checks=$((checks + 1)); if grep -q '^KUBECONFIG=scratch' "$T/apiversion-meta.txt"; then printf 'PASS  KUBECONFIG forced to a scratch file\n'; else printf 'FAIL  KUBECONFIG scratch\n'; fails=$((fails + 1)); fi
  printf '%s\n' "self-test ($SH): $((checks - fails))/$checks passed"
  [ "$fails" -eq 0 ]; exit $?
fi

# ---------------------------------------------------------------- setup --------------------------
[ -n "$SCAN" ] || { printf 'usage: apiversion.sh <scan-dir> --target=<oldest>[,<newest>] | --self-test\n' >&2; exit 2; }
have jq || { printf 'NOT-INSTALLED: jq — every § is blocked\n' >&2; exit 4; }
[ -n "$(find "$SCAN" -maxdepth 1 -name 'render-*.json' 2>/dev/null)" ] || { printf 'no render-*.json in %s: run render.sh first (§ 0)\n' "$SCAN" >&2; exit 4; }
: > "$SCAN/.api-empty.kubeconfig"; export KUBECONFIG="$SCAN/.api-empty.kubeconfig"
unset HELM_KUBECONTEXT 2>/dev/null
printf 'KUBECONFIG=scratch (%s)\ntarget=%s\ntoday=%s\nsupport-table=%s\n' "$KUBECONFIG" "${TARGET:-unset}" "$TODAY" "$SUPPORT_DATE" > "$SCAN/apiversion-meta.txt"
LED="$SCAN/apiversion-ledger.tsv"; printf 'tool\tversion\tstatus\tread\texpected\tnote\n' > "$LED"
A="$SCAN/.api"; rm -rf "$A"; mkdir -p "$A"; : > "$A/kc-rows.tsv"
find "$SCAN" -maxdepth 1 -name 'render-*.json' -exec jq -c '.[]' {} + | jq -s 'map(select(type == "object" and .kind != null))' > "$A/all.json"
OBJ="$(jq length "$A/all.json")"
TMIN=""; TMAX=""
if [ -n "$TARGET" ]; then
  TMIN="$(minor "${TARGET%%,*}")"; TMAX="$(minor "${TARGET##*,}")"
  [ "$TMIN" -le "$TMAX" ] 2>/dev/null || { t="$TMIN"; TMIN="$TMAX"; TMAX="$t"; }
fi

# ---------------------------------------------------------------- § 1 static table ----------------
if [ -n "$TMAX" ]; then
  printf '%s\n' "$REMOVED" > "$A/removed.tsv"
  jq -r --rawfile tab "$A/removed.tsv" --argjson tmin "$TMIN" --argjson tmax "$TMAX" "$JQLIB"'
    ($tab | split("\n") | map(select(. != "") | split("\t") | {re: .[0], m: (.[1] | tonumber)})) as $T
    | .[] | . as $o | "\(.apiVersion) \(.kind)" as $gk
    | ([$T[] | . as $t | select($gk | test($t.re))] | first) as $hit
    | ( (select($hit != null and $hit.m <= $tmax)
         | row("1"; "K-API-REMOVED"; "\(.apiVersion) \(.kind) removed in 1.\($hit.m); target 1.\($tmin)–1.\($tmax)\(if $hit.m > $tmin then " (served at the oldest target, not at the newest: the upgrade breaks it)" else "" end)")),
        (select($tmax >= 36) | select(iswl) | select(any((ps.volumes // [])[]; .gitRepo != null))
         | row("1"; "K-API-FIELD"; "gitRepo volume: removed per the 1.36 release notes (secondary source, research 2026-10-10); prove with the dry-run on a 1.\($tmax) kind node")),
        (select($tmax >= 36) | select(.kind == "Service" and ((.spec.externalIPs // []) | length) > 0)
         | row("1"; "K-API-DEPRECATED"; "Service spec.externalIPs is deprecated from 1.36 (low; plan the move)")) )' "$A/all.json"
fi

# ---------------------------------------------------------------- § 1 pluto ----------------------
if [ -z "$TMAX" ]; then printf 'pluto\t-\tNOT-RUN\t-\t-\tno target minor read (gate 3)\n' >> "$LED"
elif have pluto; then
  mkdir -p "$A/pluto"; find "$SCAN" -maxdepth 1 \( -name 'render-*.yaml' -o -name canary.yaml \) -exec cp {} "$A/pluto/" \;
  pluto detect-files -d "$A/pluto" -o json --target-versions "k8s=v1.$TMAX.0" > "$A/pluto.json" 2> "$A/pluto.err"; prc=$?
  pv="$(pluto version 2>/dev/null | sed -n 's/^Version:\([^ ]*\).*/\1/p')"
  if jq -e '.items' "$A/pluto.json" >/dev/null 2>&1; then
    can="$(jq -r '[.items[] | select(.name == "refract-canary-removed-api")] | if length > 0 then "flagged" else "MISSING" end' "$A/pluto.json")"
    printf 'pluto\t%s\tRAN (exit %s)\t%s items\t-\tcanary=%s; target k8s=v1.%s.0\n' "$pv" "$prc" "$(jq '.items | length' "$A/pluto.json")" "$can" "$TMAX" >> "$LED"
    jq -r '.items[] | select(.name != "refract-canary-removed-api" and .name != "n")
      | ["1", (if .removed then "K-API-REMOVED" else "K-API-DEPRECATED" end), (.filePath | split("/") | last | sub("^render-"; "") | sub("\\.yaml$"; "")), "pluto",
         "\(.api.kind)/\(.namespace // "-")/\(.name)", "pluto: \(.api.version) deprecated \(.api["deprecated-in"]) removed \(.api["removed-in"]) → \(.api["replacement-api"])", "(render)"] | @tsv' "$A/pluto.json"
  else printf 'pluto\t%s\tNOT-RUN\t-\t-\tno JSON (exit %s): %s\n' "$pv" "$prc" "$(head -c 160 "$A/pluto.err" | tr '\n\t' '  ')" >> "$LED"; fi
else printf 'pluto\t-\tNOT-INSTALLED\t-\t-\tbrew install FairwindsOps/tap/pluto\n' >> "$LED"; fi

# ---------------------------------------------------------------- § 2 schemas --------------------
SCHEMAS="${SCHEMAS:-$SCAN/schemas}"
fetch_schemas() {  # $1 minor → $SCHEMAS/v1.<m>.0-standalone-strict/ (core) and $SCHEMAS/crds/<group>/ (CRDs)
  m="$1"; d="$SCHEMAS/v1.$m.0-standalone-strict"; mkdir -p "$d" "$SCHEMAS/crds"
  # The repo's own CRDs, converted locally (nested objects made strict, as openapi2jsonschema -strict does).
  jq -c '.[] | select(.kind == "CustomResourceDefinition") | .spec as $s | $s.versions[]? | select(.schema.openAPIV3Schema != null)
    | {g: $s.group, k: ($s.names.kind | ascii_downcase), v: .name, s: (.schema.openAPIV3Schema | walk(if type == "object" and has("properties")
        and (has("additionalProperties") | not) and ((.["x-kubernetes-preserve-unknown-fields"] // false) | not) then . + {additionalProperties: false} else . end))}' "$A/all.json" \
    | while IFS= read -r c; do g="$(printf '%s' "$c" | jq -r .g)"; mkdir -p "$SCHEMAS/crds/$g"
        printf '%s' "$c" | jq '.s' > "$SCHEMAS/crds/$g/$(printf '%s' "$c" | jq -r '"\(.k)_\(.v)"').json"; done
  { jq -r '.[] | "\(.apiVersion)\t\(.kind)"' "$A/all.json"; printf 'policy/v1beta1\tPodDisruptionBudget\nv1\tConfigMap\n'; } | sort -u |
  while IFS="$(printf '\t')" read -r av k; do
    case "$av" in */*) g="${av%/*}"; v="${av#*/}" ;; *) g=""; v="$av" ;; esac
    lk="$(printf '%s' "$k" | tr 'A-Z' 'a-z')"; f="$lk${g:+-${g%%.*}}-$v.json"
    [ -s "$d/$f" ] && continue
    [ -n "$g" ] && [ -s "$SCHEMAS/crds/$g/${lk}_$v.json" ] && continue
    curl -fsS --max-time 20 -o "$d/$f" "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/$CORE_REF/v1.$m.0-standalone-strict/$f" 2>/dev/null && continue
    rm -f "$d/$f"; [ -n "$g" ] || continue
    mkdir -p "$SCHEMAS/crds/$g"
    curl -fsS --max-time 20 -o "$SCHEMAS/crds/$g/${lk}_$v.json" "https://raw.githubusercontent.com/datreeio/CRDs-catalog/$CATALOG_REF/$g/${lk}_$v.json" 2>/dev/null || rm -f "$SCHEMAS/crds/$g/${lk}_$v.json"
  done
}
if [ -z "$TMAX" ]; then printf 'kubeconform\t-\tNOT-RUN\t-\t-\tno target minor read (gate 3)\n' >> "$LED"
elif ! have kubeconform; then printf 'kubeconform\t-\tNOT-INSTALLED\t-\t-\tbrew install kubeconform\n' >> "$LED"
else
  [ "$FETCH" -eq 1 ] && { fetch_schemas "$TMAX"; [ "$TMIN" != "$TMAX" ] && fetch_schemas "$TMIN"; }
  for m in $(printf '%s\n%s\n' "$TMIN" "$TMAX" | sort -u); do
    if [ ! -d "$SCHEMAS/v1.$m.0-standalone-strict" ]; then
      printf 'kubeconform\t%s\tNOT-RUN\t0\t%s\tk8s 1.%s: no local schemas in %s (pass --fetch-schemas once, or --schemas=<vendored dir>)\n' "$(kubeconform -v 2>/dev/null)" "$((OBJ + 2))" "$m" "$SCHEMAS" >> "$LED"; continue; fi
    find "$SCAN" -maxdepth 1 -name 'render-*.yaml' | sort > "$A/kc-files"; printf '%s\n' "$SCAN/canary.yaml" >> "$A/kc-files"
    # shellcheck disable=SC2046  # file list from find in $SCAN (render.sh names: no spaces)
    kubeconform -strict -summary -verbose -output json -kubernetes-version "1.$m.0" \
      -schema-location "$SCHEMAS/{{ .NormalizedKubernetesVersion }}-standalone{{ .StrictSuffix }}/{{ .ResourceKind }}{{ .KindSuffix }}.json" \
      -schema-location "$SCHEMAS/crds/{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json" \
      $(tr '\n' ' ' < "$A/kc-files") > "$A/kc-$m.json" 2> "$A/kc-$m.err"; krc=$?
    if ! jq -e '.summary' "$A/kc-$m.json" >/dev/null 2>&1; then
      printf 'kubeconform\t%s\tNOT-RUN\t0\t%s\tk8s 1.%s: no JSON (exit %s) %s\n' "$(kubeconform -v)" "$((OBJ + 2))" "$m" "$krc" "$(head -c 160 "$A/kc-$m.err" | tr '\n\t' '  ')" >> "$LED"; continue; fi
    rd="$(jq '.summary | .valid + .invalid + .errors + .skipped' "$A/kc-$m.json")"
    cr="$(jq -r '[.resources[] | select(.name == "refract-canary-removed-api") | .status] | first // "ABSENT"' "$A/kc-$m.json")"
    cn="$(jq -r '[.resources[] | select(.filename | endswith("canary.yaml")) | select(.kind == "ConfigMap") | .name] | first // "ABSENT"' "$A/kc-$m.json")"
    nr=""; [ "$rd" -lt "$((OBJ + 2))" ] && nr="; NOT-RUN for $((OBJ + 2 - rd)) objects"
    printf 'kubeconform\t%s\tRAN (exit %s)\t%s\t%s\tk8s 1.%s; canary-removed=%s; canary-yaml11 name=%s%s; %s\n' "$(kubeconform -v)" "$krc" "$rd" "$((OBJ + 2))" "$m" "$cr" "$cn" "$nr" \
      "$(jq -r '.summary | "valid \(.valid) invalid \(.invalid) errors \(.errors) skipped \(.skipped)"' "$A/kc-$m.json")" >> "$LED"
    jq -r --arg m "$m" --slurpfile ALL "$A/all.json" '.resources[] | select(.filename | endswith("canary.yaml") | not) | select(.status == "statusInvalid" or .status == "statusError")
      | (.filename | split("/") | last | sub("^render-"; "") | sub("\\.yaml$"; "")) as $env | . as $r
      | ([$ALL[0][] | select(.__src.env == $env and .kind == $r.kind and .metadata.name == $r.name and .apiVersion == $r.version)] | first) as $o
      | "\(.kind)/\($o.metadata.namespace // "-")/\(.name)" as $id | ($o.__src.file // "(render)") as $f
      | if (.msg // "" | test("could not find schema")) then ["2", "K-SCHEMA-MISSING", $env, ($o.__src.origin // "kubeconform"), $id, "1.\($m) \(.version) \(.kind): no local schema (a removed core API → §1; a CRD → NOT-RUN for this kind until its schema is added)", $f]
        else ["2", "K-SCHEMA-INVALID", $env, ($o.__src.origin // "kubeconform"), $id, "1.\($m) \(.version): \(([.validationErrors[]? | "\(.path) \(.msg)"] | join("; ")) | if . == "" then $r.msg else . end | .[0:240])", $f] end | @tsv' "$A/kc-$m.json" >> "$A/kc-rows.tsv"
  done
  # One row per object and message; the minors that report it are joined (1.34+1.37), not printed twice.
  [ -s "$A/kc-rows.tsv" ] && awk -F'\t' -v OFS='\t' '{ mn = $6; sub(/ .*/, "", mn); d = $6; sub(/^[^ ]+ /, "", d); k = $2 FS $3 FS $5 FS d
      if (!(k in row)) { order[++n] = k; row[k] = $0; ds[k] = d } if (index("+" mins[k] "+", "+" mn "+") == 0) mins[k] = mins[k] (mins[k] != "" ? "+" : "") mn }
    END { for (i = 1; i <= n; i++) { k = order[i]; split(row[k], f, "\t"); print f[1], f[2], f[3], f[4], f[5], "k8s " mins[k] ": " ds[k], f[7] } }' "$A/kc-rows.tsv"
fi

# YAML-1.1 plain scalars: a string the YAML-1.2 render keeps, which YAML-1.1 tools (kubeconform among them) read as a bool.
if have yq; then
  find "$SCAN" -maxdepth 1 -name 'render-*.yaml' | sort | while IFS= read -r y; do e="$(basename "$y" .yaml)"; e="${e#render-}"
    yq -o=json -I=0 '{"k": .kind, "ns": (.metadata.namespace // "-"), "n": .metadata.name, "h": [.. | select(tag == "!!str" and style == ""
        and test("^(y|Y|yes|Yes|YES|n|N|no|No|NO|on|On|ON|off|Off|OFF)$")) | {"p": (path | join(".")), "v": .}]}' "$y" 2>/dev/null \
      | jq -r --arg e "$e" 'select((.h | length) > 0) | ["2", "read:YAML11-SCALAR", $e, "render", "\(.k)/\(.ns)/\(.n)", ([.h[] | "\(.p) = \(.v)"] | join(" · ")), "(render)"] | @tsv'; done | sort -u
fi

# ---------------------------------------------------------------- § 3 admission ------------------
jq -r "$JQLIB"'
  def bad_baseline: ps as $p | [ (if $p.hostNetwork == true then "hostNetwork" else empty end), (if $p.hostPID == true then "hostPID" else empty end),
      (if $p.hostIPC == true then "hostIPC" else empty end), (($p.volumes // [])[] | select(.hostPath != null) | "hostPath \(.name)"),
      (everyc | select(.securityContext.privileged == true) | "\(.name) privileged"),
      (everyc | (.ports // [])[] | select(.hostPort != null and .hostPort != 0) | "hostPort \(.hostPort)") ];
  def bad_restricted: ps as $p | bad_baseline + [
      (everyc | select(.securityContext.allowPrivilegeEscalation != false) | "\(.name) allowPrivilegeEscalation not false"),
      (everyc | select((if .securityContext.runAsNonRoot != null then .securityContext.runAsNonRoot else $p.securityContext.runAsNonRoot end) != true) | "\(.name) runAsNonRoot not true"),
      (everyc | select(((.securityContext.capabilities.drop // []) | index("ALL")) == null) | "\(.name) capabilities.drop lacks ALL"),
      (everyc | select(((.securityContext.seccompProfile.type // $p.securityContext.seccompProfile.type) // "") | IN("RuntimeDefault","Localhost") | not) | "\(.name) seccompProfile unset"),
      (($p.volumes // [])[] | select(keys - ["name"] | .[0] | IN("configMap","csi","downwardAPI","emptyDir","ephemeral","persistentVolumeClaim","projected","secret") | not) | "volume \(.name) type not allowed") ];
  group_by(.__src.env)[] | . as $E
  | ($E | map(select(.kind == "Namespace") | {n: .metadata.name, lv: (.metadata.labels["pod-security.kubernetes.io/enforce"] // null)}) | map(select(.lv != null))) as $PSA
  | $E[] | select(iswl) | . as $w | ([$PSA[] | select(.n == ($w | ns))] | first) as $p | select($p != null and ($p.lv | IN("restricted","baseline")))
  | (if $p.lv == "restricted" then bad_restricted else bad_baseline end) as $v | select(($v | length) > 0)
  | row("3"; "K-PSA-LABELS"; "namespace \($p.n) has enforce \($p.lv); this workload violates it (\($v | unique | join("; "))): every pod create is rejected")' "$A/all.json"

# Repo policies through kyverno, offline. Only Enforce / Deny-bound rules reject at admission; Audit and an
# unbound ValidatingAdmissionPolicy reject nothing (listed as read rows).
jq '[.[] | select((.apiVersion | test("^(kyverno\\.io|policies\\.kyverno\\.io)/")) or .kind == "ValidatingAdmissionPolicy" or .kind == "ValidatingAdmissionPolicyBinding")]' "$A/all.json" > "$A/pol.json"
NPOL="$(jq length "$A/pol.json")"
if [ "$NPOL" -eq 0 ]; then printf 'kyverno\t-\tN/A\t-\t-\tno Kyverno or VAP policy in the render\n' >> "$LED"
elif ! have kyverno || ! have yq; then printf 'kyverno\t-\tNOT-INSTALLED\t-\t-\t%s policies unread (brew install kyverno yq)\n' "$NPOL" >> "$LED"
else
  jq -r '. as $P | .[] | select(.kind == "ValidatingAdmissionPolicy") | .metadata.name as $n
    | select([$P[] | select(.kind == "ValidatingAdmissionPolicyBinding" and .spec.policyName == $n and ((.spec.validationActions // []) | index("Deny")))] | length == 0)
    | ["3", "read:VAP-UNBOUND", .__src.env, .__src.origin, "ValidatingAdmissionPolicy/-/\($n)", "no binding with validationActions Deny: it rejects nothing at admission", "\(.__src.file // "?")"] | @tsv' "$A/pol.json"
  jq '[.[] | del(.__src)]' "$A/pol.json" > "$A/pol.clean.json"; yq -P -p=json -oy '.[] | split_doc' "$A/pol.clean.json" > "$A/pol.yaml"
  printf '%s\n' "$REMOVED" | cut -f1 > "$A/removed.re"
  # Per env: kyverno's fake client panics on two objects with one name ("already exists"), and envs repeat names.
  jq --rawfile re "$A/removed.re" '[.[] | select(.kind != "CustomResourceDefinition") | . as $o
      | select(($re | split("\n") | map(select(. != ""))) as $r | any($r[]; . as $x | ("\($o.apiVersion) \($o.kind)" | test($x))) | not)
      | select(.kind | IN("ValidatingAdmissionPolicy","ValidatingAdmissionPolicyBinding") | not)
      | select(.apiVersion | test("^(v1|[a-z0-9]+/[^/]+|[a-z0-9.]+\\.k8s\\.io/[^/]+)$") and (test("^gateway\\.networking\\.k8s\\.io/|x-k8s\\.io/") | not))] | unique_by([.__src.env, .apiVersion, .kind, (.metadata.namespace // ""), .metadata.name])' "$A/all.json" > "$A/res.json"
  RES=0; RAN=0; ABORT=""; PASS=0; FAIL=0; : > "$A/kyv-rows.tsv"; KV="$(kyverno version 2>/dev/null | sed -n 's/^Version: //p')"
  for e in $(jq -r '[.[].__src.env] | unique | .[]' "$A/res.json"); do
    jq --arg e "$e" '[.[] | select(.__src.env == $e) | del(.__src)]' "$A/res.json" > "$A/res-$e.json"
    n="$(jq length "$A/res-$e.json")"; [ "$n" -gt 0 ] || continue; yq -P -p=json -oy '.[] | split_doc' "$A/res-$e.json" > "$A/res-$e.yaml"
    kyverno apply "$A/pol.yaml" --resource "$A/res-$e.yaml" --policy-report > "$A/kyv-$e.raw" 2> "$A/kyv-$e.err"; kyrc=$?
    sed -n '/^apiVersion:/,$p' "$A/kyv-$e.raw" > "$A/kyv-$e.out"   # stdout starts with deprecation warnings
    # The --policy-report output is a ClusterReport; its summary block is the count (exit 1 only means "fail > 0").
    sm="$(yq -o=json ea '[.] | map(select(.kind == "ClusterReport" or .kind == "PolicyReport")) | .[0].summary' "$A/kyv-$e.out" 2>/dev/null | jq -r 'select(.pass != null) | "pass: \(.pass), fail: \(.fail)"' 2>/dev/null)"
    if [ -z "$sm" ]; then ABORT="$ABORT $e(exit $kyrc: $(grep -v '^Warning' "$A/kyv-$e.err" | grep -m1 . | cut -c1-80 | tr '\t' ' '))"; continue; fi
    RAN=$((RAN + 1)); RES=$((RES + n)); PASS=$((PASS + $(printf '%s' "$sm" | sed -E 's/pass: ([0-9]+).*/\1/'))); FAIL=$((FAIL + $(printf '%s' "$sm" | sed -E 's/.*fail: ([0-9]+)/\1/')))
    yq -o=json ea '[.]' "$A/kyv-$e.out" 2>/dev/null | jq -r --arg e "$e" --slurpfile P "$A/pol.json" '
      [.[] | select(type == "object") | (.results // [])[]] | .[] | select(.result == "fail") | . as $r
      | ([$P[0][] | select(.metadata.name == $r.policy)] | first) as $pol
      | (if $pol.kind == "ValidatingAdmissionPolicy" then
           (if any($P[0][]; .kind == "ValidatingAdmissionPolicyBinding" and .spec.policyName == $pol.metadata.name and ((.spec.validationActions // []) | index("Deny"))) then "Deny" else "unbound" end)
         else ([$pol.spec.rules[]? | select(.name == $r.rule or ("autogen-" + .name) == $r.rule) | (.validate.failureAction // $pol.spec.validationFailureAction // "Audit")] | first // "Audit") end) as $act
      | ($r.resources // [])[] | ["3", (if ($act | ascii_downcase) | IN("enforce","deny") then "K-ADMISSION-REJECT" else "read:ADMISSION-AUDIT" end), $e, "kyverno",
          "\(.kind)/\(.namespace // "-")/\(.name)", "\($r.policy)/\($r.rule) [\($act)]: \($r.message // "" | .[0:200])", ($pol.__src.file // "?")] | @tsv' 2>/dev/null >> "$A/kyv-rows.tsv"
  done
  st="RAN"; [ "$RAN" -eq 0 ] && st="NOT-RUN"
  printf 'kyverno\t%s\t%s (%s envs)\t%s\t%s\tpass %s fail %s; %s objects not mappable offline (removed APIs, CRD kinds kyverno cannot map offline, the policies themselves, same-name duplicates inside one env) were not sent%s\n' "$KV" "$st" "$RAN" "$RES" "$OBJ" "$PASS" "$FAIL" "$((OBJ - RES))" "${ABORT:+; aborted:$ABORT}" >> "$LED"
  sort -u "$A/kyv-rows.tsv"
fi

# ---------------------------------------------------------------- § 4 support status --------------
if [ -n "$TMIN" ]; then
  printf '%s\n' "$SUPPORT" | awk -F'\t' -v tmin="$TMIN" -v tmax="$TMAX" -v today="$TODAY" -v sd="$SUPPORT_DATE" '
    { eol[$1] = $2; if (min == "" || $1 < min) min = $1 }
    END { for (m = tmin; m <= tmax; m++) { if (m != tmin && m != tmax) continue
        if (!(m in eol)) { if (m < min) printf "4\tK-MINOR-SUPPORT\t-\tversion-gate\tTarget/-/1.%s\tout of support: older than every minor in the support table (read %s)\t(version gate)\n", m, sd; continue }
        cmd = "date -j -f %Y-%m-%d " eol[m] " +%s 2>/dev/null || date -d " eol[m] " +%s"; cmd | getline e; close(cmd)
        cmd = "date -j -f %Y-%m-%d " today " +%s 2>/dev/null || date -d " today " +%s"; cmd | getline t; close(cmd)
        d = int((e - t) / 86400)
        if (d < 0) printf "4\tK-MINOR-SUPPORT\t-\tversion-gate\tTarget/-/1.%s\tpast EOL %s (%d days ago; table read %s): no patches\t(version gate)\n", m, eol[m], -d, sd
        else if (d <= 90) printf "4\tK-MINOR-SUPPORT\t-\tversion-gate\tTarget/-/1.%s\tEOL %s in %d days (table read %s): schedule the upgrade\t(version gate)\n", m, eol[m], d, sd } }'
fi
jq -r "$JQLIB"'
  .[] | ( (select(iswl) | . as $w | everyc | select((.image // "") | test("ingress-nginx/controller|ingress-nginx/controller-chroot"))
           | $w | row("4"; "K-INGRESS-RETIRED"; "image \(.image // ""): ingress-nginx is retired (last release v1.15.1, 2026-03-19; precedents § 62): no security patches")),
          (select(.kind == "IngressClass" and (.spec.controller // "") == "k8s.io/ingress-nginx")
           | row("4"; "K-INGRESS-RETIRED"; "IngressClass controller k8s.io/ingress-nginx is retired (precedents § 62)")) )' "$A/all.json" | sort -u
if [ -f "$SCAN/inventory-platform.tsv" ]; then
  awk -F'\t' 'NR > 1 && $2 == "helm" {
      if ($5 ~ /ingress-nginx\/ingress-nginx$/ || $5 ~ /kubernetes\.github\.io\/ingress-nginx/)
        printf "4\tK-INGRESS-RETIRED\t-\tinventory\tInventory/%s/%s\tchart %s %s installs the retired ingress-nginx controller (precedents § 62)\t%s\n", $8, $4, $5, $6, $1
      else if ($5 ~ /(cert-manager|keda|argo-cd|argocd|flux|gateway|traefik|kong|istio|cilium|external-dns|external-secrets|reloader|kube-prometheus)/)
        printf "4\tread:CONTROLLER-PIN\t-\tinventory\tInventory/-/%s\tchart %s at %s: read its support window at this version (a dated source)\t%s\n", $4, $5, $6, $1 }' "$SCAN/inventory-platform.tsv"
fi
rm -f "$SCAN/.api-empty.kubeconfig"
exit 0
