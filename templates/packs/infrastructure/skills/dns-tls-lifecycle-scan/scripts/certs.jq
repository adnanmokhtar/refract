# certs.jq — dns-tls-lifecycle-scan § 4–§ 6: the certificate inventory and the cert-manager joins over
# k8s-render-scan § 0's render, one environment at a time (an Issuer in dev never clears a prod row).
#
# Input:  every rendered object, slurped:  find "$SCAN" -maxdepth 1 -name 'render-*.json' -exec jq -c '.[]' {} + | jq -rs -f certs.jq
#         (each object carries __src {env, origin, file, line}, as render.sh writes it)
# Output: one TSV row per inventory line or candidate:  §  CLASS  env  ns/Kind/name detail  source file:line
#         CERT rows are the § 4 inventory, not candidates. The env-name tests are hints for the read
#         step (gate 1 decides which env is prod), never the verdict.
# Measured 2026-10-10 (jq 1.7.1) on a hand-built two-env render of the skill's seeded fixture:
#         7/7 seeds (K-CERT-STAGING, K-CERT-DUP-SECRET, K-CERT-RENEW, K-CERT-ROTATION, D7-CLIENT-AUTH,
#         D6-PROD-ACME-NONPROD, CERT-MANUAL), the well-formed Certificate quiet.
def secs: if . == null then null else [scan("([0-9.]+)(h|m|s)")] | map((.[0] | tonumber) * ({"h": 3600, "m": 60, "s": 1}[.[1]])) | add end;
def nonprod: test("(^|[-_/])(dev|test|ci|preview|pr|review|ephemeral|staging|stage|qa|local|kind|sandbox)([-_/0-9]|$)"; "i");
def prod: test("(^|[-_/])(prod|production|live)([-_/0-9]|$)"; "i");
group_by(.__src.env)[] | . as $E | ($E[0].__src.env) as $env
| ($E | map(select(.kind == "Issuer" or .kind == "ClusterIssuer"))) as $ISS
| [ $E[] | if .kind == "Certificate" then {ns: (.metadata.namespace // "-"), obj: "Certificate/\(.metadata.name)", iname: .spec.issuerRef.name,
        ikind: (.spec.issuerRef.kind // "Issuer"), secret: .spec.secretName, spec: .spec, src: "\(.__src.file):\(.__src.line // 0)"}
    elif .kind == "Ingress" then (.metadata.annotations // {}) as $a | (.spec.tls // [])[] as $t
      | {ns: (.metadata.namespace // "-"), obj: "Ingress/\(.metadata.name)", iname: ($a["cert-manager.io/cluster-issuer"] // $a["cert-manager.io/issuer"]),
         ikind: (if $a["cert-manager.io/cluster-issuer"] then "ClusterIssuer" else "Issuer" end), secret: $t.secretName, spec: {}, src: "\(.__src.file):\(.__src.line // 0)"}
    else empty end ] as $C
| ($C | map(select(.obj | startswith("Certificate/")) | "\(.ns)/\(.secret)")) as $issued
| ( $C[] | . as $c
    | ([ $ISS[] | select(.metadata.name == $c.iname and .kind == $c.ikind and (.kind == "ClusterIssuer" or (.metadata.namespace // "-") == $c.ns)) ][0]) as $i
    | (if $c.iname == null then (if ($issued | index("\($c.ns)/\($c.secret)")) then "certificate-object" else "manual" end)
       elif $i == null then "issuer-not-rendered" elif $i.spec.acme then $i.spec.acme.server else ($i.spec | keys | join(",")) end) as $srv
    | "4\tCERT\t\($env)\t\($c.ns)/\($c.obj) secret \($c.secret) issuer \($c.iname // "-") → \($srv)\t\($c.src)",
      (if ($srv | test("staging")) and ($env | prod) then "5\tK-CERT-STAGING\t\($env)\t\($c.ns)/\($c.obj) issues from a staging ACME endpoint: browsers reject it\t\($c.src)" else empty end),
      (if ($srv | test("acme") and (test("staging") | not)) and ($env | nonprod) then "5\tD6-PROD-ACME-NONPROD\t\($env)\t\($c.ns)/\($c.obj) issues from a production ACME endpoint: its churn spends the registered domain's rate limits\t\($c.src)" else empty end),
      (if $srv == "manual" then "4\tCERT-MANUAL\t\($env)\t\($c.ns)/\($c.obj) secret \($c.secret) has no issuer in the render: renewed by hand, or by a controller outside the repo\t\($c.src)" else empty end),
      (if ($c.spec.duration | secs) != null and ($c.spec.renewBefore | secs) != null and (($c.spec.renewBefore | secs) >= ($c.spec.duration | secs))
       then "6\tK-CERT-RENEW\t\($env)\t\($c.ns)/\($c.obj) renewBefore \($c.spec.renewBefore) >= duration \($c.spec.duration)\t\($c.src)" else empty end),
      (if $c.spec.isCA == true and ($c.spec.privateKey.rotationPolicy // null) == null
       then "6\tK-CERT-ROTATION\t\($env)\t\($c.ns)/\($c.obj) isCA with no privateKey.rotationPolicy: cert-manager >= 1.18 rotates the key on renewal\t\($c.src)" else empty end),
      (if (($c.spec.usages // []) | index("client auth")) and ($srv | test("acme")) then "6\tD7-CLIENT-AUTH\t\($env)\t\($c.ns)/\($c.obj) asks a public ACME CA for a client-auth certificate\t\($c.src)" else empty end) )
, ( $C | map(select(.obj | startswith("Certificate/"))) | group_by("\(.ns)/\(.secret)")[] | select(length > 1)
    | "5\tK-CERT-DUP-SECRET\t\($env)\t\(.[0].ns)/\(.[0].secret) written by \(map(.obj) | join(", "))\t\(.[0].src)" )
