# plan-joins.jq — iac-lifecycle-scan (and serverless-reliability-scan, dr-audit): joins over an
# OFFLINE plan JSON (`terraform|tofu show -json tfplan`). One TSV row per candidate:
#     CLASS <TAB> address <TAB> detail
#   jq -r -f plan-joins.jq plan.json | sort | uniq            # all classes
#   jq -r -f plan-joins.jq plan.json | awk -F'\t' '$1 ~ /^(IDENTITY|STATEFUL-REPLACE|FORGET)/'
# Extra stateful types: IAC_STATEFUL='^(acme_db|foo_store)$' jq -r -f plan-joins.jq plan.json
#
# A row is a structural fact about the plan, never a finding: the skill's read step and the
# refuter decide. Unknown-after values (computed at apply) never produce a row.
# Measured 2026-10-10 on Terraform 1.16.5 and OpenTofu 1.13.1 (terraform_data, local state, no network):
#   count churn  → by_count[0],[1] delete,create (replace_because_cannot_update) + [2] delete (delete_because_count_index)
#   destroy=false + forced replace → ["forget","create"]: the old object is orphaned, a NEW EMPTY one is created
#   create_before_destroy replace  → ["create","delete"]
#   removed { lifecycle { destroy = false } } → ["forget"]

def stateful_re:
  "^(aws_(db_instance|rds_cluster|rds_cluster_instance|docdb_cluster|neptune_cluster|redshift_cluster|dynamodb_table|elasticache_(replication_group|cluster)|memorydb_cluster|s3_bucket|efs_file_system|ebs_volume|fsx_\\w+|kms_key|sqs_queue|route53_zone|opensearch_domain|elasticsearch_domain|msk_cluster|kinesis_stream|backup_vault|secretsmanager_secret)"
  + "|google_(sql_database_instance|storage_bucket|bigquery_(dataset|table)|spanner_(instance|database)|bigtable_instance|compute_disk|filestore_instance|kms_crypto_key|redis_instance|alloydb_cluster)"
  + "|azurerm_(postgresql_flexible_server|mysql_flexible_server|mssql_(server|database)|storage_account|cosmosdb_account|managed_disk|key_vault|redis_cache)"
  + "|digitalocean_(database_cluster|volume|spaces_bucket)|hcloud_(volume|server)|kubernetes_persistent_volume(_claim)?(_v1)?)$";
