#!/usr/bin/env bash
# verify.sh — build the Larkmoor dbt project offline on duckdb, in a scratch copy, and run its tests.
#
# Never touches the repo tree (dbt writes target/ and logs/ into the copy) and never a warehouse: the
# profile written into the scratch folder has one duckdb target. Telemetry is off. `dbt deps` needs the
# package hub once; pass DBT_PACKAGES_DIR=<dir> to reuse packages already downloaded.
#
# Exit: 0 PASS (every step ran and passed) · 1 FAIL (a step ran and failed) · 2 NOT-RUN (a tool is missing;
# nothing is reported as passing).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$(mktemp -d "${TMPDIR:-/tmp}/larkmoor-verify.XXXXXX")"
export DO_NOT_TRACK=1 DBT_SEND_ANONYMOUS_USAGE_STATS=False DBT_ENGINE_SEND_ANONYMOUS_USAGE_STATS=false

if ! command -v dbt >/dev/null 2>&1 || ! python3 -c 'import dbt.adapters.duckdb' >/dev/null 2>&1; then
  echo "dbt build (duckdb): NOT-RUN — dbt-core and dbt-duckdb are not installed (pip install -r requirements.txt)"
  echo "scratch: $OUT (empty)"
  exit 2
fi

cp -R "$HERE/analytics" "$OUT/analytics"
cat > "$OUT/profiles.yml" <<YML
larkmoor:
  target: dev
  outputs:
    dev:
      type: duckdb
      path: "$OUT/larkmoor.duckdb"
      threads: 1
      settings:
        autoinstall_known_extensions: false
YML
cd "$OUT/analytics" || exit 1
if [ -n "${DBT_PACKAGES_DIR:-}" ]; then cp -R "$DBT_PACKAGES_DIR" dbt_packages; else dbt deps --profiles-dir "$OUT" || { echo "dbt deps: FAIL (needs the package hub once)"; exit 1; }; fi
rc=0
dbt parse --profiles-dir "$OUT" --target dev >"$OUT/parse.log" 2>&1 && echo "dbt parse: PASS" || { echo "dbt parse: FAIL ($OUT/parse.log)"; rc=1; }
dbt seed --profiles-dir "$OUT" --target dev >"$OUT/seed.log" 2>&1 && echo "dbt seed: PASS" || { echo "dbt seed: FAIL ($OUT/seed.log)"; rc=1; }
dbt build --profiles-dir "$OUT" --target dev --exclude resource_type:snapshot >"$OUT/build.log" 2>&1 && echo "dbt build: PASS" || { echo "dbt build: FAIL ($OUT/build.log)"; rc=1; }
echo "scratch: $OUT"
exit "$rc"
