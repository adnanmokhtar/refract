"""Daily sessions copy for the product dashboard."""
from datetime import datetime

from airflow.sdk import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

with DAG(
    dag_id="sessions_daily",
    schedule="30 1 * * *",
    start_date=datetime(2025, 3, 1),
    catchup=False,
) as dag:
    SQLExecuteQueryOperator(
        task_id="copy_sessions",
        conn_id="warehouse",
        sql="""
            delete from mart.sessions_copy
             where started_at >= '{{ data_interval_start }}' and started_at < '{{ data_interval_end }}';
            insert into mart.sessions_copy
            select * from staging.sessions
             where started_at >= '{{ data_interval_start }}' and started_at < '{{ data_interval_end }}';
        """,
    )
