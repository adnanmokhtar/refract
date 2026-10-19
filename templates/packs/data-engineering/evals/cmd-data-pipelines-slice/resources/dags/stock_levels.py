"""Hourly stock levels — explicit interval timetable, idempotent partition replace, cleanup task."""
from datetime import datetime

import pendulum
from airflow.sdk import DAG
from airflow.timetables.interval import CronDataIntervalTimetable
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.providers.standard.operators.bash import BashOperator

with DAG(
    dag_id="stock_levels",
    schedule=CronDataIntervalTimetable("0 * * * *", timezone=pendulum.timezone("UTC")),
    start_date=datetime(2025, 3, 1),
    catchup=False,
    max_active_runs=1,
) as dag:
    replace = SQLExecuteQueryOperator(
        task_id="replace_stock_hour",
        conn_id="warehouse",
        retries=2,
        sql="""
            delete from mart.stock_levels where hour_start = '{{ data_interval_start }}';
            insert into mart.stock_levels
            select * from staging.stock where captured_at >= '{{ data_interval_start }}' and captured_at < '{{ data_interval_end }}';
        """,
    )
    cleanup = BashOperator(
        task_id="cleanup_tmp_files",
        bash_command="rm -rf /tmp/stock_levels/{{ run_id }}",
        trigger_rule="all_done",
    )
    replace >> cleanup
