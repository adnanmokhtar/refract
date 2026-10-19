"""Daily refunds copy."""
from datetime import datetime

from airflow.sdk import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

with DAG(
    dag_id="refunds_daily",
    schedule="@daily",
    start_date=datetime(2025, 3, 1),
    catchup=False,
) as dag:
    SQLExecuteQueryOperator(
        task_id="copy_refunds",
        conn_id="warehouse",
        sql="insert into mart.refunds select * from staging.refunds where refunded_at >= '{{ data_interval_start }}' and refunded_at < '{{ data_interval_end }}'",
    )
