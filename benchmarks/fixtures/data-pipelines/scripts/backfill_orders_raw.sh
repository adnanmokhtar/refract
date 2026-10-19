#!/usr/bin/env bash
# replays orders_daily for a range after an outage
set -euo pipefail
airflow dags backfill -s "$1" -e "$2" orders_daily