def stateful: test(stateful_re) or ((env.IAC_STATEFUL // "") as $x | ($x != "" and test($x)));
def acts: .change.actions | join(",");
def known($k): ((.change.after_unknown // {})[$k] // false) | not;

# Every module in the configuration, with the address prefix its resources carry in resource_changes.
def mods($p): {p: $p, m: .}, ((.module_calls // {}) | to_entries[] | .key as $k | .value.module // empty | mods($p + "module." + $k + "."));
def cfg_resources: [.configuration.root_module // {} | mods("") | .p as $p | (.m.resources // [])[] | . + {addr: ($p + .address), pfx: $p}];

. as $plan
| ([.resource_changes[]?]) as $rc
| ($rc | map({key: .address, value: .change.after}) | from_entries) as $after
| (cfg_resources) as $cfg
| (
  # 1. IDENTITY — count re-indexing: one row per resource, listing every instance it churns.
  ( $rc | map(select(.address | test("\\[[0-9]+\\]$"))) | group_by(.address | sub("\\[[0-9]+\\]$"; ""))[]
    | select(any(.[]; .action_reason == "delete_because_count_index") and any(.[]; (.change.actions | index("delete")) and (.change.actions | index("create"))))
    | "IDENTITY\t\(.[0].address | sub("\\[[0-9]+\\]$"; ""))\tcount re-index: " + (map("\(.address | capture("(?<i>\\[[0-9]+\\])$").i)=\(acts)") | join(" ")) + (if (.[0].type | stateful) then " · STATEFUL type" else "" end) ),
  ( $rc[] | select(.previous_address) | "MOVED\t\(.address)\tfrom \(.previous_address) actions=\(acts)" ),
  # 4. Replacement of a stateful type (delete/forget + create in either order), with its cause.
  ( $rc[] | select((.change.actions | index("create")) and ((.change.actions | index("delete")) or (.change.actions | index("forget"))))
    | (if (.type | stateful) then "STATEFUL-REPLACE" else "REPLACE" end) as $c
    | "\($c)\t\(.address)\tactions=\(acts) reason=\(.action_reason // "-") replace_paths=\(.change.replace_paths // [] | tostring)"
      + (if (.change.actions | index("forget")) then " · FORGET: old object orphaned, new one created EMPTY" else "" end) ),
  # 3. Forget (removed{} / lifecycle destroy=false) and stateful destroys.
  ( $rc[] | select(.change.actions == ["forget"]) | "FORGET\t\(.address)\treason=\(.action_reason // "-") (orphan: still exists, still billed, no longer managed)" ),
  ( $rc[] | select(.change.actions == ["delete"] and (.type | stateful)) | "STATEFUL-DELETE\t\(.address)\treason=\(.action_reason // "-")" ),
  # 7. Deletion safety on what the plan creates or keeps (after values; unset reads null, precedent 59).
  ( $rc[] | select(.change.after != null and (.change.actions | index("create") or index("update") or index("no-op"))) | . as $r | .change.after as $a
    | ( (["deletion_protection", "deletion_protection_enabled", "enable_deletion_protection", "delete_protection"][]) as $k
        | select(($a | has($k)) and $a[$k] != true and ($r | known($k))) | "DEL-02\t\($r.address)\t\($k)=\($a[$k] | tostring)" ),
      ( select($a.skip_final_snapshot == true) | "DEL-01\t\($r.address)\tskip_final_snapshot=true" ),
      ( select(($r.type | test("^aws_elasticache_replication_group$")) and ($a.final_snapshot_identifier // null) == null) | "DEL-01\t\($r.address)\tfinal_snapshot_identifier unset" ),
      ( select($a.force_destroy == true or $a.force_delete == true) | "DEL-03\t\($r.address)\tforce_destroy/force_delete=true" ),
      ( select($a.delete_automated_backups == true) | "DEL-05\t\($r.address)\tdelete_automated_backups=true (provider default)" ),
      ( select(($a.deletion_window_in_days // 30) < 30) | "DEL-05\t\($r.address)\tdeletion_window_in_days=\($a.deletion_window_in_days) < THR-KMS-WINDOW 30" ) ),
  # Serverless and DR joins (consumed by serverless-reliability-scan §2/§1 and dr-audit §7).
  ( ($rc | map(select(.type == "aws_lambda_function") | {key: .address, value: (.change.after.timeout // 3)}) | from_entries) as $t
    | ($rc | map(select(.type == "aws_sqs_queue") | {key: .address, value: (.change.after.visibility_timeout_seconds // 30)}) | from_entries) as $v
    | $cfg[] | select(.type == "aws_lambda_event_source_mapping") | .pfx as $p
    | ((.expressions.function_name.references // []) | map(select(test("^aws_lambda_function\\.[^.]+$")))[0]) as $fn
    | ((.expressions.event_source_arn.references // []) | map(select(test("^aws_sqs_queue\\.[^.]+$")))[0]) as $q
    | ((($after[.addr] // {}).maximum_batching_window_in_seconds) // 0) as $w
    | select($q and $fn and ($v[$p + $q] != null) and ($t[$p + $fn] != null) and ($v[$p + $q] < 6 * ($t[$p + $fn] + $w)))
    | "VIS\t\(.addr)\t\($p + $q) visibility=\($v[$p + $q]) < 6 x (\($p + $fn) timeout=\($t[$p + $fn]) + window=\($w))" ),
  ( ($rc | map(select(.type == "aws_lambda_function") | {key: .address, value: (.change.after.timeout // 3)}) | from_entries) as $t
    | $cfg[] | select(.type == "aws_api_gateway_integration" or .type == "aws_apigatewayv2_integration") | .pfx as $p
    | (((.expressions.uri.references // []) + (.expressions.integration_uri.references // [])) | map(select(test("^aws_lambda_function\\.[^.]+$")))[0]) as $fn
    | ((($after[.addr] // {}).timeout_milliseconds) // 29000) as $ms
    | select($fn and ($t[$p + $fn] != null) and ($ms < 1000 * $t[$p + $fn]))
    | "APIGW\t\(.addr)\tintegration timeout \($ms) ms < \($p + $fn) timeout \($t[$p + $fn]) s" ),
  ( ([$cfg[] | select(.type == "aws_s3_bucket_versioning") | .pfx as $p | (.expressions.bucket.references // [])[] | select(test("^aws_s3_bucket\\.[^.]+$")) | $p + .]) as $versioned
    | $rc[] | select(.type == "aws_s3_bucket" and (.change.actions | index("create") or index("update") or index("no-op")))
    | (.address | sub("\\[.*\\]$"; "")) as $base | select(($versioned | index($base)) | not)
    | "BUCKET-NO-VERSIONING\t\(.address)\tno aws_s3_bucket_versioning references it (read: is it a log/artifact bucket? precedents § 16–17)" )
)
